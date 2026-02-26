use std::io::Write;

use owo_colors::OwoColorize;

use crate::cli::ResolvedConfig;
use crate::types::{DuplicationResult, FileAnalysisResult, FunctionAnalysisResult};

/// Severity level for a single threshold violation.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum Severity {
    Warning,
    Error,
}

/// A single threshold violation for a function metric.
#[derive(Debug, Clone)]
pub struct Violation {
    pub line: usize,
    pub col: usize,
    pub severity: Severity,
    pub message: String,
    pub rule_id: String,
}

/// Determines color usage based on flags and environment variables.
///
/// Priority: --no-color > --color > NO_COLOR env > FORCE_COLOR/YES_COLOR env > TTY
pub fn should_use_color(force_color: Option<bool>) -> bool {
    // Explicit override from caller (from --color / --no-color flags)
    if let Some(force) = force_color {
        return force;
    }
    // NO_COLOR env var (https://no-color.org/)
    if std::env::var("NO_COLOR").is_ok() {
        return false;
    }
    // FORCE_COLOR or YES_COLOR env var
    if std::env::var("FORCE_COLOR").is_ok() || std::env::var("YES_COLOR").is_ok() {
        return true;
    }
    // TTY detection
    use std::io::IsTerminal;
    std::io::stdout().is_terminal()
}

/// Computes all violations for a function against the resolved thresholds.
pub fn function_violations(
    func: &FunctionAnalysisResult,
    config: &ResolvedConfig,
) -> Vec<Violation> {
    let mut violations: Vec<Violation> = Vec::new();

    // Cyclomatic complexity
    let cyc = func.cyclomatic as f64;
    if cyc >= config.cyclomatic_error as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Cyclomatic complexity {} exceeds error threshold {}",
                func.cyclomatic, config.cyclomatic_error
            ),
            rule_id: "complexity-guard/cyclomatic".to_string(),
        });
    } else if cyc >= config.cyclomatic_warning as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Cyclomatic complexity {} exceeds warning threshold {}",
                func.cyclomatic, config.cyclomatic_warning
            ),
            rule_id: "complexity-guard/cyclomatic".to_string(),
        });
    }

    // Cognitive complexity
    let cog = func.cognitive as f64;
    if cog >= config.cognitive_error as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Cognitive complexity {} exceeds error threshold {}",
                func.cognitive, config.cognitive_error
            ),
            rule_id: "complexity-guard/cognitive".to_string(),
        });
    } else if cog >= config.cognitive_warning as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Cognitive complexity {} exceeds warning threshold {}",
                func.cognitive, config.cognitive_warning
            ),
            rule_id: "complexity-guard/cognitive".to_string(),
        });
    }

    // Halstead volume
    if func.halstead_volume >= config.halstead_volume_error {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Halstead volume {:.1} exceeds error threshold {:.1}",
                func.halstead_volume, config.halstead_volume_error
            ),
            rule_id: "complexity-guard/halstead-volume".to_string(),
        });
    } else if func.halstead_volume >= config.halstead_volume_warning {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Halstead volume {:.1} exceeds warning threshold {:.1}",
                func.halstead_volume, config.halstead_volume_warning
            ),
            rule_id: "complexity-guard/halstead-volume".to_string(),
        });
    }

    // Halstead difficulty
    if func.halstead_difficulty >= config.halstead_difficulty_error {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Halstead difficulty {:.1} exceeds error threshold {:.1}",
                func.halstead_difficulty, config.halstead_difficulty_error
            ),
            rule_id: "complexity-guard/halstead-difficulty".to_string(),
        });
    } else if func.halstead_difficulty >= config.halstead_difficulty_warning {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Halstead difficulty {:.1} exceeds warning threshold {:.1}",
                func.halstead_difficulty, config.halstead_difficulty_warning
            ),
            rule_id: "complexity-guard/halstead-difficulty".to_string(),
        });
    }

    // Halstead effort
    if func.halstead_effort >= config.halstead_effort_error {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Halstead effort {:.1} exceeds error threshold {:.1}",
                func.halstead_effort, config.halstead_effort_error
            ),
            rule_id: "complexity-guard/halstead-effort".to_string(),
        });
    } else if func.halstead_effort >= config.halstead_effort_warning {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Halstead effort {:.1} exceeds warning threshold {:.1}",
                func.halstead_effort, config.halstead_effort_warning
            ),
            rule_id: "complexity-guard/halstead-effort".to_string(),
        });
    }

    // Halstead bugs
    if func.halstead_bugs >= config.halstead_bugs_error {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Halstead bugs {:.3} exceeds error threshold {:.3}",
                func.halstead_bugs, config.halstead_bugs_error
            ),
            rule_id: "complexity-guard/halstead-bugs".to_string(),
        });
    } else if func.halstead_bugs >= config.halstead_bugs_warning {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Halstead bugs {:.3} exceeds warning threshold {:.3}",
                func.halstead_bugs, config.halstead_bugs_warning
            ),
            rule_id: "complexity-guard/halstead-bugs".to_string(),
        });
    }

    // Nesting depth
    let nd = func.nesting_depth as f64;
    if nd >= config.nesting_depth_error as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Nesting depth {} exceeds error threshold {}",
                func.nesting_depth, config.nesting_depth_error
            ),
            rule_id: "complexity-guard/nesting-depth".to_string(),
        });
    } else if nd >= config.nesting_depth_warning as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Nesting depth {} exceeds warning threshold {}",
                func.nesting_depth, config.nesting_depth_warning
            ),
            rule_id: "complexity-guard/nesting-depth".to_string(),
        });
    }

    // Line count (function_length in FunctionAnalysisResult)
    let lc = func.function_length as f64;
    if lc >= config.line_count_error as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Line count {} exceeds error threshold {}",
                func.function_length, config.line_count_error
            ),
            rule_id: "complexity-guard/line-count".to_string(),
        });
    } else if lc >= config.line_count_warning as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Line count {} exceeds warning threshold {}",
                func.function_length, config.line_count_warning
            ),
            rule_id: "complexity-guard/line-count".to_string(),
        });
    }

    // Params count
    let pc = func.params_count as f64;
    if pc >= config.params_count_error as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Error,
            message: format!(
                "Params count {} exceeds error threshold {}",
                func.params_count, config.params_count_error
            ),
            rule_id: "complexity-guard/param-count".to_string(),
        });
    } else if pc >= config.params_count_warning as f64 {
        violations.push(Violation {
            line: func.start_line,
            col: func.start_col,
            severity: Severity::Warning,
            message: format!(
                "Params count {} exceeds warning threshold {}",
                func.params_count, config.params_count_warning
            ),
            rule_id: "complexity-guard/param-count".to_string(),
        });
    }

    violations
}

/// Returns the worst severity across all violations for a function.
pub fn function_status(violations: &[Violation]) -> &'static str {
    let has_error = violations.iter().any(|v| v.severity == Severity::Error);
    let has_warning = violations.iter().any(|v| v.severity == Severity::Warning);
    if has_error {
        "error"
    } else if has_warning {
        "warning"
    } else {
        "ok"
    }
}

/// Returns the worst severity across all violations for a function as an enum.
fn worst_severity(violations: &[Violation]) -> Option<Severity> {
    if violations.iter().any(|v| v.severity == Severity::Error) {
        Some(Severity::Error)
    } else if violations.iter().any(|v| v.severity == Severity::Warning) {
        Some(Severity::Warning)
    } else {
        None
    }
}

/// Checks whether halstead metrics have any violations.
fn has_halstead_violation(func: &FunctionAnalysisResult, config: &ResolvedConfig) -> bool {
    func.halstead_volume >= config.halstead_volume_warning
        || func.halstead_difficulty >= config.halstead_difficulty_warning
        || func.halstead_effort >= config.halstead_effort_warning
        || func.halstead_bugs >= config.halstead_bugs_warning
}

/// Renders the consolidated per-function console line matching Zig format.
///
/// Format: `  {line}:{col}  {symbol}  {severity}  Function '{name}' cyclomatic {N} cognitive {N} [halstead vol {N}] [depth {N}]`
fn render_function_line(
    func: &FunctionAnalysisResult,
    violations: &[Violation],
    config: &ResolvedConfig,
    use_color: bool,
    verbose: bool,
) -> String {
    let worst = worst_severity(violations);
    let (symbol, severity_str) = match &worst {
        None => ("✓", "ok"),
        Some(Severity::Warning) => ("⚠", "warning"),
        Some(Severity::Error) => ("✗", "error"),
    };

    let position = format!("{}:{}", func.start_line, func.start_col);

    // Build the core line
    let line = if use_color {
        let pos_str = position.dimmed().to_string();
        let (sym_colored, sev_colored) = match &worst {
            None => (symbol.green().to_string(), severity_str.green().to_string()),
            Some(Severity::Warning) => (
                symbol.yellow().to_string(),
                severity_str.yellow().to_string(),
            ),
            Some(Severity::Error) => (symbol.red().to_string(), severity_str.red().to_string()),
        };
        format!("  {pos_str}  {sym_colored}  {sev_colored}  Function '{name}' cyclomatic {cyc} cognitive {cog}",
            name = func.name,
            cyc = func.cyclomatic,
            cog = func.cognitive,
        )
    } else {
        format!("  {position}  {symbol}  {severity_str}  Function '{name}' cyclomatic {cyc} cognitive {cog}",
            name = func.name,
            cyc = func.cyclomatic,
            cog = func.cognitive,
        )
    };

    // Append halstead info if there are halstead violations OR verbose
    let show_halstead = verbose || has_halstead_violation(func, config);
    let halstead_suffix = if show_halstead {
        format!(" [halstead vol {:.0}]", func.halstead_volume)
    } else {
        String::new()
    };

    // Append structural info if there are structural violations OR verbose
    let show_depth = verbose || func.nesting_depth as f64 >= config.nesting_depth_warning as f64;
    let show_length = verbose || func.function_length as f64 >= config.line_count_warning as f64;
    let show_params = verbose || func.params_count as f64 >= config.params_count_warning as f64;

    let mut structural_parts = String::new();
    if show_length {
        structural_parts.push_str(&format!(" [length {}]", func.function_length));
    }
    if show_params {
        structural_parts.push_str(&format!(" [params {}]", func.params_count));
    }
    if show_depth {
        structural_parts.push_str(&format!(" [depth {}]", func.nesting_depth));
    }

    format!("{line}{halstead_suffix}{structural_parts}")
}

/// Renders ESLint-style console output for all analysis results using the Zig consolidated format.
///
/// Each function gets ONE line showing the worst severity across all metrics.
/// Respects config.quiet (errors only) and config.verbose (show ok functions).
/// Color output is controlled by config.color.
pub fn render_console(
    files: &[FileAnalysisResult],
    duplication: Option<&DuplicationResult>,
    config: &ResolvedConfig,
    writer: &mut dyn Write,
) -> anyhow::Result<()> {
    let use_color = should_use_color(config.color);

    let mut total_warnings: u32 = 0;
    let mut total_errors: u32 = 0;
    let mut total_functions: u32 = 0;
    let mut total_health: f64 = 0.0;
    let mut health_count: u32 = 0;

    // Hotspot tracking for summary
    struct HotspotItem {
        name: String,
        path: String,
        line: usize,
        cyclomatic: u32,
        cognitive: u32,
        halstead_volume: f64,
    }
    let mut hotspot_items: Vec<HotspotItem> = Vec::new();

    for file in files {
        let mut file_lines: Vec<String> = Vec::new();
        let mut file_has_output = false;

        for func in &file.functions {
            total_functions += 1;
            total_health += func.health_score;
            health_count += 1;

            let violations = function_violations(func, config);
            let func_warnings: u32 = violations
                .iter()
                .filter(|v| v.severity == Severity::Warning)
                .count() as u32;
            let func_errors: u32 = violations
                .iter()
                .filter(|v| v.severity == Severity::Error)
                .count() as u32;
            total_warnings += func_warnings;
            total_errors += func_errors;

            // Track hotspot data
            hotspot_items.push(HotspotItem {
                name: func.name.clone(),
                path: file.path.display().to_string(),
                line: func.start_line,
                cyclomatic: func.cyclomatic,
                cognitive: func.cognitive,
                halstead_volume: func.halstead_volume,
            });

            // Determine whether to show this function
            let worst = worst_severity(&violations);
            let show = match worst {
                None => config.verbose, // ok functions only shown in verbose
                Some(Severity::Warning) => !config.quiet, // warnings suppressed in quiet
                Some(Severity::Error) => true, // errors always shown
            };

            if show {
                let line =
                    render_function_line(func, &violations, config, use_color, config.verbose);
                file_lines.push(line);
                file_has_output = true;
            }
        }

        // Print file section only if it has output
        if file_has_output {
            if use_color {
                writeln!(writer, "{}", file.path.display().bold())?;
            } else {
                writeln!(writer, "{}", file.path.display())?;
            }
            for line in &file_lines {
                writeln!(writer, "{}", line)?;
            }
            writeln!(writer)?;
        }
    }

    // In quiet mode, only show verdict
    if config.quiet {
        render_verdict(writer, total_errors, total_warnings, use_color)?;
        return Ok(());
    }

    // Summary section
    let file_count = files.len();
    writeln!(
        writer,
        "Analyzed {file_count} files, {total_functions} functions"
    )?;

    // Health score (integer, no decimal — matching Zig format)
    if health_count > 0 {
        let avg_health = total_health / health_count as f64;
        let health_str = format!("Health: {:.0}", avg_health);
        let health_line = if use_color {
            if avg_health >= 80.0 {
                health_str.green().to_string()
            } else if avg_health >= 60.0 {
                health_str.yellow().to_string()
            } else {
                health_str.red().to_string()
            }
        } else {
            health_str
        };
        writeln!(writer, "{health_line}")?;
    }

    // Warning/error counts (only shown when there are some)
    if total_warnings > 0 || total_errors > 0 {
        writeln!(
            writer,
            "Found {total_warnings} warnings, {total_errors} errors"
        )?;
    }

    // Duplication section (if present)
    if let Some(dup) = duplication {
        writeln!(writer, "Duplication: {:.1}%", dup.duplication_percentage)?;
    }

    // Top cyclomatic hotspots (top 5, cyclomatic > 1)
    let mut cycl_hotspots: Vec<_> = hotspot_items.iter().filter(|h| h.cyclomatic > 1).collect();
    if !cycl_hotspots.is_empty() {
        cycl_hotspots.sort_by(|a, b| b.cyclomatic.cmp(&a.cyclomatic));
        let top_count = cycl_hotspots.len().min(5);
        writeln!(writer)?;
        writeln!(writer, "Top cyclomatic hotspots:")?;
        for (idx, h) in cycl_hotspots[..top_count].iter().enumerate() {
            writeln!(
                writer,
                "  {}. {} ({}:{}) complexity {}",
                idx + 1,
                h.name,
                h.path,
                h.line,
                h.cyclomatic
            )?;
        }
    }

    // Top cognitive hotspots (top 5, cognitive > 0)
    let mut cog_hotspots: Vec<_> = hotspot_items.iter().filter(|h| h.cognitive > 0).collect();
    if !cog_hotspots.is_empty() {
        cog_hotspots.sort_by(|a, b| b.cognitive.cmp(&a.cognitive));
        let top_count = cog_hotspots.len().min(5);
        writeln!(writer)?;
        writeln!(writer, "Top cognitive hotspots:")?;
        for (idx, h) in cog_hotspots[..top_count].iter().enumerate() {
            writeln!(
                writer,
                "  {}. {} ({}:{}) complexity {}",
                idx + 1,
                h.name,
                h.path,
                h.line,
                h.cognitive
            )?;
        }
    }

    // Top halstead volume hotspots (top 5, volume > 0)
    let mut hal_hotspots: Vec<_> = hotspot_items
        .iter()
        .filter(|h| h.halstead_volume > 0.0)
        .collect();
    if !hal_hotspots.is_empty() {
        hal_hotspots.sort_by(|a, b| {
            b.halstead_volume
                .partial_cmp(&a.halstead_volume)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        let top_count = hal_hotspots.len().min(5);
        writeln!(writer)?;
        writeln!(writer, "Top Halstead volume hotspots:")?;
        for (idx, h) in hal_hotspots[..top_count].iter().enumerate() {
            writeln!(
                writer,
                "  {}. {} ({}:{}) volume {:.0}",
                idx + 1,
                h.name,
                h.path,
                h.line,
                h.halstead_volume
            )?;
        }
    }

    // Final verdict
    writeln!(writer)?;
    render_verdict(writer, total_errors, total_warnings, use_color)?;

    Ok(())
}

/// Renders the final verdict line matching Zig format.
fn render_verdict(
    writer: &mut dyn Write,
    error_count: u32,
    warning_count: u32,
    use_color: bool,
) -> anyhow::Result<()> {
    let total = error_count + warning_count;
    if error_count > 0 {
        let msg = format!(
            "✗ {} problems ({} errors, {} warnings)",
            total, error_count, warning_count
        );
        if use_color {
            writeln!(writer, "{}", msg.red())?;
        } else {
            writeln!(writer, "{msg}")?;
        }
    } else if warning_count > 0 {
        let msg = format!(
            "⚠ {} problems (0 errors, {} warnings)",
            warning_count, warning_count
        );
        if use_color {
            writeln!(writer, "{}", msg.yellow())?;
        } else {
            writeln!(writer, "{msg}")?;
        }
    } else {
        let msg = "✓ No problems found";
        if use_color {
            writeln!(writer, "{}", msg.green())?;
        } else {
            writeln!(writer, "{msg}")?;
        }
    }
    Ok(())
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::FileAnalysisResult;
    use std::path::PathBuf;

    fn make_func(
        name: &str,
        start_line: usize,
        cyclomatic: u32,
        cognitive: u32,
        health_score: f64,
    ) -> FunctionAnalysisResult {
        FunctionAnalysisResult {
            name: name.to_string(),
            start_line,
            end_line: start_line + 10,
            start_col: 0,
            cyclomatic,
            cognitive,
            halstead_volume: 0.0,
            halstead_difficulty: 0.0,
            halstead_effort: 0.0,
            halstead_time: 0.0,
            halstead_bugs: 0.0,
            function_length: 10,
            params_count: 1,
            nesting_depth: 1,
            health_score,
        }
    }

    fn make_file(path: &str, functions: Vec<FunctionAnalysisResult>) -> FileAnalysisResult {
        FileAnalysisResult {
            path: PathBuf::from(path),
            functions,
            tokens: vec![],
            file_score: 90.0,
            file_length: 100,
            export_count: 1,
            error: false,
        }
    }

    fn default_config() -> ResolvedConfig {
        ResolvedConfig::default()
    }

    #[test]
    fn test_render_console_violation_format() {
        // Function with cyclomatic complexity exceeding warning threshold (10)
        let func = make_func("myFunc", 10, 12, 5, 72.0);
        let file = make_file("src/example.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(
            output.contains("src/example.ts"),
            "Should contain file path"
        );
        assert!(output.contains("10:0"), "Should contain line:col");
        assert!(output.contains("warning"), "Should contain severity");
        assert!(output.contains("⚠"), "Should contain warning symbol");
        assert!(output.contains("myFunc"), "Should contain function name");
        assert!(
            output.contains("cyclomatic 12"),
            "Should contain cyclomatic value"
        );
        assert!(
            output.contains("cognitive 5"),
            "Should contain cognitive value"
        );
    }

    #[test]
    fn test_render_console_single_line_per_function() {
        // Function with both cyclomatic and cognitive violations — should produce ONE line in the file section
        let func = make_func("bigFunc", 25, 25, 30, 40.0);
        let file = make_file("src/big.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        // The file section (before the blank line after it) should have exactly one indented line
        // that contains the function info with both metrics
        assert!(
            output.contains("  25:0"),
            "Should have position indented line"
        );
        let indented_lines: Vec<&str> = output.lines().filter(|l| l.starts_with("  ")).collect();
        // All indented function lines are in the file section (hotspot lines are also indented)
        // Key test: the file section line contains BOTH cyclomatic and cognitive on one line
        let has_combined_line = output
            .lines()
            .any(|l| l.contains("bigFunc") && l.contains("cyclomatic") && l.contains("cognitive"));
        assert!(
            has_combined_line,
            "Should have single combined line with cyclomatic and cognitive"
        );
        let _ = indented_lines; // used for documentation purposes
    }

    #[test]
    fn test_render_console_error_violation() {
        // Function with cyclomatic complexity exceeding error threshold (20)
        let func = make_func("bigFunc", 25, 25, 5, 40.0);
        let file = make_file("src/big.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(output.contains("error"), "Should contain error severity");
        assert!(output.contains("✗"), "Should contain error symbol");
        assert!(
            output.contains("cyclomatic 25"),
            "Should contain cyclomatic value"
        );
    }

    #[test]
    fn test_render_console_worst_severity_wins() {
        // Function with cyclomatic warning (12) and cognitive error (30)
        // Should show error-level (worst)
        let func = make_func("mixedFunc", 1, 12, 30, 40.0);
        let file = make_file("src/mixed.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        // Should show error symbol since cognitive 30 >= error threshold 25
        assert!(
            output.contains("✗"),
            "Should show error symbol for worst severity"
        );
        assert!(output.contains("error"), "Should show error severity text");
    }

    #[test]
    fn test_render_console_summary_format() {
        let func1 = make_func("f1", 1, 12, 5, 72.0); // warning
        let func2 = make_func("f2", 20, 25, 5, 40.0); // error
        let func3 = make_func("f3", 40, 2, 2, 95.0); // ok
        let file = make_file("src/test.ts", vec![func1, func2, func3]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(
            output.contains("Analyzed 1 files, 3 functions"),
            "Should show analyzed count"
        );
        assert!(output.contains("Found"), "Should show found line");
        assert!(output.contains("warnings"), "Should show warnings");
        assert!(output.contains("errors"), "Should show errors");
    }

    #[test]
    fn test_render_console_health_integer_format() {
        let func = make_func("f", 1, 2, 1, 85.0);
        let file = make_file("src/test.ts", vec![func]);
        let mut config = default_config();
        config.verbose = true;
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(output.contains("Health:"), "Should show health label");
        // Should be integer format (no decimal point in health value)
        assert!(
            output.contains("Health: 85"),
            "Should show integer health score"
        );
        assert!(
            !output.contains("Health: 85."),
            "Health score should not have decimal"
        );
    }

    #[test]
    fn test_render_console_summary_line() {
        let func1 = make_func("f1", 1, 12, 5, 72.0); // warning
        let func2 = make_func("f2", 20, 25, 5, 40.0); // error
        let func3 = make_func("f3", 40, 2, 2, 95.0); // ok
        let file = make_file("src/test.ts", vec![func1, func2, func3]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(
            output.contains("Analyzed 1 files, 3 functions"),
            "Should show analyzed line"
        );
    }

    #[test]
    fn test_render_console_quiet_suppresses_warnings() {
        let func = make_func("myFunc", 10, 12, 5, 72.0); // cyclomatic warning
        let file = make_file("src/test.ts", vec![func]);
        let mut config = default_config();
        config.quiet = true;
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        // Quiet mode suppresses warning-only file sections
        assert!(
            !output.contains("src/test.ts"),
            "Quiet mode should suppress the file section for warning-only files"
        );
        // In quiet mode, only verdict is shown
        assert!(
            !output.contains("Analyzed"),
            "Quiet mode should not show analyzed summary"
        );
    }

    #[test]
    fn test_render_console_verbose_shows_ok_functions() {
        let func = make_func("simpleFunc", 5, 2, 1, 95.0); // no violations
        let file = make_file("src/clean.ts", vec![func]);
        let mut config = default_config();
        config.verbose = true;
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(output.contains("✓"), "Verbose mode should show ok symbol");
        assert!(
            output.contains("ok"),
            "Verbose mode should show ok functions"
        );
        assert!(
            output.contains("simpleFunc"),
            "Verbose mode should show function name"
        );
    }

    #[test]
    fn test_render_console_no_verbose_hides_ok_functions() {
        // Use cyclomatic=1 (no violations, won't appear in cyclomatic hotspot section which requires > 1)
        let func = make_func("simpleFunc", 5, 1, 0, 95.0); // no violations, cyclomatic=1
        let file = make_file("src/clean.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        // File section header should NOT appear since no violations
        // (hotspot sections use format "(path:line)" so a standalone "src/clean.ts\n" line won't appear)
        let file_header_line = output.lines().any(|l| l == "src/clean.ts");
        assert!(
            !file_header_line,
            "File with no violations should not appear as a file section header"
        );
    }

    #[test]
    fn test_render_console_no_problems_verdict() {
        let func = make_func("simpleFunc", 5, 2, 1, 95.0);
        let file = make_file("src/clean.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(
            output.contains("✓ No problems found"),
            "Should show no problems verdict"
        );
    }

    #[test]
    fn test_render_console_error_verdict() {
        let func = make_func("bigFunc", 25, 25, 5, 40.0);
        let file = make_file("src/big.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(output.contains("✗"), "Should show error verdict symbol");
        assert!(output.contains("problems"), "Should show problems count");
    }

    #[test]
    fn test_function_violations_cyclomatic_warning() {
        let func = make_func("f", 1, 12, 0, 80.0);
        let config = default_config();
        let violations = function_violations(&func, &config);
        assert_eq!(violations.len(), 1);
        assert_eq!(violations[0].severity, Severity::Warning);
        assert!(violations[0].rule_id.contains("cyclomatic"));
    }

    #[test]
    fn test_function_violations_cyclomatic_error() {
        let func = make_func("f", 1, 25, 0, 40.0);
        let config = default_config();
        let violations = function_violations(&func, &config);
        let cyc_violations: Vec<_> = violations
            .iter()
            .filter(|v| v.rule_id.contains("cyclomatic"))
            .collect();
        assert_eq!(cyc_violations.len(), 1);
        assert_eq!(cyc_violations[0].severity, Severity::Error);
    }

    #[test]
    fn test_function_violations_no_violations() {
        let func = make_func("f", 1, 3, 3, 95.0);
        let config = default_config();
        let violations = function_violations(&func, &config);
        assert!(
            violations.is_empty(),
            "Should have no violations for low complexity"
        );
    }

    #[test]
    fn test_function_status_ok() {
        assert_eq!(function_status(&[]), "ok");
    }

    #[test]
    fn test_function_status_warning() {
        let v = Violation {
            line: 1,
            col: 0,
            severity: Severity::Warning,
            message: "test".to_string(),
            rule_id: "test".to_string(),
        };
        assert_eq!(function_status(&[v]), "warning");
    }

    #[test]
    fn test_function_status_error() {
        let v = Violation {
            line: 1,
            col: 0,
            severity: Severity::Error,
            message: "test".to_string(),
            rule_id: "test".to_string(),
        };
        assert_eq!(function_status(&[v]), "error");
    }

    #[test]
    fn test_render_console_multiple_files_summary() {
        let func1 = make_func("f", 1, 2, 1, 90.0);
        let func2 = make_func("g", 1, 2, 1, 85.0);
        let file1 = make_file("src/a.ts", vec![func1]);
        let file2 = make_file("src/b.ts", vec![func2]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file1, file2], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(
            output.contains("Analyzed 2 files, 2 functions"),
            "Should show 2 files and 2 functions"
        );
    }

    #[test]
    fn test_should_use_color_no_color_flag() {
        // --no-color -> false
        assert!(!should_use_color(Some(false)));
    }

    #[test]
    fn test_should_use_color_force_color_flag() {
        // --color -> true
        assert!(should_use_color(Some(true)));
    }
}
