---
status: resolved
trigger: "Diagnose --save-baseline removal and --init config completeness"
created: 2026-02-22T00:00:00Z
updated: 2026-02-22T00:00:00Z
---

## Current Focus

hypothesis: --save-baseline has artifacts in 3 source files + 8 doc files; --init config is missing many options from Config schema
test: Compare generateJsonConfig output against Config/ThresholdsConfig type definitions
expecting: Gap between generated config options and full schema
next_action: Document all findings for removal/fix plan

## Symptoms

expected: (1) --save-baseline removed entirely. (2) --init generates config with ALL available options.
actual: (1) --save-baseline still fully wired in CLI parsing, help text, main.zig handler. (2) --init generates config missing most threshold options, baseline, duplication thresholds, file_length, export_count, halstead sub-metrics, nesting_depth, line_count, params_count thresholds, structural thresholds, and threads.
errors: N/A (functional bugs, not crashes)
reproduction: Run `complexity-guard --save-baseline .` (still works); Run `complexity-guard --init` (generates incomplete config)
started: These are design gaps, not regressions

## Eliminated

(none - direct code inspection, no hypotheses needed)

## Evidence

- timestamp: 2026-02-22T00:01:00Z
  checked: src/cli/args.zig for save_baseline field and parsing
  found: Line 21 declares `save_baseline: bool = false`; Line 78-79 parses `--save-baseline` flag
  implication: Must remove field from CliArgs struct and remove parsing branch

- timestamp: 2026-02-22T00:02:00Z
  checked: src/main.zig for --save-baseline handler
  found: Lines 28-48 define `writeDefaultConfigWithBaseline()` helper; Lines 619-675 handle `cli_args.save_baseline` (compute rounded score, read/write config with baseline field)
  implication: Must remove the entire writeDefaultConfigWithBaseline function and the save_baseline handler block

- timestamp: 2026-02-22T00:03:00Z
  checked: src/cli/help.zig for --save-baseline in help text
  found: Line 28 contains `\\      --save-baseline        Save current health score as baseline in config`
  implication: Must remove this line from help text

- timestamp: 2026-02-22T00:04:00Z
  checked: src/cli/init.zig generateJsonConfig function
  found: Config generated includes only: output.format, analysis.metrics, analysis.thresholds (cyclomatic + cognitive ONLY), files.exclude, weights (all 5). Missing everything else.
  implication: --init config is severely incomplete

- timestamp: 2026-02-22T00:05:00Z
  checked: src/cli/config.zig Config/ThresholdsConfig schema vs init output
  found: ThresholdsConfig has 12 fields (cyclomatic, cognitive, halstead_volume, halstead_difficulty, halstead_effort, halstead_bugs, nesting_depth, line_count, params_count, file_length, export_count, duplication). Init only generates 2 (cyclomatic, cognitive).
  implication: 10 threshold categories missing from --init config

- timestamp: 2026-02-22T00:06:00Z
  checked: Config struct for additional top-level options
  found: Config has `baseline: ?f64` field and `overrides: ?[]OverrideConfig` field. AnalysisConfig has `threads: ?u32`, `no_duplication: ?bool`, `duplication_enabled: ?bool`. None appear in --init output.
  implication: baseline, threads, duplication flags, and files.include all missing from --init

## Resolution

root_cause: Two distinct issues:

**Issue 1: --save-baseline not removed.** The feature is fully wired across 3 source files (args.zig, main.zig, help.zig) plus 8+ documentation/planning files. It was never removed despite being flagged for removal.

**Issue 2: --init config incomplete.** The `generateJsonConfig` function in `src/cli/init.zig` only generates a subset of available config options. It includes only cyclomatic and cognitive thresholds but omits all halstead, structural, duplication, file-level, and other threshold categories. It also omits baseline, threads, and files.include.

---

## DETAILED FINDINGS

### Part 1: --save-baseline Artifacts (TO BE REMOVED)

#### Source Code Files

**File: `src/cli/args.zig`**
- Line 21: `save_baseline: bool = false` -- field in CliArgs struct
- Lines 78-79: Parsing branch for `"save-baseline"` flag
- Lines 251-260: Test `"parse --save-baseline sets save_baseline flag"`

**File: `src/main.zig`**
- Lines 28-48: `writeDefaultConfigWithBaseline()` -- helper function to write config file with baseline
- Line 29: Doc comment referencing `--save-baseline`
- Lines 619-675: `if (cli_args.save_baseline) { ... }` -- full handler block that:
  - Computes rounded project score
  - Reads existing config or creates new one
  - Writes/updates baseline field in config JSON
  - Prints "Baseline saved: X" and returns

**File: `src/cli/help.zig`**
- Line 28: `\\      --save-baseline        Save current health score as baseline in config`

**File: `src/cli/merge.zig`**
- No direct reference to save_baseline (it's not merged into config, it's handled in main.zig directly)

#### Documentation Files (also need updating)

- `docs/cli-reference.md` -- Line 271+: `--save-baseline` section
- `docs/health-score.md` -- Lines 138, 141, 178, 237: references to `--save-baseline`
- `docs/getting-started.md` -- references to `--save-baseline`
- `docs/examples.md` -- references to `--save-baseline`
- `CHANGELOG.md` -- Line 47: mentions `--save-baseline`

#### Planning Files (reference only, may not need changes)

- `.planning/ROADMAP.md`
- `.planning/v1.0-MILESTONE-AUDIT.md`
- `.planning/phases/08-composite-health-score/` (multiple files)
- `.planning/phases/13-gap-closure-pipeline-wiring/` (multiple files)

### Part 2: --init Config Completeness Analysis

#### Current --init Output (from `src/cli/init.zig:69-113` `generateJsonConfig`)

The generated JSON currently includes:

```json
{
  "output": {
    "format": "console"
  },
  "analysis": {
    "metrics": ["cyclomatic", "cognitive", "halstead", "nesting", "line_count", "params_count"],
    "thresholds": {
      "cyclomatic": { "warning": 10, "error": 20 },
      "cognitive": { "warning": 15, "error": 25 }
    }
  },
  "files": {
    "exclude": ["node_modules", "dist", "build", ".git"]
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "duplication": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  }
}
```

#### What SHOULD Be Included (from Config schema + metric defaults)

**Missing threshold categories** (from `ThresholdsConfig` in `src/cli/config.zig:34-47`):

| Threshold | Default Warning | Default Error | Source |
|-----------|----------------|---------------|--------|
| `halstead_volume` | 500 | 1000 | `src/metrics/halstead.zig:35-37` |
| `halstead_difficulty` | 10 | 20 | `src/metrics/halstead.zig:39-41` |
| `halstead_effort` | 5000 | 10000 | `src/metrics/halstead.zig:43-45` |
| `halstead_bugs` | (0.5) | (2.0) | `src/metrics/halstead.zig:47-49` (NOTE: f64, but ThresholdPair uses u32) |
| `nesting_depth` | 3 | 5 | `src/metrics/structural.zig:16-17` |
| `line_count` | 25 | 50 | `src/metrics/structural.zig:10-11` |
| `params_count` | 3 | 6 | `src/metrics/structural.zig:13-14` |
| `file_length` | 300 | 600 | `src/metrics/structural.zig:19-20` |
| `export_count` | 15 | 30 | `src/metrics/structural.zig:22-23` |
| `duplication` | (file: 15%, project: 5%) | (file: 25%, project: 10%) | `src/metrics/duplication.zig:100-103` (NOTE: uses DuplicationThresholds, not ThresholdPair) |

**Missing top-level/section options:**

| Option | Type | Default | Source |
|--------|------|---------|--------|
| `baseline` | `?f64` | null | `src/cli/config.zig:15` |
| `analysis.threads` | `?u32` | null (auto-detect) | `src/cli/config.zig:30` |
| `files.include` | `?[]string` | null | `src/cli/config.zig:67` |
| `output.file` | `?string` | null | `src/cli/config.zig:21` |

**Note on duplication thresholds:** The `DuplicationThresholds` struct (config.zig:58-63) uses different field names than `ThresholdPair` -- it has `file_warning`, `file_error`, `project_warning`, `project_error` (all `?f64`).

#### Complete --init config SHOULD look like:

```json
{
  "output": {
    "format": "console"
  },
  "analysis": {
    "metrics": ["cyclomatic", "cognitive", "halstead", "nesting", "line_count", "params_count"],
    "thresholds": {
      "cyclomatic": { "warning": 10, "error": 20 },
      "cognitive": { "warning": 15, "error": 25 },
      "halstead_volume": { "warning": 500, "error": 1000 },
      "halstead_difficulty": { "warning": 10, "error": 20 },
      "halstead_effort": { "warning": 5000, "error": 10000 },
      "halstead_bugs": { "warning": 1, "error": 2 },
      "nesting_depth": { "warning": 3, "error": 5 },
      "line_count": { "warning": 25, "error": 50 },
      "params_count": { "warning": 3, "error": 6 },
      "file_length": { "warning": 300, "error": 600 },
      "export_count": { "warning": 15, "error": 30 },
      "duplication": {
        "file_warning": 15.0,
        "file_error": 25.0,
        "project_warning": 5.0,
        "project_error": 10.0
      }
    }
  },
  "files": {
    "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "exclude": ["node_modules", "dist", "build", ".git"]
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "duplication": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  }
}
```

**Note on halstead_bugs:** The default values are 0.5 (warning) and 2.0 (error) as f64 in HalsteadConfig, but ThresholdPair uses `?u32`. The config schema rounds these to integers (1 and 2). This is a pre-existing design tension -- the config file uses u32 but the actual thresholds are f64. The --init output should use the integer versions since that matches the ThresholdPair schema that loadConfig will parse.

### Part 3: Additional Notes

1. The `generateTomlConfig` function (init.zig:116-163) has the same incompleteness as `generateJsonConfig` -- both need to be updated in parallel.

2. The `ThresholdPreset` struct in init.zig (lines 10-15) only has cyclomatic and cognitive fields. If presets are to remain, this struct needs to be expanded to cover all metrics, or the preset concept should be replaced with direct default values from the metric modules.

3. The `writeDefaultConfigWithBaseline` function in main.zig (lines 30-48) also writes an incomplete config (only output, weights, and baseline) -- but this function should be removed entirely as part of --save-baseline removal.
