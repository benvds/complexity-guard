---
phase: 12-parallelization-distribution
plan: 01
subsystem: pipeline
tags: [parallelization, thread-pool, performance, std.Thread.Pool]

# Dependency graph
requires:
  - phase: 10.1-performance-benchmarks
    provides: "Profiling data showing parsing is 40-64% of pipeline time"
provides:
  - "src/pipeline/parallel.zig: Thread pool dispatch for concurrent file analysis"
  - "main.zig: Parallel/sequential branching with CPU auto-detection and timing"
  - "JSON output metadata: elapsed_ms and thread_count fields"
affects:
  - phase 12-02 (distribution)
  - benchmarks that use lib.zig

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "std.Thread.Pool with WaitGroup for parallel work dispatch"
    - "Per-worker arena allocators for thread-local scratch memory"
    - "Deep-copy of struct string fields before arena free (function_name, function_kind)"
    - "Mutex-protected append as the only critical section; all computation outside lock"
    - "Atomic counters (std.atomic.Value(u32)) for lock-free count aggregation"

key-files:
  created:
    - src/pipeline/parallel.zig
  modified:
    - src/main.zig
    - src/lib.zig
    - src/output/json_output.zig

key-decisions:
  - "Per-worker arena allocator from std.heap.page_allocator for scratch memory, freed at worker exit"
  - "Deep-copy ThresholdResult string fields (function_name, function_kind) to main allocator before arena deinit"
  - "Sort file results by path in both sequential and parallel paths for deterministic output"
  - "Sequential path (threads==1) uses no pool at all for zero overhead"
  - "CPU auto-detection via std.Thread.getCpuCount() with fallback to 1"
  - "verbose timing printed to stderr (not stdout) to avoid polluting machine-readable output"
  - "elapsed_ms and thread_count added as top-level metadata field in JSON output (additive, backward compatible)"

patterns-established:
  - "analyzeFileWorker: per-invocation parser + arena, compute outside lock, lock only for append"
  - "freeResults: explicitly free duped strings within each ThresholdResult before freeing slice"

requirements-completed: [PERF-01, PERF-02]

# Metrics
duration: 10min
completed: 2026-02-21
---

# Phase 12 Plan 01: Parallel File Analysis Summary

**std.Thread.Pool parallel file analysis with per-worker parsers, deterministic sorted output, and JSON timing metadata**

## Performance

- **Duration:** 10 min
- **Started:** 2026-02-21T12:34:00Z
- **Completed:** 2026-02-21T12:43:30Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Implement `src/pipeline/parallel.zig` with `analyzeFilesParallel` dispatching one work item per file via `std.Thread.Pool`
- Add sequential bypass path in `main.zig` (threads==1) with zero pool overhead; auto-detect CPU count otherwise
- Sort output by file path in both paths for deterministic results regardless of thread scheduling or discovery order
- Add `metadata: { elapsed_ms, thread_count }` field to JSON output
- Verbose mode prints `Analyzed N files in Xms (N threads)` to stderr

## Task Commits

Each task was committed atomically:

1. **Task 1: Create parallel analysis module and wire into main.zig pipeline** - `d69af29` (feat)
2. **Task 2: Add elapsed_ms and thread_count to JSON output metadata** - `128f870` (feat)

## Files Created/Modified
- `src/pipeline/parallel.zig` - New module: WorkerContext, FileAnalysisResult, analyzeFilesParallel, analyzeFileWorker, freeResults; 2 tests
- `src/main.zig` - Parallel/sequential branching with CPU count resolution, timing capture, verbose output, sort step
- `src/lib.zig` - Added `pub const parallel = @import("pipeline/parallel.zig")`
- `src/output/json_output.zig` - Metadata struct, updated buildJsonOutput signature, updated 8 existing tests, added 1 new metadata test

## Decisions Made
- **Deep-copy strings before arena free:** ThresholdResult.function_name and function_kind are `[]const u8` slices pointing into per-worker arenas. Shallow `allocator.dupe(ThresholdResult, ...)` leaves dangling pointers after the arena frees. Fixed by allocating each string individually to the main allocator.
- **Sort in both paths:** The sequential path previously output files in walker discovery order (filesystem-dependent). Added `std.mem.sort` after both paths to ensure identical output regardless of thread count.
- **No defer in sequential block:** Removed `defer seq_parse_summary.deinit()` inside the if-block because the parse result data (function names pointing into source/tree) must outlive the block for output generation. The arena allocator cleans up at main() exit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Shallow dupe of ThresholdResult caused dangling string pointers**
- **Found during:** Task 1 (testing parallel mode)
- **Issue:** Used `ctx.allocator.dupe(cyclomatic.ThresholdResult, ...)` which copies the struct values shallowly. The `function_name` and `function_kind` string slices point into the per-worker arena. When the arena is freed at worker exit, these become dangling pointers causing segfault on display.
- **Fix:** Replaced shallow dupe with `alloc` + per-field string dupe using `ctx.allocator.dupe(u8, ...)`. Updated `freeResults` to free the duped strings.
- **Files modified:** src/pipeline/parallel.zig
- **Verification:** No segfault in parallel mode, function names display correctly
- **Committed in:** d69af29 (Task 1 commit)

**2. [Rule 1 - Bug] Sequential path defer ran before output, garbling function names**
- **Found during:** Task 1 (comparing sequential vs parallel output)
- **Issue:** `defer seq_parse_summary.deinit(arena_allocator)` inside the if-block freed parse result memory (source/tree backing function name slices) before the sort + display phase ran.
- **Fix:** Removed the defer — the arena allocator covers cleanup at main() exit.
- **Files modified:** src/main.zig
- **Verification:** Sequential and parallel outputs now identical
- **Committed in:** d69af29 (Task 1 commit)

**3. [Rule 1 - Bug] Sequential path output was non-deterministic (discovery order vs sorted)**
- **Found during:** Task 1 (diff of --threads 1 vs parallel outputs)
- **Issue:** Sequential path output files in walker discovery order (filesystem-dependent); parallel path sorted by path. Same data but different ordering.
- **Fix:** Added `std.mem.sort(console.FileThresholdResults, ...)` after both paths complete, sorting by path lexicographically.
- **Files modified:** src/main.zig
- **Verification:** `diff seq_out par_out` produces no differences
- **Committed in:** d69af29 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (Rule 1 - Bug, all in Task 1)
**Impact on plan:** All auto-fixes required for correctness. No scope creep. The string duplication pattern is now established for future parallel workers.

## Issues Encountered
None beyond the three bugs documented above (all auto-fixed within Task 1).

## Next Phase Readiness
- Parallel analysis pipeline is complete and functional
- `src/lib.zig` exports `parallel` module for use by benchmarks in Phase 10.1
- Phase 12-02 (distribution/packaging) can now proceed with the parallel binary as its subject

## Self-Check: PASSED

- src/pipeline/parallel.zig: FOUND
- src/main.zig: FOUND (updated)
- src/lib.zig: FOUND (updated)
- src/output/json_output.zig: FOUND (updated)
- 12-01-SUMMARY.md: FOUND
- Commit d69af29 (Task 1): FOUND
- Commit 128f870 (Task 2): FOUND
- All tests pass: VERIFIED
- Sequential and parallel outputs identical: VERIFIED
- JSON metadata.elapsed_ms and metadata.thread_count present: VERIFIED

---
*Phase: 12-parallelization-distribution*
*Completed: 2026-02-21*
