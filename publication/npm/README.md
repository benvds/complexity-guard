# ComplexityGuard

Fast complexity analysis for TypeScript/JavaScript — single static binary, zero dependencies.

## Install

```sh
# Global install (CLI access from anywhere)
npm install -g complexity-guard

# Local/CI install (project dependency)
npm install --save-dev complexity-guard
```

## Usage

```sh
complexity-guard src/
```

### Example Output

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18
  89:2  ✗  error  Method 'handleComplexAuthFlow' cyclomatic 25 cognitive 32

Analyzed 12 files, 47 functions
Found 3 warnings, 1 errors

Top cyclomatic hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 25
  2. processPayment (src/checkout/payment.ts:156) complexity 18

Top cognitive hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 32
  2. processLoginFlow (src/auth/login.ts:67) complexity 18

✗ 4 problems (1 errors, 3 warnings)
```

## Features

- **Cognitive Complexity**: SonarSource-based metric measuring code *understandability* with nesting depth penalties
- **Cyclomatic Complexity**: McCabe metric with ESLint-aligned counting rules, complementary to cognitive complexity
- **Console + JSON Output**: Human-readable terminal display and machine-readable JSON for CI integration
- **Configurable Thresholds**: Warning and error levels for both metrics, customizable per project via config file
- **Zero Config**: Works out of the box with sensible defaults, optional `.complexityguard.json` for customization
- **Single Binary**: No runtime dependencies, runs offline, fast startup
- **Error-Tolerant Parsing**: Tree-sitter based parser handles syntax errors gracefully, continues analysis on remaining files

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
  }
}
```

## Links

- [GitHub](https://github.com/benvds/complexity-guard)
- [Documentation](https://github.com/benvds/complexity-guard#documentation)

## License

MIT
