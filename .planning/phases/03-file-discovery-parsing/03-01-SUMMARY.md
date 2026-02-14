---
phase: 03-file-discovery-parsing
plan: 01
subsystem: parser
tags: [tree-sitter, c-interop, zig-bindings, ast-parsing]
dependency_graph:
  requires:
    - vendor/tree-sitter/ (C library source)
    - vendor/tree-sitter-typescript/ (TypeScript/TSX grammars)
    - vendor/tree-sitter-javascript/ (JavaScript grammar)
    - build.zig (C compilation configuration)
  provides:
    - src/parser/tree_sitter.zig (Parser, Tree, Node, Language types)
  affects:
    - Phase 03 Plan 03 (will use Parser to create ASTs from source files)
tech_stack:
  added:
    - tree-sitter C API (via @cImport)
    - extern fn declarations (language grammar functions)
  patterns:
    - C interop via @cImport and @cInclude
    - Wrapper structs for C pointers (*c.TSParser -> Parser)
    - Optional returns for fallible operations (?Node for out-of-bounds)
    - RAII with init/deinit pairs
key_files:
  created:
    - src/parser/tree_sitter.zig (tree-sitter Zig bindings)
  modified:
    - src/main.zig (added parser test import)
    - build.zig (added unicode include path)
decisions:
  - decision: "Wrapper types for tree-sitter C API"
    rationale: "Provide idiomatic Zig interface hiding C pointer details"
    alternatives: ["Direct C API usage", "Opaque pointers"]
    impact: "Safer API, enforces init/deinit pairs, ?Node for bounds checking"

  - decision: "Language enum with toTSLanguage() method"
    rationale: "Type-safe language selection vs raw function pointers"
    alternatives: ["Direct extern fn calls", "String-based language names"]
    impact: "Compile-time safety, clear API, no invalid language values"

  - decision: "Node wraps TSNode by value, not pointer"
    rationale: "TSNode is small struct (32 bytes), tree-sitter passes by value"
    alternatives: ["Wrap *c.TSNode pointer"]
    impact: "Matches C API semantics, no pointer lifetime issues"
metrics:
  duration_min: 9
  tasks_completed: 2
  files_created: 1
  files_modified: 2
  tests_added: 11
  completed_at: "2026-02-14T19:04:29Z"
---

# Phase 03 Plan 01: Tree-sitter Integration Summary

**One-liner:** Zig bindings wrapping tree-sitter C API with Parser, Tree, and Node types for TypeScript, TSX, and JavaScript parsing.

## Objective Achieved

Established C interop foundation for all parsing work by vendoring tree-sitter C libraries as git submodules, configuring build.zig to compile them, and creating safe Zig wrapper types that expose parser creation, language selection, string parsing, and AST node traversal.

## Tasks Completed

### Task 1: Vendor tree-sitter and configure build.zig
**Status:** Already completed in commit c14c1ce (03-02 plan)
**Note:** Tree-sitter submodules and build configuration were added in a previous execution

The following work was already done:
- Git submodules added for tree-sitter core, tree-sitter-typescript, tree-sitter-javascript
- build.zig configured with addTreeSitterSources() helper function
- C compilation flags added: -std=c11, -fno-sanitize=undefined, -D_POSIX_C_SOURCE=200809L, -D_DEFAULT_SOURCE
- Include paths added for all three parsers

### Task 2: Create tree-sitter Zig bindings module
**Commit:** 1d1c3ac
**Files:** src/parser/tree_sitter.zig, src/main.zig, build.zig

- Created Parser struct wrapping *c.TSParser
  - init() creates parser, returns error if null
  - deinit() frees parser
  - setLanguage() configures parser for typescript/tsx/javascript
  - parseString() parses source and returns Tree

- Created Tree struct wrapping *c.TSTree
  - rootNode() returns root Node
  - deinit() calls ts_tree_delete

- Created Node struct wrapping c.TSNode by value
  - hasError() checks for parse errors
  - childCount() returns number of children
  - nodeType() returns type string (e.g., "program")
  - startPoint() and endPoint() return source positions
  - child(index) returns ?Node (null if out of bounds)

- Created Language enum with typescript, tsx, javascript variants
  - toTSLanguage() returns C language struct pointer

- Created Point struct with row/column fields for source positions

- Declared extern language functions:
  - tree_sitter_typescript()
  - tree_sitter_tsx()
  - tree_sitter_javascript()

- Added 11 comprehensive inline tests:
  - Parser creation and destruction
  - Language setting for all three variants
  - String parsing with "const x = 1;"
  - Root node has no errors
  - Root node type is "program"
  - Root node has children
  - Child node access works
  - Out-of-bounds child returns null
  - Nodes have start and end points

- Updated src/main.zig test block to import parser module

## Deviations from Plan

### Out-of-order Execution

**Context:** Plan 03-01 was executed after plan 03-02 had already been completed. This resulted in Task 1 work (tree-sitter vendoring and build configuration) already being present in the codebase from commit c14c1ce.

**Resolution:** Skipped redundant work for Task 1, proceeded directly to Task 2 (Zig bindings), which was not yet implemented. Documented this execution order anomaly.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing unicode include path**
- **Found during:** Task 2 test execution
- **Issue:** build.zig missing vendor/tree-sitter/lib/src/unicode include path, causing "unicode/umachine.h not found" errors
- **Fix:** Added step.addIncludePath(b.path("vendor/tree-sitter/lib/src/unicode"))
- **Files modified:** build.zig
- **Commit:** 1d1c3ac
- **Note:** This path was missing from the c632275 commit that added tree-sitter build config

## Verification Results

- zig build compiles successfully with tree-sitter C sources linked
- zig build test passes all tests (existing + new tree_sitter.zig tests)
- Parser can be created and set to TypeScript, TSX, and JavaScript languages
- Parser parses "const x = 1;" and returns valid AST with root node type "program"
- Root node has no errors and has children
- Child node access works with bounds checking
- No memory leaks detected by std.testing.allocator

## Key Implementation Details

**C interop pattern:** Use @cImport with @cInclude for header access, wrap C types in Zig structs

**Extern functions:** Declare tree_sitter_typescript() etc. as extern - these are provided by compiled parser.c files

**Node by value:** TSNode is small (32 bytes), tree-sitter API passes by value, so Node wraps c.TSNode directly (not pointer)

**Tree by pointer:** TSTree is opaque, so Tree wraps *c.TSTree pointer and owns cleanup

**Parser by pointer:** TSParser is opaque, so Parser wraps *c.TSParser and owns cleanup

**Optional child:** child(index) returns ?Node to handle out-of-bounds safely

**Point extraction:** Convert c.TSPoint to Zig Point struct with row/column fields

**String handling:** Use std.mem.span() to convert C string from ts_node_type() to Zig slice

## Dependencies Satisfied

**Requires:**
- tree-sitter C library (vendored in vendor/tree-sitter/)
- TypeScript/TSX grammars (vendored in vendor/tree-sitter-typescript/)
- JavaScript grammar (vendored in vendor/tree-sitter-javascript/)
- build.zig C compilation configuration (addTreeSitterSources helper)

**Provides for downstream:**
- Parser type - create parsers and set language
- Tree type - AST result with root node
- Node type - traverse AST, check errors, get types/positions
- Language enum - type-safe language selection

## Integration Points

**Used by Phase 03 Plan 03:** Will import tree_sitter.zig and use Parser to parse discovered files into ASTs

**Depends on build.zig:** Requires C compilation of tree-sitter and language grammars

**Tested independently:** All bindings have inline tests, no dependencies on other subsystems

## Self-Check: PASSED

Created files verified:
```
FOUND: src/parser/tree_sitter.zig
```

Modified files verified:
```
FOUND: src/main.zig (parser import added)
FOUND: build.zig (unicode path added)
```

Commits verified:
```
FOUND: 1d1c3ac (feat(03-01): create tree-sitter Zig bindings module)
```

All tests passing:
```
zig build test (91/91 passed - includes 11 new parser tests)
```

Build succeeds:
```
zig build (completed without errors)
```

Submodules present:
```
FOUND: vendor/tree-sitter/
FOUND: vendor/tree-sitter-typescript/
FOUND: vendor/tree-sitter-javascript/
```
