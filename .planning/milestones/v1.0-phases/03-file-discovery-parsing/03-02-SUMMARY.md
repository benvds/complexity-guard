---
phase: 03-file-discovery-parsing
plan: 02
subsystem: discovery
tags: [file-discovery, directory-traversal, filtering, tree-sitter-build]
dependency_graph:
  requires:
    - src/cli/config.zig (FilterConfig pattern)
  provides:
    - src/discovery/filter.zig (isTargetFile, isExcludedDir, shouldIncludeFile)
    - src/discovery/walker.zig (discoverFiles, DiscoveryResult)
  affects:
    - Phase 03 Plan 03 (will use discoverFiles for file input)
tech_stack:
  added:
    - std.fs.Dir.walk (recursive directory iteration)
    - std.ArrayList (path collection)
  patterns:
    - Arena allocator for walker internal state
    - Owned paths pattern with explicit deinit
    - Try-directory-first pattern for file/dir detection
key_files:
  created:
    - src/discovery/filter.zig (extension and directory filtering logic)
    - src/discovery/walker.zig (recursive file discovery)
  modified:
    - src/main.zig (added test imports)
    - build.zig (fixed tree-sitter compilation flags)
decisions:
  - decision: "Simple pattern matching for include/exclude (endsWith, indexOf)"
    rationale: "Defer full glob support to later phase per research recommendation"
    alternatives: ["Implement full glob immediately", "Use regex"]
    impact: "Simpler implementation, sufficient for common cases like *.test.ts"

  - decision: "Try-directory-first pattern for path type detection"
    rationale: "openDir().close() is cleaner than statFile with IsDir error handling"
    alternatives: ["Use statFile and check mode", "Use access()"]
    impact: "More readable code, works reliably across platforms"

  - decision: "Added POSIX and DEFAULT_SOURCE defines to tree-sitter build"
    rationale: "Required for fdopen, le16toh, be16toh POSIX/BSD functions"
    alternatives: ["Use different tree-sitter version", "Patch source code"]
    impact: "Enables tree-sitter compilation on Linux without external ICU dependency"
metrics:
  duration_min: 5
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  tests_added: 20
  completed_at: "2026-02-14T19:01:16Z"
---

# Phase 03 Plan 02: File Discovery Subsystem Summary

**One-liner:** Recursive directory walker with extension filtering (.ts/.tsx/.js/.jsx), excluding .d.ts and node_modules directories.

## Objective Achieved

Created file discovery subsystem that recursively walks directories to find TypeScript and JavaScript source files, filtering by extension and excluding non-source directories. The subsystem is independent of tree-sitter parsing and tested against real fixture files.

## Tasks Completed

### Task 1: Create file extension filter module
**Commit:** c14c1ce
**Files:** src/discovery/filter.zig, src/main.zig

- Defined FilterConfig struct for include/exclude patterns
- Created isTargetFile() to detect .ts/.tsx/.js/.jsx extensions
- Excluded TypeScript declaration files (.d.ts, .d.tsx)
- Created isExcludedDir() for common non-source directories (node_modules, .git, dist, etc.)
- Implemented shouldIncludeFile() with simple pattern matching
- Added 11 inline tests verifying extension matching and exclusions

### Task 2: Create recursive directory walker
**Commit:** c632275
**Files:** src/discovery/walker.zig, build.zig, src/main.zig

- Defined DiscoveryResult struct with owned paths and metadata
- Implemented discoverFiles() supporting both files and directories
- Used std.fs.Dir.walk() for recursive traversal
- Filtered directories via containsExcludedDir() path component check
- Properly duplicated walker paths (walker reuses buffer)
- Fixed tree-sitter build with include path and POSIX defines
- Added 9 inline tests against real tests/fixtures/ directory

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Tree-sitter compilation missing include path**
- **Found during:** Task 2 test execution
- **Issue:** tree-sitter unicode headers not found
- **Fix:** Added vendor/tree-sitter/lib/src to include path
- **Files modified:** build.zig
- **Commit:** c632275

**2. [Rule 3 - Blocking] Tree-sitter missing POSIX function declarations**
- **Found during:** Task 2 test execution
- **Issue:** fdopen, le16toh, be16toh undeclared
- **Fix:** Added -D_POSIX_C_SOURCE=200809L and -D_DEFAULT_SOURCE
- **Files modified:** build.zig
- **Commit:** c632275

**3. [Rule 1 - Bug] ArrayList.empty() syntax error**
- **Found during:** Task 2 compilation
- **Issue:** Used .empty() as function call instead of const value
- **Fix:** Changed to .empty per Zig 0.15.2 API
- **Files modified:** src/discovery/walker.zig
- **Commit:** c632275

**4. [Rule 1 - Bug] Directory detection using statFile**
- **Found during:** Task 2 test execution
- **Issue:** statFile with IsDir error handling failed tests
- **Fix:** Switched to try-directory-first pattern
- **Files modified:** src/discovery/walker.zig
- **Commit:** c632275

**5. [Rule 1 - Bug] Empty directory test path missing parent**
- **Found during:** Task 2 test execution
- **Issue:** zig-cache parent dir didn't exist
- **Fix:** Changed to .zig-cache/test-empty-dir
- **Files modified:** src/discovery/walker.zig
- **Commit:** c632275

## Verification Results

- All tests pass (zig build test - 80/80)
- Discovery finds 4 .ts files in tests/fixtures/typescript
- Discovery finds 2 .js files in tests/fixtures/javascript
- Discovery finds 6 total files in tests/fixtures
- .d.ts files excluded correctly
- node_modules directories excluded
- Single file paths work
- No memory leaks (testing.allocator)

## Self-Check: PASSED

Created files verified:
- FOUND: src/discovery/filter.zig
- FOUND: src/discovery/walker.zig

Commits verified:
- FOUND: c14c1ce
- FOUND: c632275

All tests passing:
- zig build test (80/80 passed)
