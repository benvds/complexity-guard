---
phase: 09-sarif-output
plan: 01
subsystem: output
tags: [sarif, github-code-scanning, json-output, zig]

# Dependency graph
requires:
  - phase: 08-composite-health-score
    provides: health_score field on ThresholdResult, baseline ratchet enforcement
  - phase: 07-halstead-structural
    provides: FileThresholdResults type, halstead/structural ThresholdResult fields
  - phase: 05-console-json-output
    provides: console.zig patterns, FileThresholdResults struct, json_output.zig serialization pattern
provides:
  - SARIF 2.1.0 output format via --format sarif
  - SarifLog/SarifRun/SarifResult struct hierarchy
  - 10 rule definitions with full descriptions and remediation advice
  - buildSarifOutput maps ThresholdResult violations to SARIF results with 1-indexed columns
  - serializeSarifOutput produces standards-compliant JSON
  - Baseline ratchet failure emits file-level health-score SARIF results
  - --metrics flag filtering applies to SARIF results
affects:
  - 09-02 (docs/cli-reference.md, --format sarif documentation, examples)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SARIF 2.1.0 struct hierarchy maps 1:1 to JSON schema using Zig @"$schema" keyword syntax
    - allocPrint for dynamic SARIF message strings (requires explicit free in tests)
    - Baseline check moved before format dispatch so SARIF output can include ratchet results
    - isMetricEnabled duplicated in sarif_output.zig (avoids circular imports from console.zig)

key-files:
  created:
    - src/output/sarif_output.zig
  modified:
    - src/main.zig

key-decisions:
  - "SARIF startColumn is 1-indexed: internal 0-indexed start_col + 1 in every SARIF result"
  - "Baseline ratchet check moved before format dispatch: enables SARIF baseline result emission"
  - "All 10 rules always included in driver.rules regardless of --metrics flag (filtering only applies to results)"
  - "Baseline health-score results only emitted for files with at least one metric violation (avoids noise)"
  - "allocPrint for SARIF message strings: requires explicit allocator.free in test cleanup alongside locations"

patterns-established:
  - "SARIF struct pattern: SarifLog->SarifRun->SarifResult with @\"$schema\" Zig keyword escape"
  - "isMetricEnabled duplicated across output modules to avoid circular imports"
  - "SARIF column indexing: always +1 from internal 0-indexed start_col"

requirements-completed: [OUT-SARIF-01, OUT-SARIF-02, OUT-SARIF-03, OUT-SARIF-04]

# Metrics
duration: 6min
completed: 2026-02-18
---

# Phase 9 Plan 01: SARIF Output Module Summary

**SARIF 2.1.0 output via `--format sarif` with 10 rule definitions, violation mapping with 1-indexed columns, baseline ratchet integration, and --metrics filtering for GitHub Code Scanning**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-18T06:33:43Z
- **Completed:** 2026-02-18T06:40:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `src/output/sarif_output.zig` with complete SARIF 2.1.0 struct hierarchy (12 struct types)
- Defined 10 rule definitions with full descriptions, remediation advice, and helpUri links
- `buildSarifOutput` iterates all metric families and maps violations to typed SARIF results with correct 1-indexed columns
- Baseline ratchet failures emit file-level health-score SARIF results at startLine 1 with violation counts
- `--metrics` flag filtering limits which metric violations appear in SARIF output
- Wired SARIF dispatch into `main.zig` with moved baseline check and complete SarifThresholds from config
- 8 inline tests covering envelope, passing functions, violations, column indexing, multiple metrics, baseline, filtering, and JSON serialization

## Task Commits

1. **Task 1: Implement SARIF output module** - `2ce01bd` (feat)
2. **Task 2: Wire SARIF into main.zig format dispatch + fix memory leaks** - `1b7ce24` (feat)

## Files Created/Modified
- `src/output/sarif_output.zig` - SARIF 2.1.0 structs, 10 rules, build/serialize functions, 8 tests
- `src/main.zig` - sarif_output import, baseline check relocated before dispatch, SARIF else-if branch, test import

## Decisions Made
- SARIF startColumn is always 1-indexed: `result.start_col + 1` in every emitted result (SARIF spec requirement)
- Baseline ratchet check moved from after format dispatch to before: this allows `buildSarifOutput` to receive `baseline_failed` and include health-score results in the SARIF output
- All 10 rules always appear in `driver.rules` array regardless of `--metrics` filtering (rules describe what ComplexityGuard can detect; only `results` are filtered)
- File-level baseline health-score results only emitted for files with at least one metric violation — avoids flooding with health-score annotations for files that merely exist
- `allocPrint` message strings require explicit `allocator.free(r.message.text)` in test cleanup alongside `allocator.free(r.locations)`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed memory management: free allocPrint message strings in test cleanup**
- **Found during:** Task 1 (first test run after implementing sarif_output)
- **Issue:** Test cleanup freed `r.locations` but not `r.message.text` allocated via `std.fmt.allocPrint`, causing 5 memory leaks detected by `std.testing.allocator`
- **Fix:** Added `allocator.free(r.message.text)` to all test defer blocks that have violation results
- **Files modified:** src/output/sarif_output.zig
- **Verification:** `zig build test` reports 0 leaked after fix
- **Committed in:** `1b7ce24` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Required fix for correct memory management in tests. No scope creep.

## Issues Encountered
- Python `json.load(sys.stdin)` failed with "Extra data" error when piping from `zig build run` because the binary exits non-zero (violations found) and the shell emits two lines. Fixed by using `sys.stdin.read()` then `json.loads()` pattern, or piping stdout separately with `2>/dev/null`.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SARIF output fully functional for GitHub Code Scanning integration
- `--format sarif` produces standards-compliant SARIF 2.1.0 JSON
- Ready for 09-02: documentation updates (docs/, README, cli-reference)

---
*Phase: 09-sarif-output*
*Completed: 2026-02-18*
