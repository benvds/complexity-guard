const std = @import("std");
const console = @import("console.zig");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const exit_codes = @import("exit_codes.zig");
const Allocator = std.mem.Allocator;

/// JSON output envelope for ComplexityGuard results
/// Uses snake_case field naming to match existing codebase convention
pub const JsonOutput = struct {
    version: []const u8,
    timestamp: i64,
    summary: Summary,
    files: []const FileOutput,

    pub const Summary = struct {
        files_analyzed: u32,
        total_functions: u32,
        warnings: u32,
        errors: u32,
        status: []const u8, // "pass", "warning", "error"
    };

    pub const FileOutput = struct {
        path: []const u8,
        functions: []const FunctionOutput,
        /// File length in logical lines (null when structural metrics not computed)
        file_length: ?u32,
        /// Export count (null when structural metrics not computed)
        export_count: ?u32,
    };

    pub const FunctionOutput = struct {
        name: []const u8,
        start_line: u32,
        end_line: u32,
        start_col: u32,
        cyclomatic: ?u32,
        cognitive: ?u32, // Populated by Phase 6 pipeline
        halstead_volume: f64,       // Populated by Phase 7 pipeline
        halstead_difficulty: f64,   // Populated by Phase 7 pipeline
        halstead_effort: f64,       // Populated by Phase 7 pipeline
        halstead_bugs: f64,         // Populated by Phase 7 pipeline
        nesting_depth: u32,
        line_count: u32,
        params_count: u32,
        health_score: ?f64, // null - Phase 8
        status: []const u8, // "ok", "warning", "error"
    };
};

// Use worstStatusAll from exit_codes for consistent all-metric status calculation

/// Build JSON output envelope from analysis results
pub fn buildJsonOutput(
    allocator: Allocator,
    file_results: []const console.FileThresholdResults,
    warning_count: u32,
    error_count: u32,
) !JsonOutput {
    // Determine overall status
    const status = if (error_count > 0)
        "error"
    else if (warning_count > 0)
        "warning"
    else
        "pass";

    // Count total functions
    var total_functions: u32 = 0;
    for (file_results) |fr| {
        total_functions += @intCast(fr.results.len);
    }

    // Build summary
    const summary = JsonOutput.Summary{
        .files_analyzed = @intCast(file_results.len),
        .total_functions = total_functions,
        .warnings = warning_count,
        .errors = error_count,
        .status = status,
    };

    // Build file outputs
    var files_list = std.ArrayList(JsonOutput.FileOutput).empty;
    defer files_list.deinit(allocator);

    for (file_results) |fr| {
        // Build function outputs for this file
        var functions_list = std.ArrayList(JsonOutput.FunctionOutput).empty;
        defer functions_list.deinit(allocator);

        for (fr.results) |result| {
            // Status reflects worst across all metric families
            const worst = exit_codes.worstStatusAll(result);
            const func_status = switch (worst) {
                .ok => "ok",
                .warning => "warning",
                .@"error" => "error",
            };

            try functions_list.append(allocator, JsonOutput.FunctionOutput{
                .name = result.function_name,
                .start_line = result.start_line,
                .end_line = result.end_line,
                .start_col = result.start_col,
                .cyclomatic = result.complexity,
                .cognitive = result.cognitive_complexity,
                .halstead_volume = result.halstead_volume,
                .halstead_difficulty = result.halstead_difficulty,
                .halstead_effort = result.halstead_effort,
                .halstead_bugs = result.halstead_bugs,
                .nesting_depth = result.nesting_depth,
                .line_count = result.function_length,
                .params_count = result.params_count,
                .health_score = null,
                .status = func_status,
            });
        }

        // File-level structural metrics (null when not computed)
        const file_length: ?u32 = if (fr.structural) |s| s.file_length else null;
        const export_count: ?u32 = if (fr.structural) |s| s.export_count else null;

        try files_list.append(allocator, JsonOutput.FileOutput{
            .path = fr.path,
            .functions = try allocator.dupe(JsonOutput.FunctionOutput, functions_list.items),
            .file_length = file_length,
            .export_count = export_count,
        });
    }

    return JsonOutput{
        .version = "1.0.0",
        .timestamp = std.time.timestamp(),
        .summary = summary,
        .files = try allocator.dupe(JsonOutput.FileOutput, files_list.items),
    };
}

/// Serialize JSON output to pretty-printed JSON string
pub fn serializeJsonOutput(
    allocator: Allocator,
    output: JsonOutput,
) ![]u8 {
    return try std.json.Stringify.valueAlloc(allocator, output, .{
        .whitespace = .indent_2,
    });
}

// TESTS

test "buildJsonOutput: produces correct version and status fields" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 0, 0);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    try std.testing.expectEqualStrings("1.0.0", output.version);
    try std.testing.expectEqualStrings("pass", output.summary.status);
    try std.testing.expectEqual(@as(u32, 1), output.summary.files_analyzed);
    try std.testing.expectEqual(@as(u32, 1), output.summary.total_functions);
}

test "buildJsonOutput: counts warnings/errors in summary correctly" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
        .{ .complexity = 25, .status = .@"error", .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 1, 1);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    try std.testing.expectEqual(@as(u32, 1), output.summary.warnings);
    try std.testing.expectEqual(@as(u32, 1), output.summary.errors);
    try std.testing.expectEqualStrings("error", output.summary.status);
}

test "buildJsonOutput: converts file/function data correctly" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 12, .status = .warning, .function_name = "testFunc", .function_kind = "function", .start_line = 42, .start_col = 4, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "src/example.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 1, 0);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    try std.testing.expectEqual(@as(usize, 1), output.files.len);
    try std.testing.expectEqualStrings("src/example.ts", output.files[0].path);
    try std.testing.expectEqual(@as(usize, 1), output.files[0].functions.len);

    const func = output.files[0].functions[0];
    try std.testing.expectEqualStrings("testFunc", func.name);
    try std.testing.expectEqual(@as(u32, 42), func.start_line);
    try std.testing.expectEqual(@as(u32, 4), func.start_col);
    try std.testing.expectEqual(@as(u32, 12), func.cyclomatic.?);
    try std.testing.expectEqualStrings("warning", func.status);
}

test "serializeJsonOutput: produces valid JSON" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 0, 0);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    const json_str = try serializeJsonOutput(allocator, output);
    defer allocator.free(json_str);

    // Verify it's valid JSON by parsing it back
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();

    // Verify key fields exist
    try std.testing.expect(parsed.value.object.get("version") != null);
    try std.testing.expect(parsed.value.object.get("timestamp") != null);
    try std.testing.expect(parsed.value.object.get("summary") != null);
    try std.testing.expect(parsed.value.object.get("files") != null);
}

test "JSON includes Halstead fields populated (non-null)" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function",
           .start_line = 1, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok,
           .halstead_volume = 150.0, .halstead_difficulty = 5.0, .halstead_effort = 750.0, .halstead_bugs = 0.05 },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 0, 0);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    const json_str = try serializeJsonOutput(allocator, output);
    defer allocator.free(json_str);

    // Verify Halstead fields are populated (non-null numeric values in JSON)
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"halstead_volume\": null") == null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"halstead_difficulty\": null") == null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"halstead_effort\": null") == null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"halstead_volume\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"halstead_bugs\":") != null);
    // health_score is still null (Phase 8)
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"health_score\": null") != null);
    // cognitive is populated (Phase 6)
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"cognitive\": null") == null);
}

test "buildJsonOutput: cognitive field is populated from cognitive_complexity" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{ .complexity = 5, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 8, .cognitive_status = .ok },
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 0, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 1, 0);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    // Cognitive field should be populated from cognitive_complexity
    try std.testing.expectEqual(@as(?u32, 8), output.files[0].functions[0].cognitive);
    try std.testing.expectEqual(@as(?u32, 0), output.files[0].functions[1].cognitive);
}

test "buildJsonOutput: status reflects worst of cyclomatic and cognitive" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        // Cyclomatic ok but cognitive error = function status should be error
        .{ .complexity = 3, .status = .ok, .function_name = "foo", .function_kind = "function", .start_line = 1, .start_col = 0, .cognitive_complexity = 30, .cognitive_status = .@"error" },
        // Cyclomatic warning, cognitive ok = function status should be warning
        .{ .complexity = 12, .status = .warning, .function_name = "bar", .function_kind = "function", .start_line = 10, .start_col = 0, .cognitive_complexity = 5, .cognitive_status = .ok },
        // Both ok
        .{ .complexity = 2, .status = .ok, .function_name = "baz", .function_kind = "function", .start_line = 20, .start_col = 0, .cognitive_complexity = 1, .cognitive_status = .ok },
    };

    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const output = try buildJsonOutput(allocator, &file_results, 1, 1);
    defer {
        for (output.files) |file| {
            allocator.free(file.functions);
        }
        allocator.free(output.files);
    }

    try std.testing.expectEqualStrings("error", output.files[0].functions[0].status);
    try std.testing.expectEqualStrings("warning", output.files[0].functions[1].status);
    try std.testing.expectEqualStrings("ok", output.files[0].functions[2].status);
}

test "empty results produce valid JSON with zero counts and pass status" {
    const allocator = std.testing.allocator;

    const file_results = [_]console.FileThresholdResults{};

    const output = try buildJsonOutput(allocator, &file_results, 0, 0);
    defer allocator.free(output.files);

    try std.testing.expectEqualStrings("pass", output.summary.status);
    try std.testing.expectEqual(@as(u32, 0), output.summary.files_analyzed);
    try std.testing.expectEqual(@as(u32, 0), output.summary.total_functions);
    try std.testing.expectEqual(@as(u32, 0), output.summary.warnings);
    try std.testing.expectEqual(@as(u32, 0), output.summary.errors);

    const json_str = try serializeJsonOutput(allocator, output);
    defer allocator.free(json_str);

    // Verify valid JSON
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();
}
