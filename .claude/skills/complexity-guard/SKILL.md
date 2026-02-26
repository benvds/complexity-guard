---
name: complexity-guard
description: "Analyzes TypeScript/JavaScript code complexity. Use when the user needs to check code quality, measure cyclomatic/cognitive/halstead/structural complexity, detect duplication, generate health scores, or enforce complexity thresholds in CI."
---

# ComplexityGuard CLI Reference

ComplexityGuard analyzes TypeScript/JavaScript complexity.

## Quick Start

```sh
complexity-guard src/                        # analyze directory
complexity-guard --init src/                 # generate .complexityguard.json config
complexity-guard --format json src/          # machine-readable JSON output
complexity-guard --fail-health-below 70 src/ # CI health score enforcement
complexity-guard --verbose src/              # show all functions, not just problems
complexity-guard --duplication src/          # add duplication detection
```

## Usage

```
complexity-guard [OPTIONS] [PATH]...
```

Analyzes all `.ts`, `.tsx`, `.js`, `.jsx` files in specified paths (recursive). Default: current directory `.`.

## Flags

### General

| Flag | Description |
|------|-------------|
| `-h, --help` | Show help message |
| `--version` | Show version |
| `--init` | Generate `.complexityguard.json` with all options and defaults |

### Output

| Flag | Description |
|------|-------------|
| `-f, --format <FORMAT>` | Output format: `console` (default), `json`, `sarif`, `html` |
| `-o, --output <FILE>` | Write output to file (in addition to stdout) |
| `--color` | Force color even when stdout is not a TTY |
| `--no-color` | Disable color even when stdout is a TTY |
| `-v, --verbose` | Show all functions including those that pass |
| `-q, --quiet` | Show only error-level violations |

### Analysis

| Flag | Description |
|------|-------------|
| `--metrics <LIST>` | Comma-separated metric families to compute: `cyclomatic,cognitive,halstead,structural,duplication` |
| `--duplication` | Enable cross-file Rabin-Karp clone detection (opt-in, slower) |
| `--no-duplication` | Explicitly disable duplication |
| `--threads <N>` | Parallel thread count (default: all CPU cores); `--threads 1` for sequential |
| `--baseline <FILE>` | Compare against baseline report (reserved) |

### File Filtering

| Flag | Description |
|------|-------------|
| `--include <GLOB>` | Include files matching glob (repeatable) |
| `--exclude <GLOB>` | Exclude files matching glob (repeatable) |

### Thresholds

| Flag | Description |
|------|-------------|
| `--fail-on <LEVEL>` | Exit non-zero on: `error` (default), `warning`, `never` |
| `--fail-health-below <N>` | Exit 1 if health score < N; overrides config `baseline` field |

### Configuration

| Flag | Description |
|------|-------------|
| `-c, --config <FILE>` | Use specific config file (default: auto-discover `.complexityguard.json`) |

## Output Formats

**console** (default): Human-readable with colors. Shows only files with problems unless `--verbose`.

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18 [halstead vol 843] [length 34] [params 3] [depth 4]
  89:2  ✗  error  Function 'handleComplexAuthFlow' cyclomatic 25 cognitive 32 [halstead vol 1244] [length 62] [params 4] [depth 6]

Analyzed 12 files, 47 functions
Health: 73
Found 3 warnings, 1 errors
```

**json**: Machine-readable. Pipe to `jq`. Includes all metric values per function.

**sarif**: SARIF 2.1.0 for GitHub Code Scanning — inline PR annotations.

**html**: Self-contained report with health dashboard, treemap, bar chart (use `--output` — large).

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | Errors found, or health score below `--fail-health-below` / `baseline` |
| 2 | Warnings found (only when `--fail-on warning`) |
| 3 | Config file invalid or not loadable |
| 4 | Parse error on one or more files |

## Configuration File

`.complexityguard.json` — generate with `complexity-guard --init`. Searched in CWD, parent dirs, `~/.config/complexity-guard/config.json`.

### Full Schema

```json
{
  "files": {
    "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "exclude": ["node_modules/**", "dist/**", "build/**", "**/*.test.ts"]
  },
  "thresholds": {
    "cyclomatic":          { "warning": 10,    "error": 20    },
    "cognitive":           { "warning": 15,    "error": 25    },
    "halstead_volume":     { "warning": 500,   "error": 1000  },
    "halstead_difficulty": { "warning": 10,    "error": 20    },
    "halstead_effort":     { "warning": 5000,  "error": 10000 },
    "halstead_bugs":       { "warning": 0.5,   "error": 2.0   },
    "function_length":     { "warning": 25,    "error": 50    },
    "params":              { "warning": 3,     "error": 6     },
    "nesting":             { "warning": 3,     "error": 5     },
    "file_length":         { "warning": 300,   "error": 600   },
    "exports":             { "warning": 15,    "error": 30    },
    "duplication": {
      "file_warning": 15.0, "file_error": 25.0,
      "project_warning": 5.0, "project_error": 10.0
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
  "analysis": {
    "threads": 4,
    "duplication_enabled": false
  },
  "output": {
    "format": "console"
  }
}
```

### Key Config Fields

- **`files.include/exclude`**: Glob patterns (exclude applied after include)
- **`thresholds.*`**: 12 threshold categories with warning/error levels
- **`counting_rules`**: Controls what contributes to cyclomatic complexity
  - `switch_case_mode`: `"perCase"` (ESLint default) or `"switchOnly"` (classic McCabe)
- **`weights`**: Health score weights (normalized to 1.0; set to 0.0 to exclude from score)
- **`baseline`**: CI enforcement — exits 1 if health score drops below this
- **`analysis.threads`**: Override CPU core auto-detection (CLI `--threads` takes precedence)
- **`analysis.duplication_enabled`**: Enable duplication without CLI flag

## Metric Families

**cyclomatic**: McCabe path counting. Counts decision branches (if, else, for, while, switch case, &&, ||, ??, ?.). Measures testability — how many paths need testing.

**cognitive**: SonarSource nesting-aware metric. Adds penalty for nesting depth. Measures readability — how hard code is to understand. Defaults: warning 15, error 25.

**halstead**: Information-theoretic metrics from operator/operand vocabulary.
- `volume`: Information content in bits
- `difficulty`: Error-proneness score
- `effort`: Mental effort to understand/implement
- `bugs`: Estimated bug count (volume / 3000)

**structural**: Shape metrics at function and file level.
- `function_length`: Logical lines in function body
- `params`: Parameter count (runtime + type parameters)
- `nesting`: Maximum control flow nesting depth
- `file_length`: Logical lines in file
- `exports`: Export statement count

**duplication**: Rabin-Karp rolling hash cross-file clone detection. Detects Type 1 (exact) and Type 2 (renamed variable) clones. Opt-in — adds extra analysis pass.

## Health Score

Composite 0–100 score combining all active metric families. Printed after every run. Weights default: cognitive 30%, cyclomatic 20%, halstead 15%, structural 15% (duplication adds 20% when enabled).

Enforce in CI:
```sh
complexity-guard --fail-health-below 70 src/
# or set "baseline": 70.0 in .complexityguard.json
```

## Common jq Recipes

```sh
# Get project health score
complexity-guard --format json src/ | jq '.summary.health_score'

# Find all error-level functions
complexity-guard --format json src/ | jq '.files[].functions[] | select(.status == "error")'

# Sort functions by cyclomatic complexity (worst first)
complexity-guard --format json src/ | jq '[.files[].functions[]] | sort_by(.cyclomatic) | reverse | .[0:5]'

# Find functions with high Halstead effort
complexity-guard --format json src/ | jq '.files[].functions[] | select(.halstead_effort > 5000) | {name, effort: .halstead_effort}'

# Get project duplication percentage (when --duplication enabled)
complexity-guard --duplication --format json src/ | jq '.summary.duplication.project_duplication_pct'

# Find files with duplication errors
complexity-guard --duplication --format json src/ | jq '.files[] | select(.duplication_error == true) | {path, duplication_pct}'

# Extract summary statistics
complexity-guard --format json src/ | jq '{health: .summary.health_score, errors: .summary.errors, warnings: .summary.warnings}'
```

## JSON Output Schema (Key Fields)

```json
{
  "summary": {
    "files_analyzed": 12,
    "total_functions": 47,
    "warnings": 3,
    "errors": 1,
    "health_score": 73.2,
    "status": "error"
  },
  "files": [{
    "path": "src/auth/login.ts",
    "file_length": 112,
    "export_count": 4,
    "functions": [{
      "name": "handleComplexAuthFlow",
      "start_line": 89,
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
    }]
  }]
}
```

## CI Integration

### GitHub Actions

```yaml
- name: Install ComplexityGuard
  run: |
    curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x86_64-musl.tar.gz -o cg.tar.gz
    tar xzf cg.tar.gz && chmod +x complexity-guard
    sudo mv complexity-guard /usr/local/bin/

- name: Run complexity analysis
  run: complexity-guard --fail-on warning src/
```

### Baseline Ratchet

```sh
# 1. Get current score
complexity-guard --format json src/ | jq '.summary.health_score'

# 2. Set in .complexityguard.json
# "baseline": 73.2

# 3. CI enforces it automatically
complexity-guard src/
```

## Installation

```sh
# npm
npm install -g complexity-guard
```
