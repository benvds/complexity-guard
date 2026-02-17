# Cyclomatic Complexity

Cyclomatic complexity counts the number of independent paths through a function. It was introduced by Thomas J. McCabe, Sr. in 1976 as a measure of *testability*: a function with cyclomatic complexity N needs at least N test cases to achieve full branch coverage. High cyclomatic complexity signals that a function does too many things and is hard to test thoroughly.

## How It Works

Every function starts with a base complexity of 1 (representing the single path through an otherwise empty function). Each branch point adds to that base.

ComplexityGuard uses ESLint-aligned counting rules by default, which count modern JavaScript/TypeScript features in addition to classical control flow.

## Counting Rules

### Control Flow (+1 each)

- `if` statements
- `for`, `for-of`, `for-in` loops
- `while` and `do-while` loops
- `catch` clauses
- Ternary expressions `? :`

### Switch Statements

- **Default (per-case):** Each `case` adds +1. A switch with 5 cases adds 5 to complexity.
- **Classic mode (switch-only):** The `switch` itself adds +1 regardless of how many cases it has. Configurable via `switch_case_mode: "switchOnly"`.

### Logical and Nullish Operators (+1 each)

- `&&` — logical AND
- `||` — logical OR
- `??` — nullish coalescing

### Optional Chaining (+1 per `?.`)

- `obj?.prop`, `fn?.()`, `arr?.[i]` — each `?.` adds 1

This makes optional chaining visible in complexity scores, because each `?.` represents a conditional branch in the execution path.

## Default Thresholds

| Level | Threshold |
|-------|-----------|
| Warning | 10 |
| Error | 20 |

The warning threshold of 10 comes from McCabe's original recommendation. The error threshold of 20 aligns with ESLint's `complexity` rule default. Both are configurable via `.complexityguard.json`:

```json
{
  "thresholds": {
    "cyclomatic": {
      "warning": 10,
      "error": 20
    }
  }
}
```

## Example

```typescript
function validateUser(user: User) {         // base: 1
  if (!user.email) {                        // +1 (if)
    return false;
  }

  if (user.role === 'admin' ||              // +1 (if), +1 (||)
      user.role === 'superadmin') {
    return true;
  }

  for (const permission of user.permissions) {  // +1 (for-of)
    if (permission.active && permission.scope === 'write') {  // +1 (if), +1 (&&)
      return true;
    }
  }

  return false;
}
// Total: 7
```

## How It Differs from Cognitive Complexity

Cyclomatic and cognitive complexity measure complementary things:

| | Cyclomatic | Cognitive |
|---|---|---|
| **Measures** | Testability (path count) | Readability (mental effort) |
| **Nesting** | Ignored | Penalized |
| **Origin** | McCabe, 1976 | G. Ann Campbell, SonarSource, 2016 |
| **Question** | "How many tests do I need?" | "How hard is this to understand?" |

A flat sequence of 10 `if` statements scores high on cyclomatic complexity (10 paths to test) but low on cognitive complexity (easy to read). A deeply nested `if` inside three loops may have fewer paths but scores high cognitively. Running both metrics together gives a more complete picture of function quality.

## Attribution

Cyclomatic complexity was introduced by Thomas J. McCabe, Sr. in 1976 in *"A Complexity Measure"* (IEEE Transactions on Software Engineering).

## See Also

- [Cognitive Complexity](cognitive-complexity.md) — measures readability (human comprehension effort)
