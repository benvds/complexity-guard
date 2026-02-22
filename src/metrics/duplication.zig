const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const halstead = @import("halstead.zig");

/// A single normalized token extracted from an AST leaf node.
/// The token identity for hashing is `kind` (normalized type string).
/// For identifier nodes, kind is replaced with sentinel "V" for Type 2 clone detection.
pub const Token = struct {
    /// Normalized token type or sentinel "V" for identifiers.
    kind: []const u8,
    /// Byte offset in source (for line-number lookup).
    start_byte: u32,
    /// 1-indexed line number (pre-computed from TSNode).
    start_line: u32,
};

/// A window of consecutive tokens identified by a rolling hash.
pub const TokenWindow = struct {
    /// Index into the file_paths array.
    file_index: u32,
    /// Start token index in the file's token sequence.
    start_token: u32,
    /// Exclusive end token index.
    end_token: u32,
    /// 1-indexed line number of first token.
    start_line: u32,
    /// 1-indexed line number of last token.
    end_line: u32,
};

/// A detected clone group: two or more locations with the same normalized token sequence.
pub const CloneGroup = struct {
    /// Number of tokens in the clone window.
    token_count: u32,
    /// All instances of this clone (2+).
    locations: []const CloneLocation,
};

/// A single instance of a clone at a specific file location.
pub const CloneLocation = struct {
    /// Relative file path.
    file_path: []const u8,
    /// 1-indexed start line.
    start_line: u32,
    /// 1-indexed end line.
    end_line: u32,
};

/// Per-file duplication summary.
pub const FileDuplicationResult = struct {
    /// Relative file path.
    path: []const u8,
    /// Total token count in this file.
    total_tokens: u32,
    /// Non-overlapping count of tokens participating in any clone.
    cloned_tokens: u32,
    /// cloned_tokens / total_tokens * 100
    duplication_pct: f64,
    /// True when duplication_pct >= file_warning_pct.
    warning: bool,
    /// True when duplication_pct >= file_error_pct.
    @"error": bool,
};

/// Project-wide duplication result.
pub const DuplicationResult = struct {
    /// All detected clone groups (2+ locations each).
    clone_groups: []const CloneGroup,
    /// Per-file duplication summaries.
    file_results: []const FileDuplicationResult,
    /// Sum of non-overlapping cloned tokens across all files.
    total_cloned_tokens: u32,
    /// Sum of all tokens across all files.
    total_tokens: u32,
    /// total_cloned_tokens / total_tokens * 100
    project_duplication_pct: f64,
    /// True when project_duplication_pct >= project_warning_pct.
    project_warning: bool,
    /// True when project_duplication_pct >= project_error_pct.
    project_error: bool,
};

/// Configuration for duplication detection.
pub const DuplicationConfig = struct {
    /// Minimum number of tokens for a clone window (default 25).
    min_window: u32,
    /// File-level warning threshold percentage.
    file_warning_pct: f64,
    /// File-level error threshold percentage.
    file_error_pct: f64,
    /// Project-level warning threshold percentage.
    project_warning_pct: f64,
    /// Project-level error threshold percentage.
    project_error_pct: f64,

    /// Returns default configuration with industry-standard thresholds.
    pub fn default() DuplicationConfig {
        return DuplicationConfig{
            .min_window = 25,
            .file_warning_pct = 15.0,
            .file_error_pct = 25.0,
            .project_warning_pct = 5.0,
            .project_error_pct = 10.0,
        };
    }
};

/// Input to detectDuplication: a file path and its token sequence.
pub const FileTokens = struct {
    /// Relative file path.
    path: []const u8,
    /// Normalized token sequence for this file.
    tokens: []const Token,
};

/// Tokenize a tree-sitter AST into a normalized token sequence.
/// Strips comments, whitespace, and TypeScript type annotations.
/// Normalizes identifier nodes to sentinel "V" for Type 2 clone detection.
pub fn tokenizeTree(
    allocator: std.mem.Allocator,
    root: tree_sitter.Node,
    source: []const u8,
) ![]Token {
    _ = source;
    var tokens = std.ArrayList(Token).empty;
    errdefer tokens.deinit(allocator);
    try tokenizeNode(root, &tokens, allocator);
    return try tokens.toOwnedSlice(allocator);
}

/// Detect code clones across multiple files using Rabin-Karp rolling hash.
/// Returns clone groups with per-file and project-level duplication statistics.
pub fn detectDuplication(
    allocator: std.mem.Allocator,
    file_tokens: []const FileTokens,
    config: DuplicationConfig,
) !DuplicationResult {
    _ = file_tokens;
    _ = config;
    // Stub: return empty result (tests will fail in RED phase)
    return DuplicationResult{
        .clone_groups = try allocator.alloc(CloneGroup, 0),
        .file_results = try allocator.alloc(FileDuplicationResult, 0),
        .total_cloned_tokens = 0,
        .total_tokens = 0,
        .project_duplication_pct = 0.0,
        .project_warning = false,
        .project_error = false,
    };
}

// --- Internal helpers (stubs for RED phase) ---

fn tokenizeNode(
    node: tree_sitter.Node,
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
) !void {
    _ = node;
    _ = tokens;
    _ = allocator;
    // Stub: does nothing — tests will fail because token count == 0
}

// TESTS

test "tokenizeTree: produces tokens from simple function" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function add(a: number, b: number): number { return a + b; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const tokens = try tokenizeTree(std.testing.allocator, root, source);
    defer std.testing.allocator.free(tokens);

    // Should produce more than 0 tokens from a real function
    try std.testing.expect(tokens.len > 0);
}

test "tokenizeTree: skips comments" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\// This is a comment
        \\function greet(name: string): string {
        \\  /* block comment */
        \\  return name;
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const tokens = try tokenizeTree(std.testing.allocator, root, source);
    defer std.testing.allocator.free(tokens);

    // No token should have kind "comment", "line_comment", or "block_comment"
    for (tokens) |tok| {
        try std.testing.expect(!std.mem.eql(u8, tok.kind, "comment"));
        try std.testing.expect(!std.mem.eql(u8, tok.kind, "line_comment"));
        try std.testing.expect(!std.mem.eql(u8, tok.kind, "block_comment"));
    }
    // Should still have tokens from the function body
    try std.testing.expect(tokens.len > 0);
}

test "tokenizeTree: normalizes identifiers to V" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function myFunc(myParam: string): void { const myVar = myParam; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const tokens = try tokenizeTree(std.testing.allocator, root, source);
    defer std.testing.allocator.free(tokens);

    // No token should retain the raw kind "identifier" — they must be normalized to "V"
    for (tokens) |tok| {
        try std.testing.expect(!std.mem.eql(u8, tok.kind, "identifier"));
    }
    // At least one token should be "V" (from the identifier nodes)
    var found_v = false;
    for (tokens) |tok| {
        if (std.mem.eql(u8, tok.kind, "V")) {
            found_v = true;
            break;
        }
    }
    try std.testing.expect(found_v);
}

test "tokenizeTree: skips type annotations" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    // TypeScript version with type annotations
    const ts_source = "function f(x: number, y: string): boolean { return x > 0; }";
    // JavaScript equivalent without types
    const js_source = "function f(x, y) { return x > 0; }";

    const ts_tree = try parser.parseString(ts_source);
    defer ts_tree.deinit();
    const js_tree = try parser.parseString(js_source);
    defer js_tree.deinit();

    const ts_tokens = try tokenizeTree(std.testing.allocator, ts_tree.rootNode(), ts_source);
    defer std.testing.allocator.free(ts_tokens);
    const js_tokens = try tokenizeTree(std.testing.allocator, js_tree.rootNode(), js_source);
    defer std.testing.allocator.free(js_tokens);

    // TypeScript and JavaScript versions should produce the same token count
    // after stripping type annotations
    try std.testing.expectEqual(js_tokens.len, ts_tokens.len);
}

test "detectDuplication: finds clone groups in identical functions" {
    // Tokenize two copies of the same function under different file names
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source_a =
        \\function processUserData(input: string): string {
        \\  const result = input.trim().toLowerCase();
        \\  if (result.length === 0) {
        \\    return "empty";
        \\  }
        \\  return result.split(",").join(";");
        \\}
    ;
    const source_b =
        \\function processItemData(input: string): string {
        \\  const result = input.trim().toLowerCase();
        \\  if (result.length === 0) {
        \\    return "empty";
        \\  }
        \\  return result.split(",").join(";");
        \\}
    ;

    const tree_a = try parser.parseString(source_a);
    defer tree_a.deinit();
    const tree_b = try parser.parseString(source_b);
    defer tree_b.deinit();

    const tokens_a = try tokenizeTree(std.testing.allocator, tree_a.rootNode(), source_a);
    defer std.testing.allocator.free(tokens_a);
    const tokens_b = try tokenizeTree(std.testing.allocator, tree_b.rootNode(), source_b);
    defer std.testing.allocator.free(tokens_b);

    const file_tokens = [_]FileTokens{
        .{ .path = "file_a.ts", .tokens = tokens_a },
        .{ .path = "file_b.ts", .tokens = tokens_b },
    };

    // Use a small min_window so the test functions (which may tokenize to ~20 tokens) are detected
    const config = DuplicationConfig{
        .min_window = 10,
        .file_warning_pct = 15.0,
        .file_error_pct = 25.0,
        .project_warning_pct = 5.0,
        .project_error_pct = 10.0,
    };
    const result = try detectDuplication(std.testing.allocator, &file_tokens, config);
    defer {
        for (result.clone_groups) |cg| {
            std.testing.allocator.free(cg.locations);
        }
        std.testing.allocator.free(result.clone_groups);
        std.testing.allocator.free(result.file_results);
    }

    // Should detect at least 1 clone group between these identical (modulo function name) functions
    try std.testing.expect(result.clone_groups.len >= 1);
}

test "detectDuplication: finds Type 2 clones with different identifiers" {
    // validateEmail and validatePhone are structurally identical but have different identifiers
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source_email =
        \\function validateEmail(email: string): boolean {
        \\  const trimmed = email.trim();
        \\  if (trimmed.length === 0) {
        \\    return false;
        \\  }
        \\  return trimmed.includes("@");
        \\}
    ;
    const source_phone =
        \\function validatePhone(phone: string): boolean {
        \\  const cleaned = phone.trim();
        \\  if (cleaned.length === 0) {
        \\    return false;
        \\  }
        \\  return cleaned.includes("+");
        \\}
    ;

    const tree_e = try parser.parseString(source_email);
    defer tree_e.deinit();
    const tree_p = try parser.parseString(source_phone);
    defer tree_p.deinit();

    const tokens_e = try tokenizeTree(std.testing.allocator, tree_e.rootNode(), source_email);
    defer std.testing.allocator.free(tokens_e);
    const tokens_p = try tokenizeTree(std.testing.allocator, tree_p.rootNode(), source_phone);
    defer std.testing.allocator.free(tokens_p);

    const file_tokens = [_]FileTokens{
        .{ .path = "email.ts", .tokens = tokens_e },
        .{ .path = "phone.ts", .tokens = tokens_p },
    };

    const config = DuplicationConfig{
        .min_window = 8,
        .file_warning_pct = 15.0,
        .file_error_pct = 25.0,
        .project_warning_pct = 5.0,
        .project_error_pct = 10.0,
    };
    const result = try detectDuplication(std.testing.allocator, &file_tokens, config);
    defer {
        for (result.clone_groups) |cg| {
            std.testing.allocator.free(cg.locations);
        }
        std.testing.allocator.free(result.clone_groups);
        std.testing.allocator.free(result.file_results);
    }

    // Type 2 clones: structurally identical after identifier normalization
    try std.testing.expect(result.clone_groups.len >= 1);
}

test "detectDuplication: merges overlapping intervals correctly" {
    // When two clone windows overlap in the same file, duplication_pct must not exceed 100%
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function processUserData(input: string): string {
        \\  const result = input.trim().toLowerCase();
        \\  if (result.length === 0) {
        \\    return "empty";
        \\  }
        \\  return result.split(",").join(";");
        \\}
        \\function processItemData(input: string): string {
        \\  const result = input.trim().toLowerCase();
        \\  if (result.length === 0) {
        \\    return "empty";
        \\  }
        \\  return result.split(",").join(";");
        \\}
    ;

    const tree = try parser.parseString(source);
    defer tree.deinit();

    const tokens = try tokenizeTree(std.testing.allocator, tree.rootNode(), source);
    defer std.testing.allocator.free(tokens);

    // Single file with duplicated functions inside it
    const file_tokens = [_]FileTokens{
        .{ .path = "combined.ts", .tokens = tokens },
    };

    const config = DuplicationConfig{
        .min_window = 8,
        .file_warning_pct = 15.0,
        .file_error_pct = 25.0,
        .project_warning_pct = 5.0,
        .project_error_pct = 10.0,
    };
    const result = try detectDuplication(std.testing.allocator, &file_tokens, config);
    defer {
        for (result.clone_groups) |cg| {
            std.testing.allocator.free(cg.locations);
        }
        std.testing.allocator.free(result.clone_groups);
        std.testing.allocator.free(result.file_results);
    }

    // duplication_pct must never exceed 100%
    for (result.file_results) |fr| {
        try std.testing.expect(fr.duplication_pct <= 100.0);
    }
    try std.testing.expect(result.project_duplication_pct <= 100.0);
}
