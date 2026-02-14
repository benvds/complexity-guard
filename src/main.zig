const std = @import("std");
const args_mod = @import("cli/args.zig");
const config_mod = @import("cli/config.zig");
const discovery = @import("cli/discovery.zig");
const help = @import("cli/help.zig");
const errors = @import("cli/errors.zig");
const merge = @import("cli/merge.zig");
const init = @import("cli/init.zig");

const version = "0.1.0";

pub fn main() !void {
    // Set up arena allocator for CLI lifecycle
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Get stdout and stderr with buffers
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    // Parse CLI arguments
    const cli_args = args_mod.parseArgs(arena_allocator) catch |err| {
        try stderr.print("error: failed to parse arguments: {s}\n", .{@errorName(err)});
        std.process.exit(2);
    };

    // Handle --help
    if (cli_args.help) {
        try help.printHelp(stdout);
        return;
    }

    // Handle --version
    if (cli_args.version) {
        try help.printVersion(stdout);
        return;
    }

    // Handle --init
    if (cli_args.init) {
        try init.runInit(arena_allocator);
        return;
    }

    // Discover config path
    const config_path = discovery.discoverConfigPath(arena_allocator, cli_args.config_path) catch |err| {
        if (err == error.ConfigFileNotFound) {
            try stderr.print("error: config file not found: {s}\n", .{cli_args.config_path.?});
            std.process.exit(3);
        }
        return err;
    };

    // Load or use default config
    var cfg: config_mod.Config = undefined;
    if (config_path) |path| {
        defer arena_allocator.free(path);

        // Detect format
        const format = discovery.detectConfigFormat(path);

        // Load config
        cfg = config_mod.loadConfig(arena_allocator, path, format) catch |err| {
            try stderr.print("error: invalid config at {s}: {s}\n", .{ path, @errorName(err) });
            std.process.exit(3);
        };

        // Validate config
        config_mod.validate(cfg) catch |err| {
            try stderr.print("error: config validation failed: {s}\n", .{@errorName(err)});
            std.process.exit(3);
        };
    } else {
        cfg = config_mod.defaults();
    }

    // Merge CLI args into config
    merge.mergeArgsIntoConfig(cli_args, &cfg);

    // Determine analysis paths
    const analysis_paths = if (cli_args.positional_paths.len > 0)
        cli_args.positional_paths
    else
        &[_][]const u8{"."};

    // Print summary of what would be analyzed (placeholder for Phase 3)
    try stdout.writeAll("Analyzing ");
    for (analysis_paths, 0..) |path, i| {
        if (i > 0) try stdout.writeAll(", ");
        try stdout.writeAll(path);
    }
    try stdout.writeAll("... (analysis not yet implemented)\n");
}

// Test that version constant exists and is valid
test "version format" {
    try std.testing.expect(version.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, version, "0."));
}

// Import core modules to ensure their tests are discovered
test {
    _ = @import("core/types.zig");
    _ = @import("core/json.zig");
    _ = @import("test_helpers.zig");
    _ = @import("cli/config.zig");
    _ = @import("cli/args.zig");
    _ = @import("cli/help.zig");
    _ = @import("cli/errors.zig");
    _ = @import("cli/discovery.zig");
    _ = @import("cli/merge.zig");
    _ = @import("cli/init.zig");
    _ = @import("discovery/filter.zig");
    _ = @import("discovery/walker.zig");
    _ = @import("parser/tree_sitter.zig");
}
