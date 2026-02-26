# ComplexityGuard Benchmarks

Performance benchmarks for ComplexityGuard across real-world TypeScript and
JavaScript projects.

## Prerequisites

- **Rust stable toolchain** -- for building ComplexityGuard (`cargo build --release`)
- **[hyperfine](https://github.com/sharkdp/hyperfine)** -- for statistical benchmarking
  ```sh
  cargo install hyperfine
  # or on macOS: brew install hyperfine
  ```
- **jq** -- for JSON extraction in shell scripts
  ```sh
  sudo apt install jq   # Linux
  brew install jq       # macOS
  ```

## Quick Start

Run the complete quick-suite benchmark in two commands:

```sh
# 1. Clone benchmark projects (quick suite)
bash benchmarks/scripts/setup.sh --suite quick

# 2. End-to-end hyperfine speed + memory benchmark
bash benchmarks/scripts/bench-quick.sh
```

Then summarize results:

```sh
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/
```

## Script Reference

| Script | Purpose | Output |
|--------|---------|--------|
| `setup.sh [--suite quick\|full\|stress]` | Clone benchmark project repositories with caching | `benchmarks/projects/<name>/` |
| `bench-quick.sh` | End-to-end hyperfine benchmark, quick suite | `results/*/`*`-quick.json`* |
| `bench-full.sh` | End-to-end hyperfine benchmark, all projects | `results/*/`*`-full.json`* |
| `bench-stress.sh` | Hyperfine benchmark, massive repos (vscode, typescript) | `results/*/`*`-stress.json`* |
| `bench-duplication.sh` | Benchmark duplication detection overhead (with/without `--duplication`) | `/tmp/bench-dup-*.json` |
| `summarize-results.mjs <results-dir>` | Aggregate hyperfine results into markdown tables | Markdown to stdout |

## Suite Tiers

| Suite | Projects | Benchmark Duration | Description |
|-------|----------|-------------------|-------------|
| quick | 10 | ~5 min | Representative set: zod, got, dayjs, vite, nestjs, webpack, vscode + 3 |
| full | 76 | ~60 min | Complete set from `public-projects.json` |
| stress | 2-3 | ~30 min | Massive repos only: vscode, typescript (tests scale ceiling) |

The quick suite is the default. It covers the full size range from small
libraries (got: 68 files) to massive projects (vscode: 5,000+ files).

## Results Directory Structure

```
benchmarks/results/
  baseline-2026-02-21/          # Timestamped baseline directory
    system-info.json              # Hardware specs captured during benchmark run
    zod-quick.json              # hyperfine JSON: CG timings for zod
    got-quick.json              # hyperfine JSON: CG timings for got
    ...
    vscode-quick.json           # hyperfine JSON: CG timings for vscode
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
    }
  ]
}
```

`results[0]` is the ComplexityGuard benchmark.

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

### Speed

`summarize-results.mjs` reports wall-clock analysis time in milliseconds for
ComplexityGuard across each benchmark project. Times are the mean of multiple
hyperfine runs with standard deviation.

**Parallel analysis (default):** CG uses rayon for parallel file processing.
Pass `--threads 1` for single-threaded baseline comparison.

### Memory

Peak RSS memory usage for ComplexityGuard in MB. CG is a native Rust binary with
no runtime dependencies -- memory usage scales with the number and size of files
being analyzed.

## Adding New Benchmark Runs

After making performance-affecting changes, run the benchmarks again using
a new timestamped directory:

```sh
# After performance-affecting changes are merged:
bash benchmarks/scripts/setup.sh --suite quick
bash benchmarks/scripts/bench-quick.sh
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
| Small | got, dayjs | 68-283 |
| Medium | zod, vite, nestjs | 169-1,624 |
| Large | webpack, vscode | 5,000+ |
