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
pub fn function_violations(func: &FunctionAnalysisResult, config: &ResolvedConfig) -> Vec<Violation> {
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

/// Renders ESLint-style console output for all analysis results.
///
/// Respects config.quiet (errors only) and config.verbose (show ok functions).
/// Color output is controlled by config.color.
pub fn render_console(
    files: &[FileAnalysisResult],
    _duplication: Option<&DuplicationResult>,
    config: &ResolvedConfig,
    writer: &mut dyn Write,
) -> anyhow::Result<()> {
    let use_color = should_use_color(config.color);

    let mut total_warnings: u32 = 0;
    let mut total_errors: u32 = 0;
    let mut total_functions: u32 = 0;
    let mut total_health: f64 = 0.0;
    let mut health_count: u32 = 0;

    for file in files {
        let mut file_had_output = false;
        let mut file_lines: Vec<String> = Vec::new();

        for func in &file.functions {
            total_functions += 1;
            total_health += func.health_score;
            health_count += 1;

            let violations = function_violations(func, config);
            let func_warnings: u32 = violations.iter().filter(|v| v.severity == Severity::Warning).count() as u32;
            let func_errors: u32 = violations.iter().filter(|v| v.severity == Severity::Error).count() as u32;
            total_warnings += func_warnings;
            total_errors += func_errors;

            if violations.is_empty() {
                // ok function
                if config.verbose {
                    let line = if use_color {
                        format!(
                            "  {}  ok  {}  complexity-guard/ok",
                            format!("{}:{}", func.start_line, func.start_col).dimmed(),
                            func.name
                        )
                    } else {
                        format!("  {}:{}  ok  {}  complexity-guard/ok", func.start_line, func.start_col, func.name)
                    };
                    file_lines.push(line);
                    file_had_output = true;
                }
            } else {
                for violation in &violations {
                    // quiet mode: skip warnings
                    if config.quiet && violation.severity == Severity::Warning {
                        continue;
                    }
                    let position = format!("{}:{}", violation.line, violation.col);
                    let line = if use_color {
                        let pos_str = position.dimmed().to_string();
                        let level_str = match violation.severity {
                            Severity::Warning => "warning".yellow().to_string(),
                            Severity::Error => "error".red().to_string(),
                        };
                        let rule_str = violation.rule_id.dimmed().to_string();
                        format!("  {pos_str}  {level_str}  {}  {rule_str}", violation.message)
                    } else {
                        let level_str = match violation.severity {
                            Severity::Warning => "warning",
                            Severity::Error => "error",
                        };
                        format!("  {position}  {level_str}  {}  {}", violation.message, violation.rule_id)
                    };
                    file_lines.push(line);
                    file_had_output = true;
                }
            }
        }

        // Print file section only if it has output lines (or verbose shows everything)
        let file_has_violations = file_lines.iter().any(|l| l.contains("warning") || l.contains("error"));
        if file_had_output || file_has_violations {
            writeln!(writer, "{}", file.path.display())?;
            for line in &file_lines {
                writeln!(writer, "{}", line)?;
            }
            writeln!(writer)?;
        }
    }

    // Summary line
    let file_count = files.len();
    let file_word = if file_count == 1 { "file" } else { "files" };
    let func_word = if total_functions == 1 { "function" } else { "functions" };
    let warn_word = if total_warnings == 1 { "warning" } else { "warnings" };
    let err_word = if total_errors == 1 { "error" } else { "errors" };

    let summary = if use_color {
        format!(
            "{} {file_word}, {} {func_word}, {} {warn_word}, {} {err_word}",
            file_count.bold(),
            total_functions.bold(),
            total_warnings.bold(),
            total_errors.bold(),
        )
    } else {
        format!(
            "{file_count} {file_word}, {total_functions} {func_word}, {total_warnings} {warn_word}, {total_errors} {err_word}"
        )
    };

    writeln!(writer, "{summary}")?;

    // Health score
    if health_count > 0 {
        let avg_health = total_health / health_count as f64;
        let health_str = format!("Health score: {:.1}", avg_health);
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

    Ok(())
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use crate::types::FileAnalysisResult;

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

        assert!(output.contains("src/example.ts"), "Should contain file path");
        assert!(output.contains("10:0"), "Should contain line:col");
        assert!(output.contains("warning"), "Should contain severity");
        assert!(output.contains("Cyclomatic complexity 12"), "Should contain message");
        assert!(output.contains("complexity-guard/cyclomatic"), "Should contain rule-id");
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
        assert!(output.contains("Cyclomatic complexity 25"), "Should contain cyclomatic message");
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

        assert!(output.contains("1 file"), "Should show file count");
        assert!(output.contains("3 functions"), "Should show function count");
        assert!(output.contains("1 warning"), "Should show warning count");
        assert!(output.contains("1 error"), "Should show error count");
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

        // Quiet mode suppresses the violation lines but summary still counts warnings
        assert!(!output.contains("src/test.ts"), "Quiet mode should suppress the file section for warning-only files");
        assert!(output.contains("1 warning"), "Summary should still count warnings");
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

        assert!(output.contains("ok"), "Verbose mode should show ok functions");
    }

    #[test]
    fn test_render_console_no_verbose_hides_ok_functions() {
        let func = make_func("simpleFunc", 5, 2, 1, 95.0); // no violations
        let file = make_file("src/clean.ts", vec![func]);
        let config = default_config();
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        // File path should NOT appear since no violations
        assert!(!output.contains("src/clean.ts"), "File with no violations should not appear");
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
        let cyc_violations: Vec<_> = violations.iter().filter(|v| v.rule_id.contains("cyclomatic")).collect();
        assert_eq!(cyc_violations.len(), 1);
        assert_eq!(cyc_violations[0].severity, Severity::Error);
    }

    #[test]
    fn test_function_violations_no_violations() {
        let func = make_func("f", 1, 3, 3, 95.0);
        let config = default_config();
        let violations = function_violations(&func, &config);
        assert!(violations.is_empty(), "Should have no violations for low complexity");
    }

    #[test]
    fn test_function_status_ok() {
        assert_eq!(function_status(&[]), "ok");
    }

    #[test]
    fn test_function_status_warning() {
        let v = Violation {
            line: 1, col: 0,
            severity: Severity::Warning,
            message: "test".to_string(),
            rule_id: "test".to_string(),
        };
        assert_eq!(function_status(&[v]), "warning");
    }

    #[test]
    fn test_function_status_error() {
        let v = Violation {
            line: 1, col: 0,
            severity: Severity::Error,
            message: "test".to_string(),
            rule_id: "test".to_string(),
        };
        assert_eq!(function_status(&[v]), "error");
    }

    #[test]
    fn test_render_console_health_score_shown() {
        let func = make_func("f", 1, 2, 1, 85.0);
        let file = make_file("src/test.ts", vec![func]);
        let mut config = default_config();
        config.verbose = true; // to see the file
        let mut buf = Vec::new();
        render_console(&[file], None, &config, &mut buf).unwrap();
        let output = String::from_utf8(buf).unwrap();

        assert!(output.contains("Health score:"), "Should show health score");
        assert!(output.contains("85.0"), "Should show the actual score");
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

        assert!(output.contains("2 files"), "Should show 2 files");
        assert!(output.contains("2 functions"), "Should show 2 functions");
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
