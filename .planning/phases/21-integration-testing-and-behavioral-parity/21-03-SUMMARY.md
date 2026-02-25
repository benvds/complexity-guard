---
phase: 21-integration-testing-and-behavioral-parity
plan: "03"
subsystem: testing
tags: [integration-tests, behavioral-parity, baselines, assert_cmd, rust, json, sarif, html]

# Dependency graph
requires:
  - phase: 21-01
    provides: "metric and schema bugs fixed (cognitive_error=25, fetchUserData cognitive=15, duplication schema)"
  - phase: 21-02
    provides: "console output parity and function naming (callbacks, exports)"
provides:
  - "29 integration tests covering all requirements PARSE-01 through PIPE-03"
  - "12 committed baseline JSON files recording Rust binary output after bug fixes"
  - "assert_cmd + predicates dev-dependencies added to Cargo.toml"
  - "Float tolerance constants: HALSTEAD_TOL=1e-9, SCORE_TOL=1e-6"
  - "Exit codes 0/1/2/3 all tested and passing"
  - "SARIF structural validation (tool.driver, results.ruleId/level/locations)"
  - "HTML self-contained check (no external URLs)"
  - "Deterministic ordering verified across two runs"
affects: [22-cross-compilation-ci-release]

# Tech tracking
tech-stack:
  added:
    - "assert_cmd = 2 (binary integration testing)"
    - "predicates = 3 (assertion helpers for assert_cmd)"
  patterns:
    - "compare_fixture() helper: loads baseline JSON and compares per-function fields with tolerances"
    - "compare_function() helper: exact integer comparison + float tolerance for Halstead/health"
    - "HALSTEAD_TOL = 1e-9 for Halstead volume/difficulty/effort/bugs"
    - "SCORE_TOL = 1e-6 for health_score fields"
    - "Baseline files strip timestamp and elapsed_ms (non-deterministic) via jq del()"

key-files:
  created:
    - rust/tests/integration_tests.rs
    - rust/tests/fixtures/baselines/simple_function.json
    - rust/tests/fixtures/baselines/cognitive_cases.json
    - rust/tests/fixtures/baselines/cyclomatic_cases.json
    - rust/tests/fixtures/baselines/halstead_cases.json
    - rust/tests/fixtures/baselines/structural_cases.json
    - rust/tests/fixtures/baselines/async_patterns.json
    - rust/tests/fixtures/baselines/class_with_methods.json
    - rust/tests/fixtures/baselines/complex_nested.json
    - rust/tests/fixtures/baselines/react_component.json
    - rust/tests/fixtures/baselines/express_middleware.json
    - rust/tests/fixtures/baselines/jsx_component.json
    - rust/tests/fixtures/baselines/callback_patterns.json
  modified:
    - rust/Cargo.toml

key-decisions:
  - "Baseline files strip timestamp and elapsed_ms with jq del() — these fields change between runs and would cause flaky tests"
  - "Float tolerances explicitly documented as constants at file top: HALSTEAD_TOL=1e-9, SCORE_TOL=1e-6"
  - "assert_cmd deprecation warning (cargo_bin) noted but left as-is — affects only a custom build-dir config we don't use; tests work correctly"
  - "Exit code 4 (parse error) intentionally not tested — tree-sitter is error-tolerant and returns partial results"
  - "compare_fixture() helper centralizes baseline comparison for 12 tests — avoids code duplication"
  - "test_config_file_loading_lowers_threshold uses cyclomatic=5 (vs default 10) on cyclomatic_cases.ts: produces 4 warnings vs 1 at default"

patterns-established:
  - "Integration tests use cargo_bin() wrapper returning assert_cmd::Command — all invocations go through single helper"
  - "fixture_path() resolves from CARGO_MANIFEST_DIR/../tests/fixtures/ for shared top-level fixtures"
  - "baseline_path() resolves from CARGO_MANIFEST_DIR/tests/fixtures/baselines/ for rust-local baselines"
  - "Float tolerance pattern: assert_float_eq(actual, expected, tol, context) with descriptive context string"

requirements-completed: [PARSE-01, PARSE-02, PARSE-03, PARSE-04, METR-01, METR-04, CLI-01, CLI-02, CLI-03, OUT-03, OUT-04, OUT-05, PIPE-01, PIPE-02, PIPE-03]

# Metrics
duration: 4min
completed: 2026-02-25
---

# Phase 21 Plan 03: Integration Test Baselines Summary

**29 integration tests validating behavioral parity against 12 committed JSON baselines — all exit codes, output formats, SARIF structure, HTML self-containment, directory scan, deterministic ordering, and duplication flag confirmed**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-25T07:05:31Z
- **Completed:** 2026-02-25T07:09:18Z
- **Tasks:** 2
- **Files modified:** 14 (Cargo.toml + 12 baseline JSONs + integration_tests.rs)

## Accomplishments

- Recorded 12 baseline JSON files from the Rust binary (all bug fixes from 21-01 and 21-02 incorporated), stripping non-deterministic fields (timestamp, elapsed_ms) via jq
- Wrote 29 integration tests in `rust/tests/integration_tests.rs` covering all requirements from PARSE-01 through PIPE-03 — all tests pass
- Float tolerances explicitly defined as constants: HALSTEAD_TOL=1e-9, SCORE_TOL=1e-6

## Task Commits

Each task was committed atomically:

1. **Task 1: Add test dependencies and record baselines from Rust binary** - `123c3bf` (chore)
2. **Task 2: Write integration test suite covering all requirements** - `650fbf4` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `rust/Cargo.toml` - Added assert_cmd = "2" and predicates = "3" to dev-dependencies
- `rust/tests/fixtures/baselines/` - 12 JSON baseline files (one per fixture file)
- `rust/tests/integration_tests.rs` - 29 integration tests covering all requirement categories

## Decisions Made

- Baseline files strip `timestamp` and `metadata.elapsed_ms` with `jq del()` — these fields change every run and would cause flaky tests
- Float tolerances documented as constants at file top: `HALSTEAD_TOL = 1e-9`, `SCORE_TOL = 1e-6`
- `assert_cmd::Command::cargo_bin` deprecation warning noted but intentionally left — affects only custom build-dir configs we don't use; tests run correctly
- Exit code 4 (parse error) intentionally not tested — tree-sitter is error-tolerant, returns partial results rather than failing
- `compare_fixture()` helper centralizes all 12 baseline comparisons, avoiding repeated code
- Config threshold test uses cyclomatic.warning=5 (vs default 10) against cyclomatic_cases.ts: produces 4 warnings vs 1 at default — proves config loading works

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — all tests passed on first run; binary builds cleanly; all 232 tests pass (195 unit + 8 parser + 29 integration).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 21 complete (3/3 plans done) — integration test suite provides regression baseline for Phase 22
- All 29 integration tests pass; coverage spans all PARSE-01 through PIPE-03 requirements
- Float tolerances documented; exit codes verified; SARIF structure validated
- Phase 22 (Cross-Compilation, CI, Release) can proceed with confidence that behavioral parity is confirmed

## Self-Check: PASSED

Files verified present:
- rust/tests/integration_tests.rs — FOUND
- rust/Cargo.toml — FOUND (assert_cmd and predicates in dev-dependencies)
- rust/tests/fixtures/baselines/ — 12 JSON files FOUND

Commits verified:
- 123c3bf — chore(21-03): add test dependencies and record Rust binary baselines
- 650fbf4 — feat(21-03): write integration test suite with 29 tests covering all requirements

Test count: 29 integration tests (plan required 20+) — PASSED

---
*Phase: 21-integration-testing-and-behavioral-parity*
*Completed: 2026-02-25*
