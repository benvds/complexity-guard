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
const halstead = @import("metrics/halstead.zig");
const structural = @import("metrics/structural.zig");
const scoring = @import("metrics/scoring.zig");
const console = @import("output/console.zig");
const json_output = @import("output/json_output.zig");
const exit_codes = @import("output/exit_codes.zig");

const version = "0.3.0";

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

    // Helper: check if a metric family is enabled
    // Returns true if metrics is null (all enabled) or if the name is in the list
    const isMetricEnabled = struct {
        fn check(metrics: ?[]const []const u8, metric: []const u8) bool {
            const list = metrics orelse return true;
            for (list) |m| {
                if (std.mem.eql(u8, m, metric)) return true;
            }
            return false;
        }
    }.check;

    // Parse --metrics flag (e.g. "cyclomatic,halstead") into a slice of names
    var parsed_metrics: ?[]const []const u8 = null;
    var metrics_storage = std.ArrayList([]const u8).empty;
    defer metrics_storage.deinit(arena_allocator);
    if (cli_args.metrics) |metrics_str| {
        var iter = std.mem.splitScalar(u8, metrics_str, ',');
        while (iter.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t");
            if (trimmed.len > 0) {
                try metrics_storage.append(arena_allocator, trimmed);
            }
        }
        parsed_metrics = metrics_storage.items;
    }

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

    // Build halstead config from loaded config
    const default_hal = halstead.HalsteadConfig.default();
    const hal_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds|
            halstead.HalsteadConfig{
                .volume_warning = if (thresholds.halstead_volume) |t| @as(f64, @floatFromInt(t.warning orelse @as(u32, @intFromFloat(default_hal.volume_warning)))) else default_hal.volume_warning,
                .volume_error = if (thresholds.halstead_volume) |t| @as(f64, @floatFromInt(t.@"error" orelse @as(u32, @intFromFloat(default_hal.volume_error)))) else default_hal.volume_error,
                .difficulty_warning = default_hal.difficulty_warning,
                .difficulty_error = default_hal.difficulty_error,
                .effort_warning = default_hal.effort_warning,
                .effort_error = default_hal.effort_error,
                .bugs_warning = default_hal.bugs_warning,
                .bugs_error = default_hal.bugs_error,
            }
        else
            default_hal
    else
        default_hal;

    // Build structural config from loaded config
    const default_str = structural.StructuralConfig.default();
    const str_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds|
            structural.StructuralConfig{
                .function_length_warning = if (thresholds.line_count) |t| t.warning orelse default_str.function_length_warning else default_str.function_length_warning,
                .function_length_error = if (thresholds.line_count) |t| t.@"error" orelse default_str.function_length_error else default_str.function_length_error,
                .params_count_warning = if (thresholds.params_count) |t| t.warning orelse default_str.params_count_warning else default_str.params_count_warning,
                .params_count_error = if (thresholds.params_count) |t| t.@"error" orelse default_str.params_count_error else default_str.params_count_error,
                .nesting_depth_warning = if (thresholds.nesting_depth) |t| t.warning orelse default_str.nesting_depth_warning else default_str.nesting_depth_warning,
                .nesting_depth_error = if (thresholds.nesting_depth) |t| t.@"error" orelse default_str.nesting_depth_error else default_str.nesting_depth_error,
                .file_length_warning = default_str.file_length_warning,
                .file_length_error = default_str.file_length_error,
                .export_count_warning = default_str.export_count_warning,
                .export_count_error = default_str.export_count_error,
            }
        else
            default_str
    else
        default_str;

    // Build MetricThresholds for scoring (used across all files)
    const metric_thresholds = scoring.MetricThresholds{
        .cyclomatic_warning = @as(f64, @floatFromInt(cycl_config.warning_threshold)),
        .cyclomatic_error = @as(f64, @floatFromInt(cycl_config.error_threshold)),
        .cognitive_warning = @as(f64, @floatFromInt(cog_config.warning_threshold)),
        .cognitive_error = @as(f64, @floatFromInt(cog_config.error_threshold)),
        .halstead_warning = hal_config.volume_warning,
        .halstead_error = hal_config.volume_error,
        .function_length_warning = @as(f64, @floatFromInt(str_config.function_length_warning)),
        .function_length_error = @as(f64, @floatFromInt(str_config.function_length_error)),
        .params_count_warning = @as(f64, @floatFromInt(str_config.params_count_warning)),
        .params_count_error = @as(f64, @floatFromInt(str_config.params_count_error)),
        .nesting_depth_warning = @as(f64, @floatFromInt(str_config.nesting_depth_warning)),
        .nesting_depth_error = @as(f64, @floatFromInt(str_config.nesting_depth_error)),
    };

    // Resolve effective weights once (applies config overrides, normalizes)
    const effective_weights = scoring.resolveEffectiveWeights(cfg.weights);

    var file_results_list = std.ArrayList(console.FileThresholdResults).empty;
    defer file_results_list.deinit(arena_allocator);

    // Per-file score tracking for project score computation
    var file_scores_list = std.ArrayList(f64).empty;
    defer file_scores_list.deinit(arena_allocator);
    var file_function_counts = std.ArrayList(u32).empty;
    defer file_function_counts.deinit(arena_allocator);

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

        // Run Halstead analysis if enabled
        if (isMetricEnabled(parsed_metrics, "halstead")) {
            if (result.tree) |tree| {
                const root = tree.rootNode();
                const hal_results = try halstead.analyzeFunctions(
                    arena_allocator,
                    root,
                    hal_config,
                    result.source,
                );
                // Merge by index (same AST walk order)
                for (cycl_results, 0..) |*tr, i| {
                    if (i < hal_results.len) {
                        const hr = hal_results[i];
                        tr.halstead_volume = hr.metrics.volume;
                        tr.halstead_difficulty = hr.metrics.difficulty;
                        tr.halstead_effort = hr.metrics.effort;
                        tr.halstead_bugs = hr.metrics.bugs;
                        tr.halstead_volume_status = cyclomatic.validateThresholdF64(
                            hr.metrics.volume,
                            hal_config.volume_warning,
                            hal_config.volume_error,
                        );
                        tr.halstead_difficulty_status = cyclomatic.validateThresholdF64(
                            hr.metrics.difficulty,
                            hal_config.difficulty_warning,
                            hal_config.difficulty_error,
                        );
                        tr.halstead_effort_status = cyclomatic.validateThresholdF64(
                            hr.metrics.effort,
                            hal_config.effort_warning,
                            hal_config.effort_error,
                        );
                        tr.halstead_bugs_status = cyclomatic.validateThresholdF64(
                            hr.metrics.bugs,
                            hal_config.bugs_warning,
                            hal_config.bugs_error,
                        );
                    }
                }
            }
        }

        // Run structural function analysis if enabled
        var str_file_result: ?structural.FileStructuralResult = null;
        if (isMetricEnabled(parsed_metrics, "structural")) {
            if (result.tree) |tree| {
                const root = tree.rootNode();
                const str_results = try structural.analyzeFunctions(
                    arena_allocator,
                    root,
                    result.source,
                );
                // Merge by index
                for (cycl_results, 0..) |*tr, i| {
                    if (i < str_results.len) {
                        const sr = str_results[i];
                        tr.function_length = sr.function_length;
                        tr.params_count = sr.params_count;
                        tr.nesting_depth = sr.nesting_depth;
                        tr.end_line = sr.end_line;
                        tr.function_length_status = cyclomatic.validateThreshold(
                            sr.function_length,
                            str_config.function_length_warning,
                            str_config.function_length_error,
                        );
                        tr.params_count_status = cyclomatic.validateThreshold(
                            sr.params_count,
                            str_config.params_count_warning,
                            str_config.params_count_error,
                        );
                        tr.nesting_depth_status = cyclomatic.validateThreshold(
                            sr.nesting_depth,
                            str_config.nesting_depth_warning,
                            str_config.nesting_depth_error,
                        );
                    }
                }
                // Compute file-level structural metrics
                str_file_result = structural.analyzeFile(result.source, root);
            }
        }

        // Compute health scores for each function (always runs, not gated by --metrics)
        var func_scores = std.ArrayList(f64).empty;
        defer func_scores.deinit(arena_allocator);
        for (cycl_results) |*tr| {
            const breakdown = scoring.computeFunctionScore(tr.*, effective_weights, metric_thresholds);
            tr.health_score = breakdown.total;
            try func_scores.append(arena_allocator, breakdown.total);
        }

        // Compute file score and track for project score
        const file_score = scoring.computeFileScore(func_scores.items);
        try file_scores_list.append(arena_allocator, file_score);
        try file_function_counts.append(arena_allocator, @intCast(cycl_results.len));

        total_functions += @intCast(cycl_results.len);

        const violations = exit_codes.countViolations(cycl_results);
        total_warnings += violations.warnings;
        total_errors += violations.errors;

        try file_results_list.append(arena_allocator, console.FileThresholdResults{
            .path = result.path,
            .results = cycl_results,
            .structural = str_file_result,
        });
    }

    const file_results = file_results_list.items;

    // Compute project score from all file scores
    const project_score = scoring.computeProjectScore(file_scores_list.items, file_function_counts.items);

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
            project_score,
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
            .selected_metrics = parsed_metrics,
        };

        // Display per-file results
        for (file_results) |fr| {
            _ = try console.formatFileResults(
                stdout,
                arena_allocator,
                fr,
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
            project_score,
        );
    }

    // Step 6: Determine and apply exit code
    const fail_on_warnings = if (cli_args.fail_on) |fo|
        std.mem.eql(u8, fo, "warning")
    else
        false;

    // Baseline ratchet check: compare project score against configured baseline
    var baseline_failed = false;
    // Check config baseline
    if (cfg.baseline) |baseline_val| {
        if (project_score < baseline_val - 0.5) {
            baseline_failed = true;
            try stderr.print("Health score {d:.1} is below baseline {d:.1}\n", .{ project_score, baseline_val });
        }
    }
    // Check CLI --baseline flag
    if (!baseline_failed) {
        if (cli_args.baseline) |baseline_str| {
            const baseline_val = std.fmt.parseFloat(f64, baseline_str) catch 0.0;
            if (project_score < baseline_val - 0.5) {
                baseline_failed = true;
                try stderr.print("Health score {d:.1} is below baseline {d:.1}\n", .{ project_score, baseline_val });
            }
        }
    }

    const exit_code = exit_codes.determineExitCode(
        parse_summary.failed_parses > 0,
        total_errors,
        total_warnings,
        fail_on_warnings,
        baseline_failed,
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
    _ = @import("metrics/halstead.zig");
    _ = @import("metrics/structural.zig");
    _ = @import("output/exit_codes.zig");
    _ = @import("output/console.zig");
    _ = @import("output/json_output.zig");
    _ = @import("metrics/scoring.zig");
}
