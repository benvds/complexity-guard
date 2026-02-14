const std = @import("std");
const builtin = @import("builtin");
const errors = @import("errors.zig");

/// Parsed CLI arguments structure.
/// All fields correspond to the CLI flags defined in CLI-01 through CLI-12.
pub const CliArgs = struct {
    help: bool = false,
    version: bool = false,
    init: bool = false,
    format: ?[]const u8 = null,
    output_file: ?[]const u8 = null,
    config_path: ?[]const u8 = null,
    fail_on: ?[]const u8 = null,
    fail_health_below: ?[]const u8 = null,
    include: []const []const u8 = &[_][]const u8{},
    exclude: []const []const u8 = &[_][]const u8{},
    metrics: ?[]const u8 = null,
    no_duplication: bool = false,
    threads: ?[]const u8 = null,
    baseline: ?[]const u8 = null,
    verbose: bool = false,
    quiet: bool = false,
    color: bool = false,
    no_color: bool = false,
    positional_paths: []const []const u8 = &[_][]const u8{},
};

/// Parse CLI arguments from process args.
pub fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    // Skip executable name
    _ = args_iter.next();

    var arg_list = std.ArrayList([]const u8).empty;
    defer arg_list.deinit(allocator);

    while (args_iter.next()) |arg| {
        try arg_list.append(allocator, arg);
    }

    return parseArgsFromSlice(allocator, arg_list.items);
}

/// Parse CLI arguments from an explicit arg slice (for testing).
pub fn parseArgsFromSlice(allocator: std.mem.Allocator, args: []const []const u8) !CliArgs {
    var cli_args = CliArgs{};
    var include_list = std.ArrayList([]const u8).empty;
    defer include_list.deinit(allocator);
    var exclude_list = std.ArrayList([]const u8).empty;
    defer exclude_list.deinit(allocator);
    var positional_list = std.ArrayList([]const u8).empty;
    defer positional_list.deinit(allocator);

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        // Long flags with values
        if (std.mem.startsWith(u8, arg, "--")) {
            const flag = arg[2..];

            // Boolean flags
            if (std.mem.eql(u8, flag, "help")) {
                cli_args.help = true;
            } else if (std.mem.eql(u8, flag, "version")) {
                cli_args.version = true;
            } else if (std.mem.eql(u8, flag, "init")) {
                cli_args.init = true;
            } else if (std.mem.eql(u8, flag, "no-duplication")) {
                cli_args.no_duplication = true;
            } else if (std.mem.eql(u8, flag, "verbose")) {
                cli_args.verbose = true;
            } else if (std.mem.eql(u8, flag, "quiet")) {
                cli_args.quiet = true;
            } else if (std.mem.eql(u8, flag, "color")) {
                cli_args.color = true;
            } else if (std.mem.eql(u8, flag, "no-color")) {
                cli_args.no_color = true;
            }
            // Value flags
            else if (std.mem.eql(u8, flag, "format")) {
                i += 1;
                if (i < args.len) cli_args.format = args[i];
            } else if (std.mem.eql(u8, flag, "output")) {
                i += 1;
                if (i < args.len) cli_args.output_file = args[i];
            } else if (std.mem.eql(u8, flag, "config")) {
                i += 1;
                if (i < args.len) cli_args.config_path = args[i];
            } else if (std.mem.eql(u8, flag, "fail-on")) {
                i += 1;
                if (i < args.len) cli_args.fail_on = args[i];
            } else if (std.mem.eql(u8, flag, "fail-health-below")) {
                i += 1;
                if (i < args.len) cli_args.fail_health_below = args[i];
            } else if (std.mem.eql(u8, flag, "metrics")) {
                i += 1;
                if (i < args.len) cli_args.metrics = args[i];
            } else if (std.mem.eql(u8, flag, "threads")) {
                i += 1;
                if (i < args.len) cli_args.threads = args[i];
            } else if (std.mem.eql(u8, flag, "baseline")) {
                i += 1;
                if (i < args.len) cli_args.baseline = args[i];
            } else if (std.mem.eql(u8, flag, "include")) {
                i += 1;
                if (i < args.len) try include_list.append(allocator, args[i]);
            } else if (std.mem.eql(u8, flag, "exclude")) {
                i += 1;
                if (i < args.len) try exclude_list.append(allocator, args[i]);
            } else {
                // Unknown long flag - provide did-you-mean suggestion
                const err_msg = try errors.formatUnknownFlagError(allocator, arg);
                defer allocator.free(err_msg);
                if (!builtin.is_test) std.debug.print("{s}\n", .{err_msg});
                return error.UnknownFlag;
            }
        }
        // Short flags
        else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            const flag_char = arg[1];

            if (flag_char == 'h') {
                cli_args.help = true;
            } else if (flag_char == 'v') {
                cli_args.verbose = true;
            } else if (flag_char == 'q') {
                cli_args.quiet = true;
            } else if (flag_char == 'f') {
                i += 1;
                if (i < args.len) cli_args.format = args[i];
            } else if (flag_char == 'o') {
                i += 1;
                if (i < args.len) cli_args.output_file = args[i];
            } else if (flag_char == 'c') {
                i += 1;
                if (i < args.len) cli_args.config_path = args[i];
            } else {
                // Unknown short flag
                const err_msg = try errors.formatUnknownFlagError(allocator, arg);
                defer allocator.free(err_msg);
                if (!builtin.is_test) std.debug.print("{s}\n", .{err_msg});
                return error.UnknownFlag;
            }
        }
        // Positional arguments
        else {
            try positional_list.append(allocator, arg);
        }
    }

    // Convert lists to owned slices
    if (include_list.items.len > 0) {
        cli_args.include = try allocator.dupe([]const u8, include_list.items);
    }
    if (exclude_list.items.len > 0) {
        cli_args.exclude = try allocator.dupe([]const u8, exclude_list.items);
    }
    if (positional_list.items.len > 0) {
        cli_args.positional_paths = try allocator.dupe([]const u8, positional_list.items);
    }

    return cli_args;
}

// TESTS

test "parse --format json sets format" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--format", "json" };
    const cli_args = try parseArgsFromSlice(allocator, &args);
    defer allocator.free(cli_args.include);
    defer allocator.free(cli_args.exclude);
    defer allocator.free(cli_args.positional_paths);

    try std.testing.expect(cli_args.format != null);
    try std.testing.expectEqualStrings("json", cli_args.format.?);
}

test "parse --verbose sets verbose flag" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"--verbose"};
    const cli_args = try parseArgsFromSlice(allocator, &args);
    defer allocator.free(cli_args.include);
    defer allocator.free(cli_args.exclude);
    defer allocator.free(cli_args.positional_paths);

    try std.testing.expectEqual(true, cli_args.verbose);
}

test "parse -f json -o report.json sets both" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "-f", "json", "-o", "report.json" };
    const cli_args = try parseArgsFromSlice(allocator, &args);
    defer allocator.free(cli_args.include);
    defer allocator.free(cli_args.exclude);
    defer allocator.free(cli_args.positional_paths);

    try std.testing.expect(cli_args.format != null);
    try std.testing.expectEqualStrings("json", cli_args.format.?);
    try std.testing.expect(cli_args.output_file != null);
    try std.testing.expectEqualStrings("report.json", cli_args.output_file.?);
}

test "parse positional paths captures them" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "src/", "lib/" };
    const cli_args = try parseArgsFromSlice(allocator, &args);
    defer allocator.free(cli_args.include);
    defer allocator.free(cli_args.exclude);
    defer allocator.free(cli_args.positional_paths);

    try std.testing.expectEqual(@as(usize, 2), cli_args.positional_paths.len);
    try std.testing.expectEqualStrings("src/", cli_args.positional_paths[0]);
    try std.testing.expectEqualStrings("lib/", cli_args.positional_paths[1]);
}

test "parse with no args returns defaults" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{};
    const cli_args = try parseArgsFromSlice(allocator, &args);
    defer allocator.free(cli_args.include);
    defer allocator.free(cli_args.exclude);
    defer allocator.free(cli_args.positional_paths);

    try std.testing.expectEqual(false, cli_args.help);
    try std.testing.expectEqual(false, cli_args.version);
    try std.testing.expectEqual(false, cli_args.verbose);
    try std.testing.expectEqual(false, cli_args.quiet);
    try std.testing.expect(cli_args.format == null);
    try std.testing.expect(cli_args.output_file == null);
    try std.testing.expectEqual(@as(usize, 0), cli_args.positional_paths.len);
}

test "parse unknown flag returns error" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"--foramt"};
    const result = parseArgsFromSlice(allocator, &args);
    try std.testing.expectError(error.UnknownFlag, result);
}
