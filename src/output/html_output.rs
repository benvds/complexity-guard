use minijinja::{context, Environment};

use crate::cli::ResolvedConfig;
use crate::output::console::function_violations;
use crate::types::{DuplicationResult, FileAnalysisResult, FunctionAnalysisResult};

const CSS: &str = include_str!("assets/report.css");
const JS: &str = include_str!("assets/report.js");
const TEMPLATE: &str = include_str!("assets/report.html");

const TOOL_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Map a health score (0-100) to a CSS class: "ok", "warning", or "error".
fn score_class(score: f64) -> &'static str {
    if score >= 80.0 {
        "ok"
    } else if score >= 60.0 {
        "warning"
    } else {
        "error"
    }
}

/// Format a health score for display (rounded, no decimals).
fn score_display(score: f64) -> String {
    format!("{:.0}", score)
}

/// Compute metric bar fill percentage, clamped to 0-100.
fn metric_pct(value: f64, error_threshold: f64) -> f64 {
    if error_threshold <= 0.0 {
        return 0.0;
    }
    let pct = value / error_threshold * 100.0;
    if pct > 100.0 {
        100.0
    } else {
        pct
    }
}

/// Map a value to a CSS class based on warning/error thresholds.
fn metric_class(value: f64, warning: f64, error: f64) -> &'static str {
    if value >= error {
        "error"
    } else if value >= warning {
        "warning"
    } else {
        "ok"
    }
}

/// Build minijinja context for a single function.
fn build_function_ctx(func: &FunctionAnalysisResult, config: &ResolvedConfig) -> minijinja::Value {
    let cw = config.cyclomatic_warning as f64;
    let ce = config.cyclomatic_error as f64;
    let kogw = config.cognitive_warning as f64;
    let koge = config.cognitive_error as f64;
    let hvw = config.halstead_volume_warning;
    let hve = config.halstead_volume_error;
    let lcw = config.line_count_warning as f64;
    let lce = config.line_count_error as f64;
    let pw = config.params_count_warning as f64;
    let pe = config.params_count_error as f64;
    let ndw = config.nesting_depth_warning as f64;
    let nde = config.nesting_depth_error as f64;

    let cyc = func.cyclomatic as f64;
    let cog = func.cognitive as f64;
    let hv = func.halstead_volume;
    let ln = func.function_length as f64;
    let params = func.params_count as f64;
    let nesting = func.nesting_depth as f64;

    context! {
        name => func.name.clone(),
        health_score_raw => func.health_score,
        health_display => score_display(func.health_score),
        health_class => score_class(func.health_score),
        cyclomatic => func.cyclomatic,
        cyclomatic_class => metric_class(cyc, cw, ce),
        cyclomatic_pct => format!("{:.1}", metric_pct(cyc, ce)),
        cognitive => func.cognitive,
        cognitive_class => metric_class(cog, kogw, koge),
        cognitive_pct => format!("{:.1}", metric_pct(cog, koge)),
        halstead_volume_display => format!("{:.0}", hv),
        halstead_class => metric_class(hv, hvw, hve),
        halstead_pct => format!("{:.1}", metric_pct(hv, hve)),
        function_length => func.function_length,
        length_class => metric_class(ln, lcw, lce),
        length_pct => format!("{:.1}", metric_pct(ln, lce)),
        params_count => func.params_count,
        params_class => metric_class(params, pw, pe),
        params_pct => format!("{:.1}", metric_pct(params, pe)),
        nesting_depth => func.nesting_depth,
        nesting_class => metric_class(nesting, ndw, nde),
        nesting_pct => format!("{:.1}", metric_pct(nesting, nde)),
    }
}

/// Compute the worst violation status string for a file.
fn worst_status_for_file(file: &FileAnalysisResult, config: &ResolvedConfig) -> &'static str {
    let mut has_warning = false;
    for func in &file.functions {
        let violations = function_violations(func, config);
        for v in &violations {
            match v.severity {
                crate::output::console::Severity::Error => return "error",
                crate::output::console::Severity::Warning => has_warning = true,
            }
        }
    }
    if has_warning {
        "warning"
    } else {
        "ok"
    }
}

/// Render a self-contained HTML report.
///
/// CSS and JS are embedded inline — no external requests are made.
/// The duplication section is included only when duplication data is present.
pub fn render_html(
    files: &[FileAnalysisResult],
    duplication: Option<&DuplicationResult>,
    config: &ResolvedConfig,
    elapsed_ms: u64,
) -> anyhow::Result<String> {
    let mut env = Environment::new();
    env.add_template("report", TEMPLATE)?;
    let tmpl = env.get_template("report")?;

    // Compute project health score (average of file scores)
    let project_score = if files.is_empty() {
        100.0_f64
    } else {
        files.iter().map(|f| f.file_score).sum::<f64>() / files.len() as f64
    };

    // Compute distribution counts (ok/warning/error by file health score)
    let mut ok_count: usize = 0;
    let mut warn_count: usize = 0;
    let mut err_count: usize = 0;
    for f in files {
        let sc = score_class(f.file_score);
        match sc {
            "ok" => ok_count += 1,
            "warning" => warn_count += 1,
            _ => err_count += 1,
        }
    }
    let total_files = files.len();
    let ok_pct = if total_files > 0 {
        format!("{:.1}", ok_count as f64 / total_files as f64 * 100.0)
    } else {
        "0.0".to_string()
    };
    let warn_pct = if total_files > 0 {
        format!("{:.1}", warn_count as f64 / total_files as f64 * 100.0)
    } else {
        "0.0".to_string()
    };
    let err_pct = if total_files > 0 {
        format!("{:.1}", err_count as f64 / total_files as f64 * 100.0)
    } else {
        "0.0".to_string()
    };

    // Count total functions and violations
    let total_functions: usize = files.iter().map(|f| f.functions.len()).sum();
    let mut error_count: usize = 0;
    let mut warning_count: usize = 0;
    for file in files {
        for func in &file.functions {
            let violations = function_violations(func, config);
            for v in &violations {
                match v.severity {
                    crate::output::console::Severity::Error => error_count += 1,
                    crate::output::console::Severity::Warning => warning_count += 1,
                }
            }
        }
    }

    // Build hotspots (up to 5, sorted by health_score ascending)
    let mut all_funcs: Vec<(&FileAnalysisResult, &FunctionAnalysisResult)> = Vec::new();
    for file in files {
        for func in &file.functions {
            all_funcs.push((file, func));
        }
    }
    all_funcs.sort_by(|a, b| {
        a.1.health_score
            .partial_cmp(&b.1.health_score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let hotspots: Vec<minijinja::Value> = all_funcs
        .iter()
        .take(5)
        .map(|(file, func)| {
            let violations = function_violations(func, config);
            let violation_list: Vec<minijinja::Value> = violations
                .iter()
                .map(|v| {
                    let warning_class = if v.severity == crate::output::console::Severity::Warning {
                        " warning".to_string()
                    } else {
                        String::new()
                    };
                    // Short label: extract the metric name from the rule_id
                    let label = match v.rule_id.as_str() {
                        "complexity-guard/cyclomatic" => format!("cyclomatic {}", func.cyclomatic),
                        "complexity-guard/cognitive" => format!("cognitive {}", func.cognitive),
                        "complexity-guard/halstead-volume" => {
                            format!("halstead vol {:.0}", func.halstead_volume)
                        }
                        "complexity-guard/halstead-difficulty" => {
                            format!("halstead diff {:.1}", func.halstead_difficulty)
                        }
                        "complexity-guard/halstead-effort" => {
                            format!("halstead effort {:.0}", func.halstead_effort)
                        }
                        "complexity-guard/halstead-bugs" => {
                            format!("halstead bugs {:.3}", func.halstead_bugs)
                        }
                        "complexity-guard/line-count" => format!("length {}", func.function_length),
                        "complexity-guard/param-count" => format!("params {}", func.params_count),
                        "complexity-guard/nesting-depth" => format!("depth {}", func.nesting_depth),
                        _ => v.rule_id.clone(),
                    };
                    context! {
                        warning_class => warning_class,
                        label => label,
                    }
                })
                .collect();

            context! {
                name => func.name.clone(),
                file_path => file.path.to_string_lossy().to_string(),
                start_line => func.start_line,
                cyclomatic => func.cyclomatic,
                cognitive => func.cognitive,
                halstead_volume_display => format!("{:.0}", func.halstead_volume),
                color_class => score_class(func.health_score),
                violations => violation_list,
            }
        })
        .collect();

    // Build file contexts
    let file_contexts: Vec<minijinja::Value> = files
        .iter()
        .map(|file| {
            let fn_contexts: Vec<minijinja::Value> = file
                .functions
                .iter()
                .map(|func| build_function_ctx(func, config))
                .collect();
            let ws = worst_status_for_file(file, config);
            context! {
                path => file.path.to_string_lossy().to_string(),
                score_raw => file.file_score,
                score_display => score_display(file.file_score),
                score_class => score_class(file.file_score),
                function_count => file.functions.len(),
                worst_status => ws,
                functions => fn_contexts,
            }
        })
        .collect();

    // Build duplication context (None serializes as falsy in minijinja)
    let dup_ctx: Option<minijinja::Value> = duplication.map(|dup| {
        let groups: Vec<minijinja::Value> = dup
            .clone_groups
            .iter()
            .take(20)
            .map(|g| {
                let locations = g
                    .instances
                    .iter()
                    .take(3)
                    .map(|inst| {
                        format!(
                            "file:{} L{}-{}",
                            inst.file_index, inst.start_line, inst.end_line
                        )
                    })
                    .collect::<Vec<_>>()
                    .join(", ");
                context! {
                    token_count => g.token_count,
                    instance_count => g.instances.len(),
                    locations => locations,
                }
            })
            .collect();
        context! {
            percentage_display => format!("{:.1}", dup.duplication_percentage),
            cloned_tokens => dup.cloned_tokens,
            total_tokens => dup.total_tokens,
            clone_group_count => dup.clone_groups.len(),
            clone_groups => groups,
        }
    });

    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let ctx = context! {
        css => CSS,
        js => JS,
        tool_version => TOOL_VERSION,
        elapsed_ms => elapsed_ms,
        project_score => project_score,
        project_score_class => score_class(project_score),
        project_score_display => score_display(project_score),
        ok_count => ok_count,
        warn_count => warn_count,
        err_count => err_count,
        ok_pct => ok_pct,
        warn_pct => warn_pct,
        err_pct => err_pct,
        total_files => total_files,
        total_functions => total_functions,
        error_count => error_count,
        warning_count => warning_count,
        hotspots => hotspots,
        files => file_contexts,
        duplication => dup_ctx,
        timestamp => timestamp,
    };

    Ok(tmpl.render(ctx)?)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cli::ResolvedConfig;
    use crate::types::{
        CloneGroup, CloneInstance, DuplicationResult, FileAnalysisResult, FunctionAnalysisResult,
    };
    use std::path::PathBuf;

    fn make_file(path: &str, functions: Vec<FunctionAnalysisResult>) -> FileAnalysisResult {
        FileAnalysisResult {
            path: PathBuf::from(path),
            functions,
            tokens: vec![],
            file_score: 85.0,
            file_length: 50,
            export_count: 1,
            error: false,
        }
    }

    fn make_func() -> FunctionAnalysisResult {
        FunctionAnalysisResult {
            name: "myFunction".to_string(),
            start_line: 10,
            end_line: 25,
            start_col: 0,
            cyclomatic: 3,
            cognitive: 2,
            halstead_volume: 45.0,
            halstead_difficulty: 3.5,
            halstead_effort: 157.5,
            halstead_time: 8.0,
            halstead_bugs: 0.015,
            function_length: 15,
            params_count: 2,
            nesting_depth: 1,
            health_score: 88.0,
        }
    }

    fn make_dup() -> DuplicationResult {
        DuplicationResult {
            clone_groups: vec![CloneGroup {
                instances: vec![
                    CloneInstance {
                        file_index: 0,
                        start_token: 0,
                        end_token: 30,
                        start_line: 1,
                        end_line: 10,
                    },
                    CloneInstance {
                        file_index: 1,
                        start_token: 0,
                        end_token: 30,
                        start_line: 5,
                        end_line: 15,
                    },
                ],
                token_count: 30,
            }],
            total_tokens: 200,
            cloned_tokens: 60,
            duplication_percentage: 30.0,
        }
    }

    #[test]
    fn html_output_contains_doctype() {
        let files = vec![make_file("src/foo.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 42).unwrap();
        assert!(output.contains("<!DOCTYPE html>"), "expected DOCTYPE html");
    }

    #[test]
    fn html_output_has_embedded_css() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        assert!(output.contains("<style>"), "expected <style> block");
        assert!(
            output.contains("prefers-color-scheme"),
            "expected CSS content (prefers-color-scheme)"
        );
    }

    #[test]
    fn html_output_has_embedded_js() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        assert!(output.contains("<script>"), "expected <script> block");
        assert!(
            output.contains("sortTable"),
            "expected JS content (sortTable)"
        );
    }

    #[test]
    fn html_output_no_external_url_refs() {
        let files = vec![make_file("src/foo.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        // No external link/script/img tags with http/https src
        assert!(
            !output.contains("<link rel=\"stylesheet\""),
            "must not have external stylesheet link"
        );
        assert!(
            !output.contains("<script src="),
            "must not have external script src"
        );
        assert!(
            !output.contains("<img src=\"http"),
            "must not have external img src"
        );
    }

    #[test]
    fn html_output_includes_duplication_section_when_present() {
        let files = vec![make_file("src/foo.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let dup = make_dup();
        let output = render_html(&files, Some(&dup), &config, 10).unwrap();
        assert!(
            output.contains("Code Duplication") || output.contains("duplication-section"),
            "expected duplication section when duplication data present"
        );
        assert!(
            output.contains("30.0%") || output.contains("30"),
            "expected duplication percentage in output"
        );
    }

    #[test]
    fn html_output_excludes_duplication_section_when_absent() {
        let files = vec![make_file("src/foo.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        // The duplication section heading "Code Duplication" only appears in the HTML section,
        // not in the CSS. When no duplication data, the {% if duplication %} block is not rendered.
        assert!(
            !output.contains("Code Duplication"),
            "must not have 'Code Duplication' heading when no duplication data"
        );
        // The section element with class duplication-section only appears when data is present
        assert!(
            !output.contains("class=\"duplication-section\""),
            "must not have <section class=\"duplication-section\"> when no duplication data"
        );
    }

    #[test]
    fn html_output_contains_file_path() {
        let files = vec![make_file("src/mymodule.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        assert!(
            output.contains("src/mymodule.ts"),
            "expected file path in output"
        );
    }

    #[test]
    fn html_output_contains_function_name() {
        let files = vec![make_file("src/foo.ts", vec![make_func()])];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        assert!(
            output.contains("myFunction"),
            "expected function name in output"
        );
    }

    #[test]
    fn html_output_contains_complexity_guard_branding() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_html(&files, None, &config, 10).unwrap();
        assert!(
            output.contains("ComplexityGuard"),
            "expected ComplexityGuard in output"
        );
    }
}
