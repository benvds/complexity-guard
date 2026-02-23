---
phase: 08-composite-health-score
plan: 03
subsystem: cli
tags: [cli, baseline, init, scoring, weight-optimization]
dependency_graph:
  requires: ["08-02"]
  provides: ["--save-baseline", "--fail-health-below", "enhanced --init"]
  affects: ["src/cli/args.zig", "src/cli/help.zig", "src/cli/init.zig", "src/main.zig"]
tech_stack:
  added: []
  patterns:
    - "Coordinate descent weight optimization: try +/-step per dimension, keep improvements, up to 20 iterations"
    - "Post-analysis --init: init command runs after full analysis pipeline to have scoring data available"
    - "stderr flush before process.exit: ensure buffered error messages appear before abrupt exit"
key_files:
  created: []
  modified:
    - src/cli/args.zig
    - src/cli/help.zig
    - src/cli/init.zig
    - src/main.zig
decisions:
  - "--init moved post-analysis: handles full analysis first, then calls runEnhancedInit with results; falls back to runInit when no files found"
  - "Coordinate descent with step=0.10: each dimension tried independently at +step and -step, improvement threshold 0.001 to avoid floating point drift"
  - "Optimized score as baseline: --init captures the optimized score (not default) as baseline, giving teams a favorable starting position"
  - "stderr flush added: buffered stderr writer needs explicit flush before std.process.exit() to ensure messages appear"
metrics:
  duration: 329
  completed: "2026-02-17"
  tasks_completed: 2
  files_changed: 4
---

# Phase 8 Plan 03: Save-Baseline CLI + Enhanced Init Summary

Implemented `--save-baseline` flag, `--fail-health-below` CLI override, and enhanced `--init` workflow with coordinate descent weight optimization. Teams can now capture a project's starting health score and enforce it in CI.

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | --save-baseline flag + CLI baseline override | e975d97 | Done |
| 2 | Enhanced --init with analysis and weight optimization | 73b5a25 | Done |

## What Was Built

### Task 1: --save-baseline + --fail-health-below

**`src/cli/args.zig`:**
- Added `save_baseline: bool = false` field to `CliArgs` struct
- Added handler for `"save-baseline"` boolean flag in `parseArgsFromSlice`
- Added test for `--save-baseline` flag parsing

**`src/cli/help.zig`:**
- Replaced `--baseline <FILE>` with `--save-baseline` in ANALYSIS section
- `--fail-health-below <N>` was already in THRESHOLDS section

**`src/main.zig`:**
- Added `writeDefaultConfigWithBaseline` helper: creates minimal config with baseline field when no config exists
- Added `--save-baseline` handler after scoring: rounds score to 1 decimal, reads/updates existing JSON config or creates new one, prints confirmation, returns early
- Rewired baseline check: CLI `--fail-health-below` takes priority over config `baseline`; legacy `--baseline` still supported as fallback
- Added `defer stderr.flush() catch {}` so baseline failure messages appear before `std.process.exit()`

### Task 2: Enhanced --init with Weight Optimization

**`src/cli/init.zig`:**
- Added imports for `cyclomatic_mod`, `scoring` modules
- Added `runEnhancedInit` function: receives pre-computed analysis results, shows file/function counts, runs optimization, displays before/after scores, writes config with optimized weights and baseline
- Added `computeScoreWithWeights` helper: computes project score directly from ThresholdResult slices with given weights (no re-analysis)
- Added `optimizeWeights` function: coordinate descent over 4 weight dimensions, step=0.10, up to 20 iterations, stops when no improvement
- Added `normalizeWeights` helper: normalizes 4 floats to sum 1.0
- Updated `generateJsonConfig` signature to accept `?EffectiveWeights` and `?f64` (baseline), writes them when provided
- Added tests for new functions

**`src/main.zig`:**
- Removed early `--init` handler (was before analysis)
- Added post-analysis `--init` handler: collects all ThresholdResult slices per file, calls `runEnhancedInit` when files found, falls back to `runInit` when no source files

## Verification Results

All plan verification steps confirmed:
1. `zig build test` - all tests pass
2. `--save-baseline tests/fixtures/` - prints "Baseline saved: 77.5", creates `.complexityguard.json` with `"baseline": 77.5`
3. `--init tests/fixtures/` - shows "Default weights score: 78 / Suggested weights score: 83", creates config with optimized weights and baseline
4. `--fail-health-below 99 tests/fixtures/` - exits 1, stderr shows "Health score 77.5 is below threshold 99.0"
5. `--fail-health-below 0 tests/fixtures/` - exits 1 due to 3 fixture errors (threshold errors, not health score failure - correct behavior)
6. `--help` - shows both `--save-baseline` and `--fail-health-below`

## Deviations from Plan

None - plan executed exactly as written, with one proactive improvement: added `defer stderr.flush() catch {}` to main.zig to ensure baseline failure messages appear before `std.process.exit()`. This was a correctness requirement (Rule 2) rather than a plan change.

## Self-Check: PASSED

Files created/modified confirmed:
- `src/cli/args.zig` - contains `save_baseline` field
- `src/cli/help.zig` - contains `save-baseline` in help text
- `src/cli/init.zig` - contains `optimizeWeights` function
- `src/main.zig` - contains `save_baseline` handler

Commits confirmed:
- e975d97 - Task 1 commit
- 73b5a25 - Task 2 commit
