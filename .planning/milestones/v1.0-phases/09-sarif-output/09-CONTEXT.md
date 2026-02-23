# Phase 9: SARIF Output - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Generate SARIF 2.1.0 output accepted by GitHub Code Scanning, mapping complexity metric violations to inline PR annotations. Users invoke `--format sarif` and pipe/redirect the output for upload. No new metrics or analysis capabilities — this phase adds an output format only.

</domain>

<decisions>
## Implementation Decisions

### Rule mapping
- Granular sub-rules: separate SARIF rule per sub-metric (e.g., `complexity-guard/cyclomatic`, `complexity-guard/cognitive`, `complexity-guard/halstead-volume`, `complexity-guard/halstead-difficulty`, `complexity-guard/nesting-depth`, `complexity-guard/param-count`)
- RuleId format: `complexity-guard/metric-name` (namespaced, clear origin)
- Severity: direct mapping from existing thresholds — warning threshold triggers SARIF `warning`, error threshold triggers SARIF `error`
- Health score produces a file-level SARIF result when below baseline

### Result granularity
- One SARIF result per violated metric per function (a function violating 3 metrics = 3 separate results)
- Violations only — passing functions do not produce SARIF results
- Location: primary location on function declaration line, with SARIF `region` covering the full function body span
- Baseline ratchet failures (health score regression) also produce SARIF results at file level

### Message content
- Violation messages: score + threshold format — e.g., "Cyclomatic complexity is 15 (warning threshold: 10, error threshold: 20)"
- Health score messages: score + worst contributing metrics — e.g., "File health score: 42.5 (baseline: 60.0). Worst contributors: cyclomatic (3 violations), cognitive (2 violations)"
- Rule descriptions: full explanations with formula, interpretation, and examples (rendered in GitHub's rule detail panel)
- Each rule includes helpUri linking to hosted docs page for "Learn more" link in annotations

### CI workflow
- Triggered via `--format sarif` (new value for existing --format flag, alongside console and json)
- Output to stdout by default (consistent with --format json behavior)
- Respects --metrics filtering — `--format sarif --metrics cyclomatic` only produces cyclomatic violation results
- Docs include a complete, copy-paste-ready GitHub Actions workflow snippet showing SARIF upload with codeql-action/upload-sarif

### Claude's Discretion
- SARIF schema version and exact JSON structure
- How to structure the `runs` array and `tool` descriptor
- Exact list of granular sub-rules (which Halstead/structural sub-metrics get their own rule)
- How to handle edge cases (no violations, empty projects)

</decisions>

<specifics>
## Specific Ideas

- helpUri should point to hosted docs pages (not raw GitHub markdown files) for polished "Learn more" experience
- GitHub Actions snippet should be complete and working — not just the upload step but the full workflow including checkout, install, run, and upload

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-sarif-output*
*Context gathered: 2026-02-17*
