// duplication_cases.ts
// Fixture for testing code clone detection.
// Contains annotated duplicate blocks for Type 1 and Type 2 clone testing.

// Clone Group A: identical logic, different names (Type 1 after normalization)
// These two functions should be detected as exact clones.
function processUserData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}

function processItemData(input: string): string {
  const result = input.trim().toLowerCase();
  if (result.length === 0) {
    return "empty";
  }
  return result.split(",").join(";");
}

// Clone Group B: same structure, different identifiers (Type 2 clone)
// After identifier normalization these should hash identically.
function validateEmail(email: string): boolean {
  const trimmed = email.trim();
  if (trimmed.length === 0) {
    return false;
  }
  return trimmed.includes("@");
}

function validatePhone(phone: string): boolean {
  const cleaned = phone.trim();
  if (cleaned.length === 0) {
    return false;
  }
  return cleaned.includes("+");
}

// Unique function: no clone anywhere in this file
function uniqueHelper(): number {
  let sum = 0;
  for (let i = 0; i < 100; i++) {
    sum += Math.pow(i, 2) * Math.random();
  }
  return sum;
}
