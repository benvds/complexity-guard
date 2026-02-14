const std = @import("std");

const version = "0.1.0";

pub fn main() !void {
    // Set up arena allocator for CLI lifecycle
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Get stdout writer with buffer
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Print version string
    try stdout.print("complexity-guard v{s}\n", .{version});

    // Flush output
    try stdout.flush();
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
}
