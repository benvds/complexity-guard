---
status: complete
phase: 09-sarif-output
source: 09-01-SUMMARY.md, 09-02-SUMMARY.md
started: 2026-02-18T07:00:00Z
updated: 2026-02-18T07:03:00Z
---

## Current Test

[testing complete]

## Tests

### 1. SARIF Output Format
expected: Running `zig build run -- --format sarif tests/fixtures/` produces valid JSON with SARIF 2.1.0 envelope: `$schema` pointing to the SARIF schema URL, `version` of `"2.1.0"`, and a `runs` array with at least one run containing `tool.driver.name` of `"ComplexityGuard"`.
result: issue
reported: "pass, but the informationUri points to https://github.com/AstroTechDev/complexity-guard, should this point to a spec? it should at least point to the correct repo: github.com/benvds/complexity-guard"
severity: minor

### 2. SARIF Rule Definitions
expected: The SARIF output contains all 10 rule definitions in `runs[0].tool.driver.rules`. Each rule has an `id` (e.g., `CG0001`), `shortDescription`, `fullDescription`, and `helpUri`.
result: pass

### 3. SARIF Violation Results
expected: The SARIF `runs[0].results` array contains entries for metric violations found in the fixtures. Each result has a `ruleId`, `level` (warning or error), `message.text` describing the violation, and `locations[0].physicalLocation` with `artifactLocation.uri` and `region` containing `startLine` and `startColumn`.
result: pass

### 4. SARIF Column Indexing
expected: All `startColumn` values in SARIF results are 1-indexed (minimum value of 1, not 0). If a function starts at column 0 internally, SARIF output shows column 1.
result: pass

### 5. SARIF Metrics Filtering
expected: Running with `--format sarif --metrics cyclomatic` produces SARIF results only for cyclomatic complexity violations — no cognitive, halstead, or structural violations appear in the results array. All 10 rules still appear in `driver.rules`.
result: pass

### 6. SARIF Documentation Page
expected: `docs/sarif-output.md` exists and contains a Quick Start section, a GitHub Actions workflow YAML block, a rule reference table listing all 10 rules, and severity mapping information.
result: pass

## Summary

total: 6
passed: 5
issues: 1
pending: 0
skipped: 0

## Gaps

- truth: "SARIF informationUri should point to the correct repository URL"
  status: failed
  reason: "User reported: pass, but the informationUri points to https://github.com/AstroTechDev/complexity-guard, should this point to a spec? it should at least point to the correct repo: github.com/benvds/complexity-guard"
  severity: minor
  test: 1
  artifacts: []
  missing: []
