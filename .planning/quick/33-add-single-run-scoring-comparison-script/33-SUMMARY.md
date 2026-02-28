---
phase: quick-33
plan: 01
subsystem: benchmarks/scripts
tags: [scoring, benchmarks, tooling, esm]
dependency_graph:
  requires: [quick-32]
  provides: [score-project.mjs, scoring-algorithms.mjs]
  affects: [compare-scoring.mjs]
tech_stack:
  added: []
  patterns: [ESM shared module, single-run CLI, child_process.execSync]
key_files:
  created:
    - benchmarks/scripts/scoring-algorithms.mjs
    - benchmarks/scripts/score-project.mjs
  modified:
    - benchmarks/scripts/compare-scoring.mjs
decisions:
  - collectAllFunctions() accepts both batch array and single analysisData object for reuse across batch and single-run modes
  - score-project.mjs imports only node built-ins and scoring-algorithms.mjs (no external deps)
  - Per-file table capped at 30 rows with "... and N more" overflow message
  - json-output row added to Algorithm Scores table for direct comparison with reported health_score
metrics:
  duration: 3 min
  completed: 2026-02-28
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase quick-33 Plan 01: Add Single-Run Scoring Comparison Script Summary

**One-liner:** ESM shared scoring module extracted from compare-scoring.mjs plus new score-project.mjs CLI that runs complexity-guard on any directory and displays all 8 algorithm scores side-by-side.

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Extract shared scoring module and refactor compare-scoring.mjs | 8d5c23c | benchmarks/scripts/scoring-algorithms.mjs (created), benchmarks/scripts/compare-scoring.mjs (modified) |
| 2 | Create score-project.mjs single-run script | d7dc267 | benchmarks/scripts/score-project.mjs (created) |

## What Was Built

### benchmarks/scripts/scoring-algorithms.mjs (new)

Shared ESM module exporting all scoring primitives, algorithm definitions, and helpers:
- `linearScore`, `computeFunctionScore` — scoring primitives (port of Rust scoring.rs)
- `DEFAULT_WEIGHTS`, `DEFAULT_THRESHOLDS` — Rust default constants
- `mean`, `geometricMean`, `minimum`, `weightedMean`, `percentile` — aggregation helpers
- `ALGORITHMS` — Map with all 8 algorithm definitions
- `scoreFunctionWithAlgorithm`, `scoreFile`, `scoreProject` — scoring engine
- `computeStats` — distribution statistics (spread, stdev, percentiles, count buckets)
- `collectAllFunctions` — accepts both batch `[{project, data}]` and single `analysisData` inputs
- `round`, `fmtScore`, `padEnd` — formatting helpers

### benchmarks/scripts/compare-scoring.mjs (refactored)

Slimmed to batch-mode concerns only: argument parsing, `detectLatestResultsDir()`, `loadAnalysisFiles()`, and the main output loop. All scoring logic now imported from `./scoring-algorithms.mjs`. Output is identical to before.

### benchmarks/scripts/score-project.mjs (new)

Single-run scoring comparison CLI:
- Accepts `<target-dir>` positional argument; prints usage and exits 1 if missing
- Builds binary via `cargo build --release` unless `--no-build` passed
- Runs `complexity-guard --format json --fail-on none <target-dir>` via execSync
- Scores output with all 8 algorithms
- **Algorithm Scores table**: sorted descending with `json-output` row for comparison against reported health_score
- **Per-File Scores table**: sorted by `current` ascending (worst first), capped at 30 rows
- **Distribution Statistics**: Spread, StdDev, Min, P25, Median, P75, Max per algorithm
- No external dependencies — only node built-ins and scoring-algorithms.mjs

## Verification Results

1. `node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26` — All 83 projects match within 0.5 tolerance. Output identical to before refactoring.
2. `node benchmarks/scripts/score-project.mjs tests/fixtures --no-build` — Produces full comparison table (15 files, 76 functions, 8 algorithms scored).
3. `node benchmarks/scripts/score-project.mjs` (no args) — Prints usage and exits with code 1.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- benchmarks/scripts/scoring-algorithms.mjs: FOUND
- benchmarks/scripts/score-project.mjs: FOUND
- benchmarks/scripts/compare-scoring.mjs: FOUND (modified)
- Commit 8d5c23c: FOUND
- Commit d7dc267: FOUND
