# Deferred Items - Phase 07

## Out-of-Scope Issues Found During Plan 07-01

### structural.zig test failures

**Found during:** Task 1 (halstead.zig implementation)

**Issue:** `src/metrics/structural.zig` (untracked, uncommitted) has pre-existing test failures:
- `countLogicalLines` tests: all count off by 1 (expected N, got N-1)
- `maxNestingDepth: stops at nested function boundary`: expected 1, got 3

**Status:** Out of scope for plan 07-01 (Halstead core). These should be fixed in the plan that owns structural.zig (likely 07-02 or 07-03).

**Impact:** 1 test failure in structural.zig causes 1 transitive failure in json_output tests (220/221 pass).
