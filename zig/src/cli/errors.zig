const std = @import("std");

/// Known flag names for did-you-mean suggestions.
const known_flags = [_][]const u8{
    "help",
    "version",
    "format",
    "output",
    "config",
    "fail-on",
    "fail-health-below",
    "include",
    "exclude",
    "metrics",
    "no-duplication",
    "threads",
    "baseline",
    "verbose",
    "quiet",
    "color",
    "no-color",
    "init",
};

/// Calculate Levenshtein distance between two strings using Wagner-Fischer algorithm.
pub fn levenshteinDistance(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !usize {
    const m = a.len;
    const n = b.len;

    // Edge cases: if either string is empty, return length of other string
    if (m == 0) return n;
    if (n == 0) return m;

    // Allocate matrix (m+1) * (n+1)
    const matrix = try allocator.alloc(usize, (m + 1) * (n + 1));
    defer allocator.free(matrix);

    // Helper to access matrix[i][j]
    const get = struct {
        fn get(mat: []usize, cols: usize, i: usize, j: usize) usize {
            return mat[i * cols + j];
        }
    }.get;

    const set = struct {
        fn set(mat: []usize, cols: usize, i: usize, j: usize, val: usize) void {
            mat[i * cols + j] = val;
        }
    }.set;

    const cols = n + 1;

    // Initialize first row and column
    var i: usize = 0;
    while (i <= m) : (i += 1) {
        set(matrix, cols, i, 0, i);
    }

    var j: usize = 0;
    while (j <= n) : (j += 1) {
        set(matrix, cols, 0, j, j);
    }

    // Fill matrix using Wagner-Fischer algorithm
    i = 1;
    while (i <= m) : (i += 1) {
        j = 1;
        while (j <= n) : (j += 1) {
            const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;

            const deletion = get(matrix, cols, i - 1, j) + 1;
            const insertion = get(matrix, cols, i, j - 1) + 1;
            const substitution = get(matrix, cols, i - 1, j - 1) + cost;

            const min_val = @min(@min(deletion, insertion), substitution);
            set(matrix, cols, i, j, min_val);
        }
    }

    return get(matrix, cols, m, n);
}

/// Suggest a flag name based on Levenshtein distance.
/// Returns the closest match if distance <= 3, otherwise null.
pub fn suggestFlag(allocator: std.mem.Allocator, unknown: []const u8) !?[]const u8 {
    // Strip leading dashes from unknown
    var clean = unknown;
    if (std.mem.startsWith(u8, clean, "--")) {
        clean = clean[2..];
    } else if (std.mem.startsWith(u8, clean, "-")) {
        clean = clean[1..];
    }

    var min_distance: usize = std.math.maxInt(usize);
    var best_match: ?[]const u8 = null;

    for (known_flags) |flag| {
        const dist = try levenshteinDistance(allocator, clean, flag);
        if (dist < min_distance) {
            min_distance = dist;
            best_match = flag;
        }
    }

    // Only suggest if distance <= 3
    if (min_distance <= 3) {
        return best_match;
    }

    return null;
}

/// Format an error message for an unknown flag.
pub fn formatUnknownFlagError(allocator: std.mem.Allocator, unknown: []const u8) ![]const u8 {
    const suggestion = try suggestFlag(allocator, unknown);

    if (suggestion) |flag| {
        return try std.fmt.allocPrint(
            allocator,
            "error: unknown flag '{s}'. Did you mean '--{s}'?",
            .{ unknown, flag },
        );
    } else {
        return try std.fmt.allocPrint(
            allocator,
            "error: unknown flag '{s}'",
            .{unknown},
        );
    }
}

// TESTS

test "levenshteinDistance kitten to sitting" {
    const allocator = std.testing.allocator;
    const dist = try levenshteinDistance(allocator, "kitten", "sitting");
    try std.testing.expectEqual(@as(usize, 3), dist);
}

test "levenshteinDistance empty string" {
    const allocator = std.testing.allocator;
    const dist = try levenshteinDistance(allocator, "", "abc");
    try std.testing.expectEqual(@as(usize, 3), dist);
}

test "levenshteinDistance identical strings" {
    const allocator = std.testing.allocator;
    const dist = try levenshteinDistance(allocator, "abc", "abc");
    try std.testing.expectEqual(@as(usize, 0), dist);
}

test "levenshteinDistance foramt to format" {
    const allocator = std.testing.allocator;
    const dist = try levenshteinDistance(allocator, "foramt", "format");
    try std.testing.expectEqual(@as(usize, 2), dist);
}

test "suggestFlag for foramt returns format" {
    const allocator = std.testing.allocator;
    const suggestion = try suggestFlag(allocator, "foramt");
    try std.testing.expect(suggestion != null);
    try std.testing.expectEqualStrings("format", suggestion.?);
}

test "suggestFlag for verbos returns verbose" {
    const allocator = std.testing.allocator;
    const suggestion = try suggestFlag(allocator, "verbos");
    try std.testing.expect(suggestion != null);
    try std.testing.expectEqualStrings("verbose", suggestion.?);
}

test "suggestFlag for xyzxyzxyz returns null" {
    const allocator = std.testing.allocator;
    const suggestion = try suggestFlag(allocator, "xyzxyzxyz");
    try std.testing.expect(suggestion == null);
}

test "formatUnknownFlagError with suggestion" {
    const allocator = std.testing.allocator;
    const msg = try formatUnknownFlagError(allocator, "--foramt");
    defer allocator.free(msg);

    try std.testing.expect(std.mem.indexOf(u8, msg, "Did you mean") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "format") != null);
}

test "formatUnknownFlagError without suggestion" {
    const allocator = std.testing.allocator;
    const msg = try formatUnknownFlagError(allocator, "--xyzxyzxyz");
    defer allocator.free(msg);

    try std.testing.expect(std.mem.indexOf(u8, msg, "Did you mean") == null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "error: unknown flag") != null);
}
