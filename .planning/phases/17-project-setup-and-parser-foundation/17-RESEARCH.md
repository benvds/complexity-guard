# Phase 17: Project Setup and Parser Foundation - Research

**Researched:** 2026-02-24
**Domain:** Rust project scaffolding, tree-sitter Rust bindings, grammar version pinning, binary size configuration
**Confidence:** HIGH

## Summary

Phase 17 is the foundation for the entire Rust rewrite. Every subsequent phase depends on the decisions made here: the Cargo.toml dependency graph (grammar versions), the `ParseResult` type (must own only pure Rust data), and the release profile (binary size). All three of the most dangerous pitfalls for this project must be addressed in this phase or they compound through all later phases.

The good news: this is a well-researched domain with no unknowns. The tree-sitter Rust crates (0.26.5 + tree-sitter-typescript 0.23.2 + tree-sitter-javascript 0.25.0) are confirmed compatible and the grammar version mismatch risk is partially mitigated by the new `tree-sitter-language` 0.1.7 stable ABI shim — grammar crates now depend on this shim rather than directly on `tree-sitter` core, reducing (but not eliminating) version conflicts. The release profile configuration is a known recipe (`opt-level = "z"`, `lto = true`, `panic = "abort"`, `strip = true`). The `ParseResult` type design is a direct application of the Node lifetime constraint: never store `Node`, always extract into owned Rust types before returning.

The most important architecture decision in this phase is creating a Rust crate that lives alongside the existing Zig source — the Rust code does not replace the Zig code yet. The planner should consider whether the Rust crate lives at the repo root (replacing `build.zig` as primary) or in a subdirectory (e.g., `rust/`). Given that the Zig binary is shipped v1.0 and the Rust rewrite is v0.8, the subdirectory approach allows both to coexist without disrupting existing Zig builds, docs, and CI.

**Primary recommendation:** Scaffold the Rust crate in a `rust/` subdirectory. Add all four grammar crates, run `cargo tree -d` to confirm zero duplicate tree-sitter versions, add the size-optimized release profile, define the `ParseResult` type as fully owned, verify all four languages parse fixture files, measure baseline binary size, and add at least one cross-compilation CI step to a musl target.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PARSE-01 | Binary parses TypeScript files using tree-sitter-typescript | `LANGUAGE_TYPESCRIPT` constant from tree-sitter-typescript 0.23.2; `parser.set_language()` + `parser.parse()` pattern |
| PARSE-02 | Binary parses TSX files using tree-sitter-typescript | `LANGUAGE_TSX` constant from the same tree-sitter-typescript crate (one crate, both TS and TSX grammars) |
| PARSE-03 | Binary parses JavaScript files using tree-sitter-javascript | `LANGUAGE` constant from tree-sitter-javascript 0.25.0 |
| PARSE-04 | Binary parses JSX files using tree-sitter-javascript | Same `LANGUAGE` constant; JSX is included in the JS grammar |
| PARSE-05 | Parser extracts function declarations with name, line, and column | `Node::kind()`, `Node::start_point()`, `Node::utf8_text()` on matched function nodes; results extracted into owned `ParseResult` type |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tree-sitter | 0.26.5 | Rust bindings to the C tree-sitter library | Official crate maintained by tree-sitter org; `Parser` is `Send + Sync`; same C library behavior as Zig version |
| tree-sitter-typescript | 0.23.2 | TypeScript + TSX grammars | One crate provides both `LANGUAGE_TYPESCRIPT` and `LANGUAGE_TSX` constants |
| tree-sitter-javascript | 0.25.0 | JavaScript + JSX grammars | `LANGUAGE` constant; JSX parsing included |
| tree-sitter-language | 0.1.7 | Stable ABI shim for grammar crates | Grammar crates depend on this instead of directly on tree-sitter core, reducing version mismatch scope |
| Rust stable 1.80+ | 1.80+ | Implementation language | Required minimum for rayon 1.11 (later phases); no nightly needed |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| thiserror | 2.x | Typed error definitions | Define `ParseError` in this phase; all later phases extend it |
| anyhow | 1.x | Error propagation in main | Wrap all errors at the `main` entry point |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tree-sitter 0.26.x official crate | oxc_parser or swc_ecma_parser | Both expose their own AST (not tree-sitter node kinds); existing metric traversal logic is written for tree-sitter node kinds — switching parsers would require rewriting all metric traversal code |
| tree-sitter-language shim | Direct tree-sitter version pinning | The shim is the modern approach; direct pinning still works but is more fragile between major releases |

**Installation (initial Cargo.toml — Phase 17 only):**
```toml
[package]
name = "complexity-guard"
version = "0.8.0"
edition = "2021"
rust-version = "1.80"

[dependencies]
# Parsing
tree-sitter = "0.26"
tree-sitter-typescript = "0.23"
tree-sitter-javascript = "0.25"

# Error handling (establish now; all later phases extend this)
thiserror = "2"
anyhow = "1"

[profile.release]
opt-level = "z"        # size-first (mirrors Zig's ReleaseSmall)
lto = true             # link-time optimization removes dead code across crates
codegen-units = 1      # maximize LTO effectiveness (single unit)
strip = true           # strip debug symbols and symbol table
panic = "abort"        # removes unwind tables (~15-20% size reduction for release)
```

## Architecture Patterns

### Recommended Project Structure

```
rust/                           # Rust crate lives alongside Zig source
├── Cargo.toml                  # single-crate manifest for now (workspace later)
├── Cargo.lock                  # committed to repo
├── src/
│   ├── main.rs                 # entry point — minimal for Phase 17
│   ├── types.rs                # ParseResult, FunctionInfo, ParseError
│   └── parser/
│       └── mod.rs              # select_language(), parse_file() -> ParseResult
└── tests/
    └── parser_tests.rs         # integration tests: parse all four fixture types
```

The `rust/` subdirectory keeps the Rust crate isolated from the existing Zig build system (`build.zig`, `build.zig.zon`). The fixtures at `tests/fixtures/` can be referenced from the Rust tests using relative paths (`../../tests/fixtures/`).

### Pattern 1: Language Selection by File Extension

**What:** Map file extensions to grammar language constants. Return an error for unsupported extensions rather than panicking.

**When to use:** At the start of every parse operation, before `Parser::new()` is called.

**Example:**
```rust
// Source: docs.rs/tree-sitter-typescript 0.23.2, docs.rs/tree-sitter-javascript 0.25.0

use tree_sitter::Language;

pub fn select_language(path: &std::path::Path) -> Result<Language, ParseError> {
    match path.extension().and_then(|e| e.to_str()) {
        Some("ts") => Ok(tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()),
        Some("tsx") => Ok(tree_sitter_typescript::LANGUAGE_TSX.into()),
        Some("js") => Ok(tree_sitter_javascript::LANGUAGE.into()),
        Some("jsx") => Ok(tree_sitter_javascript::LANGUAGE.into()),
        Some(ext) => Err(ParseError::UnsupportedExtension(ext.to_string())),
        None => Err(ParseError::NoExtension),
    }
}
```

### Pattern 2: ParseResult With Only Owned Data

**What:** Extract all needed information from `tree_sitter::Node` within the scope that owns the `Tree`. Return a pure Rust struct with no references to tree-sitter internals.

**When to use:** Always. `Node` is not `Send` and cannot outlive `Tree`. The only correct pattern for the parallel pipeline (Phase 20) is to extract into owned types before returning.

**Example:**
```rust
// Source: docs.rs/tree-sitter 0.26.5

#[derive(Debug, Clone)]
pub struct FunctionInfo {
    pub name: String,           // owned — extracted from Node::utf8_text()
    pub start_line: usize,      // 1-indexed (row + 1)
    pub start_column: usize,    // 0-indexed (column as-is)
    pub end_line: usize,
}

#[derive(Debug, Clone)]
pub struct ParseResult {
    pub path: std::path::PathBuf,  // owned
    pub functions: Vec<FunctionInfo>,  // owned Vec of owned structs
    pub source_len: usize,
    pub error: bool,               // true if tree has parse errors
}

pub fn parse_file(path: &std::path::Path) -> Result<ParseResult, ParseError> {
    let source = std::fs::read(path)?;
    let language = select_language(path)?;
    let mut parser = tree_sitter::Parser::new();
    parser.set_language(&language).map_err(ParseError::LanguageError)?;
    let tree = parser.parse(&source, None).ok_or(ParseError::ParseFailed)?;

    // Extract all data from nodes BEFORE tree is dropped
    let functions = extract_functions(tree.root_node(), &source)?;
    let has_error = tree.root_node().has_error();

    // tree and source are dropped here — safe because ParseResult owns only Strings/usize
    Ok(ParseResult {
        path: path.to_path_buf(),
        functions,
        source_len: source.len(),
        error: has_error,
    })
}
```

### Pattern 3: Function Node Extraction

**What:** Walk the CST to find function declaration nodes, extract name, start line, and start column. The node kinds for TypeScript/JavaScript function declarations are: `function_declaration`, `arrow_function`, `method_definition`.

**When to use:** In `extract_functions()` called within the same scope as `Tree`.

**Example:**
```rust
// Patterns confirmed against Zig source (src/parser/parse.zig) and tree-sitter docs

fn extract_functions(
    root: tree_sitter::Node,
    source: &[u8],
) -> Result<Vec<FunctionInfo>, ParseError> {
    let mut functions = Vec::new();
    let mut cursor = root.walk();

    // DFS traversal using cursor
    traverse(&mut cursor, source, &mut functions);
    Ok(functions)
}

fn traverse(
    cursor: &mut tree_sitter::TreeCursor,
    source: &[u8],
    functions: &mut Vec<FunctionInfo>,
) {
    loop {
        let node = cursor.node();

        if matches!(node.kind(), "function_declaration" | "method_definition") {
            if let Some(name_node) = node.child_by_field_name("name") {
                if let Ok(name) = name_node.utf8_text(source) {
                    functions.push(FunctionInfo {
                        name: name.to_string(),
                        start_line: node.start_position().row + 1,  // 1-indexed
                        start_column: node.start_position().column, // 0-indexed
                        end_line: node.end_position().row + 1,
                    });
                }
            }
        }

        // Descend, advance sibling, or retreat
        if cursor.goto_first_child() { continue; }
        if cursor.goto_next_sibling() { continue; }
        loop {
            if !cursor.goto_parent() { return; }
            if cursor.goto_next_sibling() { break; }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Storing `Node` in a struct:** `Node` borrows from `Tree` and is not `Send`. Any attempt to store a node in a struct that outlives the function will fail to compile. Extract data immediately.
- **Sharing one `Parser` across threads:** Parser requires `&mut self` for `parse()`. Create a new `Parser` per rayon task in Phase 20; for Phase 17, one per `parse_file()` call is correct.
- **Using `parse_with` callbacks:** Avoid callback-based parsing to prevent panic-across-FFI UB. Use `parser.parse(&source, None)` with an in-memory `&[u8]` slice.
- **Skipping `cargo tree -d` after adding grammar crates:** Run it immediately after adding dependencies; grammar version mismatches appear here and are confusing to diagnose later.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TypeScript/TSX parsing | Custom parser or regex | tree-sitter-typescript 0.23.2 | Handles all TS syntax including template literals, generics, decorators, JSX in TSX |
| JavaScript/JSX parsing | Custom parser or regex | tree-sitter-javascript 0.25.0 | Handles ES2023+, JSX, optional chaining, nullish coalescing |
| Binary size reduction | Manual strip scripts | `[profile.release]` with `opt-level="z"`, `lto`, `strip` | Cargo handles all of this; manual stripping can corrupt macOS codesigned binaries |
| Grammar C compilation | Writing build.rs from scratch | Depend on grammar crates — they include precompiled C sources | Grammar crates include their own build.rs and vendor their C sources; no custom build.rs needed for basic grammar use |

**Key insight:** The tree-sitter-typescript and tree-sitter-javascript crates vendor their own C source files and include a `build.rs` that compiles them. A custom `build.rs` is NOT needed for Phase 17 when using these crates as Cargo dependencies.

## Common Pitfalls

### Pitfall 1: Grammar Version Mismatch ("expected Language, found a different Language")

**What goes wrong:** If the grammar crates resolve to a different `tree-sitter` version than the one in your `Cargo.toml`, Cargo compiles both. The `Language` type from version `0.24.x` and `Language` from `0.26.x` are distinct Rust types despite identical names. `parser.set_language()` fails to compile with a confusing duplicate-type error.

**Why it happens:** Grammar crates each declare their own `tree-sitter` dependency (or `tree-sitter-language` shim). Version mismatch occurs when the crate's pinned version differs from yours.

**How to avoid:** Run `cargo tree -d` immediately after adding grammar dependencies. If duplicates appear, use `[patch.crates-io]` or explicit version bounds to align. Modern grammar crates (tree-sitter-typescript 0.23.x, tree-sitter-javascript 0.25.x) use the `tree-sitter-language` shim which reduces (but does not eliminate) this risk.

**Warning signs:** Compile error containing "expected `tree_sitter::Language`, found a different `tree_sitter::Language`"; `cargo tree -d` shows two `tree-sitter` versions.

### Pitfall 2: Node Lifetime Prevents Cross-Scope Use

**What goes wrong:** Attempting to return `Node` from `parse_file()` or store it in any struct that lives beyond the current function scope triggers lifetime compile errors. `Node<'_>` borrows from `Tree`, and `Tree` borrows from the source `&[u8]`.

**Why it happens:** This is the Rust borrow checker enforcing tree-sitter's ownership model correctly. In Zig, the underlying `TSNode` struct is copied by value, masking this relationship.

**How to avoid:** Never return `Node` from functions. Design `ParseResult` to contain only owned data (`String`, `usize`, `Vec<T>`) extracted within the same scope that owns `Tree`. This is non-negotiable — the borrow checker enforces it.

**Warning signs:** Compile error "does not live long enough" when trying to store or return a `Node` value.

### Pitfall 3: Binary Size Without Size Profile

**What goes wrong:** A default `cargo build --release` with three grammar crates and serde produces 15–25 MB binaries. Without the size-optimized profile set up in Phase 17, every subsequent phase adds code that inflates the binary further, and the problem is harder to diagnose later.

**Why it happens:** Default `release` profile uses `opt-level = 3` (speed), `codegen-units = 16` (parallelism), and no stripping. Each grammar crate statically links C objects.

**How to avoid:** Add the `[profile.release]` configuration from the Standard Stack section to `Cargo.toml` in the first commit of Phase 17. Measure binary size at the end of the phase and record it as the v0.8 baseline. Do not assume the 5 MB target is achievable without measurement.

**Warning signs:** `cargo build --release` produces a binary over 10 MB; `cargo bloat --release` shows `serde` or formatting as top contributors.

### Pitfall 4: build.rs Is Not Needed for Grammar Crates

**What goes wrong:** Some tutorials show writing a custom `build.rs` using `cc::Build` to compile tree-sitter grammar C sources. This is the pattern for embedding grammars NOT available as crates. Using this pattern with the official grammar crates creates duplicate C compilation and can cause linker errors.

**Why it happens:** Older tree-sitter integration guides predate the official grammar crates. The `rfdonnelly.github.io` blog post in the research sources is this older pattern.

**How to avoid:** Simply add `tree-sitter-typescript` and `tree-sitter-javascript` as Cargo dependencies. They include their own `build.rs` and C sources. Do not write a custom `build.rs`.

**Warning signs:** Linker errors about duplicate symbols when building; `build.rs` touching the same C files that grammar crates compile.

### Pitfall 5: Workspace Root vs. Subdirectory Placement

**What goes wrong:** Placing `Cargo.toml` at the repo root conflicts with the existing `build.zig` workflow. The Zig build system expects to be the primary build tool for the current codebase. CI and docs reference the Zig binary. Replacing the root build with Cargo disrupts in-progress work.

**Why it happens:** The temptation to start fresh at the repo root, but the Zig v1.0 binary is still the shipped product.

**How to avoid:** Create the Rust crate in a `rust/` subdirectory. Reference existing fixtures with `../../tests/fixtures/` in tests. Add `.gitignore` entries for `rust/target/`. Update CI to run `cargo build --release` in the `rust/` directory specifically.

## Code Examples

Verified patterns from official sources and Zig source inspection:

### Setting Up the Parser and Parsing a File

```rust
// Source: docs.rs/tree-sitter 0.26.5

fn parse_typescript_file(path: &Path) -> Option<tree_sitter::Tree> {
    let source = std::fs::read(path).ok()?;
    let mut parser = tree_sitter::Parser::new();
    parser.set_language(&tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()).ok()?;
    parser.parse(&source, None)
}
```

### Checking Grammar Version Alignment

```bash
# Run immediately after adding grammar crates to Cargo.toml
cargo tree -d

# Expected: no output (no duplicates)
# Problem output would show: tree-sitter v0.24.x AND tree-sitter v0.26.x
```

### Measuring Binary Size

```bash
# Build with size-optimized profile
cargo build --release

# Measure (macOS/Linux)
ls -lh target/release/complexity-guard

# For Linux static binary (cross-compile to musl):
cargo zigbuild --target x86_64-unknown-linux-musl --release
ls -lh target/x86_64-unknown-linux-musl/release/complexity-guard
```

### Writing a Parser Integration Test

```rust
// tests/parser_tests.rs

#[test]
fn test_parse_typescript_fixture() {
    let fixture = Path::new("../../tests/fixtures/typescript/simple_function.ts");
    let result = parse_file(fixture).expect("parse should succeed");
    assert!(!result.error, "fixture should parse without errors");
    assert!(!result.functions.is_empty(), "should find at least one function");
    // Verify name, line, column are extracted
    let f = &result.functions[0];
    assert!(!f.name.is_empty());
    assert!(f.start_line >= 1);
}

#[test]
fn test_parse_tsx_fixture() {
    let fixture = Path::new("../../tests/fixtures/typescript/react_component.tsx");
    let result = parse_file(fixture).expect("TSX parse should succeed");
    assert!(!result.error);
}

#[test]
fn test_parse_jsx_fixture() {
    let fixture = Path::new("../../tests/fixtures/javascript/jsx_component.jsx");
    let result = parse_file(fixture).expect("JSX parse should succeed");
    assert!(!result.error);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Grammar crates depend directly on `tree-sitter` core | Grammar crates depend on `tree-sitter-language` stable ABI shim | tree-sitter ~0.22+ | Reduces (not eliminates) version mismatch; `cargo tree -d` check still required |
| Custom `build.rs` with `cc::Build` to compile grammar C | Grammar crates bundle their own `build.rs` and C sources | ~2022 | No custom `build.rs` needed for official grammar crates |
| `parser.set_language(language())` function call | `parser.set_language(&LANGUAGE_TYPESCRIPT.into())` with LanguageFn constant | 0.23.x era | Constants replace function calls; `LANGUAGE_TYPESCRIPT` is the current API |

**Deprecated/outdated:**
- `tree_sitter_typescript::language()` function: replaced by `tree_sitter_typescript::LANGUAGE_TYPESCRIPT` constant (LanguageFn type). Use `.into()` to convert to `Language`.
- `parse_with` callback-based parsing: still supported but introduces panic-across-FFI risk. Use `parse(&source, None)` for file parsing.

## Open Questions

1. **Crate placement: repo root vs. `rust/` subdirectory**
   - What we know: Zig build system is at repo root; Rust rewrite is v0.8 in progress; CI currently runs Zig tests
   - What's unclear: Whether the planner should create a Cargo workspace that spans the repo root (replacing Zig as primary) or isolate in `rust/`
   - Recommendation: Use `rust/` subdirectory to keep Zig v1.0 production binary untouched until Rust binary achieves parity (Phase 21)

2. **Binary size baseline expectation**
   - What we know: Zig achieves 3.6–3.8 MB with ReleaseSmall; Rust realistic estimate is 5–8 MB after optimization; the 5 MB target from the project constraint may not be achievable
   - What's unclear: Actual measurement for this specific dependency set (three grammar crates, no serde yet in Phase 17)
   - Recommendation: Measure at end of Phase 17 and document the actual number as the v0.8 baseline; do not block the phase on hitting 5 MB — that measurement informs the Phase 22 constraint

3. **CI cross-compilation in Phase 17 vs. Phase 22**
   - What we know: Phase 17 success criterion requires "at least one cross-compilation target builds successfully in CI"; Phase 22 is the dedicated cross-compilation phase
   - What's unclear: How much CI configuration to add in Phase 17 (minimal smoke test vs. full matrix)
   - Recommendation: In Phase 17, add a single CI job that cross-compiles to `x86_64-unknown-linux-musl` using cargo-zigbuild — this validates build.rs behavior and confirms grammar crate C compilation works cross-platform without setting up the full release matrix

## Sources

### Primary (HIGH confidence)
- [docs.rs/tree-sitter 0.26.5](https://docs.rs/tree-sitter/latest/tree_sitter/) — Parser API, Node lifetime constraints, Send + Sync
- [docs.rs/tree-sitter-typescript 0.23.2](https://docs.rs/tree-sitter-typescript/latest/tree_sitter_typescript/) — LANGUAGE_TYPESCRIPT and LANGUAGE_TSX constants confirmed current
- [docs.rs/tree-sitter-javascript 0.25.0](https://docs.rs/tree-sitter-javascript/latest/tree_sitter_javascript/) — LANGUAGE constant confirmed current
- [docs.rs/tree-sitter-language 0.1.7](https://docs.rs/tree-sitter-language/latest/tree_sitter_language/) — LanguageFn stable ABI shim, reduces version mismatch scope
- [github.com/johnthagen/min-sized-rust](https://github.com/johnthagen/min-sized-rust) — opt-level=z, LTO, strip, panic=abort techniques
- [github.com/tree-sitter/tree-sitter#3095](https://github.com/tree-sitter/tree-sitter/issues/3095) — Grammar version mismatch documented
- ComplexityGuard Zig source (`src/parser/parse.zig`, `src/parser/tree_sitter.zig`) — node traversal patterns, function extraction logic (direct inspection)

### Secondary (MEDIUM confidence)
- [.planning/research/SUMMARY.md](../../research/SUMMARY.md) — Comprehensive project research, Phase 17 rationale
- [.planning/research/STACK.md](../../research/STACK.md) — Crate versions, Cargo.toml patterns, size estimates
- [.planning/research/PITFALLS.md](../../research/PITFALLS.md) — 11 pitfalls with prevention strategies and phase mapping
- [.planning/research/ARCHITECTURE.md](../../research/ARCHITECTURE.md) — Project structure, data flow, build order

### Tertiary (LOW confidence)
- None — all findings in this research are supported by primary or secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all crate versions verified via docs.rs
- Architecture: HIGH — patterns derived from Zig source (direct inspection) and tree-sitter Rust API docs
- Pitfalls: HIGH — grammar version mismatch verified against tree-sitter issue tracker; Node lifetime is a Rust language-level constraint; binary size is empirically documented

**Research date:** 2026-02-24
**Valid until:** 2026-04-24 (stable ecosystem; tree-sitter grammar crates on stable release cadence)
