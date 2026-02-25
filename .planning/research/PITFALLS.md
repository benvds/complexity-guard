# Pitfalls Research: Zig → Rust Rewrite of ComplexityGuard

**Domain:** Systems rewrite — Zig to Rust, CLI binary with tree-sitter FFI, cross-platform distribution
**Researched:** 2026-02-24
**Confidence:** HIGH (tree-sitter docs via docs.rs, cargo-zigbuild README, official Rust references, verified with multiple sources)

---

## Critical Pitfalls

### Pitfall 1: tree-sitter Grammar Version Mismatch Causes Type-Level Compile Error

**What goes wrong:**
The `tree-sitter-typescript`, `tree-sitter-javascript`, and `tree-sitter-tsx` grammar crates each declare their own dependency on `tree-sitter` core. If their pinned version differs from the version declared in your `Cargo.toml`, Cargo resolves both versions simultaneously. The `Language` type from version `0.20.x` and the `Language` type from `0.22.x` are **distinct Rust types** despite identical names. The call to `parser.set_language(tree_sitter_typescript::language())` then fails with: `expected tree_sitter::Language, found a different tree_sitter::Language`.

This is not a runtime error — it is a compile error, and it is confusing because the error message names the same type twice.

**Why it happens:**
Cargo allows multiple versions of the same crate. Grammar crates often lag behind the core `tree-sitter` release cadence. The grammar crates on crates.io use tilde version pinning (`~0.20.10`) which prevents them from automatically updating to `0.22.x` even when it is released. This issue was documented in tree-sitter/tree-sitter#3095 and has recurred across multiple major releases.

**How to avoid:**
- Check the `Cargo.toml` of every grammar crate (`tree-sitter-typescript`, `tree-sitter-javascript`) before adding them. Run `cargo tree -d` to detect duplicate versions.
- Pin all grammar crates and the core `tree-sitter` crate to the **same compatible version** range.
- Use `cargo update --precise` if a grammar crate is lagging.
- Prefer grammar crates that have been recently updated. Check the crates.io "last updated" date before depending on them.
- The `tree-sitter-language` intermediary crate (a stable ABI shim) was introduced to reduce this problem. Prefer grammar crates that depend on `tree-sitter-language` rather than `tree-sitter` directly.

**Warning signs:**
- Compile error: "expected `tree_sitter::Language`, found a different `tree_sitter::Language`"
- `cargo tree -d` shows two versions of the `tree-sitter` crate
- Grammar crate `Cargo.toml` shows `tree-sitter = "~0.20"` while project uses `tree-sitter = "0.22"`

**Phase to address:**
Phase 1 (Parser integration) — Resolve version alignment before writing any metric code. Lock all grammar crate versions in `Cargo.lock` immediately.

---

### Pitfall 2: Unwinding Panics Across FFI Boundary Is Undefined Behavior

**What goes wrong:**
If Rust code panics inside a callback or function that is called from C (tree-sitter's C core calls back into Rust for custom input providers), the unwinding stack crosses an FFI boundary. This is undefined behavior in Rust — the program may crash, silently corrupt memory, or produce wrong output. This also applies in reverse: C exceptions unwinding into Rust frames.

For ComplexityGuard, the risk is lower because tree-sitter is used in the Rust-calls-C direction (not C-calls-Rust). However, if `parse_with` (callback-based parsing) is used for streaming input, Rust panics inside the callback are UB.

**Why it happens:**
Rust's panic mechanism assumes the entire stack is Rust frames using Rust's unwind tables. C code has no knowledge of Rust's unwind protocol. The Rustonomicon states: "Unwinding into Rust from another language, or unwinding into another language from Rust is Undefined Behavior."

**How to avoid:**
- Use `parser.parse(source, None)` with a full in-memory `&[u8]` slice rather than `parse_with` callback for file parsing. ComplexityGuard reads the entire file before parsing, so this is the natural approach.
- If callback-based parsing is ever added, wrap the callback body in `std::panic::catch_unwind(|| { ... })` and convert panics to `None` returns.
- In release builds, set `panic = "abort"` in `[profile.release]` of `Cargo.toml`. This prevents unwind overhead and eliminates the UB risk by turning panics into immediate process termination — acceptable for a CLI tool.
- Add `#[cfg(panic = "unwind")]` guards on any code that crosses FFI if needed.

**Warning signs:**
- Using `parse_with` or `parse_with_options` with a Rust closure that could panic
- Stack traces in crash reports that show C frames between Rust frames
- Intermittent crashes that don't reproduce under Miri

**Phase to address:**
Phase 1 (Parser integration) — Establish `panic = "abort"` in `[profile.release]` from the start. Use simple `parse(&source, None)` everywhere.

---

### Pitfall 3: `tree_sitter::Parser` Is Not Clone — Per-Thread Instances Required

**What goes wrong:**
`tree_sitter::Parser` implements `Send` and `Sync` (confirmed via docs.rs), but it requires `&mut self` for `parse()` and `set_language()`. This means you cannot share a single `Parser` across threads without a `Mutex`. Under Rayon or a thread pool, wrapping a single Parser in `Arc<Mutex<Parser>>` causes severe lock contention — every thread blocks waiting to use the parser sequentially, eliminating parallelism.

A secondary mistake is using a `thread_local!` Parser that is initialized with the wrong language (e.g., TypeScript) and then used for a JavaScript file because the language is not reset between tasks.

**Why it happens:**
Developers port the Zig pattern of "one parser per thread" without understanding that Rayon workers are not 1:1 with OS threads in the same way as `std.Thread.Pool`. Rayon's `par_iter` distributes work across a pool, and tasks can execute on any worker thread.

**How to avoid:**
- Use `thread_local! { static PARSER: RefCell<Parser> = RefCell::new(Parser::new()); }` for a per-thread parser instance. `RefCell` prevents concurrent access from the same thread.
- Always call `parser.set_language(language)` at the start of each file analysis task, even if you believe the language is unchanged. Language selection is cheap.
- Do not place the Parser inside `Arc<Mutex<_>>`. Instead, ensure each Rayon worker accesses only its thread-local copy.
- Test with `--threads <N>` at values larger than the number of CPU cores to expose contention bugs.

**Warning signs:**
- Parallel analysis is slower than sequential (classic lock contention symptom)
- Panic: "already borrowed" when using `RefCell<Parser>` if a task panics and leaves the borrow active
- Wrong metrics for files (e.g., JavaScript file analyzed as TypeScript) when language is not reset

**Phase to address:**
Phase 2 (Parallel pipeline) — Establish thread-local parser pattern before adding Rayon. Test correctness with mixed .ts/.js/.tsx files processed concurrently.

---

### Pitfall 4: Binary Size Balloons to 20+ MB Without Explicit Size Profile

**What goes wrong:**
A default `cargo build --release` binary for a tool with three tree-sitter grammars (TypeScript, TSX, JavaScript) compiled in, Serde for JSON serialization, and standard library formatting machinery will typically produce a binary in the range of 15–25 MB. The Zig version achieved 3.6–3.8 MB with `ReleaseSmall`. Matching that in Rust requires deliberate configuration and likely cannot be achieved without accepting longer compile times.

**Why it happens:**
Rust's `release` profile defaults to `opt-level = 3` (speed, not size), `codegen-units = 16` (parallelism over optimization), and no stripping. Serde's `derive` macros generate substantial code. The standard library's formatting machinery (`println!`, `format!`) pulls in unicode tables. Rust does not have an equivalent of Zig's `ReleaseSmall` as a first-class profile.

**How to avoid:**
Add a size-optimized release profile to `Cargo.toml`:
```toml
[profile.release]
opt-level = "z"        # optimize for size, not speed
lto = true             # link-time optimization removes dead code across crates
codegen-units = 1      # single codegen unit for maximum LTO effectiveness
strip = true           # strip debug symbols and symbol table
panic = "abort"        # removes unwind tables (~15% size reduction)
```
Additional techniques if still too large:
- Use `#[no_std]` where feasible (not practical for a full CLI, skip this)
- Replace `serde_json` with a lighter serializer (`miniserde`, `simd-json`) — evaluate after measuring
- Consider `upx --best` compression for final distribution binaries (adds ~50ms startup on cold run, negligible)
- Build against `musl` for Linux to get static binary without glibc overhead

Expected outcome: 4–8 MB with the above profile. Sub-5 MB is achievable. Under 4 MB requires UPX compression or eliminating large dependencies.

**Warning signs:**
- Default `cargo build --release` produces >15 MB binary
- `cargo bloat --release` shows `serde` or formatting as top contributors
- Binary grows significantly when adding each grammar crate

**Phase to address:**
Phase 1 (Project setup) — Add the size-optimized profile to `Cargo.toml` immediately. Check binary size at end of every phase. Do not wait until Phase 5 to discover it is 20 MB.

---

### Pitfall 5: Cross-Compilation Requires Zig as Linker — cargo-zigbuild Has Gaps

**What goes wrong:**
Rust does not include a cross-linker in its toolchain the way Zig does. The standard approach — installing cross-compilation targets with `rustup target add` — only provides the Rust standard library for the target. You still need a C linker and sysroot for the target platform. With tree-sitter (a C library) compiled as part of the build via `build.rs`, this requirement is not optional.

The recommended solution (`cargo-zigbuild`) covers most cases but has documented gaps:

1. **Static glibc linking is unsupported:** `-C target-feature=+crt-static` with glibc targets is not supported by `zig cc`. Use musl targets (`x86_64-unknown-linux-musl`) instead for static Linux binaries.
2. **Windows targets:** `x86_64-pc-windows-gnu` cross-compilation from macOS/Linux via cargo-zigbuild has limited support. Release builds on Windows Docker images fail. The `x86_64-pc-windows-msvc` target cannot be cross-compiled without the MSVC SDK.
3. **macOS strip binary step:** Release cross-compile to macOS targets on Linux may fail with `strip: program not found`.

**Why it happens:**
Zig ships its own bundled sysroots and musl libc, which is why Zig cross-compilation works out of the box. Rust delegates linking to the host system toolchain and does not bundle sysroots.

**How to avoid:**
- Use `cargo-zigbuild` for Linux (musl and gnu-gnu targets) and macOS targets. These work well.
- For Windows: use GitHub Actions `windows-latest` runner to build Windows binaries natively rather than cross-compiling. This is the most reliable approach.
- For macOS arm64 (aarch64-apple-darwin): build on an actual macOS ARM runner in GitHub Actions.
- Target matrix: build Linux (both arches) on Linux runner with cargo-zigbuild + musl; build macOS binaries on macOS runner; build Windows on Windows runner.
- Accept that cross-compilation in Rust cannot be as seamless as in Zig. Plan the CI matrix accordingly.

**Warning signs:**
- `cargo zigbuild` fails with linker errors when adding tree-sitter C sources
- `strip: program not found` during macOS cross-compile on Linux
- Windows binary is built on Linux but crashes immediately when run (ABI mismatch)
- Static glibc linking silently falls back to dynamic linking

**Phase to address:**
Phase 6 (Cross-compilation and CI) — Design the GitHub Actions matrix from scratch rather than assuming Zig's matrix will translate. Validate each target binary actually executes on a native runner.

---

### Pitfall 6: Duplication Re-Parse Overhead — Zig's 800%+ Problem Must Be Solved in Rust

**What goes wrong:**
The Zig implementation has a documented architectural flaw: the duplication detection pipeline re-reads and re-parses every file a second time after the metrics pipeline completes. This creates 800%+ overhead on large codebases because:

1. Each file is read from disk twice
2. Each file is parsed by tree-sitter twice
3. File I/O and parsing are the dominant costs in the pipeline

In Rust, naively porting the Zig structure (metrics phase first, then duplication phase with fresh re-parse) reproduces the same bug.

**Why it happens:**
In the Zig implementation, the metrics pipeline uses per-worker arenas that are freed after each file. The tokenized output for duplication detection is not retained because there was no obvious lifetime to attach it to that would survive the arena deallocation. The natural fix in Zig is complex. In Rust, ownership makes the correct approach clearer but requires deliberate design.

**How to avoid:**
Design the Rust pipeline to tokenize during the first parse and retain tokens alongside metrics results:

```
Per-file worker:
  1. Read file
  2. Parse with tree-sitter → Tree
  3. Run all metric walkers on Tree → MetricResults
  4. Run tokenizer on Tree → Vec<Token>  ← done in same pass, same Tree
  5. Return (MetricResults, Vec<Token>) as a tuple

After all workers complete:
  6. Run detectDuplication(all_file_tokens) → DuplicationResult
```

Key design points:
- `tree_sitter::Tree` is `Send` (confirmed), so it can be returned from Rayon workers along with results
- But `Tree` contains a raw pointer to a C heap object and its lifetime is tied to the source bytes being live. Do not drop `source: Vec<u8>` while `Tree` is alive.
- `Vec<Token>` is pure Rust data and can be moved freely across thread boundaries
- Drop the `Tree` immediately after tokenization — do not retain it across the barrier

The corrected architecture eliminates the re-parse entirely. Duplication tokenization runs once per file in the same worker task as metrics.

**Warning signs:**
- Duplication analysis is absent from the per-file worker function and runs in a separate post-processing step that re-reads files
- Benchmarks show analysis time scales super-linearly with file count (re-parse overhead compounds)
- Memory profile shows two peaks (metrics phase + duplication phase) rather than one sustained plateau

**Phase to address:**
Phase 2 (Core pipeline) — Design the pipeline architecture to tokenize-during-parse before implementing any metric. This is a foundational decision that is expensive to retrofit.

---

### Pitfall 7: Rust Lifetimes Make Retaining tree-sitter Nodes Between Phases Impossible

**What goes wrong:**
`tree_sitter::Node` (the Rust wrapper for `TSNode`) is not `Send` and cannot outlive the `Tree` it came from. Developers attempting to cache nodes or store them for cross-file analysis will encounter lifetime errors that appear to have no solution. This is a different problem than the grammar version mismatch — this is the Rust borrow checker enforcing tree-sitter's ownership invariants correctly.

Example of what fails:
```rust
let tree = parser.parse(&source, None).unwrap();
let root = tree.root_node(); // Node<'_> — borrows from tree
drop(tree); // ERROR: cannot drop tree while root is borrowed
my_struct.root = root; // ERROR: Node does not implement Send
```

**Why it happens:**
`Node` is a thin wrapper around `TSNode` (a struct-by-value in C), which internally contains a pointer back into the `Tree`'s memory. Rust correctly infers that `Node` cannot outlive `Tree`. In Zig, the C `TSNode` struct is copied by value and this lifetime relationship is not enforced — it works until it doesn't.

**How to avoid:**
- Never store `Node` values between pipeline stages. Use `Node` only within the scope of the file worker task, during the same stack frame that owns `Tree`.
- Extract all needed information from the tree (metrics, tokens, line numbers) before the function returns. Return pure Rust data structures (`Vec<Token>`, metric structs) — not tree nodes.
- If incremental parsing is ever needed, retain the `Tree` alongside the `source: Vec<u8>` in a struct that owns both and never lends `Node` values outside.

**Warning signs:**
- Compiler error: "does not live long enough" when trying to pass `Node` to another function that stores it
- Attempting to put `Node` in a struct that will live beyond the current function
- Trying to return `Node` from a Rayon parallel iterator

**Phase to address:**
Phase 1 (Parser wrapper) — Design the `ParseResult` type to own only pure Rust data. Make `Node` usage purely local to metric walker functions.

---

### Pitfall 8: Arena Allocator Pattern Has No Direct Zig Equivalent in Rust

**What goes wrong:**
The Zig implementation extensively uses `std.heap.ArenaAllocator` — allocate many small objects, free all at once by deiniting the arena. This pattern is idiomatic in Zig but is **not idiomatic in Rust**. Attempting to port the pattern directly using `bumpalo` or `typed-arena` crates creates friction with Rust's borrow checker, because objects allocated in an arena cannot outlive the arena, and Rust enforces this with lifetimes.

The specific friction: metrics walkers in Zig return slices allocated in the worker arena. In Rust, the equivalent `Vec<MetricResult>` returned from a walker function would need to contain references into the arena (`&'arena MetricResult`) rather than owned values, which complicates function signatures and prevents moving results across thread boundaries.

**Why it happens:**
Zig arenas are transparent to callers — any allocation using the arena allocator is automatically in the arena's lifetime. Rust has no equivalent because Rust tracks lifetimes explicitly. bumpalo works but requires propagating `'bump` lifetime parameters throughout all types that reference arena-allocated data, which is impractical for a 10k+ LOC codebase.

**How to avoid:**
- Use `Vec<T>` with owned `T` values everywhere. This is idiomatic Rust and avoids the arena lifetime problem.
- For short-lived temporary allocations within a single function (e.g., building an intermediate data structure during AST walking), use a local `Vec` and discard it when done. The allocator overhead is acceptable.
- Use `bumpalo` only if profiling shows allocator overhead is a bottleneck, and only for types that live entirely within one function scope.
- The Rayon work-stealing approach combined with per-task `Vec` allocations is sufficient and idiomatic.

**Warning signs:**
- Function signatures with `'arena` lifetime parameters propagating through metric walker types
- Trying to return `&'arena [MetricResult]` from worker functions passed to Rayon
- Compile errors about lifetimes when `Vec<&'arena T>` is moved across thread boundaries

**Phase to address:**
Phase 1 (Core types) — Define all result types as owned structs with `Vec<T>` fields, not arena-allocated slices. Do not introduce arena crates until profiling demands it.

---

### Pitfall 9: `build.rs` for Grammar C Sources Breaks Cross-Compilation Without the Right `cc` Configuration

**What goes wrong:**
The three tree-sitter grammars (typescript, tsx, javascript) are C source files that must be compiled and linked into the Rust binary. This is handled by a `build.rs` script using the `cc` crate. Without explicit configuration, the `cc` crate uses the host C compiler, which produces host-architecture object files — not the target architecture. Cross-compilation silently builds the wrong architecture.

A secondary issue: the `cc` crate honors `CC` and `CXX` environment variables, but `cargo-zigbuild` sets its own linker overrides. If `build.rs` does not propagate the correct cross-compilation flags, the C grammar objects are built for the wrong target while the Rust objects are built for the correct target, causing linker errors.

**Why it happens:**
`build.rs` is executed on the host machine. The `cc` crate is designed to respect cross-compilation but requires correct environment setup. When using `cargo-zigbuild`, the Zig C compiler is the linker but the `cc` crate may not automatically use it for C source compilation unless `CC` is set to `zig cc --target=<target>`.

**How to avoid:**
- Use `cc::Build::new().file("...").compile("grammar")` pattern correctly. The `cc` crate does handle cross-compilation when `cargo-zigbuild` sets the appropriate environment variables.
- Test cross-compilation on CI early (Phase 1), not in the final cross-compilation phase. A CI step that builds for `aarch64-unknown-linux-musl` from an `x86_64` Linux runner will surface this immediately.
- Pin grammar C source files in the repository (vendor them) rather than downloading at build time. This avoids network failures and ensures reproducible builds.
- Add `cargo:rerun-if-changed=src/grammar/typescript/parser.c` directives in `build.rs` so incremental builds work correctly.

**Warning signs:**
- Cross-compiled binary crashes immediately with "Illegal instruction" (architecture mismatch)
- `build.rs` succeeds but final `cargo zigbuild` link step fails with "incompatible object format"
- `cargo check` passes but `cargo build --target aarch64-...` fails

**Phase to address:**
Phase 1 (Project setup) — Write `build.rs` and test cross-compilation to at least one non-native target before any feature work. This catches the C compilation issue before it is entangled with metric code.

---

### Pitfall 10: std::HashMap Is Slower Than Needed for the Duplication Hash Index

**What goes wrong:**
The duplication detection builds a hash index mapping `u64` rolling hashes to lists of token windows. `std::collections::HashMap` uses SipHash-1-3 as its default hasher, which is designed for DoS resistance (HashDoS attacks) rather than speed. For internal data structures with `u64` integer keys where HashDoS is not a concern, SipHash is measurably slower than alternatives.

In the Zig implementation, `std.AutoHashMap(u64, ...)` uses a simple open-addressing scheme with a fast integer hash. The Rust equivalent `HashMap<u64, Vec<TokenWindow>>` with SipHash may be 2–3x slower for lookups on a hot table.

**Why it happens:**
`std::HashMap` defaults to SipHash for safety. The Rust Performance Book explicitly recommends switching to `FxHashMap` (from `rustc-hash`) for performance-critical code where DoS resistance is not needed. This is a well-known optimization but requires a conscious decision to deviate from the default.

**How to avoid:**
- Use `rustc_hash::FxHashMap` for the duplication hash index. This is the hash algorithm used internally by the Rust compiler itself for its own hash tables.
- Import: `use rustc_hash::FxHashMap;` after adding `rustc-hash = "2"` to `Cargo.toml`.
- The `FxHashMap` type is a drop-in replacement: same API as `HashMap`.
- Only switch the duplication hash index — keep `HashMap` elsewhere unless profiling shows it is hot.

**Warning signs:**
- Duplication detection benchmarks are significantly slower than expected given the Rabin-Karp algorithmic complexity
- Profiling (with `cargo flamegraph`) shows `siphasher` as hot in the duplication path

**Phase to address:**
Phase 3 (Duplication detection port) — Use `FxHashMap` from the start for the token window index. Do not optimize later; start with the right hasher.

---

### Pitfall 11: Rust Compile Times Are Significantly Longer Than Zig

**What goes wrong:**
Zig's compile times are fast by design. Rust's compile times, especially for release builds with `lto = true` and `codegen-units = 1`, are slow. A project with three grammar crates, Serde, Rayon, and several output format libraries may have:

- `cargo build` (debug): 45–90 seconds on first build
- `cargo build --release` with full LTO: 3–5 minutes
- Incremental debug builds: 5–15 seconds

This affects developer experience during the rewrite and CI turnaround time.

**Why it happens:**
Rust's monomorphization and LLVM backend have fundamentally higher compilation overhead than Zig's single-pass compilation model. LTO across many crates compounds this. The grammar crates compile substantial C source code via `build.rs`.

**How to avoid:**
- Use `cargo check` during development (type-checks without full compilation — runs in seconds).
- Use the `dev` profile (not `release`) during implementation phases. LTO only matters for the final binary.
- Split the project into multiple crates (workspace) only if crate boundaries provide meaningful compile-time isolation. For a single-binary CLI, a single crate is fine.
- Use `sccache` or GitHub Actions' Cargo cache (`actions/cache`) to avoid rebuilding dependencies on every CI run.
- Add `[profile.dev] opt-level = 1` to improve debug-build runtime without full release cost, speeding up slow tests.
- Accept that CI release builds will be slow (3–5 minutes). This is the cost of the Rust ecosystem.

**Warning signs:**
- Full clean rebuild taking >10 minutes (indicates excessive monomorphization from generic code)
- Incremental builds rebuilding too many units (check `cargo build --timings`)
- CI timeout on release build step

**Phase to address:**
All phases — Set up CI caching in Phase 1. Accept slow release builds. Do not add unnecessary generic abstractions that amplify monomorphization.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Porting Zig `defer` cleanups as bare `drop()` calls | Familiar pattern | Easy to miss, not RAII — `drop()` is manual, not automatic | Never — use struct `Drop` impls or scope-based ownership |
| Using `unwrap()` in metric walkers | Fast to write | Panics on unexpected AST structure in production | Dev only — replace with proper error propagation before release |
| Allocating `String` for every token kind | Simple code | String allocation per token explodes memory on large files | Never — use `&'static str` or interned string IDs for token kinds |
| `Arc<Mutex<HashMap>>` for shared metric results | Simple concurrency | Lock contention eliminates parallelism benefit | Never for hot paths — use per-thread collection + merge |
| Skipping `cargo test` on cross-compiled targets | Faster CI | Binaries that build but produce wrong output on target | Never — add at least one smoke test on each target |
| Vendoring tree-sitter grammar versions that are outdated | No immediate breakage | Misses bug fixes in grammar; TypeScript syntax coverage gaps | Acceptable for initial port, but set a version-review cadence |
| Using `serde_json::Value` for all JSON output | Flexible, no type design | 3–5x slower serialization; no compile-time schema validation | Never for hot output path — use typed serialization structs |

---

## Integration Gotchas

Common mistakes when connecting to external systems and libraries.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| tree-sitter grammar crates | Assuming latest crate version is compatible with latest core | Run `cargo tree -d` and verify no duplicate `tree-sitter` versions before adding grammar crates |
| cargo-zigbuild (cross-compile) | Using `--target x86_64-pc-windows-gnu` from Linux for Windows release builds | Build Windows binaries on `windows-latest` GHA runner natively |
| tree-sitter `Tree` lifetime | Keeping `Node` values after calling any function that requires the original source | Extract all data from nodes into owned Rust types within the same scope as `Tree` |
| GitHub SARIF upload | Carrying over Zig's 0-indexed line numbers unchanged | Verify 1-indexed conversion: `sarif_line = ts_node.start_point().row + 1` |
| Rayon `par_iter` | Creating a new `Parser` inside each `par_iter` task without `thread_local!` | Use `thread_local! { static PARSER: RefCell<Parser> = RefCell::new(Parser::new()); }` |
| `build.rs` grammar compilation | Not vendoring grammar C sources, relying on network at build time | Vendor all grammar C sources in the repo under `vendor/` |
| musl static linking | Linking against glibc dynamically on the Linux musl target | Always use `x86_64-unknown-linux-musl` for static Linux binaries |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-parsing files for duplication after metrics phase | Analysis time 800%+ above expected; two sequential passes visible in `--verbose` | Tokenize during first parse pass and return tokens alongside metrics | Noticeable at 100 files; severe at 1000+ |
| `std::HashMap` with default SipHash for u64 keys | Duplication hash index is CPU-bottlenecked | Use `FxHashMap<u64, Vec<TokenWindow>>` from `rustc-hash` | Hot path visible in flamegraph at ~500 files |
| `String::clone()` for every function name in results | Memory spikes on large codebases | Use string interning or `Arc<str>` for repeated names | 10k+ files with many duplicate function names |
| Single `Mutex<Vec<FileResult>>` shared across Rayon workers | Rayon thread pool stalls waiting for mutex | Each worker returns results; merge after `par_iter().collect()` | Visible at > 8 threads |
| Reading entire file into `Vec<u8>` with no size limit | OOM on generated files (minified JS can be 50+ MB) | Enforce max file size limit (default 10 MB) with early rejection | First user with a minified bundle in the scan path |
| Recursive AST descent implemented as Rust recursion | Stack overflow on deeply nested generated code | Use explicit stack (`Vec<Node>`) for tree traversal | Nesting depth > ~3000 frames (can happen in generated code) |
| Building output strings via `String` concatenation | Console output slow on 10k+ file results | Use `BufWriter<Stdout>` and write directly, or build output in one pass | Reports with thousands of results |

---

## Security Mistakes

Domain-specific security issues for a CLI code analysis tool.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Following symlinks during directory walk without a depth limit | Infinite loop or reading files outside the project (e.g., `/etc/passwd`) | Use `walkdir` crate with `follow_links(false)` default; add `max_depth` guard |
| No file size limit before reading into memory | DoS via 1 GB minified JS file passed to `--include` | Reject files above configurable limit (default 10 MB) before allocating |
| Path traversal in `--output` flag | `--output ../../.ssh/authorized_keys` overwrites sensitive files | Validate output path: reject `..` components, check write permission before opening |
| Unbounded duplication hash index memory | Codebase with pathological repetition (generated code) fills RAM | Apply `MAX_BUCKET_SIZE` cap (the Zig implementation has 1000 — port this) |
| Leaking source code in error messages | Printing file content in parse error output | Only show file path and line number in errors, never source text |

---

## UX Pitfalls

Common user experience mistakes when porting CLI behavior.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| CLI flag names changing from the Zig version | Breaks existing CI scripts and shell aliases | Map all existing flags identically; this is a drop-in binary replacement |
| Exit codes changing between versions | CI pipelines that gate on exit code break silently | Keep exit codes 0–4 identical to the Zig version |
| JSON output field names changing | Any tool that parses ComplexityGuard JSON breaks | Run Zig and Rust versions side-by-side on the same input; diff output exactly |
| SARIF `tool.driver.version` not updated | GitHub Code Scanning shows wrong version | Update version string to reflect Rust rewrite version |
| Slower startup time than Zig version | Users notice CLI "feels slower" even if analysis is same speed | Profile startup with `cargo flamegraph` — Rust's `main()` should be near-instant |
| Different float formatting in JSON output | Numbers like `3.5999999999` vs `3.6` break downstream consumers | Use controlled precision: `format!("{:.2}", value)` consistently |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Grammar version alignment:** `cargo tree -d` shows zero duplicate `tree-sitter` crate versions
- [ ] **Binary size:** Release binary is under 5 MB — measured, not assumed
- [ ] **Cross-compilation:** Each target binary (`linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`, `windows-x64`) runs correctly on a native machine, not just builds
- [ ] **JSON output parity:** Byte-for-byte field name match with Zig version's JSON output on same input (field order may differ but all fields present)
- [ ] **Exit code parity:** Exit codes 0/1/2/3/4 match Zig version on identical scenarios
- [ ] **Re-parse eliminated:** Duplication tokenization runs in the first parse pass — verify no file is read twice in flamegraph or with `strace`
- [ ] **Windows path separator:** SARIF `artifactLocation.uri` uses forward slashes on Windows output
- [ ] **Panic = abort:** Release profile has `panic = "abort"` — verify with `readelf -d` that no unwind sections present
- [ ] **Thread-local parser language reset:** Each parallel file analysis task calls `set_language()` even if the previous task used the same language
- [ ] **Token kind is `&'static str`:** Token kinds are not heap-allocated strings per token — verify no `String` allocation per token in the tokenizer hot path

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Grammar version mismatch at compile time | LOW | `cargo update` specific grammar crate; pin all to same tree-sitter version in `Cargo.lock` |
| Panic UB across FFI | MEDIUM | Add `panic = "abort"` to release profile; wrap any callbacks in `catch_unwind` |
| Parser contention killing parallelism | MEDIUM | Refactor to `thread_local! Parser`; measure before and after with `hyperfine` |
| Binary size exceeds 5 MB | LOW–MEDIUM | Add full size-optimization profile to `Cargo.toml`; run `cargo bloat --release` to identify top contributors |
| Cross-compilation failing for one target | MEDIUM | Move that target to native GHA runner; do not attempt to fix cargo-zigbuild limitations |
| Re-parse overhead reproduced from Zig | HIGH | Refactor pipeline to unified per-file worker returning `(MetricResults, Vec<Token>)` — requires restructuring parallel pipeline |
| `Node` lifetime errors when crossing boundaries | LOW | Extract data into owned structs immediately; do not fight the lifetime — the borrow checker is right |
| Arena allocator pattern causing lifetime pain | MEDIUM | Remove arena crate; use `Vec<T>` with owned values throughout |
| `build.rs` cross-compile produces wrong architecture | MEDIUM | Test cross-compile to one non-native target in Phase 1 CI; fix `cc` configuration before it compounds |
| Compile times blocking CI | LOW | Add `actions/cache` for Cargo target directory; parallelize CI matrix jobs |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Grammar version mismatch | Phase 1 (Setup) | `cargo tree -d` shows no duplicate tree-sitter versions |
| Panic across FFI boundary | Phase 1 (Setup) | `panic = "abort"` in release profile from day one |
| Parser thread contention | Phase 2 (Parallel pipeline) | `hyperfine` shows linear speedup with thread count |
| Binary size bloat | Phase 1 (Setup) | Binary size checked after every phase; <5 MB before shipping |
| Cross-compilation gaps | Phase 1 + dedicated CI phase | Each target binary runs on native runner, not just builds |
| Duplication re-parse overhead | Phase 2 (Core pipeline design) | Flamegraph shows single parse pass per file; no file read twice |
| Node lifetime errors | Phase 1 (Parser wrapper types) | ParseResult type returns only owned data; compiles clean |
| Arena allocator friction | Phase 1 (Core types) | All result types use owned `Vec<T>`; no arena crate imported |
| build.rs cross-compile | Phase 1 (Setup) | CI cross-compiles to `aarch64-unknown-linux-musl` from `x86_64` runner |
| HashMap performance | Phase 3 (Duplication port) | FxHashMap used for token index; benchmarked against expected throughput |
| Compile time impact | All phases | CI caching configured in Phase 1; incremental builds used in dev |

---

## Zig-Specific Patterns That Do Not Translate to Rust

A focused mapping for developers coming directly from the Zig implementation.

| Zig Pattern | Why It Fails in Rust | Rust Equivalent |
|-------------|---------------------|-----------------|
| `defer allocator.free(slice)` | Rust has no `defer` keyword | `Drop` trait implementation or scope-based `Vec` (auto-freed) |
| `std.heap.ArenaAllocator.init(...)` + `defer arena.deinit()` | Lifetime parameters propagate through all borrowed types | Own data with `Vec<T>`; for true arena use, `bumpalo::Bump` with `'bump` lifetime throughout |
| `comptime` constants | Rust uses `const fn` and `const` items; fewer zero-cost abstractions at this level | `const fn` + `const` generics; acceptable equivalent |
| `?T` optional with no allocator | Direct equivalent: `Option<T>` | `Option<T>` — identical semantics |
| `!T` error union (`anyerror!T`) | Direct equivalent: `Result<T, E>` | `Result<T, Box<dyn Error>>` or `anyhow::Error` |
| `@cImport` for C headers | Rust uses `extern "C"` declarations + bindgen or manual `unsafe extern` blocks | `bindgen` for generating bindings; or use tree-sitter's Rust crate which provides safe wrappers |
| `@atomicStore` / `std.atomic.Value` | Direct equivalent: `std::sync::atomic::AtomicU32` | `AtomicU32::fetch_add(1, Ordering::Relaxed)` |
| Per-worker `ArenaAllocator` in thread pool | Arena lifetime cannot cross `Send` boundary safely | Per-task `Vec<T>` returned and collected; `rayon::collect()` |
| `std.Thread.Pool` with explicit mutex | Direct equivalent via Rayon or `std::thread::scope` | `rayon::ThreadPool` or `rayon::par_iter()` |

---

## Sources

- [tree-sitter Rust bindings docs (docs.rs)](https://docs.rs/tree-sitter/latest/tree_sitter/) — Parser Send/Sync, Tree lifetime, Node constraints — HIGH confidence
- [Versioning Conflict for Grammars' Rust Bindings — tree-sitter/tree-sitter#3095](https://github.com/tree-sitter/tree-sitter/issues/3095) — Grammar version mismatch details — HIGH confidence
- [cargo-zigbuild README](https://github.com/rust-cross/cargo-zigbuild/blob/main/README.md) — Cross-compilation limitations — HIGH confidence
- [Zig Makes Rust Cross-compilation Just Work (actually.fyi)](https://actually.fyi/posts/zig-makes-rust-cross-compilation-just-work/) — Zig vs Rust cross-compile comparison — MEDIUM confidence
- [min-sized-rust (johnthagen/min-sized-rust)](https://github.com/johnthagen/min-sized-rust) — Binary size reduction techniques — HIGH confidence
- [The Rust Performance Book — Hashing](https://nnethercote.github.io/perf-book/hashing.html) — FxHashMap recommendation — HIGH confidence
- [rustc-hash crate](https://github.com/rust-lang/rustc-hash) — FxHashMap implementation — HIGH confidence
- [Arenas in Rust (manishearth.github.io)](https://manishearth.github.io/blog/2021/03/15/arenas-in-rust/) — Arena allocator patterns and Rust friction — MEDIUM confidence
- [bumpalo crate docs](https://docs.rs/bumpalo/latest/bumpalo/) — Arena allocator Rust equivalent — HIGH confidence
- [Lessons learned from a successful Rust rewrite (gaultier.github.io)](https://gaultier.github.io/blog/lessons_learned_from_a_successful_rust_rewrite.html) — C FFI friction, arena allocators in Rust rewrites — MEDIUM confidence
- [The Rustonomicon — FFI Unwinding](https://doc.rust-lang.org/nomicon/ffi.html) — Panic across FFI boundary UB — HIGH confidence
- [cargo-zigbuild issue #231](https://github.com/rust-cross/cargo-zigbuild/issues/231) — Static glibc unsupported limitation — HIGH confidence
- [Rayon optimization article — Making a parallel Rust workload 10x faster (gendignoux.com)](https://gendignoux.com/blog/2024/11/18/rust-rayon-optimized.html) — Rayon parallelism pitfalls — MEDIUM confidence
- ComplexityGuard Zig source (`src/pipeline/parallel.zig`, `src/metrics/duplication.zig`) — Re-parse overhead architecture — HIGH confidence (direct code inspection)

---

*Pitfalls research for: ComplexityGuard Zig → Rust rewrite (v0.8 milestone)*
*Researched: 2026-02-24*
*Confidence: HIGH — verified against official docs, crates.io, and direct Zig source inspection*
