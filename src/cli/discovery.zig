const std = @import("std");

/// Supported config file formats.
pub const ConfigFormat = enum {
    json,
    toml,
};

/// Config filenames checked in priority order (per locked decision).
const config_filenames = [_][]const u8{
    ".complexityguard.json",
    "complexityguard.config.json",
    ".complexityguard.toml",
    "complexityguard.config.toml",
};

/// User-level config paths checked in priority order.
const user_config_paths = [_][]const u8{
    "complexityguard/config.json",
    "complexityguard/config.toml",
};

/// Maximum directory depth to prevent infinite loops.
const max_search_depth = 100;

/// Discovers config file path using upward search with .git boundary,
/// XDG fallback, or explicit override.
///
/// Search order:
/// 1. If explicit_path is provided, return it (after verifying existence)
/// 2. Search upward from CWD for config files, stop at .git boundary
/// 3. Fall back to user config in XDG config directory
/// 4. Return null if no config found
///
/// Returns owned string that caller must free.
pub fn discoverConfigPath(allocator: std.mem.Allocator, explicit_path: ?[]const u8) !?[]const u8 {
    // If explicit path provided, verify it exists
    if (explicit_path) |path| {
        std.fs.cwd().access(path, .{}) catch {
            return error.ConfigFileNotFound;
        };
        return try allocator.dupe(u8, path);
    }

    // Try project config (upward search)
    if (try searchProjectConfig(allocator)) |path| {
        return path;
    }

    // Try user config (XDG fallback)
    if (try searchUserConfig(allocator)) |path| {
        return path;
    }

    // No config found
    return null;
}

/// Searches upward from CWD for config files, stopping at .git boundary.
fn searchProjectConfig(allocator: std.mem.Allocator) !?[]const u8 {
    var current_dir = try std.process.getCwdAlloc(allocator);
    defer allocator.free(current_dir);

    var iterations: usize = 0;
    while (iterations < max_search_depth) : (iterations += 1) {
        // Check for config files in priority order
        for (config_filenames) |filename| {
            const config_path = try std.fs.path.join(allocator, &.{ current_dir, filename });
            defer allocator.free(config_path);

            std.fs.cwd().access(config_path, .{}) catch {
                continue; // File doesn't exist, try next
            };

            // Found config file
            return try allocator.dupe(u8, config_path);
        }

        // Check if we hit .git boundary
        const git_path = try std.fs.path.join(allocator, &.{ current_dir, ".git" });
        defer allocator.free(git_path);

        var is_git_boundary = false;
        std.fs.cwd().access(git_path, .{}) catch {
            // .git doesn't exist, continue search
        };
        // Check if .git exists
        const git_stat = std.fs.cwd().statFile(git_path) catch null;
        if (git_stat != null) {
            is_git_boundary = true;
        }

        if (is_git_boundary) {
            // Hit git boundary, stop searching
            return null;
        }

        // Move to parent directory
        const parent = std.fs.path.dirname(current_dir) orelse break;
        const parent_copy = try allocator.dupe(u8, parent);
        allocator.free(current_dir);
        current_dir = parent_copy;
    }

    return null;
}

/// Searches for user-level config in XDG config directory.
fn searchUserConfig(allocator: std.mem.Allocator) !?[]const u8 {
    const config_home = try getConfigHome(allocator) orelse {
        return null; // No XDG config directory
    };
    defer allocator.free(config_home);

    for (user_config_paths) |relative_path| {
        const full_path = try std.fs.path.join(allocator, &.{ config_home, relative_path });
        defer allocator.free(full_path);

        std.fs.cwd().access(full_path, .{}) catch {
            continue; // File doesn't exist, try next
        };

        // Found user config
        return try allocator.dupe(u8, full_path);
    }

    return null;
}

/// Gets XDG config home directory.
/// Returns $XDG_CONFIG_HOME if set, otherwise ~/.config on Unix or %APPDATA% on Windows.
fn getConfigHome(allocator: std.mem.Allocator) !?[]const u8 {
    // Check XDG_CONFIG_HOME environment variable
    const xdg_config = std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => |e| return e,
    };
    if (xdg_config) |val| return val;

    // Fall back to HOME/.config on Unix-like systems
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => |e| return e,
    };
    if (home) |home_val| {
        defer allocator.free(home_val);
        return try std.fs.path.join(allocator, &.{ home_val, ".config" });
    }

    // Fall back to APPDATA on Windows
    const appdata = std.process.getEnvVarOwned(allocator, "APPDATA") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => |e| return e,
    };
    if (appdata) |val| return val;

    return null;
}

/// Detects config format based on file extension.
pub fn detectConfigFormat(path: []const u8) ConfigFormat {
    if (std.mem.endsWith(u8, path, ".json")) {
        return .json;
    } else if (std.mem.endsWith(u8, path, ".toml")) {
        return .toml;
    }
    // Default to JSON if extension is unclear
    return .json;
}

// TESTS

test "detectConfigFormat returns .json for .json files" {
    try std.testing.expectEqual(ConfigFormat.json, detectConfigFormat(".complexityguard.json"));
    try std.testing.expectEqual(ConfigFormat.json, detectConfigFormat("complexityguard.config.json"));
    try std.testing.expectEqual(ConfigFormat.json, detectConfigFormat("/path/to/config.json"));
}

test "detectConfigFormat returns .toml for .toml files" {
    try std.testing.expectEqual(ConfigFormat.toml, detectConfigFormat(".complexityguard.toml"));
    try std.testing.expectEqual(ConfigFormat.toml, detectConfigFormat("complexityguard.config.toml"));
    try std.testing.expectEqual(ConfigFormat.toml, detectConfigFormat("/path/to/config.toml"));
}

test "discoverConfigPath with explicit path returns that path" {
    const allocator = std.testing.allocator;

    // Create temp file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const config_content = "{}";
    try tmp_dir.dir.writeFile(.{ .sub_path = "test-config.json", .data = config_content });

    // Get real path
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    const explicit_path = try std.fs.path.join(allocator, &.{ tmp_path, "test-config.json" });
    defer allocator.free(explicit_path);

    // Test discovery
    const discovered = try discoverConfigPath(allocator, explicit_path);
    try std.testing.expect(discovered != null);
    defer allocator.free(discovered.?);

    try std.testing.expectEqualStrings(explicit_path, discovered.?);
}

test "discoverConfigPath returns null when no config exists" {
    const allocator = std.testing.allocator;

    // Create empty temp dir and change to it
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create .git to act as boundary
    try tmp_dir.dir.makeDir(".git");

    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    // Test discovery (should return null)
    const discovered = try discoverConfigPath(allocator, null);
    try std.testing.expect(discovered == null);
}

test "upward search stops at .git boundary" {
    const allocator = std.testing.allocator;

    // Create directory structure:
    // temp/
    //   config.json (this should NOT be found)
    //   project/
    //     .git/
    //     subdir/ (we'll run from here)

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create config at root
    try tmp_dir.dir.writeFile(.{ .sub_path = ".complexityguard.json", .data = "{}" });

    // Create project with .git boundary
    try tmp_dir.dir.makeDir("project");
    try tmp_dir.dir.makeDir("project/.git");
    try tmp_dir.dir.makeDir("project/subdir");

    // Change to subdir
    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, "project/subdir");
    defer allocator.free(tmp_path);

    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    // Search should return null because .git boundary prevents finding parent config
    const discovered = try discoverConfigPath(allocator, null);
    try std.testing.expect(discovered == null);
}
