# Health Score

Health score gives you a single number — 0 to 100 — representing the overall complexity health of your codebase. Rather than juggling four separate metric families with separate warning/error thresholds, the health score collapses everything into one actionable signal. 100 means minimal complexity across all metrics; lower scores indicate areas that need attention.

The score is designed for CI enforcement: set a baseline, keep it from dropping, and improve it over time.

## How It Works

The pipeline has three stages:

1. **Normalize** — Each raw metric value is converted to a 0-100 sub-score using a piecewise linear function
2. **Weight** — Sub-scores are combined using configurable weights into a per-function score
3. **Aggregate** — Function scores roll up into file scores, then into a project score

## The Formula

### Piecewise Linear Normalization

Each metric value is normalized with a 3-segment linear function anchored at the warning and error thresholds:

```
score(x) =
  x <= 0:         100
  0 < x <= warn:  100 - 20 * (x / warn)
  warn < x <= err: 80 - 20 * ((x - warn) / (err - warn))
  x > err:         max(0, 60 - 60 * ((x - err) / err))
```

Key properties:
- `score(0) = 100` — zero complexity is perfect
- `score(warning) = 80` — boundary between "good" and "ok"
- `score(error) = 60` — boundary between "ok" and "bad"
- `score(2 * error) = 0` — floor
- Monotonically decreasing, continuous, no jumps
- Full 0-100 range is reachable

### Example: Cyclomatic Complexity (warning=10, error=20)

| Cyclomatic | Sub-score |
|------------|-----------|
| 0          | 100       |
| 5          | 90        |
| 10         | 80        |
| 15         | 70        |
| 20         | 60        |
| 30         | 30        |
| 40         | 0         |

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

Run ComplexityGuard with `--format json` to see your project score, then add it to your config file:

```sh
complexity-guard --format json src/ | jq '.summary.health_score'
# e.g. 73.2
```

Then edit (or create) `.complexityguard.json` and add the baseline field:

```json
{
  "baseline": 73.2
}
```

You can also generate a default config first with `complexity-guard --init`, then edit the `baseline` field.

### Step 2: Enforce in CI

Add ComplexityGuard to your CI pipeline. The tool automatically enforces the baseline from config:

```sh
complexity-guard src/
# Exits 1 if health score drops below baseline
```

Or override the threshold directly from the command line (no config change needed):

```sh
complexity-guard --fail-health-below 70 src/
```

When the health score falls below the threshold, ComplexityGuard exits with code 1 and prints a message to stderr:

```
Health score 68.4 is below threshold 70.0 — exiting with error
```

### Step 3: Improve Over Time

As your team refactors high-complexity functions, the health score rises. When you're comfortable with the new level, update the baseline value in your config file:

```json
{
  "baseline": 78.5
}
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
| 90 – 100 | Green | Almost perfect — minimal complexity |
| 80 – 89 | Green | Good — complexity is under control |
| 60 – 79 | Yellow | OK — some functions need attention |
| 0 – 59 | Red | Bad — significant complexity debt |

These ranges map directly to the scoring formula: a score of 80 means all metrics are at their warning thresholds, and 60 means all metrics are at their error thresholds. The goal is the trend, not the exact number.

A healthy workflow: start where you are, commit to not regressing (baseline), and chip away at high-complexity functions over time.

## See Also

- [CLI Reference](cli-reference.md) — `--fail-health-below`, `--init`, and weights config options
- [Examples](examples.md) — Health score in CI workflows and JSON output
- [Cyclomatic Complexity](cyclomatic-complexity.md) — One of the four contributing metrics
- [Cognitive Complexity](cognitive-complexity.md) — The highest-weighted metric by default
- [Halstead Metrics](halstead-metrics.md) — Information-theoretic component
- [Structural Metrics](structural-metrics.md) — Shape-based component
