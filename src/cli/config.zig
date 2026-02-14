const std = @import("std");

/// Top-level configuration structure matching locked schema.
/// All fields are optional to support partial configs and defaults.
pub const Config = struct {
    output: ?OutputConfig = null,
    analysis: ?AnalysisConfig = null,
    files: ?FilesConfig = null,
    weights: ?WeightsConfig = null,
    overrides: ?[]OverrideConfig = null,
};

/// Output format and destination configuration.
pub const OutputConfig = struct {
    format: ?[]const u8 = null, // "console", "json", "sarif", "html"
    file: ?[]const u8 = null, // output file path
};

/// Analysis behavior configuration.
pub const AnalysisConfig = struct {
    metrics: ?[]const []const u8 = null, // ["cyclomatic", "cognitive", "halstead"]
    thresholds: ?ThresholdsConfig = null,
    no_duplication: ?bool = null,
    threads: ?u32 = null,
};

/// Thresholds organized by metric type.
pub const ThresholdsConfig = struct {
    cyclomatic: ?ThresholdPair = null,
    cognitive: ?ThresholdPair = null,
    halstead_volume: ?ThresholdPair = null,
    halstead_difficulty: ?ThresholdPair = null,
    nesting_depth: ?ThresholdPair = null,
    line_count: ?ThresholdPair = null,
    params_count: ?ThresholdPair = null,
};

/// Warning and error threshold pair for a single metric.
/// Note: "error" is a Zig keyword, so we use @"error" syntax.
/// In JSON/TOML files, the field will be called "error".
pub const ThresholdPair = struct {
    warning: ?u32 = null,
    @"error": ?u32 = null,
};

/// File inclusion/exclusion patterns.
pub const FilesConfig = struct {
    include: ?[]const []const u8 = null,
    exclude: ?[]const []const u8 = null,
};

/// Weights for composite score calculation.
pub const WeightsConfig = struct {
    cyclomatic: ?f64 = null,
    cognitive: ?f64 = null,
    duplication: ?f64 = null,
    halstead: ?f64 = null,
    structural: ?f64 = null,
};

/// ESLint-style per-path override configuration.
pub const OverrideConfig = struct {
    files: []const []const u8, // glob patterns (required)
    analysis: ?AnalysisConfig = null, // reuses AnalysisConfig
};

/// Returns a Config with sensible default values.
pub fn defaults() Config {
    const default_metrics = [_][]const u8{
        "cyclomatic",
        "cognitive",
        "halstead",
        "nesting",
        "line_count",
        "params_count",
    };

    return Config{
        .output = OutputConfig{
            .format = "console",
            .file = null,
        },
        .analysis = AnalysisConfig{
            .metrics = &default_metrics,
            .thresholds = null,
            .no_duplication = false,
            .threads = null, // null = use CPU count
        },
        .files = null,
        .weights = WeightsConfig{
            .cognitive = 0.30,
            .cyclomatic = 0.20,
            .duplication = 0.20,
            .halstead = 0.15,
            .structural = 0.15,
        },
        .overrides = null,
    };
}

// TESTS

test "Config can be created with all null fields" {
    const config = Config{};
    try std.testing.expect(config.output == null);
    try std.testing.expect(config.analysis == null);
    try std.testing.expect(config.files == null);
    try std.testing.expect(config.weights == null);
    try std.testing.expect(config.overrides == null);
}

test "defaults() returns expected default values" {
    const config = defaults();

    // Check output defaults
    try std.testing.expect(config.output != null);
    try std.testing.expectEqualStrings("console", config.output.?.format.?);
    try std.testing.expect(config.output.?.file == null);

    // Check analysis defaults
    try std.testing.expect(config.analysis != null);
    try std.testing.expect(config.analysis.?.metrics != null);
    try std.testing.expectEqual(@as(usize, 6), config.analysis.?.metrics.?.len);
    try std.testing.expectEqual(@as(?bool, false), config.analysis.?.no_duplication);

    // Check weights defaults
    try std.testing.expect(config.weights != null);
    try std.testing.expectEqual(@as(?f64, 0.30), config.weights.?.cognitive);
    try std.testing.expectEqual(@as(?f64, 0.20), config.weights.?.cyclomatic);
    try std.testing.expectEqual(@as(?f64, 0.20), config.weights.?.duplication);
    try std.testing.expectEqual(@as(?f64, 0.15), config.weights.?.halstead);
    try std.testing.expectEqual(@as(?f64, 0.15), config.weights.?.structural);
}

test "Config struct is JSON serializable and parseable" {
    const allocator = std.testing.allocator;

    // Create a simple config for testing JSON compatibility
    const config = Config{
        .output = OutputConfig{
            .format = "json",
            .file = null,
        },
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = null,
            .no_duplication = true,
            .threads = 4,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };

    // Serialize to JSON
    const json_string = try std.json.Stringify.valueAlloc(allocator, config, .{});
    defer allocator.free(json_string);

    // Verify JSON was created
    try std.testing.expect(json_string.len > 0);

    // Parse it back
    const parsed = try std.json.parseFromSlice(Config, allocator, json_string, .{});
    defer parsed.deinit();

    // Verify round-trip preserves key values
    try std.testing.expect(parsed.value.output != null);
    try std.testing.expectEqualStrings("json", parsed.value.output.?.format.?);
    try std.testing.expect(parsed.value.analysis != null);
    try std.testing.expectEqual(@as(?bool, true), parsed.value.analysis.?.no_duplication);
    try std.testing.expectEqual(@as(?u32, 4), parsed.value.analysis.?.threads);
}
