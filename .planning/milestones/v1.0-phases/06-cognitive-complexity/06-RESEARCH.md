# Phase 6: Cognitive Complexity - Research

**Researched:** 2026-02-17
**Domain:** SonarSource cognitive complexity algorithm for TypeScript/JavaScript, Zig implementation, output integration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**SonarSource spec alignment:**
- Follow SonarSource whitepaper as baseline with pragmatic deviations for TS/JS
- Deviations are documented, not configurable (no --strict-sonar flag). One behavior, well-documented
- Users who need exact SonarQube parity use SonarQube

**Logical operator counting:**
- Each logical operator increments regardless of sequence (deviation from SonarSource)
- SonarSource groups same-operator sequences as 1 increment; ComplexityGuard counts each operator
- Simpler mental model: every `&&`, `||`, `??` adds 1

**Recursion detection:**
- Only detect recursion when a function calls itself by its declared name
- No indirect recursion detection via variable references or re-exports

**Arrow function nesting:**
- Arrow function callbacks (e.g., `arr.map(x => ...)`) increase nesting depth — follows SonarSource
- Top-level arrow function definitions (`const fn = () => ...`) do NOT add nesting — treated like function declarations
- Nested arrow callbacks inside methods DO add nesting depth (method=0, callback=1, if inside callback=2)

**Class method nesting:**
- Class methods start at nesting 0, same as standalone functions (follows SonarSource)
- Only nested structures inside the method body add depth

**Output integration:**
- Side-by-side display: both cyclomatic and cognitive on the same line per function
- Separate hotspot lists for cyclomatic and cognitive (combined list deferred to Phase 8)
- Sibling fields in JSON output: `{ cyclomatic: 12, cognitive: 8 }` — flat, matches existing structure
- Same warning/error severity indicators as cyclomatic — consistent UX

**Attribution and documentation:**
- Credit SonarSource and cite G. Ann Campbell's whitepaper in documentation
- Create detailed docs page (~300 words) for cognitive complexity
- Create matching detailed docs page (~300 words) for cyclomatic complexity
- Reference both docs pages from README

### Claude's Discretion

- Default threshold values (likely 15/25 based on industry norms, but Claude decides)
- Exact nesting penalty formula
- How to handle `else if` vs `else { if }` (likely both increment, but implementation detail)
- Test fixture design and edge case coverage

### Deferred Ideas (OUT OF SCOPE)

- Combined hotspot list (single ranked list across all metrics) — belongs in Phase 8: Composite Health Score
- Configurable strict SonarSource mode — not planned, document-only approach chosen
</user_constraints>

## Summary

Cognitive complexity is a metric invented by G. Ann Campbell at SonarSource (2016) that measures how difficult code is to understand rather than how many paths exist through it. Unlike cyclomatic complexity (which counts branches), cognitive complexity penalizes nesting: an `if` statement at nesting depth 2 costs more than at depth 0. This creates a score that correlates with human comprehension effort.

The algorithm has three types of increments: structural increments (control flow that adds 1 + nesting penalty), flat increments (structures that always add 1 regardless of nesting), and hybrid increments (recursion adds 1 flat). SonarSource's default threshold is 15; scores above 25 indicate code needing refactoring.

The codebase already has `cognitive: ?u32` placeholder in `FunctionResult`, `JsonOutput.FunctionOutput`, and the config system already has `ThresholdsConfig.cognitive`. The pipeline works through `ThresholdResult` slices, so Phase 6 needs to extend this data model to carry both cyclomatic and cognitive values per function, then update console and JSON output to display both.

**Primary recommendation:** Create `src/metrics/cognitive.zig` mirroring `cyclomatic.zig`'s structure. Extend `ThresholdResult` to include both metrics. Update `console.zig` and `json_output.zig` for side-by-side display. Add a separate cognitive hotspot list in the console summary.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tree-sitter | already integrated | AST parsing | Same as cyclomatic phase, no change |
| tree-sitter-typescript | already integrated | TS/TSX grammar | Official grammar |
| tree-sitter-javascript | already integrated | JS/JSX grammar | Official grammar |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| N/A | - | Pure traversal logic | No additional dependencies |

**Installation:** No new dependencies. All libraries already in vendor/.

## Architecture Patterns

### Recommended Module Structure

```
src/metrics/
├── cyclomatic.zig       # Existing - unchanged
├── cognitive.zig        # NEW: cognitive complexity calculator
└── (shared types can stay in each file - follow cyclomatic.zig pattern)

src/output/
├── console.zig          # MODIFY: side-by-side display, cognitive hotspot list
└── json_output.zig      # MODIFY: populate cognitive field (was null)
```

### Pattern 1: Nesting-Aware Recursive AST Traversal

**What:** Walk the AST carrying a `nesting_level` counter. Structural nodes increment the counter before recursing into their body; the counter decrements when exiting. Each structural node's complexity contribution is `1 + nesting_level`.

**When to use:** The core algorithm for cognitive complexity.

**Example:**
```zig
// Source: SonarSource eslint-plugin-sonarjs cognitive-complexity.ts implementation
pub const CognitiveContext = struct {
    nesting_level: u32,
    function_name: []const u8,  // For recursion detection
    complexity: u32,
};

fn visitNode(ctx: *CognitiveContext, node: tree_sitter.Node, source: []const u8) void {
    const node_type = node.nodeType();

    // Structural increment: 1 + nesting_level
    if (isStructuralNode(node_type)) {
        ctx.complexity += 1 + ctx.nesting_level;

        // Increment nesting for children
        ctx.nesting_level += 1;
        visitChildren(ctx, node, source);
        ctx.nesting_level -= 1;
        return;
    }

    // Flat increment: always 1
    if (isFlatNode(ctx, node, node_type, source)) {
        ctx.complexity += 1;
    }

    visitChildren(ctx, node, source);
}
```

### Pattern 2: Separate Cognitive Config Struct (mirrors CyclomaticConfig)

**What:** A `CognitiveConfig` struct with warning/error thresholds. Simpler than cyclomatic because counting rules are fixed (no toggle options — user decisions lock the behavior).

**Example:**
```zig
pub const CognitiveConfig = struct {
    /// Warning threshold (default: 15)
    warning_threshold: u32 = 15,
    /// Error threshold (default: 25)
    error_threshold: u32 = 25,

    pub fn default() CognitiveConfig {
        return CognitiveConfig{};
    }
};
```

### Pattern 3: Extend ThresholdResult for Dual Metrics

**What:** The current `ThresholdResult` in `cyclomatic.zig` only carries cyclomatic data. Phase 6 needs cognitive data alongside it. Options:

**Option A:** Add `cognitive` fields to `cyclomatic.ThresholdResult` (tight coupling)
**Option B:** Create a new `CombinedThresholdResult` struct that has both metrics (clean, recommended)
**Option C:** Parallel arrays — one `ThresholdResult` slice per metric (awkward to correlate)

**Recommended: Option B** — Create a new `CombinedFunctionResult` that carries both metrics:

```zig
// In a shared module, or in cyclomatic.zig as it already has related types
pub const CombinedFunctionResult = struct {
    name: []const u8,
    kind: []const u8,
    start_line: u32,
    start_col: u32,
    end_line: u32,
    // Cyclomatic
    cyclomatic: u32,
    cyclomatic_status: ThresholdStatus,
    // Cognitive
    cognitive: u32,
    cognitive_status: ThresholdStatus,
};
```

This keeps file results paired (same function, both scores) and simplifies output formatting significantly.

### Pattern 4: else if Handling

**What:** In tree-sitter, `else if` appears as an `else_clause` containing an `if_statement`. The `if_statement` is a structural node (costs 1 + nesting). The `else_clause` wrapper is a flat increment (+1, no nesting penalty). SonarSource's rule: `else if` does NOT add nesting (because it continues the same chain).

**ComplexityGuard behavior (follows SonarSource):**
- `if` → structural: 1 + nesting_level; increases nesting for body
- `else` (plain) → flat: +1; increases nesting for its body
- `else if` (else_clause containing if_statement) → the `else_clause` gets +1 flat; the `if_statement` inside it does NOT get nesting penalty (treat as continuation)

**Implementation approach:**
```zig
// When visiting else_clause:
// - Add 1 (flat) for the else itself
// - If first child is if_statement: visit it WITHOUT incrementing nesting
//   (the if_statement will add its own structural increment at current nesting level)
// - If first child is statement_block: increment nesting, visit, decrement
```

### Anti-Patterns to Avoid

- **Counting else if's if_statement at increased nesting:** This would inflate scores. `else if` is a continuation, not deeper nesting.
- **Incrementing nesting for top-level arrow functions:** `const fn = () => {}` does NOT add nesting (user decision).
- **Counting logical operators by sequence (SonarSource default):** User decision locks each `&&`/`||`/`??` as +1 regardless. Do NOT group same-type sequences.
- **Counting `else if` as two separate increments:** It is ONE increment (the else clause handles it, the nested if shares the nesting level context).
- **Forgetting to stop recursion at function boundaries:** Nested `function_declaration`, `arrow_function`, etc. inside a function's body must NOT contribute to the outer function's cognitive complexity. Each function has its own context.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST parsing | Custom JS/TS parser | tree-sitter (already integrated) | Already proven, same as cyclomatic phase |
| Nesting tracking | Global counter | Struct-carried context passed recursively | Zig lacks closures; carry context through parameters |
| Threshold validation | New logic | Reuse `validateThreshold` from cyclomatic.zig | Already handles warning/error level logic |
| Function name extraction | New logic | Reuse `extractFunctionInfo` from cyclomatic.zig | Already handles all function node types |
| Function node detection | New logic | Reuse `isFunctionNode` from cyclomatic.zig | Already covers all function forms |

**Key insight:** Phase 4 already solved function discovery, name extraction, and threshold validation. Phase 6 only needs to add the cognitive scoring algorithm on top.

## Cognitive Complexity Counting Rules

This section documents the complete counting spec for ComplexityGuard (SonarSource baseline + documented deviations).

### Structural Increments (1 + nesting_depth)

These nodes add `1 + current_nesting_level` to the score AND increase nesting for their body:

| Construct | tree-sitter node_type | Notes |
|-----------|----------------------|-------|
| `if` statement | `if_statement` | Does NOT apply when inside `else_clause` with an if first child |
| `else if` | `else_clause` → `if_statement` | The else clause gets +1 flat; the if inside does not get extra nesting |
| `else` | `else_clause` (plain block) | +1 flat (not structural) |
| `for` loop | `for_statement` | Structural |
| `for...of` loop | `for_in_statement` | Structural (tree-sitter uses same type for for-of) |
| `while` loop | `while_statement` | Structural |
| `do...while` loop | `do_statement` | Structural |
| `switch` statement | `switch_statement` | +1 structural (NOT each case — whole switch) |
| `catch` clause | `catch_clause` | Structural |
| Ternary `? :` | `ternary_expression` | Structural |
| Arrow callback | `arrow_function` (nested inside call args) | Structural — increases nesting for body |

### Flat Increments (+1, no nesting penalty)

These nodes always add exactly 1, regardless of nesting depth:

| Construct | Notes |
|-----------|-------|
| `else` clause (plain block body) | +1 |
| Labeled `break` | `break_statement` with label |
| Labeled `continue` | `continue_statement` with label |
| `&&` operator | Every occurrence (ComplexityGuard deviation: counts each) |
| `\|\|` operator | Every occurrence (ComplexityGuard deviation: counts each) |
| `??` operator | Every occurrence (ComplexityGuard deviation: counts each) |
| Recursive call | When call_expression matches enclosing function name (+1 flat) |

### What Does NOT Increment

| Construct | Reason |
|-----------|--------|
| `try` block | No increment; only `catch` increments |
| `finally` block | No increment |
| `?.` optional chaining | SonarSource: shorthand — no increment |
| `switch` cases | The switch statement increments; individual cases do not |
| `throw` | No increment (not a flow break in cognitive complexity) |
| Top-level `arrow_function` definition | User decision: treated like function declaration, no nesting |
| `function_declaration` | No self-increment; starts its own independent context |
| `return` | No increment |

### Nesting Level Rules

These constructs INCREASE the nesting level when their body is entered:

- `if_statement` body (consequent)
- `else_clause` body (when not containing another `if`)
- `for_statement`, `for_in_statement` body
- `while_statement`, `do_statement` body
- `switch_statement` body
- `catch_clause` body
- `ternary_expression` consequent and alternate
- Arrow function callback body (when arrow function is nested inside another function)

These DO NOT increase nesting level:
- Top-level arrow function definitions
- Class method definitions (start at 0)
- Standalone function declarations (each starts a new context at 0)

### Threshold Recommendations

Industry data (SonarSource default: 15, their warning level):
- **Warning:** 15 (SonarSource default, widely used industry baseline)
- **Error:** 25 (SonarSource guidance for "needs immediate refactoring")

Rationale: SonarSource explicitly recommends 15 as the upper limit for maintainable code. 25 matches their "critical" zone. These are the right defaults — do not deviate.

## Common Pitfalls

### Pitfall 1: else if Nesting Double-Count

**What goes wrong:** Treating `else if` as `else` (+1) + nested `if` (1 + nesting+1) = over-counting.

**Why it happens:** Tree-sitter represents `else if` as `else_clause` → `if_statement`, which looks like increasing nesting.

**How to avoid:** When processing `else_clause`, check if its first non-trivial child is `if_statement`. If yes: add 1 (flat for the else) and visit the `if_statement` at the CURRENT nesting level (do not increment for the else_clause before visiting the if inside).

**Example correctness:**
```typescript
if (a) {          // +1 (nesting 0) → complexity = 1
} else if (b) {   // +1 for else_clause, then if at nesting 0 → +1 = complexity = 3
} else {          // +1 flat → complexity = 4
}
```

**Warning signs:** `else if` chains scoring higher than expected.

### Pitfall 2: Arrow Function Nesting Discrimination

**What goes wrong:** Treating all arrow functions identically — either all add nesting or none do.

**Why it happens:** There are two cases: top-level `const fn = () => {}` and callback `arr.map(x => ...)`.

**How to avoid:** During the AST walk, track whether an arrow_function node's parent context indicates it is:
- A `variable_declarator` value at program/module scope → NOT a nesting increment
- An argument to a call expression / inside another function's body → IS a nesting increment (structural)

Implementation hint: Check the parent node type. If `arrow_function` is the value of a `variable_declarator` and its depth in the function stack is 0 (top-level), treat like a function declaration. Otherwise, treat as a nested callback.

**Warning signs:** `const fn = () => { if (x) {} }` scoring as if the if is at nesting depth 1.

### Pitfall 3: Recursion Detection Scope

**What goes wrong:** Detecting recursion incorrectly when a function with the same name exists elsewhere, or missing it when it occurs.

**Why it happens:** Recursion detection compares `call_expression` identifier to the enclosing function's name.

**How to avoid:** Pass the function name through the traversal context. When visiting a `call_expression`, check if its callee identifier text (extracted from source bytes) matches the context's `function_name`. Only count as recursion if names match exactly.

**Edge cases to handle:**
- Method recursion: `this.methodName()` — the callee is a `member_expression`, not bare identifier. User decision: only detect direct name calls. Skip `this.X()` recursion.
- Arrow functions stored in variables: `const fn = () => { fn(); }` — the function name in context would be "fn" (from variable_declarator). A call to `fn()` inside the body is recursion.

**Warning signs:** Functions that clearly recurse showing no recursion increment.

### Pitfall 4: Logical Operators in Non-Boolean Contexts

**What goes wrong:** Counting `??` in contexts where it's used for simple default assignment, or `||` in a non-boolean guard context.

**SonarSource behavior:** Skips default value patterns like `const x = a || literal` and `a = a || literal`.
**ComplexityGuard behavior (user decision):** Count every `&&`, `||`, `??` regardless. Simpler mental model.

**How to avoid:** No special-casing needed. Count every `binary_expression` with these operators.

**Warning signs:** None expected — this deviation is intentional and documented.

### Pitfall 5: Nested Function Scope Leakage

**What goes wrong:** An inner function declaration inside the body of another function contributes its complexity to the outer function.

**Why it happens:** Recursive AST walk visits all children including nested function bodies.

**How to avoid:** When the traversal encounters any function node (`function_declaration`, `function`, `arrow_function`, `method_definition`, etc.), stop descending into it for the outer function's context. Create a new independent context for the inner function.

This is the SAME pattern as cyclomatic.zig's `countDecisionPoints` which returns 0 when it hits a function node.

**Warning signs:** Functions containing nested function declarations showing inflated complexity.

## Code Examples

### CognitiveConfig Struct

```zig
// Source: SonarSource default threshold 15, error at 25 per industry usage
pub const CognitiveConfig = struct {
    /// Warning threshold (default: 15 per SonarSource recommendation)
    warning_threshold: u32 = 15,
    /// Error threshold (default: 25 per SonarSource critical zone)
    error_threshold: u32 = 25,

    pub fn default() CognitiveConfig {
        return CognitiveConfig{};
    }
};
```

### Core Traversal Context

```zig
/// Context passed through the cognitive complexity traversal
const CognitiveContext = struct {
    /// Current nesting depth (0 = top-level inside function)
    nesting_level: u32,
    /// Name of the enclosing function (for recursion detection)
    function_name: []const u8,
    /// Accumulated complexity score
    complexity: u32,
    /// Source bytes for text extraction
    source: []const u8,
};
```

### Structural vs Flat Node Classification

```zig
// Source: SonarSource whitepaper + eslint-plugin-sonarjs implementation

/// Returns true if this node gets 1 + nesting_level and increases nesting for body
fn isStructuralNode(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "if_statement") or
        std.mem.eql(u8, node_type, "for_statement") or
        std.mem.eql(u8, node_type, "for_in_statement") or  // covers for-of too
        std.mem.eql(u8, node_type, "while_statement") or
        std.mem.eql(u8, node_type, "do_statement") or
        std.mem.eql(u8, node_type, "switch_statement") or
        std.mem.eql(u8, node_type, "catch_clause") or
        std.mem.eql(u8, node_type, "ternary_expression");
    // arrow_function handled separately (context-dependent)
}

/// Returns true if this node adds 1 flat (no nesting component)
/// Note: else_clause requires special handling (check for nested if)
fn isFlatIncrementNode(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "else_clause");
    // Logical operators handled by inspecting binary_expression children
    // Recursion detected by checking call_expression callee
    // Labeled break/continue detected by checking ContinueStatement/BreakStatement label
}
```

### else_clause Special Handling

```zig
fn visitElseClause(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    // Always +1 for the else itself (flat increment)
    ctx.complexity += 1;

    // Check if first meaningful child is an if_statement
    // If so: visit the if_statement at current nesting level (NOT increased)
    // If not: it's a plain else block — increase nesting for body
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const child_type = child.nodeType();
            // Skip "else" keyword token
            if (std.mem.eql(u8, child_type, "else")) continue;

            if (std.mem.eql(u8, child_type, "if_statement")) {
                // else if: visit if at CURRENT nesting level
                visitStructuralNode(ctx, child, false); // false = don't pre-increment
            } else {
                // plain else block: increase nesting
                ctx.nesting_level += 1;
                visitChildren(ctx, child);
                ctx.nesting_level -= 1;
            }
            break;
        }
    }
}
```

### Logical Operator Counting (ComplexityGuard deviation)

```zig
// ComplexityGuard deviation: count each &&, ||, ?? as +1 (not sequence-based)
fn countLogicalOperators(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    // Only for binary_expression nodes
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const op_type = child.nodeType();
            if (std.mem.eql(u8, op_type, "&&") or
                std.mem.eql(u8, op_type, "||") or
                std.mem.eql(u8, op_type, "??"))
            {
                ctx.complexity += 1;  // flat +1 per operator
            }
        }
    }
}
```

### Recursion Detection

```zig
fn isRecursiveCall(ctx: *CognitiveContext, node: tree_sitter.Node) bool {
    // Only check call_expression nodes
    if (!std.mem.eql(u8, node.nodeType(), "call_expression")) return false;
    if (ctx.function_name.len == 0) return false;

    // Look for identifier child (direct call, not method call)
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const child_type = child.nodeType();
            if (std.mem.eql(u8, child_type, "identifier")) {
                const start = child.startByte();
                const end = child.endByte();
                if (start < ctx.source.len and end <= ctx.source.len) {
                    const callee_name = ctx.source[start..end];
                    return std.mem.eql(u8, callee_name, ctx.function_name);
                }
            }
            break; // Only check first child (callee)
        }
    }
    return false;
}
```

### Output Integration: Extended ThresholdResult

The current `console.FileThresholdResults` uses `cyclomatic.ThresholdResult` which only has cyclomatic data. Phase 6 must either:

1. Add cognitive fields to `cyclomatic.ThresholdResult` — quick but tight coupling
2. Create a new combined result type and update the pipeline — cleaner

**Recommended approach:** Add cognitive fields to the existing `cyclomatic.ThresholdResult` since the pipeline is already built around it. This minimizes changes to `console.zig`, `json_output.zig`, and `main.zig`.

```zig
// Modified cyclomatic.ThresholdResult to include cognitive:
pub const ThresholdResult = struct {
    // Cyclomatic
    complexity: u32,
    status: ThresholdStatus,
    // Cognitive (new in Phase 6)
    cognitive_complexity: u32,
    cognitive_status: ThresholdStatus,
    // Identity
    function_name: []const u8,
    function_kind: []const u8,
    start_line: u32,
    start_col: u32,
};
```

### Console Output: Side-by-Side Display

The current format line:
```
  12:0  ⚠  warning  Function 'foo' has complexity 12 (threshold: 10)  cyclomatic
```

New format with both metrics on same line:
```
  12:0  ⚠  warning  Function 'foo' cyclomatic 12 (warn 10)  cognitive 8 (ok)
```

Or alternatively (more ESLint-like, easier to scan):
```
  12:0  ⚠  warning  Function 'foo' has cyclomatic 12, cognitive 8
```

The exact format is Claude's discretion, but both values appear on the same line per user decision.

## Data Flow Analysis

Current pipeline (Phase 5 state):
```
parse.ParseResult → cyclomatic.analyzeFile() → ThresholdResult[] → FileThresholdResults → console/json output
```

Phase 6 pipeline:
```
parse.ParseResult
  → cyclomatic.analyzeFunctions() → FunctionComplexity[]
  → cognitive.analyzeFunctions()  → CognitiveFunctionResult[]  (new)
  → merge into CombinedThresholdResult[] (or extend ThresholdResult)
  → FileThresholdResults
  → console/json output (updated)
```

**Key integration point in main.zig:**

The current `main.zig` calls `cyclomatic.analyzeFile()` which internally calls `analyzeFunctions()`. For Phase 6, the analysis step needs to run both metrics. The cleanest approach: call both `cyclomatic.analyzeFunctions()` and `cognitive.analyzeFunctions()` on the same AST root, then zip the results together by position (they will be in the same order since both walk the same tree).

## Fixture Design

### New fixture file needed: `tests/fixtures/typescript/cognitive_cases.ts`

```typescript
// Expected cognitive scores (ComplexityGuard rules)

// Score: 0 — simple function, no branches
function baseline(): number { return 42; }

// Score: 1 — single if at nesting 0
function singleIf(x: number): string {
    if (x > 0) { return "pos"; }  // +1
    return "non-pos";
}

// Score: 3 — if + else + else nesting
function ifElseChain(x: number): string {
    if (x > 0) {         // +1 (nesting 0)
        return "pos";
    } else if (x < 0) {  // +1 (else) + 0 nesting = +1
        return "neg";
    } else {             // +1
        return "zero";
    }
}  // total: 3

// Score: 5 — nested if inside for (nesting penalty)
function nestedIfInLoop(items: number[]): number {
    let count = 0;
    for (const item of items) {     // +1 (nesting 0)
        if (item > 0) {              // +1+1 (nesting 1 = penalty)
            if (item > 100) {        // +1+2 (nesting 2 = penalty)
                count++;
            }
        }
    }
    return count;
}  // total: 1+2+3 = 6

// Score: 3 — logical operators (ComplexityGuard: each counts)
function logicalOps(a: boolean, b: boolean, c: boolean): boolean {
    return a && b && c;  // +1 +1 = 2 operators... but function also has no structural
}  // total: 2

// Score: recursion
function factorial(n: number): number {
    if (n <= 1) return 1;    // +1
    return n * factorial(n - 1);  // +1 (recursion)
}  // total: 2

// Top-level arrow: same as function declaration, no nesting penalty
const topLevelArrow = (x: number): boolean => {
    if (x > 0) {    // +1 (nesting 0, NOT nesting 1)
        return true;
    }
    return false;
};  // total: 1

// Callback arrow: increases nesting
function withCallback(items: number[]): number[] {
    return items.filter(x => {  // arrow_function +1 structural (nesting 0)
        if (x > 0) {            // +1+1 (nesting 1)
            return true;
        }
        return false;
    });
}  // total: 1+2 = 3
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Cyclomatic only | Cyclomatic + Cognitive side by side | SonarSource 2016 | Cognitive captures comprehension; cyclomatic captures testability |
| Single threshold | Separate thresholds per metric | Industry norm | Cognitive and cyclomatic have different natural scales |
| Same score for flat vs nested structures | Nesting penalty makes deeply nested code score higher | SonarSource spec 2016 | Better correlates with human comprehension effort |

**Deprecated/outdated:**
- **Cyclomatic as sole complexity metric:** Cognitive complexity is now the primary human-comprehension metric per SonarSource; cyclomatic remains relevant for testability (number of test cases needed).

## Open Questions

1. **Exact console output format for side-by-side display**
   - What we know: Both metrics on same line per user decision
   - What's unclear: Exact string format (severity indicator per metric? single status? how to handle when statuses differ?)
   - Recommendation: Show worst status as the line's status; show both values. e.g., `⚠ warning Function 'foo' cyclomatic 12 cognitive 18 (cognitive exceeds threshold 15)`

2. **Arrow function nesting detection implementation**
   - What we know: Top-level arrows don't nest; callback arrows do
   - What's unclear: How to determine at traversal time whether an arrow_function is "top-level" vs "callback" without tracking full parent chain
   - Recommendation: When encountering `arrow_function` during the walk: if the walk is already inside a function context (nesting_level > 0, OR we're inside a different function's body), treat as nested callback. If it's the outermost function being analyzed, treat as non-nesting. The key: the outer `walkAndAnalyze` already handles this by treating arrow_functions as function boundaries — the complexity calculation for the arrow function itself starts fresh, but when the arrow is nested INSIDE another function's body traversal, the arrow body creates a new scope with depth tracking continuing from the outer depth.

3. **Per-function worst-status computation for exit codes**
   - What we know: Exit codes currently based on cyclomatic violations only
   - What's unclear: Should cognitive violations also trigger non-zero exit codes?
   - Recommendation: Yes. A function with cognitive error should be an "error" in the tool. Combine: if either cyclomatic OR cognitive is error-status, the function contributes an error to the exit code count.

## Sources

### Primary (HIGH confidence)

- **SonarSource eslint-plugin-sonarjs implementation** — direct inspection of `cognitive-complexity.ts` rule, verified structural vs flat increment logic, nesting tracking, threshold default of 15
  - URL: https://github.com/SonarSource/eslint-plugin-sonarjs/blob/master/src/rules/cognitive-complexity.ts

- **SonarSource Cognitive Complexity whitepaper (G. Ann Campbell)** — authoritative specification document
  - URL: https://www.sonarsource.com/docs/CognitiveComplexity.pdf

- **SonarSource rules spec for TypeScript S3776** — confirms threshold, rules for TS
  - URL: https://rules.sonarsource.com/typescript/rspec-3776/ (redirected during research, content verified via eslint-plugin source)

- **Existing codebase** — `cyclomatic.zig`, `console.zig`, `json_output.zig`, `main.zig`, `types.zig`, `config.zig` — all read directly. Phase 6 data flow constraints are HIGH confidence based on actual code.

### Secondary (MEDIUM confidence)

- **SonarSource Community discussion** — cognitive complexity TypeScript calculation edge cases
  - URL: https://community.sonarsource.com/t/cognitive-complexity-calculation-for-typescript-on-and/120242

- **Baeldung: Cognitive Complexity overview** — confirms counting rules for control flow structures
  - URL: https://www.baeldung.com/java-cognitive-complexity

- **Go cognitive complexity implementation (gocognit)** — cross-language verification of counting rules
  - URL: https://github.com/uudashr/gocognit

### Tertiary (LOW confidence)

- Various blog posts (Medium, DevGenius) on SonarQube cognitive complexity — used only to confirm threshold values, not counting rules

## Metadata

**Confidence breakdown:**
- Counting rules (structural/flat classification): HIGH — verified against SonarSource eslint-plugin source
- Nesting penalty formula: HIGH — `1 + nesting_level` confirmed by eslint-plugin implementation
- Default thresholds (15 warning, 25 error): HIGH — SonarSource default is 15; 25 from industry guidance
- else if handling: HIGH — confirmed by both spec description and implementation
- Arrow function nesting rules: HIGH — locked by user decisions in CONTEXT.md
- Logical operator counting: HIGH — locked by user decisions (each counts: deviation documented)
- Zig implementation patterns: MEDIUM — inferred from cyclomatic.zig patterns; cognitive.zig will mirror them
- Output integration approach: MEDIUM — recommended approach (extend ThresholdResult) may need adjustment once full integration complexity is seen

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (tree-sitter grammars and SonarSource spec are stable; verify no breaking ESLint plugin changes before implementation)
