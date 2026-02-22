const std = @import("std");
const cyclomatic = @import("../metrics/cyclomatic.zig");

/// Exit code values for ComplexityGuard
pub const ExitCode = enum(u8) {
    success = 0,        // All checks pass
    errors_found = 1,   // Error-level threshold violations
    warnings_found = 2, // Warning-level violations (only if --fail-on warning)
    config_error = 3,   // Config validation/load failures
    parse_error = 4,    // Tree-sitter parse failures

    /// Convert to integer exit code
    pub fn toInt(self: ExitCode) u8 {
        return @intFromEnum(self);
    }
};

/// Determine the appropriate exit code based on analysis results
/// Priority order (highest to lowest):
///   1. parse_error (exit 4) - if has_parse_errors is true
///   2. errors_found (exit 1) - if baseline_failed is true
///   3. errors_found (exit 1) - if error_count > 0
///   4. warnings_found (exit 2) - if warning_count > 0 AND fail_on_warnings
///   5. success (exit 0) - otherwise
pub fn determineExitCode(
    has_parse_errors: bool,
    error_count: u32,
    warning_count: u32,
    fail_on_warnings: bool,
    baseline_failed: bool,
) ExitCode {
    // Priority 1: Parse errors
    if (has_parse_errors) return .parse_error;

    // Priority 2: Baseline failure
    if (baseline_failed) return .errors_found;

    // Priority 3: Threshold errors
    if (error_count > 0) return .errors_found;

    // Priority 4: Threshold warnings (only if fail_on_warnings enabled)
    if (warning_count > 0 and fail_on_warnings) return .warnings_found;

    // Default: Success
    return .success;
}

/// Return the worse of two threshold statuses (error > warning > ok)
fn worstStatus(a: cyclomatic.ThresholdStatus, b: cyclomatic.ThresholdStatus) cyclomatic.ThresholdStatus {
    if (a == .@"error" or b == .@"error") return .@"error";
    if (a == .warning or b == .warning) return .warning;
    return .ok;
}

/// Return the worst status across all metric families for a ThresholdResult.
pub fn worstStatusAll(result: cyclomatic.ThresholdResult) cyclomatic.ThresholdStatus {
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

/// Count warnings and errors from threshold results.
/// Considers all metric families — a function counts as the worst status
/// across cyclomatic, cognitive, Halstead, and structural metrics.
pub fn countViolations(
    threshold_results: []const cyclomatic.ThresholdResult,
) struct { warnings: u32, errors: u32 } {
    var warnings: u32 = 0;
    var errors: u32 = 0;

    for (threshold_results) |result| {
        const worst = worstStatusAll(result);
        switch (worst) {
            .warning => warnings += 1,
            .@"error" => errors += 1,
            .ok => {},
        }
    }

    return .{ .warnings = warnings, .errors = errors };
}

/// Check if a metric family is enabled.
/// Returns true when metrics is null (all families enabled) or the name is in the list.
/// Duplicated from main.zig/parallel.zig to avoid circular imports (Phase 07-03 decision).
fn isMetricEnabled(metrics: ?[]const []const u8, metric: []const u8) bool {
    const list = metrics orelse return true;
    for (list) |m| {
        if (std.mem.eql(u8, m, metric)) return true;
    }
    return false;
}

/// Return the worst status across only the enabled metric families for a ThresholdResult.
/// When metrics is null, considers all families (same as worstStatusAll).
pub fn worstStatusForMetrics(result: cyclomatic.ThresholdResult, metrics: ?[]const []const u8) cyclomatic.ThresholdStatus {
    var worst = cyclomatic.ThresholdStatus.ok;
    if (isMetricEnabled(metrics, "cyclomatic")) {
        worst = worstStatus(worst, result.status);
    }
    if (isMetricEnabled(metrics, "cognitive")) {
        worst = worstStatus(worst, result.cognitive_status);
    }
    if (isMetricEnabled(metrics, "halstead")) {
        worst = worstStatus(worst, result.halstead_volume_status);
        worst = worstStatus(worst, result.halstead_difficulty_status);
        worst = worstStatus(worst, result.halstead_effort_status);
        worst = worstStatus(worst, result.halstead_bugs_status);
    }
    if (isMetricEnabled(metrics, "structural")) {
        worst = worstStatus(worst, result.function_length_status);
        worst = worstStatus(worst, result.params_count_status);
        worst = worstStatus(worst, result.nesting_depth_status);
    }
    return worst;
}

/// Count warnings and errors, considering only the enabled metric families.
/// When metrics is null, behaves identically to countViolations (all families).
pub fn countViolationsFiltered(
    threshold_results: []const cyclomatic.ThresholdResult,
    metrics: ?[]const []const u8,
) struct { warnings: u32, errors: u32 } {
    var warnings: u32 = 0;
    var errors: u32 = 0;

    for (threshold_results) |result| {
        const worst = worstStatusForMetrics(result, metrics);
        switch (worst) {
            .warning => warnings += 1,
            .@"error" => errors += 1,
            .ok => {},
        }
    }

    return .{ .warnings = warnings, .errors = errors };
}

// TESTS

test "determineExitCode: success when no violations" {
    const exit_code = determineExitCode(false, 0, 0, false, false);
    try std.testing.expectEqual(ExitCode.success, exit_code);
}

test "determineExitCode: errors_found when error_count > 0" {
    const exit_code = determineExitCode(false, 1, 0, false, false);
    try std.testing.expectEqual(ExitCode.errors_found, exit_code);
}

test "determineExitCode: warnings_found when warnings > 0 and fail_on_warnings true" {
    const exit_code = determineExitCode(false, 0, 3, true, false);
    try std.testing.expectEqual(ExitCode.warnings_found, exit_code);
}

test "determineExitCode: success when warnings > 0 but fail_on_warnings false" {
    const exit_code = determineExitCode(false, 0, 5, false, false);
    try std.testing.expectEqual(ExitCode.success, exit_code);
}

test "determineExitCode: parse_error when has_parse_errors true" {
    const exit_code = determineExitCode(true, 0, 0, false, false);
    try std.testing.expectEqual(ExitCode.parse_error, exit_code);
}

test "determineExitCode: priority parse_error > errors_found > warnings_found" {
    // Parse error takes priority over everything
    const exit_code1 = determineExitCode(true, 10, 20, true, false);
    try std.testing.expectEqual(ExitCode.parse_error, exit_code1);

    // Errors take priority over warnings
    const exit_code2 = determineExitCode(false, 5, 10, true, false);
    try std.testing.expectEqual(ExitCode.errors_found, exit_code2);

    // Warnings take priority over success
    const exit_code3 = determineExitCode(false, 0, 3, true, false);
    try std.testing.expectEqual(ExitCode.warnings_found, exit_code3);
}

test "determineExitCode: baseline_failed causes errors_found" {
    const exit_code = determineExitCode(false, 0, 0, false, true);
    try std.testing.expectEqual(ExitCode.errors_found, exit_code);
}

test "determineExitCode: parse_error takes priority over baseline_failed" {
    const exit_code = determineExitCode(true, 0, 0, false, true);
    try std.testing.expectEqual(ExitCode.parse_error, exit_code);
}

test "countViolations: counts correctly with mixed statuses" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 15, .status = .warning, .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 25, .status = .@"error", .function_name = "qux", .function_kind = "function", .start_line = 30, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 8, .status = .ok, .function_name = "quux", .function_kind = "function", .start_line = 40, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 30, .status = .@"error", .function_name = "corge", .function_kind = "function", .start_line = 50, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 2), counts.warnings);
    try std.testing.expectEqual(@as(u32, 2), counts.errors);
}

test "countViolations: returns zeros for all-ok results" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 8, .status = .ok, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 3, .status = .ok, .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 0), counts.warnings);
    try std.testing.expectEqual(@as(u32, 0), counts.errors);
}

test "countViolations: cognitive warning upgrades ok cyclomatic to warning" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 16, .cognitive_status = .warning },
        .{ .complexity = 3, .status = .ok, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 3, .cognitive_status = .ok },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 1), counts.warnings);
    try std.testing.expectEqual(@as(u32, 0), counts.errors);
}

test "countViolations: cognitive error upgrades cyclomatic warning to error" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 12, .status = .warning, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 26, .cognitive_status = .@"error" },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 0), counts.warnings);
    try std.testing.expectEqual(@as(u32, 1), counts.errors);
}

test "countViolations: both ok means no violations" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 3, .cognitive_status = .ok },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 0), counts.warnings);
    try std.testing.expectEqual(@as(u32, 0), counts.errors);
}

test "worstStatusAll: picks halstead volume warning" {
    const result = cyclomatic.ThresholdResult{
        .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
        .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
        .halstead_volume_status = .warning,
    };
    try std.testing.expectEqual(cyclomatic.ThresholdStatus.warning, worstStatusAll(result));
}

test "worstStatusAll: picks halstead effort error over volume warning" {
    const result = cyclomatic.ThresholdResult{
        .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
        .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
        .halstead_volume_status = .warning,
        .halstead_effort_status = .@"error",
    };
    try std.testing.expectEqual(cyclomatic.ThresholdStatus.@"error", worstStatusAll(result));
}

test "worstStatusAll: picks structural nesting_depth warning" {
    const result = cyclomatic.ThresholdResult{
        .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
        .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
        .nesting_depth_status = .warning,
    };
    try std.testing.expectEqual(cyclomatic.ThresholdStatus.warning, worstStatusAll(result));
}

test "worstStatusAll: all ok returns ok" {
    const result = cyclomatic.ThresholdResult{
        .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
        .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
    };
    try std.testing.expectEqual(cyclomatic.ThresholdStatus.ok, worstStatusAll(result));
}

test "countViolations: Halstead violation counted" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 3, .status = .ok, .function_name = "foo", .function_kind = "function",
           .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume_status = .warning },
    };
    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 1), counts.warnings);
    try std.testing.expectEqual(@as(u32, 0), counts.errors);
}

test "ExitCode.toInt: returns correct numeric values" {
    try std.testing.expectEqual(@as(u8, 0), ExitCode.success.toInt());
    try std.testing.expectEqual(@as(u8, 1), ExitCode.errors_found.toInt());
    try std.testing.expectEqual(@as(u8, 2), ExitCode.warnings_found.toInt());
    try std.testing.expectEqual(@as(u8, 3), ExitCode.config_error.toInt());
    try std.testing.expectEqual(@as(u8, 4), ExitCode.parse_error.toInt());
}
