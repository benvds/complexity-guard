# Phase 14: Tech Debt Cleanup - Research

**Researched:** 2026-02-23
**Domain:** Zig source code cleanup, documentation housekeeping, benchmark data rendering
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Function name extraction:**
- Arrow functions assigned to variables use the variable name (`const handler = () => {}` → "handler")
- Truly anonymous callbacks use context from what they're passed to (`arr.map(() => ...)` → "map callback", `addEventListener('click', fn)` → "click handler")
- Class and object methods include the parent: `Foo.bar`, `obj.handler` — gives full context in output
- Unnamed default exports labeled as "default export"

**Benchmark data:**
- Benchmark both synthetic fixtures (project's own test files) and real open-source projects for credibility
- Speed-focused metrics: files/second, time per file, total scan time
- One-time manual capture for v1.0 — no automated benchmark script needed
- Present as narrative with tables: brief methodology explanation, data tables, key takeaways

**Cleanup approach:**
- Fix related issues discovered along the way (e.g., inconsistent output formatting found while fixing names)
- Verify ROADMAP.md and REQUIREMENTS.md checkboxes against actual code/test state, not just phase completion records
- Clean up tests related to dead code removal (remove/update tests covering the unreachable arrow_function branch)
- Update the audit findings document to mark resolved items with notes on what was done

### Claude's Discretion
- Which open-source projects to benchmark against
- Exact format of context-based anonymous function names
- How to handle edge cases in function naming (deeply nested, IIFE, etc.)

### Deferred Ideas (OUT OF SCOPE)
- Better ignore workflows — use .gitignore, .eslintignore, or other ignore files as input for file discovery. This is a new capability that belongs in its own phase.
</user_constraints>

---

## Summary

Phase 14 is a purely housekeeping phase with no new capabilities. All five success criteria are addressable through targeted edits to existing source files. The work clusters into three groups: (1) Zig source code changes in `src/metrics/cyclomatic.zig` and `src/metrics/cognitive.zig` for function naming and dead code removal; (2) planning doc corrections to ROADMAP.md and REQUIREMENTS.md; and (3) filling the subsystem benchmark placeholder in `docs/benchmarks.md` with data that already exists in `benchmarks/results/baseline-2026-02-21-single-threaded/`.

The benchmarks.md placeholder issue is already mostly resolved: the Key Findings, Parallelization, Memory, and Metric Accuracy sections all contain real data. Only the "Subsystem Breakdown" section at line 236 still contains a `[RESULTS: ...]` placeholder. That data exists in JSON files and can be rendered into the document now.

The function naming work is the most substantive: `extractFunctionInfo` in `cyclomatic.zig` already handles `variable_declarator` parent context (arrow functions assigned to `const`), but doesn't yet handle (a) class/object method parent context for Foo.bar style names, (b) truly anonymous callbacks with call-site context, or (c) default export detection.

**Primary recommendation:** Implement all five success criteria in a single focused plan (one wave). The work is all low-risk Zig editing with no new dependencies.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Zig | 0.15.2 | Source language | Project-locked |
| tree-sitter | vendored | AST traversal for function naming | Already in use |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| std.mem.eql | stdlib | String comparison for node types | Used throughout codebase |
| std.ArrayList | stdlib | Result accumulation | Used throughout codebase |

**Installation:** No new dependencies. All changes use existing stdlib and vendored tree-sitter.

---

## Architecture Patterns

### Recommended Project Structure

No structural changes. All edits target existing files:

```
src/metrics/cyclomatic.zig    # extractFunctionInfo — function naming logic
src/metrics/cognitive.zig     # Dead code removal (lines 143-162 in visitNode)
.planning/ROADMAP.md           # Checkbox corrections
.planning/REQUIREMENTS.md      # Checkbox + count corrections
docs/benchmarks.md             # Fill subsystem breakdown placeholder
.planning/v1.0-MILESTONE-AUDIT.md  # Mark resolved items
```

### Pattern 1: Function Name Extraction — Current State

**What:** `extractFunctionInfo()` in `src/metrics/cyclomatic.zig` already:
- Handles `function_declaration` / `generator_function_declaration` → reads `identifier` child node
- Handles `method_definition` → reads `property_identifier` child node
- Falls through to `<anonymous>` for `arrow_function` and unnamed `function` expressions

**Parent context propagation:** `walkAndAnalyze()` in cyclomatic.zig, cognitive.zig, halstead.zig, and structural.zig ALL already track `variable_declarator` parent context. When they see `const handler = () => {}`, the `handler` name is captured and passed down. This works.

**What's missing (per CONTEXT.md decisions):**
1. Class/object method parent for `Foo.bar` format — `method_definition` already extracts the method name (e.g., `bar`), but not the class/object name prefix (`Foo.`)
2. Anonymous callbacks with call-site context (`arr.map(...)` → "map callback")
3. Default export detection (`export default function() {}` → "default export")

### Pattern 2: Dead Code in cognitive.zig

**What:** Lines 143-162 in `visitNode()` form an unreachable branch:

```zig
// Lines 65-68: This returns early for ALL function nodes including arrow_function
if (cyclomatic.isFunctionNode(node)) {
    return;  // <-- arrow_function hits this and returns
}

// Lines 143-162: NEVER REACHED — arrow_function already returned above
if (std.mem.eql(u8, node_type, "arrow_function")) {
    ctx.complexity += 1 + ctx.nesting_level;
    ctx.nesting_level += 1;
    // ... dead code body ...
    ctx.nesting_level -= 1;
    return;
}
```

The correct handling of arrow function callbacks IS implemented — in `visitNodeWithArrows()` (line 332) which calls `visitArrowCallback()` (line 299). The dead branch in `visitNode()` was a transitional artifact that was superseded but never removed.

**Tests to update:** Any test that specifically tests the unreachable branch behavior in `visitNode()` directly should be removed. Tests that test arrow callback behavior through `calculateCognitiveComplexity()` / `analyzeFunctions()` are correct and should be kept.

### Pattern 3: ROADMAP.md Checkbox Corrections

**Unchecked plan checkboxes that should be `[x]`** (phases marked complete in header but plans still have `[ ]`):

- Phase 10.1: all 3 plans (`10.1-01`, `10.1-02`, `10.1-03`)
- Phase 11: all 4 plans (`11-01`, `11-02`, `11-03`, `11-04`)
- Phase 12: both plans (`12-01`, `12-02`)
- Phase 13: plans 13-02 and 13-03 (13-01 is already `[x]`)

Phase 14 header is still `[ ]` — leave as-is until the phase is complete.

**Progress table:** Phase 7, 8, 9, 10, 11, 12, 13 show "Complete" in status column but are missing the `✓ Complete` date suffix compared to Phases 1-6. Can normalize but this is cosmetic.

### Pattern 4: REQUIREMENTS.md Corrections

**Three distinct issues:**

**Issue 1: Stale checkboxes** — Requirements that are Complete in traceability table but show `[ ]` in the v1 requirements list:
- All requirements for Phase 2 (CLI-01–12, CFG-01–07) — these are complete
- All requirements for Phase 3 (PARSE-01–06) — complete
- All requirements for Phase 4 (CYCL-01–08; CYCL-09 already marked `[x]`) — complete
- All requirements for Phase 6 cognitive (COGN-01–09) — complete
- All requirements for Phase 6 Halstead (HALT-01–05) and structural (STRC-01–06) — complete
- All requirements for Phase 7 composite (COMP-01–04) — complete
- All requirements for Phase 8 console/JSON/CI (OUT-CON-01–04, OUT-JSON-01–03, CI-01–05) — complete

Already correctly `[x]`: CLI-07, CLI-08, CFG-04, CYCL-09, DUP-01–07, OUT-SARIF-01–04, OUT-HTML-01–04, PERF-01–02, DIST-01–02

**Issue 2: Phase numbers off-by-one in traceability table** — The Phase 5.1 insertion shifted cognitive (6), Halstead/structural (7), composite (8), console/JSON/CI (originally called Phase 5 in the original pre-insertion plan) upward. The traceability table still uses the pre-insertion numbering:

| Requirement | Current Table Value | Should Be |
|-------------|---------------------|-----------|
| COGN-01–09 | Phase 5 | Phase 6 |
| HALT-01–05, STRC-01–06 | Phase 6 | Phase 7 |
| COMP-01–04 | Phase 7 | Phase 8 |
| OUT-CON-01–04, OUT-JSON-01–03, CI-01–05 | Phase 8 | Phase 5 (console/JSON was Phase 5 per ROADMAP) |

Wait — re-reading ROADMAP.md: Phase 5 is "Console & JSON Output", Phase 6 is "Cognitive Complexity", Phase 7 is "Halstead & Structural Metrics", Phase 8 is "Composite Health Score". The traceability table has COGN mapped to "Phase 5" but the ROADMAP shows cognitive is Phase 6. Console/JSON is Phase 5. The table numbers are indeed off — COGN should be Phase 6, HALT/STRC should be Phase 7, COMP should be Phase 8. OUT-CON/OUT-JSON/CI should be Phase 5.

**Issue 3: Count wrong** — "v1 requirements: 72 total" but the actual checkbox count is 89 items (66 unchecked + 23 checked in v1 section). The actual count is 89 v1 requirements, not 72.

**Phase requirement counts** at the bottom also need updating to reflect correct phase numbers:
- "Phase 5: 9 requirements (Cognitive)" should be Phase 6
- "Phase 6: 11 requirements (Halstead + Structural)" should be Phase 7
- etc.

### Pattern 5: Benchmarks Subsystem Placeholder

**Location:** `docs/benchmarks.md` lines 236–239

**Placeholder text:**
```
[RESULTS: Run `bash benchmarks/scripts/bench-subsystems.sh` then
`node benchmarks/scripts/summarize-results.mjs ...`
to populate this section with actual subsystem timing data]
```

**Data available:** `benchmarks/results/baseline-2026-02-21-single-threaded/` contains subsystem JSON files for: dayjs, got, nestjs, vite, vscode, webpack, zod. This is the single-threaded baseline from Phase 10.1.

**Sample data (from zod-subsystems.json):**
```json
{
  "subsystems": {
    "file_discovery": { "mean_ms": 0.476 },
    "file_read": { "mean_ms": 1.893 },
    "parsing": { "mean_ms": 135.947 },
    "cyclomatic": { "mean_ms": 36.160 },
    "cognitive": { "mean_ms": 33.856 },
    "halstead": { "mean_ms": 46.305 },
    "structural": { "mean_ms": 32.711 },
    "scoring": { "mean_ms": 0.000 },
    "json_output": { "mean_ms": 0.019 }
  },
  "total_pipeline_mean_ms": 287.368,
  "hotspot": "parsing",
  "hotspot_pct": 47.3
}
```

**Key finding from data:** Parsing is the dominant hotspot across all 7 projects (40–64% of total pipeline time). This matches STATE.md note: "Parsing is dominant hotspot at 40-64% of total pipeline time across all 7 quick-suite projects".

The subsystem data is from the single-threaded baseline. This is the appropriate reference since Phase 10.1 captured it before parallelization (Phase 12) was added. The section should note this clearly.

### Anti-Patterns to Avoid

- **Don't propagate class names everywhere**: Class/object method parent context for `Foo.bar` format requires tracking additional parent context (the class declaration or object expression name) in `walkAndAnalyze`. This is a bounded scope change — only affect the `method_definition` case, not all function types.
- **Don't change test helpers**: Tests in `test_helpers.zig` use hardcoded names. Only tests for anonymous/context-based names need updating.
- **Don't modify behavior in structural/halstead**: The function naming changes should be made in `extractFunctionInfo` (cyclomatic.zig) since that function is shared by cognitive, halstead, and structural walkers via `cyclomatic.extractFunctionInfo()`. Changes there propagate automatically.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subsystem table rendering | Custom script | Manual edit from existing JSON | One-time task, data already summarized |
| REQUIREMENTS.md checkbox update | Automated tool | Manual edit + grep verification | 89 checkboxes, predictable patterns |
| Function name context | New AST library | Extend existing walkAndAnalyze pattern | Pattern already established in all 4 walkers |

---

## Common Pitfalls

### Pitfall 1: All Four Walkers Need Updating

**What goes wrong:** Updating `extractFunctionInfo()` in cyclomatic.zig improves function names for cyclomatic results, but cognitive, halstead, and structural walkers all call `cyclomatic.extractFunctionInfo()`. The parent context tracking (for class/object names) is separate per-walker. If only cyclomatic's `walkAndAnalyze` tracks class parent context, the other walkers will still produce partial names.

**Why it happens:** The `walkAndAnalyze` functions are duplicated across cyclomatic.zig, cognitive.zig, halstead.zig, and structural.zig. Each has its own parent context struct. The `variable_declarator` pattern is already in all four. Adding class/object method context must be added to all four.

**How to avoid:** Make changes to `extractFunctionInfo` first (shared), then add parent context tracking to all four walkers simultaneously.

**Warning signs:** One metric shows "Foo.bar" but another shows just "bar" for the same function.

### Pitfall 2: Dead Code Test Cleanup

**What goes wrong:** Tests that test the `visitNode` arrow_function branch behavior (lines 143-162) will become confusing or fail if they're specifically testing that unreachable path.

**Why it happens:** The dead code has accompanying comments explaining the problem. Tests may have been written for the original (broken) logic.

**How to avoid:** After removing the dead branch, run `zig build test` immediately. Look for test failures. Any test specifically asserting that `visitNode` with `arrow_function` input does X needs to be removed or rewritten to test via the public `analyzeFunctions` API.

**Warning signs:** Test failure with `arrow_function` in the test name.

### Pitfall 3: REQUIREMENTS.md Phase Number Off-by-One Direction

**What goes wrong:** Getting the correction direction wrong. The original plan had Console/JSON Output as Phase 5 (it still is), then Phase 5.1 was INSERTED. The pre-5.1 cognitive was Phase "5" in the original numbering but is Phase 6 in the current ROADMAP.

**Why it happens:** The Phase 5.1 insertion shifted cognitive from "5" to "6" in the ROADMAP. The REQUIREMENTS.md traceability table was not updated to match.

**How to avoid:** Cross-reference ROADMAP.md phase headers to determine correct phase numbers. The ROADMAP is authoritative.

**Correct mapping:**
- COGN-01 to COGN-09: Phase 5 (wrong) → Phase 6 (correct)
- HALT-01 to HALT-05, STRC-01 to STRC-06: Phase 6 (wrong) → Phase 7 (correct)
- COMP-01 to COMP-04: Phase 7 (wrong) → Phase 8 (correct)
- OUT-CON-01 to OUT-CON-04, OUT-JSON-01 to OUT-JSON-03, CI-01 to CI-05: Phase 8 (wrong) → Phase 5 (correct — these are the original Phase 5)

### Pitfall 4: Subsystem Data Context

**What goes wrong:** Presenting the subsystem data without noting it's from the single-threaded baseline (not the parallel baseline).

**Why it happens:** The subsystem benchmark script runs the `complexity-bench` binary which is single-threaded by design (it benchmarks the pipeline stages sequentially). This is the Phase 10.1 data, captured before parallelization.

**How to avoid:** Explicitly note in the subsystem section that data is from the single-threaded baseline (Phase 10.1), which is the appropriate reference for understanding per-stage costs.

---

## Code Examples

### Verified Pattern: Checking for Dead Code Block

The dead code block in `cognitive.zig` `visitNode()`:

```zig
// Lines 65-68: This gate returns for ALL function nodes
if (cyclomatic.isFunctionNode(node)) {
    return;   // arrow_function is a function node — returns here
}

// Lines 143-162: UNREACHABLE — isFunctionNode includes arrow_function
if (std.mem.eql(u8, node_type, "arrow_function")) {
    ctx.complexity += 1 + ctx.nesting_level;
    ctx.nesting_level += 1;
    // ... body ...
    ctx.nesting_level -= 1;
    return;
}
```

**Fix:** Delete lines 143-162 entirely. The correct arrow callback handling is in `visitNodeWithArrows()` / `visitArrowCallback()` (lines 296-339), which is called from `calculateCognitiveComplexity()`.

### Verified Pattern: Add Class Parent Context to walkAndAnalyze

Current state in cyclomatic.zig `walkAndAnalyze()` — only `variable_declarator` is tracked:

```zig
var child_context: ?FunctionContext = null;

if (std.mem.eql(u8, node_type, "variable_declarator")) {
    // capture identifier name for arrow functions assigned to variables
}

// Recurse
var i: u32 = 0;
while (i < node.childCount()) : (i += 1) {
    if (node.child(i)) |child| {
        try walkAndAnalyze(allocator, child, results, config, source, child_context);
    }
}
```

**Extension needed for class method naming (Foo.bar):**
```zig
var child_context: ?FunctionContext = null;

if (std.mem.eql(u8, node_type, "variable_declarator")) {
    // existing: capture identifier for arrow functions
}
// NEW: track class name so method_definition can use "ClassName.methodName"
else if (std.mem.eql(u8, node_type, "class_declaration") or
         std.mem.eql(u8, node_type, "class")) {
    // find identifier child = class name
}
// NEW: track object key name for pair-defined functions: { handler: () => {} }
else if (std.mem.eql(u8, node_type, "pair")) {
    // find property_identifier or string child = key name
}
```

Then in the function-node branch, when `func_info.kind == "method"` and `parent_context` contains a class name, compose `"ClassName.methodName"`.

### Verified Pattern: Anonymous Callback Context

For `arr.map(() => ...)` → "map callback" — this requires reading the grandparent context (the call_expression's callee):

```zig
// When encountering arrow_function as direct argument in call_expression:
// call_expression
//   └─ identifier "map"       ← callee
//   └─ arguments
//       └─ arrow_function     ← our node
//
// To name this "map callback", we need the callee identifier when
// building child_context for a call_expression's arguments.

if (std.mem.eql(u8, node_type, "call_expression")) {
    // Find callee identifier (first child)
    if (node.child(0)) |callee| {
        const callee_type = callee.nodeType();
        if (std.mem.eql(u8, callee_type, "identifier") or
            std.mem.eql(u8, callee_type, "member_expression")) {
            // Extract last identifier = method name ("map", "forEach", etc.)
            // Build child_context with name = "<method> callback"
        }
    }
}
```

### Verified Pattern: Default Export Detection

```zig
// export_statement
//   └─ "default"
//   └─ function / arrow_function
//
// Check if isFunctionNode AND parent is export_statement with default keyword
// OR the node has no name AND parent context name is null

// Simple heuristic: in extractFunctionInfo, when name would be <anonymous>
// and the function node is a direct child of export_statement:
// → return "default export"
```

---

## State of the Art

No external libraries involved. All changes are in-codebase Zig edits.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `<anonymous>` for arrow/expr functions | Variable name from parent context | Phase 4 (partial) | partial fix only |
| `<anonymous>` for callbacks | Still `<anonymous>` | Not done yet | Phase 14 target |
| Dead arrow branch in visitNode | To be removed | Phase 14 target | Code clarity |

---

## Open Questions

1. **How deep should class name propagation go?**
   - What we know: CONTEXT.md says "Foo.bar, obj.handler" — parent is always direct (one level up)
   - What's unclear: Nested classes (`Outer.Inner.method`), anonymous class expressions
   - Recommendation: One level only. `ClassName.method`. Skip nested class inheritance chains. For anonymous class expressions, use "class.method".

2. **Format for callback names with member expression callees**
   - What we know: `arr.map(() => ...)` → "map callback" per CONTEXT.md
   - What's unclear: `obj.utils.transform(() => ...)` — use "transform callback" (last segment) or "utils.transform callback"?
   - Recommendation: Last segment only: "transform callback". Simpler, consistent with the `arr.map` example.

3. **addEventListener case**
   - What we know: CONTEXT.md example: `addEventListener('click', fn)` → "click handler"
   - What's unclear: The argument is a string literal `'click'`, not a function name
   - Recommendation: For `addEventListener` specifically, read the first argument string literal. For generic `on<Event>` patterns, use the callee name + " handler". This requires a small special case in the call_expression handler.

4. **REQUIREMENTS.md traceability: should "Pending" status rows be updated?**
   - What we know: The table has ~40 rows still showing "Pending" for phases 2-8 which are complete
   - What's unclear: Whether to update all "Pending" → "Complete" or just the phase number corrections
   - Recommendation: Update both — change status AND fix phase numbers in the same pass. The table should accurately reflect current project state.

---

## Validation Architecture

*Nyquist validation is not configured (workflow.nyquist_validation not present in .planning/config.json). Skipping this section.*

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection of `src/metrics/cyclomatic.zig` lines 128-195 (extractFunctionInfo), 442-519 (walkAndAnalyze) — confirmed via Read tool
- Direct code inspection of `src/metrics/cognitive.zig` lines 62-162 (visitNode dead code block confirmed) — confirmed via Read tool
- `.planning/v1.0-MILESTONE-AUDIT.md` — authoritative audit document with tech debt list — confirmed via Read tool
- `benchmarks/results/baseline-2026-02-21-single-threaded/*.json` — subsystem data confirmed to exist and be complete — confirmed via Bash tool
- `docs/benchmarks.md` — confirmed placeholder at line 236 via Read tool
- `docs/benchmarks.md` — confirmed all other sections already have real data
- ROADMAP.md line-by-line checkbox audit — unchecked plans for phases 10.1, 11, 12, 13 confirmed

### Secondary (MEDIUM confidence)
- REQUIREMENTS.md phase numbering analysis — cross-referenced against ROADMAP.md phase headers to determine correct phase assignments for COGN, HALT/STRC, COMP, OUT-CON/JSON/CI groups

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all existing patterns
- Architecture: HIGH — all issues located precisely in source, patterns well understood
- Pitfalls: HIGH — issues verified by direct code inspection not inference

**Research date:** 2026-02-23
**Valid until:** N/A (cleanup phase, not subject to library staleness)
