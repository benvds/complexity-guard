---
status: complete
phase: 06-cognitive-complexity
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md]
started: 2026-02-17T10:00:00Z
updated: 2026-02-17T10:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Console shows cognitive scores
expected: Running `zig build run -- tests/fixtures/typescript/cognitive_cases.ts` shows each function with both metrics on the same line in format like `Function 'name' cyclomatic N cognitive N`
result: pass

### 2. Cognitive hotspot list appears separately
expected: The console summary shows two separate hotspot lists: "Top cyclomatic hotspots:" and "Top cognitive hotspots:", each sorted independently by their respective metric
result: pass

### 3. Worst-of-both status displayed
expected: A function that has ok cyclomatic but warning/error cognitive shows the warning/error indicator (symbol and severity word), not ok. Run against the cognitive fixture to see functions with varying scores.
result: pass

### 4. JSON output has cognitive values
expected: Running `zig build run -- --format json tests/fixtures/typescript/cognitive_cases.ts` produces JSON where each function object has a non-null `cognitive` field with a numeric value
result: pass

### 5. Exit code reflects cognitive violations
expected: Running against a file with high cognitive complexity (above error threshold 25) returns a non-zero exit code. Check with `echo $?` after running.
result: pass

### 6. Cognitive docs page exists
expected: `docs/cognitive-complexity.md` exists, explains what cognitive complexity measures, mentions SonarSource and G. Ann Campbell, and documents ComplexityGuard's deviations (individual operator counting)
result: pass

### 7. Cyclomatic docs page exists
expected: `docs/cyclomatic-complexity.md` exists, explains what cyclomatic complexity measures, mentions McCabe, and cross-references the cognitive complexity page
result: pass

### 8. README updated with cognitive complexity
expected: README.md mentions cognitive complexity in the features list, shows example output with side-by-side format, and links to both docs pages
result: pass

### 9. All tests pass
expected: Running `zig build test` passes with zero failures — all existing tests plus new cognitive complexity tests
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0

## Gaps

[none]
