---
phase: quick-21
plan: 01
subsystem: monorepo-structure
tags: [restructure, zig, rust, monorepo, submodules]
dependency-graph:
  requires: []
  provides: [zig-subdirectory-layout]
  affects: [ci-workflows, benchmark-scripts, memory-check-script, docs]
tech-stack:
  added: []
  patterns: [monorepo-per-language-subdirectory, zig-build-setCwd-for-test-fixtures]
key-files:
  created:
    - zig/build.zig
    - zig/src/main.zig
    - zig/vendor/tree-sitter
    - zig/benchmarks/
    - zig/tests/public-projects.json
    - zig/.valgrind.supp
  modified:
    - .gitmodules
    - .gitignore
    - CLAUDE.md
    - README.md
    - PUBLISHING.md
    - scripts/check-memory.sh
    - .github/workflows/test.yml
    - .github/workflows/release.yml
    - docs/benchmarks.md
    - zig/benchmarks/scripts/bench-quick.sh
    - zig/benchmarks/scripts/bench-full.sh
    - zig/benchmarks/scripts/bench-stress.sh
    - zig/benchmarks/scripts/bench-duplication.sh
    - zig/benchmarks/scripts/bench-subsystems.sh
    - zig/benchmarks/scripts/setup.sh
decisions:
  - "setCwd(..) in build.zig runs Zig tests from project root so tests/fixtures/ is accessible to both Zig and Rust"
  - "Shared tests/fixtures/ stays at project root (not moved to zig/) to be accessible by both implementations"
metrics:
  duration: 15min
  completed: 2026-02-25
  tasks: 3
  files: 18
---

# Quick Task 21: Move Zig Code to zig/ Directory Summary

**One-liner:** Reorganized monorepo by moving all Zig implementation files into a `zig/` subdirectory mirroring the existing `rust/` structure, with `tests/fixtures/` remaining shared at project root.

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Move Zig files into zig/ directory and update git submodules | e6b0182 | Done |
| 2 | Update all references in docs, scripts, and CI workflows | bc95d94 | Done |
| 3 | Verify Rust tests still pass with shared fixtures at root | 9c9a585 | Done |

## What Was Done

### Task 1: File Migration

Moved all Zig-specific files from project root to `zig/`:
- `src/` → `zig/src/`
- `build.zig` → `zig/build.zig`
- `build.zig.zon` → `zig/build.zig.zon`
- `vendor/` → `zig/vendor/` (submodules)
- `benchmarks/` → `zig/benchmarks/`
- `tests/public-projects.json` → `zig/tests/public-projects.json`
- `.valgrind.supp` → `zig/.valgrind.supp`

Shared `tests/fixtures/` directory intentionally left at project root — used by both Zig and Rust implementations.

Updated `.gitmodules` submodule paths from `vendor/*` to `zig/vendor/*`. Updated `.gitignore` artifact paths with `zig/` prefix.

### Task 2: Reference Updates

- **CLAUDE.md**: Updated project structure diagram and build commands (`cd zig && zig build`)
- **README.md**: Updated legacy Zig build instructions
- **PUBLISHING.md**: Updated cross-compilation commands for Zig binary
- **scripts/check-memory.sh**: Updated binary path to `zig/zig-out/bin/`, suppressions to `zig/.valgrind.supp`, build command runs from `zig/` directory
- **.github/workflows/test.yml**: Updated `zig build test` to `cd zig && zig build test`, updated Zod clone path to `zig/tests/repos/zod`
- **.github/workflows/release.yml**: Updated `zig build` commands and `zig-out/bin/` paths to `zig/zig-out/bin/`, fixed archive creation directory (`cd zig/zig-out/bin` with `../../../` for output)
- **docs/benchmarks.md**: Updated all benchmark script paths and results directory references
- **zig/benchmarks/scripts/*.sh**: Updated internal `PROJECT_ROOT`-relative paths for binary, results, and projects directories

### Task 3: Verification

- Rust tests pass without modification: `cd rust && cargo test` — all 8 tests OK
- Zig tests initially failed (see Deviations), then passed after build.zig fix

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Zig tests failing after move due to fixture path resolution**

- **Found during:** Task 3 verification
- **Issue:** Zig test binary runs with `zig/` as its working directory after the move. Tests use relative paths like `tests/fixtures/typescript/...` which now resolve to `zig/tests/fixtures/...` (nonexistent) instead of project root `tests/fixtures/...`.
- **Fix:** Added `run_unit_tests.setCwd(b.path(".."))` in `zig/build.zig` to set the test runner's working directory to the project root. This ensures both `tests/fixtures/` (shared) and other relative paths resolve correctly.
- **Files modified:** `zig/build.zig`
- **Commit:** 9c9a585

## Verification Results

1. `ls zig/` shows: build.zig, build.zig.zon, src/, vendor/, tests/, benchmarks/, .valgrind.supp — PASS
2. `ls tests/fixtures/` shows: typescript/, javascript/, naming-edge-cases.ts — PASS
3. `.gitmodules` all three submodule paths updated to `zig/vendor/*` — PASS
4. `cd rust && cargo test` — all 8 tests pass — PASS
5. `cd zig && zig build test` — all 325 tests pass (305 originally passing + 20 fixture tests restored) — PASS
6. No stale root-level `src/`, `build.zig`, `vendor/`, `benchmarks/` remain — PASS
7. CI workflow YAML files reference `zig/` paths — PASS

## Self-Check: PASSED

- zig/build.zig exists: FOUND
- zig/src/main.zig exists: FOUND
- zig/vendor/tree-sitter exists: FOUND
- tests/fixtures/typescript exists: FOUND
- Commits e6b0182, bc95d94, 9c9a585 exist: FOUND
