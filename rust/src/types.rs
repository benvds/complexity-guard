use std::path::PathBuf;

/// Information about a single function extracted from a parsed source file.
///
/// All fields are owned data types suitable for cross-thread use.
/// Line numbers are 1-indexed, columns are 0-indexed.
#[derive(Debug, Clone)]
pub struct FunctionInfo {
    pub name: String,
    pub start_line: usize,
    pub start_column: usize,
    pub end_line: usize,
}

/// Result of parsing a single source file.
///
/// Contains only owned data — no references to tree-sitter `Node` or `Tree`.
#[derive(Debug, Clone)]
pub struct ParseResult {
    pub path: PathBuf,
    pub functions: Vec<FunctionInfo>,
    pub source_len: usize,
    pub error: bool,
}

/// Errors that can occur during file parsing.
#[derive(thiserror::Error, Debug)]
pub enum ParseError {
    #[error("unsupported file extension: {0}")]
    UnsupportedExtension(String),

    #[error("file has no extension")]
    NoExtension,

    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("language setup error: {0}")]
    LanguageError(String),

    #[error("tree-sitter parse returned None")]
    ParseFailed,
}

// --- Metric types ---

/// Switch/case counting modes for cyclomatic complexity.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
pub enum SwitchCaseMode {
    /// Each case increments complexity (+1 per case).
    Classic,
    /// Entire switch counts as single decision (+1 total).
    Modified,
}

/// Configuration for cyclomatic complexity calculation.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CyclomaticConfig {
    pub count_logical_operators: bool,
    pub count_nullish_coalescing: bool,
    pub count_optional_chaining: bool,
    pub count_ternary: bool,
    pub count_default_params: bool,
    pub switch_case_mode: SwitchCaseMode,
    pub warning_threshold: u32,
    pub error_threshold: u32,
}

impl Default for CyclomaticConfig {
    fn default() -> Self {
        Self {
            count_logical_operators: true,
            count_nullish_coalescing: true,
            count_optional_chaining: true,
            count_ternary: true,
            count_default_params: true,
            switch_case_mode: SwitchCaseMode::Classic,
            warning_threshold: 10,
            error_threshold: 20,
        }
    }
}

/// Per-function cyclomatic complexity result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CyclomaticResult {
    pub name: String,
    pub complexity: u32,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

/// Per-function structural metric result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct StructuralResult {
    pub name: String,
    pub function_length: u32,
    pub params_count: u32,
    pub nesting_depth: u32,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

/// Per-file structural metric result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct FileStructuralResult {
    pub file_length: u32,
    pub export_count: u32,
}

/// Per-function cognitive complexity result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CognitiveResult {
    pub name: String,
    pub complexity: u32,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

/// Configuration for cognitive complexity calculation.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CognitiveConfig {
    pub warning_threshold: u32,
    pub error_threshold: u32,
}

impl Default for CognitiveConfig {
    fn default() -> Self {
        Self {
            warning_threshold: 15,
            error_threshold: 30,
        }
    }
}

/// Per-function Halstead metrics result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct HalsteadResult {
    pub name: String,
    pub volume: f64,
    pub difficulty: f64,
    pub effort: f64,
    pub time: f64,
    pub bugs: f64,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

// --- Scoring types ---

/// Weight configuration for composite health scoring.
///
/// Weights are normalized to sum 1.0 before use.
/// When duplication is disabled, the duplication weight is excluded
/// and the remaining four weights are re-normalized.
#[derive(Debug, Clone, serde::Serialize)]
pub struct ScoringWeights {
    pub cyclomatic: f64,
    pub cognitive: f64,
    pub halstead: f64,
    pub structural: f64,
    pub duplication: f64,
}

impl Default for ScoringWeights {
    fn default() -> Self {
        Self {
            cyclomatic: 0.20,
            cognitive: 0.30,
            halstead: 0.15,
            structural: 0.15,
            duplication: 0.20,
        }
    }
}

/// Per-metric threshold pairs for sigmoid scoring.
///
/// Each metric has a warning and error threshold. The sigmoid
/// returns 50 at the warning threshold and ~20 at the error threshold.
#[derive(Debug, Clone, serde::Serialize)]
pub struct ScoringThresholds {
    pub cyclomatic_warning: f64,
    pub cyclomatic_error: f64,
    pub cognitive_warning: f64,
    pub cognitive_error: f64,
    pub halstead_warning: f64,
    pub halstead_error: f64,
    pub function_length_warning: f64,
    pub function_length_error: f64,
    pub params_count_warning: f64,
    pub params_count_error: f64,
    pub nesting_depth_warning: f64,
    pub nesting_depth_error: f64,
}

impl Default for ScoringThresholds {
    fn default() -> Self {
        Self {
            cyclomatic_warning: 10.0,
            cyclomatic_error: 20.0,
            cognitive_warning: 15.0,
            cognitive_error: 25.0,
            halstead_warning: 500.0,
            halstead_error: 1000.0,
            function_length_warning: 25.0,
            function_length_error: 50.0,
            params_count_warning: 3.0,
            params_count_error: 6.0,
            nesting_depth_warning: 3.0,
            nesting_depth_error: 5.0,
        }
    }
}

// --- Duplication types ---

/// A single normalized token extracted from an AST leaf node.
#[derive(Debug, Clone, serde::Serialize)]
pub struct Token {
    pub kind: String,
    pub start_byte: usize,
    pub end_byte: usize,
    pub file_index: usize,
}

/// A single instance of a clone at a specific location.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CloneInstance {
    pub file_index: usize,
    pub start_token: usize,
    pub end_token: usize,
    pub start_line: usize,
    pub end_line: usize,
}

/// A detected clone group: two or more locations with the same normalized token sequence.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CloneGroup {
    pub instances: Vec<CloneInstance>,
    pub token_count: u32,
}

/// Result of duplication detection across files.
#[derive(Debug, Clone, serde::Serialize)]
pub struct DuplicationResult {
    pub clone_groups: Vec<CloneGroup>,
    pub total_tokens: usize,
    pub cloned_tokens: usize,
    pub duplication_percentage: f64,
}

/// Configuration for duplication detection.
#[derive(Debug, Clone, serde::Serialize)]
pub struct DuplicationConfig {
    pub min_tokens: u32,
    pub enabled: bool,
}

impl Default for DuplicationConfig {
    fn default() -> Self {
        Self {
            min_tokens: 25,
            enabled: true,
        }
    }
}

// --- Analysis result types ---

/// Combined per-function metrics with health score.
#[derive(Debug, Clone, serde::Serialize)]
pub struct FunctionAnalysisResult {
    pub name: String,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
    pub cyclomatic: u32,
    pub cognitive: u32,
    pub halstead_volume: f64,
    pub halstead_difficulty: f64,
    pub halstead_effort: f64,
    pub halstead_time: f64,
    pub halstead_bugs: f64,
    pub function_length: u32,
    pub params_count: u32,
    pub nesting_depth: u32,
    pub health_score: f64,
}

/// Per-file analysis result containing all metrics.
#[derive(Debug, Clone, serde::Serialize)]
pub struct FileAnalysisResult {
    pub path: PathBuf,
    pub functions: Vec<FunctionAnalysisResult>,
    pub tokens: Vec<Token>,
    pub file_score: f64,
    pub file_length: u32,
    pub export_count: u32,
    pub error: bool,
}

/// Combined configuration for all metric analyses.
#[derive(Debug, Clone)]
pub struct AnalysisConfig {
    pub cyclomatic: CyclomaticConfig,
    pub cognitive: CognitiveConfig,
    pub scoring_weights: ScoringWeights,
    pub scoring_thresholds: ScoringThresholds,
    pub duplication: DuplicationConfig,
}

impl Default for AnalysisConfig {
    fn default() -> Self {
        Self {
            cyclomatic: CyclomaticConfig::default(),
            cognitive: CognitiveConfig::default(),
            scoring_weights: ScoringWeights::default(),
            scoring_thresholds: ScoringThresholds::default(),
            duplication: DuplicationConfig::default(),
        }
    }
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cyclomatic_config_default_matches_zig() {
        let config = CyclomaticConfig::default();
        assert!(config.count_logical_operators);
        assert!(config.count_nullish_coalescing);
        assert!(config.count_optional_chaining);
        assert!(config.count_ternary);
        assert!(config.count_default_params);
        assert_eq!(config.switch_case_mode, SwitchCaseMode::Classic);
        assert_eq!(config.warning_threshold, 10);
        assert_eq!(config.error_threshold, 20);
    }

    #[test]
    fn cognitive_config_default_matches_zig() {
        let config = CognitiveConfig::default();
        assert_eq!(config.warning_threshold, 15);
        assert_eq!(config.error_threshold, 30);
    }

    #[test]
    fn scoring_weights_default() {
        let w = ScoringWeights::default();
        assert!((w.cyclomatic - 0.20).abs() < 1e-10);
        assert!((w.cognitive - 0.30).abs() < 1e-10);
        assert!((w.halstead - 0.15).abs() < 1e-10);
        assert!((w.structural - 0.15).abs() < 1e-10);
        assert!((w.duplication - 0.20).abs() < 1e-10);
    }

    #[test]
    fn scoring_thresholds_default() {
        let t = ScoringThresholds::default();
        assert!((t.cyclomatic_warning - 10.0).abs() < 1e-10);
        assert!((t.cyclomatic_error - 20.0).abs() < 1e-10);
        assert!((t.cognitive_warning - 15.0).abs() < 1e-10);
        assert!((t.cognitive_error - 25.0).abs() < 1e-10);
        assert!((t.halstead_warning - 500.0).abs() < 1e-10);
        assert!((t.halstead_error - 1000.0).abs() < 1e-10);
        assert!((t.function_length_warning - 25.0).abs() < 1e-10);
        assert!((t.function_length_error - 50.0).abs() < 1e-10);
        assert!((t.params_count_warning - 3.0).abs() < 1e-10);
        assert!((t.params_count_error - 6.0).abs() < 1e-10);
        assert!((t.nesting_depth_warning - 3.0).abs() < 1e-10);
        assert!((t.nesting_depth_error - 5.0).abs() < 1e-10);
    }

    #[test]
    fn duplication_config_default() {
        let c = DuplicationConfig::default();
        assert_eq!(c.min_tokens, 25);
        assert!(c.enabled);
    }

    #[test]
    fn analysis_config_default() {
        let c = AnalysisConfig::default();
        assert_eq!(c.cyclomatic.warning_threshold, 10);
        assert_eq!(c.cognitive.warning_threshold, 15);
        assert!((c.scoring_weights.cyclomatic - 0.20).abs() < 1e-10);
        assert!((c.scoring_thresholds.cyclomatic_warning - 10.0).abs() < 1e-10);
        assert!(c.duplication.enabled);
    }
}
