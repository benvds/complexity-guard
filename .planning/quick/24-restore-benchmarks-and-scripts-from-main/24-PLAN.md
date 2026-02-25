---
phase: quick-24
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/bench-quick.sh
  - benchmarks/scripts/bench-full.sh
  - benchmarks/scripts/bench-stress.sh
  - benchmarks/scripts/bench-duplication.sh
  - benchmarks/scripts/compare-metrics.sh
  - benchmarks/scripts/compare-metrics.mjs
  - benchmarks/scripts/summarize-results.mjs
  - benchmarks/scripts/setup.sh
  - benchmarks/README.md
  - benchmarks/projects/.gitkeep
  - benchmarks/results/.gitkeep
  - benchmarks/results/baseline-2026-02-21/*
  - benchmarks/results/baseline-2026-02-21-single-threaded/*
  - benchmarks/results/baseline-2026-02-22/*
  - tests/public-projects.json
  - docs/benchmarks.md
autonomous: true
requirements: []

must_haves:
  truths:
    - "All benchmark shell scripts use cargo build --release and target/release/complexity-guard"
    - "No Zig references remain in any restored file"
    - "bench-subsystems.sh and benchmarks/src/benchmark.zig are NOT restored"
    - "benchmarks/README.md documents Rust toolchain prerequisites"
    - "Historical baseline results are preserved intact"
    - "docs/benchmarks.md has no subsystem breakdown references"
  artifacts:
    - path: "benchmarks/scripts/bench-quick.sh"
      provides: "Quick suite benchmark script using Rust binary"
    - path: "benchmarks/scripts/bench-full.sh"
      provides: "Full suite benchmark script using Rust binary"
    - path: "benchmarks/scripts/bench-stress.sh"
      provides: "Stress test benchmark script using Rust binary"
    - path: "benchmarks/scripts/bench-duplication.sh"
      provides: "Duplication overhead benchmark script using Rust binary"
    - path: "benchmarks/scripts/compare-metrics.sh"
      provides: "Metric comparison script using Rust binary"
    - path: "benchmarks/scripts/setup.sh"
      provides: "Project cloning script (no build references)"
    - path: "benchmarks/scripts/compare-metrics.mjs"
      provides: "Node.js metric comparison (no changes needed)"
    - path: "benchmarks/scripts/summarize-results.mjs"
      provides: "Node.js results summarizer (no changes needed)"
    - path: "benchmarks/README.md"
      provides: "Benchmark documentation for Rust implementation"
    - path: "tests/public-projects.json"
      provides: "Project list referenced by setup.sh and bench-full.sh"
  key_links:
    - from: "benchmarks/scripts/bench-quick.sh"
      to: "target/release/complexity-guard"
      via: "CG_BIN variable"
      pattern: "cargo build --release"
    - from: "benchmarks/scripts/setup.sh"
      to: "tests/public-projects.json"
      via: "PROJECTS_JSON variable"
      pattern: "tests/public-projects.json"
---

<objective>
Restore the benchmarks/ directory and tests/public-projects.json from the main branch into the rust branch. Update all shell scripts to use Rust build commands (cargo build --release) and binary paths (target/release/complexity-guard). Remove Zig-only artifacts (bench-subsystems.sh, benchmarks/src/benchmark.zig). Update benchmarks/README.md for Rust. Clean up outdated single-threaded comments in bench-stress.sh.

Purpose: The benchmarks directory was lost during the Zig-to-Rust transition. Restoring it with proper Rust references enables continued performance benchmarking.
Output: Complete benchmarks/ directory with Rust-compatible scripts, updated docs, and preserved historical baselines.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@docs/benchmarks.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restore files from main, update scripts for Rust</name>
  <files>
    benchmarks/scripts/bench-quick.sh
    benchmarks/scripts/bench-full.sh
    benchmarks/scripts/bench-stress.sh
    benchmarks/scripts/bench-duplication.sh
    benchmarks/scripts/compare-metrics.sh
    benchmarks/scripts/compare-metrics.mjs
    benchmarks/scripts/summarize-results.mjs
    benchmarks/scripts/setup.sh
    benchmarks/projects/.gitkeep
    benchmarks/results/.gitkeep
    benchmarks/results/baseline-2026-02-21/
    benchmarks/results/baseline-2026-02-21-single-threaded/
    benchmarks/results/baseline-2026-02-22/
    tests/public-projects.json
  </files>
  <action>
    Step 1: Restore unchanged files directly from main using git checkout:
    - `git checkout main -- benchmarks/scripts/setup.sh` (no build references, restore as-is)
    - `git checkout main -- benchmarks/scripts/compare-metrics.mjs` (pure Node.js, no Zig refs)
    - `git checkout main -- benchmarks/scripts/summarize-results.mjs` (pure Node.js, no Zig refs)
    - `git checkout main -- benchmarks/projects/.gitkeep`
    - `git checkout main -- benchmarks/results/.gitkeep`
    - `git checkout main -- benchmarks/results/baseline-2026-02-21/` (historical data, preserve intact)
    - `git checkout main -- benchmarks/results/baseline-2026-02-21-single-threaded/` (historical data)
    - `git checkout main -- benchmarks/results/baseline-2026-02-22/` (historical data)
    - `git checkout main -- tests/public-projects.json` (needed by setup.sh, bench-full.sh)

    Step 2: Restore and update shell scripts that have Zig references. For each of the following scripts, restore from main then apply these substitutions:

    **bench-quick.sh:**
    - Replace the "Build CG in ReleaseFast mode" block:
      - `echo "Building ComplexityGuard in ReleaseFast mode..."` -> `echo "Building ComplexityGuard in release mode..."`
      - `(cd "$PROJECT_ROOT" && zig build -Doptimize=ReleaseFast)` -> `(cd "$PROJECT_ROOT" && cargo build --release)`
      - `CG_BIN="$PROJECT_ROOT/zig-out/bin/complexity-guard"` -> `CG_BIN="$PROJECT_ROOT/target/release/complexity-guard"`

    **bench-full.sh:**
    - Same three substitutions as bench-quick.sh (identical build block pattern)

    **bench-stress.sh:**
    - Same three build substitutions as bench-quick.sh
    - Remove/update outdated single-threaded comments throughout:
      - In the file header comment block: Remove the line `#       ComplexityGuard is currently single-threaded (Phase 12 will add parallelization).` and `#       These results document the single-threaded baseline for before/after comparison.`
      - In the STRESS_SUITE comment: Remove the lines `# Note: ComplexityGuard is single-threaded at this baseline. Phase 12 will add` and `#       parallelization — rerun this suite after Phase 12 for before/after comparison.`
      - In the echo output: Change `echo "Limitation: CG is single-threaded (no parallelization until Phase 12)"` to remove this line entirely
      - In the summary table echo: Change `echo "(Single-threaded CG baseline — Phase 12 parallelization will improve this)"` to remove this line entirely
      - In the footer echo block: Remove the `echo "Phase 12 note: After parallelization is implemented, rerun this script to"` and the follow-up line `echo "  measure speedup. Compare $RESULTS_DIR/*-stress.json files."`

    **bench-duplication.sh:**
    - Replace `CG_BIN="$PROJECT_ROOT/zig-out/bin/complexity-guard"` -> `CG_BIN="$PROJECT_ROOT/target/release/complexity-guard"`
    - Replace the build fallback block: `(cd "$PROJECT_ROOT" && zig build -Doptimize=ReleaseFast)` -> `(cd "$PROJECT_ROOT" && cargo build --release)`
    - Update the "Binary not found" message: replace `$CG_BIN` path reference if it echoes the old path

    **compare-metrics.sh:**
    - Same three build substitutions as bench-quick.sh
    - Fix the `public-projects.json` path bug: `PROJECTS_JSON="$PROJECT_ROOT/benchmarks/public-projects.json"` -> `PROJECTS_JSON="$PROJECT_ROOT/tests/public-projects.json"`
    - Update the prerequisite comment: `#   - Zig must be available for CG ReleaseFast build` -> `#   - Rust toolchain must be available for cargo build`

    Step 3: Do NOT restore these files (they have no Rust equivalent):
    - benchmarks/src/benchmark.zig
    - benchmarks/scripts/bench-subsystems.sh

    Step 4: Verify no Zig references remain:
    - `grep -r "zig" benchmarks/scripts/` should return zero matches
    - `grep -r "zig-out" benchmarks/` should return zero matches (historical JSON data excluded since it contains command strings)
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && grep -rn "zig build\|zig-out\|Doptimize=Release\|Zig 0\.15" benchmarks/scripts/ && echo "FAIL: Zig references found" || echo "PASS: No Zig references in scripts"</automated>
    <manual>Spot-check bench-quick.sh has "cargo build --release" and "target/release/complexity-guard"</manual>
  </verify>
  <done>
    All benchmark scripts restored with Rust build commands. Historical baselines preserved. No Zig-only files (benchmark.zig, bench-subsystems.sh) restored. tests/public-projects.json restored. No Zig references in any script file.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update benchmarks/README.md and docs/benchmarks.md for Rust</name>
  <files>
    benchmarks/README.md
    docs/benchmarks.md
  </files>
  <action>
    **benchmarks/README.md** -- Restore from main then apply these changes:

    1. **Prerequisites section:**
       - Replace `- **Zig 0.15.2+** — for building ComplexityGuard in ReleaseFast mode` with `- **Rust stable toolchain** — for building ComplexityGuard (`cargo build --release`)`

    2. **Quick Start section:**
       - Remove step 3 entirely (the `bench-subsystems.sh` step and its comment)
       - Renumber step 4 to step 3

    3. **Script Reference table:**
       - Remove the `bench-subsystems.sh` row (`| bench-subsystems.sh | Zig subsystem timing: parse, cyclomatic, cognitive, halstead, structural | results/*/-subsystems.json |`)

    4. **Speed section ("Why FTA is currently faster"):**
       - Replace the entire "Why FTA is currently faster" paragraph. It says CG is single-threaded. Replace with:
         `**CG with parallel analysis:** CG uses rayon for parallel file processing (the default). It is 1.5-3.1x faster than FTA across the quick suite. Pass --threads 1 for single-threaded baseline comparison.`

    5. **Memory section:**
       - Replace `CG has no runtime — it's a native Zig binary.` with `CG has no runtime — it's a native Rust binary.`

    6. **Results Directory Structure:**
       - Remove the `zod-subsystems.json` line and its comment

    7. **Subsystem Breakdown section** (### Subsystem Breakdown):
       - Remove this entire section (starts with `### Subsystem Breakdown` and ends before `## Adding New Benchmark Runs`)

    8. **Adding New Benchmark Runs section:**
       - Remove references to Phase 11/12 in the heading — change to just `## Adding New Benchmark Runs`
       - Remove `bash benchmarks/scripts/bench-subsystems.sh` from the example commands if present
       - Update the "After Phase 11 or 12 changes are merged" text to something generic like "After making performance-affecting changes:"

    **docs/benchmarks.md** -- Already on rust branch and mostly correct. Verify it has no subsystem or Zig references. If any remain, remove them. Based on grep search, no subsystem references exist, so this file likely needs no changes. Double-check for any lingering "Zig" or "single-threaded" references that are incorrect.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && grep -n "zig\|Zig\|subsystem\|bench-subsystems\|Phase 12\|Phase 11" benchmarks/README.md && echo "FAIL: stale references found" || echo "PASS: README clean"</automated>
    <manual>Read benchmarks/README.md to confirm Rust prerequisites, no subsystem section, and accurate speed description</manual>
  </verify>
  <done>
    benchmarks/README.md reflects Rust toolchain, has no subsystem or Zig references, and accurately describes parallel CG performance. docs/benchmarks.md is verified clean.
  </done>
</task>

</tasks>

<verification>
1. `ls benchmarks/scripts/` shows: bench-quick.sh, bench-full.sh, bench-stress.sh, bench-duplication.sh, compare-metrics.sh, compare-metrics.mjs, summarize-results.mjs, setup.sh (8 files -- NO bench-subsystems.sh)
2. `ls benchmarks/src/` should NOT exist (benchmark.zig not restored)
3. `grep -rn "zig" benchmarks/scripts/` returns no matches
4. `grep -rn "zig-out" benchmarks/scripts/` returns no matches
5. `grep -c "cargo build --release" benchmarks/scripts/*.sh` shows matches in bench-quick.sh, bench-full.sh, bench-stress.sh, bench-duplication.sh, compare-metrics.sh (5 scripts)
6. `ls benchmarks/results/baseline-2026-02-21/` shows historical JSON files preserved
7. `ls benchmarks/results/baseline-2026-02-22/` shows historical JSON files preserved
8. `ls tests/public-projects.json` exists
9. `grep "Rust stable" benchmarks/README.md` matches in prerequisites
10. `grep "subsystem\|bench-subsystems" benchmarks/README.md` returns no matches
</verification>

<success_criteria>
- All 8 benchmark scripts restored and updated for Rust (cargo build, target/release path)
- No Zig-only files restored (benchmark.zig, bench-subsystems.sh)
- Historical baseline data preserved intact in benchmarks/results/
- tests/public-projects.json restored
- benchmarks/README.md fully updated for Rust (prerequisites, no subsystem section, accurate speed info)
- docs/benchmarks.md verified clean
- Zero "zig build", "zig-out", or "Zig 0.15" references in any script
</success_criteria>

<output>
After completion, create `.planning/quick/24-restore-benchmarks-and-scripts-from-main/24-SUMMARY.md`
</output>
