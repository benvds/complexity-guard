# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.
**Current focus:** v0.8 Rust Rewrite — Phase 21: Integration Testing and Behavioral Parity — Plans 01-02 complete (2/3)

## Current Position

Phase: 21 of 22 (Integration Testing and Behavioral Parity)
Plan: 2 of 3 in current phase — 21-01 and 21-02 complete
Status: Phase 21 IN PROGRESS — plans 01-02 done (metric/schema bugs + console format + function naming)
Last activity: 2026-02-25 — Phase 21 plan 02 complete (console output consolidated format, callback/export function naming)

Progress: [████████░░] 65% (v0.8 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 11 (v0.8)
- Average duration: 8 min
- Total execution time: 91 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | 3/3 | 10 min | 3 min |
| 18 | 3/3 | 30 min | 10 min |
| 19 | 4/4 | 19 min | 5 min |
| 20 | 2/2 | 6 min | 3 min |
| 21 | 2/3 | 39 min | 20 min |

**Recent Trend:**
- Last 5 plans: 20-01 (3 min), 20-02 (3 min), 21-01 (12 min), 21-02 (27 min)
- Trend: Increasing (complex behavioral parity work)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full v1.0 decision log archived in `.planning/milestones/v1.0-phases/` SUMMARY.md files.
Key decisions in PROJECT.md Key Decisions table.

Recent decisions affecting v0.8:
- Duplication tokenization in per-file worker (Phase 18) — avoids 800%+ re-parse overhead from Zig version
- Grammar version pinning required in Phase 17 — tree-sitter core + grammar crates must share same version range
- Binary size optimized profile (`opt-level = "z"`, `lto = true`, `strip = true`) in Cargo.toml from Phase 17
- cargo-zigbuild for Linux/macOS targets, native windows-latest runner for Windows — split CI matrix
- 279 KB baseline binary size on macOS arm64 (Phase 17, stub only) — well under 5 MB target
- Zero duplicate tree-sitter versions confirmed via cargo tree -d — no patching needed
- Avoided serde-sarif in Phase 19 — hand-rolled SARIF structs with serde instead (per research recommendation)
- Phase 19 doc updates deferred publication READMEs to Phase 22 (Rust binary not yet shipped)
- [Phase 19-01]: clap derive #[command(version)] handles --version automatically; tempfile added as dev-dependency for discovery tests; fail_on 'none' override checked first in exit code priority; Config overlay in main.rs is field-by-field merge to preserve defaults
- [Phase 19-02]: ResolvedConfig added to cli/config.rs as flat non-optional struct with resolve_config(); function_violations() reused between console and JSON renderers; summary status uses 'pass' (not 'ok') matching Zig JSON schema; quiet mode suppresses file sections but counts violations in summary
- [Phase 19-03]: Hand-rolled SARIF structs with #[serde(rename)] per-field for all camelCase SARIF names; CSS/JS extracted verbatim from Zig html_output.zig; minijinja template uses {% if duplication %} conditional; test assertions use class="duplication-section" not CSS selector names
- [Phase 19]: Phase 19 doc updates are minimal notes only — not a full rewrite; full doc update deferred to Phase 22 when Rust binary ships
- [Phase 19]: Publication READMEs (publication/npm/) intentionally deferred to Phase 22 when Rust binary becomes official distribution
- [Phase 20-01]: Local rayon ThreadPoolBuilder used (not build_global()) to avoid test interference between concurrent test runs
- [Phase 20-01]: EXCLUDED_DIRS constant matches Zig filter.zig exactly (10 entries); WalkDir filter_entry prunes dirs before descent
- [Phase 20-01]: analyze_files_parallel() sorts by PathBuf::cmp for cross-platform deterministic ordering (PIPE-03)
- [Phase 20-02]: build_analysis_config() maps ResolvedConfig flat thresholds into AnalysisConfig struct hierarchy in main.rs
- [Phase 20-02]: Duplication gated on duplication_enabled && !no_duplication (post-parallel step in main.rs)
- [Phase 20-02]: function_violations() reused from output::console to count violations for exit codes — no duplication of threshold logic
- [Phase 21-01]: cognitive_error default changed from 30 to 25 in ResolvedConfig to match ScoringThresholds default (25.0); fixes health score divergence (greet: Rust 79.38 → 82.71 matching Zig)
- [Phase 21-01]: visit_node_cognitive() added as scope-boundary variant of visit_node_with_arrows(); stops traversal at arrow_function nodes (scope boundary) vs treating them as callbacks — mirrors Zig visitNode() semantics
- [Phase 21-01]: Duplication JSON schema rewritten to match Zig: enabled/project_duplication_pct/project_status/clone_groups.locations/files array; duplication thresholds hardcoded (3%/5%) since ResolvedConfig doesn't carry them yet
- [Phase 21]: Console output consolidated to one line per function with worst severity — matching Zig format (symbols ✓/⚠/✗, inline cyclomatic/cognitive/halstead/structural)
- [Phase 21]: Function name extraction enhanced with object_key/call_name/is_default_export NameContext fields in cyclomatic.rs walker — produces 'map callback', 'click handler', 'default export' matching Zig

### Pending Todos

1. **Add multi-language support via language profile abstraction** (general) — Refactor hardcoded TS/JS assumptions into a `LanguageProfile` abstraction to enable tree-sitter multi-language support
2. **Document Homebrew SHA256 update process** (docs) — Document placeholder mechanism, manual tap push step, and create helper script for SHA256 verification

### Blockers/Concerns

- Binary size target of 5 MB — baseline was 279 KB stub; needs measurement after all dependencies added
- serde-sarif skipped — using hand-rolled SARIF structs per research recommendation

## Session Continuity

Last session: 2026-02-25 (execute-phase 21)
Stopped at: Completed 21-02-PLAN.md — console output format parity (consolidated per-function, ✓/⚠/✗ symbols) and function naming for callbacks/exports
Resume with: Execute Phase 21 Plan 03 (integration test baselines)

**Remaining phases to execute:**
- Phase 19: CLI, Config, Output Formats — COMPLETE (4/4)
- Phase 20: Parallel Pipeline — COMPLETE (2/2)
- Phase 21: Integration Testing — IN PROGRESS (2/3 complete)
  - 21-01: Metric and schema bug fixes — COMPLETE
  - 21-02: Console format rewrite (Zig ESLint-style) + function naming — COMPLETE
  - 21-03: Integration test baselines — TODO
- Phase 22: Cross-Compilation, CI, Release — TODO

---
*State initialized: 2026-02-14*
*Last updated: 2026-02-25 after Phase 21 plan 02 completion (console output format parity + function naming for callbacks/exports)*
