---
phase: quick-19
plan: 01
subsystem: benchmarks
tags: [benchmarks, system-info, documentation, shell-scripts]
dependency_graph:
  requires: []
  provides: [system-info-capture, benchmark-hardware-context]
  affects: [benchmarks/scripts, benchmarks/results, docs/benchmarks.md]
tech_stack:
  added: []
  patterns: [portable-linux-macos-shell, jq-json-construction]
key_files:
  created:
    - benchmarks/results/baseline-2026-02-21/system-info.json
  modified:
    - benchmarks/scripts/bench-quick.sh
    - benchmarks/scripts/bench-full.sh
    - benchmarks/scripts/bench-stress.sh
    - benchmarks/scripts/bench-subsystems.sh
    - benchmarks/scripts/summarize-results.mjs
    - benchmarks/README.md
    - docs/benchmarks.md
decisions:
  - Skip-if-exists pattern for system-info.json allows multiple bench scripts to share same dated results directory without overwriting
  - Duplicate capture_system_info function across 4 scripts (no shared sourcing) to keep each script standalone
  - Node.js for memory/MHz calculations in shell function (already a required dep for FTA)
  - Normalize subsystem object schema to array in parseSubsystemsFile for backward compatibility
metrics:
  duration: 8 min
  completed: 2026-02-21
  tasks_completed: 2
  files_modified: 7
---

# Phase quick-19 Plan 01: Include System Specs in Benchmarking Summary

Hardware context added to all benchmark results via portable system detection, baseline system-info.json for AMD Ryzen 7 5700U, and updated summary display in summarize-results.mjs.

## What Was Built

### Task 1: System spec capture in all four bench scripts + baseline system-info.json

Added a `capture_system_info()` function (62 lines) to all four bench scripts:
- `benchmarks/scripts/bench-quick.sh`
- `benchmarks/scripts/bench-full.sh`
- `benchmarks/scripts/bench-stress.sh`
- `benchmarks/scripts/bench-subsystems.sh`

The function is called immediately after `mkdir -p "$RESULTS_DIR"` in each script. It:
- Detects Linux vs macOS via `uname -s`
- On Linux: uses `lscpu`, `/proc/meminfo`, `/etc/os-release`
- On macOS: uses `sysctl`, `sw_vers`
- Constructs JSON with `jq -n` using `--argjson` for numeric fields
- Skips silently if `system-info.json` already exists (shared dated results dir)

Created `benchmarks/results/baseline-2026-02-21/system-info.json` with actual machine specs:
```json
{
  "hostname": "fedora.home",
  "os": "Fedora Linux 43",
  "kernel": "6.18.9-200.fc43.x86_64",
  "arch": "x86_64",
  "cpu": {
    "model": "AMD Ryzen 7 5700U with Radeon Graphics",
    "cores": 8,
    "threads": 16,
    "max_mhz": 4374
  },
  "memory": { "total_gb": 13.5 },
  "captured_at": "2026-02-21T00:00:00Z"
}
```

### Task 2: Update summarize-results.mjs and documentation

**summarize-results.mjs:**
- Loads `system-info.json` from results directory (graceful fallback if missing for older baselines)
- Prints `### System` table with CPU, Memory, OS, Architecture immediately after "Results from:" line
- Includes `system_info` in the `--json` output object

**docs/benchmarks.md Hardware section:** Replaced "Linux x86-64 development machine" with actual hardware spec table including CPU model, memory, OS, architecture.

**benchmarks/README.md:**
- Added `system-info.json` to Results Directory Structure tree
- Added `### System Info JSON Schema` subsection showing the JSON schema with example values

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed subsystem schema mismatch in summarize-results.mjs**
- **Found during:** Task 2 when testing `--json` output
- **Issue:** `parseSubsystemsFile` docstring described array schema `[{name, mean_ms}]` but actual Zig bench output uses object schema `{name: {mean_ms, stddev_ms, ...}}`. The iteration code `for (const s of d.subsystems || [])` crashed with `TypeError: object is not iterable` on object-type subsystems.
- **Fix:** Added normalization in `parseSubsystemsFile` to detect object-keyed subsystems and convert to array format before returning
- **Files modified:** `benchmarks/scripts/summarize-results.mjs`
- **Commit:** 73c2088

## Self-Check

**Files exist:**
- [x] `benchmarks/results/baseline-2026-02-21/system-info.json` — created
- [x] `benchmarks/scripts/bench-quick.sh` — contains `capture_system_info`
- [x] `benchmarks/scripts/summarize-results.mjs` — loads and prints system-info.json
- [x] `docs/benchmarks.md` — contains "AMD Ryzen 7 5700U"
- [x] `benchmarks/README.md` — mentions system-info.json

**Commits exist:**
- [x] 00d4858: feat(quick-19): add system spec capture to bench scripts and create baseline system-info.json
- [x] 73c2088: feat(quick-19): display system specs in benchmark summary and update documentation

## Self-Check: PASSED
