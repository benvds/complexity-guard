# Requirements: ComplexityGuard

**Defined:** 2026-02-14
**Core Value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### CLI & Configuration

- [ ] **CLI-01**: User can run `complexityguard [paths...]` to analyze files/directories
- [ ] **CLI-02**: User can specify output format via `--format` flag (console, json, sarif, html)
- [ ] **CLI-03**: User can write report to file via `--output` flag
- [ ] **CLI-04**: User can set failure level via `--fail-on` flag (warning, error, none)
- [ ] **CLI-05**: User can set health score threshold via `--fail-health-below` flag
- [ ] **CLI-06**: User can filter files via `--include` and `--exclude` glob flags
- [ ] **CLI-07**: User can select specific metrics via `--metrics` flag
- [ ] **CLI-08**: User can skip duplication via `--no-duplication` flag
- [ ] **CLI-09**: User can set thread count via `--threads` flag
- [ ] **CLI-10**: User can compare against baseline via `--baseline` flag
- [ ] **CLI-11**: User can control verbosity via `--verbose` and `--quiet` flags
- [ ] **CLI-12**: User can display version via `--version` and help via `--help`

### Configuration File

- [ ] **CFG-01**: Tool loads configuration from `.complexityguard.json` when present
- [ ] **CFG-02**: User can specify custom config path via `--config` flag
- [ ] **CFG-03**: User can set include/exclude glob patterns in config file
- [ ] **CFG-04**: User can set per-metric warning and error thresholds in config file
- [ ] **CFG-05**: User can set composite score weights in config file
- [ ] **CFG-06**: User can set CI failure behavior in config file
- [ ] **CFG-07**: CLI flags override config file values

### Parsing

- [ ] **PARSE-01**: Tool parses TypeScript files (.ts) via tree-sitter
- [ ] **PARSE-02**: Tool parses TSX files (.tsx) via tree-sitter
- [ ] **PARSE-03**: Tool parses JavaScript files (.js) via tree-sitter
- [ ] **PARSE-04**: Tool parses JSX files (.jsx) via tree-sitter
- [ ] **PARSE-05**: Tool handles syntax errors gracefully (skips or best-effort, reports in output)
- [ ] **PARSE-06**: Tool recursively discovers files in directories matching include/exclude patterns

### Cyclomatic Complexity

- [ ] **CYCL-01**: Tool calculates McCabe cyclomatic complexity per function starting at base 1
- [ ] **CYCL-02**: Tool increments for if, else if, for, for-in, for-of, while, do-while
- [ ] **CYCL-03**: Tool increments for switch cases (not default)
- [ ] **CYCL-04**: Tool increments for catch clauses
- [ ] **CYCL-05**: Tool increments for ternary operators
- [ ] **CYCL-06**: Tool increments for logical && and || operators
- [ ] **CYCL-07**: Tool increments for nullish coalescing (??) operator
- [ ] **CYCL-08**: Tool makes optional chaining (?.) counting configurable
- [ ] **CYCL-09**: Tool applies configurable warning (default 10) and error (default 20) thresholds

### Cognitive Complexity

- [ ] **COGN-01**: Tool calculates SonarSource cognitive complexity per function
- [ ] **COGN-02**: Tool increments for flow breaks (if, else if, else, switch, loops, catch, ternary, labeled break/continue)
- [ ] **COGN-03**: Tool adds nesting penalty equal to current nesting depth for nested structures
- [ ] **COGN-04**: Tool tracks nesting level increases for if, else if, else, switch, loops, catch, ternary, arrow functions
- [ ] **COGN-05**: Tool counts same-operator logical sequences as +1 (e.g., a && b && c = +1)
- [ ] **COGN-06**: Tool increments on operator type changes in mixed sequences (e.g., a && b || c = +2)
- [ ] **COGN-07**: Tool increments +1 for recursive function calls
- [ ] **COGN-08**: Tool does not increment for null coalescing or optional chaining (shorthand rule)
- [ ] **COGN-09**: Tool applies configurable warning (default 15) and error (default 25) thresholds

### Halstead Metrics

- [ ] **HALT-01**: Tool classifies tokens as operators or operands per TypeScript/JavaScript definitions
- [ ] **HALT-02**: Tool computes distinct operators (n1), distinct operands (n2), total operators (N1), total operands (N2)
- [ ] **HALT-03**: Tool derives vocabulary, length, volume, difficulty, effort, time-to-program, estimated bugs
- [ ] **HALT-04**: Tool handles edge cases (zero operands/operators) without divide-by-zero errors
- [ ] **HALT-05**: Tool applies configurable thresholds for volume, difficulty, effort, and estimated bugs

### Duplication Detection

- [x] **DUP-01**: Tool tokenizes source files stripping comments and whitespace
- [x] **DUP-02**: Tool normalizes identifiers for Type 2 clone detection
- [x] **DUP-03**: Tool uses Rabin-Karp rolling hash with configurable minimum window (default 25 tokens)
- [x] **DUP-04**: Tool builds cross-file hash index and verifies matches token-by-token
- [x] **DUP-05**: Tool merges overlapping matches into maximal clone groups
- [ ] **DUP-06**: Tool reports clone groups with locations, token counts, and duplication percentages
- [ ] **DUP-07**: Tool applies configurable thresholds for file duplication % and project duplication %

### Structural Metrics

- [ ] **STRC-01**: Tool measures function length (logical lines, excluding blanks/comments) per function
- [ ] **STRC-02**: Tool measures parameter count per function
- [ ] **STRC-03**: Tool measures maximum nesting depth per function
- [ ] **STRC-04**: Tool measures file length (logical lines) per file
- [ ] **STRC-05**: Tool measures export count per file
- [ ] **STRC-06**: Tool applies configurable warning and error thresholds for each structural metric

### Composite Health Score

- [ ] **COMP-01**: Tool computes weighted composite score (0-100) per file
- [ ] **COMP-02**: Tool computes weighted composite score (0-100) for entire project
- [ ] **COMP-03**: Tool uses configurable weights (default: cognitive 0.30, cyclomatic 0.20, duplication 0.20, halstead 0.15, structural 0.15)
- [ ] **COMP-04**: Tool assigns letter grade (A-F) based on score thresholds

### Output: Console

- [ ] **OUT-CON-01**: Tool displays per-file, per-function metric summaries with threshold indicators
- [ ] **OUT-CON-02**: Tool displays project summary (files, functions, health score, grade)
- [ ] **OUT-CON-03**: Tool displays error/warning counts per metric category
- [ ] **OUT-CON-04**: Tool supports --verbose (per-function detail) and --quiet (errors only) modes

### Output: JSON

- [ ] **OUT-JSON-01**: Tool outputs valid JSON with version, timestamp, summary, files, and duplication sections
- [ ] **OUT-JSON-02**: Tool includes per-function metrics with threshold levels in JSON
- [ ] **OUT-JSON-03**: Tool includes clone group details with file locations in JSON

### Output: SARIF

- [x] **OUT-SARIF-01**: Tool outputs valid SARIF 2.1.0 with $schema, version, and runs array
- [x] **OUT-SARIF-02**: Tool maps each metric violation to a SARIF result with ruleId, level, and physicalLocation
- [x] **OUT-SARIF-03**: Tool uses 1-indexed line/column numbers in SARIF locations
- [x] **OUT-SARIF-04**: Tool output is accepted by GitHub Code Scanning upload

### Output: HTML

- [x] **OUT-HTML-01**: Tool generates self-contained single-file HTML report (inline CSS/JS)
- [x] **OUT-HTML-02**: Tool includes project summary dashboard with health score and grade
- [x] **OUT-HTML-03**: Tool includes per-file breakdown with expandable function details
- [x] **OUT-HTML-04**: Tool includes sortable tables by any metric

### CI Integration

- [ ] **CI-01**: Tool exits with code 0 when all checks pass
- [ ] **CI-02**: Tool exits with code 1 when errors found (or health below threshold)
- [ ] **CI-03**: Tool exits with code 2 when warnings found (if --fail-on warning)
- [ ] **CI-04**: Tool exits with code 3 on configuration errors
- [ ] **CI-05**: Tool exits with code 4 on parse errors

### Performance & Distribution

- [x] **PERF-01**: Tool analyzes 10,000 TypeScript files in under 2 seconds
- [x] **PERF-02**: Tool processes files in parallel via thread pool
- [x] **DIST-01**: Tool compiles to single static binary under 5 MB
- [x] **DIST-02**: Tool cross-compiles to x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Editor Integration

- **LSP-01**: Tool runs as LSP server via `complexityguard lsp`
- **LSP-02**: Tool shows complexity warnings/errors as inline diagnostics
- **LSP-03**: Tool displays complexity scores as code lenses above functions
- **LSP-04**: Tool shows detailed metric breakdown on function name hover

### Development Workflow

- **WATCH-01**: Tool watches files and re-analyzes on change
- **DIFF-01**: Tool only flags new complexity when given a baseline (diff mode)
- **BLAME-01**: Tool shows who introduced complexity via git blame integration

### Distribution

- **PKG-01**: Tool available via npm wrapper (`npx complexityguard`)
- **PKG-02**: Tool available via Homebrew tap
- **PKG-03**: Tool available via AUR package

## Out of Scope

| Feature | Reason |
|---------|--------|
| Vue SFC support | Different parser needed, may add later based on demand |
| Type-checking / semantic analysis | Syntax-only tool by design — no type resolution |
| Bug detection / security scanning | Not a linter or security tool — focused on complexity metrics |
| Auto-fix suggestions | Analysis only — let developers decide how to refactor |
| Type-level complexity metrics | TypeScript type expressions are complex but v2+ feature |
| Multi-language support (Python, Go, etc.) | Master TS/JS first, each language needs dedicated grammar integration |
| Cloud/SaaS platform | Local-first tool — users own their data |
| IDE plugins | Provide LSP server (v2), let IDE ecosystem handle UI |
| Plugin architecture for custom metrics | Adds API surface, versioning complexity — built-in metrics only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLI-01 | Phase 2 | Pending |
| CLI-02 | Phase 2 | Pending |
| CLI-03 | Phase 2 | Pending |
| CLI-04 | Phase 2 | Pending |
| CLI-05 | Phase 2 | Pending |
| CLI-06 | Phase 2 | Pending |
| CLI-07 | Phase 2 | Pending |
| CLI-08 | Phase 2 | Pending |
| CLI-09 | Phase 2 | Pending |
| CLI-10 | Phase 2 | Pending |
| CLI-11 | Phase 2 | Pending |
| CLI-12 | Phase 2 | Pending |
| CFG-01 | Phase 2 | Pending |
| CFG-02 | Phase 2 | Pending |
| CFG-03 | Phase 2 | Pending |
| CFG-04 | Phase 2 | Pending |
| CFG-05 | Phase 2 | Pending |
| CFG-06 | Phase 2 | Pending |
| CFG-07 | Phase 2 | Pending |
| PARSE-01 | Phase 3 | Pending |
| PARSE-02 | Phase 3 | Pending |
| PARSE-03 | Phase 3 | Pending |
| PARSE-04 | Phase 3 | Pending |
| PARSE-05 | Phase 3 | Pending |
| PARSE-06 | Phase 3 | Pending |
| CYCL-01 | Phase 4 | Pending |
| CYCL-02 | Phase 4 | Pending |
| CYCL-03 | Phase 4 | Pending |
| CYCL-04 | Phase 4 | Pending |
| CYCL-05 | Phase 4 | Pending |
| CYCL-06 | Phase 4 | Pending |
| CYCL-07 | Phase 4 | Pending |
| CYCL-08 | Phase 4 | Pending |
| CYCL-09 | Phase 4 | Pending |
| COGN-01 | Phase 5 | Pending |
| COGN-02 | Phase 5 | Pending |
| COGN-03 | Phase 5 | Pending |
| COGN-04 | Phase 5 | Pending |
| COGN-05 | Phase 5 | Pending |
| COGN-06 | Phase 5 | Pending |
| COGN-07 | Phase 5 | Pending |
| COGN-08 | Phase 5 | Pending |
| COGN-09 | Phase 5 | Pending |
| HALT-01 | Phase 6 | Pending |
| HALT-02 | Phase 6 | Pending |
| HALT-03 | Phase 6 | Pending |
| HALT-04 | Phase 6 | Pending |
| HALT-05 | Phase 6 | Pending |
| STRC-01 | Phase 6 | Pending |
| STRC-02 | Phase 6 | Pending |
| STRC-03 | Phase 6 | Pending |
| STRC-04 | Phase 6 | Pending |
| STRC-05 | Phase 6 | Pending |
| STRC-06 | Phase 6 | Pending |
| COMP-01 | Phase 7 | Pending |
| COMP-02 | Phase 7 | Pending |
| COMP-03 | Phase 7 | Pending |
| COMP-04 | Phase 7 | Pending |
| OUT-CON-01 | Phase 8 | Pending |
| OUT-CON-02 | Phase 8 | Pending |
| OUT-CON-03 | Phase 8 | Pending |
| OUT-CON-04 | Phase 8 | Pending |
| OUT-JSON-01 | Phase 8 | Pending |
| OUT-JSON-02 | Phase 8 | Pending |
| OUT-JSON-03 | Phase 8 | Pending |
| CI-01 | Phase 8 | Pending |
| CI-02 | Phase 8 | Pending |
| CI-03 | Phase 8 | Pending |
| CI-04 | Phase 8 | Pending |
| CI-05 | Phase 8 | Pending |
| OUT-SARIF-01 | Phase 9 | Complete |
| OUT-SARIF-02 | Phase 9 | Complete |
| OUT-SARIF-03 | Phase 9 | Complete |
| OUT-SARIF-04 | Phase 9 | Complete |
| OUT-HTML-01 | Phase 10 | Complete |
| OUT-HTML-02 | Phase 10 | Complete |
| OUT-HTML-03 | Phase 10 | Complete |
| OUT-HTML-04 | Phase 10 | Complete |
| DUP-01 | Phase 11 | Complete |
| DUP-02 | Phase 11 | Complete |
| DUP-03 | Phase 11 | Complete |
| DUP-04 | Phase 11 | Complete |
| DUP-05 | Phase 11 | Complete |
| DUP-06 | Phase 11 | Pending |
| DUP-07 | Phase 11 | Pending |
| PERF-01 | Phase 12 | Complete |
| PERF-02 | Phase 12 | Complete |
| DIST-01 | Phase 12 | Complete |
| DIST-02 | Phase 12 | Complete |

**Coverage:**
- v1 requirements: 72 total
- Mapped to phases: 72
- Unmapped: 0

**Phase requirement counts:**
- Phase 1: 0 requirements (foundational infrastructure)
- Phase 2: 19 requirements (CLI + Config)
- Phase 3: 6 requirements (Parsing)
- Phase 4: 9 requirements (Cyclomatic)
- Phase 5: 9 requirements (Cognitive)
- Phase 6: 11 requirements (Halstead + Structural)
- Phase 7: 4 requirements (Composite)
- Phase 8: 12 requirements (Console + JSON + CI)
- Phase 9: 4 requirements (SARIF)
- Phase 10: 4 requirements (HTML)
- Phase 11: 7 requirements (Duplication)
- Phase 12: 4 requirements (Performance + Distribution)

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-14 after roadmap creation*
