# Phase 13: Gap Closure — Main Pipeline Wiring - Research

**Researched:** 2026-02-22
**Domain:** Zig pipeline wiring — config propagation, flag gating, exit code logic
**Confidence:** HIGH

## Summary

This phase closes four concrete gaps in `src/main.zig` that were identified by the v1.0 milestone audit. All gaps are purely wiring bugs — the underlying data structures and config fields exist; they just are not consulted when they should be. No new modules, structs, or APIs are required. The work is mechanical: read existing config fields and pass them into the right call sites.

Gap 1 (CYCL-09): `CyclomaticConfig` is always built from `.default()` on line 229 of `main.zig`. The config file does parse `analysis.thresholds.cyclomatic` into `ThresholdsConfig.cyclomatic: ?ThresholdPair`, and a `buildCyclomaticConfig` helper pattern already exists for Halstead and Structural, but was never created for cyclomatic. The fix is a `buildCyclomaticConfig()` function that reads `ThresholdsConfig.cyclomatic` and returns a properly wired `CyclomaticConfig`.

Gap 2 (CLI-07): The `--metrics` flag already gates which metrics are *computed* and which metrics are *displayed*, but does not gate which metrics drive *exit codes*. `countViolations` in `exit_codes.zig` calls `worstStatusAll`, which always considers all metric families. If a user runs `--metrics cyclomatic`, a halstead violation in a function still causes `total_errors += 1` and exits with code 1. The fix is to add a `parsed_metrics: ?[]const []const u8` parameter to `countViolations` (and/or `worstStatusAll`) so only enabled metric families contribute to the violation count.

Gap 3 (CLI-08): `--no-duplication` is parsed in `args.zig` and merged into `cfg.analysis.no_duplication` in `merge.zig`, but `main.zig` never consults it. The `duplication_enabled` block in `main.zig` only checks `cfg.analysis.duplication_enabled` and `parsed_metrics`. The fix is a one-line guard: check `cfg.analysis.no_duplication` in the `duplication_enabled` block and return false early when it is set.

Gap 4 (CFG-04 / `--save-baseline`): `writeDefaultConfigWithBaseline` writes a default config that includes `cyclomatic`, `cognitive`, `halstead`, and `structural` weights but omits the `duplication: 0.20` weight. When a user with duplication enabled runs `--save-baseline` without an existing config file, the written file silently drops the duplication weight. The fix is to add `"duplication": 0.20` to the `weights` object in `writeDefaultConfigWithBaseline`.

**Primary recommendation:** Implement all four fixes in a single plan. Each fix is 1–5 lines in `main.zig` or `exit_codes.zig`. Add targeted unit tests (TDD: fail first, then fix) for each fix. No new modules or struct changes needed.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Zig std | 0.15.2 | All logic | Already in use; no external deps |

### Supporting
None. All four fixes are standard Zig within the existing codebase.

### Alternatives Considered
None. This is pure wiring — no architectural decisions remain open.

**Installation:** None needed.

## Architecture Patterns

### Recommended Project Structure

No new files. All changes land in existing files:

```
src/
├── main.zig                   # Gaps 1, 2 (partial), 3, 4
├── output/exit_codes.zig      # Gap 2 (countViolations / worstStatusAll)
```

### Pattern 1: buildCyclomaticConfig() helper (Gap 1 - CYCL-09)

**What:** Mirror the `buildHalsteadConfig()` and `buildStructuralConfig()` pattern already in `main.zig` to build `CyclomaticConfig` from `ThresholdsConfig`.

**When to use:** Called in `main.zig` at the same spot where `cycl_config = cyclomatic.CyclomaticConfig.default()` currently is.

**Example (lines 51–97 of main.zig show the established pattern):**
```zig
/// Build CyclomaticConfig from ThresholdsConfig, falling back to defaults for missing fields.
/// Exposed for unit testing.
pub fn buildCyclomaticConfig(thresholds: config_mod.ThresholdsConfig) cyclomatic.CyclomaticConfig {
    const default_cycl = cyclomatic.CyclomaticConfig.default();
    return cyclomatic.CyclomaticConfig{
        .warning_threshold = if (thresholds.cyclomatic) |t| t.warning orelse default_cycl.warning_threshold else default_cycl.warning_threshold,
        .error_threshold = if (thresholds.cyclomatic) |t| t.@"error" orelse default_cycl.error_threshold else default_cycl.error_threshold,
        .count_logical_operators = default_cycl.count_logical_operators,
        .count_nullish_coalescing = default_cycl.count_nullish_coalescing,
        .count_optional_chaining = default_cycl.count_optional_chaining,
        .count_ternary = default_cycl.count_ternary,
        .count_default_params = default_cycl.count_default_params,
        .switch_case_mode = default_cycl.switch_case_mode,
    };
}
```

Then call it in `main.zig` replacing line 229:
```zig
// Before:
const cycl_config = cyclomatic.CyclomaticConfig.default();

// After:
const cycl_config = if (cfg.analysis) |analysis|
    if (analysis.thresholds) |thresholds| buildCyclomaticConfig(thresholds)
    else cyclomatic.CyclomaticConfig.default()
else
    cyclomatic.CyclomaticConfig.default();
```

### Pattern 2: --metrics gating in countViolations (Gap 2 - CLI-07)

**What:** Add `parsed_metrics` parameter to `countViolations` (and `worstStatusAll`) so only enabled metric families affect the violation count.

**When to use:** The existing `worstStatusAll` function must gain a `metrics` parameter. All callers must pass `parsed_metrics`.

**Example:**
```zig
/// Return the worst status across enabled metric families only.
pub fn worstStatusForMetrics(
    result: cyclomatic.ThresholdResult,
    metrics: ?[]const []const u8,
) cyclomatic.ThresholdStatus {
    var worst = cyclomatic.ThresholdStatus.ok;
    if (isMetricEnabled(metrics, "cyclomatic")) worst = worstStatus(worst, result.status);
    if (isMetricEnabled(metrics, "cognitive")) worst = worstStatus(worst, result.cognitive_status);
    if (isMetricEnabled(metrics, "halstead")) {
        worst = worstStatus(worst, result.halstead_volume_status);
        worst = worstStatus(worst, result.halstead_difficulty_status);
        worst = worstStatus(worst, result.halstead_effort_status);
        worst = worstStatus(worst, result.halstead_bugs_status);
    }
    if (isMetricEnabled(metrics, "structural")) {
        worst = worstStatus(worst, result.function_length_status);
        worst = worstStatus(worst, result.params_count_status);
        worst = worstStatus(worst, result.nesting_depth_status);
    }
    return worst;
}

pub fn countViolations(
    threshold_results: []const cyclomatic.ThresholdResult,
    metrics: ?[]const []const u8,
) struct { warnings: u32, errors: u32 } {
    ...
    for (threshold_results) |result| {
        const worst = worstStatusForMetrics(result, metrics);
        ...
    }
}
```

The `isMetricEnabled` helper is currently a local struct function inside `main.zig` and duplicated in `console.zig`. Move or duplicate it in `exit_codes.zig` to avoid circular imports (this is the established pattern from Phase 07-03 decisions).

**IMPORTANT:** `worstStatusAll` is also used in `console.zig` for verbosity filtering (line per the Phase 07-05 decision: "worstStatusAll considers ALL metrics for verbosity filtering — --metrics flag only controls display, not which functions appear"). The existing `worstStatusAll` WITHOUT metric filtering must stay for the verbosity display path. Only `countViolations` (for exit codes) needs the filtered version.

### Pattern 3: --no-duplication gate (Gap 3 - CLI-08)

**What:** Add a check for `cfg.analysis.no_duplication` to the `duplication_enabled` block in `main.zig`.

**When to use:** In the `blk:` block that computes `duplication_enabled`.

**Example:**
```zig
const duplication_enabled: bool = blk: {
    // --no-duplication overrides everything
    if (cfg.analysis) |a| {
        if (a.no_duplication) |nd| {
            if (nd) break :blk false;
        }
    }
    if (cfg.analysis) |a| {
        if (a.duplication_enabled) |de| {
            if (de) break :blk true;
        }
    }
    if (parsed_metrics) |pm| {
        for (pm) |m| {
            if (std.mem.eql(u8, m, "duplication")) break :blk true;
        }
    }
    break :blk false;
};
```

### Pattern 4: duplication weight in writeDefaultConfigWithBaseline (Gap 4 - CFG-04)

**What:** Add `"duplication": 0.20` to the weights object in the default config JSON.

**When to use:** Only `writeDefaultConfigWithBaseline` needs changing. The weighted 4-metric sum (0.20+0.30+0.15+0.15 = 0.80, which is then renormalized) already works correctly at runtime because `resolveEffectiveWeights` handles normalization — but the saved file should match what the tool actually uses when duplication is disabled.

**Example:**
```zig
try writer.writeAll("  \"weights\": {\n");
try writer.writeAll("    \"cyclomatic\": 0.20,\n");
try writer.writeAll("    \"cognitive\": 0.30,\n");
try writer.writeAll("    \"halstead\": 0.15,\n");
try writer.writeAll("    \"structural\": 0.15,\n");
try writer.writeAll("    \"duplication\": 0.20\n");  // add this
try writer.writeAll("  },\n");
```

### Anti-Patterns to Avoid

- **Changing worstStatusAll signature globally:** `console.zig` uses `worstStatusAll` for verbosity filtering where all-metrics behavior is correct per the Phase 07-05 decision. Add a NEW function `worstStatusForMetrics` rather than changing the existing one.
- **Adding a buildCyclomaticConfig in cyclomatic.zig:** Keep it in `main.zig` alongside `buildHalsteadConfig` and `buildStructuralConfig` — that is the established pattern.
- **Forgetting the parallel path:** The `parallel.zig` worker calls `exit_codes.countViolations` implicitly through `exit_codes.countViolations` called from the worker loop in `parallel.zig`. Actually the parallel path does NOT call `countViolations` itself — it returns `FileAnalysisResult` which stores `warning_count` and `error_count` already computed. Check whether `parallel.zig` duplicates the violation counting logic and patch it too.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config deep copy for cyclomatic | Manual copy | Add field to existing deepCopyConfig | ThresholdPair contains only numbers — already handled |
| isMetricEnabled in exit_codes.zig | New implementation | Duplicate the helper (established pattern from Phase 07-03) | Avoids circular imports |

**Key insight:** All four gaps require only code reading existing struct fields. No new structs or types are needed.

## Common Pitfalls

### Pitfall 1: Parallel path also calls countViolations
**What goes wrong:** The `parallel.zig` worker computes `warning_count` and `error_count` per-file. If `countViolations` gains a `metrics` parameter, the parallel path must pass it too — otherwise parallel runs still count all metrics for exit codes while sequential runs are filtered.
**Why it happens:** Two separate code paths produce the same counters.
**How to avoid:** `parallel.zig` line 240 calls `exit_codes.countViolations(cycl_results)` directly (CONFIRMED by source inspection). When the signature changes, `parallel.zig` must also be updated.
**Warning signs:** Tests pass sequentially but fail when `--threads N` is used. This pitfall is CONFIRMED real — both call sites must be patched.

### Pitfall 2: CyclomaticConfig has non-threshold fields
**What goes wrong:** `CyclomaticConfig` has more fields than just `warning_threshold` and `error_threshold` — it also has boolean counting flags (`count_logical_operators`, etc.) and `switch_case_mode`. The `buildCyclomaticConfig` helper should only override the threshold fields from config, preserving the other fields at their defaults.
**Why it happens:** Over-broad mapping of config → struct.
**How to avoid:** Only map `ThresholdsConfig.cyclomatic.warning` → `warning_threshold` and `ThresholdsConfig.cyclomatic.error` → `error_threshold`. Leave all other `CyclomaticConfig` fields at default.

### Pitfall 3: metric_thresholds for scoring still uses hardcoded cycl_config values
**What goes wrong:** After building `cycl_config` from config, `metric_thresholds` (the scoring struct used for health score sigmoid) must also use the updated values:
```zig
const metric_thresholds = scoring.MetricThresholds{
    .cyclomatic_warning = @as(f64, @floatFromInt(cycl_config.warning_threshold)),  // this
    .cyclomatic_error = @as(f64, @floatFromInt(cycl_config.error_threshold)),       // and this
```
This is already wired from `cycl_config`, so once `cycl_config` is built correctly, `metric_thresholds` inherits the fix automatically. No separate change needed — but verify this.

### Pitfall 4: SARIF thresholds must also pick up cyclomatic from config
**What goes wrong:** `sarif_thresholds` is built from `cycl_config` fields directly:
```zig
.cyclomatic_warning = cycl_config.warning_threshold,
.cyclomatic_error = cycl_config.error_threshold,
```
Once `cycl_config` is built correctly from config, this propagates automatically. Verify that the SARIF path is not a separate source of hardcoded values.

### Pitfall 5: --no-duplication from config file vs CLI
**What goes wrong:** `no_duplication` can come from both the config file (`analysis.no_duplication`) and from the CLI flag (`--no-duplication`). The `merge.zig` already handles merging both into `cfg.analysis.no_duplication`. The fix in `main.zig` just needs to check this merged value — not re-check the CLI flag.
**Why it happens:** Confusing config-after-merge with pre-merge CLI args.
**How to avoid:** Check `cfg.analysis.no_duplication` (after merge), not `cli_args.no_duplication` directly.

## Code Examples

Verified patterns from codebase inspection:

### Gap 1: Call site in main.zig (line 229 replacement)
```zig
// Source: src/main.zig line 229 (current)
const cycl_config = cyclomatic.CyclomaticConfig.default();

// Source: src/main.zig lines 247-257 (cognitive pattern to mirror)
const cog_config = if (cfg.analysis) |analysis|
    if (analysis.thresholds) |thresholds|
        if (thresholds.cognitive) |cog_thresh|
            cognitive.CognitiveConfig{
                .warning_threshold = cog_thresh.warning orelse default_cog.warning_threshold,
                .error_threshold = cog_thresh.@"error" orelse default_cog.error_threshold,
            }
        else
            default_cog
    else
        default_cog
else
    default_cog;
```

Cyclomatic follows the same shape. Use a `buildCyclomaticConfig()` helper in `main.zig` for testability (matching `buildHalsteadConfig` and `buildStructuralConfig`).

### Gap 2: parallel.zig countViolations call site
```zig
// Source: grep countViolations in parallel.zig - verify call site and patch
// After the fix, the signature becomes:
// pub fn countViolations(results: []const ThresholdResult, metrics: ?[]const []const u8) ...
```

### Gap 3: duplication_enabled block (current vs fixed)
```zig
// Current (src/main.zig lines 276-288) - missing no_duplication check:
const duplication_enabled: bool = blk: {
    if (cfg.analysis) |a| {
        if (a.duplication_enabled) |de| {
            if (de) break :blk true;
        }
    }
    if (parsed_metrics) |pm| { ... }
    break :blk false;
};

// Fixed - no_duplication guard added first:
const duplication_enabled: bool = blk: {
    if (cfg.analysis) |a| {
        if (a.no_duplication) |nd| {
            if (nd) break :blk false;  // explicit gate
        }
    }
    // ... rest unchanged
};
```

### Gap 4: writeDefaultConfigWithBaseline (current vs fixed)
```zig
// Current (src/main.zig lines 38-43) - missing duplication weight:
try writer.writeAll("  \"weights\": {\n");
try writer.writeAll("    \"cyclomatic\": 0.20,\n");
try writer.writeAll("    \"cognitive\": 0.30,\n");
try writer.writeAll("    \"halstead\": 0.15,\n");
try writer.writeAll("    \"structural\": 0.15\n");  // note: no trailing comma

// Fixed - duplication weight added:
try writer.writeAll("  \"weights\": {\n");
try writer.writeAll("    \"cyclomatic\": 0.20,\n");
try writer.writeAll("    \"cognitive\": 0.30,\n");
try writer.writeAll("    \"halstead\": 0.15,\n");
try writer.writeAll("    \"structural\": 0.15,\n");  // comma added
try writer.writeAll("    \"duplication\": 0.20\n");  // new line
try writer.writeAll("  },\n");
```

## State of the Art

This phase is entirely internal to the existing codebase. No external libraries or ecosystem changes apply.

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All gaps as-is | All gaps closed | Phase 13 | v1.0 requirements met |

## Open Questions

1. **Does parallel.zig call countViolations directly?**
   - CONFIRMED: `parallel.zig` line 240 calls `exit_codes.countViolations(cycl_results)` directly. The `WorkerContext` struct must gain a `parsed_metrics: ?[]const []const u8` field, and `analyzeFileWorker` must pass `ctx.parsed_metrics` when calling `countViolations`. The `analyzeFilesParallel` function signature already accepts `parsed_metrics` — it just needs to store it in the context and forward it.
   - Recommendation: This is now a CONFIRMED required change. Patch all three: `WorkerContext` field, `analyzeFilesParallel` storage, and `countViolations` call site.

2. **Should `--metrics` with only a subset also suppress computation (not just exit codes)?**
   - What we know: CLI-07 says "gates which metrics are computed and which drive exit codes." Currently halstead and structural are already compute-gated (lines 365, 408 of main.zig). Cyclomatic and cognitive are always computed.
   - What's unclear: Whether gating cyclomatic/cognitive computation when absent from `--metrics` is in scope for this phase.
   - Recommendation: Per CLI-07 requirement, the fix for exit codes is clearly in scope. Gating computation of cyclomatic/cognitive is a larger change with AST traversal implications. Keep this phase focused on exit code gating only (which is what the success criteria says: "gates which metrics are computed and which drive exit codes" — the computation gating for cyclomatic/cognitive is arguably already satisfied since halstead+structural are gated).

3. **writeDefaultConfigWithBaseline vs existing config update path**
   - What we know: The `--save-baseline` code has TWO paths: (a) update existing config (lines 600-646), (b) create new config (lines 643-644). Gap 4 only applies to path (b) — `writeDefaultConfigWithBaseline`. Path (a) preserves existing JSON including whatever `weights` the user already has.
   - Recommendation: Only fix `writeDefaultConfigWithBaseline`. The existing-config path is correct.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CYCL-09 | Tool applies configurable warning (default 10) and error (default 20) thresholds | `ThresholdsConfig.cyclomatic: ?ThresholdPair` exists in config.zig but is never read in main.zig. Fix: `buildCyclomaticConfig()` helper + call site replacement. |
| CFG-04 | User can set per-metric warning and error thresholds in config file | Gap is specifically cyclomatic thresholds — all other metric thresholds are already wired. Also covers the `--save-baseline` duplication weight omission in `writeDefaultConfigWithBaseline`. |
| CLI-07 | User can select specific metrics via `--metrics` flag | `parsed_metrics` gates computation of halstead/structural but does NOT gate exit code counting. `countViolations` in exit_codes.zig ignores `parsed_metrics`. Fix: add `metrics` parameter to `countViolations` and filter by enabled metrics only. |
| CLI-08 | User can skip duplication via `--no-duplication` flag | `no_duplication` is parsed and merged into config but the `duplication_enabled` block in main.zig never checks it. Fix: one-line guard at top of the `duplication_enabled` block. |
</phase_requirements>

## Sources

### Primary (HIGH confidence)
- `src/main.zig` — Direct inspection of all four gap sites (lines 29-47, 229, 276-288, 365-408)
- `src/cli/config.zig` — Confirmed `ThresholdsConfig.cyclomatic` exists but is unused
- `src/cli/merge.zig` — Confirmed `no_duplication` merged into config but unused in main
- `src/cli/args.zig` — Confirmed `no_duplication: bool` field parsed
- `src/output/exit_codes.zig` — Confirmed `countViolations` ignores `parsed_metrics`
- `src/metrics/cyclomatic.zig` — Confirmed `CyclomaticConfig` struct shape (threshold fields + other fields)
- `.planning/debug/resolved/hardcoded-thresholds-ignore-config.md` — Prior audit documented 3 of these bugs; cyclomatic was explicitly called out as a remaining issue
- `.planning/STATE.md` decisions — Phase 07-03, Phase 07-05 decisions confirm isMetricEnabled duplication pattern and worstStatusAll all-metrics behavior for verbosity

### Secondary (MEDIUM confidence)
- `.planning/ROADMAP.md` Phase 13 description — Describes all four gaps at high level
- `.planning/REQUIREMENTS.md` CYCL-09, CFG-04, CLI-07, CLI-08 — Requirement text

## Metadata

**Confidence breakdown:**
- Gap identification: HIGH — directly observed in source code
- Fix patterns: HIGH — mirrors existing patterns in codebase
- Pitfalls: HIGH — derived from prior audit notes and codebase decisions log
- Parallel path concern: MEDIUM — needs one grep to verify before writing plan

**Research date:** 2026-02-22
**Valid until:** 2026-03-22 (stable codebase, no external dependencies)
