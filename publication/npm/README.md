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
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18 [halstead vol 843] [length 34] [params 3] [depth 4]
  89:2  ✗  error  Function 'handleComplexAuthFlow' cyclomatic 25 cognitive 32 [halstead vol 1244] [length 62] [params 4] [depth 6]

Analyzed 12 files, 47 functions
Health: 73
Found 3 warnings, 1 errors

Top cyclomatic hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 25
  2. processPayment (src/checkout/payment.ts:156) complexity 18

Top cognitive hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) complexity 32
  2. processLoginFlow (src/auth/login.ts:67) complexity 18

Top Halstead volume hotspots:
  1. handleComplexAuthFlow (src/auth/login.ts:89) volume 1244
  2. processLoginFlow (src/auth/login.ts:67) volume 843

✗ 4 problems (1 errors, 3 warnings)
```

## Features

- **Cyclomatic Complexity**: McCabe metric counting independent code paths — measures testability
- **Cognitive Complexity**: SonarSource-based metric with nesting depth penalties — measures understandability
- **Halstead Metrics**: Information-theoretic vocabulary density, volume, difficulty, effort, and estimated bugs
- **Structural Metrics**: Function length, parameter count, nesting depth, file length, and export count
- **Duplication Detection**: Rabin-Karp rolling hash detects Type 1 and Type 2 code clones across files — enable with `--duplication`
- **Composite Health Score**: Single 0–100 score combining all metric families with configurable weights — enforce in CI with `--fail-health-below`
- **Console + JSON + SARIF + HTML Output**: Human-readable terminal display, machine-readable JSON, SARIF 2.1.0 for GitHub Code Scanning, and self-contained HTML reports with interactive dashboard, treemap visualization, and sortable metric tables
- **Multi-threaded Parallel Analysis**: Analyzes files concurrently across all CPU cores by default — 1.5–3.1x faster than FTA; use `--threads N` to control thread count
- **Configurable Thresholds**: Warning and error levels for all metric families, customizable per project
- **Selective Metrics**: Use `--metrics cyclomatic,halstead` to compute only specific families
- **Zero Config**: Works out of the box with sensible defaults, optional `.complexityguard.json` for customization
- **Single Binary**: No runtime dependencies, runs offline, fast startup
- **Low Memory Footprint**: 1.2–2.2x less memory than Node.js-based tools on small and medium projects
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
    "cyclomatic": { "warning": 10, "error": 20 },
    "cognitive": { "warning": 15, "error": 25 },
    "halstead_volume": { "warning": 500, "error": 1000 },
    "halstead_effort": { "warning": 5000, "error": 10000 },
    "function_length": { "warning": 25, "error": 50 },
    "params": { "warning": 3, "error": 6 },
    "nesting": { "warning": 3, "error": 5 }
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
- [SARIF Output / GitHub Code Scanning](https://github.com/benvds/complexity-guard/blob/main/docs/sarif-output.md)
- [HTML Reports](https://github.com/benvds/complexity-guard/blob/main/docs/examples.md#html-reports)
- [Performance Benchmarks](https://github.com/benvds/complexity-guard/blob/main/docs/benchmarks.md)

---

**Rust Rewrite — Phase 20 (Parallel Pipeline) complete:** The Rust binary now discovers files and analyzes them in parallel using rayon, producing sorted deterministic output. Full directory analysis end-to-end is functional.

## License

MIT
