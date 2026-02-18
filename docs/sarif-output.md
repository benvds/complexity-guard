# SARIF Output

SARIF (Static Analysis Results Interchange Format) is an open standard for sharing static analysis results. When you run ComplexityGuard with `--format sarif`, it produces a SARIF 2.1.0 file that GitHub Code Scanning understands natively — giving you inline complexity annotations directly on pull request diffs.

No server, no SaaS, no tokens. Just generate the file and upload it.

## Quick Start

```sh
# Generate SARIF output (redirect to file)
complexity-guard --format sarif . > results.sarif

# Or write directly to a file
complexity-guard --format sarif --output results.sarif .

# Focus on specific metrics
complexity-guard --format sarif --metrics cyclomatic,cognitive . > results.sarif
```

## GitHub Actions Workflow

Here is a complete, copy-paste-ready workflow that runs ComplexityGuard and uploads results to GitHub Code Scanning. Violations appear as inline annotations on pull request diffs.

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
        run: npm install -g complexity-guard

      - name: Run complexity analysis
        run: complexity-guard --format sarif . > results.sarif
        continue-on-error: true

      - name: Upload SARIF to GitHub Code Scanning
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: results.sarif
          category: complexity-guard
```

**Why `continue-on-error: true`?** ComplexityGuard exits with a non-zero code when violations are found. Without `continue-on-error`, the upload step would be skipped — so the SARIF file never reaches GitHub Code Scanning. With it, analysis runs, SARIF is generated, and the upload always happens regardless of violations.

**Permissions:** The `security-events: write` permission is required for the `upload-sarif` action. The `actions: read` and `contents: read` permissions are needed by CodeQL action internals.

## Rule Reference

ComplexityGuard defines 10 SARIF rules — one per metric threshold. All 10 rules always appear in the SARIF output regardless of `--metrics` filtering (rules describe detection capability; only the `results` array is filtered).

| Rule ID | Name | Triggers When |
|---------|------|---------------|
| `complexity-guard/cyclomatic` | CyclomaticComplexity | Cyclomatic complexity exceeds threshold |
| `complexity-guard/cognitive` | CognitiveComplexity | Cognitive complexity exceeds threshold |
| `complexity-guard/halstead-volume` | HalsteadVolume | Halstead volume exceeds threshold |
| `complexity-guard/halstead-difficulty` | HalsteadDifficulty | Halstead difficulty exceeds threshold |
| `complexity-guard/halstead-effort` | HalsteadEffort | Halstead effort exceeds threshold |
| `complexity-guard/halstead-bugs` | HalsteadBugs | Halstead estimated bugs exceed threshold |
| `complexity-guard/line-count` | LineCount | Function line count exceeds threshold |
| `complexity-guard/param-count` | ParamCount | Parameter count exceeds threshold |
| `complexity-guard/nesting-depth` | NestingDepth | Nesting depth exceeds threshold |
| `complexity-guard/health-score` | HealthScore | File health score below baseline |

Each rule has a full description, help text, and a `helpUri` link to the relevant documentation page. GitHub Code Scanning surfaces these in its rule details panel.

## Severity Mapping

SARIF results have a `level` field — `warning` or `error`. ComplexityGuard maps threshold violations to SARIF levels as follows:

| Condition | SARIF Level | GitHub Annotation |
|-----------|-------------|-------------------|
| Warning threshold reached | `warning` | Yellow annotation in PR |
| Error threshold reached | `error` | Red annotation in PR |
| Baseline health score failure | `error` | Red annotation at file level |

When a function exceeds the **warning threshold** but not the error threshold, the SARIF result has `"level": "warning"`. When it exceeds the **error threshold**, it gets `"level": "error"`. Baseline failures (health score below the saved baseline) are always emitted as errors at file level (line 1, column 1).

## Filtering with --metrics

Use `--metrics` to limit which violation types appear in the SARIF output. This is useful for phased rollout — start with one metric family, validate it with your team, then add more:

```sh
# Phase 1: Start with just cyclomatic complexity
complexity-guard --format sarif --metrics cyclomatic . > results.sarif

# Phase 2: Add cognitive complexity
complexity-guard --format sarif --metrics cyclomatic,cognitive . > results.sarif

# Phase 3: Full analysis
complexity-guard --format sarif . > results.sarif
```

When `--metrics` is specified, only violations for the listed families appear in the `results` array. All 10 rules still appear in `driver.rules` — filtering applies to results only.

## Message Format

SARIF result messages follow a consistent format so they read clearly in GitHub Code Scanning annotations.

**Function-level violation:**
```
Cyclomatic complexity is 15 (warning threshold: 10, error threshold: 20)
```

**Parameter count violation:**
```
Parameter count is 5 (warning threshold: 3, error threshold: 6)
```

**Health score baseline failure (file-level):**
```
File health score: 42.5 (baseline: 60.0). Worst contributors: cyclomatic (3 violations), cognitive (2 violations)
```

The function name and file location appear in the SARIF `location` field, which GitHub Code Scanning uses to place the annotation on the correct line of the diff.

## SARIF Structure

ComplexityGuard produces a standards-compliant SARIF 2.1.0 document. Here is a trimmed example showing the top-level shape:

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "ComplexityGuard",
          "version": "0.4.0",
          "informationUri": "https://github.com/benvds/complexity-guard",
          "rules": [
            {
              "id": "complexity-guard/cyclomatic",
              "name": "CyclomaticComplexity",
              "shortDescription": {
                "text": "Cyclomatic complexity measures the number of independent code paths through a function."
              },
              "helpUri": "https://github.com/benvds/complexity-guard/blob/main/docs/cyclomatic-complexity.md"
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "complexity-guard/cyclomatic",
          "level": "warning",
          "message": {
            "text": "Cyclomatic complexity is 15 (warning threshold: 10, error threshold: 20)"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "src/auth/login.ts"
                },
                "region": {
                  "startLine": 67,
                  "startColumn": 1
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

The `runs[0].tool.driver.rules` array always contains all 10 rules. The `runs[0].results` array contains only the violations found (filtered by `--metrics` if specified). Columns in `region` are 1-indexed per the SARIF spec.

For the full SARIF 2.1.0 specification, see the [OASIS SARIF spec](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html).

## Tips

**File size limits:** GitHub Code Scanning has a 5,000 result limit per SARIF file. For very large codebases that produce many violations, use `--metrics` to focus on specific metric families:

```sh
# Focus on the two most actionable metrics first
complexity-guard --format sarif --metrics cyclomatic,cognitive . > results.sarif
```

**Stdout vs file:** Both approaches work identically:

```sh
# Redirect stdout
complexity-guard --format sarif . > results.sarif

# Or use --output flag
complexity-guard --format sarif --output results.sarif .
```

**Annotations on PR diffs:** GitHub Code Scanning annotations only appear on lines that changed in the PR. If a complex function exists in an unchanged file, it will appear in the Security tab but not as a diff annotation. This is a GitHub Code Scanning behavior, not a ComplexityGuard limitation.

**Fingerprinting:** You do not need to add `partialFingerprints` manually — GitHub Code Scanning auto-computes them from the file content and location to track issues across commits.

**Inspect before uploading:**

```sh
# Count results
complexity-guard --format sarif . | jq '.runs[0].results | length'

# List all rule IDs that triggered
complexity-guard --format sarif . | jq '[.runs[0].results[].ruleId] | unique'

# See warning vs error breakdown
complexity-guard --format sarif . | jq '.runs[0].results | group_by(.level) | map({level: .[0].level, count: length})'
```

## Links

- [CLI Reference](cli-reference.md) — `--format sarif`, `--metrics`, `--output` flags
- [Getting Started](getting-started.md) — Installation and configuration basics
- [Health Score](health-score.md) — Baseline workflow that drives health-score SARIF results
- [Cyclomatic Complexity](cyclomatic-complexity.md) — Rule `complexity-guard/cyclomatic`
- [Cognitive Complexity](cognitive-complexity.md) — Rule `complexity-guard/cognitive`
- [Halstead Metrics](halstead-metrics.md) — Rules `complexity-guard/halstead-*`
- [Structural Metrics](structural-metrics.md) — Rules `complexity-guard/line-count`, `complexity-guard/param-count`, `complexity-guard/nesting-depth`
