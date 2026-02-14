const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");

/// Serialize a result type to JSON string
pub fn serializeResult(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    // TODO: Implement
    _ = allocator;
    _ = value;
    return error.NotImplemented;
}

/// Serialize a result type to pretty-printed JSON string
pub fn serializeResultPretty(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    // TODO: Implement
    _ = allocator;
    _ = value;
    return error.NotImplemented;
}

// TESTS

test "FunctionResult serializes to JSON with expected keys" {
    const func = types.FunctionResult{
        .name = "myFunc",
        .start_line = 1,
        .end_line = 10,
        .start_col = 0,
        .params_count = 2,
        .line_count = 10,
        .cyclomatic = null,
        .cognitive = null,
        .halstead_volume = null,
        .halstead_difficulty = null,
        .halstead_effort = null,
        .nesting_depth = 2,
        .health_score = null,
    };

    const json = try serializeResult(testing.allocator, func);
    defer testing.allocator.free(json);

    // Verify JSON contains expected keys
    try testing.expect(std.mem.indexOf(u8, json, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"myFunc\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"start_line\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"cyclomatic\":null") != null);
}

test "FileResult with nested FunctionResults serializes correctly" {
    const funcs = [_]types.FunctionResult{
        types.FunctionResult{
            .name = "func1",
            .start_line = 1,
            .end_line = 10,
            .start_col = 0,
            .params_count = 1,
            .line_count = 10,
            .cyclomatic = 5,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 2,
            .health_score = null,
        },
        types.FunctionResult{
            .name = "func2",
            .start_line = 15,
            .end_line = 25,
            .start_col = 0,
            .params_count = 0,
            .line_count = 11,
            .cyclomatic = null,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 1,
            .health_score = null,
        },
    };

    const file = types.FileResult{
        .path = "src/main.zig",
        .total_lines = 100,
        .function_count = 2,
        .functions = &funcs,
        .health_score = null,
        .export_count = 1,
    };

    const json = try serializeResult(testing.allocator, file);
    defer testing.allocator.free(json);

    // Verify nested structure
    try testing.expect(std.mem.indexOf(u8, json, "\"functions\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"function_count\":2") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"func1\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"func2\"") != null);
}

test "ProjectResult serializes to valid JSON" {
    const funcs1 = [_]types.FunctionResult{
        types.FunctionResult{
            .name = "main",
            .start_line = 1,
            .end_line = 10,
            .start_col = 0,
            .params_count = 0,
            .line_count = 10,
            .cyclomatic = null,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 1,
            .health_score = null,
        },
    };

    const files = [_]types.FileResult{
        types.FileResult{
            .path = "src/main.zig",
            .total_lines = 50,
            .function_count = 1,
            .functions = &funcs1,
            .health_score = null,
            .export_count = 1,
        },
    };

    const project = types.ProjectResult{
        .files_analyzed = 1,
        .total_functions = 1,
        .total_lines = 50,
        .files = &files,
        .health_score = null,
        .grade = null,
    };

    const json = try serializeResult(testing.allocator, project);
    defer testing.allocator.free(json);

    // Verify structure
    try testing.expect(std.mem.indexOf(u8, json, "\"files\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"files_analyzed\":1") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"health_score\":null") != null);
}

test "round-trip serialization preserves field values" {
    const original = types.FunctionResult{
        .name = "testFunc",
        .start_line = 42,
        .end_line = 52,
        .start_col = 4,
        .params_count = 3,
        .line_count = 11,
        .cyclomatic = 7,
        .cognitive = 9,
        .halstead_volume = 123.45,
        .halstead_difficulty = 6.78,
        .halstead_effort = 900.0,
        .nesting_depth = 4,
        .health_score = 85.5,
    };

    // Serialize to JSON
    const json = try serializeResult(testing.allocator, original);
    defer testing.allocator.free(json);

    // Parse back from JSON
    const parsed = try std.json.parseFromSlice(
        types.FunctionResult,
        testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    // Verify values match
    try testing.expectEqualStrings(original.name, parsed.value.name);
    try testing.expectEqual(original.start_line, parsed.value.start_line);
    try testing.expectEqual(original.end_line, parsed.value.end_line);
    try testing.expectEqual(original.cyclomatic, parsed.value.cyclomatic);
    try testing.expectEqual(original.cognitive, parsed.value.cognitive);
    try testing.expectEqual(original.halstead_volume, parsed.value.halstead_volume);
    try testing.expectEqual(original.health_score, parsed.value.health_score);
}

test "pretty-print produces indented output" {
    const func = types.FunctionResult{
        .name = "test",
        .start_line = 1,
        .end_line = 1,
        .start_col = 0,
        .params_count = 0,
        .line_count = 1,
        .cyclomatic = null,
        .cognitive = null,
        .halstead_volume = null,
        .halstead_difficulty = null,
        .halstead_effort = null,
        .nesting_depth = 0,
        .health_score = null,
    };

    const json = try serializeResultPretty(testing.allocator, func);
    defer testing.allocator.free(json);

    // Verify indentation exists (look for newlines and spaces)
    try testing.expect(std.mem.indexOf(u8, json, "\n") != null);
    try testing.expect(std.mem.indexOf(u8, json, "  ") != null);
}
