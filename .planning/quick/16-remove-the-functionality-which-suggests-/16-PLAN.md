---
phase: quick-16
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/cli/init.zig
  - src/main.zig
  - docs/health-score.md
  - docs/cli-reference.md
  - docs/getting-started.md
  - docs/examples.md
autonomous: true
must_haves:
  truths:
    - "--init always writes default weights (no optimization or suggestion)"
    - "--init no longer analyzes codebase for weight optimization"
    - "runEnhancedInit function is removed entirely"
    - "Documentation reflects the simplified --init behavior"
  artifacts:
    - path: "src/cli/init.zig"
      provides: "Simplified init with default weights only"
    - path: "src/main.zig"
      provides: "Simplified --init handler calling runInit directly"
    - path: "docs/health-score.md"
      provides: "No mention of enhanced --init or weight optimization"
    - path: "docs/cli-reference.md"
      provides: "Updated --init description"
    - path: "docs/getting-started.md"
      provides: "Updated --init description"
  key_links:
    - from: "src/main.zig"
      to: "src/cli/init.zig"
      via: "init.runInit()"
      pattern: "init\\.runInit"
---

<objective>
Remove the enhanced --init weight optimization/suggestion functionality. The --init flag should always generate a config file with default weights, without analyzing the codebase for weight optimization. This eliminates the `runEnhancedInit`, `optimizeWeights`, `computeScoreWithWeights`, and `normalizeWeights` functions, and simplifies the --init handler in main.zig.

Purpose: Simplify the init workflow -- weight optimization adds complexity without clear value. Users should always start with default weights.
Output: Simplified --init that always writes default config with default weights.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@src/cli/init.zig
@src/main.zig
@docs/health-score.md
@docs/cli-reference.md
@docs/getting-started.md
@docs/examples.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove weight optimization from init.zig and simplify main.zig --init handler</name>
  <files>src/cli/init.zig, src/main.zig</files>
  <action>
In `src/cli/init.zig`:
- Remove `runEnhancedInit` function entirely (lines 74-118)
- Remove `computeScoreWithWeights` function (lines 122-140)
- Remove `optimizeWeights` function (lines 145-200)
- Remove `normalizeWeights` function (lines 204-215)
- Remove the `weights` and `baseline` optional parameters from `generateJsonConfig` -- it should always write default weights (the `else` branch at lines 262-267) and never write a baseline field
- Remove imports that are no longer needed: `scoring` import (line 4), `MetricThresholds` (line 9), `EffectiveWeights` (line 10)
- Remove tests for the removed functions: "generateJsonConfig with weights and baseline includes them" (lines 382-411), "optimizeWeights returns normalized weights summing to 1.0" (lines 442-463), "normalizeWeights sums to 1.0" (lines 465-469), "normalizeWeights all-zero returns equal weights" (lines 471-477)
- Update the existing `generateJsonConfig` test to not pass null for weights/baseline params (since those params are removed)

In `src/main.zig`:
- Simplify the `--init` handler (lines 418-437): remove the `if (total_functions > 0)` branch that calls `runEnhancedInit`. Replace the entire block with just `try init.runInit(arena_allocator); return;`
- This eliminates the need to collect `all_results_list` for weight optimization
- Move the `--init` check BEFORE the analysis loop (before line 268). The init should just write defaults and return immediately, no analysis needed. Place it right after `merge.mergeArgsIntoConfig` (after line 112), before file discovery begins.

Verify the simplified flow: `--init` -> write default config -> exit. No analysis, no optimization.
  </action>
  <verify>`zig build test` passes with no failures. Verify `runEnhancedInit` no longer exists: `grep -r "runEnhancedInit\|optimizeWeights\|normalizeWeights\|computeScoreWithWeights" src/` returns no matches.</verify>
  <done>--init always writes default config with default weights. No weight optimization code remains in the codebase. All tests pass.</done>
</task>

<task type="auto">
  <name>Task 2: Update documentation to reflect simplified --init</name>
  <files>docs/health-score.md, docs/cli-reference.md, docs/getting-started.md, docs/examples.md</files>
  <action>
In `docs/health-score.md`:
- Remove the entire "Enhanced --init" section (lines 183-206), including the "How the Optimization Works" subsection
- Keep the "Configuration Reference" section that follows it

In `docs/cli-reference.md`:
- Line 56: Change description to: "Generate a `.complexityguard.json` configuration file with default thresholds and weights."
- Lines 58-64: Simplify to just show `complexity-guard --init` (no src/ path needed since no analysis happens)
- Lines 66-68: Replace the enhanced workflow description with: "Creates a config file with standard thresholds, default metric weights, and common exclude patterns. Edit the generated file to customize for your project."

In `docs/getting-started.md`:
- Lines 172-182: Simplify the --init description. Remove references to "suggested weights", "optimized config", "before/after comparison". Just describe it as generating a default config file.
- Change the code example to just `complexity-guard --init` (no src/ path)

In `docs/examples.md`:
- Line 188: Change comment from "Analyze and set up with optimized weights + baseline" to "Generate default config"
- Change the command from `complexity-guard --init src/` to `complexity-guard --init`
  </action>
  <verify>Run `grep -ri "suggest\|optimiz\|enhanced.*init\|coordinate descent" docs/` and confirm no matches related to weight optimization remain (the word "adjust" in getting-started.md about adjusting thresholds is fine to keep).</verify>
  <done>All documentation accurately describes --init as writing a default config. No references to weight optimization, suggested weights, or enhanced init workflow remain.</done>
</task>

</tasks>

<verification>
1. `zig build test` passes
2. `grep -r "runEnhancedInit\|optimizeWeights\|normalizeWeights\|computeScoreWithWeights" src/` returns nothing
3. `grep -ri "suggested weights\|optimized weights\|coordinate descent\|enhanced.*init" docs/` returns nothing
4. The generated config from `--init` contains default weights (cognitive: 0.30, cyclomatic: 0.20, etc.)
</verification>

<success_criteria>
- --init writes a default config file with standard weights, no codebase analysis
- All weight optimization code removed from init.zig
- main.zig --init handler is simplified (no analysis before init)
- Documentation updated across all 4 doc files
- All tests pass
</success_criteria>

<output>
After completion, create `.planning/quick/16-remove-the-functionality-which-suggests-/16-SUMMARY.md`
</output>
