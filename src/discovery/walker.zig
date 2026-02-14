const std = @import("std");
const filter = @import("filter.zig");

const Allocator = std.mem.Allocator;

/// Result of file discovery operation.
pub const DiscoveryResult = struct {
    files: [][]const u8, // owned paths (caller must free each + slice)
    skipped_count: u32, // files that matched extension but were excluded
    dir_count: u32, // directories traversed

    /// Frees all memory associated with this result.
    pub fn deinit(self: *DiscoveryResult, allocator: Allocator) void {
        for (self.files) |path| {
            allocator.free(path);
        }
        allocator.free(self.files);
    }
};

/// Errors that can occur during file discovery.
pub const DiscoveryError = error{
    DirectoryNotFound,
    PermissionDenied,
} || std.mem.Allocator.Error || std.fs.Dir.OpenError;

/// Discovers source files in the given paths (files or directories).
/// For directories, walks recursively and filters by extension and exclusion rules.
/// Returns owned file paths that must be freed by caller using result.deinit().
pub fn discoverFiles(
    allocator: Allocator,
    paths: []const []const u8,
    filter_config: filter.FilterConfig,
) DiscoveryError!DiscoveryResult {
    var files = std.ArrayList([]const u8).empty;
    defer {
        // Clean up on error
        for (files.items) |path| allocator.free(path);
        files.deinit(allocator);
    }

    var skipped_count: u32 = 0;
    var dir_count: u32 = 0;

    for (paths) |path| {
        // Try to open as directory first
        if (std.fs.cwd().openDir(path, .{})) |dir| {
            var d = dir;
            d.close();
            // It's a directory, walk it
            const discovered = try walkDirectory(
                allocator,
                path,
                filter_config,
            );
            defer allocator.free(discovered.file_list);

            skipped_count += discovered.skipped;
            dir_count += discovered.dirs;

            // Transfer ownership of discovered paths to our list
            for (discovered.file_list) |file_path| {
                try files.append(allocator, file_path);
            }
        } else |_| {
            // Not a directory, treat as a file
            if (filter.shouldIncludeFile(path, filter_config)) {
                const owned_path = try allocator.dupe(u8, path);
                try files.append(allocator, owned_path);
            } else {
                skipped_count += 1;
            }
        }
    }

    // Transfer ownership to result
    const owned_slice = try files.toOwnedSlice(allocator);

    return DiscoveryResult{
        .files = owned_slice,
        .skipped_count = skipped_count,
        .dir_count = dir_count,
    };
}

/// Internal result for directory walking.
const WalkResult = struct {
    file_list: [][]const u8, // owned paths
    skipped: u32,
    dirs: u32,
};

/// Walks a directory recursively, collecting matching files.
fn walkDirectory(
    allocator: Allocator,
    base_path: []const u8,
    filter_config: filter.FilterConfig,
) !WalkResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var files = std.ArrayList([]const u8).empty;
    defer {
        for (files.items) |path| allocator.free(path);
        files.deinit(allocator);
    }

    var skipped: u32 = 0;
    var dirs: u32 = 0;

    // Open the directory
    var dir = std.fs.cwd().openDir(base_path, .{ .iterate = true }) catch |err| {
        if (err == error.AccessDenied) return error.PermissionDenied;
        return error.DirectoryNotFound;
    };
    defer dir.close();

    // Create walker
    var walker = try dir.walk(arena_alloc);
    defer walker.deinit();

    // Iterate through entries
    while (try walker.next()) |entry| {
        // Skip non-files
        if (entry.kind != .file) {
            if (entry.kind == .directory) {
                dirs += 1;
            }
            continue;
        }

        // Check if path contains excluded directory
        if (containsExcludedDir(entry.path)) {
            skipped += 1;
            continue;
        }

        // Build full path relative to cwd
        const full_path = if (std.mem.eql(u8, base_path, "."))
            try allocator.dupe(u8, entry.path)
        else
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, entry.path });

        // Check if file should be included
        if (filter.shouldIncludeFile(full_path, filter_config)) {
            try files.append(allocator, full_path);
        } else {
            allocator.free(full_path);
            skipped += 1;
        }
    }

    const owned_slice = try files.toOwnedSlice(allocator);

    return WalkResult{
        .file_list = owned_slice,
        .skipped = skipped,
        .dirs = dirs,
    };
}

/// Checks if a path contains any excluded directory component.
fn containsExcludedDir(path: []const u8) bool {
    var it = std.mem.splitScalar(u8, path, '/');
    while (it.next()) |component| {
        if (filter.isExcludedDir(component)) {
            return true;
        }
    }
    return false;
}

// TESTS

test "discoverFiles: TypeScript directory" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    var result = try discoverFiles(allocator, &[_][]const u8{"tests/fixtures/typescript"}, config);
    defer result.deinit(allocator);

    // 5 .ts files + 1 .tsx file + 1 syntax_error.ts = 7 files
    try std.testing.expectEqual(@as(usize, 7), result.files.len);

    // Verify all files are .ts or .tsx files
    for (result.files) |path| {
        const is_ts = std.mem.endsWith(u8, path, ".ts") or std.mem.endsWith(u8, path, ".tsx");
        try std.testing.expect(is_ts);
        try std.testing.expect(!std.mem.endsWith(u8, path, ".d.ts"));
    }
}

test "discoverFiles: JavaScript directory" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    var result = try discoverFiles(allocator, &[_][]const u8{"tests/fixtures/javascript"}, config);
    defer result.deinit(allocator);

    // 2 .js files + 1 .jsx file = 3 files
    try std.testing.expectEqual(@as(usize, 3), result.files.len);

    // Verify all files are .js or .jsx files
    for (result.files) |path| {
        const is_js = std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".jsx");
        try std.testing.expect(is_js);
    }
}

test "discoverFiles: all fixtures" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    var result = try discoverFiles(allocator, &[_][]const u8{"tests/fixtures"}, config);
    defer result.deinit(allocator);

    // Should find 6 .ts + 1 .tsx + 2 .js + 1 .jsx = 10 files
    try std.testing.expectEqual(@as(usize, 10), result.files.len);
}

test "discoverFiles: single file path" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    var result = try discoverFiles(
        allocator,
        &[_][]const u8{"tests/fixtures/typescript/simple_function.ts"},
        config,
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), result.files.len);
    try std.testing.expect(std.mem.endsWith(u8, result.files[0], "simple_function.ts"));
}

test "discoverFiles: empty directory" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    // Create a temporary empty directory
    const test_dir = ".zig-cache/test-empty-dir";
    std.fs.cwd().makeDir(test_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    var result = try discoverFiles(allocator, &[_][]const u8{test_dir}, config);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), result.files.len);
}

test "discoverFiles: exclude pattern" {
    const allocator = std.testing.allocator;

    const exclude = [_][]const u8{"simple_function"};
    const config = filter.FilterConfig{ .exclude_patterns = &exclude };

    var result = try discoverFiles(allocator, &[_][]const u8{"tests/fixtures/typescript"}, config);
    defer result.deinit(allocator);

    // Should find 6 files (7 total - 1 excluded)
    try std.testing.expectEqual(@as(usize, 6), result.files.len);

    // Verify simple_function.ts is not in results
    for (result.files) |path| {
        try std.testing.expect(!std.mem.endsWith(u8, path, "simple_function.ts"));
    }
}

test "discoverFiles: memory cleanup" {
    const allocator = std.testing.allocator;
    const config = filter.FilterConfig{};

    var result = try discoverFiles(allocator, &[_][]const u8{"tests/fixtures/typescript"}, config);
    defer result.deinit(allocator);

    // Verify we got files
    try std.testing.expect(result.files.len > 0);

    // Testing allocator will catch leaks automatically
}

test "containsExcludedDir: detects node_modules" {
    try std.testing.expect(containsExcludedDir("node_modules/package/file.js"));
    try std.testing.expect(containsExcludedDir("src/node_modules/file.js"));
    try std.testing.expect(!containsExcludedDir("src/components/file.js"));
}

test "containsExcludedDir: detects .git" {
    try std.testing.expect(containsExcludedDir(".git/config"));
    try std.testing.expect(containsExcludedDir("project/.git/file.js"));
    try std.testing.expect(!containsExcludedDir("src/file.js"));
}
