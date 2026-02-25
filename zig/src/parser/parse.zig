const std = @import("std");
const tree_sitter = @import("tree_sitter.zig");

const Allocator = std.mem.Allocator;

/// Result of parsing a single file.
pub const ParseResult = struct {
    path: []const u8, // file path (borrowed, not owned)
    tree: ?tree_sitter.Tree, // parsed tree (null if parse failed completely)
    language: tree_sitter.Language, // which grammar was used
    has_errors: bool, // true if tree contains ERROR/MISSING nodes
    source: []const u8, // file contents (owned by caller)
};

/// Error information for a file that failed to parse.
pub const FileParseError = struct {
    path: []const u8,
    message: []const u8,
};

/// Summary of parsing multiple files.
pub const ParseSummary = struct {
    results: []ParseResult, // successfully parsed files
    errors: []FileParseError, // files that failed to parse
    total_files: u32,
    successful_parses: u32,
    files_with_errors: u32, // parsed but had syntax errors
    failed_parses: u32, // could not parse at all

    /// Free all memory associated with this summary.
    pub fn deinit(self: *ParseSummary, allocator: Allocator) void {
        for (self.results) |*result| {
            if (result.tree) |tree| {
                tree.deinit();
            }
            allocator.free(result.source);
        }
        allocator.free(self.results);

        for (self.errors) |err| {
            allocator.free(err.message);
        }
        allocator.free(self.errors);
    }
};

/// Select the appropriate tree-sitter language based on file extension.
pub fn selectLanguage(path: []const u8) !tree_sitter.Language {
    // Check .tsx before .ts since .ts is a suffix of .tsx
    if (std.mem.endsWith(u8, path, ".tsx")) {
        return .tsx;
    }
    if (std.mem.endsWith(u8, path, ".ts")) {
        return .typescript;
    }
    if (std.mem.endsWith(u8, path, ".jsx")) {
        return .javascript;
    }
    if (std.mem.endsWith(u8, path, ".js")) {
        return .javascript;
    }

    return error.UnsupportedFileType;
}

/// Parse a single file and return the result.
/// Caller owns the returned ParseResult and must free source and tree.
pub fn parseFile(
    allocator: Allocator,
    base_dir: ?[]const u8,
    relative_path: []const u8,
) !ParseResult {
    // Construct full path for file reading
    const full_path = if (base_dir) |dir|
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, relative_path })
    else
        relative_path;
    defer if (base_dir != null) allocator.free(full_path);

    // Read file contents (10MB max)
    const source = try std.fs.cwd().readFileAlloc(allocator, full_path, 10 * 1024 * 1024);
    errdefer allocator.free(source);

    // Select language from extension
    const language = try selectLanguage(full_path);

    // Create parser and set language
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();

    try parser.setLanguage(language);

    // Parse the source
    const tree = try parser.parseString(source);

    // Check for errors in the tree
    const root = tree.rootNode();
    const has_errors = root.hasError();

    return ParseResult{
        .path = relative_path, // borrowed, not owned
        .tree = tree,
        .language = language,
        .has_errors = has_errors,
        .source = source, // ownership transferred to ParseResult
    };
}

/// Parse multiple files and return a summary of results and errors.
pub fn parseFiles(
    allocator: Allocator,
    file_paths: []const []const u8,
) !ParseSummary {
    var results = std.ArrayList(ParseResult).empty;
    defer results.deinit(allocator);
    try results.ensureTotalCapacity(allocator, file_paths.len);

    var errors = std.ArrayList(FileParseError).empty;
    defer errors.deinit(allocator);

    var successful: u32 = 0;
    var with_errors: u32 = 0;
    var failed: u32 = 0;

    for (file_paths) |path| {
        const result = parseFile(allocator, null, path) catch |err| {
            // Parsing failed completely
            failed += 1;

            const error_message = try std.fmt.allocPrint(
                allocator,
                "{s}",
                .{@errorName(err)},
            );

            try errors.append(allocator, FileParseError{
                .path = path,
                .message = error_message,
            });

            continue;
        };

        // Parsing succeeded (even if there are syntax errors)
        successful += 1;
        if (result.has_errors) {
            with_errors += 1;
        }

        try results.append(allocator, result);
    }

    return ParseSummary{
        .results = try results.toOwnedSlice(allocator),
        .errors = try errors.toOwnedSlice(allocator),
        .total_files = @intCast(file_paths.len),
        .successful_parses = successful,
        .files_with_errors = with_errors,
        .failed_parses = failed,
    };
}

// TESTS

test "selectLanguage: TypeScript" {
    const lang = try selectLanguage("foo.ts");
    try std.testing.expectEqual(tree_sitter.Language.typescript, lang);
}

test "selectLanguage: TSX" {
    const lang = try selectLanguage("component.tsx");
    try std.testing.expectEqual(tree_sitter.Language.tsx, lang);
}

test "selectLanguage: JavaScript" {
    const lang = try selectLanguage("script.js");
    try std.testing.expectEqual(tree_sitter.Language.javascript, lang);
}

test "selectLanguage: JSX" {
    const lang = try selectLanguage("component.jsx");
    try std.testing.expectEqual(tree_sitter.Language.javascript, lang);
}

test "selectLanguage: tsx before ts check" {
    // Ensure .tsx is checked before .ts (since .ts is suffix of .tsx)
    const lang = try selectLanguage("file.tsx");
    try std.testing.expectEqual(tree_sitter.Language.tsx, lang);
}

test "selectLanguage: unsupported extension" {
    const result = selectLanguage("file.py");
    try std.testing.expectError(error.UnsupportedFileType, result);
}

test "parseFile: simple TypeScript" {
    const allocator = std.testing.allocator;

    const result = try parseFile(allocator, null, "tests/fixtures/typescript/simple_function.ts");
    defer {
        if (result.tree) |tree| tree.deinit();
        allocator.free(result.source);
    }

    try std.testing.expectEqual(tree_sitter.Language.typescript, result.language);
    try std.testing.expect(result.tree != null);
    try std.testing.expect(!result.has_errors);
    try std.testing.expect(result.source.len > 0);
}

test "parseFile: TSX component" {
    const allocator = std.testing.allocator;

    const result = try parseFile(allocator, null, "tests/fixtures/typescript/react_component.tsx");
    defer {
        if (result.tree) |tree| tree.deinit();
        allocator.free(result.source);
    }

    try std.testing.expectEqual(tree_sitter.Language.tsx, result.language);
    try std.testing.expect(result.tree != null);
    try std.testing.expect(!result.has_errors);
}

test "parseFile: JavaScript" {
    const allocator = std.testing.allocator;

    const result = try parseFile(allocator, null, "tests/fixtures/javascript/callback_patterns.js");
    defer {
        if (result.tree) |tree| tree.deinit();
        allocator.free(result.source);
    }

    try std.testing.expectEqual(tree_sitter.Language.javascript, result.language);
    try std.testing.expect(result.tree != null);
}

test "parseFile: JSX component" {
    const allocator = std.testing.allocator;

    const result = try parseFile(allocator, null, "tests/fixtures/javascript/jsx_component.jsx");
    defer {
        if (result.tree) |tree| tree.deinit();
        allocator.free(result.source);
    }

    try std.testing.expectEqual(tree_sitter.Language.javascript, result.language);
    try std.testing.expect(result.tree != null);
}

test "parseFile: syntax errors detected" {
    const allocator = std.testing.allocator;

    const result = try parseFile(allocator, null, "tests/fixtures/typescript/syntax_error.ts");
    defer {
        if (result.tree) |tree| tree.deinit();
        allocator.free(result.source);
    }

    try std.testing.expect(result.tree != null); // Tree is still returned
    try std.testing.expect(result.has_errors); // But has errors
}

test "parseFile: nonexistent file" {
    const allocator = std.testing.allocator;

    const result = parseFile(allocator, null, "nonexistent.ts");
    try std.testing.expectError(error.FileNotFound, result);
}

test "parseFiles: multiple files" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
        "tests/fixtures/javascript/callback_patterns.js",
        "tests/fixtures/typescript/react_component.tsx",
    };

    var summary = try parseFiles(allocator, &paths);
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 3), summary.total_files);
    try std.testing.expectEqual(@as(u32, 3), summary.successful_parses);
    try std.testing.expectEqual(@as(u32, 0), summary.failed_parses);
    try std.testing.expectEqual(@as(usize, 3), summary.results.len);
    try std.testing.expectEqual(@as(usize, 0), summary.errors.len);
}

test "parseFiles: with syntax errors" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
        "tests/fixtures/typescript/syntax_error.ts",
    };

    var summary = try parseFiles(allocator, &paths);
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 2), summary.total_files);
    try std.testing.expectEqual(@as(u32, 2), summary.successful_parses);
    try std.testing.expectEqual(@as(u32, 1), summary.files_with_errors);
    try std.testing.expectEqual(@as(u32, 0), summary.failed_parses);
}

test "parseFiles: with failed file" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
        "nonexistent.ts",
        "tests/fixtures/javascript/callback_patterns.js",
    };

    var summary = try parseFiles(allocator, &paths);
    defer summary.deinit(allocator);

    try std.testing.expectEqual(@as(u32, 3), summary.total_files);
    try std.testing.expectEqual(@as(u32, 2), summary.successful_parses);
    try std.testing.expectEqual(@as(u32, 1), summary.failed_parses);
    try std.testing.expectEqual(@as(usize, 2), summary.results.len);
    try std.testing.expectEqual(@as(usize, 1), summary.errors.len);
}

test "parseFiles: memory cleanup" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "tests/fixtures/typescript/simple_function.ts",
        "tests/fixtures/javascript/callback_patterns.js",
    };

    var summary = try parseFiles(allocator, &paths);
    defer summary.deinit(allocator);

    // Testing allocator will catch leaks
    try std.testing.expect(summary.results.len > 0);
}
