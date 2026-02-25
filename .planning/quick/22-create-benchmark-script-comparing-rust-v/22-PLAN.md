---
phase: quick-22
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - zig/benchmarks/scripts/bench-rust-vs-zig.sh
autonomous: true
requirements: [QUICK-22]
must_haves:
  truths:
    - "Script benchmarks Rust binary against Zig binary on all 10 quick suite projects"
    - "Script outputs a comparison table with mean times and speedup ratio for each project"
    - "Results are saved as JSON files for later analysis"
  artifacts:
    - path: "zig/benchmarks/scripts/bench-rust-vs-zig.sh"
      provides: "Hyperfine benchmark comparing Rust vs Zig binaries"
      contains: "hyperfine"
  key_links:
    - from: "zig/benchmarks/scripts/bench-rust-vs-zig.sh"
      to: "rust/target/release/complexity-guard"
      via: "cargo build --release"
      pattern: "cargo build --release"
    - from: "zig/benchmarks/scripts/bench-rust-vs-zig.sh"
      to: "zig/zig-out/bin/complexity-guard"
      via: "zig build -Doptimize=ReleaseFast"
      pattern: "zig build.*ReleaseFast"
---

<objective>
Create a benchmark script that compares the Rust and Zig ComplexityGuard binaries head-to-head using hyperfine against the quick benchmark suite (10 projects).

Purpose: Quantify performance differences between the Rust rewrite (v0.8) and the original Zig implementation (v1.0) across real-world TypeScript/JavaScript projects.
Output: `zig/benchmarks/scripts/bench-rust-vs-zig.sh` -- executable benchmark script producing per-project JSON results and a summary comparison table.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@zig/benchmarks/scripts/bench-quick.sh (existing benchmark script to use as template)
@zig/benchmarks/README.md (benchmark infrastructure documentation)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create bench-rust-vs-zig.sh benchmark script</name>
  <files>zig/benchmarks/scripts/bench-rust-vs-zig.sh</files>
  <action>
Create `zig/benchmarks/scripts/bench-rust-vs-zig.sh` modeled on the existing `bench-quick.sh` but comparing Rust vs Zig instead of CG vs FTA.

Key implementation details:

1. **Prerequisites check**: Verify hyperfine and jq are installed (same pattern as bench-quick.sh).

2. **Build both binaries**:
   - Zig: `cd "$PROJECT_ROOT/zig" && zig build -Doptimize=ReleaseFast` -> binary at `zig/zig-out/bin/complexity-guard`
   - Rust: `cd "$PROJECT_ROOT/rust" && cargo build --release` -> binary at `rust/target/release/complexity-guard`
   - Print both binary versions after build.

3. **Results directory**: `zig/benchmarks/results/rust-vs-zig-YYYY-MM-DD/` (distinct prefix from "baseline-" used by CG-vs-FTA benchmarks). Reuse the `capture_system_info` function from bench-quick.sh (copy the function into this script).

4. **Quick suite projects**: Same 10 projects as bench-quick.sh: `zod got dayjs vite nestjs webpack typeorm rxjs effect vscode`. Verify projects exist in `zig/benchmarks/projects/` and error with setup instructions if none found.

5. **Hyperfine invocation per project**: Use 3 warmup runs, 15 measured runs, `--ignore-failure` flag. Both binaries use identical arguments: `--format json --fail-on none <project_dir>`. Name the commands "Rust" and "Zig" using `--command-name` flags for clarity in output. Export JSON to `$RESULTS_DIR/${project}-rust-vs-zig.json`.
   ```
   "$HYPERFINE" \
     --warmup 3 \
     --runs 15 \
     --ignore-failure \
     --command-name "Rust" \
     --command-name "Zig" \
     --export-json "$RESULT_JSON" \
     "${RUST_BIN} --format json --fail-on none ${PROJECT_DIR}" \
     "${ZIG_BIN} --format json --fail-on none ${PROJECT_DIR}"
   ```

6. **Summary table**: After all projects, print a table with columns: Project, Rust (ms), Zig (ms), Ratio (Rust/Zig). Ratio < 1.0 means Rust is faster. Use jq to extract `results[0].mean` (Rust) and `results[1].mean` (Zig) from each JSON file.

7. **Overall summary line**: Print average ratio across all projects at the bottom.

8. Make the script executable (`chmod +x`).

The script should NOT require FTA or Node.js -- it only compares the two native binaries.
  </action>
  <verify>
    <automated>bash -n zig/benchmarks/scripts/bench-rust-vs-zig.sh && test -x zig/benchmarks/scripts/bench-rust-vs-zig.sh && echo "Script syntax OK and executable"</automated>
    <manual>Run `bash zig/benchmarks/scripts/bench-rust-vs-zig.sh` (requires benchmark projects cloned via setup.sh --suite quick) and verify it produces JSON results and a comparison table</manual>
  </verify>
  <done>Script exists at zig/benchmarks/scripts/bench-rust-vs-zig.sh, is executable, passes bash syntax check, builds both binaries, runs hyperfine on all 10 quick suite projects comparing Rust vs Zig, and prints a summary table with per-project timings and ratios.</done>
</task>

<task type="auto">
  <name>Task 2: Update benchmarks README with Rust-vs-Zig documentation</name>
  <files>zig/benchmarks/README.md</files>
  <action>
Update `zig/benchmarks/README.md` to document the new script:

1. In the **Script Reference** table, add a row:
   `| bench-rust-vs-zig.sh | Hyperfine benchmark: Rust binary vs Zig binary, quick suite | results/rust-vs-zig-*/\*-rust-vs-zig.json |`

2. In the **Quick Start** section, add a new step after the existing ones:
   ```
   # 5. Rust vs Zig binary comparison (requires both toolchains)
   bash benchmarks/scripts/bench-rust-vs-zig.sh
   ```

3. In the **Prerequisites** section, add:
   - **Rust / Cargo** -- for building the Rust binary (`cargo build --release`)

4. In the **Results Directory Structure** section, add an example entry:
   ```
   rust-vs-zig-2026-02-25/          # Rust vs Zig comparison
     system-info.json
     zod-rust-vs-zig.json           # hyperfine JSON: Rust vs Zig timings for zod
     ...
   ```

5. In **Interpreting Results**, add a subsection:
   ```
   ### Rust vs Zig (Binary Comparison)

   `bench-rust-vs-zig.sh` reports Rust/Zig ratio:

   - **< 1.0**: Rust is faster
   - **= 1.0**: Equal performance
   - **> 1.0**: Zig is faster
   ```

Do NOT change any existing content beyond adding these new sections/rows.
  </action>
  <verify>
    <automated>grep -q "bench-rust-vs-zig.sh" zig/benchmarks/README.md && grep -q "Rust vs Zig" zig/benchmarks/README.md && echo "README updated"</automated>
  </verify>
  <done>Benchmarks README documents the new script in the script reference table, quick start, prerequisites, results structure, and interpreting results sections.</done>
</task>

</tasks>

<verification>
- `bash -n zig/benchmarks/scripts/bench-rust-vs-zig.sh` passes (no syntax errors)
- `test -x zig/benchmarks/scripts/bench-rust-vs-zig.sh` passes (executable)
- `grep "bench-rust-vs-zig" zig/benchmarks/README.md` finds documentation entries
- Script references both `zig build -Doptimize=ReleaseFast` and `cargo build --release`
- Script uses same quick suite project list as bench-quick.sh
</verification>

<success_criteria>
A single `bash zig/benchmarks/scripts/bench-rust-vs-zig.sh` command builds both binaries, runs hyperfine comparisons on all 10 quick suite projects, saves per-project JSON results, and prints a summary table showing Rust vs Zig performance.
</success_criteria>

<output>
After completion, create `.planning/quick/22-create-benchmark-script-comparing-rust-v/22-SUMMARY.md`
</output>
