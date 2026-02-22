# Phase 11: Duplication Detection - Context

**Gathered:** 2026-02-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Detect code clones across files using Rabin-Karp rolling hash. Tokenize files stripping comments/whitespace, normalize identifiers for Type 2 clones, build cross-file hash index, verify matches token-by-token, merge overlapping matches into maximal clone groups, and report results with locations, token counts, and duplication percentages. Duplication detection is disabled by default — users opt in explicitly.

</domain>

<decisions>
## Implementation Decisions

### Enabled by default
- Duplication detection is **disabled by default** — it is an opt-in feature
- Three opt-in paths, all equivalent:
  - `--duplication` dedicated CLI flag
  - `--metrics duplication` (consistent with existing `--metrics` flag)
  - Config file: set duplication enabled in `.complexityguard.json`
- When not enabled, duplication analysis is skipped entirely (zero overhead)

### Clone display — Console
- Location pairs only, no code snippets: `Clone group (42 tokens): file_a.ts:15, file_b.ts:88`
- Dedicated "Duplication" section **after** per-file results (separate from file output)
- Keep file output clean — no inline duplication info per file

### Clone display — HTML
- Sortable table of clone groups (locations, token count, line count)
- Plus heatmap overlay showing which files share the most clones

### Clone display — SARIF
- One SARIF result per clone group (not per instance)
- Use `relatedLocations` to point to all instances within the group
- GitHub Code Scanning shows them linked

### Clone display — JSON
- Clone groups array in JSON output with locations, token count, and duplication percentages
- Consistent with existing JSON structure patterns

### Threshold defaults
- File-level duplication warning: **15%**
- File-level duplication error: **25%**
- Project-level duplication warning: **5%**
- Project-level duplication error: **10%**

### Performance benchmarking
- Run benchmarks with and without duplication enabled to measure runtime and memory impact
- Measure wall time and peak memory usage
- Test scaling across file counts (100, 1k, 10k files) to identify scaling curve
- Use the quick benchmark suite projects (zod, got, dayjs, vite, nestjs, webpack, typeorm, rxjs, effect, vscode)
- Reproducible benchmark script: `benchmarks/scripts/bench-duplication.sh`
- Results documented in `docs/performance.md` (or existing `docs/benchmarks.md`)

### Claude's Discretion
- Normalization depth (what gets normalized beyond identifiers — string literals, numbers, type annotations)
- JSON output structure for clone groups (field names, nesting)
- Heatmap visualization approach in HTML
- Health score integration (how duplication % maps to 0-100 scale using existing 0.20 weight)
- Internal algorithm details (hash function, table sizing, memory management)

</decisions>

<specifics>
## Specific Ideas

- Console output should be compact and scannable — location pairs, not code dumps
- Benchmarking approach should mirror the existing `bench-quick.sh` infrastructure (hyperfine, same project suite)
- SARIF grouping should produce linked annotations in GitHub Code Scanning
- The feature being off by default is important — duplication analysis is expensive and should be consciously enabled

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-duplication-detection*
*Context gathered: 2026-02-22*
