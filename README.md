# ComplexityGuard

Fast complexity analysis for TypeScript/JavaScript — single static binary, zero dependencies.

## Quick Start

Install ComplexityGuard:

```sh
# npm (global install)
npm install -g complexity-guard

# Homebrew (macOS/Linux)
brew install benvds/tap/complexity-guard

# Direct download (all platforms)
# Download the binary for your platform from GitHub releases:
# https://github.com/benvds/complexity-guard/releases
# Then make it executable and add to your PATH:
chmod +x complexity-guard
mv complexity-guard /usr/local/bin/
```

Run analysis on your codebase:

```sh
complexity-guard src/
```

## Example Output

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

## Features

- **Cyclomatic Complexity**: McCabe metric with ESLint-aligned counting rules for accurate complexity measurement
- **Console + JSON Output**: Human-readable terminal display and machine-readable JSON for CI integration
- **Configurable Thresholds**: Warning (10) and error (20) levels, customizable per project via config file
- **Zero Config**: Works out of the box with sensible defaults, optional `.complexityguard.json` for customization
- **Single Binary**: No runtime dependencies, runs offline, fast startup
- **Error-Tolerant Parsing**: Tree-sitter based parser handles syntax errors gracefully, continues analysis on remaining files

## Documentation

- **[Getting Started](docs/getting-started.md)** — Installation, first analysis, configuration basics
- **[CLI Reference](docs/cli-reference.md)** — All flags, config options, exit codes
- **[Examples](docs/examples.md)** — Real-world usage patterns, CI integration recipes

## Configuration

Create a `.complexityguard.json` file in your project root to customize behavior:

```json
{
  "files": {
    "include": ["src/**/*.ts", "src/**/*.tsx"],
    "exclude": ["**/*.test.ts", "**/*.spec.ts", "node_modules/**"]
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
  }
}
```

See the [CLI Reference](docs/cli-reference.md) for complete configuration options.

## Building from Source

Requires [Zig](https://ziglang.org/) 0.14.0 or later:

```sh
zig build          # build binary to zig-out/bin/complexity-guard
zig build test     # run all tests
zig build run      # run the binary
```

The build produces a single static binary at `zig-out/bin/complexity-guard`.

## License

[MIT](LICENSE)
