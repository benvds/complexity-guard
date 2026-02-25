const std = @import("std");
const args = @import("args.zig");
const config = @import("config.zig");

const CliArgs = args.CliArgs;
const Config = config.Config;
const OutputConfig = config.OutputConfig;
const AnalysisConfig = config.AnalysisConfig;
const FilesConfig = config.FilesConfig;

/// Merge CLI arguments into a Config struct.
/// CLI flags override config file values per CFG-07.
/// This function modifies the config in place.
pub fn mergeArgsIntoConfig(cli_args: CliArgs, cfg: *Config) void {
    // Initialize nested configs if they don't exist
    if (cfg.output == null) {
        cfg.output = OutputConfig{};
    }
    if (cfg.analysis == null) {
        cfg.analysis = AnalysisConfig{};
    }
    if (cfg.files == null) {
        cfg.files = FilesConfig{};
    }

    // Merge output options
    if (cli_args.format) |format| {
        cfg.output.?.format = format;
    }
    if (cli_args.output_file) |output_file| {
        cfg.output.?.file = output_file;
    }

    // Merge analysis options
    if (cli_args.duplication) {
        cfg.analysis.?.duplication_enabled = true;
    }
    if (cli_args.no_duplication) {
        cfg.analysis.?.no_duplication = true;
    }
    if (cli_args.threads) |threads_str| {
        // Parse thread count string to u32
        if (std.fmt.parseInt(u32, threads_str, 10)) |threads| {
            cfg.analysis.?.threads = threads;
        } else |_| {
            // Invalid thread count, ignore
        }
    }

    // Merge file patterns
    if (cli_args.include.len > 0) {
        cfg.files.?.include = cli_args.include;
    }
    if (cli_args.exclude.len > 0) {
        cfg.files.?.exclude = cli_args.exclude;
    }
}

// TESTS

test "mergeArgsIntoConfig with format flag overrides config" {
    var cfg = config.defaults();
    const cli_args = CliArgs{
        .format = "json",
        .help = false,
        .version = false,
        .init = false,
        .output_file = null,
        .config_path = null,
        .fail_on = null,
        .fail_health_below = null,
        .include = &[_][]const u8{},
        .exclude = &[_][]const u8{},
        .metrics = null,
        .no_duplication = false,
        .threads = null,
        .baseline = null,
        .verbose = false,
        .quiet = false,
        .color = false,
        .no_color = false,
        .positional_paths = &[_][]const u8{},
    };

    mergeArgsIntoConfig(cli_args, &cfg);

    try std.testing.expect(cfg.output != null);
    try std.testing.expectEqualStrings("json", cfg.output.?.format.?);
}

test "mergeArgsIntoConfig with no flags preserves config" {
    var cfg = config.defaults();
    const original_format = cfg.output.?.format.?;

    const cli_args = CliArgs{
        .help = false,
        .version = false,
        .init = false,
        .format = null,
        .output_file = null,
        .config_path = null,
        .fail_on = null,
        .fail_health_below = null,
        .include = &[_][]const u8{},
        .exclude = &[_][]const u8{},
        .metrics = null,
        .no_duplication = false,
        .threads = null,
        .baseline = null,
        .verbose = false,
        .quiet = false,
        .color = false,
        .no_color = false,
        .positional_paths = &[_][]const u8{},
    };

    mergeArgsIntoConfig(cli_args, &cfg);

    try std.testing.expectEqualStrings(original_format, cfg.output.?.format.?);
}

test "mergeArgsIntoConfig with threads parses to u32" {
    var cfg = config.defaults();
    const cli_args = CliArgs{
        .help = false,
        .version = false,
        .init = false,
        .format = null,
        .output_file = null,
        .config_path = null,
        .fail_on = null,
        .fail_health_below = null,
        .include = &[_][]const u8{},
        .exclude = &[_][]const u8{},
        .metrics = null,
        .no_duplication = false,
        .threads = "8",
        .baseline = null,
        .verbose = false,
        .quiet = false,
        .color = false,
        .no_color = false,
        .positional_paths = &[_][]const u8{},
    };

    mergeArgsIntoConfig(cli_args, &cfg);

    try std.testing.expect(cfg.analysis != null);
    try std.testing.expectEqual(@as(?u32, 8), cfg.analysis.?.threads);
}

test "mergeArgsIntoConfig with --duplication sets duplication_enabled" {
    var cfg = config.defaults();
    const cli_args = CliArgs{
        .duplication = true,
    };

    mergeArgsIntoConfig(cli_args, &cfg);

    try std.testing.expect(cfg.analysis != null);
    try std.testing.expectEqual(@as(?bool, true), cfg.analysis.?.duplication_enabled);
}

test "mergeArgsIntoConfig with include and exclude patterns" {
    var cfg = config.defaults();
    const include_patterns = [_][]const u8{ "src/**/*.ts", "lib/**/*.ts" };
    const exclude_patterns = [_][]const u8{ "**/*.test.ts" };

    const cli_args = CliArgs{
        .help = false,
        .version = false,
        .init = false,
        .format = null,
        .output_file = null,
        .config_path = null,
        .fail_on = null,
        .fail_health_below = null,
        .include = &include_patterns,
        .exclude = &exclude_patterns,
        .metrics = null,
        .no_duplication = false,
        .threads = null,
        .baseline = null,
        .verbose = false,
        .quiet = false,
        .color = false,
        .no_color = false,
        .positional_paths = &[_][]const u8{},
    };

    mergeArgsIntoConfig(cli_args, &cfg);

    try std.testing.expect(cfg.files != null);
    try std.testing.expect(cfg.files.?.include != null);
    try std.testing.expectEqual(@as(usize, 2), cfg.files.?.include.?.len);
    try std.testing.expect(cfg.files.?.exclude != null);
    try std.testing.expectEqual(@as(usize, 1), cfg.files.?.exclude.?.len);
}
