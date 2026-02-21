---
phase: quick-20
plan: 01
subsystem: ci-tooling
tags: [memory, valgrind, helgrind, thread-safety, ci]
dependency_graph:
  requires: []
  provides: [memory-leak-check, thread-safety-check, ci-memory-job]
  affects: [.github/workflows/test.yml]
tech_stack:
  added: [valgrind, helgrind]
  patterns: [error-exitcode-distinction, parallel-ci-jobs]
key_files:
  created:
    - scripts/check-memory.sh
  modified:
    - .github/workflows/test.yml
decisions:
  - "--error-exitcode=99 to distinguish Valgrind errors from CG's own threshold exit code (1)"
  - "Helgrind included alongside memcheck to cover data races from Phase 12 thread pool"
  - "Stress test against tests/repos/webpack is optional — script skips gracefully if not cloned"
  - "memory-check CI job runs in parallel with test matrix (no needs dependency)"
metrics:
  duration: "2 min"
  completed: "2026-02-21"
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 20: Create Memory Leak and Thread-Safety Check Script Summary

Valgrind memcheck (single + multi-threaded) and Helgrind thread-safety verification script with CI integration.

## Objective

Prove ComplexityGuard has zero memory leaks and no data races in both sequential and parallel modes introduced by Phase 12's thread pool.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create memory leak and thread-safety check script | 04502c4 | scripts/check-memory.sh |
| 2 | Add memory-check job to CI workflow | c9e13b5 | .github/workflows/test.yml |

## What Was Built

### scripts/check-memory.sh

Executable shell script (122 lines) that:

1. **Builds** the binary with `ReleaseSafe` (preserves safety checks)
2. **Valgrind memcheck (single-threaded):** `--threads 1` forces sequential code path — baseline leak check
3. **Valgrind memcheck (multi-threaded):** `--threads 4` exercises Phase 12 thread pool and per-worker arena allocators
4. **Helgrind thread-safety:** Detects data races, lock ordering violations, and POSIX thread API misuse in the parallel path
5. **Optional webpack stress test:** Runs against `tests/repos/webpack` (skips gracefully with a message if not cloned)

Key design decisions:
- Uses `--error-exitcode=99` instead of `1` so Valgrind-detected errors are distinguishable from CG's own threshold exit codes (exit 1 for errors, exit 2 for warnings)
- Uses `--fail-on none` on all CG invocations so threshold violations don't mask Valgrind's exit behavior
- Tracks pass/fail counts and prints a clear summary; exits non-zero only if a check fails
- Prints an actionable error if Valgrind is not installed

### .github/workflows/test.yml

Added `memory-check` job:
- Runs on `ubuntu-latest` (Valgrind is Linux-only)
- Checks out with submodules (required for tree-sitter vendor)
- Installs Zig 0.15.2 via `mlugg/setup-zig@v2`
- Installs Valgrind via `apt-get`
- Runs `bash scripts/check-memory.sh`
- No `needs` dependency — runs in parallel with the existing `test` matrix

## Verification

- `bash -n scripts/check-memory.sh` exits 0 (syntax valid)
- YAML is valid (confirmed with python3 yaml.safe_load)
- CI workflow contains both `test` and `memory-check` jobs
- memory-check job installs valgrind and invokes the script

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `scripts/check-memory.sh` exists and is executable (-rwxr-xr-x)
- `.github/workflows/test.yml` contains `memory-check` job
- Commits 04502c4 and c9e13b5 exist in git log
