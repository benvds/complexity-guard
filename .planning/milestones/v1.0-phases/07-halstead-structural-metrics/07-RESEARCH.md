# Phase 7: Halstead & Structural Metrics - Research

**Researched:** 2026-02-17
**Domain:** Halstead information-theoretic metrics, structural code properties, Zig AST walker patterns, tree-sitter token classification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**TypeScript type awareness:**
- Exclude type-only syntax from Halstead metrics: type annotations, generics, `as`, `satisfies` do not count as operators/operands. Halstead measures runtime logic only — TS and equivalent JS should score the same.
- Skip Halstead computation for type-only declarations (`interface`, `type` aliases). Only compute Halstead for functions/methods with runtime bodies.
- Count decorators (`@Component`, `@Injectable`) as operators in Halstead — they are runtime constructs that modify behavior.
- For structural parameter count: count both runtime params AND generic type params (`<T, U>`). A function with 3 regular params and 3 generics = 6 params. Reflects full signature complexity.

**Default thresholds:**
- Halstead metrics: use industry-standard defaults from academic literature (research specific values from SonarQube, CodeClimate, etc.)
- Function length warning: 25 logical lines (strict, pushes toward single-responsibility functions)
- Parameter count warning: 3 parameters
- Max nesting depth warning: 3 levels

**Function length counting:**
- "Logical lines" = lines with actual code only. Exclude blank lines and comment-only lines.
- Single-expression arrow functions count as 1 logical line regardless of formatting.
- File length (STRC-04) uses the same rules as function length — logical lines only, no blanks, no comments. One consistent definition of "length" everywhere.

**Metric presentation:**
- Default console output shows only violations (metrics exceeding thresholds). Clean code = clean output. Use --verbose to see all values.
- JSON output always includes all Halstead and structural metrics for every function, regardless of thresholds. Predictable, complete schema.
- Hotspot ranking considers all metrics including Halstead and structural. A function with extreme Halstead volume can rank as a hotspot even with low cyclomatic/cognitive scores.
- Users can select which metric families to compute via `--metrics` flag (e.g., `--metrics cyclomatic,halstead`). Useful for gradual adoption or focusing CI on specific concerns.

### Claude's Discretion
- Specific Halstead threshold values (research industry standards and pick)
- Error-level thresholds (typically 2x warning level, but Claude can adjust)
- Exact operator/operand classification rules for JS/TS tokens
- How to handle edge cases (empty functions, zero operands)
- File length and export count default thresholds
- File length and export count default thresholds

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HALT-01 | Tool classifies tokens as operators or operands per TypeScript/JavaScript definitions | Operator/operand classification table below; use node_type-based classification in tree-sitter walk |
| HALT-02 | Tool computes distinct operators (n1), distinct operands (n2), total operators (N1), total operands (N2) | Use `std.HashMap` (string-keyed) to track distinct tokens; count total occurrences separately |
| HALT-03 | Tool derives vocabulary, length, volume, difficulty, effort, time-to-program, estimated bugs | Formulas verified from Halstead (1977) and Wikipedia. See Code Examples section. |
| HALT-04 | Tool handles edge cases (zero operands/operators) without divide-by-zero errors | If n2 == 0: set difficulty=0, volume=0, all derived=0. Guard at formula level. |
| HALT-05 | Tool applies configurable thresholds for volume, difficulty, effort, and estimated bugs | HalsteadConfig struct with warning/error pairs; validated same as CyclomaticConfig |
| STRC-01 | Tool measures function length (logical lines) per function | Traverse function body, count lines with non-comment, non-blank content. Use source byte range + newline scan. |
| STRC-02 | Tool measures parameter count per function | Count `formal_parameters` children (runtime params) + generic type_parameters children. Locked: total = runtime + generic. |
| STRC-03 | Tool measures maximum nesting depth per function | Walk function body, track depth counter: +1 for if/for/while/do/switch/catch/ternary/arrow_callback, take max seen. |
| STRC-04 | Tool measures file length (logical lines) per file | Same algorithm as function length but applied to full source text (same logical line definition). |
| STRC-05 | Tool measures export count per file | Walk program root, count `export_statement` nodes (and `export_default_declaration`, `export_named_declaration`). |
| STRC-06 | Tool applies configurable warning/error thresholds for each structural metric | StructuralConfig struct with threshold pairs for function_length, param_count, nesting_depth, file_length, export_count |
</phase_requirements>

## Summary

Halstead metrics are derived from counting distinct and total operators and operands in a function's token stream. The four base counts (n1, N1, n2, N2) produce vocabulary, volume, difficulty, effort, time, and estimated bugs. For JavaScript/TypeScript, the key implementation decisions are: (1) which tree-sitter node types count as operators vs. operands, and (2) how to exclude TypeScript type-only syntax per the locked user decisions.

Structural metrics are straightforward AST properties: counting lines, parameters, nesting levels, and exports. The codebase already has stub fields for all of these in `FunctionResult` and `FileResult` (`params_count`, `line_count`, `nesting_depth`, `export_count`). Phase 7 fills these in and adds Halstead computation on top.

The pipeline pattern established in Phase 6 carries through: create a `halstead.zig` module following the `cyclomatic.zig` / `cognitive.zig` pattern, extend `ThresholdResult` with Halstead and structural fields, and update `console.zig`, `json_output.zig`, and `main.zig` to carry and display the new values.

**Primary recommendation:** Create `src/metrics/halstead.zig` for Halstead token counting + formula computation; create `src/metrics/structural.zig` for logical line counting, parameter counting, nesting depth, and export counting; extend `ThresholdResult` with all new fields; wire into `main.zig`; update output layer. Implement the `--metrics` flag filtering in `main.zig` using the existing `cfg.analysis.metrics` slice.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tree-sitter | already integrated | AST traversal for token classification | Same as all prior phases |
| tree-sitter-typescript | already integrated | TS/TSX grammar | Official grammar |
| tree-sitter-javascript | already integrated | JS/JSX grammar | Official grammar |
| std.HashMap | Zig stdlib | Tracking distinct operators/operands | No external deps needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| N/A | - | Pure traversal logic | No additional dependencies needed |

**Installation:** No new dependencies.

## Architecture Patterns

### Recommended Project Structure

```
src/metrics/
├── cyclomatic.zig       # Existing - minor extension (add structural fields to FunctionComplexity)
├── cognitive.zig        # Existing - unchanged
├── halstead.zig         # NEW: Halstead token classification + formula computation
└── structural.zig       # NEW: logical line count, param count, nesting depth, export count

src/output/
├── console.zig          # MODIFY: add Halstead/structural violations; update hotspot to include all metrics
└── json_output.zig      # MODIFY: populate halstead_*, nesting_depth, line_count, params_count fields
```

The `ThresholdResult` in `cyclomatic.zig` already holds cyclomatic + cognitive. Phase 7 extends it further. This matches the Phase 6 pattern exactly.

### Pattern 1: Halstead Token Walker (AST-based)

**What:** Walk the function body AST. For each node, classify it as operator or operand (or neither). Accumulate counts into a `HalsteadCounts` struct. Compute derived metrics at the end.

**Key principle:** Use `tree_sitter.Node.nodeType()` to determine classification. Do NOT use `ts_node_is_named()` — the type string is sufficient and more explicit. TypeScript type-only nodes (type_annotation, generic_type, type_assertion, etc.) are simply skipped.

```zig
// In halstead.zig
pub const HalsteadCounts = struct {
    /// Distinct operators (n1): set of unique operator tokens
    operators: std.StringHashMap(void),
    /// Distinct operands (n2): set of unique operand tokens
    operands: std.StringHashMap(void),
    /// Total operator occurrences (N1)
    total_operators: u32,
    /// Total operand occurrences (N2)
    total_operands: u32,
};

pub const HalsteadMetrics = struct {
    /// n1: distinct operators
    n1: u32,
    /// n2: distinct operands
    n2: u32,
    /// N1: total operator occurrences
    n1_total: u32,
    /// N2: total operand occurrences
    n2_total: u32,
    /// Vocabulary: n = n1 + n2
    vocabulary: u32,
    /// Length: N = N1 + N2
    length: u32,
    /// Volume: V = N * log2(n)
    volume: f64,
    /// Difficulty: D = (n1/2) * (N2/n2), 0 if n2==0
    difficulty: f64,
    /// Effort: E = V * D
    effort: f64,
    /// Time to program: T = E / 18 (seconds)
    time: f64,
    /// Estimated bugs: B = V / 3000
    bugs: f64,
};
```

### Pattern 2: Operator/Operand Classification for JS/TS

**What:** Classify each tree-sitter token (leaf node type) into operator, operand, or skip.

**Classification approach:** After walking a function body, the leaves we encounter can be classified by their `nodeType()` string. The approach is to check node types and the text of leaf nodes.

For non-leaf nodes (compound expressions like `binary_expression`, `call_expression`): recurse into children, let the children classify themselves.

For leaf nodes: classify by type string.

**Operators** (count occurrence + add to distinct set using the operator text):
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `**` (as binary_expression operator children)
- Comparison: `==`, `!=`, `===`, `!==`, `<`, `>`, `<=`, `>=`
- Logical: `&&`, `||`, `??`
- Assignment: `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `**=`, `&&=`, `||=`, `??=`, `<<=`, `>>=`, `>>>=`, `&=`, `|=`, `^=`
- Bitwise: `&`, `|`, `^`, `~`, `<<`, `>>`, `>>>`
- Unary: `!`, `++`, `--`, `typeof`, `void`, `delete`, `await`, `yield`
- Punctuation-operators: `,` (argument separator counts as operator in classic Halstead), `(` pairs (function call), `[` pairs (subscript)
- Keywords-as-operators: `if`, `else`, `for`, `while`, `do`, `switch`, `case`, `default`, `break`, `continue`, `return`, `throw`, `try`, `catch`, `finally`, `new`, `in`, `of`, `instanceof`
- TypeScript-specific operators: decorators (`@`) — count as operator (locked decision)
- Ternary: `?` and `:` as pair (count as one operator "?:")

**Operands** (count occurrence + add to distinct set using the literal token text):
- `identifier` node (variable names, function names in calls)
- `number`, `string`, `template_string`, `regex` (literals)
- `true`, `false`, `null`, `undefined` (special value literals)
- `this` keyword

**Skip entirely (neither operator nor operand):**
- TypeScript type annotations: `type_annotation`, `type_identifier`, `generic_type`, `type_parameters`, `type_parameter`, `predefined_type`
- TypeScript `as` expression body type: `as_expression` type part
- TypeScript `satisfies_expression` type part
- `interface_declaration`, `type_alias_declaration` — skip entire node (locked decision: no Halstead for type-only)
- Comment nodes: `comment`
- Structural/grouping syntax already counted elsewhere: `{`, `}`, `;`
- `=>` (arrow, not a runtime operator in the Halstead sense — the function itself is what matters)

**IMPORTANT implementation note on "paired tokens":** Classic Halstead theory counts `()`, `[]`, `{}` as single operator pairs. For JS/TS implementation, the simplest pragmatic approach (used by most tools): count `(` of a `call_expression` as one operator, skip the matching `)`. Count `[` of a `subscript_expression` as one operator, skip `]`. Skip standalone `{`/`}` (they are structural, not operators). This avoids double-counting.

**Practical tree-sitter approach for JS/TS:**
Since tree-sitter represents compound expressions with intermediate nodes, walk the tree but only classify **leaf nodes** (nodes with `childCount() == 0`). For named compound nodes that are purely structural (like `statement_block`), recurse but don't count the node itself. This is the cleanest approach:

```zig
fn classifyNode(counts: *HalsteadCounts, node: tree_sitter.Node, source: []const u8) !void {
    const node_type = node.nodeType();

    // Skip TypeScript type-only constructs entirely
    if (isTypeOnlyNode(node_type)) return;

    // If leaf node, classify it
    if (node.childCount() == 0) {
        try classifyLeaf(counts, node_type, source[node.startByte()..node.endByte()]);
        return;
    }

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try classifyNode(counts, child, source);
        }
    }
}
```

### Pattern 3: Logical Line Counting

**What:** Count lines within a source range that have actual code (not blank, not comment-only).

**Approach:** Given a function's start and end byte offsets in source, extract the lines in that range and count those containing non-whitespace, non-comment content.

```zig
/// Count logical lines in a source range
/// Logical lines = lines with actual code (excludes blanks and comment-only lines)
pub fn countLogicalLines(source: []const u8, start_byte: u32, end_byte: u32) u32 {
    const text = source[@min(start_byte, source.len)..@min(end_byte, source.len)];
    var count: u32 = 0;
    var iter = std.mem.splitScalar(u8, text, '\n');
    while (iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;  // blank line
        if (std.mem.startsWith(u8, trimmed, "//")) continue;  // line comment
        if (std.mem.startsWith(u8, trimmed, "/*") and std.mem.endsWith(u8, trimmed, "*/")) continue;  // inline block comment
        // Lines that start with * (inside block comment) — skip
        if (std.mem.startsWith(u8, trimmed, "*")) continue;
        count += 1;
    }
    return count;
}
```

**Single-expression arrow functions (locked decision):** An arrow function with expression body (no `statement_block`) counts as 1 logical line. Detect this by checking if the function body child is NOT a `statement_block`. If body is a `statement_block`, apply normal logical line counting. If body is an expression, return 1.

### Pattern 4: Parameter Count (Structural)

**What:** Count parameters in `formal_parameters` + generic `type_parameters` (locked decision: both count).

```zig
/// Count parameters for a function node (runtime + generic type params)
pub fn countParameters(node: tree_sitter.Node) u32 {
    var count: u32 = 0;

    // Count formal_parameters children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (std.mem.eql(u8, ct, "formal_parameters")) {
                // Count non-punctuation children (the actual parameter nodes)
                count += countFormalParams(child);
            } else if (std.mem.eql(u8, ct, "type_parameters")) {
                // Count generic type params
                count += countTypeParams(child);
            }
        }
    }
    return count;
}

fn countFormalParams(params_node: tree_sitter.Node) u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < params_node.childCount()) : (i += 1) {
        if (params_node.child(i)) |child| {
            const ct = child.nodeType();
            // Skip punctuation: (, ), ,
            if (!std.mem.eql(u8, ct, "(") and
                !std.mem.eql(u8, ct, ")") and
                !std.mem.eql(u8, ct, ","))
            {
                count += 1;
            }
        }
    }
    return count;
}
```

### Pattern 5: Nesting Depth (Structural)

**What:** Walk the function body tracking nesting depth. Record maximum depth seen. Same nesting rules as cognitive complexity (for/while/do/if/switch/catch/ternary/arrow_callbacks).

```zig
const NestingContext = struct {
    current_depth: u32,
    max_depth: u32,
};

fn walkNesting(ctx: *NestingContext, node: tree_sitter.Node) void {
    const node_type = node.nodeType();

    // Stop at nested function boundaries (same as cognitive.zig)
    if (isFunctionNode(node)) return;

    const is_nesting = std.mem.eql(u8, node_type, "if_statement") or
        std.mem.eql(u8, node_type, "for_statement") or
        std.mem.eql(u8, node_type, "for_in_statement") or
        std.mem.eql(u8, node_type, "while_statement") or
        std.mem.eql(u8, node_type, "do_statement") or
        std.mem.eql(u8, node_type, "switch_statement") or
        std.mem.eql(u8, node_type, "catch_clause") or
        std.mem.eql(u8, node_type, "ternary_expression");

    if (is_nesting) {
        ctx.current_depth += 1;
        if (ctx.current_depth > ctx.max_depth) {
            ctx.max_depth = ctx.current_depth;
        }
    }

    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            walkNesting(ctx, child);
        }
    }

    if (is_nesting) {
        ctx.current_depth -= 1;
    }
}
```

### Pattern 6: Export Count (per file)

**What:** Count exported symbols at the program level.

```zig
pub fn countExports(root: tree_sitter.Node) u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < root.childCount()) : (i += 1) {
        if (root.child(i)) |child| {
            const ct = child.nodeType();
            if (std.mem.eql(u8, ct, "export_statement") or
                std.mem.eql(u8, ct, "export_default_declaration"))
            {
                count += 1;
            }
        }
    }
    return count;
}
```

### Pattern 7: ThresholdResult Extension

Current `ThresholdResult` in `cyclomatic.zig` has: `complexity`, `status`, `cognitive_complexity`, `cognitive_status`, identity fields. Phase 7 adds:

```zig
pub const ThresholdResult = struct {
    // Cyclomatic (Phase 4)
    complexity: u32,
    status: ThresholdStatus,
    // Cognitive (Phase 6)
    cognitive_complexity: u32,
    cognitive_status: ThresholdStatus,
    // Halstead (Phase 7)
    halstead_volume: f64,
    halstead_difficulty: f64,
    halstead_effort: f64,
    halstead_bugs: f64,
    halstead_volume_status: ThresholdStatus,
    halstead_effort_status: ThresholdStatus,
    // Structural (Phase 7)
    function_length: u32,
    params_count: u32,
    nesting_depth: u32,
    function_length_status: ThresholdStatus,
    params_count_status: ThresholdStatus,
    nesting_depth_status: ThresholdStatus,
    // Identity
    function_name: []const u8,
    function_kind: []const u8,
    start_line: u32,
    start_col: u32,
    end_line: u32,  // Phase 7 can now provide this from FunctionComplexity
};
```

Note: File-level structural metrics (file_length, export_count) belong in `FileThresholdResults` in `console.zig`, not in `ThresholdResult`.

### Pattern 8: Config Extension

Two new config structs to add alongside `CyclomaticConfig` and `CognitiveConfig`:

```zig
// In halstead.zig:
pub const HalsteadConfig = struct {
    /// Volume warning threshold (default: 500)
    volume_warning: f64 = 500.0,
    /// Volume error threshold (default: 1000)
    volume_error: f64 = 1000.0,
    /// Difficulty warning threshold (default: 10.0)
    difficulty_warning: f64 = 10.0,
    /// Difficulty error threshold (default: 20.0)
    difficulty_error: f64 = 20.0,
    /// Effort warning threshold (default: 5000.0)
    effort_warning: f64 = 5000.0,
    /// Effort error threshold (default: 10000.0)
    effort_error: f64 = 10000.0,
    /// Estimated bugs warning threshold (default: 0.5)
    bugs_warning: f64 = 0.5,
    /// Estimated bugs error threshold (default: 2.0)
    bugs_error: f64 = 2.0,

    pub fn default() HalsteadConfig { return HalsteadConfig{}; }
};

// In structural.zig:
pub const StructuralConfig = struct {
    /// Function length warning (logical lines, default: 25)
    function_length_warning: u32 = 25,
    /// Function length error (default: 50)
    function_length_error: u32 = 50,
    /// Parameter count warning (default: 3)
    params_count_warning: u32 = 3,
    /// Parameter count error (default: 6)
    params_count_error: u32 = 6,
    /// Nesting depth warning (default: 3)
    nesting_depth_warning: u32 = 3,
    /// Nesting depth error (default: 5)
    nesting_depth_error: u32 = 5,
    /// File length warning (logical lines, default: 300)
    file_length_warning: u32 = 300,
    /// File length error (default: 600)
    file_length_error: u32 = 600,
    /// Export count warning (default: 15)
    export_count_warning: u32 = 15,
    /// Export count error (default: 30)
    export_count_error: u32 = 30,

    pub fn default() StructuralConfig { return StructuralConfig{}; }
};
```

### Anti-Patterns to Avoid

- **Including TypeScript type annotations in Halstead counts:** `type_annotation`, `type_identifier`, `generic_type` nodes must be skipped entirely when traversing. Failing to skip them inflates scores for TypeScript vs equivalent JavaScript.
- **Divide-by-zero in Halstead formulas:** When n2 == 0 (no operands), difficulty formula `(n1/2) * (N2/n2)` divides by zero. Guard: if n2 == 0 OR n == 0, set volume=0, difficulty=0, all derived metrics=0.
- **Counting the same token twice:** For binary operators, the operator text is a child of the `binary_expression` node. Only classify leaf nodes (childCount() == 0) to avoid double-counting.
- **Counting closing brackets separately:** Classic Halstead counts `()` as ONE operator (a pair). Tree-sitter produces `(` and `)` as separate leaf nodes. Count only `(` for call expressions, skip `)`. Same for `[` / `]`.
- **Including nested function bodies in Halstead:** Like cyclomatic/cognitive, stop traversal at nested function node boundaries. Each function gets its own independent Halstead counts.
- **Not exposing `isNamed()` in tree_sitter.zig:** The current wrapper lacks `ts_node_is_named()`. Rather than adding it (and having to reason about the named/anonymous distinction across all code), just classify by `nodeType()` string directly — more explicit and easier to test.
- **Computing Halstead on interface/type alias bodies:** Locked decision: skip these. In tree-sitter, `interface_declaration` and `type_alias_declaration` are top-level program children. Walk the function list (using existing `walkAndAnalyze` pattern), skip non-function nodes that have type-only bodies.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST parsing | Custom TS/JS parser | tree-sitter (already integrated) | Already proven, same as all prior phases |
| Distinct-token tracking | Array with linear search | `std.StringHashMap(void)` from Zig stdlib | O(1) lookup, correct distinct-count semantics |
| Threshold validation | New logic | Reuse `validateThreshold()` from `cyclomatic.zig` | Already handles warning/error level logic |
| Function discovery | New walker | Reuse `walkAndAnalyze` pattern from `cyclomatic.zig` | Already handles all JS/TS function forms |
| log2 computation | Custom bit-twiddling | `std.math.log2()` from Zig stdlib | Already available, correct for f64 |
| Function name extraction | New logic | Reuse `extractFunctionInfo` from `cyclomatic.zig` | Already handles all function forms |

**Key insight:** Phase 7 adds NEW counting logic (token classification for Halstead, logical line counting, nesting depth tracking) but reuses ALL existing infrastructure for function discovery, name extraction, threshold validation, and pipeline integration.

## Halstead Formulas (Verified)

From Halstead (1977) "Elements of Software Science" and verified via Wikipedia:

```
n1 = number of distinct operators
n2 = number of distinct operands
N1 = total number of operator occurrences
N2 = total number of operand occurrences

Vocabulary:  n = n1 + n2
Length:      N = N1 + N2
Volume:      V = N * log2(n)               [bits of information]
Difficulty:  D = (n1/2) * (N2/n2)         [0 if n2 == 0]
Effort:      E = V * D                    [mental effort units]
Time:        T = E / 18                   [seconds]
Bugs:        B = V / 3000                 [estimated delivered bugs]
```

Note on Bugs formula: Two versions exist in literature:
- Halstead original: B = V / 3000
- Alternative: B = E^(2/3) / 3000

Use `B = V / 3000` — it is the canonical original formula, simpler, and used by most tools. The alternative is less common.

## Threshold Recommendations (Claude's Discretion)

Industry thresholds are not standardized (SonarQube does not use Halstead; CodeClimate references but does not enforce specific values). Based on academic literature and Verifysoft/objectscriptQuality recommendations:

**Halstead Volume (V):**
- Functions: minimum 20 (trivial), maximum 1000 (too large)
- **Warning: 500** — function doing multiple things
- **Error: 1000** — function clearly too large
- Academic basis: "volume greater than 1000 indicates function probably does too many things" (objectscriptQuality)

**Halstead Difficulty (D):**
- Warning: 10.0 — moderately difficult to understand
- Error: 20.0 — very difficult, rewrite candidate
- Rationale: D increases when vocabulary is large and operands are reused heavily. 10 is a reasonable "start worrying" threshold.

**Halstead Effort (E):**
- Warning: 5000 — noticeable implementation effort
- Error: 10000 — substantial effort, likely needs decomposition
- Rationale: Effort = V * D, so warning and error are products of their respective thresholds.

**Estimated Bugs (B = V/3000):**
- Warning: 0.5 — function has ~50% expected bug rate
- Error: 2.0 — "less than 2 delivered bugs per file" (objectscriptQuality standard for files)
- For functions: 2.0 is very high; 0.5 is a practical warning level.

**Structural thresholds:**
- Function length: warning=25, error=50 (locked at 25 by user; error at 2x)
- Parameter count: warning=3, error=6 (locked at 3 by user; error at 2x)
- Nesting depth: warning=3, error=5 (locked at 3 by user; error at ~1.67x)
- File length: warning=300, error=600 (reasonable for logical lines)
- Export count: warning=15, error=30 (flags barrel files; 15 exports is already a lot)

## Common Pitfalls

### Pitfall 1: TypeScript Type Node Leakage

**What goes wrong:** TypeScript's `type_annotation` subtrees (`: string`, `as Type`, generic `<T>`) get classified as operators/operands, inflating Halstead scores vs equivalent JavaScript.

**Why it happens:** The AST walker recurses into all children, and type annotations are children of parameter nodes, variable declarations, etc.

**How to avoid:** Maintain a skip-list of TypeScript-specific type node types. When `classifyNode()` encounters one of these, return immediately without recursing:

```zig
fn isTypeOnlyNode(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "type_annotation") or
        std.mem.eql(u8, node_type, "type_identifier") or
        std.mem.eql(u8, node_type, "generic_type") or
        std.mem.eql(u8, node_type, "type_parameters") or
        std.mem.eql(u8, node_type, "type_parameter") or
        std.mem.eql(u8, node_type, "predefined_type") or
        std.mem.eql(u8, node_type, "union_type") or
        std.mem.eql(u8, node_type, "intersection_type") or
        std.mem.eql(u8, node_type, "array_type") or
        std.mem.eql(u8, node_type, "object_type") or
        std.mem.eql(u8, node_type, "tuple_type") or
        std.mem.eql(u8, node_type, "function_type") or
        std.mem.eql(u8, node_type, "readonly_type") or
        std.mem.eql(u8, node_type, "type_query") or
        std.mem.eql(u8, node_type, "as_expression") or  // x as Type — skip the whole thing or just the type part
        std.mem.eql(u8, node_type, "satisfies_expression"); // x satisfies Type — similarly
}
```

**Warning signs:** TypeScript functions scoring significantly higher than equivalent JavaScript equivalents.

### Pitfall 2: Divide-by-Zero in Halstead Formulas

**What goes wrong:** An empty function body (or a function with only comments) produces n2=0. The difficulty formula `(n1/2) * (N2/n2)` divides by zero.

**Why it happens:** Empty arrow functions like `() => {}` or functions that are stubs.

**How to avoid:** Guard formula computation:

```zig
pub fn computeHalsteadMetrics(counts: HalsteadCounts) HalsteadMetrics {
    const n1 = @as(f64, @floatFromInt(counts.operators.count()));
    const n2 = @as(f64, @floatFromInt(counts.operands.count()));
    const n1_total = @as(f64, @floatFromInt(counts.total_operators));
    const n2_total = @as(f64, @floatFromInt(counts.total_operands));

    const vocab = n1 + n2;
    const length = n1_total + n2_total;

    // Guard: if vocabulary == 0, all derived metrics are 0
    if (vocab == 0.0 or length == 0.0) {
        return HalsteadMetrics{ .n1=0, .n2=0, ... .volume=0, .difficulty=0, ... };
    }

    const volume = length * std.math.log2(vocab);

    // Guard: if n2 == 0, difficulty is 0 (no operands = trivial)
    const difficulty = if (n2 == 0.0) 0.0
        else (n1 / 2.0) * (n2_total / n2);

    const effort = volume * difficulty;
    const time = effort / 18.0;
    const bugs = volume / 3000.0;

    return HalsteadMetrics{ ... };
}
```

**Warning signs:** Panic on empty or stub functions.

### Pitfall 3: HashMap Memory Management

**What goes wrong:** `std.StringHashMap(void)` requires an allocator. If the allocator is not passed through correctly or if the HashMap is not `deinit()`-ed, memory leaks occur.

**Why it happens:** Halstead counting creates temporary HashMaps per function. If `std.testing.allocator` is used in tests (required by CLAUDE.md conventions), leaked HashMaps will be detected.

**How to avoid:** Follow the established Zig pattern — `defer counts.operators.deinit();` immediately after init. Extract the count values before deinit. Only the final `HalsteadMetrics` struct (which holds only primitive f64/u32 values) is returned.

**Example:**
```zig
pub fn calculateHalstead(
    allocator: Allocator,
    node: tree_sitter.Node,
    source: []const u8,
) !HalsteadMetrics {
    var operators = std.StringHashMap(void).init(allocator);
    defer operators.deinit();
    var operands = std.StringHashMap(void).init(allocator);
    defer operands.deinit();

    // ... walk and classify ...

    return computeMetrics(operators.count(), operands.count(), total_ops, total_opnds);
}
```

**Warning signs:** `std.testing.allocator` reports leaked memory in tests.

### Pitfall 4: Logical Line Counting — Block Comments

**What goes wrong:** Multi-line block comments (`/* ... */`) get counted as code lines because only the last line ends with `*/`.

**Why it happens:** Line-by-line scan sees `/* start of comment` as code (no `//` prefix and not a blank line).

**How to avoid:** Track block comment state during line scanning:

```zig
var in_block_comment = false;
var iter = std.mem.splitScalar(u8, text, '\n');
while (iter.next()) |line| {
    const trimmed = std.mem.trim(u8, line, " \t\r");
    if (in_block_comment) {
        if (std.mem.indexOf(u8, trimmed, "*/") != null) {
            in_block_comment = false;
        }
        continue; // Skip all lines inside block comment
    }
    if (std.mem.startsWith(u8, trimmed, "/*")) {
        in_block_comment = true;
        if (std.mem.indexOf(u8, trimmed, "*/") != null) {
            in_block_comment = false; // Inline block comment
        }
        continue;
    }
    if (std.mem.startsWith(u8, trimmed, "//")) continue;
    if (trimmed.len == 0) continue;
    count += 1;
}
```

**Warning signs:** Functions with JSDoc comments reporting higher line counts than expected.

### Pitfall 5: Parameter Counting — Destructuring and Rest Params

**What goes wrong:** Destructured parameters like `{ a, b }: Props` or rest parameters `...args` count as one parameter each in the AST (one node in `formal_parameters`) but look like multiple identifiers. The user decision is clear: count parameter nodes, not identifiers within destructuring.

**How to avoid:** Count direct children of `formal_parameters` that are not punctuation. Tree-sitter represents each parameter (even destructured ones) as a single direct child of `formal_parameters`. `rest_pattern`, `assignment_pattern`, `object_pattern`, `array_pattern` are each ONE child = ONE parameter.

**Warning signs:** `function f({a, b, c}: T)` counting as 3 params instead of 1.

### Pitfall 6: Export Count — Re-exports and `export *`

**What goes wrong:** `export * from './module'` and `export { a, b, c } from './module'` count multiple symbol re-exports but represent different patterns in the AST.

**How to avoid:** For Phase 7, count `export_statement` nodes at program level (each node = 1 export event). Don't try to count individual exported names — that's over-engineered for this phase. One `export_statement` node = +1 to export count, regardless of how many symbols it exports.

**Warning signs:** Barrel files (`index.ts` with many re-exports) reporting unexpectedly low export counts.

## Data Flow Analysis

**Current pipeline (Phase 6 state):**
```
ParseResult
  → cyclomatic.analyzeFile()     → cycl ThresholdResult[]
  → cognitive.analyzeFunctions() → CognitiveFunctionResult[]
  → merge (zip by index)         → ThresholdResult[] (with cognitive fields)
  → FileThresholdResults
  → console/json output
```

**Phase 7 pipeline:**
```
ParseResult
  → cyclomatic.analyzeFunctions()  → FunctionComplexity[]
  → cognitive.analyzeFunctions()   → CognitiveFunctionResult[]
  → halstead.analyzeFunctions()    → HalsteadFunctionResult[]  (NEW)
  → structural.analyzeFunctions()  → StructuralFunctionResult[] (NEW)
  → merge all (zip by index)       → ThresholdResult[] (extended)
  → structural.analyzeFile()       → FileStructuralResult (file_length, export_count) (NEW)
  → FileThresholdResults + FileStructuralResult
  → console/json output (updated)
```

All four analysis passes walk the same AST in the same order, so results align by index (same `walkAndAnalyze` pattern established in Phase 6).

**File-level structural data** needs a new struct alongside `FileThresholdResults`:

```zig
// In structural.zig or console.zig:
pub const FileStructuralResult = struct {
    file_length: u32,
    file_length_status: ThresholdStatus,
    export_count: u32,
    export_count_status: ThresholdStatus,
};
```

`FileThresholdResults` in `console.zig` gets an optional `structural: ?FileStructuralResult` field.

## --metrics Flag Integration

The `CliArgs.metrics: ?[]const u8` field (e.g., `"cyclomatic,halstead"`) maps to `cfg.analysis.metrics: ?[]const []const u8` after parsing. The existing `config.zig` already has this field.

In `main.zig`, add helper to check if a metric family is enabled:

```zig
fn isMetricEnabled(metrics: ?[]const []const u8, metric: []const u8) bool {
    const list = metrics orelse return true; // null = all enabled
    for (list) |m| {
        if (std.mem.eql(u8, m, metric)) return true;
    }
    return false;
}
```

Then in the per-file loop:
```zig
if (isMetricEnabled(cfg.analysis.?.metrics, "halstead")) {
    // Run halstead analysis
}
if (isMetricEnabled(cfg.analysis.?.metrics, "structural")) {
    // Run structural analysis
}
```

This is the `--metrics` selectability decision locked in CONTEXT.md.

## Code Examples

### Halstead Formula Computation

```zig
// Source: Halstead (1977) "Elements of Software Science", verified via Wikipedia
pub fn computeHalsteadMetrics(
    n1: u32,  // distinct operators
    n2: u32,  // distinct operands
    n1_total: u32,  // total operator occurrences
    n2_total: u32,  // total operand occurrences
) HalsteadMetrics {
    const fn1 = @as(f64, @floatFromInt(n1));
    const fn2 = @as(f64, @floatFromInt(n2));
    const fn1t = @as(f64, @floatFromInt(n1_total));
    const fn2t = @as(f64, @floatFromInt(n2_total));

    const vocab = fn1 + fn2;
    const length = fn1t + fn2t;

    if (vocab <= 0.0 or length <= 0.0) {
        return .{ .n1 = n1, .n2 = n2, ... all derived = 0 ... };
    }

    const volume = length * std.math.log2(vocab);
    const difficulty = if (fn2 <= 0.0) 0.0 else (fn1 / 2.0) * (fn2t / fn2);
    const effort = volume * difficulty;
    const time = effort / 18.0;
    const bugs = volume / 3000.0;

    return HalsteadMetrics{
        .n1 = n1, .n2 = n2,
        .n1_total = n1_total, .n2_total = n2_total,
        .vocabulary = n1 + n2,
        .length = n1_total + n2_total,
        .volume = volume,
        .difficulty = difficulty,
        .effort = effort,
        .time = time,
        .bugs = bugs,
    };
}
```

### Fixture File for Halstead Tests

```typescript
// tests/fixtures/typescript/halstead_cases.ts

// Expected: simple function, only 2 operators (=, return), 3 operands (x, 1, result)
// n1=2, n2=3, N1=2, N2=3, vocab=5, len=5, vol=5*log2(5)≈11.6
function simpleAssignment(x: number): number {
    const result = x + 1;
    return result;
}

// Expected: TypeScript types excluded — same Halstead score as equivalent JS
function withTypeAnnotations(name: string, age: number): boolean {
    return age > 0;  // operators: >, return; operands: age, 0
}

// Equivalent JS (should have identical Halstead to withTypeAnnotations):
// function withTypeAnnotations(name, age) { return age > 0; }

// Decorator: counts as operator
@Injectable()
class Service {
    getValue(): number {
        return 42;
    }
}

// Generic params count in structural param count (6 total = 3 runtime + 3 type)
function complexSignature<T, U, V>(a: T, b: U, c: V): void {}

// Empty function — should not divide by zero
function empty(): void {}

// Single-expression arrow — 1 logical line
const add = (a: number, b: number) => a + b;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All tokens counted including TS types | Exclude TS type-only syntax | ComplexityGuard decision | TS code scores same as equivalent JS |
| Volume/3000 for bugs (original Halstead) | V/3000 (canonical) | Consistent with Halstead 1977 | Predictable, widely understood |
| No structural metrics | Logical line count, param count, nesting | Phase 7 addition | More complete structural view |
| Count all params | Count runtime + generic type params | Locked decision | Reflects full signature complexity |

## Open Questions

1. **Ternary operator as operator token classification**
   - What we know: Ternary `?:` is represented in tree-sitter as `ternary_expression` node with children `condition`, `?`, `consequence`, `:`, `alternate`
   - What's unclear: Should `?` and `:` each count as a separate operator, or should the pair count as one operator `?:`?
   - Recommendation: Count `ternary_expression` itself as one operator occurrence (1 in N1) for the operator text "?:" — check for the node type rather than its token children. This avoids counting `?` as a separate token from conditional chaining `?.`.

2. **`as_expression` node handling for TypeScript `as` casts**
   - What we know: `x as Type` is an `as_expression` node. The value `x` is an operand, `Type` is type-only.
   - What's unclear: Does the `as` keyword itself count as an operator?
   - Recommendation: Skip the entire `as_expression` for Halstead purposes (locked decision: `as` does not count). Visit the `x` sub-expression directly if needed, but since `as` expressions typically wrap identifiers/expressions that will be visited at a higher level, the simplest approach is to skip the `as_expression` node entirely. This matches the locked decision.

3. **Arrow function body type for logical line counting**
   - What we know: `(x) => expr` has no `statement_block` child — the body IS the expression
   - What's unclear: Does the expression `a + b + c` spanning multiple lines count as 1 logical line or multiple?
   - Recommendation: Single-expression arrow functions count as 1 logical line regardless (locked decision). Check: if the function body is NOT a `statement_block`, return 1.

4. **`export count` for `export * from '...'`**
   - What we know: `export * from './module'` is a single `export_statement` in tree-sitter
   - What's unclear: Should `export { a, b, c }` count as 1 export or 3?
   - Recommendation: Count 1 per `export_statement` node. Counting individual names is over-engineered; the export count metric is about "how many export statements does this file have," not "how many names are exported."

5. **`FileThresholdResults` modification scope**
   - What we know: `console.zig` uses `FileThresholdResults` as a struct with `.path` and `.results`
   - What's unclear: Adding `.structural: ?FileStructuralResult` to it vs creating a parallel struct
   - Recommendation: Add `.structural` field to `FileThresholdResults` as optional (null until Phase 7 populates it). Minimal change, backward compatible with existing tests.

## Sources

### Primary (HIGH confidence)

- **Halstead (1977) "Elements of Software Science"** — original Halstead formulas. Vocabulary, Length, Volume, Difficulty, Effort, Time, Bugs formulas verified.
  - Derived via: Wikipedia Halstead complexity measures page (confirmed same formulas)

- **objectscriptQuality Halstead page** — concrete thresholds: "volume greater than 1000 indicates function probably does too many things"; "estimated bugs in a file should be less than 2"
  - URL: https://objectscriptquality.com/docs/metrics/halstead

- **DAC Manual — Halstead classification** — C-language classification reference. Operator list (keywords as operators, assignment, arithmetic, comparison, logical, `(`, `,`, `{`). Operands = identifiers + constants + strings.
  - URL: https://www.ristancase.com/html/dac/manual/2.12.01-Software-Metrics-Classification.html

- **Existing codebase (HIGH)** — `cyclomatic.zig`, `cognitive.zig`, `console.zig`, `json_output.zig`, `main.zig`, `config.zig` — all read directly. Phase 7 pipeline constraints are HIGH confidence based on actual code.

- **tree-sitter C API (`cimport.zig` in .zig-cache)** — `ts_node_is_named()` is available in the C API if needed. Current `tree_sitter.zig` wrapper does not expose it.

### Secondary (MEDIUM confidence)

- **Verifysoft Halstead Metrics page** — confirms volume thresholds: function max 1000, file max 8000; bugs "should be less than 2"
  - URL: https://www.verifysoft.com/en_halstead_metrics.html

- **Grokipedia Halstead** — confirms all formulas including the two variants of B formula; confirms operator/operand categories
  - URL: https://grokipedia.com/page/Halstead_complexity_measures

- **SonarQube documentation** — confirmed SonarQube does NOT use Halstead metrics. Not relevant for threshold comparison.

### Tertiary (LOW confidence)

- escomplex, typhonjs-escomplex — mentioned in research but source code classification rules not accessible. General alignment with tree-sitter approach confirmed from description.

## Metadata

**Confidence breakdown:**
- Halstead formulas: HIGH — verified from multiple sources
- Volume/bugs thresholds: MEDIUM — based on objectscriptQuality + Verifysoft; no single authoritative standard
- Difficulty/effort thresholds: LOW — no strong industry consensus; values chosen by ratio reasoning
- Operator/operand classification for JS/TS: MEDIUM — derived from C language rules + adapted for JS/TS AST structure
- TypeScript exclusion rules: HIGH — locked by user decisions; list of TS-specific node types from tree-sitter grammar knowledge
- Zig implementation patterns: HIGH — codebase analyzed directly; patterns mirrored from cyclomatic.zig + cognitive.zig
- Pipeline integration: HIGH — based on actual main.zig analysis

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (Halstead theory is stable; tree-sitter grammars are stable; verify no Zig stdlib HashMap API changes if upgrading Zig version)
