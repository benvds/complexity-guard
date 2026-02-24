# Phase 20: Parallel Pipeline - Research

**Researched:** 2026-02-24
**Domain:** Rust parallel file analysis, recursive directory scanning, glob pattern filtering
**Confidence:** HIGH

## Summary

Phase 20 wires together the components built in Phases 17-19 (parser, metrics, CLI/config, output renderers) into a functional end-to-end pipeline. Currently, `main.rs` contains a placeholder comment — "Placeholder: no actual file analysis yet (Phase 20 parallel pipeline)" — and produces empty results. This phase fills that gap.

The three requirements are: (1) recursive directory scanning with glob exclusion, (2) parallel file analysis using rayon, and (3) deterministic output sorted by path. The Zig implementation in `src/pipeline/parallel.zig` and `src/discovery/walker.zig` serves as the behavioral reference. The Rust ecosystem has mature, well-maintained crates for all three concerns: `walkdir` for traversal, `globset` for glob matching, and `rayon` for data parallelism.

The key insight from the Zig code is the separation of concerns: discovery (collect paths) runs first, then parallelism runs over those paths, then results are sorted before rendering. The Rust versions of each stage map cleanly onto `walkdir`, `rayon::par_iter`, and `Vec::sort_by`. The tree-sitter `Parser` type is confirmed `Send + Sync` (verified from docs.rs), meaning each rayon thread can create its own `Parser` instance safely without needing mutex protection.

**Primary recommendation:** Add `rayon = "1"`, `walkdir = "2"`, and `globset = "0.4"` as dependencies. Implement a `pipeline` module with two functions: `discover_files()` and `analyze_files_parallel()`. Wire them into `main.rs`, replacing the placeholder stub. Sort results by path after collection. The entire implementation can be done in 2-3 plans.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PIPE-01 | Recursive directory scanning with glob exclusion | walkdir 2.5 for traversal; globset 0.4 for exclude/include pattern matching; hardcoded excluded dirs (node_modules, .git, dist, build, .next, coverage, vendor) matching Zig filter.zig |
| PIPE-02 | Parallel file analysis with configurable thread count | rayon 1.11 ThreadPoolBuilder::num_threads() + install(); `analyze_file()` from metrics::mod already exists and is stateless; Parser is Send so per-thread creation works |
| PIPE-03 | Deterministic output ordering (sorted by path) | Rayon par_iter().map().collect() does NOT guarantee order; explicit sort_by after collection; matches Zig `std.mem.sort` post-parallel-join approach |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rayon | 1.11.0 | Data parallelism (par_iter, ThreadPoolBuilder) | De facto standard for CPU-bound parallelism in Rust; 0 runtime overhead; work-stealing scheduler; REQUIREMENTS.md explicitly mandates rayon |
| walkdir | 2.5.0 | Recursive directory traversal | Most widely used (291M+ downloads); cross-platform; supports filter_entry for early pruning of excluded dirs; BurntSushi (ripgrep author) |
| globset | 0.4.18 | Glob pattern matching for include/exclude | Same author as walkdir; supports `**` patterns; multi-glob matching in one pass; used by ripgrep, cargo |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| std::path::PathBuf | stdlib | Path manipulation and comparison | Already used throughout the codebase; sort by path is lexicographic on PathBuf |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| walkdir | std::fs::read_dir (recursive) | walkdir handles symlinks, max-depth, filter_entry pruning — hand-rolling misses edge cases |
| globset | glob crate | globset is more actively maintained, supports GlobSet (multi-pattern single-pass matching) |
| rayon | tokio + spawn_blocking | REQUIREMENTS.md explicitly rules out async/tokio: "CPU-bound workload; rayon is correct" — out of scope |

**Installation:**
```bash
# In rust/Cargo.toml [dependencies]:
rayon = "1"
walkdir = "2"
globset = "0.4"
```

## Architecture Patterns

### Recommended Project Structure
```
rust/src/
├── pipeline/
│   ├── mod.rs         # pub use discover, analyze_files_parallel
│   ├── discover.rs    # discover_files() — walkdir + globset filter
│   └── parallel.rs    # analyze_files_parallel() — rayon par_iter
├── metrics/mod.rs     # analyze_file() already exists — no changes needed
└── main.rs            # wire: discover -> parallel -> sort -> render
```

### Pattern 1: Directory Discovery with Glob Filtering

**What:** Walk a directory tree with walkdir, skip excluded directory components early, apply globset patterns for include/exclude.

**When to use:** Any time paths argument is a directory (vs. single file). Single files bypass walking entirely.

**Example:**
```rust
// Source: walkdir 2.5.0 docs.rs + globset 0.4.18 docs.rs
use walkdir::WalkDir;
use globset::{GlobSet, GlobSetBuilder, Glob};

const EXCLUDED_DIRS: &[&str] = &[
    "node_modules", ".git", "dist", "build",
    ".next", "coverage", "vendor", "__pycache__", ".svn", ".hg",
];

fn is_target_extension(path: &std::path::Path) -> bool {
    match path.extension().and_then(|e| e.to_str()) {
        Some("ts") | Some("tsx") | Some("js") | Some("jsx") => true,
        _ => false,
    }
}

fn is_declaration_file(path: &std::path::Path) -> bool {
    let s = path.to_string_lossy();
    s.ends_with(".d.ts") || s.ends_with(".d.tsx")
}

pub fn discover_files(
    paths: &[std::path::PathBuf],
    include_patterns: &[String],
    exclude_patterns: &[String],
) -> anyhow::Result<Vec<std::path::PathBuf>> {
    let exclude_set = build_globset(exclude_patterns)?;
    let include_set = if include_patterns.is_empty() {
        None
    } else {
        Some(build_globset(include_patterns)?)
    };

    let mut result = Vec::new();

    for path in paths {
        if path.is_dir() {
            for entry in WalkDir::new(path)
                .into_iter()
                .filter_entry(|e| {
                    // Prune excluded dirs early — prevents descent
                    if e.file_type().is_dir() {
                        let name = e.file_name().to_str().unwrap_or("");
                        !EXCLUDED_DIRS.contains(&name)
                    } else {
                        true
                    }
                })
                .filter_map(|e| e.ok())
                .filter(|e| e.file_type().is_file())
            {
                let p = entry.path();
                if should_include(p, &exclude_set, &include_set) {
                    result.push(p.to_path_buf());
                }
            }
        } else if path.is_file() {
            if should_include(path, &exclude_set, &include_set) {
                result.push(path.clone());
            }
        }
    }

    Ok(result)
}

fn should_include(
    path: &std::path::Path,
    exclude: &GlobSet,
    include: &Option<GlobSet>,
) -> bool {
    if !is_target_extension(path) { return false; }
    if is_declaration_file(path) { return false; }
    if exclude.is_match(path) { return false; }
    if let Some(inc) = include {
        if !inc.is_match(path) { return false; }
    }
    true
}

fn build_globset(patterns: &[String]) -> anyhow::Result<GlobSet> {
    let mut builder = GlobSetBuilder::new();
    for pat in patterns {
        builder.add(Glob::new(pat)?);
    }
    Ok(builder.build()?)
}
```

### Pattern 2: Parallel Analysis with Configurable Thread Count

**What:** Use rayon's `ThreadPoolBuilder` to create a pool with the configured thread count, then run `analyze_file()` in parallel via `par_iter`.

**When to use:** Always in the pipeline after discovery. Sequential analysis (threads=1) uses the same code path — rayon with 1 thread is sequential.

**Example:**
```rust
// Source: rayon 1.11.0 docs.rs
use rayon::prelude::*;
use crate::metrics::analyze_file;
use crate::types::{AnalysisConfig, FileAnalysisResult};

pub fn analyze_files_parallel(
    paths: &[std::path::PathBuf],
    config: &AnalysisConfig,
    threads: u32,
) -> Vec<Result<FileAnalysisResult, crate::types::ParseError>> {
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(threads as usize)
        .build()
        .expect("failed to build thread pool");

    pool.install(|| {
        paths.par_iter()
            .map(|path| analyze_file(path, config))
            .collect()
    })
}
```

**Key points:**
- `ThreadPoolBuilder::num_threads()` sets thread count; 0 = use CPU count automatically
- `pool.install(|| { ... })` scopes all rayon operations to this pool
- `par_iter()` on a slice is order-preserving on collect() for `IndexedParallelIterator`
- Still sort by path after collect because analyze_file errors and order may diverge in practice
- Each rayon worker creates its own `tree_sitter::Parser` inside `analyze_file()` — this is correct: `Parser` is `Send + Sync`, per-invocation creation is the right pattern (same as Zig's per-worker arena)

### Pattern 3: Deterministic Sort After Collection

**What:** After parallel collection, sort the results vector by path before passing to renderers.

**When to use:** Always — rayon does not guarantee execution order even if collect() preserves index order from the source slice. Sorting by path makes output identical across runs.

**Example:**
```rust
// Zig reference: std.mem.sort(FileAnalysisResult, ctx.results.items, {}, resultLessThan)
let mut results: Vec<FileAnalysisResult> = paths
    .par_iter()
    .filter_map(|p| analyze_file(p, config).ok())
    .collect();

// Sort by path for deterministic output — PIPE-03 requirement
results.sort_by(|a, b| a.path.cmp(&b.path));
```

### Pattern 4: Error Handling in Parallel Pipeline

**What:** Files that fail to parse return `Err(ParseError)` from `analyze_file()`. These must be counted for exit code determination but should not crash the pipeline.

**When to use:** Always — collect `Result` types and partition into successes and failures after.

**Example:**
```rust
let raw: Vec<Result<FileAnalysisResult, ParseError>> = pool.install(|| {
    paths.par_iter().map(|p| analyze_file(p, config)).collect()
});

let (mut files, errors): (Vec<_>, Vec<_>) = raw.into_iter().partition(Result::is_ok);
let files: Vec<FileAnalysisResult> = files.into_iter().map(|r| r.unwrap()).collect();
let has_parse_errors = !errors.is_empty();

files.sort_by(|a, b| a.path.cmp(&b.path));
```

### Anti-Patterns to Avoid

- **Sharing one Parser across threads:** tree-sitter Parser performs internal caching on node access. Create one per thread invocation (inside the par_iter closure), not as a shared global.
- **Using `par_bridge()` for walkdir:** `par_bridge()` does NOT preserve order per rayon docs. Use sequential walkdir to collect, then parallel for analysis.
- **Sorting paths as strings:** Use `PathBuf::cmp` (which compares OsStr) for consistent cross-platform sort order. Don't compare `.to_string_lossy()`.
- **Installing global thread pool unconditionally:** `ThreadPoolBuilder::build_global()` can only be called once. Use `build()` + `install()` for a local pool — avoids test interference.
- **Defaulting threads=0 to rayon's auto:** Pass `num_threads(threads as usize)` directly; when `resolved.threads` is the CPU count (from `std::thread::available_parallelism()`), rayon will use that number. Don't set 0 unless you want rayon's internal auto-detection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recursive directory walk | Custom walk with `std::fs::read_dir` | walkdir 2.5 | Symlink handling, cross-platform, filter_entry for efficient dir pruning |
| Glob pattern matching | Custom `*` / `**` parser | globset 0.4 | Brace expansion, character classes, cross-platform separators, `**` semantics |
| Thread pool | `std::thread::spawn` + channel | rayon par_iter | Work-stealing, backpressure, join barriers — all handled automatically |

**Key insight:** The Zig binary hand-rolled its own simple glob matcher (using endsWith and indexOf) — the REQUIREMENTS.md explicitly says Phase 20 adds proper glob exclusion. Use globset for correctness.

## Common Pitfalls

### Pitfall 1: `par_iter().collect()` Order on Errors
**What goes wrong:** Results with `Err` variants get inserted at the position their source path was in the input slice. After filtering out errors, the remaining `Ok` results are not re-indexed. The sort step is still mandatory.
**Why it happens:** Rayon preserves *input* order, but after filtering (partition/filter_map), the slice positions shift.
**How to avoid:** Always sort the final `files` Vec by path after partitioning out errors.
**Warning signs:** Output order changes between runs with low file counts.

### Pitfall 2: Thread Pool Build Failure in Tests
**What goes wrong:** Calling `rayon::ThreadPoolBuilder::new().build_global()` in production code causes test failures when multiple tests try to initialize the global pool.
**Why it happens:** `build_global()` can only be called once per process; tests run in the same process.
**How to avoid:** Use `build()` + `pool.install(||{})` pattern (local pool per call), never `build_global()`.
**Warning signs:** Tests fail with "global thread pool has already been initialized".

### Pitfall 3: Glob Pattern Path Separator Mismatch
**What goes wrong:** User provides pattern `src/**/*.ts` but on Windows paths use `\`. GlobSet's default handles this, but only if paths are passed as `Path` not as `str`.
**Why it happens:** globset normalizes separators when given `Path::new(...)` but not raw strings.
**How to avoid:** Pass `path` as `&Path` to `globset.is_match(path)`, not `path.to_str().unwrap()`.
**Warning signs:** Exclude patterns silently fail on Windows.

### Pitfall 4: Hardcoded Excluded Dirs vs. Glob Patterns
**What goes wrong:** User can specify `--exclude node_modules` expecting it to exclude the `node_modules` directory, but the glob `node_modules` only matches an exact file name. The walker would still descend into the directory.
**Why it happens:** Glob patterns matching directories must use a path-component check, not a terminal glob.
**How to avoid:** Keep the hardcoded `EXCLUDED_DIRS` constant for the well-known dirs (matches Zig behavior). Additionally apply user-supplied `--exclude` patterns as globs on full paths.
**Warning signs:** `--exclude node_modules` has no effect on discovered files.

### Pitfall 5: Default Path When No Paths Provided
**What goes wrong:** When the user runs `complexityguard` with no positional arguments, `args.paths` is empty. The current `main.rs` placeholder shows `"."` as the default. Without this default, the binary analyzes nothing.
**Why it happens:** clap returns an empty Vec for positional paths if none given.
**How to avoid:** In the pipeline wiring, default to `[PathBuf::from(".")]` when `args.paths` is empty — matches Zig behavior.
**Warning signs:** Running `complexityguard` in a TS project directory produces no output.

## Code Examples

Verified patterns from official sources:

### GlobSet Construction
```rust
// Source: globset 0.4.18 docs.rs
use globset::{Glob, GlobSetBuilder};

let mut builder = GlobSetBuilder::new();
builder.add(Glob::new("**/*.test.ts")?);
builder.add(Glob::new("**/node_modules/**")?);
let set = builder.build()?;

assert!(set.is_match(std::path::Path::new("src/foo.test.ts")));
assert!(!set.is_match(std::path::Path::new("src/foo.ts")));
```

### Rayon ThreadPoolBuilder with Local Pool
```rust
// Source: rayon 1.11.0 docs.rs
let pool = rayon::ThreadPoolBuilder::new()
    .num_threads(4)
    .build()
    .unwrap();

let results: Vec<_> = pool.install(|| {
    paths.par_iter()
        .map(|p| expensive_computation(p))
        .collect()
});
```

### walkdir filter_entry (Efficient Dir Pruning)
```rust
// Source: walkdir 2.5.0 docs.rs
use walkdir::WalkDir;

let walker = WalkDir::new(".").into_iter();
for entry in walker.filter_entry(|e| {
    // Return false to prune entire subtree
    !(e.file_type().is_dir() && e.file_name() == "node_modules")
}) {
    let entry = entry?;
    if entry.file_type().is_file() {
        println!("{}", entry.path().display());
    }
}
```

### Full Pipeline Wiring in main.rs

Replace the placeholder comment block in `main.rs`:
```rust
// Phase 20: real pipeline
let input_paths: Vec<std::path::PathBuf> = if args.paths.is_empty() {
    vec![std::path::PathBuf::from(".")]
} else {
    args.paths.clone()
};

let include_patterns = resolved_files_include(&config); // from config.files.include
let exclude_patterns = resolved_files_exclude(&config); // from config.files.exclude

let discovered = complexity_guard::pipeline::discover_files(
    &input_paths,
    &include_patterns,
    &exclude_patterns,
)?;

let start = std::time::Instant::now();
let analysis_config = complexity_guard::types::AnalysisConfig::from_resolved(&resolved);
let (files, has_parse_errors) = complexity_guard::pipeline::analyze_files_parallel(
    &discovered,
    &analysis_config,
    resolved.threads,
);
let elapsed_ms = start.elapsed().as_millis() as u64;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Zig std.Thread.Pool (manual mutex locking, arena per-worker) | Rayon par_iter (work-stealing, no manual sync needed) | Phase 20 (this phase) | No manual mutex needed; rayon handles all synchronization |
| Zig simple pattern matching (endsWith/indexOf) | globset GlobSet | Phase 20 (this phase) | Correct `**` semantics, brace expansion, character classes |
| Placeholder stub in main.rs | Real pipeline wiring | Phase 20 (this phase) | Binary becomes functional end-to-end |

**Deprecated/outdated:**
- Zig `matchesSimplePattern`: replaced by globset. The Zig implementation explicitly says "Full glob support deferred" — Phase 20 delivers that deferred feature in the Rust version.

## Open Questions

1. **DuplicationResult integration in pipeline**
   - What we know: `analyze_file()` already embeds tokens in `FileAnalysisResult.tokens`. Duplication detection (`duplication::detect_clones()`) runs cross-file on all tokens combined.
   - What's unclear: Does Phase 20 need to wire duplication detection into the pipeline, or is that Phase 21? The `--duplication` flag exists in CLI. The Zig parallel.zig does NOT run duplication — it's a separate post-processing step in main.zig.
   - Recommendation: Wire duplication as a post-parallel step in main.rs, gated by `resolved.duplication_enabled`. Collect all tokens from `FileAnalysisResult.tokens`, run `duplication::detect_clones()`, pass result to renderers. This keeps the plan clean — duplication is sequential and separate from the parallel step.

2. **Violation counting for exit code**
   - What we know: `determine_exit_code()` takes `error_count` and `warning_count`. The parallel pipeline needs to count these from the rendered results.
   - What's unclear: Is there a `count_violations()` function already in the Rust codebase?
   - Recommendation: Add a helper function that counts violations from `FileAnalysisResult` vec using the resolved thresholds. Check output/console.rs — it likely has a `function_violations()` helper (mentioned in STATE.md: "function_violations() reused between console and JSON renderers").

3. **Summary statistics in output renderers**
   - What we know: All four renderers currently accept `Option<DuplicationResult>` as second parameter.
   - What's unclear: Do renderers also need a summary (total files, elapsed_ms, file counts) that's distinct from the current signature?
   - Recommendation: The current signatures `render_json(&files, None, &resolved, elapsed_ms)` are already correct — elapsed_ms is tracked from the real start time. No signature changes needed.

## Sources

### Primary (HIGH confidence)
- rayon 1.11.0 docs.rs - ThreadPoolBuilder, num_threads, install, par_iter ordering
- walkdir 2.5.0 docs.rs - WalkDir, filter_entry, DirEntry
- globset 0.4.18 docs.rs - Glob, GlobSet, GlobSetBuilder, is_match
- tree-sitter docs.rs - `impl Send for Parser`, `impl Sync for Parser`
- /Users/benvds/code/complexity-guard/rust/src/metrics/mod.rs - existing `analyze_file()` API
- /Users/benvds/code/complexity-guard/rust/src/main.rs - placeholder to replace
- /Users/benvds/code/complexity-guard/rust/Cargo.toml - current dependencies (no rayon/walkdir/globset yet)

### Secondary (MEDIUM confidence)
- github.com/rayon-rs/rayon/issues/551 - rayon maintainer confirmed par_iter().collect() preserves order for IndexedParallelIterator; explicit sort still recommended for safety
- /Users/benvds/code/complexity-guard/src/pipeline/parallel.zig - Zig reference: per-worker Parser creation, mutex for shared alloc, post-join sort
- /Users/benvds/code/complexity-guard/src/discovery/walker.zig - Zig reference: EXCLUDED_DIRS, shouldIncludeFile logic
- /Users/benvds/code/complexity-guard/src/discovery/filter.zig - Zig reference: exact EXCLUDED_DIRS list, isTargetFile, isDeclarationFile behavior

### Tertiary (LOW confidence)
- None — all key claims verified from official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All three crates confirmed from official docs.rs with exact versions
- Architecture: HIGH - Zig reference implementation fully read; Rust analyze_file() API confirmed
- Pitfalls: MEDIUM - walkdir/globset interaction on Windows not locally testable; thread pool global init pitfall from official rayon docs

**Research date:** 2026-02-24
**Valid until:** 2026-08-24 (stable crates; rayon/walkdir/globset rarely have breaking changes)
