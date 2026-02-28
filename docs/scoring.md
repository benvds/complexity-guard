# Scoring Algorithms & Comparison Scripts

This page documents the developer and benchmarking tools for experimenting with alternative scoring formulas. These scripts let you tune health score weights, thresholds, and aggregation strategies by comparing results across real projects — helping you understand how scoring choices affect the distribution of health scores before committing a change to the Rust source.

These scripts live in `benchmarks/scripts/` and are **not** part of the `complexity-guard` binary itself. They operate on JSON output from the binary. Node.js >= 18 is required (ES modules).

## Quick Start

Score any local directory with all 8 algorithms side-by-side:

```sh
node benchmarks/scripts/score-project.mjs src/
```

Run a batch comparison across all benchmark project analysis results:

```sh
node benchmarks/scripts/compare-scoring.mjs
```

Skip the Rust build step if the binary is already up to date:

```sh
node benchmarks/scripts/score-project.mjs src/ --no-build
```

## The 8 Algorithms

Each algorithm is a complete, self-contained scoring configuration: normalization curve, weights, thresholds, and aggregation strategy. All 8 run on the same JSON output from `complexity-guard --format json`.

### 1. current

**Exact replication of Rust defaults (baseline)**

Uses piecewise linear normalization anchored at the default warning and error thresholds (see [Health Score](health-score.md) for the full formula). Weights: cognitive 0.30, cyclomatic 0.20, halstead 0.15, structural 0.15. File aggregation is arithmetic mean of function scores. Project aggregation is function-count-weighted mean across files.

This is the reference algorithm — all other algorithms are compared against it. Use to verify the JavaScript implementation matches the Rust binary output (the validation spot-check table in `compare-scoring.mjs` tests exactly this).

**Default thresholds:**

| Metric | Warning | Error |
|--------|--------:|------:|
| Cyclomatic | 10 | 20 |
| Cognitive | 15 | 25 |
| Halstead volume | 500 | 1000 |
| Function length | 25 lines | 50 lines |
| Params count | 3 | 6 |
| Nesting depth | 3 | 5 |

### 2. harsh-thresholds

**Halve all warning/error thresholds (flags moderate code as problematic)**

Same normalization curve and weights as `current`, but every threshold is halved — cyclomatic warning 5 instead of 10, error 10 instead of 20; cognitive warning 8 instead of 15, error 13 instead of 25; and so on for all metric families.

Effect: moderate code that scores 80+ under default thresholds now scores significantly lower. A function with cyclomatic complexity 10 hits the error threshold (not just warning) under this algorithm.

**When to use:** See how your codebase holds up under stricter standards, or explore whether the default thresholds are too lenient for your team's quality bar.

**Halved thresholds:**

| Metric | Warning | Error |
|--------|--------:|------:|
| Cyclomatic | 5 | 10 |
| Cognitive | 8 | 13 |
| Halstead volume | 250 | 500 |
| Function length | 12 lines | 25 lines |
| Params count | 2 | 4 |
| Nesting depth | 2 | 3 |

### 3. steep-penalty

**Halved thresholds + steep penalty curve: score(warn)=60, score(err)=20**

Combines halved thresholds from `harsh-thresholds` with a steeper penalty curve. The standard piecewise linear function produces score(warning)=80 and score(error)=60. This algorithm changes those breakpoints to score(warning)=60 and score(error)=20, with score reaching 0 at 2×error.

Effect: this is the steepest drop-off of any algorithm. Even small complexity spikes cause dramatic score drops. A function at the warning threshold already scores 60 (the "bad" zone) instead of 80 (the "ok" boundary).

**When to use:** Identify code that is "barely passing" under the current rules — functions that look acceptable under `current` but would be flagged as serious problems under a stricter regime.

**Curve comparison:**

| Point | current | steep-penalty |
|-------|--------:|-------------:|
| x = 0 | 100 | 100 |
| x = warning | 80 | 60 |
| x = error | 60 | 20 |
| x = 2×error | 0 | 0 |

### 4. cognitive-heavy

**cognitive weight=0.50, other weights unchanged**

Increases the cognitive complexity weight from 0.30 to 0.50 while keeping all other weights and thresholds at their defaults. The total weight (0.20 + 0.50 + 0.15 + 0.15 = 1.00) still sums to 1.0, so no normalization is needed.

Effect: the score is dominated by cognitive complexity. Projects with deeply nested, hard-to-follow control flow score much lower than they would under equal or default weighting.

**When to use:** If your team values code readability and understandability above all other metrics, use this algorithm to surface the functions that are hardest to reason about.

**Weights:**

| Metric | Default | cognitive-heavy |
|--------|--------:|---------------:|
| Cognitive | 0.30 | **0.50** |
| Cyclomatic | 0.20 | 0.20 |
| Halstead | 0.15 | 0.15 |
| Structural | 0.15 | 0.15 |

### 5. geometric-mean

**Geometric mean of per-metric scores (one bad metric drags the whole score down)**

Uses the standard thresholds and linear normalization, but replaces the weighted average of 4 metric sub-scores (cyclomatic, cognitive, halstead, structural) with a geometric mean of those 4 values.

Effect: one poor sub-score drags the entire function score down disproportionately. A function with excellent cyclomatic complexity but very high Halstead volume scores poorly overall, even if the weighted average would look acceptable. A single sub-score of 0 pulls the geometric mean to 0.

**When to use:** Penalize unbalanced complexity profiles — functions that are strong in most metrics but terrible in one. The geometric mean enforces that all metric families must be healthy, not just on average.

### 6. worst-metric

**File score=min function score; project score=p25 of file scores**

Two-level pessimistic aggregation. At the file level, uses the minimum function score instead of the mean — a single terrible function tanks the entire file. At the project level, uses the 25th percentile of file scores instead of the weighted mean — a bad tail of files pulls the project score down.

Effect: worst-case hotspots that mean-based scoring hides become visible. If one function in a file has catastrophic complexity, the file score equals that function's score.

**When to use:** Surface the worst-case outliers in your codebase. Good for identifying the highest-priority refactoring targets.

### 7. percentile-based

**Score functions by percentile rank in dataset (relative, not absolute thresholds)**

Rather than scoring each function against absolute warning/error thresholds, this algorithm scores functions by their percentile rank within the full dataset. A function at the 90th percentile of cyclomatic complexity scores low regardless of its absolute value. Functions below median score above 50; functions above median score below 50.

This requires a preprocessing pass over all functions to collect the distribution, then binary search for each function's rank.

Effect: relative scoring — "how does this function compare to all others in the dataset?" The bottom 10% always scores near zero; the top 10% always scores near 100. The absolute threshold values are ignored.

**When to use:** Comparative analysis across a large benchmark set. Useful when you want to identify relative outliers rather than enforce absolute standards. Note that the scores are meaningful only within the context of the dataset analyzed.

### 8. log-penalty

**Logarithmic penalty: 100 * (1 - log(1+x) / log(1+2*error))**

Replaces the piecewise linear normalization with a smooth logarithmic curve. The formula is `100 * (1 - log(1+x) / log(1+2*error))`. The warning threshold is unused — there are no breakpoints. The curve reaches 0 at `x = 2*error` (same floor as `current`).

Effect: more gradual penalty for moderate complexity compared to the piecewise linear curve. Early growth (low complexity values) is penalized more gently. The curve is monotonically decreasing and smooth, with no abrupt slope changes at the warning or error thresholds.

**When to use:** If the piecewise linear breakpoints (the abrupt slope changes at warning and error) feel too arbitrary for your use case. The logarithmic curve is more mathematically principled, though it produces generally higher scores for moderately complex code.

**Curve comparison (cyclomatic, warning=10, error=20):**

| Cyclomatic | current (linear) | log-penalty |
|----------:|:----------------:|:-----------:|
| 0 | 100 | 100 |
| 5 | 90 | ~85 |
| 10 | 80 | ~75 |
| 15 | 70 | ~65 |
| 20 | 60 | ~57 |
| 30 | 30 | ~40 |
| 40 | 0 | ~22 |

## Scoring Primitives

All algorithms build on shared primitives defined in `scoring-algorithms.mjs`. See [Health Score](health-score.md) for the full mathematical treatment of the production scoring formula.

### linearScore(x, warning, error)

The standard piecewise linear normalization function. Maps a metric value to 0-100 using warning and error thresholds as breakpoints. See [Health Score — Piecewise Linear Normalization](health-score.md#piecewise-linear-normalization) for the complete formula and properties.

Several algorithms override this function with their own normalization (e.g., `steep-penalty` changes the breakpoint scores; `log-penalty` uses a logarithmic formula entirely).

### computeFunctionScore(fn, weights, thresholds, scoreFn)

Computes a weighted composite score for a single function from its 4 metric families. Calls `scoreFn` once per metric (cyclomatic, cognitive, halstead, structural — where structural is the average of function length, params, and nesting). Returns the weight-normalized average. If total weight is zero, falls back to equal weighting.

### Aggregation functions

| Function | Description |
|----------|-------------|
| `mean(scores)` | Arithmetic mean. Returns 100 for empty arrays. |
| `geometricMean(scores)` | Geometric mean in log space. A single zero pulls the result to zero. |
| `minimum(scores)` | Minimum value. Returns 100 for empty arrays. |
| `weightedMean(fileScores, functionCounts)` | Function-count-weighted mean across files. Matches the Rust project-level aggregation. |
| `percentile(sorted, p)` | Linear interpolation percentile from a sorted array. `p` is in [0, 1]. |

### computeStats(scores)

Computes distribution statistics for an array of scores. Returns: `min`, `max`, `mean`, `median`, `p25`, `p75`, `stdev`, `spread` (max - min), and threshold counts (`count_gt95`, `count_gt90`, `count_gt80`, `count_gt70`).

## Scripts

### score-project.mjs

Analyze a single directory with all 8 algorithms side-by-side.

**Usage:**

```sh
node benchmarks/scripts/score-project.mjs <target-dir> [--no-build]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `<target-dir>` | Directory to analyze (required) |
| `--no-build` | Skip `cargo build --release` step |

**What it does:**

1. Optionally runs `cargo build --release` to ensure the binary is current
2. Runs `complexity-guard --format json --fail-on none <target-dir>` and captures JSON output
3. Scores the JSON output with all 8 algorithms using the shared module
4. Runs the `preprocess` pass for algorithms that need a first pass (percentile-based)

**Output sections:**

- **Algorithm Scores** — table of all 8 algorithm scores sorted descending (best first), including the raw `json-output` health score from the binary for comparison
- **Per-File Scores** — table of up to 30 files sorted by `current` score ascending (worst first), with all 8 algorithm scores shown per file
- **Distribution Statistics** — spread, standard deviation, min/max/percentiles for each algorithm's per-file score distribution

**Examples:**

```sh
# Score this project's source directory (builds first)
node benchmarks/scripts/score-project.mjs src/

# Score test fixtures without rebuilding
node benchmarks/scripts/score-project.mjs tests/fixtures --no-build

# Score an external project
node benchmarks/scripts/score-project.mjs /path/to/other/project/src --no-build
```

---

### compare-scoring.mjs

Batch comparison across all benchmark project analysis results.

**Usage:**

```sh
node benchmarks/scripts/compare-scoring.mjs [results-dir] [--json output.json]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `[results-dir]` | Path to benchmark results directory (optional) |
| `--json <file>` | Export full results as JSON to the specified file |

If `results-dir` is not provided, the script auto-detects the latest `benchmarks/results/baseline-*` directory.

**What it does:**

1. Loads all `*-analysis.json` files from the results directory
2. Runs the `preprocess` pass for algorithms that need a first pass (percentile-based uses all functions across all projects)
3. Scores each project with all 8 algorithms
4. Outputs comparison tables and optional JSON export

**Output sections:**

- **Algorithms** — legend table mapping each algorithm name to its description
- **Per-Project Scores** — table of all projects sorted by `current` score ascending (lowest-scoring projects first), with all 8 algorithm scores per row
- **Distribution Statistics** — spread, standard deviation, percentiles, and threshold counts for each algorithm's distribution across all projects
- **Validation spot-check** — compares the `current` algorithm's JS-computed score against the `health_score` field in each JSON file (tolerance: 0.5); confirms that the JS implementation matches the Rust binary

**Examples:**

```sh
# Auto-detect latest baseline directory
node benchmarks/scripts/compare-scoring.mjs

# Use a specific results directory
node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26

# Export full results as JSON for further analysis
node benchmarks/scripts/compare-scoring.mjs --json scoring-comparison.json

# Specific directory + JSON export
node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26 --json out.json
```

---

### scoring-algorithms.mjs

The shared module containing all algorithm definitions, scoring primitives, and statistics helpers. This is not a standalone script — it is imported by both `score-project.mjs` and `compare-scoring.mjs`.

**Exports:**

| Export | Type | Description |
|--------|------|-------------|
| `ALGORITHMS` | `Map<string, object>` | All 8 algorithm configurations keyed by name |
| `linearScore` | function | Standard piecewise linear normalization |
| `computeFunctionScore` | function | Weighted composite from 4 metric families |
| `DEFAULT_WEIGHTS` | object | `{ cyclomatic, cognitive, halstead, structural }` |
| `DEFAULT_THRESHOLDS` | object | All 12 warning/error threshold values |
| `mean` | function | Arithmetic mean |
| `geometricMean` | function | Geometric mean |
| `minimum` | function | Minimum value |
| `weightedMean` | function | Function-count-weighted mean |
| `percentile` | function | Linear interpolation percentile |
| `scoreFile` | function | Score all functions in a file |
| `scoreProject` | function | Score all files in a project |
| `computeStats` | function | Distribution statistics |
| `collectAllFunctions` | function | Flatten all function objects from analysis data |
| `round`, `padEnd`, `fmtScore` | functions | Formatting helpers |

## Adding or Modifying Algorithms

To add a new scoring algorithm:

**Step 1:** Open `benchmarks/scripts/scoring-algorithms.mjs`.

**Step 2:** Add a new entry to the `ALGORITHMS` Map following the existing pattern:

```js
ALGORITHMS.set('my-algorithm', {
  name: 'my-algorithm',
  description: 'One-line description of what this algorithm does',
  linearScore: linearScore,         // or a custom normalization function
  weights: { ...DEFAULT_WEIGHTS },  // or override specific weights
  thresholds: { ...DEFAULT_THRESHOLDS }, // or override specific thresholds
  functionAggregate: mean,          // mean, geometricMean, or minimum
  projectAggregate: weightedMean,   // weightedMean or custom function
});
```

**Step 3 — Required fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Short identifier (must match Map key) |
| `description` | string | One-line explanation shown in output tables |
| `linearScore` | function | `(x, warning, error) => number` — per-metric normalization |
| `weights` | object | `{ cyclomatic, cognitive, halstead, structural }` |
| `thresholds` | object | All 12 threshold values (see `DEFAULT_THRESHOLDS`) |
| `functionAggregate` | function | `(functionScores) => number` — file score from function scores |
| `projectAggregate` | function | `(fileScores, functionCounts) => number` — project score from file scores |

**Step 4 — Optional fields:**

| Field | Type | Description |
|-------|------|-------------|
| `scoreFn` | function | Override the entire per-function scoring logic. Signature: `(fn, weights, thresholds, scoreFn) => number`. If present, `computeFunctionScore` is not called. |
| `preprocess` | function | First pass over all function objects before scoring. Signature: `(allFunctions) => void`. Used by `percentile-based` to collect the distribution. |

**Step 5 — Minimal example:** An algorithm using equal weights (0.25 each):

```js
ALGORITHMS.set('equal-weights', {
  name: 'equal-weights',
  description: 'Equal weight on all 4 metric families (0.25 each)',
  linearScore: linearScore,
  weights: {
    cyclomatic: 0.25,
    cognitive:  0.25,
    halstead:   0.25,
    structural: 0.25,
  },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});
```

Once added, the new algorithm automatically appears in both `score-project.mjs` and `compare-scoring.mjs` output tables — no other changes needed.

## See Also

- **[Health Score](health-score.md)** — The scoring formula used by the binary: piecewise linear normalization, weights, and aggregation details
- **[Performance Benchmarks](benchmarks.md)** — Benchmark results across 83 open-source projects
- **[CLI Reference](cli-reference.md)** — `--format json`, `--fail-health-below`, and other relevant flags
