# Case Study: React Composition Skills and Health Score Alignment

A study of how React composition and refactoring patterns interact with ComplexityGuard's health scoring, based on 20 refactoring passes on a real-world React application (bookmarks, ~55 files, ~143 functions).

## Skills Analyzed

Five Claude Code skills were used to drive the refactoring:

| Skill | Focus | Key Patterns |
|---|---|---|
| **react-composition** | Component structure | Compound components, explicit variants, children over render props, context interface design |
| **react-ui-patterns** | UI state management | Loading/error/empty states, button patterns, form submission |
| **react-refactor** | Architectural refactoring | 40 rules across component architecture, state architecture, hook patterns, decomposition, coupling/cohesion |
| **vercel-react-best-practices** | Performance optimization | Waterfall elimination, bundle size, re-render optimization (57 rules) |
| **vercel-composition-patterns** | Composition at scale | Boolean prop elimination, compound components, state decoupling, React 19 APIs |

Common themes across all five: composition over configuration, context-based state sharing, explicit variants over boolean props, component decomposition, separation of concerns.

## Results

| Metric | Baseline | Refactored | Change |
|---|---|---|---|
| Health Score | 71 | 77 | +6 |
| Total Files | 55 | 57 | +2 |
| Total Functions | 143 | 203 | +60 |
| Error-severity functions | 5 | 0 | -5 |
| Warning-severity functions | 27 | 34 | +7 |
| Healthy functions | 23 | 23 | 0 |
| Violation count (errors) | 80 | 39 | -41 |
| Violation count (warnings) | 72 | 110 | +38 |

### Function Health Distribution

| Score Range | Baseline | Refactored |
|---|---|---|
| 0-30 | 5 | 0 |
| 31-50 | 8 | 1 |
| 51-60 | 6 | 7 |
| 61-70 | 15 | 36 |
| 71-80 | 29 | 75 |
| 81-90 | 80 | 84 |

### Average Metrics Per Function

| Metric | Baseline | Refactored | Change |
|---|---|---|---|
| Cyclomatic | 2.5 | 2.2 | -0.3 |
| Cognitive | 4.7 | 2.9 | -1.8 |
| Halstead Volume | 275 | 196 | -79 |
| Lines | 28 | 20 | -8 |
| Params | 0.6 | 0.9 | +0.3 |
| Depth | 0.5 | 0.5 | 0.0 |

### Biggest Improvements (File-Level)

| File | Before | After | Delta |
|---|---|---|---|
| EditBookmarkModal.tsx | 26 | 70 | +43 |
| SaveForm.tsx | 30 | 67 | +37 |
| TagInput.tsx | 32 | 69 | +37 |
| DebugMenu.tsx | 40 | 76 | +35 |
| TagSidebar.tsx | 45 | 71 | +25 |
| bookmarklet/save.tsx | 51 | 73 | +22 |
| login.tsx | 51 | 72 | +21 |
| seed.ts | 56 | 75 | +19 |
| BookmarkItem.tsx | 55 | 74 | +19 |
| Header.tsx | 62 | 77 | +15 |

All 5 former error-severity files were resolved. No file regressed.

### Threshold Violations (Per-Function)

| Metric | Threshold | Baseline | Refactored |
|---|---|---|---|
| Cyclomatic >= 10 (warn) | 10 | 4 | 3 |
| Cyclomatic >= 20 (err) | 20 | 1 | 0 |
| Cognitive >= 15 (warn) | 15 | 11 | 4 |
| Cognitive >= 25 (err) | 25 | 7 | 0 |
| Halstead >= 500 (warn) | 500 | 25 | 25 |
| Halstead >= 1000 (err) | 1000 | 15 | 5 |
| Lines >= 25 (warn) | 25 | 42 | 55 |
| Lines >= 50 (err) | 50 | 30 | 24 |
| Params >= 3 (warn) | 3 | 1 | 15 |
| Depth >= 3 (warn) | 3 | 8 | 6 |

## Analysis

### What the Skills Fix Well

The composition patterns have their strongest impact on **cognitive complexity** and **cyclomatic complexity**:

| Skill Pattern | Primary Metric Reduced | Mechanism |
|---|---|---|
| Compound components | Cognitive, Cyclomatic | Fewer conditionals per component |
| Explicit variants | Cognitive, Cyclomatic | Eliminates type-switching branches |
| Component decomposition | Lines, Cognitive, Cyclomatic | Splits large functions into smaller ones |
| State lifting to context | Depth, Params, Cognitive | Removes prop drilling and nesting |
| Children over render props | Depth, Cognitive | Flattens component trees |

Cognitive violations dropped from 11 to 4 (warn) and 7 to 0 (err). Cyclomatic violations dropped from 4 to 3 (warn) and 1 to 0 (err). These are exactly the metrics the skills target.

### What the Skills Don't Fix

**Halstead Volume** remained largely unchanged: 25 functions above the warning threshold in both baseline and refactored. JSX markup is inherently operator/operand-dense -- a single line like `<Button variant="primary" onClick={handler}>Save</Button>` generates 6+ operators and operands. The skills split halstead volume across more functions rather than reducing it.

**Function Length** violations actually increased from 42 to 55 at the warning threshold. Decomposition creates more medium-sized functions (20-40 lines) rather than fewer large ones. A composed React component with a hooks section and JSX return body naturally occupies 25-40 lines.

**Params** violations increased from 1 to 15. Extracting logic into custom hooks and utility functions introduces explicit parameter signatures that were previously implicit within monolithic components.

### The Warning Zone

Many functions (59%) land in the 60-80 "ok" range despite being well-structured, composed code. This happens because:

1. **JSX inflates halstead volume.** A clean component with standard JSX easily hits halstead 300-500, which reduces the halstead sub-score.

2. **React components have a natural length floor.** A component with imports, a hooks section, and a JSX return block occupies 20-35 lines even when well-decomposed. With a warning threshold of 25, this always penalizes.

Note: with the piecewise linear scoring model, a trivially simple function (cyc=1, cog=0, hal=50, lines=3) now scores ~99, and the full 0-100 range is reachable. The warning zone issue is driven by JSX-inherent metric inflation, not a scoring formula ceiling.

### Metric-by-Metric Sensitivity

The relative sensitivity ordering holds regardless of scoring model: cognitive improvements move the needle most (highest weight at 0.30), followed by halstead and cyclomatic reductions. Structural sub-metrics (lines, params, depth) have limited influence because they share a single 0.15 weight slot split three ways.

## Recommendations

### Threshold Changes

**Halstead Volume: raise to warn=750, error=1500**

JSX is inherently operand/operator-dense. The current threshold of 500 penalizes declarative UI code that is genuinely readable. Raising to 750/1500 means halstead only flags functions with actual logical complexity, not verbose JSX templates.

Impact: With raised thresholds, a component at hal=400 scores well within the "good" range instead of triggering a warning.

**Function Length: raise to warn=35, error=65**

25 lines is too aggressive for React/JSX. A component with a 10-line hooks section and a 15-line JSX return is already at the warning. The composition patterns produce functions in the 20-40 line range, which represents good architecture.

Impact: With raised thresholds, a component at 30 lines scores comfortably within the "good" range instead of being penalized.

### Weight Changes

**Halstead: reduce from 0.15 to 0.10**

Even with raised thresholds, halstead volume is the least actionable metric for composition-based refactoring. The skills have no direct pattern for "reduce halstead" -- it's a side effect of decomposition, not a direct target.

**Cognitive: raise from 0.30 to 0.35**

Cognitive complexity is the metric most aligned with composition skill outcomes. Compound components, explicit variants, and state lifting all directly reduce cognitive complexity. Making it the dominant factor means the health score better reflects quality improvements from these patterns.

### Combined Profile

```json
{
  "weights": {
    "cognitive": 0.35,
    "cyclomatic": 0.20,
    "halstead": 0.10,
    "structural": 0.15
  },
  "thresholds": {
    "halstead": { "warning": 750, "error": 1500 },
    "function_length": { "warning": 35, "error": 65 }
  }
}
```

### Simulated Impact

Using the proposed profile against the refactored codebase:

| Metric | Current Config | Proposed Config |
|---|---|---|
| Estimated Project Health | ~77 | ~80 |
| Healthy functions (>=80) | 84 (41%) | ~130 (64%) |
| Warning functions (60-79) | 118 (58%) | ~72 (36%) |
| Error functions (<60) | 1 (0.5%) | 1 (0.5%) |

The shift: ~46 functions move from warning to healthy, reflecting that composition-pattern refactoring genuinely improved code quality that the default scoring was not recognizing.

### What to Leave Unchanged

- **Cyclomatic thresholds** (10/20) -- well-calibrated, skills reduce this effectively
- **Cognitive thresholds** (15/25) -- appropriate range, good discrimination in the warning zone
- **Depth thresholds** (3/5) -- composition patterns fix nesting depth, current thresholds reward that
- **Params thresholds** (3/6) -- reasonable for both React and non-React code
- **Cyclomatic weight** (0.20) -- good balance between importance and the skill patterns' impact
- **Structural weight** (0.15) -- correct level given it bundles three sub-metrics

### Applicability

These recommendations are tuned for **React/JSX codebases** where composition skills are the primary refactoring tool. For non-React TypeScript/JavaScript (Node.js backends, utility libraries), the default thresholds remain more appropriate since those codebases don't exhibit JSX-driven halstead/line inflation.

A project-level config (`.complexityguard.json`) is the right mechanism for applying this -- teams choose the profile that matches their codebase.

## See Also

- [Health Score](health-score.md) -- scoring formula and configuration reference
- [Halstead Metrics](halstead-metrics.md) -- how halstead volume is computed
- [Cognitive Complexity](cognitive-complexity.md) -- the highest-weighted metric
- [Structural Metrics](structural-metrics.md) -- function length, params, nesting depth
- [Claude Code Skill](claude-code-skill.md) -- using ComplexityGuard as a Claude Code skill
