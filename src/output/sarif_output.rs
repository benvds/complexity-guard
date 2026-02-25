use crate::cli::ResolvedConfig;
use crate::output::console::{function_violations, Severity};
use crate::types::{DuplicationResult, FileAnalysisResult};

const SARIF_SCHEMA: &str =
    "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json";
const SARIF_VERSION: &str = "2.1.0";
const TOOL_NAME: &str = "ComplexityGuard";
const TOOL_VERSION: &str = env!("CARGO_PKG_VERSION");
const TOOL_INFO_URI: &str = "https://github.com/benvds/complexity-guard";

// Rule index constants matching the Zig source exactly
const RULE_CYCLOMATIC: usize = 0;
const RULE_COGNITIVE: usize = 1;
const RULE_HALSTEAD_VOLUME: usize = 2;
const RULE_HALSTEAD_DIFFICULTY: usize = 3;
const RULE_HALSTEAD_EFFORT: usize = 4;
const RULE_HALSTEAD_BUGS: usize = 5;
const RULE_LINE_COUNT: usize = 6;
const RULE_PARAM_COUNT: usize = 7;
const RULE_NESTING_DEPTH: usize = 8;
const RULE_HEALTH_SCORE: usize = 9;
const RULE_DUPLICATION: usize = 10;

// --- SARIF 2.1.0 hand-rolled structs ---

#[derive(serde::Serialize)]
pub struct SarifLog<'a> {
    #[serde(rename = "$schema")]
    pub schema: &'a str,
    pub version: &'a str,
    pub runs: Vec<SarifRun>,
}

#[derive(serde::Serialize)]
pub struct SarifRun {
    pub tool: SarifTool,
    pub results: Vec<SarifResult>,
}

#[derive(serde::Serialize)]
pub struct SarifTool {
    pub driver: SarifDriver,
}

#[derive(serde::Serialize)]
pub struct SarifDriver {
    pub name: &'static str,
    pub version: &'static str,
    #[serde(rename = "informationUri")]
    pub information_uri: &'static str,
    pub rules: Vec<SarifRule>,
}

#[derive(serde::Serialize)]
pub struct SarifRule {
    pub id: &'static str,
    pub name: &'static str,
    #[serde(rename = "shortDescription")]
    pub short_description: SarifMessage<'static>,
    #[serde(rename = "fullDescription")]
    pub full_description: SarifMessage<'static>,
    #[serde(rename = "defaultConfiguration")]
    pub default_configuration: SarifConfiguration,
    #[serde(rename = "helpUri")]
    pub help_uri: &'static str,
    pub help: SarifMessage<'static>,
}

#[derive(serde::Serialize)]
pub struct SarifConfiguration {
    pub level: &'static str,
}

#[derive(serde::Serialize)]
pub struct SarifMessage<'a> {
    pub text: &'a str,
}

#[derive(serde::Serialize)]
pub struct SarifResult {
    #[serde(rename = "ruleId")]
    pub rule_id: &'static str,
    #[serde(rename = "ruleIndex")]
    pub rule_index: usize,
    pub level: &'static str,
    pub message: SarifOwnedMessage,
    pub locations: Vec<SarifLocation>,
    #[serde(rename = "relatedLocations", skip_serializing_if = "Option::is_none")]
    pub related_locations: Option<Vec<SarifRelatedLocation>>,
}

#[derive(serde::Serialize)]
pub struct SarifOwnedMessage {
    pub text: String,
}

#[derive(serde::Serialize)]
pub struct SarifLocation {
    #[serde(rename = "physicalLocation")]
    pub physical_location: SarifPhysicalLocation,
}

#[derive(serde::Serialize)]
pub struct SarifPhysicalLocation {
    #[serde(rename = "artifactLocation")]
    pub artifact_location: SarifArtifactLocation,
    pub region: SarifRegion,
}

#[derive(serde::Serialize)]
pub struct SarifArtifactLocation {
    pub uri: String,
}

#[derive(serde::Serialize)]
pub struct SarifRegion {
    #[serde(rename = "startLine")]
    pub start_line: usize,
    #[serde(rename = "startColumn")]
    pub start_column: usize,
    #[serde(rename = "endLine")]
    pub end_line: usize,
}

#[derive(serde::Serialize)]
pub struct SarifRelatedLocation {
    pub id: usize,
    pub message: SarifOwnedMessage,
    #[serde(rename = "physicalLocation")]
    pub physical_location: SarifPhysicalLocation,
}

/// Build all 11 SARIF rule definitions matching the Zig source exactly.
fn build_rules() -> Vec<SarifRule> {
    vec![
        // RULE 0: Cyclomatic complexity
        SarifRule {
            id: "complexity-guard/cyclomatic",
            name: "CyclomaticComplexity",
            short_description: SarifMessage { text: "Cyclomatic complexity exceeded threshold" },
            full_description: SarifMessage {
                text: "Cyclomatic complexity measures the number of linearly independent paths through a function. It counts decision points like if statements, loops, logical operators, and ternary expressions plus 1 (McCabe's base). High values indicate functions that are hard to test and maintain.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/cyclomatic-complexity.md",
            help: SarifMessage {
                text: "Reduce cyclomatic complexity by extracting complex conditional logic into smaller functions, simplifying boolean expressions, or replacing switch statements with lookup tables.",
            },
        },
        // RULE 1: Cognitive complexity
        SarifRule {
            id: "complexity-guard/cognitive",
            name: "CognitiveComplexity",
            short_description: SarifMessage { text: "Cognitive complexity exceeded threshold" },
            full_description: SarifMessage {
                text: "Cognitive complexity measures how difficult a function is to understand, weighted by nesting depth and structural increments. Defined by G. Ann Campbell/SonarSource. Higher nesting adds more weight to each control flow element.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/cognitive-complexity.md",
            help: SarifMessage {
                text: "Reduce cognitive complexity by flattening nested conditions using early returns, extracting nested loops into separate functions, and simplifying deeply nested logic.",
            },
        },
        // RULE 2: Halstead volume
        SarifRule {
            id: "complexity-guard/halstead-volume",
            name: "HalsteadVolume",
            short_description: SarifMessage { text: "Halstead volume exceeded threshold" },
            full_description: SarifMessage {
                text: "Halstead volume measures the information content of a program, calculated as N * log2(n) where N is total operators+operands and n is distinct operators+operands. High volume indicates functions with excessive vocabulary or repetition.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
            help: SarifMessage {
                text: "Reduce Halstead volume by splitting large functions, eliminating redundant expressions, and extracting repeated patterns into helper functions.",
            },
        },
        // RULE 3: Halstead difficulty
        SarifRule {
            id: "complexity-guard/halstead-difficulty",
            name: "HalsteadDifficulty",
            short_description: SarifMessage { text: "Halstead difficulty exceeded threshold" },
            full_description: SarifMessage {
                text: "Halstead difficulty measures implementation error-proneness, calculated as (n1/2) * (N2/n2) where n1 is distinct operators, N2 is total operands, and n2 is distinct operands. High difficulty indicates repeated operands with many unique operators.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
            help: SarifMessage {
                text: "Reduce Halstead difficulty by introducing named constants for repeated values, reducing operator diversity, and clarifying variable naming to reduce operand reuse.",
            },
        },
        // RULE 4: Halstead effort
        SarifRule {
            id: "complexity-guard/halstead-effort",
            name: "HalsteadEffort",
            short_description: SarifMessage { text: "Halstead effort exceeded threshold" },
            full_description: SarifMessage {
                text: "Halstead effort estimates the mental effort required to implement or understand a function, calculated as Volume * Difficulty. It combines both the information content and the error-proneness into a single measure.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
            help: SarifMessage {
                text: "Reduce Halstead effort by addressing both volume (split large functions) and difficulty (reduce operator/operand repetition) simultaneously.",
            },
        },
        // RULE 5: Halstead bugs
        SarifRule {
            id: "complexity-guard/halstead-bugs",
            name: "HalsteadBugs",
            short_description: SarifMessage { text: "Halstead bug estimate exceeded threshold" },
            full_description: SarifMessage {
                text: "Halstead bug estimate predicts the number of errors in the implementation, calculated as Volume / 3000. Higher values correlate with increased defect density and maintenance burden.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/halstead-complexity.md",
            help: SarifMessage {
                text: "Reduce the bug estimate by splitting complex functions into smaller, well-tested units. Each unit should have a single, clear responsibility.",
            },
        },
        // RULE 6: Line count
        SarifRule {
            id: "complexity-guard/line-count",
            name: "LineCount",
            short_description: SarifMessage { text: "Function line count exceeded threshold" },
            full_description: SarifMessage {
                text: "Measures the logical line count of a function body, excluding blank lines and brace-only lines. Long functions are harder to read, test, and maintain. The Single Responsibility Principle suggests functions should do one thing.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
            help: SarifMessage {
                text: "Reduce function length by extracting logical sections into well-named helper functions. Aim for functions that fit on a single screen without scrolling.",
            },
        },
        // RULE 7: Param count
        SarifRule {
            id: "complexity-guard/param-count",
            name: "ParamCount",
            short_description: SarifMessage { text: "Function parameter count exceeded threshold" },
            full_description: SarifMessage {
                text: "Measures the number of parameters a function accepts. Functions with many parameters are harder to call correctly, test, and remember. High parameter counts often indicate missing abstraction or violated cohesion.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
            help: SarifMessage {
                text: "Reduce parameter count by grouping related parameters into an options object, using builder patterns, or splitting the function into smaller focused functions.",
            },
        },
        // RULE 8: Nesting depth
        SarifRule {
            id: "complexity-guard/nesting-depth",
            name: "NestingDepth",
            short_description: SarifMessage { text: "Function nesting depth exceeded threshold" },
            full_description: SarifMessage {
                text: "Measures the maximum nesting depth within a function body. Deeply nested code is harder to read and reason about. Each level of nesting increases the cognitive load required to understand the surrounding context.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/structural-complexity.md",
            help: SarifMessage {
                text: "Reduce nesting depth by using early returns to handle edge cases first, extracting nested blocks into helper functions, and inverting conditions to eliminate else clauses.",
            },
        },
        // RULE 9: Health score
        SarifRule {
            id: "complexity-guard/health-score",
            name: "HealthScore",
            short_description: SarifMessage { text: "File health score below baseline" },
            full_description: SarifMessage {
                text: "The composite health score aggregates all metric families using configurable weights into a single 0-100 score. A score below the configured baseline indicates the file's complexity has regressed since the baseline was recorded.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/health-score.md",
            help: SarifMessage {
                text: "Improve the health score by addressing the metric violations shown in other results. The health score weights cyclomatic, cognitive, Halstead, and structural metrics. Run without a baseline to see individual violations.",
            },
        },
        // RULE 10: Duplication
        SarifRule {
            id: "complexity-guard/duplication",
            name: "CodeDuplication",
            short_description: SarifMessage { text: "Duplicate code block detected across files" },
            full_description: SarifMessage {
                text: "A sequence of tokens was found duplicated in multiple locations. Consider extracting shared code into a reusable function or module.",
            },
            default_configuration: SarifConfiguration { level: "warning" },
            help_uri: "https://github.com/benvds/complexity-guard/blob/main/docs/duplication.md",
            help: SarifMessage {
                text: "Eliminate code duplication by extracting duplicated logic into shared functions, utilities, or modules. Type 2 clones (structurally identical with different variable names) can often be generalized with parameters.",
            },
        },
    ]
}

/// Map a rule_id string to the corresponding rule index constant.
fn rule_id_to_index(rule_id: &str) -> usize {
    match rule_id {
        "complexity-guard/cyclomatic" => RULE_CYCLOMATIC,
        "complexity-guard/cognitive" => RULE_COGNITIVE,
        "complexity-guard/halstead-volume" => RULE_HALSTEAD_VOLUME,
        "complexity-guard/halstead-difficulty" => RULE_HALSTEAD_DIFFICULTY,
        "complexity-guard/halstead-effort" => RULE_HALSTEAD_EFFORT,
        "complexity-guard/halstead-bugs" => RULE_HALSTEAD_BUGS,
        "complexity-guard/line-count" => RULE_LINE_COUNT,
        "complexity-guard/param-count" => RULE_PARAM_COUNT,
        "complexity-guard/nesting-depth" => RULE_NESTING_DEPTH,
        "complexity-guard/health-score" => RULE_HEALTH_SCORE,
        "complexity-guard/duplication" => RULE_DUPLICATION,
        _ => 0,
    }
}

/// Map a rule_id string to the static str (for use in SarifResult).
fn rule_id_static(rule_id: &str) -> &'static str {
    match rule_id {
        "complexity-guard/cyclomatic" => "complexity-guard/cyclomatic",
        "complexity-guard/cognitive" => "complexity-guard/cognitive",
        "complexity-guard/halstead-volume" => "complexity-guard/halstead-volume",
        "complexity-guard/halstead-difficulty" => "complexity-guard/halstead-difficulty",
        "complexity-guard/halstead-effort" => "complexity-guard/halstead-effort",
        "complexity-guard/halstead-bugs" => "complexity-guard/halstead-bugs",
        "complexity-guard/line-count" => "complexity-guard/line-count",
        "complexity-guard/param-count" => "complexity-guard/param-count",
        "complexity-guard/nesting-depth" => "complexity-guard/nesting-depth",
        "complexity-guard/health-score" => "complexity-guard/health-score",
        "complexity-guard/duplication" => "complexity-guard/duplication",
        _ => "complexity-guard/cyclomatic",
    }
}

/// Map Severity to SARIF level static str.
fn severity_to_level(severity: &Severity) -> &'static str {
    match severity {
        Severity::Error => "error",
        Severity::Warning => "warning",
    }
}

/// Render SARIF 2.1.0 output from analysis results.
///
/// Produces a valid SARIF log with all 11 rule definitions and results for
/// every threshold violation detected across all analyzed files.
pub fn render_sarif(
    files: &[FileAnalysisResult],
    duplication: Option<&DuplicationResult>,
    config: &ResolvedConfig,
) -> anyhow::Result<String> {
    let rules = build_rules();
    let mut sarif_results: Vec<SarifResult> = Vec::new();

    // Build results from function threshold violations
    for file in files {
        let uri = file.path.to_string_lossy().to_string();
        for func in &file.functions {
            let violations = function_violations(func, config);
            for violation in violations {
                let rule_id_str = violation.rule_id.as_str();
                sarif_results.push(SarifResult {
                    rule_id: rule_id_static(rule_id_str),
                    rule_index: rule_id_to_index(rule_id_str),
                    level: severity_to_level(&violation.severity),
                    message: SarifOwnedMessage {
                        text: violation.message,
                    },
                    locations: vec![SarifLocation {
                        physical_location: SarifPhysicalLocation {
                            artifact_location: SarifArtifactLocation { uri: uri.clone() },
                            region: SarifRegion {
                                start_line: func.start_line,
                                // SARIF uses 1-indexed columns; our cols are 0-indexed
                                start_column: func.start_col + 1,
                                end_line: func.end_line,
                            },
                        },
                    }],
                    related_locations: None,
                });
            }
        }
    }

    // Build duplication results if present
    if let Some(dup) = duplication {
        for (group_idx, group) in dup.clone_groups.iter().enumerate() {
            if group.instances.len() < 2 {
                continue;
            }
            // The primary location is the first instance
            let primary = &group.instances[0];
            let primary_file = files.get(primary.file_index);
            let primary_uri = primary_file
                .map(|f| f.path.to_string_lossy().to_string())
                .unwrap_or_default();

            let related: Vec<SarifRelatedLocation> = group
                .instances
                .iter()
                .enumerate()
                .skip(1)
                .filter_map(|(i, inst)| {
                    let f = files.get(inst.file_index)?;
                    Some(SarifRelatedLocation {
                        id: i,
                        message: SarifOwnedMessage {
                            text: format!(
                                "Duplicate clone instance {} of group {}",
                                i + 1,
                                group_idx + 1
                            ),
                        },
                        physical_location: SarifPhysicalLocation {
                            artifact_location: SarifArtifactLocation {
                                uri: f.path.to_string_lossy().to_string(),
                            },
                            region: SarifRegion {
                                start_line: inst.start_line,
                                start_column: 1,
                                end_line: inst.end_line,
                            },
                        },
                    })
                })
                .collect();

            sarif_results.push(SarifResult {
                rule_id: "complexity-guard/duplication",
                rule_index: RULE_DUPLICATION,
                level: "warning",
                message: SarifOwnedMessage {
                    text: format!(
                        "Duplicate code block detected: {} tokens duplicated across {} locations",
                        group.token_count,
                        group.instances.len()
                    ),
                },
                locations: vec![SarifLocation {
                    physical_location: SarifPhysicalLocation {
                        artifact_location: SarifArtifactLocation { uri: primary_uri },
                        region: SarifRegion {
                            start_line: primary.start_line,
                            start_column: 1,
                            end_line: primary.end_line,
                        },
                    },
                }],
                related_locations: if related.is_empty() {
                    None
                } else {
                    Some(related)
                },
            });
        }
    }

    let log = SarifLog {
        schema: SARIF_SCHEMA,
        version: SARIF_VERSION,
        runs: vec![SarifRun {
            tool: SarifTool {
                driver: SarifDriver {
                    name: TOOL_NAME,
                    version: TOOL_VERSION,
                    information_uri: TOOL_INFO_URI,
                    rules,
                },
            },
            results: sarif_results,
        }],
    };

    Ok(serde_json::to_string_pretty(&log)?)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cli::ResolvedConfig;
    use crate::types::{FileAnalysisResult, FunctionAnalysisResult};
    use std::path::PathBuf;

    fn make_file(path: &str, functions: Vec<FunctionAnalysisResult>) -> FileAnalysisResult {
        FileAnalysisResult {
            path: PathBuf::from(path),
            functions,
            tokens: vec![],
            file_score: 100.0,
            file_length: 50,
            export_count: 1,
            error: false,
        }
    }

    fn make_func_ok() -> FunctionAnalysisResult {
        FunctionAnalysisResult {
            name: "okFunc".to_string(),
            start_line: 1,
            end_line: 10,
            start_col: 0,
            cyclomatic: 2,
            cognitive: 2,
            halstead_volume: 50.0,
            halstead_difficulty: 2.0,
            halstead_effort: 100.0,
            halstead_time: 5.0,
            halstead_bugs: 0.01,
            function_length: 10,
            params_count: 2,
            nesting_depth: 1,
            health_score: 95.0,
        }
    }

    fn make_func_with_violation() -> FunctionAnalysisResult {
        FunctionAnalysisResult {
            name: "complexFunc".to_string(),
            start_line: 5,
            end_line: 50,
            start_col: 0,
            cyclomatic: 25,          // Exceeds error threshold of 20
            cognitive: 20,           // Exceeds warning threshold of 15
            halstead_volume: 1100.0, // Exceeds error threshold of 1000
            halstead_difficulty: 2.0,
            halstead_effort: 100.0,
            halstead_time: 5.0,
            halstead_bugs: 0.01,
            function_length: 10,
            params_count: 2,
            nesting_depth: 1,
            health_score: 40.0,
        }
    }

    #[test]
    fn sarif_output_parses_as_valid_json() {
        let files = vec![make_file("src/foo.ts", vec![make_func_ok()])];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        assert!(parsed.is_object());
    }

    #[test]
    fn sarif_output_has_schema_field() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let schema = parsed["$schema"].as_str().unwrap();
        assert!(
            schema.contains("sarif-schema-2.1.0.json"),
            "expected SARIF schema URL, got: {schema}"
        );
    }

    #[test]
    fn sarif_output_has_correct_version() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["version"].as_str().unwrap(), "2.1.0");
    }

    #[test]
    fn sarif_output_has_11_rules() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let rules = &parsed["runs"][0]["tool"]["driver"]["rules"];
        assert_eq!(rules.as_array().unwrap().len(), 11);
    }

    #[test]
    fn sarif_output_rule_ids_match_zig_source() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let rules = parsed["runs"][0]["tool"]["driver"]["rules"]
            .as_array()
            .unwrap();
        let rule_ids: Vec<&str> = rules.iter().map(|r| r["id"].as_str().unwrap()).collect();
        assert_eq!(rule_ids[0], "complexity-guard/cyclomatic");
        assert_eq!(rule_ids[1], "complexity-guard/cognitive");
        assert_eq!(rule_ids[2], "complexity-guard/halstead-volume");
        assert_eq!(rule_ids[3], "complexity-guard/halstead-difficulty");
        assert_eq!(rule_ids[4], "complexity-guard/halstead-effort");
        assert_eq!(rule_ids[5], "complexity-guard/halstead-bugs");
        assert_eq!(rule_ids[6], "complexity-guard/line-count");
        assert_eq!(rule_ids[7], "complexity-guard/param-count");
        assert_eq!(rule_ids[8], "complexity-guard/nesting-depth");
        assert_eq!(rule_ids[9], "complexity-guard/health-score");
        assert_eq!(rule_ids[10], "complexity-guard/duplication");
    }

    #[test]
    fn sarif_output_camelcase_field_names() {
        let files: Vec<FileAnalysisResult> = vec![];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        // Driver camelCase fields
        assert!(
            output.contains("\"informationUri\""),
            "expected informationUri in output"
        );
        // Rule camelCase fields
        assert!(
            output.contains("\"shortDescription\""),
            "expected shortDescription in output"
        );
        assert!(
            output.contains("\"fullDescription\""),
            "expected fullDescription in output"
        );
        assert!(output.contains("\"helpUri\""), "expected helpUri in output");
        assert!(
            output.contains("\"defaultConfiguration\""),
            "expected defaultConfiguration in output"
        );
    }

    #[test]
    fn sarif_output_generates_results_for_threshold_violations() {
        let files = vec![make_file(
            "src/complex.ts",
            vec![make_func_with_violation()],
        )];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let results = parsed["runs"][0]["results"].as_array().unwrap();
        // Should have at least cyclomatic, cognitive, and halstead-volume violations
        assert!(
            !results.is_empty(),
            "expected at least one SARIF result for threshold violations"
        );
        let rule_ids: Vec<&str> = results
            .iter()
            .map(|r| r["ruleId"].as_str().unwrap())
            .collect();
        assert!(
            rule_ids.contains(&"complexity-guard/cyclomatic"),
            "expected cyclomatic violation"
        );
        assert!(
            rule_ids.contains(&"complexity-guard/cognitive"),
            "expected cognitive violation"
        );
        assert!(
            rule_ids.contains(&"complexity-guard/halstead-volume"),
            "expected halstead-volume violation"
        );
    }

    #[test]
    fn sarif_results_have_camelcase_location_fields() {
        let files = vec![make_file(
            "src/complex.ts",
            vec![make_func_with_violation()],
        )];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        assert!(
            output.contains("\"physicalLocation\""),
            "expected physicalLocation"
        );
        assert!(
            output.contains("\"artifactLocation\""),
            "expected artifactLocation"
        );
        assert!(output.contains("\"startLine\""), "expected startLine");
        assert!(output.contains("\"startColumn\""), "expected startColumn");
        assert!(output.contains("\"endLine\""), "expected endLine");
        assert!(output.contains("\"ruleId\""), "expected ruleId");
        assert!(output.contains("\"ruleIndex\""), "expected ruleIndex");
    }

    #[test]
    fn sarif_no_results_for_ok_functions() {
        let files = vec![make_file("src/ok.ts", vec![make_func_ok()])];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let results = parsed["runs"][0]["results"].as_array().unwrap();
        assert!(results.is_empty(), "expected no results for ok functions");
    }

    #[test]
    fn sarif_result_level_matches_severity() {
        let files = vec![make_file(
            "src/complex.ts",
            vec![make_func_with_violation()],
        )];
        let config = ResolvedConfig::default();
        let output = render_sarif(&files, None, &config).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&output).unwrap();
        let results = parsed["runs"][0]["results"].as_array().unwrap();
        // cyclomatic=25 exceeds error threshold 20 -> level should be "error"
        let cyc_result = results
            .iter()
            .find(|r| r["ruleId"].as_str().unwrap() == "complexity-guard/cyclomatic")
            .expect("cyclomatic result not found");
        assert_eq!(cyc_result["level"].as_str().unwrap(), "error");
    }
}
