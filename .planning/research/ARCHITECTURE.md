# Architecture Research

**Domain:** Rust Rewrite of ComplexityGuard (Zig → Rust Static Analysis Binary)
**Researched:** 2026-02-24
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLI Layer (main.rs)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  clap v4     │  │ Config Loader│  │  `init`      │              │
│  │  (derive)    │→ │ serde_json   │→ │  subcommand  │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
├─────────────────────────────────────────────────────────────────────┤
│                     Discovery Layer                                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ignore::WalkBuilder (respects .gitignore, .ignore)          │   │
│  │  glob pattern filter → Vec<PathBuf>                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                  Analysis Pipeline (rayon par_iter)                  │
│  ┌────────────┐  ┌────────────┐  ┌───────────┐  ┌──────────────┐   │
│  │  Parser    │→ │  Metrics   │→ │  Scoring  │→ │ FileResult   │   │
│  │ tree-sitter│  │ cyclomatic │  │  sigmoid  │  │  (owned)     │   │
│  │ per-thread │  │ cognitive  │  │ normalize │  │              │   │
│  └────────────┘  │ halstead   │  └───────────┘  └──────────────┘   │
│                  │ structural │                                      │
│                  └────────────┘                                      │
├─────────────────────────────────────────────────────────────────────┤
│              Duplication Pass (sequential, cross-file)               │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Rabin-Karp rolling hash over token sequences                │   │
│  │  HashMap<u64, Vec<TokenWindow>> → CloneGroups                │   │
│  └──────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                      Output Layer                                    │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │
│  │  console   │  │    JSON    │  │  SARIF 2.1 │  │    HTML    │    │
│  │  (stderr / │  │ serde_json │  │ serde      │  │  (string   │    │
│  │   stdout)  │  │ to_writer  │  │ derive     │  │  template) │    │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Rust Implementation |
|-----------|---------------|---------------------|
| `main.rs` | Entry point, wires pipeline stages | Thin orchestrator only |
| `cli/args.rs` | CLI argument definitions | `#[derive(Parser)]` on `Cli` struct |
| `cli/config.rs` | `.complexityguard.json` load/merge | `serde::Deserialize` on `Config` struct |
| `discovery/mod.rs` | File walking, extension filter | `ignore::WalkBuilder` |
| `parser/mod.rs` | Language selection, source → Tree | `tree_sitter::Parser` per rayon task |
| `metrics/cyclomatic.rs` | McCabe cyclomatic complexity | AST node visitor, pure function |
| `metrics/cognitive.rs` | SonarSource cognitive complexity | Recursive traversal with nesting state |
| `metrics/halstead.rs` | Halstead volume/difficulty/effort/bugs | Operator/operand token counting |
| `metrics/structural.rs` | Length, params, nesting depth, file stats | Single-pass AST walk |
| `metrics/duplication.rs` | Rabin-Karp rolling hash, clone groups | Cross-file HashMap; called after parallel pass |
| `metrics/scoring.rs` | Sigmoid normalization, composite score | Pure math, no allocations |
| `output/console.rs` | Human-readable terminal output | `Write` to stdout/stderr |
| `output/json.rs` | JSON serialization | `serde_json::to_writer_pretty` |
| `output/sarif.rs` | SARIF 2.1.0 format | Typed structs with `#[derive(Serialize)]` |
| `output/html.rs` | Self-contained HTML report | Inline template string substitution |
| `types.rs` | Shared data structures | `#[derive(Debug, Clone, Serialize)]` |

## Recommended Project Structure

```
complexity-guard/
├── Cargo.toml              # workspace or single-crate manifest
├── Cargo.lock
├── build.rs                # NOT needed — tree-sitter language crates include precompiled C
├── src/
│   ├── main.rs             # entry point: parse args → run pipeline → exit code
│   ├── lib.rs              # optional: re-exports for integration tests
│   ├── types.rs            # FunctionResult, FileResult, ProjectResult, ThresholdStatus
│   ├── cli/
│   │   ├── mod.rs
│   │   ├── args.rs         # clap derive: Cli, Commands, AnalyzeArgs, InitArgs
│   │   └── config.rs       # Config, ThresholdsConfig, WeightsConfig + JSON load/merge
│   ├── discovery/
│   │   └── mod.rs          # WalkBuilder setup, extension filter, glob exclude
│   ├── parser/
│   │   └── mod.rs          # select_language(), parse_source() → tree_sitter::Tree
│   ├── metrics/
│   │   ├── mod.rs          # AnalysisResult, per-file orchestration
│   │   ├── cyclomatic.rs   # analyze_file() → Vec<FunctionMetrics>
│   │   ├── cognitive.rs    # analyze_functions() → Vec<u32>
│   │   ├── halstead.rs     # analyze_functions() → Vec<HalsteadMetrics>
│   │   ├── structural.rs   # analyze_functions() + analyze_file() structural
│   │   ├── duplication.rs  # tokenize() + rabin_karp() + build_clone_groups()
│   │   └── scoring.rs      # sigmoid_score(), compute_function_score(), compute_file_score()
│   ├── pipeline/
│   │   └── mod.rs          # rayon par_iter over file list → Vec<FileAnalysisResult>
│   └── output/
│       ├── mod.rs          # dispatch to format-specific renderer
│       ├── console.rs
│       ├── json.rs
│       ├── sarif.rs
│       └── html.rs
└── tests/
    ├── fixtures/           # same TS/JS fixture files from Zig version
    │   ├── typescript/
    │   └── javascript/
    └── integration/        # end-to-end tests via process::Command
        └── cli_tests.rs
```

### Structure Rationale

- **`src/cli/`:** Isolates clap and serde_json config concerns. `args.rs` and `config.rs` are separate so arg parsing is testable without touching the filesystem.
- **`src/discovery/`:** Wraps the `ignore` crate. The `ignore::WalkBuilder` respects `.gitignore` automatically — the Zig version implemented this manually. Single module, low churn.
- **`src/parser/`:** Thin adapter over tree-sitter. Owns language selection (`ts`, `tsx`, `js`, `jsx`) and creates `Parser` instances. In Rust, `Parser` implements `Send + Sync` (confirmed in tree-sitter 0.26.x docs), so parsers can be moved into rayon closures.
- **`src/metrics/`:** One file per metric family, matching the Zig structure exactly. Each exposes pure functions taking `&Node` and `&[u8]` (source). No shared mutable state.
- **`src/pipeline/`:** Single module for the rayon parallel analysis. Replaces the Zig `std.Thread.Pool` + mutex pattern with `par_iter().map().collect()`. Much simpler — no explicit mutex, no arena-to-owned deep-copy.
- **`src/output/`:** Renderer dispatch. JSON and SARIF use `#[derive(Serialize)]` structs, eliminating all hand-rolled serialization from the Zig version.
- **`tests/integration/`:** CLI-level tests using `std::process::Command` — equivalent to Zig's UAT approach.

## Architectural Patterns

### Pattern 1: rayon par_iter Replaces Manual Thread Pool

**What:** The Zig implementation used `std.Thread.Pool` with a `WorkerContext` shared behind a `Mutex`. Worker threads computed metrics in per-worker arenas, then locked the mutex to deep-copy results to the shared allocator. This was ~150 lines of low-level thread coordination.

**Rust equivalent:** `rayon`'s `par_iter` handles all of this. Each closure is independent, returns an owned `FileAnalysisResult`, and rayon collects into `Vec` safely.

**When to use:** Always for the per-file analysis pass. Not appropriate for the duplication pass (cross-file state).

**Trade-offs:** Rayon's thread pool is shared globally — cannot set a custom thread count trivially. Use `rayon::ThreadPoolBuilder::new().num_threads(n).build_global()` in `main` before the parallel pass if the user specifies `--threads N`.

**Example:**
```rust
use rayon::prelude::*;

let results: Vec<FileAnalysisResult> = file_paths
    .par_iter()
    .filter_map(|path| analyze_file(path, &config).ok())
    .collect();
```

### Pattern 2: Tree-sitter Parser is Send + Sync in Rust (No Per-Thread Workaround Needed)

**What:** In the Zig implementation, `TSParser` was not thread-safe, so each worker thread created its own parser instance inside the worker function. The same requirement applies in Rust — create one `Parser` per rayon task, not a shared instance.

**Key difference from Zig:** Rust's tree-sitter crate (0.26.x) explicitly implements `Send` and `Sync` for `Parser`, `Tree`, and `Node`. This means you can create a `Parser` in a rayon closure without any `unsafe` tricks or thread-local storage.

**Recommended pattern:** Create `Parser` at the top of each rayon closure, set the language, parse, then drop. Parser creation is cheap; grammar loading is cheap (language constants are static).

**Example:**
```rust
let results: Vec<_> = file_paths
    .par_iter()
    .filter_map(|path| {
        let mut parser = tree_sitter::Parser::new();
        let lang = select_language(path)?;
        parser.set_language(&lang).ok()?;
        let source = std::fs::read_to_string(path).ok()?;
        let tree = parser.parse(&source, None)?;
        Some(compute_metrics(path, &source, &tree, &config))
    })
    .collect();
```

### Pattern 3: Owned Types Replace Arena Allocators

**What:** Zig required explicit arena allocators for temporary computation (per-worker) and careful deep-copy to the long-lived allocator. In Rust, types are owned by default — `String` and `Vec<T>` are heap-allocated and move semantics prevent double-frees. There are no arena allocators needed.

**Translation table:**

| Zig pattern | Rust equivalent |
|-------------|-----------------|
| `arena_alloc.dupe(u8, str)` | `str.to_string()` or `String::from(str)` |
| `arena.alloc(T)` | `Box::new(T)` or just own the value |
| `mutex.lock()` then `alloc.dupe(path)` | rayon closure returns owned `String` |
| `defer arena.deinit()` | RAII drop — automatic |
| `?T` optional fields | `Option<T>` — direct equivalent |

**When to use:** Everywhere. Rust's ownership model eliminates the entire category of arena/deep-copy complexity.

### Pattern 4: serde Replaces Hand-Rolled JSON and Config Parsing

**What:** The Zig implementation used a custom TOML dependency for config and hand-rolled `std.json` serialization for output. In Rust, `serde` + `serde_json` handle both.

**Config loading:** Derive `Deserialize` on the `Config` struct. Use `Option<T>` fields for all optional config. Merge CLI overrides after deserialization with explicit precedence logic.

**JSON output:** Derive `Serialize` on result types. Use `serde_json::to_writer_pretty` for `--format json`.

**SARIF output:** Define SARIF structs with `#[derive(Serialize)]` and `#[serde(rename = "camelCase")]` where field names differ from Rust convention.

**Trade-off:** `serde` adds ~200KB to binary size (per `min-sized-rust` guidance). Acceptable given the 5 MB budget and the elimination of ~800 lines of hand-rolled serialization code.

**Example:**
```rust
#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct Config {
    pub output: Option<OutputConfig>,
    pub analysis: Option<AnalysisConfig>,
    pub thresholds: Option<ThresholdsConfig>,
    pub weights: Option<WeightsConfig>,
}

// Load config:
let config: Config = serde_json::from_str(&file_content)?;
```

### Pattern 5: clap Derive Replaces Hand-Rolled CLI Parser

**What:** The Zig version implemented its own arg parser (~400 lines) due to incompatibilities with available libraries. In Rust, `clap` v4 with derive macros is the standard.

**Structure:** One `Cli` struct with a `Commands` enum for subcommands (`analyze` is the default, `init` generates config).

**Example:**
```rust
#[derive(Parser)]
#[command(name = "complexity-guard", version, about)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,
    #[command(flatten)]
    pub analyze: AnalyzeArgs,  // default when no subcommand
}

#[derive(Subcommand)]
pub enum Commands {
    Init(InitArgs),
}

#[derive(Args)]
pub struct AnalyzeArgs {
    pub path: Option<PathBuf>,
    #[arg(long, default_value = "console")]
    pub format: String,
    #[arg(long)]
    pub threads: Option<usize>,
    // ...
}
```

### Pattern 6: ignore Crate Replaces Manual Directory Walker

**What:** The Zig version implemented gitignore-aware walking manually. The `ignore` crate (extracted from ripgrep) provides this as a first-class feature.

**When to use:** Always for file discovery. Handles `.gitignore`, `.ignore`, global git excludes automatically.

**Example:**
```rust
use ignore::WalkBuilder;

let walker = WalkBuilder::new(&root)
    .hidden(false)           // include dot-files if needed
    .git_ignore(true)        // respect .gitignore
    .build();

let files: Vec<PathBuf> = walker
    .filter_map(|e| e.ok())
    .map(|e| e.path().to_path_buf())
    .filter(|p| is_supported_extension(p))
    .collect();
```

## Data Flow

### Primary Analysis Flow

```
CLI args (clap)
    ↓
Config merge: .complexityguard.json + CLI overrides
    ↓
File discovery: ignore::WalkBuilder → Vec<PathBuf>
    ↓
[rayon par_iter] For each PathBuf:
    → create Parser, set language
    → read source: fs::read_to_string()
    → parse: parser.parse() → Tree
    → cyclomatic::analyze(&tree, &source) → Vec<FunctionCyclomatic>
    → cognitive::analyze(&tree, &source) → Vec<u32>
    → halstead::analyze(&tree, &source) → Vec<HalsteadMetrics>
    → structural::analyze(&tree, &source) → (Vec<FunctionStructural>, FileStructural)
    → scoring::compute_function_scores() → Vec<f64>
    → scoring::compute_file_score() → f64
    → FileAnalysisResult (owned, no shared state)
[end par_iter] → Vec<FileAnalysisResult>
    ↓
Sort results by path (for deterministic output)
    ↓
[if duplication enabled, sequential pass]
    → duplication::analyze_all(&file_results) → DuplicationResult
    ↓
Output dispatch:
    → console::render() / json::render() / sarif::render() / html::render()
    ↓
Exit code (0-4 based on violations and baseline)
```

### Key Differences from Zig Data Flow

1. **No explicit allocator threading.** rayon closures return owned values; the collector (`collect::<Vec<_>>()`) handles aggregation. No mutex required.

2. **Config merge is explicit field-by-field.** CLI args override config file values. The `Option<T>` pattern in both layers makes precedence clear: `cli_value.or(config_value).unwrap_or(default)`.

3. **Duplication still sequential.** Cross-file hash comparison requires global state (a `HashMap<u64, Vec<TokenWindow>>`). The Zig "re-parse approach" warning (800%+ overhead noted in PROJECT.md) should be addressed: tokenize during the parallel pass and store token sequences in `FileAnalysisResult`, then run the hash comparison sequentially on the aggregated token data.

4. **SARIF and JSON use typed structs.** No manual string-building. `serde_json::to_writer` handles escaping, ordering, and indentation.

## Integration Points

### External Libraries

| Library | Version | Integration Point | Notes |
|---------|---------|-------------------|-------|
| `tree-sitter` | 0.26.x | `parser/mod.rs` | `Parser::new()`, `set_language()`, `parse()` |
| `tree-sitter-typescript` | 0.23.x | `parser/mod.rs` | `LANGUAGE_TYPESCRIPT`, `LANGUAGE_TSX` constants |
| `tree-sitter-javascript` | 0.25.x | `parser/mod.rs` | `LANGUAGE` constant |
| `rayon` | 1.x | `pipeline/mod.rs` | `par_iter()` on `Vec<PathBuf>` |
| `clap` | 4.x | `cli/args.rs` | `#[derive(Parser, Subcommand, Args)]` |
| `serde` | 1.x | `types.rs`, `cli/config.rs`, `output/` | `#[derive(Serialize, Deserialize)]` |
| `serde_json` | 1.x | `cli/config.rs`, `output/json.rs`, `output/sarif.rs` | `from_str()`, `to_writer_pretty()` |
| `ignore` | 0.4.x | `discovery/mod.rs` | `WalkBuilder::new().build()` |

### Internal Module Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `cli/` → `pipeline/` | `Config` struct (cloned) + `Vec<PathBuf>` | Config is `Clone + Send + Sync` |
| `pipeline/` → `metrics/*` | `&PathBuf`, `&[u8]` source, `&tree_sitter::Tree` | Pure function calls; no shared state |
| `pipeline/` → `types.rs` | Returns `Vec<FileAnalysisResult>` | Owned types; rayon collects safely |
| `metrics/duplication.rs` → `types.rs` | Takes `&[FileAnalysisResult]`, returns `DuplicationResult` | Sequential; called after par_iter |
| `pipeline/` → `output/` | `&ProjectResult` (aggregate) + `&Config` | Output is read-only over results |

### New vs Modified Components

| Component | Status | Change |
|-----------|--------|--------|
| `cli/args.rs` | Modified | clap derive replaces hand-rolled parser; same flags |
| `cli/config.rs` | Modified | serde replaces toml crate; same JSON schema |
| `discovery/mod.rs` | Modified | `ignore` crate replaces manual walker; same semantics |
| `parser/mod.rs` | Modified | Rust tree-sitter API instead of C FFI; same language selection |
| `metrics/cyclomatic.rs` | Modified | Same algorithm; Rust Node traversal API instead of C API |
| `metrics/cognitive.rs` | Modified | Same algorithm; same |
| `metrics/halstead.rs` | Modified | Same algorithm; same |
| `metrics/structural.rs` | Modified | Same algorithm; same |
| `metrics/scoring.rs` | Mostly unchanged | Pure math; direct translation |
| `metrics/duplication.rs` | Modified | Same Rabin-Karp algorithm; address re-parse overhead |
| `pipeline/mod.rs` | Replaced | rayon par_iter replaces `std.Thread.Pool` + Mutex |
| `output/console.rs` | Modified | Same format; `termcolor` or raw ANSI codes |
| `output/json.rs` | Replaced | `serde_json` replaces hand-rolled serializer |
| `output/sarif.rs` | Replaced | `#[derive(Serialize)]` structs replace hand-rolled |
| `output/html.rs` | Modified | Same template; string formatting instead of writer |
| `types.rs` | Modified | Same shape; add `#[derive(Serialize, Clone, Debug)]` |

## Build Order for Incremental Development

The recommended build order minimizes rework and enables testing at each stage:

1. **`types.rs`** — Define all data structures first. Every other module depends on these. Add `#[derive(Debug, Clone, Serialize, Deserialize)]` from the start.

2. **`cli/args.rs` + `cli/config.rs`** — Get argument parsing and config loading working. Write unit tests for config merge precedence. Nothing else can proceed without knowing the config shape.

3. **`discovery/mod.rs`** — File discovery using `ignore`. Integration-test with the fixture directory.

4. **`parser/mod.rs`** — Language selection and tree-sitter parsing. Verify all four languages (ts, tsx, js, jsx) parse without errors against fixtures.

5. **`metrics/cyclomatic.rs`** — Highest value metric; used as the primary traversal baseline for all other metrics. Once this works, the traversal pattern is established.

6. **`metrics/structural.rs`** — Simple single-pass metrics; validates function boundary detection that cognitive and halstead depend on.

7. **`metrics/cognitive.rs`** — Depends on structural (nesting) patterns being correct.

8. **`metrics/halstead.rs`** — Independent of cognitive; can develop in parallel. Token counting is self-contained.

9. **`metrics/scoring.rs`** — Pure math; direct Zig → Rust translation. Test sigmoid values match.

10. **`pipeline/mod.rs`** — Wire the parallel pass. At this point all metrics exist; verify par_iter produces correct per-file results.

11. **`output/console.rs`** — Default output; needed for manual validation during development.

12. **`output/json.rs` + `output/sarif.rs` + `output/html.rs`** — Remaining output formats. JSON and SARIF are mechanical serde derives.

13. **`metrics/duplication.rs`** — Last metric because it requires the full per-file `Vec<FileAnalysisResult>` as input. Address the re-parse overhead by storing token sequences inside `FileAnalysisResult` during the parallel pass.

14. **Integration tests + CI** — Verify exit codes, fixture-based output parity, cross-platform builds.

## Anti-Patterns

### Anti-Pattern 1: Sharing a Single Parser Across Rayon Threads

**What people do:** Create one `tree_sitter::Parser`, wrap it in `Arc<Mutex<Parser>>`, and share it across rayon closures.

**Why it's wrong:** Mutex contention on every file defeats the purpose of parallel processing. The tree-sitter C library underlying `Parser` is not designed for concurrent use on the same instance. Even with `Parser: Send + Sync`, the canonical pattern is one parser per task.

**Do this instead:** Create `Parser::new()` at the start of each rayon closure. Parser initialization is cheap (~microseconds). Grammar loading is zero-cost (static constants).

### Anti-Pattern 2: Re-Parsing Files for Duplication After the Parallel Pass

**What people do:** Run the per-file metric analysis in parallel, then re-read and re-parse every file a second time just to tokenize for the duplication pass.

**Why it's wrong:** This was identified in PROJECT.md as causing 800%+ overhead on large codebases. Two full file reads and two full parses per file doubles I/O and CPU time.

**Do this instead:** Include tokenization (`Vec<Token>`) in `FileAnalysisResult` during the parallel pass. The tokens are computed from the already-parsed tree — no second parse needed. Pass the collected token sequences directly into `duplication::analyze_all()`.

### Anti-Pattern 3: Using String Concatenation for JSON/SARIF Output

**What people do:** Build JSON/SARIF by `format!()` or `write!()` string concatenation, either to avoid serde or to manually control field ordering.

**Why it's wrong:** Manual JSON building is error-prone (escaping, special characters in function names), hard to maintain, and produces incorrect output when function names contain quotes or backslashes.

**Do this instead:** Use `#[derive(Serialize)]` on all output types and `serde_json::to_writer_pretty`. The binary size cost (~200 KB) is well within the 5 MB budget.

### Anti-Pattern 4: Trying to Use Zig's `?T` Optional Pattern for Incremental Phase Population

**What people do:** Port the Zig `?T` optional fields directly (e.g., `cyclomatic: Option<u32>`) and populate them across multiple passes, mutating results in place.

**Why it's wrong:** Mutation across multiple passes means results are partially initialized at various stages, which requires either `Arc<Mutex<T>>` or sequential code. This eliminates rayon's benefits.

**Do this instead:** Compute all metrics in a single pass per file. The rayon closure reads the file, parses, runs all enabled metrics, and returns a complete `FileAnalysisResult`. No optional fields needed at the intermediate level. `Option<T>` is appropriate in output types where a metric may be disabled, not in intermediate computation.

### Anti-Pattern 5: Calling `rayon::ThreadPoolBuilder::build_global()` Too Late

**What people do:** Call `build_global()` after some rayon work has already started (e.g., inside a `par_iter` closure or after a `collect()`).

**Why it's wrong:** The global thread pool initializes on first use. After initialization, `build_global()` returns an error.

**Do this instead:** Configure the thread pool at the top of `main()`, immediately after parsing CLI args, before any parallel work:
```rust
if let Some(threads) = args.threads {
    rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .build_global()
        .expect("Failed to initialize thread pool");
}
```

## Binary Size Considerations

The Zig version achieved 3.6-3.8 MB with `ReleaseSmall`. Rust has a larger baseline but can reach comparable sizes with tuning.

Recommended `Cargo.toml` release profile:
```toml
[profile.release]
opt-level = "z"       # optimize for size
lto = "fat"           # whole-program optimization
codegen-units = 1     # single unit for best LTO
strip = true          # remove debug symbols
panic = "abort"       # remove unwinding machinery (~20-50 KB savings)
```

For Linux targets, build with `x86_64-unknown-linux-musl` and `-C target-feature=+crt-static -C link-self-contained=yes` for a fully static binary. For macOS and Windows, the standard dynamic runtime linkage is acceptable and produces static-feeling binaries in practice.

**Confidence note (MEDIUM):** Rust binaries with tree-sitter grammar crates included will likely exceed the Zig 3.6 MB baseline. Realistic estimate is 5-12 MB before stripping. The 5 MB constraint may need to be relaxed for the Rust version, or `upx` compression applied post-build. This requires empirical measurement during the build phase.

## Sources

- [tree-sitter Rust crate docs (0.26.x)](https://docs.rs/tree-sitter/latest/tree_sitter/struct.Parser.html) — confirmed `Parser: Send + Sync`
- [tree-sitter-typescript crate (0.23.x)](https://docs.rs/tree-sitter-typescript/latest/tree_sitter_typescript/) — `LANGUAGE_TYPESCRIPT`, `LANGUAGE_TSX` constants
- [tree-sitter-javascript crate (0.25.x)](https://docs.rs/tree-sitter-javascript/latest/tree_sitter_javascript/) — `LANGUAGE` constant
- [rayon GitHub](https://github.com/rayon-rs/rayon) — par_iter, ThreadPoolBuilder, work-stealing
- [rayon: Data Parallelism with Rust (Shuttle, 2024)](https://www.shuttle.dev/blog/2024/04/11/using-rayon-rust) — par_iter patterns, mutex contention pitfalls
- [ignore crate docs](https://docs.rs/ignore/latest/ignore/struct.WalkBuilder.html) — WalkBuilder, gitignore support
- [clap v4 derive docs](https://docs.rs/clap/latest/clap/_derive/_tutorial/index.html) — Parser, Subcommand, Args derive
- [serde field attributes](https://serde.rs/field-attrs.html) — Option<T> deserialization, skip_serializing_if
- [min-sized-rust guide](https://github.com/johnthagen/min-sized-rust) — opt-level z, LTO, strip, panic=abort
- [Rust MUSL static binaries (2025)](https://raniz.blog/2025-02-06_rust-musl-malloc/) — musl crt-static, mimalloc performance
- [Using Tree-sitter Parsers in Rust](https://rfdonnelly.github.io/posts/using-tree-sitter-parsers-in-rust/) — build.rs pattern (not needed for crate-based grammars)
- [houseabsolute/actions-rust-cross](https://github.com/houseabsolute/actions-rust-cross) — GitHub Actions cross-compilation

---
*Architecture research for: ComplexityGuard Rust rewrite (Zig → Rust, v0.8 milestone)*
*Researched: 2026-02-24*
