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

const version = "0.1.0";

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

    // Run cyclomatic complexity analysis
    const cycl_config = cyclomatic.CyclomaticConfig.default();
    var total_warnings: u32 = 0;
    var total_errors: u32 = 0;
    var total_functions_analyzed: u32 = 0;

    for (parse_summary.results) |result| {
        const threshold_results = try cyclomatic.analyzeFile(
            arena_allocator,
            result,
            cycl_config,
        );

        total_functions_analyzed += @intCast(threshold_results.len);

        for (threshold_results) |tr| {
            switch (tr.status) {
                .warning => total_warnings += 1,
                .@"error" => total_errors += 1,
                .ok => {},
            }
        }
    }

    // Print summary
    try stdout.print("Discovered {d} files, parsed {d} successfully", .{
        discovery_result.files.len,
        parse_summary.successful_parses,
    });

    if (parse_summary.files_with_errors > 0) {
        try stdout.print(", {d} with errors", .{parse_summary.files_with_errors});
    }

    if (parse_summary.failed_parses > 0) {
        try stdout.print(", {d} failed", .{parse_summary.failed_parses});
    }

    try stdout.writeAll("\n");

    try stdout.print("Analyzed {d} functions", .{total_functions_analyzed});
    if (total_warnings > 0 or total_errors > 0) {
        try stdout.print(": {d} warnings, {d} errors", .{ total_warnings, total_errors });
    }
    try stdout.writeAll("\n");

    // Print detailed results if verbose
    if (cli_args.verbose) {
        try stdout.writeAll("\nParsed files:\n");
        for (parse_summary.results) |result| {
            const status = if (result.has_errors) " (has errors)" else "";
            try stdout.print("  {s} [{s}]{s}\n", .{
                result.path,
                @tagName(result.language),
                status,
            });
        }

        if (parse_summary.errors.len > 0) {
            try stdout.writeAll("\nFailed files:\n");
            for (parse_summary.errors) |err| {
                try stdout.print("  {s}: {s}\n", .{ err.path, err.message });
            }
        }

        // Show complexity details
        try stdout.writeAll("\nComplexity analysis:\n");
        for (parse_summary.results) |result| {
            const threshold_results = try cyclomatic.analyzeFile(
                arena_allocator,
                result,
                cycl_config,
            );

            if (threshold_results.len > 0) {
                try stdout.print("  {s}:\n", .{result.path});
                for (threshold_results) |tr| {
                    const status_str = switch (tr.status) {
                        .ok => "ok",
                        .warning => "WARN",
                        .@"error" => "ERROR",
                    };
                    try stdout.print("    {s} (line {d}): complexity {d} [{s}]\n", .{
                        tr.function_name,
                        tr.start_line,
                        tr.complexity,
                        status_str,
                    });
                }
            }
        }
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
    _ = @import("output/exit_codes.zig");
}
