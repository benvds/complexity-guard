use crate::cli::ResolvedConfig;
use crate::output::console::{function_violations, Severity};
use crate::types::{DuplicationResult, FileAnalysisResult};

/// Duplication thresholds used for computing per-file and project status.
/// These match the Zig defaults since ResolvedConfig does not currently carry
/// duplication thresholds.
const DUP_FILE_WARNING: f64 = 3.0;
const DUP_FILE_ERROR: f64 = 5.0;
const DUP_PROJECT_WARNING: f64 = 3.0;
const DUP_PROJECT_ERROR: f64 = 5.0;

// --- JSON output structs matching Zig schema exactly ---

/// Top-level JSON output matching the Zig JsonOutput struct.
///
/// Field names are snake_case matching the Zig JSON schema exactly.
#[derive(serde::Serialize)]
pub struct JsonOutput {
    pub version: String,
    pub timestamp: u64,
    pub summary: JsonSummary,
    pub files: Vec<JsonFileOutput>,
    pub metadata: JsonMetadata,
    pub duplication: Option<JsonDuplicationOutput>,
}

/// Summary statistics for the entire run.
#[derive(serde::Serialize)]
pub struct JsonSummary {
    pub files_analyzed: usize,
    pub total_functions: usize,
    pub warnings: u32,
    pub errors: u32,
    /// "pass", "warning", or "error"
    pub status: String,
    pub health_score: f64,
}

/// Per-file output matching the Zig JsonFileOutput struct.
#[derive(serde::Serialize)]
pub struct JsonFileOutput {
    pub path: String,
    pub functions: Vec<JsonFunctionOutput>,
    pub file_length: u32,
    pub export_count: u32,
}

/// Per-function output matching the Zig JsonFunctionOutput struct.
///
/// All field names match Zig exactly (snake_case).
#[derive(serde::Serialize)]
pub struct JsonFunctionOutput {
    pub name: String,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
    pub cyclomatic: u32,
    pub cognitive: u32,
    pub halstead_volume: f64,
    pub halstead_difficulty: f64,
    pub halstead_effort: f64,
    pub halstead_bugs: f64,
    pub nesting_depth: u32,
    pub line_count: u32,
    pub params_count: u32,
    pub health_score: f64,
    /// "ok", "warning", or "error"
    pub status: String,
}

/// Execution metadata.
#[derive(serde::Serialize)]
pub struct JsonMetadata {
    pub elapsed_ms: u64,
    pub thread_count: u32,
}

/// Duplication detection results matching the Zig JSON schema exactly.
#[derive(serde::Serialize)]
pub struct JsonDuplicationOutput {
    pub enabled: bool,
    pub project_duplication_pct: f64,
    /// "ok", "warning", or "error"
    pub project_status: String,
    pub clone_groups: Vec<JsonCloneGroup>,
    pub files: Vec<JsonDuplicationFileInfo>,
}

/// A single clone group entry matching Zig schema: token_count + locations array.
#[derive(serde::Serialize)]
pub struct JsonCloneGroup {
    pub token_count: u32,
    pub locations: Vec<JsonCloneLocation>,
}

/// A single clone location within a clone group.
#[derive(serde::Serialize)]
pub struct JsonCloneLocation {
    pub file: String,
    pub start_line: usize,
    pub end_line: usize,
}

/// Per-file duplication stats matching Zig schema.
#[derive(serde::Serialize)]
pub struct JsonDuplicationFileInfo {
    pub path: String,
    pub total_tokens: usize,
    pub cloned_tokens: usize,
    pub duplication_pct: f64,
    /// "ok", "warning", or "error"
    pub status: String,
}

/// Compute a duplication status string from a percentage value and thresholds.
fn duplication_status(pct: f64, warning: f64, error: f64) -> String {
    if pct >= error {
        "error".to_string()
    } else if pct >= warning {
        "warning".to_string()
    } else {
        "ok".to_string()
    }
}

/// Renders analysis results as a JSON string matching the Zig schema exactly.
///
/// Sets `timestamp` to current Unix epoch seconds and `version` from CARGO_PKG_VERSION.
/// The `duplication` field is `null` when `duplication` is None.
pub fn render_json(
    files: &[FileAnalysisResult],
    duplication: Option<&DuplicationResult>,
    config: &ResolvedConfig,
    elapsed_ms: u64,
) -> anyhow::Result<String> {
    let mut total_warnings: u32 = 0;
    let mut total_errors: u32 = 0;
    let mut total_functions: usize = 0;
    let mut total_health: f64 = 0.0;

    let json_files: Vec<JsonFileOutput> = files
        .iter()
        .map(|file| {
            let json_functions: Vec<JsonFunctionOutput> = file
                .functions
                .iter()
                .map(|func| {
                    total_functions += 1;
                    total_health += func.health_score;

                    let violations = function_violations(func, config);
                    let func_warnings = violations
                        .iter()
                        .filter(|v| v.severity == Severity::Warning)
                        .count() as u32;
                    let func_errors = violations
                        .iter()
                        .filter(|v| v.severity == Severity::Error)
                        .count() as u32;
                    total_warnings += func_warnings;
                    total_errors += func_errors;

                    let status = if func_errors > 0 {
                        "error".to_string()
                    } else if func_warnings > 0 {
                        "warning".to_string()
                    } else {
                        "ok".to_string()
                    };

                    JsonFunctionOutput {
                        name: func.name.clone(),
                        start_line: func.start_line,
                        end_line: func.end_line,
                        start_col: func.start_col,
                        cyclomatic: func.cyclomatic,
                        cognitive: func.cognitive,
                        halstead_volume: func.halstead_volume,
                        halstead_difficulty: func.halstead_difficulty,
                        halstead_effort: func.halstead_effort,
                        halstead_bugs: func.halstead_bugs,
                        nesting_depth: func.nesting_depth,
                        line_count: func.function_length,
                        params_count: func.params_count,
                        health_score: func.health_score,
                        status,
                    }
                })
                .collect();

            JsonFileOutput {
                path: file.path.to_string_lossy().to_string(),
                functions: json_functions,
                file_length: file.file_length,
                export_count: file.export_count,
            }
        })
        .collect();

    let summary_status = if total_errors > 0 {
        "error".to_string()
    } else if total_warnings > 0 {
        "warning".to_string()
    } else {
        "pass".to_string()
    };

    let avg_health = if total_functions > 0 {
        total_health / total_functions as f64
    } else {
        100.0
    };

    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let json_duplication = duplication.map(|d| {
        // Build clone groups with locations (file paths resolved from files slice)
        let clone_groups: Vec<JsonCloneGroup> = d
            .clone_groups
            .iter()
            .map(|group| {
                let locations: Vec<JsonCloneLocation> = group
                    .instances
                    .iter()
                    .map(|inst| {
                        let file_path = if inst.file_index < files.len() {
                            files[inst.file_index].path.to_string_lossy().to_string()
                        } else {
                            String::new()
                        };
                        JsonCloneLocation {
                            file: file_path,
                            start_line: inst.start_line,
                            end_line: inst.end_line,
                        }
                    })
                    .collect();
                JsonCloneGroup {
                    token_count: group.token_count,
                    locations,
                }
            })
            .collect();

        // Compute per-file cloned token counts from clone group instances
        let mut file_cloned: Vec<usize> = vec![0usize; files.len()];
        for group in &d.clone_groups {
            for inst in &group.instances {
                if inst.file_index < files.len() {
                    // Count tokens in this instance: end_token - start_token
                    // If token indices are available use them; else approximate with token_count
                    file_cloned[inst.file_index] += group.token_count as usize;
                }
            }
        }

        // Build per-file info array
        let dup_files: Vec<JsonDuplicationFileInfo> = files
            .iter()
            .enumerate()
            .map(|(i, f)| {
                let total = f.tokens.len();
                let cloned = file_cloned[i];
                let pct = if total > 0 {
                    (cloned as f64 / total as f64) * 100.0
                } else {
                    0.0
                };
                let status = duplication_status(pct, DUP_FILE_WARNING, DUP_FILE_ERROR);
                JsonDuplicationFileInfo {
                    path: f.path.to_string_lossy().to_string(),
                    total_tokens: total,
                    cloned_tokens: cloned,
                    duplication_pct: pct,
                    status,
                }
            })
            .collect();

        let project_status = duplication_status(
            d.duplication_percentage,
            DUP_PROJECT_WARNING,
            DUP_PROJECT_ERROR,
        );

        JsonDuplicationOutput {
            enabled: true,
            project_duplication_pct: d.duplication_percentage,
            project_status,
            clone_groups,
            files: dup_files,
        }
    });

    let output = JsonOutput {
        version: env!("CARGO_PKG_VERSION").to_string(),
        timestamp,
        summary: JsonSummary {
            files_analyzed: files.len(),
            total_functions,
            warnings: total_warnings,
            errors: total_errors,
            status: summary_status,
            health_score: avg_health,
        },
        files: json_files,
        metadata: JsonMetadata {
            elapsed_ms,
            thread_count: config.threads,
        },
        duplication: json_duplication,
    };

    Ok(serde_json::to_string_pretty(&output)?)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{FileAnalysisResult, FunctionAnalysisResult};
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
            halstead_volume: 45.0,
            halstead_difficulty: 3.5,
            halstead_effort: 157.5,
            halstead_time: 8.75,
            halstead_bugs: 0.015,
            function_length: 10,
            params_count: 2,
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
            export_count: 3,
            error: false,
        }
    }

    fn default_config() -> ResolvedConfig {
        ResolvedConfig::default()
    }

    #[test]
    fn test_render_json_field_names() {
        let func = make_func("myFunc", 10, 3, 2, 88.0);
        let file = make_file("src/foo.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 45).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        // Top-level fields
        assert!(parsed["version"].is_string(), "version field missing");
        assert!(parsed["timestamp"].is_number(), "timestamp field missing");
        assert!(parsed["summary"].is_object(), "summary field missing");
        assert!(parsed["files"].is_array(), "files field missing");
        assert!(parsed["metadata"].is_object(), "metadata field missing");
        assert!(
            parsed["duplication"].is_null(),
            "duplication should be null"
        );

        // Summary fields
        let summary = &parsed["summary"];
        assert!(summary["files_analyzed"].is_number());
        assert!(summary["total_functions"].is_number());
        assert!(summary["warnings"].is_number());
        assert!(summary["errors"].is_number());
        assert!(summary["status"].is_string());
        assert!(summary["health_score"].is_number());

        // File fields
        let file_obj = &parsed["files"][0];
        assert!(file_obj["path"].is_string());
        assert!(file_obj["functions"].is_array());
        assert!(file_obj["file_length"].is_number());
        assert!(file_obj["export_count"].is_number());

        // Function fields
        let func_obj = &file_obj["functions"][0];
        assert!(func_obj["name"].is_string());
        assert!(func_obj["start_line"].is_number());
        assert!(func_obj["end_line"].is_number());
        assert!(func_obj["start_col"].is_number());
        assert!(func_obj["cyclomatic"].is_number());
        assert!(func_obj["cognitive"].is_number());
        assert!(func_obj["halstead_volume"].is_number());
        assert!(func_obj["halstead_difficulty"].is_number());
        assert!(func_obj["halstead_effort"].is_number());
        assert!(func_obj["halstead_bugs"].is_number());
        assert!(func_obj["nesting_depth"].is_number());
        assert!(func_obj["line_count"].is_number());
        assert!(func_obj["params_count"].is_number());
        assert!(func_obj["health_score"].is_number());
        assert!(func_obj["status"].is_string());

        // Metadata fields
        let metadata = &parsed["metadata"];
        assert!(metadata["elapsed_ms"].is_number());
        assert!(metadata["thread_count"].is_number());
    }

    #[test]
    fn test_render_json_status_ok() {
        // Function below all warning thresholds
        let func = make_func("simpleFunc", 5, 3, 2, 95.0);
        let file = make_file("src/clean.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 10).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let func_status = parsed["files"][0]["functions"][0]["status"]
            .as_str()
            .unwrap();
        assert_eq!(
            func_status, "ok",
            "Function below thresholds should have status ok"
        );

        let summary_status = parsed["summary"]["status"].as_str().unwrap();
        assert_eq!(
            summary_status, "pass",
            "Summary with no violations should be pass"
        );
    }

    #[test]
    fn test_render_json_status_warning() {
        // Cyclomatic complexity 12 > warning threshold 10
        let func = make_func("warnFunc", 10, 12, 5, 72.0);
        let file = make_file("src/warn.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 10).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let func_status = parsed["files"][0]["functions"][0]["status"]
            .as_str()
            .unwrap();
        assert_eq!(func_status, "warning");

        let summary_status = parsed["summary"]["status"].as_str().unwrap();
        assert_eq!(summary_status, "warning");
    }

    #[test]
    fn test_render_json_status_error() {
        // Cyclomatic complexity 25 > error threshold 20
        let func = make_func("errFunc", 25, 25, 5, 40.0);
        let file = make_file("src/error.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 10).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let func_status = parsed["files"][0]["functions"][0]["status"]
            .as_str()
            .unwrap();
        assert_eq!(func_status, "error");

        let summary_status = parsed["summary"]["status"].as_str().unwrap();
        assert_eq!(summary_status, "error");
    }

    #[test]
    fn test_render_json_summary_status_error_when_any_error() {
        // One ok, one error function: summary should be "error"
        let func_ok = make_func("ok", 1, 2, 1, 95.0);
        let func_err = make_func("bad", 20, 25, 5, 40.0);
        let file = make_file("src/mixed.ts", vec![func_ok, func_err]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 10).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        assert_eq!(parsed["summary"]["status"].as_str().unwrap(), "error");
        assert_eq!(parsed["summary"]["errors"].as_u64().unwrap(), 1);
        assert_eq!(parsed["summary"]["total_functions"].as_u64().unwrap(), 2);
    }

    #[test]
    fn test_render_json_duplication_null_when_absent() {
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/a.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 5).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        assert!(
            parsed["duplication"].is_null(),
            "duplication should be null when not provided"
        );
    }

    #[test]
    fn test_render_json_duplication_present() {
        use crate::types::DuplicationResult;
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/a.ts", vec![func]);
        let config = default_config();
        let dup = DuplicationResult {
            clone_groups: vec![],
            total_tokens: 1000,
            cloned_tokens: 150,
            duplication_percentage: 15.0,
        };
        let json_str = render_json(&[file], Some(&dup), &config, 5).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        // Verify Zig schema fields are present
        assert!(
            !parsed["duplication"].is_null(),
            "duplication should be present"
        );
        let dup_obj = &parsed["duplication"];
        assert!(
            dup_obj["enabled"].as_bool().unwrap(),
            "enabled must be true"
        );
        assert_eq!(
            dup_obj["project_duplication_pct"].as_f64().unwrap(),
            15.0,
            "project_duplication_pct must match"
        );
        assert_eq!(
            dup_obj["project_status"].as_str().unwrap(),
            "error",
            "15% duplication should be error status (threshold=5%)"
        );
        assert!(
            dup_obj["clone_groups"].is_array(),
            "clone_groups must be array"
        );
        assert!(dup_obj["files"].is_array(), "files must be array");
    }

    #[test]
    fn test_render_json_duplication_schema_field_names() {
        // Verifies the Zig schema field names are present (not the old Rust schema names).
        use crate::types::Token;
        use crate::types::{CloneGroup, CloneInstance, DuplicationResult};
        let token = Token {
            kind: "identifier",
            kind_hash: 0,
            start_byte: 0,
            end_byte: 5,
        };
        let tokens = vec![token; 50];
        let file = FileAnalysisResult {
            path: std::path::PathBuf::from("src/a.ts"),
            functions: vec![make_func("f", 1, 2, 1, 90.0)],
            tokens,
            file_score: 90.0,
            file_length: 100,
            export_count: 1,
            error: false,
        };
        let config = default_config();
        let clone_instance = CloneInstance {
            file_index: 0,
            start_token: 0,
            end_token: 24,
            start_line: 1,
            end_line: 10,
        };
        let dup = DuplicationResult {
            clone_groups: vec![CloneGroup {
                instances: vec![clone_instance],
                token_count: 25,
            }],
            total_tokens: 50,
            cloned_tokens: 25,
            duplication_percentage: 50.0,
        };
        let json_str = render_json(&[file], Some(&dup), &config, 5).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();
        let dup_obj = &parsed["duplication"];

        // Zig schema fields must be present
        assert!(dup_obj["enabled"].is_boolean(), "enabled field missing");
        assert!(
            dup_obj["project_duplication_pct"].is_number(),
            "project_duplication_pct missing"
        );
        assert!(
            dup_obj["project_status"].is_string(),
            "project_status missing"
        );
        assert!(dup_obj["clone_groups"].is_array(), "clone_groups missing");
        assert!(dup_obj["files"].is_array(), "files missing");

        // Old Rust schema fields must NOT be present
        assert!(
            dup_obj["total_tokens"].is_null(),
            "total_tokens is old Rust schema — should not be present"
        );
        assert!(
            dup_obj["cloned_tokens"].is_null(),
            "cloned_tokens is old Rust schema — should not be present"
        );
        assert!(
            dup_obj["duplication_percentage"].is_null(),
            "duplication_percentage is old Rust schema — should not be present"
        );

        // Clone group structure: token_count + locations
        let group = &dup_obj["clone_groups"][0];
        assert!(group["token_count"].is_number(), "token_count missing");
        assert!(group["locations"].is_array(), "locations missing");
        // Old schema uses instances — must not be present
        assert!(
            group["instances"].is_null(),
            "instances is old Rust schema — should not be present"
        );

        // Location structure: file, start_line, end_line
        let location = &group["locations"][0];
        assert!(location["file"].is_string(), "location.file missing");
        assert!(
            location["start_line"].is_number(),
            "location.start_line missing"
        );
        assert!(
            location["end_line"].is_number(),
            "location.end_line missing"
        );

        // Per-file array structure: path, total_tokens, cloned_tokens, duplication_pct, status
        let file_info = &dup_obj["files"][0];
        assert!(file_info["path"].is_string(), "file_info.path missing");
        assert!(
            file_info["total_tokens"].is_number(),
            "file_info.total_tokens missing"
        );
        assert!(
            file_info["cloned_tokens"].is_number(),
            "file_info.cloned_tokens missing"
        );
        assert!(
            file_info["duplication_pct"].is_number(),
            "file_info.duplication_pct missing"
        );
        assert!(file_info["status"].is_string(), "file_info.status missing");
    }

    #[test]
    fn test_render_json_timestamp_present_and_reasonable() {
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/a.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 5).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let ts = parsed["timestamp"].as_u64().unwrap();
        // Should be a reasonable Unix timestamp (after 2024-01-01 = 1704067200)
        assert!(ts > 1704067200, "timestamp should be a valid Unix epoch");
        // Should not be too far in the future (before 2050)
        assert!(
            ts < 2524608000,
            "timestamp should not be unreasonably far in the future"
        );
    }

    #[test]
    fn test_render_json_version_matches_cargo() {
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/a.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 5).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        assert_eq!(
            parsed["version"].as_str().unwrap(),
            env!("CARGO_PKG_VERSION"),
            "version should match CARGO_PKG_VERSION"
        );
    }

    #[test]
    fn test_render_json_metadata_elapsed_ms() {
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/a.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 123).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        assert_eq!(parsed["metadata"]["elapsed_ms"].as_u64().unwrap(), 123);
    }

    #[test]
    fn test_render_json_function_field_values() {
        let func = make_func("myFunc", 10, 3, 2, 88.0);
        let file = make_file("src/foo.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 45).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let func_obj = &parsed["files"][0]["functions"][0];
        assert_eq!(func_obj["name"].as_str().unwrap(), "myFunc");
        assert_eq!(func_obj["start_line"].as_u64().unwrap(), 10);
        assert_eq!(func_obj["cyclomatic"].as_u64().unwrap(), 3);
        assert_eq!(func_obj["cognitive"].as_u64().unwrap(), 2);
        assert_eq!(func_obj["line_count"].as_u64().unwrap(), 10);
        assert_eq!(func_obj["params_count"].as_u64().unwrap(), 2);
        assert_eq!(func_obj["nesting_depth"].as_u64().unwrap(), 1);
    }

    #[test]
    fn test_render_json_file_field_values() {
        let func = make_func("f", 1, 2, 1, 90.0);
        let file = make_file("src/foo.ts", vec![func]);
        let config = default_config();
        let json_str = render_json(&[file], None, &config, 10).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json_str).unwrap();

        let file_obj = &parsed["files"][0];
        assert_eq!(file_obj["path"].as_str().unwrap(), "src/foo.ts");
        assert_eq!(file_obj["file_length"].as_u64().unwrap(), 100);
        assert_eq!(file_obj["export_count"].as_u64().unwrap(), 3);
    }
}
