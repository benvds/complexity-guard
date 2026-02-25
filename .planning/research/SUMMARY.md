# Project Research Summary

**Project:** ComplexityGuard — Zig to Rust Rewrite (v0.8 milestone)
**Domain:** Static Analysis CLI Binary — Zig to Rust port with 1:1 feature parity
**Researched:** 2026-02-24
**Confidence:** HIGH

## Executive Summary

ComplexityGuard v1.0 is a mature Zig-based static binary that analyzes TypeScript/JavaScript complexity across five metric families (cyclomatic, cognitive, Halstead, structural, duplication) with four output formats and full CI integration. The Rust rewrite is a drop-in binary replacement — same CLI flags, same JSON schema, same exit codes, same metrics — with no new features until parity is confirmed. The research confirms this is a well-understood problem with direct Rust equivalents for every Zig component: tree-sitter's official Rust crates provide the same C library through safe bindings, rayon replaces the hand-rolled thread pool, serde eliminates all hand-rolled serialization, and clap reduces 400+ lines of arg parsing to a derive-annotated struct.

The recommended approach is a strict sequential build order: establish types and parsing first, then implement metrics one-by-one with output parity tests against the Zig binary, then wire parallel analysis, then outputs, and finally cross-compilation and CI. This order is dictated by dependency structure — every metric depends on the parsing pipeline, duplication detection depends on all other metrics being complete, and the pipeline architecture must be designed correctly from the start to avoid the single most dangerous pitfall: reproducing the Zig codebase's documented 800%+ re-parse overhead for duplication detection. Designing the pipeline to tokenize during the first parse pass is a foundational decision that cannot be retrofitted cheaply.

The main risks are: (1) tree-sitter grammar version mismatches causing compile errors that are confusing to diagnose; (2) the binary size target of 5 MB being tighter for Rust than it was for Zig — realistic estimates put the optimized binary at 5–8 MB, making the 5 MB constraint aspirational rather than guaranteed without UPX compression; (3) cross-compilation being meaningfully more complex in Rust than Zig, requiring a split CI matrix (cargo-zigbuild for Linux/macOS, native runners for Windows). All three risks have clear mitigations and should be addressed in Phase 1 before any metric code is written.

---

## Key Findings

### Recommended Stack

The stack is entirely stable-channel Rust with no nightly features required. The core parse-analyze-output pipeline maps to well-maintained crates with multi-year track records. Every major Zig component has a direct idiomatic Rust replacement, and several replacements are improvements (serde over hand-rolled JSON, clap over hand-rolled arg parsing).

**Core technologies:**
- **Rust 1.80+ (stable):** Implementation language — required minimum for rayon 1.11; no nightly features needed
- **tree-sitter 0.26.5 + tree-sitter-typescript 0.23.2 + tree-sitter-javascript 0.25.0:** Parsing — official Rust bindings for the same C grammars used in the Zig version; `Parser` is `Send + Sync`
- **clap 4.5.x (derive):** CLI interface — replaces 400-line hand-rolled Zig parser with a struct and annotations
- **serde 1.x + serde_json 1.x:** JSON serialization and config loading — replaces all hand-rolled JSON code
- **rayon 1.11.0:** Parallel file analysis — replaces custom `std.Thread.Pool` + Mutex with `par_iter()`
- **ignore 0.4.x:** Directory traversal — replaces manual `.gitignore` logic with ripgrep's battle-tested walker
- **serde-sarif 0.8.x:** SARIF 2.1.0 output — only typed SARIF crate for Rust; pre-1.0, validate output against GitHub schema
- **thiserror 2.x + anyhow 1.x:** Error handling — typed errors in library code, ergonomic propagation at CLI boundary
- **owo-colors 4.x:** Terminal color output — zero-allocation ANSI, respects `NO_COLOR`
- **cargo-zigbuild 0.21.x (Linux/macOS) + native GHA runners (Windows):** Cross-compilation — no Docker required for Linux/macOS targets

**What not to use:** tokio/async (workload is CPU-bound, not I/O-bound), askama (one template — use `include_str!`), nightly Rust, regex for parsing, `cross` tool (requires Docker), `log`/`env_logger` (this is a CLI, not a server).

### Expected Features

The feature set is frozen at Zig v1.0 parity for this milestone. All 15 features have direct Rust crate equivalents with LOW or MEDIUM port complexity — there is no feature that requires architectural invention.

**Must have (1:1 parity — v0.8):**
- Cyclomatic, cognitive, Halstead, and structural metric computation — hand-rolled AST traversal, ports cleanly to recursive Rust functions on `tree_sitter::Node`
- Duplication detection (Rabin-Karp, Type 1 and 2 clone groups) — most algorithmically complex; must reproduce same tokenization normalization exactly
- Health score (sigmoid normalization) — pure `f64` math; direct translation
- Console, JSON, SARIF 2.1.0, and HTML output formats — all four; JSON parity is byte-level
- CLI flags and `.complexityguard.json` config — identical interface; clap + serde replace all hand-rolled parsing
- Parallel file analysis and file discovery — rayon + ignore crate
- Exit codes 0–4 — exact same semantics as Zig binary

**Should have (v0.9 improvements, after parity confirmed):**
- Fix duplication re-parse overhead — single-pass tokenization shared between Halstead and duplication passes (800%+ performance improvement)
- Binary size validation — confirm optimized Rust binary meets 5 MB constraint or document revised limit

**Defer (post-rewrite):**
- Watch mode, LSP server, baseline/diff mode, npm distribution update — all explicitly deferred in PROJECT.md
- New metrics, plugin API, type-aware semantic analysis — out of scope; strict feature freeze during rewrite

**Critical behavioral differences to preserve exactly:**
- Cognitive complexity counts each `&&`/`||`/`??` operator as +1 separately — documented ComplexityGuard deviation from SonarSource's spec; tests will fail if not replicated
- Duplication identifier normalization — replace identifiers with sentinel "V" for Type 2 clones; must match exactly
- Float serialization precision — Halstead floats may differ in last digits between Zig and serde_json; add tolerance in comparison tests

### Architecture Approach

The architecture is a classic linear pipeline: CLI args → config merge → file discovery → parallel per-file analysis → sequential duplication pass → output dispatch → exit code. Every stage is a separate module. The key architectural improvement over Zig is that rayon's work-stealing replaces ~150 lines of explicit thread pool management, and Rust's ownership model eliminates the arena-to-owned deep-copy problem that made the Zig parallel pipeline complex.

**Major components:**
1. **`cli/` (args.rs + config.rs):** clap derive for CLI, serde_json for `.complexityguard.json` load/merge with explicit CLI-overrides-config precedence
2. **`discovery/mod.rs`:** `ignore::WalkBuilder` — respects `.gitignore` automatically; produces `Vec<PathBuf>`
3. **`parser/mod.rs`:** Thin tree-sitter adapter — language selection per extension, one `Parser` created per rayon task (not shared)
4. **`metrics/` (one file per metric family):** Pure functions taking `&Node` and `&[u8]`; no shared mutable state; all metrics run in a single tree traversal per file
5. **`pipeline/mod.rs`:** `rayon par_iter` over file list — each closure creates its own Parser, runs all metrics, returns owned `FileAnalysisResult` including token sequences for duplication
6. **`metrics/duplication.rs`:** Sequential cross-file Rabin-Karp hash pass over token sequences collected during the parallel pass — no re-parse
7. **`output/` (console, json, sarif, html):** Renderer dispatch — JSON and SARIF via serde derives, HTML via `include_str!` embedded template, console via owo-colors

**Recommended build order:** `types.rs` → CLI → discovery → parser → cyclomatic → structural → cognitive → halstead → scoring → pipeline → console → JSON/SARIF/HTML → duplication → integration tests + CI. This order minimizes rework and enables testing at each stage.

### Critical Pitfalls

1. **tree-sitter grammar version mismatch** — Grammar crates each declare their own `tree-sitter` dependency; Cargo may resolve two incompatible versions, causing a confusing compile error: "expected `tree_sitter::Language`, found a different `tree_sitter::Language`". Prevention: run `cargo tree -d` before adding grammar crates; pin all grammar and core crates to the same version range. Address in Phase 1 before writing any metric code.

2. **Duplication re-parse overhead reproduced from Zig** — The Zig implementation re-reads and re-parses every file a second time for duplication tokenization, causing 800%+ overhead. Naively porting this reproduces the flaw. Prevention: design the per-file worker to return `(MetricResults, Vec<Token>)` — tokenize during the first parse, store tokens in `FileAnalysisResult`, run the duplication hash pass on the collected token sequences. This is a foundational pipeline decision; retrofitting it is expensive. Address in Phase 2 before any metric implementation.

3. **Binary size balloons without explicit size profile** — Default `cargo build --release` with three grammar crates and serde produces 15–25 MB binaries. Prevention: add the size-optimized `[profile.release]` configuration (`opt-level = "z"`, `lto = true`, `codegen-units = 1`, `strip = true`, `panic = "abort"`) to `Cargo.toml` immediately in Phase 1. Measure binary size at the end of every phase.

4. **`tree_sitter::Node` lifetime prevents cross-stage caching** — `Node` cannot outlive the `Tree` it came from and is not `Send`. Any attempt to store nodes in structs or pass them to other pipeline stages causes lifetime compile errors. Prevention: extract all needed data (metrics, tokens, line numbers) into owned Rust types within the same scope as `Tree`; never store or return `Node`. Address in Phase 1 when designing `ParseResult`.

5. **Cross-compilation more complex than Zig** — cargo-zigbuild does not support Windows targets and does not support static glibc linking. Prevention: use cargo-zigbuild only for Linux musl and macOS targets; build Windows binaries on `windows-latest` GitHub Actions runners natively. Design the CI matrix for this split approach from the start.

---

## Implications for Roadmap

Based on combined research, the Rust rewrite should proceed in six phases that sequence from foundational infrastructure through feature parity to release validation.

### Phase 1: Project Setup and Parser Foundation

**Rationale:** All other work depends on this. Three pitfalls (grammar version mismatch, binary size, Node lifetime, build.rs cross-compile) must be resolved before any metric code exists — they are cheapest to fix here. The types and parser are the foundation every other module imports.
**Delivers:** Compiling Rust crate with correct grammar versions, size-optimized release profile, all four languages (ts/tsx/js/jsx) parsing without errors against fixture files, `ParseResult` returning only owned data, baseline binary size measurement, cross-compile to at least one non-native target confirmed in CI.
**Addresses:** All P1 infrastructure features (project skeleton, type definitions)
**Avoids:** Grammar version mismatch (Pitfall 1), binary size bloat (Pitfall 3), Node lifetime errors (Pitfall 4), build.rs cross-compile failure (Pitfall 9 from PITFALLS.md)
**Research flag:** Standard patterns — no additional research needed.

### Phase 2: Core Metrics Pipeline (Single-File, Sequential)

**Rationale:** Implement all five metric families for a single file with sequential processing before introducing parallelism. Isolates metric correctness from concurrency concerns. The pipeline architecture must embed tokenization in the per-file worker here — retrofitting it into Phase 4 is expensive. Cyclomatic first (simplest, establishes traversal pattern); duplication last (most complex, depends on token streams from all other metrics).
**Delivers:** Correct per-file output for all five metrics matching Zig v1.0 behavior, with JSON output for automated comparison. Cognitive complexity deviation from SonarSource replicated exactly. Float tolerance established for Halstead metrics. Duplication Rabin-Karp implementation with correct Type 1 and 2 normalization. Per-file worker returns `(MetricResults, Vec<Token>)` — pipeline architecture set correctly.
**Uses:** tree-sitter 0.26.x traversal API, serde_json for comparison output, FxHashMap from rustc-hash for duplication hash index
**Implements:** `metrics/` module family, `output/json.rs` for test validation
**Avoids:** Duplication re-parse overhead (Pitfall 2 — foundational pipeline decision made here), HashMap performance trap (Pitfall 10 from PITFALLS.md)
**Research flag:** Standard patterns for cyclomatic/structural/Halstead/scoring. Cognitive complexity deviation and duplication Type 1/2 normalization need exact match validation against Zig binary output.

### Phase 3: CLI, Config, and Output Formats

**Rationale:** Once metrics produce correct output, wire up the full CLI interface and all four output formats. clap + serde make this mechanical, but it requires complete metric type definitions from Phase 2 to be stable. SARIF output needs schema validation against GitHub Code Scanning.
**Delivers:** Identical CLI flag interface to Zig binary, `.complexityguard.json` config loading with CLI override precedence, all four output formats (console, JSON, SARIF 2.1.0, HTML) producing correct output. Exit codes 0–4 matching Zig semantics exactly.
**Uses:** clap 4.5.x derive, serde + serde_json, serde-sarif 0.8.x, owo-colors, `include_str!` for HTML template
**Implements:** `cli/`, `output/` modules
**Avoids:** CLI flag name changes, JSON field name drift, float formatting differences in output
**Research flag:** Standard patterns. serde-sarif is pre-1.0 — if it proves unstable during implementation, fall back to hand-rolled SARIF structs with `serde_json::json!`.

### Phase 4: Parallel Pipeline

**Rationale:** Parallelism is added after single-file correctness is established. Introducing rayon before metrics are correct mixes concurrency bugs with correctness bugs. The key constraint is that `Parser` must be created per rayon task — thread contention on a shared parser defeats parallelism.
**Delivers:** Full parallel file analysis with linear speedup with thread count, deterministic output (sorted by path), `--threads N` support, throughput matching or exceeding Zig binary. Duplication sequential pass operating over token sequences collected in the parallel pass (no re-parse).
**Uses:** rayon 1.11.0 `par_iter`, `ThreadPoolBuilder` for `--threads` support, ignore 0.4.x for directory walking
**Implements:** `pipeline/mod.rs`, `discovery/mod.rs`
**Avoids:** Parser thread contention (Pitfall 3 from PITFALLS.md — per-closure Parser creation), `Arc<Mutex<Vec>>` anti-pattern
**Research flag:** Standard patterns — rayon par_iter is well-documented. Validate with `hyperfine` that parallel speedup is linear.

### Phase 5: Integration Testing and Behavioral Parity Validation

**Rationale:** Before cross-compilation and release work, verify complete behavioral parity with the Zig v1.0 binary. This is the quality gate for the v0.8 milestone. Fixture-based output comparison catches metric deviations, float precision issues, and serialization differences before they reach users.
**Delivers:** Integration test suite using `std::process::Command` against fixture files (reused from Zig version), output parity confirmed for all formats, exit code parity confirmed, cognitive complexity deviation validated, duplication clone group ordering normalized in tests.
**Implements:** `tests/integration/cli_tests.rs`
**Avoids:** JSON field name changes, cognitive complexity miscounting, float serialization divergence reaching users
**Research flag:** Standard patterns — `process::Command`-based integration tests are idiomatic Rust.

### Phase 6: Cross-Compilation, CI, and Release

**Rationale:** Establish the complete release matrix only after feature parity and test coverage are confirmed. Cross-compilation in Rust requires a split strategy (cargo-zigbuild for Linux/macOS, native runners for Windows) that is more complex than Zig's approach — finalizing this in a dedicated phase keeps it from blocking earlier phases.
**Delivers:** Release binaries for all six targets (linux-x64-musl, linux-arm64-musl, macos-x64, macos-arm64, windows-x64, windows-arm64), binary size validated with actual measurement (not assumption), each target binary confirmed to execute on a native runner, CI caching configured (sccache or actions/cache).
**Uses:** cargo-zigbuild 0.21.x, GitHub Actions matrix, `windows-latest` native runners
**Avoids:** cargo-zigbuild Windows cross-compile failure (Pitfall 5), static glibc linking attempt, macOS strip failure on Linux cross-compile
**Research flag:** Standard patterns for cargo-zigbuild Linux/macOS targets and native Windows runners. Binary size may require UPX if 5 MB cannot be achieved — measure first, decide after.

### Phase Ordering Rationale

- **Infrastructure before metrics:** Grammar version mismatches and release profile must be resolved in Phase 1; discovering them in Phase 3 means three phases of compounding technical debt.
- **Sequential before parallel:** Metric correctness bugs and concurrency bugs are impossible to distinguish when both are present; Phase 2 single-file work isolates correctness.
- **Tokenization architecture in Phase 2, not Phase 4:** The duplication re-parse flaw is a pipeline architecture decision — if the per-file worker does not return token sequences, Phase 4 cannot add them without restructuring every metric module.
- **CLI and outputs after metrics are stable:** clap and serde work is mechanical once type definitions are finalized; changing `FileAnalysisResult` fields after serde derives are in place means regenerating derive impls throughout.
- **Parity validation before release:** Phase 5 before Phase 6 ensures cross-compilation effort is spent on a correct binary.

### Research Flags

Phases needing deeper research during planning:
- **Phase 6 (Cross-compilation):** Binary size target of 5 MB may not be achievable without UPX — empirical measurement required before committing to the constraint. If cargo-zigbuild behavior for specific targets has changed since research date, re-verify.
- **Phase 3 (SARIF):** serde-sarif 0.8.x is pre-1.0. If it is missing required SARIF 2.1.0 fields or has breaking changes between minor versions, a fallback plan (hand-rolled serde structs) should be designed before the phase begins.

Phases with standard patterns (skip additional research):
- **Phase 1:** tree-sitter Rust crate patterns are extensively documented; grammar version pinning procedure is clear from the tree-sitter issue tracker.
- **Phase 2:** All five metric algorithms are already implemented in Zig — porting is translation, not design. FxHashMap usage is a drop-in replacement.
- **Phase 3:** clap derive and serde derive are industry-standard with comprehensive documentation.
- **Phase 4:** rayon par_iter pattern is well-documented; per-closure Parser creation is the canonical approach.
- **Phase 5:** `process::Command` integration tests are idiomatic Rust with clear patterns.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All crates verified via docs.rs and crates.io; versions confirmed; alternatives considered and rejected with explicit rationale. No nightly required. |
| Features | HIGH | Feature set is fixed at Zig v1.0 parity; all port complexities assessed against direct Zig source; behavioral differences (cognitive deviation, float formatting, duplication normalization) documented with prevention strategies. |
| Architecture | HIGH | Module structure and data flow are direct translations of the known Zig architecture; rayon and serde patterns are well-documented with code examples; build order derived from explicit dependency analysis. |
| Pitfalls | HIGH | 11 pitfalls documented with code examples; most verified against official docs, tree-sitter issue tracker (issue #3095 confirmed), and direct Zig source inspection; grammar version mismatch, cargo-zigbuild limitations, and Node lifetime constraints all have authoritative sources. |

**Overall confidence: HIGH**

### Gaps to Address

- **Binary size under 5 MB:** The Zig binary achieved 3.6–3.8 MB with ReleaseSmall. Realistic Rust estimates with three grammar crates are 5–8 MB after full optimization. The 5 MB constraint may need to be updated to 8 MB, or UPX compression applied for distribution. Measure empirically at end of Phase 1 and set the constraint based on actual measurement, not assumption.

- **serde-sarif stability:** serde-sarif 0.8.x is pre-1.0. The SARIF output module should validate its JSON against the SARIF 2.1.0 schema in integration tests. Fallback plan: hand-roll SARIF structs with `serde_json::json!` macros if the crate proves problematic.

- **Cognitive complexity deviation replication:** ComplexityGuard's per-operator `&&`/`||`/`??` counting deviates from SonarSource's spec. This deviation must be replicated exactly or all cognitive complexity tests fail. Requires explicit cross-validation tests comparing Rust output to Zig output on the same fixtures.

- **Float serialization precision alignment:** `serde_json` and Zig's `std.json.Stringify` may format `f64` values differently in the last digit. Halstead metrics (`volume`, `difficulty`, `effort`) will be affected. Integration tests should use floating-point tolerance rather than byte-exact comparison for these fields.

---

## Sources

### Primary (HIGH confidence)
- [docs.rs/tree-sitter 0.26.5](https://docs.rs/tree-sitter/latest/tree_sitter/) — Parser Send+Sync, Tree/Node lifetime constraints, parse API
- [docs.rs/tree-sitter-typescript 0.23.2](https://docs.rs/tree-sitter-typescript/latest/tree_sitter_typescript/) — LANGUAGE_TYPESCRIPT, LANGUAGE_TSX constants confirmed
- [crates.io/tree-sitter-javascript 0.25.0](https://crates.io/crates/tree-sitter-javascript) — LANGUAGE constant, JSX support confirmed
- [crates.io/clap 4.5.60](https://crates.io/crates/clap) — derive API, current version confirmed
- [crates.io/serde_json 1.0.149](https://crates.io/crates/serde_json) — current version confirmed
- [docs.rs/rayon 1.11.0](https://docs.rs/crate/rayon/latest) — rustc 1.80 requirement, par_iter patterns
- [docs.rs/serde-sarif 0.8.0](https://docs.rs/serde-sarif/latest/serde_sarif/) — SARIF 2.1.0 support, TypedBuilder pattern
- [github.com/rust-cross/cargo-zigbuild README](https://github.com/rust-cross/cargo-zigbuild/blob/main/README.md) — Windows NOT supported limitation confirmed
- [github.com/johnthagen/min-sized-rust](https://github.com/johnthagen/min-sized-rust) — opt-level=z, LTO, strip, panic=abort techniques
- [nnethercote.github.io — Rust Performance Book: Hashing](https://nnethercote.github.io/perf-book/hashing.html) — FxHashMap recommendation
- [github.com/rust-lang/rustc-hash](https://github.com/rust-lang/rustc-hash) — FxHashMap implementation
- [doc.rust-lang.org/nomicon — FFI Unwinding](https://doc.rust-lang.org/nomicon/ffi.html) — panic across FFI boundary UB
- [tree-sitter/tree-sitter#3095](https://github.com/tree-sitter/tree-sitter/issues/3095) — grammar version mismatch details confirmed
- [cargo-zigbuild issue #231](https://github.com/rust-cross/cargo-zigbuild/issues/231) — static glibc unsupported confirmed
- ComplexityGuard Zig source (direct code inspection) — re-parse architecture flaw, cognitive complexity deviation, duplication normalization

### Secondary (MEDIUM confidence)
- [rfdonnelly.github.io — Using Tree-sitter Parsers in Rust](https://rfdonnelly.github.io/posts/using-tree-sitter-parsers-in-rust/) — build.rs + cc crate pattern
- [manishearth.github.io — Arenas in Rust](https://manishearth.github.io/blog/2021/03/15/arenas-in-rust/) — arena allocator friction patterns
- [gaultier.github.io — Lessons from a successful Rust rewrite](https://gaultier.github.io/blog/lessons_learned_from_a_successful_rust_rewrite.html) — C FFI friction, arena patterns in rewrites
- [gendignoux.com — Making a parallel Rust workload 10x faster](https://gendignoux.com/blog/2024/11/18/rust-rayon-optimized.html) — Rayon parallelism pitfalls
- [shuttle.dev — Data Parallelism with Rayon](https://www.shuttle.dev/blog/2024/04/11/using-rayon-rust) — par_iter patterns, mutex contention
- [actually.fyi — Zig Makes Rust Cross-compilation Just Work](https://actually.fyi/posts/zig-makes-rust-cross-compilation-just-work/) — Zig vs Rust cross-compile comparison
- GitHub Actions documentation — native runner matrix strategy for Windows MSVC targets

---
*Research completed: 2026-02-24*
*Ready for roadmap: yes*
