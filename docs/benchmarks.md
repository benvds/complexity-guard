# Performance Benchmarks

ComplexityGuard is a native Rust binary with no runtime dependencies. This page documents its
performance characteristics measured across real-world TypeScript and JavaScript projects.

The short version: CG analyzes even the largest TypeScript codebases in seconds with parallel
analysis across all CPU cores.

## Key Findings

### Speed

CG analysis times across quick-suite projects with parallel analysis (the default):

| Project | CG (ms) | Project Size |
|---------|---------|-------------|
| got | 37 +/- 4 | 68 files |
| dayjs | 56 +/- 2 | 283 files |
| zod | 82 +/- 3 | 169 files |
| vite | 131 +/- 4 | 1,182 files |
| nestjs | 145 +/- 3 | 1,653 files |
| webpack | 678 +/- 49 | 6,889 files |
| vscode | 3,394 +/- 124 | 5,071 files |

**Mean analysis time: 661 ms across the quick suite.**

Analysis time scales with project size. Even the largest project (vscode,
5,071 files) analyzes in 3.4 seconds.

### Parallelization Impact

Parallel analysis delivers 2.6-5.8x speedup over single-threaded mode:

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

CG memory usage across quick-suite projects:

| Project | CG Mem (MB) |
|---------|------------|
| got | 21.0 |
| dayjs | 29.8 |
| zod | 38.7 |
| vite | 71.8 |
| nestjs | 91.1 |
| webpack | 209.0 |
| vscode | 1,891.2 |

**Mean CG memory: 336 MB across the quick suite.**

Memory usage scales with the number and size of files being analyzed. CG is a native Rust binary
with no runtime dependencies, so there is no interpreter or VM baseline overhead.

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

System specs are automatically captured in `system-info.json` alongside benchmark results.

### Tool Versions

| Tool | Version |
|------|---------|
| ComplexityGuard | 0.8.0 |
| hyperfine | 1.20.0 |

### Statistical Approach

- **Quick/full suites:** 15 benchmark runs per project, 3 warmup runs (discarded)
- **Stress suite:** 5 runs per project, 1 warmup run
- hyperfine reports mean +/- standard deviation across runs
- Memory measured as peak RSS per run (from `/proc/<pid>/status`); mean across runs reported

### Suite Composition

| Suite | Projects | Expected Duration |
|-------|----------|------------------|
| quick | 10 representative projects | ~5 min |
| full | 76 projects from public-projects list | ~60 min |
| stress | 3 massive repos (vscode, typescript) | ~30 min |

The quick suite covers the full project size range: small (got, dayjs), medium (zod, vite,
nestjs), and large (webpack, vscode).

### Benchmark Commands

Each hyperfine invocation benchmarks ComplexityGuard on a project directory:

```sh
# CG command (parallel, default -- uses all CPU cores)
complexity-guard --format json --fail-on none <project-dir>

# CG command (single-threaded -- for baseline comparison)
complexity-guard --threads 1 --format json --fail-on none <project-dir>
```

Flags chosen for benchmarking:
- `--fail-on none` (CG): disables threshold-based exit codes so CI violations don't abort hyperfine
- `--ignore-failure` (hyperfine): CG may still exit 1 for error-level violations; this flag prevents
  hyperfine from treating non-zero exit as measurement failure
- `--format json` (CG): JSON output mode (vs. console)

### Important Caveats

1. **Parallel by default.** CG benchmarks use the default parallel mode (all CPU cores). Pass
   `--threads 1` for single-threaded baseline comparison. Results will vary by core count.

2. **Benchmarks measure wall-clock time** for a full analysis pass (file discovery, parsing,
   metric computation, and output serialization). Times include all overhead.

---

## Duplication Detection Performance

Duplication detection adds a **cross-file analysis pass** that runs after the standard per-file analysis. This pass computes a token index (during the per-file pass), then runs the Rabin-Karp hash pipeline across all files.

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

### When to Use `--duplication`

Given the overhead, use duplication detection:
- **In CI for periodic audits** (daily or on PR, not every commit) -- `complexity-guard --duplication src/`
- **During refactoring sessions** to find copy-paste candidates
- **In pre-merge gates** when reducing technical debt is a priority

Avoid on very large repos (webpack/vscode scale) in fast CI pipelines -- the re-parse overhead will dominate. For those cases, consider running duplication analysis in a separate, less frequent CI job.

---

## Baseline History

### v0.8: Rust Implementation (current)

The current benchmarks reflect ComplexityGuard v0.8 (Rust) with parallel analysis enabled (the default). Historical benchmark data comparing Zig v1.0 vs Rust v0.8 is preserved in git history (quick task 22, `bench-rust-vs-zig.sh`). Key finding: Rust is significantly faster with parallel analysis.

### Schema Version

The benchmark JSON schema is at **version 1.0**. The schema is intentionally stable so
before/after comparisons require no format conversion.

The schema consists of:
- hyperfine JSON format (from `hyperfine --export-json`)
- CG JSON output (`--format json`)
