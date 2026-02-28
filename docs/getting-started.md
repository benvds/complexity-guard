# Getting Started

Welcome to ComplexityGuard! This guide will walk you through installation, running your first analysis, and customizing the tool for your project.

## Installation

ComplexityGuard is distributed as a single static binary with zero runtime dependencies. Choose the installation method that works best for you:

### npm (Global Install)

```sh
npm install -g complexity-guard
```

After installation, verify it works:

```sh
complexity-guard --version
```

### Direct Download

1. Visit the [GitHub Releases page](https://github.com/benvds/complexity-guard/releases)
2. Download the archive for your platform:
   - `complexity-guard-linux-x86_64-musl.tar.gz` — Linux x86_64
   - `complexity-guard-linux-aarch64-musl.tar.gz` — Linux ARM64
   - `complexity-guard-macos-x86_64.tar.gz` — macOS Intel
   - `complexity-guard-macos-aarch64.tar.gz` — macOS Apple Silicon
   - `complexity-guard-windows-x86_64.zip` — Windows x64
3. Extract and install (macOS/Linux):
   ```sh
   tar xzf complexity-guard-*.tar.gz
   chmod +x complexity-guard
   sudo mv complexity-guard /usr/local/bin/

   # Or install to your home bin directory
   mkdir -p ~/bin
   mv complexity-guard ~/bin/
   # Add ~/bin to PATH in your shell profile if needed
   ```
4. On Windows: extract the `.zip` and place `complexity-guard.exe` somewhere on your PATH.

### Building from Source

Requires [Rust](https://www.rust-lang.org/) (stable toolchain):

```sh
git clone https://github.com/benvds/complexity-guard.git
cd complexity-guard
cargo build --release
```

The binary will be at `target/release/complexity-guard`. Add it to your PATH or run it directly.

## Your First Analysis

ComplexityGuard works without any configuration. Just point it at a directory or files:

```sh
# Analyze all TypeScript/JavaScript files in src/
complexity-guard src/

# Analyze specific files
complexity-guard src/auth.ts src/utils.ts

# Analyze current directory
complexity-guard .
```

ComplexityGuard automatically finds all `.ts`, `.tsx`, `.js`, and `.jsx` files in the given paths and analyzes them in parallel across all available CPU cores by default. On multi-core machines this means large codebases run significantly faster than single-threaded analysis. Use `--threads 1` if you need single-threaded sequential output (useful for debugging or timing comparisons).

ComplexityGuard also applies automatic safety limits: files exceeding 10,000 lines and functions exceeding 5,000 lines are skipped and reported in the output. This prevents crashes or hangs on auto-generated code, minified bundles, or unusually large files. See [Size Limits](cli-reference.md#size-limits) for details.

## Understanding the Output

ComplexityGuard measures five families of metrics:

- **Cyclomatic complexity** — testability: how many paths need testing (McCabe, 1976)
- **Cognitive complexity** — readability: how hard the code is to understand (SonarSource, 2016)
- **Halstead metrics** — information theory: vocabulary density, volume, difficulty, and estimated bugs
- **Structural metrics** — shape: function length, parameter count, nesting depth, file length, export count
- **Duplication detection** — copy-paste detection: what percentage of tokens are cloned across files (opt-in, see [Duplication Detection](duplication-detection.md))

By default, the first four families run on every analysis. Duplication detection is opt-in — enable it with `--duplication` when you want to measure copy-paste debt. Use `--metrics cyclomatic,cognitive` to compute a subset of the standard metrics.

ComplexityGuard also computes a **[Health Score](health-score.md)** — a single 0–100 number that combines all active metric families into one signal. It appears at the bottom of each run and is useful for CI enforcement via `--fail-health-below`. When duplication is enabled, it contributes 20% to the composite score.

Cyclomatic and cognitive scores appear side by side on each function line. Halstead and structural violations appear as additional annotations when thresholds are exceeded. Run with `--verbose` to see all metric values for every function.

When you run ComplexityGuard, you'll see output like this:

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18
  89:2  ✗  error  Method 'handleComplexAuthFlow' cyclomatic 25 cognitive 32

Analyzed 12 files, 47 functions
Found 3 warnings, 1 errors
Health: 73

Top cyclomatic hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 25
  2. processPayment (src/checkout/payment.ts:156) complexity 18

Top cognitive hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 32
  2. processLoginFlow (src/auth/login.ts:67) complexity 18

✗ 4 problems (1 errors, 3 warnings)
```

### Reading the Results

Each line shows:
- **Line:Column** — Location of the function (e.g., `42:0`)
- **Indicator** — Visual status marker:
  - `✓` (green) = OK, both complexity scores below warning thresholds
  - `⚠` (yellow) = Warning, at least one score between warning and error threshold
  - `✗` (red) = Error, at least one score exceeds error threshold
- **Severity** — `ok`, `warning`, or `error`
- **Function Info** — Type and name (e.g., `Function 'validateCredentials'`)
- **Cyclomatic** — Cyclomatic complexity score (measures testability)
- **Cognitive** — Cognitive complexity score (measures readability)

By default, ComplexityGuard shows only files with warnings or errors. Functions that pass all thresholds are hidden to reduce noise.

### Default Thresholds

**Cyclomatic complexity:**
- **Warning**: 10 (McCabe's original recommendation)
- **Error**: 20 (ESLint default)

**Cognitive complexity:**
- **Warning**: 15 (SonarSource recommendation)
- **Error**: 25 (SonarSource recommendation)

**Halstead metrics:**
- **Volume**: warning 500, error 1000
- **Difficulty**: warning 10, error 20
- **Effort**: warning 5000, error 10000
- **Bugs (estimated)**: warning 0.5, error 1.0

**Structural metrics:**
- **Function length**: warning 25 lines, error 50 lines
- **Parameters**: warning 3, error 6
- **Nesting depth**: warning 3, error 5
- **File length**: warning 300 lines, error 600 lines
- **Exports per file**: warning 15, error 30

These thresholds are based on industry standards and can be customized (see Configuration below).

### Verbosity Modes

Control how much output you see:

```sh
# Default: show only problems
complexity-guard src/

# Verbose: show all functions, even those that pass
complexity-guard --verbose src/

# Quiet: show only errors, suppress warnings
complexity-guard --quiet src/
```

## Configuration

ComplexityGuard works great with zero configuration, but you can customize its behavior by creating a `.complexityguard.json` file in your project root.

### Creating a Config File

Create a `.complexityguard.json` file in your project root to customize behavior. The `--init` flag is reserved for future use (it currently prints a message and exits).

Here is an example config file:

```json
{
  "files": {
    "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "exclude": ["node_modules/**", "dist/**", "build/**"]
  },
  "analysis": {
    "thresholds": {
      "cyclomatic": {
        "warning": 10,
        "error": 20
      },
      "cognitive": {
        "warning": 15,
        "error": 25
      }
    }
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

### File Patterns

Control which files are analyzed using glob patterns:

```json
{
  "files": {
    "include": ["src/**/*.ts", "src/**/*.tsx"],
    "exclude": ["**/*.test.ts", "**/*.spec.ts", "**/__tests__/**"]
  }
}
```

**Include patterns** specify which files to analyze. If not specified, all TypeScript/JavaScript files are included.

**Exclude patterns** filter out files you don't want analyzed (tests, build output, dependencies, etc.).

### Threshold Customization

Adjust warning and error thresholds for any metric family to match your team's standards. Thresholds are nested under `analysis.thresholds`:

```json
{
  "analysis": {
    "thresholds": {
      "cyclomatic": {
        "warning": 5,
        "error": 10
      },
      "cognitive": {
        "warning": 8,
        "error": 15
      },
      "halstead_volume": {
        "warning": 400,
        "error": 800
      },
      "line_count": {
        "warning": 20,
        "error": 40
      },
      "nesting_depth": {
        "warning": 2,
        "error": 4
      }
    }
  }
}
```

**Strict mode** (lower thresholds) catches complexity issues early:
```json
{
  "analysis": {
    "thresholds": {
      "cyclomatic": { "warning": 5, "error": 10 },
      "cognitive": { "warning": 8, "error": 15 },
      "line_count": { "warning": 15, "error": 30 }
    }
  }
}
```

**Lenient mode** (higher thresholds) for legacy codebases:
```json
{
  "analysis": {
    "thresholds": {
      "cyclomatic": { "warning": 20, "error": 40 },
      "cognitive": { "warning": 25, "error": 50 },
      "line_count": { "warning": 50, "error": 100 }
    }
  }
}
```

### Counting Rules

ComplexityGuard follows ESLint-aligned counting rules. These rules are hardcoded and not configurable in the current version:

- `&&` and `||` operators count toward complexity
- `??` (nullish coalescing) counts toward complexity
- `?.` (optional chaining) counts toward complexity
- Switch statements: each case adds +1 (ESLint behavior)

This matches the ESLint `complexity` rule defaults. Counting rules will be configurable in a future release.

## HTML Reports

Generate a self-contained HTML report for sharing with stakeholders or reviewing in a browser:

```sh
complexity-guard --format html --output report.html src/
open report.html        # macOS
xdg-open report.html   # Linux
```

The report is fully self-contained (no external CSS/JS dependencies) and includes:
- **Project health dashboard** — overall score, summary metrics, and health status
- **File breakdown table** — sortable by any metric, with expandable function detail rows
- **Treemap visualization** — proportional view of function complexity across the codebase
- **Bar chart** — top complexity hotspots at a glance

Use `--output` when generating HTML — the report is large and piping to stdout is impractical.

## GitHub Code Scanning Integration

Use `--format sarif` to generate SARIF reports for GitHub Code Scanning. This gives you inline complexity annotations directly on pull request diffs:

```sh
complexity-guard --format sarif . > results.sarif
```

See [SARIF Output](sarif-output.md) for a complete GitHub Actions workflow that uploads results automatically on every PR.

## Tracking Health Over Time

Use the health score as a ratchet: set a baseline once, then enforce it in CI to prevent regression.

```sh
# Step 1: Check your current score
complexity-guard --format json src/ | jq '.summary.health_score'
# e.g. 73.2
```

Create a `.complexityguard.json` file and add the baseline field:

```json
{
  "baseline": 73.2
}
```

```sh
# Step 3: In CI — enforce the baseline (exits 1 if score drops below it)
complexity-guard src/

# Or override the threshold from the command line (no config change needed)
complexity-guard --fail-health-below 70 src/
```

See [Health Score](health-score.md) for the full baseline + ratchet workflow.

## Next Steps

Now that you have ComplexityGuard installed and understand the basics, explore:

- **[CLI Reference](cli-reference.md)** — Complete documentation of all flags, config options, and exit codes
- **[Examples](examples.md)** — Real-world usage patterns, CI integration, and configuration recipes
- **[SARIF Output](sarif-output.md)** — GitHub Code Scanning integration with inline PR annotations
- **[HTML Reports](examples.md#html-reports)** — Self-contained interactive reports with dashboard and visualizations
- **[Health Score](health-score.md)** — Composite 0–100 score, formula, weights, and baseline workflow
- **[Halstead Metrics](halstead-metrics.md)** — Formulas, thresholds, and what the information-theoretic numbers mean
- **[Structural Metrics](structural-metrics.md)** — Function length, parameters, nesting depth, and more
- **[Cyclomatic Complexity](cyclomatic-complexity.md)** — How path counting works and when it matters
- **[Cognitive Complexity](cognitive-complexity.md)** — How nesting penalties measure readability
- **[Duplication Detection](duplication-detection.md)** — Copy-paste detection using Rabin-Karp rolling hash (opt-in)
