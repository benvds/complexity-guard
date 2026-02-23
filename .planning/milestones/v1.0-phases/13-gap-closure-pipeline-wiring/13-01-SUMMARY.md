---
phase: 13-gap-closure-pipeline-wiring
plan: "01"
subsystem: pipeline-wiring
tags: [cyclomatic, exit-codes, duplication, config, gap-closure]
dependency_graph:
  requires: []
  provides: [buildCyclomaticConfig, countViolationsFiltered, worstStatusForMetrics]
  affects: [src/main.zig, src/output/exit_codes.zig, src/pipeline/parallel.zig]
tech_stack:
  added: []
  patterns: [buildXxxConfig helper pattern, isMetricEnabled duplication pattern]
key_files:
  created: []
  modified:
    - src/main.zig
    - src/output/exit_codes.zig
    - src/pipeline/parallel.zig
decisions:
  - "buildCyclomaticConfig follows same helper pattern as buildHalsteadConfig and buildStructuralConfig: reads ThresholdPair, falls back to CyclomaticConfig.default() for all other fields"
  - "countViolationsFiltered added alongside countViolations (not replacing): worstStatusAll in console.zig/exit_codes.zig unchanged for verbosity filtering (Phase 07-05 decision preserved)"
  - "isMetricEnabled duplicated in exit_codes.zig (not imported from main.zig): avoids circular imports per Phase 07-03 decision"
  - "no_duplication gate placed before duplication_enabled check in duplication_enabled block: flag overrides everything"
metrics:
  duration: "~2 min"
  completed: "2026-02-22"
  tasks_completed: 2
  files_modified: 3
  new_tests: 8
---

# Phase 13 Plan 01: Pipeline Gap Closure Summary

Four small but requirement-blocking wiring gaps identified by the v1.0 milestone audit are now closed. All four gaps were cases where config fields existed in the data model but were never read at the relevant call sites.

## One-liner

Closed four v1.0 pipeline gaps: cyclomatic config thresholds now flow from config file, --metrics flag now gates exit code counting (not just display), --no-duplication flag now prevents duplication detection, and --save-baseline default config now includes duplication weight 0.20.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wire four pipeline gaps in main.zig, exit_codes.zig, parallel.zig | d7413d5 | src/main.zig, src/output/exit_codes.zig, src/pipeline/parallel.zig |
| 2 | Add targeted tests for all four gap fixes | 3ef6b35 | src/main.zig, src/output/exit_codes.zig |

## What Was Done

### Gap 1 (CYCL-09): buildCyclomaticConfig helper

Added `pub fn buildCyclomaticConfig(thresholds: config_mod.ThresholdsConfig) cyclomatic.CyclomaticConfig` in `src/main.zig`, placed after `buildStructuralConfig`. Mirrors the existing `buildHalsteadConfig`/`buildStructuralConfig` pattern: reads `thresholds.cyclomatic.warning` and `.error`, falls back to `CyclomaticConfig.default()` for all other fields.

Replaced the hardcoded `const cycl_config = cyclomatic.CyclomaticConfig.default();` in the analysis pipeline with a config-file-aware expression that uses `buildCyclomaticConfig`. This ensures `metric_thresholds` (used for scoring sigmoid) and `sarif_thresholds` also automatically pick up config values since they already read from `cycl_config`.

### Gap 2 (CLI-07): --metrics gating of exit code counting

Added to `src/output/exit_codes.zig`:
- `isMetricEnabled` helper (same pattern as main.zig/parallel.zig, duplicated to avoid circular imports)
- `worstStatusForMetrics(result, metrics)`: considers only enabled metric families; null means all
- `countViolationsFiltered(results, metrics)`: uses `worstStatusForMetrics` instead of `worstStatusAll`

Updated sequential path in `src/main.zig` and parallel path in `src/pipeline/parallel.zig` to call `countViolationsFiltered(..., parsed_metrics)` instead of `countViolations(...)`. The existing `worstStatusAll` and `countViolations` functions are unchanged (still used in console.zig verbosity filtering).

### Gap 3 (CLI-08): --no-duplication flag gate

Added a check at the TOP of the `duplication_enabled` block in `src/main.zig`. Before the existing `duplication_enabled` config field check, the code now checks `cfg.analysis.no_duplication` and breaks out of the block with `false` if it is set. This ensures `--no-duplication` overrides both the `duplication_enabled` config flag and the `--metrics duplication` flag.

### Gap 4 (CFG-04): duplication weight in --save-baseline

Updated `writeDefaultConfigWithBaseline` in `src/main.zig` to add `"duplication": 0.20` to the weights section. Changed the existing `"structural": 0.15` line to add a trailing comma.

## Tests Added (8 new)

**In `src/output/exit_codes.zig`** (5 tests):
1. `worstStatusForMetrics: null metrics considers all families` — null treats same as worstStatusAll
2. `worstStatusForMetrics: cyclomatic-only ignores halstead warning` — single family isolation
3. `worstStatusForMetrics: cognitive-only ignores structural` — cross-family isolation
4. `countViolationsFiltered: filters by enabled metrics` — halstead warning ignored when only cyclomatic enabled
5. `countViolationsFiltered: null metrics matches countViolations` — behavioral equivalence

**In `src/main.zig`** (3 tests):
6. `buildCyclomaticConfig: applies config thresholds` — warning=15, error=30 from ThresholdPair
7. `buildCyclomaticConfig: falls back to defaults for null` — warning=10, error=20 defaults
8. `buildCyclomaticConfig: partial override (warning only)` — warning=12, error=20 default

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- `zig build` compiles without errors
- `zig build test` passes (existing tests + 8 new)
- Spot checks all passed:
  - `CyclomaticConfig.default()` at old line 229 replaced by `buildCyclomaticConfig`
  - No unfiltered `exit_codes.countViolations(cycl_results)` in production code paths
  - `no_duplication` check present in `duplication_enabled` block
  - `"duplication": 0.20` present in `writeDefaultConfigWithBaseline`

## Self-Check: PASSED

Files exist:
- src/main.zig: FOUND (modified)
- src/output/exit_codes.zig: FOUND (modified)
- src/pipeline/parallel.zig: FOUND (modified)

Commits exist:
- d7413d5: FOUND (feat(13-01): wire four pipeline gaps)
- 3ef6b35: FOUND (test(13-01): add targeted tests)
