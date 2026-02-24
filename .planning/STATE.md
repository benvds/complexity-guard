# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.
**Current focus:** v0.8 Rust Rewrite — Phase 20: Parallel Pipeline (plan 1 of 2 complete)

## Current Position

Phase: 20 of 22 (Parallel Pipeline)
Plan: 1 of 2 in current phase — 20-01 complete
Status: Phase 20 in progress — 20-01 done, moving to 20-02
Last activity: 2026-02-24 — Phase 20 plan 01 complete (pipeline module: discover + parallel)

Progress: [█████░░░░░] 44% (v0.8 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 8 (v0.8)
- Average duration: 7 min
- Total execution time: 49 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | 3/3 | 10 min | 3 min |
| 18 | 3/3 | 30 min | 10 min |
| 19 | 4/4 | 19 min | 5 min |
| 20 | 1/2 | 3 min | 3 min |

**Recent Trend:**
- Last 5 plans: 19-02 (6 min), 19-03 (6 min), 19-04 (1 min), 20-01 (3 min)
- Trend: Stable

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

### Pending Todos

1. **Add multi-language support via language profile abstraction** (general) — Refactor hardcoded TS/JS assumptions into a `LanguageProfile` abstraction to enable tree-sitter multi-language support
2. **Document Homebrew SHA256 update process** (docs) — Document placeholder mechanism, manual tap push step, and create helper script for SHA256 verification

### Blockers/Concerns

- Binary size target of 5 MB — baseline was 279 KB stub; needs measurement after all dependencies added
- serde-sarif skipped — using hand-rolled SARIF structs per research recommendation

## Session Continuity

Last session: 2026-02-24 (execute-phase 20)
Stopped at: Completed 20-01-PLAN.md — pipeline module with discover_files() and analyze_files_parallel(); 10 tests passing
Resume with: Execute Phase 20 plan 02 (main.rs CLI integration)

**Remaining phases to plan+execute:**
- Phase 19: CLI, Config, Output Formats — COMPLETE (4/4)
- Phase 20: Parallel Pipeline — IN PROGRESS (1/2 complete)
- Phase 21: Integration Testing — plan + execute
- Phase 22: Cross-Compilation, CI, Release — plan + execute

---
*State initialized: 2026-02-14*
*Last updated: 2026-02-24 after Phase 20 plan 01 completion (pipeline module: discover + parallel)*
