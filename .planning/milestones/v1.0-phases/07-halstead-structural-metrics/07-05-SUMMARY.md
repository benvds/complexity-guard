---
phase: 07-halstead-structural-metrics
plan: 05
subsystem: output
tags: [zig, console-output, metrics-filtering, cli]

requires:
  - phase: 07-halstead-structural-metrics
    provides: parsed_metrics in main.zig and console.zig output layer

provides:
  - OutputConfig.selected_metrics field wires --metrics flag to output layer
  - isMetricEnabled helper in console.zig gates all display sections
  - Per-function detail lines filtered by selected metric families
  - Hotspot sections (cyclomatic/cognitive/Halstead) filtered by selected_metrics
  - File-level structural section gated by structural metric selection

affects: [07-UAT, output/console.zig, src/main.zig]

tech-stack:
  added: []
  patterns: [isMetricEnabled helper pattern for conditional display gating]

key-files:
  created: []
  modified:
    - src/output/console.zig
    - src/main.zig

key-decisions:
  - "OutputConfig.selected_metrics null means all metrics enabled (backward compatible)"
  - "isMetricEnabled duplicated in console.zig (same pattern as main.zig) to avoid cross-module dependency"
  - "Per-function base line always shows status/severity/kind/name; cyclomatic and cognitive appended conditionally"
  - "worstStatusAll still considers ALL metrics for verbosity filtering (filter only affects display, not which functions appear)"

patterns-established:
  - "isMetricEnabled(config.selected_metrics, metric_name) pattern for display gating throughout console.zig"

requirements-completed: []

duration: 2min
completed: 2026-02-17
---

# Phase 07 Plan 05: --metrics Flag Output Filtering Summary

**OutputConfig gains selected_metrics field to filter per-function detail lines and hotspot sections by selected metric families, closing UAT test 6 gap**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T11:58:24Z
- **Completed:** 2026-02-17T12:01:16Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Added `selected_metrics: ?[]const []const u8` field to `OutputConfig` struct in console.zig
- Added `isMetricEnabled` private helper function in console.zig
- Gated per-function cyclomatic/cognitive score display by their respective selected_metrics entries
- Gated halstead `[halstead vol N]` bracket by `isMetricEnabled("halstead")`
- Gated structural `[length N]`, `[params N]`, `[depth N]` brackets by `isMetricEnabled("structural")`
- Gated file-level structural section (file line count / exports) by `isMetricEnabled("structural")`
- Gated all three hotspot sections (cyclomatic/cognitive/Halstead) in `formatSummary` by `isMetricEnabled`
- Passed `parsed_metrics` from main.zig into `OutputConfig.selected_metrics`
- Updated all 13 test OutputConfig literals with `.selected_metrics = null` to preserve backward compat

## Task Commits

1. **Task 1: Add selected_metrics to OutputConfig and gate console output** - `e684ab9` (feat)

**Plan metadata:** (committed with docs commit below)

## Files Created/Modified

- `src/output/console.zig` - OutputConfig struct extended; isMetricEnabled helper added; all display sections gated; all test literals updated
- `src/main.zig` - OutputConfig construction updated to pass parsed_metrics

## Decisions Made

- `selected_metrics: null` means all metrics enabled — preserves backward compatibility and matches existing `isMetricEnabled` semantics from main.zig
- `isMetricEnabled` duplicated in console.zig rather than shared import to avoid circular module dependencies
- Per-function base line (status symbol, severity, kind, name) is always shown; metric values conditionally appended
- `worstStatusAll` continues to consider ALL metric statuses for verbosity filtering — the --metrics flag only controls display, not which functions appear in the listing

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Minor: Initial structural gating attempt used `_ = str` discard pattern inside an optional capture, which Zig rejects as "pointless discard of capture" (the variable is still used in the else branch). Fixed by restructuring to `if (isMetricEnabled(...)) { ... }` inside the capture block instead.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- UAT test 6 gap is now resolved: `--metrics cyclomatic` shows only cyclomatic hotspots and per-function cyclomatic scores
- Phase 07 is fully complete — all 5 plans executed and all UAT tests passing
- Ready for Phase 08

---
*Phase: 07-halstead-structural-metrics*
*Completed: 2026-02-17*
