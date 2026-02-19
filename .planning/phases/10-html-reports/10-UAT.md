---
status: complete
phase: 10-html-reports
source: 10-01-SUMMARY.md, 10-02-SUMMARY.md, 10-03-SUMMARY.md
started: 2026-02-19T10:00:00Z
updated: 2026-02-19T10:38:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Generate HTML Report via CLI
expected: Run `zig build run -- --format html --output /tmp/cg-report.html tests/fixtures/` and it produces a valid HTML file at /tmp/cg-report.html. No HTML output appears on stdout — only the file is written.
result: pass

### 2. Dashboard with Health Score and Grade
expected: Opening the HTML report in a browser shows a dashboard section at the top with a project health score (0-100 number) and a letter grade (A-F). Summary stats (files analyzed, functions found) are visible.
result: issue
reported: "pass for the health score, remove the letter grade completely"
severity: major

### 3. Distribution Bar
expected: The dashboard area includes a colored bar showing the breakdown of files by status (healthy/warning/error) as proportional segments.
result: pass

### 4. Top Hotspot Cards
expected: Below the dashboard, up to 5 hotspot cards are displayed showing the worst functions. Each card shows function name, file path, metric scores, and colored violation tags.
result: pass

### 5. Sortable File Table
expected: A file breakdown table is visible with columns (File Path, Health Score, Functions, Worst Violation). Clicking a column header sorts the table by that column.
result: issue
reported: "the table is too wide on mobile viewports. hide the start of the file path, show ellipsis when hiding part of the path, e.g. directory-a/directory-b/file.js -> …ctory-b/file.js"
severity: minor

### 6. Expandable Function Details
expected: Clicking a file row in the table expands it to reveal a nested function detail table showing per-function metrics: Function, Kind, Health, Cyclomatic, Cognitive, Halstead Vol, Halstead Diff, Lines, Params, Nesting.
result: pass

### 7. Treemap Visualization
expected: An SVG treemap is visible where rectangles represent files. Rectangle size corresponds to function count and color corresponds to health score (green=healthy, yellow=warning, red=error). File names appear on sufficiently large tiles.
result: pass

### 8. Bar Chart Visualization
expected: A horizontal bar chart SVG is visible showing files ranked by health score (worst first). Bars are colored by health status.
result: pass

### 9. Dark Mode Support
expected: The report respects system color scheme preference. If your system is in dark mode, the report background is dark with light text. If in light mode, the report has a light background with dark text.
result: pass

## Summary

total: 9
passed: 7
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Dashboard shows numeric health score only (no letter grade per COMP-04 override)"
  status: failed
  reason: "User reported: pass for the health score, remove the letter grade completely"
  severity: major
  test: 2
  artifacts: []
  missing: []

- truth: "File table fits mobile viewports with truncated file paths showing ellipsis"
  status: failed
  reason: "User reported: the table is too wide on mobile viewports. hide the start of the file path, show ellipsis when hiding part of the path, e.g. directory-a/directory-b/file.js -> …ctory-b/file.js"
  severity: minor
  test: 5
  artifacts: []
  missing: []
