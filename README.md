# ComplexityGuard

A fast, zero-dependency code complexity analyzer for TypeScript and JavaScript projects. A single static binary built with Zig that runs complexity analysis at linter speed, giving teams configurable scoring across multiple complexity dimensions.

## Why ComplexityGuard?

- **Single binary, zero dependencies** -- download and run, no Node.js/npm/pip required
- **Fast** -- targets under 2 seconds for 10,000 files via parallel analysis
- **Multiple metrics** -- cyclomatic, cognitive, Halstead, structural, and duplication detection in one tool
- **CI-ready** -- JSON, SARIF (GitHub Code Scanning), and HTML output formats with configurable exit codes
- **Offline** -- runs locally, no SaaS account or network access needed

## Metrics

| Metric | What it measures |
|--------|-----------------|
| **Cyclomatic** (McCabe) | Number of independent paths through a function |
| **Cognitive** (SonarSource) | How difficult code is to understand, with nesting penalties |
| **Halstead** | Information-theoretic complexity: volume, difficulty, effort, estimated bugs |
| **Structural** | Function length, parameter count, nesting depth, file length, export count |
| **Duplication** | Type 1 & 2 code clones via Rabin-Karp rolling hash |
| **Composite** | Weighted health score (0-100) with letter grade (A-F) |

## Status

**Work in progress** -- Phase 1 (project foundation) is complete. The build system, core data structures, and test infrastructure are in place. Core metric analysis, CLI, output formats, and other features are under active development.

See the [roadmap](.planning/ROADMAP.md) for the full development plan.

## Building

Requires [Zig](https://ziglang.org/) 0.14.0 or later.

```sh
# Build
zig build

# Run
zig build run

# Run tests
zig build test
```

The build produces a single static binary at `zig-out/bin/complexity-guard`.

## Planned Usage

```sh
# Analyze a directory
complexityguard src/

# Analyze specific files
complexityguard src/app.ts src/utils.ts

# Output as JSON
complexityguard --format json --output report.json src/

# Output as SARIF for GitHub Code Scanning
complexityguard --format sarif --output results.sarif src/

# Generate HTML report
complexityguard --format html --output report.html src/

# Fail CI if health score drops below threshold
complexityguard --fail-health-below 70 src/

# Use a config file
complexityguard --config .complexityguard.json src/
```

## Configuration

ComplexityGuard loads configuration from `.complexityguard.json` when present. CLI flags override config file values.

```json
{
  "include": ["src/**/*.ts", "src/**/*.tsx"],
  "exclude": ["**/*.test.ts", "**/*.spec.ts"],
  "thresholds": {
    "cyclomatic": { "warning": 10, "error": 20 },
    "cognitive": { "warning": 15, "error": 25 }
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "duplication": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  }
}
```

## Output Formats

| Format | Flag | Use case |
|--------|------|----------|
| Console | `--format console` | Developer workflow in terminal |
| JSON | `--format json` | CI/CD pipelines, tooling integration |
| SARIF | `--format sarif` | GitHub Code Scanning integration |
| HTML | `--format html` | Visual reports for stakeholders |

## CI Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks pass |
| 1 | Errors found (or health below threshold) |
| 2 | Warnings found (with `--fail-on warning`) |
| 3 | Configuration error |
| 4 | Parse error |

## Supported File Types

- TypeScript (`.ts`)
- TSX (`.tsx`)
- JavaScript (`.js`)
- JSX (`.jsx`)

Parsing is handled by [tree-sitter](https://tree-sitter.github.io/) with error-tolerant grammars.

## Architecture

ComplexityGuard is written in Zig for single-binary output and fast C interop with tree-sitter. The analysis pipeline runs all metrics in a single AST pass per file, with cross-file duplication detection as a second phase. Files are processed in parallel via a thread pool.

## License

TBD
