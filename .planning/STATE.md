# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.
**Current focus:** v0.8 Rust Rewrite — Phase 20: Parallel Pipeline COMPLETE (2/2); Phase 21: Integration Testing next

## Current Position

Phase: 20 of 22 (Parallel Pipeline)
Plan: 2 of 2 in current phase — 20-01 and 20-02 complete
Status: Phase 20 COMPLETE — both plans done; ready for Phase 21 Integration Testing
Last activity: 2026-02-24 — Phase 20 plan 02 complete (main.rs pipeline wiring: end-to-end binary functional)

Progress: [██████░░░░] 55% (v0.8 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 9 (v0.8)
- Average duration: 6 min
- Total execution time: 52 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | 3/3 | 10 min | 3 min |
| 18 | 3/3 | 30 min | 10 min |
| 19 | 4/4 | 19 min | 5 min |
| 20 | 2/2 | 6 min | 3 min |

**Recent Trend:**
- Last 5 plans: 19-03 (6 min), 19-04 (1 min), 20-01 (3 min), 20-02 (3 min)
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
- [Phase 20-02]: build_analysis_config() maps ResolvedConfig flat thresholds into AnalysisConfig struct hierarchy in main.rs
- [Phase 20-02]: Duplication gated on duplication_enabled && !no_duplication (post-parallel step in main.rs)
- [Phase 20-02]: function_violations() reused from output::console to count violations for exit codes — no duplication of threshold logic

### Pending Todos

1. **Add multi-language support via language profile abstraction** (general) — Refactor hardcoded TS/JS assumptions into a `LanguageProfile` abstraction to enable tree-sitter multi-language support
2. **Document Homebrew SHA256 update process** (docs) — Document placeholder mechanism, manual tap push step, and create helper script for SHA256 verification

### Blockers/Concerns

- Binary size target of 5 MB — baseline was 279 KB stub; needs measurement after all dependencies added
- serde-sarif skipped — using hand-rolled SARIF structs per research recommendation

## Session Continuity

Last session: 2026-02-24 (execute-phase 20)
Stopped at: Completed 20-02-PLAN.md — full pipeline wiring in main.rs; binary analyzes real files end-to-end
Resume with: Plan + Execute Phase 21 (Integration Testing)

**Remaining phases to plan+execute:**
- Phase 19: CLI, Config, Output Formats — COMPLETE (4/4)
- Phase 20: Parallel Pipeline — COMPLETE (2/2)
- Phase 21: Integration Testing — plan + execute
- Phase 22: Cross-Compilation, CI, Release — plan + execute

---
*State initialized: 2026-02-14*
*Last updated: 2026-02-24 after Phase 20 plan 02 completion (main.rs pipeline wiring: binary end-to-end functional)*
