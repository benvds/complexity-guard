---
phase: quick-21
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - zig/                        # new directory (moved from root)
  - zig/src/                    # moved from src/
  - zig/build.zig               # moved from build.zig
  - zig/build.zig.zon           # moved from build.zig.zon
  - zig/vendor/                 # moved from vendor/
  - zig/tests/                  # Zig-specific test files (public-projects.json)
  - zig/.valgrind.supp          # moved from .valgrind.supp
  - zig/benchmarks/             # moved from benchmarks/
  - .gitmodules                 # updated submodule paths
  - .gitignore                  # updated Zig artifact paths
  - CLAUDE.md                   # updated paths and build commands
  - README.md                   # updated Zig build paths
  - scripts/check-memory.sh     # updated binary and fixture paths
  - .github/workflows/test.yml  # updated to run from zig/ directory
  - .github/workflows/release.yml # updated to run from zig/ directory
autonomous: true
requirements: []

must_haves:
  truths:
    - "Zig code lives in zig/ directory mirroring rust/ structure"
    - "Rust tests still pass (shared fixtures at tests/fixtures/ unchanged)"
    - "Zig build commands work from zig/ directory"
    - "Git submodules point to zig/vendor/* paths"
    - "CI workflows reference correct zig/ paths"
  artifacts:
    - path: "zig/build.zig"
      provides: "Zig build configuration"
    - path: "zig/src/main.zig"
      provides: "Zig entry point"
    - path: "zig/vendor/tree-sitter"
      provides: "Tree-sitter submodule at new path"
    - path: "tests/fixtures/"
      provides: "Shared test fixtures (unchanged location)"
  key_links:
    - from: ".gitmodules"
      to: "zig/vendor/*"
      via: "submodule path declarations"
      pattern: "path = zig/vendor"
    - from: ".github/workflows/test.yml"
      to: "zig/"
      via: "working-directory or cd commands"
      pattern: "zig build"
    - from: "rust/tests/integration_tests.rs"
      to: "tests/fixtures/"
      via: "CARGO_MANIFEST_DIR/../tests/fixtures/"
      pattern: "join.*\\.\\."
---

<objective>
Move all Zig-specific code from the project root into a `zig/` directory, mirroring the existing `rust/` directory structure. This creates a clean multi-language monorepo layout where each implementation lives in its own subdirectory.

Purpose: The project has both a Zig implementation (original v1.0) and a Rust implementation (v0.8) side by side. Currently Zig files are scattered at root while Rust is neatly in `rust/`. Moving Zig into `zig/` makes the structure symmetric and cleaner.

Output: All Zig code under `zig/`, shared `tests/fixtures/` remaining at root, all references updated.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.gitmodules
@.gitignore
@.github/workflows/test.yml
@.github/workflows/release.yml
@scripts/check-memory.sh
@README.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Move Zig files into zig/ directory and update git submodules</name>
  <files>
    zig/ (new directory)
    zig/src/ (moved from src/)
    zig/build.zig (moved from build.zig)
    zig/build.zig.zon (moved from build.zig.zon)
    zig/vendor/ (moved from vendor/)
    zig/tests/public-projects.json (moved from tests/public-projects.json)
    zig/.valgrind.supp (moved from .valgrind.supp)
    zig/benchmarks/ (moved from benchmarks/)
    .gitmodules
    .gitignore
  </files>
  <action>
Move Zig-specific files and directories into a new `zig/` directory. The shared `tests/fixtures/` directory stays at root since both Zig and Rust reference it.

**Step 1 - Create zig/ directory and move files using git mv:**

```
mkdir -p zig

# Move Zig source and build files
git mv src/ zig/src/
git mv build.zig zig/build.zig
git mv build.zig.zon zig/build.zig.zon

# Move vendor submodules (requires special handling)
git mv vendor/ zig/vendor/

# Move Zig-specific test file (NOT the shared fixtures directory)
mkdir -p zig/tests
git mv tests/public-projects.json zig/tests/public-projects.json

# Move valgrind suppressions (Zig-specific)
git mv .valgrind.supp zig/.valgrind.supp

# Move benchmarks (contains Zig benchmark binary source)
git mv benchmarks/ zig/benchmarks/
```

**Step 2 - Update .gitmodules** to reflect new vendor paths:
- Change `path = vendor/tree-sitter` to `path = zig/vendor/tree-sitter`
- Change `path = vendor/tree-sitter-typescript` to `path = zig/vendor/tree-sitter-typescript`
- Change `path = vendor/tree-sitter-javascript` to `path = zig/vendor/tree-sitter-javascript`

**Step 3 - Update .gitignore:**
- Change `zig-out/` to `zig/zig-out/`
- Change `.zig-cache/` to `zig/.zig-cache/`
- Change `zig-cache/` to `zig/zig-cache/`
- Change `zig-pkg/` to `zig/zig-pkg/`
- Change `benchmarks/projects/*/` to `zig/benchmarks/projects/*/`
- Change `!benchmarks/projects/.gitkeep` to `!zig/benchmarks/projects/.gitkeep`
- Change `tests/repos/` to `zig/tests/repos/`

**Step 4 - Verify the shared tests/fixtures/ directory remains at root.** The `tests/` directory should still exist with just `fixtures/` in it (the `public-projects.json` was moved to `zig/tests/`). Verify Rust fixture path resolution still works: `CARGO_MANIFEST_DIR/../tests/fixtures/` from `rust/` still resolves correctly since `tests/fixtures/` stays at root.

**IMPORTANT:** After `git mv vendor/`, Git needs the submodule config synced. Run `git submodule sync` after updating `.gitmodules` to ensure the submodule paths are consistent.

**NOTE on build.zig:** The `build.zig` file likely has hardcoded paths to `vendor/` and `src/`. These are RELATIVE paths within the Zig project, so they should still work correctly when run from the `zig/` directory (since `vendor/` moves alongside `build.zig`). However, verify by checking `build.zig` for any absolute or root-relative paths that might break.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && test -f zig/build.zig && test -f zig/build.zig.zon && test -d zig/src/main.zig -o -f zig/src/main.zig && test -d zig/vendor/tree-sitter && test -d tests/fixtures/typescript && grep -q "path = zig/vendor/tree-sitter" .gitmodules && echo "PASS: Files moved and submodules updated" || echo "FAIL"</automated>
    <manual>Verify zig/ directory structure looks clean with ls -la zig/</manual>
  </verify>
  <done>All Zig-specific files live under zig/. Shared tests/fixtures/ remains at project root. Git submodule paths in .gitmodules point to zig/vendor/*. .gitignore references updated to zig/ prefix.</done>
</task>

<task type="auto">
  <name>Task 2: Update all references in docs, scripts, and CI workflows</name>
  <files>
    CLAUDE.md
    README.md
    scripts/check-memory.sh
    .github/workflows/test.yml
    .github/workflows/release.yml
    docs/getting-started.md
    docs/cli-reference.md
    docs/examples.md
    docs/benchmarks.md
    docs/releasing.md
    publication/npm/README.md
    publication/npm/packages/darwin-arm64/README.md
    publication/npm/packages/darwin-x64/README.md
    publication/npm/packages/linux-arm64/README.md
    publication/npm/packages/linux-x64/README.md
    publication/npm/packages/windows-x64/README.md
  </files>
  <action>
Update all files that reference Zig paths to use the new `zig/` prefix.

**CLAUDE.md updates:**
- Update "Build and Test" section: `cd zig && zig build` (or document the working directory requirement)
- Update "Project Structure" to show `zig/` directory containing `src/`, `build.zig`, etc.
- Update any path references from `src/` to `zig/src/`, `tests/fixtures/` stays as-is

**README.md updates:**
- Update build command references from `zig build` to `cd zig && zig build` (or equivalent)
- Update any path references to `zig-out/bin/` to `zig/zig-out/bin/`
- Keep the Rust build instructions (in `rust/`) as they are

**scripts/check-memory.sh updates:**
- Change `BINARY="./zig-out/bin/complexity-guard"` to `BINARY="./zig/zig-out/bin/complexity-guard"`
- Change `FIXTURES="tests/fixtures/typescript"` to `FIXTURES="tests/fixtures/typescript"` (stays same -- shared fixtures at root)
- Update any `zig build` commands to run from `zig/` directory

**.github/workflows/test.yml updates:**
- Add `working-directory: zig` or prefix `zig build test` with `cd zig &&`
- Update `scripts/check-memory.sh` path if needed
- The `submodules: true` checkout already handles submodules regardless of path

**.github/workflows/release.yml updates:**
- Update `zig build` commands to run from `zig/` directory
- Update `zig-out/bin/complexity-guard` references to `zig/zig-out/bin/complexity-guard`

**docs/ updates:**
- `docs/getting-started.md`: Update any `zig build` or `zig-out/` references
- `docs/cli-reference.md`: Update binary path references
- `docs/examples.md`: Update any build/binary path references
- `docs/benchmarks.md`: Update benchmark script and binary paths
- `docs/releasing.md`: Update any Zig build/path references

**Benchmark script updates (now at zig/benchmarks/scripts/):**
- These files were already moved in Task 1. Their internal references to `$PROJECT_ROOT/zig-out/bin/` need updating to `$PROJECT_ROOT/zig/zig-out/bin/` since they use PROJECT_ROOT (repo root).

**publication/ README updates:**
- Update any `zig build` or path references to reflect the `zig/` directory structure (per CLAUDE.md GSD workflow rule about syncing publication READMEs)

**IMPORTANT:** Do NOT update paths in `.planning/` files -- those are historical records and should not be edited.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && ! grep -r "zig-out/bin" --include="*.yml" --include="*.sh" --include="*.md" . --exclude-dir=.planning --exclude-dir=.git --exclude-dir=zig | grep -v "zig/zig-out/bin" | grep -v "rust/" | head -5 && echo "PASS: No stale zig-out/bin references outside .planning/" || echo "WARNING: Check stale references"</automated>
    <manual>Spot-check CLAUDE.md and README.md for correct zig/ paths</manual>
  </verify>
  <done>All docs, scripts, and CI workflows reference zig/ paths correctly. CLAUDE.md project structure reflects new layout. README.md build instructions updated. CI workflows run Zig builds from zig/ directory. Publication READMEs synced.</done>
</task>

<task type="auto">
  <name>Task 3: Verify Rust tests still pass with shared fixtures at root</name>
  <files>(no files modified -- verification only)</files>
  <action>
Run the Rust test suite to confirm the shared `tests/fixtures/` directory at project root is still correctly resolved by the Rust code.

The Rust code uses `env!("CARGO_MANIFEST_DIR")` which resolves to the `rust/` directory. From there it does `join("..")` to get to project root, then `join("tests/fixtures/...")`. Since `tests/fixtures/` stays at root, this should work unchanged.

Run:
```
cd rust && cargo test
```

If tests fail due to fixture path issues, the `tests/fixtures/` symlink or path approach needs adjustment. But based on analysis, no changes should be needed since the shared fixtures remain at project root.

Also verify the Zig build still works from the new location:
```
cd zig && zig build test
```

Note: The Zig build may fail if the tree-sitter submodules aren't properly synced after the move. If so, run `git submodule sync && git submodule update` first.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard/rust && cargo test 2>&1 | tail -5</automated>
    <manual>Confirm "test result: ok" in output</manual>
  </verify>
  <done>Rust test suite passes with all tests finding fixtures at tests/fixtures/. No path resolution regressions from the Zig directory reorganization.</done>
</task>

</tasks>

<verification>
1. `ls zig/` shows: build.zig, build.zig.zon, src/, vendor/, tests/, benchmarks/, .valgrind.supp
2. `ls tests/fixtures/` shows: typescript/, javascript/, naming-edge-cases.ts (shared fixtures at root)
3. `grep "path = zig/vendor" .gitmodules` shows all three submodule paths updated
4. `cd rust && cargo test` passes (shared fixtures still accessible)
5. No stale root-level `src/`, `build.zig`, `vendor/` remain
6. CI workflow YAML files reference `zig/` paths
</verification>

<success_criteria>
- Zig code fully contained in zig/ directory
- Shared test fixtures remain at tests/fixtures/ (used by both Zig and Rust)
- Git submodules correctly point to zig/vendor/*
- Rust tests pass without modification
- All docs, scripts, and CI workflows reference correct paths
- No stale Zig-related files at project root
</success_criteria>

<output>
After completion, create `.planning/quick/21-move-zig-code-to-zig-directory-to-match-/21-SUMMARY.md`
</output>
