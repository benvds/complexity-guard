---
phase: quick-02
plan: 01
subsystem: output
tags: [name-extraction, console-output, json-output, tree-sitter]
dependency_graph:
  requires: [tree-sitter-byte-offsets, FunctionComplexity-struct]
  provides: [real-function-names, function-kind-indicators]
  affects: [console-formatting, json-output, all-tests]
tech_stack:
  added: [Node.startByte, Node.endByte, FunctionInfo]
  patterns: [byte-offset-slicing, kind-display-mapping]
key_files:
  created: []
  modified:
    - src/parser/tree_sitter.zig
    - src/metrics/cyclomatic.zig
    - src/output/console.zig
    - src/output/exit_codes.zig
    - src/output/json_output.zig
decisions:
  - slug: byte-offset-extraction
    summary: Use tree-sitter byte offsets (startByte/endByte) instead of point-based calculation
    rationale: Tree-sitter provides accurate byte offsets; point-to-byte conversion (row*1000+col) was incorrect
  - slug: function-info-struct
    summary: Created FunctionInfo struct to return both name and kind from extraction
    rationale: Cleaner API than returning tuple or multiple values
  - slug: kind-capitalization
    summary: Display capitalized kind labels (Function, Method, Arrow function, Generator)
    rationale: More professional output; "Arrow function" reads better than "arrow"
metrics:
  tasks_completed: 2
  duration_minutes: 4
  files_modified: 5
  tests_updated: 24
  completed_date: 2026-02-15
---

# Quick Task 2: Show Function Indicator and Actual Function Names

**One-liner:** Real function names extracted via byte offsets with kind indicators (Function, Method, Arrow function, Generator) in console and JSON output.

## Summary

Replaced placeholder function names (`<function>`, `<method>`, `<variable>`) with actual identifiers extracted from source code using tree-sitter byte offsets. Added function kind field throughout the analysis pipeline and updated console output to display capitalized kind labels alongside real names.

**Before:** `Function '<function>' has complexity 5`
**After:** `Function 'calculateTotal' has complexity 5` or `Method 'process' has complexity 12`

## Tasks Completed

### Task 1: Add byte offset methods and extract real function names
- **Commit:** fdde352
- **Files:**
  - src/parser/tree_sitter.zig: Added `startByte()` and `endByte()` methods to Node wrapper
  - src/metrics/cyclomatic.zig: Created `FunctionInfo` struct, updated `extractFunctionInfo` to slice source text, added `function_kind` field to FunctionComplexity and ThresholdResult
  - src/output/*.zig: Updated all test fixtures to include function_kind field

**Changes:**
- `Node.startByte()` and `Node.endByte()` call tree-sitter C API functions
- `extractFunctionInfo` returns `FunctionInfo{ name, kind }` instead of just name
- Variable declarator handling fixed: extracts actual identifier text using byte offsets (removed incorrect row*1000+col calculation)
- Kind determined from node type: "function_declaration" → "function", "arrow_function" → "arrow", etc.
- Updated 24 test fixtures across cyclomatic.zig, console.zig, json_output.zig, exit_codes.zig

**Verification:**
- All tests pass (zig build test)
- Integration test verifies real names: "baseline", "arrowFunc", "process"
- No placeholders in test output except `<anonymous>` for truly anonymous functions

### Task 2: Update console output format to show kind + name
- **Commit:** 53021f1
- **Files:**
  - src/output/console.zig: Added kind capitalization logic, updated format string

**Changes:**
- `formatFileResults` maps kind to display label: "function" → "Function", "arrow" → "Arrow function", "method" → "Method", "generator" → "Generator"
- Format string changed from `Function '{s}'` to `{s} '{s}'` where first placeholder is capitalized kind
- Hotspot display unchanged (just name is fine for compact list)

**Verification:**
- Console output shows: `Function 'baseline'`, `Arrow function 'arrowFunc'`, `Method 'process'`
- JSON output verified: `"name": "baseline"`, `"name": "simpleConditionals"`, etc.
- All tests pass

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

**Tests:** All pass (zig build test)

**Console output verification:**
```
Function 'baseline' has complexity 1
Function 'simpleConditionals' has complexity 3
Arrow function 'arrowFunc' has complexity 2
Method 'process' has complexity 2
```

**JSON output verification:**
```json
{
  "name": "baseline",
  "name": "simpleConditionals",
  "name": "arrowFunc"
}
```

**No placeholders:** Confirmed zero occurrences of `<function>`, `<method>`, `<variable>` in output (only `<anonymous>` for genuinely anonymous functions).

## Technical Notes

**Tree-sitter byte offsets:**
- `ts_node_start_byte()` and `ts_node_end_byte()` return absolute byte positions in source
- Safe slicing: verify `start_byte < source.len && end_byte <= source.len` before slicing
- Handles UTF-8 correctly (tree-sitter byte offsets respect UTF-8 boundaries)

**Kind detection:**
- Function declarations and expressions → "function"
- Method definitions → "method"
- Arrow functions → "arrow"
- Generator functions/declarations → "generator"
- Variable context doesn't override kind (variable name used, but kind reflects actual function type)

**Test coverage:**
- 24 test fixtures updated across 4 files
- Integration test verifies named function extraction from real TypeScript fixture
- Placeholder detection added to integration test (ensures no regressions)

## Impact

**User-facing:**
- Console output now shows real function names with descriptive kind labels
- JSON output includes actual identifiers for downstream tooling
- Easier to identify which functions need refactoring

**Developer-facing:**
- Node wrapper complete with byte offset access
- FunctionInfo pattern established for multi-value extraction
- All tests updated with real expectations (no more placeholder acceptance)

## Self-Check: PASSED

**Created files exist:** None created (only modifications)

**Modified files exist:**
```
FOUND: src/parser/tree_sitter.zig
FOUND: src/metrics/cyclomatic.zig
FOUND: src/output/console.zig
FOUND: src/output/exit_codes.zig
FOUND: src/output/json_output.zig
```

**Commits exist:**
```
FOUND: fdde352
FOUND: 53021f1
```

**Runtime verification:**
```
zig build run -- --verbose tests/fixtures/typescript/cyclomatic_cases.ts
Output shows: Function 'baseline', Arrow function 'arrowFunc', Method 'process'
```
