---
phase: 11-duplication-detection
plan: 02
subsystem: cli, pipeline, scoring
tags: [duplication, cli-flags, config, scoring, pipeline, weights]

# Dependency graph
requires:
  - phase: 11-01
    provides: duplication.zig (tokenizeTree, detectDuplication, DuplicationResult, DuplicationConfig, FileTokens)
  - phase: 02
    provides: CLI args parsing, config types, merge logic
  - phase: 08
    provides: scoring.zig (EffectiveWeights, resolveEffectiveWeights, computeFunctionScore)
provides:
  - --duplication CLI flag and --metrics duplication path to enable duplication analysis
  - DuplicationThresholds struct (configurable file/project warning/error percentages)
  - duplication_enabled field in AnalysisConfig
  - Duplication pass wired into main.zig pipeline (re-parse approach)
  - 5-metric weight normalization in resolveEffectiveWeights when duplication enabled
  - normalizeDuplication() sigmoid scoring for duplication percentages
  - computeFileScoreWithDuplication() blending base and duplication scores
affects: [11-03, 11-04, output-modules, json-output, sarif-output]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "5-metric weight normalization: resolveEffectiveWeights(weights, duplication_enabled: bool) — 4-metric or 5-metric mode"
    - "Re-parse approach for duplication: main.zig re-reads and re-parses files after per-file analysis (trees were freed)"
    - "Sigmoid normalization for duplication percentage: warning_pct -> 50, error_pct -> ~20"
    - "File score blending: base_file_score * (1 - dup_weight) + dup_score * dup_weight"

key-files:
  created: []
  modified:
    - src/cli/args.zig
    - src/cli/config.zig
    - src/cli/merge.zig
    - src/cli/help.zig
    - src/main.zig
    - src/metrics/scoring.zig
    - src/pipeline/parallel.zig

key-decisions:
  - "Re-parse approach in main.zig: re-read and re-parse each file for tokenization after per-file analysis loop (trees freed during analysis) — simpler than pre-tokenizing in workers"
  - "duplication_enabled: bool parameter on resolveEffectiveWeights: single function handles both 4-metric and 5-metric normalization modes"
  - "duplication field added to EffectiveWeights struct: always present, 0.0 when disabled (no separate struct variant)"
  - "buildDuplicationConfig helper in main.zig: maps optional ThresholdsConfig.duplication to DuplicationConfig with defaults"
  - "Score blending uses (1 - dup_weight) factor: correctly re-weights base score when duplication is included"

requirements-completed: [DUP-06, DUP-07]

# Metrics
duration: 5min
completed: 2026-02-22
---

# Phase 11 Plan 02: CLI Flag, Config, Pipeline, and Scoring Integration Summary

**Duplication detection wired into CLI (--duplication flag), configuration (DuplicationThresholds), analysis pipeline (re-parse tokenization pass), and health score system (5-metric weight normalization with 0.20 duplication weight)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-22T18:16:44Z
- **Completed:** 2026-02-22T18:22:24Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added `--duplication` CLI flag to `CliArgs` struct with parsing in `parseArgsFromSlice`; help text updated in ANALYSIS section
- Added `DuplicationThresholds` struct (file_warning/error, project_warning/error as `?f64`) and `duplication: ?DuplicationThresholds` to `ThresholdsConfig`
- Added `duplication_enabled: ?bool = null` to `AnalysisConfig` (defaults to `false`); `deepCopyConfig` propagates it
- `mergeArgsIntoConfig` sets `duplication_enabled = true` when `--duplication` flag is set
- Added `duplication_mod` import in `main.zig`; `duplication_enabled` computed from flag or `--metrics duplication`
- Duplication pass runs after per-file analysis: re-parses all files, builds `FileTokens` list, calls `detectDuplication`
- `buildDuplicationConfig` helper maps `ThresholdsConfig.duplication` to `DuplicationConfig` with defaults
- File scores blended with duplication sigmoid scores; file/project threshold violations counted in `total_warnings`/`total_errors`
- `EffectiveWeights` struct gains `duplication: f64` field; `resolveEffectiveWeights` takes `duplication_enabled: bool` parameter
- 4-metric mode: `duplication = 0.0`, 4 weights normalized; 5-metric mode: all 5 weights normalized
- Added `normalizeDuplication()` and `computeFileScoreWithDuplication()` scoring functions
- All parallel.zig and scoring.zig test call sites updated; 8 new tests added for new functions

## Task Commits

1. **Task 1: CLI flag, config types, merge, help** - `b26b677` (feat)
2. **Task 2: Pipeline wiring, scoring, thresholds** - `f971056` (feat)

## Files Created/Modified

- `src/cli/args.zig` - Added `duplication: bool = false` field and `--duplication` parsing
- `src/cli/config.zig` - Added `DuplicationThresholds` struct, `duplication: ?DuplicationThresholds` in `ThresholdsConfig`, `duplication_enabled: ?bool` in `AnalysisConfig`, deepCopy support
- `src/cli/merge.zig` - Set `duplication_enabled = true` when `--duplication` flag set; new test
- `src/cli/help.zig` - Added `--duplication` line in ANALYSIS section
- `src/main.zig` - Added `duplication_mod`/`tree_sitter_mod` imports, `buildDuplicationConfig` helper, `duplication_enabled` determination, full duplication pass with re-parse loop, score blending, violation counting
- `src/metrics/scoring.zig` - Added `duplication: f64` to `EffectiveWeights`, updated `resolveEffectiveWeights(weights, duplication_enabled)`, added `normalizeDuplication()` and `computeFileScoreWithDuplication()`, 8 new tests, updated all test call sites
- `src/pipeline/parallel.zig` - Updated 2 `resolveEffectiveWeights(null)` calls to `resolveEffectiveWeights(null, false)`

## Decisions Made

- Re-parse approach chosen: simpler than pre-tokenizing in parallel workers; duplication is an opt-in pass so the overhead only occurs when enabled
- Single `resolveEffectiveWeights` function with boolean parameter handles both modes cleanly
- `duplication: f64` always present in `EffectiveWeights` (0.0 when disabled) avoids branching at every use site

## Deviations from Plan

None - plan executed exactly as written. The re-parse approach was explicitly documented in the plan as the recommended path.

## Issues Encountered

None beyond the auto-fixed deviations above.

## Next Phase Readiness

- `dup_result: ?DuplicationResult` available in main.zig pipeline for output module consumption (Plan 03: console/JSON/SARIF/HTML output)
- File-level `duplication_pct`, `warning`, `error` flags and project-level `project_duplication_pct`, `project_warning`, `project_error` ready for display
- DUP-06 and DUP-07 complete. DUP-08 and beyond (output format integration) ready for Plan 03.

## Self-Check: PASSED

- FOUND: src/cli/args.zig (duplication: bool field)
- FOUND: src/cli/config.zig (DuplicationThresholds struct)
- FOUND: src/main.zig (detectDuplication call)
- FOUND: src/metrics/scoring.zig (duplication weight field)
- FOUND commit: b26b677 (Task 1)
- FOUND commit: f971056 (Task 2)
- `zig build test` exit code: 0 (all tests pass)
- `zig-out/bin/complexity-guard --duplication tests/fixtures/` runs without crash: 19 problems detected
- `zig-out/bin/complexity-guard tests/fixtures/` without flag: 13 problems (zero duplication overhead confirmed)

---
*Phase: 11-duplication-detection*
*Completed: 2026-02-22*
