---
phase: 11-duplication-detection
plan: 03
subsystem: output
tags: [duplication, console-output, json-output, sarif-output, html-output, clone-groups, heatmap]

# Dependency graph
requires:
  - phase: 11-01
    provides: DuplicationResult, CloneGroup, CloneLocation, FileDuplicationResult types
  - phase: 11-02
    provides: dup_result wired in main.zig pipeline, duplication_enabled flag
provides:
  - formatDuplicationSection in console.zig (clone groups + file/project percentages)
  - JsonDuplication/JsonCloneGroup/JsonCloneLocation/JsonFileDuplication structs in json_output.zig
  - Duplication field in JSON output (enabled/project_status/clone_groups/files)
  - RULE_DUPLICATION (index 10) and relatedLocations in SARIF output
  - writeDuplicationSection in html_output.zig (clone table, file list, adjacency heatmap)
affects: [main.zig, all-four-output-formats]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Optional DuplicationResult parameter pattern: all 3 output functions (JSON/SARIF/HTML) accept ?DuplicationResult; null means disabled"
    - "SARIF relatedLocations for clone groups: one result per group, first location as primary, rest as relatedLocations with sequential IDs"
    - "Adjacency heatmap: shared_tokens[i][j] matrix built from clone group cross-file pairs; orange-to-red intensity CSS rgba"
    - "Exit code integration via main.zig: duplication violations already counted in total_warnings/total_errors (Plan 02); no changes to exit_codes.zig needed"

key-files:
  created: []
  modified:
    - src/output/console.zig
    - src/output/json_output.zig
    - src/output/sarif_output.zig
    - src/output/html_output.zig
    - src/main.zig

key-decisions:
  - "Exit codes: Plan 02 already counts duplication violations into total_warnings/total_errors — no changes to determineExitCode or exit_codes.zig needed (simpler approach per plan)"
  - "SARIF relatedLocations: one result per clone group (not per instance), primary = first location, related = remaining with 'Clone instance N' messages"
  - "HTML heatmap uses explicit `const n: usize = if (len > 10) 10 else len` instead of @min() to avoid Zig comptime integer overflow in debug builds"
  - "RGB color clamping in heatmap: use @min(255.0, ...) and @max(0.0, ...) before @intFromFloat to prevent u8 overflow at max intensity"
  - "Quiet mode duplication: show only error-level files in file duplication list; return early from entire section if no project/file errors"

requirements-completed: [DUP-06, DUP-07]

# Metrics
duration: 10min
completed: 2026-02-22
---

# Phase 11 Plan 03: Output Format Integration Summary

**Duplication results integrated into all four output formats: console (clone groups + percentages), JSON (structured duplication object), SARIF (rule with relatedLocations for GitHub Code Scanning), and HTML (clone table + file list + adjacency heatmap)**

## Performance

- **Duration:** 10 min
- **Started:** 2026-02-22T18:25:18Z
- **Completed:** 2026-02-22T18:35:16Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `formatDuplicationSection` to `console.zig`: prints "Duplication" header, clone groups as `Clone group (N tokens): path:line, path:line`, file duplication percentages with [OK]/[WARNING]/[ERROR] indicators, and project duplication summary; respects verbosity (quiet mode shows only errors) and color (yellow for warning, red for error)
- Added `JsonDuplication`, `JsonCloneGroup`, `JsonCloneLocation`, `JsonFileDuplication` structs to `json_output.zig`; updated `buildJsonOutput` to accept optional `?DuplicationResult` and populate the `duplication` field when provided (null otherwise)
- Added `RULE_DUPLICATION` (index 10) rule definition and `SarifRelatedLocation` struct to `sarif_output.zig`; `buildSarifOutput` now accepts optional `?DuplicationResult` and emits one SARIF result per clone group with primary location + `relatedLocations` array pointing to all other instances
- Added `writeDuplicationSection` to `html_output.zig`: project summary badge, sortable clone groups table, file duplication list with percentage bars (sorted descending, top 20 files), and adjacency heatmap (10x10 max, orange-to-red intensity for shared clone tokens between file pairs); added duplication CSS to the embedded stylesheet
- Updated `main.zig` to pass `dup_result` to `buildJsonOutput`, `buildSarifOutput`, `buildHtmlReport`, and added `formatDuplicationSection` call after `formatSummary` in console path
- All 323 tests pass; runtime verified: console shows Duplication section, JSON includes duplication object, SARIF has duplication rule with relatedLocations, HTML generates with clone table and heatmap, no output when `--duplication` not specified

## Task Commits

1. **Task 1: Console, JSON, exit codes** - `be63b2d` (feat)
2. **Task 2: SARIF with relatedLocations, HTML with heatmap** - `66cfb05` (feat)

## Files Created/Modified

- `src/output/console.zig` - Added `formatDuplicationSection` function and 2 tests; imported `duplication` module
- `src/output/json_output.zig` - Added `JsonDuplication`/`JsonCloneGroup`/`JsonCloneLocation`/`JsonFileDuplication` structs; updated `buildJsonOutput` with optional `dup_result` param; added 2 tests; updated all 9 existing test call sites to pass `null`
- `src/output/sarif_output.zig` - Added `RULE_DUPLICATION` constant; added `SarifRelatedLocation` struct; added duplication rule to `buildRules`; updated `buildSarifOutput` with optional `dup_result` param and clone group emission logic; added 2 tests; updated all 8 existing test call sites to pass `null`
- `src/output/html_output.zig` - Added duplication CSS; added `writeDuplicationSection` function with clone table, file list, heatmap; updated `buildHtmlReport` with optional `dup_result` param; added 2 tests; updated all 3 existing test call sites to pass `null`; imported `duplication` module
- `src/main.zig` - Updated `buildJsonOutput`, `buildSarifOutput`, `buildHtmlReport` calls to pass `dup_result`; added `formatDuplicationSection` call in console path

## Decisions Made

- Exit codes: No changes to `exit_codes.zig` needed — Plan 02 already added duplication violations to `total_warnings`/`total_errors` in `main.zig` before `determineExitCode` is called
- SARIF `relatedLocations` follows CONTEXT.md spec: one result per clone group, first instance as primary location, remaining as `relatedLocations[0..n-2]` with `id` starting at 1 and `message.text: "Clone instance N"`
- HTML heatmap limited to top 10 files × top 10 files for readability (10x10 matrix); top 20 files shown in file duplication list sorted by descending percentage

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Integer overflow in HTML heatmap matrix size**
- **Found during:** Task 2 (runtime test of `--duplication --format html`)
- **Issue:** `const matrix_size = n * n` where `n = @min(10, len)` triggered integer overflow panic in debug builds — Zig's comptime integer arithmetic behaved unexpectedly with the `@min` return type
- **Fix:** Changed to `const n: usize = if (len > 10) 10 else len` with explicit `usize` type annotation; changed `matrix_size` to `const matrix_size: usize = n * n`
- **Files modified:** `src/output/html_output.zig`

**2. [Rule 1 - Bug] u8 overflow in heatmap RGBA color computation**
- **Found during:** Task 2 (same runtime crash investigation)
- **Issue:** `@intFromFloat(220.0 + 35.0 * intensity)` could produce value > 255 when cast to u8
- **Fix:** Added `@min(255.0, ...)` and `@max(0.0, ...)` clamping before `@intFromFloat`
- **Files modified:** `src/output/html_output.zig`

**3. [Rule 1 - Bug] Unused capture `_group_idx` in SARIF duplication loop**
- **Found during:** Task 2 (first compile attempt)
- **Issue:** Zig treats unused captures as compilation errors
- **Fix:** Changed `for (dup.clone_groups, 0..) |group, _group_idx|` to `for (dup.clone_groups) |group|`
- **Files modified:** `src/output/sarif_output.zig`

**4. [Rule 1 - Bug] Test for quiet mode used clone group that referenced both files**
- **Found during:** Task 1 (test run — `formatDuplicationSection: quiet mode` test failure)
- **Issue:** Clone group output always shows all file paths (not filtered by severity), so `src/b.ts` appeared in the clone group line even though the test expected it not to appear
- **Fix:** Updated test to use empty `clone_groups` slice so no cross-file references appear; the test now correctly verifies only file-level severity filtering
- **Files modified:** `src/output/console.zig`

---

**Total deviations:** 4 auto-fixed (all Rule 1 bugs)
**Impact on plan:** All fixes were trivial correctness issues. No scope changes.

## Issues Encountered

None beyond the auto-fixed deviations above.

## Next Phase Readiness

- All four output formats (console, JSON, SARIF, HTML) support duplication when `--duplication` is enabled
- DUP-06 and DUP-07 complete across all output formats
- Plan 04 (performance benchmarking + docs) can proceed

## Self-Check: PASSED

- FOUND: src/output/console.zig (formatDuplicationSection)
- FOUND: src/output/json_output.zig (JsonDuplication struct, duplication field in JsonOutput)
- FOUND: src/output/sarif_output.zig (RULE_DUPLICATION=10, SarifRelatedLocation, duplication rule)
- FOUND: src/output/html_output.zig (writeDuplicationSection, buildHtmlReport with dup_result)
- FOUND: .planning/phases/11-duplication-detection/11-03-SUMMARY.md
- FOUND commit: be63b2d (Task 1)
- FOUND commit: 66cfb05 (Task 2)
- `zig build test` exit code: 0 (all 323 tests pass)
- Console --duplication: shows Duplication section with clone groups and file percentages
- JSON --duplication: duplication field present with enabled=true, clone_groups, files
- SARIF --duplication: complexity-guard/duplication rule with relatedLocations
- HTML --duplication: duplication-section div with Clone Groups table and heatmap
- Without --duplication: no Duplication output in any format confirmed

---
*Phase: 11-duplication-detection*
*Completed: 2026-02-22*
