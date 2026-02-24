# ComplexityGuard

## What This Is

A fast, cross-platform code complexity analyzer for TypeScript/JavaScript projects. A single zero-dependency static binary (compiled from Zig with tree-sitter) that analyzes codebases across five complexity dimensions — cyclomatic, cognitive, Halstead, structural, and duplication — with configurable weighted health scoring. Outputs ESLint-style console, JSON, SARIF 2.1.0 (GitHub Code Scanning), and interactive HTML reports. Targets solo developers, small teams, and CI/CD pipelines that want SonarCloud-level insight without the SaaS cost.

## Core Value

Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.

## Requirements

### Validated

- ✓ CLI tool with file/directory scanning for TS/TSX/JS/JSX — v1.0
- ✓ Tree-sitter-based parsing pipeline — v1.0
- ✓ Cyclomatic complexity (McCabe) metric with configurable thresholds — v1.0
- ✓ Cognitive complexity (SonarSource) metric with nesting penalties — v1.0
- ✓ Halstead complexity metrics (volume, difficulty, effort, estimated bugs) — v1.0
- ✓ Duplication detection via Rabin-Karp rolling hashes (Type 1 & 2 clones) — v1.0
- ✓ Structural metrics (function length, parameter count, nesting depth, file length, export count) — v1.0
- ✓ Composite weighted health score (0-100) with configurable weights — v1.0
- ✓ Console output with per-function/per-file summaries — v1.0
- ✓ JSON output format — v1.0
- ✓ SARIF 2.1.0 output for GitHub Code Scanning integration — v1.0
- ✓ Self-contained HTML report output — v1.0
- ✓ Configuration via `.complexityguard.json` — v1.0
- ✓ CLI flags for all config options — v1.0
- ✓ Exit codes for CI/CD gating (0-4) — v1.0
- ✓ Parallel file analysis via thread pool — v1.0
- ✓ Cross-compilation to Linux/macOS/Windows (x86_64 + aarch64) — v1.0
- ✓ Single static binary under 5 MB — v1.0

### Active

## Current Milestone: v0.8 Rust Rewrite

**Goal:** Rewrite ComplexityGuard from Zig to Rust for ecosystem maturity and language stability, achieving 1:1 feature parity as a drop-in binary replacement.

**Target features:**
- Rust implementation with tree-sitter-rs for TS/JS/TSX/JSX parsing
- All five metric families (cyclomatic, cognitive, Halstead, structural, duplication)
- All four output formats (console, JSON, SARIF 2.1.0, HTML)
- Same CLI interface and configuration system
- CI testing pipeline (GitHub Actions)
- Cross-compilation to same target platforms

### Out of Scope

- LSP server / editor integration — deferred post-rewrite
- Watch mode — deferred post-rewrite
- Baseline/diff mode — deferred post-rewrite
- Git blame integration — deferred post-rewrite
- npm distribution packages — deferred to after Rust binary stabilizes
- Vue SFC support — may add later based on demand
- Type-checking or semantic analysis — syntax-only tool by design
- Bug detection or security scanning — not a linter
- Auto-fix suggestions — analysis only
- Type-level complexity metrics — v2 feature
- Plugin architecture for custom metrics — built-in metrics only
- Cloud/SaaS platform — local-first tool

## Context

Shipped v1.0 with 17,549 LOC Zig across 16 phases in 10 days.
Tech stack: Zig 0.14+ with tree-sitter (TypeScript, TSX, JavaScript grammars compiled in).
Binary size: 3.6-3.8 MB (ReleaseSmall) across all 5 target platforms.
Distribution: GitHub Releases, npm wrapper packages (platform-specific).
Performance: parallel file analysis via thread pool; benchmarked against FTA tool.
CI/CD: GitHub Actions for testing and release automation.

## Constraints

- **Tech stack**: Zig + tree-sitter — chosen for single-binary output and C interop
- **Binary size**: Under 5 MB with tree-sitter grammars compiled in (achieved 3.6-3.8 MB)
- **Performance**: Must analyze 10,000 TS files in under 2 seconds
- **Compatibility**: Must produce valid SARIF 2.1.0 accepted by GitHub Code Scanning
- **Parsing**: Syntax-only analysis, no type resolution or semantic analysis

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Zig over Rust | Faster compile times, simpler C interop for tree-sitter, single static binary | ✓ Good — 3.6 MB binary, fast builds, seamless tree-sitter integration |
| tree-sitter for parsing | Proven grammars, error-tolerant, incremental (useful for future LSP), C library | ✓ Good — reliable parsing of TS/TSX/JS/JSX with graceful error handling |
| Five metric families | Covers structural, flow, cognitive, duplication, and information-theoretic dimensions | ✓ Good — comprehensive coverage, configurable weights let teams prioritize |
| Weighted composite score | Single "health score" lets teams customize what complexity means for them | ✓ Good — sigmoid normalization provides smooth 0-100 scoring |
| Optional chaining in cyclomatic | Configurable — debatable whether `?.` is a branch point | ✓ Good — configurable flag satisfies both camps |
| Hand-rolled CLI arg parser | zig-clap/yazap incompatible with Zig 0.15 API changes | ✓ Good — full control over ripgrep-style UX |
| ReleaseSmall over ReleaseSafe | ReleaseSafe binaries 9.1-9.2 MB exceed 5 MB limit | ✓ Good — 3.6-3.8 MB across all targets |
| Per-operator cognitive counting | Each &&/\|\|/?? counts +1 (deviation from SonarSource grouping) | ✓ Good — locked user decision, documented |
| Rabin-Karp for duplication | Rolling hash with configurable window for Type 1/2 clone detection | ✓ Good — cross-file detection with manageable performance overhead |
| Re-parse approach for duplication | Re-read files for tokenization after per-file metric analysis | ⚠️ Revisit — significant overhead on large projects (800%+ on some codebases) |

---
*Last updated: 2026-02-24 after v0.8 milestone start*
