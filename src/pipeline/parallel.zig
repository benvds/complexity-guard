const std = @import("std");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const cognitive = @import("../metrics/cognitive.zig");
const halstead = @import("../metrics/halstead.zig");
const structural = @import("../metrics/structural.zig");
const scoring = @import("../metrics/scoring.zig");
const parse = @import("../parser/parse.zig");
const tree_sitter = @import("../parser/tree_sitter.zig");
const console = @import("../output/console.zig");
const exit_codes = @import("../output/exit_codes.zig");

const Allocator = std.mem.Allocator;

/// Per-file analysis result returned by the parallel pipeline.
/// All owned memory is allocated from the main allocator (not per-worker arenas).
pub const FileAnalysisResult = struct {
    path: []const u8, // owned, duped to main allocator
    results: []cyclomatic.ThresholdResult, // owned slice
    structural: ?structural.FileStructuralResult,
    file_score: f64,
    function_count: u32,
    warning_count: u32,
    error_count: u32,
};

/// Summary counts returned alongside the results slice.
pub const ParallelSummary = struct {
    total: u32,
    successful: u32,
    failed: u32,
    with_errors: u32,
};

/// Context shared by all worker goroutines.
/// Mutex protects results and errors lists; all heavy computation runs outside the lock.
const WorkerContext = struct {
    mutex: std.Thread.Mutex,
    results: std.ArrayList(FileAnalysisResult),
    // Main allocator for durable allocations (paths, slices that outlive workers).
    // NOT thread-safe — all operations on this allocator MUST be inside mutex lock.
    allocator: Allocator,
    // Metric configs (read-only, shared safely)
    cycl_config: cyclomatic.CyclomaticConfig,
    cog_config: cognitive.CognitiveConfig,
    hal_config: halstead.HalsteadConfig,
    str_config: structural.StructuralConfig,
    effective_weights: scoring.EffectiveWeights,
    metric_thresholds: scoring.MetricThresholds,
    parsed_metrics: ?[]const []const u8,
    // Track successful/failed counts atomically
    successful: std.atomic.Value(u32),
    failed: std.atomic.Value(u32),
    with_errors: std.atomic.Value(u32),
};

/// Check if a metric is enabled (same logic as main.zig isMetricEnabled).
fn isMetricEnabled(metrics: ?[]const []const u8, metric: []const u8) bool {
    const list = metrics orelse return true;
    for (list) |m| {
        if (std.mem.eql(u8, m, metric)) return true;
    }
    return false;
}

/// Worker function invoked by std.Thread.Pool for each file.
/// Creates per-invocation arena and per-invocation parser (TSParser is not thread-safe).
/// All computation uses the per-worker arena. The shared allocator (ctx.allocator) is only
/// touched inside the mutex lock, since ArenaAllocator is NOT thread-safe.
fn analyzeFileWorker(ctx: *WorkerContext, path: []const u8) void {
    // Per-worker arena for all temporary allocations within this invocation
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    // Create per-worker parser (TSParser is NOT thread-safe)
    const parser = tree_sitter.Parser.init() catch {
        _ = ctx.failed.fetchAdd(1, .monotonic);
        return;
    };
    defer parser.deinit();

    // Read file source
    const source = std.fs.cwd().readFileAlloc(arena_alloc, path, 10 * 1024 * 1024) catch {
        _ = ctx.failed.fetchAdd(1, .monotonic);
        return;
    };
    // source is in arena — freed at scope exit

    // Select language from file extension
    const language = parse.selectLanguage(path) catch {
        _ = ctx.failed.fetchAdd(1, .monotonic);
        return;
    };

    // Configure parser for this language and parse
    parser.setLanguage(language) catch {
        _ = ctx.failed.fetchAdd(1, .monotonic);
        return;
    };

    const tree = parser.parseString(source) catch {
        _ = ctx.failed.fetchAdd(1, .monotonic);
        return;
    };
    defer tree.deinit();

    // Check for syntax errors
    const root = tree.rootNode();
    const has_errors = root.hasError();
    if (has_errors) {
        _ = ctx.with_errors.fetchAdd(1, .monotonic);
    }
    _ = ctx.successful.fetchAdd(1, .monotonic);

    // Construct a lightweight ParseResult to feed existing metric analyzers
    const parse_result = parse.ParseResult{
        .path = path,
        .tree = tree,
        .language = language,
        .has_errors = has_errors,
        .source = source,
    };

    // Run cyclomatic analysis — results are allocated in the worker arena
    const cycl_results = cyclomatic.analyzeFile(
        arena_alloc,
        parse_result,
        ctx.cycl_config,
    ) catch return;

    // Run cognitive analysis and merge into cycl_results
    var cog_results: []const cognitive.CognitiveFunctionResult = &[_]cognitive.CognitiveFunctionResult{};
    cog_results = cognitive.analyzeFunctions(
        arena_alloc,
        root,
        ctx.cog_config,
        source,
    ) catch &[_]cognitive.CognitiveFunctionResult{};

    for (cycl_results, 0..) |*tr, i| {
        if (i < cog_results.len) {
            const cog = cog_results[i];
            tr.cognitive_complexity = cog.complexity;
            tr.cognitive_status = cyclomatic.validateThreshold(
                cog.complexity,
                ctx.cog_config.warning_threshold,
                ctx.cog_config.error_threshold,
            );
        }
    }

    // Run Halstead analysis if enabled
    if (isMetricEnabled(ctx.parsed_metrics, "halstead")) {
        const hal_results = halstead.analyzeFunctions(
            arena_alloc,
            root,
            ctx.hal_config,
            source,
        ) catch null;
        if (hal_results) |hr_slice| {
            for (cycl_results, 0..) |*tr, i| {
                if (i < hr_slice.len) {
                    const hr = hr_slice[i];
                    tr.halstead_volume = hr.metrics.volume;
                    tr.halstead_difficulty = hr.metrics.difficulty;
                    tr.halstead_effort = hr.metrics.effort;
                    tr.halstead_bugs = hr.metrics.bugs;
                    tr.halstead_volume_status = cyclomatic.validateThresholdF64(
                        hr.metrics.volume,
                        ctx.hal_config.volume_warning,
                        ctx.hal_config.volume_error,
                    );
                    tr.halstead_difficulty_status = cyclomatic.validateThresholdF64(
                        hr.metrics.difficulty,
                        ctx.hal_config.difficulty_warning,
                        ctx.hal_config.difficulty_error,
                    );
                    tr.halstead_effort_status = cyclomatic.validateThresholdF64(
                        hr.metrics.effort,
                        ctx.hal_config.effort_warning,
                        ctx.hal_config.effort_error,
                    );
                    tr.halstead_bugs_status = cyclomatic.validateThresholdF64(
                        hr.metrics.bugs,
                        ctx.hal_config.bugs_warning,
                        ctx.hal_config.bugs_error,
                    );
                }
            }
        }
    }

    // Run structural analysis if enabled
    var str_file_result: ?structural.FileStructuralResult = null;
    if (isMetricEnabled(ctx.parsed_metrics, "structural")) {
        const str_results = structural.analyzeFunctions(
            arena_alloc,
            root,
            source,
        ) catch null;
        if (str_results) |sr_slice| {
            for (cycl_results, 0..) |*tr, i| {
                if (i < sr_slice.len) {
                    const sr = sr_slice[i];
                    tr.function_length = sr.function_length;
                    tr.params_count = sr.params_count;
                    tr.nesting_depth = sr.nesting_depth;
                    tr.end_line = sr.end_line;
                    tr.function_length_status = cyclomatic.validateThreshold(
                        sr.function_length,
                        ctx.str_config.function_length_warning,
                        ctx.str_config.function_length_error,
                    );
                    tr.params_count_status = cyclomatic.validateThreshold(
                        sr.params_count,
                        ctx.str_config.params_count_warning,
                        ctx.str_config.params_count_error,
                    );
                    tr.nesting_depth_status = cyclomatic.validateThreshold(
                        sr.nesting_depth,
                        ctx.str_config.nesting_depth_warning,
                        ctx.str_config.nesting_depth_error,
                    );
                }
            }
        }
        str_file_result = structural.analyzeFile(source, root);
    }

    // Compute health scores — func_scores in arena (temp)
    var func_scores = std.ArrayList(f64).empty;
    defer func_scores.deinit(arena_alloc);
    for (cycl_results) |*tr| {
        const breakdown = scoring.computeFunctionScore(tr.*, ctx.effective_weights, ctx.metric_thresholds);
        tr.health_score = breakdown.total;
        func_scores.append(arena_alloc, breakdown.total) catch {};
    }

    const file_score = scoring.computeFileScore(func_scores.items);
    const violations = exit_codes.countViolationsFiltered(cycl_results, ctx.parsed_metrics);

    // === CRITICAL: Lock mutex for ALL shared allocator operations ===
    // ArenaAllocator is NOT thread-safe — every alloc/dupe/append must be serialized.
    ctx.mutex.lock();

    // Deep-copy threshold results to shared allocator so they outlive the worker arena
    const threshold_results = ctx.allocator.alloc(cyclomatic.ThresholdResult, cycl_results.len) catch {
        ctx.mutex.unlock();
        return;
    };
    for (cycl_results, 0..) |tr_src, i| {
        threshold_results[i] = tr_src;
        threshold_results[i].function_name = ctx.allocator.dupe(u8, tr_src.function_name) catch {
            for (threshold_results[0..i]) |*tr| {
                ctx.allocator.free(tr.function_name);
                ctx.allocator.free(tr.function_kind);
            }
            ctx.allocator.free(threshold_results);
            ctx.mutex.unlock();
            return;
        };
        threshold_results[i].function_kind = ctx.allocator.dupe(u8, tr_src.function_kind) catch {
            ctx.allocator.free(threshold_results[i].function_name);
            for (threshold_results[0..i]) |*tr| {
                ctx.allocator.free(tr.function_name);
                ctx.allocator.free(tr.function_kind);
            }
            ctx.allocator.free(threshold_results);
            ctx.mutex.unlock();
            return;
        };
    }

    // Dupe path to shared allocator
    const owned_path = ctx.allocator.dupe(u8, path) catch {
        for (threshold_results) |*tr| {
            ctx.allocator.free(tr.function_name);
            ctx.allocator.free(tr.function_kind);
        }
        ctx.allocator.free(threshold_results);
        ctx.mutex.unlock();
        return;
    };

    const result = FileAnalysisResult{
        .path = owned_path,
        .results = threshold_results,
        .structural = str_file_result,
        .file_score = file_score,
        .function_count = @intCast(threshold_results.len),
        .warning_count = violations.warnings,
        .error_count = violations.errors,
    };

    ctx.results.append(ctx.allocator, result) catch {
        ctx.allocator.free(owned_path);
        for (threshold_results) |*tr| {
            ctx.allocator.free(tr.function_name);
            ctx.allocator.free(tr.function_kind);
        }
        ctx.allocator.free(threshold_results);
        ctx.mutex.unlock();
        return;
    };

    ctx.mutex.unlock();
}

/// Comparator for sorting FileAnalysisResult by path (lexicographic).
fn resultLessThan(_: void, a: FileAnalysisResult, b: FileAnalysisResult) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

/// Analyze files in parallel using std.Thread.Pool.
///
/// thread_count MUST be >= 2 (caller ensures this — use sequential path for thread_count == 1).
/// Returns an owned slice of FileAnalysisResult sorted by path, plus summary counts.
/// The caller owns the returned slice and each element's path and results fields.
pub fn analyzeFilesParallel(
    allocator: Allocator,
    file_paths: []const []const u8,
    thread_count: usize,
    cycl_config: cyclomatic.CyclomaticConfig,
    cog_config: cognitive.CognitiveConfig,
    hal_config: halstead.HalsteadConfig,
    str_config: structural.StructuralConfig,
    effective_weights: scoring.EffectiveWeights,
    metric_thresholds: scoring.MetricThresholds,
    parsed_metrics: ?[]const []const u8,
) !struct { results: []FileAnalysisResult, summary: ParallelSummary } {
    var ctx = WorkerContext{
        .mutex = .{},
        .results = std.ArrayList(FileAnalysisResult).empty,
        .allocator = allocator,
        .cycl_config = cycl_config,
        .cog_config = cog_config,
        .hal_config = hal_config,
        .str_config = str_config,
        .effective_weights = effective_weights,
        .metric_thresholds = metric_thresholds,
        .parsed_metrics = parsed_metrics,
        .successful = std.atomic.Value(u32).init(0),
        .failed = std.atomic.Value(u32).init(0),
        .with_errors = std.atomic.Value(u32).init(0),
    };

    // Create thread pool with page_allocator (thread-safe) for pool internals.
    // The caller's allocator (arena) is NOT thread-safe, so the pool must not use it
    // for Runnable allocations that happen concurrently with worker allocs.
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = std.heap.page_allocator, .n_jobs = @intCast(thread_count) });
    defer pool.deinit();

    // Dispatch one work item per file using WaitGroup barrier
    var wg = std.Thread.WaitGroup{};
    for (file_paths) |path| {
        pool.spawnWg(&wg, analyzeFileWorker, .{ &ctx, path });
    }
    pool.waitAndWork(&wg);

    // Sort results by path for deterministic output
    std.mem.sort(FileAnalysisResult, ctx.results.items, {}, resultLessThan);

    const summary = ParallelSummary{
        .total = @intCast(file_paths.len),
        .successful = ctx.successful.load(.monotonic),
        .failed = ctx.failed.load(.monotonic),
        .with_errors = ctx.with_errors.load(.monotonic),
    };

    return .{
        .results = try ctx.results.toOwnedSlice(allocator),
        .summary = summary,
    };
}

/// Free all memory owned by a FileAnalysisResult slice (returned by analyzeFilesParallel).
pub fn freeResults(allocator: Allocator, results: []FileAnalysisResult) void {
    for (results) |result| {
        allocator.free(result.path);
        for (result.results) |tr| {
            allocator.free(tr.function_name);
            allocator.free(tr.function_kind);
        }
        allocator.free(result.results);
    }
    allocator.free(results);
}

// TESTS

test "analyzeFilesParallel: single file" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
    };

    const cycl_config = @import("../metrics/cyclomatic.zig").CyclomaticConfig.default();
    const cog_config = @import("../metrics/cognitive.zig").CognitiveConfig.default();
    const hal_config = @import("../metrics/halstead.zig").HalsteadConfig.default();
    const str_config = @import("../metrics/structural.zig").StructuralConfig.default();
    const weights = scoring.resolveEffectiveWeights(null, false);
    const metric_thresholds = scoring.MetricThresholds{
        .cyclomatic_warning = 10.0,
        .cyclomatic_error = 20.0,
        .cognitive_warning = 15.0,
        .cognitive_error = 30.0,
        .halstead_warning = 500.0,
        .halstead_error = 1000.0,
        .function_length_warning = 25.0,
        .function_length_error = 50.0,
        .params_count_warning = 3.0,
        .params_count_error = 6.0,
        .nesting_depth_warning = 3.0,
        .nesting_depth_error = 5.0,
    };

    const out = try analyzeFilesParallel(
        allocator,
        &paths,
        2,
        cycl_config,
        cog_config,
        hal_config,
        str_config,
        weights,
        metric_thresholds,
        null,
    );
    defer freeResults(allocator, out.results);

    try std.testing.expectEqual(@as(usize, 1), out.results.len);
    try std.testing.expectEqual(@as(u32, 1), out.summary.total);
    try std.testing.expectEqual(@as(u32, 1), out.summary.successful);
    try std.testing.expectEqual(@as(u32, 0), out.summary.failed);
}

test "analyzeFilesParallel: results sorted by path" {
    const allocator = std.testing.allocator;

    // Provide files in reverse alphabetical order — results must come back sorted
    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
        "tests/fixtures/javascript/callback_patterns.js",
    };

    const cycl_config = @import("../metrics/cyclomatic.zig").CyclomaticConfig.default();
    const cog_config = @import("../metrics/cognitive.zig").CognitiveConfig.default();
    const hal_config = @import("../metrics/halstead.zig").HalsteadConfig.default();
    const str_config = @import("../metrics/structural.zig").StructuralConfig.default();
    const weights = scoring.resolveEffectiveWeights(null, false);
    const metric_thresholds = scoring.MetricThresholds{
        .cyclomatic_warning = 10.0,
        .cyclomatic_error = 20.0,
        .cognitive_warning = 15.0,
        .cognitive_error = 30.0,
        .halstead_warning = 500.0,
        .halstead_error = 1000.0,
        .function_length_warning = 25.0,
        .function_length_error = 50.0,
        .params_count_warning = 3.0,
        .params_count_error = 6.0,
        .nesting_depth_warning = 3.0,
        .nesting_depth_error = 5.0,
    };

    const out = try analyzeFilesParallel(
        allocator,
        &paths,
        2,
        cycl_config,
        cog_config,
        hal_config,
        str_config,
        weights,
        metric_thresholds,
        null,
    );
    defer freeResults(allocator, out.results);

    try std.testing.expectEqual(@as(usize, 2), out.results.len);
    // Results should be sorted lexicographically by path
    // "tests/fixtures/javascript/..." < "tests/fixtures/typescript/..."
    try std.testing.expect(std.mem.lessThan(u8, out.results[0].path, out.results[1].path));
}
