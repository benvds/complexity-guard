const std = @import("std");

/// Configuration for filtering files during discovery.
pub const FilterConfig = struct {
    include_patterns: ?[]const []const u8 = null, // from config files.include
    exclude_patterns: ?[]const []const u8 = null, // from config files.exclude
};

/// Target file extensions for analysis.
const TARGET_EXTENSIONS = [_][]const u8{ ".ts", ".tsx", ".js", ".jsx" };

/// Common directories to exclude from discovery.
const EXCLUDED_DIRS = [_][]const u8{
    "node_modules",
    ".git",
    "dist",
    "build",
    ".next",
    "coverage",
    "__pycache__",
    ".svn",
    ".hg",
    "vendor",
};

/// Checks if a file path has a target extension (.ts, .tsx, .js, .jsx).
/// Excludes TypeScript declaration files (.d.ts, .d.tsx).
pub fn isTargetFile(path: []const u8) bool {
    // Check for declaration files first (must exclude before checking .ts/.tsx)
    if (std.mem.endsWith(u8, path, ".d.ts")) return false;
    if (std.mem.endsWith(u8, path, ".d.tsx")) return false;

    // Check if path ends with any target extension
    for (TARGET_EXTENSIONS) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }

    return false;
}

/// Checks if a directory name should be excluded from traversal.
pub fn isExcludedDir(name: []const u8) bool {
    for (EXCLUDED_DIRS) |excluded| {
        if (std.mem.eql(u8, name, excluded)) return true;
    }
    return false;
}

/// Determines if a file should be included based on filter config.
/// This is a simple pattern matcher using endsWith and indexOf.
/// Full glob matching is deferred to a later phase.
pub fn shouldIncludeFile(path: []const u8, config: FilterConfig) bool {
    // Base filter: must be a target file
    if (!isTargetFile(path)) return false;

    // If no patterns specified, include all target files
    if (config.include_patterns == null and config.exclude_patterns == null) {
        return true;
    }

    // Check exclude patterns first (exclusions override inclusions)
    if (config.exclude_patterns) |patterns| {
        for (patterns) |pattern| {
            if (matchesSimplePattern(path, pattern)) {
                return false;
            }
        }
    }

    // If include patterns specified, path must match at least one
    if (config.include_patterns) |patterns| {
        for (patterns) |pattern| {
            if (matchesSimplePattern(path, pattern)) {
                return true;
            }
        }
        return false; // Had include patterns but didn't match any
    }

    return true;
}

/// Simple pattern matching using endsWith for extension patterns (*.ext)
/// and indexOf for substring patterns. Full glob support deferred.
fn matchesSimplePattern(path: []const u8, pattern: []const u8) bool {
    // Handle extension patterns like "*.ts"
    if (std.mem.startsWith(u8, pattern, "*.")) {
        const ext = pattern[1..]; // Remove the '*'
        return std.mem.endsWith(u8, path, ext);
    }

    // Handle substring patterns
    return std.mem.indexOf(u8, path, pattern) != null;
}

// TESTS

test "isTargetFile: TypeScript files" {
    try std.testing.expect(isTargetFile("foo.ts"));
    try std.testing.expect(isTargetFile("bar.tsx"));
    try std.testing.expect(isTargetFile("path/to/file.ts"));
    try std.testing.expect(isTargetFile("component.tsx"));
}

test "isTargetFile: JavaScript files" {
    try std.testing.expect(isTargetFile("foo.js"));
    try std.testing.expect(isTargetFile("bar.jsx"));
    try std.testing.expect(isTargetFile("path/to/file.js"));
    try std.testing.expect(isTargetFile("component.jsx"));
}

test "isTargetFile: excludes declaration files" {
    try std.testing.expect(!isTargetFile("foo.d.ts"));
    try std.testing.expect(!isTargetFile("types.d.ts"));
    try std.testing.expect(!isTargetFile("global.d.tsx"));
    try std.testing.expect(!isTargetFile("path/to/declarations.d.ts"));
}

test "isTargetFile: excludes non-target extensions" {
    try std.testing.expect(!isTargetFile("foo.css"));
    try std.testing.expect(!isTargetFile("foo.zig"));
    try std.testing.expect(!isTargetFile("foo.json"));
    try std.testing.expect(!isTargetFile("foo.txt"));
    try std.testing.expect(!isTargetFile("README.md"));
}

test "isExcludedDir: common exclusions" {
    try std.testing.expect(isExcludedDir("node_modules"));
    try std.testing.expect(isExcludedDir(".git"));
    try std.testing.expect(isExcludedDir("dist"));
    try std.testing.expect(isExcludedDir("build"));
    try std.testing.expect(isExcludedDir(".next"));
    try std.testing.expect(isExcludedDir("coverage"));
    try std.testing.expect(isExcludedDir("vendor"));
}

test "isExcludedDir: source directories allowed" {
    try std.testing.expect(!isExcludedDir("src"));
    try std.testing.expect(!isExcludedDir("lib"));
    try std.testing.expect(!isExcludedDir("components"));
    try std.testing.expect(!isExcludedDir("utils"));
    try std.testing.expect(!isExcludedDir("tests"));
}

test "shouldIncludeFile: no config includes all target files" {
    const config = FilterConfig{};
    try std.testing.expect(shouldIncludeFile("foo.ts", config));
    try std.testing.expect(shouldIncludeFile("bar.js", config));
    try std.testing.expect(!shouldIncludeFile("baz.css", config));
    try std.testing.expect(!shouldIncludeFile("types.d.ts", config));
}

test "shouldIncludeFile: exclude patterns" {
    const exclude = [_][]const u8{"*.test.ts"};
    const config = FilterConfig{ .exclude_patterns = &exclude };
    try std.testing.expect(shouldIncludeFile("foo.ts", config));
    try std.testing.expect(!shouldIncludeFile("foo.test.ts", config));
    try std.testing.expect(!shouldIncludeFile("bar.test.ts", config));
}

test "shouldIncludeFile: include patterns" {
    const include = [_][]const u8{"src/"};
    const config = FilterConfig{ .include_patterns = &include };
    try std.testing.expect(shouldIncludeFile("src/foo.ts", config));
    try std.testing.expect(!shouldIncludeFile("lib/bar.ts", config));
}

test "shouldIncludeFile: exclude overrides include" {
    const include = [_][]const u8{"*.ts"};
    const exclude = [_][]const u8{"*.test.ts"};
    const config = FilterConfig{
        .include_patterns = &include,
        .exclude_patterns = &exclude,
    };
    try std.testing.expect(shouldIncludeFile("foo.ts", config));
    try std.testing.expect(!shouldIncludeFile("foo.test.ts", config));
}
