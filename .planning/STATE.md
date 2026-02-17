# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** Deliver accurate, fast complexity analysis in a single binary that runs locally and offline — making code health metrics accessible without SaaS dependencies or slow tooling.
**Current focus:** Phase 7 in progress - Plan 03 (pipeline integration) complete

## Current Position

Phase: 7 of 12 (Halstead + Structural Metrics)
Plan: 3 of 4
Status: In Progress - Plan 03 complete (pipeline integration, all 4 metric families wired)
Last activity: 2026-02-17 - Completed 07-03: Pipeline integration (ThresholdResult extended, all 4 passes, console/JSON/exit codes updated)

Progress: [████████░░] 54% (7/13 phases)

## Performance Metrics

**Velocity:**
- Total plans completed: 21
- Average duration: 4 min
- Total execution time: 2.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | 13 min | 4 min |
| 02 | 5 | 39 min | 8 min |
| 03 | 3 | 18 min | 6 min |
| 04 | 2 | 7 min | 3.5 min |
| 05 | 2 | 7 min | 3.5 min |
| 05.1 | 6 | 16 min | 2.7 min |

**Recent Trend:**
- Last 5 plans: 05.1-02 (2 min), 05.1-03 (3 min), 05.1-04 (1 min), 05.1-05 (3 min), 05.1-06 (3 min)
- Trend: Consistently fast execution (sub-5 minute average)

*Updated after each plan completion*
| Phase 05.1 P01 | 81 | 2 tasks | 3 files |
| Phase 05.1 P02 | 2 | 2 tasks | 13 files |
| Phase 05.1 P03 | 3 | 2 tasks | 4 files |
| Phase 05.1 P04 | 79 | 1 tasks | 1 files |
| Phase 05.1 P05 | 165 | 2 tasks | 4 files |
| Phase 05.1 P06 | 178 | 2 tasks | 3 files |
| Phase quick-8 P1 | 20 | 1 tasks | 1 files |
| Phase quick-9 P1 | 1 | 1 tasks | 2 files |
| Phase quick-10 P1 | 42 | 1 tasks | 2 files |
| Phase quick-11 P1 | 62 | 2 tasks | 6 files |
| Phase quick-12 P01 | 59 | 1 tasks | 1 files |
| Phase quick-13 P01 | 62 | 2 tasks | 6 files |
| Phase quick-14 P01 | 24 | 1 tasks | 1 files |
| Phase quick-15 P01 | 4 | 2 tasks | 2 files |
| Phase 06 P01 | 7 | 3 tasks | 7 files |
| Phase 06 P03 | 3 | 2 tasks | 6 files |
| Phase 06 P02 | 4 | 2 tasks | 4 files |
| Phase 07 P01 | 4 | 2 tasks | 4 files |
| Phase 07 P02 | 7 | 1 tasks | 2 files |
| Phase 07 P03 | 6 | 2 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Zig over Rust: Faster compile times, simpler C interop for tree-sitter, single static binary (Confirmed - 01-01)
- tree-sitter for parsing: Proven grammars, error-tolerant, incremental (Pending)
- Five metric families: Covers structural, flow, cognitive, duplication, and information-theoretic dimensions (Pending)
- Weighted composite score: Single health score lets teams customize what complexity means (Pending)
- Zig 0.15.2 API patterns: Adapted from 0.14 research to match installed version (01-01)
- Arena allocator for CLI lifecycle: Simplifies memory management for short-lived CLI tool (01-01)
- Inline tests during Phase 1: Co-locate tests with implementation for fast TDD iteration (01-01)
- Optional types for future metrics: Use ?u32 and ?f64 for metrics computed in later phases (01-02)
- std.json.Stringify.valueAlloc: Clean JSON serialization pattern for Zig 0.15.2 (01-02)
- Separate RED/GREEN commits: Preserve TDD history in git log for design evolution tracking (01-02)
- Test helpers use builder pattern with defaults: Reduces test boilerplate from 13 lines to 1-3 lines (01-03)
- Fixtures include complexity annotations: Hand-crafted synthetic examples with documented expected values for metric validation (01-03)
- Auto-computation in test helpers: Helpers calculate derived fields (function_count, totals) from input data (01-03)
- Hand-rolled argument parser for Zig 0.15.2: zig-clap and yazap incompatible with Zig 0.15 API changes (@Tuple/@Struct removed, ArrayList.init removed, std.Io.Threaded removed) (02-01)
- Zig 0.15.2 ArrayList API: Use ArrayList.empty const instead of .init(), pass allocator to append() and deinit() (02-01)
- Quoted identifier for ThresholdPair.error: Use @"error" syntax since error is Zig keyword, maintains JSON/TOML schema compatibility (02-01)
- [Phase 02]: Hardcoded help text over zig-clap auto-generation for full formatting control per ripgrep-style locked decision
- [Phase 02]: Removed incompatible known-folders dependency (Zig 0.14 APIs) - will need Zig 0.15-compatible alternative for Phase 4
- [Phase 02]: Hand-rolled XDG config path detection: Implemented minimal XDG detection after known-folders proved incompatible with Zig 0.15.2 API changes
- [Phase 02]: Simplified --init to generate default config without interactive prompts due to Zig 0.15.2 IO API changes (File.Reader lacks readUntilDelimiterOrEof)
- [Phase 02-cli-configuration]: Fixed unknown flag detection to provide did-you-mean suggestions
- [Phase 02-cli-configuration]: Human-approved CLI personality: compact help, ripgrep-style UX, fits one screen
- [Phase 03-file-discovery-parsing]: Simple pattern matching for include/exclude (defer full glob to later phase)
- [Phase 03-file-discovery-parsing]: Try-directory-first pattern using openDir().close() for file/dir detection
- [Phase 03-file-discovery-parsing]: Tree-sitter requires POSIX_C_SOURCE and DEFAULT_SOURCE defines for fdopen/le16toh/be16toh
- [Phase 03-file-discovery-parsing]: Wrapper types for tree-sitter C API provide idiomatic Zig interface hiding C pointer details
- [Phase 03-file-discovery-parsing]: Node wraps TSNode by value (not pointer) - matches tree-sitter semantics, TSNode is small (32 bytes)
- [Phase 03-file-discovery-parsing]: Tree-sitter unicode headers require vendor/tree-sitter/lib/src/unicode include path
- [Phase 03-file-discovery-parsing]: ParseResult borrows path instead of owning for memory efficiency
- [Phase 03-file-discovery-parsing]: Language selection checks .tsx before .ts (.ts is suffix of .tsx)
- [Phase 03-file-discovery-parsing]: Syntax errors don't fail parsing - tree-sitter returns tree with ERROR nodes for graceful degradation
- [Phase 04-cyclomatic-complexity]: ESLint-aligned counting rules by default (count logical operators, nullish coalescing, optional chaining)
- [Phase 04-cyclomatic-complexity]: Support both classic and modified switch/case counting modes
- [Phase 04-cyclomatic-complexity]: Base complexity 1 (McCabe's original definition)
- [Phase 04-cyclomatic-complexity]: Nested function scope isolation (inner complexity doesn't inflate outer)
- [Phase 04-cyclomatic-complexity]: Function body is in statement_block child node, not function_declaration itself
- [Phase 04-cyclomatic-complexity]: Default thresholds: warning=10 (McCabe), error=20 (ESLint) for industry standard alignment
- [Phase 04-cyclomatic-complexity]: ThresholdStatus uses @"error" syntax since error is Zig keyword
- [Phase 04-cyclomatic-complexity]: analyzeFile returns empty slice for null trees instead of erroring
- [Phase 04-cyclomatic-complexity]: toFunctionResults sets structural fields to 0 (populated in future phases)
- [Phase 04-cyclomatic-complexity]: Double-analysis in main.zig acceptable for now - Phase 5 will restructure pipeline
- [Phase 05-console-json-output]: Default thresholds hardcoded in formatFileResults (acceptable as values match defaults)
- [Phase 05-console-json-output]: Bubble sort for hotspot ranking (sufficient for top-5 list, max ~hundreds of functions)
- [Phase 05-console-json-output]: Exit code priority order: parse_error > errors > warnings > success (matches CI integration needs)
- [Phase 05-console-json-output]: snake_case field naming in JSON output (matches existing codebase convention in core/types.zig, core/json.zig)
- [Phase 05-console-json-output]: Single-pass analysis eliminates double-analysis pattern from Phase 4 (analyze once, store results, format from stored data)
- [Phase 05-console-json-output]: Structural fields set to 0 in JSON FunctionOutput (ThresholdResult doesn't include end_line, nesting_depth, line_count, params_count)
- [Phase 05.1]: Keep a Changelog 1.1.0 format for release history
- [Phase 05.1]: Portable sed pattern (create .bak, then rm) for macOS/Linux compatibility
- [Phase 05.1]: mlugg/setup-zig@v2 for GitHub Actions Zig setup with locked version 0.15.2
- [Phase 05.1-03]: TanStack-style progressive disclosure for README (quick start path without overwhelming detail)
- [Phase 05.1-03]: Document only current features in user docs (prevents confusion, sets accurate expectations)
- [Phase 05.1-03]: Friendly and thorough tone throughout documentation (TanStack/Astro style per user decision)
- [Phase 05.1-04]: Manual dispatch trigger with version validation for release workflow
- [Phase 05.1-04]: Single Ubuntu runner for all Zig cross-compilation targets (5 platforms)
- [Phase 05.1-04]: Separate job dependency chain: validate -> build -> release -> (npm-publish || homebrew-update)
- [Quick Task 4]: Tag push trigger enables automatic workflow execution from local release script
- [Quick Task 4]: Dual-trigger workflow extracts version from tag name (push) or manual input (dispatch)
- [Quick Task 4]: Confirmation prompt in release script prevents accidental pushes during testing
- [Phase 05.1-05]: Publication files scoped under publication/ directory (publication/npm/, publication/homebrew/) for cleaner project root
- [Phase 05.1-05]: All workflow and script references updated to publication/ paths
- [Phase 05.1-06]: Comprehensive release documentation following TanStack/Astro friendly style
- [Phase 05.1-06]: Homebrew formula comments explain SHA256 placeholder mechanism inline
- [Quick Task 6]: DISABLED marker pattern for temporarily disabled workflow jobs (comment out with clear re-enablement instructions)
- [Quick Task 7]: Selective submodule checkout in CI workflows (only enable where builds occur to minimize checkout time)
- [Quick Task 8]: tags-ignore pattern in test workflow prevents redundant CI runs when release tags are pushed (release workflow already handles builds)
- [Phase quick-11]: Use npm trusted publishing (OIDC) instead of secret tokens for improved supply chain security
- [Phase quick-12]: Interactive npm login over NPM_TOKEN for initial publish (one-time bootstrap)
- [Phase quick-12]: Warn-but-continue on org access check (npm publish handles access)
- [Phase quick-14]: Use package@version naming convention for GitHub releases (matches industry standard)
- [Phase quick-15]: Temp file approach for CHANGELOG.md insertion (portable across macOS/Linux, avoids sed newline issues)
- [Phase quick-15]: Combined feat/fix regex with explicit type capture group for reliable bash matching
- [Phase 06-01]: Each &&, ||, ?? counts as +1 flat individually (ComplexityGuard deviation from SonarSource grouping)
- [Phase 06-01]: Top-level arrow functions start at nesting 0; arrow function callbacks add structural increment
- [Phase 06-01]: Scope isolation: inner function bodies don't inflate outer cognitive complexity
- [Phase 06]: Cognitive complexity docs credit G. Ann Campbell/SonarSource per locked requirement
- [Phase 06]: Example output format updated to show side-by-side cyclomatic/cognitive scores
- [Phase 06]: Worst-of-both-metrics for exit codes and display: cognitive violations treated at same severity as cyclomatic
- [Phase 06]: Index alignment merge pattern: cyclomatic and cognitive walkers produce same-order results from same AST walk
- [Phase 06]: Side-by-side console format: 'Function name cyclomatic N cognitive N' on single line for compact output
- [Phase 07]: StringHashMap initialized in-place in HalsteadContext struct to prevent copy-on-assign memory leak (Zig structs copy by value; defer on original does not clean up the populated copy)
- [Phase 07]: isOperatorToken uses node type string as key; isOperandToken uses source text as key — operators are syntax types, operands are values
- [Phase 07]: ternary_expression handled as non-leaf operator: '?:' added before recursing; leaf ? and : tokens skipped as structural punctuation
- [Phase 07]: TypeScript type exclusion: isTypeOnlyNode returns early on entire subtree for all type annotation nodes
- [Phase 07]: Standalone brace-only lines excluded from logical line count (structural delimiters, not code)
- [Phase 07]: Function declarations used for scope isolation tests (TypeScript function expressions have different AST representation)
- [Phase 07]: Single-expression arrow functions count as 1 logical line (locked decision: expression body != statement_block)
- [Phase 07-03]: formatFileResults signature takes FileThresholdResults struct (cleaner, carries structural field alongside path and results)
- [Phase 07-03]: worstStatusAll duplicated in exit_codes.zig and console.zig independently (avoids circular import; json_output imports exit_codes)
- [Phase 07-03]: Halstead fields in JSON changed from ?f64 to f64 (Phase 7 always computes them; 0.0 valid for empty functions)
- [Phase 07-03]: isMetricEnabled helper: returns true when metrics is null (all enabled) or metric name is in list

### Pending Todos

1. **Add multi-language support via language profile abstraction** (general) — Refactor hardcoded TS/JS assumptions into a `LanguageProfile` abstraction to enable tree-sitter multi-language support
2. **Document Homebrew SHA256 update process** (docs) — Document placeholder mechanism, manual tap push step, and create helper script for SHA256 verification

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 1 | Reorder phases 5-8: move phase 8 to phase 5, shift phases 5-7 down | 2026-02-14 | d5337e6 | [1-reorder-phases-5-8-move-phase-8-to-phase](./quick/1-reorder-phases-5-8-move-phase-8-to-phase/) |
| 2 | Show function indicator and actual function names | 2026-02-15 | 53021f1 | [2-show-function-indicator-and-actual-funct](./quick/2-show-function-indicator-and-actual-funct/) |
| 3 | Document credentials and create .env.example | 2026-02-15 | 1b64692 | [3-document-credentials-create-env-example-](./quick/3-document-credentials-create-env-example-/) |
| 4 | Add tag push trigger to release workflow | 2026-02-15 | 39a02d6 | [4-add-tag-push-trigger-to-release-workflow](./quick/4-add-tag-push-trigger-to-release-workflow/) |
| 5 | Update release script to require explicit bump type | 2026-02-16 | 9fa4762 | [5-update-the-release-script-to-have-no-def](./quick/5-update-the-release-script-to-have-no-def/) |
| 6 | Disable Homebrew publication but keep code for re-enablement | 2026-02-16 | 8cafb14 | [6-disable-the-homebrew-publication-but-kee](./quick/6-disable-the-homebrew-publication-but-kee/) |
| 7 | Fix CI test failure: vendor/tree-sitter/lib/src/lib.c FileNotFound in GitHub Actions | 2026-02-16 | 2cd0eca | [7-fix-ci-test-failure-vendor-tree-sitter-l](./quick/7-fix-ci-test-failure-vendor-tree-sitter-l/) |
| 8 | Skip test workflow on release tag pushes | 2026-02-16 | b4dd0be | [8-skip-test-workflow-on-release-tag-pushes](./quick/8-skip-test-workflow-on-release-tag-pushes/) |
| 9 | Fix Windows build failure: replace std.posix.getenv with cross-platform APIs | 2026-02-16 | b77d545 | [9-fix-windows-build-failure-replace-std-po](./quick/9-fix-windows-build-failure-replace-std-po/) |
| 10 | Fix release script to update optionalDependencies | 2026-02-16 | dd2d90f | [10-fix-release-script-to-update-optionaldep](./quick/10-fix-release-script-to-update-optionaldep/) |
| 11 | Fix npm package.json repository URLs and switch to OIDC trusted publishing | 2026-02-16 | c5ba6ae | [11-fix-npm-package-json-repository-urls-and](./quick/11-fix-npm-package-json-repository-urls-and/) |
| 12 | Create bash script for initial manual npm publish | 2026-02-16 | a89cabf | [12-create-bash-script-for-initial-manual-np](./quick/12-create-bash-script-for-initial-manual-np/) |
| 13 | Create README files for each package under publication/npm | 2026-02-16 | a536031 | [13-create-readme-files-for-each-package-und](./quick/13-create-readme-files-for-each-package-und/) |
| 14 | Fix GitHub release name to show package@version format | 2026-02-16 | 415d57f | [14-fix-github-release-name-to-show-package-](./quick/14-fix-github-release-name-to-show-package-/) |
| 15 | Add automatic CHANGELOG.md generation from conventional commits | 2026-02-16 | bdd0b4a | [15-add-automatic-changelog-md-generation-fr](./quick/15-add-automatic-changelog-md-generation-fr/) |

### Blockers/Concerns

**Phase 1 considerations:**
- Verify Zig 0.14.x std.Thread.Pool API with official documentation (research suggests API may have changed since training data)
- Confirm tree-sitter C API thread-safety guarantees for parallel parsing
- Establish cross-platform build on CI immediately (Windows path handling must work from start)

**Phase 3 considerations:**
- Tree-sitter memory management at Zig/C boundary requires careful cleanup patterns (use defer for ts_tree_delete)

**Phase 6 considerations:**
- Cognitive complexity arrow function nesting is controversial in SonarSource spec — may need configuration flag

**Phase 11 considerations:**
- Rabin-Karp hash collision rate needs empirical tuning with large TypeScript codebases
- Duplication detection may conflict with < 1s performance target on 10K files — consider opt-in flag

### Roadmap Evolution

- Phase 05.1 inserted after Phase 5: CI/CD, Release Pipeline & Documentation (URGENT)

## Session Continuity

Last session: 2026-02-17 (execute-phase)
Stopped at: Completed 07-03-PLAN.md (pipeline integration: all 4 metric families wired, output updated)
Resume file: .planning/phases/07-halstead-structural-metrics/07-03-SUMMARY.md

---
*State initialized: 2026-02-14*
*Last updated: 2026-02-17T10:10:00Z*
