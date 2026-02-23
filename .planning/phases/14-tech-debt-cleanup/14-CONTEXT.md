# Phase 14: Tech Debt Cleanup - Context

**Gathered:** 2026-02-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve all tech debt items identified by the v1.0 milestone audit: fix function name extraction, remove dead code, update ROADMAP.md/REQUIREMENTS.md checkboxes, and fill docs/benchmarks.md with actual data. No new capabilities — strictly cleanup and corrections.

</domain>

<decisions>
## Implementation Decisions

### Function name extraction
- Arrow functions assigned to variables use the variable name (const handler = () => {} → "handler")
- Truly anonymous callbacks use context from what they're passed to (arr.map(() => ...) → "map callback", addEventListener('click', fn) → "click handler")
- Class and object methods include the parent: Foo.bar, obj.handler — gives full context in output
- Unnamed default exports labeled as "default export"

### Benchmark data
- Benchmark both synthetic fixtures (project's own test files) and real open-source projects for credibility
- Speed-focused metrics: files/second, time per file, total scan time
- One-time manual capture for v1.0 — no automated benchmark script needed
- Present as narrative with tables: brief methodology explanation, data tables, key takeaways

### Cleanup approach
- Fix related issues discovered along the way (e.g., inconsistent output formatting found while fixing names)
- Verify ROADMAP.md and REQUIREMENTS.md checkboxes against actual code/test state, not just phase completion records
- Clean up tests related to dead code removal (remove/update tests covering the unreachable arrow_function branch)
- Update the audit findings document to mark resolved items with notes on what was done

### Claude's Discretion
- Which open-source projects to benchmark against
- Exact format of context-based anonymous function names
- How to handle edge cases in function naming (deeply nested, IIFE, etc.)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

- Better ignore workflows — use .gitignore, .eslintignore, or other ignore files as input for file discovery. This is a new capability that belongs in its own phase.

</deferred>

---

*Phase: 14-tech-debt-cleanup*
*Context gathered: 2026-02-23*
