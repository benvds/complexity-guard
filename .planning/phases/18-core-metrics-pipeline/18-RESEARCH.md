# Phase 18: Core Metrics Pipeline - Research

**Researched:** 2026-02-24
**Domain:** Zig-to-Rust port of five metric families (cyclomatic, cognitive, Halstead, structural, duplication) + composite health scoring for a tree-sitter-based TypeScript/JavaScript static analysis tool
**Confidence:** HIGH

## Summary

Phase 18 ports all five ComplexityGuard metric families from Zig to Rust. This is the single largest phase in the v0.8 milestone: it transforms the Phase 17 stub binary (which parses files and extracts function names) into a binary that produces accurate per-file metric output matching the Zig v1.0 values. The dependency for every subsequent phase (CLI output, parallel pipeline) is on the correctness of these metrics.

The Zig source code has been read in full. Every algorithm is concrete: cyclomatic complexity is a DFS tree walk counting specific node types; cognitive complexity is a recursive visitor with nesting-level context and the critical per-operator deviation; Halstead is a leaf-node classification pass building two hash maps; structural metrics are a single-pass walk counting logical lines, parameters, nesting depth, and exports; duplication is Rabin-Karp rolling hash over a normalized token sequence; and scoring is sigmoid-normalized weighted averages. Every algorithm translates directly to idiomatic Rust with no design invention required.

The single most important architectural decision for this phase is embedding tokenization inside the per-file analysis worker. The Zig version separates tokenization (duplication pass reads files again), causing 800%+ overhead. The Rust port must avoid this: the per-file worker returns `(MetricResults, Vec<Token>)` in one pass. Duplication then runs sequentially over collected token sequences. The phase also requires a new, richer `FileAnalysisResult` type in `types.rs` that carries all metric fields.

**Primary recommendation:** Port metrics in dependency order (cyclomatic first, then structural, cognitive, Halstead, scoring, tokenization, duplication), write golden-output tests for each metric against the existing fixture files, and design `FileAnalysisResult` with all required fields before writing any metric code.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| METR-01 | Cyclomatic complexity matches Zig output for all fixture files | Zig algorithm fully read; DFS walk counting if/while/for/catch/ternary/switch/logical operators; exact node types documented below |
| METR-02 | Cognitive complexity matches Zig output (including per-operator counting deviation) | Zig algorithm fully read; critical deviation: each `&&`/`\|\|`/`??` counts as +1 flat individually; recursion detection; else-if chain handling documented |
| METR-03 | Halstead metrics match Zig output within float tolerance | Zig algorithm fully read; operator/operand classification as `&'static str` sets; ternary special-case; type-annotation skipping; exact formulas documented |
| METR-04 | Structural metrics (length, params, nesting, exports) match Zig output | Zig algorithm fully read; logical-line counting rules; param counting (runtime + generic type params); nesting constructs list documented |
| METR-05 | Duplication detection (Rabin-Karp, Type 1 & 2) matches Zig clone groups | Zig algorithm fully read; HASH_BASE=37; MAX_BUCKET_SIZE=1000; identifier normalization to "V"; min_window=25; token skipping rules documented |
| METR-06 | Composite health score (sigmoid normalization) matches Zig output within tolerance | Zig algorithm fully read; sigmoid formula, steepness derivation, weight normalization (4-metric vs 5-metric mode), file/project score aggregation documented |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `tree-sitter` | 0.26 (already in Cargo.toml) | AST traversal for all metric walkers | Already integrated in Phase 17; `Node::kind()`, `Node::child()`, `Node::child_count()` are the primary API |
| `rustc-hash` (`FxHashMap`) | 2.x | Hash maps for Halstead operator/operand counting and duplication hash index | 15-30% faster than `std::HashMap` for string/integer keys; `u64` keys in duplication hash index; string keys in Halstead |
| `serde` + `serde_json` | 1.x (add to Cargo.toml) | JSON output for golden-output test validation | Enables automated parity comparison with Zig binary output; already planned for Phase 19 outputs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `std::collections::HashMap` | std | General-purpose maps where hot-path performance is not critical | Anywhere outside Halstead distinct-count maps and duplication hash index |
| `f64` standard math | std | Halstead formulas, sigmoid scoring | `f64::ln()`, `f64::exp()`, `f64::log2()` all in std; no external crate needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `FxHashMap` for Halstead operator map | `std::HashMap` | std is safer against DoS but measurably slower for hot leaf-node counting; use FxHashMap |
| Hand-rolled Rabin-Karp | rolling-hash crate | No crate covers the exact Type 1/Type 2 sliding window pattern; hand-roll as in Zig |

**Installation:**
```bash
# Add to Cargo.toml [dependencies]:
rustc-hash = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

## Architecture Patterns

### Recommended Project Structure

New files to create in `rust/src/`:

```
rust/src/
├── lib.rs                   # add: pub mod metrics;
├── types.rs                 # EXTEND: add FileAnalysisResult with all metric fields
├── parser/mod.rs            # EXTEND: expose parse_source() returning (Tree, Vec<u8>)
├── metrics/
│   ├── mod.rs               # FileAnalysisResult assembly; analyze_file() entry point
│   ├── cyclomatic.rs        # countDecisionPoints(); analyzeFunctions() -> Vec<CyclomaticResult>
│   ├── cognitive.rs         # visitNode(); analyzeFunctions() -> Vec<CognitiveResult>
│   ├── halstead.rs          # classifyNode(); analyzeFunctions() -> Vec<HalsteadResult>
│   ├── structural.rs        # countLogicalLines(); analyzeFunctions() + analyzeFile()
│   ├── duplication.rs       # tokenizeTree(); detectDuplication()
│   └── scoring.rs           # sigmoidScore(); computeFunctionScore(); computeFileScore()
└── output/
    └── json.rs              # serde Serialize on result types (for test validation)
```

### Pattern 1: The Per-File Analysis Worker

**What:** A single function that takes a path, reads the file, parses it, runs all five metric families, tokenizes for duplication, and returns a fully-owned `FileAnalysisResult` containing all metric data plus the token sequence. This is the foundational design decision.

**When to use:** This is the only correct design. The alternative (separate passes) reproduces the Zig re-parse flaw.

**Example:**
```rust
pub fn analyze_file(path: &Path) -> Result<FileAnalysisResult, AnalysisError> {
    let language = select_language(path)?;
    let source = std::fs::read(path)?;

    let mut parser = tree_sitter::Parser::new();
    parser.set_language(&language).map_err(...)?;
    let tree = parser.parse(&source, None).ok_or(...)?;

    let root = tree.root_node();

    let cyclomatic_results = cyclomatic::analyze_functions(root, &source, &config.cyclomatic);
    let cognitive_results = cognitive::analyze_functions(root, &source, &config.cognitive);
    let halstead_results = halstead::analyze_functions(root, &source);
    let structural_fn_results = structural::analyze_functions(root, &source);
    let structural_file_result = structural::analyze_file(&source, root);
    let tokens = duplication::tokenize_tree(root, &source);

    // Merge per-function results by index (functions are discovered in the same order)
    let functions = merge_function_results(...);

    let function_scores: Vec<f64> = functions.iter()
        .map(|f| scoring::compute_function_score(f, &weights, &thresholds))
        .collect();
    let file_score = scoring::compute_file_score(&function_scores);

    Ok(FileAnalysisResult {
        path: path.to_path_buf(),
        functions,
        tokens,  // kept for duplication pass later
        file_score,
        structural: structural_file_result,
    })
}
```

### Pattern 2: isFunctionNode — The Scope Isolation Guard

**What:** Every metric walker stops recursion when it encounters a nested function node. The Zig code uses `isFunctionNode()` as a guard at the top of each recursive call. The Rust port must replicate this exactly.

**Node types that are function boundaries:**
```rust
fn is_function_node(kind: &str) -> bool {
    matches!(kind,
        "function_declaration" |
        "function" |
        "function_expression" |
        "arrow_function" |
        "method_definition" |
        "generator_function" |
        "generator_function_declaration"
    )
}
```

### Pattern 3: Tree Traversal via `TreeCursor`

**What:** The Phase 17 parser already uses `TreeCursor` for DFS traversal. The metric walkers use a simpler pattern: direct child indexing (`node.child(i)`) with a loop, because they need to process specific children differently (e.g., cognitive skips `else_clause` children of `if_statement` on the first pass). Either pattern is correct but the direct-child approach matches the Zig code more closely.

**Rust tree-sitter child access:**
```rust
// Zig: node.child(i)
// Rust equivalent:
let child = node.child(i);  // returns Option<Node>

// Zig: node.nodeType()
// Rust equivalent:
let kind = node.kind();  // returns &str

// Zig: node.startPoint().row + 1 (1-indexed line)
// Rust equivalent:
let start_line = node.start_position().row + 1;

// Zig: node.startByte() / node.endByte()
// Rust equivalent:
let start = node.start_byte();
let end = node.end_byte();
let text = &source[start..end];  // source is &[u8]

// For UTF-8 text:
let text = node.utf8_text(source)?;  // returns Result<&str, _>
```

### Pattern 4: FxHashMap for Halstead Token Classification

**What:** Halstead counting requires two sets of distinct tokens: operators (keyed by node type string, a `&'static str`) and operands (keyed by source text, a `&str` slice). The Zig version uses `std.StringHashMap(void)` for both.

**Rust equivalent:**
```rust
use rustc_hash::FxHashMap;

struct HalsteadContext<'src> {
    operators: FxHashMap<&'static str, ()>,  // node type = &'static str
    operands: FxHashMap<&'src str, ()>,       // source slice = &'src str
    n1_total: u32,
    n2_total: u32,
}
```

Key insight: operator keys are `&'static str` (node kind strings are static in tree-sitter), while operand keys are slices into the source bytes (`&'src str`). This avoids all allocation during counting.

### Pattern 5: Cognitive Complexity — The Per-Operator Deviation

**What:** ComplexityGuard's documented deviation from SonarSource: each `&&`, `||`, and `??` operator inside a `binary_expression` node counts as +1 flat (not grouped by same-operator sequences as SonarSource specifies). This is the single most dangerous source of parity failure.

**Exact implementation from Zig source:**
```rust
// In binary_expression handling:
for i in 0..node.child_count() {
    if let Some(child) = node.child(i) {
        match child.kind() {
            "&&" | "||" | "??" => {
                ctx.complexity += 1;  // flat +1, no nesting increment
            }
            _ => {
                visit_node(ctx, child, source);  // recurse into operands
            }
        }
    }
}
return;  // early return — children already handled
```

### Pattern 6: Rabin-Karp Rolling Hash — Exact Parameters

**What:** The duplication algorithm uses a specific Rabin-Karp implementation with exact constants from the Zig source. These must be replicated exactly.

**Constants and algorithm:**
```rust
const HASH_BASE: u64 = 37;
const MAX_BUCKET_SIZE: usize = 1000;
const DEFAULT_MIN_WINDOW: u32 = 25;

fn token_hash(kind: &str) -> u64 {
    let mut h: u64 = 0;
    for c in kind.bytes() {
        h = h.wrapping_mul(HASH_BASE).wrapping_add(c as u64);
    }
    h
}

struct RollingHasher {
    hash: u64,
    base_pow: u64,  // HASH_BASE^(window-1)
}

impl RollingHasher {
    fn new(tokens: &[Token], window: u32) -> Self {
        let mut h: u64 = 0;
        let mut bpow: u64 = 1;
        for i in 0..(window as usize) {
            h = h.wrapping_mul(HASH_BASE).wrapping_add(token_hash(&tokens[i].kind));
            if i < (window - 1) as usize {
                bpow = bpow.wrapping_mul(HASH_BASE);
            }
        }
        RollingHasher { hash: h, base_pow: bpow }
    }

    fn roll(&mut self, remove: &Token, add: &Token) {
        self.hash = (self.hash
            .wrapping_sub(token_hash(&remove.kind).wrapping_mul(self.base_pow)))
            .wrapping_mul(HASH_BASE)
            .wrapping_add(token_hash(&add.kind));
    }
}
```

### Pattern 7: Token Normalization for Type 2 Clones

**What:** Identifiers are normalized to the sentinel string `"V"` before hashing. This enables Type 2 clone detection (structurally identical but different identifiers). The exact set of node types that get normalized to `"V"`:

```rust
fn normalize_kind(kind: &str) -> &'static str {
    match kind {
        "identifier" |
        "property_identifier" |
        "shorthand_property_identifier" |
        "shorthand_property_identifier_pattern" => "V",
        other => other,  // WARNING: this returns a non-static str; see pitfall below
    }
}
```

**Important:** `Token.kind` must store a `String` or `Cow<'static, str>` because the normalization converts non-static identifiers to the static `"V"` but other tokens retain their node kind. The simplest approach: store `kind` as `String` in `Token`, paying one allocation per token. Acceptable given tokens are short-lived.

### Pattern 8: Sigmoid Scoring — Exact Formulas

**What:** The scoring formulas from Zig are direct math with no surprises:

```rust
pub fn sigmoid_score(x: f64, x0: f64, k: f64) -> f64 {
    100.0 / (1.0 + (k * (x - x0)).exp())
}

pub fn compute_steepness(warning: f64, error: f64) -> f64 {
    if error <= warning { return 1.0; }
    4_f64.ln() / (error - warning)
}

// File score: arithmetic mean of function scores
pub fn compute_file_score(function_scores: &[f64]) -> f64 {
    if function_scores.is_empty() { return 100.0; }
    function_scores.iter().sum::<f64>() / function_scores.len() as f64
}

// Project score: function-count-weighted average of file scores
pub fn compute_project_score(file_scores: &[f64], function_counts: &[u32]) -> f64 {
    let total_functions: u32 = function_counts.iter().sum();
    if total_functions == 0 { return 100.0; }
    let weighted_sum: f64 = file_scores.iter().zip(function_counts.iter())
        .map(|(s, c)| s * *c as f64)
        .sum();
    weighted_sum / total_functions as f64
}
```

**Default weights (when no config override):**
- cyclomatic: 0.20, cognitive: 0.30, halstead: 0.15, structural: 0.15, duplication: 0.20
- When duplication disabled: normalize 4 active weights to sum 1.0
- When all weights are zero: fall back to equal weights (0.25 each, or 0.2 each for 5-metric mode)

### Pattern 9: Logical Line Counting

**What:** The structural metric `function_length` counts "logical lines" — not raw lines. The Zig implementation skips blank lines, `//` comment lines, block comment interiors, and standalone brace-only lines (`{`, `}`, `};`, `},`).

```rust
pub fn count_logical_lines(source: &[u8], start_byte: usize, end_byte: usize) -> u32 {
    let text = &source[start_byte.min(source.len())..end_byte.min(source.len())];
    let text_str = std::str::from_utf8(text).unwrap_or("");
    let mut count = 0u32;
    let mut in_block_comment = false;

    for raw_line in text_str.split('\n') {
        let line = raw_line.trim_matches([' ', '\t', '\r'].as_ref());

        if in_block_comment {
            if let Some(close_idx) = line.find("*/") {
                in_block_comment = false;
                let after = line[close_idx + 2..].trim();
                if !after.is_empty() { count += 1; }
            }
            continue;
        }

        if line.is_empty() { continue; }
        if matches!(line, "{" | "}" | "};" | "},") { continue; }
        if line.starts_with("//") { continue; }
        if line.starts_with("/*") {
            if let Some(close_idx) = line[2..].find("*/") {
                let after = line[2 + close_idx + 2..].trim();
                if !after.is_empty() { count += 1; }
            } else {
                in_block_comment = true;
            }
            continue;
        }
        count += 1;
    }
    count
}
```

### Pattern 10: Parameter Counting (Runtime + Generic Type Params)

**What:** The Zig implementation counts both runtime parameters (`formal_parameters`) and TypeScript generic type parameters (`type_parameters`), excluding punctuation tokens.

```rust
const PUNCTUATION: &[&str] = &[",", "(", ")", "<", ">", ";"];

pub fn count_parameters(function_node: tree_sitter::Node) -> u32 {
    let mut count = 0u32;
    for i in 0..function_node.child_count() {
        if let Some(child) = function_node.child(i) {
            match child.kind() {
                "formal_parameters" | "type_parameters" => {
                    for j in 0..child.child_count() {
                        if let Some(param) = child.child(j) {
                            if !PUNCTUATION.contains(&param.kind()) {
                                count += 1;
                            }
                        }
                    }
                }
                _ => {}
            }
        }
    }
    count
}
```

### Anti-Patterns to Avoid

- **Separate tree passes per metric:** Do not make four separate DFS traversals. The Zig code has separate functions per metric but they each traverse the whole tree. In Rust, the correct approach is still separate functions (cleaner) but called once per file, all within the same analysis closure.
- **Retaining `Node` across function boundaries:** All metrics must extract data to owned types within the scope of the live `Tree`. Never return `Node`, never store `Node` in structs.
- **Recursive AST descent using Rust call stack for deep trees:** Generated/minified code can have thousands of nesting levels. Use an explicit `Vec<Node>` stack if stack overflow is detected in testing. For most real-world TypeScript, recursion is fine.
- **Using `String` keys in the Halstead operator map:** Operator keys are node kind strings, which are `&'static str` in tree-sitter. No allocation needed. Only operand values (source text) require `&'src str` or `String`.
- **Cloning `FileAnalysisResult` for the duplication pass:** The duplication pass should consume or borrow `Vec<Token>` from each result; do not clone the token sequences.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rabin-Karp rolling hash | Custom hash library | Hand-roll with exact Zig constants | No crate covers Type 1/2 clone detection pattern; algorithm is 50 lines |
| Interval merging for cloned-token counting | Segment tree | Simple sort-and-sweep (as in Zig) | O(n log n) is sufficient; the Zig version uses exactly this |
| Float formatting | Custom serializer | `serde_json` with tolerance in tests | Zig and Rust may differ in last float digit; test with epsilon comparison |

## Common Pitfalls

### Pitfall 1: Cognitive Complexity Deviation Not Replicated

**What goes wrong:** Tests produce cognitive scores that match SonarSource's published spec but not the Zig binary's output. Every test fails by a small amount.

**Why it happens:** ComplexityGuard counts each `&&`/`||`/`??` as +1 flat individually. SonarSource groups consecutive same-operator chains and counts them as +1. Most implementations (and LLM training data) follow SonarSource. Copying "standard" cognitive complexity implementations produces wrong output.

**How to avoid:** The `binary_expression` handler must iterate children, add +1 for each `&&`/`||`/`??` child, and recurse into non-operator children. Early return after handling. Test against the cognitive_cases.ts fixture vs Zig binary output.

**Warning signs:** Cognitive scores match SonarSource's online calculator but differ from `./complexity-guard` binary output.

### Pitfall 2: Re-Parse Overhead Reproduced

**What goes wrong:** `analyze_file()` computes metrics, returns a result, then `detect_duplication()` re-reads and re-parses each file.

**Why it happens:** Naively porting the Zig structure — where tokenization is a separate pipeline stage.

**How to avoid:** `analyze_file()` must call `duplication::tokenize_tree(root, &source)` before dropping `tree`, store `Vec<Token>` in `FileAnalysisResult`. The `detect_duplication()` function then takes `&[FileAnalysisResult]` and reads `result.tokens`, never touching the filesystem.

### Pitfall 3: Wrong Structural Metric — Arrow Functions Without Block Body

**What goes wrong:** Arrow functions like `const f = (x) => x * 2` report `function_length = 0` or an incorrect line count.

**Why it happens:** The Zig implementation special-cases expression-body arrow functions: if no `statement_block` child is found, `function_length = 1` (the expression body counts as one logical line).

**How to avoid:**
```rust
// Arrow function without statement_block: function_length = 1
let function_length = node.children(&mut node.walk())
    .find(|c| c.kind() == "statement_block")
    .map(|body| count_logical_lines(&source, body.start_byte(), body.end_byte()))
    .unwrap_or(1);  // expression body = 1 line
```

### Pitfall 4: Float Precision Mismatch in Halstead Metrics

**What goes wrong:** Halstead `volume`, `difficulty`, `effort`, `time`, `bugs` values differ from Zig output in the last digit or two.

**Why it happens:** Zig's `std.json.Stringify` and Rust's `serde_json` serialize `f64` differently. The formulas are identical but IEEE 754 rounding in different formatting paths produces different last digits.

**How to avoid:** All tests comparing Halstead float values must use epsilon tolerance (`assert!((actual - expected).abs() < 1e-6)`). Do not use byte-exact comparison for float fields.

### Pitfall 5: Switch Case Counting Mode

**What goes wrong:** Cyclomatic complexity for switch statements is off by one or by the case count.

**Why it happens:** Two modes: `classic` (counts each non-default `case` label as +1) vs `modified` (counts the entire switch as +1). Default is `classic`. The classic mode must check that the `switch_case` has a non-punctuation expression child (not a bare `default`).

**How to avoid:** In classic mode, iterate `switch_case` children, skip `"case"`, `":"`, and `"default"` nodes; if any other child exists, `count += 1`.

### Pitfall 6: Token `kind` Lifetime in Duplication

**What goes wrong:** Compiler error: cannot return `&str` with lifetime tied to `node.kind()` after the `Tree` is dropped.

**Why it happens:** `node.kind()` returns `&'tree str` — a reference into tree-sitter's static grammar strings. After `Tree` is dropped, those references are still valid (they point to static data), but the Rust compiler may not prove this.

**How to avoid:** Store token `kind` as `String` (owned) in the `Token` struct. `"V"` normalizations are cheaply allocated. Each token kind string is short (max ~30 chars). The total allocation for a typical file's tokens is negligible.

### Pitfall 7: Halstead Type-Only Node Skipping

**What goes wrong:** TypeScript files produce higher Halstead metrics than equivalent JavaScript because type annotation tokens are counted.

**Why it happens:** The Zig implementation skips entire subtrees when it encounters TypeScript type-only nodes: `type_annotation`, `type_identifier`, `generic_type`, `type_parameters`, `type_parameter`, `predefined_type`, `union_type`, `intersection_type`, `array_type`, `object_type`, `tuple_type`, `function_type`, `readonly_type`, `type_query`, `as_expression`, `satisfies_expression`, `interface_declaration`, `type_alias_declaration`. If any of these are not skipped, TypeScript files get inflated counts.

**How to avoid:** Create an `is_type_only_node(kind: &str) -> bool` function with all 18 node types listed above. Call it at the top of the `classify_node` recursion — if true, return immediately without descending.

### Pitfall 8: Function Name Extraction Requires Parent Context

**What goes wrong:** Arrow functions assigned to variables are reported as `<anonymous>` instead of their variable name.

**Why it happens:** Arrow function nodes do not contain their own name — it comes from the parent `variable_declarator`. The Zig code uses a `FunctionContext` struct that propagates naming information downward during the walk.

**How to avoid:** All metric walkers (cyclomatic, cognitive, halstead, structural) implement the same parent-context naming pattern:
- `variable_declarator` → extract identifier child as `name` in context
- `class_declaration` → extract class name; methods become `"ClassName.methodName"`
- `pair` → extract key as name for object literal methods
- `call_expression` → extract callee as `"X callback"` or `"event handler"`
- `export_statement` with `default` child → `"default export"`
- Pass context through `class_body` and `arguments` nodes unchanged

### Pitfall 9: Duplication Skipped Token Kinds

**What goes wrong:** Token sequences include comments, semicolons, commas, or hash-bang lines, causing false clone detections or token count mismatches with Zig.

**Why it happens:** The tokenizer must skip specific leaf node kinds.

**How to avoid:**
```rust
fn is_skipped_kind(kind: &str) -> bool {
    matches!(kind,
        "comment" | "line_comment" | "block_comment" |
        ";" | "," | "hash_bang_line"
    )
}
```

### Pitfall 10: Missing `FunctionContext` Propagation Through `class_body` and `arguments`

**What goes wrong:** Methods inside classes are unnamed (reported as `<anonymous>.methodName` instead of `ClassName.methodName`), and callback functions inside `addEventListener` are unnamed instead of `"click handler"`.

**Why it happens:** The Zig code explicitly passes the parent context through `class_body` (transparent container) and `arguments` (container for callbacks). Without this, the context is lost when traversal enters these nodes.

**How to avoid:** In the `walkAndAnalyze` function, when `node_type == "class_body"` or `"arguments"`, set `child_context = parent_context` before recursing.

## Code Examples

### Cyclomatic Decision Point Counter
```rust
// Source: src/metrics/cyclomatic.zig (direct read)
fn count_decision_points(node: tree_sitter::Node, source: &[u8], config: &CyclomaticConfig) -> u32 {
    if is_function_node(node.kind()) { return 0; }

    let mut count = 0u32;
    match node.kind() {
        "if_statement" | "while_statement" | "do_statement" |
        "for_statement" | "for_in_statement" | "catch_clause" => count += 1,
        "ternary_expression" if config.count_ternary => count += 1,
        "switch_statement" if config.switch_case_mode == SwitchCaseMode::Modified => count += 1,
        "switch_case" if config.switch_case_mode == SwitchCaseMode::Classic => {
            // Count only non-default cases (those with an expression child)
            let has_expression = (0..node.child_count())
                .filter_map(|i| node.child(i))
                .any(|c| !matches!(c.kind(), "case" | ":" | "default"));
            if has_expression { count += 1; }
        }
        "binary_expression" => {
            for i in 0..node.child_count() {
                if let Some(child) = node.child(i) {
                    match child.kind() {
                        "&&" | "||" if config.count_logical_operators => count += 1,
                        "??" if config.count_nullish_coalescing => count += 1,
                        _ => {}
                    }
                }
            }
        }
        "augmented_assignment_expression" => {
            for i in 0..node.child_count() {
                if let Some(child) = node.child(i) {
                    match child.kind() {
                        "&&=" | "||=" if config.count_logical_operators => count += 1,
                        _ => {}
                    }
                }
            }
        }
        "member_expression" | "call_expression" | "subscript_expression"
            if config.count_optional_chaining => {
            let has_optional = (0..node.child_count())
                .filter_map(|i| node.child(i))
                .any(|c| c.kind() == "?.");
            if has_optional { count += 1; }
        }
        _ => {}
    }

    // Recurse into children (stop at default params if configured)
    for i in 0..node.child_count() {
        if let Some(child) = node.child(i) {
            count += count_decision_points(child, source, config);
        }
    }
    count
}
```

### Halstead Operator/Operand Classification
```rust
// Source: src/metrics/halstead.zig (direct read)
fn is_operator_token(kind: &str) -> bool {
    matches!(kind,
        // Arithmetic
        "+" | "-" | "*" | "/" | "%" | "**" |
        // Comparison
        "==" | "!=" | "===" | "!==" | "<" | ">" | "<=" | ">=" |
        // Logical
        "&&" | "||" | "??" |
        // Assignment
        "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "**=" |
        "&&=" | "||=" | "??=" | "<<=" | ">>=" | ">>>=" | "&=" | "|=" | "^=" |
        // Bitwise
        "&" | "|" | "^" | "~" | "<<" | ">>" | ">>>" |
        // Unary keyword
        "typeof" | "void" | "delete" | "await" | "yield" |
        // Unary symbol
        "!" | "++" | "--" |
        // Control flow keywords
        "if" | "else" | "for" | "while" | "do" | "switch" | "case" | "default" |
        "break" | "continue" | "return" | "throw" | "try" | "catch" | "finally" |
        "new" | "in" | "of" | "instanceof" |
        // Punctuation-operators
        "," | "@"
    )
}

fn is_operand_token(kind: &str) -> bool {
    matches!(kind,
        "identifier" | "number" | "string" | "template_string" | "regex" |
        "true" | "false" | "null" | "undefined" | "this" | "property_identifier"
    )
}
```

### Validation Test Pattern (Golden Output)
```rust
// Pattern for parity tests against Zig binary output
#[test]
fn test_cyclomatic_cyclomatic_cases_ts() {
    let path = fixture_path("typescript/cyclomatic_cases.ts");
    let result = analyze_file(&path).expect("should analyze");

    // Values obtained by running: ./zig-out/bin/complexity-guard --format json tests/fixtures/...
    let simple = result.functions.iter().find(|f| f.name == "simpleFunction").unwrap();
    assert_eq!(simple.cyclomatic, 1);

    let complex = result.functions.iter().find(|f| f.name == "complexFunction").unwrap();
    assert_eq!(complex.cyclomatic, 7);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate tokenization pass for duplication | Tokenize during parse, store in FileAnalysisResult | This phase (design decision) | Eliminates 800%+ overhead; single I/O and parse per file |
| `std::HashMap` for all hash maps | `FxHashMap` for hot paths (Halstead, duplication) | Phase 18 | 15-30% faster for string/integer key lookups |
| `Option<T>` fields in intermediate types | Complete `FileAnalysisResult` with all metrics | Phase 18 design | Simplifies rayon parallel pipeline in Phase 20 |

## Open Questions

1. **Float tolerance for Halstead metrics in tests**
   - What we know: Zig and Rust `f64` formatting will differ in last digits for formulas like `volume = N * log2(n)`
   - What's unclear: Exact epsilon needed — 1e-6 is standard but actual divergence not yet measured
   - Recommendation: Use `(actual - expected).abs() < 1e-6` in tests; tighten if empirical testing shows it is too loose

2. **Stack overflow risk for deeply nested generated code**
   - What we know: The Zig metric walkers use recursive AST descent; Rust has a default stack size of ~8MB
   - What's unclear: Maximum safe nesting depth for Rust recursive DFS
   - Recommendation: Start with recursive implementation for code clarity; if tests on minified/generated fixtures cause overflow, convert to explicit stack (`Vec<(Node, Context)>`)

3. **Merge order of per-function results across metrics**
   - What we know: All five metric walkers discover functions in DFS order (same tree traversal order)
   - What's unclear: Whether the order is guaranteed identical when each walker does its own DFS
   - Recommendation: Since all walkers start at root and use the same DFS order, function indices align. Verify with an assertion that all result vecs have the same length before merging.

4. **`FunctionNameContext` sharing across metric modules**
   - What we know: All four per-function walkers (cyclomatic, cognitive, halstead, structural) implement the same naming context logic — identical 200-line blocks in each Zig module
   - What's unclear: Best factoring in Rust — shared module vs. duplicate per metric
   - Recommendation: Extract naming context into `metrics/mod.rs` as a shared `FunctionNameContext` struct and `walk_with_naming()` helper; avoid duplicating 200 lines across four files

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Rust built-in (`cargo test`) |
| Config file | `rust/Cargo.toml` (existing) |
| Quick run command | `cargo test --manifest-path rust/Cargo.toml -q` |
| Full suite command | `cargo test --manifest-path rust/Cargo.toml` |
| Estimated runtime | ~5-15 seconds (builds metric code + runs tests) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| METR-01 | Cyclomatic scores match Zig for all fixture files | unit + integration | `cargo test --manifest-path rust/Cargo.toml metrics::cyclomatic` | No — Wave 0 gap |
| METR-02 | Cognitive scores match Zig (per-operator deviation) | unit + integration | `cargo test --manifest-path rust/Cargo.toml metrics::cognitive` | No — Wave 0 gap |
| METR-03 | Halstead scores match Zig within float tolerance | unit + integration | `cargo test --manifest-path rust/Cargo.toml metrics::halstead` | No — Wave 0 gap |
| METR-04 | Structural metrics match Zig (length, params, nesting, exports) | unit + integration | `cargo test --manifest-path rust/Cargo.toml metrics::structural` | No — Wave 0 gap |
| METR-05 | Duplication clone groups match Zig (Rabin-Karp, Type 1/2) | unit + integration | `cargo test --manifest-path rust/Cargo.toml metrics::duplication` | No — Wave 0 gap |
| METR-06 | Health score matches Zig within float tolerance | unit | `cargo test --manifest-path rust/Cargo.toml metrics::scoring` | No — Wave 0 gap |

### Nyquist Sampling Rate
- **Minimum sample interval:** After every committed task → run: `cargo test --manifest-path rust/Cargo.toml -q`
- **Full suite trigger:** Before merging final task of any plan wave
- **Phase-complete gate:** Full suite green + all six metrics validate against Zig binary output
- **Estimated feedback latency per task:** ~10 seconds (incremental build + test run)

### Wave 0 Gaps (must be created before implementation)

- [ ] `rust/src/metrics/mod.rs` — module declaration + `FileAnalysisResult` type + `analyze_file()` entry point
- [ ] `rust/src/metrics/cyclomatic.rs` — covers METR-01
- [ ] `rust/src/metrics/cognitive.rs` — covers METR-02
- [ ] `rust/src/metrics/halstead.rs` — covers METR-03
- [ ] `rust/src/metrics/structural.rs` — covers METR-04
- [ ] `rust/src/metrics/duplication.rs` — covers METR-05
- [ ] `rust/src/metrics/scoring.rs` — covers METR-06
- [ ] `rust/src/output/json.rs` — serde Serialize on result types for golden-output comparison
- [ ] `rust/tests/metrics_tests.rs` — integration tests using fixture files

## Sources

### Primary (HIGH confidence)
- `/Users/benvds/code/complexity-guard/src/metrics/cyclomatic.zig` — direct source read; cyclomatic algorithm, isFunctionNode(), extractFunctionInfo(), countDecisionPoints(), all node types counted
- `/Users/benvds/code/complexity-guard/src/metrics/cognitive.zig` — direct source read; visitNode(), visitElseClause(), visitIfAsContinuation(), visitArrowCallback(), per-operator deviation documented
- `/Users/benvds/code/complexity-guard/src/metrics/halstead.zig` — direct source read; isTypeOnlyNode() (18 types), isOperatorToken() (42 tokens), isOperandToken() (11 tokens), computeHalsteadMetrics() formulas
- `/Users/benvds/code/complexity-guard/src/metrics/structural.zig` — direct source read; countLogicalLines() algorithm, countParameters() (formal + generic), isNestingConstruct() (7 types), countExports()
- `/Users/benvds/code/complexity-guard/src/metrics/duplication.zig` — direct source read; HASH_BASE=37, MAX_BUCKET_SIZE=1000, normalizeKind() to "V", isSkippedKind(), tokenHash(), RollingHasher, buildHashIndex(), formCloneGroups(), countMergedClonedTokens()
- `/Users/benvds/code/complexity-guard/src/metrics/scoring.zig` — direct source read; sigmoidScore(), computeSteepness(), resolveEffectiveWeights(), computeFunctionScore(), computeFileScore(), computeProjectScore()
- `/Users/benvds/code/complexity-guard/rust/src/types.rs` — Phase 17 types; `FunctionInfo`, `ParseResult` exist; `FileAnalysisResult` does not yet exist
- `/Users/benvds/code/complexity-guard/rust/src/parser/mod.rs` — Phase 17 parser; `parse_file()` and `select_language()` exist; needs extension to expose tree/source for metrics
- `/Users/benvds/code/complexity-guard/rust/Cargo.toml` — current dependencies; `rustc-hash`, `serde`, `serde_json` not yet added
- `.planning/REQUIREMENTS.md` — METR-01 through METR-06 requirements confirmed
- `.planning/research/SUMMARY.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md` — confirmed standard stack, architectural patterns, and pitfall list

### Secondary (MEDIUM confidence)
- [docs.rs/tree-sitter 0.26](https://docs.rs/tree-sitter/latest/tree_sitter/) — Node API: `kind()`, `child()`, `child_count()`, `start_position()`, `start_byte()`, `utf8_text()`
- [docs.rs/rustc-hash](https://docs.rs/rustc-hash/latest/rustc_hash/) — `FxHashMap` as drop-in for `HashMap`

## Metadata

**Confidence breakdown:**
- Algorithms: HIGH — Zig source read in full; all five algorithms documented with exact node types, constants, and formulas
- Architecture: HIGH — Per-file worker pattern is clear; FileAnalysisResult design is straightforward
- Pitfalls: HIGH — 10 specific pitfalls identified from direct Zig source inspection + prior research

**Research date:** 2026-02-24
**Valid until:** 2026-04-24 (stable algorithms; only tree-sitter API changes would affect this)
