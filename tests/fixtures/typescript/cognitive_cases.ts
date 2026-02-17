// Fixture: Cognitive complexity test cases (ComplexityGuard rules)
// Purpose: Validate cognitive complexity scoring with ComplexityGuard deviations
//
// ComplexityGuard deviations from SonarSource spec:
//   - Each logical operator (&&, ||, ??) counts as +1 flat individually (not grouped)
//   - ?? counts as +1 flat (like && and ||)
//   - ?. (optional chaining) does NOT increment
//   - Top-level arrow function definitions do NOT add nesting
//   - Arrow function callbacks DO increase nesting depth
//
// Scoring formula:
//   Structural increment: 1 + nesting_level (for control flow nodes)
//   Flat increment: +1 (for else, logical ops, recursion, labeled break/continue)
//
// Each function has a // Expected cognitive: N comment with breakdown

// Expected cognitive: 0
// Breakdown: no branches, no operators, no recursion
export function baseline(): number {
  return 42;
}

// Expected cognitive: 1
// Breakdown: if (+1 structural at nesting 0) = 1
export function singleIf(x: number): string {
  if (x > 0) {
    return "positive";
  }
  return "non-positive";
}

// Expected cognitive: 4
// Breakdown:
//   if (+1 structural at nesting 0) = 1
//   else if: else (+1 flat) + if_continuation (+1 structural at nesting 0) = 2
//   else (+1 flat) = 1
//   Total = 4
export function ifElseChain(x: number): string {
  if (x > 0) {
    return "positive";
  } else if (x < 0) {
    return "negative";
  } else {
    return "zero";
  }
}

// Expected cognitive: 6
// Breakdown:
//   for-of (+1 structural at nesting 0, increases to 1) = 1
//   if (+1+1 structural at nesting 1, increases to 2) = 2
//   if (+1+2 structural at nesting 2) = 3
//   Total = 1 + 2 + 3 = 6
export function nestedIfInLoop(items: any[]): any[] {
  const result: any[] = [];
  for (const item of items) {
    if (item.active) {
      if (item.score > 50) {
        result.push(item);
      }
    }
  }
  return result;
}

// Expected cognitive: 3
// Breakdown:
//   if (+1 structural at nesting 0) = 1
//   && (+1 flat) = 1
//   && (+1 flat) = 1
//   Total = 3
// Note: ComplexityGuard counts EACH operator individually, not per-group
export function logicalOps(a: boolean, b: boolean, c: boolean): boolean {
  if (a && b && c) {
    return true;
  }
  return false;
}

// Expected cognitive: 4
// Breakdown:
//   if (+1 structural at nesting 0) = 1
//   && (+1 flat) = 1
//   || (+1 flat) = 1
//   && (+1 flat) = 1
//   Total = 4
// Note: Mixed operators all count individually
export function mixedLogicalOps(a: boolean, b: boolean, c: boolean): boolean {
  if (a && b || c && a) {
    return true;
  }
  return false;
}

// Expected cognitive: 2
// Breakdown:
//   if (+1 structural at nesting 0) = 1
//   recursion: factorial call (+1 flat) = 1
//   Total = 2
export function factorial(n: number): number {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}

// Expected cognitive: 1
// Breakdown:
//   Top-level arrow does NOT add nesting (user decision: treated like function declaration)
//   if (+1 structural at nesting 0) = 1
//   Total = 1
export const topLevelArrow = (x: number): string => {
  if (x > 0) {
    return "positive";
  }
  return "non-positive";
};

// Expected cognitive: 3
// Breakdown:
//   Arrow callback is structural (+1 at nesting 0, increases nesting to 1) = 1
//   if inside callback (+1+1 structural at nesting 1) = 2
//   Total = 3
export function withCallback(items: number[]): number[] {
  return items.filter((x) => {
    if (x > 0) {
      return true;
    }
    return false;
  });
}

// Expected cognitive: 1
// Breakdown:
//   switch (+1 structural at nesting 0) = 1
//   Individual cases do NOT increment in cognitive complexity
//   Total = 1
export function switchStatement(x: number): string {
  switch (x) {
    case 1:
      return "one";
    case 2:
      return "two";
    case 3:
      return "three";
    default:
      return "other";
  }
}

// Expected cognitive: 1
// Breakdown:
//   try: no increment
//   catch (+1 structural at nesting 0) = 1
//   finally: no increment
//   Total = 1
export function tryCatch(): any {
  try {
    return JSON.parse("{}");
  } catch (e) {
    return null;
  }
}

// Expected cognitive: 3
// Breakdown:
//   ternary (+1 structural at nesting 0, increases nesting to 1) = 1
//   nested ternary (+1+1 structural at nesting 1) = 2
//   Total = 3
export function ternaryNested(x: number): string {
  return x > 0 ? (x > 100 ? "large" : "small") : "negative";
}

// Expected cognitive: 3
// Breakdown:
//   Class methods start at nesting 0
//   for-of (+1 structural at nesting 0, increases nesting to 1) = 1
//   if (+1+1 structural at nesting 1) = 2
//   Total = 3
export class MyClass {
  // Expected cognitive: 3
  classMethod(items: any[]): any[] {
    const result: any[] = [];
    for (const item of items) {
      if (item.valid) {
        result.push(item);
      }
    }
    return result;
  }
}

// Expected cognitive: 10
// Breakdown demonstrates deep nesting penalty escalation:
//   if (+1 at nesting 0, increases to 1) = 1
//   for-of (+1+1 at nesting 1, increases to 2) = 2
//   while (+1+2 at nesting 2, increases to 3) = 3
//   if (+1+3 at nesting 3) = 4
//   Total = 1 + 2 + 3 + 4 = 10
export function deeplyNested(data: any[]): any {
  if (data.length > 0) {
    for (const item of data) {
      while (item.hasMore()) {
        if (item.current.valid) {
          return item.current;
        }
      }
    }
  }
  return null;
}

// Expected cognitive: 7
// Breakdown:
//   outer for-of (+1 structural at nesting 0, increases to 1) = 1
//   inner for-of (+1+1 structural at nesting 1, increases to 2) = 2
//   if (+1+2 structural at nesting 2) = 3
//   break outer (labeled break, +1 flat) = 1
//   Total = 1 + 2 + 3 + 1 = 7
export function labeledBreak(items: any[]): any {
  outer: for (const item of items) {
    for (const sub of item.subs) {
      if (sub.found) {
        break outer;
      }
    }
  }
  return null;
}

// Expected cognitive: 0
// Breakdown:
//   try: no increment
//   finally: no increment
//   throw: no increment
//   return: no increment
//   Total = 0
export function noIncrement(): void {
  try {
    const x = 1;
    void x;
    throw new Error("done");
  } finally {
    // cleanup - no increment
    return;
  }
}
