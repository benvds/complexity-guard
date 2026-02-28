# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.
**Current focus:** v0.8 Rust Rewrite — Phase 22: Cross-Compilation, CI, Release — COMPLETE (3/3)

## Current Position

Phase: 22 of 22 (Cross-Compilation, CI, and Release) — COMPLETE
Plan: 3 of 3 in phase 22 — plan 03 complete
Status: Phase 22-03 COMPLETE — documentation updates for Rust binary (README, docs, releasing, publication READMEs)
Last activity: 2026-02-28 - Completed quick task 32: Build scoring algorithm comparison tool to test and tune health score weights

Progress: [█████████░] 75% (v0.8 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 13 (v0.8)
- Average duration: 8 min
- Total execution time: 97 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | 3/3 | 10 min | 3 min |
| 18 | 3/3 | 30 min | 10 min |
| 19 | 4/4 | 19 min | 5 min |
| 20 | 2/2 | 6 min | 3 min |
| 21 | 4/4 | 45 min | 11 min |
| 22 | 2/3 | 2 min | 1 min |

**Recent Trend:**
- Last 5 plans: 21-03 (4 min), 21-04 (2 min), 22-01 (1 min), 22-02 (1 min)
- Trend: Fast (infra/config YAML changes with Python verification)

*Updated after each plan completion*
| Phase 22 P03 | 4 | 2 tasks | 11 files |

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
- [Phase 21-03]: Baseline files strip timestamp and elapsed_ms with jq del() — these fields change between runs
- [Phase 21-03]: Float tolerances: HALSTEAD_TOL=1e-9, SCORE_TOL=1e-6 — explicitly defined as constants in integration_tests.rs
- [Phase 21-03]: assert_cmd deprecation warning (cargo_bin API) noted but left — custom build-dir config not used; tests work correctly
- [Phase 21-04]: Exit code 4 (ParseError) is unreachable by design — tree-sitter error tolerance means binary content in .ts files parses to zero functions with exit 0; documented via executable test not comment
- [Phase 22-01]: can_test: false only for linux-aarch64-musl — aarch64 binary cannot execute on x86_64 ubuntu-latest runner (no free arm64 Linux runners on GitHub)
- [Phase 22-01]: RUSTFLAGS crt-static applied conditionally via matrix.target expression for Windows-only static CRT (avoids extra step)
- [Phase 22-01]: ext matrix field (empty string vs .exe) handles Windows binary suffix consistently across ls and --version steps
- [Phase 22]: rust-release.yml is a SEPARATE workflow from the Zig release.yml — they coexist for parallel Zig/Rust release paths
- [Phase 22]: release.sh now uses rust/Cargo.toml as single source of truth for version — replaces src/main.zig grep/sed
- [Phase 22]: docs/releasing.md fully rewritten around rust-release.yml; legacy Zig workflow noted in final section for historical reference
- [Phase 22]: npm/Homebrew installation methods kept intact in README — will be updated when npm distribution ships
- [Phase quick-21]: setCwd(..) in build.zig runs Zig tests from project root so tests/fixtures/ is accessible to both Zig and Rust
- [quick-23]: Rust adopted as sole implementation language; ADR in docs/architecture-decision-rust.md with benchmark rationale (1.5-3.1x faster with parallel)
- [quick-23]: Cargo.toml, src/, tests/ now at project root; all CARGO_MANIFEST_DIR-relative paths in src/**/*.rs updated from ../tests/fixtures to tests/fixtures
- [quick-23]: CI unified: rust-ci.yml → ci.yml, rust-release.yml → release.yml (old Zig release.yml removed)
- [quick-23]: release.sh now references Cargo.toml (not rust/Cargo.toml) as version source
- [quick-30]: FileOutcome enum used in parallel pipeline to cleanly separate skipped vs analyzed vs error outcomes
- [quick-30]: Function-level size guard uses `continue` in merge loop rather than index-based filtering
- [quick-30]: JSON skipped array omitted (not null) when empty, using skip_serializing_if
- [quick-30]: SARIF complexity-guard/skipped rule at index 11 with "note" default level; rule count is now 12

### Pending Todos

1. **Add multi-language support via language profile abstraction** (general) — Refactor hardcoded TS/JS assumptions into a `LanguageProfile` abstraction to enable tree-sitter multi-language support
2. **Document Homebrew SHA256 update process** (docs) — Document placeholder mechanism, manual tap push step, and create helper script for SHA256 verification
3. **Add cargo install publication via crates.io** (general) — Publish crate to crates.io to enable `cargo install complexity-guard` as an additional distribution channel

### Blockers/Concerns

- Binary size target of 5 MB — baseline was 279 KB stub; needs measurement after all dependencies added
- serde-sarif skipped — using hand-rolled SARIF structs per research recommendation

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 21 | Move zig code to zig/ directory to match rust/ directory structure | 2026-02-25 | 0c20250 | [21-move-zig-code-to-zig-directory-to-match-](./quick/21-move-zig-code-to-zig-directory-to-match-/) |
| 22 | Create benchmark script comparing Rust vs Zig binaries | 2026-02-25 | 54154f5 | [22-create-benchmark-script-comparing-rust-v](./quick/22-create-benchmark-script-comparing-rust-v/) |
| 23 | Adopt Rust as sole language: remove Zig, promote Rust to root, create ADR | 2026-02-25 | 5e25696 | [23-rust-is-faster-so-were-going-with-rust-d](./quick/23-rust-is-faster-so-were-going-with-rust-d/) |
| 24 | Restore benchmarks/ directory from main with Rust build commands | 2026-02-25 | 91c487e | [24-restore-benchmarks-and-scripts-from-main](./quick/24-restore-benchmarks-and-scripts-from-main/) |
| 25 | Create a Claude Code skill for complexity-guard CLI | 2026-02-26 | 0855eac | [25-create-a-claude-skill-for-complexity-gua](./quick/25-create-a-claude-skill-for-complexity-gua/) |
| 26 | Restructure public-projects.json with categories, repo_size, test_sets | 2026-02-26 | 00af450 | [26-improve-public-projects-json-restructure](./quick/26-improve-public-projects-json-restructure/) |
| 27 | Add 8 missing combo repos and restrict quick set to small repos | 2026-02-26 | b8f0412 | [27-add-missing-combo-repos-and-restrict-qui](./quick/27-add-missing-combo-repos-and-restrict-qui/) |
| 28 | Add license field to all repos in public-projects.json | 2026-02-26 | 62457fb | [28-add-license-field-to-all-repos-in-public](./quick/28-add-license-field-to-all-repos-in-public/) |
| 29 | Remove FTA benchmarking from all scripts and documentation | 2026-02-26 | a011be5 | [29-remove-the-benchmarking-against-the-fta-](./quick/29-remove-the-benchmarking-against-the-fta-/) |
| 30 | Add size guards to skip files > 10,000 lines and functions > 5,000 lines | 2026-02-26 | b8da1c8 | [30-add-a-fail-safe-to-skip-files-bigger-tha](./quick/30-add-a-fail-safe-to-skip-files-bigger-tha/) |
| 31 | Update README and docs to reflect actual Rust code (correct config schema, field names, CLI behavior) | 2026-02-28 | 769168a | [31-update-readme-and-docs-to-reflect-actual](./quick/31-update-readme-and-docs-to-reflect-actual/) |
| 32 | Build scoring algorithm comparison tool to compare 8 algorithms across 84 projects | 2026-02-28 | d013f3b | [32-build-scoring-algorithm-comparison-tool-](./quick/32-build-scoring-algorithm-comparison-tool-/) |

## Session Continuity

Last session: 2026-02-28 (quick task 32)
Stopped at: Completed quick task 32 — scoring algorithm comparison tool (compare-scoring.mjs) showing spread 7.9-37.1 across 8 algorithms on 83 real-world projects
Resume with: Scoring comparison tool available; ready for next task

**Remaining phases to execute:**
- Phase 19: CLI, Config, Output Formats — COMPLETE (4/4)
- Phase 20: Parallel Pipeline — COMPLETE (2/2)
- Phase 21: Integration Testing — COMPLETE (4/4)
  - 21-01: Metric and schema bug fixes — COMPLETE
  - 21-02: Console format rewrite (Zig ESLint-style) + function naming — COMPLETE
  - 21-03: Integration test baselines (29 tests, 12 baselines) — COMPLETE
  - 21-04: Exit code 4 documentation test + gap closure — COMPLETE
- Phase 22: Cross-Compilation, CI, Release — COMPLETE (3/3)
  - 22-01: CI cross-compilation matrix (5 targets) — COMPLETE
  - 22-02: rust-release.yml (GitHub release workflow) — COMPLETE
  - 22-03: Documentation updates — COMPLETE

---
*State initialized: 2026-02-14*
*Last updated: 2026-02-28 after quick task 32 completion (scoring algorithm comparison tool — 8 algorithms across 83 projects)*
