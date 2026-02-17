const std = @import("std");
const args_mod = @import("cli/args.zig");
const config_mod = @import("cli/config.zig");
const discovery = @import("cli/discovery.zig");
const help = @import("cli/help.zig");
const errors = @import("cli/errors.zig");
const merge = @import("cli/merge.zig");
const init = @import("cli/init.zig");
const walker = @import("discovery/walker.zig");
const filter = @import("discovery/filter.zig");
const parse = @import("parser/parse.zig");
const cyclomatic = @import("metrics/cyclomatic.zig");
const cognitive = @import("metrics/cognitive.zig");
const console = @import("output/console.zig");
const json_output = @import("output/json_output.zig");
const exit_codes = @import("output/exit_codes.zig");

const version = "0.2.0";

pub fn main() !void {
    // Set up arena allocator for CLI lifecycle
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Get stdout and stderr with buffers
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    // Parse CLI arguments
    const cli_args = args_mod.parseArgs(arena_allocator) catch |err| {
        try stderr.print("error: failed to parse arguments: {s}\n", .{@errorName(err)});
        std.process.exit(2);
    };

    // Handle --help
    if (cli_args.help) {
        try help.printHelp(stdout);
        return;
    }

    // Handle --version
    if (cli_args.version) {
        try help.printVersion(stdout);
        return;
    }

    // Handle --init
    if (cli_args.init) {
        try init.runInit(arena_allocator);
        return;
    }

    // Discover config path
    const config_path = discovery.discoverConfigPath(arena_allocator, cli_args.config_path) catch |err| {
        if (err == error.ConfigFileNotFound) {
            try stderr.print("error: config file not found: {s}\n", .{cli_args.config_path.?});
            std.process.exit(3);
        }
        return err;
    };

    // Load or use default config
    var cfg: config_mod.Config = undefined;
    if (config_path) |path| {
        defer arena_allocator.free(path);

        // Detect format
        const format = discovery.detectConfigFormat(path);

        // Load config
        cfg = config_mod.loadConfig(arena_allocator, path, format) catch |err| {
            try stderr.print("error: invalid config at {s}: {s}\n", .{ path, @errorName(err) });
            std.process.exit(3);
        };

        // Validate config
        config_mod.validate(cfg) catch |err| {
            try stderr.print("error: config validation failed: {s}\n", .{@errorName(err)});
            std.process.exit(3);
        };
    } else {
        cfg = config_mod.defaults();
    }

    // Merge CLI args into config
    merge.mergeArgsIntoConfig(cli_args, &cfg);

    // Determine analysis paths
    const analysis_paths = if (cli_args.positional_paths.len > 0)
        cli_args.positional_paths
    else
        &[_][]const u8{"."};

    // Create filter config from config files section
    const filter_config = if (cfg.files) |files|
        filter.FilterConfig{
            .include_patterns = files.include,
            .exclude_patterns = files.exclude,
        }
    else
        filter.FilterConfig{};

    // Discover files
    var discovery_result = walker.discoverFiles(
        arena_allocator,
        analysis_paths,
        filter_config,
    ) catch |err| {
        try stderr.print("error: file discovery failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer discovery_result.deinit(arena_allocator);

    // Parse discovered files
    var parse_summary = parse.parseFiles(
        arena_allocator,
        discovery_result.files,
    ) catch |err| {
        try stderr.print("error: parsing failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer parse_summary.deinit(arena_allocator);

    // Step 1: Analyze all files once and store results
    const cycl_config = cyclomatic.CyclomaticConfig.default();

    // Build cognitive config from loaded config (use defaults if not specified)
    const default_cog = cognitive.CognitiveConfig.default();
    const cog_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds|
            if (thresholds.cognitive) |cog_thresh|
                cognitive.CognitiveConfig{
                    .warning_threshold = cog_thresh.warning orelse default_cog.warning_threshold,
                    .error_threshold = cog_thresh.@"error" orelse default_cog.error_threshold,
                }
            else
                default_cog
        else
            default_cog
    else
        default_cog;

    var file_results_list = std.ArrayList(console.FileThresholdResults).empty;
    defer file_results_list.deinit(arena_allocator);

    var total_warnings: u32 = 0;
    var total_errors: u32 = 0;
    var total_functions: u32 = 0;

    for (parse_summary.results) |result| {
        // Run cyclomatic analysis
        const cycl_results = try cyclomatic.analyzeFile(
            arena_allocator,
            result,
            cycl_config,
        );

        // Run cognitive analysis on the same file
        var cog_results: []const cognitive.CognitiveFunctionResult = &[_]cognitive.CognitiveFunctionResult{};
        if (result.tree) |tree| {
            const root = tree.rootNode();
            cog_results = try cognitive.analyzeFunctions(
                arena_allocator,
                root,
                cog_config,
                result.source,
            );
        }

        // Merge cognitive results into cyclomatic ThresholdResults
        // Both walks process the same tree in the same order, so indices align
        for (cycl_results, 0..) |*tr, i| {
            if (i < cog_results.len) {
                const cog = cog_results[i];
                tr.cognitive_complexity = cog.complexity;
                tr.cognitive_status = cyclomatic.validateThreshold(
                    cog.complexity,
                    cog_config.warning_threshold,
                    cog_config.error_threshold,
                );
            }
        }

        total_functions += @intCast(cycl_results.len);

        const violations = exit_codes.countViolations(cycl_results);
        total_warnings += violations.warnings;
        total_errors += violations.errors;

        try file_results_list.append(arena_allocator, console.FileThresholdResults{
            .path = result.path,
            .results = cycl_results,
        });
    }

    const file_results = file_results_list.items;

    // Step 2: Determine output format
    const effective_format = cli_args.format orelse (if (cfg.output) |out| (out.format orelse "console") else "console");

    // Step 3: Determine verbosity
    const verbosity: console.Verbosity = if (cli_args.quiet)
        .quiet
    else if (cli_args.verbose)
        .verbose
    else
        .default;

    // Step 4: Determine color
    const use_color = help.shouldUseColor(cli_args.color, cli_args.no_color);

    // Step 5: Output based on format
    if (std.mem.eql(u8, effective_format, "json")) {
        // JSON output
        const json_result = try json_output.buildJsonOutput(
            arena_allocator,
            file_results,
            total_warnings,
            total_errors,
        );
        const json_str = try json_output.serializeJsonOutput(arena_allocator, json_result);
        defer arena_allocator.free(json_str);

        // Write to stdout
        try stdout.writeAll(json_str);
        try stdout.writeAll("\n");

        // Also write to file if specified
        if (cli_args.output_file) |output_path| {
            const file = try std.fs.cwd().createFile(output_path, .{});
            defer file.close();
            try file.writeAll(json_str);
            try file.writeAll("\n");
        }
    } else {
        // Console output (default)
        const output_config = console.OutputConfig{
            .use_color = use_color,
            .verbosity = verbosity,
        };

        // Display per-file results
        for (file_results) |fr| {
            _ = try console.formatFileResults(
                stdout,
                arena_allocator,
                fr.path,
                fr.results,
                output_config,
            );
        }

        // Display summary
        try console.formatSummary(
            stdout,
            arena_allocator,
            @intCast(parse_summary.results.len),
            total_functions,
            total_warnings,
            total_errors,
            file_results,
            output_config,
        );
    }

    // Step 6: Determine and apply exit code
    const fail_on_warnings = if (cli_args.fail_on) |fo|
        std.mem.eql(u8, fo, "warning")
    else
        false;

    const exit_code = exit_codes.determineExitCode(
        parse_summary.failed_parses > 0,
        total_errors,
        total_warnings,
        fail_on_warnings,
    );

    if (exit_code != .success) {
        stdout.flush() catch {};
        std.process.exit(exit_code.toInt());
    }
}

// Test that version constant exists and is valid
test "version format" {
    try std.testing.expect(version.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, version, "0."));
}

// Import core modules to ensure their tests are discovered
test {
    _ = @import("core/types.zig");
    _ = @import("core/json.zig");
    _ = @import("test_helpers.zig");
    _ = @import("cli/config.zig");
    _ = @import("cli/args.zig");
    _ = @import("cli/help.zig");
    _ = @import("cli/errors.zig");
    _ = @import("cli/discovery.zig");
    _ = @import("cli/merge.zig");
    _ = @import("cli/init.zig");
    _ = @import("discovery/filter.zig");
    _ = @import("discovery/walker.zig");
    _ = @import("parser/tree_sitter.zig");
    _ = @import("parser/parse.zig");
    _ = @import("metrics/cyclomatic.zig");
    _ = @import("metrics/cognitive.zig");
    _ = @import("output/exit_codes.zig");
    _ = @import("output/console.zig");
    _ = @import("output/json_output.zig");
}
