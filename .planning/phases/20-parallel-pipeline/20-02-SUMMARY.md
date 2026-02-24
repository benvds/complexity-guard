---
phase: 20-parallel-pipeline
plan: "02"
subsystem: pipeline
tags: [rust, rayon, parallel, main, cli, pipeline, documentation]
dependency_graph:
  requires:
    - phase: 20-01
      provides: pipeline::discover_files, pipeline::analyze_files_parallel
  provides:
    - main.rs full pipeline wiring (discover -> parallel analyze -> duplication -> output -> exit codes)
    - build_analysis_config() helper mapping ResolvedConfig to AnalysisConfig
    - Working end-to-end binary analyzing real TS/JS files
  affects: [21-integration-testing, 22-cross-compile-ci-release]
tech_stack:
  added: []
  patterns: [config-to-analysis-config-mapping, post-parallel-duplication-gating, violation-count-for-exit-code]
key_files:
  created: []
  modified:
    - rust/src/main.rs
    - README.md
    - docs/getting-started.md
    - docs/cli-reference.md
    - docs/examples.md
    - publication/npm/README.md
    - publication/npm/packages/darwin-arm64/README.md
    - publication/npm/packages/darwin-x64/README.md
    - publication/npm/packages/linux-arm64/README.md
    - publication/npm/packages/linux-x64/README.md
    - publication/npm/packages/windows-x64/README.md
key-decisions:
  - "build_analysis_config() maps ResolvedConfig flat thresholds into AnalysisConfig struct hierarchy (cyclomatic, cognitive, scoring_weights, scoring_thresholds, duplication)"
  - "Duplication gated on config.analysis.duplication_enabled && !no_duplication (post-parallel step)"
  - "function_violations() reused from output::console to count warnings/errors for exit code — no duplication of violation logic"
  - "Default path '.' used when args.paths is empty — mirrors Zig binary behavior"
patterns-established:
  - "Pipeline wiring pattern: discover -> analyze_parallel -> optional_post_step -> count_violations -> render -> exit"
requirements-completed: [PIPE-01, PIPE-02, PIPE-03]
duration: 3min
completed: 2026-02-24
---

# Phase 20 Plan 02: Pipeline Wiring (main.rs CLI Integration) Summary

**Full end-to-end Rust binary with rayon-parallel file discovery, analysis, duplication detection, correct exit codes, and deterministic sorted output wired into main.rs**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-24T19:43:48Z
- **Completed:** 2026-02-24T19:47:32Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Binary now discovers and analyzes real TS/JS files end-to-end when pointed at a directory or file path
- Replaced placeholder stub (empty vec + hardcoded exit 0) with real `discover_files()` -> `analyze_files_parallel()` -> `detect_duplication()` pipeline
- Duplication detection runs post-parallel when `--duplication` flag is set (gated by `duplication_enabled` config flag)
- Exit code correctly reflects actual violation counts from `function_violations()` — errors return 1, warnings + `--fail-on warning` return 2
- Default path "." used when no positional args provided (mirrors Zig binary)
- Output is deterministic across multiple runs (PathBuf::cmp sorting from Phase 20-01)
- All 11 documentation files updated with Phase 20 parallel pipeline note

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace main.rs placeholder with full pipeline wiring** - `8a631d1` (feat)
2. **Task 2: Update README.md and docs pages for parallel pipeline** - `35a873a` (docs)

**Plan metadata:** (forthcoming in docs commit)

## Files Created/Modified

- `rust/src/main.rs` — Full pipeline wiring with build_analysis_config() helper; replaced placeholder stub
- `README.md` — Phase 20 completion note in Rust Rewrite section
- `docs/getting-started.md` — Note that Rust binary can now analyze directories end-to-end
- `docs/cli-reference.md` — Note that --threads, --include, --exclude functional in Rust binary
- `docs/examples.md` — Note that Rust binary supports directory analysis
- `publication/npm/README.md` — Phase 20 parallel pipeline note synced
- `publication/npm/packages/darwin-arm64/README.md` — Phase 20 note
- `publication/npm/packages/darwin-x64/README.md` — Phase 20 note
- `publication/npm/packages/linux-arm64/README.md` — Phase 20 note
- `publication/npm/packages/linux-x64/README.md` — Phase 20 note
- `publication/npm/packages/windows-x64/README.md` — Phase 20 note

## Decisions Made

- `build_analysis_config()` added as a private helper in main.rs that maps from `Config` + `ResolvedConfig` (flat thresholds) to `AnalysisConfig` struct (nested cyclomatic/cognitive/scoring sub-configs). This centralizes all config-to-analysis mapping in one place.
- Duplication gated on `config.analysis.duplication_enabled && !no_duplication` — reads from the merged config directly (same fields that `merge_args_into_config` writes when `--duplication` is passed).
- `function_violations()` reused from `output::console` to count errors/warnings for exit code — avoids duplicating threshold comparison logic.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Verification Results

```
cargo build                    => Finished cleanly
cargo run -- fixtures/ts/      => 11 files, 60 functions, 11 warnings, 4 errors
cargo run -- simple.ts -f json => Correct JSON output with real metrics
--fail-on warning              => Exit code 1 (errors found), correct behavior
default "." path               => Works, analyzes current directory
deterministic output           => Identical analysis data across multiple runs (only elapsed_ms differs)
cargo test                     => All tests pass
```

## Self-Check: PASSED

- `rust/src/main.rs` — exists (full pipeline wiring, 234 lines)
- `.planning/phases/20-parallel-pipeline/20-02-SUMMARY.md` — exists
- `README.md` — exists with Phase 20 note
- Task 1 commit: 8a631d1 — verified in git log
- Task 2 commit: 35a873a — verified in git log

## Next Phase Readiness

- Binary fully functional end-to-end — ready for Phase 21 integration testing
- All pipeline stages wired: discovery, parallel analysis, duplication, output formats, exit codes
- No blockers for Phase 21

---
*Phase: 20-parallel-pipeline*
*Completed: 2026-02-24*
