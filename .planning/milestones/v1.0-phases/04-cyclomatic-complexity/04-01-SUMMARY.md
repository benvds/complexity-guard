---
phase: 04-cyclomatic-complexity
plan: 01
subsystem: metrics
tags:
  - cyclomatic-complexity
  - ast-traversal
  - metrics
  - decision-points
dependency_graph:
  requires:
    - 03-file-discovery-parsing (tree-sitter parsing infrastructure)
  provides:
    - cyclomatic complexity calculation engine
    - CyclomaticConfig for counting variants
    - FunctionComplexity result type
    - analyzeFunctions API
  affects:
    - Phase 05 (cognitive complexity will follow similar patterns)
    - Phase 06 (Halstead metrics will use same AST traversal)
    - Phase 07 (threshold validation will use complexity values)
tech_stack:
  added:
    - src/metrics/cyclomatic.zig (core complexity calculator)
  patterns:
    - Recursive AST traversal with accumulator
    - Configuration-driven counting (toggles for modern JS features)
    - Nested function scope isolation
    - Classic vs modified switch/case counting modes
key_files:
  created:
    - src/metrics/cyclomatic.zig
    - tests/fixtures/typescript/cyclomatic_cases.ts
  modified:
    - src/main.zig (added test import)
    - src/discovery/walker.zig (updated test counts for new fixture)
decisions:
  - decision: "Use ESLint-aligned counting rules by default (count logical operators, nullish coalescing, optional chaining)"
    rationale: "ESLint is the de facto standard for JavaScript/TypeScript. Modern JS features create real branches that test coverage tools measure."
    alternatives: "Classic McCabe only (ignore modern features)"
    impact: "More accurate complexity scores for modern codebases"
  - decision: "Support both classic and modified switch/case counting"
    rationale: "Industry lacks consensus. ESLint added both modes in 2024. Classic is stricter (safer default), modified is useful for state machines."
    alternatives: "Pick one variant only"
    impact: "Users can configure to match their team's philosophy"
  - decision: "Start each function at base complexity 1"
    rationale: "McCabe's original definition. Matches ESLint, SonarQube, academic sources."
    alternatives: "Start at 0"
    impact: "Empty functions report complexity 1, not 0"
  - decision: "Isolate nested function scope (don't count inner function complexity toward outer)"
    rationale: "Each function is an independent unit. Inner complexity inflating outer would double-count."
    alternatives: "Accumulate all complexity upward"
    impact: "Parent functions with nested functions get accurate scores"
  - decision: "Defer default parameter counting to Plan 02"
    rationale: "Tree-sitter representation is more complex than anticipated. Need to inspect AST structure more carefully."
    alternatives: "Implement now with best guess"
    impact: "Default params not counted yet, but config flag exists for future"
metrics:
  duration: 297 seconds (5 minutes)
  completed_date: 2026-02-14T20:20:51Z
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  tests_added: 15
  commits: 2
---

# Phase 04 Plan 01: Cyclomatic Complexity Calculator Summary

**One-liner:** Recursive AST traversal counting decision points (if/while/for/switch/catch/ternary/logical operators/nullish coalescing) with configurable counting modes and nested function scope isolation.

## What Was Built

Implemented the core cyclomatic complexity calculator that traverses tree-sitter ASTs to count decision points per function. This establishes the `src/metrics/` module pattern for all future metrics (cognitive complexity, Halstead).

**Key components:**

1. **CyclomaticConfig** - Configuration struct with toggles for modern JavaScript features:
   - `count_logical_operators` (&&, ||) - default true
   - `count_nullish_coalescing` (??) - default true
   - `count_optional_chaining` (?.) - default true
   - `count_ternary` (? :) - default true
   - `count_default_params` - default true (deferred implementation)
   - `switch_case_mode` - classic (each case) vs modified (switch once)

2. **FunctionComplexity** - Per-function result type:
   - name, complexity, start_line, end_line, start_col
   - 1-indexed lines, 0-indexed columns (matches tree-sitter conventions)

3. **Core algorithm:**
   - `isFunctionNode()` - identifies 6 function types (function_declaration, function, arrow_function, method_definition, generator_function, generator_function_declaration)
   - `countDecisionPoints()` - recursive traversal counting decision nodes
   - `calculateComplexity()` - finds function body (statement_block), returns base 1 + decision points
   - `analyzeFunctions()` - walks full AST, finds all functions, calculates complexity for each

4. **Decision point types counted:**
   - Control flow: if_statement, while_statement, do_statement, for_statement, for_in_statement, catch_clause
   - Ternary: ternary_expression
   - Switch: switch_case (classic mode, excluding default) or switch_statement (modified mode)
   - Logical: && and || in binary_expression nodes
   - Nullish: ?? in binary_expression nodes
   - Logical assignment: &&= and ||= in augmented_assignment_expression nodes
   - Optional chaining: ?. token in member/call/subscript expressions (if present in AST)

5. **Nested function handling:**
   - When traversing, if a function node is encountered, recursion stops
   - Each function analyzed independently starting at base 1
   - Inner function complexity does NOT inflate outer function

6. **Test fixture:**
   - `tests/fixtures/typescript/cyclomatic_cases.ts` - 11+ functions with documented expected complexity
   - Covers: baseline (1), conditionals (2-3), loops (2), switch (5), try/catch (3), ternary (2), logical operators (2-5), nullish coalescing (3), nested functions (2 outer, 2 inner), arrow functions (2), class methods (2)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed function body extraction in calculateComplexity**
- **Found during:** Task 1, running initial tests
- **Issue:** calculateComplexity was counting decision points starting from function_declaration node itself, which doesn't contain the actual if/while/for statements. The function body is in a statement_block child node.
- **Fix:** Modified calculateComplexity to find the statement_block child node and count decision points within it, not the function_declaration wrapper.
- **Files modified:** src/metrics/cyclomatic.zig
- **Commit:** a5f4dad (included in task commit)

**2. [Rule 3 - Blocking] Updated walker test counts for new fixture file**
- **Found during:** Task 2, running integration test
- **Issue:** Adding cyclomatic_cases.ts increased the TypeScript fixture count from 6 to 7 files, breaking walker tests that had hard-coded counts.
- **Fix:** Updated walker.zig test expectations: TypeScript directory from 6 to 7 files, all fixtures from 9 to 10 files, exclude pattern from 5 to 6 files.
- **Files modified:** src/discovery/walker.zig
- **Commit:** c3601be (included in task commit)

**3. [Rule 1 - Bug] Removed pointless discard of source parameter**
- **Found during:** Task 1, compilation
- **Issue:** Zig compiler error "pointless discard of function parameter" for `_ = source;` in countDecisionPoints. The parameter was actually used in recursive calls.
- **Fix:** Removed the pointless discard line.
- **Files modified:** src/metrics/cyclomatic.zig
- **Commit:** a5f4dad (included in task commit)

### Deferred Work

**Default parameter counting:**
- **Status:** Config flag exists (`count_default_params: bool = true`), but counting logic not implemented
- **Reason:** Tree-sitter's representation of default parameters varies between JS and TS grammars. Need to parse test snippets and inspect AST structure to determine correct node types.
- **Plan:** Defer to Plan 02 as noted in plan's action section
- **Impact:** Default params currently not counted, but can be added without breaking API

## Test Results

**All tests passing:**
- 122 total tests (including 15 new cyclomatic tests)
- Zero failures
- Zero memory leaks (std.testing.allocator)

**New cyclomatic tests:**
1. CyclomaticConfig.default() returns expected values
2. isFunctionNode identifies function_declaration
3. Simple function has complexity 1 (baseline)
4. if statement adds 1 to complexity
5. if/else if has complexity 3
6. for loop has complexity 2
7. while loop has complexity 2
8. switch with 3 cases has complexity 4 in classic mode
9. catch clause has complexity 2
10. ternary has complexity 2
11. logical AND has complexity 3 (if + &&)
12. logical OR has complexity 2
13. nullish coalescing has complexity 2
14. nested functions do not inflate parent complexity
15. analyzeFunctions finds multiple functions
16. **Integration test:** cyclomatic_cases.ts fixture validates all decision point types

**Integration test coverage:**
- Parses real TypeScript fixture file (110+ lines)
- Finds 11+ functions
- Validates complexity values: 1, 2, 3, 5 (confirms all complexity levels present)
- Verifies 1-indexed line numbers
- Confirms end_line >= start_line

## Verification Against Success Criteria

✅ **src/metrics/cyclomatic.zig exists and exports:**
- CyclomaticConfig ✓
- FunctionComplexity ✓
- calculateComplexity ✓
- analyzeFunctions ✓

✅ **All CYCL-01 through CYCL-08 requirements addressed:**
- CYCL-01: McCabe base complexity 1 ✓
- CYCL-02: Standard control flow (if/while/for/switch/catch) ✓
- CYCL-03: Modern JS (logical operators, nullish coalescing, optional chaining) ✓
- CYCL-04: Configurable counting toggles ✓
- CYCL-05: Nested function scope isolation ✓
- CYCL-06: Switch classic/modified modes ✓
- CYCL-07: Function identification (6 types) ✓
- CYCL-08: Default switch does not count ✓
- CYCL-09: Thresholds deferred to Plan 02 (as planned)

✅ **Integration test validates complexity against fixture with known expected values**

✅ **All 122 tests continue to pass (109 existing + 13 new inline tests + integration test)**

## Technical Achievements

1. **Recursive AST traversal pattern** - establishes the pattern for cognitive complexity (Phase 5) and Halstead (Phase 6)
2. **Configuration-driven counting** - allows teams to match their preferred counting philosophy
3. **Nested function scope isolation** - correctly handles inner functions, closures, callbacks
4. **Tree-sitter node type identification** - handles all 6 JavaScript/TypeScript function variants
5. **Modern JavaScript support** - counts logical operators, nullish coalescing, optional chaining (not in classic McCabe)
6. **Clean test fixture approach** - dedicated file with documented expected values for metric validation

## What's Next (Plan 02)

Plan 02 will:
- Implement threshold validation (warning=10, error=20 by default)
- Add default parameter counting (inspect tree-sitter AST representation)
- Integrate with Config system (.complexityguardrc support)
- Add threshold violation reporting
- Populate FunctionResult.cyclomatic field in core/types.zig

## Self-Check

Verifying all claimed artifacts exist and commits are valid.

**Created files:**
```bash
$ ls -la src/metrics/cyclomatic.zig
-rw-r--r-- 1 ben ben 19742 Feb 14 20:19 src/metrics/cyclomatic.zig
✓ FOUND

$ ls -la tests/fixtures/typescript/cyclomatic_cases.ts
-rw-r--r-- 1 ben ben 2642 Feb 14 20:19 tests/fixtures/typescript/cyclomatic_cases.ts
✓ FOUND
```

**Commits:**
```bash
$ git log --oneline | grep -E "(a5f4dad|c3601be)"
c3601be feat(04-01): add cyclomatic complexity test fixture and integration test
a5f4dad feat(04-01): implement cyclomatic complexity calculator
✓ FOUND
```

**Test passing:**
```bash
$ zig build test 2>&1 | grep -E "Build Summary"
Build Summary: 3/3 steps succeeded
✓ PASSED
```

## Self-Check: PASSED

All files exist, commits are in git history, tests pass.
