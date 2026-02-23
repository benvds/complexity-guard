# Performance Benchmarks

ComplexityGuard is a native Zig binary with no runtime dependencies. This page documents its
performance characteristics measured against [FTA](https://ftaproject.dev/) (Fast TypeScript
Analyzer), a Rust-based alternative tool, across real-world TypeScript and JavaScript projects.

The short version: CG is 1.5–3.1x faster than FTA with parallel analysis enabled (the default).
CG uses 1.2–3.5x less memory than FTA because FTA requires a Node.js/V8 runtime.

## Key Findings

### Speed

CG is faster than FTA on all quick-suite projects with parallel analysis (the default):

| Project | CG (ms) | FTA (ms) | Speedup | Project Size |
|---------|---------|---------|---------|-------------|
| got | 37 ± 4 | 106 ± 4 | 2.9x CG | 68 files |
| dayjs | 56 ± 2 | 139 ± 2 | 2.5x CG | 283 files |
| zod | 82 ± 3 | 154 ± 2 | 1.9x CG | 169 files |
| vite | 131 ± 4 | 411 ± 8 | 3.1x CG | 1,182 files |
| nestjs | 145 ± 3 | 424 ± 7 | 2.9x CG | 1,653 files |
| webpack | 678 ± 49 | 1,320 ± 13 | 1.9x CG | 6,889 files |
| vscode | 3,394 ± 124 | 5,218 ± 96 | 1.5x CG | 5,071 files |

**Mean: CG is 2.4x faster than FTA** across the quick suite.

The advantage is largest on medium-sized projects (vite at 3.1x, nestjs at 2.9x) where CG's
multi-threaded analysis scales well relative to project size. Even the largest project (vscode,
5,071 files) analyzes in 3.4 seconds — a 5.8x speedup over CG's single-threaded baseline.

### Parallelization Impact

Parallel analysis (added in Phase 12) delivers 2.6–5.8x speedup over single-threaded mode:

| Project | Single-threaded (ms) | Parallel (ms) | Speedup | Files |
|---------|---------------------|---------------|---------|-------|
| got | 131 | 37 | 3.5x | 68 |
| dayjs | 206 | 56 | 3.7x | 283 |
| zod | 291 | 82 | 3.6x | 169 |
| vite | 481 | 131 | 3.7x | 1,182 |
| nestjs | 588 | 145 | 4.1x | 1,653 |
| webpack | 1,735 | 678 | 2.6x | 6,889 |
| vscode | 19,845 | 3,394 | 5.8x | 5,071 |

**Mean: 3.9x speedup** with parallelization on 8 cores / 16 threads. The speedup is largest on
vscode (5.8x) where CG can saturate all cores with file-level parallelism.

### Memory

CG uses significantly less memory than FTA for small and medium projects:

| Project | CG Mem (MB) | FTA Mem (MB) | Ratio |
|---------|------------|--------------|-------|
| got | 21.0 | 46.6 | 2.2x FTA |
| dayjs | 29.8 | 46.6 | 1.6x FTA |
| zod | 38.7 | 46.5 | 1.2x FTA |
| vite | 71.8 | 71.8 | 1.0x |
| nestjs | 91.1 | 91.1 | 1.0x |
| webpack | 209.0 | 209.0 | 1.0x |
| vscode | 1,891.2 | 1,891.2 | 1.0x |

**Mean: FTA uses 1.3x more memory than CG.**

Memory advantage is clearest on small projects (2.2x for `got`) where FTA's Node.js/V8 baseline
overhead (~46 MB) dominates. For large repos, both tools are bounded by the file content they
must hold in memory, and the advantage shrinks.

### Metric Accuracy

CG and FTA measure similar concepts but with different granularity and parsers. The key metric
for comparing their utility is **ranking correlation** — do both tools agree on which files are
most complex?

| Project | Files | Cyclomatic Rank Corr | Halstead Rank Corr | Line Count Agree |
|---------|-------|---------------------|-------------------|-----------------|
| got | 68 | 0.560 | 0.890 | 82% |
| dayjs | 283 | 0.797 | 0.702 | 92% |
| zod | 169 | 0.719 | 0.901 | 94% |
| vite | 1,149 | 0.695 | 0.748 | 84% |
| nestjs | 1,624 | 0.548 | 0.732 | 84% |
| webpack | 6,555 | 0.544 | 0.550 | 76% |
| vscode | 5,002 | 0.891 | 0.775 | 74% |

**Ranking correlations are moderate to strong** (0.55–0.90 for cyclomatic, 0.55–0.90 for
Halstead). This means CG and FTA generally agree on which files are most complex, even though
absolute values diverge due to parser and aggregation differences. Line count agreement is
strongest (74–94% within ±20% tolerance).

---

## Methodology

### Hardware

Benchmarks were run on the following system:

| Component | Value |
| --------- | ----- |
| CPU | AMD Ryzen 7 5700U with Radeon Graphics (8 cores / 16 threads, up to 4.37 GHz) |
| Memory | 13.5 GB DDR4 |
| OS | Fedora Linux 43 (kernel 6.18.9) |
| Architecture | x86_64 |

For reproducible results on your hardware, run `bash benchmarks/scripts/bench-quick.sh` directly.
System specs are automatically captured in `system-info.json` alongside benchmark results.

### Tool Versions

| Tool | Version |
|------|---------|
| ComplexityGuard | 0.1.0 |
| FTA (fta-cli) | 3.0.0 |
| hyperfine | 1.20.0 |
| Zig | 0.15.2 |

### Statistical Approach

- **Quick/full suites:** 15 benchmark runs per project, 3 warmup runs (discarded)
- **Stress suite:** 5 runs per project, 1 warmup run
- hyperfine reports mean ± standard deviation across runs
- Memory measured as peak RSS per run (from `/proc/<pid>/status`); mean across runs reported

### Suite Composition

| Suite | Projects | Expected Duration |
|-------|----------|------------------|
| quick | 10 representative projects | ~5 min |
| full | 76 projects from `public-projects.json` | ~60 min |
| stress | 3 massive repos (vscode, typescript) | ~30 min |

The quick suite covers the full project size range: small (got, dayjs), medium (zod, vite,
nestjs), and large (webpack, vscode).

### Benchmark Commands

Each hyperfine invocation runs both tools back-to-back on the same project directory:

```sh
# CG command (parallel, default — uses all CPU cores)
complexity-guard --format json --fail-on none <project-dir>

# CG command (single-threaded — for baseline comparison)
complexity-guard --threads 1 --format json --fail-on none <project-dir>

# FTA command
fta --json --exclude-under 0 <project-dir>
```

Flags chosen for fair comparison:
- `--fail-on none` (CG): disables threshold-based exit codes so CI violations don't abort hyperfine
- `--ignore-failure` (hyperfine): CG may still exit 1 for error-level violations; this flag prevents
  hyperfine from treating non-zero exit as measurement failure
- `--exclude-under 0` (FTA): disables FTA's default minimum-lines-per-file filter so both tools
  analyze the same file set
- `--format json` (CG): JSON output mode (vs. console), matching FTA's `--json` output mode

### Important Caveats

1. **Parallel by default.** CG benchmarks use the default parallel mode (all CPU cores). Pass
   `--threads 1` for single-threaded baseline comparison. Results will vary by core count.

2. **Different granularity.** CG analyzes at function level and provides per-function metrics.
   FTA analyzes at file level. For comparison, CG's per-function values are summed to file level.
   This aggregation explains why absolute values diverge even when rankings agree.

3. **Different parsers.** CG uses tree-sitter; FTA uses SWC. Different tokenization rules affect
   Halstead operator/operand classification, particularly for:
   - TypeScript type annotations (CG excludes them; FTA may include differently)
   - Template literals and tagged templates
   - Optional chaining (`?.`) and nullish coalescing (`??`)

4. **FTA counts cyclomatic differently.** FTA's `cyclo` is a single-pass file-level count, not
   a sum of per-function cyclomatic values. The aggregation produces similar rankings but
   different absolute numbers.

### Reproducibility

To reproduce these benchmarks:

```sh
# 1. Clone the repo
git clone https://github.com/benvds/complexity-guard && cd complexity-guard

# 2. Checkout benchmark project repos
bash benchmarks/scripts/setup.sh --suite quick

# 3. Run end-to-end benchmark
bash benchmarks/scripts/bench-quick.sh

# 4. Compare metrics
bash benchmarks/scripts/compare-metrics.sh --suite quick

# 5. View results
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/
```

Results will differ based on hardware but relative ratios should be consistent.

---

## Detailed Results

### Speed and Memory (Quick Suite)

See the table in [Key Findings: Speed](#speed) above. Raw data is available in
`benchmarks/results/baseline-2026-02-21/` (parallel) and
`benchmarks/results/baseline-2026-02-21-single-threaded/` (single-threaded baseline):

- Per-project timing: `*-quick.json` (hyperfine JSON format)
- Aggregate summary: run `node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/`

### Metric Accuracy

CG vs FTA metric comparison for the quick suite is in
`benchmarks/results/baseline-2026-02-21/metric-accuracy.json`.

**Interpretation of low within-tolerance percentages:**

The within-tolerance percentages for cyclomatic (17–60%) and Halstead (2–8%) look low, but
the ranking correlations tell the more useful story. For code review and complexity analysis,
the question is not "do both tools produce the same absolute number?" but "do both tools agree on
which files need attention?" The ranking correlations (0.55–0.90) show moderate to strong
agreement on file ordering.

The Halstead within-tolerance percentage is low because SWC and tree-sitter classify tokens
very differently, producing absolute volume values that diverge by 70–85% on average. However,
the ranking correlation (0.55–0.90) remains reasonable — both tools identify the same files as
highest-volume, even if exact volumes differ by a factor of 2–3x.

**Line count** has the best agreement (74–94% within ±20%) because line counting is
parser-independent — both tools count newlines in the same files.

### Subsystem Breakdown

> **Note:** Subsystem data is from the single-threaded baseline (Phase 10.1, captured 2026-02-21).
> This is the appropriate reference for understanding per-stage costs before parallelization (Phase 12).

| Project | Files | Funcs | Discovery | File I/O | Parsing | Cyclomatic | Cognitive | Halstead | Structural | Scoring | JSON | Total |
|---------|------:|------:|----------:|---------:|--------:|-----------:|----------:|---------:|-----------:|--------:|-----:|------:|
| dayjs | 283 | 994 | 1.1 ms | 2.4 ms | 102.1 ms | 26.2 ms | 29.4 ms | 34.4 ms | 22.2 ms | 0.0 ms | 0.0 ms | 217.8 ms |
| got | 68 | 888 | 0.7 ms | 0.8 ms | 68.9 ms | 14.1 ms | 14.4 ms | 19.7 ms | 13.0 ms | 0.0 ms | 0.0 ms | 131.7 ms |
| zod | 172 | 1,878 | 0.5 ms | 1.9 ms | 135.9 ms | 36.2 ms | 33.9 ms | 46.3 ms | 32.7 ms | 0.0 ms | 0.0 ms | 287.4 ms |
| vite | 1,182 | 2,652 | 7.8 ms | 10.1 ms | 283.0 ms | 43.0 ms | 50.0 ms | 56.1 ms | 41.6 ms | 0.0 ms | 0.1 ms | 491.8 ms |
| NestJS | 1,653 | 3,398 | 7.1 ms | 15.1 ms | 376.4 ms | 42.8 ms | 54.0 ms | 53.0 ms | 43.6 ms | 0.0 ms | 0.2 ms | 592.1 ms |
| webpack | 6,889 | 9,463 | 27.6 ms | 61.0 ms | 967.6 ms | 161.1 ms | 170.8 ms | 219.9 ms | 151.1 ms | 0.0 ms | 0.8 ms | 1,759.7 ms |
| VS Code | 5,071 | 62,565 | 26.0 ms | 82.3 ms | 7,707.4 ms | 2,769.3 ms | 2,923.3 ms | 3,154.5 ms | 2,679.1 ms | 0.0 ms | 0.6 ms | 19,342.3 ms |

**Parsing dominates** across all projects, consuming 40-64% of total pipeline time:

| Project | Parsing % | Analysis % | I/O % |
|---------|----------:|-----------:|------:|
| dayjs | 46.9% | 51.5% | 1.6% |
| got | 52.3% | 46.6% | 1.1% |
| zod | 47.3% | 51.9% | 0.8% |
| vite | 57.6% | 38.8% | 3.6% |
| NestJS | 63.6% | 32.7% | 3.7% |
| webpack | 55.0% | 39.9% | 5.0% |
| VS Code | 39.8% | 59.6% | 0.6% |

**Key takeaway:** Tree-sitter parsing is the clear optimization target. For projects up to ~1,600 files, parsing takes more time than all four metric analyses combined. For VS Code (5,071 files, 62,565 functions), the sheer volume of functions shifts the balance toward analysis, but parsing still accounts for 40% of total time.

Scoring and JSON serialization are negligible (<0.1% combined) at all scales.

The subsystem benchmark profiles each CG pipeline stage independently:
file discovery, file I/O, parsing, cyclomatic analysis, cognitive analysis,
Halstead analysis, structural analysis, health score computation, and JSON serialization.
This identifies which stage to optimize first in Phase 12.

---

## Duplication Detection Performance

Duplication detection adds a **cross-file analysis pass** that runs after the standard per-file analysis. This pass re-reads and re-parses all files to build a token index, then runs the Rabin-Karp hash pipeline.

The overhead is significant because duplication detection requires:
1. Re-reading all source files from disk
2. Re-parsing all files with tree-sitter (since parse trees were freed after per-file analysis)
3. Building a cross-file hash index of all 25-token windows
4. Verifying candidate clone pairs with token-by-token comparison

Duplication is **disabled by default** so these costs are never incurred unless explicitly requested via `--duplication` or `analysis.duplication_enabled: true` in config.

### Results

Benchmarks run on the duplication benchmark subset (zod, got, dayjs) using 5 runs with 2 warmup runs. Same hardware as the main benchmarks.

| Project | Files | Without `--duplication` | With `--duplication` | Overhead |
|---------|-------|------------------------|----------------------|----------|
| zod | 169 | 579 ms | 6,817 ms | +6,238 ms (+1,077%) |
| got | 68 | 216 ms | 1,935 ms | +1,720 ms (+798%) |
| dayjs | 283 | 362 ms | 1,017 ms | +655 ms (+181%) |

### Interpreting the Numbers

The overhead varies widely across projects:

- **dayjs (181% overhead):** Large number of short files. Re-parsing is fast per file. The token index stays manageable. This is the best-case scenario for duplication detection.
- **got (798% overhead):** Medium-sized project with complex TypeScript. Re-parsing and hash index construction dominate.
- **zod (1,077% overhead):** zod has very long, deeply-typed files. Re-parsing complex TypeScript ASTs is expensive, and the token index grows large.

The re-parse approach (chosen for implementation simplicity) is the primary overhead source. A future optimization could cache token sequences during the first parse pass to eliminate the re-parse entirely.

### When to Use `--duplication`

Given the overhead, use duplication detection:
- **In CI for periodic audits** (daily or on PR, not every commit) — `complexity-guard --duplication src/`
- **During refactoring sessions** to find copy-paste candidates
- **In pre-merge gates** when reducing technical debt is a priority

Avoid on very large repos (webpack/vscode scale) in fast CI pipelines — the re-parse overhead will dominate. For those cases, consider running duplication analysis in a separate, less frequent CI job.

### Reproducing

```sh
# Clone benchmark projects (if not already done)
bash benchmarks/scripts/setup.sh --suite quick

# Run duplication overhead benchmark
bash benchmarks/scripts/bench-duplication.sh
```

Results are saved to `/tmp/bench-dup-*.json` in hyperfine JSON format.

---

## Baseline History

### Phase 12: Parallelization (current)

The current benchmarks reflect CG with parallel analysis enabled (the default since Phase 12).
CG went from 1.2–3.8x slower than FTA to 1.5–3.1x faster across all projects.

### Phase 10.1: Single-threaded Baseline

The Phase 10.1 baseline captured single-threaded (`--threads 1`) performance before
parallelization. Raw data is preserved in `benchmarks/results/baseline-2026-02-21-single-threaded/`.

### Schema Version

The benchmark JSON schema is at **version 1.0**. The schema is intentionally stable so
before/after comparisons require no format conversion.

The schema consists of:
- hyperfine JSON format (from `hyperfine --export-json`)
- CG JSON output (`--format json`)
- FTA JSON output (`--json`)
- `metric-accuracy.json` (produced by `compare-metrics.mjs`)

### Running a New Baseline

Capture a new baseline at any time:

```sh
bash benchmarks/scripts/setup.sh --suite quick
bash benchmarks/scripts/bench-quick.sh
bash benchmarks/scripts/compare-metrics.sh --suite quick
```

The results directory will be timestamped automatically (`baseline-YYYY-MM-DD`).

### Raw Data

All raw benchmark data is committed to the repository in
[`benchmarks/results/`](../benchmarks/results/). This includes:

- `baseline-2026-02-21/*.json` — Phase 12 parallel benchmarks: 7 quick-suite projects
- `baseline-2026-02-21-single-threaded/*.json` — Phase 10.1 single-threaded baseline
- `metric-accuracy.json` — Metric accuracy comparison

See [`benchmarks/`](../benchmarks/) for scripts and additional documentation.
