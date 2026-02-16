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

When you run ComplexityGuard, you'll see output like this:

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' has complexity 3 (threshold: 10)  cyclomatic
  67:0  ⚠  warning  Function 'processLoginFlow' has complexity 12 (threshold: 10)  cyclomatic
  89:2  ✗  error  Function 'handleComplexAuthFlow' has complexity 25 (threshold: 20)  cyclomatic

Analyzed 12 files, 47 functions
Found 3 warnings, 1 errors

Top complexity hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 25
  2. processPayment (src/checkout/payment.ts:156) complexity 18
  3. validateFormData (src/forms/validator.ts:34) complexity 15

✗ 4 problems (1 errors, 3 warnings)
```

### Reading the Results

Each line shows:
- **Line:Column** — Location of the function (e.g., `42:0`)
- **Indicator** — Visual status marker:
  - `✓` (green) = OK, complexity below warning threshold
  - `⚠` (yellow) = Warning, complexity between warning and error thresholds
  - `✗` (red) = Error, complexity exceeds error threshold
- **Severity** — `ok`, `warning`, or `error`
- **Function Info** — Type and name (e.g., `Function 'validateCredentials'`)
- **Complexity Value** — Cyclomatic complexity score
- **Threshold** — The threshold that triggered the status
- **Metric** — Currently always `cyclomatic`

By default, ComplexityGuard shows only files with warnings or errors. Functions that pass all thresholds are hidden to reduce noise.

### Default Thresholds

- **Warning**: Complexity 10 or higher (McCabe's original recommendation)
- **Error**: Complexity 20 or higher (ESLint default)

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

Use the `--init` command to generate a default configuration:

```sh
complexity-guard --init
```

This creates a `.complexityguard.json` file with sensible defaults:

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

Adjust warning and error thresholds to match your team's standards:

```json
{
  "thresholds": {
    "cyclomatic": {
      "warning": 5,
      "error": 10
    }
  }
}
```

**Strict mode** (lower thresholds) catches complexity issues early:
```json
{
  "thresholds": {
    "cyclomatic": { "warning": 5, "error": 10 }
  }
}
```

**Lenient mode** (higher thresholds) for legacy codebases:
```json
{
  "thresholds": {
    "cyclomatic": { "warning": 20, "error": 40 }
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

## Next Steps

Now that you have ComplexityGuard installed and understand the basics, explore:

- **[CLI Reference](cli-reference.md)** — Complete documentation of all flags, config options, and exit codes
- **[Examples](examples.md)** — Real-world usage patterns, CI integration, and configuration recipes
