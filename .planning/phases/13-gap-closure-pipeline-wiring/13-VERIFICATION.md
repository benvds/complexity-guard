---
phase: 13-gap-closure-pipeline-wiring
verified: 2026-02-22T22:00:00Z
status: passed
score: 6/6 must-haves verified
re_verification:
  previous_status: gaps_found (UAT Test 4)
  previous_score: 3/4 UAT tests passed
  gaps_closed:
    - "--save-baseline removed entirely from source code and documentation"
    - "--init generates config with all 12 threshold categories, files.include, duplication weight 0.20, and baseline placeholder"
  gaps_remaining: []
  regressions: []
gaps: []
human_verification: []
---

# Phase 13: Gap Closure Pipeline Wiring — Verification Report

**Phase Goal:** Close all requirement, integration, and flow gaps found by v1.0 milestone audit and UAT
**Verified:** 2026-02-22T22:00:00Z
**Status:** PASSED
**Re-verification:** Yes — after UAT gap closure (plans 13-02 and 13-03)

## Summary

UAT identified one gap in plan 13-01's verification: `--save-baseline` was claimed to write `duplication: 0.20` in the config, but the user reported the feature should be removed entirely and `--init` should generate a complete config instead. Plans 13-02 and 13-03 addressed both issues. This re-verification confirms all six observable truths now hold.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Config file cyclomatic thresholds override the hardcoded defaults (warning=10, error=20) | VERIFIED | `buildCyclomaticConfig` at `src/main.zig:102` reads `thresholds.cyclomatic.warning/.error`, falls back to `CyclomaticConfig.default()` for null. Called at line 247. Three targeted tests in `src/main.zig` verify threshold override, null fallback, and partial override. |
| 2 | `--metrics` flag gates which metric families drive exit codes (not just display) | VERIFIED | `countViolationsFiltered` at `src/output/exit_codes.zig:126` uses `worstStatusForMetrics` (line 102) to filter by enabled families. Called from sequential path (`src/main.zig:485`) and parallel path (`src/pipeline/parallel.zig:240`) both passing `parsed_metrics`. |
| 3 | `--no-duplication` flag prevents duplication detection from running | VERIFIED | Guard at `src/main.zig:298-301` checks `cfg.analysis.no_duplication` at the TOP of the `duplication_enabled` block, overrides both `duplication_enabled` config and `--metrics duplication`. |
| 4 | `--save-baseline` flag is not recognized by the CLI (removed entirely) | VERIFIED | Zero matches for `save_baseline` or `save-baseline` in all of `src/`. `CliArgs` struct has no `save_baseline` field; `writeDefaultConfigWithBaseline` function is gone from `src/main.zig`; `--save-baseline` help text removed from `src/cli/help.zig`. Build passes with no errors. |
| 5 | `--init` generates config with ALL 12 threshold categories | VERIFIED | `src/cli/init.zig` `generateJsonConfig` emits all 12 categories: cyclomatic, cognitive, halstead_volume, halstead_difficulty, halstead_effort, halstead_bugs, nesting_depth, line_count, params_count, file_length, export_count, duplication (with file_warning/file_error/project_warning/project_error). `generateTomlConfig` emits the equivalent TOML. |
| 6 | `--init` generates config with duplication weight 0.20, files.include patterns, and baseline placeholder | VERIFIED | `src/cli/init.zig:70` emits `"duplication": 0.20` in weights; line 64 emits `"include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"]`; line 74 emits `"baseline": null`. TOML equivalent at lines 155, 149, 159. |

**Score:** 6/6 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/main.zig` | `buildCyclomaticConfig` helper, `--no-duplication` gate, `--init` handler, NO `writeDefaultConfigWithBaseline`, NO `save_baseline` handler | VERIFIED | `buildCyclomaticConfig` at line ~102; `no_duplication` guard at ~298; `--init` handler at lines 164-166 calling `init.runInit`; zero matches for `save_baseline` or `writeDefaultConfigWithBaseline`. |
| `src/output/exit_codes.zig` | `worstStatusForMetrics` and `countViolationsFiltered` functions | VERIFIED | Both present; `worstStatusForMetrics` at line 102; `countViolationsFiltered` at line 126. Original `worstStatusAll` and `countViolations` preserved unchanged. |
| `src/pipeline/parallel.zig` | Parallel path passes `parsed_metrics` to `countViolationsFiltered` | VERIFIED | `WorkerContext.parsed_metrics` field at line 49; passed to `countViolationsFiltered` at line 240. |
| `src/cli/args.zig` | CliArgs struct without `save_baseline` field | VERIFIED | Zero matches for `save_baseline` or `save-baseline` in `src/cli/args.zig`. |
| `src/cli/help.zig` | Help text without `--save-baseline` line | VERIFIED | Zero matches for `save` in `src/cli/help.zig`. |
| `src/cli/init.zig` | Complete config generation with all 12 threshold categories, no ThresholdPreset struct | VERIFIED | All 12 categories confirmed present by grep; `ThresholdPreset` and `getThresholdPreset` absent; `generateJsonConfig(allocator, filename)` signature simplified; two tests updated to check for `halstead_volume`, `nesting_depth`, `file_length`, `duplication`, `include`, `baseline`. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/main.zig` | `src/output/exit_codes.zig` | `countViolationsFiltered` call with `parsed_metrics` | WIRED | `exit_codes.countViolationsFiltered(cycl_results, parsed_metrics)` at `src/main.zig:485` |
| `src/pipeline/parallel.zig` | `src/output/exit_codes.zig` | `countViolationsFiltered` call with `ctx.parsed_metrics` | WIRED | `exit_codes.countViolationsFiltered(cycl_results, ctx.parsed_metrics)` at `src/pipeline/parallel.zig:240` |
| `src/main.zig buildCyclomaticConfig` | `src/metrics/cyclomatic.zig CyclomaticConfig` | Builds config from `ThresholdsConfig.cyclomatic ThresholdPair` | WIRED | Function reads `thresholds.cyclomatic` optional; called at line 247 |
| `src/main.zig` | `src/cli/init.zig runInit` | `--init` handler calls `init.runInit(arena_allocator)` | WIRED | `src/main.zig:165-166`; `init` imported at line 8 |
| `src/cli/init.zig generateJsonConfig` | `src/cli/config.zig ThresholdsConfig` | Generated config covers all 12 ThresholdsConfig fields | WIRED | All 12 categories confirmed by grep; function signature simplified to `(allocator, filename)` |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CYCL-09 | 13-01-PLAN.md | Tool applies configurable warning (default 10) and error (default 20) thresholds | SATISFIED | `buildCyclomaticConfig` reads config thresholds; replaces hardcoded `.default()`. Marked Complete in REQUIREMENTS.md traceability table (line 220). |
| CFG-04 | 13-01-PLAN.md, 13-03-PLAN.md | User can set per-metric warning and error thresholds in config file | SATISFIED | All threshold types wired. `--init` now generates complete config with all 12 categories so users can discover and set every threshold. Marked Complete in REQUIREMENTS.md (line 202). |
| CLI-07 | 13-01-PLAN.md | User can select specific metrics via `--metrics` flag | SATISFIED | `countViolationsFiltered` gates exit code counting by enabled metric families; both sequential and parallel paths updated. Marked Complete in REQUIREMENTS.md (line 193). |
| CLI-08 | 13-01-PLAN.md, 13-02-PLAN.md | User can skip duplication via `--no-duplication` flag | SATISFIED | `no_duplication` guard at top of `duplication_enabled` block in `src/main.zig`. `--save-baseline` fully removed (user-reported scope expansion for CLI-08 gap). Marked Complete in REQUIREMENTS.md (line 194). |

All 4 requirement IDs (`CYCL-09`, `CFG-04`, `CLI-07`, `CLI-08`) accounted for. Zero orphaned requirements. REQUIREMENTS.md traceability table lists all four under Phase 13 with status Complete.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No TODO/FIXME/placeholder comments or stub patterns found in any modified file. |

Spot-check results (plans 13-02 and 13-03 additions):
- `save_baseline` field or handler anywhere in `src/`: ABSENT — zero matches across entire `src/` tree.
- `save-baseline` in `docs/`: ABSENT — zero matches across `docs/` directory.
- `ThresholdPreset` struct in `src/cli/init.zig`: ABSENT — removed as planned.
- All 12 threshold categories in `generateJsonConfig`: PRESENT — confirmed by grep for each category name.
- `"duplication": 0.20` in `generateJsonConfig` weights block: PRESENT at line 70.
- `"baseline": null` in `generateJsonConfig`: PRESENT at line 74.
- `"include"` patterns in `generateJsonConfig`: PRESENT at line 64.

---

### Build and Test Results

- `zig build`: Exit 0, no errors, no warnings.
- `zig build test`: Exit 0, all tests pass (8 new tests from plan 13-01; 2 updated tests in `src/cli/init.zig` from plan 13-03; threshold preset tests removed as planned).

---

### Commits Verified

| Commit | Description | Status |
|--------|-------------|--------|
| `d7413d5` | feat(13-01): wire four pipeline gaps in main.zig, exit_codes.zig, parallel.zig | FOUND |
| `3ef6b35` | test(13-01): add targeted tests for all four pipeline gap fixes | FOUND |
| `35fdc00` | feat(13-02): remove --save-baseline from source code | FOUND |
| `8c6ec17` | docs(13-02): remove --save-baseline from documentation | FOUND |
| `608d185` | feat(13-03): expand --init to generate complete config with all 12 threshold categories | FOUND |
| `29c70b8` | docs(13-03): update --init description to reflect complete config generation | FOUND |

---

### Human Verification Required

None. All truths are testable programmatically. The UAT already confirmed runtime behavior for three originally-passing tests. The two new truths (save-baseline removal and --init expansion) were scope-expanded from user feedback and are verified structurally here.

---

### Gap Summary

No gaps found. The UAT-identified gap (Test 4) has been fully resolved across two additional plans:

1. **Plan 13-02 (--save-baseline removal)** — The flag, its `CliArgs` field, its arg parser branch, its `main.zig` handler block, its `writeDefaultConfigWithBaseline` helper, and its help text are all gone. Docs updated across `docs/cli-reference.md`, `docs/health-score.md`, `docs/getting-started.md`, and `docs/examples.md` to document manual config editing as the baseline workflow.

2. **Plan 13-03 (--init expansion)** — `generateJsonConfig` and `generateTomlConfig` now emit all 12 threshold categories, `files.include` patterns, all 5 metric weights (including `duplication: 0.20`), and a `baseline: null` placeholder. `ThresholdPreset` struct removed. Function signatures simplified to `(allocator, filename)`. Two tests updated to verify the expanded output.

All 6 observable truths hold. All 4 phase requirements are satisfied and marked Complete in REQUIREMENTS.md.

---

_Verified: 2026-02-22T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — after UAT gap closure via plans 13-02 and 13-03_
