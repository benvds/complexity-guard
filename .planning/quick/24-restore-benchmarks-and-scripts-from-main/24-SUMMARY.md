---
phase: quick-24
plan: 01
subsystem: benchmarks
tags: [benchmarks, shell-scripts, rust, cargo, hyperfine]

requires:
  - phase: quick-23
    provides: Rust-only project structure with Cargo.toml at root
provides:
  - Complete benchmarks/ directory with Rust-compatible benchmark scripts
  - Historical baseline results preserved from Zig era
  - tests/public-projects.json restored for benchmark setup
affects: [benchmarks, performance-testing]

tech-stack:
  added: []
  patterns: [cargo build --release for benchmark builds, target/release/complexity-guard binary path]

key-files:
  created:
    - benchmarks/scripts/bench-quick.sh
    - benchmarks/scripts/bench-full.sh
    - benchmarks/scripts/bench-stress.sh
    - benchmarks/scripts/bench-duplication.sh
    - benchmarks/scripts/compare-metrics.sh
    - benchmarks/scripts/compare-metrics.mjs
    - benchmarks/scripts/summarize-results.mjs
    - benchmarks/scripts/setup.sh
    - benchmarks/README.md
    - tests/public-projects.json
  modified: []

key-decisions:
  - "Historical baseline results preserved intact including Zig-era subsystem JSONs (read-only data)"
  - "bench-subsystems.sh and benchmarks/src/benchmark.zig NOT restored (no Rust equivalent)"
  - "public-projects.json path bug fixed in compare-metrics.sh and benchmarks/README.md"

patterns-established:
  - "All benchmark scripts use cargo build --release and target/release/complexity-guard"

requirements-completed: []

duration: 2min
completed: 2026-02-25
---

# Quick Task 24: Restore Benchmarks and Scripts from Main Summary

**Restored 8 benchmark scripts and README from main branch, updated all Zig build commands to cargo/Rust, removed Zig-only artifacts (bench-subsystems.sh, benchmark.zig), preserved 3 historical baseline directories**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-25T12:10:24Z
- **Completed:** 2026-02-25T12:13:14Z
- **Tasks:** 2
- **Files modified:** 46

## Accomplishments
- Restored all 8 benchmark shell/JS scripts with Zig-to-Rust build command updates
- Preserved 3 historical baseline result directories (2026-02-21, 2026-02-21-single-threaded, 2026-02-22)
- Updated benchmarks/README.md: Rust prerequisites, removed subsystem section, accurate parallel CG speed description
- Verified docs/benchmarks.md is already clean (Zig reference is historical context only)

## Task Commits

Each task was committed atomically:

1. **Task 1: Restore files from main, update scripts for Rust** - `91c487e` (feat)
2. **Task 2: Update benchmarks/README.md and docs/benchmarks.md for Rust** - `345acad` (docs)

## Files Created/Modified
- `benchmarks/scripts/bench-quick.sh` - Quick suite benchmark with cargo build --release
- `benchmarks/scripts/bench-full.sh` - Full suite benchmark with cargo build --release
- `benchmarks/scripts/bench-stress.sh` - Stress test benchmark, removed Phase 12 comments
- `benchmarks/scripts/bench-duplication.sh` - Duplication overhead benchmark with Rust binary path
- `benchmarks/scripts/compare-metrics.sh` - Metric comparison with Rust build and fixed public-projects.json path
- `benchmarks/scripts/compare-metrics.mjs` - Node.js metric comparison (restored as-is)
- `benchmarks/scripts/summarize-results.mjs` - Node.js results summarizer (restored as-is)
- `benchmarks/scripts/setup.sh` - Project cloning script (restored as-is, no build references)
- `benchmarks/README.md` - Updated for Rust: prerequisites, speed section, no subsystem section
- `benchmarks/projects/.gitkeep` - Restored placeholder
- `benchmarks/results/.gitkeep` - Restored placeholder
- `benchmarks/results/baseline-2026-02-21/*` - Historical baseline data (7 project JSONs + system-info)
- `benchmarks/results/baseline-2026-02-21-single-threaded/*` - Historical single-threaded baseline (16 files)
- `benchmarks/results/baseline-2026-02-22/*` - Historical parallel baseline (9 project JSONs + system-info)
- `tests/public-projects.json` - Project list for setup.sh and bench-full.sh

## Decisions Made
- Historical baseline results preserved intact, including Zig-era subsystem JSONs (they are read-only historical data)
- bench-subsystems.sh and benchmarks/src/benchmark.zig intentionally NOT restored (no Rust equivalent for Zig subsystem timing)
- docs/benchmarks.md line 216 Zig reference is historical context (Zig v1.0 vs Rust v0.8 comparison), left as-is

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed public-projects.json path in benchmarks/README.md**
- **Found during:** Task 2 (benchmarks/README.md updates)
- **Issue:** README referenced `benchmarks/public-projects.json` but file is at `tests/public-projects.json`
- **Fix:** Updated path to `tests/public-projects.json`
- **Files modified:** benchmarks/README.md
- **Verification:** grep confirms correct path
- **Committed in:** 345acad (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Path fix was necessary for documentation accuracy. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Benchmark infrastructure fully operational for Rust implementation
- Run `bash benchmarks/scripts/setup.sh --suite quick` then `bash benchmarks/scripts/bench-quick.sh` to generate new baselines

---
*Quick Task: 24-restore-benchmarks-and-scripts-from-main*
*Completed: 2026-02-25*

## Self-Check: PASSED

All 12 created files verified present. Both task commits (91c487e, 345acad) verified in git log.
