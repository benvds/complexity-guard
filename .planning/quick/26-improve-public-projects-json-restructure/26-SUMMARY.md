---
phase: quick-26
plan: 01
subsystem: benchmarking
tags: [json, jq, bash, benchmarks, test-sets]

# Dependency graph
requires:
  - phase: quick-24
    provides: Restored benchmarks/ directory with scripts
provides:
  - Restructured public-projects.json with 3-value category taxonomy
  - repo_size field (small/medium/large) on all 76 entries
  - test_sets arrays (quick/normal/full) for targeted benchmarking
  - JSON-driven benchmark scripts (no hardcoded project lists)
affects: [benchmarks, setup, bench-quick]

# Tech tracking
tech-stack:
  added: []
  patterns: [test_sets-driven suite selection via jq filters]

key-files:
  created: []
  modified:
    - tests/public-projects.json
    - benchmarks/scripts/setup.sh
    - benchmarks/scripts/bench-quick.sh

key-decisions:
  - "Collapsed 32 fine-grained categories into 3: library, application, framework-and-build-tool"
  - "TypeScript compiler classified as library (not framework) per plan guidance"
  - "pm2 classified as application/medium (plan listed as small in quick set but medium in repo_size list)"
  - "Quick set covers 17 unique category/size/tier combos for representative benchmarking"

patterns-established:
  - "test_sets array in public-projects.json drives all suite selection"
  - "jq filters on test_sets for quick/normal, repo_size for stress"

requirements-completed: [QUICK-26]

# Metrics
duration: 5min
completed: 2026-02-26
---

# Quick Task 26: Improve Public Projects JSON Restructure Summary

**Restructured 76-entry project registry with 3-category taxonomy, repo_size, and test_sets-driven benchmark suite selection**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-26T14:13:25Z
- **Completed:** 2026-02-26T14:18:40Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Replaced 32 fine-grained categories with 3 actionable ones (library, application, framework-and-build-tool)
- Added repo_size (small: 24, medium: 36, large: 16) and test_sets to all 76 entries
- Quick set covers 17 unique (category x repo_size x quality_tier) combos for representative benchmarking
- Normal set provides 39 entries for broader coverage (2-3 per populated combo)
- Eliminated all hardcoded project lists from setup.sh and bench-quick.sh
- Added --suite normal option to setup.sh

## Task Commits

Each task was committed atomically:

1. **Task 1: Restructure public-projects.json schema** - `cd47d0a` (feat)
2. **Task 2: Update benchmark scripts to use test_sets from JSON** - `00af450` (feat)

## Files Created/Modified
- `tests/public-projects.json` - Restructured with 3 categories, repo_size, test_sets; removed comparison_group
- `benchmarks/scripts/setup.sh` - JSON-driven suite selection with new --suite normal option
- `benchmarks/scripts/bench-quick.sh` - Dynamic QUICK_SUITE from test_sets in JSON

## Decisions Made
- Collapsed 32 fine-grained categories into 3 broad categories per plan specification
- TypeScript compiler classified as "library" (compiler/language tool, not a framework)
- pm2 assigned repo_size "medium" per the plan's size classification (despite quick set label saying "small")
- Quick set covers 17 combos (vs plan estimate of 10-20), exceeding minimum coverage goal

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected meta repo_sizes counts**
- **Found during:** Task 1 (verification step)
- **Issue:** Initial meta section had estimated counts (small: 26, medium: 33, large: 17) that did not match actual entry assignments (small: 24, medium: 36, large: 16)
- **Fix:** Ran jq group_by to get actual counts and updated meta section
- **Files modified:** tests/public-projects.json
- **Verification:** jq group_by confirms counts match meta section
- **Committed in:** cd47d0a (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Meta counts corrected to match actual data. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Public projects JSON is ready for targeted benchmarking with test_sets-driven suite selection
- bench-full.sh was not modified (it already reads all libraries dynamically from JSON)

---
## Self-Check: PASSED

All files exist and both task commits verified in git log.

---
*Quick task: 26-improve-public-projects-json-restructure*
*Completed: 2026-02-26*
