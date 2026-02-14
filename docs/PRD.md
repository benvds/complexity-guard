# PRD: ComplexityGuard

**A fast, cross-platform code complexity analyzer for TypeScript/JavaScript projects**

Version: 0.1.0 Draft
Date: 2026-02-14
Author: Ben (Lean Digital)

---

## Problem Statement

JavaScript and TypeScript projects lack fast, local, offline-first complexity analysis. Teams either pay for SonarCloud, accept slow ESLint plugins, or just skip complexity analysis entirely. There's nothing in the "oxlint speed class" that focuses specifically on code health metrics.

ComplexityGuard fills that gap: a single binary that runs complexity analysis at the speed of a linter, outputs SARIF/JSON/HTML, integrates with CI and editors, and gives teams configurable weighted scoring across multiple complexity dimensions.

## Product Vision

Ship a single, zero-dependency binary (compiled from Zig) that analyzes TypeScript, TSX, JavaScript, and JSX files for code complexity. It should feel as fast as `oxlint`, produce output compatible with existing toolchains (SARIF, JSON, HTML), and let teams define what "complexity" means for their codebase through configurable metric weights.

## Target Users

- Solo developers and small teams using Vite/TypeScript who want SonarCloud-level insight without the SaaS cost
- CI/CD pipelines that need fast complexity gates with exit codes
- Developers who want inline editor feedback through LSP

## Scope

### In scope (v1.0)

- CLI tool with file/directory scanning
- TS/TSX/JS/JSX parsing via tree-sitter
- Five metric families (detailed below)
- Configurable thresholds and weights
- JSON, SARIF 2.1.0, and HTML report output
- Exit codes for CI integration
- Config file support (`.complexityguard.json`)

### In scope (v1.x roadmap)

- LSP server for editor integration
- Watch mode for development
- Baseline/diff mode (only flag new complexity)
- Git blame integration (who introduced complexity)

### Out of scope

- Vue SFC support (may add later)
- Type-checking or semantic analysis (we work with syntax only)
- Bug detection or security scanning
- Auto-fix suggestions

---

## Metrics & Algorithms

ComplexityGuard measures five families of metrics. Each produces a raw score at function-level and file-level. A configurable weighted composite score combines them into a single "health score" per file and per project.

### 1. Cyclomatic Complexity (McCabe, 1976)

Measures the number of linearly independent paths through a function's control flow graph.

**Algorithm:**
Start with a base complexity of 1 per function. Increment by 1 for each:

- `if`, `else if` (not `else` alone)
- `for`, `for...in`, `for...of`, `while`, `do...while`
- `case` in switch statements (not `default`)
- `catch` clause
- Ternary operator `? :`
- Logical AND `&&` and OR `||` when used as control flow (short-circuit)
- Nullish coalescing `??`
- Optional chaining `?.` (debatable, configurable)

**Implementation notes:**
Walk the tree-sitter AST. Count node types that correspond to branch points. For boolean operator sequences like `a && b && c`, count each operator. This aligns with how SonarQube counts cyclomatic complexity for JS/TS.

**Default threshold:** 10 per function (warning), 20 per function (error)

### 2. Cognitive Complexity (SonarSource, 2016)

Measures how hard a function is to understand, not just how many paths exist. Three core rules:

**Rule 1 — Increment for flow breaks:**
+1 for each: `if`, `else if`, `else`, `switch`, `for`, `for...in`, `for...of`, `while`, `do...while`, `catch`, ternary `? :`, `break` (labeled), `continue` (labeled), `goto`-equivalents.

Note: `else if` gets +1 total (not +1 for else and +1 for if). A `switch` gets +1 for the whole structure, not per-case.

**Rule 2 — Increment for nesting:**
Each flow-break structure nested inside another flow-break adds a nesting penalty equal to its current nesting depth. So an `if` inside a `for` inside another `if` gets: +1 (for) + 1 nesting, then +1 (inner if) + 2 nesting = total +5 for those two constructs.

Structures that increase nesting level: `if`, `else if`, `else`, `switch`, `for`, `while`, `do...while`, `catch`, ternary, arrow functions, lambda expressions.

**Rule 3 — Ignore shorthand:**
No increment for structures that make code more readable: null coalescing `??` used in assignment, optional chaining `?.`, early returns.

**Sequences of logical operators:**
A chain of the same operator (e.g., `a && b && c`) gets +1 total. Mixing operators (e.g., `a && b || c`) gets +1 for each switch between operator types.

**Recursion:**
+1 when a function calls itself.

**Implementation:**
Walk the AST while maintaining a nesting counter. Push nesting on entering relevant nodes, pop on exit. Increment the score by `1 + current_nesting` for structural increments, or just `1` for fundamental increments. Track boolean operator sequences by remembering the previous operator type.

**Default threshold:** 15 per function (warning), 25 per function (error)

### 3. Halstead Complexity Metrics (Halstead, 1977)

Measures program vocabulary and volume based on operators and operands.

**Step 1 — Classify tokens:**

Operators (TypeScript): `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `**=`, `&&=`, `||=`, `??=`, `<<=`, `>>=`, `>>>=`, `&=`, `|=`, `^=`, `+`, `-`, `*`, `/`, `%`, `**`, `==`, `===`, `!=`, `!==`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `??`, `!`, `~`, `&`, `|`, `^`, `<<`, `>>`, `>>>`, `++`, `--`, `?.`, `...`, `=>`, `typeof`, `instanceof`, `void`, `delete`, `new`, `await`, `yield`, `in`, `of`, `as`, `is`, `keyof`, `import`, `export`, `return`, `throw`, `if`, `else`, `switch`, `case`, `for`, `while`, `do`, `break`, `continue`, `try`, `catch`, `finally`, `class`, `extends`, `implements`, `function`, method calls (the call itself, not the name).

Operands: identifiers, literals (string, number, boolean, null, undefined, template), property access names, type annotations.

**Step 2 — Compute base counts:**

| Symbol | Meaning |
|--------|---------|
| n1 | Distinct operators |
| n2 | Distinct operands |
| N1 | Total operator occurrences |
| N2 | Total operand occurrences |

**Step 3 — Derive metrics:**

| Metric | Formula | What it tells you |
|--------|---------|-------------------|
| Vocabulary | n = n1 + n2 | How many unique tokens exist |
| Length | N = N1 + N2 | Total tokens used |
| Calculated length | N̂ = n1·log₂(n1) + n2·log₂(n2) | Expected length if no repetition |
| Volume | V = N · log₂(n) | Information content in bits |
| Difficulty | D = (n1/2) · (N2/n2) | How hard to write or understand |
| Effort | E = D · V | Total mental effort |
| Time to program | T = E / 18 seconds | Estimated coding time |
| Estimated bugs | B = E^(2/3) / 3000 | Predicted defect count |

**Default thresholds (per function):**

| Metric | Warning | Error |
|--------|---------|-------|
| Volume | > 500 | > 1000 |
| Difficulty | > 30 | > 50 |
| Effort | > 100,000 | > 300,000 |
| Estimated bugs | > 0.5 | > 2.0 |

### 4. Duplication Detection

Detects copy-pasted code blocks using token-based matching with Rabin-Karp rolling hashes.

**Algorithm:**

1. **Tokenize** each source file using tree-sitter. Strip comments and whitespace. Normalize identifiers to a canonical form (Type 2 clone detection: `let foo = bar + baz` and `let x = y + z` produce the same token sequence).

2. **Hash token sequences** using a rolling Rabin-Karp hash with a configurable minimum window size (default: 25 tokens, roughly 5-6 lines of code). Use a large prime modulus to minimize collisions.

3. **Build a hash index** across all files. Group sequences with matching hashes.

4. **Verify matches** by comparing token sequences character-by-character on hash collisions.

5. **Merge overlapping matches** into maximal clone groups.

6. **Report** clone groups with locations, token counts, and a duplication percentage per file and project.

**Clone types detected:**
- Type 1: Exact duplicates (ignoring whitespace/comments)
- Type 2: Renamed identifiers/literals (token normalization)
- Type 3 (optional, v1.x): Near-miss clones with configurable gap tolerance

**Default thresholds:**

| Metric | Warning | Error |
|--------|---------|-------|
| Minimum clone size | 25 tokens | — |
| File duplication % | > 5% | > 15% |
| Project duplication % | > 3% | > 10% |

### 5. Structural Metrics

Simple but valuable measurements that catch common code smells.

| Metric | What | Default warning | Default error |
|--------|------|-----------------|---------------|
| Function length | Lines of code per function (logical, excluding blanks/comments) | > 30 | > 60 |
| Parameter count | Number of parameters per function | > 4 | > 7 |
| Nesting depth | Maximum nesting level within a function | > 3 | > 5 |
| File length | Logical lines of code per file | > 300 | > 500 |
| Export count | Number of exports per file | > 10 | > 20 |

---

## Composite Health Score

ComplexityGuard computes a weighted composite score (0-100) for each file and for the whole project. Higher is better.

**Formula:**

```
health = 100 - Σ(weight_i × normalized_violation_score_i)
```

Where each metric family contributes a normalized violation score (0-100 scale) based on how far above thresholds the measured values are. The weights are configurable.

**Default weights:**

| Metric | Weight |
|--------|--------|
| Cyclomatic complexity | 0.20 |
| Cognitive complexity | 0.30 |
| Halstead difficulty/effort | 0.15 |
| Duplication | 0.20 |
| Structural metrics | 0.15 |

Users override these in `.complexityguard.json`:

```json
{
  "weights": {
    "cyclomatic": 0.10,
    "cognitive": 0.40,
    "halstead": 0.10,
    "duplication": 0.25,
    "structural": 0.15
  }
}
```

**Grading (default):**

| Score | Grade | Meaning |
|-------|-------|---------|
| 80-100 | A | Healthy |
| 60-79 | B | Acceptable |
| 40-59 | C | Needs attention |
| 20-39 | D | Poor |
| 0-19 | F | Critical |

---

## Technical Architecture

### Language: Zig

Chosen for:
- Single static binary output, no runtime dependencies
- Cross-compilation to Linux (x86_64, aarch64), macOS (x86_64, aarch64), Windows (x86_64) from any host
- C ABI compatibility for linking tree-sitter (which is written in C)
- Fast compile times compared to Rust
- Explicit memory management without garbage collector overhead

### Parsing: tree-sitter

tree-sitter provides the TypeScript/TSX grammar as a C library. Zig calls it through C interop.

**Why tree-sitter:**
- Proven grammars for TypeScript, TSX, JavaScript, JSX
- Error-tolerant parsing (doesn't fail on syntax errors)
- Incremental parsing (useful for watch mode and LSP in v1.x)
- AST node types map cleanly to complexity increment rules
- Zig has official tree-sitter bindings (zig-tree-sitter)

**Parsing pipeline:**

```
Source file → tree-sitter parser → Concrete Syntax Tree → AST walker → Metric collectors
```

Each metric collector is an independent AST visitor. They run in a single pass where possible (cyclomatic, cognitive, structural, and Halstead can all collect data in one walk). Duplication requires a separate tokenization pass.

### Parallelism

Files are analyzed independently. Use Zig's `std.Thread` pool to process files in parallel. The duplication detector runs after individual file analysis completes, as it needs cross-file comparisons.

**Expected performance target:** < 1 second for 10,000 files on modern hardware. (Based on oxlint benchmarks, which processes ~50,000 files/sec for lint rules. Complexity analysis is heavier per-file but the same order of magnitude.)

### Project Structure

```
complexityguard/
├── build.zig                  # Build configuration
├── src/
│   ├── main.zig              # CLI entry point, arg parsing
│   ├── config.zig            # Config file loading
│   ├── scanner.zig           # File discovery and filtering
│   ├── parser.zig            # tree-sitter integration
│   ├── metrics/
│   │   ├── cyclomatic.zig    # McCabe cyclomatic complexity
│   │   ├── cognitive.zig     # SonarSource cognitive complexity
│   │   ├── halstead.zig      # Halstead metrics
│   │   ├── duplication.zig   # Rabin-Karp duplication detection
│   │   ├── structural.zig    # Function length, params, nesting
│   │   └── composite.zig     # Weighted health score
│   ├── output/
│   │   ├── json.zig          # JSON output formatter
│   │   ├── sarif.zig         # SARIF 2.1.0 output
│   │   ├── html.zig          # HTML report generator
│   │   └── console.zig       # Terminal pretty-printer
│   └── lsp/                  # (v1.x) LSP server
│       ├── server.zig
│       └── protocol.zig
├── grammars/                  # tree-sitter TypeScript/JS grammars (C source)
└── tests/
    ├── fixtures/             # Test TypeScript files with known complexity
    └── metric_tests.zig      # Unit tests per metric
```

---

## Output Formats

### Console (default)

```
src/utils/parser.ts
  parseConfig()     cognitive: 23 ⚠  cyclomatic: 12 ⚠  nesting: 4 ⚠
  transformData()   cognitive: 8 ✓   cyclomatic: 5 ✓   nesting: 2 ✓

src/api/handler.ts
  handleRequest()   cognitive: 31 ✗  cyclomatic: 18 ⚠  halstead.difficulty: 42 ⚠

── Summary ────────────────────────────────────
Files: 142  Functions: 891  Health: 72/100 (B)
  Cognitive: 3 errors, 12 warnings
  Cyclomatic: 0 errors, 8 warnings
  Duplication: 2.1% (4 clone groups)
```

### JSON

```json
{
  "version": "1.0.0",
  "timestamp": "2026-02-14T10:30:00Z",
  "summary": {
    "healthScore": 72,
    "grade": "B",
    "files": 142,
    "functions": 891,
    "duplicationPercent": 2.1
  },
  "files": [
    {
      "path": "src/utils/parser.ts",
      "healthScore": 65,
      "functions": [
        {
          "name": "parseConfig",
          "line": 14,
          "metrics": {
            "cyclomatic": { "value": 12, "threshold": "warning" },
            "cognitive": { "value": 23, "threshold": "warning" },
            "halstead": {
              "volume": 342,
              "difficulty": 28,
              "effort": 9576,
              "estimatedBugs": 0.3
            },
            "nesting": { "value": 4, "threshold": "warning" },
            "parameterCount": { "value": 3, "threshold": "ok" },
            "length": { "value": 45, "threshold": "warning" }
          }
        }
      ]
    }
  ],
  "duplication": {
    "percentage": 2.1,
    "cloneGroups": [
      {
        "tokenCount": 48,
        "instances": [
          { "file": "src/api/users.ts", "startLine": 22, "endLine": 34 },
          { "file": "src/api/posts.ts", "startLine": 18, "endLine": 30 }
        ]
      }
    ]
  }
}
```

### SARIF 2.1.0

Produces a valid SARIF file that integrates with GitHub Code Scanning, VS Code SARIF Viewer, and other SARIF-compatible tools. Each metric violation becomes a SARIF `result` with appropriate `level` (warning/error), `ruleId`, and `physicalLocation`.

### HTML

A self-contained single-file HTML report with:
- Project summary dashboard (health score, grade, trend sparklines if baseline exists)
- Per-file breakdown with expandable function details
- Duplication visualization
- Sortable tables by any metric
- No external dependencies (inline CSS/JS)

---

## Configuration

### `.complexityguard.json`

```json
{
  "include": ["src/**/*.ts", "src/**/*.tsx"],
  "exclude": ["**/*.test.ts", "**/*.spec.ts", "node_modules/**", "dist/**"],

  "thresholds": {
    "cyclomatic": { "warning": 10, "error": 20 },
    "cognitive": { "warning": 15, "error": 25 },
    "halstead": {
      "volume": { "warning": 500, "error": 1000 },
      "difficulty": { "warning": 30, "error": 50 }
    },
    "duplication": {
      "minTokens": 25,
      "filePercent": { "warning": 5, "error": 15 },
      "projectPercent": { "warning": 3, "error": 10 }
    },
    "structural": {
      "functionLength": { "warning": 30, "error": 60 },
      "parameterCount": { "warning": 4, "error": 7 },
      "nestingDepth": { "warning": 3, "error": 5 },
      "fileLength": { "warning": 300, "error": 500 }
    }
  },

  "weights": {
    "cyclomatic": 0.20,
    "cognitive": 0.30,
    "halstead": 0.15,
    "duplication": 0.20,
    "structural": 0.15
  },

  "output": {
    "format": "console",
    "file": null
  },

  "ci": {
    "failOn": "error",
    "failHealthBelow": null
  }
}
```

### CLI Flags

```
complexityguard [options] [paths...]

Options:
  --config <path>          Config file path (default: .complexityguard.json)
  --format <fmt>           Output: console, json, sarif, html (default: console)
  --output <file>          Write report to file instead of stdout
  --fail-on <level>        Exit non-zero on: warning, error, none (default: error)
  --fail-health-below <n>  Exit non-zero if health score below n
  --include <glob>         Include pattern (repeatable)
  --exclude <glob>         Exclude pattern (repeatable)
  --metrics <list>         Comma-separated metrics to run (default: all)
  --no-duplication         Skip duplication detection (faster)
  --threads <n>            Thread count (default: CPU count)
  --baseline <file>        Compare against previous JSON report
  --verbose                Show per-function details in console
  --quiet                  Only show errors
  --version                Print version
  --help                   Show help
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | Errors found (or health below threshold) |
| 2 | Warnings found (if `--fail-on warning`) |
| 3 | Configuration error |
| 4 | Parse error (couldn't read source files) |

---

## LSP Integration (v1.x)

ComplexityGuard will ship a built-in LSP server for real-time editor feedback.

**Capabilities:**
- Diagnostics: Show complexity warnings/errors inline as you type
- Code lenses: Display complexity scores above functions
- Hover: Show detailed metric breakdown on hover over function names

**Activation:** `complexityguard lsp` starts the server. Editor plugins connect over stdio.

**Priority targets:** VS Code extension, Neovim (nvim-lspconfig), Zed

---

## Build & Distribution

### Cross-compilation

Zig's cross-compilation makes this trivial:

```bash
zig build -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseFast
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseFast
zig build -Dtarget=x86_64-macos -Doptimize=ReleaseFast
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast
```

### Distribution channels

- GitHub Releases (pre-built binaries)
- npm wrapper package (`npx complexityguard`)
- Homebrew tap
- AUR package

### Binary size target

< 5 MB for the static binary (tree-sitter grammars compiled in).

---

## Testing Strategy

### Unit tests

Each metric module has property-based tests against known TypeScript snippets with hand-calculated expected scores. Compare results against SonarQube/ESLint outputs for cognitive and cyclomatic complexity.

### Integration tests

Run ComplexityGuard on popular open-source TypeScript projects (e.g., tRPC, Zod, TanStack Router) and validate output is reasonable.

### Benchmark tests

Track analysis speed per file and regression test against performance targets.

---

## Success Criteria (v1.0)

- Produces correct cyclomatic and cognitive complexity scores matching SonarQube within ±5% on a test corpus of 1000+ functions
- Analyzes 10,000 TypeScript files in under 2 seconds
- Single binary under 5 MB, runs on Linux/macOS/Windows
- Valid SARIF output accepted by GitHub Code Scanning
- Configurable weights produce different health scores as expected
- Exit codes work correctly for CI/CD gating

---

## Open Questions

1. **Optional chaining (`?.`) in cyclomatic complexity:** Should it count as a branch? It's a control flow shortcut but doesn't create a testable path. Consider making it configurable.

2. **Arrow functions and nesting:** Should `array.map(x => ...)` increase nesting depth for cognitive complexity? SonarSource says yes for lambdas. This could be controversial for functional-style TS code.

3. **Type-level complexity:** TypeScript has complex type expressions (`Conditional<T extends U ? X : Y>`). Should there be a separate "type complexity" metric? Probably a v2 feature.

4. **Monorepo awareness:** Should `complexityguard` read `package.json` workspaces or Vite config to scope analysis? Or just rely on include/exclude patterns?

5. **Naming:** ComplexityGuard is a working title. Other candidates: `cxguard`, `tscx`, `codemeter`, `oxcx`.
