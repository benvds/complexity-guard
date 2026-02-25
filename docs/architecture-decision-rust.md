# ADR: Adopt Rust as Sole Implementation Language

**Status:** Accepted
**Date:** 2026-02-25

## Context

ComplexityGuard was originally built in Zig (v1.0, phases 1–14). A parallel Rust rewrite (v0.8, phases 17–22) was undertaken to evaluate whether Rust offered meaningful advantages in ecosystem, tooling, and distribution. The project ran both implementations in parallel through Phase 22, with benchmark comparisons conducted in quick task 22 (`bench-rust-vs-zig.sh`).

The evaluation covered:

- **Performance** — measured via hyperfine across 5 target platforms
- **Ecosystem** — cargo, crates.io, derive macros, maintained upstream crates
- **Cross-compilation** — cargo-zigbuild vs Zig's built-in cross-compilation
- **CI complexity** — GitHub Actions workflow complexity for each language
- **Maintenance burden** — vendored C submodules (Zig) vs registry dependencies (Rust)

## Decision

Adopt Rust as the sole implementation language. Remove all Zig code and infrastructure.

## Rationale

### Performance: Rust is 1.5–3.1x faster than Zig with parallel analysis

Benchmarks from quick task 22 (bench-rust-vs-zig.sh) across representative TypeScript projects:

| Project | Rust (ms) | Zig (ms) | Speedup |
|---------|-----------|----------|---------|
| got (68 files) | ~37 | ~55 | 1.5x Rust |
| zod (169 files) | ~82 | ~140 | 1.7x Rust |
| vite (1,182 files) | ~131 | ~250 | 1.9x Rust |
| nestjs (1,653 files) | ~145 | ~320 | 2.2x Rust |
| webpack (6,889 files) | ~678 | ~2,100 | 3.1x Rust |

The performance advantage comes from Rust's rayon-based parallelism (ThreadPoolBuilder with
work-stealing) versus Zig's std.Thread.Pool approach. The Rust implementation also avoids
re-parsing files for duplication detection (tokens pre-computed in the per-file worker), which
eliminates the 800%+ overhead that the Zig implementation incurred.

### Ecosystem: Rust has superior dependency management

- **cargo + crates.io**: Standard dependency management with semantic versioning, lock files, and reproducible builds. No manual submodule pinning required.
- **Derive macros**: `#[derive(Serialize, Deserialize)]` eliminates hundreds of lines of hand-rolled JSON serialization code needed in Zig.
- **Upstream crates**: `tree-sitter`, `tree-sitter-typescript`, and `tree-sitter-javascript` are published as cargo crates and maintained by their respective authors. Zero vendoring required.
- **cargo-zigbuild**: Cross-compilation to Linux musl targets is handled by a single cargo plugin, eliminating the need for platform-specific CI matrix hacks.

### Cross-compilation: Simpler with cargo-zigbuild

Rust cross-compilation uses a split CI matrix:
- **Linux musl targets**: `cargo zigbuild` (cargo-zigbuild plugin + pip3 install ziglang)
- **macOS/Windows**: Native runners with standard `cargo build`

The Zig approach required the full Zig compiler on every runner and `zig build -Dtarget=<triple> -Doptimize=ReleaseSmall` invocations. The Rust approach uses standard cargo commands and only requires Zig for the musl linker (via cargo-zigbuild), not for the source language.

### CI complexity: Rust workflows are simpler

The Zig CI (`test.yml`) required:
- `mlugg/setup-zig@v2` action on every runner
- `submodules: true` checkout (to fetch tree-sitter vendored C sources)
- Valgrind memcheck + Helgrind thread-safety checks (Zig-specific memory management)
- A separate suppression file for Helgrind false positives from Zig's futex-based mutex

The Rust CI (`ci.yml`) requires only:
- `dtolnay/rust-toolchain@stable` (standard)
- `Swatinem/rust-cache@v2` (standard)
- `cargo fmt --check`, `cargo clippy`, `cargo test`, `cargo build --release`

Rust's ownership model eliminates entire classes of bugs (use-after-free, data races) that Valgrind checked for in Zig, so memory-check CI is unnecessary.

### Maintenance: Vendored submodules removed

The Zig implementation vendored tree-sitter core and two grammar libraries as git submodules:
- `zig/vendor/tree-sitter`
- `zig/vendor/tree-sitter-typescript`
- `zig/vendor/tree-sitter-javascript`

These required manual updates, added ~15 MB to repository size, complicated `git clone` (requiring `--recurse-submodules`), and required C compilation as part of the Zig build. The Rust implementation declares them as cargo dependencies — no submodules, no C compilation, standard `cargo update` for upgrades.

## Consequences

- **Positive**: Single implementation to maintain. No dual-language confusion. Simpler onboarding for contributors.
- **Positive**: Rust ecosystem tooling (rustfmt, clippy, cargo doc) provides better developer experience than Zig's equivalent tools at this maturity stage.
- **Positive**: Repository is smaller (no vendored submodules, no Zig build artifacts).
- **Negative**: Zig implementation history is preserved only in git history. Developers who wish to study the Zig implementation must check out commits before this change.
- **Neutral**: Historical benchmark data comparing Zig vs Rust (quick task 22, `zig/benchmarks/results/`) is preserved in git history and no longer present in the working tree.

## Alternatives Considered

**Keep both implementations**: Rejected. Dual implementations double the maintenance surface and create confusion about which is canonical.

**Keep Zig, discard Rust**: Rejected. Rust is measurably faster, has better ecosystem support, and produces smaller binaries with simpler cross-compilation. The Zig implementation would require continued manual submodule management and vendored C compilation.
