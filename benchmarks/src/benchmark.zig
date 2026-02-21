/// ComplexityGuard subsystem benchmark module.
/// Profiles each pipeline stage independently: file discovery, file I/O, parsing,
/// cyclomatic analysis, cognitive analysis, halstead analysis, structural analysis,
/// health score computation, and JSON serialization.
///
/// Usage: complexity-bench [options] <project-directory>
///   --runs N         Number of iterations per subsystem (default: 5)
///   --json <path>    Write JSON results to file (optional)
const std = @import("std");

// Access the ComplexityGuard pipeline via the "cg" module (src/lib.zig).
// This single module contains all pipeline namespaces with their shared dependencies
// (tree_sitter, types, filter, etc.) resolved correctly within one module boundary.
const cg = @import("cg");
const walker = cg.walker;
const parse = cg.parse;
const cyclomatic = cg.cyclomatic;
const cognitive = cg.cognitive;
const halstead = cg.halstead;
const structural = cg.structural;
const scoring = cg.scoring;

/// Timing statistics for a single subsystem across N runs (in nanoseconds).
const SubsystemStats = struct {
    name: []const u8,
    mean_ns: f64,
    stddev_ns: f64,
    min_ns: u64,
    max_ns: u64,

    fn meanMs(self: SubsystemStats) f64 {
        return self.mean_ns / 1_000_000.0;
    }

    fn stddevMs(self: SubsystemStats) f64 {
        return self.stddev_ns / 1_000_000.0;
    }

    fn minMs(self: SubsystemStats) f64 {
        return @as(f64, @floatFromInt(self.min_ns)) / 1_000_000.0;
    }

    fn maxMs(self: SubsystemStats) f64 {
        return @as(f64, @floatFromInt(self.max_ns)) / 1_000_000.0;
    }
};

/// Compute statistics over a slice of nanosecond timings.
fn computeStats(name: []const u8, timings: []const u64) SubsystemStats {
    var min: u64 = timings[0];
    var max: u64 = timings[0];
    var sum: u64 = 0;
    for (timings) |t| {
        if (t < min) min = t;
        if (t > max) max = t;
        sum += t;
    }
    const mean: f64 = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(timings.len));

    var variance: f64 = 0.0;
    for (timings) |t| {
        const diff = @as(f64, @floatFromInt(t)) - mean;
        variance += diff * diff;
    }
    variance /= @as(f64, @floatFromInt(timings.len));

    return SubsystemStats{
        .name = name,
        .mean_ns = mean,
        .stddev_ns = @sqrt(variance),
        .min_ns = min,
        .max_ns = max,
    };
}

/// Parsed command-line arguments.
const BenchArgs = struct {
    project_path: []const u8,
    runs: u32,
    json_path: ?[]const u8,
};

fn printUsage(stderr: anytype) !void {
    try stderr.writeAll(
        \\Usage: complexity-bench [options] <project-directory>
        \\
        \\Options:
        \\  --runs N         Number of iterations per subsystem (default: 5)
        \\  --json <path>    Write JSON results to file (optional)
        \\  --help           Show this help
        \\
        \\Example:
        \\  complexity-bench benchmarks/projects/zod
        \\  complexity-bench --runs 10 --json results.json benchmarks/projects/nestjs
        \\
    );
}

/// Write to stderr directly (unbuffered) and exit with the given code.
/// Used for argument parsing errors where we can't defer flush.
fn dieWithMsg(comptime fmt: []const u8, args: anytype, code: u8) noreturn {
    const stderr = std.fs.File.stderr();
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch "error: message too long\n";
    _ = stderr.write(msg) catch {};
    std.process.exit(code);
}

fn parseArgs(allocator: std.mem.Allocator) !BenchArgs {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var runs: u32 = 5;
    var json_path: ?[]const u8 = null;
    var project_path: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const stderr = std.fs.File.stderr();
            var buf: [1024]u8 = undefined;
            var sw = stderr.writer(&buf);
            printUsage(&sw.interface) catch {};
            sw.interface.flush() catch {};
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--runs")) {
            i += 1;
            if (i >= args.len) {
                dieWithMsg("error: --runs requires a value\n", .{}, 1);
            }
            runs = std.fmt.parseInt(u32, args[i], 10) catch {
                dieWithMsg("error: --runs value must be a positive integer, got: {s}\n", .{args[i]}, 1);
            };
            if (runs == 0) runs = 1;
        } else if (std.mem.eql(u8, arg, "--json")) {
            i += 1;
            if (i >= args.len) {
                dieWithMsg("error: --json requires a path\n", .{}, 1);
            }
            json_path = try allocator.dupe(u8, args[i]);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            dieWithMsg("error: unknown option: {s}\n", .{arg}, 1);
        } else {
            // Positional argument: project directory
            if (project_path != null) {
                dieWithMsg("error: unexpected argument: {s}\n", .{arg}, 1);
            }
            project_path = try allocator.dupe(u8, arg);
        }
    }

    if (project_path == null) {
        const stderr = std.fs.File.stderr();
        var buf: [1024]u8 = undefined;
        var sw = stderr.writer(&buf);
        printUsage(&sw.interface) catch {};
        sw.interface.writeAll("\nerror: missing required argument: <project-directory>\n") catch {};
        sw.interface.flush() catch {};
        std.process.exit(1);
    }

    return BenchArgs{
        .project_path = project_path.?,
        .runs = runs,
        .json_path = json_path,
    };
}

/// Print a formatted timing table to stdout.
fn printTable(stdout: anytype, stats: []const SubsystemStats) !void {
    const header_line = "─────────────────────────────────────────────────────────────────────";
    try stdout.print("  {s:<20} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
        "Subsystem",
        "Mean (ms)",
        "Stddev (ms)",
        "Min (ms)",
        "Max (ms)",
    });
    try stdout.print("  {s}\n", .{header_line});

    var total_mean: f64 = 0.0;
    var total_stddev_sq: f64 = 0.0;

    for (stats) |s| {
        try stdout.print("  {s:<20} {d:>12.3} {d:>12.3} {d:>12.3} {d:>12.3}\n", .{
            s.name,
            s.meanMs(),
            s.stddevMs(),
            s.minMs(),
            s.maxMs(),
        });
        total_mean += s.mean_ns;
        total_stddev_sq += s.stddev_ns * s.stddev_ns;
    }

    try stdout.print("  {s}\n", .{header_line});
    try stdout.print("  {s:<20} {d:>12.3} {d:>12.3}\n", .{
        "Total pipeline",
        total_mean / 1_000_000.0,
        @sqrt(total_stddev_sq) / 1_000_000.0,
    });
}

/// Find the hotspot subsystem (largest mean time).
fn findHotspot(stats: []const SubsystemStats) struct { name: []const u8, pct: f64 } {
    var total: f64 = 0.0;
    var max_mean: f64 = 0.0;
    var hotspot_name: []const u8 = stats[0].name;

    for (stats) |s| {
        total += s.mean_ns;
        if (s.mean_ns > max_mean) {
            max_mean = s.mean_ns;
            hotspot_name = s.name;
        }
    }

    const pct = if (total > 0.0) (max_mean / total) * 100.0 else 0.0;
    return .{ .name = hotspot_name, .pct = pct };
}

/// Write JSON benchmark results to a file.
fn writeJsonResults(
    allocator: std.mem.Allocator,
    json_path: []const u8,
    project_path: []const u8,
    file_count: usize,
    function_count: usize,
    total_bytes: usize,
    runs: u32,
    stats: []const SubsystemStats,
) !void {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    const hotspot = findHotspot(stats);
    var total_mean: f64 = 0.0;
    for (stats) |s| total_mean += s.mean_ns;

    try writer.writeAll("{\n");
    try writer.print("  \"project\": \"{s}\",\n", .{project_path});
    try writer.print("  \"files\": {d},\n", .{file_count});
    try writer.print("  \"functions\": {d},\n", .{function_count});
    try writer.print("  \"bytes\": {d},\n", .{total_bytes});
    try writer.print("  \"runs\": {d},\n", .{runs});
    try writer.writeAll("  \"subsystems\": {\n");

    for (stats, 0..) |s, i| {
        const comma = if (i + 1 < stats.len) "," else "";
        try writer.print(
            "    \"{s}\": {{ \"mean_ms\": {d:.3}, \"stddev_ms\": {d:.3}, \"min_ms\": {d:.3}, \"max_ms\": {d:.3} }}{s}\n",
            .{ s.name, s.meanMs(), s.stddevMs(), s.minMs(), s.maxMs(), comma },
        );
    }

    try writer.writeAll("  },\n");
    try writer.print("  \"total_pipeline_mean_ms\": {d:.3},\n", .{total_mean / 1_000_000.0});
    try writer.print("  \"hotspot\": \"{s}\",\n", .{hotspot.name});
    try writer.print("  \"hotspot_pct\": {d:.1}\n", .{hotspot.pct});
    try writer.writeAll("}\n");

    const file = try std.fs.cwd().createFile(json_path, .{});
    defer file.close();
    try file.writeAll(buf.items);
}

pub fn main() !void {
    // Arena allocator for entire benchmark lifecycle
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Buffered stdout for output
    var stdout_buf: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    const bench_args = try parseArgs(allocator);

    // Verify the project directory exists
    std.fs.cwd().access(bench_args.project_path, .{}) catch {
        try stderr.print(
            "error: project directory not found: {s}\n\nRun: benchmarks/scripts/setup.sh --suite quick\n",
            .{bench_args.project_path},
        );
        stderr.flush() catch {};
        std.process.exit(1);
    };

    const runs = bench_args.runs;

    try stdout.print("\nBenchmark: {s}\n", .{bench_args.project_path});
    try stdout.print("Runs: {d}\n\n", .{runs});
    try stdout.writeAll("Warming up subsystems...\n\n");
    stdout.flush() catch {};

    // Allocate timing arrays (runs iterations per subsystem)
    var t_discovery = try allocator.alloc(u64, runs);
    var t_file_read = try allocator.alloc(u64, runs);
    var t_parsing = try allocator.alloc(u64, runs);
    var t_cyclomatic = try allocator.alloc(u64, runs);
    var t_cognitive = try allocator.alloc(u64, runs);
    var t_halstead = try allocator.alloc(u64, runs);
    var t_structural = try allocator.alloc(u64, runs);
    var t_scoring = try allocator.alloc(u64, runs);
    var t_serialization = try allocator.alloc(u64, runs);

    // Counters gathered during measurement (use last run's values for reporting)
    var file_count: usize = 0;
    var function_count: usize = 0;
    var total_bytes: usize = 0;

    const filter_cfg = walker.FilterConfig{};
    const paths = [_][]const u8{bench_args.project_path};

    // Default configs (matches main.zig pipeline)
    const cycl_cfg = cyclomatic.CyclomaticConfig.default();
    const cog_cfg = cognitive.CognitiveConfig.default();
    const hal_cfg = halstead.HalsteadConfig.default();
    const metric_thresholds = scoring.MetricThresholds{
        .cyclomatic_warning = @as(f64, @floatFromInt(cycl_cfg.warning_threshold)),
        .cyclomatic_error = @as(f64, @floatFromInt(cycl_cfg.error_threshold)),
        .cognitive_warning = @as(f64, @floatFromInt(cog_cfg.warning_threshold)),
        .cognitive_error = @as(f64, @floatFromInt(cog_cfg.error_threshold)),
        .halstead_warning = hal_cfg.volume_warning,
        .halstead_error = hal_cfg.volume_error,
        .function_length_warning = 25.0,
        .function_length_error = 50.0,
        .params_count_warning = 3.0,
        .params_count_error = 6.0,
        .nesting_depth_warning = 3.0,
        .nesting_depth_error = 5.0,
    };
    const effective_weights = scoring.resolveEffectiveWeights(null);

    var timer = try std.time.Timer.start();

    for (0..runs) |run| {
        // ── 1. File Discovery ─────────────────────────────────────────────────
        timer.reset();
        var discovery = try walker.discoverFiles(allocator, &paths, filter_cfg);
        t_discovery[run] = timer.read();
        file_count = discovery.files.len;
        // Keep files for next stage (don't deinit yet)

        // ── 2. File I/O (Read) ────────────────────────────────────────────────
        timer.reset();
        var sources = try allocator.alloc([]u8, discovery.files.len);
        var byte_count: usize = 0;
        for (discovery.files, 0..) |path, fi| {
            const src = try std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024);
            sources[fi] = src;
            byte_count += src.len;
        }
        t_file_read[run] = timer.read();
        total_bytes = byte_count;

        // ── 3. Parsing ────────────────────────────────────────────────────────
        timer.reset();
        var parse_summary = try parse.parseFiles(allocator, discovery.files);
        t_parsing[run] = timer.read();

        // Free file-read sources (parse.parseFiles reads files again internally)
        for (sources) |src| allocator.free(src);
        allocator.free(sources);

        // ── 4. Cyclomatic Analysis ────────────────────────────────────────────
        var all_cycl_results = std.ArrayList([]cyclomatic.ThresholdResult).empty;

        timer.reset();
        for (parse_summary.results) |pr| {
            const results = try cyclomatic.analyzeFile(allocator, pr, cycl_cfg);
            try all_cycl_results.append(allocator, results);
        }
        t_cyclomatic[run] = timer.read();

        // ── 5. Cognitive Analysis ─────────────────────────────────────────────
        timer.reset();
        for (parse_summary.results) |pr| {
            if (pr.tree) |tree| {
                const root = tree.rootNode();
                const cog_results = try cognitive.analyzeFunctions(allocator, root, cog_cfg, pr.source);
                _ = cog_results;
            }
        }
        t_cognitive[run] = timer.read();

        // ── 6. Halstead Analysis ──────────────────────────────────────────────
        timer.reset();
        for (parse_summary.results) |pr| {
            if (pr.tree) |tree| {
                const root = tree.rootNode();
                const hal_results = try halstead.analyzeFunctions(allocator, root, hal_cfg, pr.source);
                _ = hal_results;
            }
        }
        t_halstead[run] = timer.read();

        // ── 7. Structural Analysis ────────────────────────────────────────────
        timer.reset();
        for (parse_summary.results) |pr| {
            if (pr.tree) |tree| {
                const root = tree.rootNode();
                const str_results = try structural.analyzeFunctions(allocator, root, pr.source);
                _ = str_results;
                const file_str = structural.analyzeFile(pr.source, root);
                _ = file_str;
            }
        }
        t_structural[run] = timer.read();

        // ── 8. Health Score Computation ───────────────────────────────────────
        var total_functions: usize = 0;
        timer.reset();
        for (all_cycl_results.items) |file_cycl| {
            for (file_cycl) |*tr| {
                const breakdown = scoring.computeFunctionScore(tr.*, effective_weights, metric_thresholds);
                _ = breakdown;
                total_functions += 1;
            }
        }
        t_scoring[run] = timer.read();
        function_count = total_functions;

        // ── 9. JSON Serialization ─────────────────────────────────────────────
        timer.reset();
        // Serialize the full analysis result to JSON (mimics real output pipeline)
        var json_buf = std.ArrayList(u8).empty;
        const jw = json_buf.writer(allocator);
        try jw.writeAll("{\"version\":\"1.0.0\",\"files\":[");
        for (parse_summary.results, all_cycl_results.items) |pr, file_cycl| {
            try jw.print("{{\"path\":\"{s}\",\"functions\":{d}}},", .{ pr.path, file_cycl.len });
        }
        try jw.writeAll("]}");
        _ = json_buf.items;
        t_serialization[run] = timer.read();

        // Clean up this run's data
        for (all_cycl_results.items) |r| allocator.free(r);
        all_cycl_results.deinit(allocator);
        parse_summary.deinit(allocator);
        discovery.deinit(allocator);
    }

    // Compute statistics for each subsystem
    const stats = [_]SubsystemStats{
        computeStats("file_discovery", t_discovery),
        computeStats("file_read", t_file_read),
        computeStats("parsing", t_parsing),
        computeStats("cyclomatic", t_cyclomatic),
        computeStats("cognitive", t_cognitive),
        computeStats("halstead", t_halstead),
        computeStats("structural", t_structural),
        computeStats("scoring", t_scoring),
        computeStats("json_output", t_serialization),
    };

    // Print summary header
    try stdout.print("Benchmark: {s}\n", .{bench_args.project_path});
    try stdout.print("Files: {d}  Functions: {d}  Bytes: {d}\n", .{
        file_count,
        function_count,
        total_bytes,
    });
    try stdout.print("Runs: {d}\n\n", .{runs});

    // Print timing table
    try printTable(stdout, &stats);

    // Print hotspot
    const hotspot = findHotspot(&stats);
    try stdout.print("\n  Hotspot: {s} ({d:.1}% of total)\n\n", .{ hotspot.name, hotspot.pct });

    // Write JSON if requested
    if (bench_args.json_path) |jp| {
        try writeJsonResults(
            allocator,
            jp,
            bench_args.project_path,
            file_count,
            function_count,
            total_bytes,
            runs,
            &stats,
        );
        try stdout.print("  JSON results written to: {s}\n\n", .{jp});
    }
}
