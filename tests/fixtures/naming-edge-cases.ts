// Fixture: Function naming edge cases
// Purpose: Validate rich function name extraction for all naming patterns
// Used by: src/metrics/cyclomatic.zig naming tests

// Baseline: regular named function — should show "myFunc"
function myFunc() {
  return 1;
}

// Variable-assigned arrow — should show "handler"
const handler = () => {
  return 2;
};

// Class methods — should show "Foo.bar" and "Foo.baz" (static)
class Foo {
  bar() {
    return 3;
  }

  static baz() {
    return 4;
  }
}

// Object literal methods — should show key name "process" (direct property)
const obj = {
  handler: () => {
    return 5;
  },
  process() {
    return 6;
  },
};

// Anonymous callbacks — should show "map callback" and "forEach callback"
const items = [1, 2, 3];
items.map(() => {
  return items.length;
});
items.forEach(() => {
  return items.length;
});

// Top-level addEventListener — should show "click handler" (top-level scope only)
// Note: addEventListener inside a function body is scope-isolated and not discovered separately
declare const document: any;
document.addEventListener("click", () => {
  return 7;
});

// Default export function — should show "default export"
export default function () {
  return 8;
}
