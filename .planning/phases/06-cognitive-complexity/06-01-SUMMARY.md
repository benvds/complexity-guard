---
phase: 06-cognitive-complexity
plan: 01
subsystem: metrics
tags: [cognitive-complexity, tree-sitter, zig, algorithm, sonarqube]

# Dependency graph
requires:
  - phase: 04-cyclomatic-complexity
    provides: ThresholdResult, isFunctionNode, extractFunctionInfo, validateThreshold, tree-sitter traversal patterns

provides:
  - src/metrics/cognitive.zig with CognitiveConfig, CognitiveFunctionResult, analyzeFunctions, analyzeFile
  - tests/fixtures/typescript/cognitive_cases.ts with 16 annotated test functions
  - Extended ThresholdResult with cognitive_complexity and cognitive_status fields

affects:
  - 06-02 (integration into main pipeline)
  - 06-03 (documentation of algorithm and deviations)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - visitNodeWithArrows: arrow-function-aware recursive AST traversal with nesting level tracking
    - Else-clause split: if/else handled as separate code paths to avoid double-counting
    - Fixture annotations: each test function has // Expected cognitive: N with breakdown comment

key-files:
  created:
    - src/metrics/cognitive.zig
    - tests/fixtures/typescript/cognitive_cases.ts
  modified:
    - src/metrics/cyclomatic.zig
    - src/output/console.zig
    - src/output/exit_codes.zig
    - src/output/json_output.zig
    - src/discovery/walker.zig
    - src/main.zig

key-decisions:
  - "Each &&, ||, ?? counts as +1 flat individually (ComplexityGuard deviation from SonarSource grouping)"
  - "Top-level arrow functions start at nesting 0 (treated like function declarations)"
  - "Arrow function callbacks inside function bodies are structural increments (add nesting)"
  - "Nested function bodies do not inflate outer function complexity (scope isolation)"
  - "Inner function declarations inside function bodies are not discovered separately by walkAndAnalyze (same as cyclomatic)"
  - "catch_clause adds structural increment; try and finally do not"
  - "switch adds structural increment; individual case clauses do not"
  - "Labeled break/continue adds +1 flat; unlabeled does not"

patterns-established:
  - "visitNodeWithArrows: arrow-function-aware node visitor that treats nested arrows as structural callbacks"
  - "Arrow discrimination: top-level arrow (via variable_declarator) = entry point; nested arrow = callback"
  - "Else-if continuation: else adds +1 flat, then if_statement at same nesting level (not incremented)"

requirements-completed:
  - COGN-01
  - COGN-02
  - COGN-03
  - COGN-04
  - COGN-05
  - COGN-06
  - COGN-07
  - COGN-08

# Metrics
duration: 7min
completed: 2026-02-17
---

# Phase 6 Plan 01: Cognitive Complexity Core Algorithm Summary

**SonarSource cognitive complexity algorithm implemented in Zig with ComplexityGuard deviations: per-operator logical counting, arrow callback nesting, and extended ThresholdResult carrying both metrics**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-17T09:15:54Z
- **Completed:** 2026-02-17T09:23:00Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Created `src/metrics/cognitive.zig` implementing the full cognitive complexity algorithm with tree-sitter AST traversal, nesting level tracking, and structural/flat increment logic
- Created `tests/fixtures/typescript/cognitive_cases.ts` with 16 hand-annotated test functions covering all major language constructs (if/else chains, loops, logical ops, recursion, arrows, switch, catch, ternary)
- Extended `ThresholdResult` in `cyclomatic.zig` with `cognitive_complexity: u32` and `cognitive_status: ThresholdStatus` fields, updated all downstream ThresholdResult literals across output modules

## Task Commits

1. **Task 1: Create cognitive test fixture and extend ThresholdResult** - `bba47e0` (feat)
2. **Task 2: Implement cognitive complexity algorithm** - `e9b318c` (feat)
3. **Task 3: Register cognitive module in main.zig test block** - `9df3ba0` (feat)

## Files Created/Modified

- `src/metrics/cognitive.zig` - Core cognitive complexity calculator with CognitiveConfig, CognitiveFunctionResult, visitNodeWithArrows traversal, analyzeFunctions, analyzeFile
- `tests/fixtures/typescript/cognitive_cases.ts` - 16 test functions with annotated expected cognitive scores and detailed breakdowns
- `src/metrics/cyclomatic.zig` - Added cognitive_complexity and cognitive_status fields to ThresholdResult; updated analyzeFile to set defaults
- `src/output/console.zig` - Updated all ThresholdResult literals in tests to include new fields
- `src/output/exit_codes.zig` - Updated all ThresholdResult literals in tests
- `src/output/json_output.zig` - Updated all ThresholdResult literals in tests
- `src/discovery/walker.zig` - Updated file count expectations (8 TypeScript files, 11 total) after adding cognitive_cases.ts
- `src/main.zig` - Added `_ = @import("metrics/cognitive.zig")` for test discovery

## Decisions Made

- ComplexityGuard deviates from SonarSource: each &&, ||, ?? operator counts as +1 flat individually rather than grouping consecutive same-operator sequences
- Top-level arrow functions (assigned to const via variable_declarator) treated as function entry points starting at nesting 0, not as structural increments
- Arrow functions encountered inside another function body are treated as callbacks: structural increment (1 + nesting_level) with nesting increase for their body
- Inner function declarations inside a function's body are NOT separately discovered by walkAndAnalyze (same behavior as cyclomatic.zig — they contribute to their own cognitive score, which is computed when the outer function is analyzed via visitNodeWithArrows stopping at the inner function boundary)
- The algorithm uses visitNodeWithArrows as the primary traversal function instead of visitNode, since arrow functions need special handling (bypass isFunctionNode check to treat them as callbacks)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Walker test file counts updated for new cognitive_cases.ts fixture**
- **Found during:** Task 1 (fixture creation)
- **Issue:** Adding cognitive_cases.ts increased TypeScript fixture count from 7 to 8, all-fixtures count from 10 to 11, and exclude-pattern count from 6 to 7, breaking three walker.zig tests
- **Fix:** Updated expected counts in walker.zig test assertions to reflect new fixture file
- **Files modified:** src/discovery/walker.zig
- **Verification:** All walker tests pass
- **Committed in:** bba47e0 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix for test count)
**Impact on plan:** Necessary consequence of adding the new fixture file. No scope creep.

## Issues Encountered

- Initial implementation of nested function discovery was incorrect: adding recursion into function bodies caused arrow callbacks to be registered as separate top-level functions. Fixed by reverting to the same "return early, don't recurse into function bodies" pattern used in cyclomatic.zig. Inner function declarations inside function bodies are not separately discoverable (same as cyclomatic behavior).
- The `visitNodeWithArrows` function needed to be the primary traversal entry point (not `visitNode`) because arrow functions require special handling — they're both function nodes (isFunctionNode returns true) and need to be treated as structural callbacks when found inside another function's body.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `src/metrics/cognitive.zig` is ready for integration into the main analysis pipeline (Plan 02)
- `ThresholdResult` now carries both cyclomatic and cognitive metrics, ready for Plan 02 to populate cognitive scores in the main analysis path
- The fixture provides ground-truth expected scores for regression testing
- Plan 02 will merge cyclomatic and cognitive analysis in `main.zig` and populate both fields in a single pass

## Self-Check: PASSED

- FOUND: tests/fixtures/typescript/cognitive_cases.ts
- FOUND: src/metrics/cognitive.zig
- FOUND: .planning/phases/06-cognitive-complexity/06-01-SUMMARY.md
- FOUND commit: bba47e0 (Task 1)
- FOUND commit: e9b318c (Task 2)
- FOUND commit: 9df3ba0 (Task 3)

---
*Phase: 06-cognitive-complexity*
*Completed: 2026-02-17*
