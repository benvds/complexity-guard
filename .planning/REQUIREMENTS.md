# Requirements: ComplexityGuard v0.8 Rust Rewrite

**Defined:** 2026-02-24
**Core Value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.

## v0.8 Requirements

Requirements for the Rust rewrite. Each maps to roadmap phases. Goal: 1:1 feature parity with Zig v1.0 binary.

### Parsing

- [x] **PARSE-01**: Binary parses TypeScript files using tree-sitter-typescript
- [x] **PARSE-02**: Binary parses TSX files using tree-sitter-typescript
- [x] **PARSE-03**: Binary parses JavaScript files using tree-sitter-javascript
- [x] **PARSE-04**: Binary parses JSX files using tree-sitter-javascript
- [x] **PARSE-05**: Parser extracts function declarations with name, line, and column

### Metrics

- [x] **METR-01**: Cyclomatic complexity matches Zig output for all fixture files
- [x] **METR-02**: Cognitive complexity matches Zig output (including per-operator counting deviation)
- [x] **METR-03**: Halstead metrics match Zig output within float tolerance
- [x] **METR-04**: Structural metrics (length, params, nesting, exports) match Zig output
- [x] **METR-05**: Duplication detection (Rabin-Karp, Type 1 & 2) matches Zig clone groups
- [x] **METR-06**: Composite health score (sigmoid normalization) matches Zig output within tolerance

### CLI & Config

- [x] **CLI-01**: Same CLI flags as Zig binary (all options preserved)
- [x] **CLI-02**: `.complexityguard.json` config loading with same schema
- [x] **CLI-03**: CLI flags override config file values

### Output

- [x] **OUT-01**: Console output matches Zig ESLint-style format
- [x] **OUT-02**: JSON output matches Zig schema (field names, structure)
- [x] **OUT-03**: SARIF 2.1.0 output accepted by GitHub Code Scanning
- [x] **OUT-04**: HTML report is self-contained with same embedded JS/CSS
- [x] **OUT-05**: Exit codes 0-4 match Zig semantics

### Pipeline

- [x] **PIPE-01**: Recursive directory scanning with glob exclusion
- [x] **PIPE-02**: Parallel file analysis with configurable thread count
- [x] **PIPE-03**: Deterministic output ordering (sorted by path)

### Release

- [ ] **REL-01**: Cross-compilation to Linux x86_64 and aarch64
- [ ] **REL-02**: Cross-compilation to macOS x86_64 and aarch64
- [ ] **REL-03**: Cross-compilation to Windows x86_64
- [ ] **REL-04**: GitHub Actions CI pipeline with test + release
- [ ] **REL-05**: Binary size measured and documented

## Future Requirements

Deferred to after Rust rewrite stabilizes.

### Distribution

- **DIST-01**: npm wrapper packages for platform-specific binaries
- **DIST-02**: Homebrew tap formula

### Performance

- **PERF-01**: Fix duplication re-parse overhead (single-pass tokenization)

## Out of Scope

| Feature | Reason |
|---------|--------|
| New metrics beyond v1.0 | Strict feature freeze during rewrite |
| LSP server / editor integration | Deferred post-rewrite |
| Watch mode | Deferred post-rewrite |
| Baseline/diff mode | Deferred post-rewrite |
| Async/tokio parallelism | CPU-bound workload; rayon is correct |
| Plugin API / custom metrics | Built-in metrics only |
| Type-aware semantic analysis | Syntax-only tool by design |
| npm distribution | After Rust binary stabilizes |
| Windows aarch64 | cargo-zigbuild limitation; defer |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PARSE-01 | Phase 17 | Complete |
| PARSE-02 | Phase 17 | Complete |
| PARSE-03 | Phase 17 | Complete |
| PARSE-04 | Phase 17 | Complete |
| PARSE-05 | Phase 17 | Complete |
| METR-01 | Phase 18 | Complete |
| METR-02 | Phase 18 | Complete |
| METR-03 | Phase 18 | Complete |
| METR-04 | Phase 18 | Complete |
| METR-05 | Phase 18 | Complete |
| METR-06 | Phase 18 | Complete |
| CLI-01 | Phase 19 | Complete |
| CLI-02 | Phase 19 | Complete |
| CLI-03 | Phase 19 | Complete |
| OUT-01 | Phase 19 | Complete |
| OUT-02 | Phase 19 | Complete |
| OUT-03 | Phase 19 | Complete |
| OUT-04 | Phase 19 | Complete |
| OUT-05 | Phase 19 | Complete |
| PIPE-01 | Phase 20 | Complete |
| PIPE-02 | Phase 20 | Complete |
| PIPE-03 | Phase 20 | Complete |
| REL-01 | Phase 22 | Pending |
| REL-02 | Phase 22 | Pending |
| REL-03 | Phase 22 | Pending |
| REL-04 | Phase 22 | Pending |
| REL-05 | Phase 22 | Pending |

**Coverage:**
- v0.8 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 after roadmap creation (traceability complete)*
