# Stack Research

**Domain:** Code Complexity Analysis — Rust Rewrite of ComplexityGuard (Zig → Rust)
**Researched:** 2026-02-24
**Confidence:** HIGH (all crates verified via docs.rs and official sources)

---

## Context: What We Are Rewriting

ComplexityGuard v1.0 is a Zig + tree-sitter static binary that analyzes TS/TSX/JS/JSX across five metric families. The Rust rewrite must achieve 1:1 feature parity as a drop-in binary replacement. Everything in this file is scoped to *Rust equivalents only* — the domain problem (parsing, metrics, scoring) is already solved; the task is choosing the right Rust crates.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Rust (stable) | 1.80+ | Implementation language | Required by rayon 1.11. Stable toolchain — no nightly needed for any crate in this stack. |
| tree-sitter | 0.26.5 | Parser framework | Official Rust bindings maintained by tree-sitter org. Same C library as Zig build — identical parse behavior, same error-tolerant CST API. |
| tree-sitter-typescript | 0.23.2 | TypeScript + TSX grammars | Official grammar crate. Exposes `LANGUAGE_TYPESCRIPT` and `LANGUAGE_TSX` constants — one crate, both grammars. |
| tree-sitter-javascript | 0.25.0 | JavaScript + JSX grammars | Official grammar crate. Exposes `LANGUAGE` constant. TSX grammar in tree-sitter-typescript depends on it — include both. |
| clap | 4.5.x | CLI argument parsing | De facto standard (4.5.60 current). Derive macro interface produces structured args from annotated structs. Handles subcommands, help text, completions. |
| serde + serde_json | 1.0.x / 1.0.149 | JSON serialization | Universal serialization framework. Derive `Serialize`/`Deserialize` on output types; config file loading is free. serde_json 1.0.149 is current. |
| rayon | 1.11.0 | Parallel file analysis | Work-stealing thread pool. Replace sequential file iteration with `.par_iter()` — zero architectural change. Requires rustc 1.80+. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| serde-sarif | 0.8.0 | SARIF 2.1.0 typed output | Generates SARIF from official schema at build time. TypedBuilder API prevents malformed SARIF. Use for the `--format sarif` output path. |
| minijinja | 2.x | HTML report templating | Runtime Jinja2-compatible templates. Use `include_str!` to embed template in binary at compile time — no external files needed. Better fit than Askama for a single self-contained HTML template. |
| ignore | 0.4.x | Directory traversal respecting .gitignore | Used by ripgrep. Walks file trees, auto-respects `.gitignore`, filters by extension. Use for `--path` directory scanning. |
| thiserror | 2.x | Typed error definitions | Define `ComplexityGuardError` enum once; propagate cleanly through parsing and metric layers. Use in library code. |
| anyhow | 1.x | Error propagation in main | Wrap thiserror errors at `main` entry point for ergonomic error reporting with context chains. |
| owo-colors | 4.x | Terminal color output | Zero-allocation ANSI colors for ESLint-style console output. Respects `NO_COLOR`. Pure Rust — no C dependency. |
| cc | 1.x | Build dependency for grammar C sources | Compiles tree-sitter grammar C files in `build.rs`. Required transitive dependency — already pulled in by tree-sitter-typescript and tree-sitter-javascript crates. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| cargo test | Unit and integration testing | Built-in test framework. No additional crate needed — Rust's `#[test]` covers unit tests; `tests/` directory covers integration. |
| cargo clippy | Linting | Run in CI with `-D warnings`. Catches common correctness and style issues. |
| cargo fmt | Formatting | Enforce in CI with `--check`. |
| cargo-zigbuild | Cross-compilation for Linux/macOS targets | Uses Zig as linker. Handles glibc version pinning. Supports `aarch64-unknown-linux-gnu`, `x86_64-unknown-linux-gnu`, `aarch64-apple-darwin`, `x86_64-apple-darwin`. Does NOT support Windows targets. |
| GitHub Actions native runners | Cross-compilation for Windows | Build Windows targets on `windows-latest` runners using standard `cargo build --release`. No Docker or cross-compilation toolchain needed. |
| cargo-zigbuild (musl) | Static Linux builds | Supports `x86_64-unknown-linux-musl` via Zig's bundled musl. Note: `-C target-feature=+crt-static` is NOT compatible with cargo-zigbuild — use musl target directly instead. |
| SARIF validator | Validate SARIF output correctness | `npm i -g @microsoft/sarif-multitool && sarif validate output.sarif` |
| tree-sitter CLI | Inspect parse trees during development | `tree-sitter parse file.ts` to understand node types when implementing metric traversal logic. |

---

## Installation (Cargo.toml)

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

# CLI
clap = { version = "4.5", features = ["derive"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# SARIF output
serde-sarif = "0.8"

# HTML templating
minijinja = "2"

# Parallel processing
rayon = "1.11"

# File traversal
ignore = "0.4"

# Error handling
thiserror = "2"
anyhow = "1"

# Terminal colors
owo-colors = "4"

[build-dependencies]
# Grammar C compilation (transitively required; declare explicitly for clarity)
cc = "1"

[profile.release]
opt-level = "z"      # size-first optimization (mirrors Zig's ReleaseSmall)
lto = true           # link-time optimization
codegen-units = 1    # maximize LTO effectiveness
panic = "abort"      # remove panic unwinding machinery
strip = true         # strip symbols from binary
```

---

## Crate Integration Points

Understanding how these crates connect prevents architectural missteps:

**Parsing pipeline:**
`tree-sitter` Parser + Language → `tree-sitter-typescript::LANGUAGE_TYPESCRIPT` / `LANGUAGE_TSX` / `tree-sitter-javascript::LANGUAGE` → `Tree` → `Node` traversal for metric computation.

**Output pipeline:**
Metric structs → `#[derive(Serialize)]` → `serde_json::to_string_pretty()` for JSON output.
Metric structs → `serde-sarif` builders → `serde_json::to_string_pretty()` for SARIF output.
Metric structs → `minijinja` template (embedded via `include_str!`) → HTML string for HTML output.
Metric structs → `owo-colors` formatted write for console output.

**Parallelism:**
`ignore::WalkBuilder` produces a file iterator → `.collect::<Vec<_>>()` → `.par_iter()` from `rayon` → per-file parse and metric computation in work-stealing threads → results collected back to main thread.

**Error handling:**
`thiserror::Error` enum for `ParseError`, `MetricError`, `ConfigError` — returned from library functions.
`anyhow::Result` at `main` boundary — wraps all errors with `.context()` for user-facing messages.

**Config file:**
`serde_json::from_str::<Config>(content)` where `Config` derives `Deserialize`. Merged with `clap` parsed CLI args (CLI takes precedence).

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| tree-sitter (0.26 Rust crate) | oxc_parser | oxc is faster for pure JS/TS but doesn't expose a stable tree-sitter-compatible CST. Metric logic is already written against tree-sitter node kinds — reuse is the goal. |
| tree-sitter (0.26 Rust crate) | swc_ecma_parser | Same issue: SWC exposes its own AST, not tree-sitter node kinds. Migration cost outweighs performance gain for a complexity analyzer. |
| clap (derive) | lexopt / argh | clap 4 derive is the ergonomic standard. lexopt/argh save compile time but offer no benefit for a binary tool where compile time is amortized. |
| serde_json | simd-json | SARIF and config files are not hot paths. simd-json's complexity is not justified for occasional serialization. |
| serde-sarif | Hand-rolled SARIF structs | serde-sarif is generated from the official JSON schema — correctness is guaranteed. Hand-rolling risks schema drift and missing required fields. |
| minijinja | Askama | The HTML report is one complex template, not a web framework. Askama requires templates at compile time with full type mapping. minijinja allows the template to be embedded as a string (`include_str!`) and rendered at runtime, which is simpler for a single self-contained report. No performance difference matters here — the report renders once per run. |
| minijinja | Tera | Tera is heavier (more dependencies). minijinja has only `serde` as a required dependency. |
| rayon | std::thread + channels | rayon's work-stealing handles uneven file sizes automatically. Thread + channel implementation would require manual pool management. rayon is the standard for data parallelism in Rust. |
| ignore | walkdir | `ignore` respects `.gitignore` out of the box — users expect this behavior in a code analysis tool. `walkdir` is simpler but requires manual ignore logic. |
| thiserror + anyhow | Box<dyn Error> | thiserror gives typed, matchable errors for library code. anyhow gives ergonomic context chains for main. The combination is idiomatic Rust for CLI tools. |
| owo-colors | colored | owo-colors is zero-allocation and more actively maintained. Both have similar APIs; owo-colors respects `NO_COLOR` env var natively. |
| cargo-zigbuild (Linux/macOS) + native runners (Windows) | cross (Docker) | cargo-zigbuild does not require Docker and produces smaller binaries through Zig's linker. cross requires Docker on the build host. Native Windows runners avoid cross-compilation complexity for MSVC targets entirely. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `nightly` Rust features | No crate in this stack requires nightly. Using nightly adds CI complexity and instability risk. | `stable` channel — pin with `rust-toolchain.toml` |
| `cargo cross` (Docker-based) | Requires Docker daemon on CI runners. More complex than cargo-zigbuild for Linux/macOS. Windows support via Docker containers on GitHub Actions is unnecessarily heavy. | cargo-zigbuild for Linux/macOS, native runners for Windows |
| `askama` for HTML | Requires compile-time template files with full type mapping. Overkill for one report template. | minijinja with `include_str!` embedded template |
| `tokio` / async runtime | File analysis is CPU-bound, not I/O-bound. Async adds overhead and complexity without benefit. Rayon's work-stealing is purpose-built for CPU parallelism. | rayon for parallelism |
| `log` + `env_logger` | This is a CLI tool, not a server. Users do not want logging middleware. | `eprintln!` for diagnostics, exit codes for status, `--verbose` flag via clap if needed |
| `regex` for parsing | Regex cannot correctly parse TS/JS syntax. Won't handle template literals, nested types, JSX. | tree-sitter for all parsing |
| `syn` (Rust parsing) | Parses Rust source, not TypeScript/JavaScript. Wrong domain entirely. | tree-sitter-typescript, tree-sitter-javascript |
| `proc-macro2` / proc macros | No metaprogramming needed. clap and serde derive macros cover all macro needs. | clap derive + serde derive |

---

## Stack Patterns by Build Variant

**Release binary (size target < 5 MB):**
- Use `[profile.release]` config above: `opt-level = "z"`, `lto = true`, `strip = true`, `panic = "abort"`
- Linux static: `cargo zigbuild --target x86_64-unknown-linux-musl --release`
- macOS: `cargo zigbuild --target x86_64-apple-darwin --release` (and aarch64)
- Windows: `cargo build --target x86_64-pc-windows-msvc --release` on `windows-latest` runner

**Development build (fast iteration):**
- Default `cargo build` — debug profile, no LTO, full symbols
- Run tests with `cargo test`
- Check formatting: `cargo fmt --check`
- Check lints: `cargo clippy -- -D warnings`

**Size risk assessment:**
The Zig binary achieved 3.6-3.8 MB with ReleaseSmall. Rust binaries with tree-sitter C grammars statically linked typically land 5-12 MB before optimization, 3-7 MB after `opt-level = "z"` + `lto` + `strip`. The 5 MB constraint is achievable but should be measured in Phase 1 before committing to the CI pipeline.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| tree-sitter 0.26.x | tree-sitter-typescript 0.23.x | Grammar crates track tree-sitter core versions. Pin both to avoid "LanguageFn version mismatch" panics. |
| tree-sitter 0.26.x | tree-sitter-javascript 0.25.x | Same pinning requirement. JSX handling depends on JS grammar. |
| rayon 1.11.0 | rustc 1.80+ | rayon 1.11 requires Rust 1.80 or later. |
| clap 4.5.x | serde 1.x | No shared types — no compatibility concern. |
| serde-sarif 0.8.0 | serde 1.x + serde_json 1.x | serde-sarif depends on both. Version 0.8.0 is current and compatible with serde 1.x. |
| cargo-zigbuild | Zig 0.13+ | cargo-zigbuild requires Zig installed on the build host. Version 0.21.x is current. Install via `pip install ziglang` or OS package manager. |

---

## Sources

- [docs.rs/tree-sitter](https://docs.rs/tree-sitter/latest/tree_sitter/) — version 0.26.5 confirmed, key API types (HIGH confidence)
- [docs.rs/tree-sitter-typescript](https://docs.rs/tree-sitter-typescript/latest/tree_sitter_typescript/) — version 0.23.2, LANGUAGE_TYPESCRIPT and LANGUAGE_TSX constants confirmed (HIGH confidence)
- [docs.rs/tree-sitter-javascript](https://docs.rs/tree-sitter-javascript/latest/tree_sitter_javascript/) — version 0.25.0, LANGUAGE constant confirmed (HIGH confidence)
- [crates.io/crates/clap](https://crates.io/crates/clap) — version 4.5.60 confirmed (HIGH confidence)
- [crates.io/crates/serde_json](https://crates.io/crates/serde_json) — version 1.0.149 confirmed (HIGH confidence)
- [docs.rs/crate/rayon/latest](https://docs.rs/crate/rayon/latest) — version 1.11.0 confirmed, rustc 1.80 requirement confirmed (HIGH confidence)
- [docs.rs/serde-sarif/latest/serde_sarif/](https://docs.rs/serde-sarif/latest/serde_sarif/) — version 0.8.0, SARIF 2.1.0 support confirmed, TypedBuilder pattern confirmed (HIGH confidence)
- [github.com/mitsuhiko/minijinja](https://github.com/mitsuhiko/minijinja) — minijinja Jinja2-compatible engine, serde-only dependency (HIGH confidence)
- [github.com/rust-cross/cargo-zigbuild](https://github.com/rust-cross/cargo-zigbuild) — Windows NOT supported, Linux/macOS targets supported, version 0.21.8 current (HIGH confidence)
- [rfdonnelly.github.io — Using Tree-sitter Parsers in Rust](https://rfdonnelly.github.io/posts/using-tree-sitter-parsers-in-rust/) — build.rs + cc crate pattern for grammar compilation (MEDIUM confidence)
- GitHub Actions documentation — native runner matrix strategy for Windows MSVC targets (MEDIUM confidence)

---

*Stack research for: Rust rewrite of ComplexityGuard (Zig → Rust)*
*Researched: 2026-02-24*
