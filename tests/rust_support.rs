use std::path::{Path, PathBuf};

use complexity_guard::{metrics, parser, pipeline, types::AnalysisConfig};
use serde_json::Value;

fn fixture() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/rust/representative.rs")
}

fn run_json(path: &Path, config: Option<&Path>) -> Value {
    let mut cmd = std::process::Command::new(env!("CARGO_BIN_EXE_complexity-guard"));
    cmd.args(["--format", "json", "--no-color"]);
    if let Some(config) = config {
        cmd.arg("--config").arg(config);
    }
    let output = cmd.arg(path).output().unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    serde_json::from_slice(&output.stdout).unwrap()
}

#[test]
fn rust_functions_and_branches_have_expected_metrics() {
    let data = run_json(&fixture(), None);
    let functions = data["files"][0]["functions"].as_array().unwrap();
    assert_eq!(functions.len(), 8);
    assert_eq!(data["files"][0]["language"], "rust");
    assert_eq!(data["files"][0]["export_count"], 2);

    let get = |name: &str| functions.iter().find(|f| f["name"] == name).unwrap();
    assert_eq!(get("classify")["cyclomatic"], 5); // let-else, two match branches, guard
    assert_eq!(get("Counter::tick")["cyclomatic"], 3); // if and &&
    assert_eq!(get("Counter::tick")["params_count"], 1); // self is excluded
    assert_eq!(get("propagate")["cyclomatic"], 1); // idiomatic ? is not a decision
    assert_eq!(get("with_closure")["cyclomatic"], 1); // closure has its own boundary
    assert_eq!(get("with_closure::double")["params_count"], 1);
    assert_eq!(get("Counter::required")["cyclomatic"], 1);
    assert!(functions.iter().all(|f| f["name"] != "Reset::required"));
    assert!(functions.iter().any(|f| f["name"] == "conditional")); // cfg is source-level
}

#[test]
fn parser_and_analysis_use_the_same_rust_function_inventory() {
    let parsed = parser::parse_file(&fixture()).unwrap();
    let (analyzed, _) = metrics::analyze_file(&fixture(), &AnalysisConfig::default()).unwrap();
    let names: Vec<_> = parsed.functions.iter().map(|f| f.name.as_str()).collect();
    let analyzed_names: Vec<_> = analyzed.functions.iter().map(|f| f.name.as_str()).collect();
    assert_eq!(names, analyzed_names);
}

#[test]
fn mixed_project_respects_gitignore_and_target() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join(".git")).unwrap();
    std::fs::create_dir(dir.path().join("src")).unwrap();
    std::fs::create_dir(dir.path().join("target")).unwrap();
    std::fs::write(dir.path().join(".gitignore"), "src/ignored.rs\n").unwrap();
    std::fs::write(dir.path().join("src/lib.rs"), "fn rust_fn() {}\n").unwrap();
    std::fs::write(dir.path().join("src/app.ts"), "function tsFn() {}\n").unwrap();
    std::fs::write(dir.path().join("src/ignored.rs"), "fn ignored() {}\n").unwrap();
    std::fs::write(
        dir.path().join("target/generated.rs"),
        "fn generated() {}\n",
    )
    .unwrap();

    let files = pipeline::discover_files(&[dir.path().to_path_buf()], &[], &[]).unwrap();
    let names: Vec<_> = files
        .iter()
        .map(|p| p.file_name().unwrap().to_str().unwrap())
        .collect();
    assert_eq!(names.len(), 2);
    assert!(names.contains(&"lib.rs"));
    assert!(names.contains(&"app.ts"));
}

#[test]
fn explicit_thresholds_override_rust_defaults() {
    let dir = tempfile::tempdir().unwrap();
    let config = dir.path().join("config.json");
    std::fs::write(&config, r#"{"analysis":{"thresholds":{"cyclomatic":{"warning":3,"error":20},"params_count":{"warning":1,"error":10}}}}"#).unwrap();
    let data = run_json(&fixture(), Some(&config));
    let functions = data["files"][0]["functions"].as_array().unwrap();
    let tick = functions
        .iter()
        .find(|f| f["name"] == "Counter::tick")
        .unwrap();
    assert_eq!(tick["status"], "warning");
}

#[test]
fn rust_sarif_reports_a_source_location() {
    let dir = tempfile::tempdir().unwrap();
    let config = dir.path().join("config.json");
    std::fs::write(
        &config,
        r#"{"analysis":{"thresholds":{"cyclomatic":{"warning":3,"error":20}}}}"#,
    )
    .unwrap();
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_complexity-guard"))
        .args(["--format", "sarif", "--config"])
        .arg(config)
        .arg(fixture())
        .output()
        .unwrap();
    assert!(output.status.success());
    let data: Value = serde_json::from_slice(&output.stdout).unwrap();
    let results = data["runs"][0]["results"].as_array().unwrap();
    let result = results
        .iter()
        .find(|item| item["ruleId"] == "complexity-guard/cyclomatic")
        .unwrap();
    assert_eq!(
        result["locations"][0]["physicalLocation"]["region"]["startLine"],
        1
    );
}

#[test]
fn rust_parameter_warning_starts_above_clippy_maximum() {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("params.rs");
    std::fs::write(
        &source,
        "fn seven(a:i32,b:i32,c:i32,d:i32,e:i32,f:i32,g:i32) {}\n\
         fn eight(a:i32,b:i32,c:i32,d:i32,e:i32,f:i32,g:i32,h:i32) {}\n",
    )
    .unwrap();
    let data = run_json(&source, None);
    let functions = data["files"][0]["functions"].as_array().unwrap();
    assert_eq!(functions[0]["params_count"], 7);
    assert_eq!(functions[0]["status"], "ok");
    assert_eq!(functions[1]["params_count"], 8);
    assert_eq!(functions[1]["status"], "warning");
}

#[test]
fn rust_control_flow_forms_are_counted_without_macro_expansion() {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("flow.rs");
    std::fs::write(
        &source,
        r#"
macro_rules! generated { () => { fn hidden() { if true {} } } }
generated!();
fn flow(mut values: Vec<i32>) {
    if let Some(_value) = values.pop() {}
    while let Some(_value) = values.pop() {}
    for _value in &values {}
    loop { break; }
    let Some(value) = values.pop() else { return; };
    match value { 0 => (), _ => () }
}
"#,
    )
    .unwrap();
    let data = run_json(&source, None);
    let functions = data["files"][0]["functions"].as_array().unwrap();
    assert_eq!(functions.len(), 1);
    assert_eq!(functions[0]["name"], "flow");
    assert_eq!(functions[0]["cyclomatic"], 7);
}
