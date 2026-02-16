---
phase: quick-9
plan: 1
subsystem: cross-platform-compatibility
tags: [windows, build-fix, posix, env-vars]
dependency_graph:
  requires: []
  provides: ["windows-cross-compilation"]
  affects: ["src/cli/discovery.zig", "src/cli/help.zig"]
tech_stack:
  added: []
  patterns: ["std.process.getEnvVarOwned", "std.process.hasEnvVarConstant", "cross-platform env var access"]
key_files:
  created: []
  modified:
    - path: "src/cli/discovery.zig"
      purpose: "Cross-platform XDG config home detection"
    - path: "src/cli/help.zig"
      purpose: "Cross-platform color environment variable checks"
decisions: []
metrics:
  duration_minutes: 1
  completed_at: "2026-02-16T11:56:43Z"
---

# Quick Task 9: Fix Windows Build Failure - Replace std.posix.getenv

**One-liner:** Replaced std.posix.getenv calls with cross-platform std.process APIs to enable Windows cross-compilation.

## Overview

Fixed Windows cross-compilation build failure by replacing all `std.posix.getenv` calls in production code with cross-platform alternatives from the `std.process` namespace. The `std.posix.getenv` function is unavailable on Windows because environment strings use WTF-16 encoding.

**Objective:** Enable `zig build -Dtarget=x86_64-windows` to succeed without errors.

**Result:** Windows cross-compilation now builds cleanly. All native tests continue to pass. Production code uses only cross-platform APIs.

## Tasks Completed

### Task 1: Replace std.posix.getenv with cross-platform APIs
- **Status:** ✓ Complete
- **Commit:** b77d545
- **Duration:** ~1 minute

**Changes in discovery.zig:**
- Replaced three `std.posix.getenv` calls in `getConfigHome` function with `std.process.getEnvVarOwned`
- Updated logic to handle owned strings that must be freed (used defer for intermediate HOME value)
- Proper error handling for `EnvironmentVariableNotFound` vs propagating other errors

**Changes in help.zig:**
- Replaced three `std.posix.getenv` calls in `shouldUseColor` function with `std.process.hasEnvVarConstant`
- Simplified logic since we only check existence (no value needed, no allocator required)

**Key differences:**
- `std.posix.getenv` returns borrowed `?[*:0]const u8` (no free needed)
- `std.process.getEnvVarOwned` returns owned `[]u8` (must be freed)
- `std.process.hasEnvVarConstant` returns `bool` (comptime, no allocator, perfect for existence checks)

**Verification:**
- ✓ `zig build -Dtarget=x86_64-windows` succeeds
- ✓ `zig build test` passes all tests
- ✓ No `std.posix.getenv` calls remain in src/cli/discovery.zig or src/cli/help.zig

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

**Files created:** None (modification-only task)

**Files modified:**
- FOUND: /Users/benvds/code/complexity-guard/src/cli/discovery.zig
- FOUND: /Users/benvds/code/complexity-guard/src/cli/help.zig

**Commits:**
- FOUND: b77d545

## Outcome

Windows cross-compilation is now functional. The codebase uses only cross-platform environment variable APIs in production code. Test code still uses `std.posix.chdir` (as expected and documented in the plan - these are only compiled for native test builds).

## Impact

- **Windows users:** Can now cross-compile from Linux/macOS to Windows target
- **CI/CD:** Unblocks Windows binary builds in release workflow
- **Code quality:** Better cross-platform compatibility practices established
