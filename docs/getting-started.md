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

1. Visit the [GitHub releases page](https://github.com/benvds/complexity-guard/releases)
2. Download the binary for your platform:
   - `complexity-guard-linux-x64` for Linux
   - `complexity-guard-macos-arm64` for macOS (Apple Silicon)
   - `complexity-guard-macos-x64` for macOS (Intel)
   - `complexity-guard-windows-x64.exe` for Windows
3. Make the binary executable (macOS/Linux):
   ```sh
   chmod +x complexity-guard
   ```
4. Move it to a directory in your PATH:
   ```sh
   # macOS/Linux
   sudo mv complexity-guard /usr/local/bin/

   # Or add to your home bin directory
   mkdir -p ~/bin
   mv complexity-guard ~/bin/
   # Add ~/bin to PATH in your shell profile if needed
   ```

### Building from Source

If you have Zig installed (0.14.0 or later), you can build from source:

```sh
git clone https://github.com/benvds/complexity-guard.git
cd complexity-guard
zig build
```

The binary will be at `zig-out/bin/complexity-guard`. You can run it directly or add it to your PATH.

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

ComplexityGuard automatically finds all `.ts`, `.tsx`, `.js`, and `.jsx` files in the given paths.

## Understanding the Output

ComplexityGuard measures four families of metrics:

- **Cyclomatic complexity** — testability: how many paths need testing (McCabe, 1976)
- **Cognitive complexity** — readability: how hard the code is to understand (SonarSource, 2016)
- **Halstead metrics** — information theory: vocabulary density, volume, difficulty, and estimated bugs
- **Structural metrics** — shape: function length, parameter count, nesting depth, file length, export count

By default, all four families run on every analysis. Use `--metrics cyclomatic,cognitive` to compute a subset.

ComplexityGuard also computes a **[Health Score](health-score.md)** — a single 0–100 number that combines all four metric families into one signal. It appears at the bottom of each run and is useful for CI enforcement via `--fail-health-below`.

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
- **Bugs (estimated)**: warning 0.5, error 2.0

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

Use the `--init` command to generate a default configuration file:

```sh
complexity-guard --init
```

This creates a `.complexityguard.json` file with standard thresholds, default metric weights, and common exclude patterns. You can then adjust the values to suit your project.

This creates a `.complexityguard.json` file:

```json
{
  "files": {
    "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
    "exclude": ["node_modules/**", "dist/**", "build/**"]
  },
  "thresholds": {
    "cyclomatic": {
      "warning": 10,
      "error": 20
    },
    "cognitive": {
      "warning": 15,
      "error": 25
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

Adjust warning and error thresholds for any metric family to match your team's standards:

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
    },
    "halstead_volume": {
      "warning": 400,
      "error": 800
    },
    "function_length": {
      "warning": 20,
      "error": 40
    },
    "nesting": {
      "warning": 2,
      "error": 4
    }
  }
}
```

**Strict mode** (lower thresholds) catches complexity issues early:
```json
{
  "thresholds": {
    "cyclomatic": { "warning": 5, "error": 10 },
    "cognitive": { "warning": 8, "error": 15 },
    "function_length": { "warning": 15, "error": 30 }
  }
}
```

**Lenient mode** (higher thresholds) for legacy codebases:
```json
{
  "thresholds": {
    "cyclomatic": { "warning": 20, "error": 40 },
    "cognitive": { "warning": 25, "error": 50 },
    "function_length": { "warning": 50, "error": 100 }
  }
}
```

### Counting Rules

ComplexityGuard follows ESLint-aligned counting rules by default, but you can customize which language features contribute to complexity:

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

**`logical_operators`** — Count `&&` and `||` operators (default: `true`)
- When `true`: `if (a && b)` adds +1 for the `if` and +1 for the `&&` = 2
- When `false`: `if (a && b)` adds only +1 for the `if` = 1

**`nullish_coalescing`** — Count `??` operator (default: `true`)
- When `true`: `value ?? default` adds +1
- When `false`: `value ?? default` adds 0

**`optional_chaining`** — Count `?.` operator (default: `true`)
- When `true`: `obj?.prop?.method?.()` adds +3
- When `false`: `obj?.prop?.method?.()` adds 0

**`switch_case_mode`** — How to count switch statements (default: `"perCase"`)
- `"perCase"`: Each case adds +1 (ESLint behavior)
- `"switchOnly"`: Only the switch itself adds +1 (classic McCabe)

## Tracking Health Over Time

Once you have a baseline analysis, use `--save-baseline` to capture it as a CI enforcement threshold:

```sh
# Generate a default config file
complexity-guard --init

# Capture the current score as a baseline
complexity-guard --save-baseline src/

# In CI: enforce the baseline (exits 1 if score drops below it)
complexity-guard src/

# Or override from the command line
complexity-guard --fail-health-below 70 src/
```

See [Health Score](health-score.md) for the full baseline + ratchet workflow.

## Next Steps

Now that you have ComplexityGuard installed and understand the basics, explore:

- **[CLI Reference](cli-reference.md)** — Complete documentation of all flags, config options, and exit codes
- **[Examples](examples.md)** — Real-world usage patterns, CI integration, and configuration recipes
- **[Health Score](health-score.md)** — Composite 0–100 score, formula, weights, and baseline workflow
- **[Halstead Metrics](halstead-metrics.md)** — Formulas, thresholds, and what the information-theoretic numbers mean
- **[Structural Metrics](structural-metrics.md)** — Function length, parameters, nesting depth, and more
- **[Cyclomatic Complexity](cyclomatic-complexity.md)** — How path counting works and when it matters
- **[Cognitive Complexity](cognitive-complexity.md)** — How nesting penalties measure readability
