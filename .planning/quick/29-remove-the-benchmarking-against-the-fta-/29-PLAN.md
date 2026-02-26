---
phase: quick-29
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/bench-quick.sh
  - benchmarks/scripts/bench-full.sh
  - benchmarks/scripts/bench-stress.sh
  - benchmarks/scripts/bench-duplication.sh
  - benchmarks/scripts/summarize-results.mjs
  - benchmarks/README.md
  - docs/benchmarks.md
  - README.md
  - publication/npm/README.md
  - publication/npm/packages/darwin-arm64/README.md
  - publication/npm/packages/darwin-x64/README.md
  - publication/npm/packages/linux-x64/README.md
  - publication/npm/packages/linux-arm64/README.md
  - publication/npm/packages/windows-x64/README.md
autonomous: true
requirements: [QUICK-29]

must_haves:
  truths:
    - "bench-quick.sh runs only complexity-guard (no FTA install, no FTA benchmark)"
    - "bench-full.sh runs only complexity-guard (no FTA install, no FTA benchmark)"
    - "bench-stress.sh runs only complexity-guard (no FTA install, no FTA benchmark)"
    - "summarize-results.mjs reports CG-only timing (no FTA columns, no speedup ratio)"
    - "benchmarks/README.md describes CG-only benchmarking with no FTA references"
    - "docs/benchmarks.md presents CG performance data without FTA comparison"
    - "README.md and publication READMEs describe CG performance without FTA references"
  artifacts:
    - path: "benchmarks/scripts/bench-quick.sh"
      provides: "CG-only quick suite benchmark"
    - path: "benchmarks/scripts/bench-full.sh"
      provides: "CG-only full suite benchmark"
    - path: "benchmarks/scripts/bench-stress.sh"
      provides: "CG-only stress suite benchmark"
    - path: "benchmarks/scripts/summarize-results.mjs"
      provides: "CG-only results summarizer"
    - path: "benchmarks/README.md"
      provides: "CG-only benchmark documentation"
    - path: "docs/benchmarks.md"
      provides: "CG-only performance documentation"
  key_links:
    - from: "benchmarks/scripts/bench-quick.sh"
      to: "benchmarks/results/"
      via: "hyperfine CG-only JSON output"
      pattern: "hyperfine.*complexity-guard"
---

<objective>
Remove all FTA (Fast TypeScript Analyzer) benchmarking from the benchmarks/ directory and documentation. After this change, benchmarks only measure ComplexityGuard itself (absolute performance, parallelization impact, duplication overhead). The compare-metrics.sh and compare-metrics.mjs scripts are deleted entirely since they exist solely for CG-vs-FTA metric comparison.

Purpose: Simplify benchmarking to focus on CG's own performance regression tracking rather than competitive comparison with an external tool.
Output: CG-only benchmark scripts, updated summarizer, updated README and docs.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@benchmarks/scripts/bench-quick.sh
@benchmarks/scripts/bench-full.sh
@benchmarks/scripts/bench-stress.sh
@benchmarks/scripts/bench-duplication.sh
@benchmarks/scripts/compare-metrics.sh
@benchmarks/scripts/compare-metrics.mjs
@benchmarks/scripts/summarize-results.mjs
@benchmarks/scripts/setup.sh
@benchmarks/README.md
@docs/benchmarks.md
@README.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove FTA from benchmark scripts and delete comparison scripts</name>
  <files>
    benchmarks/scripts/bench-quick.sh
    benchmarks/scripts/bench-full.sh
    benchmarks/scripts/bench-stress.sh
    benchmarks/scripts/bench-duplication.sh
    benchmarks/scripts/summarize-results.mjs
    benchmarks/scripts/compare-metrics.sh (DELETE)
    benchmarks/scripts/compare-metrics.mjs (DELETE)
  </files>
  <action>
**Delete entirely:**
- `benchmarks/scripts/compare-metrics.sh` — exists solely for CG-vs-FTA metric comparison
- `benchmarks/scripts/compare-metrics.mjs` — exists solely for CG-vs-FTA metric comparison

**Modify bench-quick.sh:**
- Remove FTA auto-install block (FTA_VERSION, FTA_TEMP, mktemp, npm install, FTA_BIN, trap cleanup)
- Remove `node/npm` from prerequisites comment
- Change hyperfine invocation from two commands (CG + FTA) to one command (CG only). hyperfine with a single command still works — it just benchmarks that one command.
- Remove FTA_MEAN associative array and all FTA column references in the summary table
- Update summary table to show: Project, CG (ms) only (no FTA column, no Ratio column)
- Update banner from "ComplexityGuard vs FTA" to "ComplexityGuard Quick Suite Benchmark"
- Update header comment to reflect CG-only benchmarking

**Modify bench-full.sh:**
- Same changes as bench-quick.sh: remove FTA install, single-command hyperfine, CG-only summary table
- Update banner from "ComplexityGuard vs FTA" to "ComplexityGuard Full Suite Benchmark"

**Modify bench-stress.sh:**
- Same changes as bench-quick.sh: remove FTA install, single-command hyperfine, CG-only summary table
- Update banner from "ComplexityGuard vs FTA" to "ComplexityGuard Stress-Test Suite Benchmark"

**Modify bench-duplication.sh:**
- Remove the final tip line referencing "CG vs FTA comparison"
- This script already only benchmarks CG (with/without --duplication), so no other FTA changes needed

**Modify summarize-results.mjs:**
- `parseHyperfineFile()`: Expect `results[0]` only (CG). Remove fta_mean_ms, fta_stddev_ms, fta_mem_mb, speedup, mem_ratio fields. Accept files with 1 result (currently skips them). Return CG-only data: project, suite, cg_mean_ms, cg_stddev_ms, cg_mem_mb.
- `formatSpeedRow()`: Remove FTA columns. Table columns: Project, CG (ms), CG Mem (MB). No speedup label.
- `printSpeedTable()`: Update header to "Performance (CG)" or similar. Remove FTA columns and speedup/memory ratio footer.
- Remove `printMetricAccuracyTable()` function entirely (no metric accuracy without FTA).
- Remove metric-accuracy.json loading from `main()`.
- Remove FTA references from overall summary (no mean speed ratio, no memory ratio).
- Update page title from "ComplexityGuard vs FTA" to "ComplexityGuard Benchmark Summary".
  </action>
  <verify>
    bash -n benchmarks/scripts/bench-quick.sh && bash -n benchmarks/scripts/bench-full.sh && bash -n benchmarks/scripts/bench-stress.sh && bash -n benchmarks/scripts/bench-duplication.sh && echo "Shell scripts pass syntax check" && node --check benchmarks/scripts/summarize-results.mjs && echo "JS passes syntax check" && ! test -f benchmarks/scripts/compare-metrics.sh && ! test -f benchmarks/scripts/compare-metrics.mjs && echo "Comparison scripts deleted"
  </verify>
  <done>
    All bench scripts run CG only (no FTA install or FTA hyperfine command). compare-metrics.sh and compare-metrics.mjs are deleted. summarize-results.mjs produces CG-only output. All scripts pass syntax validation.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update benchmarks/README.md and docs/benchmarks.md</name>
  <files>
    benchmarks/README.md
    docs/benchmarks.md
  </files>
  <action>
**Rewrite benchmarks/README.md:**
- Change opening paragraph from "comparing ComplexityGuard against FTA" to "Performance benchmarks for ComplexityGuard across real-world TypeScript and JavaScript projects."
- Prerequisites: Remove "Node.js / npm — FTA is auto-installed" line. Keep hyperfine and jq.
- Quick Start: Remove step 3 (compare-metrics.sh). Keep setup.sh and bench-quick.sh. Keep summarize-results.mjs.
- Script Reference table: Remove compare-metrics.sh and compare-metrics.mjs rows. Update descriptions for bench scripts to say "CG benchmark" not "CG vs FTA".
- Results Directory Structure: Remove `metric-accuracy.json` reference. Update hyperfine JSON comment from "CG vs FTA timings" to "CG timings". Remove the FTA entry from hyperfine JSON schema example (keep only CG results[0]). Remove `results[0] is always CG; results[1] is always FTA` note. State `results[0]` is the CG benchmark.
- Remove Metric Accuracy JSON Schema section entirely.
- Interpreting Results: Remove Speed section about "speedup ratio" (CG/FTA). Replace with simple "Wall-clock time in milliseconds for CG analysis". Remove Memory Ratio section about FTA/CG RSS comparison — replace with "Peak RSS memory usage for CG". Remove Metric Accuracy section entirely (no FTA to compare against).
- Keep "Adding New Benchmark Runs" section but remove compare-metrics.sh step.
- Update "Project Sources" section — keep as-is (no FTA references there).

**Rewrite docs/benchmarks.md:**
- Change framing from "measured against FTA" to "measured across real-world TypeScript and JavaScript projects".
- Remove "The short version: CG is 1.5-3.1x faster than FTA..." intro sentence. Replace with something like "The short version: CG analyzes even the largest TypeScript codebases in seconds with parallel analysis."
- Key Findings > Speed table: Remove FTA (ms) and Speedup columns. Keep Project, CG (ms), Project Size. Remove "Mean: CG is 2.4x faster than FTA" — replace with "Mean analysis time: X ms across the quick suite" (compute from existing CG data).
- Keep Parallelization Impact section as-is (already CG-only comparison: single vs parallel).
- Key Findings > Memory table: Remove FTA Mem and Ratio columns. Keep Project, CG Mem (MB) only. Remove "Mean: FTA uses 1.3x more memory" line. Replace with "Mean CG memory: X MB" or similar.
- Remove "Metric Accuracy" section entirely (the ranking correlation table and all explanation).
- Methodology > Tool Versions table: Remove FTA row.
- Benchmark Commands section: Remove FTA command. Keep CG parallel and single-threaded commands.
- Important Caveats: Remove caveats 2, 3, 4 about FTA granularity, parsers, cyclomatic differences. Keep caveat 1 about parallel by default. Add a note that benchmarks measure wall-clock time for a full analysis pass.
- Keep Duplication Detection Performance section as-is (already CG-only).
- Baseline History: Remove FTA references in the schema version note. Remove "FTA JSON output" from schema list.
  </action>
  <verify>
    ! grep -i 'fta\|fast typescript analyzer' benchmarks/README.md docs/benchmarks.md && echo "No FTA references remain in benchmark docs"
  </verify>
  <done>
    benchmarks/README.md and docs/benchmarks.md describe CG-only benchmarking with zero FTA references. Documentation is coherent and self-contained.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update README.md and publication READMEs to remove FTA references</name>
  <files>
    README.md
    publication/npm/README.md
    publication/npm/packages/darwin-arm64/README.md
    publication/npm/packages/darwin-x64/README.md
    publication/npm/packages/linux-x64/README.md
    publication/npm/packages/linux-arm64/README.md
    publication/npm/packages/windows-x64/README.md
  </files>
  <action>
**README.md:**
- Line ~91: Change "1.5-3.1x faster than FTA with parallel analysis across all CPU cores" to something like "Analyzes thousands of files in seconds with parallel analysis across all CPU cores". Reference the benchmarks page for details.
- Line ~102: Change "Speed and memory comparison vs FTA across real-world projects" to "Speed and memory benchmarks across real-world projects"

**publication/npm/README.md:**
- Line ~57: Change "1.5-3.1x faster than FTA; analyzes files concurrently..." to "Analyzes files concurrently across all CPU cores by default; use `--threads N` to control thread count". Remove the FTA comparison claim.

**All 5 publication/npm/packages/*/README.md files:**
- Each has line ~21 with "1.5-3.1x faster than FTA; analyzes files concurrently...". Change to "Analyzes files concurrently across all CPU cores by default; use `--threads N` to control thread count". Remove the FTA comparison claim.
  </action>
  <verify>
    ! grep -ri 'fta' README.md publication/npm/README.md publication/npm/packages/*/README.md && echo "No FTA references in any README"
  </verify>
  <done>
    All README files (main, npm, platform packages) describe CG performance without FTA comparison claims.
  </done>
</task>

</tasks>

<verification>
1. `bash -n benchmarks/scripts/bench-quick.sh` passes (valid shell)
2. `bash -n benchmarks/scripts/bench-full.sh` passes (valid shell)
3. `bash -n benchmarks/scripts/bench-stress.sh` passes (valid shell)
4. `node --check benchmarks/scripts/summarize-results.mjs` passes (valid JS)
5. `! test -f benchmarks/scripts/compare-metrics.sh` (deleted)
6. `! test -f benchmarks/scripts/compare-metrics.mjs` (deleted)
7. `grep -ri 'fta' benchmarks/ README.md docs/benchmarks.md publication/` returns no matches
8. `cargo test` still passes (no Rust code changed)
</verification>

<success_criteria>
- Zero references to FTA, fta-cli, or "Fast TypeScript Analyzer" in any benchmarks/ file, docs/benchmarks.md, README.md, or publication/ READMEs
- compare-metrics.sh and compare-metrics.mjs are deleted
- All bench scripts only invoke complexity-guard (single hyperfine command, no npm install)
- summarize-results.mjs produces CG-only summary output
- All scripts pass syntax validation
</success_criteria>

<output>
After completion, create `.planning/quick/29-remove-the-benchmarking-against-the-fta-/29-SUMMARY.md`
</output>
