const std = @import("std");
const testing = std.testing;

/// Project version
pub const version = "0.1.0";

/// FunctionResult captures all complexity metrics for a single function.
///
/// Identity fields locate the function in source code. Structural metrics
/// are populated during AST traversal (Phase 2-3). Computed metrics are
/// placeholders filled in later phases (cyclomatic: Phase 4, cognitive: Phase 5,
/// halstead: Phase 6, health_score: Phase 7).
pub const FunctionResult = struct {
    // Identity fields
    name: []const u8,        // Function identifier
    start_line: u32,         // 1-indexed line number where function begins
    end_line: u32,           // 1-indexed line number where function ends
    start_col: u32,          // 0-indexed column where function begins

    // Structural metrics (computed during parsing)
    params_count: u32,       // Number of function parameters
    line_count: u32,         // Total lines in function body
    nesting_depth: u32,      // Maximum nesting depth

    // Computed metrics (placeholders - filled in later phases)
    cyclomatic: ?u32,        // McCabe cyclomatic complexity (Phase 4)
    cognitive: ?u32,         // Cognitive complexity (Phase 5)
    halstead_volume: ?f64,   // Halstead volume (Phase 6)
    halstead_difficulty: ?f64, // Halstead difficulty (Phase 6)
    halstead_effort: ?f64,   // Halstead effort (Phase 6)
    health_score: ?f64,      // Weighted composite score (Phase 7)
};

/// FileResult aggregates all functions found in a single source file.
///
/// Contains both file-level structural metadata (line count, export count)
/// and an array of function-level results. Health score is computed in Phase 7
/// as the weighted average of constituent function health scores.
pub const FileResult = struct {
    // Identity
    path: []const u8,        // Relative path to source file

    // Structural metrics
    total_lines: u32,        // Total line count in file
    function_count: u32,     // Number of functions analyzed
    export_count: u32,       // Number of exported symbols

    // Nested results
    functions: []const FunctionResult, // All functions found in this file

    // Computed metrics (placeholders)
    health_score: ?f64,      // Aggregate health score (Phase 7)
};

/// ProjectResult is the top-level container for all analysis results.
///
/// Aggregates all files analyzed, with project-level summary statistics.
/// The files array contains complete per-file results including nested function
/// data. Health score and grade are computed in Phase 7 based on project-wide
/// metric distributions and configurable thresholds.
pub const ProjectResult = struct {
    // Summary metrics
    files_analyzed: u32,     // Total number of files processed
    total_functions: u32,    // Total functions across all files
    total_lines: u32,        // Sum of all file line counts

    // Nested results
    files: []const FileResult, // All analyzed files with function results

    // Computed metrics (placeholders)
    health_score: ?f64,      // Project-wide health score (Phase 7)
    grade: ?[]const u8,      // Letter grade A-F (Phase 7)
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
