# Phase 5: Console & JSON Output - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Display analysis results in two formats: human-readable console output for developers and machine-readable JSON for CI pipelines. Includes verbosity modes (default, --verbose, --quiet), exit code mapping, and graceful handling of null/future metrics. SARIF and HTML output are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Console formatting
- Default view shows only functions exceeding warning/error thresholds — clean functions are skipped
- Threshold indicators use symbols with color: checkmark for ok, warning symbol for warnings, X for errors
- Project summary at the end includes: files analyzed, functions found, warning/error counts, pass/fail verdict, plus top 3-5 worst functions by complexity as hotspot highlights
- ESLint-style output layout: results grouped by file path, problem functions indented underneath, summary line at bottom

### Claude's Discretion
- Verbosity mode details (what --verbose adds, what --quiet removes)
- Exit code mapping (which codes for which conditions)
- JSON schema structure and field naming
- Color detection and --no-color fallback
- Handling of null/future metrics in display (-- placeholder vs omission)

</decisions>

<specifics>
## Specific Ideas

- ESLint output style reference: file path as header, indented problems below, summary at bottom
- Existing CLI personality is ripgrep-style compact — console output should feel consistent but ESLint grouping fits better for multi-function results
- Symbols (checkmark/warning/X) chosen for accessibility alongside color

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-console-json-output*
*Context gathered: 2026-02-14*
