---
phase: quick-17
plan: 01
subsystem: html-output
tags: [html, css-grid, details-element, file-breakdown, sorting]
dependency_graph:
  requires: []
  provides: [css-grid-file-table, native-details-expansion]
  affects: [src/output/html_output.zig]
tech_stack:
  added: []
  patterns: [css-grid-layout, html-details-element, native-expand-collapse]
key_files:
  modified:
    - path: src/output/html_output.zig
      role: CSS grid file table, details-based expandable rows, updated sort JS, updated tests
decisions:
  - "CSS grid with 1fr auto auto auto for file breakdown columns (responsive, simpler than table)"
  - "Native <details> element for expand/collapse (no custom JS needed)"
  - "sortTable JS updated to query details.file-row and summary > span children"
  - "detail-inner div replaces detail-row tr as expansion content container"
metrics:
  duration_seconds: 145
  tasks_completed: 1
  files_modified: 1
  completed_date: "2026-02-19"
---

# Quick Task 17: Replace HTML Table with CSS Grid for File Breakdown Summary

CSS grid file breakdown with `1fr auto auto auto` columns and native `<details>` expand/collapse replacing the JS-toggled table row approach.

## What Was Done

Replaced the `<table class="file-table">` structure in the HTML report's file breakdown section with a CSS grid layout using `<div class="file-grid">`. Each file entry is now a `<details class="file-row">` element with a `<summary>` containing the four grid cells as `<span>` elements, and the function detail table inside the `<details>` body.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Replace HTML table with CSS grid and details elements | 99df70f | src/output/html_output.zig |

## Key Changes

**CSS:**
- Removed `.file-table`, `.file-table th`, `.file-table td`, `.file-table tr:last-child td`, `.file-row:hover td`, `.detail-row`, `.detail-row.expanded`, `.detail-row td` styles
- Added `.file-grid` container with `overflow: hidden` and border/radius
- Added `.file-grid-header` using `display: grid; grid-template-columns: 1fr auto auto auto; gap: 0 0.75rem`
- Added `.file-row` as block element with border-bottom for separation
- Added `.file-row > summary` with `display: grid; grid-template-columns: 1fr auto auto auto`
- Added `.file-path` class for monospace RTL path display
- Removed `.file-row > summary` default disclosure triangle with `::marker` and `::-webkit-details-marker`
- Kept `.truncate` for RTL ellipsis with `@media (max-width: 600px)` max-width
- `.detail-inner` now used as direct expansion container (no `<td>` wrapper)

**HTML structure:**
- `<table class="file-table" id="file-table">` → `<div class="file-grid" id="file-grid">`
- `<thead><tr><th>` → `<div class="file-grid-header"><span>`
- Each file: `<tr class="file-row">` + `<tr class="detail-row">` → single `<details class="file-row">` with `<summary>` + `<div class="detail-inner">`
- `<td>` cells → `<span>` elements inside `<summary>` (keep `data-value` for sorting)
- Nested `<table class="fn-table">` inside detail content is unchanged

**JavaScript:**
- `sortTable` updated to query `details.file-row` elements and `summary > span` children
- Sort indicator targets `.file-grid-header span` instead of `thead th`
- Re-appends sorted `<details>` directly to the grid container
- Removed expand/collapse event delegation (native `<details>` handles it)

**Tests:**
- `"file table row count"`: `class="detail-row"` → `class="detail-inner"` assertion
- `"buildHtmlReport basic"`: `"file-table"` → `"file-grid"`, `"detail-row"` → `"detail-inner"`

## Verification

- `zig build test` passes with no failures
- Generated HTML contains `grid-template-columns: 1fr auto auto auto` (verified: 2 occurrences)
- Generated HTML contains `<details class="file-row"` elements (13 files)
- Generated HTML contains NO `<tr class="file-row"` or `<table class="file-table"` elements
- Sort function references `file-grid` container
- `detail-inner` present for all 13 files

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] `src/output/html_output.zig` modified
- [x] Commit 99df70f exists: `feat(quick-17): replace HTML table with CSS grid and details elements in file breakdown`
- [x] All tests pass (`zig build test`)
- [x] Generated HTML verified with key structural assertions
