---
phase: 02-cli-configuration
plan: 02
subsystem: cli
tags: [config, discovery, toml, json, validation]
requires: [02-01]
provides: [config-discovery, config-loading, config-validation]
affects: [build-system]
dependency_graph:
  requires:
    - 02-01-PLAN (CLI foundation, config types, args parsing)
  provides:
    - Config file discovery with upward search
    - JSON and TOML config loading
    - Config validation with domain constraints
  affects:
    - build.zig (removed known-folders dependency)
    - build.zig.zon (removed known-folders dependency)
tech_stack:
  added:
    - Hand-rolled XDG config home detection
  patterns:
    - Upward directory search with .git boundary
    - Deep copying to avoid parser arena memory leaks
    - ConfigFormat enum for file format detection
key_files:
  created:
    - src/cli/discovery.zig (285 lines)
  modified:
    - src/cli/config.zig (+415 lines - loadConfig, validate, freeConfig)
    - src/cli/help.zig (fixed ArrayList API for Zig 0.15.2)
    - build.zig (removed known-folders import)
    - build.zig.zon (removed known-folders dependency)
    - src/main.zig (added discovery.zig to test imports)
decisions:
  - title: Hand-rolled XDG config detection
    rationale: known-folders library incompatible with Zig 0.15.2 API changes (std.Io.Cancelable, std.process.Environ removed)
    alternatives: Wait for library update, vendor old Zig version
    chosen: Implement minimal XDG detection (HOME/.config on Unix, APPDATA on Windows)
  - title: Deep copy pattern for config loading
    rationale: JSON/TOML parsers use arena allocators that must be freed, but we need to return config data
    alternatives: Keep arena alive and return it, use static strings only
    chosen: Deep copy all strings into caller's allocator for clean ownership
  - title: Separate freeConfig function
    rationale: Config has optional nested structures with allocated strings
    alternatives: Arena allocator at CLI level, manual free in each use site
    chosen: Centralized free function for ergonomics and correctness
metrics:
  duration: 9 minutes
  tasks_completed: 2
  files_created: 1
  files_modified: 5
  lines_added: 700
  tests_added: 13
  commits: 2
  completed_at: 2026-02-14T15:37:00Z
---

# Phase 2 Plan 2: Config Discovery & Loading Summary

Config file discovery (upward search, XDG fallback) and loading (JSON + TOML) with validation implemented and tested.

## What Was Built

### Config Discovery (`src/cli/discovery.zig`)

**Upward search with .git boundary:**
- Searches from CWD upward through parent directories
- Checks four config filenames in locked priority order:
  1. `.complexityguard.json`
  2. `complexityguard.config.json`
  3. `.complexityguard.toml`
  4. `complexityguard.config.toml`
- Stops at .git directory boundary to respect project scope
- Prevents infinite loops with max 100 iterations

**XDG user config fallback:**
- Checks `$XDG_CONFIG_HOME/complexityguard/config.{json,toml}`
- Falls back to `~/.config/complexityguard/config.{json,toml}` on Unix
- Falls back to `%APPDATA%/complexityguard/config.{json,toml}` on Windows
- Returns null if no config found anywhere

**Explicit path override:**
- `--config` flag path takes precedence over all discovery
- Returns error if explicit path doesn't exist (for exit code 3 handling)

**Format detection:**
- `detectConfigFormat()` returns `.json` or `.toml` based on extension

### Config Loading (`src/cli/config.zig`)

**Multi-format support:**
- `loadConfig(allocator, path, format)` loads JSON or TOML
- Reads up to 1MB file size limit
- Uses `std.json.parseFromSlice` for JSON with `ignore_unknown_fields`
- Uses `toml.Parser(Config)` for TOML parsing

**Memory management:**
- Deep copies all strings from parser arena into caller's allocator
- Prevents memory leaks when parser arena is freed
- `freeConfig(allocator, config)` properly cleans up all allocations

**Validation:**
- `validate(config)` checks domain constraints:
  - Output format must be one of: console, json, sarif, html
  - Weights must be in range [0.0, 1.0]
  - Warning thresholds must be ≤ error thresholds
  - Thread count must be ≥ 1
- Returns specific errors: `InvalidFormat`, `InvalidWeights`, `InvalidThresholds`, `InvalidThreads`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] known-folders incompatible with Zig 0.15.2**
- **Found during:** Task 1 (config discovery implementation)
- **Issue:** known-folders library uses removed Zig 0.15.2 APIs (`std.Io.Cancelable`, `std.process.Environ.Map`)
- **Fix:** Implemented hand-rolled XDG config home detection using `std.posix.getenv`
- **Files modified:** src/cli/discovery.zig, build.zig, build.zig.zon
- **Commit:** 24171a0

**2. [Rule 1 - Bug] ArrayList.empty is constant, not function**
- **Found during:** Task 1 (running tests for first time)
- **Issue:** Zig 0.15.2 changed `ArrayList.init()` to `ArrayList.empty` (constant, not function)
- **Fix:** Changed `.empty(allocator)` to `.empty` with `.deinit(allocator)` in help.zig and config.zig
- **Files modified:** src/cli/help.zig, src/cli/config.zig
- **Commit:** 24171a0

## Tests Added

**Discovery tests (src/cli/discovery.zig):**
1. `detectConfigFormat returns .json for .json files`
2. `detectConfigFormat returns .toml for .toml files`
3. `discoverConfigPath with explicit path returns that path`
4. `discoverConfigPath returns null when no config exists`
5. `upward search stops at .git boundary`

**Loading tests (src/cli/config.zig):**
1. `loadConfig with valid JSON`
2. `loadConfig with valid TOML`
3. `JSON and TOML produce identical Config`

**Validation tests (src/cli/config.zig):**
1. `validate passes for default config`
2. `validate rejects invalid format`
3. `validate rejects negative weights`
4. `validate rejects warning > error threshold`
5. `validate rejects zero threads`

All tests pass with no memory leaks.

## Key Decisions

**Hand-rolled XDG detection:**
- Why: known-folders incompatible with Zig 0.15.2
- Trade-off: Simpler implementation, but less portable (only handles Unix/Windows basics)
- Future: Could add more platform-specific paths if needed

**Deep copy pattern:**
- Why: Parser arenas must be freed, but config data needs to outlive them
- Trade-off: Extra allocation overhead, but clean memory ownership
- Alternative considered: Keep arena alive, but complicates lifecycle

## Files Changed

**Created:**
- `src/cli/discovery.zig` (285 lines): Config discovery with upward search and XDG fallback

**Modified:**
- `src/cli/config.zig` (+415 lines): Added loadConfig, validate, freeConfig, deep copy logic
- `src/cli/help.zig` (2 lines): Fixed ArrayList API for Zig 0.15.2
- `build.zig` (-3 lines): Removed known-folders dependency
- `build.zig.zon` (-4 lines): Removed known-folders dependency entry
- `src/main.zig` (+1 line): Added discovery.zig test import

## Verification

```
zig build test
```

All 65 tests pass (52 existing + 13 new). No memory leaks detected.

## What's Next

Plan 02-03: Help text and error UX (already completed).
Plan 02-04: Main function integration (wire up discovery, loading, args).

---

## Self-Check: PASSED

**Files exist:**
- FOUND: src/cli/discovery.zig (285 lines)
- FOUND: src/cli/config.zig (loadConfig, validate, freeConfig present)

**Commits exist:**
- FOUND: 24171a0 (feat(02-02): implement config file discovery)
- FOUND: 8e5a7a2 (feat(02-02): implement config loading and validation)

**Tests pass:**
- 65/65 tests passed
- 0 memory leaks

**Functional verification:**
- Config discovery searches upward to .git boundary
- Four config filenames checked in correct priority
- XDG fallback works (tested with env var simulation)
- JSON and TOML both load into identical Config
- Validation rejects all invalid inputs tested
- Explicit --config path overrides discovery
