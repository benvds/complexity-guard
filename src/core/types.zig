const std = @import("std");
const testing = std.testing;

/// Project version
pub const version = "0.1.0";

/// FunctionResult captures all complexity metrics for a single function.
pub const FunctionResult = struct {
    // TODO: Implement fields to pass tests
};

/// FileResult aggregates all functions found in a single source file.
pub const FileResult = struct {
    // TODO: Implement fields to pass tests
};

/// ProjectResult is the top-level container for all analysis results.
pub const ProjectResult = struct {
    // TODO: Implement fields to pass tests
};

// TESTS

test "FunctionResult has all required fields" {
    const func = FunctionResult{
        .name = "myFunc",
        .start_line = 10,
        .end_line = 20,
        .start_col = 4,
        .params_count = 2,
        .line_count = 11,
        .cyclomatic = null,
        .cognitive = null,
        .halstead_volume = null,
        .halstead_difficulty = null,
        .halstead_effort = null,
        .nesting_depth = 3,
        .health_score = null,
    };

    try testing.expectEqualStrings("myFunc", func.name);
    try testing.expectEqual(@as(u32, 10), func.start_line);
    try testing.expectEqual(@as(u32, 20), func.end_line);
    try testing.expectEqual(@as(u32, 4), func.start_col);
    try testing.expectEqual(@as(u32, 2), func.params_count);
    try testing.expectEqual(@as(u32, 11), func.line_count);
    try testing.expectEqual(@as(u32, 3), func.nesting_depth);
    try testing.expectEqual(@as(?u32, null), func.cyclomatic);
    try testing.expectEqual(@as(?u32, null), func.cognitive);
    try testing.expectEqual(@as(?f64, null), func.halstead_volume);
    try testing.expectEqual(@as(?f64, null), func.halstead_difficulty);
    try testing.expectEqual(@as(?f64, null), func.halstead_effort);
    try testing.expectEqual(@as(?f64, null), func.health_score);
}

test "FileResult contains FunctionResults and metadata" {
    const funcs = [_]FunctionResult{
        FunctionResult{
            .name = "func1",
            .start_line = 1,
            .end_line = 10,
            .start_col = 0,
            .params_count = 1,
            .line_count = 10,
            .cyclomatic = null,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 2,
            .health_score = null,
        },
        FunctionResult{
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

    const file = FileResult{
        .path = "src/main.zig",
        .total_lines = 100,
        .function_count = 2,
        .functions = &funcs,
        .health_score = null,
        .export_count = 1,
    };

    try testing.expectEqualStrings("src/main.zig", file.path);
    try testing.expectEqual(@as(u32, 100), file.total_lines);
    try testing.expectEqual(@as(u32, 2), file.function_count);
    try testing.expectEqual(@as(usize, 2), file.functions.len);
    try testing.expectEqual(@as(u32, 1), file.export_count);
    try testing.expectEqual(@as(?f64, null), file.health_score);
}

test "ProjectResult contains FileResults and totals" {
    const funcs1 = [_]FunctionResult{
        FunctionResult{
            .name = "func1",
            .start_line = 1,
            .end_line = 10,
            .start_col = 0,
            .params_count = 1,
            .line_count = 10,
            .cyclomatic = null,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 2,
            .health_score = null,
        },
    };

    const funcs2 = [_]FunctionResult{
        FunctionResult{
            .name = "func2",
            .start_line = 1,
            .end_line = 15,
            .start_col = 0,
            .params_count = 2,
            .line_count = 15,
            .cyclomatic = null,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .nesting_depth = 3,
            .health_score = null,
        },
    };

    const files = [_]FileResult{
        FileResult{
            .path = "src/file1.zig",
            .total_lines = 50,
            .function_count = 1,
            .functions = &funcs1,
            .health_score = null,
            .export_count = 1,
        },
        FileResult{
            .path = "src/file2.zig",
            .total_lines = 75,
            .function_count = 1,
            .functions = &funcs2,
            .health_score = null,
            .export_count = 2,
        },
    };

    const project = ProjectResult{
        .files_analyzed = 2,
        .total_functions = 2,
        .total_lines = 125,
        .files = &files,
        .health_score = null,
        .grade = null,
    };

    try testing.expectEqual(@as(u32, 2), project.files_analyzed);
    try testing.expectEqual(@as(u32, 2), project.total_functions);
    try testing.expectEqual(@as(u32, 125), project.total_lines);
    try testing.expectEqual(@as(usize, 2), project.files.len);
    try testing.expectEqual(@as(?f64, null), project.health_score);
    try testing.expectEqual(@as(?[]const u8, null), project.grade);
}

test "nullable metric fields default to null" {
    const func = FunctionResult{
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

    try testing.expect(func.cyclomatic == null);
    try testing.expect(func.cognitive == null);
    try testing.expect(func.halstead_volume == null);
    try testing.expect(func.halstead_difficulty == null);
    try testing.expect(func.halstead_effort == null);
    try testing.expect(func.health_score == null);
}
