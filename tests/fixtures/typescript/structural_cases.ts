/**
 * Test fixture for structural metric validation.
 * Each function is annotated with expected structural metric values.
 */

// --- Function Length (STRC-01) ---

// shortFunction: function_length=3 (3 code lines, no blanks/comments)
function shortFunction(x: number): number {
  const a = x + 1;
  const b = a * 2;
  return b;
}

// longFunctionWithComments: function_length=5 (only code lines counted)
function longFunctionWithComments(input: string): string {
  // This is a single-line comment - excluded
  const trimmed = input.trim();

  /* This is a block comment
     spanning multiple lines - all excluded */
  const upper = trimmed.toUpperCase();

  // Another comment - excluded
  const result = upper + "!";
  return result;
}

// singleExpressionArrow: function_length=1 (expression body = 1 logical line)
const singleExpressionArrow = (x: number) => x * 2;

// --- Parameter Count (STRC-02) ---

// manyParams: params_count=7 (3 generic + 4 runtime)
function manyParams<T, U, V>(a: T, b: U, c: V, d: number): void {
  console.log(a, b, c, d);
}

// noParams: params_count=0
function noParams(): void {
  return;
}

// destructuredParams: params_count=2 (destructured object = 1, rest = 1)
function destructuredParams({ a, b }: { a: number; b: string }, ...rest: any[]): void {
  console.log(a, b, rest);
}

// --- Nesting Depth (STRC-03) ---

// flatFunction: nesting_depth=0 (no control flow)
function flatFunction(x: number): number {
  const y = x + 1;
  return y;
}

// deeplyNested: nesting_depth=4 (if > for > while > if)
function deeplyNested(items: number[]): number {
  let result = 0;
  if (items.length > 0) {
    for (let i = 0; i < items.length; i++) {
      while (items[i] > 0) {
        if (items[i] % 2 === 0) {
          result += items[i];
        }
        items[i]--;
      }
    }
  }
  return result;
}

// nestedFunctionScope: outer nesting_depth=1 (inner function declaration not counted)
function nestedFunctionScope(x: number): number {
  if (x > 0) {
    // inner function declaration has its own scope - doesn't inflate outer depth
    function inner(y: number): number {
      if (y > 100) {
        if (y > 1000) {
          return y;
        }
      }
      return y;
    }
    return inner(x);
  }
  return 0;
}

// --- Exports (STRC-05) ---

export { shortFunction };
export { longFunctionWithComments, flatFunction };
export default deeplyNested;
export * from "./nonexistent-module";
