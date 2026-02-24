use clap::Parser;
use complexity_guard::cli::{config_defaults, discover_config, merge_args_into_config, resolve_config, Args};
use complexity_guard::output::{determine_exit_code, render_console, render_json, ExitCode};

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

    let paths: Vec<String> = args
        .paths
        .iter()
        .map(|p| p.to_string_lossy().to_string())
        .collect();

    // Placeholder: no actual file analysis yet (Phase 20 parallel pipeline)
    // For now, render with empty results to demonstrate format dispatch
    let start = std::time::Instant::now();
    let files: Vec<complexity_guard::types::FileAnalysisResult> = vec![];
    let elapsed_ms = start.elapsed().as_millis() as u64;

    match resolved.format.as_str() {
        "json" => {
            match render_json(&files, None, &resolved, elapsed_ms) {
                Ok(json) => println!("{}", json),
                Err(e) => {
                    eprintln!("Error rendering JSON output: {}", e);
                    std::process::exit(ExitCode::ConfigError as i32);
                }
            }
        }
        _ => {
            // console format (default) and unknown formats fall through to console
            if resolved.format != "console" && !["sarif", "html"].contains(&resolved.format.as_str()) {
                eprintln!(
                    "Warning: unknown format '{}', using console",
                    resolved.format
                );
            }
            if resolved.format == "console" {
                // Show paths being analyzed when no actual analysis yet
                let analyze_paths = if paths.is_empty() { vec![".".to_string()] } else { paths };
                eprintln!(
                    "complexity-guard v{} — analyzing {:?}",
                    env!("CARGO_PKG_VERSION"),
                    analyze_paths
                );
            }
            if let Err(e) = render_console(&files, None, &resolved, &mut std::io::stdout()) {
                eprintln!("Error rendering console output: {}", e);
                std::process::exit(ExitCode::ConfigError as i32);
            }
        }
    }

    // Determine exit code from stub results (no analysis yet)
    let exit_code = determine_exit_code(
        false, // has_parse_errors
        0,     // error_count
        0,     // warning_count
        args.fail_on.as_deref(),
        false, // baseline_failed
    );

    std::process::exit(exit_code as i32);
}
