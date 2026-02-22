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
const tree_sitter_mod = @import("parser/tree_sitter.zig");
const cyclomatic = @import("metrics/cyclomatic.zig");
const cognitive = @import("metrics/cognitive.zig");
const halstead = @import("metrics/halstead.zig");
const structural = @import("metrics/structural.zig");
const scoring = @import("metrics/scoring.zig");
const duplication_mod = @import("metrics/duplication.zig");
const console = @import("output/console.zig");
const json_output = @import("output/json_output.zig");
const sarif_output = @import("output/sarif_output.zig");
const html_output = @import("output/html_output.zig");
const exit_codes = @import("output/exit_codes.zig");
const parallel = @import("pipeline/parallel.zig");

const version = "0.6.0";

/// Write a minimal config file with a baseline field.
/// Used by --save-baseline when no existing config file is found.
fn writeDefaultConfigWithBaseline(allocator: std.mem.Allocator, path: []const u8, baseline: f64) !void {
    var content = std.ArrayList(u8).empty;
    defer content.deinit(allocator);
    const writer = content.writer(allocator);
    try writer.writeAll("{\n");
    try writer.writeAll("  \"output\": {\n");
    try writer.writeAll("    \"format\": \"console\"\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"weights\": {\n");
    try writer.writeAll("    \"cyclomatic\": 0.20,\n");
    try writer.writeAll("    \"cognitive\": 0.30,\n");
    try writer.writeAll("    \"halstead\": 0.15,\n");
    try writer.writeAll("    \"structural\": 0.15,\n");
    try writer.writeAll("    \"duplication\": 0.20\n");
    try writer.writeAll("  },\n");
    try writer.print("  \"baseline\": {d:.1}\n", .{baseline});
    try writer.writeAll("}\n");
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = content.items });
}

/// Build HalsteadConfig from ThresholdsConfig, falling back to defaults for missing fields.
/// Exposed for unit testing.
pub fn buildHalsteadConfig(thresholds: config_mod.ThresholdsConfig) halstead.HalsteadConfig {
    const default_hal = halstead.HalsteadConfig.default();
    return halstead.HalsteadConfig{
        .volume_warning = if (thresholds.halstead_volume) |t| @as(f64, @floatFromInt(t.warning orelse @as(u32, @intFromFloat(default_hal.volume_warning)))) else default_hal.volume_warning,
        .volume_error = if (thresholds.halstead_volume) |t| @as(f64, @floatFromInt(t.@"error" orelse @as(u32, @intFromFloat(default_hal.volume_error)))) else default_hal.volume_error,
        .difficulty_warning = if (thresholds.halstead_difficulty) |t| @as(f64, @floatFromInt(t.warning orelse @as(u32, @intFromFloat(default_hal.difficulty_warning)))) else default_hal.difficulty_warning,
        .difficulty_error = if (thresholds.halstead_difficulty) |t| @as(f64, @floatFromInt(t.@"error" orelse @as(u32, @intFromFloat(default_hal.difficulty_error)))) else default_hal.difficulty_error,
        .effort_warning = if (thresholds.halstead_effort) |t| @as(f64, @floatFromInt(t.warning orelse @as(u32, @intFromFloat(default_hal.effort_warning)))) else default_hal.effort_warning,
        .effort_error = if (thresholds.halstead_effort) |t| @as(f64, @floatFromInt(t.@"error" orelse @as(u32, @intFromFloat(default_hal.effort_error)))) else default_hal.effort_error,
        .bugs_warning = if (thresholds.halstead_bugs) |t| @as(f64, @floatFromInt(t.warning orelse 1)) else default_hal.bugs_warning,
        .bugs_error = if (thresholds.halstead_bugs) |t| @as(f64, @floatFromInt(t.@"error" orelse 2)) else default_hal.bugs_error,
    };
}

/// Build DuplicationConfig from Config, applying configurable thresholds from config file.
fn buildDuplicationConfig(cfg: config_mod.Config) duplication_mod.DuplicationConfig {
    var dc = duplication_mod.DuplicationConfig.default();
    if (cfg.analysis) |a| {
        if (a.thresholds) |t| {
            if (t.duplication) |d| {
                if (d.file_warning) |v| dc.file_warning_pct = v;
                if (d.file_error) |v| dc.file_error_pct = v;
                if (d.project_warning) |v| dc.project_warning_pct = v;
                if (d.project_error) |v| dc.project_error_pct = v;
            }
        }
    }
    return dc;
}

/// Build StructuralConfig from ThresholdsConfig, falling back to defaults for missing fields.
/// Exposed for unit testing.
pub fn buildStructuralConfig(thresholds: config_mod.ThresholdsConfig) structural.StructuralConfig {
    const default_str = structural.StructuralConfig.default();
    return structural.StructuralConfig{
        .function_length_warning = if (thresholds.line_count) |t| t.warning orelse default_str.function_length_warning else default_str.function_length_warning,
        .function_length_error = if (thresholds.line_count) |t| t.@"error" orelse default_str.function_length_error else default_str.function_length_error,
        .params_count_warning = if (thresholds.params_count) |t| t.warning orelse default_str.params_count_warning else default_str.params_count_warning,
        .params_count_error = if (thresholds.params_count) |t| t.@"error" orelse default_str.params_count_error else default_str.params_count_error,
        .nesting_depth_warning = if (thresholds.nesting_depth) |t| t.warning orelse default_str.nesting_depth_warning else default_str.nesting_depth_warning,
        .nesting_depth_error = if (thresholds.nesting_depth) |t| t.@"error" orelse default_str.nesting_depth_error else default_str.nesting_depth_error,
        .file_length_warning = if (thresholds.file_length) |t| t.warning orelse default_str.file_length_warning else default_str.file_length_warning,
        .file_length_error = if (thresholds.file_length) |t| t.@"error" orelse default_str.file_length_error else default_str.file_length_error,
        .export_count_warning = if (thresholds.export_count) |t| t.warning orelse default_str.export_count_warning else default_str.export_count_warning,
        .export_count_error = if (thresholds.export_count) |t| t.@"error" orelse default_str.export_count_error else default_str.export_count_error,
    };
}

/// Build CyclomaticConfig from ThresholdsConfig, falling back to defaults for missing fields.
/// Exposed for unit testing.
pub fn buildCyclomaticConfig(thresholds: config_mod.ThresholdsConfig) cyclomatic.CyclomaticConfig {
    const default_cycl = cyclomatic.CyclomaticConfig.default();
    return cyclomatic.CyclomaticConfig{
        .count_logical_operators = default_cycl.count_logical_operators,
        .count_nullish_coalescing = default_cycl.count_nullish_coalescing,
        .count_optional_chaining = default_cycl.count_optional_chaining,
        .count_ternary = default_cycl.count_ternary,
        .count_default_params = default_cycl.count_default_params,
        .switch_case_mode = default_cycl.switch_case_mode,
        .warning_threshold = if (thresholds.cyclomatic) |t| t.warning orelse default_cycl.warning_threshold else default_cycl.warning_threshold,
        .error_threshold = if (thresholds.cyclomatic) |t| t.@"error" orelse default_cycl.error_threshold else default_cycl.error_threshold,
    };
}

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
    defer stderr.flush() catch {};

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

    // Handle --init: write default config and exit immediately (no analysis needed)
    if (cli_args.init) {
        try init.runInit(arena_allocator);
        return;
    }

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
    const cycl_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds| buildCyclomaticConfig(thresholds) else cyclomatic.CyclomaticConfig.default()
    else
        cyclomatic.CyclomaticConfig.default();

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

    // Build halstead config from loaded config (uses buildHalsteadConfig helper)
    const hal_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds| buildHalsteadConfig(thresholds) else halstead.HalsteadConfig.default()
    else
        halstead.HalsteadConfig.default();

    // Build structural config from loaded config (uses buildStructuralConfig helper)
    const str_config = if (cfg.analysis) |analysis|
        if (analysis.thresholds) |thresholds| buildStructuralConfig(thresholds) else structural.StructuralConfig.default()
    else
        structural.StructuralConfig.default();

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

    // Determine if duplication detection is enabled (via --duplication flag or --metrics duplication)
    const duplication_enabled: bool = blk: {
        // --no-duplication overrides everything
        if (cfg.analysis) |a| {
            if (a.no_duplication) |nd| {
                if (nd) break :blk false;
            }
        }
        if (cfg.analysis) |a| {
            if (a.duplication_enabled) |de| {
                if (de) break :blk true;
            }
        }
        if (parsed_metrics) |pm| {
            for (pm) |m| {
                if (std.mem.eql(u8, m, "duplication")) break :blk true;
            }
        }
        break :blk false;
    };

    // Resolve effective weights once (applies config overrides, normalizes)
    const effective_weights = scoring.resolveEffectiveWeights(cfg.weights, duplication_enabled);

    // Resolve effective thread count: CLI/config threads override, else auto-detect CPU count
    const cpu_count = std.Thread.getCpuCount() catch 1;
    const effective_threads: usize = if (cfg.analysis) |a| if (a.threads) |t| @as(usize, @intCast(t)) else cpu_count else cpu_count;

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
    var failed_parses: u32 = 0;

    // Capture analysis start time for elapsed_ms computation
    const analysis_start = std.time.nanoTimestamp();

    if (effective_threads <= 1) {
        // Sequential path: use existing parseFiles + per-file for-loop (zero pool overhead)
        const seq_parse_summary = parse.parseFiles(
            arena_allocator,
            discovery_result.files,
        ) catch |err| {
            try stderr.print("error: parsing failed: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        };

        failed_parses = seq_parse_summary.failed_parses;

        for (seq_parse_summary.results) |result| {
            // Free the TSTree after processing each file. The arena allocator only frees Zig
            // allocations; TSTree is allocated via ts_malloc (C heap) and requires an explicit
            // ts_tree_delete call. Function name slices borrow from result.source which must
            // remain alive until output, so we only free the tree here — not the full result.
            defer if (result.tree) |tree| tree.deinit();
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
                    str_file_result = structural.analyzeFile(result.source, root);
                }
            }

            // Compute health scores for each function
            var func_scores = std.ArrayList(f64).empty;
            defer func_scores.deinit(arena_allocator);
            for (cycl_results) |*tr| {
                const breakdown = scoring.computeFunctionScore(tr.*, effective_weights, metric_thresholds);
                tr.health_score = breakdown.total;
                try func_scores.append(arena_allocator, breakdown.total);
            }

            const file_score = scoring.computeFileScore(func_scores.items);
            try file_scores_list.append(arena_allocator, file_score);
            try file_function_counts.append(arena_allocator, @intCast(cycl_results.len));

            total_functions += @intCast(cycl_results.len);

            const violations = exit_codes.countViolationsFiltered(cycl_results, parsed_metrics);
            total_warnings += violations.warnings;
            total_errors += violations.errors;

            try file_results_list.append(arena_allocator, console.FileThresholdResults{
                .path = result.path,
                .results = cycl_results,
                .structural = str_file_result,
            });
        }
    } else {
        // Parallel path: dispatch all files to thread pool, collect sorted results
        const par_out = try parallel.analyzeFilesParallel(
            arena_allocator,
            discovery_result.files,
            effective_threads,
            cycl_config,
            cog_config,
            hal_config,
            str_config,
            effective_weights,
            metric_thresholds,
            parsed_metrics,
        );
        // par_out.results is owned by arena_allocator (paths and results slices duped)
        failed_parses = par_out.summary.failed;

        for (par_out.results) |par_result| {
            try file_scores_list.append(arena_allocator, par_result.file_score);
            try file_function_counts.append(arena_allocator, par_result.function_count);

            total_functions += par_result.function_count;
            total_warnings += par_result.warning_count;
            total_errors += par_result.error_count;

            try file_results_list.append(arena_allocator, console.FileThresholdResults{
                .path = par_result.path,
                .results = par_result.results,
                .structural = par_result.structural,
            });
        }
    }

    // Compute elapsed time in milliseconds (covers both parallel and sequential paths)
    const analysis_end = std.time.nanoTimestamp();
    const elapsed_ns = analysis_end - analysis_start;
    const elapsed_ms: u64 = @intCast(@divTrunc(elapsed_ns, std.time.ns_per_ms));

    // Verbose mode: print timing to stderr (not stdout, to avoid polluting machine-readable output)
    if (cli_args.verbose) {
        try stderr.print("Analyzed {d} files in {d}ms ({d} threads)\n", .{
            file_results_list.items.len,
            elapsed_ms,
            effective_threads,
        });
    }

    // Sort file results by path for deterministic output regardless of thread count or discovery order
    std.mem.sort(console.FileThresholdResults, file_results_list.items, {}, struct {
        fn lessThan(_: void, a: console.FileThresholdResults, b: console.FileThresholdResults) bool {
            return std.mem.lessThan(u8, a.path, b.path);
        }
    }.lessThan);

    const file_results = file_results_list.items;

    // Run duplication pass after all per-file analysis (re-parses files to get AST tokens)
    var dup_result: ?duplication_mod.DuplicationResult = null;
    if (duplication_enabled) {
        const dup_config = buildDuplicationConfig(cfg);

        var file_tokens_list = std.ArrayList(duplication_mod.FileTokens).empty;
        defer file_tokens_list.deinit(arena_allocator);

        for (discovery_result.files) |file_path| {
            const source = std.fs.cwd().readFileAlloc(arena_allocator, file_path, 10 * 1024 * 1024) catch continue;
            const lang = parse.selectLanguage(file_path) catch continue;
            const ts_parser = tree_sitter_mod.Parser.init() catch continue;
            defer ts_parser.deinit();
            ts_parser.setLanguage(lang) catch continue;
            const tree = ts_parser.parseString(source) catch continue;
            defer tree.deinit();
            const root = tree.rootNode();
            const tokens = duplication_mod.tokenizeTree(arena_allocator, root, source) catch continue;
            file_tokens_list.append(arena_allocator, duplication_mod.FileTokens{
                .path = file_path,
                .tokens = tokens,
            }) catch continue;
        }

        dup_result = duplication_mod.detectDuplication(
            arena_allocator,
            file_tokens_list.items,
            dup_config,
        ) catch null;
    }

    // If duplication enabled, blend duplication scores into file scores and update warning/error counts
    if (dup_result) |dup| {
        const dup_config = buildDuplicationConfig(cfg);
        for (dup.file_results) |fdr| {
            // Find matching file_scores_list entry by path
            for (file_results_list.items, 0..) |fr, i| {
                if (std.mem.eql(u8, fr.path, fdr.path)) {
                    const dup_score = scoring.normalizeDuplication(
                        fdr.duplication_pct,
                        dup_config.file_warning_pct,
                        dup_config.file_error_pct,
                    );
                    file_scores_list.items[i] = scoring.computeFileScoreWithDuplication(
                        file_scores_list.items[i],
                        dup_score,
                        effective_weights,
                    );
                    if (fdr.@"error") {
                        total_errors += 1;
                    } else if (fdr.warning) {
                        total_warnings += 1;
                    }
                    break;
                }
            }
        }
        // Project-level duplication threshold violations
        if (dup.project_error) {
            total_errors += 1;
        } else if (dup.project_warning) {
            total_warnings += 1;
        }
    }

    // Compute project score from all file scores
    const project_score = scoring.computeProjectScore(file_scores_list.items, file_function_counts.items);

    // Handle --save-baseline: write rounded score to config file, then exit
    if (cli_args.save_baseline) {
        const rounded_score = @round(project_score * 10.0) / 10.0;
        // Determine config file path: use discovered config or default
        const save_path = ".complexityguard.json";

        // Try to read existing config to preserve its contents
        const existing_content = std.fs.cwd().readFileAlloc(arena_allocator, save_path, 1024 * 1024) catch null;

        if (existing_content) |content| {
            // Parse existing JSON as dynamic value, update baseline, write back
            const parsed = std.json.parseFromSlice(std.json.Value, arena_allocator, content, .{}) catch null;
            if (parsed) |p| {
                // Rebuild JSON with baseline field added/updated
                var new_content = std.ArrayList(u8).empty;
                defer new_content.deinit(arena_allocator);
                const writer = new_content.writer(arena_allocator);

                if (p.value == .object) {
                    try writer.writeAll("{\n");
                    var first = true;
                    var iter = p.value.object.iterator();
                    while (iter.next()) |entry| {
                        if (!first) try writer.writeAll(",\n");
                        first = false;
                        if (std.mem.eql(u8, entry.key_ptr.*, "baseline")) {
                            try writer.print("  \"baseline\": {d:.1}", .{rounded_score});
                        } else {
                            try writer.print("  \"{s}\": ", .{entry.key_ptr.*});
                            const val_str = try std.json.Stringify.valueAlloc(arena_allocator, entry.value_ptr.*, .{ .whitespace = .indent_2 });
                            defer arena_allocator.free(val_str);
                            try writer.writeAll(val_str);
                        }
                    }
                    // Add baseline if it wasn't already present
                    if (p.value.object.get("baseline") == null) {
                        if (!first) try writer.writeAll(",\n");
                        try writer.print("  \"baseline\": {d:.1}", .{rounded_score});
                    }
                    try writer.writeAll("\n}\n");
                    try std.fs.cwd().writeFile(.{ .sub_path = save_path, .data = new_content.items });
                } else {
                    // Not an object, write new config
                    try writeDefaultConfigWithBaseline(arena_allocator, save_path, rounded_score);
                }
            } else {
                // Parse failed, write new config
                try writeDefaultConfigWithBaseline(arena_allocator, save_path, rounded_score);
            }
        } else {
            // No existing config, create new one with baseline
            try writeDefaultConfigWithBaseline(arena_allocator, save_path, rounded_score);
        }

        try stdout.print("Baseline saved: {d:.1}\n", .{rounded_score});
        return;
    }

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

    // Step 5: Baseline ratchet check — must run before format dispatch so SARIF output can include baseline results
    const fail_on_warnings = if (cli_args.fail_on) |fo|
        std.mem.eql(u8, fo, "warning")
    else
        false;

    var baseline_failed = false;
    // CLI --fail-health-below overrides config baseline when present
    if (cli_args.fail_health_below) |fhb_str| {
        const fhb_val = std.fmt.parseFloat(f64, fhb_str) catch 0.0;
        if (project_score < fhb_val - 0.5) {
            baseline_failed = true;
            try stderr.print("Health score {d:.1} is below threshold {d:.1}\n", .{ project_score, fhb_val });
        }
    } else {
        // Check config baseline (only when CLI --fail-health-below not provided)
        if (cfg.baseline) |baseline_val| {
            if (project_score < baseline_val - 0.5) {
                baseline_failed = true;
                try stderr.print("Health score {d:.1} is below baseline {d:.1}\n", .{ project_score, baseline_val });
            }
        }
        // Check legacy CLI --baseline flag
        if (!baseline_failed) {
            if (cli_args.baseline) |baseline_str| {
                const baseline_val = std.fmt.parseFloat(f64, baseline_str) catch 0.0;
                if (project_score < baseline_val - 0.5) {
                    baseline_failed = true;
                    try stderr.print("Health score {d:.1} is below baseline {d:.1}\n", .{ project_score, baseline_val });
                }
            }
        }
    }

    // Step 6: Output based on format
    if (std.mem.eql(u8, effective_format, "json")) {
        // JSON output
        const json_result = try json_output.buildJsonOutput(
            arena_allocator,
            file_results,
            total_warnings,
            total_errors,
            project_score,
            elapsed_ms,
            @intCast(effective_threads),
            dup_result,
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
    } else if (std.mem.eql(u8, effective_format, "sarif")) {
        // SARIF output
        const sarif_thresholds = sarif_output.SarifThresholds{
            .cyclomatic_warning = cycl_config.warning_threshold,
            .cyclomatic_error = cycl_config.error_threshold,
            .cognitive_warning = cog_config.warning_threshold,
            .cognitive_error = cog_config.error_threshold,
            .halstead_volume_warning = hal_config.volume_warning,
            .halstead_volume_error = hal_config.volume_error,
            .halstead_difficulty_warning = hal_config.difficulty_warning,
            .halstead_difficulty_error = hal_config.difficulty_error,
            .halstead_effort_warning = hal_config.effort_warning,
            .halstead_effort_error = hal_config.effort_error,
            .halstead_bugs_warning = hal_config.bugs_warning,
            .halstead_bugs_error = hal_config.bugs_error,
            .line_count_warning = str_config.function_length_warning,
            .line_count_error = str_config.function_length_error,
            .param_count_warning = str_config.params_count_warning,
            .param_count_error = str_config.params_count_error,
            .nesting_depth_warning = str_config.nesting_depth_warning,
            .nesting_depth_error = str_config.nesting_depth_error,
        };

        const sarif_result = try sarif_output.buildSarifOutput(
            arena_allocator,
            file_results,
            version,
            baseline_failed,
            cfg.baseline,
            project_score,
            parsed_metrics,
            sarif_thresholds,
            dup_result,
        );
        const sarif_str = try sarif_output.serializeSarifOutput(arena_allocator, sarif_result);

        try stdout.writeAll(sarif_str);
        try stdout.writeAll("\n");

        // Also write to file if specified
        if (cli_args.output_file) |output_path| {
            const file = try std.fs.cwd().createFile(output_path, .{});
            defer file.close();
            try file.writeAll(sarif_str);
            try file.writeAll("\n");
        }
    } else if (std.mem.eql(u8, effective_format, "html")) {
        // HTML report output
        const html_str = try html_output.buildHtmlReport(
            arena_allocator,
            file_results,
            total_warnings,
            total_errors,
            project_score,
            version,
            dup_result,
        );

        if (cli_args.output_file) |output_path| {
            const file = try std.fs.cwd().createFile(output_path, .{});
            defer file.close();
            try file.writeAll(html_str);
        } else {
            try stdout.writeAll(html_str);
        }
    } else {
        // Console output (default)
        const output_config = console.OutputConfig{
            .use_color = use_color,
            .verbosity = verbosity,
            .selected_metrics = parsed_metrics,
            .file_level_thresholds = console.FileLevelThresholds{
                .file_length_warning = str_config.file_length_warning,
                .file_length_error = str_config.file_length_error,
                .export_count_warning = str_config.export_count_warning,
                .export_count_error = str_config.export_count_error,
            },
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
            @intCast(file_results.len),
            total_functions,
            total_warnings,
            total_errors,
            file_results,
            output_config,
            project_score,
        );

        // Display duplication section after summary (only when enabled)
        if (dup_result) |dup| {
            try console.formatDuplicationSection(
                stdout,
                arena_allocator,
                dup,
                output_config,
            );
        }
    }

    // Step 7: Determine and apply exit code
    const exit_code = exit_codes.determineExitCode(
        failed_parses > 0,
        total_errors,
        total_warnings,
        fail_on_warnings,
        baseline_failed,
    );

    if (exit_code != .success) {
        stdout.flush() catch {};
        stderr.flush() catch {};
        std.process.exit(exit_code.toInt());
    }
}

// Test that version constant exists and is valid
test "version format" {
    try std.testing.expect(version.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, version, "0."));
}

test "buildHalsteadConfig: uses defaults when no thresholds set" {
    const thresholds = config_mod.ThresholdsConfig{};
    const default_hal = halstead.HalsteadConfig.default();
    const result = buildHalsteadConfig(thresholds);
    try std.testing.expectApproxEqAbs(default_hal.volume_warning, result.volume_warning, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.volume_error, result.volume_error, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.difficulty_warning, result.difficulty_warning, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.difficulty_error, result.difficulty_error, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.effort_warning, result.effort_warning, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.effort_error, result.effort_error, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.bugs_warning, result.bugs_warning, 1e-6);
    try std.testing.expectApproxEqAbs(default_hal.bugs_error, result.bugs_error, 1e-6);
}

test "buildHalsteadConfig: halstead_difficulty threshold read from config" {
    const thresholds = config_mod.ThresholdsConfig{
        .halstead_difficulty = config_mod.ThresholdPair{ .warning = 50, .@"error" = 100 },
    };
    const result = buildHalsteadConfig(thresholds);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), result.difficulty_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), result.difficulty_error, 1e-6);
}

test "buildHalsteadConfig: halstead_effort threshold read from config" {
    const thresholds = config_mod.ThresholdsConfig{
        .halstead_effort = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 99999 },
    };
    const result = buildHalsteadConfig(thresholds);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.effort_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 99999.0), result.effort_error, 1e-6);
}

test "buildHalsteadConfig: halstead_bugs threshold read from config" {
    const thresholds = config_mod.ThresholdsConfig{
        .halstead_bugs = config_mod.ThresholdPair{ .warning = 3, .@"error" = 9999 },
    };
    const result = buildHalsteadConfig(thresholds);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result.bugs_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.bugs_error, 1e-6);
}

test "buildHalsteadConfig: very high thresholds set difficulty to 9999" {
    // When all halstead thresholds set to 9999, no function should trigger warnings
    const thresholds = config_mod.ThresholdsConfig{
        .halstead_difficulty = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
        .halstead_effort = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
        .halstead_bugs = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
    };
    const result = buildHalsteadConfig(thresholds);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.difficulty_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.difficulty_error, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.effort_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.effort_error, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.bugs_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 9999.0), result.bugs_error, 1e-6);
}

test "buildStructuralConfig: uses defaults when no thresholds set" {
    const thresholds = config_mod.ThresholdsConfig{};
    const default_str = structural.StructuralConfig.default();
    const result = buildStructuralConfig(thresholds);
    try std.testing.expectEqual(default_str.file_length_warning, result.file_length_warning);
    try std.testing.expectEqual(default_str.file_length_error, result.file_length_error);
    try std.testing.expectEqual(default_str.export_count_warning, result.export_count_warning);
    try std.testing.expectEqual(default_str.export_count_error, result.export_count_error);
}

test "buildStructuralConfig: file_length threshold read from config" {
    const thresholds = config_mod.ThresholdsConfig{
        .file_length = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
    };
    const result = buildStructuralConfig(thresholds);
    try std.testing.expectEqual(@as(u32, 9999), result.file_length_warning);
    try std.testing.expectEqual(@as(u32, 9999), result.file_length_error);
}

test "buildStructuralConfig: export_count threshold read from config" {
    const thresholds = config_mod.ThresholdsConfig{
        .export_count = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
    };
    const result = buildStructuralConfig(thresholds);
    try std.testing.expectEqual(@as(u32, 9999), result.export_count_warning);
    try std.testing.expectEqual(@as(u32, 9999), result.export_count_error);
}

test "buildStructuralConfig: very high thresholds suppress file-level violations" {
    const thresholds = config_mod.ThresholdsConfig{
        .file_length = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
        .export_count = config_mod.ThresholdPair{ .warning = 9999, .@"error" = 9999 },
    };
    const result = buildStructuralConfig(thresholds);
    // A file with 400 lines and 20 exports would NOT trigger with these thresholds
    try std.testing.expect(result.file_length_warning > 400);
    try std.testing.expect(result.export_count_warning > 20);
}

test "buildCyclomaticConfig: applies config thresholds" {
    const thresholds = config_mod.ThresholdsConfig{
        .cyclomatic = config_mod.ThresholdPair{ .warning = 15, .@"error" = 30 },
    };
    const result = buildCyclomaticConfig(thresholds);
    try std.testing.expectEqual(@as(u32, 15), result.warning_threshold);
    try std.testing.expectEqual(@as(u32, 30), result.error_threshold);
}

test "buildCyclomaticConfig: falls back to defaults for null" {
    const thresholds = config_mod.ThresholdsConfig{};
    const default_cycl = cyclomatic.CyclomaticConfig.default();
    const result = buildCyclomaticConfig(thresholds);
    try std.testing.expectEqual(default_cycl.warning_threshold, result.warning_threshold);
    try std.testing.expectEqual(default_cycl.error_threshold, result.error_threshold);
}

test "buildCyclomaticConfig: partial override (warning only)" {
    const thresholds = config_mod.ThresholdsConfig{
        .cyclomatic = config_mod.ThresholdPair{ .warning = 12, .@"error" = null },
    };
    const default_cycl = cyclomatic.CyclomaticConfig.default();
    const result = buildCyclomaticConfig(thresholds);
    try std.testing.expectEqual(@as(u32, 12), result.warning_threshold);
    try std.testing.expectEqual(default_cycl.error_threshold, result.error_threshold);
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
    _ = @import("output/sarif_output.zig");
    _ = @import("output/html_output.zig");
    _ = @import("metrics/scoring.zig");
    _ = @import("pipeline/parallel.zig");
    _ = @import("metrics/duplication.zig");
}
