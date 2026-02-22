const std = @import("std");
const discovery = @import("discovery.zig");
const toml = @import("toml");

/// Top-level configuration structure matching locked schema.
/// All fields are optional to support partial configs and defaults.
pub const Config = struct {
    output: ?OutputConfig = null,
    analysis: ?AnalysisConfig = null,
    files: ?FilesConfig = null,
    weights: ?WeightsConfig = null,
    overrides: ?[]OverrideConfig = null,
    /// Baseline health score for ratchet enforcement. If set and project score
    /// drops below baseline - 0.5, the tool exits with code 1.
    baseline: ?f64 = null,
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
    duplication_enabled: ?bool = null,
    threads: ?u32 = null,
};

/// Thresholds organized by metric type.
pub const ThresholdsConfig = struct {
    cyclomatic: ?ThresholdPair = null,
    cognitive: ?ThresholdPair = null,
    halstead_volume: ?ThresholdPair = null,
    halstead_difficulty: ?ThresholdPair = null,
    halstead_effort: ?ThresholdPair = null,
    halstead_bugs: ?ThresholdPair = null,
    nesting_depth: ?ThresholdPair = null,
    line_count: ?ThresholdPair = null,
    params_count: ?ThresholdPair = null,
    file_length: ?ThresholdPair = null,
    export_count: ?ThresholdPair = null,
    duplication: ?DuplicationThresholds = null,
};

/// Warning and error threshold pair for a single metric.
/// Note: "error" is a Zig keyword, so we use @"error" syntax.
/// In JSON/TOML files, the field will be called "error".
pub const ThresholdPair = struct {
    warning: ?u32 = null,
    @"error": ?u32 = null,
};

/// Duplication percentage thresholds (floating-point, not integer).
pub const DuplicationThresholds = struct {
    file_warning: ?f64 = null, // default 15.0
    file_error: ?f64 = null, // default 25.0
    project_warning: ?f64 = null, // default 5.0
    project_error: ?f64 = null, // default 10.0
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
            .duplication_enabled = false,
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

/// Load configuration from a file (JSON or TOML).
/// Returns a Config that shares memory with the parser's arena.
/// Caller should NOT free individual fields - they will be freed when the arena is cleaned up.
/// For now, we just return the parsed value directly.
/// In production, we'd either:
/// 1. Keep the arena alive and pass it back, or
/// 2. Deep copy all strings into a new allocation
/// For this phase, we'll use approach #2 to avoid leaks.
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8, format: discovery.ConfigFormat) !Config {
    // Read file contents (max 1MB)
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(file_contents);

    switch (format) {
        .json => {
            const parsed = try std.json.parseFromSlice(
                Config,
                allocator,
                file_contents,
                .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
            );
            defer parsed.deinit();

            // Deep copy the config so we can free the parser's arena
            return try deepCopyConfig(allocator, parsed.value);
        },
        .toml => {
            var parser = toml.Parser(Config).init(allocator);
            defer parser.deinit();

            const parsed = try parser.parseString(file_contents);
            defer parsed.deinit();

            // Deep copy the config so we can free the parser's arena
            return try deepCopyConfig(allocator, parsed.value);
        },
    }
}

/// Free a Config struct and all its allocated memory.
pub fn freeConfig(allocator: std.mem.Allocator, config: Config) void {
    // Free output config strings
    if (config.output) |output| {
        if (output.format) |f| allocator.free(f);
        if (output.file) |f| allocator.free(f);
    }

    // Free analysis config strings
    if (config.analysis) |analysis| {
        if (analysis.metrics) |metrics| {
            for (metrics) |metric| {
                allocator.free(metric);
            }
            allocator.free(metrics);
        }
    }

    // Free files config strings
    if (config.files) |files| {
        if (files.include) |include| {
            for (include) |pattern| {
                allocator.free(pattern);
            }
            allocator.free(include);
        }
        if (files.exclude) |exclude| {
            for (exclude) |pattern| {
                allocator.free(pattern);
            }
            allocator.free(exclude);
        }
    }

    // Overrides not implemented yet
}

/// Deep copy a Config struct, duplicating all string slices.
fn deepCopyConfig(allocator: std.mem.Allocator, config: Config) !Config {
    var result = Config{};

    // Copy output config
    if (config.output) |output| {
        result.output = OutputConfig{
            .format = if (output.format) |f| try allocator.dupe(u8, f) else null,
            .file = if (output.file) |f| try allocator.dupe(u8, f) else null,
        };
    }

    // Copy analysis config
    if (config.analysis) |analysis| {
        var metrics_copy: ?[]const []const u8 = null;
        if (analysis.metrics) |metrics| {
            var metrics_list = std.ArrayList([]const u8).empty;
            for (metrics) |metric| {
                try metrics_list.append(allocator, try allocator.dupe(u8, metric));
            }
            metrics_copy = try metrics_list.toOwnedSlice(allocator);
        }

        result.analysis = AnalysisConfig{
            .metrics = metrics_copy,
            .thresholds = analysis.thresholds, // ThresholdPair/DuplicationThresholds contain only numbers, no strings
            .no_duplication = analysis.no_duplication,
            .duplication_enabled = analysis.duplication_enabled,
            .threads = analysis.threads,
        };
    }

    // Copy files config
    if (config.files) |files| {
        var include_copy: ?[]const []const u8 = null;
        if (files.include) |include| {
            var include_list = std.ArrayList([]const u8).empty;
            for (include) |pattern| {
                try include_list.append(allocator, try allocator.dupe(u8, pattern));
            }
            include_copy = try include_list.toOwnedSlice(allocator);
        }

        var exclude_copy: ?[]const []const u8 = null;
        if (files.exclude) |exclude| {
            var exclude_list = std.ArrayList([]const u8).empty;
            for (exclude) |pattern| {
                try exclude_list.append(allocator, try allocator.dupe(u8, pattern));
            }
            exclude_copy = try exclude_list.toOwnedSlice(allocator);
        }

        result.files = FilesConfig{
            .include = include_copy,
            .exclude = exclude_copy,
        };
    }

    // Copy weights config (no strings, just floats)
    result.weights = config.weights;

    // Copy baseline (plain ?f64, no allocation needed)
    result.baseline = config.baseline;

    // Copy overrides (complex, skip for now - not tested in this phase)
    result.overrides = null;

    return result;
}

/// Validation errors.
pub const ValidationError = error{
    InvalidFormat,
    InvalidWeights,
    InvalidThresholds,
    InvalidThreads,
};

/// Validate a configuration.
pub fn validate(config: Config) ValidationError!void {
    // Validate output format
    if (config.output) |output| {
        if (output.format) |format| {
            const valid_formats = [_][]const u8{ "console", "json", "sarif", "html" };
            var format_valid = false;
            for (valid_formats) |valid_format| {
                if (std.mem.eql(u8, format, valid_format)) {
                    format_valid = true;
                    break;
                }
            }
            if (!format_valid) {
                return ValidationError.InvalidFormat;
            }
        }
    }

    // Validate weights (all must be 0.0-1.0)
    if (config.weights) |weights| {
        if (weights.cyclomatic) |w| {
            if (w < 0.0 or w > 1.0) return ValidationError.InvalidWeights;
        }
        if (weights.cognitive) |w| {
            if (w < 0.0 or w > 1.0) return ValidationError.InvalidWeights;
        }
        if (weights.duplication) |w| {
            if (w < 0.0 or w > 1.0) return ValidationError.InvalidWeights;
        }
        if (weights.halstead) |w| {
            if (w < 0.0 or w > 1.0) return ValidationError.InvalidWeights;
        }
        if (weights.structural) |w| {
            if (w < 0.0 or w > 1.0) return ValidationError.InvalidWeights;
        }
    }

    // Validate thresholds (warning <= error)
    if (config.analysis) |analysis| {
        if (analysis.thresholds) |thresholds| {
            try validateThresholdPair(thresholds.cyclomatic);
            try validateThresholdPair(thresholds.cognitive);
            try validateThresholdPair(thresholds.halstead_volume);
            try validateThresholdPair(thresholds.halstead_difficulty);
            try validateThresholdPair(thresholds.halstead_effort);
            try validateThresholdPair(thresholds.halstead_bugs);
            try validateThresholdPair(thresholds.nesting_depth);
            try validateThresholdPair(thresholds.line_count);
            try validateThresholdPair(thresholds.params_count);
            try validateThresholdPair(thresholds.file_length);
            try validateThresholdPair(thresholds.export_count);
        }

        // Validate thread count
        if (analysis.threads) |threads| {
            if (threads < 1) {
                return ValidationError.InvalidThreads;
            }
        }
    }
}

/// Validate a single threshold pair (warning <= error).
fn validateThresholdPair(pair: ?ThresholdPair) ValidationError!void {
    if (pair) |p| {
        if (p.warning != null and p.@"error" != null) {
            if (p.warning.? > p.@"error".?) {
                return ValidationError.InvalidThresholds;
            }
        }
    }
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

test "loadConfig with valid JSON" {
    const allocator = std.testing.allocator;

    // Create temp file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const json_content =
        \\{
        \\  "output": {
        \\    "format": "json"
        \\  },
        \\  "analysis": {
        \\    "threads": 8
        \\  }
        \\}
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "config.json", .data = json_content });

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, "config.json" });
    defer allocator.free(config_path);

    // Load config
    const config = try loadConfig(allocator, config_path, .json);
    defer freeConfig(allocator, config);

    // Verify fields
    try std.testing.expect(config.output != null);
    try std.testing.expectEqualStrings("json", config.output.?.format.?);
    try std.testing.expect(config.analysis != null);
    try std.testing.expectEqual(@as(?u32, 8), config.analysis.?.threads);
}

test "loadConfig with valid TOML" {
    const allocator = std.testing.allocator;

    // Create temp file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const toml_content =
        \\[output]
        \\format = "console"
        \\
        \\[analysis]
        \\threads = 4
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "config.toml", .data = toml_content });

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, "config.toml" });
    defer allocator.free(config_path);

    // Load config
    const config = try loadConfig(allocator, config_path, .toml);
    defer freeConfig(allocator, config);

    // Verify fields
    try std.testing.expect(config.output != null);
    try std.testing.expectEqualStrings("console", config.output.?.format.?);
    try std.testing.expect(config.analysis != null);
    try std.testing.expectEqual(@as(?u32, 4), config.analysis.?.threads);
}

test "JSON and TOML produce identical Config" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const json_content =
        \\{
        \\  "output": {
        \\    "format": "json"
        \\  }
        \\}
    ;

    const toml_content =
        \\[output]
        \\format = "json"
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "config.json", .data = json_content });
    try tmp_dir.dir.writeFile(.{ .sub_path = "config.toml", .data = toml_content });

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const json_path = try std.fs.path.join(allocator, &.{ tmp_path, "config.json" });
    defer allocator.free(json_path);
    const toml_path = try std.fs.path.join(allocator, &.{ tmp_path, "config.toml" });
    defer allocator.free(toml_path);

    const json_config = try loadConfig(allocator, json_path, .json);
    defer freeConfig(allocator, json_config);
    const toml_config = try loadConfig(allocator, toml_path, .toml);
    defer freeConfig(allocator, toml_config);

    // Verify both have same output format
    try std.testing.expect(json_config.output != null);
    try std.testing.expect(toml_config.output != null);
    try std.testing.expectEqualStrings(json_config.output.?.format.?, toml_config.output.?.format.?);
}

test "validate passes for default config" {
    const config = defaults();
    try validate(config);
}

test "validate rejects invalid format" {
    const config = Config{
        .output = OutputConfig{
            .format = "xml", // invalid
            .file = null,
        },
        .analysis = null,
        .files = null,
        .weights = null,
        .overrides = null,
    };

    try std.testing.expectError(ValidationError.InvalidFormat, validate(config));
}

test "validate rejects negative weights" {
    const config = Config{
        .output = null,
        .analysis = null,
        .files = null,
        .weights = WeightsConfig{
            .cognitive = -0.5, // invalid
            .cyclomatic = null,
            .duplication = null,
            .halstead = null,
            .structural = null,
        },
        .overrides = null,
    };

    try std.testing.expectError(ValidationError.InvalidWeights, validate(config));
}

test "validate rejects warning > error threshold" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = ThresholdsConfig{
                .cyclomatic = ThresholdPair{
                    .warning = 20,
                    .@"error" = 10, // warning > error is invalid
                },
                .cognitive = null,
                .halstead_volume = null,
                .halstead_difficulty = null,
                .halstead_effort = null,
                .halstead_bugs = null,
                .nesting_depth = null,
                .line_count = null,
                .params_count = null,
                .file_length = null,
                .export_count = null,
            },
            .no_duplication = null,
            .threads = null,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };

    try std.testing.expectError(ValidationError.InvalidThresholds, validate(config));
}

test "validate rejects zero threads" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = null,
            .no_duplication = null,
            .threads = 0, // invalid
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };

    try std.testing.expectError(ValidationError.InvalidThreads, validate(config));
}

test "deepCopyConfig preserves baseline field" {
    const allocator = std.testing.allocator;
    const original = Config{
        .baseline = 77.5,
    };
    const copy = try deepCopyConfig(allocator, original);
    try std.testing.expectEqual(@as(?f64, 77.5), copy.baseline);
}

test "ThresholdsConfig has halstead_effort field" {
    const thresholds = ThresholdsConfig{
        .halstead_effort = ThresholdPair{ .warning = 5000, .@"error" = 10000 },
    };
    try std.testing.expect(thresholds.halstead_effort != null);
    try std.testing.expectEqual(@as(?u32, 5000), thresholds.halstead_effort.?.warning);
    try std.testing.expectEqual(@as(?u32, 10000), thresholds.halstead_effort.?.@"error");
}

test "ThresholdsConfig has halstead_bugs field" {
    const thresholds = ThresholdsConfig{
        .halstead_bugs = ThresholdPair{ .warning = 1, .@"error" = 2 },
    };
    try std.testing.expect(thresholds.halstead_bugs != null);
    try std.testing.expectEqual(@as(?u32, 1), thresholds.halstead_bugs.?.warning);
    try std.testing.expectEqual(@as(?u32, 2), thresholds.halstead_bugs.?.@"error");
}

test "ThresholdsConfig has file_length field" {
    const thresholds = ThresholdsConfig{
        .file_length = ThresholdPair{ .warning = 300, .@"error" = 600 },
    };
    try std.testing.expect(thresholds.file_length != null);
    try std.testing.expectEqual(@as(?u32, 300), thresholds.file_length.?.warning);
    try std.testing.expectEqual(@as(?u32, 600), thresholds.file_length.?.@"error");
}

test "ThresholdsConfig has export_count field" {
    const thresholds = ThresholdsConfig{
        .export_count = ThresholdPair{ .warning = 15, .@"error" = 30 },
    };
    try std.testing.expect(thresholds.export_count != null);
    try std.testing.expectEqual(@as(?u32, 15), thresholds.export_count.?.warning);
    try std.testing.expectEqual(@as(?u32, 30), thresholds.export_count.?.@"error");
}

test "validate validates halstead_effort threshold pair" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = ThresholdsConfig{
                .halstead_effort = ThresholdPair{
                    .warning = 10000,
                    .@"error" = 5000, // warning > error is invalid
                },
            },
            .no_duplication = null,
            .threads = null,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };
    try std.testing.expectError(ValidationError.InvalidThresholds, validate(config));
}

test "validate validates halstead_bugs threshold pair" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = ThresholdsConfig{
                .halstead_bugs = ThresholdPair{
                    .warning = 5,
                    .@"error" = 2, // warning > error is invalid
                },
            },
            .no_duplication = null,
            .threads = null,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };
    try std.testing.expectError(ValidationError.InvalidThresholds, validate(config));
}

test "validate validates file_length threshold pair" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = ThresholdsConfig{
                .file_length = ThresholdPair{
                    .warning = 600,
                    .@"error" = 300, // warning > error is invalid
                },
            },
            .no_duplication = null,
            .threads = null,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };
    try std.testing.expectError(ValidationError.InvalidThresholds, validate(config));
}

test "validate validates export_count threshold pair" {
    const config = Config{
        .output = null,
        .analysis = AnalysisConfig{
            .metrics = null,
            .thresholds = ThresholdsConfig{
                .export_count = ThresholdPair{
                    .warning = 30,
                    .@"error" = 15, // warning > error is invalid
                },
            },
            .no_duplication = null,
            .threads = null,
        },
        .files = null,
        .weights = null,
        .overrides = null,
    };
    try std.testing.expectError(ValidationError.InvalidThresholds, validate(config));
}
