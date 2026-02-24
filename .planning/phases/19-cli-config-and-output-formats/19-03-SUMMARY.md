---
phase: 19-cli-config-and-output-formats
plan: 03
subsystem: rust-output
tags: [output, sarif, html, minijinja, serde, camelCase]
dependency_graph:
  requires: [19-02-console-json-output, 19-01-cli-args-config]
  provides: [sarif-output-renderer, html-output-renderer, all-four-format-dispatch]
  affects: [19-04]
tech_stack:
  added: [minijinja-2]
  patterns: [hand-rolled-sarif-structs, include_str-asset-embedding, minijinja-context-rendering, format-dispatch-to-file]
key_files:
  created:
    - rust/src/output/sarif_output.rs
    - rust/src/output/html_output.rs
    - rust/src/output/assets/report.css
    - rust/src/output/assets/report.js
    - rust/src/output/assets/report.html
  modified:
    - rust/src/output/mod.rs
    - rust/src/main.rs
    - rust/Cargo.toml
decisions:
  - "Hand-rolled SARIF structs with #[serde(rename)] per field — avoids serde-sarif pre-1.0 crate per STATE.md recommendation"
  - "minijinja template for HTML uses context! macro with pre-computed display values — avoids Zig-style string concatenation logic in template"
  - "CSS and JS extracted verbatim from Zig html_output.zig via Python extraction script — maintains parity with Zig binary"
  - "Duplication section in HTML uses {% if duplication %} conditional — absent when None passed"
  - "Test assertions for duplication absent check class=\"duplication-section\" not CSS class names (CSS always embedded)"
metrics:
  duration: 6min
  completed: 2026-02-24
  tasks_completed: 2
  files_created: 5
  files_modified: 3
  tests_added: 19
  total_tests: 181
---

# Phase 19 Plan 03: SARIF and HTML Output Renderers Summary

SARIF 2.1.0 output with hand-rolled serde structs and all 11 rule definitions, plus self-contained HTML report with CSS/JS extracted verbatim from Zig source and rendered via minijinja template.

## What Was Built

### Task 1: SARIF 2.1.0 output renderer (commit bf691af)

**`rust/src/output/sarif_output.rs`** — `render_sarif(files, duplication, config)` producing SARIF 2.1.0 output accepted by GitHub Code Scanning.

- All 11 rule definitions matching Zig sarif_output.zig exactly: cyclomatic (0), cognitive (1), halstead-volume (2), halstead-difficulty (3), halstead-effort (4), halstead-bugs (5), line-count (6), param-count (7), nesting-depth (8), health-score (9), duplication (10)
- SARIF structs use `#[serde(rename)]` for all camelCase SARIF field names: `$schema`, `informationUri`, `shortDescription`, `fullDescription`, `helpUri`, `defaultConfiguration`, `ruleId`, `ruleIndex`, `physicalLocation`, `artifactLocation`, `startLine`, `startColumn`, `endLine`, `relatedLocations`
- `render_sarif()` reuses `function_violations()` from console.rs for threshold violation detection
- Duplication results serialized with `relatedLocations` for each clone instance beyond the primary
- Schema URL: `https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json`
- 10 unit tests: JSON validity, schema URL, version "2.1.0", 11 rules, rule IDs in order, camelCase fields, results generated for violations, no results for ok functions, levels match severity (error/warning)

**`rust/src/output/mod.rs`** — Updated to export `sarif_output` and `html_output`, re-export `render_sarif` and `render_html`.

### Task 2: Self-contained HTML report (commit d651630)

**`rust/src/output/assets/report.css`** — 221-line CSS extracted verbatim from Zig html_output.zig. Includes dark mode via `prefers-color-scheme`, score panels, hotspot cards, file grid, function table, metric bars, score badges, visualization panels, duplication section classes.

**`rust/src/output/assets/report.js`** — 36-line JS extracted verbatim from Zig html_output.zig. Implements `window.sortTable(gridId, colIndex, type)` for sorting the file grid by column.

**`rust/src/output/assets/report.html`** — minijinja template producing the same HTML structure as the Zig version:
- `<!DOCTYPE html>` with embedded `<style>{{ css }}</style>` and `<script>{{ js }}</script>`
- Header with title and files analyzed / elapsed time
- Dashboard section: health score panel (score, distribution bar, summary stats), top hotspots panel (up to 5 worst functions with violation tags)
- File breakdown grid: sortable headers (sortTable), expandable `<details>` rows with function table
- Conditional `{% if duplication %}` section with project duplication percentage and clone group table
- Footer with tool version and timestamp

**`rust/src/output/html_output.rs`** — `render_html(files, duplication, config, elapsed_ms)`:
- `CSS`, `JS`, `TEMPLATE` constants via `include_str!("assets/...")`
- Builds minijinja `Environment`, adds template, renders with full context
- Context includes: css, js, project_score, distribution percentages, hotspots (sorted ascending by health_score, up to 5), per-file contexts with worst_status, per-function contexts with metric bars and class assignments
- Duplication context: None maps to falsy in minijinja, triggering `{% if duplication %}` to not render
- 9 unit tests: DOCTYPE, embedded CSS (style block + prefers-color-scheme), embedded JS (script block + sortTable), no external URLs, duplication section present/absent, file path, function name, branding

**`rust/src/main.rs`** — Full four-format dispatch:
- `"json"` → `render_json()`
- `"sarif"` → `render_sarif()`
- `"html"` → `render_html()`
- `"console"` (default) → `render_console()` writes directly to stdout
- `--output path` → writes rendered string to file instead of stdout (for json/sarif/html)

## Verification Results

- `cargo build` — compiles without warnings
- `cargo test` — 181 tests pass (173 lib + 8 integration)
- SARIF output: 10 tests pass — valid JSON, correct schema URL "2.1.0", 11 rules, camelCase field names
- HTML output: 9 tests pass — DOCTYPE, embedded CSS/JS, no external URLs, conditional duplication section
- All four format dispatch branches wired in main.rs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test assertion for duplication section absent**
- **Found during:** Task 2
- **Issue:** Initial test checked `!output.contains("duplication-section")` but the CSS is always embedded in the output and contains `.duplication-section` selector. The test was checking CSS content, not HTML structure.
- **Fix:** Changed assertion to check `!output.contains("class=\"duplication-section\"")` which only appears in the HTML section element, not in CSS.
- **Files modified:** `rust/src/output/html_output.rs`
- **Commit:** d651630

## Self-Check: PASSED

- `rust/src/output/sarif_output.rs` — FOUND
- `rust/src/output/html_output.rs` — FOUND
- `rust/src/output/assets/report.css` — FOUND
- `rust/src/output/assets/report.js` — FOUND
- `rust/src/output/assets/report.html` — FOUND
- Task 1 commit bf691af — FOUND
- Task 2 commit d651630 — FOUND
- 181 tests pass (173 lib + 8 integration, cargo test confirms)
- `cargo build` clean with no warnings
