use clap::Parser;
use std::path::PathBuf;

/// CLI arguments for complexityguard.
///
/// All flags match the Zig binary interface for v0.8 parity.
#[derive(Parser, Debug)]
#[command(name = "complexityguard")]
#[command(about = "Analyze code complexity for TypeScript/JavaScript files")]
#[command(version)]
pub struct Args {
    /// Paths to analyze (files or directories)
    pub paths: Vec<PathBuf>,

    // --- General ---
    /// Run interactive config setup
    #[arg(long)]
    pub init: bool,

    // --- Output ---
    /// Output format [console, json, sarif, html]
    #[arg(short = 'f', long)]
    pub format: Option<String>,

    /// Write report to file
    #[arg(short = 'o', long = "output")]
    pub output_file: Option<String>,

    /// Force color output
    #[arg(long)]
    pub color: bool,

    /// Disable color output
    #[arg(long = "no-color")]
    pub no_color: bool,

    /// Suppress non-error output
    #[arg(short = 'q', long)]
    pub quiet: bool,

    /// Show detailed output
    #[arg(short = 'v', long)]
    pub verbose: bool,

    // --- Analysis ---
    /// Comma-separated metrics to enable
    #[arg(long)]
    pub metrics: Option<String>,

    /// Enable cross-file duplication detection
    #[arg(long)]
    pub duplication: bool,

    /// Skip duplication analysis
    #[arg(long = "no-duplication")]
    pub no_duplication: bool,

    /// Thread count (default: CPU count)
    #[arg(long)]
    pub threads: Option<u32>,

    // --- Files ---
    /// Include files matching pattern (repeatable)
    #[arg(long)]
    pub include: Vec<String>,

    /// Exclude files matching pattern (repeatable)
    #[arg(long)]
    pub exclude: Vec<String>,

    // --- Thresholds ---
    /// Exit non-zero on: warning, error, none
    #[arg(long = "fail-on")]
    pub fail_on: Option<String>,

    /// Exit non-zero if health score below N
    #[arg(long = "fail-health-below")]
    pub fail_health_below: Option<f64>,

    // --- Config ---
    /// Use specific config file
    #[arg(short = 'c', long)]
    pub config: Option<String>,

    // --- Baseline ---
    /// Baseline file path for ratchet enforcement
    #[arg(long)]
    pub baseline: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_format_json() {
        let args = Args::try_parse_from(["complexityguard", "--format", "json"]).unwrap();
        assert_eq!(args.format, Some("json".to_string()));
    }

    #[test]
    fn test_parse_short_format() {
        let args = Args::try_parse_from(["complexityguard", "-f", "sarif"]).unwrap();
        assert_eq!(args.format, Some("sarif".to_string()));
    }

    #[test]
    fn test_parse_output_file() {
        let args = Args::try_parse_from(["complexityguard", "-o", "report.json"]).unwrap();
        assert_eq!(args.output_file, Some("report.json".to_string()));
    }

    #[test]
    fn test_parse_long_output() {
        let args = Args::try_parse_from(["complexityguard", "--output", "out.sarif"]).unwrap();
        assert_eq!(args.output_file, Some("out.sarif".to_string()));
    }

    #[test]
    fn test_parse_verbose_flag() {
        let args = Args::try_parse_from(["complexityguard", "--verbose"]).unwrap();
        assert!(args.verbose);
    }

    #[test]
    fn test_parse_quiet_short() {
        let args = Args::try_parse_from(["complexityguard", "-q"]).unwrap();
        assert!(args.quiet);
    }

    #[test]
    fn test_parse_no_color() {
        let args = Args::try_parse_from(["complexityguard", "--no-color"]).unwrap();
        assert!(args.no_color);
    }

    #[test]
    fn test_parse_color() {
        let args = Args::try_parse_from(["complexityguard", "--color"]).unwrap();
        assert!(args.color);
    }

    #[test]
    fn test_parse_fail_on() {
        let args = Args::try_parse_from(["complexityguard", "--fail-on", "warning"]).unwrap();
        assert_eq!(args.fail_on, Some("warning".to_string()));
    }

    #[test]
    fn test_parse_fail_health_below() {
        let args =
            Args::try_parse_from(["complexityguard", "--fail-health-below", "80.0"]).unwrap();
        assert_eq!(args.fail_health_below, Some(80.0));
    }

    #[test]
    fn test_parse_config_short() {
        let args =
            Args::try_parse_from(["complexityguard", "-c", ".complexityguard.json"]).unwrap();
        assert_eq!(args.config, Some(".complexityguard.json".to_string()));
    }

    #[test]
    fn test_parse_duplication() {
        let args = Args::try_parse_from(["complexityguard", "--duplication"]).unwrap();
        assert!(args.duplication);
    }

    #[test]
    fn test_parse_no_duplication() {
        let args = Args::try_parse_from(["complexityguard", "--no-duplication"]).unwrap();
        assert!(args.no_duplication);
    }

    #[test]
    fn test_parse_threads() {
        let args = Args::try_parse_from(["complexityguard", "--threads", "4"]).unwrap();
        assert_eq!(args.threads, Some(4));
    }

    #[test]
    fn test_parse_include_exclude() {
        let args = Args::try_parse_from([
            "complexityguard",
            "--include",
            "src/**/*.ts",
            "--exclude",
            "**/*.test.ts",
        ])
        .unwrap();
        assert_eq!(args.include, vec!["src/**/*.ts"]);
        assert_eq!(args.exclude, vec!["**/*.test.ts"]);
    }

    #[test]
    fn test_parse_positional_paths() {
        let args = Args::try_parse_from(["complexityguard", "src/", "lib/"]).unwrap();
        assert_eq!(args.paths.len(), 2);
    }

    #[test]
    fn test_parse_baseline() {
        let args =
            Args::try_parse_from(["complexityguard", "--baseline", "baseline.json"]).unwrap();
        assert_eq!(args.baseline, Some("baseline.json".to_string()));
    }

    #[test]
    fn test_parse_init() {
        let args = Args::try_parse_from(["complexityguard", "--init"]).unwrap();
        assert!(args.init);
    }

    #[test]
    fn test_parse_metrics() {
        let args =
            Args::try_parse_from(["complexityguard", "--metrics", "cyclomatic,cognitive"]).unwrap();
        assert_eq!(args.metrics, Some("cyclomatic,cognitive".to_string()));
    }

    #[test]
    fn test_parse_defaults_are_false() {
        let args = Args::try_parse_from(["complexityguard"]).unwrap();
        assert!(!args.init);
        assert!(!args.verbose);
        assert!(!args.quiet);
        assert!(!args.color);
        assert!(!args.no_color);
        assert!(!args.duplication);
        assert!(!args.no_duplication);
        assert!(args.format.is_none());
        assert!(args.output_file.is_none());
        assert!(args.fail_on.is_none());
        assert!(args.config.is_none());
        assert!(args.paths.is_empty());
    }
}
