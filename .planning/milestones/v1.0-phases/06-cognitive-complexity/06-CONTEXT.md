# Phase 6: Cognitive Complexity - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Calculate SonarSource-style cognitive complexity per function with nesting depth penalties. Applies configurable warning/error thresholds. Integrates into existing console and JSON output alongside cyclomatic complexity. Does not add new output formats or new metric types.

</domain>

<decisions>
## Implementation Decisions

### SonarSource spec alignment
- Follow SonarSource whitepaper as baseline with pragmatic deviations for TS/JS
- Deviations are documented, not configurable (no --strict-sonar flag). One behavior, well-documented
- Users who need exact SonarQube parity use SonarQube

### Logical operator counting
- Each logical operator increments regardless of sequence (deviation from SonarSource)
- SonarSource groups same-operator sequences as 1 increment; ComplexityGuard counts each operator
- Simpler mental model for users: every `&&`, `||`, `??` adds 1

### Recursion detection
- Only detect recursion when a function calls itself by its declared name
- No indirect recursion detection via variable references or re-exports

### Arrow function nesting
- Arrow function callbacks (e.g., `arr.map(x => ...)`) increase nesting depth — follows SonarSource
- Top-level arrow function definitions (`const fn = () => ...`) do NOT add nesting — treated like function declarations
- Nested arrow callbacks inside methods DO add nesting depth (method=0, callback=1, if inside callback=2)

### Class method nesting
- Class methods start at nesting 0, same as standalone functions (follows SonarSource)
- Only nested structures inside the method body add depth

### Output integration
- Side-by-side display: both cyclomatic and cognitive on the same line per function
- Separate hotspot lists for cyclomatic and cognitive (combined list deferred to composite health phase)
- Sibling fields in JSON output: `{ cyclomatic: 12, cognitive: 8 }` — flat, matches existing structure
- Same warning/error severity indicators as cyclomatic — consistent UX

### Attribution and documentation
- Credit SonarSource and cite G. Ann Campbell's whitepaper in documentation
- Create detailed docs page (~300 words) explaining cognitive complexity: what it measures, how it differs from cyclomatic, key counting rules
- Create matching detailed docs page (~300 words) for cyclomatic complexity
- Reference both docs pages from README

### Claude's Discretion
- Default threshold values (likely 15/25 based on industry norms, but Claude decides)
- Exact nesting penalty formula
- How to handle `else if` vs `else { if }` (likely both increment, but implementation detail)
- Test fixture design and edge case coverage

</decisions>

<specifics>
## Specific Ideas

- "Pragmatic deviations" philosophy: follow the spec where it makes sense, deviate where TS/JS idioms warrant it, document all deviations clearly
- Simpler logical operator counting chosen specifically for user comprehension over spec compliance
- Top-level arrow functions not nesting is a key deviation — prevents inflated scores for the most common TS/JS function declaration pattern

</specifics>

<deferred>
## Deferred Ideas

- Combined hotspot list (single ranked list across all metrics) — belongs in Phase 8: Composite Health Score
- Configurable strict SonarSource mode — not planned, document-only approach chosen

</deferred>

---

*Phase: 06-cognitive-complexity*
*Context gathered: 2026-02-17*
