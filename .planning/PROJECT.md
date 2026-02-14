# ComplexityGuard

## What This Is

A fast, cross-platform code complexity analyzer for TypeScript/JavaScript projects. A single zero-dependency binary (compiled from Zig) that runs complexity analysis at linter speed, outputs SARIF/JSON/HTML reports, integrates with CI and editors, and gives teams configurable weighted scoring across multiple complexity dimensions. Targets solo developers, small teams, and CI/CD pipelines that want SonarCloud-level insight without the SaaS cost.

## Core Value

Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] CLI tool with file/directory scanning for TS/TSX/JS/JSX
- [ ] Tree-sitter-based parsing pipeline
- [ ] Cyclomatic complexity (McCabe) metric with configurable thresholds
- [ ] Cognitive complexity (SonarSource) metric with nesting penalties
- [ ] Halstead complexity metrics (volume, difficulty, effort, estimated bugs)
- [ ] Duplication detection via Rabin-Karp rolling hashes (Type 1 & 2 clones)
- [ ] Structural metrics (function length, parameter count, nesting depth, file length, export count)
- [ ] Composite weighted health score (0-100) with configurable weights
- [ ] Console output with per-function/per-file summaries
- [ ] JSON output format
- [ ] SARIF 2.1.0 output for GitHub Code Scanning integration
- [ ] Self-contained HTML report output
- [ ] Configuration via `.complexityguard.json`
- [ ] CLI flags for all config options
- [ ] Exit codes for CI/CD gating (0-4)
- [ ] Parallel file analysis via thread pool
- [ ] Cross-compilation to Linux/macOS/Windows (x86_64 + aarch64)
- [ ] Single static binary under 5 MB

### Out of Scope

- LSP server / editor integration — deferred to v1.x
- Watch mode — deferred to v1.x
- Baseline/diff mode — deferred to v1.x
- Git blame integration — deferred to v1.x
- Vue SFC support — may add later
- Type-checking or semantic analysis — syntax-only tool
- Bug detection or security scanning — not a linter
- Auto-fix suggestions — analysis only
- Type-level complexity metrics — v2 feature

## Context

- **Language choice:** Zig for single static binary, C ABI compatibility with tree-sitter, fast compile times, no runtime dependencies
- **Parsing:** tree-sitter provides proven TypeScript/TSX/JS/JSX grammars with error-tolerant and incremental parsing
- **Performance target:** < 1 second for 10,000 files on modern hardware
- **Accuracy target:** Cyclomatic and cognitive complexity scores within ±5% of SonarQube on 1000+ function test corpus
- **Metric algorithms are well-specified:** McCabe 1976, SonarSource 2016, Halstead 1977, Rabin-Karp for duplication
- **Distribution:** GitHub Releases, npm wrapper, Homebrew tap, AUR package

## Constraints

- **Tech stack**: Zig + tree-sitter — chosen for single-binary output and C interop
- **Binary size**: Under 5 MB with tree-sitter grammars compiled in
- **Performance**: Must analyze 10,000 TS files in under 2 seconds
- **Compatibility**: Must produce valid SARIF 2.1.0 accepted by GitHub Code Scanning
- **Parsing**: Syntax-only analysis, no type resolution or semantic analysis

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Zig over Rust | Faster compile times, simpler C interop for tree-sitter, single static binary | — Pending |
| tree-sitter for parsing | Proven grammars, error-tolerant, incremental (useful for future LSP), C library | — Pending |
| Five metric families | Covers structural, flow, cognitive, duplication, and information-theoretic dimensions | — Pending |
| Weighted composite score | Single "health score" lets teams customize what complexity means for them | — Pending |
| Optional chaining in cyclomatic | Configurable — debatable whether `?.` is a branch point | — Pending |

---
*Last updated: 2026-02-14 after initialization*
