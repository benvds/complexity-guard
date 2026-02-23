# Phase 4: Cyclomatic Complexity - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Calculate McCabe cyclomatic complexity per function and validate against configurable thresholds. This is the first metric the tool computes — a vertical slice from AST traversal through threshold checking. Output formatting belongs to Phase 8; this phase produces structured results in the existing data structures.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

User directed: "Research modern best practices and decide for me" across all decision areas. Claude has full flexibility guided by research into modern tools (ESLint, SonarQube, CodeClimate, etc.).

**Counting philosophy**
- Determine what increments the count: traditional McCabe vs modern JS-aware counting
- Decide default treatment of logical operators (&&, ||), optional chaining (?.), nullish coalescing (??), ternary expressions
- Research how leading tools handle these and choose sensible defaults
- Configurability: user should be able to toggle optional constructs on/off

**Default thresholds**
- Research industry-standard warning and error levels (ESLint default 20, SonarQube 10/20/30, academic McCabe 10)
- Choose defaults that balance catching genuinely complex functions without noisy false positives
- Thresholds must be configurable per the existing config system

**Function scope**
- Determine what counts as a "function" for analysis: named functions, arrow functions, class methods, getters/setters, constructors, IIFEs, module-level code
- Research what modern tools include/exclude by default

**Switch/case handling**
- Decide between each-case-counts (standard McCabe) vs switch-only counting
- Research modern tool consensus on this controversial point

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User wants modern best practices as the guiding principle.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-cyclomatic-complexity*
*Context gathered: 2026-02-14*
