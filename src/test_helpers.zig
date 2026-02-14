const std = @import("std");
const testing = std.testing;
const types = @import("core/types.zig");

/// Test helper for creating FunctionResult with sensible defaults.
/// Reduces test boilerplate from 13 lines to 1 line.
///
/// Example:
///   const func = try createTestFunction(allocator, "myFunc");
pub fn createTestFunction(allocator: std.mem.Allocator, name: []const u8) !types.FunctionResult {
    const owned_name = try allocator.dupe(u8, name);
    return types.FunctionResult{
        .name = owned_name,
        .start_line = 1,
        .end_line = 10,
        .start_col = 0,
        .params_count = 0,
        .line_count = 10,
        .nesting_depth = 0,
        .cyclomatic = null,
        .cognitive = null,
        .halstead_volume = null,
        .halstead_difficulty = null,
        .halstead_effort = null,
        .health_score = null,
    };
}

/// Options for creating a customized FunctionResult.
/// All fields have sensible defaults - override only what you need.
pub const TestFunctionOpts = struct {
    name: []const u8 = "testFunc",
    start_line: u32 = 1,
    end_line: u32 = 10,
    start_col: u32 = 0,
    params_count: u32 = 0,
    line_count: u32 = 10,
    nesting_depth: u32 = 0,
    cyclomatic: ?u32 = null,
    cognitive: ?u32 = null,
    halstead_volume: ?f64 = null,
    halstead_difficulty: ?f64 = null,
    halstead_effort: ?f64 = null,
    health_score: ?f64 = null,
};

/// Test helper for creating FunctionResult with custom field values.
/// Uses builder pattern with defaults.
///
/// Example:
///   const func = try createTestFunctionFull(allocator, .{
///       .name = "complex",
///       .cyclomatic = 15,
///       .cognitive = 20,
///   });
pub fn createTestFunctionFull(allocator: std.mem.Allocator, opts: TestFunctionOpts) !types.FunctionResult {
    const owned_name = try allocator.dupe(u8, opts.name);
    return types.FunctionResult{
        .name = owned_name,
        .start_line = opts.start_line,
        .end_line = opts.end_line,
        .start_col = opts.start_col,
        .params_count = opts.params_count,
        .line_count = opts.line_count,
        .nesting_depth = opts.nesting_depth,
        .cyclomatic = opts.cyclomatic,
        .cognitive = opts.cognitive,
        .halstead_volume = opts.halstead_volume,
        .halstead_difficulty = opts.halstead_difficulty,
        .halstead_effort = opts.halstead_effort,
        .health_score = opts.health_score,
    };
}

/// Test helper for creating FileResult from a slice of functions.
/// Auto-computes function_count from the slice length.
///
/// Example:
///   const funcs = [_]FunctionResult{func1, func2};
///   const file = try createTestFile(allocator, "src/main.ts", &funcs);
pub fn createTestFile(allocator: std.mem.Allocator, path: []const u8, functions: []const types.FunctionResult) !types.FileResult {
    const owned_path = try allocator.dupe(u8, path);
    const owned_functions = try allocator.dupe(types.FunctionResult, functions);

    return types.FileResult{
        .path = owned_path,
        .total_lines = 100,
        .function_count = @as(u32, @intCast(functions.len)),
        .export_count = 0,
        .functions = owned_functions,
        .health_score = null,
    };
}

/// Test helper for creating ProjectResult from a slice of files.
/// Auto-computes files_analyzed, total_functions, and total_lines from the files slice.
///
/// Example:
///   const files = [_]FileResult{file1, file2};
///   const project = try createTestProject(allocator, &files);
pub fn createTestProject(allocator: std.mem.Allocator, files: []const types.FileResult) !types.ProjectResult {
    const owned_files = try allocator.dupe(types.FileResult, files);

    var total_funcs: u32 = 0;
    var total_lines: u32 = 0;

    for (files) |file| {
        total_funcs += file.function_count;
        total_lines += file.total_lines;
    }

    return types.ProjectResult{
        .files_analyzed = @as(u32, @intCast(files.len)),
        .total_functions = total_funcs,
        .total_lines = total_lines,
        .files = owned_files,
        .health_score = null,
        .grade = null,
    };
}

/// Test helper for asserting that a JSON string contains an expected substring.
/// Provides clear error messages when the substring is not found.
///
/// Example:
///   try expectJsonContains(json, "\"name\":\"myFunc\"");
pub fn expectJsonContains(json_str: []const u8, expected_substring: []const u8) !void {
    if (std.mem.indexOf(u8, json_str, expected_substring)) |_| {
        // Found - test passes
        return;
    }

    // Not found - provide helpful error
    std.debug.print("\nJSON substring not found!\n", .{});
    std.debug.print("Expected substring: {s}\n", .{expected_substring});
    std.debug.print("Full JSON ({d} bytes):\n{s}\n", .{ json_str.len, json_str });
    return error.JsonSubstringNotFound;
}

// TESTS

test "createTestFunction returns valid defaults" {
    const func = try createTestFunction(testing.allocator, "testFunc");
    defer testing.allocator.free(func.name);

    try testing.expectEqualStrings("testFunc", func.name);
    try testing.expectEqual(@as(u32, 1), func.start_line);
    try testing.expectEqual(@as(u32, 10), func.end_line);
    try testing.expectEqual(@as(u32, 0), func.start_col);
    try testing.expectEqual(@as(u32, 0), func.params_count);
    try testing.expectEqual(@as(u32, 10), func.line_count);
    try testing.expectEqual(@as(u32, 0), func.nesting_depth);
    try testing.expectEqual(@as(?u32, null), func.cyclomatic);
    try testing.expectEqual(@as(?u32, null), func.cognitive);
    try testing.expectEqual(@as(?f64, null), func.health_score);
}

test "createTestFunctionFull overrides defaults" {
    const func = try createTestFunctionFull(testing.allocator, .{
        .name = "complexFunc",
        .cyclomatic = 15,
        .cognitive = 20,
        .nesting_depth = 5,
        .health_score = 0.65,
    });
    defer testing.allocator.free(func.name);

    try testing.expectEqualStrings("complexFunc", func.name);
    try testing.expectEqual(@as(?u32, 15), func.cyclomatic);
    try testing.expectEqual(@as(?u32, 20), func.cognitive);
    try testing.expectEqual(@as(u32, 5), func.nesting_depth);
    try testing.expectEqual(@as(?f64, 0.65), func.health_score);

    // Non-overridden fields still have defaults
    try testing.expectEqual(@as(u32, 1), func.start_line);
    try testing.expectEqual(@as(u32, 10), func.end_line);
}

test "createTestFunctionFull uses all defaults when empty opts" {
    const func = try createTestFunctionFull(testing.allocator, .{});
    defer testing.allocator.free(func.name);

    try testing.expectEqualStrings("testFunc", func.name);
    try testing.expectEqual(@as(u32, 1), func.start_line);
    try testing.expectEqual(@as(u32, 10), func.end_line);
    try testing.expectEqual(@as(?u32, null), func.cyclomatic);
}

test "createTestFile auto-computes function_count" {
    const func1 = try createTestFunction(testing.allocator, "func1");
    const func2 = try createTestFunction(testing.allocator, "func2");
    defer testing.allocator.free(func1.name);
    defer testing.allocator.free(func2.name);

    const funcs = [_]types.FunctionResult{ func1, func2 };
    const file = try createTestFile(testing.allocator, "src/test.ts", &funcs);
    defer {
        testing.allocator.free(file.path);
        testing.allocator.free(file.functions);
    }

    try testing.expectEqualStrings("src/test.ts", file.path);
    try testing.expectEqual(@as(u32, 2), file.function_count);
    try testing.expectEqual(@as(usize, 2), file.functions.len);
}

test "createTestProject auto-computes totals" {
    const func1 = try createTestFunction(testing.allocator, "func1");
    const func2 = try createTestFunction(testing.allocator, "func2");
    const func3 = try createTestFunction(testing.allocator, "func3");
    defer {
        testing.allocator.free(func1.name);
        testing.allocator.free(func2.name);
        testing.allocator.free(func3.name);
    }

    const funcs1 = [_]types.FunctionResult{func1};
    const funcs2 = [_]types.FunctionResult{ func2, func3 };

    const file1 = try createTestFile(testing.allocator, "file1.ts", &funcs1);
    const file2 = try createTestFile(testing.allocator, "file2.ts", &funcs2);
    defer {
        testing.allocator.free(file1.path);
        testing.allocator.free(file1.functions);
        testing.allocator.free(file2.path);
        testing.allocator.free(file2.functions);
    }

    const files = [_]types.FileResult{ file1, file2 };
    const project = try createTestProject(testing.allocator, &files);
    defer testing.allocator.free(project.files);

    try testing.expectEqual(@as(u32, 2), project.files_analyzed);
    try testing.expectEqual(@as(u32, 3), project.total_functions);
    try testing.expectEqual(@as(u32, 200), project.total_lines); // 100 per file default
}

test "expectJsonContains passes when substring present" {
    const json = "{\"name\":\"testFunc\",\"value\":123}";
    try expectJsonContains(json, "\"name\"");
    try expectJsonContains(json, "testFunc");
    try expectJsonContains(json, "\"value\":123");
}

test "expectJsonContains fails when substring absent" {
    const json = "{\"name\":\"testFunc\"}";
    const result = expectJsonContains(json, "notPresent");
    try testing.expectError(error.JsonSubstringNotFound, result);
}
