---
phase: 06-cognitive-complexity
plan: 02
subsystem: metrics
tags: [cognitive-complexity, cyclomatic, console-output, json-output, pipeline]

# Dependency graph
requires:
  - phase: 06-01
    provides: cognitive.analyzeFunctions, CognitiveFunctionResult, cognitive.analyzeFile, ThresholdResult with cognitive fields

provides:
  - main.zig pipeline running both cyclomatic and cognitive analysis, merged into ThresholdResult
  - console.zig side-by-side metric display with separate cyclomatic and cognitive hotspot lists
  - json_output.zig with populated cognitive field (non-null)
  - exit_codes.zig violation counting using worst-of-both-metrics status

affects:
  - 06-03 (documentation phase uses cognitive output formats)
  - future phases adding more metrics to pipeline

# Tech tracking
tech-stack:
  added: []
  patterns:
    - worst-status merge pattern for combining two metric statuses (error > warning > ok)
    - index-aligned merge: cyclomatic and cognitive walkers produce same-order results, merge by index

key-files:
  created: []
  modified:
    - src/main.zig
    - src/output/console.zig
    - src/output/json_output.zig
    - src/output/exit_codes.zig

key-decisions:
  - "Worst-of-both-metrics for exit codes: a function with cyclomatic=ok but cognitive=error counts as error"
  - "Index alignment for merging: both cyclomatic and cognitive walkers process same tree in same order"
  - "Side-by-side format per function: 'Function name cyclomatic N cognitive N' on one line"
  - "Separate hotspot lists: Top cyclomatic hotspots and Top cognitive hotspots"
  - "cognitive field in JSON: u32 value (not null) since Phase 6 pipeline always computes it"

patterns-established:
  - "worstStatus helper: shared pattern in exit_codes.zig, console.zig, json_output.zig for combining metric statuses"
  - "Per-file cognitive analysis: run cognitive.analyzeFunctions on same tree root used by cyclomatic"

requirements-completed: [COGN-09]

# Metrics
duration: 4min
completed: 2026-02-17
---

# Phase 6 Plan 02: Pipeline Integration for Cognitive Complexity Summary

**Cognitive complexity integrated as first-class metric: side-by-side console output, separate hotspot lists, non-null JSON cognitive field, and combined exit codes using worst of cyclomatic/cognitive status.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-17T08:06:15Z
- **Completed:** 2026-02-17T08:10:36Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- main.zig now runs cognitive.analyzeFunctions for each file alongside cyclomatic and merges results by index alignment
- Console output shows `Function 'name' cyclomatic N cognitive N` on each function line, using worst status for symbol/color/severity
- Summary shows two separate hotspot lists: "Top cyclomatic hotspots" and "Top cognitive hotspots" sorted independently
- JSON output populates the `cognitive` field from `cognitive_complexity` (previously hardcoded null)
- Exit codes reflect worst of cyclomatic and cognitive: cognitive-only errors produce non-zero exit codes
- Configurable cognitive thresholds read from config file with fallback to defaults (warning=15, error=25)

## Task Commits

1. **Task 1: Pipeline integration — main.zig and exit_codes.zig** - `92a2b61` (feat)
2. **Task 2: Console and JSON output integration** - `557b624` (feat)

**Plan metadata:** (included in final commit)

## Files Created/Modified

- `src/main.zig` - Added cognitive import, CognitiveConfig from config, per-file cognitive analysis, index-aligned merge into ThresholdResult
- `src/output/exit_codes.zig` - Added worstStatus helper, updated countViolations to use worst of cyclomatic/cognitive status
- `src/output/console.zig` - Added worstStatus helper, side-by-side format, worst-status for symbol/color, separate hotspot lists
- `src/output/json_output.zig` - Added worstStatus helper, populated cognitive field, status from worst metric

## Decisions Made

- Worst-of-both-metrics approach: a function that passes cyclomatic but fails cognitive still counts as a violation for exit codes and display status
- Index alignment for merge: both analysis walkers process the same AST in the same top-level function order, so pairing by index is correct
- Side-by-side on one line (not two separate lines per function) keeps output compact
- Cognitive thresholds from config file use `orelse` fallback since ThresholdPair fields are `?u32`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed optional type handling for ThresholdPair cognitive thresholds**
- **Found during:** Task 1 (pipeline integration in main.zig)
- **Issue:** ThresholdPair.warning and .error fields are `?u32` not `u32`, causing compile error
- **Fix:** Added `orelse default_cog.warning_threshold` / `orelse default_cog.error_threshold` fallbacks
- **Files modified:** src/main.zig
- **Verification:** zig build test passes, zig build run works
- **Committed in:** 92a2b61 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — optional type mismatch)
**Impact on plan:** Minor compile-time fix, no scope change.

## Issues Encountered

None beyond the optional type issue above.

## Next Phase Readiness

- Cognitive complexity is now fully integrated as a first-class metric visible to users
- Console shows both metrics per function with worst-case status indicators
- JSON output has non-null cognitive values for downstream tooling
- Exit codes correctly reflect cognitive violations
- Plan 03 (documentation) can reference actual output format since it is now stable

---
*Phase: 06-cognitive-complexity*
*Completed: 2026-02-17*
