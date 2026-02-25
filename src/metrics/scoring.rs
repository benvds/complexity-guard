use crate::types::{ScoringThresholds, ScoringWeights};

/// Core sigmoid normalization: returns 50.0 at x=x0, ~20 at error threshold.
/// Formula: 100 / (1 + exp(k * (x - x0)))
pub fn sigmoid_score(x: f64, x0: f64, k: f64) -> f64 {
    100.0 / (1.0 + (k * (x - x0)).exp())
}

/// Derives sigmoid steepness k from warning/error thresholds.
/// k = ln(4) / (error - warning) so that at error threshold score ~ 20.
/// Guard: if warning >= error, return 1.0 (steep falloff).
pub fn compute_steepness(warning: f64, error: f64) -> f64 {
    if error <= warning {
        return 1.0;
    }
    4_f64.ln() / (error - warning)
}

/// Compute composite function health score from individual metrics.
///
/// Applies sigmoid normalization to each metric, then returns a weighted average.
/// The structural sub-score is the average of function_length, params_count,
/// and nesting_depth sigmoid scores.
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
    let cycl_k = compute_steepness(thresholds.cyclomatic_warning, thresholds.cyclomatic_error);
    let cycl_score = sigmoid_score(cyclomatic as f64, thresholds.cyclomatic_warning, cycl_k);

    // Cognitive
    let cogn_k = compute_steepness(thresholds.cognitive_warning, thresholds.cognitive_error);
    let cogn_score = sigmoid_score(cognitive as f64, thresholds.cognitive_warning, cogn_k);

    // Halstead
    let hal_k = compute_steepness(thresholds.halstead_warning, thresholds.halstead_error);
    let hal_score = sigmoid_score(halstead_volume, thresholds.halstead_warning, hal_k);

    // Structural: average of 3 sub-metrics
    let len_k = compute_steepness(
        thresholds.function_length_warning,
        thresholds.function_length_error,
    );
    let len_score = sigmoid_score(
        function_length as f64,
        thresholds.function_length_warning,
        len_k,
    );

    let par_k = compute_steepness(
        thresholds.params_count_warning,
        thresholds.params_count_error,
    );
    let par_score = sigmoid_score(params_count as f64, thresholds.params_count_warning, par_k);

    let nest_k = compute_steepness(
        thresholds.nesting_depth_warning,
        thresholds.nesting_depth_error,
    );
    let nest_score = sigmoid_score(
        nesting_depth as f64,
        thresholds.nesting_depth_warning,
        nest_k,
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
    fn sigmoid_score_at_x0_is_50() {
        let k = compute_steepness(10.0, 20.0);
        let score = sigmoid_score(10.0, 10.0, k);
        assert_float_eq(score, 50.0, "sigmoid at x0");
    }

    #[test]
    fn sigmoid_score_at_error_is_about_20() {
        let k = compute_steepness(10.0, 20.0);
        let score = sigmoid_score(20.0, 10.0, k);
        assert!(
            (score - 20.0).abs() < 0.5,
            "sigmoid at error should be ~20, got {}",
            score
        );
    }

    #[test]
    fn sigmoid_score_below_warning_is_high() {
        let k = compute_steepness(10.0, 20.0);
        let score = sigmoid_score(0.0, 10.0, k);
        assert!(
            score > 75.0,
            "sigmoid below warning should be >75, got {}",
            score
        );
        assert!(
            score <= 100.0,
            "sigmoid should not exceed 100, got {}",
            score
        );
    }

    #[test]
    fn sigmoid_degrades_smoothly() {
        let k = compute_steepness(10.0, 20.0);
        let mut prev = sigmoid_score(0.0, 10.0, k);
        for x in 1..=50 {
            let curr = sigmoid_score(x as f64, 10.0, k);
            assert!(curr < prev, "sigmoid should decrease monotonically");
            assert!(curr > 0.0, "sigmoid should always be > 0");
            prev = curr;
        }
    }

    #[test]
    fn compute_steepness_ln4_over_10() {
        let k = compute_steepness(10.0, 20.0);
        let expected = 4_f64.ln() / 10.0;
        assert_float_eq(k, expected, "steepness(10,20)");
    }

    #[test]
    fn compute_steepness_equal_thresholds() {
        let k = compute_steepness(10.0, 10.0);
        assert_float_eq(k, 1.0, "steepness when error==warning");
    }

    #[test]
    fn compute_steepness_error_below_warning() {
        let k = compute_steepness(20.0, 10.0);
        assert_float_eq(k, 1.0, "steepness when error<warning");
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
            score > 70.0,
            "low complexity should yield high score, got {}",
            score
        );
        assert!(score <= 100.0, "score should not exceed 100, got {}", score);
    }

    #[test]
    fn function_score_at_warning_around_50() {
        let weights = ScoringWeights::default();
        let thresholds = ScoringThresholds::default();
        // All metrics at their warning thresholds
        let score = compute_function_score(10, 15, 500.0, 30, 4, 3, &weights, &thresholds);
        assert!(
            (score - 50.0).abs() < 5.0,
            "at warning thresholds, score should be ~50, got {}",
            score
        );
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
