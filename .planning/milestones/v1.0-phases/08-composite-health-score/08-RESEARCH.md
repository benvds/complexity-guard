# Phase 8: Composite Health Score - Research

**Researched:** 2026-02-17
**Domain:** Composite scoring, metric normalization, baseline ratchet, Zig numeric math
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Score system:**
- Numeric 0-100 score only, no letter grades (A-F removed from requirements)
- 100 = healthiest (higher is better)
- Score appears per-file and in project summary
- No default CI failure threshold for score — user must configure via baseline or config

**Score display:**
- Plain number format in console: "Health: 73"
- Color-coded by value: green >= 80, yellow 50-79, red < 50
- JSON output includes score + breakdown showing each metric's weighted contribution

**Missing metrics handling:**
- Redistribute weights proportionally when metrics aren't implemented yet (e.g., duplication not available until Phase 11)
- When a new metric is added, weights auto-adjust to include it — no user action needed
- Score always computed from 100% of available weight

**Metric normalization:**
- Continuous curve (sigmoid or similar) to map raw metric values to 0-100 sub-scores
- No hard cutoffs — smooth degradation as values exceed ideal ranges
- Exact formula fully documented so users can predict scores

**Weight customization:**
- Named weights in config: `"weights": {"cyclomatic": 0.30, "cognitive": 0.25, ...}`
- Partial override allowed: unspecified weights use defaults, tool normalizes total to 1.0
- Weight of 0 explicitly excludes a metric from scoring (still analyzed, just doesn't affect score)
- `--init` includes all weights with default values in generated config

**Baseline + ratchet workflow:**
- `--save-baseline` flag captures current project score into config file as `"baseline": 73`
- Baseline stored in `.complexityguard.json` alongside other config — committed to git, shared by team
- When baseline exists, score dropping below it causes CI failure (exit code 1)
- Project-level baseline only (not per-file) — individual files can fluctuate as long as overall score holds

**Initial setup workflow (--init enhancement):**
- Enhanced `--init` workflow: analyze codebase, capture baseline score, suggest optimized weights
- Auto-optimize: tool finds weight configuration that maximizes starting score for this codebase
- Output shows: default weights score vs. suggested weights score
- Writes suggested weights + baseline into generated config
- Documentation explains how to remove custom weights and return to ideal defaults once improvements are underway

**Score transparency:**
- Full formula documentation: normalization curves, weight math, aggregation method
- JSON breakdown shows per-metric contribution so users understand what's driving the score

### Claude's Discretion

- Exact sigmoid/curve parameters for normalization
- Project score aggregation method (e.g., average of file scores, weighted by file size/function count)
- Implementation of weight optimization algorithm for --init

### Deferred Ideas (OUT OF SCOPE)

- Per-file baselines — could be added later if project-level proves too coarse
- Score-gated weight graduation (auto-suggest shifting weights toward ideal when score improves) — future enhancement
- Trend tracking over time (score history across commits) — separate feature
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| COMP-01 | Tool computes weighted composite score (0-100) per file | Scoring module applies normalization + weighted sum per file across all ThresholdResult entries |
| COMP-02 | Tool computes weighted composite score (0-100) for entire project | Project score aggregates file scores; research recommends function-count-weighted average |
| COMP-03 | Tool uses configurable weights (default: cognitive 0.30, cyclomatic 0.20, duplication 0.20, halstead 0.15, structural 0.15) | WeightsConfig already exists in config.zig with these exact defaults; scoring reads from it |
| COMP-04 | (Overridden) Letter grades removed per CONTEXT.md — numeric score only | Remove `grade` field from ProjectResult or leave null; remove from JSON output |

**Note on COMP-04:** CONTEXT.md explicitly removes letter grades. The `grade: ?[]const u8` field exists in `ProjectResult` and `ProjectResult` test uses `grade = null`. Phase 8 should leave this null or remove the field entirely and update tests. Recommend keeping the field but always setting it null (minimal diff), documenting the removal.
</phase_requirements>

## Summary

Phase 8 adds a composite health score (0-100) computed from the metric data the tool already collects. The entire metric pipeline (cyclomatic, cognitive, Halstead, structural) already runs and produces `ThresholdResult` structs — Phase 8 reads those values, normalizes each sub-metric to 0-100, computes a weighted average, and attaches the score to file and project output.

The key algorithmic work is the normalization curve. A sigmoid (logistic) function is the right choice: it provides smooth degradation (no hard cutoffs), maps any positive metric value to (0, 100), and is documentable with exact parameters. A practical formulation is `score = 100 / (1 + exp(k * (x - x0)))` where `x0` is the threshold at which the score hits 50 and `k` controls steepness. Per-metric parameters are chosen relative to warning/error thresholds.

The three areas Claude has discretion over (sigmoid parameters, project aggregation method, weight optimization algorithm) are all resolved below. Sigmoid parameters are derived from thresholds. Project aggregation uses function-count-weighted average of file scores. Weight optimization for `--init` uses a simple coordinate descent over discrete weight increments — adequate because the optimization space is small and predictable.

**Primary recommendation:** Create `src/metrics/scoring.zig` with normalization + weighted composite logic. Wire into `main.zig` after all metric passes. Update `console.zig` (health line in summary), `json_output.zig` (score + breakdown fields), `exit_codes.zig` (baseline check), `init.zig` (enhanced --init), and `cli/config.zig` (baseline field). No external libraries needed.

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Zig std math | 0.14.0 | `@exp`, `@log`, float ops | Built-in; no external dep |
| existing `config.zig` | current | WeightsConfig already defined | No new config structure needed |
| existing `cli/args.zig` | current | `--save-baseline` already parsed | Flag is already in CliArgs |
| existing `json_output.zig` | current | Add score fields to JsonOutput | Extend FunctionOutput + add JsonOutput.Summary.health_score |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Zig `std.math.exp` | 0.14.0 | Sigmoid calculation | Only in scoring.zig |
| Arena allocator | existing | Short-lived score breakdown slices | For JSON breakdown slices in formatSummary |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sigmoid normalization | Linear clamp (0 at error threshold, 100 at 0) | Linear is simpler to explain but creates hard cliffs; sigmoid is smooth |
| Sigmoid normalization | Exponential decay `100 * exp(-k * x)` | Simpler formula, easier to parameterize; asymptotes to 0 not 100; equivalent to sigmoid at 0 |
| Function-count-weighted project average | File-count average | File-count is simpler but unfairly weights tiny files; function-count better represents actual code volume |
| Coordinate descent weight optimizer | Exhaustive grid search | Grid search over 5 weights at 0.05 increments = ~10M combinations; coordinate descent converges in <1000 iterations |

## Architecture Patterns

### Recommended Project Structure
```
src/
├── metrics/
│   ├── scoring.zig      # NEW: normalization, composite computation
│   ├── cyclomatic.zig   # existing
│   ├── cognitive.zig    # existing
│   ├── halstead.zig     # existing
│   └── structural.zig   # existing
├── cli/
│   ├── config.zig       # ADD: baseline field to Config struct
│   ├── init.zig         # ENHANCE: run analysis, optimize weights, write baseline
│   └── args.zig         # existing (--save-baseline already present)
└── output/
    ├── console.zig      # ADD: "Health: 73" line in formatSummary
    ├── json_output.zig  # ADD: health_score + breakdown to summary + per-function
    └── exit_codes.zig   # ADD: baseline comparison + exit 1
```

### Pattern 1: Metric Normalization via Sigmoid

**What:** Map each raw metric value to a 0-100 sub-score using a logistic sigmoid parameterized by the metric's warning threshold.

**Formula:** `sub_score = 100.0 / (1.0 + @exp(k * (x - x0)))`

**Parameter derivation:**
- `x0` = warning threshold value (score = 50 at the warning boundary)
- `k` = steepness; set so score ≈ 20 at the error threshold: `k = ln(4) / (error_threshold - warning_threshold)`
  - Rationale: at error threshold, score drops to ~20 (not 0 — smooth degradation continues)

**Example parameters for cyclomatic (warning=10, error=20):**
- `x0 = 10`, `k = ln(4) / 10 ≈ 0.139`
- At x=1: score ≈ 99 (very clean)
- At x=10 (warning): score = 50
- At x=20 (error): score ≈ 20
- At x=30: score ≈ 6

**When to use:** For every metric that has a numeric raw value and known thresholds.

**Example:**
```zig
// Source: derived from standard sigmoid formula
pub fn sigmoidScore(x: f64, x0: f64, k: f64) f64 {
    return 100.0 / (1.0 + @exp(k * (x - x0)));
}

// Cyclomatic normalization
pub fn normalizeCyclomatic(cyclomatic: u32, warning: u32, @"error": u32) f64 {
    const x: f64 = @floatFromInt(cyclomatic);
    const x0: f64 = @floatFromInt(warning);
    const k: f64 = @log(4.0) / @as(f64, @floatFromInt(@"error" - warning));
    return sigmoidScore(x, x0, k);
}
```

### Pattern 2: Proportional Weight Redistribution for Missing Metrics

**What:** When a metric has no data (not implemented yet, e.g., duplication in Phase 8), redistribute its weight proportionally among available metrics.

**Algorithm:**
1. Start with full weight map from config (or defaults)
2. Set weight = 0 for any metric where data is unavailable
3. Sum remaining weights; divide each by the sum to normalize to 1.0

**Example:**
```zig
// Source: derived from standard proportional redistribution
pub fn redistributeWeights(weights: WeightsSnapshot) WeightsSnapshot {
    var total: f64 = 0.0;
    if (weights.cyclomatic > 0 and data_available.cyclomatic) total += weights.cyclomatic;
    if (weights.cognitive > 0 and data_available.cognitive)   total += weights.cognitive;
    if (weights.halstead > 0 and data_available.halstead)     total += weights.halstead;
    if (weights.structural > 0 and data_available.structural) total += weights.structural;
    // duplication: not available until Phase 11 — weight excluded
    if (total == 0.0) return zeroWeights();
    // Divide each included weight by total
    return normalizeByTotal(weights, total);
}
```

**In Phase 8:** duplication weight (0.20) is always excluded because duplication metric doesn't exist yet. The remaining 0.80 is renormalized to 1.0 automatically.

### Pattern 3: Structural Metric Aggregation

**What:** Structural metrics (function_length, params_count, nesting_depth) each produce a sub-score. The "structural" composite sub-score is the average of all three.

**Rationale:** Each structural metric is independent and equally weighted within the family. This matches the single `structural` weight in config.

```zig
pub fn normalizeStructural(tr: ThresholdResult, cfg: StructuralConfig) f64 {
    const length_score = normalizeLengthMetric(tr.function_length, cfg.function_length_warning, cfg.function_length_error);
    const params_score = normalizeMetric(tr.params_count, cfg.params_count_warning, cfg.params_count_error);
    const depth_score  = normalizeMetric(tr.nesting_depth, cfg.nesting_depth_warning, cfg.nesting_depth_error);
    return (length_score + params_score + depth_score) / 3.0;
}
```

### Pattern 4: Per-Function Composite Score

**What:** Weighted average of normalized sub-scores for a single function using effective weights.

```zig
pub fn computeFunctionScore(
    tr: ThresholdResult,
    effective_weights: EffectiveWeights,
    metric_cfgs: MetricConfigs,
) f64 {
    const cycl_score = normalizeCyclomatic(tr.complexity, metric_cfgs.cyclomatic_warning, metric_cfgs.cyclomatic_error);
    const cog_score  = normalizeCognitive(tr.cognitive_complexity, metric_cfgs.cognitive_warning, metric_cfgs.cognitive_error);
    const hal_score  = normalizeHalstead(tr.halstead_volume, metric_cfgs.halstead_volume_warning, metric_cfgs.halstead_volume_error);
    const str_score  = normalizeStructural(tr, metric_cfgs.structural);

    return effective_weights.cyclomatic * cycl_score +
           effective_weights.cognitive  * cog_score  +
           effective_weights.halstead   * hal_score  +
           effective_weights.structural * str_score;
}
```

### Pattern 5: File Score Aggregation

**What:** File score = average of all function scores in the file, weighted by function line count. Heavier functions drag the score down more.

**Recommendation (Claude's discretion):** Function-count-weighted average is simpler to implement and explain. Line-count weighting is more accurate but adds complexity. Use function-count average for Phase 8; users can see per-function scores to understand outliers.

```zig
pub fn computeFileScore(function_scores: []const f64) f64 {
    if (function_scores.len == 0) return 100.0; // empty file = perfect
    var sum: f64 = 0.0;
    for (function_scores) |s| sum += s;
    return sum / @as(f64, @floatFromInt(function_scores.len));
}
```

### Pattern 6: Project Score Aggregation

**What (Claude's discretion):** Function-count-weighted average across all files.

```zig
pub fn computeProjectScore(file_scores: []const f64, function_counts: []const u32) f64 {
    var weighted_sum: f64 = 0.0;
    var total_functions: u32 = 0;
    for (file_scores, function_counts) |score, count| {
        weighted_sum += score * @as(f64, @floatFromInt(count));
        total_functions += count;
    }
    if (total_functions == 0) return 100.0;
    return weighted_sum / @as(f64, @floatFromInt(total_functions));
}
```

### Pattern 7: Baseline Check and Exit Code

**What:** After computing project score, compare to `cfg.baseline`. If score < baseline, exit 1.

```zig
// In main.zig after computing project_score:
if (cfg.baseline) |baseline| {
    if (project_score < baseline - 0.5) { // 0.5 tolerance for float rounding
        // Print message, set exit code 1
    }
}
```

**Key detail:** The `baseline` field must be added to `Config` struct in `config.zig`. The `--save-baseline` flag writes the current score into the config file on disk.

### Pattern 8: Weight Optimization for --init (Claude's discretion)

**What:** Simple coordinate descent that iterates over each weight dimension and nudges it to maximize total score over the analyzed codebase.

**Algorithm:**
1. Start with default weights
2. For each weight dimension (cyclomatic, cognitive, halstead, structural):
   a. Try weight - 0.10, weight (no change), weight + 0.10 (clamped to [0.0, 1.0])
   b. After each change, renormalize all weights to sum to 1.0
   c. Recompute project score with trial weights
   d. Keep change that maximizes score
3. Repeat until no improvement or max 20 iterations
4. This is O(iterations * dimensions * score_computation) — fast enough for --init

**Rationale:** The user's codebase score is dominated by their worst metrics. If cyclomatic is uniformly low, reducing cyclomatic weight raises the starting score. The optimizer finds this automatically. The goal is to give teams a high starting score they can improve over time.

### Anti-Patterns to Avoid

- **Hard cutoffs:** Setting score = 0 when value > error_threshold destroys smooth degradation. Always use sigmoid.
- **Dividing by zero weights:** When all weights are 0 (user sets all to 0 in config), return 100.0 (no metrics = perfect by definition) or warn user.
- **Using `@floatFromInt` on u32 without checking overflow:** Zig's `@floatFromInt` is safe for u32→f64 since f64 can represent all u32 values exactly.
- **Computing scores inside output formatters:** Score computation belongs in `scoring.zig`, not in `console.zig` or `json_output.zig`. Pass pre-computed scores to formatters.
- **Mutating ThresholdResult to add health_score:** `ThresholdResult` is already the "merged metrics" struct. Add `health_score: f64 = 0.0` to it directly, analogous to how halstead and structural fields were added in Phase 7.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exponential function | Custom Taylor series | `std.math.exp` / `@exp` | Standard library; correctly rounded |
| Natural log | Manual approximation | `std.math.log` | Standard library |
| Float formatting for display | Custom formatter | `{d:.0}` format specifier | Built-in Zig format, rounds to integer |
| JSON serialization of score breakdown | Custom JSON builder | `std.json.Stringify.valueAlloc` | Already used throughout codebase |
| Config file writing for --save-baseline | Parse + re-serialize | Direct string manipulation to insert/replace `"baseline"` key | Simpler than full JSON round-trip for a single-field update |

**Key insight:** All math for scoring is elementary — one sigmoid function, one weighted sum. No external libraries needed. The complexity is in the wiring (10+ files to update), not the math.

## Common Pitfalls

### Pitfall 1: Float Precision in Baseline Comparison

**What goes wrong:** Project score is `72.9999...` due to floating-point accumulation, baseline is `73`, comparison fails and CI breaks.

**Why it happens:** Floating-point arithmetic is not exact; summing N scores introduces small errors.

**How to avoid:** Round score to 1 decimal place before storing as baseline and before comparing. Use `@round(score * 10.0) / 10.0`. Or compare with a small tolerance: `score < baseline - 0.5`.

**Warning signs:** Flaky CI failures on unchanged code.

### Pitfall 2: Duplication Weight Included Before Phase 11

**What goes wrong:** Default weights include `duplication: 0.20` but duplication metric is always 0 (not computed). Score is incorrectly low for all codebases.

**Why it happens:** The weight config has duplication but the metric pipeline never sets halstead/structural equivalent for duplication.

**How to avoid:** Scoring module must check metric availability at computation time, not at config-read time. If `duplication_available = false`, exclude its weight from denominator before normalizing. Document this explicitly.

**Warning signs:** Scores consistently ~20% lower than expected; console shows "duplication: 0" for everything.

### Pitfall 3: Empty File Score

**What goes wrong:** A file with 0 functions produces `NaN` or divide-by-zero in score computation.

**Why it happens:** `computeFileScore` divides by `function_scores.len` which is 0.

**How to avoid:** Guard at the top: `if (function_scores.len == 0) return 100.0;` — a file with no analyzable functions is "perfect" by definition.

**Warning signs:** JSON output contains `"health_score": null` or `"NaN"`.

### Pitfall 4: Weight Normalization Side Effects on User Config

**What goes wrong:** User sets `"weights": {"cyclomatic": 0.5}` (partial override). Tool normalizes to 1.0 in memory but writes the normalized value back to config file.

**Why it happens:** If `--save-baseline` or `--init` writes weights to config, it might write the normalized (internal) values instead of the user's original partial values.

**How to avoid:** Always write the user-specified weights verbatim. Only normalize weights internally for score computation. Never persist normalized weights.

**Warning signs:** After one `--save-baseline`, config shows `"cyclomatic": 1.0` instead of `"cyclomatic": 0.5`.

### Pitfall 5: Baseline Field Missing from Config Struct

**What goes wrong:** `--save-baseline` writes `"baseline": 73` to the JSON config file but `loadConfig` silently ignores it because the struct doesn't have the field (uses `ignore_unknown_fields = true`).

**Why it happens:** `Config` struct in `config.zig` doesn't have a `baseline` field. The JSON parser is configured to ignore unknown fields.

**How to avoid:** Add `baseline: ?f64 = null` to `Config` struct before implementing `--save-baseline`. Verify with a round-trip test.

**Warning signs:** `--save-baseline` appears to succeed but ratchet never fires.

### Pitfall 6: Score in Console/JSON When Scoring Not Run

**What goes wrong:** JSON output always shows `"health_score": null` even after Phase 8 ships.

**Why it happens:** Scoring is an optional pass (like halstead was gated by `isMetricEnabled`). If it's not explicitly gated, it must always run. Phase 7 established the pattern of gating metrics behind `--metrics` flag — scoring should NOT follow this pattern; it should always compute.

**How to avoid:** Score computation is NOT gated by `--metrics`. It always runs, using whatever metrics are available. Document this clearly.

### Pitfall 7: Halstead Normalization for Scoring vs Threshold

**What goes wrong:** Halstead volume is used for both threshold checking (warning/error status) and score normalization. Using the same thresholds for both is appropriate, but the normalization curve maps volume 0→100 (perfect) while threshold treats 0 as ideal. These are consistent: low volume = high score = no violation.

**How to avoid:** Explicitly document that for Halstead, `x0 = volume_warning_threshold`, consistent with cyclomatic/cognitive. The sigmoid is oriented correctly: lower x → higher score.

## Code Examples

Verified patterns from codebase (HIGH confidence — read directly from source):

### Adding health_score to ThresholdResult

```zig
// src/metrics/cyclomatic.zig — ThresholdResult struct (add field)
pub const ThresholdResult = struct {
    // ... existing fields ...
    // Scoring (Phase 8)
    health_score: f64 = 0.0,  // Computed by scoring.zig after all metrics run
};
```

### Adding baseline to Config

```zig
// src/cli/config.zig — Config struct (add field)
pub const Config = struct {
    output: ?OutputConfig = null,
    analysis: ?AnalysisConfig = null,
    files: ?FilesConfig = null,
    weights: ?WeightsConfig = null,
    overrides: ?[]OverrideConfig = null,
    baseline: ?f64 = null,  // NEW: project baseline score for ratchet
};
```

### Scoring module structure

```zig
// src/metrics/scoring.zig
const std = @import("std");
const cyclomatic = @import("cyclomatic.zig");
const config = @import("../cli/config.zig");

/// Inputs to score computation for one metric set
pub const MetricThresholds = struct {
    cyclomatic_warning: u32,
    cyclomatic_error: u32,
    cognitive_warning: u32,
    cognitive_error: u32,
    halstead_volume_warning: f64,
    halstead_volume_error: f64,
    structural_length_warning: u32,
    structural_length_error: u32,
    structural_params_warning: u32,
    structural_params_error: u32,
    structural_depth_warning: u32,
    structural_depth_error: u32,
};

/// Effective weights after redistribution (sum to 1.0)
pub const EffectiveWeights = struct {
    cyclomatic: f64,
    cognitive: f64,
    halstead: f64,
    structural: f64,
    // duplication: always 0.0 until Phase 11
};

/// Breakdown of score by metric contribution (for JSON output)
pub const ScoreBreakdown = struct {
    cyclomatic_sub_score: f64,
    cognitive_sub_score: f64,
    halstead_sub_score: f64,
    structural_sub_score: f64,
    effective_weights: EffectiveWeights,
};

pub fn sigmoidScore(x: f64, x0: f64, k: f64) f64 {
    return 100.0 / (1.0 + @exp(k * (x - x0)));
}

pub fn resolveEffectiveWeights(weights: config.WeightsConfig) EffectiveWeights {
    // duplication excluded (Phase 11); normalize remaining
    const cycl = weights.cyclomatic orelse 0.20;
    const cog  = weights.cognitive orelse 0.30;
    const hal  = weights.halstead orelse 0.15;
    const str  = weights.structural orelse 0.15;
    const total = cycl + cog + hal + str;
    if (total <= 0.0) return .{ .cyclomatic = 0.25, .cognitive = 0.25, .halstead = 0.25, .structural = 0.25 };
    return .{
        .cyclomatic = cycl / total,
        .cognitive  = cog  / total,
        .halstead   = hal  / total,
        .structural = str  / total,
    };
}
```

### Console output — health score line in formatSummary

```zig
// src/output/console.zig — add after "Analyzed N files" line
const score_color: []const u8 = if (config.use_color) blk: {
    if (project_score >= 80.0) break :blk AnsiCode.green
    else if (project_score >= 50.0) break :blk AnsiCode.yellow
    else break :blk AnsiCode.red;
} else "";
const score_reset = if (config.use_color) AnsiCode.reset else "";
try writer.print("{s}Health: {d:.0}{s}\n", .{ score_color, project_score, score_reset });
```

### JSON output — health score in summary and per-function

```zig
// src/output/json_output.zig — extend Summary
pub const Summary = struct {
    files_analyzed: u32,
    total_functions: u32,
    warnings: u32,
    errors: u32,
    status: []const u8,
    health_score: f64,           // NEW: project composite score
    health_score_breakdown: ?ScoreBreakdownOutput = null, // NEW: optional
};

// Extend FunctionOutput
pub const FunctionOutput = struct {
    // ... existing fields ...
    health_score: f64,           // WAS: ?f64 = null; NOW: always populated
    score_breakdown: ?ScoreBreakdownOutput = null, // NEW: optional breakdown
};
```

### Writing baseline to config file (--save-baseline)

The config file is JSON. The simplest correct approach is:
1. Read existing config file content
2. Parse as `std.json.Value` (dynamic)
3. Set the `baseline` key to the rounded score
4. Re-serialize with `std.json.Stringify.valueAlloc`

This is cleaner than string manipulation and avoids invalidating other keys. The dynamic JSON value API (`std.json.Value`) supports mutation.

```zig
// Pseudocode for --save-baseline
pub fn saveBaseline(allocator: Allocator, config_path: []const u8, score: f64) !void {
    const rounded = @round(score * 10.0) / 10.0;
    // Read file → parse as std.json.Value → set .object["baseline"] = .{ .float = rounded }
    // → serialize back to file
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-field health_score placeholder (`?f64`) in FunctionResult | Live computed f64 in ThresholdResult | Phase 8 | FunctionResult.health_score stays as forward placeholder; ThresholdResult gets the computed value |
| `grade: ?[]const u8` in ProjectResult | Always null / removed | Phase 8 | CONTEXT.md removes letter grades; planner should leave null or remove the field |
| `--save-baseline` in CliArgs already parsed | Needs handler in main.zig | Phase 7 → Phase 8 | Flag parsing exists, behavior not yet implemented |
| `fail_health_below` in CliArgs already parsed | Could be used as alternative to config baseline | Phase 7 → Phase 8 | Planner decision: implement or defer. CONTEXT.md uses config baseline — `fail_health_below` CLI flag is redundant but already exists |

**Deprecated/outdated:**
- Letter grades (A-F) mentioned in original COMP-04: replaced by numeric-only score per CONTEXT.md
- `health_score: ?f64 = null` in `json_output.zig FunctionOutput`: change to `health_score: f64` (always populated after Phase 8)

## Open Questions

1. **What to do with `fail_health_below` CLI flag?**
   - What we know: `CliArgs.fail_health_below: ?[]const u8` already parsed. CONTEXT.md specifies baseline in config, not CLI flag.
   - What's unclear: Should `--fail-health-below 70` be a valid CLI override of config baseline?
   - Recommendation: Implement as CLI analog to config baseline — if `fail_health_below` is set, override config baseline. Provides one-off CI threshold without modifying config file. This is consistent with how other CLI flags override config.

2. **Should `--save-baseline` require a config file to exist?**
   - What we know: `--save-baseline` must write to `.complexityguard.json`. If no config file exists, it must create one.
   - What's unclear: Should it create a minimal config (just `{"baseline": 73}`) or full default config?
   - Recommendation: Create full default config (like `--init` without optimization) and add baseline. This ensures the file is always well-formed.

3. **Score display precision in console output**
   - What we know: CONTEXT.md says `"Health: 73"` — plain integer.
   - What's unclear: Should it be `{d:.0}` (rounds 72.5 → 73) or `{d}` truncated to integer?
   - Recommendation: Use `{d:.0}` (standard round-half-up). Document this in formula docs.

4. **Where does `--init` enhanced analysis run?**
   - What we know: Enhanced `--init` must analyze the codebase, compute scores, find optimal weights.
   - What's unclear: `runInit` in `init.zig` currently doesn't have access to the full analysis pipeline. It would need to call `analyzeProject` which lives in `main.zig`.
   - Recommendation: Extract analysis pipeline into a standalone `analyzeProject(allocator, paths, config) !ProjectScoreResult` function callable from both `main.zig` and `init.zig`. This is the cleanest refactor.

## Sources

### Primary (HIGH confidence)
- Direct source code read — `src/cli/config.zig`: WeightsConfig defaults (cognitive 0.30, cyclomatic 0.20, duplication 0.20, halstead 0.15, structural 0.15) confirmed
- Direct source code read — `src/cli/args.zig`: `--save-baseline`, `--fail-health-below`, `--baseline` flags already parsed; need handlers
- Direct source code read — `src/metrics/cyclomatic.zig`: ThresholdResult struct confirmed; pattern for adding fields established (halstead/structural added in Phase 7)
- Direct source code read — `src/output/json_output.zig`: `health_score: ?f64 = null` placeholder confirmed; needs to become populated f64
- Direct source code read — `src/output/console.zig`: AnsiCode constants confirmed (red, yellow, green); formatSummary signature confirmed
- Direct source code read — `src/output/exit_codes.zig`: `determineExitCode` function confirmed; baseline check will add a new condition parallel to error/warning checks
- Direct source code read — `src/cli/init.zig`: `runInit` function confirmed; currently generates static config without analysis

### Secondary (MEDIUM confidence)
- Standard sigmoid function mathematics: `100 / (1 + exp(k*(x-x0)))` — well-established formula, parameterization strategy derived from first principles
- Weight redistribution via proportional normalization — standard approach in composite indicators literature
- Coordinate descent for weight optimization — widely used, convergent for convex-like objective functions

### Tertiary (LOW confidence)
- WebSearch for sigmoid normalization in code complexity tools — no direct match found; formula is derived from general ML/scoring literature and adapted for this domain

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all existing code read directly; no external libraries needed
- Architecture patterns: HIGH — follows established Phase 7 patterns exactly; all extension points identified
- Math/formulas: MEDIUM — sigmoid formula is standard; exact parameterization (k=ln(4)/(error-warning)) is a reasoned choice, not industry-specified
- Pitfalls: HIGH — identified from direct codebase analysis (placeholder fields, missing config field, empty file edge case)

**Research date:** 2026-02-17
**Valid until:** 2026-03-19 (30 days — Zig 0.14 stable; no fast-moving dependencies)
