---
status: complete
phase: 11-duplication-detection
source: 11-01-SUMMARY.md, 11-02-SUMMARY.md, 11-03-SUMMARY.md, 11-04-SUMMARY.md
started: 2026-02-22T19:00:00Z
updated: 2026-02-22T19:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Enable Duplication via --duplication Flag
expected: Running `zig-out/bin/complexity-guard --duplication tests/fixtures/` completes successfully and console output includes a "Duplication" section with clone groups and file percentages.
result: pass

### 2. Console Duplication Output Details
expected: The Duplication section shows clone groups as "Clone group (N tokens): path:line, path:line" format, file duplication percentages with [OK]/[WARNING]/[ERROR] indicators, and a project duplication summary line.
result: pass

### 3. JSON Duplication Output
expected: Running with `--duplication --format json` produces JSON containing a "duplication" object with "enabled": true, "clone_groups" array, and "files" array with per-file duplication percentages.
result: pass

### 4. SARIF Duplication Output
expected: Running with `--duplication --format sarif` produces SARIF JSON that includes a "complexity-guard/duplication" rule and results with relatedLocations arrays pointing to clone instances.
result: pass

### 5. HTML Duplication Output
expected: Running with `--duplication --format html` produces HTML containing a duplication section with a clone groups table, file duplication list with percentage bars, and an adjacency heatmap.
result: pass

### 6. No Duplication Without Flag
expected: Running `zig-out/bin/complexity-guard tests/fixtures/` (without --duplication) produces NO duplication section in the output — no "Duplication" header, no clone groups, no duplication percentages.
result: pass

### 7. Health Score Integration
expected: When --duplication is enabled, file health scores change compared to without --duplication (duplication adds a 5th metric at 0.20 weight, re-normalizing other weights).
result: pass

### 8. All Tests Pass
expected: Running `zig build test` passes with zero failures, including all duplication-related unit tests.
result: pass

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
