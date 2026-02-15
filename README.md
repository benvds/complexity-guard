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

**Work in progress** -- Phases 1-3 are complete. The build system, core data structures, CLI with argument parsing and config file support, and tree-sitter-based file discovery and parsing are all operational. Metric analysis (cyclomatic, cognitive, Halstead, structural), output formats, and duplication detection are under active development.

See the [roadmap](.planning/ROADMAP.md) for the full development plan.

### Completed

- **Phase 1: Project Foundation** -- Build system, core data structures, JSON serialization, test infrastructure
- **Phase 2: CLI & Configuration** -- Argument parsing, config file loading (`.complexityguard.json`), flag-over-config merging, `--init` scaffolding, help/version output
- **Phase 3: File Discovery & Parsing** -- Tree-sitter C library integration, recursive file scanning with extension filtering, include/exclude pattern matching, error-tolerant parsing

### Up Next

- **Phase 4: Cyclomatic Complexity** -- McCabe metric with threshold validation

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

## Usage

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

# Generate a default config file
complexityguard --init
```

> **Note:** The CLI accepts all flags today. Output formats and metric analysis are still being implemented -- currently the tool discovers files and parses them via tree-sitter.

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

## Project Structure

```
src/
  main.zig              # entry point, module imports for test discovery
  core/types.zig        # core data structures (FunctionResult, FileResult, ProjectResult)
  core/json.zig         # JSON serialization helpers
  cli/args.zig          # argument parsing (hand-rolled, ripgrep-style UX)
  cli/config.zig        # config file discovery and loading (.complexityguard.json)
  cli/merge.zig         # flag-over-config merge logic
  cli/help.zig          # help text and version display
  cli/init.zig          # --init config scaffolding
  cli/errors.zig        # CLI error types
  cli/discovery.zig     # config file search (CWD upward, XDG)
  discovery/walker.zig  # recursive directory traversal
  discovery/filter.zig  # extension and glob pattern filtering
  parser/tree_sitter.zig # tree-sitter Zig bindings (wraps C API)
  parser/parse.zig      # parse orchestration and error handling
  test_helpers.zig      # test builders (createTestFunction, createTestFile, etc.)
vendor/                 # vendored tree-sitter + TS/JS/TSX grammars (C sources)
tests/fixtures/         # real-world TS/JS fixture files for testing
```

## Architecture

ComplexityGuard is written in Zig for single-binary output and fast C interop with tree-sitter. The analysis pipeline will run all metrics in a single AST pass per file, with cross-file duplication detection as a second phase. Files will be processed in parallel via a thread pool.

Currently the tool discovers files via recursive directory walking with extension filtering, parses them into ASTs via tree-sitter (TypeScript, TSX, JavaScript, JSX grammars), and handles syntax errors gracefully by continuing with remaining files.

## License

[MIT](LICENSE)
