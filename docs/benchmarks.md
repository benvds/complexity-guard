# Performance Benchmarks

ComplexityGuard is a native Zig binary with no runtime dependencies. This page documents its
performance characteristics measured against [FTA](https://ftaproject.dev/) (Fast TypeScript
Analyzer), a Rust-based alternative tool, across real-world TypeScript and JavaScript projects.

The short version: FTA is 1.2–3.8x faster than CG today because CG is single-threaded and FTA
uses multi-threaded I/O. CG uses 1.2–3.5x less memory than FTA because FTA requires a Node.js/V8
runtime. Phase 12 will add parallelization to CG.

## Key Findings

### Speed

FTA is currently faster than CG on most projects:

| Project | CG (ms) | FTA (ms) | Speedup | Project Size |
|---------|---------|---------|---------|-------------|
| got | 131 ± 1 | 104 ± 2 | 1.3x FTA | 68 files |
| dayjs | 206 ± 1 | 137 ± 2 | 1.5x FTA | 283 files |
| zod | 291 ± 3 | 150 ± 3 | 1.9x FTA | 169 files |
| vite | 481 ± 3 | 400 ± 7 | 1.2x FTA | 1,182 files |
| nestjs | 588 ± 3 | 414 ± 4 | 1.4x FTA | 1,653 files |
| webpack | 1,735 ± 4 | 1,275 ± 10 | 1.4x FTA | 6,889 files |
| vscode | 19,845 ± 340 | 5,256 ± 52 | 3.8x FTA | 5,071 files |

**Mean: FTA is 1.8x faster than CG** across the quick suite.

The gap is smallest on medium-sized projects (vite, nestjs, webpack at 1.2–1.4x) and largest on
vscode (3.8x). The vscode gap is significant because FTA leverages multi-threaded I/O for large
repos, while CG processes files sequentially.

**Why CG is slower today:** CG is intentionally single-threaded in its current form. Phase 12
will add parallel file processing, which is expected to bring CG to parity or better on
modern multi-core hardware. See [Baseline for Future Phases](#baseline-for-future-phases).

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

Benchmarks were run on a Linux x86-64 development machine. For reproducible results on your
hardware, run `bash benchmarks/scripts/bench-quick.sh` directly.

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
# CG command
complexity-guard --format json --fail-on none <project-dir>

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

1. **CG is single-threaded.** Phase 12 will add parallel file processing. Current benchmarks
   represent a deliberate baseline before that optimization.

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
`benchmarks/results/baseline-2026-02-21/`:

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

[RESULTS: Run `bash benchmarks/scripts/bench-subsystems.sh` then
`node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-$(date +%Y-%m-%d)/`
to populate this section with actual subsystem timing data]

The subsystem benchmark profiles each CG pipeline stage independently:
file discovery, file I/O, parsing, cyclomatic analysis, cognitive analysis,
Halstead analysis, structural analysis, health score computation, and JSON serialization.
This identifies which stage to optimize first in Phase 12.

---

## Baseline for Future Phases

These benchmarks establish the **Phase 10.1 baseline** — the performance reference point
before Phase 11 (duplication detection) and Phase 12 (parallelization).

### Why This Matters

- **Phase 11** adds duplication detection. It may increase analysis time for large repos.
  Benchmarking before and after Phase 11 will show the cost of the new feature.

- **Phase 12** adds parallel file processing. It is expected to significantly reduce CG's
  wall-clock time on large repos. The baseline makes this impact measurable.

### Schema Version

The benchmark JSON schema is at **version 1.0**. The schema is intentionally stable so
Phase 11/12 before/after comparisons require no format conversion.

The schema consists of:
- hyperfine JSON format (from `hyperfine --export-json`)
- CG JSON output (`--format json`)
- FTA JSON output (`--json`)
- `metric-accuracy.json` (produced by `compare-metrics.mjs`)

### Running a New Baseline

After Phase 11 or 12 changes are merged, capture a new baseline:

```sh
bash benchmarks/scripts/setup.sh --suite quick
bash benchmarks/scripts/bench-quick.sh
bash benchmarks/scripts/compare-metrics.sh --suite quick
```

The results directory will be timestamped automatically (`baseline-YYYY-MM-DD`).
Compare old and new summaries to measure phase impact:

```sh
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/ > before.md
node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-<new-date>/ > after.md
diff before.md after.md
```

### Raw Data

All raw benchmark data is committed to the repository in
[`benchmarks/results/`](../benchmarks/results/). This includes:

- `baseline-2026-02-21/*.json` — Phase 10.1 baseline: 7 quick-suite projects
- `metric-accuracy.json` — Phase 10.1 metric accuracy comparison

See [`benchmarks/`](../benchmarks/) for scripts and additional documentation.
