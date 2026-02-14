// Fixture: Cyclomatic complexity test cases
// Purpose: Validate cyclomatic complexity counting for all decision point types
// Each function has documented expected complexity

// Expected: 1 (no branches)
export function baseline(): number {
  return 42;
}

// Expected: 3 (if + else if)
export function simpleConditionals(x: number): string {
  if (x > 0) {
    return "positive";
  } else if (x < 0) {
    return "negative";
  }
  return "zero";
}

// Expected: 5 (for-of + if + && + if)
export function loopWithConditions(items: any[]): any[] {
  const result: any[] = [];
  for (const item of items) {
    if (item.active && item.valid) {
      if (item.score > 50) {
        result.push(item);
      }
    }
  }
  return result;
}

// Expected: 5 (switch with 4 cases, not counting default)
// In classic mode: base 1 + 4 cases = 5
export function switchStatement(status: string): number {
  switch (status) {
    case "active": return 1;
    case "pending": return 2;
    case "suspended": return 3;
    case "cancelled": return 4;
    default: return 0;
  }
}

// Expected: 3 (catch + if)
export function errorHandling(input: string): any {
  try {
    const parsed = JSON.parse(input);
    if (parsed.valid) {
      return parsed;
    }
    return null;
  } catch (e) {
    return { error: e };
  }
}

// Expected: 3 (|| + ternary)
export function ternaryAndLogical(a: any, b: any): any {
  const value = a || b;
  return value ? "truthy" : "falsy";
}

// Expected: 3 (2x ?? + base)
export function nullishCoalescing(a: any, b: any): any {
  return a ?? b ?? "default";
}

// Expected: complexity of outer does NOT include inner's branches
// Outer: 2 (if)
// Inner: 2 (if)
export function nestedFunctions(x: number): () => string {
  if (x > 0) {
    return () => {
      if (x > 10) {
        return "large";
      }
      return "small";
    };
  }
  return () => "negative";
}

// Arrow function: Expected 2 (if)
export const arrowFunc = (x: number): string => {
  if (x > 0) {
    return "positive";
  }
  return "non-positive";
};

// Expected: 5 (while + if + || + && + base)
export function complexLogical(data: any): boolean {
  let found = false;
  while (data.hasNext()) {
    if (data.current.valid || data.current.forced && data.current.enabled) {
      found = true;
    }
  }
  return found;
}

// Class method: Expected 2 (for-of)
export class DataProcessor {
  process(items: any[]): any[] {
    const results: any[] = [];
    for (const item of items) {
      results.push(item.value);
    }
    return results;
  }
}
