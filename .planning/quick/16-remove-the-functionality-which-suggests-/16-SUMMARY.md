---
phase: quick-16
plan: 01
subsystem: cli/init
tags: [simplification, removal, documentation]
dependency_graph:
  requires: []
  provides: ["simplified --init that always writes default config"]
  affects: ["src/cli/init.zig", "src/main.zig", "docs/health-score.md", "docs/cli-reference.md", "docs/getting-started.md", "docs/examples.md"]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - src/cli/init.zig
    - src/main.zig
    - docs/health-score.md
    - docs/cli-reference.md
    - docs/getting-started.md
    - docs/examples.md
decisions:
  - "--init simplified to write default config without any codebase analysis"
  - "runEnhancedInit, optimizeWeights, computeScoreWithWeights, normalizeWeights removed entirely"
  - "--init handler moved before analysis loop in main.zig (no analysis needed)"
metrics:
  duration: "2 min"
  completed: "2026-02-17"
  tasks_completed: 2
  files_modified: 6
---

# Quick Task 16: Remove weight optimization suggestion from --init

**One-liner:** Removed coordinate descent weight optimization from --init; flag now always writes default config immediately without analyzing the codebase.

## What Was Done

Removed the weight optimization/suggestion functionality from the `--init` flag. The flag previously had two paths:
- With source path: analyzed codebase, ran coordinate descent to suggest optimized weights, wrote config with suggested weights + baseline
- Without source path: wrote default config

Now `--init` always writes a default config and exits immediately, with no codebase analysis.

## Changes

### src/cli/init.zig

Removed four functions:
- `runEnhancedInit` — the analysis-aware init wrapper
- `computeScoreWithWeights` — scored functions with given weights
- `optimizeWeights` — coordinate descent optimizer
- `normalizeWeights` — normalized four weights to sum to 1.0

Removed unused imports: `scoring`, `MetricThresholds`, `EffectiveWeights`.

Simplified `generateJsonConfig`: removed `weights: ?EffectiveWeights` and `baseline: ?f64` parameters. The function now always writes default weights (the former `else` branch) and never writes a `baseline` field.

Removed tests for removed functions:
- "generateJsonConfig with weights and baseline includes them"
- "optimizeWeights returns normalized weights summing to 1.0"
- "normalizeWeights sums to 1.0"
- "normalizeWeights all-zero returns equal weights"

Updated `generateJsonConfig` test call to remove the null params.

### src/main.zig

Moved `--init` handler to immediately after `merge.mergeArgsIntoConfig`, before file discovery and analysis. The handler now calls `init.runInit(arena_allocator)` directly and returns. The old post-analysis block (which collected all_results_list and called runEnhancedInit) was removed entirely.

### Documentation

- **docs/health-score.md**: Removed "Enhanced --init" section and "How the Optimization Works" subsection (24 lines)
- **docs/cli-reference.md**: Simplified `--init` description to single-path workflow with concise description
- **docs/getting-started.md**: Simplified --init description in two locations — removed references to "suggested weights", "optimized config", "before/after comparison"
- **docs/examples.md**: Updated comment and command in Baseline + Ratchet Workflow example

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

### Files Exist
- src/cli/init.zig: FOUND
- src/main.zig: FOUND
- docs/health-score.md: FOUND
- docs/cli-reference.md: FOUND
- docs/getting-started.md: FOUND
- docs/examples.md: FOUND

### Commits Exist
- 7425c3c: feat(quick-16): simplify --init to always write default config
- 3b29c03: docs(quick-16): update documentation to reflect simplified --init

### Verification
- `zig build test`: PASSED
- `grep -r "runEnhancedInit|optimizeWeights|normalizeWeights|computeScoreWithWeights" src/`: no matches
- `grep -ri "suggested weights|optimized weights|coordinate descent|enhanced.*init" docs/`: no matches

## Self-Check: PASSED
