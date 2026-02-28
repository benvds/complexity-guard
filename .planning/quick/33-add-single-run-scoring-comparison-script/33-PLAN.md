---
phase: quick-33
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/scoring-algorithms.mjs
  - benchmarks/scripts/compare-scoring.mjs
  - benchmarks/scripts/score-project.mjs
autonomous: true
requirements: [QUICK-33]
must_haves:
  truths:
    - "Running score-project.mjs with a target directory produces a comparison table of all 8 scoring algorithms"
    - "compare-scoring.mjs still works identically after refactoring to use shared module"
    - "score-project.mjs builds the binary if needed before running"
  artifacts:
    - path: "benchmarks/scripts/scoring-algorithms.mjs"
      provides: "Shared scoring primitives, algorithm definitions, statistics helpers"
      exports: ["ALGORITHMS", "computeFunctionScore", "linearScore", "scoreFile", "scoreProject", "computeStats", "collectAllFunctions", "mean", "geometricMean", "minimum", "weightedMean", "percentile", "round", "fmtScore", "padEnd", "DEFAULT_WEIGHTS", "DEFAULT_THRESHOLDS"]
    - path: "benchmarks/scripts/score-project.mjs"
      provides: "Single-run scoring comparison CLI"
    - path: "benchmarks/scripts/compare-scoring.mjs"
      provides: "Multi-project batch scoring (refactored to import shared module)"
  key_links:
    - from: "benchmarks/scripts/score-project.mjs"
      to: "benchmarks/scripts/scoring-algorithms.mjs"
      via: "ESM import"
      pattern: "import.*from.*scoring-algorithms"
    - from: "benchmarks/scripts/compare-scoring.mjs"
      to: "benchmarks/scripts/scoring-algorithms.mjs"
      via: "ESM import"
      pattern: "import.*from.*scoring-algorithms"
    - from: "benchmarks/scripts/score-project.mjs"
      to: "target/release/complexity-guard"
      via: "child_process.execSync"
      pattern: "execSync.*complexity-guard.*--format json"
---

<objective>
Add a single-run scoring comparison script that runs complexity-guard once on any target directory and displays all 8 scoring algorithm variant scores side by side.

Purpose: Enable quick scoring algorithm comparison on any project without needing to set up the full benchmark suite (hyperfine, cloned repos, results directories). Useful for testing score tuning against local codebases.

Output: `benchmarks/scripts/score-project.mjs` script and `benchmarks/scripts/scoring-algorithms.mjs` shared module, with `compare-scoring.mjs` refactored to use the shared module.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@benchmarks/scripts/compare-scoring.mjs
@benchmarks/scripts/bench-quick.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extract shared scoring module and refactor compare-scoring.mjs</name>
  <files>benchmarks/scripts/scoring-algorithms.mjs, benchmarks/scripts/compare-scoring.mjs</files>
  <action>
Extract all scoring logic from compare-scoring.mjs into a new shared module benchmarks/scripts/scoring-algorithms.mjs.

The shared module should export:
- Scoring primitives: `linearScore`, `computeFunctionScore`
- Constants: `DEFAULT_WEIGHTS`, `DEFAULT_THRESHOLDS`
- Aggregation helpers: `mean`, `geometricMean`, `minimum`, `weightedMean`, `percentile`
- Algorithm map: `ALGORITHMS` (the full Map with all 8 algorithm definitions)
- Scoring engine: `scoreFunctionWithAlgorithm`, `scoreFile`, `scoreProject`
- Statistics: `computeStats`
- Data helpers: `collectAllFunctions`
- Formatting: `round`, `fmtScore`, `padEnd`

Then refactor compare-scoring.mjs to import everything from ./scoring-algorithms.mjs instead of defining it inline. The refactored compare-scoring.mjs should only contain:
- Its own argument parsing (resultsDir, --json flag)
- `detectLatestResultsDir()` and `loadAnalysisFiles()` (file I/O specific to batch mode)
- The main() function with the output formatting (tables, validation section, JSON output)

Ensure all imports use relative path `./scoring-algorithms.mjs`.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26 2>&1 | head -5</automated>
  </verify>
  <done>scoring-algorithms.mjs exists with all 8 algorithms and scoring logic exported. compare-scoring.mjs imports from the shared module and produces identical output to before.</done>
</task>

<task type="auto">
  <name>Task 2: Create score-project.mjs single-run script</name>
  <files>benchmarks/scripts/score-project.mjs</files>
  <action>
Create benchmarks/scripts/score-project.mjs as an ESM script (#!/usr/bin/env node) that:

1. **Argument parsing:** Accept a target directory as the first positional argument. If not provided, print usage and exit with code 1. Support optional `--no-build` flag to skip building.

2. **Build step:** Unless `--no-build` is passed, run `cargo build --release` from the project root (detect project root via `git rev-parse --show-toplevel`). Print "Building ComplexityGuard..." to stderr.

3. **Run complexity-guard:** Execute `target/release/complexity-guard --format json --fail-on none <target-dir>` using `child_process.execSync`. Capture stdout as the JSON output. Print the command being run to stderr.

4. **Parse and score:** Parse the JSON output. Import `ALGORITHMS`, `scoreProject`, `collectAllFunctions`, `computeStats`, `round`, `fmtScore`, `padEnd` from `./scoring-algorithms.mjs`. Run preprocess for algorithms that need it (percentile-based). Score the project with all 8 algorithms.

5. **Output - Summary header:** Print to stdout:
   ```
   ## Scoring Comparison: <directory-basename>

   Files: N   Functions: N
   ```

6. **Output - Score comparison table:** Print a table with columns: Algorithm, Score, Description. Sort by score descending. Include the original health_score from JSON as a "json-output" row for comparison.

7. **Output - Per-file breakdown:** Print a table of per-file scores for each algorithm. Columns: File (relative path, truncated to 50 chars), then one column per algorithm (short names). Sort files by the "current" algorithm score ascending (worst files first). Limit to 30 rows; if more files, print "... and N more files".

8. **Output - Distribution stats:** For the per-file scores of each algorithm, print the same stats table as compare-scoring.mjs (Spread, StdDev, Min, P25, Median, P75, Max).

Use `import.meta.url` to resolve paths. Use `node:child_process`, `node:path`, `node:fs`, `node:process` only (no external dependencies).
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && node benchmarks/scripts/score-project.mjs tests/fixtures --no-build 2>&1 | head -20</automated>
  </verify>
  <done>score-project.mjs runs complexity-guard on any directory and outputs a comparison table of all 8 scoring algorithms with per-file breakdown and distribution statistics.</done>
</task>

</tasks>

<verification>
1. `node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26` produces valid output (regression check)
2. `node benchmarks/scripts/score-project.mjs tests/fixtures --no-build` produces scoring comparison table
3. `node benchmarks/scripts/score-project.mjs` (no args) prints usage and exits with code 1
</verification>

<success_criteria>
- scoring-algorithms.mjs contains all 8 algorithms and scoring logic as named exports
- compare-scoring.mjs imports from scoring-algorithms.mjs and produces identical output
- score-project.mjs accepts a directory, runs the binary, and outputs all algorithm scores
- No external dependencies (ESM, node built-ins only)
</success_criteria>

<output>
After completion, create `.planning/quick/33-add-single-run-scoring-comparison-script/33-SUMMARY.md`
</output>
