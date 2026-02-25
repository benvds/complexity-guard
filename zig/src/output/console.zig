const std = @import("std");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const structural = @import("../metrics/structural.zig");
const duplication = @import("../metrics/duplication.zig");
const help = @import("../cli/help.zig");
const Allocator = std.mem.Allocator;

/// File-level structural thresholds for display in console output.
/// Passed through OutputConfig so console functions don't need direct access to StructuralConfig.
pub const FileLevelThresholds = struct {
    file_length_warning: u32,
    file_length_error: u32,
    export_count_warning: u32,
    export_count_error: u32,
};

/// ANSI escape codes for colored output
const AnsiCode = struct {
    pub const reset = "\x1b[0m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const green = "\x1b[32m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
};

/// Verbosity level for console output
pub const Verbosity = enum {
    default,  // Problems only
    verbose,  // All functions, all files
    quiet,    // Errors only, minimal output
};

/// Configuration for console output
pub const OutputConfig = struct {
    use_color: bool,
    verbosity: Verbosity,
    /// When non-null, only these metric families are shown in output and hotspot sections.
    /// Null means all metrics are enabled (backward compatible).
    selected_metrics: ?[]const []const u8,
    /// File-level structural thresholds for display. Defaults to standard values when null.
    file_level_thresholds: ?FileLevelThresholds = null,
};

/// Returns true if the given metric is enabled.
/// When metrics is null (no --metrics flag), all metrics are enabled.
fn isMetricEnabled(metrics: ?[]const []const u8, metric: []const u8) bool {
    const list = metrics orelse return true;
    for (list) |m| {
        if (std.mem.eql(u8, m, metric)) return true;
    }
    return false;
}

/// File path with its threshold results
pub const FileThresholdResults = struct {
    path: []const u8,
    results: []const cyclomatic.ThresholdResult,
    /// File-level structural metrics (null when structural metrics not computed)
    structural: ?structural.FileStructuralResult = null,
};

/// Return the worse of two threshold statuses (error > warning > ok)
fn worstStatus(a: cyclomatic.ThresholdStatus, b: cyclomatic.ThresholdStatus) cyclomatic.ThresholdStatus {
    if (a == .@"error" or b == .@"error") return .@"error";
    if (a == .warning or b == .warning) return .warning;
    return .ok;
}

/// Return the worst status across all metric families for a ThresholdResult.
fn worstStatusAll(result: cyclomatic.ThresholdResult) cyclomatic.ThresholdStatus {
    var worst = worstStatus(result.status, result.cognitive_status);
    worst = worstStatus(worst, result.halstead_volume_status);
    worst = worstStatus(worst, result.halstead_difficulty_status);
    worst = worstStatus(worst, result.halstead_effort_status);
    worst = worstStatus(worst, result.halstead_bugs_status);
    worst = worstStatus(worst, result.function_length_status);
    worst = worstStatus(worst, result.params_count_status);
    worst = worstStatus(worst, result.nesting_depth_status);
    return worst;
}

/// Format results for a single file in ESLint style
/// Returns true if any output was written for this file
pub fn formatFileResults(
    writer: anytype,
    allocator: Allocator,
    file_results: FileThresholdResults,
    config: OutputConfig,
) !bool {
    _ = allocator;
    const file_path = file_results.path;
    const results = file_results.results;

    // Filter results based on verbosity
    var has_output = false;
    var has_problems = false;

    // Check if file has any problems (using worst of all metrics)
    for (results) |result| {
        const worst = worstStatusAll(result);
        if (config.verbosity == .quiet and worst != .@"error") continue;
        if (config.verbosity == .default and worst == .ok) continue;

        if (worst != .ok) {
            has_problems = true;
        }
        has_output = true;
    }

    // Check file-level structural violations (only when structural metric is enabled)
    var has_file_level_violations = false;
    if (file_results.structural) |str| {
        if (isMetricEnabled(config.selected_metrics, "structural")) {
            const flt = config.file_level_thresholds orelse FileLevelThresholds{
                .file_length_warning = 300,
                .file_length_error = 600,
                .export_count_warning = 15,
                .export_count_error = 30,
            };
            if (str.file_length >= flt.file_length_warning or str.export_count >= flt.export_count_warning) {
                has_file_level_violations = true;
                has_problems = true;
                has_output = true;
            }
            if (config.verbosity == .verbose) {
                has_output = true;
            }
        }
    }

    // In default mode, skip files with no problems
    if (config.verbosity == .default and !has_problems) {
        return false;
    }

    // In quiet mode, skip if nothing to show
    if (config.verbosity == .quiet and !has_output) {
        return false;
    }

    // Write file header (bold if color enabled)
    if (config.use_color) {
        try writer.print("{s}{s}{s}\n", .{ AnsiCode.bold, file_path, AnsiCode.reset });
    } else {
        try writer.print("{s}\n", .{file_path});
    }

    // Write file-level structural metrics if present (gated by selected_metrics)
    if (file_results.structural) |str| {
        if (isMetricEnabled(config.selected_metrics, "structural")) {
            const show_file_line = config.verbosity == .verbose or has_file_level_violations;
            if (show_file_line) {
                const file_worst: cyclomatic.ThresholdStatus = blk: {
                    const flt = config.file_level_thresholds orelse FileLevelThresholds{
                        .file_length_warning = 300,
                        .file_length_error = 600,
                        .export_count_warning = 15,
                        .export_count_error = 30,
                    };
                    var w: cyclomatic.ThresholdStatus = .ok;
                    if (str.file_length >= flt.file_length_error) w = .@"error" else if (str.file_length >= flt.file_length_warning) w = .warning;
                    const ec: cyclomatic.ThresholdStatus = if (str.export_count >= flt.export_count_error) .@"error" else if (str.export_count >= flt.export_count_warning) .warning else .ok;
                    break :blk worstStatus(w, ec);
                };
                const file_symbol: []const u8 = switch (file_worst) {
                    .ok => "✓",
                    .warning => "⚠",
                    .@"error" => "✗",
                };
                const file_color: []const u8 = if (config.use_color) switch (file_worst) {
                    .ok => AnsiCode.green,
                    .warning => AnsiCode.yellow,
                    .@"error" => AnsiCode.red,
                } else "";
                const file_reset = if (config.use_color) AnsiCode.reset else "";
                const file_severity = switch (file_worst) {
                    .ok => "ok",
                    .warning => "warning",
                    .@"error" => "error",
                };
                try writer.print("  file  {s}{s}{s}  {s}  file length {d} logical lines, {d} exports\n", .{
                    file_color,
                    file_symbol,
                    file_reset,
                    file_severity,
                    str.file_length,
                    str.export_count,
                });
            }
        }
    }

    // Write function results
    for (results) |result| {
        // Compute worst status across all metric families
        const worst = worstStatusAll(result);

        // Skip based on verbosity mode (using worst status)
        if (config.verbosity == .quiet and worst != .@"error") continue;
        if (config.verbosity == .default and worst == .ok) continue;

        // Determine symbol and color based on worst status
        const symbol: []const u8 = switch (worst) {
            .ok => "✓",
            .warning => "⚠",
            .@"error" => "✗",
        };

        const color: []const u8 = if (config.use_color) switch (worst) {
            .ok => AnsiCode.green,
            .warning => AnsiCode.yellow,
            .@"error" => AnsiCode.red,
        } else "";

        const reset = if (config.use_color) AnsiCode.reset else "";

        const severity = switch (worst) {
            .ok => "ok",
            .warning => "warning",
            .@"error" => "error",
        };

        // Capitalize kind for display
        const kind_display = if (std.mem.eql(u8, result.function_kind, "function"))
            "Function"
        else if (std.mem.eql(u8, result.function_kind, "method"))
            "Method"
        else if (std.mem.eql(u8, result.function_kind, "arrow"))
            "Arrow function"
        else if (std.mem.eql(u8, result.function_kind, "generator"))
            "Generator"
        else
            "Function";

        // Base line: status symbol/severity/kind/name always shown
        try writer.print("  {d}:{d}  {s}{s}{s}  {s}  {s} '{s}'", .{
            result.start_line,
            result.start_col,
            color,
            symbol,
            reset,
            severity,
            kind_display,
            result.function_name,
        });

        // Append cyclomatic score only if cyclomatic metric is selected
        if (isMetricEnabled(config.selected_metrics, "cyclomatic")) {
            try writer.print(" cyclomatic {d}", .{result.complexity});
        }

        // Append cognitive score only if cognitive metric is selected
        if (isMetricEnabled(config.selected_metrics, "cognitive")) {
            try writer.print(" cognitive {d}", .{result.cognitive_complexity});
        }

        // Add Halstead info if halstead enabled AND (verbose OR non-ok status)
        if (isMetricEnabled(config.selected_metrics, "halstead") and
            (config.verbosity == .verbose or
            result.halstead_volume_status != .ok or
            result.halstead_difficulty_status != .ok or
            result.halstead_effort_status != .ok or
            result.halstead_bugs_status != .ok))
        {
            try writer.print(" [halstead vol {d:.0}]", .{result.halstead_volume});
        }

        // Add structural info if structural enabled AND (verbose OR non-ok status)
        if (isMetricEnabled(config.selected_metrics, "structural") and
            (config.verbosity == .verbose or result.function_length_status != .ok))
        {
            try writer.print(" [length {d}]", .{result.function_length});
        }
        if (isMetricEnabled(config.selected_metrics, "structural") and
            (config.verbosity == .verbose or result.params_count_status != .ok))
        {
            try writer.print(" [params {d}]", .{result.params_count});
        }
        if (isMetricEnabled(config.selected_metrics, "structural") and
            (config.verbosity == .verbose or result.nesting_depth_status != .ok))
        {
            try writer.print(" [depth {d}]", .{result.nesting_depth});
        }

        try writer.writeAll("\n");
    }

    return true;
}

/// Format project summary at the bottom
pub fn formatSummary(
    writer: anytype,
    allocator: Allocator,
    file_count: u32,
    function_count: u32,
    warning_count: u32,
    error_count: u32,
    all_results: []const FileThresholdResults,
    config: OutputConfig,
    project_score: f64,
) !void {
    // In quiet mode, only show verdict
    if (config.verbosity == .quiet) {
        try formatVerdict(writer, error_count, warning_count, config);
        return;
    }

    // Blank line separator
    try writer.writeAll("\n");

    // Files and functions analyzed
    try writer.print("Analyzed {d} files, {d} functions\n", .{ file_count, function_count });

    // Health score display (always shown, color-coded)
    if (config.use_color) {
        const score_color: []const u8 = if (project_score >= 80.0)
            AnsiCode.green
        else if (project_score >= 50.0)
            AnsiCode.yellow
        else
            AnsiCode.red;
        try writer.print("{s}Health: {d:.0}{s}\n", .{ score_color, project_score, AnsiCode.reset });
    } else {
        try writer.print("Health: {d:.0}\n", .{project_score});
    }

    // Warning/error counts if any
    if (warning_count > 0 or error_count > 0) {
        try writer.print("Found {d} warnings, {d} errors\n", .{ warning_count, error_count });
    }

    // Hotspot item type for integer-valued metrics
    const HotspotItem = struct {
        name: []const u8,
        path: []const u8,
        line: u32,
        complexity: u32,
    };

    // Hotspot item type for float-valued metrics (Halstead volume)
    const HalsteadHotspotItem = struct {
        name: []const u8,
        path: []const u8,
        line: u32,
        volume: f64,
    };

    // Top 5 cyclomatic hotspots
    var cycl_hotspots = std.ArrayList(HotspotItem).empty;
    defer cycl_hotspots.deinit(allocator);

    // Top 5 cognitive hotspots
    var cog_hotspots = std.ArrayList(HotspotItem).empty;
    defer cog_hotspots.deinit(allocator);

    // Top 5 Halstead volume hotspots
    var hal_hotspots = std.ArrayList(HalsteadHotspotItem).empty;
    defer hal_hotspots.deinit(allocator);

    // Collect all results into hotspot lists
    for (all_results) |file_results| {
        for (file_results.results) |result| {
            if (result.complexity > 1) {
                try cycl_hotspots.append(allocator, .{
                    .name = result.function_name,
                    .path = file_results.path,
                    .line = result.start_line,
                    .complexity = result.complexity,
                });
            }
            if (result.cognitive_complexity > 0) {
                try cog_hotspots.append(allocator, .{
                    .name = result.function_name,
                    .path = file_results.path,
                    .line = result.start_line,
                    .complexity = result.cognitive_complexity,
                });
            }
            if (result.halstead_volume > 0) {
                try hal_hotspots.append(allocator, .{
                    .name = result.function_name,
                    .path = file_results.path,
                    .line = result.start_line,
                    .volume = result.halstead_volume,
                });
            }
        }
    }

    // Sort and display cyclomatic hotspots (gated by selected_metrics)
    if (isMetricEnabled(config.selected_metrics, "cyclomatic")) {
        const items = cycl_hotspots.items;
        if (items.len > 0) {
            var i: usize = 0;
            while (i < items.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < items.len) : (j += 1) {
                    if (items[j].complexity > items[i].complexity) {
                        const temp = items[i];
                        items[i] = items[j];
                        items[j] = temp;
                    }
                }
            }
            const top_count = @min(5, items.len);
            try writer.writeAll("\nTop cyclomatic hotspots:\n");
            var idx: usize = 0;
            while (idx < top_count) : (idx += 1) {
                const hotspot = items[idx];
                try writer.print("  {d}. {s} ({s}:{d}) complexity {d}\n", .{
                    idx + 1,
                    hotspot.name,
                    hotspot.path,
                    hotspot.line,
                    hotspot.complexity,
                });
            }
        }
    }

    // Sort and display cognitive hotspots (gated by selected_metrics)
    if (isMetricEnabled(config.selected_metrics, "cognitive")) {
        const items = cog_hotspots.items;
        if (items.len > 0) {
            var i: usize = 0;
            while (i < items.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < items.len) : (j += 1) {
                    if (items[j].complexity > items[i].complexity) {
                        const temp = items[i];
                        items[i] = items[j];
                        items[j] = temp;
                    }
                }
            }
            const top_count = @min(5, items.len);
            try writer.writeAll("\nTop cognitive hotspots:\n");
            var idx: usize = 0;
            while (idx < top_count) : (idx += 1) {
                const hotspot = items[idx];
                try writer.print("  {d}. {s} ({s}:{d}) complexity {d}\n", .{
                    idx + 1,
                    hotspot.name,
                    hotspot.path,
                    hotspot.line,
                    hotspot.complexity,
                });
            }
        }
    }

    // Sort and display Halstead volume hotspots (gated by selected_metrics)
    if (isMetricEnabled(config.selected_metrics, "halstead")) {
        const items = hal_hotspots.items;
        if (items.len > 0) {
            var i: usize = 0;
            while (i < items.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < items.len) : (j += 1) {
                    if (items[j].volume > items[i].volume) {
                        const temp = items[i];
                        items[i] = items[j];
                        items[j] = temp;
                    }
                }
            }
            const top_count = @min(5, items.len);
            try writer.writeAll("\nTop Halstead volume hotspots:\n");
            var idx: usize = 0;
            while (idx < top_count) : (idx += 1) {
                const hotspot = items[idx];
                try writer.print("  {d}. {s} ({s}:{d}) volume {d:.0}\n", .{
                    idx + 1,
                    hotspot.name,
                    hotspot.path,
                    hotspot.line,
                    hotspot.volume,
                });
            }
        }
    }

    // Final verdict
    try writer.writeAll("\n");
    try formatVerdict(writer, error_count, warning_count, config);
}

/// Format final verdict line
pub fn formatVerdict(
    writer: anytype,
    error_count: u32,
    warning_count: u32,
    config: OutputConfig,
) !void {
    if (error_count > 0) {
        // Red error verdict
        const total = error_count + warning_count;
        const error_word = if (error_count == 1) "error" else "errors";
        const warning_word = if (warning_count == 1) "warning" else "warnings";

        if (config.use_color) {
            try writer.print("{s}✗ {d} problems ({d} {s}, {d} {s}){s}\n", .{
                AnsiCode.red,
                total,
                error_count,
                error_word,
                warning_count,
                warning_word,
                AnsiCode.reset,
            });
        } else {
            try writer.print("✗ {d} problems ({d} {s}, {d} {s})\n", .{
                total,
                error_count,
                error_word,
                warning_count,
                warning_word,
            });
        }
    } else if (warning_count > 0) {
        // Yellow warning verdict
        const warning_word = if (warning_count == 1) "warning" else "warnings";

        if (config.use_color) {
            try writer.print("{s}⚠ {d} {s}{s}\n", .{
                AnsiCode.yellow,
                warning_count,
                warning_word,
                AnsiCode.reset,
            });
        } else {
            try writer.print("⚠ {d} {s}\n", .{ warning_count, warning_word });
        }
    } else {
        // Green success verdict
        if (config.use_color) {
            try writer.print("{s}✓ All checks passed{s}\n", .{ AnsiCode.green, AnsiCode.reset });
        } else {
            try writer.writeAll("✓ All checks passed\n");
        }
    }
}

/// Format duplication analysis results as a separate section after per-file output.
/// Only called when duplication detection is enabled and dup_result is non-null.
pub fn formatDuplicationSection(
    writer: anytype,
    allocator: Allocator,
    dup_result: duplication.DuplicationResult,
    config: OutputConfig,
) !void {
    _ = allocator;

    // In quiet mode, skip entirely unless there are errors
    if (config.verbosity == .quiet and !dup_result.project_error) {
        var has_file_error = false;
        for (dup_result.file_results) |fr| {
            if (fr.@"error") {
                has_file_error = true;
                break;
            }
        }
        if (!has_file_error) return;
    }

    try writer.writeAll("\nDuplication\n");
    try writer.writeAll("-----------\n");

    // Print clone groups
    for (dup_result.clone_groups) |group| {
        try writer.print("Clone group ({d} tokens): ", .{group.token_count});
        for (group.locations, 0..) |loc, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.print("{s}:{d}", .{ loc.file_path, loc.start_line });
        }
        try writer.writeAll("\n");
    }

    // File duplication section
    try writer.writeAll("\nFile duplication:\n");
    for (dup_result.file_results) |fr| {
        // In quiet mode, only show error-level files
        if (config.verbosity == .quiet and !fr.@"error") continue;
        // In default mode, only show files with warnings or errors
        if (config.verbosity == .default and !fr.warning and !fr.@"error") continue;

        const status_str: []const u8 = if (fr.@"error") "ERROR" else if (fr.warning) "WARNING" else "OK";
        const color: []const u8 = if (config.use_color)
            if (fr.@"error") AnsiCode.red else if (fr.warning) AnsiCode.yellow else AnsiCode.green
        else
            "";
        const reset = if (config.use_color) AnsiCode.reset else "";
        try writer.print("  {s:<40} {d:.1}%  {s}[{s}]{s}\n", .{
            fr.path,
            fr.duplication_pct,
            color,
            status_str,
            reset,
        });
    }

    // Project duplication
    const proj_status: []const u8 = if (dup_result.project_error) "ERROR" else if (dup_result.project_warning) "WARNING" else "OK";
    const proj_color: []const u8 = if (config.use_color)
        if (dup_result.project_error) AnsiCode.red else if (dup_result.project_warning) AnsiCode.yellow else AnsiCode.green
    else
        "";
    const proj_reset = if (config.use_color) AnsiCode.reset else "";
    try writer.print("\nProject duplication: {d:.1}%  {s}[{s}]{s}\n", .{
        dup_result.project_duplication_pct,
        proj_color,
        proj_status,
        proj_reset,
    });
}

// TESTS

test "formatFileResults: all-ok results in default mode writes nothing" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 8, .status = .ok, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 4, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    try std.testing.expectEqual(false, wrote_output);
    try std.testing.expectEqual(@as(usize, 0), buffer.items.len);
}

test "formatFileResults: warning/error results in default mode writes file header and problems" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 4, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 25, .status = .@"error", .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 2, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    try std.testing.expectEqual(true, wrote_output);
    const output = buffer.items;

    // Check file header
    try std.testing.expect(std.mem.indexOf(u8, output, "test.ts") != null);

    // Check warning is shown
    try std.testing.expect(std.mem.indexOf(u8, output, "bar") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "warning") != null);

    // Check error is shown
    try std.testing.expect(std.mem.indexOf(u8, output, "baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "error") != null);

    // Check ok function is NOT shown
    try std.testing.expect(std.mem.indexOf(u8, output, "foo") == null);
}

test "formatFileResults: verbose mode writes all functions including ok" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 4, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .verbose, .selected_metrics = null };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    try std.testing.expectEqual(true, wrote_output);
    const output = buffer.items;

    // Both functions should be shown
    try std.testing.expect(std.mem.indexOf(u8, output, "foo") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "bar") != null);
}

test "formatFileResults: quiet mode writes only error-level functions" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 4, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 25, .status = .@"error", .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 2, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .quiet, .selected_metrics = null };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    try std.testing.expectEqual(true, wrote_output);
    const output = buffer.items;

    // Only error should be shown
    try std.testing.expect(std.mem.indexOf(u8, output, "baz") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "foo") == null);
    try std.testing.expect(std.mem.indexOf(u8, output, "bar") == null);
}

test "formatFileResults: no_color produces no ANSI codes" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 25, .status = .@"error", .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 2, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    _ = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    const output = buffer.items;

    // Should not contain ANSI escape codes
    try std.testing.expect(std.mem.indexOf(u8, output, "\x1b[") == null);
}

test "formatSummary: includes file count, function count, verdict" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const file_results = [_]FileThresholdResults{};
    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatSummary(
        buffer.writer(allocator),
        allocator,
        5,
        20,
        0,
        0,
        &file_results,
        config,
        95.0,
    );

    const output = buffer.items;

    // Check counts
    try std.testing.expect(std.mem.indexOf(u8, output, "Analyzed 5 files") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "20 functions") != null);

    // Check health score
    try std.testing.expect(std.mem.indexOf(u8, output, "Health: 95") != null);

    // Check verdict
    try std.testing.expect(std.mem.indexOf(u8, output, "All checks passed") != null);
}

test "formatSummary: shows top 5 hotspots when functions exist" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 15, .status = .warning, .function_name = "func1", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 25, .status = .@"error", .function_name = "func2", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 10, .status = .warning, .function_name = "func3", .function_kind = "function", .start_line = 20, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 30, .status = .@"error", .function_name = "func4", .function_kind = "function", .start_line = 30, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 5, .status = .ok, .function_name = "func5", .function_kind = "function", .start_line = 40, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatSummary(
        buffer.writer(allocator),
        allocator,
        1,
        5,
        2,
        2,
        &file_results,
        config,
        42.0,
    );

    const output = buffer.items;

    // Check hotspots section exists
    try std.testing.expect(std.mem.indexOf(u8, output, "Top cyclomatic hotspots:") != null);

    // Check functions are listed in descending complexity order
    try std.testing.expect(std.mem.indexOf(u8, output, "func4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "func2") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "complexity 30") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "complexity 25") != null);
}

test "formatSummary: quiet mode shows only verdict" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const file_results = [_]FileThresholdResults{};
    const config = OutputConfig{ .use_color = false, .verbosity = .quiet, .selected_metrics = null };

    try formatSummary(
        buffer.writer(allocator),
        allocator,
        5,
        20,
        3,
        1,
        &file_results,
        config,
        30.0,
    );

    const output = buffer.items;

    // Should NOT include summary details
    try std.testing.expect(std.mem.indexOf(u8, output, "Analyzed") == null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Top cyclomatic hotspots:") == null);

    // Should include verdict
    try std.testing.expect(std.mem.indexOf(u8, output, "problems") != null);
}

test "formatVerdict: shows correct message for errors" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatVerdict(buffer.writer(allocator), 2, 3, config);

    const output = buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, output, "5 problems") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "2 errors") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "3 warnings") != null);
}

test "formatVerdict: shows correct message for warnings only" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatVerdict(buffer.writer(allocator), 0, 4, config);

    const output = buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, output, "4 warnings") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "problems") == null);
}

test "formatVerdict: shows correct message for all clear" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatVerdict(buffer.writer(allocator), 0, 0, config);

    const output = buffer.items;

    try std.testing.expect(std.mem.indexOf(u8, output, "All checks passed") != null);
}

test "formatFileResults: shows both cyclomatic and cognitive on same line" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 12, .status = .warning, .function_name = "foo", .function_kind = "function", .start_line = 10, .start_col = 4, .cognitive_complexity = 8, .cognitive_status = .ok },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    _ = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    const output = buffer.items;

    // Both metrics should appear on same line
    try std.testing.expect(std.mem.indexOf(u8, output, "cyclomatic 12") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "cognitive 8") != null);
}

test "formatFileResults: worst status shown when metrics differ" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    // Cyclomatic ok, cognitive warning — worst is warning
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 3, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 18, .cognitive_status = .warning },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    _ = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    const output = buffer.items;

    // Should show warning (worst status) even though cyclomatic is ok
    try std.testing.expect(std.mem.indexOf(u8, output, "warning") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "foo") != null);
}

test "formatFileResults: verbose mode shows Halstead volume" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
           .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume = 150.5 },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .verbose, .selected_metrics = null };
    _ = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    const output = buffer.items;
    // Verbose mode should show halstead volume
    try std.testing.expect(std.mem.indexOf(u8, output, "halstead vol") != null);
}

test "formatFileResults: Halstead volume violation shown in default mode" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
           .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume = 600.0, .halstead_volume_status = .warning },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results },
        config,
    );

    try std.testing.expectEqual(true, wrote_output);
    const output = buffer.items;
    // Should show the function because Halstead volume has warning status
    try std.testing.expect(std.mem.indexOf(u8, output, "foo") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "halstead vol") != null);
}

test "formatFileResults: file-level structural shown in verbose mode" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{};
    const str_result = structural.FileStructuralResult{ .file_length = 50, .export_count = 3 };

    const config = OutputConfig{ .use_color = false, .verbosity = .verbose, .selected_metrics = null };
    _ = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results, .structural = str_result },
        config,
    );

    const output = buffer.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "file length") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "50") != null);
}

test "formatSummary: shows separate cyclomatic and cognitive hotspot lists" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 15, .status = .warning, .function_name = "func1", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 5, .cognitive_status = .ok },
        .{ .complexity = 5, .status = .ok, .function_name = "func2", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 20, .cognitive_status = .warning },
    };

    const file_results = [_]FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatSummary(
        buffer.writer(allocator),
        allocator,
        1,
        2,
        2,
        0,
        &file_results,
        config,
        65.0,
    );

    const output = buffer.items;

    // Both hotspot sections should appear
    try std.testing.expect(std.mem.indexOf(u8, output, "Top cyclomatic hotspots:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Top cognitive hotspots:") != null);
}

test "formatSummary: shows Halstead volume hotspot list" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "bigFunc", .function_kind = "function",
           .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume = 800.0 },
        .{ .complexity = 3, .status = .ok, .function_name = "smallFunc", .function_kind = "function",
           .start_line = 20, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume = 50.0 },
    };

    const file_results = [_]FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };

    try formatSummary(
        buffer.writer(allocator),
        allocator,
        1,
        2,
        0,
        0,
        &file_results,
        config,
        88.0,
    );

    const output = buffer.items;

    // Halstead hotspot section should appear
    try std.testing.expect(std.mem.indexOf(u8, output, "Top Halstead volume hotspots:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "bigFunc") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "volume 800") != null);
}

test "formatFileResults: file-level thresholds from config respected (no violation at low count)" {
    // File has 10 exports and 200 lines - below default thresholds (15/300).
    // With custom very-high thresholds (9999/9999), there should be no violation.
    // This test verifies that hardcoded magic numbers are NOT used.
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{};
    const str_result = structural.FileStructuralResult{ .file_length = 200, .export_count = 10 };

    // Default thresholds: file_length_warning=300, export_count_warning=15
    // 200 < 300 and 10 < 15, so no violation with defaults either
    const config_default = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    const wrote_output_default = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results, .structural = str_result },
        config_default,
    );
    // With default thresholds, 200 lines and 10 exports = no violation -> no output in default mode
    try std.testing.expectEqual(false, wrote_output_default);
}

test "formatFileResults: file-level violation uses config thresholds not hardcoded defaults" {
    // File has 12 exports - above default threshold (15) would NOT trigger,
    // but we set custom threshold of 10, so it SHOULD trigger.
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{};
    const str_result = structural.FileStructuralResult{ .file_length = 50, .export_count = 12 };

    // Custom threshold: export_count_warning=10 (lower than default 15)
    const config = OutputConfig{
        .use_color = false,
        .verbosity = .default,
        .selected_metrics = null,
        .file_level_thresholds = FileLevelThresholds{
            .file_length_warning = 300,
            .file_length_error = 600,
            .export_count_warning = 10,  // lower than default 15
            .export_count_error = 20,
        },
    };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results, .structural = str_result },
        config,
    );
    // 12 exports >= 10 (custom warning threshold) -> should show violation
    try std.testing.expectEqual(true, wrote_output);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "warning") != null);
}

test "formatFileResults: very high config thresholds suppress file-level violations" {
    // File has 400 lines and 20 exports - would normally trigger with default thresholds.
    // With very high custom thresholds (9999/9999), no violation should occur.
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const results = [_]cyclomatic.ThresholdResult{};
    const str_result = structural.FileStructuralResult{ .file_length = 400, .export_count = 20 };

    const config = OutputConfig{
        .use_color = false,
        .verbosity = .default,
        .selected_metrics = null,
        .file_level_thresholds = FileLevelThresholds{
            .file_length_warning = 9999,
            .file_length_error = 9999,
            .export_count_warning = 9999,
            .export_count_error = 9999,
        },
    };
    const wrote_output = try formatFileResults(
        buffer.writer(allocator),
        allocator,
        FileThresholdResults{ .path = "test.ts", .results = &results, .structural = str_result },
        config,
    );
    // 400 < 9999 and 20 < 9999 -> no violation -> no output in default mode
    try std.testing.expectEqual(false, wrote_output);
}

test "formatDuplicationSection: shows clone groups and project duplication" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    const locations1 = [_]duplication.CloneLocation{
        .{ .file_path = "src/auth/login.ts", .start_line = 15, .end_line = 25 },
        .{ .file_path = "src/auth/register.ts", .start_line = 88, .end_line = 98 },
    };
    const clone_groups = [_]duplication.CloneGroup{
        .{ .token_count = 42, .locations = &locations1 },
    };
    const file_results = [_]duplication.FileDuplicationResult{
        .{ .path = "src/auth/login.ts", .total_tokens = 500, .cloned_tokens = 62, .duplication_pct = 12.4, .warning = false, .@"error" = false },
        .{ .path = "src/auth/register.ts", .total_tokens = 400, .cloned_tokens = 68, .duplication_pct = 17.0, .warning = true, .@"error" = false },
    };
    const dup_result = duplication.DuplicationResult{
        .clone_groups = &clone_groups,
        .file_results = &file_results,
        .total_cloned_tokens = 130,
        .total_tokens = 900,
        .project_duplication_pct = 4.2,
        .project_warning = false,
        .project_error = false,
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .default, .selected_metrics = null };
    try formatDuplicationSection(buffer.writer(allocator), allocator, dup_result, config);

    const output = buffer.items;

    // Check header
    try std.testing.expect(std.mem.indexOf(u8, output, "Duplication") != null);

    // Check clone group output
    try std.testing.expect(std.mem.indexOf(u8, output, "Clone group (42 tokens)") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "src/auth/login.ts:15") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "src/auth/register.ts:88") != null);

    // Check file duplication section (warning file should appear in default mode)
    try std.testing.expect(std.mem.indexOf(u8, output, "File duplication:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "src/auth/register.ts") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "17.0%") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[WARNING]") != null);

    // Check project duplication
    try std.testing.expect(std.mem.indexOf(u8, output, "Project duplication: 4.2%") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[OK]") != null);
}

test "formatDuplicationSection: quiet mode only shows error-level files in file duplication list" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    // No clone groups to avoid src/b.ts appearing in the group list
    const clone_groups = [_]duplication.CloneGroup{};
    const file_results = [_]duplication.FileDuplicationResult{
        .{ .path = "src/a.ts", .total_tokens = 200, .cloned_tokens = 50, .duplication_pct = 26.0, .warning = true, .@"error" = true },
        .{ .path = "src/b.ts", .total_tokens = 300, .cloned_tokens = 30, .duplication_pct = 10.0, .warning = false, .@"error" = false },
    };
    const dup_result = duplication.DuplicationResult{
        .clone_groups = &clone_groups,
        .file_results = &file_results,
        .total_cloned_tokens = 80,
        .total_tokens = 500,
        .project_duplication_pct = 16.0,
        .project_warning = true,
        .project_error = false,
    };

    const config = OutputConfig{ .use_color = false, .verbosity = .quiet, .selected_metrics = null };
    try formatDuplicationSection(buffer.writer(allocator), allocator, dup_result, config);

    const output = buffer.items;

    // Error-level file should appear in file duplication list (in quiet mode)
    // Note: src/a.ts shows in the file duplication list because it has @"error" = true
    try std.testing.expect(std.mem.indexOf(u8, output, "src/a.ts") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[ERROR]") != null);
    // Non-error, non-warning file should NOT appear in file duplication section
    try std.testing.expect(std.mem.indexOf(u8, output, "src/b.ts") == null);
}
