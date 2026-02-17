# Phase 8: Composite Health Score - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Compute a weighted composite health score (0-100) per file and project. Score uses configurable weights across all metric categories. Includes baseline capture and ratchet mechanism for gradual quality improvement. Enhanced --init generates config with baseline score and optimized starting weights.

</domain>

<decisions>
## Implementation Decisions

### Score system
- Numeric 0-100 score only, no letter grades (A-F removed from requirements)
- 100 = healthiest (higher is better)
- Score appears per-file and in project summary
- No default CI failure threshold for score — user must configure via baseline or config

### Score display
- Plain number format in console: "Health: 73"
- Color-coded by value: green >= 80, yellow 50-79, red < 50
- JSON output includes score + breakdown showing each metric's weighted contribution

### Missing metrics handling
- Redistribute weights proportionally when metrics aren't implemented yet (e.g., duplication not available until Phase 11)
- When a new metric is added, weights auto-adjust to include it — no user action needed
- Score always computed from 100% of available weight

### Metric normalization
- Continuous curve (sigmoid or similar) to map raw metric values to 0-100 sub-scores
- No hard cutoffs — smooth degradation as values exceed ideal ranges
- Exact formula fully documented so users can predict scores

### Weight customization
- Named weights in config: `"weights": {"cyclomatic": 0.30, "cognitive": 0.25, ...}`
- Partial override allowed: unspecified weights use defaults, tool normalizes total to 1.0
- Weight of 0 explicitly excludes a metric from scoring (still analyzed, just doesn't affect score)
- `--init` includes all weights with default values in generated config

### Baseline + ratchet workflow
- `--save-baseline` flag captures current project score into config file as `"baseline": 73`
- Baseline stored in `.complexityguard.json` alongside other config — committed to git, shared by team
- When baseline exists, score dropping below it causes CI failure (exit code 1)
- Project-level baseline only (not per-file) — individual files can fluctuate as long as overall score holds

### Initial setup workflow (--init enhancement)
- Enhanced `--init` workflow: analyze codebase, capture baseline score, suggest optimized weights
- Auto-optimize: tool finds weight configuration that maximizes starting score for this codebase
- Output shows: default weights score vs. suggested weights score
- Writes suggested weights + baseline into generated config
- Documentation explains how to remove custom weights and return to ideal defaults once improvements are underway

### Score transparency
- Full formula documentation: normalization curves, weight math, aggregation method
- JSON breakdown shows per-metric contribution so users understand what's driving the score

### Claude's Discretion
- Exact sigmoid/curve parameters for normalization
- Project score aggregation method (e.g., average of file scores, weighted by file size/function count)
- Implementation of weight optimization algorithm for --init

</decisions>

<specifics>
## Specific Ideas

- The refinement workflow is key: teams adopt the tool with optimized weights (higher starting score), then gradually return to ideal default weights as code quality improves
- Baseline is a "never go backwards" mechanism, not a target — it prevents degradation
- Documentation should include a clear guide: "start with suggested weights, improve code, eventually remove custom weights to use defaults"

</specifics>

<deferred>
## Deferred Ideas

- Per-file baselines — could be added later if project-level proves too coarse
- Score-gated weight graduation (auto-suggest shifting weights toward ideal when score improves) — future enhancement
- Trend tracking over time (score history across commits) — separate feature

</deferred>

---

*Phase: 08-composite-health-score*
*Context gathered: 2026-02-17*
