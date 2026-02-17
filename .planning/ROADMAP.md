# Roadmap: ComplexityGuard

## Overview

ComplexityGuard delivers fast, accurate complexity analysis for TypeScript/JavaScript projects through a single static binary. The journey starts with foundational infrastructure (build system, CLI, parsing), progresses through metric implementation (cyclomatic, cognitive, Halstead, structural), adds output formats (console, JSON, SARIF, HTML), implements cross-file duplication detection, and culminates in parallelization for sub-second performance on 10,000+ file codebases.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Project Foundation** - Build system, test infrastructure, core data structures ✓ 2026-02-14
- [x] **Phase 2: CLI & Configuration** - Argument parsing, config file loading, flag handling ✓ 2026-02-14
- [x] **Phase 3: File Discovery & Parsing** - Tree-sitter integration, recursive file scanning, error handling ✓ 2026-02-14
- [x] **Phase 4: Cyclomatic Complexity** - McCabe metric with threshold validation (vertical slice) ✓ 2026-02-14
- [x] **Phase 5: Console & JSON Output** - Primary developer and CI output formats ✓ 2026-02-15
- [ ] **Phase 5.1: CI/CD, Release Pipeline & Documentation** - Changelog, GitHub workflows, publishing, docs (INSERTED) -- gap closure in progress
- [x] **Phase 6: Cognitive Complexity** - SonarSource metric with nesting tracking (completed 2026-02-17)
- [x] **Phase 7: Halstead & Structural Metrics** - Information theory and structural metrics (completed 2026-02-17)
- [ ] **Phase 8: Composite Health Score** - Weighted scoring and letter grade assignment
- [ ] **Phase 9: SARIF Output** - GitHub Code Scanning integration
- [ ] **Phase 10: HTML Reports** - Self-contained visual reports for stakeholders
- [ ] **Phase 11: Duplication Detection** - Rabin-Karp cross-file clone analysis
- [ ] **Phase 12: Parallelization & Distribution** - Thread pool, performance tuning, cross-compilation

## Phase Details

### Phase 1: Project Foundation
**Goal**: Establish build system, core infrastructure, and test framework for all subsequent development
**Depends on**: Nothing (first phase)
**Requirements**: None (foundational infrastructure)
**Success Criteria** (what must be TRUE):
  1. Zig project builds successfully with `zig build` producing executable
  2. Test suite runs via `zig build test` with CI integration ready
  3. Core data structures (FileResult, FunctionResult, ProjectResult) exist and serialize to JSON
  4. Build produces single static binary under 5 MB target
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md -- Zig project skeleton with build system, entry point, and test runner
- [x] 01-02-PLAN.md -- Core data structures (FunctionResult, FileResult, ProjectResult) with TDD and JSON serialization
- [x] 01-03-PLAN.md -- Test infrastructure: helper builders and real-world TS/JS fixtures

### Phase 2: CLI & Configuration
**Goal**: Users can invoke complexityguard with flags and load configuration from files
**Depends on**: Phase 1
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-04, CLI-05, CLI-06, CLI-07, CLI-08, CLI-09, CLI-10, CLI-11, CLI-12, CFG-01, CFG-02, CFG-03, CFG-04, CFG-05, CFG-06, CFG-07
**Success Criteria** (what must be TRUE):
  1. User can run `complexityguard [paths...]` and see usage help
  2. User can specify all flags (--format, --output, --fail-on, --metrics, etc.) and flags override config file values
  3. Tool loads `.complexityguard.json` when present and validates schema
  4. Tool displays version with `--version` and help with `--help`
**Plans:** 5 plans

Plans:
- [x] 02-01-PLAN.md -- Dependencies, config types, and CLI argument parsing with zig-clap
- [x] 02-02-PLAN.md -- Config discovery (upward search, XDG) and loading (JSON + TOML) with validation
- [x] 02-03-PLAN.md -- Help output, version display, Levenshtein did-you-mean, color detection
- [x] 02-04-PLAN.md -- Merge logic (flags override config), --init command, main.zig integration
- [x] 02-05-PLAN.md -- End-to-end integration testing and human verification

### Phase 3: File Discovery & Parsing
**Goal**: Tool discovers TypeScript/JavaScript files and parses them into ASTs via tree-sitter
**Depends on**: Phase 2
**Requirements**: PARSE-01, PARSE-02, PARSE-03, PARSE-04, PARSE-05, PARSE-06
**Success Criteria** (what must be TRUE):
  1. Tool recursively discovers .ts, .tsx, .js, .jsx files in directories matching include/exclude patterns
  2. Tool parses each file via tree-sitter and produces valid AST
  3. Tool handles syntax errors gracefully (reports error, continues with other files)
  4. Tool integrates tree-sitter with proper memory cleanup (no leaks)
  5. Tool respects glob patterns from config file for file filtering
**Plans:** 3 plans

Plans:
- [x] 03-01-PLAN.md -- Vendor tree-sitter C libraries and create Zig bindings
- [x] 03-02-PLAN.md -- Recursive file discovery with extension filtering
- [x] 03-03-PLAN.md -- Parse orchestration, error handling, and main.zig integration

### Phase 4: Cyclomatic Complexity
**Goal**: Tool calculates McCabe cyclomatic complexity per function and validates against thresholds
**Depends on**: Phase 3
**Requirements**: CYCL-01, CYCL-02, CYCL-03, CYCL-04, CYCL-05, CYCL-06, CYCL-07, CYCL-08, CYCL-09
**Success Criteria** (what must be TRUE):
  1. Tool calculates cyclomatic complexity starting at base 1, incrementing for all control flow branches
  2. Tool handles logical operators (&&, ||, ??), ternary operators, and optional chaining per configuration
  3. Tool applies configurable warning and error thresholds per function
  4. Tool identifies function locations (file path, line number, column number) in results
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md -- Cyclomatic complexity calculator with function extraction, decision point counting, and test fixtures
- [x] 04-02-PLAN.md -- Threshold validation, FunctionResult population, and main.zig pipeline integration

### Phase 5: Console & JSON Output
**Goal**: Tool displays results in terminal and outputs machine-readable JSON for CI integration
**Depends on**: Phase 4
**Requirements**: OUT-CON-01, OUT-CON-02, OUT-CON-03, OUT-CON-04, OUT-JSON-01, OUT-JSON-02, OUT-JSON-03, CI-01, CI-02, CI-03, CI-04, CI-05
**Success Criteria** (what must be TRUE):
  1. Tool displays per-file, per-function metric summaries with threshold indicators in console
  2. Tool displays project summary (files analyzed, functions found, health score (when available), grade (when available))
  3. Tool supports --verbose (per-function detail) and --quiet (errors only) modes
  4. Tool outputs valid JSON with version, timestamp, summary, files, and metrics
  5. Tool exits with appropriate codes (0=pass, 1=errors, 2=warnings, 3=config errors, 4=parse errors)
  6. Output layer handles optional (`null`) metrics gracefully — metrics not yet computed display as `--` or are omitted
**Plans:** 2 plans

Plans:
- [x] 05-01-PLAN.md -- Console output formatter (ESLint-style) and exit code logic
- [x] 05-02-PLAN.md -- JSON output format and main.zig pipeline integration

### Phase 05.1: CI/CD, Release Pipeline & Documentation (INSERTED)

**Goal:** Set up changelog, release automation, CI test pipelines, multi-channel distribution (npm, Homebrew, GitHub releases), and progressive disclosure documentation
**Depends on:** Phase 5
**Plans:** 6/6 plans complete

Plans:
- [x] 05.1-01-PLAN.md -- Release infrastructure: CHANGELOG.md, release script, CI test workflow
- [x] 05.1-02-PLAN.md -- npm platform packages and Homebrew formula template
- [x] 05.1-03-PLAN.md -- Documentation: README rewrite and docs/ pages (getting started, CLI reference, examples)
- [x] 05.1-04-PLAN.md -- GitHub Actions release workflow (build, publish, distribute)
- [x] 05.1-05-PLAN.md -- Gap closure: move publication files to publication/ directory (structural refactor)
- [x] 05.1-06-PLAN.md -- Gap closure: release process documentation (docs/releasing.md) and Homebrew SHA256 docs

### Phase 6: Cognitive Complexity
**Goal**: Tool calculates SonarSource cognitive complexity with nesting penalties
**Depends on**: Phase 5
**Requirements**: COGN-01, COGN-02, COGN-03, COGN-04, COGN-05, COGN-06, COGN-07, COGN-08, COGN-09
**Success Criteria** (what must be TRUE):
  1. Tool increments for flow breaks (if, else if, switch, loops, catch, ternary) with nesting depth penalties
  2. Tool tracks nesting level correctly across nested structures (functions, conditionals, loops)
  3. Tool handles logical operator sequences (same-operator vs mixed-operator counting)
  4. Tool increments for recursive function calls
  5. Tool applies configurable warning and error thresholds
**Plans:** 3/3 plans complete

Plans:
- [x] 06-01-PLAN.md -- Core cognitive complexity algorithm, test fixture, and ThresholdResult extension
- [x] 06-02-PLAN.md -- Pipeline integration (main.zig, console, JSON, exit codes)
- [x] 06-03-PLAN.md -- Documentation (cognitive/cyclomatic docs pages, README, docs updates)

### Phase 7: Halstead & Structural Metrics
**Goal**: Tool measures information-theoretic complexity and structural properties per function
**Depends on**: Phase 6
**Requirements**: HALT-01, HALT-02, HALT-03, HALT-04, HALT-05, STRC-01, STRC-02, STRC-03, STRC-04, STRC-05, STRC-06
**Success Criteria** (what must be TRUE):
  1. Tool classifies tokens as operators/operands and computes Halstead metrics (vocabulary, volume, difficulty, effort, estimated bugs)
  2. Tool handles edge cases without divide-by-zero errors
  3. Tool measures structural properties (function length, parameter count, nesting depth, file length, export count)
  4. Tool applies configurable thresholds for all Halstead and structural metrics
**Plans:** 4/4 plans complete

Plans:
- [ ] 07-01-PLAN.md -- Halstead metrics core: token classification, counting, and formula computation (TDD)
- [ ] 07-02-PLAN.md -- Structural metrics core: logical lines, params, nesting, file length, exports (TDD)
- [ ] 07-03-PLAN.md -- Pipeline integration: ThresholdResult extension, main.zig wiring, console/JSON output, --metrics flag
- [ ] 07-04-PLAN.md -- Documentation: Halstead/structural docs pages, README, CLI reference, examples

### Phase 8: Composite Health Score
**Goal**: Tool computes weighted composite health score (0-100) per file and project with letter grades
**Depends on**: Phase 7
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04
**Success Criteria** (what must be TRUE):
  1. Tool computes weighted composite score per file using configurable weights across all metric categories
  2. Tool computes project-wide composite score aggregating all files
  3. Tool assigns letter grades (A-F) based on score thresholds
  4. Tool uses default weights (cognitive 0.30, cyclomatic 0.20, duplication 0.20, Halstead 0.15, structural 0.15) unless overridden
**Plans**: TBD

Plans: (to be created during /gsd:plan-phase)

### Phase 9: SARIF Output
**Goal**: Tool outputs SARIF 2.1.0 format accepted by GitHub Code Scanning
**Depends on**: Phase 8
**Requirements**: OUT-SARIF-01, OUT-SARIF-02, OUT-SARIF-03, OUT-SARIF-04
**Success Criteria** (what must be TRUE):
  1. Tool outputs valid SARIF 2.1.0 with schema, version, and runs array
  2. Tool maps each metric violation to SARIF result with ruleId, level, and physicalLocation
  3. Tool uses 1-indexed line/column numbers in SARIF locations
  4. Tool output passes GitHub Code Scanning upload validation
**Plans**: TBD

Plans: (to be created during /gsd:plan-phase)

### Phase 10: HTML Reports
**Goal**: Tool generates self-contained HTML reports with interactive visualizations
**Depends on**: Phase 9
**Requirements**: OUT-HTML-01, OUT-HTML-02, OUT-HTML-03, OUT-HTML-04
**Success Criteria** (what must be TRUE):
  1. Tool generates single-file HTML report with inline CSS and JavaScript
  2. Tool includes project summary dashboard with health score and grade
  3. Tool includes per-file breakdown with expandable function details
  4. Tool provides sortable tables by any metric column
**Plans**: TBD

Plans: (to be created during /gsd:plan-phase)

### Phase 11: Duplication Detection
**Goal**: Tool detects code clones across files using Rabin-Karp rolling hash
**Depends on**: Phase 10
**Requirements**: DUP-01, DUP-02, DUP-03, DUP-04, DUP-05, DUP-06, DUP-07
**Success Criteria** (what must be TRUE):
  1. Tool tokenizes files stripping comments/whitespace and normalizes identifiers for Type 2 clones
  2. Tool computes Rabin-Karp rolling hash with configurable minimum window (default 25 tokens)
  3. Tool builds cross-file hash index and verifies matches token-by-token
  4. Tool merges overlapping matches into maximal clone groups
  5. Tool reports clone groups with locations, token counts, and duplication percentages
  6. Tool applies configurable thresholds for file and project duplication percentages
**Plans**: TBD

Plans: (to be created during /gsd:plan-phase)

### Phase 12: Parallelization & Distribution
**Goal**: Tool analyzes 10,000 files in under 2 seconds and cross-compiles to all target platforms
**Depends on**: Phase 11
**Requirements**: PERF-01, PERF-02, DIST-01, DIST-02
**Success Criteria** (what must be TRUE):
  1. Tool processes files in parallel via thread pool with configurable thread count
  2. Tool analyzes 10,000 TypeScript files in under 2 seconds on modern hardware
  3. Tool compiles to single static binary under 5 MB for x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows
  4. Tool runs successfully on all target platforms without runtime dependencies
**Plans**: TBD

Plans: (to be created during /gsd:plan-phase)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Foundation | 3/3 | ✓ Complete | 2026-02-14 |
| 2. CLI & Configuration | 5/5 | ✓ Complete | 2026-02-14 |
| 3. File Discovery & Parsing | 3/3 | ✓ Complete | 2026-02-14 |
| 4. Cyclomatic Complexity | 2/2 | ✓ Complete | 2026-02-14 |
| 5. Console & JSON Output | 2/2 | ✓ Complete | 2026-02-15 |
| 5.1 CI/CD, Release & Docs | 6/6 | ✓ Complete | 2026-02-15 |
| 6. Cognitive Complexity | 0/3 | Complete    | 2026-02-17 |
| 7. Halstead & Structural Metrics | 0/4 | Complete    | 2026-02-17 |
| 8. Composite Health Score | 0/TBD | Not started | - |
| 9. SARIF Output | 0/TBD | Not started | - |
| 10. HTML Reports | 0/TBD | Not started | - |
| 11. Duplication Detection | 0/TBD | Not started | - |
| 12. Parallelization & Distribution | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-14*
*Last updated: 2026-02-17 (Phase 6 plans created)*
