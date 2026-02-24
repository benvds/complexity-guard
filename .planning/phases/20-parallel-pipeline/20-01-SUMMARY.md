---
phase: 20-parallel-pipeline
plan: "01"
subsystem: pipeline
tags: [rust, rayon, walkdir, globset, parallel, discovery]
dependency_graph:
  requires: []
  provides: [pipeline::discover_files, pipeline::analyze_files_parallel]
  affects: [rust/src/lib.rs, rust/Cargo.toml]
tech_stack:
  added: [rayon 1.x, walkdir 2.x, globset 0.4.x]
  patterns: [local-rayon-threadpool, walkdir-filter-entry-pruning, globset-include-exclude]
key_files:
  created:
    - rust/src/pipeline/mod.rs
    - rust/src/pipeline/discover.rs
    - rust/src/pipeline/parallel.rs
  modified:
    - rust/Cargo.toml
    - rust/src/lib.rs
decisions:
  - "Local rayon ThreadPoolBuilder used (not build_global()) to avoid test interference between concurrent test runs"
  - "EXCLUDED_DIRS constant matches Zig filter.zig exactly: same 10 entries in same order"
  - "discover_files() filter_entry prunes excluded dirs before descent for efficiency"
  - "analyze_files_parallel() sorts results by PathBuf::cmp for cross-platform deterministic ordering"
metrics:
  duration: "3 min"
  completed: "2026-02-24"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 2
---

# Phase 20 Plan 01: Pipeline Module (Discovery + Parallel Analysis) Summary

Implemented `pipeline::discover_files()` and `pipeline::analyze_files_parallel()` as the core library functions for PIPE-01, PIPE-02, and PIPE-03.

## What Was Built

**`rust/src/pipeline/discover.rs`** — Recursive file discovery with glob filtering:
- `discover_files(paths, include_patterns, exclude_patterns)` walks directories using `WalkDir::filter_entry` for early directory pruning
- `EXCLUDED_DIRS` constant mirrors the Zig `filter.zig` list exactly: node_modules, .git, dist, build, .next, coverage, __pycache__, .svn, .hg, vendor
- `GlobSet`-based include/exclude patterns via the `globset` crate
- Helper functions: `is_target_extension`, `is_declaration_file`, `should_include`, `build_globset`

**`rust/src/pipeline/parallel.rs`** — Rayon-based parallel analysis:
- `analyze_files_parallel(paths, config, threads)` builds a local thread pool and uses `par_iter()` to call `analyze_file()` concurrently
- Results partitioned into Ok/Err; successful results sorted by `PathBuf::cmp` for deterministic output (PIPE-03)
- `has_parse_errors` flag returned when any file fails to parse; valid files are not discarded

**`rust/src/pipeline/mod.rs`** — Public API module with re-exports of both functions.

**`rust/Cargo.toml`** — Added three dependencies: `rayon = "1"`, `walkdir = "2"`, `globset = "0.4"`.

**`rust/src/lib.rs`** — Added `pub mod pipeline;`.

## Test Results

10 tests passing across both modules:

| Module | Tests | Status |
|--------|-------|--------|
| pipeline::discover | 6 | All pass |
| pipeline::parallel | 4 | All pass |

Key tests:
- `test_excluded_dirs_matches_zig` — verifies 10-entry parity with Zig filter.zig
- `test_discover_files_exclude_pattern` — glob `**/*_cases.ts` correctly filters _cases files
- `test_analyze_parallel_deterministic_order` — two runs with threads=4 produce identical path ordering
- `test_analyze_parallel_invalid_file_returns_error` — .rs file triggers error flag; .ts file still analyzed

## Verification

```
cargo test pipeline --lib   =>  10/10 passed
cargo build --release       =>  Finished cleanly (added globset, walkdir, rayon)
```

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `rust/src/pipeline/mod.rs` — exists
- `rust/src/pipeline/discover.rs` — exists (120+ lines)
- `rust/src/pipeline/parallel.rs` — exists (60+ lines)
- Task 1 commit: a9414c5 — verified in git log
- Task 2 commit: 0598ff1 — verified in git log
