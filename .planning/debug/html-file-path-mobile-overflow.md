---
status: resolved
trigger: "file breakdown table too wide on mobile - long file paths cause horizontal overflow"
created: 2026-02-19T00:00:00Z
updated: 2026-02-19T00:00:00Z
---

## Current Focus

hypothesis: File path cell in .file-table uses max-width + overflow:hidden + text-overflow:ellipsis but truncates from the END, not the start. On narrow viewports the cell still overflows because direction is not set to rtl.
test: Read CSS and writeFileRow HTML rendering
expecting: Confirmed: no direction:rtl, no ltr reset for the cell
next_action: DIAGNOSED - ready for fix

## Symptoms

expected: File paths in the File Breakdown table truncate from the start, keeping the filename (end of path) visible, with an ellipsis character at the left
actual: File paths overflow horizontally on mobile viewports; long paths push the table wider than the viewport
errors: none (visual bug)
reproduction: Open HTML report on mobile viewport with long file paths like src/deeply/nested/directory/file.ts
started: present in current implementation

## Eliminated

- hypothesis: No CSS truncation at all on the file path cell
  evidence: Line 136 has max-width:400px, overflow:hidden, text-overflow:ellipsis, white-space:nowrap - truncation IS present
  timestamp: 2026-02-19

## Evidence

- timestamp: 2026-02-19
  checked: CSS constant, line 136
  found: ".file-row td:first-child { font-family: monospace; font-size: 0.8rem; max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }"
  implication: Truncation is end-based (LTR default). On small viewports max-width:400px may still be too wide. No direction:rtl means ellipsis appears at the END, hiding the filename instead of the directory prefix.

- timestamp: 2026-02-19
  checked: writeFileRow function, lines 598-642
  found: File path written as plain text inside <td> with no wrapping span or inline style. The <td> inherits the .file-row td:first-child CSS rule.
  implication: The fix is entirely CSS-side. No HTML structure change needed in writeFileRow.

- timestamp: 2026-02-19
  checked: Mobile breakpoints in CSS
  found: Only two breakpoints exist: @media (max-width:700px) for .dashboard and @media (max-width:800px) for .visualizations. No responsive rule for .file-table or .file-row td:first-child.
  implication: max-width:400px is a fixed pixel value - on a 375px-wide mobile screen the column alone is wider than the viewport.

- timestamp: 2026-02-19
  checked: direction:rtl usage elsewhere
  found: Not used anywhere in the CSS block.
  implication: No precedent; must add it fresh.

## Resolution

root_cause: |
  The file path cell (.file-row td:first-child, line 136 of src/output/html_output.zig) applies
  text-overflow:ellipsis with the default LTR text direction. This has two problems:
  1. Ellipsis appears at the END of the path, hiding the filename and keeping the less-useful
     directory prefix visible - the opposite of the desired behavior.
  2. max-width:400px is a fixed pixel cap that is wider than typical mobile viewports (320-390px),
     so the table still overflows horizontally on small screens.

fix: |
  Change the CSS rule for .file-row td:first-child (line 136 of the CSS constant in
  src/output/html_output.zig) to:
    - Remove or reduce max-width (or make it relative, e.g. max-width:50vw is an option, but
      the simpler approach is to let the column be constrained by table layout)
    - Add direction:rtl so text-overflow:ellipsis clips from the LEFT (start of path)
    - Add a wrapping <span dir="ltr"> inside the <td> if needed to keep the text itself LTR
      (so slashes still appear correctly) while the overflow direction is RTL

  Minimal CSS-only fix (no HTML change needed):
    OLD: max-width: 400px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    NEW: max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
         direction: rtl; unicode-bidi: plaintext;

  The direction:rtl trick causes the browser to overflow from the left side, so the ellipsis
  appears at the start and the rightmost characters (the filename) remain visible.
  unicode-bidi:plaintext keeps the characters in their natural order.

  For the table to not overflow on mobile, also add a responsive rule:
    @media (max-width: 600px) {
      .file-row td:first-child { max-width: 160px; }
    }

verification: empty
files_changed:
  - src/output/html_output.zig
