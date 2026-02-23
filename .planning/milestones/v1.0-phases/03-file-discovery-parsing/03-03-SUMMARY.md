---
phase: 03-file-discovery-parsing
plan: 03
subsystem: parser-orchestration
tags: [integration, parsing, orchestration, end-to-end]
one_liner: "File discovery and parsing pipeline with tree-sitter integration"
dependency_graph:
  requires:
    - "03-01 (tree-sitter bindings)"
    - "03-02 (file discovery walker)"
  provides:
    - "parseFile/parseFiles API"
    - "Language selection by extension"
    - "ParseSummary with statistics"
    - "End-to-end discovery → parsing flow"
  affects:
    - "main.zig (CLI analysis flow)"
    - "discovery/walker tests (fixture counts)"
tech_stack:
  added: []
  patterns:
    - "Parse orchestration layer over tree-sitter"
    - "Borrowed paths in ParseResult (memory efficiency)"
    - "Error collection during batch parsing"
    - "Optional config unwrapping for filter config"
key_files:
  created:
    - src/parser/parse.zig
  modified:
    - src/main.zig
    - src/discovery/walker.zig
    - tests/fixtures/typescript/react_component.tsx
    - tests/fixtures/javascript/jsx_component.jsx
    - tests/fixtures/typescript/syntax_error.ts
decisions:
  - summary: "ParseResult borrows path instead of owning it"
    rationale: "Avoids duplicate allocations - caller already owns discovered paths"
    impact: "Reduced memory allocations, cleaner ownership model"
  - summary: "Language selection checks .tsx before .ts"
    rationale: ".ts is a suffix of .tsx, must check longer extension first"
    impact: "Correct grammar selection for TSX files"
  - summary: "Syntax errors don't fail parsing"
    rationale: "Tree-sitter returns tree with ERROR nodes, allows continued analysis"
    impact: "Graceful degradation - analyze what's parseable, report errors"
metrics:
  duration: 4
  tasks_completed: 2
  files_created: 4
  tests_added: 13
  completed_at: "2026-02-14T19:12:48Z"
---

# Phase 03 Plan 03: Parse Orchestration and Integration Summary

**One-liner:** File discovery and parsing pipeline with tree-sitter integration

## What Was Built

This plan created the parse orchestration layer that connects file discovery (Plan 02) with tree-sitter bindings (Plan 01) into a working end-to-end pipeline. The tool now discovers TypeScript/JavaScript files and parses them with the correct tree-sitter grammar.

### Core Components

**src/parser/parse.zig** - Parse orchestration module:
- `selectLanguage()` - Maps file extensions to tree-sitter grammars
  - `.tsx` → TSX grammar
  - `.ts` → TypeScript grammar
  - `.jsx` → JavaScript grammar
  - `.js` → JavaScript grammar
- `parseFile()` - Reads file, selects language, parses with tree-sitter
  - Returns `ParseResult` with tree, language, error status, source
  - Borrows path from caller (no duplicate allocation)
  - Transfers ownership of tree and source to caller
- `parseFiles()` - Batch parsing with error collection
  - Returns `ParseSummary` with results and errors arrays
  - Continues parsing after individual file failures
  - Tracks counts: total, successful, with errors, failed
- `ParseSummary.deinit()` - Cleanup for all trees and sources

**main.zig integration:**
- Wires discovery → parsing pipeline
- Creates FilterConfig from config files (with optional unwrapping)
- Calls `walker.discoverFiles()` then `parse.parseFiles()`
- Prints summary: "Discovered N files, parsed M successfully, K with errors, J failed"
- Verbose mode shows per-file parse status with language and error flags

### Test Fixtures

Added three new fixture files for parser verification:
- `tests/fixtures/typescript/react_component.tsx` - TSX component with JSX elements
- `tests/fixtures/javascript/jsx_component.jsx` - JavaScript component with JSX
- `tests/fixtures/typescript/syntax_error.ts` - Intentionally broken TypeScript

Updated walker tests to account for new fixture counts (9 total files).

## Implementation Decisions

### 1. Borrowed Paths in ParseResult

ParseResult stores a borrowed path pointer instead of owning the path string. This avoids duplicate allocations since the caller (parseFiles) already owns the discovered file paths.

**Before (would leak):**
```zig
const full_path = try allocator.dupe(u8, relative_path); // Duplicate!
return ParseResult{ .path = relative_path, ... }; // Borrowed
```

**After:**
```zig
const full_path = if (base_dir) |dir|
    try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, relative_path })
else
    relative_path; // No allocation when base_dir is null
defer if (base_dir != null) allocator.free(full_path);
```

### 2. Extension Ordering in selectLanguage

Check `.tsx` before `.ts` because `.ts` is a suffix of `.tsx`. String matching must check longer extensions first.

```zig
if (std.mem.endsWith(u8, path, ".tsx")) return .tsx;  // Must be first!
if (std.mem.endsWith(u8, path, ".ts")) return .typescript;
```

### 3. Graceful Error Handling

Tree-sitter returns trees even for files with syntax errors (ERROR/MISSING nodes). We leverage this for graceful degradation:
- Parse succeeds → set `has_errors` flag if tree contains errors
- File read fails → collect in `errors` array, continue with other files
- User sees summary with both successful parses and failures

### 4. Optional Config Unwrapping

`Config.files` is optional. Main.zig unwraps it or provides empty FilterConfig:

```zig
const filter_config = if (cfg.files) |files|
    filter.FilterConfig{ .include_patterns = files.include, .exclude_patterns = files.exclude }
else
    filter.FilterConfig{};
```

## Testing

All tests pass (106 tests total):
- **selectLanguage routing** - Correct grammar for each extension
- **parseFile tests** - Parse .ts, .tsx, .js, .jsx files
- **Syntax error detection** - `has_errors` flag set for broken TypeScript
- **parseFiles batch** - Multiple files, error collection, correct counts
- **Memory cleanup** - No leaks (testing.allocator validates)
- **End-to-end CLI** - `zig build run -- tests/fixtures/` works

**Verification outputs:**

Single file:
```
$ zig build run -- tests/fixtures/typescript/simple_function.ts
Discovered 1 files, parsed 1 successfully
```

Full directory:
```
$ zig build run -- tests/fixtures/
Discovered 9 files, parsed 9 successfully, 1 with errors
```

Verbose mode:
```
$ zig build run -- --verbose tests/fixtures/typescript/
Discovered 6 files, parsed 6 successfully, 1 with errors

Parsed files:
  tests/fixtures/typescript//simple_function.ts [typescript]
  tests/fixtures/typescript//react_component.tsx [tsx]
  tests/fixtures/typescript//syntax_error.ts [typescript] (has errors)
  ...
```

Error handling:
```
$ zig build run -- --verbose nonexistent.ts tests/fixtures/typescript/simple_function.ts
Discovered 2 files, parsed 1 successfully, 1 failed

Parsed files:
  tests/fixtures/typescript/simple_function.ts [typescript]

Failed files:
  nonexistent.ts: FileNotFound
```

## Deviations from Plan

None - plan executed exactly as written. All tasks completed without architectural changes or blockers.

## What's Next

Phase 3 is now complete. The tool can:
- Discover TypeScript/JavaScript files recursively
- Filter by include/exclude patterns
- Parse files with correct tree-sitter grammar (.ts/.tsx/.js/.jsx)
- Handle syntax errors gracefully
- Report results with statistics

**Next phase (Phase 4):** AST traversal and function extraction. We'll walk parsed trees to identify function nodes, extract names/signatures, and build the function catalog for complexity analysis.

## Self-Check: PASSED

**Created files exist:**
```
FOUND: src/parser/parse.zig
FOUND: tests/fixtures/typescript/react_component.tsx
FOUND: tests/fixtures/javascript/jsx_component.jsx
FOUND: tests/fixtures/typescript/syntax_error.ts
```

**Commits exist:**
```
FOUND: 4df0a12 (Task 1 - test fixtures)
FOUND: cda4a1a (Task 2 - parse orchestration)
```

**Modified files updated:**
```
FOUND: src/main.zig (discovery and parsing integration)
FOUND: src/discovery/walker.zig (test fixture count updates)
```

**All tests pass:**
```
zig build test: EXIT CODE 0 (106 tests, no leaks)
```

**End-to-end verification:**
```
zig build run -- tests/fixtures/: SUCCESS (9 files, 1 with errors)
zig build run -- tests/fixtures/typescript/simple_function.ts: SUCCESS
zig build run -- --verbose tests/fixtures/typescript/: SUCCESS (shows TSX grammar)
```
