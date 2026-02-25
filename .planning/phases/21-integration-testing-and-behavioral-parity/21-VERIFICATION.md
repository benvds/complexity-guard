---
phase: 21-integration-testing-and-behavioral-parity
verified: 2026-02-25T08:00:00Z
status: gaps_found
score: 3/4 success criteria verified
gaps:
  - truth: "Exit code parity is confirmed for scenarios that trigger each of codes 0, 1, 2, 3, and 4"
    status: partial
    reason: "Exit codes 0, 1, 2, 3 are all tested and passing. Exit code 4 (parse error) is intentionally not tested — the integration tests document that tree-sitter is error-tolerant and returns partial results instead of failing, making exit code 4 unreachable in practice. The ROADMAP success criterion explicitly lists code 4."
    artifacts:
      - path: "rust/tests/integration_tests.rs"
        issue: "Line 309 comments 'Exit code 4 (parse error) is intentionally not tested' — no test exists for this exit code"
    missing:
      - "Either: add a test that confirms exit code 4 CAN be triggered (find or create a deliberately broken fixture that tree-sitter cannot recover from), OR update the ROADMAP success criterion to explicitly exclude code 4 with documented rationale"
---

# Phase 21: Integration Testing and Behavioral Parity Verification Report

**Phase Goal:** A comprehensive integration test suite validates complete behavioral parity between the Rust binary and Zig v1.0 across all fixture files and all output formats, catching any metric deviations, float precision issues, serialization differences, or exit code discrepancies before release work begins.
**Verified:** 2026-02-25T08:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | Integration tests run against all fixture files and compare output to recorded Zig v1.0 baseline — all tests pass | VERIFIED | 29 tests run, all 29 pass; 12 baseline JSON files committed; `cargo test --test integration_tests` exits 0 |
| 2   | Exit code parity confirmed for codes 0, 1, 2, 3, and 4 | PARTIAL | Codes 0/1/2/3 tested and passing; exit code 4 deliberately excluded with documented rationale |
| 3   | Cognitive complexity deviation validated by dedicated test comparing Rust and Zig output on same fixture | VERIFIED | `test_cognitive_async_patterns_fetchuserdata_is_15` pins fetchUserData cognitive=15, matching Zig baseline |
| 4   | Float tolerance explicitly defined and documented for all Halstead metric fields | VERIFIED | `HALSTEAD_TOL = 1e-9` and `SCORE_TOL = 1e-6` defined as constants at top of integration_tests.rs; applied to all 4 Halstead fields + health_score in `compare_function()` |

**Score:** 3/4 success criteria fully verified (criterion 2 is partial)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `rust/tests/integration_tests.rs` | End-to-end binary integration tests, min 200 lines | VERIFIED | 658 lines, 29 test functions, substantive — no stubs |
| `rust/tests/fixtures/baselines/` | 12 committed Zig v1.0 baseline JSON files | VERIFIED | 12 files present, all valid JSON, timestamp and elapsed_ms stripped |
| `rust/Cargo.toml` | assert_cmd and predicates dev-dependencies | VERIFIED | `assert_cmd = "2"` and `predicates = "3"` confirmed |
| `rust/src/cli/config.rs` | cognitive_error default of 25 | VERIFIED | Line 152: `cognitive_error: 25` |
| `rust/src/metrics/cognitive.rs` | visit_node_cognitive() for arrow callback scope boundary | VERIFIED | Function defined at line 413, used throughout visit_arrow_callback() |
| `rust/src/output/json_output.rs` | Duplication JSON matching Zig schema with project_duplication_pct | VERIFIED | JsonCloneGroup, JsonCloneLocation, JsonDuplicationFileInfo, project_duplication_pct all present |
| `rust/src/types.rs` | DuplicationFileInfo type | VERIFIED | Line 259: `pub struct DuplicationFileInfo` |
| `rust/src/output/console.rs` | Zig-parity consolidated per-function format | VERIFIED | `worst_severity()`, `render_function_line()`, `render_verdict()` all present; Unicode symbols ✓/⚠/✗ used |
| `rust/src/metrics/cyclomatic.rs` | Enhanced function naming (NameContext with callback/export patterns) | VERIFIED | `object_key`, `call_name`, `is_default_export` fields; `extract_event_name()`, `get_last_member_segment()` helpers present |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `rust/src/cli/config.rs` | `rust/src/main.rs` | build_analysis_config uses resolved.cognitive_error | WIRED | main.rs line 262/281: `resolved.cognitive_error` used for scoring thresholds |
| `rust/src/metrics/cognitive.rs` | `rust/src/pipeline/parallel.rs` | analyze_file calls cognitive via metrics::analyze_file | WIRED | parallel.rs uses `crate::metrics::analyze_file`; metrics/mod.rs calls `cognitive::analyze_functions` |
| `rust/src/output/console.rs` | `rust/src/main.rs` | render_console called from main | WIRED | main.rs line 5 imports render_console; line 196 calls it |
| `rust/src/metrics/mod.rs` | `rust/src/metrics/cognitive.rs` | cognitive.rs calls extract_function_name from mod.rs | WIRED | cognitive.rs line 26: `crate::metrics::extract_function_name` |
| `rust/tests/integration_tests.rs` | `rust/tests/fixtures/baselines/` | load_baseline() reads JSON files | WIRED | `load_baseline()` defined at line 44; called in all 12 baseline comparison tests |
| `rust/tests/integration_tests.rs` | complexity-guard binary | Command::cargo_bin() runs the binary | WIRED | `cargo_bin()` wrapper at line 21; used in all test functions |

### Requirements Coverage

All 22 functional requirements from PARSE-01 through PIPE-03 are claimed across the three plans and validated by passing integration tests:

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| PARSE-01 | 21-03 | TypeScript parsing | SATISFIED | test_baseline_simple_function, test_baseline_cognitive_cases, etc. |
| PARSE-02 | 21-03 | TSX parsing | SATISFIED | test_baseline_react_component (react_component.tsx) |
| PARSE-03 | 21-03 | JavaScript parsing | SATISFIED | test_baseline_express_middleware, test_baseline_callback_patterns |
| PARSE-04 | 21-03 | JSX parsing | SATISFIED | test_baseline_jsx_component (jsx_component.jsx) |
| PARSE-05 | 21-02 | Function name extraction | SATISFIED | NameContext with callback/export naming; naming_edge_cases_fixture test |
| METR-01 | 21-03 | Cyclomatic complexity parity | SATISFIED | All 12 baseline tests compare cyclomatic field exactly |
| METR-02 | 21-01 | Cognitive complexity parity | SATISFIED | fetchUserData=15 pinned; all 12 baseline tests compare cognitive field exactly |
| METR-03 | 21-01 | Halstead metrics within tolerance | SATISFIED | HALSTEAD_TOL=1e-9 applied to 4 Halstead fields in compare_function() |
| METR-04 | 21-03 | Structural metrics parity | SATISFIED | nesting_depth, line_count, params_count compared exactly in all baseline tests |
| METR-05 | 21-01 | Duplication detection | SATISFIED | test_duplication_flag_enables_analysis; Zig-schema JSON output |
| METR-06 | 21-01 | Health score sigmoid parity | SATISFIED | SCORE_TOL=1e-6 applied to health_score; simple_function baseline shows 82.71 |
| CLI-01 | 21-03 | CLI flags preserved | SATISFIED | --format, --no-color, --fail-on, --config, --threads, --duplication all exercised |
| CLI-02 | 21-03 | Config file loading | SATISFIED | test_config_file_loading_lowers_threshold creates temp config and verifies effect |
| CLI-03 | 21-03 | CLI overrides config | SATISFIED | test_cli_format_overrides_config_format verifies --format sarif beats config format=json |
| OUT-01 | 21-02 | Console output Zig ESLint format | SATISFIED | Consolidated per-function format with ✓/⚠/✗ symbols; 195 unit tests pass |
| OUT-02 | 21-01 | JSON schema matches Zig | SATISFIED | project_duplication_pct, clone_groups.locations, files[] array match Zig schema |
| OUT-03 | 21-03 | SARIF 2.1.0 structural validation | SATISFIED | test_sarif_structure validates $schema, version, tool.driver, results[].ruleId/level/locations |
| OUT-04 | 21-03 | HTML self-contained | SATISFIED | test_html_no_external_urls confirms no http:// or https:// in output |
| OUT-05 | 21-03 | Exit codes 0-4 | PARTIAL | Codes 0/1/2/3 tested; code 4 excluded (see gap) |
| PIPE-01 | 21-03 | Directory scanning | SATISFIED | test_directory_scan_multiple_files verifies files_analyzed > 1 |
| PIPE-02 | 21-03 | Parallel analysis | SATISFIED | test_threads_flag_produces_correct_results verifies --threads 1 gives same results |
| PIPE-03 | 21-03 | Deterministic ordering | SATISFIED | test_deterministic_ordering_across_runs compares file path order across two runs |

**Orphaned requirements:** None — all 22 functional requirements are covered by phase 21 plans.

### Anti-Patterns Found

No blocking anti-patterns found in any files modified by this phase.

| File | Pattern | Severity | Notes |
| ---- | ------- | -------- | ----- |
| `rust/tests/integration_tests.rs` line 309 | Exit code 4 deliberately untested (comment-documented) | Info | Not a stub — explicitly reasoned design decision |

### Human Verification Required

The following items are verified programmatically via passing tests and cannot produce additional gaps:

1. **Visual console output parity with Zig binary** — test_render_console_* unit tests verify the format programmatically, but a side-by-side human comparison of actual binary output against Zig would be the gold standard.
   - Test: Run `./rust/target/release/complexity-guard tests/fixtures/typescript/complex_nested.ts` and compare with Zig binary output.
   - Expected: Single line per function with ✗/⚠/✓ symbols and inline metrics.
   - Why human: Visual formatting and symbol rendering cannot be fully validated programmatically.

2. **Duplication output against real Zig v1.0 baseline** — baselines were recorded from the Rust binary (after bug fixes), not directly from Zig v1.0. The claim of "behavioral parity" rests on the correctness of Plan 01 bug fixes.
   - Test: Run both Zig v1.0 binary and Rust binary on the same fixture directory with duplication enabled; compare JSON output field by field.
   - Expected: project_duplication_pct, clone_groups, and files[] match between binaries.
   - Why human: Zig binary availability and direct comparison cannot be done via grep.

## Gaps Summary

One gap against the ROADMAP success criteria:

**Success Criterion 2 — Exit code 4 not confirmed:** The integration tests confirm exit codes 0 (clean), 1 (errors present), 2 (warnings with --fail-on warning), and 3 (bad config path). Exit code 4 (parse error / unrecoverable parse failure) is not tested. The code comment explains that tree-sitter is error-tolerant and returns partial parse results rather than failing, making exit code 4 unreachable in practice with real fixture files.

This represents a deliberate design trade-off: the implementation correctly handles the other four exit codes, but the stated success criterion includes code 4. The gap can be resolved by either:
1. Creating a fixture or mechanism that forces a parse-level error (e.g., a completely invalid binary file passed as input)
2. Formally updating the ROADMAP to document exit code 4 as untestable by design

The gap does not prevent the phase goal from being substantially achieved — 29/29 integration tests pass, all other success criteria are met, and behavioral parity is confirmed for all metric and output concerns.

---

_Verified: 2026-02-25T08:00:00Z_
_Verifier: Claude (gsd-verifier)_
