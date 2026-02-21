---
phase: quick-18
plan: 01
subsystem: benchmarks/scripts
tags: [benchmarks, node, jq, python-removal, tooling]
dependency_graph:
  requires: []
  provides: [summarize-results.mjs, compare-metrics.mjs]
  affects: [benchmarks/scripts, benchmarks/README.md, docs/benchmarks.md]
tech_stack:
  added: [Node.js ESM (.mjs), jq]
  patterns: [node-esm-scripts, jq-json-extraction, bash-loop-aggregation]
key_files:
  created:
    - benchmarks/scripts/summarize-results.mjs
    - benchmarks/scripts/compare-metrics.mjs
  modified:
    - benchmarks/scripts/setup.sh
    - benchmarks/scripts/bench-quick.sh
    - benchmarks/scripts/bench-full.sh
    - benchmarks/scripts/bench-stress.sh
    - benchmarks/scripts/bench-subsystems.sh
    - benchmarks/scripts/compare-metrics.sh
    - benchmarks/README.md
    - docs/benchmarks.md
  deleted:
    - benchmarks/scripts/summarize_results.py
    - benchmarks/scripts/compare_metrics.py
decisions:
  - "Node.js ESM (.mjs) for complex JSON aggregation scripts (same runtime already required for FTA install)"
  - "jq for inline JSON extraction in shell scripts (simple field reads, no Python subprocess needed)"
  - "node -e for ratio arithmetic in summary tables (avoids jq floating-point formatting edge cases)"
  - "bash loop + node compare-metrics.mjs for aggregation in compare-metrics.sh (replaces Python heredoc)"
metrics:
  duration: 6 min
  completed: 2026-02-21
  tasks_completed: 2
  files_changed: 10
---

# Quick Task 18: Remove Python Dependency from Phase 10.1 Benchmark Scripts Summary

**One-liner:** Ported summarize_results.py and compare_metrics.py to Node.js ESM scripts and replaced all inline python3 JSON parsing in shell scripts with jq and node invocations.

## What Was Built

Eliminated the python3 prerequisite from the Phase 10.1 benchmark tooling. The project now depends only on Zig and Node.js/npm (already required for FTA installation) plus jq for simple JSON field extraction in shell scripts.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Port Python scripts to Node.js and replace inline Python in shell scripts with jq | 3a08f3a | summarize-results.mjs, compare-metrics.mjs, 6 updated .sh files |
| 2 | Delete Python scripts and update documentation | b911d16 | benchmarks/README.md, docs/benchmarks.md, 2 deleted .py files |

## Key Changes

### New Node.js Scripts

**`benchmarks/scripts/summarize-results.mjs`** — Direct port of `summarize_results.py`:
- Same CLI: `node summarize-results.mjs <results-dir> [--json <output-path>]`
- Same output: markdown tables to stdout, JSON to file on `--json`
- Same speedup formula: CG_time/FTA_time (>1.0 = FTA faster)
- Functions: `meanMemory`, `parseHyperfineFile`, `parseSubsystemsFile`, `parseMetricAccuracy`, `formatSpeedRow`, `printSpeedTable`, `printMetricAccuracyTable`
- Uses only `node:fs`, `node:path`, `node:process` (no npm dependencies)

**`benchmarks/scripts/compare-metrics.mjs`** — Direct port of `compare_metrics.py`:
- Same CLI: `node compare-metrics.mjs <cg-json> <fta-json> <project-name>`
- Same output: JSON to stdout, human summary to stderr
- Same tolerances: CYCLOMATIC_TOLERANCE=25, HALSTEAD_TOLERANCE=30, LINE_COUNT_TOLERANCE=20
- Same Spearman rank correlation implementation
- Functions: `normalizeCgPath`, `loadCgOutput`, `loadFtaOutput`, `diffPct`, `computeRankingCorrelation`, `analyzeMetric`

### Shell Script Updates

| Script | Change |
|--------|--------|
| `setup.sh` | Replaced python3 heredoc with jq + bash loop for project cloning |
| `bench-quick.sh` | Replaced python3 JSON extraction with jq; ratio computation with `node -e` |
| `bench-full.sh` | Replaced python3 project list extraction with jq; JSON extraction with jq |
| `bench-stress.sh` | Replaced python3 JSON extraction with jq; ratio with `node -e` |
| `bench-subsystems.sh` | Replaced python3 hotspot extraction with jq |
| `compare-metrics.sh` | Replaced python3 aggregation heredoc with bash loop + node invocation; full suite project list with jq |

All scripts that use jq now check for jq availability and emit a friendly install message on failure.

### Documentation Updates

- **benchmarks/README.md**: Removed python3 prerequisite, added jq prerequisite with install commands, updated all script references and command examples
- **docs/benchmarks.md**: Updated all `python3 benchmarks/scripts/summarize_results.py` references to `node benchmarks/scripts/summarize-results.mjs`, updated `compare_metrics.py` reference to `compare-metrics.mjs`

## Verification Results

All verification checks passed:
- Zero python3 references in owned benchmark shell scripts and documentation
- Zero .py files remaining in `benchmarks/scripts/`
- All 6 shell scripts pass `bash -n` syntax validation
- Both .mjs scripts pass `node --check` syntax validation
- `parseHyperfineFile` function present in summarize-results.mjs
- `computeRankingCorrelation` function present in compare-metrics.mjs

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

### Files Created/Modified

- [x] benchmarks/scripts/summarize-results.mjs — EXISTS
- [x] benchmarks/scripts/compare-metrics.mjs — EXISTS
- [x] benchmarks/scripts/setup.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/bench-quick.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/bench-full.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/bench-stress.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/bench-subsystems.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/compare-metrics.sh — MODIFIED (no python references)
- [x] benchmarks/scripts/summarize_results.py — DELETED
- [x] benchmarks/scripts/compare_metrics.py — DELETED
- [x] benchmarks/README.md — UPDATED (no python3 references)
- [x] docs/benchmarks.md — UPDATED (no python3 references)

### Commits

- [x] 3a08f3a — Task 1 commit
- [x] b911d16 — Task 2 commit

## Self-Check: PASSED
