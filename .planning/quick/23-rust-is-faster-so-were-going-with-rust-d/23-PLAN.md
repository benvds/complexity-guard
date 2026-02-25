---
phase: quick-23
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/architecture-decision-rust.md
  - CLAUDE.md
  - README.md
  - PUBLISHING.md
  - CHANGELOG.md
  - .gitignore
  - .gitmodules
  - Cargo.toml
  - Cargo.lock
  - src/**
  - tests/**
  - .github/workflows/test.yml
  - .github/workflows/release.yml
  - .github/workflows/rust-ci.yml
  - .github/workflows/rust-release.yml
  - scripts/release.sh
  - scripts/check-memory.sh
  - docs/getting-started.md
  - docs/releasing.md
  - docs/benchmarks.md
  - docs/cli-reference.md
  - docs/examples.md
  - publication/npm/README.md
  - publication/npm/packages/*/README.md
  - publication/homebrew/complexity-guard.rb
autonomous: true
requirements: []
must_haves:
  truths:
    - "An ADR documents why Rust was chosen over Zig with benchmark data"
    - "The zig/ directory no longer exists in the repository"
    - "Rust source code lives at project root (src/, Cargo.toml) not in rust/ subdirectory"
    - "All documentation references Rust, not Zig, as the implementation language"
    - "cargo build and cargo test work from project root"
    - "Git submodules for tree-sitter Zig vendor libs are removed"
    - "CI workflows use Rust only, no Zig workflows remain"
  artifacts:
    - path: "docs/architecture-decision-rust.md"
      provides: "ADR documenting Rust vs Zig decision"
    - path: "Cargo.toml"
      provides: "Rust project config at root level"
    - path: "src/main.rs"
      provides: "Rust entry point at root level"
    - path: ".github/workflows/ci.yml"
      provides: "Unified Rust CI workflow"
    - path: ".github/workflows/release.yml"
      provides: "Rust release workflow (renamed from rust-release.yml)"
  key_links:
    - from: "scripts/release.sh"
      to: "Cargo.toml"
      via: "version grep"
      pattern: "grep.*Cargo\\.toml"
    - from: ".github/workflows/ci.yml"
      to: "Cargo.toml"
      via: "cargo test"
      pattern: "cargo test"
---

<objective>
Finalize the migration from Zig to Rust: document the rationale in an ADR, remove all Zig code and infrastructure, and promote the Rust code from rust/ subdirectory to the project root.

Purpose: The Rust implementation (v0.8) is faster than Zig in benchmarks and is the go-forward implementation. The zig/ directory and dual-language structure create confusion and maintenance burden. This task cleans up the project to be a single-language Rust project.

Output: Clean Rust-only project with ADR, updated docs, root-level Cargo.toml, and Rust-only CI.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@README.md
@.gitignore
@.gitmodules
@rust/Cargo.toml
@scripts/release.sh
@scripts/check-memory.sh
@.github/workflows/test.yml
@.github/workflows/rust-ci.yml
@.github/workflows/rust-release.yml
@.github/workflows/release.yml
@docs/getting-started.md
@docs/releasing.md
@docs/benchmarks.md
@PUBLISHING.md
@publication/homebrew/complexity-guard.rb
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create ADR and remove Zig code, submodules, and Zig CI</name>
  <files>
    docs/architecture-decision-rust.md
    .gitmodules
    .gitignore
    .github/workflows/test.yml
    scripts/check-memory.sh
  </files>
  <action>
    1. Create `docs/architecture-decision-rust.md` as an Architecture Decision Record:
       - Title: "ADR: Adopt Rust as sole implementation language"
       - Status: Accepted
       - Date: 2026-02-25
       - Context: ComplexityGuard was originally built in Zig (v1.0, phases 1-14). A Rust rewrite (v0.8, phases 17-22) was undertaken to evaluate Rust's ecosystem advantages (cargo, crates.io, better CI tooling, cross-compilation via cargo-zigbuild).
       - Decision: Adopt Rust, remove Zig implementation.
       - Rationale with benchmark data: Reference the benchmark results from quick task 22 (bench-rust-vs-zig.sh). Key points:
         - Rust is 1.5-3.1x faster than Zig with parallel analysis
         - Rust has superior ecosystem: cargo for dependency management, crates.io for libraries, derive macros reduce boilerplate
         - Cross-compilation is simpler with cargo-zigbuild
         - tree-sitter Rust crates are maintained upstream (vs vendored C submodules for Zig)
         - CI setup is simpler (standard cargo commands vs Zig build system)
       - Consequences: Zig code removed, single implementation to maintain, existing benchmarks in zig/benchmarks/ archived in git history

    2. Remove the Zig tree-sitter git submodules:
       ```
       git submodule deinit -f zig/vendor/tree-sitter
       git submodule deinit -f zig/vendor/tree-sitter-typescript
       git submodule deinit -f zig/vendor/tree-sitter-javascript
       git rm -rf zig/vendor/tree-sitter
       git rm -rf zig/vendor/tree-sitter-typescript
       git rm -rf zig/vendor/tree-sitter-javascript
       ```

    3. Remove the entire `zig/` directory:
       ```
       git rm -rf zig/
       ```
       Also remove `zig-out/` and `.zig-cache/` if they exist (these are in .gitignore but may have leaked).

    4. Remove `.gitmodules` file entirely (it only contained Zig submodules).

    5. Delete `.github/workflows/test.yml` (Zig test + Valgrind memory check workflow — entirely Zig-specific). The Rust CI is in `rust-ci.yml`.

    6. Delete `scripts/check-memory.sh` (Valgrind-based memory check for Zig binary — not applicable to Rust).

    7. Update `.gitignore`:
       - Remove all Zig-related entries (zig/zig-out/, zig/.zig-cache/, zig/zig-cache/, zig/zig-pkg/, zig/benchmarks/projects/, zig/tests/repos/)
       - Change `rust/target/` to `/target/` (will be at root after Task 2)
       - Keep all other entries unchanged
  </action>
  <verify>
    <automated>test ! -d zig && test ! -f .gitmodules && test ! -f .github/workflows/test.yml && test ! -f scripts/check-memory.sh && test -f docs/architecture-decision-rust.md && echo "PASS"</automated>
  </verify>
  <done>Zig code, submodules, and Zig-only CI/scripts are removed. ADR exists documenting the rationale.</done>
</task>

<task type="auto">
  <name>Task 2: Move Rust code to project root and update all references</name>
  <files>
    Cargo.toml
    Cargo.lock
    src/
    tests/
    .github/workflows/rust-ci.yml
    .github/workflows/rust-release.yml
    .github/workflows/release.yml
    scripts/release.sh
    README.md
    CLAUDE.md
    PUBLISHING.md
    docs/getting-started.md
    docs/releasing.md
    docs/benchmarks.md
    docs/cli-reference.md
    docs/examples.md
    publication/npm/README.md
    publication/npm/packages/darwin-arm64/README.md
    publication/npm/packages/darwin-x64/README.md
    publication/npm/packages/linux-arm64/README.md
    publication/npm/packages/linux-x64/README.md
    publication/npm/packages/windows-x64/README.md
    publication/homebrew/complexity-guard.rb
  </files>
  <action>
    **Phase A: Move Rust files to project root**

    1. Move `rust/Cargo.toml`, `rust/Cargo.lock`, `rust/src/`, `rust/tests/` to project root using git mv:
       ```
       git mv rust/Cargo.toml Cargo.toml
       git mv rust/Cargo.lock Cargo.lock
       git mv rust/src src
       git mv rust/tests/integration_tests.rs tests/integration_tests.rs
       git mv rust/tests/parser_tests.rs tests/parser_tests.rs
       git mv rust/tests/fixtures tests/rust-fixtures
       ```
       Note: `tests/fixtures/` already exists (shared fixtures). The Rust-specific test fixtures in `rust/tests/fixtures/` should be moved to `tests/rust-fixtures/` or merged. Check contents first.

    2. Remove the now-empty `rust/` directory (including `rust/.gitignore` and `rust/target/`).

    3. Update `Cargo.toml` if any paths reference `rust/` (unlikely but check).

    4. Update `tests/integration_tests.rs` and `tests/parser_tests.rs`: search for any path references to `rust/` or `../tests/fixtures` and update to reflect new root-relative paths. The integration tests likely reference `tests/fixtures/` which is now a sibling — check and fix any `../tests/fixtures` patterns to just `tests/fixtures`.

    **Phase B: Rename CI workflows**

    5. Rename `rust-ci.yml` to `ci.yml` and `rust-release.yml` to `release.yml`:
       - `git mv .github/workflows/rust-ci.yml .github/workflows/ci.yml`
       - Delete the old Zig `release.yml` first: `git rm .github/workflows/release.yml`
       - `git mv .github/workflows/rust-release.yml .github/workflows/release.yml`

    6. Update `ci.yml` (formerly rust-ci.yml):
       - Change `name: Rust CI` to `name: CI`
       - Remove `working-directory: rust` or `cd rust` prefixes from all steps — cargo commands should now run from project root
       - Update any path filters if they reference `rust/`

    7. Update `release.yml` (formerly rust-release.yml):
       - Change `name: Rust Release` to `name: Release`
       - Remove `working-directory: rust` or `cd rust` prefixes from all cargo/build steps
       - Update any path references from `rust/target/` to `target/`
       - Remove comment about "legacy Zig workflow" since there is none anymore

    **Phase C: Update scripts**

    8. Update `scripts/release.sh`:
       - Change version source from `rust/Cargo.toml` to `Cargo.toml`
       - Update all `sed` commands that reference `rust/Cargo.toml` to just `Cargo.toml`
       - Update `git add rust/Cargo.toml` to `git add Cargo.toml`
       - Update comments referencing `rust/Cargo.toml`

    **Phase D: Update all documentation**

    9. Update `CLAUDE.md`:
       - Change project description from "Zig-based" to "Rust-based"
       - Replace Build & Test section with Rust commands: `cargo build --release`, `cargo test`
       - Update Project Structure: remove zig/ entry, show src/, Cargo.toml, tests/ at root, remove rust/ subdirectory reference
       - Remove entire "Zig Conventions" section
       - Remove Zig-specific "Code Patterns" section
       - Add brief "Rust Conventions" section if appropriate (or just remove language-specific conventions since Rust conventions are standard)
       - Keep GSD Workflow Rules unchanged

    10. Update `README.md`:
        - "Building from Source" section: change `cd rust && cargo build --release` to just `cargo build --release`
        - Remove "For the legacy Zig source" paragraph entirely
        - Binary path: change `rust/target/release/complexity-guard` to `target/release/complexity-guard`

    11. Update `PUBLISHING.md`:
        - Replace the entire "Building binaries locally" section that shows `cd zig && zig build` commands
        - Replace with Rust cross-compilation commands using cargo-zigbuild or just `cargo build --release --target <triple>`
        - Update any other Zig references

    12. Update `docs/getting-started.md`:
        - "Building from Source" section: change `cd rust && cargo build --release` to `cargo build --release`
        - Update binary path from `rust/target/release/complexity-guard` to `target/release/complexity-guard`

    13. Update `docs/releasing.md`:
        - Change `rust/Cargo.toml` references to `Cargo.toml`
        - Remove "legacy Zig release workflow" references
        - Remove mentions of `release.yml` being the Zig workflow
        - The workflow is now just `release.yml` (the Rust one)

    14. Update `docs/benchmarks.md`: Search for Zig references. The Rust vs FTA benchmarks should stay. Remove or update any "Zig vs Rust" comparison sections — note that historical benchmark data is preserved in git history.

    15. Update `docs/cli-reference.md` and `docs/examples.md`: Search for any `rust/` path references or `cd rust` commands and remove the `rust/` prefix.

    16. Update `publication/homebrew/complexity-guard.rb`: Update comments that reference "Zig cross-compilation target names" to just reference build targets.

    17. Update all publication README files (`publication/npm/README.md` and `publication/npm/packages/*/README.md`): Search for any Zig references or `rust/` path references and update.

    **Phase E: Verify**

    18. Run `cargo test` from project root to confirm everything works.
    19. Run `cargo build --release` from project root to confirm build works.
  </action>
  <verify>
    <automated>test -f Cargo.toml && test -f src/main.rs && test ! -d rust && cd /Users/benvds/code/complexity-guard && cargo test 2>&1 | tail -5 && echo "PASS"</automated>
  </verify>
  <done>
    Rust code lives at project root. `cargo build` and `cargo test` work from project root. All documentation, CI workflows, and scripts reference root-level paths. No `rust/` subdirectory references remain. No Zig references remain in active documentation (historical references in .planning/ are left as-is). Publication READMEs are updated.
  </done>
</task>

</tasks>

<verification>
1. `cargo test` passes from project root
2. `cargo build --release` succeeds from project root
3. `test ! -d zig` — no Zig directory
4. `test ! -d rust` — no rust subdirectory
5. `test -f docs/architecture-decision-rust.md` — ADR exists
6. `grep -r "cd rust" README.md docs/ scripts/ .github/` returns no matches
7. `grep -r "rust/Cargo" README.md docs/ scripts/ .github/` returns no matches
8. `grep -rL "zig" .github/workflows/` confirms no Zig references in CI (should show all workflow files = no matches for zig)
</verification>

<success_criteria>
- ADR documents the Zig-to-Rust decision with benchmark rationale
- Zero Zig code, submodules, or Zig-specific infrastructure remains
- Rust project builds and tests from project root (no rust/ subdirectory)
- All documentation, CI, and scripts reference root-level Rust paths
- Publication READMEs updated to stay in sync with main README
</success_criteria>

<output>
After completion, create `.planning/quick/23-rust-is-faster-so-were-going-with-rust-d/23-SUMMARY.md`
</output>
