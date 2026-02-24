# Roadmap: ComplexityGuard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-14 (shipped 2026-02-23)
- 🚧 **v0.8 Rust Rewrite** — Phases 17-22 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-14) — SHIPPED 2026-02-23</summary>

- [x] Phase 1: Project Foundation (3/3 plans) — completed 2026-02-14
- [x] Phase 2: CLI & Configuration (5/5 plans) — completed 2026-02-14
- [x] Phase 3: File Discovery & Parsing (3/3 plans) — completed 2026-02-14
- [x] Phase 4: Cyclomatic Complexity (2/2 plans) — completed 2026-02-14
- [x] Phase 5: Console & JSON Output (2/2 plans) — completed 2026-02-15
- [x] Phase 5.1: CI/CD, Release & Docs (6/6 plans) — completed 2026-02-15
- [x] Phase 6: Cognitive Complexity (3/3 plans) — completed 2026-02-17
- [x] Phase 7: Halstead & Structural Metrics (5/5 plans) — completed 2026-02-17
- [x] Phase 8: Composite Health Score (5/5 plans) — completed 2026-02-17
- [x] Phase 9: SARIF Output (2/2 plans) — completed 2026-02-18
- [x] Phase 10: HTML Reports (4/4 plans) — completed 2026-02-18
- [x] Phase 10.1: Performance Benchmarks (3/3 plans) — completed 2026-02-19
- [x] Phase 11: Duplication Detection (4/4 plans) — completed 2026-02-22
- [x] Phase 12: Parallelization & Distribution (2/2 plans) — completed 2026-02-21
- [x] Phase 13: Gap Closure — Pipeline Wiring (3/3 plans) — completed 2026-02-22
- [x] Phase 14: Tech Debt Cleanup (2/2 plans) — completed 2026-02-23

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v0.8 Rust Rewrite (In Progress)

**Milestone Goal:** Rewrite ComplexityGuard from Zig to Rust achieving 1:1 feature parity — same CLI interface, same output formats, same metrics, same exit codes — as a drop-in binary replacement.

- [x] **Phase 17: Project Setup and Parser Foundation** - Rust crate scaffolding, grammar version pinning, all four languages parsing against fixtures (completed 2026-02-24)
- [ ] **Phase 18: Core Metrics Pipeline** - All five metric families computing correct per-file output with JSON comparison against Zig v1.0
- [ ] **Phase 19: CLI, Config, and Output Formats** - Full CLI interface, config loading, all four output formats with exit code parity
- [ ] **Phase 20: Parallel Pipeline** - Rayon-based parallel file analysis with directory scanning and deterministic output ordering
- [ ] **Phase 21: Integration Testing and Behavioral Parity** - Complete behavioral parity validated against Zig binary across all fixtures and output formats
- [ ] **Phase 22: Cross-Compilation, CI, and Release** - Release binaries for all five targets, GitHub Actions CI, binary size measured

## Phase Details

### Phase 17: Project Setup and Parser Foundation
**Goal**: A compiling Rust crate where all four language grammars (TS, TSX, JS, JSX) parse real fixture files without errors, grammar version mismatches are eliminated, binary size profile is configured, and the `ParseResult` type returns only owned data safe for cross-thread use.
**Depends on**: Nothing (first phase of v0.8 milestone)
**Requirements**: PARSE-01, PARSE-02, PARSE-03, PARSE-04, PARSE-05
**Success Criteria** (what must be TRUE):
  1. Running `cargo build --release` produces a binary with no compile errors or warnings about grammar version mismatches
  2. The binary parses TypeScript, TSX, JavaScript, and JSX fixture files and extracts function names, line numbers, and column numbers without panicking
  3. `cargo tree -d` shows no duplicate tree-sitter dependency versions
  4. The release binary size is measured and recorded (baseline for tracking)
  5. At least one cross-compilation target (e.g. linux-x86_64-musl) builds successfully in CI
**Plans**: 3 plans
Plans:
- [ ] 17-01-PLAN.md — Rust crate scaffolding with grammar dependencies, types, and release profile
- [ ] 17-02-PLAN.md — Parser implementation with TDD against all four language fixtures
- [ ] 17-03-PLAN.md — GitHub Actions CI with cross-compilation smoke test

### Phase 18: Core Metrics Pipeline
**Goal**: All five metric families (cyclomatic, cognitive, Halstead, structural, duplication) produce per-file output that matches Zig v1.0 values for all fixture files, with JSON output enabling automated comparison and the per-file worker architecture already embedding tokenization so duplication needs no re-parse.
**Depends on**: Phase 17
**Requirements**: METR-01, METR-02, METR-03, METR-04, METR-05, METR-06
**Success Criteria** (what must be TRUE):
  1. Cyclomatic complexity values match Zig output exactly for all fixture files
  2. Cognitive complexity values match Zig output exactly, including the per-operator `&&`/`||`/`??` counting deviation from SonarSource spec
  3. Halstead metrics (volume, difficulty, effort, estimated bugs) match Zig output within defined float tolerance for all fixture files
  4. Structural metrics (function length, parameter count, nesting depth, file length, export count) match Zig output exactly
  5. Duplication clone groups (Type 1 and Type 2) match Zig output for cross-file fixture sets, with no re-parse pass required
  6. Composite health score matches Zig output within float tolerance for all fixture files
**Plans**: TBD

### Phase 19: CLI, Config, and Output Formats
**Goal**: The binary exposes an identical CLI interface to the Zig version, loads `.complexityguard.json` with CLI flags overriding config values, and produces all four output formats (console, JSON, SARIF 2.1.0, HTML) that match or are accepted by their respective consumers.
**Depends on**: Phase 18
**Requirements**: CLI-01, CLI-02, CLI-03, OUT-01, OUT-02, OUT-03, OUT-04, OUT-05
**Success Criteria** (what must be TRUE):
  1. All CLI flags from the Zig binary exist with identical names and semantics; passing `--help` shows the same options
  2. A `.complexityguard.json` config file is loaded correctly and CLI flags override its values when both are present
  3. Console output matches Zig ESLint-style format (same column layout, same severity labels, same per-function and per-file sections)
  4. JSON output matches Zig schema exactly — same field names, same nesting structure, same array ordering
  5. SARIF 2.1.0 output is accepted by GitHub Code Scanning without schema validation errors
  6. HTML report is self-contained (no external requests) with the same embedded JS/CSS as the Zig version
  7. Exit codes 0-4 are returned under the same conditions as the Zig binary (clean, warn, error, critical, fatal)
**Plans**: TBD

### Phase 20: Parallel Pipeline
**Goal**: File analysis runs in parallel across available CPU cores using rayon, directory scanning respects glob exclusions, output is always sorted by path regardless of completion order, and throughput matches or exceeds the Zig binary on representative fixtures.
**Depends on**: Phase 19
**Requirements**: PIPE-01, PIPE-02, PIPE-03
**Success Criteria** (what must be TRUE):
  1. Running the binary against a directory recursively discovers all TS/TSX/JS/JSX files and excludes paths matching configured glob patterns
  2. Analysis of a multi-file fixture set completes faster with `--threads 4` than with `--threads 1`, demonstrating parallel speedup
  3. Output file ordering is identical across multiple runs of the same input regardless of CPU scheduling
**Plans**: TBD

### Phase 21: Integration Testing and Behavioral Parity
**Goal**: A comprehensive integration test suite validates complete behavioral parity between the Rust binary and Zig v1.0 across all fixture files and all output formats, catching any metric deviations, float precision issues, serialization differences, or exit code discrepancies before release work begins.
**Depends on**: Phase 20
**Requirements**: (validation phase — exercises PARSE-01 through PIPE-03)
**Success Criteria** (what must be TRUE):
  1. Integration tests run the Rust binary against all fixture files and compare output to recorded Zig v1.0 baseline — all tests pass
  2. Exit code parity is confirmed for scenarios that trigger each of codes 0, 1, 2, 3, and 4
  3. Cognitive complexity deviation (per-operator counting) is validated by a dedicated test comparing Rust and Zig output on the same fixture
  4. Float tolerance is explicitly defined and documented in tests for all Halstead metric fields
**Plans**: TBD

### Phase 22: Cross-Compilation, CI, and Release
**Goal**: The CI pipeline builds release binaries for all five target platforms, each binary executes correctly on a native runner, binary sizes are measured and documented, and a GitHub release with attached binaries can be triggered from a version tag.
**Depends on**: Phase 21
**Requirements**: REL-01, REL-02, REL-03, REL-04, REL-05
**Success Criteria** (what must be TRUE):
  1. CI builds succeed for linux-x86_64-musl, linux-aarch64-musl, macos-x86_64, macos-aarch64, and windows-x86_64 targets
  2. Each built binary executes `--version` and produces correct output when run on a native runner of that platform
  3. Binary sizes for all five targets are recorded in documentation; the 5 MB target is assessed with actual measurements and any revised limit is documented
  4. Pushing a version tag triggers the release pipeline and attaches all five binaries to a GitHub Release
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 17 → 18 → 19 → 20 → 21 → 22

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Project Foundation | v1.0 | 3/3 | Complete | 2026-02-14 |
| 2. CLI & Configuration | v1.0 | 5/5 | Complete | 2026-02-14 |
| 3. File Discovery & Parsing | v1.0 | 3/3 | Complete | 2026-02-14 |
| 4. Cyclomatic Complexity | v1.0 | 2/2 | Complete | 2026-02-14 |
| 5. Console & JSON Output | v1.0 | 2/2 | Complete | 2026-02-15 |
| 5.1 CI/CD, Release & Docs | v1.0 | 6/6 | Complete | 2026-02-15 |
| 6. Cognitive Complexity | v1.0 | 3/3 | Complete | 2026-02-17 |
| 7. Halstead & Structural Metrics | v1.0 | 5/5 | Complete | 2026-02-17 |
| 8. Composite Health Score | v1.0 | 5/5 | Complete | 2026-02-17 |
| 9. SARIF Output | v1.0 | 2/2 | Complete | 2026-02-18 |
| 10. HTML Reports | v1.0 | 4/4 | Complete | 2026-02-18 |
| 10.1 Performance Benchmarks | v1.0 | 3/3 | Complete | 2026-02-19 |
| 11. Duplication Detection | v1.0 | 4/4 | Complete | 2026-02-22 |
| 12. Parallelization & Distribution | v1.0 | 2/2 | Complete | 2026-02-21 |
| 13. Gap Closure — Pipeline Wiring | v1.0 | 3/3 | Complete | 2026-02-22 |
| 14. Tech Debt Cleanup | v1.0 | 2/2 | Complete | 2026-02-23 |
| 17. Project Setup and Parser Foundation | 3/3 | Complete   | 2026-02-24 | - |
| 18. Core Metrics Pipeline | v0.8 | 0/TBD | Not started | - |
| 19. CLI, Config, and Output Formats | v0.8 | 0/TBD | Not started | - |
| 20. Parallel Pipeline | v0.8 | 0/TBD | Not started | - |
| 21. Integration Testing and Behavioral Parity | v0.8 | 0/TBD | Not started | - |
| 22. Cross-Compilation, CI, and Release | v0.8 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-14*
*Last updated: 2026-02-24 after v0.8 milestone roadmap creation*
