# Duplication Detection

Duplication detection finds copy-pasted or structurally identical code blocks across your TypeScript/JavaScript codebase. Where complexity metrics measure individual function complexity, duplication detection measures how much code is being repeated — a key indicator of maintenance burden and technical debt.

Duplication detection is **opt-in**: it does not run by default because it requires an extra cross-file analysis pass. Enable it with the `--duplication` flag or via config.

## Quick Start

Enable duplication detection with a single flag:

```sh
complexity-guard --duplication src/
```

Example output with duplication enabled:

```
src/auth/login.ts
  42:0  ✓  ok  Function 'validateCredentials' cyclomatic 3 cognitive 2
  67:0  ⚠  warning  Function 'processLoginFlow' cyclomatic 12 cognitive 18

src/auth/register.ts
  15:0  ⚠  warning  Function 'validateInput' cyclomatic 4 cognitive 3

Analyzed 12 files, 47 functions
Found 3 warnings, 1 errors
Duplication: 8.2% (project warning threshold: 5%)
Health: 68

✗ 4 problems (1 errors, 3 warnings)
```

## How It Works

ComplexityGuard uses a **Rabin-Karp rolling hash** algorithm to detect duplicate code blocks. The algorithm runs in four stages:

### 1. Tokenization

For each file, ComplexityGuard walks the tree-sitter AST and extracts leaf node tokens:

- **Identifiers are normalized**: all identifier tokens (`identifier`, `property_identifier`, `shorthand_property_identifier`) are replaced with the sentinel value `V`. This enables **Type 2 clone detection** — finding code blocks that have the same structure but use different variable names.
- **Type annotations are skipped**: TypeScript type annotation subtrees are excluded entirely, so `const x: string = "foo"` and `const x: number = "foo"` produce the same token sequence.
- **Comments are stripped**: line comments and block comments are excluded.
- **Punctuation is filtered**: `;` and `,` are skipped, but `{` and `}` are kept to preserve block structure.

### 2. Rolling Hash (Rabin-Karp)

A sliding window of 25 tokens is passed over each file's token sequence. For each window position, a hash is computed using Rabin-Karp arithmetic:

```
hash = (token_1 * base^24 + token_2 * base^23 + ... + token_25 * base^0) mod p
```

The base is 37. As the window slides, the leftmost token is removed and the rightmost token is added in O(1) time. This produces one hash per position without recomputing the entire window.

All hashes are collected into a cross-file index: a map from hash value to the list of file + position locations that produced that hash.

### 3. Verification

Any hash bucket with 2 or more entries is a **candidate clone group**. ComplexityGuard verifies each candidate by comparing token sequences directly — this eliminates false positives from hash collisions.

Buckets with more than 1000 entries are discarded (the `MAX_BUCKET_SIZE` guard). These represent common patterns (e.g., empty function bodies) that would produce O(N²) verification work and are not meaningful clones.

### 4. Interval Merging

Overlapping or adjacent clone windows are merged into maximal spans. This prevents double-counting: if a 50-token block is cloned, it will be represented as one clone spanning all 50 tokens rather than 26 overlapping 25-token windows.

Per-file duplication percentage is computed from the merged intervals:

```
duplication_pct = merged_cloned_tokens / total_tokens * 100
```

## Clone Types

ComplexityGuard detects two types of code clones:

### Type 1: Exact Clones

Byte-for-byte identical code blocks (after stripping comments and whitespace). The most obvious duplication.

```typescript
// processUserData and processItemData are Type 1 clones
function processUserData(users: User[]) {
  const result = [];
  for (const user of users) {
    if (user.active) {
      result.push(user.name);
    }
  }
  return result;
}

function processItemData(items: Item[]) {
  const result = [];
  for (const item of items) {
    if (item.active) {
      result.push(item.name);
    }
  }
  return result;
}
```

These two functions are structurally identical and differ only in variable names — exactly the Type 2 case below. Pure Type 1 clones (with identical identifiers) are rarer in practice.

### Type 2: Identifier-Normalized Clones

Structurally identical code where variable names, parameter names, or property names differ. Detected by normalizing all identifiers to `V` before hashing.

```typescript
// validateEmail and validatePhone are Type 2 clones
function validateEmail(email: string): boolean {
  if (!email) return false;
  return email.includes('@');
}

function validatePhone(phone: string): boolean {
  if (!phone) return false;
  return phone.includes('+');
}
```

After normalization, both functions produce the same token sequence and are flagged as clones.

## Enabling Duplication Detection

There are three equivalent ways to enable duplication analysis:

### 1. CLI Flag

```sh
complexity-guard --duplication src/
```

### 2. Metrics Selection

```sh
complexity-guard --metrics duplication src/
```

Note: when specifying `--metrics`, you can include `duplication` alongside other metric families:

```sh
complexity-guard --metrics cyclomatic,cognitive,duplication src/
```

### 3. Configuration File

```json
{
  "analysis": {
    "duplication_enabled": true
  }
}
```

## Thresholds

Duplication thresholds are applied at two levels: **per-file** and **project-wide**.

### Default Thresholds

| Level | Scope | Warning | Error |
|-------|-------|---------|-------|
| File | Per-file duplication percentage | 15% | 25% |
| Project | Project-wide duplication percentage | 5% | 10% |

A file with 20% duplicated tokens triggers a warning. A project where more than 10% of all tokens are cloned triggers a project-level error.

### Configuring Thresholds

Override defaults in `.complexityguard.json`:

```json
{
  "thresholds": {
    "duplication": {
      "file_warning": 10.0,
      "file_error": 20.0,
      "project_warning": 3.0,
      "project_error": 8.0
    }
  }
}
```

**Strict mode** (new projects):
```json
{
  "thresholds": {
    "duplication": {
      "file_warning": 5.0,
      "file_error": 10.0,
      "project_warning": 2.0,
      "project_error": 5.0
    }
  }
}
```

**Lenient mode** (legacy codebases with known duplication):
```json
{
  "thresholds": {
    "duplication": {
      "file_warning": 25.0,
      "file_error": 40.0,
      "project_warning": 10.0,
      "project_error": 20.0
    }
  }
}
```

## Output Formats

### Console Output

When `--duplication` is enabled, the summary line includes a project-level duplication percentage:

```
Analyzed 12 files, 47 functions
Found 3 warnings, 1 errors
Duplication: 8.2% (project warning threshold: 5%)
Health: 68
```

Files or projects exceeding duplication thresholds appear as additional violations:

```
src/utils/helpers.ts  [duplication 22%  ⚠ warning]
src/utils/validators.ts  [duplication 31%  ✗ error]
```

### JSON Output

When `--duplication` is enabled, the JSON output includes a `duplication` object in the summary and per-file `duplication_pct` fields:

```json
{
  "summary": {
    "files_analyzed": 12,
    "total_functions": 47,
    "warnings": 3,
    "errors": 1,
    "health_score": 68.4,
    "duplication": {
      "project_duplication_pct": 8.2,
      "clone_groups": 4,
      "project_warning": false,
      "project_error": true
    },
    "status": "error"
  },
  "files": [
    {
      "path": "src/utils/helpers.ts",
      "duplication_pct": 22.1,
      "duplication_warning": true,
      "duplication_error": false,
      "functions": [...]
    }
  ]
}
```

### SARIF Output

When `--duplication` is enabled and `--format sarif` is used, duplication violations are emitted as SARIF results with rule IDs:

- `CG-DUP-FILE` — file-level duplication threshold exceeded
- `CG-DUP-PROJECT` — project-level duplication threshold exceeded

Each result includes the file path and duplication percentage in the message text.

### HTML Report

When `--duplication` is enabled and `--format html` is used, the report includes:

- A duplication summary in the project health dashboard
- Per-file duplication percentage in the file breakdown table
- Files with threshold violations highlighted

## Health Score Impact

When duplication is enabled, it is incorporated into the composite health score as a fifth metric family.

The effective weights are re-normalized to sum to 1.0 across all five metrics. With default weights:

| Metric | Default Weight | 4-Metric Mode | 5-Metric Mode (with duplication) |
|--------|---------------|---------------|----------------------------------|
| Cognitive | 0.30 | 0.375 | 0.300 |
| Cyclomatic | 0.20 | 0.250 | 0.200 |
| Halstead | 0.15 | 0.188 | 0.150 |
| Structural | 0.15 | 0.188 | 0.150 |
| Duplication | — | 0.000 | 0.200 |

The duplication weight is fixed at **0.20** (20% of the composite score). The other four weights are renormalized from their configured values to fill the remaining 80%.

Duplication scoring uses a sigmoid function centered at the warning threshold: a file at the warning threshold scores approximately 50. Files with zero duplication score near 100; files at or above the error threshold score near 20.

See [Health Score](health-score.md) for the full scoring formula and weight normalization details.

## Performance

Duplication detection adds a cross-file analysis pass that runs **after** the standard per-file analysis. This pass re-reads and re-parses all files to build the token index, then runs the Rabin-Karp hash pipeline.

Because duplication is opt-in, it never affects the baseline performance of `complexity-guard src/`. The additional overhead only applies when `--duplication` is explicitly passed.

See [Performance Benchmarks](benchmarks.md#duplication-detection-performance) for measured overhead across representative TypeScript projects.

## Configuration Reference

Complete duplication configuration in `.complexityguard.json`:

```json
{
  "analysis": {
    "duplication_enabled": true
  },
  "thresholds": {
    "duplication": {
      "file_warning": 15.0,
      "file_error": 25.0,
      "project_warning": 5.0,
      "project_error": 10.0
    }
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15
  }
}
```

### Fields

**`analysis.duplication_enabled`** (boolean)

Whether to run duplication detection. Default: `false`. Equivalent to passing `--duplication` on the CLI.

**`thresholds.duplication.file_warning`** (float)

Per-file duplication percentage that triggers a warning. Default: `15.0`.

**`thresholds.duplication.file_error`** (float)

Per-file duplication percentage that triggers an error. Default: `25.0`.

**`thresholds.duplication.project_warning`** (float)

Project-wide duplication percentage that triggers a warning. Default: `5.0`.

**`thresholds.duplication.project_error`** (float)

Project-wide duplication percentage that triggers an error. Default: `10.0`.

## See Also

- [Getting Started](getting-started.md) — Installation and first analysis
- [CLI Reference](cli-reference.md) — All flags and configuration options
- [Health Score](health-score.md) — How duplication feeds into the composite score
- [Performance Benchmarks](benchmarks.md) — Speed and overhead measurements
