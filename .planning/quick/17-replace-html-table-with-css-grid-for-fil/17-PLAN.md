---
phase: quick-17
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/output/html_output.zig
autonomous: true
requirements: [QUICK-17]

must_haves:
  truths:
    - "File breakdown section renders as CSS grid instead of HTML table"
    - "Grid uses column widths 1fr auto auto auto"
    - "Expandable detail rows use HTML details element"
    - "Sorting by column still works"
    - "All existing tests pass (with updated assertions where needed)"
  artifacts:
    - path: "src/output/html_output.zig"
      provides: "CSS grid file table, details-based expandable rows"
      contains: "grid-template-columns: 1fr auto auto auto"
  key_links:
    - from: "CSS grid styles"
      to: "HTML structure in writeFileTable/writeFileRow/writeDetailRow"
      via: "class names"
      pattern: "file-grid|file-row|grid-template-columns"
---

<objective>
Replace the HTML table in the file breakdown section of the HTML report with a CSS grid layout, using `1fr auto auto auto` for column widths. The expandable detail rows should use a `<details>` element instead of the current JS-toggled table row approach.

Purpose: CSS grid provides better responsive behavior and simpler markup than HTML tables for this layout. Using `<details>` elements gives native expand/collapse without custom JS.
Output: Updated `src/output/html_output.zig` with CSS grid file table and `<details>`-based expansion.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@src/output/html_output.zig
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace HTML table with CSS grid and details elements</name>
  <files>src/output/html_output.zig</files>
  <action>
Replace the file table HTML structure and associated CSS/JS in `src/output/html_output.zig`:

**CSS changes (in the CSS constant):**

Remove/replace the table-based `.file-table` styles (lines ~112-148: `.file-table`, `.file-table th`, `.file-table td`, `.file-table tr:last-child td`, `.file-row:hover td`, `.file-row td:first-child`, `.truncate`, `.detail-row`, `.detail-row.expanded`, `.detail-row td`, `.detail-inner`).

Add CSS grid styles:
- `.file-grid` — the grid container: `background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden;`
- `.file-grid-header` — a grid row for column headers: `display: grid; grid-template-columns: 1fr auto auto auto; gap: 0 0.75rem; padding: 0.6rem 0.75rem; font-size: 0.8rem; font-weight: 600; color: var(--muted); border-bottom: 1px solid var(--border); background: var(--bg);` Each child span should be `cursor: pointer; user-select: none; white-space: nowrap;` with the same sort indicator `::after` pseudo-elements as before.
- `.file-row` — each file entry is a `<details>` element. The `<summary>` inside uses: `display: grid; grid-template-columns: 1fr auto auto auto; gap: 0 0.75rem; padding: 0.5rem 0.75rem; font-size: 0.85rem; cursor: pointer; list-style: none; border-bottom: 1px solid var(--border); align-items: center;` Remove the default disclosure triangle: `.file-row summary::-webkit-details-marker { display: none; }` and `.file-row summary::marker { display: none; }` (or `content: ""`)
- `.file-row:hover summary` or `.file-row summary:hover` — `background: color-mix(in srgb, var(--border) 30%, transparent);`
- First child of summary (file path): `font-family: monospace; font-size: 0.8rem; direction: rtl;` with the `.truncate` class as before for RTL ellipsis.
- `.file-row[open]` styles if needed for visual indication.
- `.detail-inner` — keep similar styling: `padding: 0.75rem; background: color-mix(in srgb, var(--border) 15%, transparent); border-bottom: 1px solid var(--border);`
- Keep the `@media (max-width: 600px)` breakpoint for `.truncate` max-width if it exists, applying it to the file path element in the summary.

**HTML structure changes:**

In `writeFileTable` (line 635-659):
- Replace `<table class="file-table" id="file-table">` with `<div class="file-grid" id="file-grid">`
- Replace `<thead>/<tr>/<th>` with a `<div class="file-grid-header">` containing 4 `<span>` elements for the column headers (File Path, Health Score, Functions, Worst Violation). Each span gets an `onclick` calling the updated sort function. Remove `<tbody>`.
- Close with `</div>` instead of `</table>`.
- Update the `sortTable` call to use `'file-grid'` instead of `'file-table'`.

In `writeFileRow` (line 588-632):
- Replace `<tr class="file-row" data-file-id="N" aria-expanded="false">` with nothing — the row is now part of a `<details>` written by the caller or integrated here.
- Actually, combine writeFileRow and writeDetailRow: each file is a `<details class="file-row" data-file-id="N">` element. The `<summary>` contains the 4 grid cells (file path, health score, function count, worst violation) as `<span>` elements. After `</summary>`, the detail content follows directly.
- Remove the `<tr>` and `<td>` tags, replace with `<span>` elements inside `<summary>`.
- Keep `data-value` attributes on the spans for sorting.

In `writeDetailRow` (line 555-585):
- Remove `<tr class="detail-row">` and `<td colspan="4">` wrapper.
- The content is now directly inside the `<details>` element after `</summary>`: just `<div class="detail-inner">` containing the nested function table (which stays as a real `<table class="fn-table">`).

**JS changes (in the JS constant):**

Update `sortTable` function:
- Instead of querying `tbody` and `tr.file-row`, query the grid container and `details.file-row` elements.
- Instead of `querySelectorAll('td')`, query the `<span>` children inside each `<summary>`.
- Re-append sorted `<details>` elements to the grid container (after the header div).
- Update sort indicator logic to target `.file-grid-header span` instead of `thead th`.

Remove the expand/collapse event delegation section (lines ~222-233) since `<details>` elements handle expand/collapse natively. Remove the `aria-expanded` attribute setting.

**Test updates:**

- Update test assertions that check for `"file-table"` to check for `"file-grid"` instead.
- Update assertions checking for `"file-row"` — these should still find `file-row` class on `<details>` elements.
- Update assertions checking for `"detail-row"` — these should now check for `"detail-inner"` or `"file-row"` since the detail is part of the `<details>` element, not a separate row.
- The `"sortTable"` assertion should still pass as the function name doesn't change.
- The `"file table row count"` test: update to count `class="file-row"` occurrences (which are now `<details>` elements) and count `class="detail-inner"` instead of `class="detail-row"`.
  </action>
  <verify>
Run `zig build test` — all tests pass. Generate an HTML report with `zig build run -- --format html --output /tmp/test-report.html tests/fixtures/` and visually inspect that:
1. The file breakdown section uses CSS grid (inspect source for `grid-template-columns: 1fr auto auto auto`)
2. Clicking a file row expands to show function details (native `<details>` behavior)
3. Column header sorting still works
4. No `<table>` element in the file breakdown section (nested fn-table inside details is fine)
  </verify>
  <done>File breakdown section uses CSS grid with `1fr auto auto auto` columns, detail rows use native `<details>` elements, sorting works, all tests pass.</done>
</task>

</tasks>

<verification>
- `zig build test` passes with no failures
- Generated HTML contains `grid-template-columns: 1fr auto auto auto` in CSS
- Generated HTML contains `<details class="file-row"` elements instead of `<tr class="file-row"`
- Generated HTML contains NO `<table class="file-table"` (nested fn-table is acceptable)
- Sort function in JS references `file-grid` container
</verification>

<success_criteria>
- HTML report file table rendered as CSS grid with `1fr auto auto auto` column widths
- Expandable file details use native `<details>` element
- Column sorting still functional
- All existing tests pass (with updated assertions)
</success_criteria>

<output>
After completion, create `.planning/quick/17-replace-html-table-with-css-grid-for-fil/17-SUMMARY.md`
</output>
