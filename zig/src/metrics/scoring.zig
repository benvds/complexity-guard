const std = @import("std");
const config = @import("../cli/config.zig");
const cyclomatic = @import("cyclomatic.zig");

pub const WeightsConfig = config.WeightsConfig;
pub const ThresholdResult = cyclomatic.ThresholdResult;

/// Per-metric threshold pairs for scoring computation.
pub const MetricThresholds = struct {
    cyclomatic_warning: f64,
    cyclomatic_error: f64,
    cognitive_warning: f64,
    cognitive_error: f64,
    halstead_warning: f64,
    halstead_error: f64,
    function_length_warning: f64,
    function_length_error: f64,
    params_count_warning: f64,
    params_count_error: f64,
    nesting_depth_warning: f64,
    nesting_depth_error: f64,
};

/// Resolved and normalized weights for each metric family.
/// When duplication is enabled, all 5 weights are normalized to sum 1.0.
/// When disabled, duplication is 0.0 and the other 4 weights sum 1.0.
pub const EffectiveWeights = struct {
    cyclomatic: f64,
    cognitive: f64,
    halstead: f64,
    structural: f64,
    duplication: f64,
};

/// Pre-computed sigmoid steepness values for all metrics.
/// Computing these once avoids repeated @log() calls per function.
pub const PrecomputedSteepness = struct {
    cyclomatic_k: f64,
    cognitive_k: f64,
    halstead_k: f64,
    function_length_k: f64,
    params_count_k: f64,
    nesting_depth_k: f64,

    pub fn init(thresholds: MetricThresholds) PrecomputedSteepness {
        return .{
            .cyclomatic_k = computeSteepness(thresholds.cyclomatic_warning, thresholds.cyclomatic_error),
            .cognitive_k = computeSteepness(thresholds.cognitive_warning, thresholds.cognitive_error),
            .halstead_k = computeSteepness(thresholds.halstead_warning, thresholds.halstead_error),
            .function_length_k = computeSteepness(thresholds.function_length_warning, thresholds.function_length_error),
            .params_count_k = computeSteepness(thresholds.params_count_warning, thresholds.params_count_error),
            .nesting_depth_k = computeSteepness(thresholds.nesting_depth_warning, thresholds.nesting_depth_error),
        };
    }
};

/// Per-metric sub-scores plus weighted total.
pub const ScoreBreakdown = struct {
    cyclomatic_score: f64,
    cognitive_score: f64,
    halstead_score: f64,
    structural_score: f64,
    weights: EffectiveWeights,
    total: f64,
};

/// Core sigmoid normalization: returns 50.0 at warning threshold (x=x0), ~20 at error threshold.
/// Approaches 100 as x approaches -infinity. Formula: 100 / (1 + exp(k * (x - x0)))
pub fn sigmoidScore(x: f64, x0: f64, k: f64) f64 {
    return 100.0 / (1.0 + @exp(k * (x - x0)));
}

/// Derives sigmoid steepness k from warning/error thresholds.
/// k = ln(4) / (error - warning) so that at error threshold score ≈ 20.
/// Guard: if warning >= error, return large k (steep falloff).
pub fn computeSteepness(warning: f64, err: f64) f64 {
    if (err <= warning) return 1.0;
    return @log(4.0) / (err - warning);
}

/// Normalize cyclomatic complexity value to 0-100 score.
pub fn normalizeCyclomatic(value: u32, warning: u32, err: u32) f64 {
    const x = @as(f64, @floatFromInt(value));
    const x0 = @as(f64, @floatFromInt(warning));
    const x1 = @as(f64, @floatFromInt(err));
    const k = computeSteepness(x0, x1);
    return sigmoidScore(x, x0, k);
}

/// Normalize cognitive complexity value to 0-100 score.
pub fn normalizeCognitive(value: u32, warning: u32, err: u32) f64 {
    const x = @as(f64, @floatFromInt(value));
    const x0 = @as(f64, @floatFromInt(warning));
    const x1 = @as(f64, @floatFromInt(err));
    const k = computeSteepness(x0, x1);
    return sigmoidScore(x, x0, k);
}

/// Normalize Halstead volume to 0-100 score.
pub fn normalizeHalstead(volume: f64, warning: f64, err: f64) f64 {
    const k = computeSteepness(warning, err);
    return sigmoidScore(volume, warning, k);
}

/// Normalize a ThresholdResult's structural metrics (function_length, params_count,
/// nesting_depth) to a 0-100 score by averaging their individual sigmoid scores.
pub fn normalizeStructural(tr: ThresholdResult, thresholds: MetricThresholds) f64 {
    const len_k = computeSteepness(thresholds.function_length_warning, thresholds.function_length_error);
    const len_score = sigmoidScore(@as(f64, @floatFromInt(tr.function_length)), thresholds.function_length_warning, len_k);

    const par_k = computeSteepness(thresholds.params_count_warning, thresholds.params_count_error);
    const par_score = sigmoidScore(@as(f64, @floatFromInt(tr.params_count)), thresholds.params_count_warning, par_k);

    const nest_k = computeSteepness(thresholds.nesting_depth_warning, thresholds.nesting_depth_error);
    const nest_score = sigmoidScore(@as(f64, @floatFromInt(tr.nesting_depth)), thresholds.nesting_depth_warning, nest_k);

    return (len_score + par_score + nest_score) / 3.0;
}

/// Resolve effective weights from optional WeightsConfig.
/// Defaults: cyclomatic=0.20, cognitive=0.30, halstead=0.15, structural=0.15, duplication=0.20.
/// When duplication_enabled=true: includes duplication weight and normalizes all 5 to sum 1.0.
/// When duplication_enabled=false: duplication=0.0, normalizes 4 weights to sum 1.0 (existing behavior).
/// If all active weights are zero, returns equal weights as fallback.
pub fn resolveEffectiveWeights(weights: ?WeightsConfig, duplication_enabled: bool) EffectiveWeights {
    const defaults_cycl: f64 = 0.20;
    const defaults_cogn: f64 = 0.30;
    const defaults_hal: f64 = 0.15;
    const defaults_str: f64 = 0.15;
    const defaults_dup: f64 = 0.20;

    var w_cycl: f64 = defaults_cycl;
    var w_cogn: f64 = defaults_cogn;
    var w_hal: f64 = defaults_hal;
    var w_str: f64 = defaults_str;
    var w_dup: f64 = defaults_dup;

    if (weights) |w| {
        if (w.cyclomatic) |v| w_cycl = v;
        if (w.cognitive) |v| w_cogn = v;
        if (w.halstead) |v| w_hal = v;
        if (w.structural) |v| w_str = v;
        if (w.duplication) |v| w_dup = v;
    }

    if (!duplication_enabled) {
        // 4-metric mode: duplication excluded, normalize remaining 4 weights
        const total = w_cycl + w_cogn + w_hal + w_str;
        if (total == 0.0) {
            return EffectiveWeights{
                .cyclomatic = 0.25,
                .cognitive = 0.25,
                .halstead = 0.25,
                .structural = 0.25,
                .duplication = 0.0,
            };
        }
        return EffectiveWeights{
            .cyclomatic = w_cycl / total,
            .cognitive = w_cogn / total,
            .halstead = w_hal / total,
            .structural = w_str / total,
            .duplication = 0.0,
        };
    } else {
        // 5-metric mode: include duplication weight, normalize all 5
        const total = w_cycl + w_cogn + w_hal + w_str + w_dup;
        if (total == 0.0) {
            return EffectiveWeights{
                .cyclomatic = 0.2,
                .cognitive = 0.2,
                .halstead = 0.2,
                .structural = 0.2,
                .duplication = 0.2,
            };
        }
        return EffectiveWeights{
            .cyclomatic = w_cycl / total,
            .cognitive = w_cogn / total,
            .halstead = w_hal / total,
            .structural = w_str / total,
            .duplication = w_dup / total,
        };
    }
}

/// Normalize a duplication percentage (0-100) to a 0-100 health score.
/// Uses sigmoid so that warning_pct maps to 50 and error_pct maps to ~20.
pub fn normalizeDuplication(duplication_pct: f64, warning_pct: f64, error_pct: f64) f64 {
    const k = computeSteepness(warning_pct, error_pct);
    return sigmoidScore(duplication_pct, warning_pct, k);
}

/// Compute a file-level health score blending function scores with a duplication score.
/// When weights.duplication > 0, blends: base_file_score * (1 - dup_weight) + dup_score * dup_weight.
/// When weights.duplication == 0, returns base_file_score unchanged.
pub fn computeFileScoreWithDuplication(base_file_score: f64, dup_score: f64, weights: EffectiveWeights) f64 {
    if (weights.duplication == 0.0) return base_file_score;
    // Re-normalize the non-duplication portion to sum 1.0
    const non_dup_weight = 1.0 - weights.duplication;
    return base_file_score * non_dup_weight + dup_score * weights.duplication;
}

/// Compute composite function score from a ThresholdResult.
/// Returns a ScoreBreakdown with per-metric scores and weighted total.
pub fn computeFunctionScore(tr: ThresholdResult, weights: EffectiveWeights, thresholds: MetricThresholds) ScoreBreakdown {
    const cycl_score = normalizeCyclomatic(
        tr.complexity,
        @as(u32, @intFromFloat(thresholds.cyclomatic_warning)),
        @as(u32, @intFromFloat(thresholds.cyclomatic_error)),
    );
    const cogn_score = normalizeCognitive(
        tr.cognitive_complexity,
        @as(u32, @intFromFloat(thresholds.cognitive_warning)),
        @as(u32, @intFromFloat(thresholds.cognitive_error)),
    );
    const hal_score = normalizeHalstead(
        tr.halstead_volume,
        thresholds.halstead_warning,
        thresholds.halstead_error,
    );
    const str_score = normalizeStructural(tr, thresholds);

    const total = cycl_score * weights.cyclomatic +
        cogn_score * weights.cognitive +
        hal_score * weights.halstead +
        str_score * weights.structural;

    return ScoreBreakdown{
        .cyclomatic_score = cycl_score,
        .cognitive_score = cogn_score,
        .halstead_score = hal_score,
        .structural_score = str_score,
        .weights = weights,
        .total = total,
    };
}

/// Compute composite function score using pre-computed steepness values.
/// Faster than computeFunctionScore when scoring many functions with the same thresholds.
pub fn computeFunctionScorePrecomputed(
    tr: ThresholdResult,
    weights: EffectiveWeights,
    thresholds: MetricThresholds,
    k: PrecomputedSteepness,
) ScoreBreakdown {
    const cycl_score = sigmoidScore(@as(f64, @floatFromInt(tr.complexity)), thresholds.cyclomatic_warning, k.cyclomatic_k);
    const cogn_score = sigmoidScore(@as(f64, @floatFromInt(tr.cognitive_complexity)), thresholds.cognitive_warning, k.cognitive_k);
    const hal_score = sigmoidScore(tr.halstead_volume, thresholds.halstead_warning, k.halstead_k);

    const len_score = sigmoidScore(@as(f64, @floatFromInt(tr.function_length)), thresholds.function_length_warning, k.function_length_k);
    const par_score = sigmoidScore(@as(f64, @floatFromInt(tr.params_count)), thresholds.params_count_warning, k.params_count_k);
    const nest_score = sigmoidScore(@as(f64, @floatFromInt(tr.nesting_depth)), thresholds.nesting_depth_warning, k.nesting_depth_k);
    const str_score = (len_score + par_score + nest_score) / 3.0;

    const total = cycl_score * weights.cyclomatic +
        cogn_score * weights.cognitive +
        hal_score * weights.halstead +
        str_score * weights.structural;

    return ScoreBreakdown{
        .cyclomatic_score = cycl_score,
        .cognitive_score = cogn_score,
        .halstead_score = hal_score,
        .structural_score = str_score,
        .weights = weights,
        .total = total,
    };
}

/// Compute file score as the average of function scores.
/// Returns 100.0 for empty files (no functions).
pub fn computeFileScore(function_scores: []const f64) f64 {
    if (function_scores.len == 0) return 100.0;
    var sum: f64 = 0.0;
    for (function_scores) |s| sum += s;
    return sum / @as(f64, @floatFromInt(function_scores.len));
}

/// Compute project score as function-count-weighted average of file scores.
/// Returns 100.0 when no files (or all files have zero functions).
pub fn computeProjectScore(file_scores: []const f64, function_counts: []const u32) f64 {
    if (file_scores.len == 0) return 100.0;

    var weighted_sum: f64 = 0.0;
    var total_functions: u32 = 0;

    for (file_scores, function_counts) |score, count| {
        weighted_sum += score * @as(f64, @floatFromInt(count));
        total_functions += count;
    }

    if (total_functions == 0) return 100.0;

    return weighted_sum / @as(f64, @floatFromInt(total_functions));
}

// TESTS

test "sigmoidScore returns ~100 when x is 0" {
    const k = computeSteepness(10.0, 20.0);
    const score = sigmoidScore(0.0, 10.0, k);
    // At x=0 (warning=10, error=20): 100/(1+exp(k*(-10))) = 100/(1+0.25) = 80
    // The function approaches 100 as x approaches -infinity; at x=0 it's 80
    try std.testing.expect(score > 75.0);
    try std.testing.expect(score <= 100.0);
}

test "sigmoidScore returns exactly 50 when x equals x0" {
    const k = computeSteepness(10.0, 20.0);
    const score = sigmoidScore(10.0, 10.0, k);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), score, 0.001);
}

test "sigmoidScore returns ~20 when x equals error threshold" {
    const k = computeSteepness(10.0, 20.0);
    const score = sigmoidScore(20.0, 10.0, k);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), score, 0.1);
}

test "sigmoidScore degrades smoothly (no hard cutoffs)" {
    const k = computeSteepness(10.0, 20.0);
    var prev = sigmoidScore(0.0, 10.0, k);
    var x: f64 = 1.0;
    while (x <= 50.0) : (x += 1.0) {
        const curr = sigmoidScore(x, 10.0, k);
        try std.testing.expect(curr < prev);
        try std.testing.expect(curr > 0.0);
        prev = curr;
    }
}

test "sigmoidScore at extreme value is very low but > 0" {
    const k = computeSteepness(10.0, 20.0);
    const score = sigmoidScore(50.0, 10.0, k);
    try std.testing.expect(score > 0.0);
    try std.testing.expect(score < 5.0);
}

test "normalizeCyclomatic: below warning = high score" {
    const score = normalizeCyclomatic(5, 10, 20);
    // At half the warning threshold, sigmoid gives ~66.7 (above midpoint 50)
    try std.testing.expect(score > 60.0);
}

test "normalizeCyclomatic: at warning = 50" {
    const score = normalizeCyclomatic(10, 10, 20);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), score, 0.1);
}

test "normalizeCyclomatic: at error = ~20" {
    const score = normalizeCyclomatic(20, 10, 20);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), score, 0.5);
}

test "normalizeCognitive: below warning = high score" {
    const score = normalizeCognitive(3, 15, 25);
    // At x=3 (well below warning=15), sigmoid gives ~84
    try std.testing.expect(score > 80.0);
}

test "normalizeHalstead: below warning = high score" {
    const score = normalizeHalstead(100.0, 500.0, 1000.0);
    // At volume=100 (well below warning=500), sigmoid gives ~75
    try std.testing.expect(score > 70.0);
}

test "normalizeStructural: low values = high score" {
    const tr = ThresholdResult{
        .complexity = 1,
        .status = .ok,
        .function_name = "test",
        .function_kind = "function",
        .start_line = 1,
        .start_col = 0,
        .cognitive_complexity = 0,
        .cognitive_status = .ok,
        .function_length = 5,
        .params_count = 1,
        .nesting_depth = 1,
        .end_line = 6,
    };
    const thresholds = MetricThresholds{
        .cyclomatic_warning = 10,
        .cyclomatic_error = 20,
        .cognitive_warning = 15,
        .cognitive_error = 25,
        .halstead_warning = 500,
        .halstead_error = 1000,
        .function_length_warning = 30,
        .function_length_error = 60,
        .params_count_warning = 4,
        .params_count_error = 8,
        .nesting_depth_warning = 3,
        .nesting_depth_error = 6,
    };
    const score = normalizeStructural(tr, thresholds);
    // Average of 3 sub-metrics (each sigmoid below their warning thresholds): ~73
    try std.testing.expect(score > 65.0);
}

test "resolveEffectiveWeights: defaults normalize to 1.0 (duplication disabled)" {
    const ew = resolveEffectiveWeights(null, false);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.375), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1875), ew.halstead, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1875), ew.structural, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ew.duplication, 0.0001);
}

test "resolveEffectiveWeights: weight of 0 excludes metric" {
    const w = WeightsConfig{
        .cyclomatic = 0.0,
        .cognitive = 0.6,
        .halstead = 0.2,
        .structural = 0.2,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w, false);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ew.cyclomatic, 0.0001);
}

test "resolveEffectiveWeights: all 4 weights zero returns 0.25 each (duplication disabled)" {
    const w = WeightsConfig{
        .cyclomatic = 0.0,
        .cognitive = 0.0,
        .halstead = 0.0,
        .structural = 0.0,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w, false);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.halstead, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.structural, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ew.duplication, 0.0001);
}

test "resolveEffectiveWeights: partial override normalizes correctly" {
    const w = WeightsConfig{
        .cyclomatic = 0.5,
        .cognitive = null,
        .halstead = null,
        .structural = null,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w, false);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.50 / 1.10), ew.cyclomatic, 0.0001);
}

test "resolveEffectiveWeights: duplication disabled ignores duplication weight" {
    const w = WeightsConfig{
        .cyclomatic = 0.20,
        .cognitive = 0.30,
        .halstead = 0.15,
        .structural = 0.15,
        .duplication = 0.99,
    };
    const ew = resolveEffectiveWeights(w, false);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ew.duplication, 0.0001);
}

test "resolveEffectiveWeights: duplication enabled normalizes 5 weights" {
    const w = WeightsConfig{
        .cyclomatic = 0.20,
        .cognitive = 0.30,
        .halstead = 0.15,
        .structural = 0.15,
        .duplication = 0.20,
    };
    const ew = resolveEffectiveWeights(w, true);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural + ew.duplication;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    // Each weight = w / 1.0 since they sum exactly to 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.20), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.30), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.20), ew.duplication, 0.0001);
}

test "resolveEffectiveWeights: duplication enabled all zero returns equal 5 weights" {
    const w = WeightsConfig{
        .cyclomatic = 0.0,
        .cognitive = 0.0,
        .halstead = 0.0,
        .structural = 0.0,
        .duplication = 0.0,
    };
    const ew = resolveEffectiveWeights(w, true);
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), ew.duplication, 0.0001);
}

test "computeFunctionScore: returns breakdown within 0-100" {
    const tr = ThresholdResult{
        .complexity = 5,
        .status = .ok,
        .function_name = "test",
        .function_kind = "function",
        .start_line = 1,
        .start_col = 0,
        .cognitive_complexity = 3,
        .cognitive_status = .ok,
        .halstead_volume = 100.0,
        .function_length = 10,
        .params_count = 2,
        .nesting_depth = 1,
        .end_line = 11,
    };
    const thresholds = MetricThresholds{
        .cyclomatic_warning = 10,
        .cyclomatic_error = 20,
        .cognitive_warning = 15,
        .cognitive_error = 25,
        .halstead_warning = 500,
        .halstead_error = 1000,
        .function_length_warning = 30,
        .function_length_error = 60,
        .params_count_warning = 4,
        .params_count_error = 8,
        .nesting_depth_warning = 3,
        .nesting_depth_error = 6,
    };
    const weights = resolveEffectiveWeights(null, false);
    const breakdown = computeFunctionScore(tr, weights, thresholds);

    try std.testing.expect(breakdown.total >= 0.0);
    try std.testing.expect(breakdown.total <= 100.0);
    try std.testing.expect(breakdown.total > 70.0);
}

test "computeFunctionScorePrecomputed: matches computeFunctionScore" {
    const tr = ThresholdResult{
        .complexity = 5,
        .status = .ok,
        .function_name = "test",
        .function_kind = "function",
        .start_line = 1,
        .start_col = 0,
        .cognitive_complexity = 3,
        .cognitive_status = .ok,
        .halstead_volume = 100.0,
        .function_length = 10,
        .params_count = 2,
        .nesting_depth = 1,
        .end_line = 11,
    };
    const thresholds = MetricThresholds{
        .cyclomatic_warning = 10,
        .cyclomatic_error = 20,
        .cognitive_warning = 15,
        .cognitive_error = 25,
        .halstead_warning = 500,
        .halstead_error = 1000,
        .function_length_warning = 30,
        .function_length_error = 60,
        .params_count_warning = 4,
        .params_count_error = 8,
        .nesting_depth_warning = 3,
        .nesting_depth_error = 6,
    };
    const weights = resolveEffectiveWeights(null, false);
    const k = PrecomputedSteepness.init(thresholds);
    const precomputed = computeFunctionScorePrecomputed(tr, weights, thresholds, k);
    const original = computeFunctionScore(tr, weights, thresholds);
    try std.testing.expectApproxEqAbs(original.total, precomputed.total, 0.0001);
    try std.testing.expectApproxEqAbs(original.cyclomatic_score, precomputed.cyclomatic_score, 0.0001);
    try std.testing.expectApproxEqAbs(original.cognitive_score, precomputed.cognitive_score, 0.0001);
    try std.testing.expectApproxEqAbs(original.halstead_score, precomputed.halstead_score, 0.0001);
    try std.testing.expectApproxEqAbs(original.structural_score, precomputed.structural_score, 0.0001);
}

test "computeFileScore: average of function scores" {
    const scores = [_]f64{ 80.0, 60.0, 100.0 };
    const result = computeFileScore(&scores);
    try std.testing.expectApproxEqAbs(@as(f64, 80.0), result, 0.001);
}

test "computeFileScore: empty file returns 100" {
    const scores = [_]f64{};
    const result = computeFileScore(&scores);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), result, 0.001);
}

test "computeProjectScore: function-count-weighted average" {
    const scores = [_]f64{ 90.0, 50.0 };
    const counts = [_]u32{ 10, 30 };
    const result = computeProjectScore(&scores, &counts);
    try std.testing.expectApproxEqAbs(@as(f64, 60.0), result, 0.001);
}

test "computeProjectScore: empty project returns 100" {
    const scores = [_]f64{};
    const counts = [_]u32{};
    const result = computeProjectScore(&scores, &counts);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), result, 0.001);
}

test "computeProjectScore: all files with zero functions returns 100" {
    const scores = [_]f64{ 80.0, 70.0 };
    const counts = [_]u32{ 0, 0 };
    const result = computeProjectScore(&scores, &counts);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), result, 0.001);
}

test "normalizeDuplication: 0% duplication gives high score" {
    const score = normalizeDuplication(0.0, 15.0, 25.0);
    try std.testing.expect(score > 80.0);
}

test "normalizeDuplication: at warning threshold gives ~50" {
    const score = normalizeDuplication(15.0, 15.0, 25.0);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), score, 0.1);
}

test "normalizeDuplication: at error threshold gives ~20" {
    const score = normalizeDuplication(25.0, 15.0, 25.0);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), score, 0.5);
}

test "computeFileScoreWithDuplication: zero duplication weight returns base score" {
    const weights = EffectiveWeights{
        .cyclomatic = 0.25,
        .cognitive = 0.25,
        .halstead = 0.25,
        .structural = 0.25,
        .duplication = 0.0,
    };
    const result = computeFileScoreWithDuplication(80.0, 50.0, weights);
    try std.testing.expectApproxEqAbs(@as(f64, 80.0), result, 0.001);
}

test "computeFileScoreWithDuplication: blends base and dup scores" {
    const weights = EffectiveWeights{
        .cyclomatic = 0.20,
        .cognitive = 0.30,
        .halstead = 0.15,
        .structural = 0.15,
        .duplication = 0.20,
    };
    // base=80, dup=60, expected = 80*0.8 + 60*0.2 = 64 + 12 = 76
    const result = computeFileScoreWithDuplication(80.0, 60.0, weights);
    try std.testing.expectApproxEqAbs(@as(f64, 76.0), result, 0.001);
}
