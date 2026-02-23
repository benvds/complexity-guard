---
phase: 06-cognitive-complexity
verified: 2026-02-17T00:00:00Z
status: passed
score: 22/22 must-haves verified
re_verification: false
human_verification:
  - test: "Run binary against a real TypeScript file with known nesting"
    expected: "Console shows 'cyclomatic N cognitive N' per function with correct cognitive scores and separate hotspot lists"
    why_human: "Cannot invoke the compiled binary from this verifier to check live terminal output format and color rendering"
  - test: "Run with --format json and inspect output"
    expected: "cognitive field is a non-null integer for every function, not null"
    why_human: "JSON output from the live binary must be inspected by a human to confirm cognitive values are non-null in practice"
---

# Phase 6: Cognitive Complexity Verification Report

**Phase Goal:** Tool calculates SonarSource cognitive complexity with nesting penalties
**Verified:** 2026-02-17
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Tool calculates cognitive complexity per function with correct structural increments (1 + nesting_level) | VERIFIED | `cognitive.zig` implements `1 + ctx.nesting_level` in `visitNodeWithArrows`; unit tests confirm correct scores |
| 2 | Tool tracks nesting level correctly across nested structures | VERIFIED | `ctx.nesting_level` incremented/decremented around each structural node; `nestedIfInLoop` test confirms 1+2+3=6 |
| 3 | Tool counts each logical operator (&&, ||, ??) as +1 flat (ComplexityGuard deviation) | VERIFIED | `binary_expression` handler counts each operator individually; `logicalOps` test expects 3 for two `&&` |
| 4 | Tool detects recursion when function calls itself by declared name | VERIFIED | `call_expression` handler checks callee identifier against `ctx.function_name`; `factorial` test expects 2 |
| 5 | Tool counts each ?? as +1 flat; ?. does NOT increment (COGN-08) | VERIFIED | `??` matched in binary_expression handler; `?.` member_expression not matched; nullish-coalescing test passes |
| 6 | Tool handles else if as continuation (not double-counted) | VERIFIED | `visitElseClauseWithArrows` adds +1 for else, then calls `visitIfAsContinuationWithArrows` at same nesting; `ifElseChain` test expects 4 |
| 7 | Top-level arrow function definitions do NOT add nesting | VERIFIED | `walkAndAnalyze` handles top-level arrows via `variable_declarator` detection; `topLevelArrow` test expects 1 |
| 8 | Arrow function callbacks DO increase nesting depth | VERIFIED | `visitArrowCallback` adds `1 + ctx.nesting_level`; `withCallback` test expects 3 |
| 9 | Nested function bodies do NOT contribute to outer function cognitive complexity | VERIFIED | `visitNodeWithArrows` stops at function boundaries (non-arrow); `outer` function with nested `inner` test expects 1 |
| 10 | Tool shows both cyclomatic and cognitive complexity on same line per function in console output | VERIFIED | `console.zig` line 129: `"Function '%s' cyclomatic %d cognitive %d"` format; test `formatFileResults: shows both cyclomatic and cognitive on same line` passes |
| 11 | Tool shows separate hotspot lists for cyclomatic and cognitive complexity | VERIFIED | `console.zig` builds two lists sorted independently; test `formatSummary: shows separate cyclomatic and cognitive hotspot lists` passes |
| 12 | Tool populates cognitive field in JSON output (no longer null) | VERIFIED | `json_output.zig` line 106: `.cognitive = result.cognitive_complexity`; test asserts cognitive field is not null |
| 13 | Tool applies configurable cognitive thresholds (default warning=15, error=25) | VERIFIED | `CognitiveConfig` defaults to 15/25; `main.zig` reads from config file with fallback to defaults |
| 14 | Function status is worst of cyclomatic and cognitive | VERIFIED | `worstStatus` helper present in all three output files; console, JSON, and exit_codes all use it |
| 15 | Cognitive violations contribute to exit codes | VERIFIED | `exit_codes.zig` `countViolations` uses `worstStatus`; tests cover cognitive warning/error upgrading cyclomatic status |
| 16 | Docs page explains cognitive complexity and credits SonarSource/G. Ann Campbell | VERIFIED | `docs/cognitive-complexity.md` contains "G. Ann Campbell", "SonarSource", whitepaper link |
| 17 | Matching docs page exists for cyclomatic complexity (credits McCabe) | VERIFIED | `docs/cyclomatic-complexity.md` contains "Thomas J. McCabe, Sr." and cross-links cognitive page |
| 18 | README references both docs pages | VERIFIED | README links to `docs/cognitive-complexity.md` and `docs/cyclomatic-complexity.md` in Metrics section |
| 19 | README features list includes cognitive complexity | VERIFIED | README Features section: "**Cognitive Complexity**: SonarSource-based metric..." |
| 20 | CLI reference documents cognitive threshold configuration | VERIFIED | `docs/cli-reference.md` documents `thresholds.cognitive.warning` and `thresholds.cognitive.error` |
| 21 | Examples show cognitive complexity scenarios | VERIFIED | `docs/examples.md` includes jq recipes for cognitive complexity filtering and comparison |
| 22 | Integration test validates expected function scores against fixture | VERIFIED | `cognitive.zig` test `integration test against cognitive_cases.ts fixture` checks 12 named functions; `zig build test` passes |

**Score:** 22/22 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/fixtures/typescript/cognitive_cases.ts` | Hand-crafted test fixture with annotated expected cognitive scores | VERIFIED | 248 lines, 16 annotated functions with `// Expected cognitive: N` comments and breakdowns |
| `src/metrics/cognitive.zig` | Cognitive complexity calculator with CognitiveConfig, analyzeFunctions, analyzeFile | VERIFIED | 1101 lines; exports `CognitiveConfig`, `CognitiveFunctionResult`, `analyzeFunctions`, `analyzeFile`, `calculateCognitiveComplexity` |
| `src/metrics/cyclomatic.zig` (ThresholdResult extension) | Extended ThresholdResult with cognitive fields | VERIFIED | `cognitive_complexity: u32` and `cognitive_status: ThresholdStatus` fields present |
| `src/main.zig` | Pipeline running both cyclomatic and cognitive analysis | VERIFIED | Imports `cognitive`, calls `cognitive.analyzeFunctions`, merges results by index alignment |
| `src/output/console.zig` | Side-by-side metric display with separate hotspot lists | VERIFIED | Contains `cyclomatic {d} cognitive {d}` format string and separate hotspot sort/display |
| `src/output/json_output.zig` | JSON output with populated cognitive field | VERIFIED | `.cognitive = result.cognitive_complexity` on line 106 |
| `src/output/exit_codes.zig` | Violation counting that considers both metrics | VERIFIED | `worstStatus` helper and updated `countViolations` |
| `docs/cognitive-complexity.md` | Detailed explanation of cognitive complexity (~300 words) crediting SonarSource | VERIFIED | ~520 words, credits G. Ann Campbell and SonarSource whitepaper |
| `docs/cyclomatic-complexity.md` | Detailed explanation of cyclomatic complexity crediting McCabe | VERIFIED | ~514 words, credits Thomas J. McCabe, Sr. |
| `README.md` | Updated features list and example output with cognitive complexity | VERIFIED | Contains cognitive bullet in features, side-by-side example output, links to both docs pages |
| `docs/cli-reference.md` | Cognitive threshold configuration documentation | VERIFIED | Documents `thresholds.cognitive.warning` and `thresholds.cognitive.error` |
| `docs/examples.md` | Examples with cognitive complexity scenarios | VERIFIED | Contains jq recipes for `select(.cognitive > 15)` and cross-metric comparison |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/metrics/cognitive.zig` | `src/parser/tree_sitter.zig` | tree_sitter.Node traversal | WIRED | Uses `tree_sitter.Node`, `.nodeType()`, `.child()`, `.childCount()`, etc. throughout |
| `src/metrics/cognitive.zig` | `src/metrics/cyclomatic.zig` | reuses `isFunctionNode`, `extractFunctionInfo`, `validateThreshold` | WIRED | `cyclomatic.isFunctionNode`, `cyclomatic.extractFunctionInfo`, `cyclomatic.validateThreshold` called; returns `cyclomatic.ThresholdResult` |
| `src/main.zig` | `src/metrics/cognitive.zig` | import and call `analyzeFunctions` | WIRED | `const cognitive = @import("metrics/cognitive.zig")` on line 13; `cognitive.analyzeFunctions` called on line 169 |
| `src/output/console.zig` | `src/metrics/cyclomatic.zig` | ThresholdResult with cognitive fields | WIRED | Uses `result.cognitive_complexity` and `result.cognitive_status` throughout |
| `src/output/json_output.zig` | `src/metrics/cyclomatic.zig` | ThresholdResult `cognitive_complexity` field | WIRED | `.cognitive = result.cognitive_complexity` on line 106 |
| `README.md` | `docs/cognitive-complexity.md` | markdown link | WIRED | `[Cognitive Complexity](docs/cognitive-complexity.md)` present |
| `README.md` | `docs/cyclomatic-complexity.md` | markdown link | WIRED | `[Cyclomatic Complexity](docs/cyclomatic-complexity.md)` present |

### Requirements Coverage

| Requirement | Status | Notes |
|-------------|--------|-------|
| COGN-01: Calculates SonarSource cognitive complexity per function | SATISFIED | `analyzeFunctions` computes per-function cognitive scores |
| COGN-02: Increments for flow breaks (if, else if, else, switch, loops, catch, ternary, labeled break/continue) | SATISFIED | All constructs handled in `visitNodeWithArrows`; switch, catch, ternary, labeled break/continue all verified |
| COGN-03: Adds nesting penalty equal to current nesting depth | SATISFIED | `1 + ctx.nesting_level` for all structural increments |
| COGN-04: Tracks nesting level increases for structural constructs | SATISFIED | `ctx.nesting_level += 1` / `ctx.nesting_level -= 1` wraps each structural node's children |
| COGN-05: Same-operator logical sequences as +1 | DEVIATION (locked) | Per user decision, ComplexityGuard counts each operator individually (+1 per operator). Documented in code and docs. Behavior differs from SonarSource spec but deviation is explicitly accepted. |
| COGN-06: Increments on operator type changes in mixed sequences | DEVIATION (locked) | Same as COGN-05: each operator is +1 regardless of type changes. Mixed sequences like `&&`, `\|\|` still count each separately. Deviation documented. |
| COGN-07: Increments +1 for recursive function calls | SATISFIED | `call_expression` handler checks callee identifier against `function_name` |
| COGN-08: Does not increment for null coalescing or optional chaining (shorthand rule) | PARTIAL DEVIATION | `??` IS counted as +1 (locked user decision). `?.` is NOT counted (compliant). The requirement says "does not increment for null coalescing" but user decision adds `??` as +1. Documented in plans and docs. |
| COGN-09: Configurable warning (15) and error (25) thresholds | SATISFIED | `CognitiveConfig` defaults to 15/25; `main.zig` reads from config; pipeline integration wires to exit codes |

**Note on COGN-05, COGN-06, and COGN-08 deviations:** These are locked user decisions documented in the 06-01-PLAN.md objective, in code comments, and in `docs/cognitive-complexity.md`. They represent ComplexityGuard's intentional design choices, not gaps. The phase goal "SonarSource cognitive complexity with nesting penalties" is substantially achieved; deviations are scoped and documented.

**Note on REQUIREMENTS.md traceability table:** The table lists COGN-01 through COGN-09 under "Phase 5" but they are implemented in Phase 6. This is a pre-existing inconsistency in the requirements document (likely a numbering artifact from roadmap restructuring), not a code gap.

### Anti-Patterns Found

| File | Lines | Pattern | Severity | Impact |
|------|-------|---------|----------|--------|
| `src/metrics/cognitive.zig` | 143-162 | Dead code: `arrow_function` branch in `visitNode` that code comment explicitly acknowledges "can never be reached as written" | Warning | No functional impact — `visitNodeWithArrows` is always used instead of `visitNode` for traversal. Tests pass. Dead code is confusing but harmless. |

The `visitNode` function itself is reachable (called by `visitArrowCallback`, `visitElseClause`, `visitIfAsContinuation`), but the `arrow_function` branch within it at lines 145-162 cannot be reached because the `isFunctionNode` check at line 67 returns early first. The architecture was refactored to `visitNodeWithArrows` but the original `visitNode` was not cleaned up.

### Human Verification Required

### 1. Live Console Output Format

**Test:** Run `zig build run -- tests/fixtures/typescript/cognitive_cases.ts` in a terminal
**Expected:** Each function line shows `cyclomatic N cognitive N` side by side; summary shows "Top cyclomatic hotspots:" and "Top cognitive hotspots:" as separate sections
**Why human:** Cannot invoke the compiled binary from this verifier; terminal color rendering and exact spacing require visual inspection

### 2. Live JSON Output Cognitive Field

**Test:** Run `zig build run -- --format json tests/fixtures/typescript/cognitive_cases.ts` and inspect output
**Expected:** Every function entry has `"cognitive": <integer>` (not `null`); values match expected cognitive scores from the fixture annotations
**Why human:** JSON output must be observed from the live binary; static code analysis confirms wiring but not runtime correctness of values

### Gaps Summary

No gaps found. All must-haves verified. The two human verification items are confirmatory checks of live binary behavior, not suspected gaps. The dead code in `visitNode` is a warning-level code quality issue, not a blocker.

---

_Verified: 2026-02-17_
_Verifier: Claude (gsd-verifier)_
