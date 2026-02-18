const std = @import("std");
const console = @import("console.zig");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const Allocator = std.mem.Allocator;

// Rule index constants
pub const RULE_CYCLOMATIC: u32 = 0;
pub const RULE_COGNITIVE: u32 = 1;
pub const RULE_HALSTEAD_VOLUME: u32 = 2;
pub const RULE_HALSTEAD_DIFFICULTY: u32 = 3;
pub const RULE_HALSTEAD_EFFORT: u32 = 4;
pub const RULE_HALSTEAD_BUGS: u32 = 5;
pub const RULE_LINE_COUNT: u32 = 6;
pub const RULE_PARAM_COUNT: u32 = 7;
pub const RULE_NESTING_DEPTH: u32 = 8;
pub const RULE_HEALTH_SCORE: u32 = 9;

/// SARIF 2.1.0 top-level log object
pub const SarifLog = struct {
    @"$schema": []const u8,
    version: []const u8,
    runs: []const SarifRun,
};

pub const SarifRun = struct {
    tool: SarifTool,
    results: []const SarifResult,
};

pub const SarifTool = struct {
    driver: SarifDriver,
};

pub const SarifDriver = struct {
    name: []const u8,
    version: []const u8,
    informationUri: []const u8,
    rules: []const SarifRule,
};

pub const SarifRule = struct {
    id: []const u8,
    name: []const u8,
    shortDescription: SarifMessage,
    fullDescription: SarifMessage,
    defaultConfiguration: SarifConfiguration,
    helpUri: []const u8,
    help: SarifMessage,
};

pub const SarifConfiguration = struct {
    level: []const u8,
};

pub const SarifMessage = struct {
    text: []const u8,
};

pub const SarifResult = struct {
    ruleId: []const u8,
    ruleIndex: u32,
    level: []const u8,
    message: SarifMessage,
    locations: []const SarifLocation,
};

pub const SarifLocation = struct {
    physicalLocation: SarifPhysicalLocation,
};

pub const SarifPhysicalLocation = struct {
    artifactLocation: SarifArtifactLocation,
    region: SarifRegion,
};

pub const SarifArtifactLocation = struct {
    uri: []const u8,
};

pub const SarifRegion = struct {
    startLine: u32,
    startColumn: u32,
    endLine: u32,
};

/// All threshold values needed for SARIF message formatting
pub const SarifThresholds = struct {
    cyclomatic_warning: u32,
    cyclomatic_error: u32,
    cognitive_warning: u32,
    cognitive_error: u32,
    halstead_volume_warning: f64,
    halstead_volume_error: f64,
    halstead_difficulty_warning: f64,
    halstead_difficulty_error: f64,
    halstead_effort_warning: f64,
    halstead_effort_error: f64,
    halstead_bugs_warning: f64,
    halstead_bugs_error: f64,
    line_count_warning: u32,
    line_count_error: u32,
    param_count_warning: u32,
    param_count_error: u32,
    nesting_depth_warning: u32,
    nesting_depth_error: u32,
};

/// Returns true if the given metric is enabled.
/// Duplicated from console.zig to avoid circular imports.
fn isMetricEnabled(metrics: ?[]const []const u8, metric: []const u8) bool {
    const list = metrics orelse return true;
    for (list) |m| {
        if (std.mem.eql(u8, m, metric)) return true;
    }
    return false;
}

/// Map ThresholdStatus to SARIF level string
fn statusToLevel(status: cyclomatic.ThresholdStatus) []const u8 {
    return switch (status) {
        .warning => "warning",
        .@"error" => "error",
        .ok => "note",
    };
}

/// Build the 10 SARIF rule definitions
fn buildRules(allocator: Allocator) ![]SarifRule {
    var rules = std.ArrayList(SarifRule).empty;
    defer rules.deinit(allocator);

    // RULE 0: Cyclomatic complexity
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/cyclomatic",
        .name = "CyclomaticComplexity",
        .shortDescription = .{ .text = "Cyclomatic complexity exceeded threshold" },
        .fullDescription = .{ .text = "Cyclomatic complexity measures the number of linearly independent paths through a function. It counts decision points like if statements, loops, logical operators, and ternary expressions plus 1 (McCabe's base). High values indicate functions that are hard to test and maintain." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/cyclomatic-complexity.md",
        .help = .{ .text = "Reduce cyclomatic complexity by extracting complex conditional logic into smaller functions, simplifying boolean expressions, or replacing switch statements with lookup tables." },
    });

    // RULE 1: Cognitive complexity
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/cognitive",
        .name = "CognitiveComplexity",
        .shortDescription = .{ .text = "Cognitive complexity exceeded threshold" },
        .fullDescription = .{ .text = "Cognitive complexity measures how difficult a function is to understand, weighted by nesting depth and structural increments. Defined by G. Ann Campbell/SonarSource. Higher nesting adds more weight to each control flow element." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/cognitive-complexity.md",
        .help = .{ .text = "Reduce cognitive complexity by flattening nested conditions using early returns, extracting nested loops into separate functions, and simplifying deeply nested logic." },
    });

    // RULE 2: Halstead volume
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/halstead-volume",
        .name = "HalsteadVolume",
        .shortDescription = .{ .text = "Halstead volume exceeded threshold" },
        .fullDescription = .{ .text = "Halstead volume measures the information content of a program, calculated as N * log2(n) where N is total operators+operands and n is distinct operators+operands. High volume indicates functions with excessive vocabulary or repetition." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
        .help = .{ .text = "Reduce Halstead volume by splitting large functions, eliminating redundant expressions, and extracting repeated patterns into helper functions." },
    });

    // RULE 3: Halstead difficulty
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/halstead-difficulty",
        .name = "HalsteadDifficulty",
        .shortDescription = .{ .text = "Halstead difficulty exceeded threshold" },
        .fullDescription = .{ .text = "Halstead difficulty measures implementation error-proneness, calculated as (n1/2) * (N2/n2) where n1 is distinct operators, N2 is total operands, and n2 is distinct operands. High difficulty indicates repeated operands with many unique operators." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
        .help = .{ .text = "Reduce Halstead difficulty by introducing named constants for repeated values, reducing operator diversity, and clarifying variable naming to reduce operand reuse." },
    });

    // RULE 4: Halstead effort
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/halstead-effort",
        .name = "HalsteadEffort",
        .shortDescription = .{ .text = "Halstead effort exceeded threshold" },
        .fullDescription = .{ .text = "Halstead effort estimates the mental effort required to implement or understand a function, calculated as Volume * Difficulty. It combines both the information content and the error-proneness into a single measure." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
        .help = .{ .text = "Reduce Halstead effort by addressing both volume (split large functions) and difficulty (reduce operator/operand repetition) simultaneously." },
    });

    // RULE 5: Halstead bugs
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/halstead-bugs",
        .name = "HalsteadBugs",
        .shortDescription = .{ .text = "Halstead bug estimate exceeded threshold" },
        .fullDescription = .{ .text = "Halstead bug estimate predicts the number of errors in the implementation, calculated as Volume / 3000. Higher values correlate with increased defect density and maintenance burden." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
        .help = .{ .text = "Reduce the bug estimate by splitting complex functions into smaller, well-tested units. Each unit should have a single, clear responsibility." },
    });

    // RULE 6: Line count
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/line-count",
        .name = "LineCount",
        .shortDescription = .{ .text = "Function line count exceeded threshold" },
        .fullDescription = .{ .text = "Measures the logical line count of a function body, excluding blank lines and brace-only lines. Long functions are harder to read, test, and maintain. The Single Responsibility Principle suggests functions should do one thing." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
        .help = .{ .text = "Reduce function length by extracting logical sections into well-named helper functions. Aim for functions that fit on a single screen without scrolling." },
    });

    // RULE 7: Param count
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/param-count",
        .name = "ParamCount",
        .shortDescription = .{ .text = "Function parameter count exceeded threshold" },
        .fullDescription = .{ .text = "Measures the number of parameters a function accepts. Functions with many parameters are harder to call correctly, test, and remember. High parameter counts often indicate missing abstraction or violated cohesion." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
        .help = .{ .text = "Reduce parameter count by grouping related parameters into an options object, using builder patterns, or splitting the function into smaller focused functions." },
    });

    // RULE 8: Nesting depth
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/nesting-depth",
        .name = "NestingDepth",
        .shortDescription = .{ .text = "Function nesting depth exceeded threshold" },
        .fullDescription = .{ .text = "Measures the maximum nesting depth within a function body. Deeply nested code is harder to read and reason about. Each level of nesting increases the cognitive load required to understand the surrounding context." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
        .help = .{ .text = "Reduce nesting depth by using early returns to handle edge cases first, extracting nested blocks into helper functions, and inverting conditions to eliminate else clauses." },
    });

    // RULE 9: Health score
    try rules.append(allocator, SarifRule{
        .id = "complexity-guard/health-score",
        .name = "HealthScore",
        .shortDescription = .{ .text = "File health score below baseline" },
        .fullDescription = .{ .text = "The composite health score aggregates all metric families using configurable weights into a single 0-100 score. A score below the configured baseline indicates the file's complexity has regressed since the baseline was recorded." },
        .defaultConfiguration = .{ .level = "warning" },
        .helpUri = "https://github.com/benvds/complexity-guard/blob/main/docs/health-score.md",
        .help = .{ .text = "Improve the health score by addressing the metric violations shown in other results. The health score weights cyclomatic, cognitive, Halstead, and structural metrics. Run without a baseline to see individual violations." },
    });

    return try allocator.dupe(SarifRule, rules.items);
}

/// Count violations per metric family for a set of ThresholdResult items.
/// Returns a struct with counts per family used for baseline failure messages.
const ViolationCounts = struct {
    cyclomatic: u32,
    cognitive: u32,
    halstead: u32,
    structural: u32,
};

fn countViolations(results: []const cyclomatic.ThresholdResult) ViolationCounts {
    var counts = ViolationCounts{
        .cyclomatic = 0,
        .cognitive = 0,
        .halstead = 0,
        .structural = 0,
    };
    for (results) |r| {
        if (r.status != .ok) counts.cyclomatic += 1;
        if (r.cognitive_status != .ok) counts.cognitive += 1;
        if (r.halstead_volume_status != .ok or
            r.halstead_difficulty_status != .ok or
            r.halstead_effort_status != .ok or
            r.halstead_bugs_status != .ok) counts.halstead += 1;
        if (r.function_length_status != .ok or
            r.params_count_status != .ok or
            r.nesting_depth_status != .ok) counts.structural += 1;
    }
    return counts;
}

/// Build SARIF 2.1.0 output from analysis results
pub fn buildSarifOutput(
    allocator: Allocator,
    file_results: []const console.FileThresholdResults,
    tool_version: []const u8,
    baseline_failed: bool,
    baseline_value: ?f64,
    project_score: f64,
    selected_metrics: ?[]const []const u8,
    thresholds: SarifThresholds,
) !SarifLog {
    _ = project_score; // Used implicitly via baseline_failed

    // Build rules array
    const rules = try buildRules(allocator);

    // Build results array
    var sarif_results = std.ArrayList(SarifResult).empty;
    defer sarif_results.deinit(allocator);

    // Iterate each file and each function result
    for (file_results) |fr| {
        for (fr.results) |result| {
            // Cyclomatic complexity violation
            if (isMetricEnabled(selected_metrics, "cyclomatic") and
                result.status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Cyclomatic complexity is {d} (warning threshold: {d}, error threshold: {d})",
                    .{ result.complexity, thresholds.cyclomatic_warning, thresholds.cyclomatic_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1, // 0-indexed -> 1-indexed
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/cyclomatic",
                    .ruleIndex = RULE_CYCLOMATIC,
                    .level = statusToLevel(result.status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Cognitive complexity violation
            if (isMetricEnabled(selected_metrics, "cognitive") and
                result.cognitive_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Cognitive complexity is {d} (warning threshold: {d}, error threshold: {d})",
                    .{ result.cognitive_complexity, thresholds.cognitive_warning, thresholds.cognitive_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/cognitive",
                    .ruleIndex = RULE_COGNITIVE,
                    .level = statusToLevel(result.cognitive_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Halstead volume violation
            if (isMetricEnabled(selected_metrics, "halstead") and
                result.halstead_volume_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Halstead volume is {d:.1} (warning threshold: {d:.1}, error threshold: {d:.1})",
                    .{ result.halstead_volume, thresholds.halstead_volume_warning, thresholds.halstead_volume_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/halstead-volume",
                    .ruleIndex = RULE_HALSTEAD_VOLUME,
                    .level = statusToLevel(result.halstead_volume_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Halstead difficulty violation
            if (isMetricEnabled(selected_metrics, "halstead") and
                result.halstead_difficulty_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Halstead difficulty is {d:.1} (warning threshold: {d:.1}, error threshold: {d:.1})",
                    .{ result.halstead_difficulty, thresholds.halstead_difficulty_warning, thresholds.halstead_difficulty_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/halstead-difficulty",
                    .ruleIndex = RULE_HALSTEAD_DIFFICULTY,
                    .level = statusToLevel(result.halstead_difficulty_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Halstead effort violation
            if (isMetricEnabled(selected_metrics, "halstead") and
                result.halstead_effort_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Halstead effort is {d:.1} (warning threshold: {d:.1}, error threshold: {d:.1})",
                    .{ result.halstead_effort, thresholds.halstead_effort_warning, thresholds.halstead_effort_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/halstead-effort",
                    .ruleIndex = RULE_HALSTEAD_EFFORT,
                    .level = statusToLevel(result.halstead_effort_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Halstead bugs violation
            if (isMetricEnabled(selected_metrics, "halstead") and
                result.halstead_bugs_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Halstead bug estimate is {d:.3} (warning threshold: {d:.3}, error threshold: {d:.3})",
                    .{ result.halstead_bugs, thresholds.halstead_bugs_warning, thresholds.halstead_bugs_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/halstead-bugs",
                    .ruleIndex = RULE_HALSTEAD_BUGS,
                    .level = statusToLevel(result.halstead_bugs_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Line count violation
            if (isMetricEnabled(selected_metrics, "structural") and
                result.function_length_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Function line count is {d} (warning threshold: {d}, error threshold: {d})",
                    .{ result.function_length, thresholds.line_count_warning, thresholds.line_count_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/line-count",
                    .ruleIndex = RULE_LINE_COUNT,
                    .level = statusToLevel(result.function_length_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Param count violation
            if (isMetricEnabled(selected_metrics, "structural") and
                result.params_count_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Parameter count is {d} (warning threshold: {d}, error threshold: {d})",
                    .{ result.params_count, thresholds.param_count_warning, thresholds.param_count_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/param-count",
                    .ruleIndex = RULE_PARAM_COUNT,
                    .level = statusToLevel(result.params_count_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }

            // Nesting depth violation
            if (isMetricEnabled(selected_metrics, "structural") and
                result.nesting_depth_status != .ok)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "Nesting depth is {d} (warning threshold: {d}, error threshold: {d})",
                    .{ result.nesting_depth, thresholds.nesting_depth_warning, thresholds.nesting_depth_error },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = result.start_line,
                            .startColumn = result.start_col + 1,
                            .endLine = result.end_line,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/nesting-depth",
                    .ruleIndex = RULE_NESTING_DEPTH,
                    .level = statusToLevel(result.nesting_depth_status),
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }
        }

        // Baseline ratchet: file-level health score result
        if (baseline_failed) {
            // Emit a health-score result for every file that has violations
            // The baseline applies project-wide but we emit per-file annotations
            const counts = countViolations(fr.results);
            const baseline_val = baseline_value orelse 0.0;

            // Calculate approximate file score from health_score field of results
            // Use the average of function health scores in the file
            var file_score: f64 = 0.0;
            if (fr.results.len > 0) {
                for (fr.results) |r| {
                    file_score += r.health_score;
                }
                file_score /= @as(f64, @floatFromInt(fr.results.len));
            }

            // Only emit file-level result if this file has violations contributing to baseline failure
            if (counts.cyclomatic > 0 or counts.cognitive > 0 or
                counts.halstead > 0 or counts.structural > 0)
            {
                const msg = try std.fmt.allocPrint(
                    allocator,
                    "File health score: {d:.1} (baseline: {d:.1}). Worst contributors: cyclomatic ({d} violations), cognitive ({d} violations)",
                    .{ file_score, baseline_val, counts.cyclomatic, counts.cognitive },
                );
                const locs = try allocator.dupe(SarifLocation, &[_]SarifLocation{.{
                    .physicalLocation = .{
                        .artifactLocation = .{ .uri = fr.path },
                        .region = .{
                            .startLine = 1,
                            .startColumn = 1,
                            .endLine = 1,
                        },
                    },
                }});
                try sarif_results.append(allocator, SarifResult{
                    .ruleId = "complexity-guard/health-score",
                    .ruleIndex = RULE_HEALTH_SCORE,
                    .level = "error",
                    .message = .{ .text = msg },
                    .locations = locs,
                });
            }
        }
    }

    // Build the run
    const run = SarifRun{
        .tool = SarifTool{
            .driver = SarifDriver{
                .name = "ComplexityGuard",
                .version = tool_version,
                .informationUri = "https://github.com/benvds/complexity-guard",
                .rules = rules,
            },
        },
        .results = try allocator.dupe(SarifResult, sarif_results.items),
    };

    const runs = try allocator.dupe(SarifRun, &[_]SarifRun{run});

    return SarifLog{
        .@"$schema" = "https://json.schemastore.org/sarif-2.1.0.json",
        .version = "2.1.0",
        .runs = runs,
    };
}

/// Serialize SARIF output to pretty-printed JSON string
pub fn serializeSarifOutput(allocator: Allocator, output: SarifLog) ![]u8 {
    return try std.json.Stringify.valueAlloc(allocator, output, .{
        .whitespace = .indent_2,
    });
}

// TESTS

test "buildSarifOutput: produces valid SARIF envelope" {
    const allocator = std.testing.allocator;

    const file_results = [_]console.FileThresholdResults{};

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        100.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    try std.testing.expectEqualStrings("https://json.schemastore.org/sarif-2.1.0.json", output.@"$schema");
    try std.testing.expectEqualStrings("2.1.0", output.version);
    try std.testing.expectEqual(@as(usize, 1), output.runs.len);
    try std.testing.expectEqualStrings("ComplexityGuard", output.runs[0].tool.driver.name);
}

test "buildSarifOutput: no results for passing functions" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 5,
            .status = .ok,
            .function_name = "foo",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 3,
            .cognitive_status = .ok,
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        100.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    try std.testing.expectEqual(@as(usize, 0), output.runs[0].results.len);
}

test "buildSarifOutput: cyclomatic violation produces result" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 15,
            .status = .warning,
            .function_name = "complexFunc",
            .function_kind = "function",
            .start_line = 10,
            .start_col = 0,
            .cognitive_complexity = 5,
            .cognitive_status = .ok,
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "src/app.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        75.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            for (run.results) |r| {
                allocator.free(r.message.text);
                allocator.free(r.locations);
            }
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    const run_results = output.runs[0].results;
    try std.testing.expectEqual(@as(usize, 1), run_results.len);

    const result = run_results[0];
    try std.testing.expectEqualStrings("complexity-guard/cyclomatic", result.ruleId);
    try std.testing.expectEqual(RULE_CYCLOMATIC, result.ruleIndex);
    try std.testing.expectEqualStrings("warning", result.level);
    // Message should contain threshold values
    try std.testing.expect(std.mem.indexOf(u8, result.message.text, "15") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.message.text, "10") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.message.text, "20") != null);
}

test "buildSarifOutput: column is 1-indexed" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 15,
            .status = .warning,
            .function_name = "indented",
            .function_kind = "function",
            .start_line = 5,
            .start_col = 4, // 0-indexed internally
            .cognitive_complexity = 0,
            .cognitive_status = .ok,
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        80.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            for (run.results) |r| {
                allocator.free(r.message.text);
                allocator.free(r.locations);
            }
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    const result = output.runs[0].results[0];
    const region = result.locations[0].physicalLocation.region;
    // start_col=4 (0-indexed) should become startColumn=5 (1-indexed)
    try std.testing.expectEqual(@as(u32, 5), region.startColumn);
    try std.testing.expectEqual(@as(u32, 5), region.startLine);
}

test "buildSarifOutput: multiple metrics produce multiple results" {
    const allocator = std.testing.allocator;

    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 25,
            .status = .@"error",
            .function_name = "bigFunc",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 30,
            .cognitive_status = .@"error",
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        30.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            for (run.results) |r| {
                allocator.free(r.message.text);
                allocator.free(r.locations);
            }
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    // Should have 2 results: cyclomatic + cognitive
    try std.testing.expectEqual(@as(usize, 2), output.runs[0].results.len);
}

test "buildSarifOutput: baseline failure produces file-level result" {
    const allocator = std.testing.allocator;

    // A function with violations so the file gets a health-score result
    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 15,
            .status = .warning,
            .function_name = "foo",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 0,
            .cognitive_status = .ok,
            .health_score = 42.5,
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "src/app.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        true, // baseline_failed
        60.0, // baseline_value
        42.5,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            for (run.results) |r| {
                allocator.free(r.message.text);
                allocator.free(r.locations);
            }
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    const run_results = output.runs[0].results;
    // Should have: 1 cyclomatic result + 1 health-score result
    try std.testing.expect(run_results.len >= 2);

    // Find the health-score result
    var found_health_score = false;
    for (run_results) |r| {
        if (std.mem.eql(u8, r.ruleId, "complexity-guard/health-score")) {
            found_health_score = true;
            try std.testing.expectEqualStrings("error", r.level);
            try std.testing.expectEqual(@as(u32, 1), r.locations[0].physicalLocation.region.startLine);
            break;
        }
    }
    try std.testing.expect(found_health_score);
}

test "buildSarifOutput: metrics filtering limits results" {
    const allocator = std.testing.allocator;

    // Function with both cyclomatic and cognitive violations
    const results = [_]cyclomatic.ThresholdResult{
        .{
            .complexity = 25,
            .status = .@"error",
            .function_name = "complexFunc",
            .function_kind = "function",
            .start_line = 1,
            .start_col = 0,
            .cognitive_complexity = 35,
            .cognitive_status = .@"error",
        },
    };
    const file_results = [_]console.FileThresholdResults{
        .{ .path = "test.ts", .results = &results },
    };

    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    // Filter to only cyclomatic
    const selected = [_][]const u8{"cyclomatic"};
    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        50.0,
        &selected,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            for (run.results) |r| {
                allocator.free(r.message.text);
                allocator.free(r.locations);
            }
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    // Only cyclomatic result should appear — cognitive filtered out
    const run_results = output.runs[0].results;
    try std.testing.expectEqual(@as(usize, 1), run_results.len);
    try std.testing.expectEqualStrings("complexity-guard/cyclomatic", run_results[0].ruleId);
}

test "serializeSarifOutput: produces valid JSON" {
    const allocator = std.testing.allocator;

    const file_results = [_]console.FileThresholdResults{};
    const thresholds = SarifThresholds{
        .cyclomatic_warning = 10, .cyclomatic_error = 20,
        .cognitive_warning = 15, .cognitive_error = 30,
        .halstead_volume_warning = 500.0, .halstead_volume_error = 1000.0,
        .halstead_difficulty_warning = 10.0, .halstead_difficulty_error = 20.0,
        .halstead_effort_warning = 5000.0, .halstead_effort_error = 10000.0,
        .halstead_bugs_warning = 0.5, .halstead_bugs_error = 1.0,
        .line_count_warning = 50, .line_count_error = 100,
        .param_count_warning = 4, .param_count_error = 7,
        .nesting_depth_warning = 3, .nesting_depth_error = 5,
    };

    const output = try buildSarifOutput(
        allocator,
        &file_results,
        "0.4.0",
        false,
        null,
        100.0,
        null,
        thresholds,
    );
    defer {
        for (output.runs) |run| {
            allocator.free(run.tool.driver.rules);
            allocator.free(run.results);
        }
        allocator.free(output.runs);
    }

    const json_str = try serializeSarifOutput(allocator, output);
    defer allocator.free(json_str);

    // Verify it's valid JSON by parsing it back
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();

    // Verify key fields exist
    try std.testing.expect(parsed.value.object.get("$schema") != null);
    try std.testing.expect(parsed.value.object.get("version") != null);
    try std.testing.expect(parsed.value.object.get("runs") != null);
    try std.testing.expectEqualStrings(
        "https://json.schemastore.org/sarif-2.1.0.json",
        parsed.value.object.get("$schema").?.string,
    );
    try std.testing.expectEqualStrings("2.1.0", parsed.value.object.get("version").?.string);
}
