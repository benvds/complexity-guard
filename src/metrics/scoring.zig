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

/// Resolved and normalized weights for each metric family (duplication excluded).
pub const EffectiveWeights = struct {
    cyclomatic: f64,
    cognitive: f64,
    halstead: f64,
    structural: f64,
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

// TESTS

test "sigmoidScore returns ~100 when x is 0" {
    const k = computeSteepness(10.0, 20.0);
    const score = sigmoidScore(0.0, 10.0, k);
    try std.testing.expect(score > 95.0);
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
    try std.testing.expect(score > 80.0);
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
    try std.testing.expect(score > 90.0);
}

test "normalizeHalstead: below warning = high score" {
    const score = normalizeHalstead(100.0, 500.0, 1000.0);
    try std.testing.expect(score > 90.0);
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
    try std.testing.expect(score > 80.0);
}

test "resolveEffectiveWeights: defaults normalize to 1.0 (duplication excluded)" {
    const ew = resolveEffectiveWeights(null);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.375), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1875), ew.halstead, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1875), ew.structural, 0.0001);
}

test "resolveEffectiveWeights: weight of 0 excludes metric" {
    const w = WeightsConfig{
        .cyclomatic = 0.0,
        .cognitive = 0.6,
        .halstead = 0.2,
        .structural = 0.2,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), ew.cyclomatic, 0.0001);
}

test "resolveEffectiveWeights: all weights zero returns 0.25 each" {
    const w = WeightsConfig{
        .cyclomatic = 0.0,
        .cognitive = 0.0,
        .halstead = 0.0,
        .structural = 0.0,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cyclomatic, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.cognitive, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.halstead, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), ew.structural, 0.0001);
}

test "resolveEffectiveWeights: partial override normalizes correctly" {
    const w = WeightsConfig{
        .cyclomatic = 0.5,
        .cognitive = null,
        .halstead = null,
        .structural = null,
        .duplication = null,
    };
    const ew = resolveEffectiveWeights(w);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.50 / 1.10), ew.cyclomatic, 0.0001);
}

test "resolveEffectiveWeights: duplication weight is ignored" {
    const w = WeightsConfig{
        .cyclomatic = 0.20,
        .cognitive = 0.30,
        .halstead = 0.15,
        .structural = 0.15,
        .duplication = 0.99,
    };
    const ew = resolveEffectiveWeights(w);
    const total = ew.cyclomatic + ew.cognitive + ew.halstead + ew.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.0001);
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
    const weights = resolveEffectiveWeights(null);
    const breakdown = computeFunctionScore(tr, weights, thresholds);

    try std.testing.expect(breakdown.total >= 0.0);
    try std.testing.expect(breakdown.total <= 100.0);
    try std.testing.expect(breakdown.total > 70.0);
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
