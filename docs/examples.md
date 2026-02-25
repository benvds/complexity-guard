# Examples

> **Note:** All examples below work identically with the Rust binary (Phase 20 parallel pipeline complete). The Rust binary now supports directory analysis end-to-end. Output formats are the same.

Real-world usage patterns, CI integration recipes, and configuration examples for ComplexityGuard.

## Basic Usage

### Analyze a Directory

```sh
# Analyze all TypeScript/JavaScript files in src/
complexity-guard src/
```

Output shows only files with problems by default.

### Analyze Specific Files

```sh
# Analyze specific files
complexity-guard src/app.ts src/utils/helpers.ts lib/config.js
```

### Verbose Output

```sh
# Show all functions, including those that pass
complexity-guard --verbose src/
```

Verbose mode shows all functions including those that pass thresholds:

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2 [halstead vol 75] [length 8] [params 2] [depth 2]
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18 [halstead vol 843] [length 34] [params 3] [depth 4]
  89:2  ✗  error  Function 'handleComplexAuthFlow' cyclomatic 25 cognitive 32 [halstead vol 1244] [length 62] [params 4] [depth 6]
```

Useful for getting a complete complexity overview of your codebase.

### Selective Metric Families

Use `--metrics` to compute only specific metric families:

```sh
# Cyclomatic and Halstead only
complexity-guard --metrics cyclomatic,halstead src/

# All except Halstead (skip token counting for performance)
complexity-guard --metrics cyclomatic,cognitive,structural src/

# Structural metrics only (shape analysis)
complexity-guard --metrics structural src/
```

This is useful in CI pipelines where you want fast feedback on specific metrics, or when profiling large codebases where you want to skip Halstead token counting.

### Performance and Threading

ComplexityGuard analyzes files in parallel across all CPU cores by default. Use `--threads` to control parallelism:

```sh
# Use all available CPU cores (default — no flag needed)
complexity-guard src/

# Limit to 4 threads
complexity-guard --threads 4 src/

# Single-threaded (sequential) mode — disables thread pool entirely
complexity-guard --threads 1 src/

# See timing and thread count in verbose mode
complexity-guard --verbose src/
```

Verbose mode prints analysis time and thread count to stderr:

```
Analyzed 12 files in 43ms (8 threads)
```

You can also set a default thread count in `.complexityguard.json`:

```json
{
  "analysis": {
    "threads": 4
  }
}
```

The `--threads` CLI flag always overrides the config file value.

### Save Results to File

```sh
# Save console output to a file
complexity-guard src/ > report.txt

# Generate JSON report
complexity-guard --format json --output report.json src/
```

### JSON Output with All Metrics

JSON output includes all metric families. Here is a condensed example of a function with Halstead and structural fields populated:

```json
{
  "name": "processLoginFlow",
  "start_line": 67,
  "start_col": 0,
  "cyclomatic": 12,
  "cognitive": 18,
  "halstead_volume": 843.2,
  "halstead_difficulty": 14.1,
  "halstead_effort": 11884.3,
  "halstead_bugs": 0.281,
  "nesting_depth": 4,
  "line_count": 34,
  "params_count": 3,
  "status": "warning"
}
```

File-level structural metrics appear at the file level:

```json
{
  "path": "src/auth/login.ts",
  "file_length": 112,
  "export_count": 4,
  "functions": [...]
}
```

The top-level JSON object includes a `metadata` field with analysis timing and thread count:

```json
{
  "metadata": {
    "elapsed_ms": 43,
    "thread_count": 8
  }
}
```

Use this to track analysis performance across runs or verify which thread mode was used:

```sh
# Check elapsed time and thread count from JSON output
complexity-guard --format json src/ | jq '.metadata'
```

## Health Score

### Console Output with Health Score

Every analysis run prints a composite health score (0–100) after the summary line:

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18
  89:2  ✗  error  Function 'handleComplexAuthFlow' cyclomatic 25 cognitive 32

Analyzed 12 files, 47 functions
Health: 73
Found 3 warnings, 1 errors

Top cyclomatic hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 25
  2. processPayment (src/checkout/payment.ts:156) complexity 18

✗ 4 problems (1 errors, 3 warnings)
```

The health score is color-coded: green (>=80), yellow (50-79), red (<50).

### Health Score in JSON Output

The JSON output includes `health_score` at both the summary and per-function level:

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
  "files": [
    {
      "path": "src/auth/login.ts",
      "functions": [
        {
          "name": "validateCredentials",
          "cyclomatic": 3,
          "cognitive": 2,
          "health_score": 94.7,
          "status": "ok"
        },
        {
          "name": "handleComplexAuthFlow",
          "cyclomatic": 25,
          "cognitive": 32,
          "health_score": 8.3,
          "status": "error"
        }
      ]
    }
  ]
}
```

### jq Recipes for Health Score

```sh
# Get the overall project health score
complexity-guard --format json src/ | jq '.summary.health_score'

# Find functions with critical health scores
complexity-guard --format json src/ | jq '.files[].functions[] | select(.health_score < 50) | {name, health_score}'

# Find functions that need attention (yellow zone)
complexity-guard --format json src/ | jq '.files[].functions[] | select(.health_score >= 50 and .health_score < 80) | {name, health_score}'

# Sort functions by health score (worst first)
complexity-guard --format json src/ | jq '[.files[].functions[]] | sort_by(.health_score) | .[] | {name, health_score}'
```

### Baseline + Ratchet Workflow

Set a baseline once, then enforce it in CI to prevent regression:

```sh
# Step 1: Generate a default config file
complexity-guard --init

# Step 2: Check your current score
complexity-guard --format json src/ | jq '.summary.health_score'
# e.g. 73.2
```

Edit `.complexityguard.json` to add the baseline field:

```json
{
  "baseline": 73.2
}
```

```sh
# Step 3: Enforce in CI (uses baseline from .complexityguard.json)
complexity-guard src/

# Or enforce a specific threshold from the command line (no config change needed)
complexity-guard --fail-health-below 70 src/
```

When the score drops below the threshold, ComplexityGuard exits 1:

```
Health score 68.4 is below threshold 70.0 — exiting with error
```

To raise the baseline after improving your codebase, update the `baseline` value in `.complexityguard.json` directly.

See [Health Score](health-score.md) for the complete formula, weight customization, and ratchet workflow guide.

## SARIF Output

Generate SARIF 2.1.0 output for GitHub Code Scanning integration. Violations appear as inline annotations on pull request diffs.

### Basic SARIF Generation

```sh
# Generate SARIF output and redirect to file
complexity-guard --format sarif . > results.sarif

# Use --output flag instead of redirect
complexity-guard --format sarif --output results.sarif .
```

### Filtered SARIF (Phased Rollout)

Use `--metrics` to limit which metric families produce SARIF results. Useful for introducing compliance incrementally:

```sh
# Start with just cyclomatic complexity
complexity-guard --format sarif --metrics cyclomatic . > results.sarif

# Add cognitive complexity
complexity-guard --format sarif --metrics cyclomatic,cognitive . > results.sarif
```

### Inspect SARIF with jq

```sh
# Count total results
complexity-guard --format sarif . | jq '.runs[0].results | length'

# List all triggered rule IDs
complexity-guard --format sarif . | jq '[.runs[0].results[].ruleId] | unique'

# Count warnings vs errors
complexity-guard --format sarif . | jq '.runs[0].results | group_by(.level) | map({level: .[0].level, count: length})'
```

See [SARIF Output](sarif-output.md) for a complete GitHub Actions workflow and full rule reference.

## HTML Reports

Generate a self-contained HTML report for sharing with stakeholders or reviewing in a browser. The report includes an interactive project health dashboard, sortable file breakdown table, treemap visualization, and a bar chart of top hotspots.

### Basic HTML Report

```sh
complexity-guard --format html --output report.html src/
```

Open in your browser:

```sh
open report.html       # macOS
xdg-open report.html   # Linux
start report.html      # Windows
```

### HTML Report with Custom Thresholds

```sh
complexity-guard --format html --output report.html --error 25 src/
```

### HTML Report in CI (Artifact Upload)

```yaml
      - name: Generate HTML complexity report
        run: |
          complexity-guard --format html --output complexity-report.html src/ || true

      - name: Upload HTML report
        uses: actions/upload-artifact@v3
        with:
          name: complexity-report
          path: complexity-report.html
```

The `|| true` ensures the step doesn't fail immediately, allowing the artifact to be uploaded even when violations are found. Team members can then download the report from the GitHub Actions run and open it locally.

### What the HTML Report Contains

- **Project health dashboard** — overall health score (0–100), total files/functions, warning/error counts
- **Interactive file table** — sortable by complexity, health score, function count; click any row to expand and see per-function metrics
- **Metric bars** — visual bar representations of cyclomatic, cognitive, and health score per function
- **Treemap visualization** — proportional view showing which files dominate complexity
- **Bar chart** — top hotspot functions ranked by cyclomatic complexity

The report is fully self-contained — all CSS and JavaScript is inlined. No server or internet connection needed to view it.

## CI Integration

### GitHub Actions

Add ComplexityGuard to your CI pipeline to catch complexity regressions:

```yaml
name: Code Quality

on:
  pull_request:
  push:
    branches: [main]

jobs:
  complexity:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install ComplexityGuard
        run: |
          curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x64 -o complexity-guard
          chmod +x complexity-guard
          sudo mv complexity-guard /usr/local/bin/

      - name: Run complexity analysis
        run: complexity-guard --fail-on warning src/
```

This workflow:
1. Checks out your code
2. Downloads and installs ComplexityGuard
3. Runs analysis, failing the build if warnings or errors are found

### Fail Only on Errors

For legacy codebases, start by failing only on errors:

```yaml
      - name: Run complexity analysis
        run: complexity-guard --fail-on error src/
```

Once complexity is under control, tighten to `--fail-on warning`.

### JSON Output for Artifact Upload

Save JSON results as a CI artifact for later review:

```yaml
      - name: Run complexity analysis
        run: |
          complexity-guard --format json --output complexity-report.json src/ || true

      - name: Upload complexity report
        uses: actions/upload-artifact@v3
        with:
          name: complexity-report
          path: complexity-report.json
```

The `|| true` ensures the step doesn't fail immediately, allowing the artifact to be uploaded even when violations are found.

### Comment PR with Results

Use the JSON output to post a comment on pull requests:

```yaml
      - name: Analyze complexity
        id: complexity
        run: |
          complexity-guard --format json src/ > report.json || true
          echo "errors=$(jq '.summary.errors' report.json)" >> $GITHUB_OUTPUT
          echo "warnings=$(jq '.summary.warnings' report.json)" >> $GITHUB_OUTPUT

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const errors = ${{ steps.complexity.outputs.errors }};
            const warnings = ${{ steps.complexity.outputs.warnings }};
            const message = `## Complexity Analysis\n\n- **Errors:** ${errors}\n- **Warnings:** ${warnings}`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: message
            });
```

### Other CI Platforms

**GitLab CI:**

```yaml
complexity:
  stage: test
  script:
    - curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x64 -o complexity-guard
    - chmod +x complexity-guard
    - ./complexity-guard --fail-on warning src/
```

**CircleCI:**

```yaml
version: 2.1

jobs:
  complexity:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - run:
          name: Install ComplexityGuard
          command: |
            curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x64 -o complexity-guard
            chmod +x complexity-guard
            sudo mv complexity-guard /usr/local/bin/
      - run:
          name: Run complexity analysis
          command: complexity-guard --fail-on warning src/
```

**Jenkins:**

```groovy
pipeline {
  agent any
  stages {
    stage('Complexity Analysis') {
      steps {
        sh 'curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x64 -o complexity-guard'
        sh 'chmod +x complexity-guard'
        sh './complexity-guard --fail-on warning src/'
      }
    }
  }
}
```

## Working with Halstead Metrics

### Identifying High-Density Functions

Halstead volume captures information density. A function triggering a volume warning has a lot going on mentally, even if it has low cyclomatic complexity:

```
src/parsers/expression.ts
  156:0  ⚠  warning  Function 'parseExpression' cyclomatic 8 cognitive 12 [halstead vol 743] [length 28] [params 2] [depth 3]
```

This function has manageable cyclomatic and cognitive scores but high Halstead effort (16643 > 10000 threshold), flagging it as mentally expensive to understand or modify. This often happens with expression parsers, mathematical algorithms, or functions operating on many distinct values.

### Filtering Halstead Results with jq

```sh
# Find functions with high Halstead effort
complexity-guard --format json src/ | jq '.files[].functions[] | select(.halstead_effort > 5000) | {name, effort: .halstead_effort}'

# Find functions with high estimated bug count
complexity-guard --format json src/ | jq '.files[].functions[] | select(.halstead_bugs > 0.5) | {name, bugs: .halstead_bugs}'

# Sort all functions by Halstead volume
complexity-guard --format json src/ | jq '[.files[].functions[]] | sort_by(.halstead_volume) | reverse | .[0:10] | .[] | {name, volume: .halstead_volume}'
```

## Configuration Recipes

### Strict Mode (Catch Complexity Early)

For new projects or teams committed to low complexity:

```json
{
  "thresholds": {
    "cyclomatic": {
      "warning": 5,
      "error": 10
    },
    "cognitive": {
      "warning": 8,
      "error": 15
    }
  }
}
```

This aggressive threshold catches complexity early, encouraging small, focused functions.

### Lenient Mode (Legacy Codebases)

For existing codebases with high complexity:

```json
{
  "thresholds": {
    "cyclomatic": {
      "warning": 20,
      "error": 40
    },
    "cognitive": {
      "warning": 25,
      "error": 50
    }
  }
}
```

Start with higher thresholds to avoid overwhelming developers, then gradually lower them over time.

### Exclude Test Files

Tests often have higher complexity by nature (many assertions, setup/teardown). Exclude them:

```json
{
  "files": {
    "exclude": [
      "**/*.test.ts",
      "**/*.spec.ts",
      "**/__tests__/**",
      "**/__mocks__/**",
      "test/**",
      "tests/**"
    ]
  }
}
```

### TypeScript Only (Exclude JavaScript)

For TypeScript projects that still have some legacy JavaScript:

```json
{
  "files": {
    "include": ["**/*.ts", "**/*.tsx"],
    "exclude": ["**/*.js", "**/*.jsx"]
  }
}
```

Or to analyze only specific directories:

```json
{
  "files": {
    "include": ["src/**/*.ts", "src/**/*.tsx"]
  }
}
```

### Monorepo Configuration

For monorepos, create a root config and override per-package:

**Root `.complexityguard.json`:**
```json
{
  "files": {
    "exclude": ["node_modules/**", "**/dist/**", "**/build/**"]
  },
  "thresholds": {
    "cyclomatic": {
      "warning": 10,
      "error": 20
    }
  }
}
```

**Package-specific `packages/api/.complexityguard.json`:**
```json
{
  "files": {
    "include": ["src/**/*.ts"],
    "exclude": ["src/**/*.test.ts"]
  },
  "thresholds": {
    "cyclomatic": {
      "warning": 8,
      "error": 15
    }
  }
}
```

Run with package-specific config:

```sh
cd packages/api
complexity-guard src/
```

### Structural Metrics Configuration

Tighten structural thresholds for clean architecture enforcement:

```json
{
  "thresholds": {
    "function_length": {
      "warning": 20,
      "error": 40
    },
    "params": {
      "warning": 3,
      "error": 5
    },
    "nesting": {
      "warning": 2,
      "error": 4
    },
    "file_length": {
      "warning": 200,
      "error": 400
    }
  }
}
```

Filtering structural results from JSON:

```sh
# Find long functions
complexity-guard --format json src/ | jq '.files[].functions[] | select(.line_count > 30) | {name, line_count}'

# Find deeply nested functions
complexity-guard --format json src/ | jq '.files[].functions[] | select(.nesting_depth > 4) | {name, nesting_depth}'

# Find functions with too many parameters
complexity-guard --format json src/ | jq '.files[].functions[] | select(.params_count > 5) | {name, params_count}'

# Files exceeding length threshold
complexity-guard --format json src/ | jq '.files[] | select(.file_length > 300) | {path, file_length}'
```

### Classic McCabe Counting

For teams that prefer classic McCabe (no modern JavaScript features counted):

```json
{
  "counting_rules": {
    "logical_operators": false,
    "nullish_coalescing": false,
    "optional_chaining": false,
    "switch_case_mode": "switchOnly"
  }
}
```

### ESLint-Aligned Counting (Default)

To explicitly match ESLint's complexity rule:

```json
{
  "counting_rules": {
    "logical_operators": true,
    "nullish_coalescing": true,
    "optional_chaining": true,
    "switch_case_mode": "perCase"
  }
}
```

This is the default, but you can make it explicit in your config.

## Working with JSON Output

### Extract Summary Statistics

```sh
# Get overall status
complexity-guard --format json src/ | jq -r '.summary.status'

# Get error count
complexity-guard --format json src/ | jq '.summary.errors'

# Get warning count
complexity-guard --format json src/ | jq '.summary.warnings'
```

### Find High-Complexity Functions

```sh
# Functions with high cyclomatic complexity
complexity-guard --format json src/ | jq '.files[].functions[] | select(.cyclomatic > 20)'

# Functions with high cognitive complexity
complexity-guard --format json src/ | jq '.files[].functions[] | select(.cognitive > 15)'

# Get top 10 most complex functions (cyclomatic)
complexity-guard --format json src/ | jq '.files[].functions[] | {name, file: .start_line, complexity: .cyclomatic} | sort_by(.complexity) | reverse | .[0:10]'
```

### Filter by Status

```sh
# Only error-level functions
complexity-guard --format json src/ | jq '.files[].functions[] | select(.status == "error")'

# Only warning-level functions
complexity-guard --format json src/ | jq '.files[].functions[] | select(.status == "warning")'
```

### Comparing Metrics

```sh
# Find functions where cognitive is much higher than cyclomatic (deeply nested code)
complexity-guard --format json src/ | jq '.files[].functions[] | select(.cognitive > .cyclomatic * 2) | {name, cyclomatic, cognitive}'

# Find functions where cyclomatic is high but cognitive is low (many flat branches)
complexity-guard --format json src/ | jq '.files[].functions[] | select(.cyclomatic > 10 and .cognitive < 10) | {name, cyclomatic, cognitive}'
```

### Per-File Analysis

```sh
# Files with any errors
complexity-guard --format json src/ | jq '.files[] | select(.functions[].status == "error") | .path'

# File with most functions
complexity-guard --format json src/ | jq '.files | max_by(.functions | length) | {path, function_count: (.functions | length)}'
```

### Generate CSV Report

```sh
# Convert to CSV
complexity-guard --format json src/ | jq -r '
  ["file", "function", "line", "complexity", "status"],
  (.files[] | .path as $file | .functions[] | [$file, .name, .start_line, .cyclomatic, .status])
  | @csv
' > complexity.csv
```

### Compare Against Baseline

Save a baseline report, then compare:

```sh
# Save baseline
complexity-guard --format json src/ > baseline.json

# Later, compare
complexity-guard --format json src/ > current.json

# Find functions that got worse
jq -s '
  .[0].files[].functions[] as $baseline |
  .[1].files[].functions[] as $current |
  select($baseline.name == $current.name and $current.cyclomatic > $baseline.cyclomatic) |
  {name: $current.name, old: $baseline.cyclomatic, new: $current.cyclomatic}
' baseline.json current.json
```

### Integration with Custom Scripts

Use ComplexityGuard JSON output in custom Node.js scripts:

```javascript
const { execSync } = require('child_process');

// Run analysis and capture JSON
const output = execSync('complexity-guard --format json src/', { encoding: 'utf-8' });
const results = JSON.parse(output);

// Custom logic
const highComplexity = results.files
  .flatMap(file => file.functions)
  .filter(fn => fn.cyclomatic > 15)
  .sort((a, b) => b.cyclomatic - a.cyclomatic);

console.log(`Found ${highComplexity.length} functions with complexity > 15`);

// Fail if too many high-complexity functions
if (highComplexity.length > 10) {
  console.error('Too many high-complexity functions! Refactoring needed.');
  process.exit(1);
}
```

## Shell Integration

### Pre-commit Hook

Add ComplexityGuard to Git pre-commit hooks to catch complexity before commits:

```sh
#!/bin/sh
# .git/hooks/pre-commit

# Get list of staged TypeScript/JavaScript files
FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx|js|jsx)$')

if [ -n "$FILES" ]; then
  echo "Running complexity analysis on staged files..."
  echo "$FILES" | xargs complexity-guard --fail-on error

  if [ $? -ne 0 ]; then
    echo "Complexity check failed! Fix errors or commit with --no-verify to skip."
    exit 1
  fi
fi
```

Make it executable:

```sh
chmod +x .git/hooks/pre-commit
```

### NPM Script

Add to `package.json`:

```json
{
  "scripts": {
    "complexity": "complexity-guard src/",
    "complexity:verbose": "complexity-guard --verbose src/",
    "complexity:json": "complexity-guard --format json --output complexity-report.json src/",
    "complexity:ci": "complexity-guard --fail-on warning --no-color src/"
  }
}
```

Run with npm:

```sh
npm run complexity
npm run complexity:ci
```

### Make Target

Add to `Makefile`:

```makefile
.PHONY: complexity complexity-strict complexity-report

complexity:
	complexity-guard src/

complexity-strict:
	complexity-guard --fail-on warning src/

complexity-report:
	complexity-guard --format json --output report.json src/
	@echo "Report saved to report.json"
```

Run with make:

```sh
make complexity
make complexity-strict
```

## Duplication Detection

### Basic Duplication Analysis

Enable duplication detection with the `--duplication` flag:

```sh
complexity-guard --duplication src/
```

Output includes a project-level duplication summary:

```
Analyzed 12 files, 47 functions
Health: 68
Found 3 warnings, 1 errors
Duplication: 8.2%

✗ 4 problems (1 errors, 3 warnings)
```

### Combine with Other Flags

Duplication works with all standard flags:

```sh
# Duplication with verbose output
complexity-guard --duplication --verbose src/

# Duplication only, skip other metrics
complexity-guard --metrics duplication src/

# Duplication with strict failure mode
complexity-guard --duplication --fail-on warning src/
```

### Custom Duplication Thresholds

Configure duplication thresholds in `.complexityguard.json`:

```json
{
  "analysis": {
    "duplication_enabled": true
  },
  "thresholds": {
    "duplication": {
      "file_warning": 10.0,
      "file_error": 20.0,
      "project_warning": 3.0,
      "project_error": 8.0
    }
  }
}
```

Then run without the `--duplication` flag (the config enables it):

```sh
complexity-guard src/
```

### JSON Output with Duplication Data

Use `--format json` to get structured duplication data:

```sh
complexity-guard --duplication --format json src/
```

The JSON output includes per-file and project-level duplication fields:

```json
{
  "summary": {
    "files_analyzed": 12,
    "health_score": 68.4,
    "duplication": {
      "project_duplication_pct": 8.2,
      "clone_groups": 4,
      "project_warning": false,
      "project_error": true
    }
  },
  "files": [
    {
      "path": "src/utils/helpers.ts",
      "duplication_pct": 22.1,
      "duplication_warning": true,
      "duplication_error": false
    }
  ]
}
```

Use `jq` to extract duplication data:

```sh
# Get project-level duplication percentage
complexity-guard --duplication --format json src/ | jq '.summary.duplication.project_duplication_pct'

# Find files with duplication errors
complexity-guard --duplication --format json src/ | jq '.files[] | select(.duplication_error == true) | {path, duplication_pct}'

# Find files above a custom duplication threshold
complexity-guard --duplication --format json src/ | jq '.files[] | select((.duplication_pct // 0) > 15) | {path, duplication_pct}'

# Get all duplication warnings
complexity-guard --duplication --format json src/ | jq '.files[] | select(.duplication_warning == true) | .path'
```

### CI Integration with Duplication

Add duplication enforcement to your CI pipeline:

```yaml
      - name: Run complexity analysis with duplication detection
        run: complexity-guard --duplication --fail-on warning src/
```

Or use a config file to enable duplication with custom thresholds, keeping CI commands clean:

```yaml
      - name: Run complexity analysis
        run: complexity-guard src/  # duplication_enabled: true in .complexityguard.json
```

See [Duplication Detection](duplication-detection.md) for algorithm details, clone type descriptions, and the full configuration reference.

## Next Steps

- Review the [CLI Reference](cli-reference.md) for complete flag documentation
- Check out the [Getting Started](getting-started.md) guide for configuration details
- See [Duplication Detection](duplication-detection.md) for copy-paste detection details
- Star the project on [GitHub](https://github.com/benvds/complexity-guard) if you find it useful!
