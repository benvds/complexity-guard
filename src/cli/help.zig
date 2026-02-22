const std = @import("std");

/// Print compact ripgrep-style help text grouped by category.
pub fn printHelp(writer: anytype) !void {
    const help_text =
        \\complexityguard [OPTIONS] [PATH]...
        \\
        \\Analyze code complexity for TypeScript/JavaScript files.
        \\
        \\GENERAL:
        \\  -h, --help                 Show this help message
        \\      --version              Show version information
        \\      --init                 Run interactive config setup
        \\
        \\OUTPUT:
        \\  -f, --format <FORMAT>      Output format [console, json, sarif, html]
        \\  -o, --output <FILE>        Write report to file
        \\      --color                Force color output
        \\      --no-color             Disable color output
        \\  -q, --quiet                Suppress non-error output
        \\  -v, --verbose              Show detailed output
        \\
        \\ANALYSIS:
        \\      --metrics <LIST>       Comma-separated metrics to enable
        \\      --duplication          Enable cross-file duplication detection (disabled by default)
        \\      --no-duplication       Skip duplication analysis
        \\      --threads <N>          Thread count (default: CPU count)
        \\
        \\FILES:
        \\      --include <GLOB>       Include files matching pattern (repeatable)
        \\      --exclude <GLOB>       Exclude files matching pattern (repeatable)
        \\
        \\THRESHOLDS:
        \\      --fail-on <LEVEL>      Exit non-zero on: warning, error, none
        \\      --fail-health-below <N>  Exit non-zero if health score below N
        \\
        \\CONFIG:
        \\  -c, --config <FILE>        Use specific config file
        \\
        \\Run 'complexityguard --init' to create a config file interactively.
        \\
    ;
    try writer.writeAll(help_text);
}

/// Print version information.
pub fn printVersion(writer: anytype) !void {
    const types = @import("../core/types.zig");
    try writer.print("complexityguard {s}\n", .{types.version});
}

/// Determine whether color output should be used based on flags and environment.
/// Priority: --no-color > --color > NO_COLOR env > FORCE_COLOR/YES_COLOR env > TTY detection
pub fn shouldUseColor(force_color: bool, no_color: bool) bool {
    // Explicit --no-color always wins
    if (no_color) return false;

    // Explicit --color forces color
    if (force_color) return true;

    // Check NO_COLOR environment variable (https://no-color.org/)
    if (std.process.hasEnvVarConstant("NO_COLOR")) return false;

    // Check FORCE_COLOR or YES_COLOR environment variables
    if (std.process.hasEnvVarConstant("FORCE_COLOR")) return true;
    if (std.process.hasEnvVarConstant("YES_COLOR")) return true;

    // Default: detect TTY on stdout
    const config = std.io.tty.detectConfig(std.fs.File.stdout());
    return config != .no_color;
}

// TESTS

test "printHelp writes non-empty content with all groups" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    try printHelp(buffer.writer(allocator));

    const output = buffer.items;
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "GENERAL:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "OUTPUT:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "ANALYSIS:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "FILES:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "THRESHOLDS:") != null);
}

test "printVersion contains complexityguard and version string" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8).empty;
    defer buffer.deinit(allocator);

    try printVersion(buffer.writer(allocator));

    const output = buffer.items;
    try std.testing.expect(std.mem.indexOf(u8, output, "complexityguard") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "0.1.0") != null);
}

test "shouldUseColor returns false when no_color is true" {
    try std.testing.expectEqual(false, shouldUseColor(false, true));
    try std.testing.expectEqual(false, shouldUseColor(true, true));
}

test "shouldUseColor returns true when force_color is true and no_color is false" {
    try std.testing.expectEqual(true, shouldUseColor(true, false));
}
