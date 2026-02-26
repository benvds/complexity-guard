# ComplexityGuard

Fast complexity analysis for TypeScript/JavaScript — single static binary built with Rust, zero dependencies.

## Quick Start

Install ComplexityGuard:

```sh
# npm (global install)
npm install -g complexity-guard

# Direct download (Rust binary — all platforms)
# Download the archive for your platform from GitHub Releases:
# https://github.com/benvds/complexity-guard/releases
#
# Available platforms:
#   complexity-guard-linux-x86_64-musl.tar.gz    (Linux x86_64)
#   complexity-guard-linux-aarch64-musl.tar.gz   (Linux ARM64)
#   complexity-guard-macos-x86_64.tar.gz         (macOS Intel)
#   complexity-guard-macos-aarch64.tar.gz        (macOS Apple Silicon)
#   complexity-guard-windows-x86_64.zip          (Windows x64)
#
# Extract and install (macOS/Linux):
tar xzf complexity-guard-*.tar.gz
chmod +x complexity-guard
sudo mv complexity-guard /usr/local/bin/
```

Run analysis on your codebase:

```sh
complexity-guard src/
```

Set up health score tracking (analyzes your code, suggests weights, saves baseline):

```sh
complexity-guard --init src/
```

## Example Output

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

### SARIF Output in VS Code

<a href="docs/images/sarif-vscode-dark.png"><img src="docs/images/sarif-vscode-dark.png" alt="SARIF results in VS Code (dark theme)" width="400"></a>&nbsp;&nbsp;<a href="docs/images/sarif-vscode-light.png"><img src="docs/images/sarif-vscode-light.png" alt="SARIF results in VS Code (light theme)" width="400"></a>

### HTML Report

<a href="docs/examples/cxg.html"><img src="docs/images/html-report.png" alt="HTML report with dashboard, treemap, and file breakdown" width="400"></a>

## Benchmarks

Analyzed across 83 open-source projects (107k files, 321k functions). Selection of results on Apple M1 Max with parallel analysis:

| Project | Files | Functions | Time (ms) | Health Score |
|---------|------:|----------:|----------:|-------------:|
| lodash | 26 | 79 | 13 ± 1 | 92.4 |
| axios | 160 | 472 | 22 ± 2 | 95.8 |
| excalidraw | 380 | 1,909 | 74 ± 6 | 92.0 |
| tanstack-query | 721 | 1,371 | 86 ± 5 | 95.0 |
| vite | 1,182 | 2,639 | 83 ± 4 | 95.4 |
| three.js | 1,537 | 10,133 | 705 ± 190 | 93.2 |
| vscode | 5,071 | 59,316 | 3,281 ± 418 | 94.1 |

See the [full benchmark results](docs/benchmarks.md) for all 83 projects.

## Features

- **Cyclomatic Complexity**: McCabe metric counting independent code paths — measures testability
- **Cognitive Complexity**: SonarSource-based metric with nesting depth penalties — measures understandability
- **Halstead Metrics**: Information-theoretic vocabulary density, volume, difficulty, effort, and estimated bugs
- **Structural Metrics**: Function length, parameter count, nesting depth, file length, and export count
- **Duplication Detection**: Rabin-Karp rolling hash detects Type 1 and Type 2 code clones across files — enable with `--duplication` (see [duplication docs](docs/duplication-detection.md))
- **Composite Health Score**: Single 0–100 score combining all metric families with configurable weights — enforce in CI with `--fail-health-below`
- **Console + JSON + SARIF + HTML Output**: Human-readable terminal display, machine-readable JSON, SARIF 2.1.0 for GitHub Code Scanning, and self-contained HTML reports with interactive dashboard, treemap visualization, and sortable metric tables
- **Parallel Analysis**: Analyzes files concurrently across all CPU cores by default — use `--threads N` to control thread count or `--threads 1` for single-threaded mode
- **Configurable Thresholds**: Warning and error levels for all metric families, customizable per project
- **Selective Metrics**: Use `--metrics cyclomatic,halstead` to compute only specific families
- **Zero Config**: Works out of the box with sensible defaults, optional `.complexityguard.json` for customization
- **Single Binary**: No runtime dependencies, runs offline, fast startup — under 300ms on mid-size projects
- **Fast**: Analyzes thousands of files in seconds with parallel analysis across all CPU cores (see [benchmarks](docs/benchmarks.md))
- **Low Memory Footprint**: 1.2–2.2x less memory than Node.js-based tools on small and medium projects (see [benchmarks](docs/benchmarks.md))
- **Error-Tolerant Parsing**: Tree-sitter based parser handles syntax errors gracefully, continues analysis on remaining files
- **Automatic Safety Limits**: Files > 10,000 lines and functions > 5,000 lines are skipped and reported in output — prevents crashes on auto-generated code or minified bundles (see [Size Limits](docs/cli-reference.md#size-limits))

## Documentation

- **[Getting Started](docs/getting-started.md)** — Installation, first analysis, configuration basics
- **[CLI Reference](docs/cli-reference.md)** — All flags, config options, exit codes
- **[Examples](docs/examples.md)** — Real-world usage patterns, CI integration recipes
- **[SARIF Output](docs/sarif-output.md)** — GitHub Code Scanning integration with inline PR annotations
- **[HTML Reports](docs/examples.md#html-reports)** — Self-contained interactive reports for sharing with stakeholders
- **[Performance Benchmarks](docs/benchmarks.md)** — Speed and memory benchmarks across real-world projects
- **[Releasing](docs/releasing.md)** — Release process, publishing, version management
- **[Claude Code Skill](docs/claude-code-skill.md)** — Use ComplexityGuard with Claude Code AI agents

### Metrics

- **[Health Score](docs/health-score.md)** — Composite 0–100 score, formula, weights, and baseline + ratchet workflow
- **[Cyclomatic Complexity](docs/cyclomatic-complexity.md)** — Path counting for testability, ESLint-aligned rules
- **[Cognitive Complexity](docs/cognitive-complexity.md)** — Nesting-aware readability metric from SonarSource
- **[Halstead Metrics](docs/halstead-metrics.md)** — Vocabulary density, volume, difficulty, effort, estimated bugs
- **[Structural Metrics](docs/structural-metrics.md)** — Function length, parameters, nesting depth, file length, exports
- **[Duplication Detection](docs/duplication-detection.md)** — Rabin-Karp clone detection, Type 1/2 clones, thresholds (opt-in)

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
    "halstead_difficulty": { "warning": 10, "error": 20 },
    "halstead_effort": { "warning": 5000, "error": 10000 },
    "halstead_bugs": { "warning": 0.5, "error": 2.0 },
    "function_length": { "warning": 25, "error": 50 },
    "params": { "warning": 3, "error": 6 },
    "nesting": { "warning": 3, "error": 5 },
    "file_length": { "warning": 300, "error": 600 },
    "exports": { "warning": 15, "error": 30 },
    "duplication": { "file_warning": 15.0, "file_error": 25.0, "project_warning": 5.0, "project_error": 10.0 }
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
  "analysis": {
    "threads": 4,
    "duplication_enabled": false
  },
  "baseline": 73.2
}
```

See the [CLI Reference](docs/cli-reference.md) for complete configuration options.

## Building from Source

Requires [Rust](https://www.rust-lang.org/) (stable toolchain):

```sh
cargo build --release
```

The binary will be at `target/release/complexity-guard`. Add it to your PATH or run it directly.

## Binary Sizes

Binary sizes are measured in CI on every release. See the [latest GitHub Release](https://github.com/benvds/complexity-guard/releases/latest) for measured binary sizes per platform.

## License

[MIT](LICENSE)
