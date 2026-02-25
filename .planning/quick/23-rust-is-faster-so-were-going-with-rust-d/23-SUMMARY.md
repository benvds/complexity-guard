---
phase: quick-23
plan: 01
subsystem: project-structure
tags: [migration, rust, zig-removal, restructure, adr]
dependency_graph:
  requires: [quick-22]
  provides: [root-level-cargo, single-language-project, rust-only-ci]
  affects: [all-ci-workflows, release-process, documentation, publication]
tech_stack:
  added: []
  patterns: [root-level-cargo, cargo-zigbuild-cross-compile]
key_files:
  created:
    - docs/architecture-decision-rust.md
    - .github/workflows/ci.yml
    - Cargo.toml
    - Cargo.lock
    - src/
    - tests/
  modified:
    - .gitignore
    - .github/workflows/release.yml
    - scripts/release.sh
    - CLAUDE.md
    - README.md
    - PUBLISHING.md
    - docs/getting-started.md
    - docs/releasing.md
    - docs/benchmarks.md
    - docs/cli-reference.md
    - docs/examples.md
    - publication/homebrew/complexity-guard.rb
decisions:
  - "ADR created documenting Rust adoption rationale with benchmark data (1.5-3.1x faster than Zig with parallel analysis)"
  - "Rust source promoted from rust/ subdirectory to project root (Cargo.toml, src/, tests/)"
  - "CI unified to single ci.yml (from rust-ci.yml) and release.yml (from rust-release.yml)"
  - "Zig submodules (tree-sitter, tree-sitter-typescript, tree-sitter-javascript) removed from .gitmodules"
  - "All fixture path references in src/**/*.rs updated from ../tests/fixtures to tests/fixtures"
metrics:
  duration: "9 min"
  completed: "2026-02-25"
  tasks: 2
  files: 70
---

# Quick Task 23: Rust Adoption, Zig Removal, and Project Restructure Summary

Migrated ComplexityGuard from dual-language Zig+Rust structure to a single Rust project at the repository root. Deleted all Zig source, submodules, and Zig-specific CI. Created an ADR documenting the decision with benchmark data. Promoted Rust code from `rust/` subdirectory to project root.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create ADR and remove Zig code, submodules, Zig CI | abb974d | docs/architecture-decision-rust.md, .gitignore, zig/ removed |
| 2 | Move Rust code to project root and update all references | 5e25696 | Cargo.toml, src/, tests/, ci.yml, release.yml, all docs |

## What Was Done

### Task 1: ADR and Zig Removal

Created `docs/architecture-decision-rust.md` with:
- Status: Accepted, Date: 2026-02-25
- Context: Parallel Zig (v1.0) + Rust (v0.8) implementation since Phase 17
- Decision: Adopt Rust, remove Zig
- Rationale with benchmark data from quick task 22: Rust 1.5-3.1x faster with parallel analysis
- Consequences: single implementation, no vendored submodules, simpler CI

Removed:
- `zig/` directory (entire Zig source tree, benchmarks, vendor submodules)
- `.gitmodules` (tree-sitter, tree-sitter-typescript, tree-sitter-javascript submodule references)
- `.github/workflows/test.yml` (Zig test + Valgrind memory check workflow)
- `scripts/check-memory.sh` (Valgrind-based Zig memory check script)

Updated `.gitignore`: removed all `zig/` entries, changed `rust/target/` to `/target/`.

### Task 2: Rust Code Promotion to Root

Phase A — Moved files using git mv:
- `rust/Cargo.toml` → `Cargo.toml`
- `rust/Cargo.lock` → `Cargo.lock`
- `rust/src/` → `src/`
- `rust/tests/integration_tests.rs` → `tests/integration_tests.rs`
- `rust/tests/parser_tests.rs` → `tests/parser_tests.rs`
- `rust/tests/fixtures/baselines/` → `tests/fixtures/baselines/`

Fixed path references in test files: removed `..` from `fixture_path` functions (CARGO_MANIFEST_DIR now points to project root, not `rust/`).

Fixed path references in 8 src/ files: replaced `../tests/fixtures` with `tests/fixtures` across all unit tests in `src/metrics/*.rs`, `src/pipeline/*.rs`.

Phase B — CI workflow renames:
- `rust-ci.yml` → `ci.yml`: renamed, removed `working-directory: rust`, removed path filter `rust/**`, updated workspace cache config, updated binary paths from `rust/target/` to `target/`
- Old Zig `release.yml` removed; `rust-release.yml` → `release.yml`: renamed, removed `working-directory: rust`, updated target binary paths, updated archive creation paths

Phase C — Scripts: `scripts/release.sh` updated to reference `Cargo.toml` instead of `rust/Cargo.toml` in all grep/sed/git add operations.

Phase D — Documentation updates:
- `CLAUDE.md`: rewritten for Rust-only project; removed Zig Conventions and Code Patterns sections; updated build commands; updated project structure
- `README.md`: simplified Building from Source section
- `PUBLISHING.md`: replaced Zig cross-compilation commands with cargo-zigbuild Rust commands
- `docs/getting-started.md`: fixed source build path
- `docs/releasing.md`: fully rewritten; references `Cargo.toml` (not `rust/Cargo.toml`), `release.yml` (not `rust-release.yml`); removed legacy Zig workflow section
- `docs/benchmarks.md`: removed Zig references; updated tool version to 0.8.0; removed zig/benchmarks/ path references
- `docs/cli-reference.md`: removed `cd rust &&` from build instruction
- `docs/examples.md`: updated note removing "legacy Zig binary" reference
- `publication/homebrew/complexity-guard.rb`: updated target name comments from Zig to Rust target triple format

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed fixture path references in src/**/*.rs unit tests**
- **Found during:** Task 2, Phase E (verification — cargo test failed with "No such file or directory")
- **Issue:** 8 source files had `../tests/fixtures` paths computed relative to CARGO_MANIFEST_DIR. When CARGO_MANIFEST_DIR was `rust/`, this resolved correctly. After promotion to project root, `../tests/fixtures` pointed one level above the project root.
- **Fix:** Replaced all `../tests/fixtures` with `tests/fixtures` in `src/metrics/cognitive.rs`, `src/metrics/cyclomatic.rs`, `src/metrics/duplication.rs`, `src/metrics/halstead.rs`, `src/metrics/mod.rs`, `src/metrics/structural.rs`, `src/pipeline/discover.rs`, `src/pipeline/parallel.rs`
- **Files modified:** 8 files in `src/`
- **Commit:** 5e25696 (included in task 2 commit)

## Verification Results

All plan verification criteria passed:

1. `cargo test` — 233 tests pass (195 lib + 30 integration + 8 parser)
2. `cargo build --release` — succeeds, binary at `target/release/complexity-guard`
3. `zig/` directory does not exist
4. `rust/` directory does not exist
5. `docs/architecture-decision-rust.md` exists
6. No `cd rust` references in README.md, docs/, scripts/, .github/
7. No `rust/Cargo` references in README.md, docs/, scripts/, .github/
8. No unexpected Zig references in CI workflows (only `cargo-zigbuild` / `ziglang` for Linux cross-compilation, which is correct)

## Self-Check: PASSED

- `docs/architecture-decision-rust.md` — FOUND
- `Cargo.toml` — FOUND
- `src/main.rs` — FOUND
- `.github/workflows/ci.yml` — FOUND
- `.github/workflows/release.yml` — FOUND
- Commit abb974d — FOUND
- Commit 5e25696 — FOUND
- No `zig/` directory — CONFIRMED
- No `rust/` directory — CONFIRMED
- All 233 tests pass — CONFIRMED
