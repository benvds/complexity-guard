# ComplexityGuard Benchmarks

Performance and metric accuracy benchmarks comparing ComplexityGuard against
[FTA](https://ftaproject.dev/) (Fast TypeScript Analyzer) across real-world
TypeScript and JavaScript projects.

## Prerequisites

- **Rust stable toolchain** — for building ComplexityGuard (`cargo build --release`)
- **Node.js / npm** — FTA is auto-installed per benchmark run (no global install needed)
- **[hyperfine](https://github.com/sharkdp/hyperfine)** — for statistical benchmarking
  ```sh
  cargo install hyperfine
  # or on macOS: brew install hyperfine
  ```
- **jq** — for JSON extraction in shell scripts
  ```sh
  sudo apt install jq   # Linux
  brew install jq       # macOS
  ```

## Quick Start

Run the complete quick-suite benchmark in three commands:

```sh
# 1. Clone benchmark projects (10 projects, quick suite)
bash benchmarks/scripts/setup.sh --suite quick

# 2. End-to-end hyperfine speed + memory benchmark (CG vs FTA)
bash benchmarks/scripts/bench-quick.sh

# 3. Metric accuracy comparison (how well do CG and FTA agree on rankings?)
bash benchmarks/scripts/compare-metrics.sh --suite quick
```

Then summarize results:

```sh
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/
```

## Script Reference

| Script | Purpose | Output |
|--------|---------|--------|
| `setup.sh [--suite quick\|full\|stress]` | Clone benchmark project repositories with caching | `benchmarks/projects/<name>/` |
| `bench-quick.sh` | End-to-end hyperfine benchmark, quick suite (10 projects) | `results/*/`*`-quick.json`* |
| `bench-full.sh` | End-to-end hyperfine benchmark, all 76 projects | `results/*/`*`-full.json`* |
| `bench-stress.sh` | Hyperfine benchmark, massive repos (vscode, typescript) | `results/*/`*`-stress.json`* |
| `compare-metrics.sh [--suite ...]` | Run both tools, compare per-file metrics with tolerance bands | `results/*/metric-accuracy.json` |
| `compare-metrics.mjs <cg> <fta> <proj>` | Per-project metric comparison (called by compare-metrics.sh) | JSON to stdout |
| `summarize-results.mjs <results-dir>` | Aggregate hyperfine + accuracy results into markdown tables | Markdown to stdout |

## Suite Tiers

| Suite | Projects | Benchmark Duration | Description |
|-------|----------|-------------------|-------------|
| quick | 10 | ~5 min | Representative set: zod, got, dayjs, vite, nestjs, webpack, vscode + 3 |
| full | 76 | ~60 min | Complete set from `public-projects.json` |
| stress | 2–3 | ~30 min | Massive repos only: vscode, typescript (tests scale ceiling) |

The quick suite is the default. It covers the full size range from small
libraries (got: 68 files) to massive projects (vscode: 5,000+ files).

## Results Directory Structure

```
benchmarks/results/
  baseline-2026-02-21/          # Timestamped baseline directory
    system-info.json              # Hardware specs captured during benchmark run
    zod-quick.json              # hyperfine JSON: CG vs FTA timings for zod
    got-quick.json              # hyperfine JSON: CG vs FTA timings for got
    ...
    vscode-quick.json           # hyperfine JSON: CG vs FTA timings for vscode
    metric-accuracy.json        # CG vs FTA metric comparison across all projects
```

### Hyperfine JSON Schema

Each `*-quick.json` / `*-full.json` / `*-stress.json` file follows the
[hyperfine JSON export format](https://github.com/sharkdp/hyperfine#export-results):

```json
{
  "results": [
    {
      "command": "<cg command>",
      "mean": 0.291,
      "stddev": 0.003,
      "median": 0.290,
      "times": [...],
      "memory_usage_byte": [...]
    },
    {
      "command": "<fta command>",
      "mean": 0.150,
      "stddev": 0.003,
      ...
    }
  ]
}
```

`results[0]` is always CG; `results[1]` is always FTA.

### Metric Accuracy JSON Schema (`metric-accuracy.json`)

```json
[
  {
    "project": "zod",
    "files_compared": 169,
    "files_cg_only": 3,
    "files_fta_only": 0,
    "cyclomatic": {
      "within_tolerance_pct": 17.2,
      "mean_diff_pct": 57.3,
      "ranking_correlation": 0.719
    },
    "halstead_volume": {
      "within_tolerance_pct": 4.1,
      "mean_diff_pct": 70.2,
      "ranking_correlation": 0.901
    },
    "line_count": {
      "within_tolerance_pct": 94.1,
      "mean_diff_pct": 7.8,
      "ranking_correlation": 0.930
    },
    "methodology": {
      "cg_aggregation": "sum of per-function values",
      "fta_granularity": "file-level",
      "cyclomatic_tolerance": 25.0,
      "halstead_tolerance": 30.0,
      "note": "FTA uses SWC parser; CG uses tree-sitter. Different tokenization causes expected divergence."
    }
  }
]
```

### System Info JSON Schema (`system-info.json`)

Each benchmark results directory contains a `system-info.json` file automatically captured
by the bench scripts. This documents the hardware context for reproducibility and comparison.

```json
{
  "hostname": "fedora.home",
  "os": "Fedora Linux 43",
  "kernel": "6.18.9-200.fc43.x86_64",
  "arch": "x86_64",
  "cpu": {
    "model": "AMD Ryzen 7 5700U with Radeon Graphics",
    "cores": 8,
    "threads": 16,
    "max_mhz": 4374
  },
  "memory": {
    "total_gb": 13.5
  },
  "captured_at": "2026-02-21T00:00:00Z"
}
```

If multiple bench scripts write to the same dated results directory, only the first one
writes `system-info.json` (subsequent scripts skip if the file already exists).

## Interpreting Results

### Speed (Speedup Ratio)

`summarize-results.mjs` reports speedup as `CG time / FTA time`:

- **> 1.0**: FTA is faster than CG (e.g., 1.4x = FTA takes 71% of CG's time)
- **< 1.0**: CG is faster than FTA
- **= 1.0**: Equal performance

**CG with parallel analysis:** CG uses rayon for parallel file processing (the default). It is 1.5-3.1x faster than FTA across the quick suite. Pass --threads 1 for single-threaded baseline comparison.

### Memory (Memory Ratio)

Memory ratio = `FTA RSS / CG RSS`. FTA requires a Node.js runtime (V8 overhead) and
SWC compiled via WebAssembly. CG has no runtime — it's a native Rust binary.

- Smaller projects: FTA uses ~2x more memory (V8 baseline cost)
- Large projects: memory converges (file content dominates V8 overhead)

### Metric Accuracy (Ranking Correlation)

CG operates at **function level** and aggregates to file level for comparison.
FTA operates at **file level** natively.

**Ranking correlation** (Spearman's rho): how well do CG and FTA agree on which
files are most complex? This matters for code review prioritization:

- **0.8–1.0**: Strong agreement — teams using either tool will focus on the same files
- **0.5–0.8**: Moderate agreement — same general direction but different specifics
- **< 0.5**: Weak agreement — tools have fundamentally different complexity models

**Within-tolerance percentage**: what fraction of files have CG and FTA values
within the tolerance band (25% for cyclomatic, 30% for halstead, 20% for line count)?

**Why values diverge:**
- CG uses tree-sitter; FTA uses SWC — different parsers produce different token counts
- CG's cyclomatic: sum of per-function values; FTA's cyclo: file-level single pass
- Halstead in particular diverges because SWC and tree-sitter classify operator/operand
  tokens differently (e.g., type annotations, template literals)

## Adding New Benchmark Runs

After making performance-affecting changes, run the benchmarks again using
a new timestamped directory:

```sh
# After performance-affecting changes are merged:
bash benchmarks/scripts/setup.sh --suite quick
bash benchmarks/scripts/bench-quick.sh
bash benchmarks/scripts/compare-metrics.sh --suite quick
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/
```

Compare the new `baseline-<date>` directory against the previous baseline to
measure the impact of each phase's changes:

```sh
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/ > before.md
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/ > after.md
diff before.md after.md
```

The JSON schema is versioned at schema version 1.0 to ensure direct
before/after comparison without format conversion.

## Project Sources

Benchmark projects are defined in `tests/public-projects.json`. Each entry
specifies a Git URL and tag for reproducible cloning. Projects span the full size
range of real-world TypeScript/JavaScript codebases:

| Size tier | Example projects | Files |
|-----------|-----------------|-------|
| Small | got, dayjs | 68–283 |
| Medium | zod, vite, nestjs | 169–1,624 |
| Large | webpack, vscode | 5,000+ |
