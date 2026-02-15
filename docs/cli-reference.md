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

Generate a default `.complexityguard.json` configuration file in the current directory.

```sh
complexity-guard --init
```

This creates a config file with sensible defaults that you can customize.

### Output

**`-f, --format <FORMAT>`**

Set output format. Available formats:
- `console` (default) — Human-readable terminal output with colors
- `json` — Machine-readable JSON for CI/tooling integration

```sh
# Console output (default)
complexity-guard src/

# JSON output
complexity-guard --format json src/

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

Comma-separated list of metrics to enable. Currently only `cyclomatic` is supported.

```sh
complexity-guard --metrics cyclomatic src/
```

This flag exists for future extensibility when additional metrics are added.

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

Exit non-zero if overall health score falls below the specified value (reserved for future use when composite health scoring is implemented).

```sh
complexity-guard --fail-health-below 70 src/
```

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
    }
  },
  "counting_rules": {
    "logical_operators": true,
    "nullish_coalescing": true,
    "optional_chaining": true,
    "switch_case_mode": "perCase"
  },
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

Default output format: `"console"` or `"json"`. Default: `"console"`.

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
| 1 | Errors Found | One or more functions exceeded error threshold |
| 2 | Warnings Found | One or more functions exceeded warning threshold (only when `--fail-on warning`) |
| 3 | Config Error | Configuration file is invalid or could not be loaded |
| 4 | Parse Error | One or more files failed to parse |

### Exit Code Priority

When multiple conditions are present, the highest priority exit code is used:

1. **Parse Error (4)** — Takes precedence over everything
2. **Errors Found (1)** — Takes precedence over warnings and success
3. **Warnings Found (2)** — Only when `--fail-on warning` is set
4. **Success (0)** — Default when no issues found

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
    "status": "error"
  },
  "files": [
    {
      "path": "src/auth/login.ts",
      "functions": [
        {
          "name": "validateCredentials",
          "start_line": 42,
          "end_line": 0,
          "start_col": 0,
          "cyclomatic": 3,
          "cognitive": null,
          "halstead_volume": null,
          "halstead_difficulty": null,
          "halstead_effort": null,
          "nesting_depth": 0,
          "line_count": 0,
          "params_count": 0,
          "health_score": null,
          "status": "ok"
        },
        {
          "name": "handleComplexAuthFlow",
          "start_line": 89,
          "end_line": 0,
          "start_col": 2,
          "cyclomatic": 25,
          "cognitive": null,
          "halstead_volume": null,
          "halstead_difficulty": null,
          "halstead_effort": null,
          "nesting_depth": 0,
          "line_count": 0,
          "params_count": 0,
          "health_score": null,
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
- `status` (string) — Overall status: `"pass"`, `"warning"`, or `"error"`

**File:**
- `path` (string) — Relative path to the file
- `functions` (array) — Functions found in this file

**Function:**
- `name` (string) — Function name
- `start_line` (integer) — Line number where function starts (1-indexed)
- `end_line` (integer) — Reserved for future use (currently 0)
- `start_col` (integer) — Column where function starts (0-indexed)
- `cyclomatic` (integer or null) — Cyclomatic complexity score
- `cognitive` (integer or null) — Reserved for future use (currently null)
- `halstead_volume` (float or null) — Reserved for future use (currently null)
- `halstead_difficulty` (float or null) — Reserved for future use (currently null)
- `halstead_effort` (float or null) — Reserved for future use (currently null)
- `nesting_depth` (integer) — Reserved for future use (currently 0)
- `line_count` (integer) — Reserved for future use (currently 0)
- `params_count` (integer) — Reserved for future use (currently 0)
- `health_score` (float or null) — Reserved for future use (currently null)
- `status` (string) — Function status: `"ok"`, `"warning"`, or `"error"`

Fields marked as null or 0 are placeholders for metrics that will be computed in future versions.

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
