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

- **Cyclomatic Complexity** — McCabe metric with ESLint-aligned counting rules for accurate complexity measurement
- **Console + JSON Output** — Human-readable terminal display and machine-readable JSON for CI integration
- **Configurable Thresholds** — Warning (10) and error (20) levels, customizable per project via config file
- **Zero Config** — Works out of the box with sensible defaults, optional `.complexityguard.json` for customization
- **Single Binary** — No runtime dependencies, runs offline, fast startup
- **Error-Tolerant Parsing** — Tree-sitter based parser handles syntax errors gracefully, continues analysis on remaining files

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

## Links

- [GitHub](https://github.com/benvds/complexity-guard)
- [Documentation](https://github.com/benvds/complexity-guard#documentation)

## License

MIT
