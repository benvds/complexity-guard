---
phase: quick-02
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/parser/tree_sitter.zig
  - src/metrics/cyclomatic.zig
  - src/output/console.zig
autonomous: true
must_haves:
  truths:
    - "Console output shows actual function names instead of placeholders like <function>, <method>, <variable>"
    - "Console output shows function kind indicator alongside the name (e.g., 'function calculateTotal', 'method process', 'arrow handler')"
    - "JSON output shows actual function names instead of placeholders"
    - "All existing tests pass with updated expectations"
  artifacts:
    - path: "src/parser/tree_sitter.zig"
      provides: "startByte and endByte methods on Node wrapper"
    - path: "src/metrics/cyclomatic.zig"
      provides: "Actual name extraction from source using byte offsets, function_kind field"
    - path: "src/output/console.zig"
      provides: "Display format using kind + name instead of hardcoded Function prefix"
  key_links:
    - from: "src/metrics/cyclomatic.zig"
      to: "src/parser/tree_sitter.zig"
      via: "Node.startByte()/endByte() for source text slicing"
      pattern: "startByte.*endByte"
    - from: "src/output/console.zig"
      to: "src/metrics/cyclomatic.zig"
      via: "ThresholdResult.function_kind field"
      pattern: "function_kind"
---

<objective>
Extract and display actual function names from source code instead of placeholder strings.

Purpose: Currently all functions show as `<function>`, `<method>`, `<variable>`, or `<anonymous>` because the name extraction code finds the identifier AST node but never reads the actual text from the source. The tree-sitter Node wrapper lacks byte offset methods needed to slice the source string. This task adds byte offsets, fixes name extraction, and updates the console output to show kind + name (e.g., "function calculateTotal", "method process").

Output: Real function names in both console and JSON output, with kind indicators.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@src/parser/tree_sitter.zig
@src/metrics/cyclomatic.zig
@src/output/console.zig
@src/output/json_output.zig
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add byte offset methods to Node and extract real function names</name>
  <files>src/parser/tree_sitter.zig, src/metrics/cyclomatic.zig</files>
  <action>
  **In src/parser/tree_sitter.zig:**
  Add two methods to the `Node` struct:
  - `pub fn startByte(self: Node) u32` -- calls `c.ts_node_start_byte(self.inner)` and returns the result
  - `pub fn endByte(self: Node) u32` -- calls `c.ts_node_end_byte(self.inner)` and returns the result

  **In src/metrics/cyclomatic.zig:**

  1. Add a `function_kind` field to `FunctionComplexity` struct:
     ```zig
     kind: []const u8,  // "function", "method", "arrow", "generator"
     ```

  2. Add a `function_kind` field to `ThresholdResult` struct:
     ```zig
     function_kind: []const u8,
     ```

  3. Fix `extractFunctionName` to use byte offsets to slice source text. The function already receives `source: []const u8` and finds the identifier child node. Instead of returning `"<function>"`, slice the source:
     ```zig
     const start_byte = child.startByte();
     const end_byte = child.endByte();
     if (start_byte < source.len and end_byte <= source.len) {
         return source[start_byte..end_byte];
     }
     ```
     Do the same for `property_identifier` in the method_definition branch (returns `"<method>"` currently).
     Keep `"<anonymous>"` as fallback for arrow functions / function expressions without parent context (these genuinely have no name node).

  4. Change `extractFunctionName` to also return the kind, or create a separate `extractFunctionKind` function. The kind is derived from the node_type:
     - `"function_declaration"` -> `"function"`
     - `"generator_function_declaration"` -> `"generator"`
     - `"generator_function"` -> `"generator"`
     - `"method_definition"` -> `"method"`
     - `"arrow_function"` -> `"arrow"`
     - `"function"` (expression) -> `"function"`

     Simplest approach: create a new struct `FunctionInfo` with `name` and `kind` fields, and change `extractFunctionName` to return `FunctionInfo`. Or add a standalone `extractFunctionKind(node: tree_sitter.Node) []const u8` function.

  5. Fix `walkAndAnalyze` variable_declarator handler (around line 418-438). Currently sets `child_context = "<variable>"`. Instead, use byte offsets to extract the actual identifier text:
     ```zig
     const id_start_byte = child.startByte();
     const id_end_byte = child.endByte();
     if (id_start_byte < source.len and id_end_byte <= source.len) {
         child_context = source[id_start_byte..id_end_byte];
     }
     ```
     Remove the unused `start_byte`/`end_byte` calculations using row*1000+column (lines 428-433) -- those were the incorrect workaround.

  6. Update `walkAndAnalyze` to populate the `kind` field in `FunctionComplexity`. When parent_context is set (variable_declarator provided name), the kind should reflect the actual function node type (arrow, function expression, etc.), not the variable.

  7. Update `analyzeFile` to propagate `function_kind` from `FunctionComplexity` to `ThresholdResult`.

  8. Update `toFunctionResults` if it references changed fields.

  9. Update ALL existing tests that construct `ThresholdResult` or `FunctionComplexity` literals to include the new `function_kind` field. This includes tests in cyclomatic.zig and any tests in console.zig and json_output.zig that construct ThresholdResult literals (search for `.function_name =` to find them all). Set appropriate kind values like `"function"` in test fixtures.

  10. Update the `analyzeFunctions` integration test ("integration: cyclomatic_cases.ts fixture") to verify that actual function names are extracted (no more checking only complexity values -- also verify at least some names are real identifiers, not placeholders).

  Note: The existing test "analyzeFunctions finds multiple functions" expects 2 results -- function names should now be the actual names from the source (`"foo"` and `"bar"` instead of `"<function>"`). Update expectations accordingly.
  </action>
  <verify>
  Run `zig build test` -- all tests pass. Specifically verify:
  - "analyzeFunctions finds multiple functions" test now gets actual names "foo" and "bar"
  - Integration test with cyclomatic_cases.ts fixture extracts real function names
  - No `<function>`, `<method>`, or `<variable>` placeholders appear in test output (only `<anonymous>` for genuinely anonymous functions is acceptable)
  </verify>
  <done>
  extractFunctionName returns actual identifier text from source. FunctionComplexity and ThresholdResult carry function_kind. All tests pass with real names.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update console output format to show kind + name</name>
  <files>src/output/console.zig</files>
  <action>
  1. Update the format string in `formatFileResults` (line 106) from:
     ```
     Function '{s}' has complexity {d}
     ```
     to:
     ```
     {s} '{s}' has complexity {d}
     ```
     where the first `{s}` is `result.function_kind` (capitalized for display, e.g., "Function", "Method", "Arrow", "Generator").

     To capitalize the first letter for display: use a simple helper or inline logic. Since kinds are known constants, a switch or lookup works:
     ```zig
     const kind_display = if (std.mem.eql(u8, result.function_kind, "function"))
         "Function"
     else if (std.mem.eql(u8, result.function_kind, "method"))
         "Method"
     else if (std.mem.eql(u8, result.function_kind, "arrow"))
         "Arrow function"
     else if (std.mem.eql(u8, result.function_kind, "generator"))
         "Generator"
     else
         "Function";
     ```

  2. Update the `formatSummary` hotspot display to also show kind if desired, or keep it as-is (just name is fine for hotspots since they're already compact).

  3. Update console.zig tests that check for specific output strings. Tests that check for `"Function '"` in output need to match the new format. Since test ThresholdResults now have `function_kind`, the output will use it.
  </action>
  <verify>
  Run `zig build test` -- all tests pass.
  Run `zig build run -- --verbose tests/fixtures/` (or a similar command with a test file) and visually confirm output shows actual function names with kind indicators instead of `<function>` placeholders.
  </verify>
  <done>
  Console output shows lines like `Function 'calculateTotal' has complexity 5` or `Method 'process' has complexity 12` or `Arrow function 'handler' has complexity 3` instead of `Function '<function>' has complexity 5`.
  </done>
</task>

</tasks>

<verification>
- `zig build test` passes with zero failures
- `zig build run -- --verbose tests/fixtures/typescript/cyclomatic_cases.ts` shows real function names
- `zig build run -- --format json tests/fixtures/typescript/cyclomatic_cases.ts` JSON output contains real function names
- No occurrences of `<function>`, `<method>`, or `<variable>` in output (only `<anonymous>` for truly anonymous functions)
</verification>

<success_criteria>
1. All function names in console and JSON output are actual identifiers extracted from source code
2. Each function line shows a kind indicator (Function, Method, Arrow function, Generator) before the name
3. All existing tests pass (updated with new field and real name expectations)
4. Anonymous functions (arrow/expression without variable assignment) still show `<anonymous>` gracefully
</success_criteria>

<output>
After completion, create `.planning/quick/2-show-function-indicator-and-actual-funct/2-SUMMARY.md`
</output>
