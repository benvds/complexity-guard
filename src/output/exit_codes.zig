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
///   2. errors_found (exit 1) - if error_count > 0
///   3. warnings_found (exit 2) - if warning_count > 0 AND fail_on_warnings
///   4. success (exit 0) - otherwise
pub fn determineExitCode(
    has_parse_errors: bool,
    error_count: u32,
    warning_count: u32,
    fail_on_warnings: bool,
) ExitCode {
    // Priority 1: Parse errors
    if (has_parse_errors) return .parse_error;

    // Priority 2: Threshold errors
    if (error_count > 0) return .errors_found;

    // Priority 3: Threshold warnings (only if fail_on_warnings enabled)
    if (warning_count > 0 and fail_on_warnings) return .warnings_found;

    // Default: Success
    return .success;
}

/// Count warnings and errors from threshold results
pub fn countViolations(
    threshold_results: []const cyclomatic.ThresholdResult,
) struct { warnings: u32, errors: u32 } {
    var warnings: u32 = 0;
    var errors: u32 = 0;

    for (threshold_results) |result| {
        switch (result.status) {
            .warning => warnings += 1,
            .@"error" => errors += 1,
            .ok => {},
        }
    }

    return .{ .warnings = warnings, .errors = errors };
}

// TESTS

test "determineExitCode: success when no violations" {
    const exit_code = determineExitCode(false, 0, 0, false);
    try std.testing.expectEqual(ExitCode.success, exit_code);
}

test "determineExitCode: errors_found when error_count > 0" {
    const exit_code = determineExitCode(false, 1, 0, false);
    try std.testing.expectEqual(ExitCode.errors_found, exit_code);
}

test "determineExitCode: warnings_found when warnings > 0 and fail_on_warnings true" {
    const exit_code = determineExitCode(false, 0, 3, true);
    try std.testing.expectEqual(ExitCode.warnings_found, exit_code);
}

test "determineExitCode: success when warnings > 0 but fail_on_warnings false" {
    const exit_code = determineExitCode(false, 0, 5, false);
    try std.testing.expectEqual(ExitCode.success, exit_code);
}

test "determineExitCode: parse_error when has_parse_errors true" {
    const exit_code = determineExitCode(true, 0, 0, false);
    try std.testing.expectEqual(ExitCode.parse_error, exit_code);
}

test "determineExitCode: priority parse_error > errors_found > warnings_found" {
    // Parse error takes priority over everything
    const exit_code1 = determineExitCode(true, 10, 20, true);
    try std.testing.expectEqual(ExitCode.parse_error, exit_code1);

    // Errors take priority over warnings
    const exit_code2 = determineExitCode(false, 5, 10, true);
    try std.testing.expectEqual(ExitCode.errors_found, exit_code2);

    // Warnings take priority over success
    const exit_code3 = determineExitCode(false, 0, 3, true);
    try std.testing.expectEqual(ExitCode.warnings_found, exit_code3);
}

test "countViolations: counts correctly with mixed statuses" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .start_line = 1, .start_col = 0 },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .start_line = 10, .start_col = 0 },
        .{ .complexity = 15, .status = .warning, .function_name = "baz", .start_line = 20, .start_col = 0 },
        .{ .complexity = 25, .status = .@"error", .function_name = "qux", .start_line = 30, .start_col = 0 },
        .{ .complexity = 8, .status = .ok, .function_name = "quux", .start_line = 40, .start_col = 0 },
        .{ .complexity = 30, .status = .@"error", .function_name = "corge", .start_line = 50, .start_col = 0 },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 2), counts.warnings);
    try std.testing.expectEqual(@as(u32, 2), counts.errors);
}

test "countViolations: returns zeros for all-ok results" {
    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .start_line = 1, .start_col = 0 },
        .{ .complexity = 8, .status = .ok, .function_name = "bar", .start_line = 10, .start_col = 0 },
        .{ .complexity = 3, .status = .ok, .function_name = "baz", .start_line = 20, .start_col = 0 },
    };

    const counts = countViolations(&results);
    try std.testing.expectEqual(@as(u32, 0), counts.warnings);
    try std.testing.expectEqual(@as(u32, 0), counts.errors);
}

test "ExitCode.toInt: returns correct numeric values" {
    try std.testing.expectEqual(@as(u8, 0), ExitCode.success.toInt());
    try std.testing.expectEqual(@as(u8, 1), ExitCode.errors_found.toInt());
    try std.testing.expectEqual(@as(u8, 2), ExitCode.warnings_found.toInt());
    try std.testing.expectEqual(@as(u8, 3), ExitCode.config_error.toInt());
    try std.testing.expectEqual(@as(u8, 4), ExitCode.parse_error.toInt());
}
