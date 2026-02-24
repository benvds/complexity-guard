# Feature Research

**Domain:** Rust rewrite of ComplexityGuard (Zig → Rust) — 1:1 feature parity port
**Researched:** 2026-02-24
**Confidence:** HIGH (verified against current crates.io, docs.rs, and official documentation)

## Context

This document focuses exclusively on how ComplexityGuard's already-shipped feature set maps to Rust idioms and the Rust crate ecosystem. Every feature listed is already built in Zig; the question is "how do we port it idiomatically to Rust?"

The frame is not "what to build" but "how each feature behaves differently in Rust, what crates replace hand-rolled Zig code, and where Rust introduces new risks or opportunities."

---

## Feature Landscape

### Table Stakes (Must Exist for 1:1 Parity)

Features that the Rust binary must match exactly. Users of the Zig binary will compare behavior directly.

| Feature | Rust Crate(s) | Zig Equivalent | Port Complexity | Notes |
|---------|---------------|----------------|-----------------|-------|
| Tree-sitter TS/TSX/JS/JSX parsing | `tree-sitter` 0.26.x + `tree-sitter-typescript` 0.23.x + `tree-sitter-javascript` 0.25.x | Vendor-compiled C grammars via `build.zig` | LOW | Direct C FFI bindings exist; same grammar C source. Version pinning is critical — tree-sitter has broken semver repeatedly between minor versions. |
| Cyclomatic complexity (McCabe) | None — hand-rolled AST traversal | `src/metrics/cyclomatic.zig` | LOW | Pure tree-sitter node-counting logic; ports cleanly to recursive Rust functions using `Node::child_count()` and `Node::kind()`. |
| Cognitive complexity (SonarSource-style) | None — hand-rolled AST traversal | `src/metrics/cognitive.zig` | MEDIUM | Nesting level tracking maps to a `u32` counter passed through recursive calls; Rust's explicit ownership makes the context struct cleaner than Zig. |
| Halstead metrics | None — hand-rolled | `src/metrics/halstead.zig` | LOW | Operator/operand counting uses `HashMap<&str, u32>` for distinct counts; Rust's standard collections are a direct replacement. Use `FxHashMap` from `rustc-hash` for 15-30% speedup on string keys. |
| Structural metrics (length, params, nesting, exports) | None — hand-rolled | `src/metrics/structural.zig` | LOW | Simple node traversal counters; most straightforward port. |
| Duplication detection (Rabin-Karp, Type 1 & 2) | None — hand-rolled rolling hash | `src/metrics/duplication.zig` | MEDIUM | Rolling hash algorithm is language-agnostic; Rust's iterator chaining makes the sliding-window cleaner. No crate covers this use case well enough to use. The re-parse architecture flaw (800%+ overhead) should be fixed in the Rust port — deduplicate tokenization with the Halstead pass. |
| Composite health score (sigmoid normalization) | None — pure math | `src/metrics/scoring.zig` | LOW | `f64` math; `f64::exp()` and `f64::ln()` are in std. Direct 1:1 translation. |
| Console output (ESLint-style) | `anstyle` 1.x or `colored` 2.x | `src/output/console.zig` | LOW | ANSI color codes; `anstyle` is the lower-level composable option (used by clap itself). `colored` is higher-level. Prefer `anstyle` for consistency with clap's styling. |
| JSON output | `serde` 1.x + `serde_json` 1.x | `src/core/json.zig` (hand-rolled) | LOW | Zig hand-rolled JSON; Rust replaces this with `#[derive(Serialize)]` on output structs. Major simplification — no manual escape logic. |
| SARIF 2.1.0 output | `serde-sarif` 0.8.x | `src/output/sarif_output.zig` | MEDIUM | `serde-sarif` provides typed SARIF structs with builder pattern. Pre-1.0 API may shift; validate output against GitHub Code Scanning schema. Alternative: hand-roll SARIF JSON with serde_json if crate proves unstable. |
| HTML report output | Inline template strings (no crate) | `src/output/html_output.zig` (embedded HTML+JS) | LOW | The Zig version embeds HTML as a string literal. In Rust, use `include_str!()` macro to embed the template at compile time. No templating crate needed — the Zig approach works identically in Rust. |
| CLI interface with all flags | `clap` 4.x with `#[derive(Parser)]` | `src/cli/args.zig` (hand-rolled parser) | LOW | `clap` 4.5.x derive API replaces 400+ lines of hand-rolled Zig arg parsing with a struct and attribute annotations. Major simplification. |
| `.complexityguard.json` config file | `serde` + `serde_json` | `src/cli/config.zig` | LOW | `#[derive(Deserialize, Default)]` on a config struct with `#[serde(default)]` on optional fields. Removes all manual JSON parsing. |
| Parallel file analysis | `rayon` 1.x | `src/pipeline/` (custom thread pool) | LOW | Replace hand-rolled thread pool with `files.par_iter().map(analyze_file)`. Each rayon thread needs its own `tree_sitter::Parser` instance — `Parser` implements `Send` and `Sync`, verified in docs.rs. |
| File discovery (recursive directory walk) | `walkdir` 2.x + `globset` 0.4.x (or `ignore` 0.4.x) | `src/cli/discovery.zig` | LOW | `ignore` crate (from BurntSushi/ripgrep) handles `.gitignore` respect + glob exclusion in one API. Alternative: `walkdir` + `globset` for minimal deps. `ignore` adds `.gitignore` semantics for free. |
| Exit codes for CI/CD (0-4) | `std::process::exit()` | `src/output/exit_codes.zig` | LOW | Trivial — `std::process::exit(code as i32)`. |
| Cross-compilation (Linux/macOS/Windows, x86_64 + aarch64) | `cross` tool + GitHub Actions matrix | `zig build` with target flag | MEDIUM | Rust cross-compilation requires more configuration than Zig's native cross-compile. Use `cross` tool with Docker for Linux musl targets; macOS targets require macOS runners. Windows is straightforward with `x86_64-pc-windows-gnu`. |
| Single binary under 5 MB | Cargo profile tuning | `zig build -Doptimize=ReleaseSmall` | MEDIUM | Rust binaries are larger than Zig by default. With `opt-level = "z"`, `lto = true`, `codegen-units = 1`, `strip = true`, and `panic = "abort"`, target 4-8 MB range. Tree-sitter grammar C code adds ~2-3 MB regardless of language. Exceeding 5 MB is likely unless size optimization is prioritized from day one. |

### Differentiators (Rust-Specific Improvements)

Features where the Rust port can improve over the Zig implementation.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Deduplicated tokenization pass (fix re-parse flaw) | Removes 800%+ overhead on some codebases | MEDIUM | In Zig, duplication re-reads and re-parses every file after metric analysis. In Rust, the Halstead pass already tokenizes AST leaf nodes — share that token stream with duplication detection. Requires architectural change: run Halstead + duplication tokenization in a single tree traversal. |
| Serde-derived JSON/config (vs hand-rolled) | Fewer serialization bugs, automatic field handling | LOW | Zig's hand-rolled JSON serializer is a maintenance liability. Serde with `#[derive(Serialize, Deserialize)]` eliminates entire classes of serialization bugs and makes config schema changes trivial. |
| Clap derive API (vs hand-rolled arg parser) | Less code, auto-generated help text, shell completion | LOW | Zig's hand-rolled arg parser is ~400 lines; clap 4.x derive reduces this to ~50 lines of struct definitions. Auto-generated `--help` output will be more standardized. |
| Rust iterator chains for metric computation | Idiomatic, composable, optimizer-friendly | LOW | Halstead counting: `nodes.iter().filter(is_operator).fold(HashMap::new(), count_distinct)`. More readable than Zig's manual loop accumulation. |
| Type-safe error handling (Result<T, E>) | Eliminates entire error categories | MEDIUM | Zig uses error unions; Rust's `Result` + `?` operator is equivalent but with richer ecosystem support. Use `anyhow` for application-level error handling (CLI errors); use typed errors in library-facing code. |

### Anti-Features (Do Not Build During Rewrite)

Features that seem natural to add during a rewrite but should be deferred.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| New metrics beyond v1.0 scope | "While we're rewriting, let's add X" | Scope creep delays parity; 1:1 match is the goal | Strict feature freeze until Rust binary passes all existing tests |
| Async/tokio for parallelism | Rust async is idiomatic in 2025 | File I/O analysis is CPU-bound, not I/O-bound; rayon is correct here; tokio adds unnecessary complexity | Use rayon `par_iter()` for CPU-bound parallelism |
| LSP server integration | Natural evolution for a code tool | Architectural shift requiring protocol implementation; deferred explicitly in PROJECT.md | Post-rewrite milestone |
| Watch mode | Developer UX improvement | Requires file system event watching (notify crate); post-rewrite feature | Post-rewrite milestone |
| Plugin API / custom metrics | Power users request extensibility | Adds API surface, versioning, security considerations | Built-in metrics cover all use cases; accept metric requests as issues |
| Type-aware analysis (semantic, not syntactic) | "True" complexity requires type resolution | Requires TypeScript compiler API; fundamentally changes architecture from tree-sitter-only | Design goal: syntax-only, no type resolution |
| npm package distribution | Existing Zig npm packages still work | Distribution channels don't change until Rust binary stabilizes | Port npm wrappers after Rust binary has a stable release cycle |

---

## Feature Dependencies

```
tree-sitter parsing (TS/TSX/JS/JSX)
    └──required by──> Cyclomatic complexity
    └──required by──> Cognitive complexity
    └──required by──> Halstead metrics
    └──required by──> Structural metrics
    └──required by──> Duplication detection (token stream)

Halstead metrics token stream
    └──can share with──> Duplication detection (optimization opportunity)

File discovery (walkdir + globset/ignore)
    └──feeds──> Parallel analysis (rayon)
                    └──produces──> Per-file results
                                       └──feeds──> All output formats

Per-file results
    └──required by──> Console output
    └──required by──> JSON output (serde_json)
    └──required by──> SARIF output (serde-sarif)
    └──required by──> HTML output (include_str! template)
    └──required by──> Exit codes
    └──required by──> Health score (scoring.rs)

CLI flags (clap derive)
    └──reads──> .complexityguard.json config (serde + serde_json)
    └──controls──> Which metrics to compute
    └──controls──> Output format selection
    └──controls──> Threshold values
```

### Dependency Notes

- **Halstead and duplication share token streams:** The Zig implementation re-parses files for duplication; the Rust port should use the AST traversal from the Halstead pass to build the token stream, then pass it to duplication detection in the same pipeline step. This requires the pipeline to collect the token stream as a side-output of Halstead analysis.
- **Rayon requires Send bounds:** Tree-sitter `Parser` implements `Send` and `Sync` (verified in docs.rs 0.26.x). However, `Parser` should be created per-thread (inside the rayon closure) rather than shared across threads to avoid contention on the internal parser state.
- **serde-sarif is pre-1.0:** The SARIF output module should validate its JSON against the SARIF 2.1.0 schema in tests. If `serde-sarif` breaks between minor versions, fall back to hand-rolling SARIF with `serde_json::json!` macros.

---

## MVP Definition

Since this is a parity rewrite, MVP is defined as "passes all behavioral tests from the Zig v1.0 implementation."

### Launch With (Rust v0.8 = feature parity)

- [x] Cyclomatic complexity — core metric, must match Zig output exactly
- [x] Cognitive complexity — must match Zig output exactly (including per-operator counting deviation from SonarSource)
- [x] Halstead metrics — must match Zig float output within floating-point tolerance
- [x] Structural metrics — must match Zig output exactly
- [x] Duplication detection (Rabin-Karp, Type 1 & 2) — must match Zig output for same inputs
- [x] Health score (sigmoid normalization) — must match Zig output within float tolerance
- [x] Console output — visual match to Zig output
- [x] JSON output — byte-level match for all fields
- [x] SARIF 2.1.0 output — accepted by GitHub Code Scanning
- [x] HTML report — self-contained, same embedded JS/CSS
- [x] CLI flags — same interface as Zig binary
- [x] `.complexityguard.json` config — same schema as Zig binary
- [x] Parallel file analysis — same or better throughput than Zig
- [x] File discovery with glob exclusion — same behavior as Zig
- [x] Exit codes (0-4) — same semantics as Zig

### Add After Parity (v0.9+)

- [ ] Fix tokenization re-parse flaw — single-pass Halstead + duplication tokenization
- [ ] Deduplicated tokenization — share token stream between Halstead and duplication
- [ ] Binary size validation — confirm Rust binary stays under 5 MB or document new limit

### Future Consideration (Post-rewrite milestones)

- [ ] Watch mode — deferred explicitly in PROJECT.md
- [ ] LSP server — deferred explicitly in PROJECT.md
- [ ] Baseline/diff mode — deferred explicitly in PROJECT.md
- [ ] npm distribution update — after Rust binary stabilizes

---

## Feature Prioritization Matrix

For the Rust rewrite, priority is sequenced to establish a working pipeline as fast as possible before adding optional features.

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Tree-sitter parsing pipeline | HIGH | LOW | P1 — all metrics depend on this |
| Cyclomatic complexity | HIGH | LOW | P1 — simplest metric, validates pipeline |
| JSON output (serde_json) | HIGH | LOW | P1 — enables automated testing of numeric outputs |
| CLI + config (clap + serde) | HIGH | LOW | P1 — enables integration testing |
| Cognitive complexity | HIGH | MEDIUM | P1 — must match Zig's deviations exactly |
| Halstead metrics | HIGH | LOW | P1 — complex math but known algorithm |
| Structural metrics | HIGH | LOW | P1 — simplest traversal |
| Duplication detection | HIGH | MEDIUM | P1 — most complex algorithm; must match Zig |
| Health score | HIGH | LOW | P1 — pure math, depends on all metrics |
| Console output | HIGH | LOW | P1 — developer-facing |
| SARIF output | MEDIUM | MEDIUM | P2 — needs schema validation |
| HTML output | MEDIUM | LOW | P2 — embed template with include_str! |
| Parallel analysis (rayon) | HIGH | LOW | P2 — add after single-file analysis confirmed correct |
| File discovery | HIGH | LOW | P2 — needed for directory scanning |
| Exit codes | HIGH | LOW | P2 — CI integration |
| Cross-compilation | HIGH | MEDIUM | P2 — needed for release |
| Binary size optimization | MEDIUM | MEDIUM | P2 — validate after feature-complete build |
| Deduplicated tokenization | MEDIUM | MEDIUM | P3 — performance improvement, not parity |

---

## Rust Crate Ecosystem Map

| Domain | Recommended Crate | Version | Why | Confidence |
|--------|-------------------|---------|-----|------------|
| Parsing | `tree-sitter` | 0.26.x | Official Rust bindings, `Parser` is `Send+Sync` | HIGH |
| TS/TSX grammar | `tree-sitter-typescript` | 0.23.x | Ships both `LANGUAGE_TYPESCRIPT` and `LANGUAGE_TSX` constants | HIGH |
| JS/JSX grammar | `tree-sitter-javascript` | 0.25.x | Ships both JS and JSX grammar | HIGH |
| Parallelism | `rayon` | 1.x | 1.11.0 current, 266M downloads, `.par_iter()` drop-in | HIGH |
| Serialization | `serde` + `serde_json` | 1.x | 614M downloads, industry standard | HIGH |
| SARIF output | `serde-sarif` | 0.8.x | Only SARIF-typed crate for Rust; supports 2.1.0 | MEDIUM (pre-1.0) |
| CLI parsing | `clap` | 4.5.x | 4.5.60 current, derive API, auto help generation | HIGH |
| File discovery | `ignore` | 0.4.x | BurntSushi/ripgrep, handles `.gitignore` + globs | HIGH |
| Terminal colors | `anstyle` | 1.x | Used by clap itself; low-level composable ANSI styles | HIGH |
| Error handling | `anyhow` | 1.x | Application-level errors; rich context chaining | HIGH |
| Hash acceleration | `rustc-hash` (`FxHashMap`) | 1.x | 15-30% faster than `std::HashMap` for string keys | MEDIUM |

### Crates Deliberately Not Used

| Crate | Why Skipped |
|-------|-------------|
| `tokio` / async runtimes | CPU-bound workload; rayon is correct; async adds overhead |
| `tera` / `minijinja` | HTML template is static; `include_str!()` is sufficient |
| `complexity` crate | Analyzes Rust code complexity, not TS/JS; wrong domain |
| `rust-code-analysis` (Mozilla) | Mozilla's library covers Halstead/cyclomatic for many languages but is not designed as a library for embedding; too heavy |
| `rolling-hash` crates | None cover the specific Type 1/2 token-window clone detection pattern; hand-roll Rabin-Karp as in Zig |

---

## Behavioral Differences to Watch

These are places where Rust idioms or crate behavior differs from the Zig implementation in ways that could cause output mismatches.

| Area | Zig Behavior | Rust Difference | Risk |
|------|-------------|-----------------|------|
| Float serialization | `std.json.Stringify` uses default precision | `serde_json` uses Rust's `Display` for `f64` | MEDIUM — Halstead `volume`, `difficulty`, `effort` floats may differ in last digits. Add tolerance in comparison tests. |
| String comparison | `std.mem.eql(u8, a, b)` | `a == b` on `&str` | LOW — identical semantics |
| HashMap iteration order | Undefined (Zig hash map) | Undefined (std HashMap) | MEDIUM — JSON output field order and duplicate group ordering may differ. Normalize in tests. |
| Optional fields in JSON | `?T` fields are omitted when null | `#[serde(skip_serializing_if = "Option::is_none")]` needed | LOW — must annotate struct fields explicitly |
| Tree-sitter node text extraction | `source[node.start_byte..node.end_byte]` | `node.utf8_text(source_bytes)?` | LOW — same result; Rust API returns `Result` for UTF-8 validation |
| Cognitive complexity counting | Per-operator `&&`/`\|\|`/`??` each +1 (ComplexityGuard deviation from SonarSource) | Must manually implement same deviation | HIGH — this is a known, documented deviation; must replicate exactly or tests will fail |
| Switch/case mode (classic vs modified) | `SwitchCaseMode` enum in config | Reproduce same enum in Rust config struct | LOW — direct mapping |
| Duplication token normalization | Identifiers replaced with sentinel "V" for Type 2 | Replicate same normalization logic | MEDIUM — must match exactly for clone groups to be identical |

---

## Sources

- [tree-sitter Rust bindings docs.rs 0.26.5](https://docs.rs/tree-sitter/latest/tree_sitter/) — confirmed `Parser: Send + Sync`
- [tree-sitter-typescript docs.rs 0.23.2](https://docs.rs/tree-sitter-typescript/0.23.2/tree_sitter_typescript/) — confirmed `LANGUAGE_TYPESCRIPT` and `LANGUAGE_TSX` constants
- [tree-sitter-javascript crates.io 0.25.0](https://crates.io/crates/tree-sitter-javascript) — confirmed JSX + JS grammar in single crate
- [tree-sitter version mismatch issues](https://github.com/tree-sitter/tree-sitter/issues/3095) — confirmed grammar crates must pin to same tree-sitter version
- [rayon GitHub](https://github.com/rayon-rs/rayon) — 1.11.0 current, `.par_iter()` pattern confirmed
- [serde-sarif docs.rs 0.8.0](https://docs.rs/serde-sarif/latest/serde_sarif/) — confirmed SARIF 2.1.0 support, builder pattern
- [clap docs.rs 4.5.60](https://docs.rs/clap/latest/clap/) — confirmed derive API, `#[derive(Parser)]`
- [ignore crate crates.io](https://crates.io/crates/ignore) — 80.8M downloads, gitignore + glob support
- [anstyle docs.rs](https://docs.rs/anstyle/latest/anstyle/) — ANSI style composable types, used by clap
- [min-sized-rust guide](https://github.com/johnthagen/min-sized-rust) — `opt-level="z"`, `lto=true`, `strip=true` pattern
- [cross-compilation in Rust 2025](https://fpira.com/blog/2025/01/cross-compilation-in-rust) — `cross` tool + Docker for musl targets
- [serde.rs derive documentation](https://serde.rs/derive.html) — `#[derive(Serialize, Deserialize)]` pattern
- [rust-code-analysis Mozilla](https://mozilla.github.io/rust-code-analysis/) — reference for Halstead metric definitions in Rust tree-sitter ecosystem

---
*Feature research for: Rust rewrite of ComplexityGuard (v0.8 milestone)*
*Researched: 2026-02-24*
