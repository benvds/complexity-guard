---
phase: quick-32
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/compare-scoring.mjs
autonomous: true
requirements: [QUICK-32]

must_haves:
  truths:
    - "User can compare multiple scoring algorithms side by side across 84 real-world projects"
    - "User can see score distribution statistics (min, max, median, p25, p75, stdev) for each algorithm"
    - "User can define custom weight/threshold configs and see their effect immediately"
    - "User can identify which algorithm produces the most meaningful differentiation between projects"
  artifacts:
    - path: "benchmarks/scripts/compare-scoring.mjs"
      provides: "Scoring algorithm comparison CLI tool"
      min_lines: 200
  key_links:
    - from: "benchmarks/scripts/compare-scoring.mjs"
      to: "benchmarks/results/baseline-*/*-analysis.json"
      via: "reads function-level metrics from analysis JSON"
      pattern: "analysis\\.json"
---

<objective>
Build a standalone Node.js scoring algorithm comparison tool that re-scores all 84 benchmark project analysis results using multiple configurable scoring algorithms, so the user can tune health score weights and thresholds to find a better distribution.

Purpose: Current health scores cluster between 91-99 for all 84 real-world projects, providing poor differentiation. The user needs to compare alternative scoring algorithms (different weights, thresholds, penalty curves) to find one that spreads scores more meaningfully.

Output: `benchmarks/scripts/compare-scoring.mjs` -- a CLI tool that reads existing analysis JSON files and re-scores them with multiple algorithms.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@src/metrics/scoring.rs (current scoring algorithm -- must be replicated in JS for comparison)
@src/types.rs (ScoringWeights, ScoringThresholds defaults)
@benchmarks/scripts/summarize-results.mjs (existing benchmark script pattern)
@benchmarks/results/baseline-2026-02-26/ava-analysis.json (sample analysis JSON schema)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build scoring algorithm comparison tool</name>
  <files>benchmarks/scripts/compare-scoring.mjs</files>
  <action>
Create `benchmarks/scripts/compare-scoring.mjs` -- a Node.js CLI tool that:

**Input:** Reads all `*-analysis.json` files from a results directory (default: latest `benchmarks/results/baseline-*`).

**Core logic:**

1. **Replicate current scoring in JS** -- Port the `linear_score()` and `compute_function_score()` functions from `src/metrics/scoring.rs` exactly. This is the baseline "current" algorithm:
   - Piecewise linear: score(0)=100, score(warn)=80, score(err)=60, score(2*err)=0
   - Weighted average with default weights: cyclomatic=0.20, cognitive=0.30, halstead=0.15, structural=0.15
   - Structural = average of function_length, params_count, nesting_depth sub-scores
   - File score = mean of function scores. Project score = function-count-weighted mean of file scores.

2. **Define 6-8 alternative scoring algorithms as named configs**, each with a short description. Include at least these:
   - `current` -- exact replication of Rust defaults (baseline)
   - `harsh-thresholds` -- halve all warning/error thresholds (cyclomatic warn=5/err=10, cognitive warn=8/err=13, halstead warn=250/err=500, etc.)
   - `steep-penalty` -- same thresholds but change linear_score curve: score(warn)=60 instead of 80, score(err)=20 instead of 60
   - `cognitive-heavy` -- cognitive weight=0.50, cyclomatic=0.20, halstead=0.15, structural=0.15
   - `geometric-mean` -- use geometric mean of metric sub-scores instead of weighted arithmetic mean (one bad metric drags the whole score down)
   - `worst-metric` -- file score = minimum function score (not mean); project score = p25 of file scores (not weighted mean)
   - `percentile-based` -- score functions relative to all functions in the dataset (percentile rank), not absolute thresholds
   - `log-penalty` -- use logarithmic penalty curve: 100 * (1 - log(1 + x) / log(1 + 2*error))

3. **For each algorithm, compute per-project scores** by re-scoring every function in every analysis JSON file.

4. **Output a comparison table** (markdown to stdout) with columns:
   - Project name
   - Score for each algorithm
   Sorted by the `current` algorithm score ascending.

5. **Output distribution statistics** for each algorithm:
   - Min, Max, Median, Mean, P25, P75, StdDev
   - Spread = Max - Min (higher is better for differentiation)
   - Count of projects scoring > 95, > 90, > 80, > 70

6. **Optional --json flag** to write full results to a JSON file for further analysis.

**Usage:**
```
node benchmarks/scripts/compare-scoring.mjs [results-dir]
node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26
node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26 --json scoring-comparison.json
```

If no results-dir given, auto-detect the latest `benchmarks/results/baseline-*` directory.

**Style:** Follow the pattern of `summarize-results.mjs` (ESM, no dependencies, clean markdown output, `padEnd` alignment). Include JSDoc comments. Keep algorithms as a `Map<string, { description, scoreFn, fileAggregate, projectAggregate }>` so the user can easily add more.

**Important:** Each algorithm config object should have:
- `name` -- short identifier
- `description` -- one-line explanation
- `linearScore(x, warn, err)` -- the per-metric normalization function
- `weights` -- { cyclomatic, cognitive, halstead, structural }
- `thresholds` -- { cyclomatic_warning, cyclomatic_error, ... } (same structure as Rust ScoringThresholds)
- `functionAggregate(functionScores)` -- how to get file score from function scores (default: mean)
- `projectAggregate(fileScores, functionCounts)` -- how to get project score from file scores (default: function-count-weighted mean)

The `percentile-based` algorithm is special: it needs a first pass to collect all function metric values, then a second pass to compute percentile ranks. Handle this by allowing an optional `preprocess(allFunctions)` step in the algorithm config.
  </action>
  <verify>
    <automated>cd /Users/benvds/code/complexity-guard && node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26 2>&1 | head -120</automated>
  </verify>
  <done>
    - Script runs successfully on the 84 analysis JSON files
    - Outputs a markdown comparison table with all algorithm columns
    - Outputs distribution statistics showing spread for each algorithm
    - `current` algorithm scores match the health_score values already in the JSON files (within floating point tolerance)
    - At least 3 alternative algorithms produce notably different score distributions (spread > 15 points)
  </done>
</task>

</tasks>

<verification>
- `node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26` produces readable markdown output
- The `current` column matches existing health_score values in the analysis JSON (spot-check 3 projects: ava ~96.5, sequelize ~91.2, biome ~98.8)
- Distribution stats section shows spread/stdev for each algorithm
- `--json` flag writes valid JSON with full per-project, per-algorithm data
</verification>

<success_criteria>
User can run a single command and see 6-8 scoring algorithms compared across 84 real-world projects, with distribution statistics that reveal which algorithms provide better score differentiation. The tool architecture makes it trivial to add new algorithms or tweak existing ones.
</success_criteria>

<output>
After completion, create `.planning/quick/32-build-scoring-algorithm-comparison-tool-/32-SUMMARY.md`
</output>
