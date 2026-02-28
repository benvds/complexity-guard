---
phase: quick-32
plan: "01"
subsystem: benchmarks
tags: [benchmarks, scoring, analysis, tooling]
dependency_graph:
  requires: []
  provides: [benchmarks/scripts/compare-scoring.mjs]
  affects: []
tech_stack:
  added: []
  patterns: [ESM Node.js, algorithm strategy pattern]
key_files:
  created:
    - benchmarks/scripts/compare-scoring.mjs
  modified: []
decisions:
  - JS replication of Rust linear_score() uses same piecewise linear formula; validated all 83 projects match within 0.5 score tolerance
  - percentile-based algorithm uses two-pass design: preprocess() collects all function metrics first, then uses percentile rank for scoring
  - geometric-mean and percentile-based algorithms override scoreFn on the algorithm object rather than using computeFunctionScore()
  - worst-metric algorithm uses minimum function score for file aggregate and p25 for project aggregate
metrics:
  duration: "~8 min"
  completed: "2026-02-28"
  tasks_completed: 1
  files_created: 1
---

# Quick Task 32: Build Scoring Algorithm Comparison Tool Summary

Node.js CLI that re-scores 84 benchmark projects with 8 alternative scoring algorithms (harsh-thresholds, steep-penalty, cognitive-heavy, geometric-mean, worst-metric, percentile-based, log-penalty) to reveal that spread values range from 7.9 (current) up to 37.1 (worst-metric), enabling tuning of health score distribution.

## What Was Built

`benchmarks/scripts/compare-scoring.mjs` -- a 500-line Node.js CLI tool that:

1. Reads all `*-analysis.json` files from a results directory (default: latest `benchmarks/results/baseline-*`)
2. Re-scores every function in every file using 8 different scoring algorithms
3. Outputs a markdown per-project comparison table sorted by `current` score ascending
4. Outputs distribution statistics (min, max, median, p25, p75, stdev, spread, count_gt95/90/80/70)
5. Validates that the JS `current` algorithm matches Rust health_score output within 0.5 tolerance
6. Optionally writes full JSON results via `--json` flag

## Algorithms Implemented

| Algorithm | Spread | Key Idea |
|-----------|--------|----------|
| `current` | 7.9 | Exact Rust defaults replication (baseline) |
| `harsh-thresholds` | 13.7 | Halved warning/error thresholds |
| `steep-penalty` | 20.2 | Halved thresholds + steeper curve (score(warn)=60, score(err)=20) |
| `cognitive-heavy` | 8.3 | cognitive weight=0.50 |
| `geometric-mean` | 10.8 | Geometric mean of 4 sub-scores |
| `worst-metric` | 37.1 | File=min function score, project=p25 of files |
| `percentile-based` | 20.8 | Percentile rank in dataset (not absolute thresholds) |
| `log-penalty` | 24.2 | Logarithmic penalty curve |

## Key Findings

- Current algorithm: all 83 projects score between 90.9-98.8 (spread=7.9), confirming the clustering problem
- `worst-metric` has the best differentiation (spread=37.1, stdev=6.8)
- `log-penalty` and `steep-penalty` both achieve spread >20
- `percentile-based` scores all projects 28-50 (relative to dataset, not absolute)
- All 83 analyzed projects match Rust health_score within 0.5 tolerance

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | d013f3b | feat(quick-32): build scoring algorithm comparison tool |

## Deviations from Plan

None -- plan executed exactly as written.

The `typescript-analysis.json` file has malformed JSON (truncated) and is skipped with a warning. This is a pre-existing data issue unrelated to this task.

## Self-Check

Files created:
- benchmarks/scripts/compare-scoring.mjs -- FOUND

Commits:
- d013f3b -- FOUND (feat(quick-32): build scoring algorithm comparison tool)

Verification:
- `node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26` -- produces readable markdown output
- ava ~96.5 -- confirmed (96.5)
- sequelize ~91.2 -- confirmed (91.2)
- biome ~98.8 -- confirmed (98.8)
- Distribution stats show spread for each algorithm -- confirmed
- `--json` flag writes valid JSON -- confirmed

## Self-Check: PASSED
