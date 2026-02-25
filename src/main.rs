use clap::Parser;
use complexity_guard::cli::{
    config_defaults, discover_config, merge_args_into_config, resolve_config, Args,
};
use complexity_guard::metrics::duplication::detect_duplication;
use complexity_guard::output::console::{function_violations, Severity};
use complexity_guard::output::{
    determine_exit_code, render_console, render_html, render_json, render_sarif, ExitCode,
};
use complexity_guard::types::{
    AnalysisConfig, CognitiveConfig, CyclomaticConfig, DuplicationConfig, DuplicationResult,
    ScoringThresholds, ScoringWeights,
};

fn main() {
    let args = Args::parse();

    // Handle --init stub
    if args.init {
        println!("Interactive config setup not yet implemented in v0.8.");
        std::process::exit(ExitCode::Success as i32);
    }

    // Discover and load config file
    let mut config = config_defaults();

    match discover_config(args.config.as_deref()) {
        Ok(Some(file_config)) => {
            // Overlay file config on top of defaults
            if let Some(output) = file_config.output {
                let default_output = config.output.get_or_insert_with(Default::default);
                if let Some(fmt) = output.format {
                    default_output.format = Some(fmt);
                }
                if let Some(file) = output.file {
                    default_output.file = Some(file);
                }
            }
            if let Some(analysis) = file_config.analysis {
                let default_analysis = config.analysis.get_or_insert_with(Default::default);
                if let Some(metrics) = analysis.metrics {
                    default_analysis.metrics = Some(metrics);
                }
                if let Some(thresholds) = analysis.thresholds {
                    default_analysis.thresholds = Some(thresholds);
                }
                if let Some(v) = analysis.no_duplication {
                    default_analysis.no_duplication = Some(v);
                }
                if let Some(v) = analysis.duplication_enabled {
                    default_analysis.duplication_enabled = Some(v);
                }
                if let Some(t) = analysis.threads {
                    default_analysis.threads = Some(t);
                }
            }
            if let Some(files) = file_config.files {
                config.files = Some(files);
            }
            if let Some(weights) = file_config.weights {
                config.weights = Some(weights);
            }
            if let Some(baseline) = file_config.baseline {
                config.baseline = Some(baseline);
            }
        }
        Ok(None) => {
            // No config file found — use defaults only
        }
        Err(e) => {
            eprintln!("Error loading config: {}", e);
            std::process::exit(ExitCode::ConfigError as i32);
        }
    }

    // Apply CLI overrides on top of config file values
    merge_args_into_config(&args, &mut config);

    // Apply color flags to the resolved config
    let color_override = if args.no_color {
        Some(false)
    } else if args.color {
        Some(true)
    } else {
        None
    };

    // Resolve the final config (non-optional, defaults applied)
    let mut resolved = resolve_config(&config);
    resolved.color = color_override;
    resolved.quiet = args.quiet;
    resolved.verbose = args.verbose;

    // Default to "." when no paths provided
    let input_paths: Vec<std::path::PathBuf> = if args.paths.is_empty() {
        vec![std::path::PathBuf::from(".")]
    } else {
        args.paths.clone()
    };

    // Extract include/exclude patterns from merged config
    let include_patterns: Vec<String> = config
        .files
        .as_ref()
        .and_then(|f| f.include.clone())
        .unwrap_or_default();
    let exclude_patterns: Vec<String> = config
        .files
        .as_ref()
        .and_then(|f| f.exclude.clone())
        .unwrap_or_default();

    // Discover files
    let discovered = match complexity_guard::pipeline::discover_files(
        &input_paths,
        &include_patterns,
        &exclude_patterns,
    ) {
        Ok(files) => files,
        Err(e) => {
            eprintln!("Error discovering files: {}", e);
            std::process::exit(ExitCode::ConfigError as i32);
        }
    };

    // Build AnalysisConfig from resolved config
    let analysis_config = build_analysis_config(&config, &resolved);

    // Parallel analysis
    let start = std::time::Instant::now();
    let (files, has_parse_errors) = complexity_guard::pipeline::analyze_files_parallel(
        &discovered,
        &analysis_config,
        resolved.threads,
    );
    let elapsed_ms = start.elapsed().as_millis() as u64;

    // Duplication detection (post-parallel, gated by flag)
    let duplication_result: Option<DuplicationResult> = {
        let dup_enabled = config
            .analysis
            .as_ref()
            .and_then(|a| a.duplication_enabled)
            .unwrap_or(false);
        let no_dup = config
            .analysis
            .as_ref()
            .and_then(|a| a.no_duplication)
            .unwrap_or(false);

        if dup_enabled && !no_dup {
            let file_tokens: Vec<&[_]> = files.iter().map(|f| f.tokens.as_slice()).collect();
            Some(detect_duplication(
                &file_tokens,
                &analysis_config.duplication,
            ))
        } else {
            None
        }
    };

    // Count violations for exit code
    let (mut error_count, mut warning_count): (u32, u32) = (0, 0);
    for file in &files {
        for func in &file.functions {
            let violations = function_violations(func, &resolved);
            for v in &violations {
                match v.severity {
                    Severity::Error => error_count += 1,
                    Severity::Warning => warning_count += 1,
                }
            }
        }
    }

    // Render output in the requested format
    let output_result: Result<Option<String>, anyhow::Error> = match resolved.format.as_str() {
        "json" => render_json(&files, duplication_result.as_ref(), &resolved, elapsed_ms).map(Some),
        "sarif" => render_sarif(&files, duplication_result.as_ref(), &resolved).map(Some),
        "html" => render_html(&files, duplication_result.as_ref(), &resolved, elapsed_ms).map(Some),
        _ => {
            // console format (default) and unknown formats fall through to console
            if resolved.format != "console" {
                eprintln!(
                    "Warning: unknown format '{}', using console",
                    resolved.format
                );
            }
            match render_console(
                &files,
                duplication_result.as_ref(),
                &resolved,
                &mut std::io::stdout(),
            ) {
                Ok(_) => Ok(None), // console writes directly to stdout
                Err(e) => Err(e),
            }
        }
    };

    match output_result {
        Ok(Some(content)) => {
            // Write to file if --output specified, otherwise stdout
            if let Some(ref output_path) = resolved.output_file {
                if let Err(e) = std::fs::write(output_path, &content) {
                    eprintln!("Error writing output to {}: {}", output_path, e);
                    std::process::exit(ExitCode::ConfigError as i32);
                }
            } else {
                println!("{}", content);
            }
        }
        Ok(None) => {
            // Console format already wrote to stdout
        }
        Err(e) => {
            eprintln!("Error rendering output: {}", e);
            std::process::exit(ExitCode::ConfigError as i32);
        }
    }

    // Determine exit code from actual analysis results
    let exit_code = determine_exit_code(
        has_parse_errors,
        error_count,
        warning_count,
        args.fail_on.as_deref(),
        false, // baseline enforcement deferred
    );

    std::process::exit(exit_code as i32);
}

/// Build an AnalysisConfig from the merged Config and ResolvedConfig.
///
/// Maps resolved threshold values to AnalysisConfig fields. Uses defaults
/// where values are not specified in config.
fn build_analysis_config(
    config: &complexity_guard::cli::Config,
    resolved: &complexity_guard::cli::ResolvedConfig,
) -> AnalysisConfig {
    let cyclomatic = CyclomaticConfig {
        count_logical_operators: true,
        count_nullish_coalescing: true,
        count_optional_chaining: true,
        count_ternary: true,
        count_default_params: true,
        switch_case_mode: complexity_guard::types::SwitchCaseMode::Classic,
        warning_threshold: resolved.cyclomatic_warning,
        error_threshold: resolved.cyclomatic_error,
    };

    let cognitive = CognitiveConfig {
        warning_threshold: resolved.cognitive_warning,
        error_threshold: resolved.cognitive_error,
    };

    let scoring_weights = if let Some(w) = &config.weights {
        ScoringWeights {
            cyclomatic: w.cyclomatic.unwrap_or(0.20),
            cognitive: w.cognitive.unwrap_or(0.30),
            halstead: w.halstead.unwrap_or(0.15),
            structural: w.structural.unwrap_or(0.15),
            duplication: w.duplication.unwrap_or(0.20),
        }
    } else {
        ScoringWeights::default()
    };

    let scoring_thresholds = ScoringThresholds {
        cyclomatic_warning: resolved.cyclomatic_warning as f64,
        cyclomatic_error: resolved.cyclomatic_error as f64,
        cognitive_warning: resolved.cognitive_warning as f64,
        cognitive_error: resolved.cognitive_error as f64,
        halstead_warning: resolved.halstead_volume_warning,
        halstead_error: resolved.halstead_volume_error,
        function_length_warning: resolved.line_count_warning as f64,
        function_length_error: resolved.line_count_error as f64,
        params_count_warning: resolved.params_count_warning as f64,
        params_count_error: resolved.params_count_error as f64,
        nesting_depth_warning: resolved.nesting_depth_warning as f64,
        nesting_depth_error: resolved.nesting_depth_error as f64,
    };

    let duplication = DuplicationConfig {
        min_tokens: 25,
        enabled: config
            .analysis
            .as_ref()
            .and_then(|a| a.duplication_enabled)
            .unwrap_or(false),
    };

    AnalysisConfig {
        cyclomatic,
        cognitive,
        scoring_weights,
        scoring_thresholds,
        duplication,
    }
}
