---
status: resolved
phase: 07-halstead-structural-metrics
source: 07-01-SUMMARY.md, 07-02-SUMMARY.md, 07-03-SUMMARY.md, 07-04-SUMMARY.md
started: 2026-02-17T10:30:00Z
updated: 2026-02-17T12:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Halstead metrics in verbose console output
expected: Running `zig-out/bin/complexity-guard --verbose <file>` shows Halstead annotations per function (e.g., `[halstead vol N]`) alongside cyclomatic/cognitive scores.
result: pass

### 2. Structural metrics in verbose console output
expected: Running `zig-out/bin/complexity-guard --verbose <file>` shows structural annotations per function (e.g., `[length N] [params N] [depth N]`).
result: pass

### 3. Halstead volume hotspots in summary
expected: Console output summary section includes a "Top Halstead Volume" hotspots list showing the highest-volume functions.
result: pass

### 4. JSON output includes Halstead fields
expected: Running with `--format json` produces JSON where each function has Halstead fields populated with real numbers (halstead_volume, halstead_difficulty, halstead_effort, halstead_bugs, etc.) — not null.
result: pass

### 5. JSON output includes structural fields
expected: Running with `--format json` produces JSON where each function has structural fields (line_count, params_count, nesting_depth) as real numbers and each file has file_length and export_count.
result: pass

### 6. --metrics flag filters output
expected: Running with `--metrics cyclomatic` shows only cyclomatic complexity — no Halstead or structural metrics appear in the output.
result: issue
reported: "when the metrics are filtered also filter out the top hotspots for that metrics, if i filter for cyclomatic now i see top hotspots for other metrics as well while they also should be hidden"
severity: pass

### 7. Exit code reflects all metric families
expected: If a function exceeds a Halstead or structural threshold (e.g., low params threshold), the tool exits with non-zero code even if cyclomatic/cognitive are fine.
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0

## Gaps

- truth: "When --metrics filters to specific families, summary hotspot sections for non-selected metrics should be hidden"
  status: resolved
  reason: "User reported: when the metrics are filtered also filter out the top hotspots for that metrics, if i filter for cyclomatic now i see top hotspots for other metrics as well while they also should be hidden"
  severity: minor
  test: 6
  root_cause: "parsed_metrics is never passed to the output layer. OutputConfig in console.zig has no field for selected metrics. formatSummary unconditionally renders all hotspot sections (cyclomatic, cognitive, Halstead)."
  artifacts:
    - path: "src/output/console.zig"
      issue: "OutputConfig lacks metrics filter field; formatSummary (lines 286-419) renders all hotspot sections unconditionally; formatFileResults renders all metric details unconditionally"
    - path: "src/main.zig"
      issue: "parsed_metrics never passed to formatSummary or formatFileResults call sites (lines 395-422)"
  missing:
    - "Add selected_metrics field to OutputConfig in console.zig"
    - "Pass parsed_metrics to OutputConfig in main.zig"
    - "Gate hotspot sections in formatSummary with isMetricEnabled check"
    - "Gate per-function metric details in formatFileResults with metrics filter"
  debug_session: ".planning/debug/metrics-flag-hotspot-filter.md"
