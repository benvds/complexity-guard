---
status: complete
phase: 05-console-json-output
source: 05-01-SUMMARY.md, 05-02-SUMMARY.md
started: 2026-02-15T06:10:00Z
updated: 2026-02-15T06:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Console output shows ESLint-style format
expected: Running `zig build run -- tests/fixtures/` shows file paths as headers, with indented problems below showing line:col, severity symbol, warning/error label, function name with complexity value, and "cyclomatic" rule name.
result: pass

### 2. Verbose mode shows all functions
expected: Running `zig build run -- --verbose tests/fixtures/` shows ALL functions including those with ok status (below threshold), not just warnings/errors.
result: pass

### 3. Quiet mode shows minimal output
expected: Running `zig build run -- --quiet tests/fixtures/` shows only the verdict line (e.g. "1 warning") with no per-file details or hotspots.
result: pass

### 4. Project summary with hotspots
expected: Console output includes a summary showing "Analyzed N files, N functions", warning/error counts, and a "Top complexity hotspots" section listing up to 5 functions ranked by complexity with file location.
result: pass

### 5. JSON output with --format json
expected: Running `zig build run -- --format json tests/fixtures/` outputs valid JSON with "version" (1.0.0), "timestamp" (number), "summary" (files_analyzed, total_functions, warnings, errors, status), and "files" array with function details.
result: pass

### 6. Exit code 0 on success
expected: Running `zig build run -- tests/fixtures/; echo $?` shows exit code 0 when no --fail-on flag is set (default ignores warnings).
result: pass

### 7. Exit code 2 with --fail-on warning
expected: Running `zig build run -- --fail-on warning tests/fixtures/; echo $?` returns exit code 2 when warnings are present.
result: pass

### 8. File output with --output flag
expected: Running `zig build run -- --format json --output /tmp/cg-test.json tests/fixtures/` writes JSON to the specified file. The file contains valid JSON matching the --format json output.
result: pass

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0

## Gaps

- show the actual function name instead of just `<function>` in the eslint like output
