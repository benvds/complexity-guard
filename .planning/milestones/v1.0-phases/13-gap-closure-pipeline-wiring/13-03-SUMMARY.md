---
phase: 13-gap-closure-pipeline-wiring
plan: "03"
subsystem: cli/init
tags: [init, config-generation, thresholds, documentation]
dependency_graph:
  requires: ["13-02"]
  provides: ["complete-init-config"]
  affects: ["src/cli/init.zig", "docs/cli-reference.md"]
tech_stack:
  added: []
  patterns: ["hand-rolled config string generation", "simplified function signatures"]
key_files:
  created: []
  modified:
    - src/cli/init.zig
    - docs/cli-reference.md
decisions:
  - "--init hardcodes all 12 threshold defaults directly in generateJsonConfig/generateTomlConfig (no preset struct needed)"
  - "ThresholdPreset struct and getThresholdPreset removed: only covered 2 of 12 categories, no longer needed"
  - "generateJsonConfig/generateTomlConfig simplified to (allocator, filename) — all values hardcoded"
  - "halstead_bugs uses integer defaults (1, 2) matching ThresholdPair u32 schema (not f64 0.5/2.0)"
  - "baseline: null in JSON output serves as placeholder for users to set their own threshold"
  - "TOML baseline commented out (# baseline = 75.0) showing syntax without activating enforcement"
metrics:
  duration: 1 min
  completed: 2026-02-22T21:59:00Z
  tasks_completed: 2
  files_modified: 2
---

# Phase 13 Plan 03: --init Expansion Summary

One-liner: Expanded --init to emit all 12 threshold categories with sensible defaults, serving as documentation-by-example for every configurable option.

## What Was Built

The `--init` command previously generated configs with only cyclomatic and cognitive thresholds (2 of 12 categories). This plan expanded `generateJsonConfig` and `generateTomlConfig` in `src/cli/init.zig` to produce complete configs covering all available options.

### Changes

**`src/cli/init.zig`**

- Removed `ThresholdPreset` struct and `getThresholdPreset` function entirely (only covered cyclomatic/cognitive)
- Simplified `generateJsonConfig(allocator, filename)` — all defaults hardcoded directly
- Simplified `generateTomlConfig(allocator, filename)` — same simplification
- Updated `runInit` to use the new simplified signatures (no more preset or exclude_patterns params)
- Removed old preset tests (`getThresholdPreset returns all strictness levels`, `moderate preset has expected values`)
- Updated `generateJsonConfig` test to verify: `halstead_volume`, `nesting_depth`, `file_length`, `duplication`, `include`, `baseline`
- Updated `generateTomlConfig` test to verify: `halstead_volume`, `nesting_depth`, `file_length`, `duplication`, `include`

**`docs/cli-reference.md`**

- Updated `--init` flag description to mention all available options and comprehensive coverage
- Updated post-example description to name all 12 threshold categories explicitly

### Generated JSON Config (complete)

The generated `.complexityguard.json` now includes:
- All 11 standard ThresholdPair entries (cyclomatic, cognitive, halstead_volume, halstead_difficulty, halstead_effort, halstead_bugs, nesting_depth, line_count, params_count, file_length, export_count)
- Duplication thresholds (file_warning, file_error, project_warning, project_error)
- `files.include` with four standard TS/JS glob patterns
- All 5 weights including `duplication: 0.20`
- `baseline: null` placeholder

## Deviations from Plan

None - plan executed exactly as written.

## Verification

1. `zig build test` — all tests pass (no output = success)
2. `complexity-guard --init` in /tmp — generates complete JSON with all 12 threshold categories
3. Generated config includes `files.include`, `duplication` weight 0.20, and `baseline: null`
4. docs/cli-reference.md `--init` description accurately reflects the new complete config output

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 608d185 | feat(13-03): expand --init to generate complete config with all 12 threshold categories |
| Task 2 | 29c70b8 | docs(13-03): update --init description to reflect complete config generation |

## Self-Check: PASSED

- [x] `src/cli/init.zig` exists and modified
- [x] `docs/cli-reference.md` exists and modified
- [x] Commit 608d185 exists
- [x] Commit 29c70b8 exists
- [x] All tests pass
- [x] Generated config has all 12 threshold categories
