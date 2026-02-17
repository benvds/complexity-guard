# Phase 7: Halstead & Structural Metrics - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement Halstead metrics (vocabulary, volume, difficulty, effort, estimated bugs) and structural metrics (function length, parameter count, nesting depth, file length, export count) per function and file. Configurable thresholds for all metrics. This phase adds metric computation and threshold validation only — composite scoring is Phase 8.

</domain>

<decisions>
## Implementation Decisions

### TypeScript type awareness
- Exclude type-only syntax from Halstead metrics: type annotations, generics, `as`, `satisfies` do not count as operators/operands. Halstead measures runtime logic only — TS and equivalent JS should score the same.
- Skip Halstead computation for type-only declarations (`interface`, `type` aliases). Only compute Halstead for functions/methods with runtime bodies.
- Count decorators (`@Component`, `@Injectable`) as operators in Halstead — they are runtime constructs that modify behavior.
- For structural parameter count: count both runtime params AND generic type params (`<T, U>`). A function with 3 regular params and 3 generics = 6 params. Reflects full signature complexity.

### Default thresholds
- Halstead metrics: use industry-standard defaults from academic literature (research specific values from SonarQube, CodeClimate, etc.)
- Function length warning: 25 logical lines (strict, pushes toward single-responsibility functions)
- Parameter count warning: 4 parameters
- Max nesting depth warning: 4 levels

### Function length counting
- "Logical lines" = lines with actual code only. Exclude blank lines and comment-only lines.
- Single-expression arrow functions count as 1 logical line regardless of formatting.
- File length (STRC-04) uses the same rules as function length — logical lines only, no blanks, no comments. One consistent definition of "length" everywhere.

### Metric presentation
- Default console output shows only violations (metrics exceeding thresholds). Clean code = clean output. Use --verbose to see all values.
- JSON output always includes all Halstead and structural metrics for every function, regardless of thresholds. Predictable, complete schema.
- Hotspot ranking considers all metrics including Halstead and structural. A function with extreme Halstead volume can rank as a hotspot even with low cyclomatic/cognitive scores.
- Users can select which metric families to compute via `--metrics` flag (e.g., `--metrics cyclomatic,halstead`). Useful for gradual adoption or focusing CI on specific concerns.

### Claude's Discretion
- Specific Halstead threshold values (research industry standards and pick)
- Error-level thresholds (typically 2x warning level, but Claude can adjust)
- Exact operator/operand classification rules for JS/TS tokens
- How to handle edge cases (empty functions, zero operands)
- File length and export count default thresholds

</decisions>

<specifics>
## Specific Ideas

- Consistent "logical lines" definition across function and file length avoids confusion
- The `--metrics` selectability enables gradual adoption — teams can start with cyclomatic only and add Halstead later
- Type-only syntax exclusion means TypeScript projects aren't unfairly penalized compared to JavaScript equivalents, while type params in signatures still count for structural complexity

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-halstead-structural-metrics*
*Context gathered: 2026-02-17*
