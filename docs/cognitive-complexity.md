# Cognitive Complexity

Cognitive complexity measures how difficult code is to *understand* — not how many paths exist through it. Where cyclomatic complexity counts branches for testability, cognitive complexity penalizes the mental effort required to read and reason about code. The more nesting, the higher the cost.

Cognitive complexity was created by G. Ann Campbell at SonarSource in 2016, addressing a core limitation of cyclomatic complexity: a deeply nested `if` inside three loops is much harder to understand than a flat sequence of `if` statements, even if both have the same branch count.

## How It Works

Cognitive complexity builds up a score through three types of increments:

### Structural Increments (nesting-aware)

Control flow structures that introduce nesting add `1 + current_nesting_depth`. They also increase the nesting level for their body:

- `if`, `else if`, `else`
- `for`, `for-of`, `for-in`, `while`, `do-while`
- `switch`
- `catch`
- Ternary expressions `? :`
- Arrow function callbacks (not top-level arrow functions)

An `if` at the top level costs 1. The same `if` nested inside a `for` loop costs 2. Nest it two levels deep and it costs 3.

### Flat Increments (+1 regardless of nesting)

These add exactly 1, regardless of how deeply nested they are:

- `else` and `else if` clauses
- Logical operators: `&&`, `||`, `??` (each counts +1 individually)
- Recursive calls
- Labeled `break` and `continue`

### What Does Not Count

These constructs do not contribute to cognitive complexity:

- `try` blocks
- `finally` blocks
- Optional chaining `?.`
- `throw` and `return` statements
- Individual `switch` cases (the `switch` itself counts)

## ComplexityGuard Deviations from SonarSource

ComplexityGuard follows the SonarSource specification with two intentional differences:

**Logical operators:** Each `&&`, `||`, and `??` counts as +1 individually. SonarSource groups consecutive same-operator sequences (e.g., `a && b && c`) as a single +1. ComplexityGuard's approach is simpler and more predictable: each operator is counted.

**Top-level arrow functions:** `const fn = () => {}` at module scope does not add nesting. It is treated like a function declaration. Arrow functions used as callbacks (passed as arguments, stored in objects) do add structural increments as expected.

## Default Thresholds

| Level | Threshold |
|-------|-----------|
| Warning | 15 |
| Error | 25 |

These match SonarSource's recommendations. Both thresholds are configurable via `.complexityguard.json`:

```json
{
  "thresholds": {
    "cognitive": {
      "warning": 15,
      "error": 25
    }
  }
}
```

## Example

```typescript
function processOrder(order: Order) {       // nesting: 0
  if (order.items.length === 0) {           // +1 (if at depth 0)
    return;
  }

  for (const item of order.items) {        // +1 (for at depth 0), nesting: 1
    if (item.inStock) {                     // +2 (if at depth 1)
      if (item.discount > 0) {              // +3 (if at depth 2)
        applyDiscount(item);
      } else {                              // +1 (else, flat)
        chargeFullPrice(item);
      }
    }
  }
}
// Total: 8
```

A function scoring above 15 becomes difficult to understand at a glance and is a candidate for refactoring.

## Attribution

Cognitive complexity was created by G. Ann Campbell. See the [original whitepaper](https://www.sonarsource.com/docs/CognitiveComplexity.pdf) for the complete specification.

## See Also

- [Cyclomatic Complexity](cyclomatic-complexity.md) — measures testability (independent code paths)
