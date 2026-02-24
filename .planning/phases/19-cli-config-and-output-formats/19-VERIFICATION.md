---
phase: 19-cli-config-and-output-formats
verified: 2026-02-24T19:10:00Z
status: gaps_found
score: 6/7 must-haves verified
re_verification: false
gaps:
  - truth: "REQUIREMENTS.md checkboxes and status table reflect OUT-03/OUT-04 completion"
    status: failed
    reason: "REQUIREMENTS.md marks OUT-03 and OUT-04 as [ ] (unchecked) and 'Pending' in the status table, despite both being fully implemented in plan 03. The ROADMAP.md also shows 19-04-PLAN.md as [ ] (incomplete) despite the summary existing. These are documentation gaps, not implementation gaps."
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "OUT-03 and OUT-04 checkboxes remain [ ] instead of [x]; status table shows 'Pending' instead of 'Complete'"
      - path: ".planning/ROADMAP.md"
        issue: "19-04-PLAN.md listed as [ ] (incomplete) despite 19-04-SUMMARY.md confirming completion"
    missing:
      - "Update REQUIREMENTS.md: change '- [ ] **OUT-03**' to '- [x] **OUT-03**'"
      - "Update REQUIREMENTS.md: change '- [ ] **OUT-04**' to '- [x] **OUT-04**'"
      - "Update REQUIREMENTS.md status table: OUT-03 from 'Pending' to 'Complete', OUT-04 from 'Pending' to 'Complete'"
      - "Update ROADMAP.md: change '- [ ] 19-04-PLAN.md' to '- [x] 19-04-PLAN.md'"
human_verification:
  - test: "Run the binary against a real TypeScript file and compare console output format to Zig binary"
    expected: "Same ESLint-style column layout, same severity labels (warning/error), same per-function sections"
    why_human: "Output format visual comparison requires looking at actual results against known Zig output for a real file"
  - test: "Upload SARIF output from --format sarif to a GitHub Code Scanning job"
    expected: "GitHub Code Scanning accepts the file without schema validation errors"
    why_human: "Requires a GitHub repository with Code Scanning enabled; cannot test externally without that environment"
---

# Phase 19: CLI, Config, and Output Formats — Verification Report

**Phase Goal:** The binary exposes an identical CLI interface to the Zig version, loads `.complexityguard.json` with CLI flags overriding config values, and produces all four output formats (console, JSON, SARIF 2.1.0, HTML) that match or are accepted by their respective consumers.
**Verified:** 2026-02-24T19:10:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All CLI flags from Zig binary exist with identical names; `--help` shows all options | VERIFIED | `cargo run -- --help` shows 17 named flags + positional paths, matching `CliArgs` struct in Zig args.zig exactly |
| 2 | `.complexityguard.json` config file is loaded; CLI flags override its values when both present | VERIFIED | `cargo run -- -c /tmp/test.json --format sarif` with config specifying `json` produces SARIF output (CLI wins) |
| 3 | Console output matches Zig ESLint-style format | VERIFIED | `render_console` produces `{line}:{col}  {level}  {message}  {rule-id}` format with file path header and summary line; 16 unit tests pass |
| 4 | JSON output matches Zig schema exactly — same field names, nesting structure | VERIFIED | `render_json` uses same snake_case field names as Zig (version, timestamp, summary, files, metadata, duplication); 12 tests verify all fields |
| 5 | SARIF 2.1.0 output is accepted by GitHub Code Scanning | VERIFIED (code) / UNCERTAIN (runtime) | All structural requirements met: correct schema URL, version 2.1.0, 11 rules, camelCase fields (ruleId, startLine, physicalLocation, etc.); human test needed for actual GitHub upload |
| 6 | HTML report is self-contained (no external requests), same embedded JS/CSS | VERIFIED | `render_html` uses `include_str!` for CSS/JS assets; runtime check confirms `<style>` and `<script>` present, no `<link rel=stylesheet>` or `<script src=` in output |
| 7 | REQUIREMENTS.md OUT-03/OUT-04 status reflects completion | FAILED | REQUIREMENTS.md shows `[ ]` and `Pending` for OUT-03 and OUT-04; ROADMAP.md shows `19-04-PLAN.md` as `[ ]` |

**Score:** 6/7 truths verified (1 documentation gap)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `rust/src/cli/args.rs` | clap derive Args struct with all CLI flags | VERIFIED | `#[derive(Parser)]` struct with 17 named flags + positional paths |
| `rust/src/cli/config.rs` | Config struct with serde Deserialize and defaults | VERIFIED | `pub struct Config` + `ResolvedConfig` + `config_defaults()` + `resolve_config()` |
| `rust/src/cli/merge.rs` | merge_args_into_config function | VERIFIED | `pub fn merge_args_into_config` with 12 unit tests covering format, threads, include/exclude, metrics |
| `rust/src/cli/discovery.rs` | Config file auto-discovery with upward search | VERIFIED | `pub fn discover_config` searches upward from CWD stopping at `.git` boundary |
| `rust/src/output/exit_codes.rs` | determine_exit_code with 0-4 semantics | VERIFIED | `pub fn determine_exit_code` with priority: ParseError(4) > baseline/errors(1) > warnings(2) > Success(0) |
| `rust/src/output/console.rs` | ESLint-style colored console output renderer | VERIFIED | `pub fn render_console` with color detection, quiet/verbose modes, violation formatting |
| `rust/src/output/json_output.rs` | JSON output with exact Zig schema field names | VERIFIED | `pub fn render_json` with `JsonOutput`, `JsonSummary`, `JsonFileOutput`, `JsonFunctionOutput` structs |
| `rust/src/output/sarif_output.rs` | SARIF 2.1.0 output with hand-rolled structs | VERIFIED | `pub fn render_sarif` with 11 rules, camelCase field renames, correct schema URL |
| `rust/src/output/html_output.rs` | Self-contained HTML report renderer | VERIFIED | `pub fn render_html` with `include_str!` asset embedding via minijinja |
| `rust/src/output/assets/report.css` | Embedded CSS for HTML report | VERIFIED | 220-line CSS extracted from Zig html_output.zig |
| `rust/src/output/assets/report.js` | Embedded JS for HTML report | VERIFIED | 35-line JS with `sortTable` function |
| `rust/src/output/assets/report.html` | HTML template for minijinja rendering | VERIFIED | 152-line minijinja template with `{% if duplication %}` conditional |
| `.planning/REQUIREMENTS.md` | OUT-03/OUT-04 marked complete | FAILED | Both remain `[ ]` and `Pending` despite implementation existing |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `rust/src/main.rs` | `rust/src/cli/args.rs` | `Args::parse()` | WIRED | Line 6: `let args = Args::parse()` |
| `rust/src/main.rs` | `rust/src/cli/merge.rs` | `merge_args_into_config` | WIRED | Line 67: `merge_args_into_config(&args, &mut config)` |
| `rust/src/cli/discovery.rs` | `rust/src/cli/config.rs` | `serde_json::from_str` | WIRED | `load_config_file` calls `serde_json::from_str::<Config>` |
| `rust/src/output/console.rs` | `rust/src/types.rs` | reads `FileAnalysisResult` | WIRED | `function_violations(func: &FunctionAnalysisResult, config)` |
| `rust/src/output/json_output.rs` | `rust/src/types.rs` | serializes via `serde_json::to_string_pretty` | WIRED | Converts `FileAnalysisResult` slices to `JsonOutput` |
| `rust/src/output/mod.rs` | `rust/src/output/console.rs` | `render_console` re-export | WIRED | `pub use console::render_console` |
| `rust/src/output/sarif_output.rs` | `rust/src/types.rs` | converts `FileAnalysisResult` to SARIF results | WIRED | Iterates `files: &[FileAnalysisResult]` |
| `rust/src/output/html_output.rs` | `rust/src/output/assets/` | `include_str!` embedding | WIRED | `const CSS: &str = include_str!("assets/report.css")` etc. |
| `rust/src/output/mod.rs` | `rust/src/output/sarif_output.rs` | format dispatch `render_sarif` | WIRED | `pub use sarif_output::render_sarif` |
| `rust/src/main.rs` | all four renderers | `match resolved.format.as_str()` dispatch | WIRED | Lines 97-125: `"json"` / `"sarif"` / `"html"` / `_` (console) dispatch |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CLI-01 | 19-01, 19-04 | Same CLI flags as Zig binary | SATISFIED | `rust/src/cli/args.rs` has all flags matching Zig `CliArgs` struct; `--help` confirmed working |
| CLI-02 | 19-01 | `.complexityguard.json` config loading with same schema | SATISFIED | `discover_config` + `load_config_file` + `serde_json::from_str::<Config>` working |
| CLI-03 | 19-01 | CLI flags override config file values | SATISFIED | `merge_args_into_config` applies CLI args after config load; runtime test confirmed |
| OUT-01 | 19-02, 19-04 | Console output matches Zig ESLint-style format | SATISFIED | `render_console` produces matching format; 16 unit tests pass |
| OUT-02 | 19-02 | JSON output matches Zig schema (field names, structure) | SATISFIED | All snake_case field names match Zig exactly; 12 unit tests pass including field name validation |
| OUT-03 | 19-03 | SARIF 2.1.0 output accepted by GitHub Code Scanning | SATISFIED (code) | Schema URL, version 2.1.0, 11 rules, camelCase fields, `runs`/`results` structure all correct; human test needed for actual GH upload |
| OUT-04 | 19-03 | HTML report is self-contained with same embedded JS/CSS | SATISFIED | `include_str!` assets, no external URLs, 9 unit tests pass |
| OUT-05 | 19-01 | Exit codes 0-4 match Zig semantics | SATISFIED | `determine_exit_code` with correct priority chain; 13 unit tests including `fail_on none` override |

**Orphaned requirements check:** None — all 8 requirement IDs claimed by plans are accounted for.

**REQUIREMENTS.md discrepancy (not a code gap):** OUT-03 and OUT-04 are marked `[ ]` (pending) in the REQUIREMENTS.md checkbox list and status table, despite both being fully implemented. This is a documentation-only issue — the code is correct and tested. ROADMAP.md also shows `19-04-PLAN.md` as `[ ]` despite the summary confirming completion.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `rust/src/main.rs` | 90-92 | `let files: Vec<...> = vec![]` (no actual analysis) | Info | Intentional — Phase 20 adds real file analysis; renderers are complete and testable |
| `rust/src/main.rs` | 10 | `println!("Interactive config setup not yet implemented in v0.8.")` | Info | Intentional stub for `--init`; documented scope exclusion |

No blockers or warnings. Both anti-patterns are explicitly scoped and documented as Phase 20 work.

### Human Verification Required

#### 1. Console output visual parity against Zig binary

**Test:** Run both binaries against the same TypeScript fixture file (`tests/fixtures/express-middleware.ts`) and compare output line by line.
**Expected:** Same file path header, same `{line}:{col}  {level}  {message}  {rule-id}` format, same summary line format.
**Why human:** Requires running both binaries against a real file with real analysis results (Phase 20 not yet wired). Currently the binary analyzes 0 files.

#### 2. SARIF acceptance by GitHub Code Scanning

**Test:** Create a GitHub Actions workflow that uploads the SARIF output file to GitHub Code Scanning via `github/codeql-action/upload-sarif`.
**Expected:** No schema validation errors; violations appear as Code Scanning alerts in the GitHub UI.
**Why human:** Requires a GitHub repository with Code Scanning enabled. The SARIF structure is correct per code review, but runtime validation requires the GH environment.

### Gaps Summary

One gap found: REQUIREMENTS.md was not updated after Plan 03 completed. The checkboxes for OUT-03 and OUT-04 remain `[ ]` (should be `[x]`) and the status table still shows `Pending` (should be `Complete`) for both. The ROADMAP.md `19-04-PLAN.md` entry also remains `[ ]` despite the 19-04-SUMMARY.md confirming completion on 2026-02-24.

This is a pure documentation gap. All eight requirements are implemented in code, all 181 tests pass (173 lib + 8 integration), and the binary produces all four output formats correctly.

The fix is four targeted line edits in REQUIREMENTS.md and one line edit in ROADMAP.md — no code changes needed.

---
_Verified: 2026-02-24T19:10:00Z_
_Verifier: Claude (gsd-verifier)_
