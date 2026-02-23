# Phase 4: Cyclomatic Complexity - Research

**Researched:** 2026-02-14
**Domain:** McCabe cyclomatic complexity calculation for JavaScript/TypeScript
**Confidence:** HIGH

## Summary

Cyclomatic complexity is a software metric developed by Thomas McCabe in 1976 that measures the number of linearly independent paths through a program's source code. For Phase 4, we need to implement a tree-sitter AST traversal that counts decision points in JavaScript/TypeScript functions and validates against configurable thresholds.

Modern static analysis tools (ESLint, SonarQube, CodeClimate) have converged on practical standards for what increments complexity, with ESLint recently (2025) adding support for modern JavaScript features like optional chaining and default parameters. The industry shows consensus around 10-20 as reasonable thresholds, with McCabe's original limit of 10 having strong supporting evidence.

**Primary recommendation:** Implement ESLint-aligned counting (including optional chaining, default parameters, logical operators) with configurable thresholds defaulting to warning=10, error=20. Support both classic and modified switch-case counting variants.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Claude's Discretion

User directed: "Research modern best practices and decide for me" across all decision areas. Claude has full flexibility guided by research into modern tools (ESLint, SonarQube, CodeClimate, etc.).

**Counting philosophy**
- Determine what increments the count: traditional McCabe vs modern JS-aware counting
- Decide default treatment of logical operators (&&, ||), optional chaining (?.), nullish coalescing (??), ternary expressions
- Research how leading tools handle these and choose sensible defaults
- Configurability: user should be able to toggle optional constructs on/off

**Default thresholds**
- Research industry-standard warning and error levels (ESLint default 20, SonarQube 10/20/30, academic McCabe 10)
- Choose defaults that balance catching genuinely complex functions without noisy false positives
- Thresholds must be configurable per the existing config system

**Function scope**
- Determine what counts as a "function" for analysis: named functions, arrow functions, class methods, getters/setters, constructors, IIFEs, module-level code
- Research what modern tools include/exclude by default

**Switch/case handling**
- Decide between each-case-counts (standard McCabe) vs switch-only counting
- Research modern tool consensus on this controversial point

### Locked Decisions (from existing codebase)

- Using tree-sitter for AST parsing with JavaScript/TypeScript grammars
- Data structure already defined: `FunctionResult.cyclomatic: ?u32`
- Zig implementation with idiomatic wrapper types (Node wraps TSNode)
- Phase boundary: this phase computes and validates metrics only, Phase 8 handles output formatting

### Deferred Ideas (OUT OF SCOPE)

None specified in CONTEXT.md.
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tree-sitter | latest | AST parsing | Already integrated, proven error-tolerant parsing |
| tree-sitter-javascript | latest | JS/JSX grammar | Official grammar, handles ES2020+ features |
| tree-sitter-typescript | latest | TS/TSX grammar | Official grammar, handles TypeScript-specific syntax |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| N/A | - | Pure traversal logic | No additional libraries needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tree-sitter | SWC parser | SWC is Rust-based, harder Zig interop; tree-sitter already integrated |
| Manual counting | Graph-based CFG | Graph construction (E - N + 2P) more complex; decision-point counting equivalent and simpler |

**Installation:**
Already integrated in vendor/tree-sitter. No additional dependencies needed.

## Architecture Patterns

### Recommended Module Structure
```
src/metrics/
├── cyclomatic.zig           # Main complexity calculator
├── cyclomatic_config.zig    # Configuration for counting variants
└── threshold.zig            # Threshold validation logic
```

### Pattern 1: Recursive AST Traversal with Accumulator

**What:** Depth-first traversal of tree-sitter AST nodes, accumulating complexity as decision points are encountered.

**When to use:** For all function-level metric calculations that require visiting every node.

**Example:**
```zig
// Based on tree-sitter API pattern
pub fn calculateComplexity(node: tree_sitter.Node, config: Config) u32 {
    var complexity: u32 = 1; // Base complexity

    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child_node| {
            complexity += countDecisionPoints(child_node, config);
        }
    }

    return complexity;
}

fn countDecisionPoints(node: tree_sitter.Node, config: Config) u32 {
    const node_type = node.nodeType();
    var count: u32 = 0;

    // Control flow statements
    if (std.mem.eql(u8, node_type, "if_statement")) count += 1;
    else if (std.mem.eql(u8, node_type, "while_statement")) count += 1;
    else if (std.mem.eql(u8, node_type, "for_statement")) count += 1;
    else if (std.mem.eql(u8, node_type, "for_in_statement")) count += 1;
    // ... additional node types

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            count += countDecisionPoints(child, config);
        }
    }

    return count;
}
```

### Pattern 2: Configuration-Driven Counting

**What:** Use configuration struct to toggle optional constructs (logical operators, optional chaining, etc.) on/off.

**When to use:** When different counting philosophies need to be supported (classic vs modified, ESLint vs academic).

**Example:**
```zig
pub const CyclomaticConfig = struct {
    count_logical_operators: bool = true,     // Count && and ||
    count_nullish_coalescing: bool = true,    // Count ??
    count_optional_chaining: bool = true,     // Count ?.
    count_ternary: bool = true,               // Count ? :
    count_default_params: bool = true,        // Count default parameter values
    switch_case_mode: SwitchCaseMode = .classic, // classic or modified

    pub const SwitchCaseMode = enum {
        classic,   // Each case increments
        modified,  // Entire switch counts as 1
    };
};
```

### Pattern 3: Threshold Validation

**What:** Separate validation step after complexity calculation to compare against configured thresholds.

**When to use:** For any metric with warning/error thresholds that need to be configurable.

**Example:**
```zig
pub const ThresholdResult = struct {
    value: u32,
    status: Status,

    pub const Status = enum {
        ok,      // Below warning threshold
        warning, // Between warning and error
        error,   // Above error threshold
    };
};

pub fn validateThreshold(complexity: u32, warning: u32, error_level: u32) ThresholdResult {
    const status = if (complexity >= error_level)
        .error
    else if (complexity >= warning)
        .warning
    else
        .ok;

    return ThresholdResult{
        .value = complexity,
        .status = status,
    };
}
```

### Anti-Patterns to Avoid

- **Building control flow graph first:** Complexity can be calculated directly from AST traversal without constructing an explicit CFG. The graph-based formula E - N + 2P is mathematically equivalent but adds unnecessary complexity.
- **Nested function confusion:** Don't count complexity of inner functions toward outer function. Each function declaration starts a new complexity context at base 1.
- **Double-counting switch statements:** In classic mode, count each `case`, not both the `switch_statement` and `switch_case` nodes.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST parsing | Custom JS/TS parser | tree-sitter grammars | Already integrated, handles ES2020+ syntax, error-tolerant |
| Node type identification | String prefix matching, regex | Direct string equality on `node.nodeType()` | tree-sitter provides exact type strings |
| Configuration merging | Custom merge logic | Existing config system from Phase 1 | Already handles .complexityguardrc merging |

**Key insight:** The complexity of cyclomatic complexity comes from correctly identifying all decision points in modern JavaScript. tree-sitter's grammar already solved that problem.

## Common Pitfalls

### Pitfall 1: Forgetting Modern JavaScript Constructs
**What goes wrong:** Missing optional chaining (`?.`), nullish coalescing (`??`), or default parameters leads to underreporting complexity.

**Why it happens:** Traditional McCabe complexity predates these features. Older tools don't count them.

**How to avoid:** Explicitly check for:
- `binary_expression` nodes with `??` operator
- `member_expression` nodes with `optional_chain` field
- Function/destructuring nodes with default values
- Logical assignment operators (`&&=`, `||=`)

**Warning signs:** Test coverage tools (like Istanbul/nyc) report different branch counts than your complexity metric.

### Pitfall 2: Switch Statement Double-Counting
**What goes wrong:** Counting both the `switch_statement` node AND each `switch_case` child, inflating the score.

**Why it happens:** Recursive traversal naturally visits both parent and child nodes.

**How to avoid:** In classic mode, count `switch_case` nodes only (skip `switch_statement` itself). In modified mode, count `switch_statement` once (skip all `switch_case` children).

**Warning signs:** Switch with 3 cases reports complexity +4 instead of +3 (classic) or +1 (modified).

### Pitfall 3: Logical Operator Ambiguity
**What goes wrong:** Treating `if (a && b)` as complexity +1 vs +3.

**Why it happens:** Controversy over whether compound conditions count as single decision or multiple predicates.

**How to avoid:** Follow ESLint precedent: count each `&&` and `||` as separate decision point within expressions. Research shows test coverage tools count them as separate branches.

**Warning signs:** Code with deeply nested logical expressions shows artificially low complexity.

### Pitfall 4: Try-Catch-Finally Handling
**What goes wrong:** Inconsistent counting of exception handling constructs.

**Why it happens:** Some tools count `try`, some count `catch`, some count both.

**How to avoid:** ESLint/academic consensus: count each `catch` clause (it's a decision point for error path). Don't count `try` or `finally` blocks themselves.

**Warning signs:** Functions with multiple catch blocks don't show increased complexity.

### Pitfall 5: Default Parameter Counting
**What goes wrong:** Ignoring default parameters, which create implicit branches.

**Why it happens:** Recently added to ESLint (2025), older references don't mention it.

**How to avoid:** Count each default parameter value as +1 (it creates an implicit `if (param === undefined)` branch).

**Warning signs:** ESLint complexity differs from your tool's complexity.

## Code Examples

### Tree-Sitter Node Types for Decision Points

Based on official tree-sitter-javascript grammar:

```zig
// Source: https://github.com/tree-sitter/tree-sitter-javascript/blob/master/src/node-types.json
// Verified 2026-02-14

const DecisionNodeTypes = [_][]const u8{
    // Control flow statements
    "if_statement",           // if/else if
    "while_statement",        // while loop
    "do_statement",           // do-while loop
    "for_statement",          // for loop
    "for_in_statement",       // for-in loop
    "switch_case",            // case in switch (classic mode)

    // Exception handling
    "catch_clause",           // catch block

    // Ternary operator
    "ternary_expression",     // condition ? true : false
};

const ConditionalNodeTypes = [_][]const u8{
    // Logical operators (when config.count_logical_operators = true)
    "&&",  // logical AND (inside binary_expression)
    "||",  // logical OR (inside binary_expression)
    "??",  // nullish coalescing (inside binary_expression)
    "&&=", // logical AND assignment
    "||=", // logical OR assignment
};
```

### Identifying Logical Operators

```zig
// Source: ESLint complexity rule behavior
// https://eslint.org/docs/latest/rules/complexity

fn isLogicalOperator(node: tree_sitter.Node, config: CyclomaticConfig) bool {
    if (!config.count_logical_operators) return false;

    const node_type = node.nodeType();

    // Check for binary_expression with logical operators
    if (std.mem.eql(u8, node_type, "binary_expression")) {
        // Need to check the operator field
        // tree-sitter provides operator as a child node
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "&&") or
                    std.mem.eql(u8, child_type, "||") or
                    (config.count_nullish_coalescing and std.mem.eql(u8, child_type, "??")))
                {
                    return true;
                }
            }
        }
    }

    return false;
}
```

### Optional Chaining Detection

```zig
// Source: tree-sitter-typescript node-types.json
// member_expression has optional_chain field

fn hasOptionalChaining(node: tree_sitter.Node) bool {
    const node_type = node.nodeType();

    if (std.mem.eql(u8, node_type, "member_expression") or
        std.mem.eql(u8, node_type, "call_expression"))
    {
        // Check for optional_chain child node
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "?.")) {
                    return true;
                }
            }
        }
    }

    return false;
}
```

### Function Scope Identification

```zig
// What counts as a "function" for complexity analysis
const FunctionNodeTypes = [_][]const u8{
    "function_declaration",        // function foo() {}
    "function",                    // function expression
    "arrow_function",              // () => {}
    "method_definition",           // class methods
    "generator_function",          // function* gen() {}
    "generator_function_declaration",
};

fn isFunctionNode(node: tree_sitter.Node) bool {
    const node_type = node.nodeType();

    for (FunctionNodeTypes) |func_type| {
        if (std.mem.eql(u8, node_type, func_type)) {
            return true;
        }
    }

    return false;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Classic McCabe only | Classic + modified variants | ESLint 2024 | Teams can choose switch counting philosophy |
| Ignore modern JS features | Count optional chaining, default params | ESLint PR #18152 (2025) | Aligns complexity with test coverage tools |
| Fixed threshold of 20 | Configurable warning/error levels | Industry standard | Teams tune to their domain (low-level: higher, business logic: lower) |
| Graph-based calculation | Direct AST traversal | N/A | Simpler implementation, equivalent result |

**Deprecated/outdated:**
- **NPATH complexity:** Counts all execution paths (exponential), too sensitive. McCabe's linear count is more practical.
- **Switch-only counting as "wrong":** Now accepted as "modified complexity," valid alternative to classic.
- **Threshold of 10 as absolute rule:** Now understood as guideline; 10-20 range acceptable depending on context.

## Open Questions

1. **IIFEs (Immediately Invoked Function Expressions)**
   - What we know: ESLint treats them as regular functions
   - What's unclear: Should they be analyzed separately or inline with parent context?
   - Recommendation: Treat as separate function scope (starts at complexity 1) - aligns with ESLint behavior

2. **Module-level code**
   - What we know: Not technically a "function" but executable code
   - What's unclear: Should top-level code be analyzed for complexity?
   - Recommendation: Skip for Phase 4 (focus on functions only) - can revisit in later phases if needed

3. **Nested function context**
   - What we know: Each function starts at base complexity 1
   - What's unclear: Exact mechanism to track "current function" during traversal
   - Recommendation: Maintain stack of function scopes during traversal, attribute decision points to current scope

## Recommended Decisions

Based on research into ESLint (industry standard for JS/TS linting), SonarQube (enterprise static analysis), and McCabe's original academic work:

### Counting Philosophy: Modern ESLint-Aligned

**Decision:** Implement ESLint's current (2025) counting rules as defaults, with configuration toggles for strictness.

**What increments by default:**
- Control flow: `if`, `else if`, `while`, `do-while`, `for`, `for-in`, `for-of` (+1 each)
- Switch cases: Each `case` in classic mode (+1 per case), entire `switch` in modified mode (+1 total)
- Exception handling: Each `catch` clause (+1)
- Ternary operators: `? :` expressions (+1)
- Logical operators: `&&`, `||` within expressions (+1 each)
- Nullish coalescing: `??` operator (+1)
- Optional chaining: Each `?.` access (+1)
- Default parameters: Each default value in function signature or destructuring (+1)
- Logical assignment: `&&=`, `||=` operators (+1)

**Rationale:** ESLint's complexity rule is the de facto standard for JavaScript/TypeScript. Their recent addition of optional chaining and default parameters reflects industry recognition that these create real branches that test coverage tools measure.

### Default Thresholds: Conservative Academia-Aligned

**Decision:** Warning at 10, error at 20.

**Rationale:**
- McCabe's original recommendation of 10 has "substantial corroborating evidence" (NIST)
- ESLint defaults to 20 (permissive)
- SonarQube highlights >10 in red (strict)
- Our choice: 10 warning (academic standard), 20 error (ESLint standard)
- Gives teams early warning without false-positive noise

### Function Scope: Explicit Functions Only

**Decision:** Analyze these constructs as separate functions:
- Named function declarations
- Function expressions (anonymous or named)
- Arrow functions
- Class methods (including getters, setters, constructors)
- Generator functions

**Exclude from analysis:**
- Module-level code (no function wrapper)
- IIFEs (analyze as functions, but they're rare in modern code)

**Rationale:** Aligns with ESLint's function-level scope. Module-level code is uncommon in TypeScript/modern JS (usually wrapped in functions/classes).

### Switch/Case Handling: Both Variants Supported

**Decision:** Support both classic and modified, default to **classic** (each case counts).

**Rationale:**
- Classic is traditional McCabe, most conservative
- Modified is useful for large state machines (don't penalize necessary switches)
- ESLint supports both as of 2024
- Default to classic (stricter is safer starting point)

### Configuration Structure

```zig
pub const CyclomaticConfig = struct {
    // Thresholds
    warning_threshold: u32 = 10,
    error_threshold: u32 = 20,

    // Counting toggles
    count_logical_operators: bool = true,
    count_nullish_coalescing: bool = true,
    count_optional_chaining: bool = true,
    count_ternary: bool = true,
    count_default_params: bool = true,

    // Switch handling
    switch_case_mode: SwitchCaseMode = .classic,

    pub const SwitchCaseMode = enum {
        classic,   // Each case increments (+1 per case)
        modified,  // Switch counts once (+1 total)
    };
};
```

**.complexityguardrc mapping:**
```json
{
  "cyclomatic": {
    "warning": 10,
    "error": 20,
    "countLogicalOperators": true,
    "countNullishCoalescing": true,
    "countOptionalChaining": true,
    "countTernary": true,
    "countDefaultParams": true,
    "switchCaseMode": "classic"
  }
}
```

## Sources

### Primary (HIGH confidence)

**ESLint Official Documentation:**
- [ESLint complexity rule](https://eslint.org/docs/latest/rules/complexity) - Official documentation of counting rules and configuration
- [ESLint complexity rule (archived)](https://archive.eslint.org/docs/rules/complexity) - Historical reference for comparison

**ESLint GitHub:**
- [Rule Change: extend complexity rule to count optional chaining and default parameters · Issue #18060](https://github.com/eslint/eslint/issues/18060) - Accepted proposal (merged PR #18152) adding modern JS features
- [Exclude Default Parameter Values from Cyclomatic Complexity Calculation · Issue #19360](https://github.com/eslint/eslint/issues/19360) - Recent discussion (January 2025) on default parameter counting

**Academic Sources:**
- [McCabe's original paper (literateprogramming.com PDF)](http://www.literateprogramming.com/mccabe.pdf) - Original 1976 specification
- [NIST Special Publication 500-235](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication500-235.pdf) - Testing methodology using cyclomatic complexity
- [Cyclomatic complexity - Wikipedia](https://en.wikipedia.org/wiki/Cyclomatic_complexity) - Well-sourced academic overview

**tree-sitter Documentation:**
- [tree-sitter-javascript on GitHub](https://github.com/tree-sitter/tree-sitter-javascript) - Official JavaScript grammar
- [tree-sitter-typescript on GitHub](https://github.com/tree-sitter/tree-sitter-typescript) - Official TypeScript grammar
- [Static Node Types - Tree-sitter](https://tree-sitter.github.io/tree-sitter/using-parsers/6-static-node-types.html) - Node type documentation

### Secondary (MEDIUM confidence)

**Industry Tools:**
- [SonarQube Community: JavaScript Cyclomatic Complexity](https://community.sonarsource.com/t/javascript-cyclomatic-complexity-computation-and-threshold/1985) - Industry tool thresholds
- [Understanding measures and metrics | SonarQube Server 10.8](https://docs.sonarsource.com/sonarqube-server/10.8/user-guide/code-metrics/metrics-definition) - SonarQube metric definitions
- [CodeClimate: Cyclomatic Complexity](https://docs.codeclimate.com/docs/cyclomatic-complexity) - Another industry perspective (connection refused during research, referenced from search results)

**Microsoft Documentation:**
- [CA1502: Avoid excessive complexity - .NET](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1502) - Microsoft's threshold (25) and rationale
- [Code metrics - Cyclomatic complexity - Visual Studio](https://learn.microsoft.com/en-us/visualstudio/code-quality/code-metrics-cyclomatic-complexity?view=vs-2022) - Visual Studio implementation

**Community Resources:**
- [Managing Code Complexity | Developer Guidelines (Trimble)](https://devguide.trimble.com/development-practices/managing-code-complexity/) - Industry best practices
- [Cyclomatic Complexity Guide | Sonar](https://www.sonarsource.com/resources/library/cyclomatic-complexity/) - Educational resource from SonarSource
- [Cyclomatic complexity refactoring tips for javascript developers](https://sergeyski.com/cyclomatic-complexity-refactoring-tips/) - Practical refactoring guidance

### Tertiary (LOW confidence - flagged for validation)

**Tool-specific implementations (not verified):**
- Various language-specific implementations (GMetrics, Checkstyle, etc.) - referenced for cross-language comparison but not authoritative for JavaScript/TypeScript

**Unverified claims:**
- Some blog posts suggest thresholds without citing sources - NOT used for recommendations

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - tree-sitter already integrated, official grammars
- Counting rules: HIGH - ESLint official docs + merged PR, cross-verified with academic sources
- Thresholds: HIGH - Multiple authoritative sources (McCabe, NIST, ESLint, SonarQube) converge
- Node types: HIGH - Verified directly from tree-sitter-javascript repository
- Architecture: MEDIUM - Patterns inferred from tree-sitter API + Zig conventions, not from existing cyclomatic complexity implementations in Zig

**Research date:** 2026-02-14
**Valid until:** ~30 days (2026-03-15) - tree-sitter grammars and ESLint rules are stable, but verify no breaking changes before implementation
