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

// --- Rolling hash constants ---
const HASH_BASE: u64 = 37;

/// Maximum bucket size for hash buckets. Buckets larger than this are likely common patterns
/// (boilerplate, short keywords) and are discarded to prevent O(N^2) verification.
const MAX_BUCKET_SIZE: usize = 1000;

// --- Internal helpers ---

/// Returns true for token kinds that should be skipped during tokenization.
/// Skips comments, whitespace-only tokens, and structural punctuation.
fn isSkippedKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "comment") or
        std.mem.eql(u8, kind, "line_comment") or
        std.mem.eql(u8, kind, "block_comment") or
        std.mem.eql(u8, kind, ";") or
        std.mem.eql(u8, kind, ",") or
        // Skip hash-bang and other file-level noise
        std.mem.eql(u8, kind, "hash_bang_line");
}

/// Returns the normalized kind for a token.
/// Identifiers (all variants) are normalized to sentinel "V" for Type 2 clone detection.
fn normalizeKind(kind: []const u8) []const u8 {
    if (std.mem.eql(u8, kind, "identifier") or
        std.mem.eql(u8, kind, "property_identifier") or
        std.mem.eql(u8, kind, "shorthand_property_identifier") or
        std.mem.eql(u8, kind, "shorthand_property_identifier_pattern"))
    {
        return "V";
    }
    return kind;
}

/// Recursively collect normalized tokens from an AST node.
/// Skips comment nodes, punctuation, and TypeScript type annotation subtrees.
fn tokenizeNode(
    node: tree_sitter.Node,
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
) !void {
    const node_type = node.nodeType();

    // Skip entire TypeScript type annotation subtrees
    if (halstead.isTypeOnlyNode(node_type)) {
        return;
    }

    const count = node.childCount();
    if (count == 0) {
        // Leaf node — classify and possibly collect
        if (isSkippedKind(node_type)) return;

        const normalized = normalizeKind(node_type);
        const start_line = node.startPoint().row + 1; // 1-indexed
        try tokens.append(allocator, Token{
            .kind = normalized,
            .start_byte = node.startByte(),
            .start_line = start_line,
        });
        return;
    }

    // Non-leaf: recurse into all children
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        if (node.child(i)) |child| {
            try tokenizeNode(child, tokens, allocator);
        }
    }
}

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

// --- Rolling hash implementation ---

/// Compute a hash value for a token kind string using Rabin-Karp polynomial hashing.
fn tokenHash(kind: []const u8) u64 {
    var h: u64 = 0;
    for (kind) |c| {
        h = h *% HASH_BASE +% @as(u64, c);
    }
    return h;
}

/// Rolling hash state for a sliding window over a token sequence.
const RollingHasher = struct {
    hash: u64,
    /// B^(window_size - 1) for removing the leftmost token.
    base_pow: u64,

    /// Initialize the hasher over the first `window` tokens.
    fn init(tokens: []const Token, window: u32) RollingHasher {
        var h: u64 = 0;
        var bpow: u64 = 1;
        var i: u32 = 0;
        while (i < window) : (i += 1) {
            h = h *% HASH_BASE +% tokenHash(tokens[i].kind);
            if (i < window - 1) bpow *%= HASH_BASE;
        }
        return .{ .hash = h, .base_pow = bpow };
    }

    /// Slide the window: remove `remove` token from the left, add `add` token to the right.
    fn roll(self: *RollingHasher, remove: Token, add: Token) void {
        self.hash = (self.hash -% tokenHash(remove.kind) *% self.base_pow) *%
            HASH_BASE +% tokenHash(add.kind);
    }
};

/// Build the global hash index mapping rolling hash → list of TokenWindows across all files.
fn buildHashIndex(
    allocator: std.mem.Allocator,
    all_tokens: []const []const Token,
    window: u32,
    index: *std.AutoHashMap(u64, std.ArrayList(TokenWindow)),
) !void {
    for (all_tokens, 0..) |file_tokens, file_idx| {
        if (file_tokens.len < window) continue;

        var hasher = RollingHasher.init(file_tokens, window);
        var start: u32 = 0;

        while (start + window <= file_tokens.len) : (start += 1) {
            const end = start + window;
            const gop = try index.getOrPut(hasher.hash);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(TokenWindow).empty;
            }
            try gop.value_ptr.append(allocator, TokenWindow{
                .file_index = @intCast(file_idx),
                .start_token = start,
                .end_token = end,
                .start_line = file_tokens[start].start_line,
                .end_line = file_tokens[end - 1].start_line,
            });
            if (start + window < file_tokens.len) {
                hasher.roll(file_tokens[start], file_tokens[start + window]);
            }
        }
    }
}

/// Verify that two token windows have identical normalized token sequences (collision check).
fn tokensMatch(
    a_tokens: []const Token,
    a_start: u32,
    b_tokens: []const Token,
    b_start: u32,
    window: u32,
) bool {
    var i: u32 = 0;
    while (i < window) : (i += 1) {
        if (!std.mem.eql(u8, a_tokens[a_start + i].kind, b_tokens[b_start + i].kind)) {
            return false;
        }
    }
    return true;
}

/// Form clone groups from the hash index by verifying token-by-token matches.
/// Returns a slice of CloneGroup (caller owns each locations slice and the outer slice).
fn formCloneGroups(
    allocator: std.mem.Allocator,
    index: *std.AutoHashMap(u64, std.ArrayList(TokenWindow)),
    all_tokens: []const []const Token,
    file_paths: []const []const u8,
    window: u32,
) ![]CloneGroup {
    var groups = std.ArrayList(CloneGroup).empty;
    errdefer {
        for (groups.items) |g| allocator.free(g.locations);
        groups.deinit(allocator);
    }

    var iter = index.iterator();
    while (iter.next()) |entry| {
        const bucket = entry.value_ptr.items;
        if (bucket.len < 2) continue;
        // Discard very large buckets (common patterns — see RESEARCH.md pitfall 2)
        if (bucket.len > MAX_BUCKET_SIZE) continue;

        // For each pair of windows in this bucket, verify token-by-token
        // Group all verified matches into one clone group per bucket
        var locations = std.ArrayList(CloneLocation).empty;
        errdefer locations.deinit(allocator);

        // Track which window indices have been added to locations
        var added = try allocator.alloc(bool, bucket.len);
        defer allocator.free(added);
        @memset(added, false);

        var i: usize = 0;
        while (i < bucket.len) : (i += 1) {
            var j: usize = i + 1;
            while (j < bucket.len) : (j += 1) {
                const a = bucket[i];
                const b = bucket[j];

                // Skip identical position in the same file (not a clone)
                if (a.file_index == b.file_index and a.start_token == b.start_token) continue;

                if (tokensMatch(
                    all_tokens[a.file_index],
                    a.start_token,
                    all_tokens[b.file_index],
                    b.start_token,
                    window,
                )) {
                    // Add both windows to the clone group if not already added
                    if (!added[i]) {
                        added[i] = true;
                        try locations.append(allocator, CloneLocation{
                            .file_path = file_paths[a.file_index],
                            .start_line = a.start_line,
                            .end_line = a.end_line,
                        });
                    }
                    if (!added[j]) {
                        added[j] = true;
                        try locations.append(allocator, CloneLocation{
                            .file_path = file_paths[b.file_index],
                            .start_line = b.start_line,
                            .end_line = b.end_line,
                        });
                    }
                }
            }
        }

        if (locations.items.len >= 2) {
            try groups.append(allocator, CloneGroup{
                .token_count = window,
                .locations = try locations.toOwnedSlice(allocator),
            });
        } else {
            locations.deinit(allocator);
        }
    }

    return try groups.toOwnedSlice(allocator);
}

/// Simple interval for token range tracking.
const Interval = struct {
    start: u32,
    end: u32,
};

fn intervalLessThan(_: void, a: Interval, b: Interval) bool {
    return a.start < b.start;
}

/// Merge overlapping token intervals to prevent double-counting cloned tokens.
/// Returns the total count of non-overlapping cloned tokens.
fn countMergedClonedTokens(
    allocator: std.mem.Allocator,
    intervals: []const Interval,
) !u32 {
    if (intervals.len == 0) return 0;

    // Sort a mutable copy by start position
    const sorted = try allocator.dupe(Interval, intervals);
    defer allocator.free(sorted);
    std.mem.sort(Interval, sorted, {}, intervalLessThan);

    var total: u32 = 0;
    var cur_start = sorted[0].start;
    var cur_end = sorted[0].end;

    var i: usize = 1;
    while (i < sorted.len) : (i += 1) {
        const iv = sorted[i];
        if (iv.start <= cur_end) {
            // Overlapping or adjacent — extend current merged interval
            if (iv.end > cur_end) cur_end = iv.end;
        } else {
            // Gap — flush current merged interval
            total += cur_end - cur_start;
            cur_start = iv.start;
            cur_end = iv.end;
        }
    }
    // Flush last interval
    total += cur_end - cur_start;

    return total;
}

/// Detect code clones across multiple files using Rabin-Karp rolling hash.
/// Returns clone groups with per-file and project-level duplication statistics.
pub fn detectDuplication(
    allocator: std.mem.Allocator,
    file_tokens: []const FileTokens,
    config: DuplicationConfig,
) !DuplicationResult {
    const window = config.min_window;

    // Build slices for all_tokens and file_paths
    const all_tokens = try allocator.alloc([]const Token, file_tokens.len);
    defer allocator.free(all_tokens);
    const file_paths = try allocator.alloc([]const u8, file_tokens.len);
    defer allocator.free(file_paths);

    for (file_tokens, 0..) |ft, i| {
        all_tokens[i] = ft.tokens;
        file_paths[i] = ft.path;
    }

    // Build hash index (arena-like: we free it after clone groups are formed)
    var index = std.AutoHashMap(u64, std.ArrayList(TokenWindow)).init(allocator);
    defer {
        var it = index.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        index.deinit();
    }

    try buildHashIndex(allocator, all_tokens, window, &index);

    // Form clone groups from verified hash collisions
    const clone_groups = try formCloneGroups(allocator, &index, all_tokens, file_paths, window);
    errdefer {
        for (clone_groups) |cg| allocator.free(cg.locations);
        allocator.free(clone_groups);
    }

    // Build per-file clone interval lists for merging
    // intervals_per_file[i] = list of (start_token, end_token) intervals that are part of a clone
    const intervals_per_file = try allocator.alloc(std.ArrayList(Interval), file_tokens.len);
    defer {
        for (intervals_per_file) |*list| list.deinit(allocator);
        allocator.free(intervals_per_file);
    }
    for (intervals_per_file) |*list| {
        list.* = std.ArrayList(Interval).empty;
    }

    // Collect all clone windows from the hash index buckets
    // We iterate the index again to gather which windows belong to clones
    {
        var it = index.iterator();
        while (it.next()) |entry| {
            const bucket = entry.value_ptr.items;
            if (bucket.len < 2 or bucket.len > MAX_BUCKET_SIZE) continue;

            // Check each pair for verified matches
            var i: usize = 0;
            while (i < bucket.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < bucket.len) : (j += 1) {
                    const a = bucket[i];
                    const b = bucket[j];
                    if (a.file_index == b.file_index and a.start_token == b.start_token) continue;

                    if (tokensMatch(
                        all_tokens[a.file_index],
                        a.start_token,
                        all_tokens[b.file_index],
                        b.start_token,
                        window,
                    )) {
                        try intervals_per_file[a.file_index].append(allocator, Interval{
                            .start = a.start_token,
                            .end = a.end_token,
                        });
                        try intervals_per_file[b.file_index].append(allocator, Interval{
                            .start = b.start_token,
                            .end = b.end_token,
                        });
                    }
                }
            }
        }
    }

    // Compute per-file results
    var file_results = try allocator.alloc(FileDuplicationResult, file_tokens.len);
    errdefer allocator.free(file_results);

    var total_cloned: u32 = 0;
    var total_all: u32 = 0;

    for (file_tokens, 0..) |ft, i| {
        const total_toks: u32 = @intCast(ft.tokens.len);
        const cloned_toks = try countMergedClonedTokens(allocator, intervals_per_file[i].items);
        const pct: f64 = if (total_toks == 0)
            0.0
        else
            @as(f64, @floatFromInt(cloned_toks)) / @as(f64, @floatFromInt(total_toks)) * 100.0;

        file_results[i] = FileDuplicationResult{
            .path = ft.path,
            .total_tokens = total_toks,
            .cloned_tokens = cloned_toks,
            .duplication_pct = pct,
            .warning = pct >= config.file_warning_pct,
            .@"error" = pct >= config.file_error_pct,
        };

        total_cloned += cloned_toks;
        total_all += total_toks;
    }

    const project_pct: f64 = if (total_all == 0)
        0.0
    else
        @as(f64, @floatFromInt(total_cloned)) / @as(f64, @floatFromInt(total_all)) * 100.0;

    return DuplicationResult{
        .clone_groups = clone_groups,
        .file_results = file_results,
        .total_cloned_tokens = total_cloned,
        .total_tokens = total_all,
        .project_duplication_pct = project_pct,
        .project_warning = project_pct >= config.project_warning_pct,
        .project_error = project_pct >= config.project_error_pct,
    };
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
