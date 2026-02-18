# CLI Reference

Complete reference for ComplexityGuard command-line interface, configuration options, and exit codes.

## Usage

```
complexity-guard [OPTIONS] [PATH]...
```

Analyze complexity of TypeScript/JavaScript files in the specified paths. If no paths are provided, analyzes the current directory (`.`).

## Arguments

**`[PATH]...`** — One or more files or directories to analyze

```sh
# Analyze a directory
complexity-guard src/

# Analyze multiple directories
complexity-guard src/ lib/

# Analyze specific files
complexity-guard src/app.ts src/utils.ts

# Analyze current directory
complexity-guard .
```

Paths can be files or directories. When given a directory, ComplexityGuard recursively finds all TypeScript/JavaScript files (`.ts`, `.tsx`, `.js`, `.jsx`).

## Flags

### General

**`-h, --help`**

Show help message with usage information.

```sh
complexity-guard --help
```

**`--version`**

Display version information.

```sh
complexity-guard --version
# Output: complexityguard 0.1.0
```

**`--init`**

Generate a `.complexityguard.json` configuration file with default thresholds and weights.

```sh
complexity-guard --init
```

Creates a config file with standard thresholds, default metric weights, and common exclude patterns. Edit the generated file to customize for your project.

### Output

**`-f, --format <FORMAT>`**

Set output format. Available formats:
- `console` (default) — Human-readable terminal output with colors
- `json` — Machine-readable JSON for CI/tooling integration
- `sarif` — SARIF 2.1.0 output for GitHub Code Scanning integration (see [SARIF Output](sarif-output.md))
- `html` — Self-contained HTML report with interactive dashboard, file breakdown table, treemap visualization, and bar chart. No external CSS/JS dependencies. Use `--output` to save to disk.

```sh
# Console output (default)
complexity-guard src/

# JSON output
complexity-guard --format json src/

# SARIF output for GitHub Code Scanning
complexity-guard --format sarif . > results.sarif

# HTML report (use --output — output is large)
complexity-guard --format html --output report.html src/

# Short form
complexity-guard -f json src/
```

**`-o, --output <FILE>`**

Write output to a file instead of (or in addition to) stdout.

```sh
# Write JSON report to file
complexity-guard --format json --output report.json src/

# Console output also goes to file
complexity-guard --output results.txt src/
```

When using JSON format with `--output`, the JSON is written to the file and also printed to stdout.

**`--color`**

Force color output even when stdout is not a TTY.

```sh
complexity-guard --color src/ | tee output.txt
```

**`--no-color`**

Disable color output even when stdout is a TTY.

```sh
complexity-guard --no-color src/
```

Color precedence order (highest to lowest):
1. `--no-color` (always disable)
2. `--color` (always enable)
3. `NO_COLOR` environment variable (disable if set)
4. `FORCE_COLOR` or `YES_COLOR` environment variables (enable if set)
5. TTY detection (enable if stdout is a terminal)

**`-v, --verbose`**

Show detailed output including all functions, even those that pass thresholds.

```sh
complexity-guard --verbose src/
```

Default mode shows only files with problems. Verbose mode shows all files and all functions.

**`-q, --quiet`**

Suppress non-error output. Show only error-level violations.

```sh
complexity-guard --quiet src/
```

### Analysis

**`--metrics <LIST>`**

Select which metric families to compute. Comma-separated list. Available: `cyclomatic`, `cognitive`, `halstead`, `structural`. Default: all families enabled.

```sh
# Enable all metrics (default)
complexity-guard src/

# Cyclomatic and Halstead only
complexity-guard --metrics cyclomatic,halstead src/

# Cyclomatic only
complexity-guard --metrics cyclomatic src/

# Skip Halstead (compute everything else)
complexity-guard --metrics cyclomatic,cognitive,structural src/
```

When `--metrics` is specified, only the listed families are computed and displayed. Unspecified families are skipped entirely — both in analysis and in output.

**`--no-duplication`**

Skip duplication analysis (reserved for future use).

```sh
complexity-guard --no-duplication src/
```

**`--threads <N>`**

Set the number of threads for parallel analysis. Defaults to CPU count.

```sh
# Use 4 threads
complexity-guard --threads 4 src/

# Single-threaded (for debugging)
complexity-guard --threads 1 src/
```

**`--baseline <FILE>`**

Compare against a baseline report (reserved for future use).

```sh
complexity-guard --baseline previous-report.json src/
```

### File Filtering

**`--include <GLOB>`**

Include files matching the glob pattern. Can be specified multiple times.

```sh
# Include only TypeScript files
complexity-guard --include "**/*.ts" --include "**/*.tsx" src/

# Single pattern
complexity-guard --include "src/**/*.ts" .
```

**`--exclude <GLOB>`**

Exclude files matching the glob pattern. Can be specified multiple times.

```sh
# Exclude test files
complexity-guard --exclude "**/*.test.ts" --exclude "**/*.spec.ts" src/

# Exclude node_modules
complexity-guard --exclude "node_modules/**" .
```

Exclude patterns are applied after include patterns.

### Thresholds

**`--fail-on <LEVEL>`**

Set the threshold level that causes a non-zero exit code. Options:
- `error` (default) — Exit non-zero only on errors
- `warning` — Exit non-zero on warnings or errors
- `never` — Always exit 0 (success)

```sh
# Fail on warnings (strict mode for CI)
complexity-guard --fail-on warning src/

# Never fail (report-only mode)
complexity-guard --fail-on never src/
```

**`--fail-health-below <N>`**

Exit non-zero if the overall project health score falls below the specified value. Takes precedence over the `baseline` field in the config file.

```sh
complexity-guard --fail-health-below 70 src/
```

When the health score is below the threshold, ComplexityGuard exits with code 1 and prints a message to stderr:

```
Health score 68.4 is below threshold 70.0 — exiting with error
```

See [Health Score](health-score.md) for the full baseline + ratchet workflow.

**`--save-baseline`**

Run the analysis, compute the project health score, and save it to `.complexityguard.json` as the `baseline` field. Future runs will enforce this score automatically.

```sh
complexity-guard --save-baseline src/
```

This reads the existing config (if any), updates the `baseline` field, and writes it back. If no config exists, a minimal config is created. The saved score is rounded to one decimal place:

```json
{
  "baseline": 73.2
}
```

After saving a baseline, subsequent runs of `complexity-guard src/` will exit 1 if the score drops below it. To change the baseline, re-run with `--save-baseline`.

### Configuration

**`-c, --config <FILE>`**

Use a specific configuration file instead of auto-discovery.

```sh
# Use custom config location
complexity-guard --config .complexity-ci.json src/

# Short form
complexity-guard -c config/complexity.json src/
```

By default, ComplexityGuard searches for `.complexityguard.json` in:
1. Current directory
2. Parent directories (up to repository root)
3. XDG config directory (`~/.config/complexity-guard/config.json`)

## Configuration File

ComplexityGuard uses `.complexityguard.json` for configuration. Generate a default config with `complexity-guard --init`.

### Full Schema

```json
{
  "files": {
    "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "exclude": ["node_modules/**", "dist/**", "build/**", "**/*.test.ts"]
  },
  "thresholds": {
    "cyclomatic": {
      "warning": 10,
      "error": 20
    },
    "cognitive": {
      "warning": 15,
      "error": 25
    },
    "halstead_volume": {
      "warning": 500,
      "error": 1000
    },
    "halstead_difficulty": {
      "warning": 10,
      "error": 20
    },
    "halstead_effort": {
      "warning": 5000,
      "error": 10000
    },
    "halstead_bugs": {
      "warning": 0.5,
      "error": 2.0
    },
    "function_length": {
      "warning": 25,
      "error": 50
    },
    "params": {
      "warning": 3,
      "error": 6
    },
    "nesting": {
      "warning": 3,
      "error": 5
    },
    "file_length": {
      "warning": 300,
      "error": 600
    },
    "exports": {
      "warning": 15,
      "error": 30
    }
  },
  "counting_rules": {
    "logical_operators": true,
    "nullish_coalescing": true,
    "optional_chaining": true,
    "switch_case_mode": "perCase"
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  },
  "baseline": 73.2,
  "output": {
    "format": "console"
  }
}
```

### Options

**`files.include`** (array of strings)

Glob patterns for files to include in analysis. Defaults to all TypeScript/JavaScript files.

**`files.exclude`** (array of strings)

Glob patterns for files to exclude from analysis.

**`thresholds.cyclomatic.warning`** (integer)

Cyclomatic complexity threshold for warnings. Default: `10`.

**`thresholds.cyclomatic.error`** (integer)

Cyclomatic complexity threshold for errors. Default: `20`.

**`thresholds.cognitive.warning`** (integer)

Cognitive complexity threshold for warnings. Default: `15` (SonarSource recommendation).

**`thresholds.cognitive.error`** (integer)

Cognitive complexity threshold for errors. Default: `25` (SonarSource recommendation).

See [Cognitive Complexity](cognitive-complexity.md) for details on how this metric is calculated.

**`thresholds.halstead_volume.warning`** (float)

Halstead volume threshold for warnings. Default: `500`.

**`thresholds.halstead_volume.error`** (float)

Halstead volume threshold for errors. Default: `1000`.

**`thresholds.halstead_difficulty.warning`** (float)

Halstead difficulty threshold for warnings. Default: `10`.

**`thresholds.halstead_difficulty.error`** (float)

Halstead difficulty threshold for errors. Default: `20`.

**`thresholds.halstead_effort.warning`** (float)

Halstead effort threshold for warnings. Default: `5000`.

**`thresholds.halstead_effort.error`** (float)

Halstead effort threshold for errors. Default: `10000`.

**`thresholds.halstead_bugs.warning`** (float)

Halstead estimated bugs threshold for warnings. Default: `0.5`.

**`thresholds.halstead_bugs.error`** (float)

Halstead estimated bugs threshold for errors. Default: `2.0`.

See [Halstead Metrics](halstead-metrics.md) for details on how these are calculated.

**`thresholds.function_length.warning`** (integer)

Function length (logical lines) threshold for warnings. Default: `25`.

**`thresholds.function_length.error`** (integer)

Function length threshold for errors. Default: `50`.

**`thresholds.params.warning`** (integer)

Parameter count threshold for warnings. Default: `3`.

**`thresholds.params.error`** (integer)

Parameter count threshold for errors. Default: `6`.

**`thresholds.nesting.warning`** (integer)

Nesting depth threshold for warnings. Default: `3`.

**`thresholds.nesting.error`** (integer)

Nesting depth threshold for errors. Default: `5`.

**`thresholds.file_length.warning`** (integer)

File length (logical lines) threshold for warnings. Default: `300`.

**`thresholds.file_length.error`** (integer)

File length threshold for errors. Default: `600`.

**`thresholds.exports.warning`** (integer)

Export count threshold for warnings. Default: `15`.

**`thresholds.exports.error`** (integer)

Export count threshold for errors. Default: `30`.

See [Structural Metrics](structural-metrics.md) for details on how these are calculated.

**`counting_rules.logical_operators`** (boolean)

Whether to count `&&` and `||` operators toward complexity. Default: `true` (ESLint behavior).

**`counting_rules.nullish_coalescing`** (boolean)

Whether to count `??` operator toward complexity. Default: `true`.

**`counting_rules.optional_chaining`** (boolean)

Whether to count `?.` operator toward complexity. Default: `true`.

**`counting_rules.switch_case_mode`** (string)

How to count switch statements:
- `"perCase"` (default) — Each case adds +1 (ESLint behavior)
- `"switchOnly"` — Only the switch itself adds +1 (classic McCabe)

**`output.format`** (string)

Default output format: `"console"`, `"json"`, `"sarif"`, or `"html"`. Default: `"console"`.

**`weights.cognitive`** (float)

Weight for cognitive complexity in the composite health score. Default: `0.30`.

**`weights.cyclomatic`** (float)

Weight for cyclomatic complexity in the composite health score. Default: `0.20`.

**`weights.halstead`** (float)

Weight for Halstead volume in the composite health score. Default: `0.15`.

**`weights.structural`** (float)

Weight for structural metrics (function length, params, nesting depth) in the composite health score. Default: `0.15`.

Weights are normalized to sum to 1.0 before use. Set a weight to `0.0` to exclude that metric from the health score (it is still analyzed and shown in output). See [Health Score](health-score.md) for the full formula and effective weight calculation.

**`baseline`** (float)

Health score threshold for CI enforcement. When set, `complexity-guard` exits with code 1 if the project health score falls below this value. Set automatically by `--save-baseline`. Default: none (no enforcement).

### CLI Flags Override Config

When both a config file and CLI flags are provided, CLI flags take precedence:

```sh
# Config sets warning=10, but CLI overrides with --fail-on
complexity-guard --fail-on never src/  # Won't fail even with errors
```

## Exit Codes

ComplexityGuard uses exit codes to signal different outcomes, making it easy to integrate with CI/CD pipelines.

| Code | Name | Meaning |
|------|------|---------|
| 0 | Success | All checks passed, no violations found |
| 1 | Errors Found | One or more functions exceeded error threshold, or health score is below baseline/`--fail-health-below` |
| 2 | Warnings Found | One or more functions exceeded warning threshold (only when `--fail-on warning`) |
| 3 | Config Error | Configuration file is invalid or could not be loaded |
| 4 | Parse Error | One or more files failed to parse |

### Exit Code Priority

When multiple conditions are present, the highest priority exit code is used:

1. **Parse Error (4)** — Takes precedence over everything
2. **Baseline Failed (1)** — Health score below threshold (after parse errors)
3. **Errors Found (1)** — One or more functions exceeded error threshold
4. **Warnings Found (2)** — Only when `--fail-on warning` is set
5. **Success (0)** — Default when no issues found

Example:

```sh
# Run analysis and check exit code
complexity-guard src/
echo $?  # Prints exit code

# Use in CI script
if complexity-guard --fail-on warning src/; then
  echo "All checks passed!"
else
  echo "Complexity violations found"
  exit 1
fi
```

## JSON Output Schema

When using `--format json`, ComplexityGuard produces structured JSON output.

### Structure

```json
{
  "version": "1.0.0",
  "timestamp": 1708012345,
  "summary": {
    "files_analyzed": 12,
    "total_functions": 47,
    "warnings": 3,
    "errors": 1,
    "health_score": 73.2,
    "status": "error"
  },
  "files": [
    {
      "path": "src/auth/login.ts",
      "file_length": 112,
      "export_count": 4,
      "functions": [
        {
          "name": "validateCredentials",
          "start_line": 42,
          "end_line": 0,
          "start_col": 0,
          "cyclomatic": 3,
          "cognitive": 2,
          "halstead_volume": 75.4,
          "halstead_difficulty": 4.2,
          "halstead_effort": 316.7,
          "halstead_bugs": 0.025,
          "nesting_depth": 2,
          "line_count": 8,
          "params_count": 2,
          "health_score": 94.7,
          "status": "ok"
        },
        {
          "name": "handleComplexAuthFlow",
          "start_line": 89,
          "end_line": 0,
          "start_col": 2,
          "cyclomatic": 25,
          "cognitive": 32,
          "halstead_volume": 1243.8,
          "halstead_difficulty": 18.6,
          "halstead_effort": 23134.7,
          "halstead_bugs": 0.414,
          "nesting_depth": 6,
          "line_count": 62,
          "params_count": 4,
          "health_score": 8.3,
          "status": "error"
        }
      ]
    }
  ]
}
```

### Fields

**Top Level:**
- `version` (string) — JSON schema version
- `timestamp` (integer) — Unix timestamp when analysis was run
- `summary` (object) — Aggregate statistics
- `files` (array) — Per-file results

**Summary:**
- `files_analyzed` (integer) — Number of files analyzed
- `total_functions` (integer) — Total functions found across all files
- `warnings` (integer) — Number of warning-level violations
- `errors` (integer) — Number of error-level violations
- `health_score` (float) — Project-level composite health score (0–100)
- `status` (string) — Overall status: `"pass"`, `"warning"`, or `"error"`

**File:**
- `path` (string) — Relative path to the file
- `file_length` (integer) — Logical lines in the file (excludes blank and comment-only lines)
- `export_count` (integer) — Number of export statements in the file
- `functions` (array) — Functions found in this file

**Function:**
- `name` (string) — Function name
- `start_line` (integer) — Line number where function starts (1-indexed)
- `end_line` (integer) — Reserved for future use (currently 0)
- `start_col` (integer) — Column where function starts (0-indexed)
- `cyclomatic` (integer or null) — Cyclomatic complexity score
- `cognitive` (integer or null) — Cognitive complexity score
- `halstead_volume` (float) — Information content of the function in bits
- `halstead_difficulty` (float) — How error-prone and hard to write the function is
- `halstead_effort` (float) — Total mental effort required to implement or understand the function
- `halstead_bugs` (float) — Estimated number of bugs delivered (volume / 3000)
- `nesting_depth` (integer) — Maximum control flow nesting depth within the function
- `line_count` (integer) — Logical lines in the function body (excludes blank and comment-only lines)
- `params_count` (integer) — Number of parameters (runtime + generic type parameters)
- `health_score` (float) — Per-function composite health score (0–100); see [Health Score](health-score.md)
- `status` (string) — Function status: `"ok"`, `"warning"`, or `"error"`

### Using JSON Output

The JSON output is designed for programmatic consumption:

```sh
# Save to file
complexity-guard --format json --output report.json src/

# Pipe to jq for filtering
complexity-guard --format json src/ | jq '.summary'

# Extract error functions only
complexity-guard --format json src/ | jq '.files[].functions[] | select(.status == "error")'

# Get total error count
complexity-guard --format json src/ | jq '.summary.errors'
```

See [Examples](examples.md) for more JSON processing recipes.
