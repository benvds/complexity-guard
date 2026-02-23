---
status: diagnosed
phase: 10-html-reports
source: 10-01-SUMMARY.md, 10-02-SUMMARY.md, 10-03-SUMMARY.md
started: 2026-02-19T10:00:00Z
updated: 2026-02-19T10:42:00Z
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
  root_cause: "writeDashboard() calls scoreToGrade() and renders <span class='grade'> with letter grade in health score div"
  artifacts:
    - path: "src/output/html_output.zig"
      issue: "scoreToGrade() at line 239, called at line 443, rendered at lines 457-461; .grade CSS at line 64; test at lines 673-683"
  missing:
    - "Delete scoreToGrade() function (lines 238-245)"
    - "Remove grade variable at line 443"
    - "Remove <span class='grade'> from print at lines 457-461"
    - "Remove .grade CSS rule at line 64"
    - "Delete scoreToGrade test block (lines 673-683)"
  debug_session: ".planning/debug/html-report-letter-grade.md"

- truth: "File table fits mobile viewports with truncated file paths showing ellipsis"
  status: failed
  reason: "User reported: the table is too wide on mobile viewports. hide the start of the file path, show ellipsis when hiding part of the path, e.g. directory-a/directory-b/file.js -> …ctory-b/file.js"
  severity: minor
  test: 5
  root_cause: "CSS .file-row td:first-child uses LTR direction with max-width: 400px — ellipsis clips filename (end) instead of directory prefix (start), and 400px exceeds mobile widths"
  artifacts:
    - path: "src/output/html_output.zig"
      issue: "Line 136: CSS rule needs direction: rtl and unicode-bidi: plaintext; needs mobile breakpoint for max-width"
  missing:
    - "Add direction: rtl; unicode-bidi: plaintext to .file-row td:first-child CSS"
    - "Reduce max-width from 400px to 300px"
    - "Add @media (max-width: 600px) { .file-row td:first-child { max-width: 160px; } } breakpoint"
  debug_session: ".planning/debug/html-file-path-mobile-overflow.md"
