---
phase: quick-29
plan: 01
subsystem: benchmarks
tags: [benchmarks, fta, documentation, performance]

requires: []
provides:
  - CG-only benchmark scripts (no FTA dependency)
  - CG-only benchmark documentation
  - FTA-free README and publication READMEs
affects: [benchmarks, docs]

tech-stack:
  added: []
  patterns: [CG-only benchmarking with hyperfine]

key-files:
  created: []
  modified:
    - benchmarks/scripts/bench-quick.sh
    - benchmarks/scripts/bench-full.sh
    - benchmarks/scripts/bench-stress.sh
    - benchmarks/scripts/bench-duplication.sh
    - benchmarks/scripts/summarize-results.mjs
    - benchmarks/README.md
    - docs/benchmarks.md
    - README.md
    - publication/npm/README.md
    - publication/npm/packages/darwin-arm64/README.md
    - publication/npm/packages/darwin-x64/README.md
    - publication/npm/packages/linux-x64/README.md
    - publication/npm/packages/linux-arm64/README.md
    - publication/npm/packages/windows-x64/README.md

key-decisions:
  - "Deleted compare-metrics.sh and compare-metrics.mjs entirely (existed solely for CG-vs-FTA comparison)"
  - "summarize-results.mjs now accepts 1-result hyperfine files (previously required 2)"
  - "Benchmark docs reframed around absolute CG performance instead of competitive comparison"

patterns-established:
  - "CG-only benchmarking: single hyperfine command per project, no external tool install"

requirements-completed: [QUICK-29]

duration: 7min
completed: 2026-02-26
---

# Quick Task 29: Remove FTA Benchmarking Summary

**Removed all FTA (Fast TypeScript Analyzer) references from benchmark scripts, summarizer, and documentation -- benchmarks now measure CG-only absolute performance**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-26T14:46:42Z
- **Completed:** 2026-02-26T14:53:52Z
- **Tasks:** 3
- **Files modified:** 14 (7 scripts/code + 7 documentation)

## Accomplishments
- Removed FTA auto-install, FTA hyperfine commands, and FTA summary columns from all 3 bench scripts
- Deleted compare-metrics.sh and compare-metrics.mjs (existed solely for CG-vs-FTA metric comparison)
- Rewrote summarize-results.mjs to produce CG-only performance tables (no speedup ratio, no FTA columns)
- Rewrote benchmarks/README.md and docs/benchmarks.md to frame around CG absolute performance
- Removed all FTA references from README.md and all 6 publication READMEs
- All 238 tests (200 unit + 30 integration + 8 parser) continue to pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove FTA from benchmark scripts and delete comparison scripts** - `73fbac0` (refactor)
2. **Task 2: Update benchmarks/README.md and docs/benchmarks.md** - `159946c` (docs)
3. **Task 3: Update README.md and publication READMEs to remove FTA references** - `a011be5` (docs)

## Files Created/Modified

**Deleted:**
- `benchmarks/scripts/compare-metrics.sh` - CG-vs-FTA metric comparison orchestrator
- `benchmarks/scripts/compare-metrics.mjs` - Per-project metric comparison logic

**Modified (scripts):**
- `benchmarks/scripts/bench-quick.sh` - CG-only quick suite benchmark (removed FTA install, single hyperfine command)
- `benchmarks/scripts/bench-full.sh` - CG-only full suite benchmark
- `benchmarks/scripts/bench-stress.sh` - CG-only stress suite benchmark
- `benchmarks/scripts/bench-duplication.sh` - Removed FTA tip line
- `benchmarks/scripts/summarize-results.mjs` - CG-only summarizer (accepts 1-result files, no FTA/speedup columns)

**Modified (documentation):**
- `benchmarks/README.md` - CG-only benchmark documentation
- `docs/benchmarks.md` - CG-only performance documentation
- `README.md` - Replaced FTA speed claims with absolute performance description
- `publication/npm/README.md` - Removed FTA comparison
- `publication/npm/packages/darwin-arm64/README.md` - Removed FTA comparison
- `publication/npm/packages/darwin-x64/README.md` - Removed FTA comparison
- `publication/npm/packages/linux-x64/README.md` - Removed FTA comparison
- `publication/npm/packages/linux-arm64/README.md` - Removed FTA comparison
- `publication/npm/packages/windows-x64/README.md` - Removed FTA comparison

## Decisions Made
- Deleted compare-metrics.sh and compare-metrics.mjs entirely rather than repurposing them (they existed solely for CG-vs-FTA metric comparison and have no use without FTA)
- summarize-results.mjs now accepts hyperfine files with 1 result (previously required 2 and skipped single-result files)
- Benchmark docs reframed around absolute CG performance and regression tracking instead of competitive comparison
- Kept Parallelization Impact and Duplication Detection Performance sections in docs/benchmarks.md (already CG-only)
- Historical note about Zig vs Rust kept in Baseline History (factual, does not reference FTA)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Benchmarks are now self-contained: no npm/Node.js dependency for running bench scripts
- Future benchmark runs will produce single-result hyperfine files compatible with the updated summarizer

---
*Quick task: 29*
*Completed: 2026-02-26*
