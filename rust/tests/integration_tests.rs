/// Integration tests for the complexity-guard binary.
///
/// Runs the compiled binary against fixture files and validates:
/// - JSON output matches committed baselines (behavioral parity with Zig v1.0)
/// - Exit codes 0, 1, 2, 3 all work correctly
/// - CLI flags (--format, --config, --threads, --duplication)
/// - SARIF structural requirements (tool.driver, results, locations)
/// - HTML is self-contained (no external URL references)
/// - Directory scan and deterministic ordering
///
/// Float tolerances:
/// - Halstead metrics: HALSTEAD_TOL = 1e-9
/// - Health scores: SCORE_TOL = 1e-6
use assert_cmd::Command;
use serde_json::Value;

const HALSTEAD_TOL: f64 = 1e-9;
const SCORE_TOL: f64 = 1e-6;

/// Construct an assert_cmd Command for the complexity-guard binary.
fn cargo_bin() -> Command {
    Command::cargo_bin("complexity-guard").unwrap()
}

/// Resolve path to a fixture file (relative to the top-level tests/fixtures/).
fn fixture_path(relative: &str) -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests")
        .join("fixtures")
        .join(relative)
}

/// Resolve path to a baseline JSON file in rust/tests/fixtures/baselines/.
fn baseline_path(name: &str) -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("baselines")
        .join(name)
}

/// Load a committed baseline JSON file.
fn load_baseline(name: &str) -> Value {
    let path = baseline_path(name);
    let content = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("failed to read baseline {}: {}", path.display(), e));
    serde_json::from_str(&content).unwrap_or_else(|e| panic!("failed to parse baseline {}: {}", name, e))
}

/// Run the binary with --format json --no-color against a fixture file.
///
/// Returns parsed JSON output. Panics if the binary fails or output is invalid JSON.
fn run_json(fixture: &str) -> Value {
    let output = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path(fixture))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    serde_json::from_str(&stdout)
        .unwrap_or_else(|e| panic!("failed to parse JSON output for {}: {}\nstdout: {}", fixture, e, stdout))
}

/// Assert two floats are equal within the given tolerance.
fn assert_float_eq(actual: f64, expected: f64, tol: f64, context: &str) {
    assert!(
        (actual - expected).abs() <= tol,
        "{}: actual={} expected={} diff={} tol={}",
        context,
        actual,
        expected,
        (actual - expected).abs(),
        tol
    );
}

/// Compare a single function's fields from JSON output against the baseline.
fn compare_function(actual_fn: &Value, baseline_fn: &Value, label: &str) {
    assert_eq!(
        actual_fn["name"], baseline_fn["name"],
        "{}: name mismatch", label
    );
    assert_eq!(
        actual_fn["start_line"], baseline_fn["start_line"],
        "{}: start_line mismatch", label
    );
    assert_eq!(
        actual_fn["start_col"], baseline_fn["start_col"],
        "{}: start_col mismatch", label
    );
    assert_eq!(
        actual_fn["cyclomatic"], baseline_fn["cyclomatic"],
        "{}: cyclomatic mismatch", label
    );
    assert_eq!(
        actual_fn["cognitive"], baseline_fn["cognitive"],
        "{}: cognitive mismatch", label
    );
    assert_eq!(
        actual_fn["nesting_depth"], baseline_fn["nesting_depth"],
        "{}: nesting_depth mismatch", label
    );
    assert_eq!(
        actual_fn["line_count"], baseline_fn["line_count"],
        "{}: line_count mismatch", label
    );
    assert_eq!(
        actual_fn["params_count"], baseline_fn["params_count"],
        "{}: params_count mismatch", label
    );
    assert_eq!(
        actual_fn["status"], baseline_fn["status"],
        "{}: status mismatch", label
    );

    // Float fields with tolerance
    let fields_halstead = ["halstead_volume", "halstead_difficulty", "halstead_effort", "halstead_bugs"];
    for field in &fields_halstead {
        let actual_val = actual_fn[field].as_f64().unwrap_or_else(|| panic!("{}: {} is not f64", label, field));
        let expected_val = baseline_fn[field].as_f64().unwrap_or_else(|| panic!("{}: baseline {} is not f64", label, field));
        assert_float_eq(actual_val, expected_val, HALSTEAD_TOL, &format!("{}.{}", label, field));
    }

    let actual_health = actual_fn["health_score"].as_f64().unwrap_or_else(|| panic!("{}: health_score is not f64", label));
    let expected_health = baseline_fn["health_score"].as_f64().unwrap_or_else(|| panic!("{}: baseline health_score is not f64", label));
    assert_float_eq(actual_health, expected_health, SCORE_TOL, &format!("{}.health_score", label));
}

/// Compare a fixture's full JSON output against a committed baseline.
///
/// Skips `timestamp` and `metadata.elapsed_ms` (non-deterministic).
/// Allows `version` to differ (Rust 0.8.0 vs baseline).
fn compare_fixture(fixture_relative: &str, baseline_name: &str) {
    let actual = run_json(fixture_relative);
    let baseline = load_baseline(baseline_name);

    // Summary fields
    assert_eq!(
        actual["summary"]["files_analyzed"], baseline["summary"]["files_analyzed"],
        "{}: summary.files_analyzed mismatch", baseline_name
    );
    assert_eq!(
        actual["summary"]["total_functions"], baseline["summary"]["total_functions"],
        "{}: summary.total_functions mismatch", baseline_name
    );
    assert_eq!(
        actual["summary"]["warnings"], baseline["summary"]["warnings"],
        "{}: summary.warnings mismatch", baseline_name
    );
    assert_eq!(
        actual["summary"]["errors"], baseline["summary"]["errors"],
        "{}: summary.errors mismatch", baseline_name
    );
    assert_eq!(
        actual["summary"]["status"], baseline["summary"]["status"],
        "{}: summary.status mismatch", baseline_name
    );

    let actual_health = actual["summary"]["health_score"].as_f64().unwrap();
    let expected_health = baseline["summary"]["health_score"].as_f64().unwrap();
    assert_float_eq(actual_health, expected_health, SCORE_TOL, &format!("{}: summary.health_score", baseline_name));

    // Per-function comparison for first file
    let actual_fns = actual["files"][0]["functions"].as_array().unwrap();
    let baseline_fns = baseline["files"][0]["functions"].as_array().unwrap();

    assert_eq!(
        actual_fns.len(), baseline_fns.len(),
        "{}: function count mismatch", baseline_name
    );

    for (i, (actual_fn, baseline_fn)) in actual_fns.iter().zip(baseline_fns.iter()).enumerate() {
        let label = format!("{}[{}]", baseline_name, i);
        compare_function(actual_fn, baseline_fn, &label);
    }
}

// ============================================================
// Task 1: Per-fixture JSON baseline comparison
// ============================================================

#[test]
fn test_baseline_simple_function() {
    compare_fixture("typescript/simple_function.ts", "simple_function.json");
}

#[test]
fn test_baseline_cognitive_cases() {
    compare_fixture("typescript/cognitive_cases.ts", "cognitive_cases.json");
}

#[test]
fn test_baseline_cyclomatic_cases() {
    compare_fixture("typescript/cyclomatic_cases.ts", "cyclomatic_cases.json");
}

#[test]
fn test_baseline_halstead_cases() {
    compare_fixture("typescript/halstead_cases.ts", "halstead_cases.json");
}

#[test]
fn test_baseline_structural_cases() {
    compare_fixture("typescript/structural_cases.ts", "structural_cases.json");
}

#[test]
fn test_baseline_async_patterns() {
    compare_fixture("typescript/async_patterns.ts", "async_patterns.json");
}

#[test]
fn test_baseline_class_with_methods() {
    compare_fixture("typescript/class_with_methods.ts", "class_with_methods.json");
}

#[test]
fn test_baseline_complex_nested() {
    compare_fixture("typescript/complex_nested.ts", "complex_nested.json");
}

#[test]
fn test_baseline_react_component() {
    compare_fixture("typescript/react_component.tsx", "react_component.json");
}

#[test]
fn test_baseline_express_middleware() {
    compare_fixture("javascript/express_middleware.js", "express_middleware.json");
}

#[test]
fn test_baseline_jsx_component() {
    compare_fixture("javascript/jsx_component.jsx", "jsx_component.json");
}

#[test]
fn test_baseline_callback_patterns() {
    compare_fixture("javascript/callback_patterns.js", "callback_patterns.json");
}

// ============================================================
// Task 2: Cognitive deviation pinning (METR-02)
// ============================================================

/// Pinned regression: fetchUserData in async_patterns.ts must have cognitive=15.
///
/// This was a confirmed bug in earlier Rust (returned 18 instead of 15).
/// Fixed in Phase 21-01 via visit_node_cognitive() scope boundary semantics.
#[test]
fn test_cognitive_async_patterns_fetchuserdata_is_15() {
    let actual = run_json("typescript/async_patterns.ts");
    let fns = actual["files"][0]["functions"].as_array().unwrap();
    let fetch = fns
        .iter()
        .find(|f| f["name"] == "fetchUserData")
        .expect("should find fetchUserData function");
    assert_eq!(
        fetch["cognitive"].as_u64().unwrap(),
        15,
        "fetchUserData cognitive complexity must be 15 (Zig v1.0 baseline)"
    );
}

// ============================================================
// Task 3: Exit code parity (OUT-05)
// ============================================================

#[test]
fn test_exit_code_0_clean_file() {
    cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .assert()
        .success();
}

#[test]
fn test_exit_code_1_errors_present() {
    // complex_nested.ts has errors — should exit 1
    cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/complex_nested.ts"))
        .assert()
        .code(1);
}

#[test]
fn test_exit_code_2_warnings_with_fail_on_warning() {
    // cognitive_cases.ts has warnings; --fail-on warning → exit 2
    cargo_bin()
        .args(["--format", "json", "--no-color", "--fail-on", "warning"])
        .arg(fixture_path("typescript/cognitive_cases.ts"))
        .assert()
        .code(2);
}

#[test]
fn test_exit_code_3_bad_config_path() {
    // Non-existent config file → exit 3
    cargo_bin()
        .args(["--config", "/nonexistent/path.json"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .assert()
        .code(3);
}

/// Exit code 4 (ParseError) is unreachable by design — documented here via behavioral test.
///
/// tree-sitter is error-tolerant: it recovers from all syntax errors and returns a partial AST
/// rather than failing. Even binary content written to a `.ts` file parses successfully,
/// producing zero functions and exit 0 (not exit 4).
///
/// Both Zig v1.0 and Rust v0.8 produce identical behavior for this scenario:
/// - File discovery filters by extension so unsupported file types never reach analysis.
/// - For supported extensions (.ts/.tsx/.js/.jsx), tree-sitter never returns a parse failure;
///   it always produces a (possibly empty) AST.
/// - `determine_exit_code` checks `has_parse_errors` but this flag is never true in the
///   normal discovery + analysis pipeline.
///
/// This test documents behavioral parity between the two implementations, not a missing feature.
#[test]
fn test_exit_code_4_unreachable_tree_sitter_error_tolerant() {
    use std::io::Write;
    // Create a temporary .ts file containing binary content (definitely not valid TypeScript).
    let mut tmp = tempfile::Builder::new()
        .suffix(".ts")
        .tempfile()
        .expect("should create tempfile");
    tmp.write_all(b"\x00\x01\x02\xff\xfe\xfd")
        .expect("should write binary content");
    tmp.flush().expect("should flush");

    // Binary content in a .ts file must exit 0 (not 4): tree-sitter parses it as zero functions.
    cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(tmp.path())
        .assert()
        .success();
}

// ============================================================
// Task 4: CLI flags (CLI-01, CLI-02, CLI-03)
// ============================================================

#[test]
fn test_format_json_flag() {
    let output = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).expect("--format json should produce valid JSON");
    assert!(parsed["version"].is_string(), "JSON output should have version field");
    assert!(parsed["summary"].is_object(), "JSON output should have summary field");
    assert!(parsed["files"].is_array(), "JSON output should have files array");
}

#[test]
fn test_format_sarif_flag() {
    let output = cargo_bin()
        .args(["--format", "sarif", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).expect("--format sarif should produce valid JSON");
    assert!(
        parsed["$schema"].as_str().unwrap_or("").contains("sarif"),
        "SARIF output should have $schema containing 'sarif'"
    );
    assert_eq!(parsed["version"], "2.1.0", "SARIF version should be 2.1.0");
}

#[test]
fn test_format_html_flag() {
    let output = cargo_bin()
        .args(["--format", "html", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(
        stdout.contains("<!DOCTYPE html>"),
        "--format html should produce HTML starting with <!DOCTYPE html>"
    );
}

#[test]
fn test_config_file_loading_lowers_threshold() {
    // Config with cyclomatic warning=5 (lower than default 10)
    // cyclomatic_cases.ts has only 1 warning at default threshold=10
    // but 4 warnings at threshold=5
    let dir = tempfile::tempdir().unwrap();
    let config_path = dir.path().join(".complexityguard.json");
    std::fs::write(
        &config_path,
        r#"{"analysis":{"thresholds":{"cyclomatic":{"warning":5}}}}"#,
    )
    .unwrap();

    let output_low = cargo_bin()
        .args(["--format", "json", "--no-color", "--config"])
        .arg(&config_path)
        .arg(fixture_path("typescript/cyclomatic_cases.ts"))
        .output()
        .unwrap();
    let low_json: Value = serde_json::from_str(&String::from_utf8(output_low.stdout).unwrap()).unwrap();
    let warnings_low = low_json["summary"]["warnings"].as_u64().unwrap();

    let output_default = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/cyclomatic_cases.ts"))
        .output()
        .unwrap();
    let default_json: Value = serde_json::from_str(&String::from_utf8(output_default.stdout).unwrap()).unwrap();
    let warnings_default = default_json["summary"]["warnings"].as_u64().unwrap();

    assert!(
        warnings_low > warnings_default,
        "Lower cyclomatic threshold (5) should produce more warnings ({}) than default threshold ({}).",
        warnings_low,
        warnings_default
    );
}

#[test]
fn test_cli_format_overrides_config_format() {
    // Config sets format=json; --format sarif on CLI should take precedence
    let dir = tempfile::tempdir().unwrap();
    let config_path = dir.path().join(".complexityguard.json");
    std::fs::write(&config_path, r#"{"output":{"format":"json"}}"#).unwrap();

    let output = cargo_bin()
        .args(["--format", "sarif", "--no-color", "--config"])
        .arg(&config_path)
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).expect("CLI --format sarif should override config format=json");
    assert!(
        parsed["$schema"].as_str().unwrap_or("").contains("sarif"),
        "CLI --format sarif must override config format=json, got $schema: {:?}",
        parsed["$schema"]
    );
}

// ============================================================
// Task 5: SARIF structure (OUT-03)
// ============================================================

#[test]
fn test_sarif_structure() {
    let output = cargo_bin()
        .args(["--format", "sarif", "--no-color"])
        .arg(fixture_path("typescript/complex_nested.ts"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let sarif: Value = serde_json::from_str(&stdout).expect("SARIF should be valid JSON");

    // Top-level fields
    assert!(
        sarif["$schema"].as_str().unwrap_or("").contains("sarif"),
        "SARIF $schema should contain 'sarif'"
    );
    assert_eq!(sarif["version"], "2.1.0", "SARIF version must be 2.1.0");
    assert!(sarif["runs"].is_array(), "SARIF should have runs array");

    // tool.driver
    let driver = &sarif["runs"][0]["tool"]["driver"];
    assert!(driver.is_object(), "runs[0].tool.driver must be an object");
    assert_eq!(driver["name"], "ComplexityGuard", "tool.driver.name must be 'ComplexityGuard'");
    assert!(driver["version"].is_string(), "tool.driver.version must be a string");

    // results array
    let results = sarif["runs"][0]["results"].as_array().expect("runs[0].results must be an array");
    assert!(!results.is_empty(), "complex_nested.ts should produce at least one SARIF result");

    // Each result has required fields
    for (i, result) in results.iter().enumerate() {
        assert!(
            result["ruleId"].is_string(),
            "result[{}].ruleId must be a string, got: {:?}",
            i,
            result["ruleId"]
        );
        assert!(
            result["level"].is_string(),
            "result[{}].level must be a string",
            i
        );
        assert!(
            result["message"]["text"].is_string(),
            "result[{}].message.text must be a string",
            i
        );
        let locations = result["locations"].as_array().expect(&format!("result[{}].locations must be array", i));
        assert!(!locations.is_empty(), "result[{}].locations must not be empty", i);
        assert!(
            locations[0]["physicalLocation"]["artifactLocation"]["uri"].is_string(),
            "result[{}].locations[0].physicalLocation.artifactLocation.uri must exist",
            i
        );
    }
}

// ============================================================
// Task 6: HTML self-contained (OUT-04)
// ============================================================

#[test]
fn test_html_no_external_urls() {
    let output = cargo_bin()
        .args(["--format", "html", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    let html = String::from_utf8(output.stdout).unwrap();

    // HTML must not reference external resources
    assert!(
        !html.contains("https://"),
        "HTML output should not reference external https:// URLs (must be self-contained)"
    );
    assert!(
        !html.contains("http://"),
        "HTML output should not reference external http:// URLs (must be self-contained)"
    );
    assert!(
        html.contains("<!DOCTYPE html>"),
        "HTML output must start with <!DOCTYPE html>"
    );
}

// ============================================================
// Task 7: Pipeline (PIPE-01, PIPE-02, PIPE-03)
// ============================================================

#[test]
fn test_directory_scan_multiple_files() {
    // Scan the entire typescript fixtures directory — should analyze multiple files
    let output = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).expect("directory scan should produce valid JSON");

    let files_analyzed = parsed["summary"]["files_analyzed"].as_u64().unwrap();
    assert!(
        files_analyzed > 1,
        "directory scan should analyze multiple files, got {}",
        files_analyzed
    );

    let files = parsed["files"].as_array().unwrap();
    assert_eq!(
        files.len() as u64,
        files_analyzed,
        "files array length should match files_analyzed"
    );
}

#[test]
fn test_deterministic_ordering_across_runs() {
    // Run twice on the same directory and verify file ordering is identical
    let run1 = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript"))
        .output()
        .unwrap();
    let run2 = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript"))
        .output()
        .unwrap();

    let json1: Value = serde_json::from_str(&String::from_utf8(run1.stdout).unwrap()).unwrap();
    let json2: Value = serde_json::from_str(&String::from_utf8(run2.stdout).unwrap()).unwrap();

    let paths1: Vec<&str> = json1["files"]
        .as_array()
        .unwrap()
        .iter()
        .map(|f| f["path"].as_str().unwrap())
        .collect();
    let paths2: Vec<&str> = json2["files"]
        .as_array()
        .unwrap()
        .iter()
        .map(|f| f["path"].as_str().unwrap())
        .collect();

    assert_eq!(
        paths1, paths2,
        "File ordering must be deterministic across runs"
    );
}

#[test]
fn test_threads_flag_produces_correct_results() {
    // --threads 1 should produce the same results as default
    let output_threads1 = cargo_bin()
        .args(["--format", "json", "--no-color", "--threads", "1"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    assert!(
        output_threads1.status.success(),
        "--threads 1 should succeed"
    );
    let json1: Value = serde_json::from_str(&String::from_utf8(output_threads1.stdout).unwrap()).unwrap();

    let output_default = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    let json_default: Value = serde_json::from_str(&String::from_utf8(output_default.stdout).unwrap()).unwrap();

    assert_eq!(
        json1["summary"]["total_functions"],
        json_default["summary"]["total_functions"],
        "--threads 1 should count same total_functions as default"
    );
    assert_eq!(
        json1["files"][0]["functions"][0]["cyclomatic"],
        json_default["files"][0]["functions"][0]["cyclomatic"],
        "--threads 1 cyclomatic should match default"
    );
}

// ============================================================
// Task 8: Duplication flag (METR-05)
// ============================================================

#[test]
fn test_duplication_flag_enables_analysis() {
    // --duplication on a directory should produce non-null duplication with enabled:true
    let output = cargo_bin()
        .args(["--format", "json", "--no-color", "--duplication"])
        .arg(fixture_path("typescript"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).expect("duplication scan should produce valid JSON");

    assert!(
        !parsed["duplication"].is_null(),
        "duplication field should not be null when --duplication flag is passed"
    );
    assert_eq!(
        parsed["duplication"]["enabled"], true,
        "duplication.enabled should be true when --duplication flag is passed"
    );
    assert!(
        parsed["duplication"]["project_duplication_pct"].is_number(),
        "duplication.project_duplication_pct should be a number"
    );
    assert!(
        parsed["duplication"]["clone_groups"].is_array(),
        "duplication.clone_groups should be an array"
    );
}

#[test]
fn test_no_duplication_flag_default() {
    // Without --duplication flag, duplication field should be null
    let output = cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .output()
        .unwrap();
    let stdout = String::from_utf8(output.stdout).unwrap();
    let parsed: Value = serde_json::from_str(&stdout).unwrap();

    assert!(
        parsed["duplication"].is_null(),
        "duplication should be null when --duplication flag is not passed, got: {:?}",
        parsed["duplication"]
    );
}
