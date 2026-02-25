/// Top-level configuration structure matching the locked schema.
///
/// All fields are optional to support partial configs and defaults.
/// Mirrors the Zig Config struct exactly.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct Config {
    pub output: Option<OutputConfig>,
    pub analysis: Option<AnalysisConfig>,
    pub files: Option<FilesConfig>,
    pub weights: Option<WeightsConfig>,
    pub overrides: Option<Vec<OverrideConfig>>,
    /// Baseline health score for ratchet enforcement.
    pub baseline: Option<f64>,
}

/// Output format and destination configuration.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct OutputConfig {
    /// Output format: "console", "json", "sarif", "html"
    pub format: Option<String>,
    /// Output file path
    pub file: Option<String>,
}

/// Analysis behavior configuration.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct AnalysisConfig {
    /// Enabled metrics (e.g. ["cyclomatic", "cognitive"])
    pub metrics: Option<Vec<String>>,
    pub thresholds: Option<ThresholdsConfig>,
    pub no_duplication: Option<bool>,
    pub duplication_enabled: Option<bool>,
    pub threads: Option<u32>,
}

/// Thresholds organized by metric type.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct ThresholdsConfig {
    pub cyclomatic: Option<ThresholdPair>,
    pub cognitive: Option<ThresholdPair>,
    pub halstead_volume: Option<ThresholdPair>,
    pub halstead_difficulty: Option<ThresholdPair>,
    pub halstead_effort: Option<ThresholdPair>,
    pub halstead_bugs: Option<ThresholdPair>,
    pub nesting_depth: Option<ThresholdPair>,
    pub line_count: Option<ThresholdPair>,
    pub params_count: Option<ThresholdPair>,
    pub file_length: Option<ThresholdPair>,
    pub export_count: Option<ThresholdPair>,
    pub duplication: Option<DuplicationThresholds>,
}

/// Warning and error threshold pair for a single metric.
///
/// Uses `error` as field name (valid in Rust unlike Zig where it needs `@"error"`).
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct ThresholdPair {
    pub warning: Option<u32>,
    pub error: Option<u32>,
}

/// Duplication percentage thresholds (floating-point).
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct DuplicationThresholds {
    pub file_warning: Option<f64>,
    pub file_error: Option<f64>,
    pub project_warning: Option<f64>,
    pub project_error: Option<f64>,
}

/// File inclusion/exclusion patterns.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct FilesConfig {
    pub include: Option<Vec<String>>,
    pub exclude: Option<Vec<String>>,
}

/// Weights for composite score calculation.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct WeightsConfig {
    pub cyclomatic: Option<f64>,
    pub cognitive: Option<f64>,
    pub duplication: Option<f64>,
    pub halstead: Option<f64>,
    pub structural: Option<f64>,
}

/// ESLint-style per-path override configuration.
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct OverrideConfig {
    /// Glob patterns (required)
    pub files: Vec<String>,
    pub analysis: Option<AnalysisConfig>,
}

/// Resolved (fully-defaulted, non-optional) configuration for use during analysis and output.
///
/// Created after merging defaults + config file + CLI args. Passed to renderers and workers.
#[derive(Debug, Clone)]
pub struct ResolvedConfig {
    // Output
    pub format: String,
    pub output_file: Option<String>,
    pub color: Option<bool>,
    pub quiet: bool,
    pub verbose: bool,
    // Analysis
    pub metrics: Vec<String>,
    // Thresholds (warning and error levels per metric)
    pub cyclomatic_warning: u32,
    pub cyclomatic_error: u32,
    pub cognitive_warning: u32,
    pub cognitive_error: u32,
    pub halstead_volume_warning: f64,
    pub halstead_volume_error: f64,
    pub halstead_difficulty_warning: f64,
    pub halstead_difficulty_error: f64,
    pub halstead_effort_warning: f64,
    pub halstead_effort_error: f64,
    pub halstead_bugs_warning: f64,
    pub halstead_bugs_error: f64,
    pub nesting_depth_warning: u32,
    pub nesting_depth_error: u32,
    pub line_count_warning: u32,
    pub line_count_error: u32,
    pub params_count_warning: u32,
    pub params_count_error: u32,
    // Threads
    pub threads: u32,
}

impl Default for ResolvedConfig {
    fn default() -> Self {
        Self {
            format: "console".to_string(),
            output_file: None,
            color: None,
            quiet: false,
            verbose: false,
            metrics: vec![
                "cyclomatic".to_string(),
                "cognitive".to_string(),
                "halstead".to_string(),
                "nesting".to_string(),
                "line_count".to_string(),
                "params_count".to_string(),
            ],
            // Thresholds matching Zig defaults
            cyclomatic_warning: 10,
            cyclomatic_error: 20,
            cognitive_warning: 15,
            cognitive_error: 25,
            halstead_volume_warning: 500.0,
            halstead_volume_error: 1000.0,
            halstead_difficulty_warning: 10.0,
            halstead_difficulty_error: 20.0,
            halstead_effort_warning: 5000.0,
            halstead_effort_error: 10000.0,
            halstead_bugs_warning: 0.5,
            halstead_bugs_error: 1.0,
            nesting_depth_warning: 3,
            nesting_depth_error: 5,
            line_count_warning: 25,
            line_count_error: 50,
            params_count_warning: 3,
            params_count_error: 6,
            threads: num_cpus(),
        }
    }
}

/// Returns number of available CPUs for default thread count.
fn num_cpus() -> u32 {
    std::thread::available_parallelism()
        .map(|n| n.get() as u32)
        .unwrap_or(1)
}

/// Resolves a merged Config into a ResolvedConfig with all defaults applied.
pub fn resolve_config(config: &Config) -> ResolvedConfig {
    let mut resolved = ResolvedConfig::default();

    if let Some(output) = &config.output {
        if let Some(fmt) = &output.format {
            resolved.format = fmt.clone();
        }
        if let Some(file) = &output.file {
            resolved.output_file = Some(file.clone());
        }
    }

    if let Some(analysis) = &config.analysis {
        if let Some(metrics) = &analysis.metrics {
            resolved.metrics = metrics.clone();
        }
        if let Some(threads) = analysis.threads {
            resolved.threads = threads;
        }
        if let Some(thresholds) = &analysis.thresholds {
            if let Some(t) = &thresholds.cyclomatic {
                if let Some(w) = t.warning {
                    resolved.cyclomatic_warning = w;
                }
                if let Some(e) = t.error {
                    resolved.cyclomatic_error = e;
                }
            }
            if let Some(t) = &thresholds.cognitive {
                if let Some(w) = t.warning {
                    resolved.cognitive_warning = w;
                }
                if let Some(e) = t.error {
                    resolved.cognitive_error = e;
                }
            }
            if let Some(t) = &thresholds.halstead_volume {
                if let Some(w) = t.warning {
                    resolved.halstead_volume_warning = w as f64;
                }
                if let Some(e) = t.error {
                    resolved.halstead_volume_error = e as f64;
                }
            }
            if let Some(t) = &thresholds.halstead_difficulty {
                if let Some(w) = t.warning {
                    resolved.halstead_difficulty_warning = w as f64;
                }
                if let Some(e) = t.error {
                    resolved.halstead_difficulty_error = e as f64;
                }
            }
            if let Some(t) = &thresholds.halstead_effort {
                if let Some(w) = t.warning {
                    resolved.halstead_effort_warning = w as f64;
                }
                if let Some(e) = t.error {
                    resolved.halstead_effort_error = e as f64;
                }
            }
            if let Some(t) = &thresholds.halstead_bugs {
                if let Some(w) = t.warning {
                    resolved.halstead_bugs_warning = w as f64;
                }
                if let Some(e) = t.error {
                    resolved.halstead_bugs_error = e as f64;
                }
            }
            if let Some(t) = &thresholds.nesting_depth {
                if let Some(w) = t.warning {
                    resolved.nesting_depth_warning = w;
                }
                if let Some(e) = t.error {
                    resolved.nesting_depth_error = e;
                }
            }
            if let Some(t) = &thresholds.line_count {
                if let Some(w) = t.warning {
                    resolved.line_count_warning = w;
                }
                if let Some(e) = t.error {
                    resolved.line_count_error = e;
                }
            }
            if let Some(t) = &thresholds.params_count {
                if let Some(w) = t.warning {
                    resolved.params_count_warning = w;
                }
                if let Some(e) = t.error {
                    resolved.params_count_error = e;
                }
            }
        }
    }

    resolved
}

/// Returns a Config with sensible default values.
///
/// Mirrors the Zig `defaults()` function exactly.
pub fn config_defaults() -> Config {
    Config {
        output: Some(OutputConfig {
            format: Some("console".to_string()),
            file: None,
        }),
        analysis: Some(AnalysisConfig {
            metrics: Some(vec![
                "cyclomatic".to_string(),
                "cognitive".to_string(),
                "halstead".to_string(),
                "nesting".to_string(),
                "line_count".to_string(),
                "params_count".to_string(),
            ]),
            thresholds: None,
            no_duplication: Some(false),
            duplication_enabled: Some(false),
            threads: None,
        }),
        files: None,
        weights: Some(WeightsConfig {
            cognitive: Some(0.30),
            cyclomatic: Some(0.20),
            duplication: Some(0.20),
            halstead: Some(0.15),
            structural: Some(0.15),
        }),
        overrides: None,
        baseline: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_defaults_output_format() {
        let config = config_defaults();
        let output = config.output.unwrap();
        assert_eq!(output.format, Some("console".to_string()));
        assert!(output.file.is_none());
    }

    #[test]
    fn test_config_defaults_analysis_metrics() {
        let config = config_defaults();
        let analysis = config.analysis.unwrap();
        let metrics = analysis.metrics.unwrap();
        assert_eq!(metrics.len(), 6);
        assert!(metrics.contains(&"cyclomatic".to_string()));
        assert!(metrics.contains(&"cognitive".to_string()));
        assert!(metrics.contains(&"halstead".to_string()));
        assert!(metrics.contains(&"nesting".to_string()));
        assert!(metrics.contains(&"line_count".to_string()));
        assert!(metrics.contains(&"params_count".to_string()));
    }

    #[test]
    fn test_config_defaults_no_duplication() {
        let config = config_defaults();
        let analysis = config.analysis.unwrap();
        assert_eq!(analysis.no_duplication, Some(false));
        assert_eq!(analysis.duplication_enabled, Some(false));
        assert!(analysis.threads.is_none());
    }

    #[test]
    fn test_config_defaults_weights() {
        let config = config_defaults();
        let weights = config.weights.unwrap();
        assert_eq!(weights.cognitive, Some(0.30));
        assert_eq!(weights.cyclomatic, Some(0.20));
        assert_eq!(weights.duplication, Some(0.20));
        assert_eq!(weights.halstead, Some(0.15));
        assert_eq!(weights.structural, Some(0.15));
    }

    #[test]
    fn test_config_defaults_no_baseline() {
        let config = config_defaults();
        assert!(config.baseline.is_none());
        assert!(config.files.is_none());
        assert!(config.overrides.is_none());
    }

    #[test]
    fn test_serde_deserialize_partial_config() {
        let json = r#"{"output": {"format": "json"}}"#;
        let config: Config = serde_json::from_str(json).unwrap();
        let output = config.output.unwrap();
        assert_eq!(output.format, Some("json".to_string()));
        assert!(output.file.is_none());
    }

    #[test]
    fn test_serde_deserialize_analysis_threads() {
        let json = r#"{"analysis": {"threads": 8}}"#;
        let config: Config = serde_json::from_str(json).unwrap();
        let analysis = config.analysis.unwrap();
        assert_eq!(analysis.threads, Some(8));
    }

    #[test]
    fn test_serde_deserialize_ignores_unknown_fields() {
        let json = r#"{"output": {"format": "html"}, "unknown_field": "ignored"}"#;
        let result: Result<Config, _> = serde_json::from_str(json);
        // serde_json by default ignores unknown fields
        assert!(result.is_ok());
        let config = result.unwrap();
        assert_eq!(config.output.unwrap().format, Some("html".to_string()));
    }

    #[test]
    fn test_serde_deserialize_thresholds() {
        let json = r#"{
            "analysis": {
                "thresholds": {
                    "cyclomatic": {"warning": 10, "error": 20},
                    "cognitive": {"warning": 15, "error": 30}
                }
            }
        }"#;
        let config: Config = serde_json::from_str(json).unwrap();
        let analysis = config.analysis.unwrap();
        let thresholds = analysis.thresholds.unwrap();
        let cyclomatic = thresholds.cyclomatic.unwrap();
        assert_eq!(cyclomatic.warning, Some(10));
        assert_eq!(cyclomatic.error, Some(20));
    }

    #[test]
    fn test_serde_deserialize_files_config() {
        let json = r#"{"files": {"include": ["src/**/*.ts"], "exclude": ["**/*.test.ts"]}}"#;
        let config: Config = serde_json::from_str(json).unwrap();
        let files = config.files.unwrap();
        assert_eq!(files.include.unwrap(), vec!["src/**/*.ts"]);
        assert_eq!(files.exclude.unwrap(), vec!["**/*.test.ts"]);
    }

    #[test]
    fn test_serde_deserialize_weights() {
        let json = r#"{"weights": {"cognitive": 0.40, "cyclomatic": 0.30}}"#;
        let config: Config = serde_json::from_str(json).unwrap();
        let weights = config.weights.unwrap();
        assert_eq!(weights.cognitive, Some(0.40));
        assert_eq!(weights.cyclomatic, Some(0.30));
    }

    #[test]
    fn test_serde_deserialize_baseline() {
        let json = r#"{"baseline": 75.5}"#;
        let config: Config = serde_json::from_str(json).unwrap();
        assert_eq!(config.baseline, Some(75.5));
    }

    #[test]
    fn test_config_all_none_by_default() {
        let config = Config::default();
        assert!(config.output.is_none());
        assert!(config.analysis.is_none());
        assert!(config.files.is_none());
        assert!(config.weights.is_none());
        assert!(config.overrides.is_none());
        assert!(config.baseline.is_none());
    }
}
