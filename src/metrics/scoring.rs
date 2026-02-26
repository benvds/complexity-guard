use crate::types::{ScoringThresholds, ScoringWeights};

/// Piecewise linear score: maps a metric value to 0-100 using warning/error thresholds.
///
/// - `score(0) = 100` (zero complexity is perfect)
/// - `score(warning) = 80` (boundary between "good" and "ok")
/// - `score(error) = 60` (boundary between "ok" and "bad")
/// - `score(2 * error) = 0` (floor)
///
/// Three segments:
/// - `[0, warn]`  → `[100, 80]`
/// - `(warn, err]` → `(80, 60]`
/// - `(err, 2*err]` → `(60, 0]`
pub fn linear_score(x: f64, warning: f64, error: f64) -> f64 {
    if x <= 0.0 {
        return 100.0;
    }
    if warning <= 0.0 || error <= 0.0 || error <= warning {
        // Degenerate thresholds: clamp to 0 if x > 0
        return 0.0;
    }
    if x <= warning {
        100.0 - 20.0 * (x / warning)
    } else if x <= error {
        80.0 - 20.0 * ((x - warning) / (error - warning))
    } else {
        (60.0 - 60.0 * ((x - error) / error)).max(0.0)
    }
}

/// Compute composite function health score from individual metrics.
///
/// Applies piecewise linear normalization to each metric, then returns a weighted average.
/// The structural sub-score is the average of function_length, params_count,
/// and nesting_depth linear scores.
#[allow(clippy::too_many_arguments)]
pub fn compute_function_score(
    cyclomatic: u32,
    cognitive: u32,
    halstead_volume: f64,
    function_length: u32,
    params_count: u32,
    nesting_depth: u32,
    weights: &ScoringWeights,
    thresholds: &ScoringThresholds,
) -> f64 {
    // Cyclomatic
    let cycl_score = linear_score(
        cyclomatic as f64,
        thresholds.cyclomatic_warning,
        thresholds.cyclomatic_error,
    );

    // Cognitive
    let cogn_score = linear_score(
        cognitive as f64,
        thresholds.cognitive_warning,
        thresholds.cognitive_error,
    );

    // Halstead
    let hal_score = linear_score(
        halstead_volume,
        thresholds.halstead_warning,
        thresholds.halstead_error,
    );

    // Structural: average of 3 sub-metrics
    let len_score = linear_score(
        function_length as f64,
        thresholds.function_length_warning,
        thresholds.function_length_error,
    );

    let par_score = linear_score(
        params_count as f64,
        thresholds.params_count_warning,
        thresholds.params_count_error,
    );

    let nest_score = linear_score(
        nesting_depth as f64,
        thresholds.nesting_depth_warning,
        thresholds.nesting_depth_error,
    );

    let str_score = (len_score + par_score + nest_score) / 3.0;

    // Resolve effective weights (4-metric mode: exclude duplication)
    let w_cycl = weights.cyclomatic;
    let w_cogn = weights.cognitive;
    let w_hal = weights.halstead;
    let w_str = weights.structural;

    let total_weight = w_cycl + w_cogn + w_hal + w_str;
    if total_weight == 0.0 {
        // Equal weights fallback
        return (cycl_score + cogn_score + hal_score + str_score) / 4.0;
    }

    // Normalized weighted average
    (cycl_score * w_cycl + cogn_score * w_cogn + hal_score * w_hal + str_score * w_str)
        / total_weight
}

/// Compute file score as arithmetic mean of function scores.
/// Returns 100.0 for empty files (no functions).
pub fn compute_file_score(function_scores: &[f64]) -> f64 {
    if function_scores.is_empty() {
        return 100.0;
    }
    let sum: f64 = function_scores.iter().sum();
    sum / function_scores.len() as f64
}

/// Compute project score as function-count-weighted average of file scores.
/// Returns 100.0 when no files or all files have zero functions.
pub fn compute_project_score(file_scores: &[f64], function_counts: &[u32]) -> f64 {
    if file_scores.is_empty() {
        return 100.0;
    }

    let mut weighted_sum: f64 = 0.0;
    let mut total_functions: u32 = 0;

    for (score, &count) in file_scores.iter().zip(function_counts.iter()) {
        weighted_sum += score * count as f64;
        total_functions += count;
    }

    if total_functions == 0 {
        return 100.0;
    }

    weighted_sum / total_functions as f64
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_float_eq(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-6,
            "{}: expected {}, got {} (diff {})",
            label,
            expected,
            actual,
            (actual - expected).abs()
        );
    }

    #[test]
    fn linear_score_at_zero_is_100() {
        let score = linear_score(0.0, 10.0, 20.0);
        assert_float_eq(score, 100.0, "linear at 0");
    }

    #[test]
    fn linear_score_at_warning_is_80() {
        let score = linear_score(10.0, 10.0, 20.0);
        assert_float_eq(score, 80.0, "linear at warning");
    }

    #[test]
    fn linear_score_at_error_is_60() {
        let score = linear_score(20.0, 10.0, 20.0);
        assert_float_eq(score, 60.0, "linear at error");
    }

    #[test]
    fn linear_score_at_double_error_is_0() {
        let score = linear_score(40.0, 10.0, 20.0);
        assert_float_eq(score, 0.0, "linear at 2*error");
    }

    #[test]
    fn linear_score_midway_in_first_segment() {
        // x=5, warn=10: 100 - 20*(5/10) = 90
        let score = linear_score(5.0, 10.0, 20.0);
        assert_float_eq(score, 90.0, "linear midway first segment");
    }

    #[test]
    fn linear_score_midway_in_second_segment() {
        // x=15, warn=10, err=20: 80 - 20*((15-10)/(20-10)) = 80 - 10 = 70
        let score = linear_score(15.0, 10.0, 20.0);
        assert_float_eq(score, 70.0, "linear midway second segment");
    }

    #[test]
    fn linear_score_midway_in_third_segment() {
        // x=30, warn=10, err=20: 60 - 60*((30-20)/20) = 60 - 30 = 30
        let score = linear_score(30.0, 10.0, 20.0);
        assert_float_eq(score, 30.0, "linear midway third segment");
    }

    #[test]
    fn linear_score_beyond_double_error_is_clamped() {
        let score = linear_score(50.0, 10.0, 20.0);
        assert_float_eq(score, 0.0, "linear beyond 2*error clamped to 0");
    }

    #[test]
    fn linear_score_negative_input_is_100() {
        let score = linear_score(-5.0, 10.0, 20.0);
        assert_float_eq(score, 100.0, "linear negative input");
    }

    #[test]
    fn linear_score_degrades_monotonically() {
        let mut prev = linear_score(0.0, 10.0, 20.0);
        for x in 1..=40 {
            let curr = linear_score(x as f64, 10.0, 20.0);
            assert!(
                curr <= prev,
                "linear should decrease monotonically: x={}, prev={}, curr={}",
                x,
                prev,
                curr
            );
            assert!(curr >= 0.0, "linear should always be >= 0");
            prev = curr;
        }
    }

    #[test]
    fn linear_score_degenerate_thresholds() {
        // warning >= error: returns 0 for x > 0
        assert_float_eq(linear_score(5.0, 10.0, 10.0), 0.0, "equal thresholds");
        assert_float_eq(linear_score(5.0, 20.0, 10.0), 0.0, "warning > error");
        // x <= 0 still returns 100
        assert_float_eq(linear_score(0.0, 10.0, 10.0), 100.0, "x=0 degenerate");
    }

    #[test]
    fn file_score_average() {
        let scores = [80.0, 60.0, 100.0];
        let result = compute_file_score(&scores);
        assert_float_eq(result, 80.0, "file_score average");
    }

    #[test]
    fn file_score_empty() {
        let result = compute_file_score(&[]);
        assert_float_eq(result, 100.0, "file_score empty");
    }

    #[test]
    fn project_score_weighted() {
        let scores = [90.0, 50.0];
        let counts = [10, 30];
        let result = compute_project_score(&scores, &counts);
        // (90*10 + 50*30) / 40 = (900 + 1500) / 40 = 60
        assert_float_eq(result, 60.0, "project_score weighted");
    }

    #[test]
    fn project_score_empty() {
        let result = compute_project_score(&[], &[]);
        assert_float_eq(result, 100.0, "project_score empty");
    }

    #[test]
    fn project_score_zero_functions() {
        let scores = [80.0, 70.0];
        let counts = [0, 0];
        let result = compute_project_score(&scores, &counts);
        assert_float_eq(result, 100.0, "project_score zero functions");
    }

    #[test]
    fn function_score_low_values_high_score() {
        let weights = ScoringWeights::default();
        let thresholds = ScoringThresholds::default();
        let score = compute_function_score(1, 0, 2.0, 1, 1, 0, &weights, &thresholds);
        assert!(
            score > 95.0,
            "low complexity should yield high score (>95), got {}",
            score
        );
        assert!(score <= 100.0, "score should not exceed 100, got {}", score);
    }

    #[test]
    fn function_score_at_warning_is_80() {
        let weights = ScoringWeights::default();
        let thresholds = ScoringThresholds::default();
        // All metrics at their warning thresholds
        let score = compute_function_score(10, 15, 500.0, 25, 3, 3, &weights, &thresholds);
        assert_float_eq(score, 80.0, "at warning thresholds, score should be 80");
    }

    #[test]
    fn function_score_at_error_is_60() {
        let weights = ScoringWeights::default();
        let thresholds = ScoringThresholds::default();
        // All metrics at their error thresholds
        let score = compute_function_score(20, 25, 1000.0, 50, 6, 5, &weights, &thresholds);
        assert_float_eq(score, 60.0, "at error thresholds, score should be 60");
    }

    #[test]
    fn weight_normalization_zero_weights() {
        let weights = ScoringWeights {
            cyclomatic: 0.0,
            cognitive: 0.0,
            halstead: 0.0,
            structural: 0.0,
            duplication: 0.0,
        };
        let thresholds = ScoringThresholds::default();
        let score = compute_function_score(5, 3, 100.0, 10, 2, 1, &weights, &thresholds);
        // Should use equal weights fallback
        assert!(
            score > 0.0 && score <= 100.0,
            "zero weights fallback should produce valid score, got {}",
            score
        );
    }

    #[test]
    fn weight_normalization_partial_zero() {
        let weights = ScoringWeights {
            cyclomatic: 0.0,
            cognitive: 0.6,
            halstead: 0.2,
            structural: 0.2,
            duplication: 0.0,
        };
        let thresholds = ScoringThresholds::default();
        let score = compute_function_score(5, 3, 100.0, 10, 2, 1, &weights, &thresholds);
        assert!(
            score > 0.0 && score <= 100.0,
            "partial zero weights should produce valid score, got {}",
            score
        );
    }
}
