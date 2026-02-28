---
phase: quick-34
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/scoring.md
  - README.md
autonomous: true
requirements: [QUICK-34]

must_haves:
  truths:
    - "Developer can understand what each of the 8 scoring algorithms does and how they differ"
    - "Developer can run score-project.mjs on any local directory and interpret the output"
    - "Developer can run compare-scoring.mjs on benchmark results and interpret the output"
    - "Developer can add or modify a scoring algorithm by following documented patterns"
    - "README Documentation section links to the new scoring docs page"
  artifacts:
    - path: "docs/scoring.md"
      provides: "Complete scoring scripts and algorithms documentation"
      min_lines: 200
    - path: "README.md"
      provides: "Link to scoring docs in Documentation section"
      contains: "scoring.md"
  key_links:
    - from: "README.md"
      to: "docs/scoring.md"
      via: "Documentation section link"
      pattern: "\\[.*Scoring.*\\]\\(docs/scoring\\.md\\)"
---

<objective>
Create comprehensive documentation for the scoring comparison scripts and all 8 scoring algorithms.

Purpose: The scoring scripts (score-project.mjs, compare-scoring.mjs, scoring-algorithms.mjs) are powerful developer/benchmarking tools but have no documentation. Users need to understand what each algorithm does, how to use the scripts, and how to extend them.

Output: New docs/scoring.md page with algorithm explanations, script usage guides, and extension guide. README updated with a link.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@README.md
@docs/health-score.md
@benchmarks/scripts/scoring-algorithms.mjs
@benchmarks/scripts/compare-scoring.mjs
@benchmarks/scripts/score-project.mjs
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create docs/scoring.md with full algorithm documentation and script usage</name>
  <files>docs/scoring.md</files>
  <action>
Create docs/scoring.md following the style conventions of docs/health-score.md (clear headings, tables, code blocks, practical examples).

Structure the document as follows:

## Header section
- Title: "Scoring Algorithms & Comparison Scripts"
- One-paragraph intro: these are developer/benchmarking tools for experimenting with alternative scoring formulas. They help tune health score weights, thresholds, and aggregation strategies by comparing results across real projects.
- Note that these scripts live in `benchmarks/scripts/` and are NOT part of the complexity-guard binary itself. They operate on JSON output from the binary.

## Quick Start
- Two quick-start examples:
  1. `node benchmarks/scripts/score-project.mjs src/` — score a single project with all 8 algorithms
  2. `node benchmarks/scripts/compare-scoring.mjs` — batch comparison across benchmark results
- Mention Node.js >= 18 required (ES modules).

## The 8 Algorithms section
For EACH algorithm, create a subsection with:
- Name (as heading: `### 1. current`)
- One-sentence summary from the algorithm's `description` field
- "What it does" paragraph explaining the scoring logic in plain English
- "When to use" sentence explaining the use case
- Key configuration differences from baseline (table for thresholds/weights if different)

The 8 algorithms (use the exact data from scoring-algorithms.mjs):

1. **current** — Exact replication of Rust defaults. Uses piecewise linear normalization, default weights (cognitive 0.30, cyclomatic 0.20, halstead 0.15, structural 0.15), default thresholds, arithmetic mean for file aggregation, function-count-weighted mean for project aggregation. This is the baseline — all other algorithms are compared against it. Use to verify JS matches Rust output.

2. **harsh-thresholds** — Halves all warning/error thresholds (e.g., cyclomatic warning 5 instead of 10, error 10 instead of 20). Same scoring curve and weights. Effect: moderate code that would score 80+ under default thresholds now scores much lower. Use to see how your codebase holds up under stricter standards.

3. **steep-penalty** — Combines halved thresholds with a steeper penalty curve: score(warning)=60 instead of 80, score(error)=20 instead of 60. The steepest drop-off of any algorithm. Effect: even small complexity spikes cause dramatic score drops. Use to identify code that is "barely passing" under current rules.

4. **cognitive-heavy** — Increases cognitive complexity weight from 0.30 to 0.50 while keeping other weights the same. Effect: the score is dominated by cognitive complexity; projects with deeply nested, hard-to-read code score much lower. Use if you believe readability/understandability matters more than other metrics.

5. **geometric-mean** — Replaces the weighted average of metric sub-scores with a geometric mean. Effect: one bad metric sub-score drags the entire function score down disproportionately. A function with excellent cyclomatic but terrible Halstead scores poorly. Use to penalize unbalanced complexity profiles.

6. **worst-metric** — File score = minimum function score (not mean). Project score = 25th percentile of file scores (not weighted mean). Effect: a single terrible function tanks the entire file score. Use to surface worst-case hotspots that mean-based scoring hides.

7. **percentile-based** — Scores functions by their percentile rank within the dataset rather than against absolute thresholds. A function at the 90th percentile of cyclomatic complexity scores low regardless of the absolute value. Requires a preprocess pass over all functions. Effect: relative scoring — "how does this function compare to all others?" Use for comparative analysis across a large benchmark set.

8. **log-penalty** — Uses `100 * (1 - log(1+x) / log(1+2*error))` instead of piecewise linear. The curve is smooth (no breakpoints at warning/error) and penalizes early growth more gently but converges to 0 at 2*error. Warning threshold is unused. Effect: more gradual penalty for moderate complexity, still reaches 0 at the same point. Use if the piecewise linear breakpoints feel too abrupt.

## Scoring Primitives section
Brief explanation of the shared building blocks (reference health-score.md for the full formula):
- `linearScore(x, warning, error)` — piecewise linear normalization (link to health-score.md for details)
- `computeFunctionScore(fn, weights, thresholds, scoreFn)` — weighted combination of 4 metric sub-scores
- Aggregation functions: `mean`, `geometricMean`, `minimum`, `weightedMean`, `percentile`
- `computeStats` — distribution statistics (min, max, mean, median, p25, p75, stdev, spread, count thresholds)

## Scripts section

### score-project.mjs
- Purpose: analyze a single directory with all 8 algorithms side-by-side
- Usage: `node benchmarks/scripts/score-project.mjs <target-dir> [--no-build]`
- What it does: builds complexity-guard (unless --no-build), runs `complexity-guard --format json --fail-on none <target-dir>`, then scores the JSON output with all 8 algorithms
- Output sections: Algorithm Scores table (sorted by score descending), Per-File Scores (sorted by current ascending, worst first, max 30 rows), Distribution Statistics
- Example: `node benchmarks/scripts/score-project.mjs src/ --no-build`

### compare-scoring.mjs
- Purpose: batch comparison across all benchmark project analysis results
- Usage: `node benchmarks/scripts/compare-scoring.mjs [results-dir] [--json output.json]`
- Auto-detects latest `benchmarks/results/baseline-*` directory if no argument given
- What it does: loads all `*-analysis.json` files, scores each project with all 8 algorithms, outputs comparison tables
- Output sections: Algorithm legend, Per-Project Scores (sorted by current ascending), Distribution Statistics, Validation spot-check (current vs JSON health_score)
- The --json flag exports full results as JSON for further analysis

### scoring-algorithms.mjs
- Purpose: shared module — all algorithm definitions, scoring primitives, and stats helpers
- Not a standalone script — imported by both score-project.mjs and compare-scoring.mjs
- Exports: ALGORITHMS map, linearScore, computeFunctionScore, DEFAULT_WEIGHTS, DEFAULT_THRESHOLDS, mean, geometricMean, minimum, weightedMean, percentile, scoreFile, scoreProject, computeStats, collectAllFunctions, and formatting helpers

## Adding or Modifying Algorithms section
Step-by-step guide:
1. Open `benchmarks/scripts/scoring-algorithms.mjs`
2. Add a new entry to the `ALGORITHMS` Map following the existing pattern
3. Required fields: `name`, `description`, `linearScore`, `weights`, `thresholds`, `functionAggregate`, `projectAggregate`
4. Optional fields: `scoreFn` (override per-function scoring logic), `preprocess` (first pass over all functions)
5. Show a minimal example of a new algorithm definition (e.g., "equal-weights" with all weights at 0.25)
6. The new algorithm automatically appears in both scripts' output

## See Also section
- Link to docs/health-score.md (the actual scoring formula used by the binary)
- Link to docs/benchmarks.md (benchmark results)
- Link to docs/cli-reference.md (--format json, --fail-health-below flags)
  </action>
  <verify>
    <automated>test -f docs/scoring.md && wc -l docs/scoring.md | awk '{if ($1 >= 200) print "OK: " $1 " lines"; else print "FAIL: only " $1 " lines"}'</automated>
  </verify>
  <done>docs/scoring.md exists with 200+ lines covering all 8 algorithms, all 3 scripts, scoring primitives, and extension guide</done>
</task>

<task type="auto">
  <name>Task 2: Add scoring docs link to README.md Documentation section</name>
  <files>README.md</files>
  <action>
In README.md, find the Documentation section (starts with `## Documentation`). Add a new bullet after the "Claude Code Skill" line:

```
- **[Scoring Algorithms](docs/scoring.md)** — Alternative scoring formulas, comparison scripts, and benchmarking tools
```

This goes at the end of the general docs list, before the `### Metrics` subsection. It is developer/benchmarking tooling so it fits in the main docs list, not the metrics subsection.

Do NOT update publication READMEs — these are internal developer/benchmarking scripts, not user-facing CLI features. The publication READMEs describe end-user installation and usage only.
  </action>
  <verify>
    <automated>grep -n "Scoring Algorithms.*docs/scoring.md" README.md</automated>
  </verify>
  <done>README.md Documentation section contains a link to docs/scoring.md</done>
</task>

</tasks>

<verification>
- docs/scoring.md exists and covers all 8 algorithms by name
- docs/scoring.md documents score-project.mjs and compare-scoring.mjs usage
- docs/scoring.md includes extension guide for adding new algorithms
- README.md links to docs/scoring.md in the Documentation section
- No publication README changes (these are dev-only scripts)
</verification>

<success_criteria>
- docs/scoring.md is a comprehensive reference (200+ lines) that a developer can use to understand, run, and extend the scoring comparison tools
- All 8 algorithms are individually documented with what they do and when to use them
- README.md Documentation section links to the new page
</success_criteria>

<output>
After completion, create `.planning/quick/34-add-docs-for-scoring-scripts-and-explain/34-SUMMARY.md`
</output>
