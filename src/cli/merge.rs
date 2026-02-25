use super::args::Args;
use super::config::{AnalysisConfig, Config, FilesConfig, OutputConfig};

/// Merge CLI arguments into a Config, with CLI args taking precedence.
///
/// Mirrors `mergeArgsIntoConfig` from the Zig binary.
/// Start with defaults, overlay config file values, then call this to apply CLI overrides.
pub fn merge_args_into_config(args: &Args, config: &mut Config) {
    // Output section
    let output = config.output.get_or_insert_with(OutputConfig::default);
    if let Some(fmt) = &args.format {
        output.format = Some(fmt.clone());
    }
    if let Some(file) = &args.output_file {
        output.file = Some(file.clone());
    }

    // Analysis section
    let analysis = config.analysis.get_or_insert_with(AnalysisConfig::default);
    if args.duplication {
        analysis.duplication_enabled = Some(true);
    }
    if args.no_duplication {
        analysis.no_duplication = Some(true);
    }
    if let Some(t) = args.threads {
        analysis.threads = Some(t);
    }
    if let Some(metrics_str) = &args.metrics {
        let parsed: Vec<String> = metrics_str
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();
        if !parsed.is_empty() {
            analysis.metrics = Some(parsed);
        }
    }

    // Files section
    let files = config.files.get_or_insert_with(FilesConfig::default);
    if !args.include.is_empty() {
        files.include = Some(args.include.clone());
    }
    if !args.exclude.is_empty() {
        files.exclude = Some(args.exclude.clone());
    }

    // Fail-on / thresholds (stored in config for later use by exit code logic)
    // fail_on and fail_health_below are read directly from Args at exit code determination time
    // so no merge needed here; they are not stored in Config.

    // Baseline path stored in Args; config.baseline is the numeric threshold.
    // If --baseline is a numeric score override, it would go here;
    // for v0.8, the file-based baseline is stubbed.
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cli::args::Args;
    use crate::cli::config::config_defaults;
    use clap::Parser;

    fn parse_args(argv: &[&str]) -> Args {
        Args::try_parse_from(argv).unwrap()
    }

    #[test]
    fn test_merge_format_overrides_config() {
        let mut config = config_defaults();
        // Config starts with "console"
        assert_eq!(
            config.output.as_ref().unwrap().format,
            Some("console".to_string())
        );

        let args = parse_args(&["complexityguard", "--format", "json"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.output.as_ref().unwrap().format,
            Some("json".to_string())
        );
    }

    #[test]
    fn test_merge_output_file_overrides_config() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--output", "report.json"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.output.as_ref().unwrap().file,
            Some("report.json".to_string())
        );
    }

    #[test]
    fn test_merge_unset_format_does_not_clobber_config() {
        let mut config = config_defaults();
        // Set a non-default format in config
        config.output.as_mut().unwrap().format = Some("sarif".to_string());

        let args = parse_args(&["complexityguard"]);
        merge_args_into_config(&args, &mut config);

        // Should remain "sarif" because --format was not set
        assert_eq!(
            config.output.as_ref().unwrap().format,
            Some("sarif".to_string())
        );
    }

    #[test]
    fn test_merge_duplication_flag_enables_analysis() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--duplication"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.analysis.as_ref().unwrap().duplication_enabled,
            Some(true)
        );
    }

    #[test]
    fn test_merge_no_duplication_flag() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--no-duplication"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.analysis.as_ref().unwrap().no_duplication,
            Some(true)
        );
    }

    #[test]
    fn test_merge_threads_overrides_config() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--threads", "8"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(config.analysis.as_ref().unwrap().threads, Some(8));
    }

    #[test]
    fn test_merge_threads_not_set_preserves_config() {
        let mut config = config_defaults();
        config.analysis.as_mut().unwrap().threads = Some(4);

        let args = parse_args(&["complexityguard"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(config.analysis.as_ref().unwrap().threads, Some(4));
    }

    #[test]
    fn test_merge_include_overrides_config() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--include", "src/**/*.ts"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.files.as_ref().unwrap().include,
            Some(vec!["src/**/*.ts".to_string()])
        );
    }

    #[test]
    fn test_merge_exclude_overrides_config() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--exclude", "**/*.test.ts"]);
        merge_args_into_config(&args, &mut config);

        assert_eq!(
            config.files.as_ref().unwrap().exclude,
            Some(vec!["**/*.test.ts".to_string()])
        );
    }

    #[test]
    fn test_merge_empty_include_does_not_clobber_config() {
        let mut config = config_defaults();
        // Pre-set include in config
        config.files = Some(crate::cli::config::FilesConfig {
            include: Some(vec!["lib/**".to_string()]),
            exclude: None,
        });

        let args = parse_args(&["complexityguard"]);
        merge_args_into_config(&args, &mut config);

        // Should remain as set in config because --include was not provided
        assert_eq!(
            config.files.as_ref().unwrap().include,
            Some(vec!["lib/**".to_string()])
        );
    }

    #[test]
    fn test_merge_metrics_comma_separated() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--metrics", "cyclomatic,cognitive"]);
        merge_args_into_config(&args, &mut config);

        let metrics = config.analysis.as_ref().unwrap().metrics.as_ref().unwrap();
        assert_eq!(metrics, &vec!["cyclomatic".to_string(), "cognitive".to_string()]);
    }

    #[test]
    fn test_merge_metrics_with_spaces() {
        let mut config = config_defaults();
        let args = parse_args(&["complexityguard", "--metrics", "cyclomatic, cognitive"]);
        merge_args_into_config(&args, &mut config);

        let metrics = config.analysis.as_ref().unwrap().metrics.as_ref().unwrap();
        assert_eq!(metrics, &vec!["cyclomatic".to_string(), "cognitive".to_string()]);
    }
}
