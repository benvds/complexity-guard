# Halstead Metrics

Halstead metrics are information-theoretic measurements that quantify the vocabulary diversity and mental effort required to understand a piece of code. Where cyclomatic complexity asks "how many paths are there?", Halstead metrics ask "how mentally dense is this code?".

Halstead metrics were introduced by Maurice Halstead in 1977 in *"Elements of Software Science"*. They are derived entirely from token counts — no control flow analysis needed.

## Base Counts

Halstead metrics begin with four raw counts from the source code:

| Symbol | Name | Description |
|--------|------|-------------|
| `n1` | Distinct operators | Number of unique operator types used |
| `n2` | Distinct operands | Number of unique operand values used |
| `N1` | Total operators | Total count of all operator usages |
| `N2` | Total operands | Total count of all operand usages |

## Derived Metrics

From these four counts, six derived metrics are calculated:

### Vocabulary

```
vocabulary = n1 + n2
```

The number of distinct symbols in the function — how many unique "words" the programmer chose.

### Volume

```
volume = (N1 + N2) × log2(n1 + n2)
```

The information content of the function in bits. A function with high vocabulary and many usages has high volume — it conveys a lot of information and requires more mental processing.

**Default thresholds:** warning 500, error 1000

### Difficulty

```
difficulty = (n1 / 2) × (N2 / n2)
```

How error-prone and hard to write the function is. High difficulty results from many distinct operators combined with heavy reuse of a small set of operands (a pattern common in complex mathematical or parsing code).

**Default thresholds:** warning 10, error 20

### Effort

```
effort = difficulty × volume
```

The total mental effort required to implement or understand the function. This is the most comprehensive single metric — it combines both the information density (volume) and the implementation complexity (difficulty).

**Default thresholds:** warning 5000, error 10000

### Time (estimated)

```
time = effort / 18  (seconds)
```

Halstead's estimate of the time to implement the function, derived empirically. The divisor 18 comes from Stroud's number — the number of elementary mental discriminations per second a human can make. This is a rough approximation.

### Bugs (estimated)

```
bugs = volume / 3000
```

Halstead's estimate of the number of bugs delivered in the function. Functions with higher volume deliver more bugs on average. This is another empirical approximation.

**Default thresholds:** warning 0.5, error 2.0

## What Counts as Operators vs Operands

In JavaScript/TypeScript, ComplexityGuard classifies tokens as follows:

| Category | Operators | Operands |
|----------|-----------|----------|
| **Syntax** | `if`, `for`, `while`, `return`, `=`, `+`, `-`, `*`, `/`, `===`, `!==`, `&&`, `\|\|`, `??`, `?.`, `,`, `.`, `(`, `)` | — |
| **Values** | — | Identifiers, string literals, number literals, boolean literals, `null`, `undefined`, `this` |
| **Declarations** | `function`, `const`, `let`, `var`, `class` | Function/variable names |

The key distinction: **operators are syntax types** (classified by their node type in the AST), **operands are values** (classified by their source text).

### TypeScript-Specific Behavior

TypeScript type annotations, type parameters, and type-only constructs are **excluded** from Halstead counts. This means a TypeScript function and its equivalent JavaScript implementation receive identical Halstead scores. Type information is not considered part of the runtime logic.

- `function greet(name: string): void` — `: string` and `: void` excluded
- `const values: Map<string, number>` — `Map<string, number>` type excluded
- Decorators count as operators (e.g., `@Injectable` adds to n1 and N1)

## Default Thresholds

| Metric | Warning | Error |
|--------|---------|-------|
| Volume | 500 | 1000 |
| Difficulty | 10 | 20 |
| Effort | 5000 | 10000 |
| Bugs | 0.5 | 2.0 |

## Example

Here is a small function with an annotated Halstead breakdown:

```typescript
function clamp(value: number, min: number, max: number): number {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
```

Counting operators and operands (type annotations excluded):

| Token | Type | Unique? |
|-------|------|---------|
| `function` | operator | n1: yes |
| `clamp` | operand | n2: yes |
| `(`, `)` | operators | n1: yes |
| `value` | operand | n2: yes |
| `min` | operand | n2: yes |
| `max` | operand | n2: yes |
| `if` | operator | n1: yes |
| `<` | operator | n1: yes |
| `return` | operator | n1: yes |
| `>` | operator | n1: yes |

Approximate counts for this function:

- `n1` (distinct operators) ≈ 8
- `n2` (distinct operands) ≈ 4 (`clamp`, `value`, `min`, `max`)
- `N1` (total operators) ≈ 12
- `N2` (total operands) ≈ 9

Derived metrics:

- vocabulary = 8 + 4 = **12**
- volume = (12 + 9) × log2(12) ≈ 21 × 3.58 ≈ **75**
- difficulty = (8/2) × (9/4) ≈ 4 × 2.25 ≈ **9**
- effort = 9 × 75 ≈ **675**

This function is well within all thresholds — low volume (75), low difficulty (9), low effort (675).

## Configuration

Customize Halstead thresholds in `.complexityguard.json`:

```json
{
  "thresholds": {
    "halstead_volume": {
      "warning": 400,
      "error": 800
    },
    "halstead_difficulty": {
      "warning": 8,
      "error": 15
    },
    "halstead_effort": {
      "warning": 3000,
      "error": 8000
    },
    "halstead_bugs": {
      "warning": 0.3,
      "error": 1.5
    }
  }
}
```

Lower thresholds catch complexity earlier; higher thresholds are useful for algorithm-heavy code where some density is expected.

## See Also

- [CLI Reference](cli-reference.md) — `--metrics` flag to enable/disable Halstead analysis
- [Structural Metrics](structural-metrics.md) — shape-based metrics complementing Halstead
- [Cyclomatic Complexity](cyclomatic-complexity.md) — path-based testability metric
- [Cognitive Complexity](cognitive-complexity.md) — readability and nesting-aware metric
