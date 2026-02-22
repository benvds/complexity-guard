---
status: testing
phase: 13-gap-closure-pipeline-wiring
source: 13-01-SUMMARY.md
started: 2026-02-22T12:00:00Z
updated: 2026-02-22T12:00:00Z
---

## Current Test

number: 1
name: Cyclomatic thresholds from config file
expected: |
  Create a config file with custom cyclomatic thresholds (e.g., warning: 15, error: 30).
  Run `complexity-guard` against a TypeScript file using that config.
  The output should use those custom thresholds instead of defaults (warning: 10, error: 20).
  Functions exceeding warning=15 should show as warnings; functions exceeding error=30 should show as errors.
awaiting: user response

## Tests

### 1. Cyclomatic thresholds from config file
expected: Create a config file with custom cyclomatic thresholds (e.g., warning: 15, error: 30). Run complexity-guard against a TypeScript file using that config. The output should use those custom thresholds instead of defaults (10/20). Functions exceeding the custom thresholds should be flagged accordingly.
result: [pending]

### 2. --metrics flag gates exit codes
expected: Run `complexity-guard --metrics cyclomatic` against files that have both cyclomatic AND halstead violations. The exit code should only reflect cyclomatic violations — halstead violations should be ignored for exit code purposes. Without --metrics, all violations count.
result: [pending]

### 3. --no-duplication skips duplication detection
expected: Run `complexity-guard --no-duplication` against files with duplicated code. Duplication analysis should be completely skipped — no duplication results in the output, regardless of config file settings or --metrics flags.
result: [pending]

### 4. --save-baseline includes duplication weight
expected: Run `complexity-guard --save-baseline`. The generated config file should include a `"duplication": 0.20` entry in the weights section alongside the other metric weights.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0

## Gaps

[none yet]
