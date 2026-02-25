---
phase: quick-22
plan: 01
subsystem: benchmarks
tags: [benchmarking, rust, zig, hyperfine, performance]
dependency_graph:
  requires: []
  provides: [bench-rust-vs-zig.sh]
  affects: [zig/benchmarks/README.md]
tech_stack:
  added: []
  patterns: [hyperfine-json-export, capture_system_info, quick-suite-benchmark]
key_files:
  created:
    - zig/benchmarks/scripts/bench-rust-vs-zig.sh
  modified:
    - zig/benchmarks/README.md
decisions:
  - Used python3 for arithmetic (ratio calculation, memory computation) instead of node to avoid Node.js dependency — script compares native binaries and should not require Node.js
  - Copied capture_system_info function verbatim from bench-quick.sh (with python3 substitution) per plan specification
  - Results directory prefix rust-vs-zig- is distinct from baseline- used by CG-vs-FTA benchmarks for clear separation
metrics:
  duration: 1 min
  completed: 2026-02-25
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Quick Task 22: Benchmark Script Comparing Rust vs Zig Summary

**One-liner:** Hyperfine benchmark script comparing Rust v0.8 and Zig v1.0 ComplexityGuard binaries across the 10-project quick suite with per-project JSON results and a summary table.

## What Was Built

- `zig/benchmarks/scripts/bench-rust-vs-zig.sh` — executable benchmark script that:
  - Builds Zig binary with `zig build -Doptimize=ReleaseFast`
  - Builds Rust binary with `cargo build --release`
  - Runs hyperfine (3 warmup + 15 measured runs) on all 10 quick suite projects
  - Exports per-project JSON to `results/rust-vs-zig-YYYY-MM-DD/`
  - Prints summary table: Project / Rust (ms) / Zig (ms) / Ratio
  - Computes overall average ratio with a plain-language interpretation

- `zig/benchmarks/README.md` updated with:
  - Rust/Cargo added to Prerequisites
  - Step 5 added to Quick Start
  - `bench-rust-vs-zig.sh` row added to Script Reference table
  - `rust-vs-zig-*` directory added to Results Directory Structure example
  - "Rust vs Zig (Binary Comparison)" subsection added to Interpreting Results

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create bench-rust-vs-zig.sh benchmark script | 54154f5 | zig/benchmarks/scripts/bench-rust-vs-zig.sh |
| 2 | Update benchmarks README with Rust-vs-Zig documentation | a79ee65 | zig/benchmarks/README.md |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Replaced node with python3 for arithmetic**
- **Found during:** Task 1 implementation
- **Issue:** The plan specified "no Node.js required" but `capture_system_info` in bench-quick.sh uses `node -e` for floating-point arithmetic (memory GB, CPU MHz). Using node would contradict the plan requirement.
- **Fix:** Replaced all `node -e "console.log(...)"` calls with equivalent `python3 -c "print(...)"` calls. Python3 is universally available on systems with Zig and Rust toolchains.
- **Files modified:** zig/benchmarks/scripts/bench-rust-vs-zig.sh

## Self-Check: PASSED

- [x] zig/benchmarks/scripts/bench-rust-vs-zig.sh exists and is executable
- [x] bash -n syntax check passes
- [x] README contains "bench-rust-vs-zig.sh" references
- [x] Script contains "zig build -Doptimize=ReleaseFast"
- [x] Script contains "cargo build --release"
- [x] Script contains quick suite project list
- [x] Commits 54154f5 and a79ee65 exist
