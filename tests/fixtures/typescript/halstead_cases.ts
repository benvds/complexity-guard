// Halstead Metrics Test Fixture
// Each function is annotated with expected Halstead base counts and derived metrics.
// TypeScript type annotations are excluded from all counts (TS scores same as equivalent JS).

// ─── simpleAssignment ───────────────────────────────────────────────────────
// const result = x + 1; return result;
// Operators: {=, +, return}  n1=3, N1=3
// Operands:  {result, x, 1} n2=3, N2=4 (result appears twice)
// Vocabulary: n=6, Length: N=7
// Volume: 7 * log2(6) ≈ 18.09
// Difficulty: (3/2) * (4/3) = 2.0
// Effort: 18.09 * 2.0 ≈ 36.18
// Time: 36.18 / 18 ≈ 2.01s
// Bugs: 18.09 / 3000 ≈ 0.006
function simpleAssignment(x: number): number {
  const result = x + 1;
  return result;
}

// ─── withTypeAnnotations ────────────────────────────────────────────────────
// Equivalent JS: function withTypeAnnotations(age) { return age > 0; }
// TypeScript types (: number, : boolean) are excluded from counts.
// Operators: {return, >}  n1=2, N1=2
// Operands:  {age, 0}    n2=2, N2=2
// Vocabulary: n=4, Length: N=4
// Volume: 4 * log2(4) = 8.0
// Difficulty: (2/2) * (2/2) = 1.0
function withTypeAnnotations(age: number): boolean {
  return age > 0;
}

// ─── emptyFunction ──────────────────────────────────────────────────────────
// Empty body: n1=0, n2=0, N1=0, N2=0
// All derived metrics = 0 (no panic)
function emptyFunction(): void {}

// ─── singleExpressionArrow ──────────────────────────────────────────────────
// const add = (a, b) => a + b;
// Operators: {=, +}     n1=2, N1=2
// Operands:  {add, a, b} n2=3, N2=5 (a and b each appear twice)
// Vocabulary: n=5, Length: N=7
// Volume: 7 * log2(5) ≈ 16.25
const singleExpressionArrow = (a: number, b: number): number => a + b;

// ─── complexLogic ───────────────────────────────────────────────────────────
// Multiple operator types: logical, comparison, assignment
// Exercises &&, ||, ===, return, if, else
// Expected: many distinct operators with various types
function complexLogic(x: number, y: number, flag: boolean): string {
  if (x > 0 && y > 0) {
    return "positive";
  } else if (x === 0 || flag) {
    return "zero-or-flag";
  } else {
    return "negative";
  }
}

// ─── decoratorCase ──────────────────────────────────────────────────────────
// Decorators (@) count as operators (locked decision).
// The @ symbol is an operator for each decorator applied.
// class decorator case — analyzer finds methods inside class
class ServiceClass {
  private value: number = 0;

  processValue(input: number): number {
    const doubled = input * 2;
    return doubled + this.value;
  }
}

// ─── withNullishAndOptional ─────────────────────────────────────────────────
// Tests ?? operator counting
function withNullishAndOptional(x: number | null): number {
  return x ?? 0;
}

// ─── withTernary ────────────────────────────────────────────────────────────
// ternary_expression adds "?:" as one operator (special case).
// Leaf ? and : tokens are skipped.
function withTernary(x: number): string {
  return x > 0 ? "positive" : "negative";
}
