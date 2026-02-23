# Phase 9: SARIF Output - Research

**Researched:** 2026-02-17
**Domain:** SARIF 2.1.0 JSON format, GitHub Code Scanning integration, Zig JSON serialization
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Rule mapping
- Granular sub-rules: separate SARIF rule per sub-metric (e.g., `complexity-guard/cyclomatic`, `complexity-guard/cognitive`, `complexity-guard/halstead-volume`, `complexity-guard/halstead-difficulty`, `complexity-guard/nesting-depth`, `complexity-guard/param-count`)
- RuleId format: `complexity-guard/metric-name` (namespaced, clear origin)
- Severity: direct mapping from existing thresholds — warning threshold triggers SARIF `warning`, error threshold triggers SARIF `error`
- Health score produces a file-level SARIF result when below baseline

#### Result granularity
- One SARIF result per violated metric per function (a function violating 3 metrics = 3 separate results)
- Violations only — passing functions do not produce SARIF results
- Location: primary location on function declaration line, with SARIF `region` covering the full function body span
- Baseline ratchet failures (health score regression) also produce SARIF results at file level

#### Message content
- Violation messages: score + threshold format — e.g., "Cyclomatic complexity is 15 (warning threshold: 10, error threshold: 20)"
- Health score messages: score + worst contributing metrics — e.g., "File health score: 42.5 (baseline: 60.0). Worst contributors: cyclomatic (3 violations), cognitive (2 violations)"
- Rule descriptions: full explanations with formula, interpretation, and examples (rendered in GitHub's rule detail panel)
- Each rule includes helpUri linking to hosted docs page for "Learn more" link in annotations

#### CI workflow
- Triggered via `--format sarif` (new value for existing --format flag, alongside console and json)
- Output to stdout by default (consistent with --format json behavior)
- Respects --metrics filtering — `--format sarif --metrics cyclomatic` only produces cyclomatic violation results
- Docs include a complete, copy-paste-ready GitHub Actions workflow snippet showing SARIF upload with codeql-action/upload-sarif

### Claude's Discretion
- SARIF schema version and exact JSON structure
- How to structure the `runs` array and `tool` descriptor
- Exact list of granular sub-rules (which Halstead/structural sub-metrics get their own rule)
- How to handle edge cases (no violations, empty projects)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OUT-SARIF-01 | Tool outputs valid SARIF 2.1.0 with $schema, version, and runs array | SARIF JSON structure fully documented; `std.json.Stringify.valueAlloc` handles serialization |
| OUT-SARIF-02 | Tool maps each metric violation to a SARIF result with ruleId, level, and physicalLocation | ThresholdResult already carries per-metric status fields; direct mapping to SARIF result fields |
| OUT-SARIF-03 | Tool uses 1-indexed line/column numbers in SARIF locations | Codebase uses 1-indexed lines (start_line) and 0-indexed columns (start_col); +1 conversion required for columns |
| OUT-SARIF-04 | Tool output is accepted by GitHub Code Scanning upload validation | Requirements: $schema URI, version "2.1.0", runs array, ruleId matches rule id, relative URIs — all achievable |
</phase_requirements>

---

## Summary

Phase 9 adds SARIF 2.1.0 output as a new value for the existing `--format` flag. No new analysis logic is needed — the phase is purely an output transformation of already-computed `ThresholdResult` data into the SARIF JSON schema.

The SARIF 2.1.0 specification is well-established and stable (ratified by OASIS). GitHub Code Scanning has specific but well-documented requirements: a `$schema` URI, `version: "2.1.0"`, a `runs` array with a `tool.driver`, a `rules` array (one entry per metric), and a `results` array (one entry per violation). The existing `json_output.zig` module provides a clear structural model to follow for `sarif_output.zig`.

The key implementation insight is that `ThresholdResult` already contains everything needed: per-metric status fields (`status`, `cognitive_status`, `halstead_volume_status`, etc.), line/column positions, function name, and end_line. The only conversion required is adding +1 to `start_col` (0-indexed in codebase, 1-indexed in SARIF). Lines are already 1-indexed. The SARIF module will iterate violations per function rather than per function as a whole, producing one `result` object per metric that is non-ok.

**Primary recommendation:** Implement `src/output/sarif_output.zig` mirroring the structure of `json_output.zig`. Wire it into `main.zig` alongside the existing `json` branch. Use Zig struct types matching the SARIF JSON shape with `std.json.Stringify.valueAlloc` for serialization.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SARIF 2.1.0 | OASIS ratified | Output format standard | Only version GitHub Code Scanning accepts |
| `std.json.Stringify` | Zig 0.14 stdlib | JSON serialization | Already used in json_output.zig; no external deps |
| `github/codeql-action/upload-sarif@v4` | v4 (current) | GitHub Actions SARIF upload | Official GitHub action for Code Scanning upload |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `$schema` URI | `https://json.schemastore.org/sarif-2.1.0.json` | Schema validation in IDEs | Always include — required by GitHub validation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-built Zig structs + std.json | sarif-sdk (npm) | Zig binary, no Node.js runtime available |
| `schemastore.org` $schema URI | `raw.githubusercontent.com` helpUri | schemastore URI is canonical for validation; raw GitHub for helpUri is less polished |

**Installation:** No external packages. Pure Zig stdlib.

---

## Architecture Patterns

### Recommended Project Structure

```
src/
├── output/
│   ├── console.zig          # existing
│   ├── json_output.zig      # existing
│   ├── exit_codes.zig       # existing
│   └── sarif_output.zig     # NEW — Phase 9
```

### Pattern 1: SARIF Log Struct Hierarchy

**What:** Define Zig structs that directly mirror the SARIF JSON schema, then use `std.json.Stringify.valueAlloc` exactly as `json_output.zig` does.

**When to use:** Always — keeps serialization trivial with no custom JSON writing.

**Exact SARIF JSON shape required by GitHub:**

```json
{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "complexity-guard",
          "version": "0.4.0",
          "informationUri": "https://github.com/owner/complexity-guard",
          "rules": [
            {
              "id": "complexity-guard/cyclomatic",
              "name": "CyclomaticComplexity",
              "shortDescription": { "text": "Cyclomatic complexity exceeded" },
              "fullDescription": { "text": "McCabe cyclomatic complexity measures the number of linearly independent paths through a function. High cyclomatic complexity correlates with defect density and testing burden. Formula: count decision points (if, for, while, &&, ||, ternary) + 1." },
              "defaultConfiguration": { "level": "warning" },
              "helpUri": "https://complexity-guard.dev/docs/cyclomatic-complexity",
              "help": { "text": "Reduce cyclomatic complexity by extracting logic into smaller functions or simplifying branching conditions." }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "complexity-guard/cyclomatic",
          "ruleIndex": 0,
          "level": "warning",
          "message": { "text": "Cyclomatic complexity is 15 (warning threshold: 10, error threshold: 20)" },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": { "uri": "src/utils.ts" },
                "region": {
                  "startLine": 42,
                  "startColumn": 1,
                  "endLine": 85
                }
              }
            }
          ]
        }
      ]
    }
  ]
}
```

**Zig struct mapping (source: github.com/oasis-tcs/sarif-spec):**

```zig
// Source: SARIF 2.1.0 OASIS specification + GitHub Code Scanning docs
pub const SarifLog = struct {
    @"$schema": []const u8,
    version: []const u8,
    runs: []const SarifRun,
};

pub const SarifRun = struct {
    tool: SarifTool,
    results: []const SarifResult,
};

pub const SarifTool = struct {
    driver: SarifDriver,
};

pub const SarifDriver = struct {
    name: []const u8,
    version: []const u8,
    informationUri: []const u8,
    rules: []const SarifRule,
};

pub const SarifRule = struct {
    id: []const u8,
    name: []const u8,
    shortDescription: SarifMessage,
    fullDescription: SarifMessage,
    defaultConfiguration: SarifConfiguration,
    helpUri: []const u8,
    help: SarifMessage,
};

pub const SarifConfiguration = struct {
    level: []const u8, // "warning" or "error"
};

pub const SarifMessage = struct {
    text: []const u8,
};

pub const SarifResult = struct {
    ruleId: []const u8,
    ruleIndex: u32,
    level: []const u8, // "warning" or "error"
    message: SarifMessage,
    locations: []const SarifLocation,
};

pub const SarifLocation = struct {
    physicalLocation: SarifPhysicalLocation,
};

pub const SarifPhysicalLocation = struct {
    artifactLocation: SarifArtifactLocation,
    region: SarifRegion,
};

pub const SarifArtifactLocation = struct {
    uri: []const u8,
};

pub const SarifRegion = struct {
    startLine: u32,
    startColumn: u32, // MUST be 1-indexed (convert from 0-indexed start_col: +1)
    endLine: u32,     // Cover full function body span
};
```

### Pattern 2: One Result Per Metric Violation

**What:** For each function, iterate over each metric's status independently. When status is `.warning` or `.@"error"`, emit one SARIF result. A function violating 3 metrics emits 3 separate results.

**Implementation approach:**

```zig
// For each file:
for (file_results) |fr| {
    for (fr.results) |result| {
        // Cyclomatic
        if (isMetricEnabled(selected_metrics, "cyclomatic") and result.status != .ok) {
            try results_list.append(allocator, buildCyclomaticResult(fr.path, result, thresholds));
        }
        // Cognitive
        if (isMetricEnabled(selected_metrics, "cognitive") and result.cognitive_status != .ok) {
            try results_list.append(allocator, buildCognitiveResult(fr.path, result, thresholds));
        }
        // Halstead volume
        if (isMetricEnabled(selected_metrics, "halstead") and result.halstead_volume_status != .ok) {
            try results_list.append(allocator, buildHalsteadVolumeResult(fr.path, result, thresholds));
        }
        // ... other metrics
    }
}
```

### Pattern 3: File-Level Health Score Result

**What:** When `baseline_failed` is true, emit a SARIF result at the file level (not function level) using line 1 as the location.

```zig
// For baseline failures, emit a result per file with health score < baseline
// Location: artifactLocation URI only, region startLine: 1
```

### Pattern 4: Rule Index

**What:** SARIF `ruleIndex` is an integer index into the `rules` array. It enables tools to find rule metadata without string matching. Build the rules array in a fixed order; reference by index.

**Rule ordering (fixed):**
1. `complexity-guard/cyclomatic` (index 0)
2. `complexity-guard/cognitive` (index 1)
3. `complexity-guard/halstead-volume` (index 2)
4. `complexity-guard/halstead-difficulty` (index 3)
5. `complexity-guard/halstead-effort` (index 4)
6. `complexity-guard/halstead-bugs` (index 5)
7. `complexity-guard/line-count` (index 6)
8. `complexity-guard/param-count` (index 7)
9. `complexity-guard/nesting-depth` (index 8)
10. `complexity-guard/health-score` (index 9) — for file-level baseline results

### Pattern 5: --metrics Filtering in SARIF

**What:** When `--metrics cyclomatic` is passed, only cyclomatic violation results are emitted. The rules array should still include only relevant rules (those for which results are emitted). This mirrors how `selected_metrics` works in `console.zig`.

**Approach:** Build rules array dynamically — only include rules that have at least one result, or include all rules that are in the enabled metrics set. Either approach is valid; static full rules array is simpler.

### Anti-Patterns to Avoid

- **Building JSON strings manually with `std.ArrayList(u8)` and string concatenation:** Do not write raw JSON. Use Zig structs + `std.json.Stringify.valueAlloc` as done in `json_output.zig`.
- **Using 0-indexed columns:** SARIF requires 1-indexed. `start_col` in `ThresholdResult` is 0-indexed (per CLAUDE.md). Always add +1.
- **Absolute file URIs:** GitHub Code Scanning requires relative URIs (relative to repo root). The existing file paths in results are already relative — use them as-is.
- **Omitting `$schema`:** GitHub's validator requires this field. Without it, uploads may fail silently or be rejected.
- **Omitting `ruleId` from results:** Required by GitHub. Without it, results are not displayed as annotations.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization | Custom write loop | `std.json.Stringify.valueAlloc` | Already proven in json_output.zig; handles escaping, nesting, types |
| Schema validation | Custom validator | Test against GitHub upload | Impractical in Zig; validate via integration test |
| Level mapping | Custom logic | Direct `ThresholdStatus` to string | Two cases only: `.warning` → `"warning"`, `.@"error"` → `"error"` |

**Key insight:** SARIF output is a pure data transformation. The hard work (analysis, thresholds, violations) is already done in prior phases. This phase only needs to reshape `[]FileThresholdResults` into the SARIF JSON schema.

---

## Common Pitfalls

### Pitfall 1: Column Indexing Off-By-One

**What goes wrong:** SARIF requires 1-indexed columns. The codebase stores `start_col` as 0-indexed (per CLAUDE.md: "Columns are 0-indexed"). If columns are used directly, every column annotation in GitHub will be off by one.

**Why it happens:** CLAUDE.md explicitly documents the 0-indexed convention for internal data. SARIF spec (section 3.30.4) uses 1-indexed.

**How to avoid:** Always use `result.start_col + 1` when writing `startColumn` in SARIF. Lines (`start_line`) are already 1-indexed — no conversion needed.

**Warning signs:** Column highlights in GitHub PR annotations pointing to the wrong character.

### Pitfall 2: Missing $schema Field

**What goes wrong:** GitHub Code Scanning silently rejects or fails validation without the `$schema` field.

**Why it happens:** It looks optional since SARIF JSON parses without it.

**How to avoid:** Always include `"$schema": "https://json.schemastore.org/sarif-2.1.0.json"` as the first field in the output.

**Warning signs:** SARIF file uploads without error but no annotations appear in PRs.

### Pitfall 3: Zig Struct Field `$schema` Naming

**What goes wrong:** Zig field names cannot start with `$`. The `$schema` field requires special handling.

**Why it happens:** `$schema` is a valid JSON key but invalid Zig identifier.

**How to avoid:** Use `@"$schema"` syntax in Zig struct definition:
```zig
pub const SarifLog = struct {
    @"$schema": []const u8,
    version: []const u8,
    runs: []const SarifRun,
};
```
`std.json.Stringify` will correctly serialize `@"$schema"` as `"$schema"` in the output.

**Warning signs:** Compilation error "expected identifier, found '$'" when defining the struct.

### Pitfall 4: Baseline Failure Without File-Level Location

**What goes wrong:** Health score violations are file-level (not tied to a specific function line). SARIF requires a location. An invalid location causes GitHub to reject the result.

**Why it happens:** Health score is computed per-file with no line association.

**How to avoid:** Use `"startLine": 1` for health score results — this is a valid SARIF location pointing to the top of the file.

**Warning signs:** Blank or invalid `region` in baseline failure results.

### Pitfall 5: Non-Relative URIs

**What goes wrong:** GitHub requires URIs relative to the repository root. Absolute paths (starting with `/`) are not resolved correctly against `checkout_path`.

**Why it happens:** Easy to accidentally prefix with the working directory.

**How to avoid:** The existing `fr.path` in `FileThresholdResults` is already relative (set during file discovery). Use it directly in `artifactLocation.uri`.

**Warning signs:** Annotations appear in the wrong file or "file not found" errors in upload.

### Pitfall 6: Empty Results Array

**What goes wrong:** When there are no violations, the `results` array is empty `[]`. This is valid SARIF and GitHub handles it correctly — no annotations appear, and the run still shows as completed.

**Why it happens:** Not a bug, but worth documenting as expected behavior.

**How to avoid:** No special handling needed. Always emit the `runs` array even with empty `results`.

---

## Code Examples

Verified patterns from official sources:

### Minimal Valid SARIF for GitHub Code Scanning

```json
{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "complexity-guard",
          "version": "0.4.0",
          "rules": []
        }
      },
      "results": []
    }
  ]
}
```
Source: GitHub Code Scanning docs (https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)

### Complete Result with Region Covering Function Body

```json
{
  "ruleId": "complexity-guard/cyclomatic",
  "ruleIndex": 0,
  "level": "error",
  "message": {
    "text": "Cyclomatic complexity is 25 (warning threshold: 10, error threshold: 20)"
  },
  "locations": [
    {
      "physicalLocation": {
        "artifactLocation": {
          "uri": "src/utils.ts"
        },
        "region": {
          "startLine": 42,
          "startColumn": 1,
          "endLine": 85
        }
      }
    }
  ]
}
```

Note: `startColumn` here is 1 (function starts at column 0 internally → +1 = 1 in SARIF).

### Rule Descriptor with helpUri

```json
{
  "id": "complexity-guard/cyclomatic",
  "name": "CyclomaticComplexity",
  "shortDescription": {
    "text": "Cyclomatic complexity exceeded threshold"
  },
  "fullDescription": {
    "text": "McCabe cyclomatic complexity counts the number of linearly independent paths through a function. Each branch point (if, for, while, &&, ||, ternary, ??, ?.) adds 1. High complexity correlates with increased defect density and testing burden. Warning at 10, error at 20."
  },
  "defaultConfiguration": {
    "level": "warning"
  },
  "helpUri": "https://complexity-guard.dev/docs/cyclomatic-complexity",
  "help": {
    "text": "Refactor functions with high cyclomatic complexity by extracting sub-functions or reducing conditional branching."
  }
}
```

Source: SARIF 2.1.0 spec section 3.49 (reportingDescriptor)

### GitHub Actions Workflow (Complete, Copy-Paste Ready)

```yaml
name: Complexity Guard

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  complexity:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install complexity-guard
        run: |
          curl -sSL https://github.com/your-org/complexity-guard/releases/latest/download/complexity-guard-linux-x86_64 \
            -o /usr/local/bin/complexity-guard
          chmod +x /usr/local/bin/complexity-guard

      - name: Run complexity analysis
        run: complexity-guard --format sarif . > results.sarif

      - name: Upload SARIF to GitHub Code Scanning
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: results.sarif
          category: complexity-guard
```

Source: GitHub Docs (https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)

### Column Conversion (Zig)

```zig
// ThresholdResult.start_col is 0-indexed (per CLAUDE.md)
// SARIF region.startColumn is 1-indexed (per SARIF spec section 3.30.4)
const sarif_start_column: u32 = result.start_col + 1;
```

### Format Dispatch in main.zig (extending existing pattern)

```zig
// Current:
if (std.mem.eql(u8, effective_format, "json")) {
    // JSON output
} else {
    // Console output (default)
}

// Phase 9 pattern:
if (std.mem.eql(u8, effective_format, "json")) {
    // JSON output (existing)
} else if (std.mem.eql(u8, effective_format, "sarif")) {
    // SARIF output (new)
    const sarif_result = try sarif_output.buildSarifOutput(
        arena_allocator,
        file_results,
        version,
        baseline_failed,
        cfg.baseline,
        parsed_metrics,
    );
    const sarif_str = try sarif_output.serializeSarifOutput(arena_allocator, sarif_result);
    defer arena_allocator.free(sarif_str);
    try stdout.writeAll(sarif_str);
    try stdout.writeAll("\n");
} else {
    // Console output (existing)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SARIF 2.0 | SARIF 2.1.0 | 2019 (OASIS ratification) | GitHub only accepts 2.1.0 |
| `upload-sarif@v2/v3` | `upload-sarif@v4` | 2024 | v4 is current; v2/v3 deprecated |
| `$schema: raw GitHub URL` | `$schema: schemastore.org URL` | ~2020 | schemastore is canonical |

**Note on `partialFingerprints`:** GitHub's `upload-sarif` action automatically computes `partialFingerprints.primaryLocationLineHash` if not present in the SARIF file. We do not need to implement fingerprinting — GitHub handles deduplication for us.

---

## Open Questions

1. **helpUri base URL**
   - What we know: Must link to a hosted docs page per the locked decision. The docs/ directory exists locally at `docs/cyclomatic-complexity.md`, etc.
   - What's unclear: The exact hosted URL structure (e.g., `https://complexity-guard.dev/docs/...` or GitHub Pages URL).
   - Recommendation: Use a placeholder like `https://github.com/your-org/complexity-guard/blob/main/docs/cyclomatic-complexity.md` for now, or make it configurable. The GitHub raw URL is acceptable for initial implementation.

2. **Halstead sub-rules granularity**
   - What we know: The user delegated to Claude's discretion which Halstead sub-metrics get separate rules.
   - Recommendation: Four separate rules: `halstead-volume`, `halstead-difficulty`, `halstead-effort`, `halstead-bugs`. Each maps directly to a `ThresholdResult` field and status. This follows the "granular sub-rules" principle from the locked decisions.

3. **Health score result location precision**
   - What we know: Health score violations are file-level. SARIF needs a location.
   - What's unclear: Should the location be the whole file (no region) or line 1?
   - Recommendation: Use `startLine: 1` with no `endLine` — this is the convention for file-level SARIF annotations. GitHub renders it as a file-level annotation rather than inline.

4. **Threshold values in messages**
   - What we know: Messages should include "score + threshold format". The SARIF module needs access to the configured threshold values (e.g., cyclomatic warning=10, error=20) to build these strings.
   - What's unclear: How to pass threshold configs into `buildSarifOutput`. The `cycl_config`, `cog_config`, etc. are constructed in `main.zig`.
   - Recommendation: Pass a `SarifThresholds` struct to `buildSarifOutput` aggregating all threshold values. This mirrors how `MetricThresholds` is passed to `scoring.computeFunctionScore`.

---

## Sources

### Primary (HIGH confidence)
- SARIF 2.1.0 OASIS Specification: https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html — structure, column indexing, result schema
- GitHub Code Scanning SARIF Support: https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning — GitHub-specific requirements, limits, required fields
- GitHub Uploading SARIF: https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github — Actions workflow pattern, `upload-sarif@v4`, required permissions

### Secondary (MEDIUM confidence)
- Microsoft SARIF Tutorials (github.com/microsoft/sarif-tutorials): minimal valid SARIF structure, `ruleIndex` usage — cross-referenced with OASIS spec
- SARIF Schema (github.com/oasis-tcs/sarif-spec): schema-level field validation

### Tertiary (LOW confidence)
- Community tooling patterns (gitleaks, MegaLinter): column indexing conventions in practice — confirmed by spec

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — SARIF 2.1.0 is finalized; GitHub's requirements are documented at official docs
- Architecture: HIGH — directly mirrors existing json_output.zig pattern; struct shape derived from official spec
- Pitfalls: HIGH — column indexing and $schema issues verified against official docs and spec
- Open questions: MEDIUM — helpUri URL and threshold passing are implementation details to decide during planning

**Research date:** 2026-02-17
**Valid until:** 2026-08-17 (SARIF spec stable; GitHub API changes slowly)
