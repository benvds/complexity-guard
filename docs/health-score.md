# Health Score

Health score gives you a single number — 0 to 100 — representing the overall complexity health of your codebase. Rather than juggling four separate metric families with separate warning/error thresholds, the health score collapses everything into one actionable signal. 100 means minimal complexity across all metrics; lower scores indicate areas that need attention.

The score is designed for CI enforcement: set a baseline, keep it from dropping, and improve it over time.

## How It Works

The pipeline has three stages:

1. **Normalize** — Each raw metric value is converted to a 0-100 sub-score using a sigmoid curve
2. **Weight** — Sub-scores are combined using configurable weights into a per-function score
3. **Aggregate** — Function scores roll up into file scores, then into a project score

## The Formula

### Sigmoid Normalization

Each metric value is normalized with:

```
sub_score = 100 / (1 + exp(k * (x - x0)))
```

Where:
- `x` is the raw metric value (e.g. cyclomatic complexity = 12)
- `x0` is the **warning threshold** — at this value, `sub_score` is exactly 50.0
- `k = ln(4) / (error_threshold - warning_threshold)` — controls the slope

This means:
- A value at or below the warning threshold scores 50 or above
- A value at the error threshold scores ~20
- Very low values (approaching 0) score ~100
- Very high values approach 0

### Example: Cyclomatic Complexity (warning=10, error=20)

| Cyclomatic | Sub-score |
|------------|-----------|
| 1          | ~99       |
| 5          | ~88       |
| 10         | 50        |
| 15         | ~20       |
| 20         | ~11       |
| 30         | ~3        |

### Metric Families

Each metric family contributes one sub-score to the weighted average:

| Family | What's normalized |
|--------|-------------------|
| **Cyclomatic** | Cyclomatic complexity value |
| **Cognitive** | Cognitive complexity value |
| **Halstead** | Halstead volume |
| **Structural** | Average of three sub-scores: function_length, params_count, nesting_depth |

> **Duplication** is excluded until the duplication detection feature is implemented in a later phase.

## Weights

### Default Weights

| Metric | Default Weight | Share of Score |
|--------|---------------|----------------|
| Cognitive | 0.30 | 30% |
| Cyclomatic | 0.20 | 20% |
| Halstead | 0.15 | 15% |
| Structural | 0.15 | 15% |
| Duplication | 0.20 | Reserved |

Because duplication is not yet implemented, the active weights are normalized to sum to 1.0. The effective weights used for scoring are:

| Metric | Effective Weight |
|--------|-----------------|
| Cognitive | ~0.375 |
| Cyclomatic | ~0.250 |
| Halstead | ~0.1875 |
| Structural | ~0.1875 |

### Customizing Weights

Override weights in `.complexityguard.json`. You only need to specify the ones you want to change — the rest use defaults:

```json
{
  "weights": {
    "cognitive": 0.40,
    "cyclomatic": 0.30,
    "halstead": 0.15,
    "structural": 0.15
  }
}
```

Setting a weight to `0.0` excludes that metric from scoring (it is still analyzed and shown in output, just not counted toward the health score):

```json
{
  "weights": {
    "halstead": 0.0
  }
}
```

If all weights are zero, ComplexityGuard falls back to equal weighting (0.25 each) as a safe default.

## Score Aggregation

### Function Score

A function's health score is the weighted average of its normalized metric sub-scores:

```
function_score = sum(weight_i * sub_score_i) / sum(weight_i)
```

Where the sum is over all active (non-zero-weight) metric families.

### File Score

A file's health score is the simple average of all its function scores. Files with no functions score 100 (no complexity to measure).

### Project Score

The project score is a **function-count-weighted average** across all files. Files with more functions carry more weight — a 50-function file contributes 5x more than a 10-function file. Projects with no functions score 100.

```
project_score = sum(file_score_i * function_count_i) / sum(function_count_i)
```

## Baseline + Ratchet Workflow

The health score is most powerful when used as a ratchet: capture today's score as a baseline, then prevent it from regressing.

### Step 1: Set a Baseline

Run ComplexityGuard with `--save-baseline` to capture the current project score and write it to your config:

```sh
complexity-guard --save-baseline src/
```

This writes (or updates) `.complexityguard.json` with the current score:

```json
{
  "baseline": 73.2
}
```

### Step 2: Enforce in CI

Add ComplexityGuard to your CI pipeline. The tool automatically enforces the baseline from config:

```sh
complexity-guard src/
# Exits 1 if health score drops below baseline
```

Or override the threshold directly from the command line:

```sh
complexity-guard --fail-health-below 70 src/
```

When the health score falls below the threshold, ComplexityGuard exits with code 1 and prints a message to stderr:

```
Health score 68.4 is below threshold 70.0 — exiting with error
```

### Step 3: Improve Over Time

As your team refactors high-complexity functions, the health score rises. When you're comfortable with the new level, update the baseline:

```sh
complexity-guard --save-baseline src/
```

The ratchet only ever moves forward — toward a healthier codebase.

## Configuration Reference

```json
{
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  },
  "baseline": 73.2
}
```

Both fields are optional. When `weights` is absent, defaults are used. When `baseline` is absent, no health-score enforcement occurs.

Full config example with thresholds:

```json
{
  "files": {
    "include": ["src/**/*.ts", "src/**/*.tsx"],
    "exclude": ["**/*.test.ts", "node_modules/**"]
  },
  "thresholds": {
    "cyclomatic": { "warning": 10, "error": 20 },
    "cognitive": { "warning": 15, "error": 25 }
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  },
  "baseline": 73.2
}
```

## Score Interpretation

The health score is a continuous number — there are no letter grades.

| Range | Color | Meaning |
|-------|-------|---------|
| 80 – 100 | Green | Healthy — complexity is under control |
| 50 – 79 | Yellow | Needs attention — some functions are complex |
| 0 – 49 | Red | Critical — significant complexity debt |

These ranges are a rough guide, not hard rules. A score of 79 and a score of 81 represent essentially the same codebase — the goal is the trend, not the exact number.

A healthy workflow: start where you are, commit to not regressing (baseline), and chip away at high-complexity functions over time.

## See Also

- [CLI Reference](cli-reference.md) — `--save-baseline`, `--fail-health-below`, and weights config options
- [Examples](examples.md) — Health score in CI workflows and JSON output
- [Cyclomatic Complexity](cyclomatic-complexity.md) — One of the four contributing metrics
- [Cognitive Complexity](cognitive-complexity.md) — The highest-weighted metric by default
- [Halstead Metrics](halstead-metrics.md) — Information-theoretic component
- [Structural Metrics](structural-metrics.md) — Shape-based component
