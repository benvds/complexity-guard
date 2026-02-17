# Structural Metrics

Structural metrics describe the *shape* of code — how long functions are, how many parameters they take, how deeply nested they get, and how large files are. They complement flow-based metrics (cyclomatic, cognitive) and information-theoretic metrics (Halstead) by flagging code that is structurally unwieldy even when its logic is simple.

A function with low cyclomatic complexity can still be hard to maintain if it is 200 lines long. Structural metrics catch those issues.

## Metrics

### Function Length

**What it measures:** The number of logical lines in a function body. Logical lines exclude blank lines and comment-only lines — only lines containing actual code are counted.

**Why it matters:** Long functions are harder to understand at a glance, harder to test thoroughly, and often violate the single responsibility principle. When a function needs scrolling to read in full, it is a candidate for extraction.

**Special case:** Single-expression arrow functions always count as 1 logical line, regardless of how the expression is formatted. A function like `const double = (x) => x * 2` is one logical unit.

**Default thresholds:** warning 25 lines, error 50 lines

### Parameter Count

**What it measures:** The total number of parameters a function accepts, including both runtime parameters and TypeScript generic type parameters.

**Why it matters:** Functions with many parameters are harder to call correctly, harder to test with all combinations, and often indicate that the function is doing too much or that related data should be grouped into an object.

**Default thresholds:** warning 3 parameters, error 6 parameters

### Nesting Depth

**What it measures:** The maximum depth of control flow nesting within a function. Each `if`, `for`, `while`, `switch`, `try`, or similar construct increases the nesting level by one.

**Why it matters:** Deep nesting makes code hard to follow because readers must track multiple conditions simultaneously. Three levels of nesting is generally the readable limit; beyond that, extraction or early returns can flatten the code.

**Default thresholds:** warning 3 levels, error 5 levels

### File Length

**What it measures:** The total number of logical lines in a file (excluding blank lines and comment-only lines).

**Why it matters:** Very long files are hard to navigate and often contain code that belongs in separate modules. A large file is a signal to review whether responsibilities should be split.

**Default thresholds:** warning 300 lines, error 600 lines

### Export Count

**What it measures:** The number of `export` statements in a file, including named exports, default exports, and re-exports.

**Why it matters:** Files that export a large number of symbols often serve as grab-bag modules. This can indicate missing abstractions or that the file is acting as an index for unrelated code. High export count combined with high file length is a strong signal for refactoring.

**Default thresholds:** warning 15 exports, error 30 exports

## Default Thresholds Summary

| Metric | Warning | Error |
|--------|---------|-------|
| Function length (logical lines) | 25 | 50 |
| Parameter count | 3 | 6 |
| Nesting depth | 3 | 5 |
| File length (logical lines) | 300 | 600 |
| Export count | 15 | 30 |

## Why These Thresholds

The defaults are based on common industry guidelines and practical experience:

- **Function length 25/50:** A function that fits in one screen (around 25 lines) is readable without scrolling. 50 lines is a hard upper limit where extraction becomes urgent.
- **Parameters 3/6:** Three parameters is the practical limit for function calls you can understand at a glance. Six is the maximum before callers need to look up the signature every time.
- **Nesting depth 3/5:** Three levels corresponds to the natural complexity of most business logic. Five levels is where humans reliably lose track of the outer conditions.
- **File length 300/600:** A 300-line file is readable in one session. Beyond 600 lines, navigation becomes a significant overhead.
- **Exports 15/30:** A module exporting 15 symbols is already large; 30 is a strong signal of a barrel file or grab-bag module.

All thresholds are configurable to match your team's standards.

## Configuration

Customize structural metric thresholds in `.complexityguard.json`:

```json
{
  "thresholds": {
    "function_length": {
      "warning": 20,
      "error": 40
    },
    "params": {
      "warning": 4,
      "error": 7
    },
    "nesting": {
      "warning": 3,
      "error": 4
    },
    "file_length": {
      "warning": 200,
      "error": 400
    },
    "exports": {
      "warning": 10,
      "error": 20
    }
  }
}
```

**Strict mode** (for new projects aiming for clean architecture):
```json
{
  "thresholds": {
    "function_length": { "warning": 15, "error": 30 },
    "params": { "warning": 2, "error": 4 },
    "nesting": { "warning": 2, "error": 3 }
  }
}
```

**Lenient mode** (for legacy codebases during gradual improvement):
```json
{
  "thresholds": {
    "function_length": { "warning": 50, "error": 100 },
    "params": { "warning": 6, "error": 10 },
    "nesting": { "warning": 5, "error": 8 }
  }
}
```

## See Also

- [CLI Reference](cli-reference.md) — `--metrics` flag to enable/disable structural analysis
- [Halstead Metrics](halstead-metrics.md) — information-theoretic metrics measuring vocabulary and effort
- [Cyclomatic Complexity](cyclomatic-complexity.md) — path-based testability metric
- [Cognitive Complexity](cognitive-complexity.md) — readability and nesting-aware metric
