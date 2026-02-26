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

## Full Benchmark Results (v0.8.0, 2026-02-26)

83 open-source TypeScript/JavaScript projects analyzed with parallel analysis on Apple M1 Max (10 cores, 64 GB RAM). Times are mean ± standard deviation over 15 runs with 3 warmup runs.

| Project | Files | Functions | Time (ms) | Health | Warnings | Errors | Skipped |
|---------|------:|----------:|----------:|-------:|---------:|-------:|--------:|
| signale | 3 | 40 | 6 ± 0 | 95.8 | 7 | 5 | |
| debug | 7 | 25 | 5 ± 1 | 95.2 | 5 | 3 | |
| chalk | 12 | 52 | 6 ± 0 | 97.6 | 13 | 0 | |
| json-server | 13 | 67 | 6 ± 0 | 93.9 | 32 | 18 | |
| dotenv | 14 | 76 | 6 ± 1 | 96.5 | 25 | 2 | |
| supabase-js | 19 | 38 | 14 ± 1 | 95.7 | 11 | 7 | |
| lodash | 26 | 79 | 13 ± 1 | 92.4 | 27 | 35 | |
| grunt | 37 | 210 | 14 ± 1 | 96.0 | 73 | 14 | |
| wretch | 39 | 93 | 14 ± 2 | 95.2 | 28 | 19 | |
| rrule | 42 | 235 | 24 ± 1 | 93.7 | 127 | 68 | |
| zustand | 45 | 140 | 16 ± 1 | 95.9 | 34 | 19 | |
| yup | 51 | 252 | 14 ± 1 | 95.6 | 61 | 31 | |
| joi | 66 | 554 | 44 ± 5 | 91.7 | 373 | 196 | 1 |
| got | 68 | 888 | 23 ± 1 | 96.2 | 570 | 52 | |
| yargs | 70 | 276 | 18 ± 1 | 94.7 | 123 | 40 | |
| request | 74 | 543 | 17 ± 3 | 96.2 | 142 | 63 | |
| npkill | 78 | 315 | 11 ± 1 | 97.3 | 35 | 19 | |
| nodemon | 79 | 166 | 12 ± 1 | 94.1 | 74 | 46 | |
| koa | 82 | 199 | 12 ± 3 | 95.9 | 37 | 32 | |
| h3 | 83 | 242 | 16 ± 3 | 93.7 | 115 | 50 | |
| winston | 87 | 207 | 13 ± 1 | 95.7 | 63 | 21 | |
| luxon | 94 | 1,601 | 27 ± 3 | 97.5 | 239 | 52 | |
| verdaccio | 117 | 303 | 44 ± 3 | 95.1 | 156 | 49 | |
| pino | 133 | 841 | 22 ± 2 | 96.8 | 120 | 36 | |
| express | 142 | 339 | 22 ± 2 | 96.4 | 124 | 69 | |
| jotai | 159 | 581 | 24 ± 1 | 95.4 | 222 | 76 | |
| axios | 160 | 472 | 22 ± 2 | 95.8 | 171 | 59 | |
| commander | 162 | 756 | 24 ± 1 | 96.5 | 140 | 71 | |
| karma | 165 | 435 | 35 ± 6 | 94.7 | 151 | 103 | |
| zod | 172 | 1,878 | 47 ± 4 | 96.5 | 348 | 140 | |
| jshint | 180 | 1,312 | 52 ± 3 | 95.5 | 452 | 231 | |
| redux | 196 | 390 | 19 ± 2 | 97.1 | 50 | 25 | |
| mobx | 230 | 1,953 | 68 ± 4 | 96.0 | 685 | 166 | 4 |
| slidev | 238 | 414 | 25 ± 2 | 92.4 | 242 | 120 | |
| jasmine | 252 | 367 | 34 ± 2 | 96.1 | 77 | 145 | |
| tailwindcss | 252 | 1,169 | 52 ± 4 | 93.4 | 571 | 362 | 1 |
| fastify | 259 | 2,243 | 59 ± 4 | 96.1 | 796 | 175 | |
| superstruct | 259 | 230 | 16 ± 1 | 97.6 | 43 | 11 | |
| dayjs | 283 | 989 | 32 ± 2 | 96.7 | 250 | 168 | |
| socket.io | 339 | 1,407 | 58 ± 5 | 95.4 | 420 | 195 | |
| hono | 342 | 1,154 | 60 ± 3 | 94.1 | 477 | 275 | |
| ava | 357 | 1,139 | 33 ± 1 | 96.5 | 200 | 123 | |
| pm2 | 365 | 939 | 35 ± 2 | 95.3 | 381 | 196 | |
| excalidraw | 380 | 1,909 | 74 ± 6 | 92.0 | 1,281 | 661 | |
| xstate | 388 | 1,263 | 60 ± 2 | 95.0 | 468 | 273 | |
| mocha | 392 | 862 | 35 ± 4 | 96.6 | 210 | 112 | |
| pdf.js | 412 | 6,391 | 235 ± 17 | 93.1 | 3,535 | 2,226 | |
| sequelize | 418 | 1,539 | 92 ± 6 | 91.2 | 945 | 749 | |
| apollo-client | 484 | 1,654 | 109 ± 5 | 93.9 | 742 | 459 | 2 |
| vue-core | 504 | 2,079 | 102 ± 5 | 90.9 | 1,385 | 818 | |
| remix | 577 | 1,444 | 68 ± 4 | 94.4 | 622 | 309 | |
| moment | 625 | 4,122 | 166 ± 22 | 93.0 | 2,390 | 1,603 | |
| tanstack-query | 721 | 1,371 | 86 ± 5 | 95.0 | 394 | 310 | 1 |
| trpc | 766 | 1,730 | 67 ± 3 | 95.8 | 519 | 232 | |
| mongodb-node-driver | 886 | 3,874 | 1,844 ± 147 | 93.3 | 1,760 | 1,410 | 9 |
| rxjs | 947 | 2,581 | 90 ± 4 | 96.6 | 439 | 289 | |
| vite | 1,182 | 2,639 | 83 ± 4 | 95.4 | 929 | 393 | |
| keystonejs | 1,276 | 2,566 | 120 ± 7 | 94.0 | 1,211 | 619 | |
| undici | 1,367 | 5,713 | 136 ± 7 | 95.9 | 1,659 | 594 | |
| eslint | 1,406 | 2,433 | 200 ± 10 | 94.7 | 846 | 586 | 7 |
| date-fns | 1,535 | 1,360 | 101 ± 7 | 94.6 | 878 | 222 | |
| three.js | 1,537 | 10,133 | 705 ± 190 | 93.2 | 5,780 | 3,557 | |
| vitest | 1,606 | 4,328 | 107 ± 8 | 95.9 | 1,241 | 515 | |
| nestjs | 1,653 | 3,366 | 100 ± 6 | 96.9 | 682 | 261 | |
| effect | 1,689 | 10,754 | 492 ± 67 | 96.5 | 3,324 | 1,535 | 2 |
| jest | 1,705 | 5,048 | 129 ± 6 | 96.2 | 1,360 | 631 | |
| valibot | 1,769 | 3,113 | 121 ± 5 | 97.9 | 300 | 316 | |
| chakra-ui | 1,841 | 2,061 | 86 ± 5 | 96.3 | 610 | 153 | |
| prisma | 2,083 | 5,193 | 178 ± 10 | 96.0 | 1,299 | 677 | |
| redwoodjs | 2,227 | 5,184 | 167 ± 6 | 95.8 | 1,373 | 674 | |
| ant-design | 2,569 | 3,578 | 167 ± 8 | 93.8 | 1,443 | 1,113 | |
| storybook | 2,863 | 6,585 | 203 ± 7 | 95.5 | 1,819 | 798 | |
| typeorm | 3,162 | 6,248 | 227 ± 9 | 95.4 | 2,054 | 1,195 | |
| biome | 3,361 | 5,528 | 149 ± 7 | 98.8 | 243 | 77 | |
| strapi | 3,720 | 6,910 | 304 ± 13 | 94.6 | 2,329 | 1,475 | |
| deno | 3,880 | 13,681 | 431 ± 13 | 96.6 | 3,327 | 1,315 | |
| prettier | 4,893 | 6,510 | 245 ± 5 | 96.9 | 1,190 | 470 | |
| vscode | 5,071 | 59,316 | 3,281 ± 418 | 94.1 | 27,460 | 11,115 | |
| n8n | 5,826 | 12,466 | 617 ± 14 | 92.4 | 6,014 | 4,644 | |
| angular | 6,096 | 20,024 | 628 ± 14 | 95.2 | 7,569 | 2,996 | |
| webpack | 6,889 | 8,730 | 327 ± 31 | 94.7 | 2,610 | 2,107 | |
| rocketchat | 8,290 | 20,090 | 601 ± 12 | 95.0 | 7,629 | 2,883 | |
| next.js | 14,346 | 31,381 | 1,370 ± 35 | 93.8 | 14,729 | 9,454 | |

**Totals:** 107,193 files, 321,366 functions across 83 projects. Average health score: 95.2. 27 items skipped by [size limits](cli-reference.md#size-limits).

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
