# Phase 12: Parallelization & Distribution - Research

**Researched:** 2026-02-21
**Domain:** Zig threading (std.Thread.Pool), tree-sitter thread safety, cross-compilation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Thread control:**
- Default thread count: auto-detect CPU cores (use all available)
- Flag: `--threads N` for explicit thread count
- `--threads 1` bypasses the thread pool entirely (single-threaded mode, no pool overhead) — useful for debugging
- Thread count is also configurable in `.complexityguard.json` (`threads` field); flag overrides config

**Output determinism:**
- Output order is always deterministic regardless of thread scheduling — results sorted by file path before output
- JSON output structure stays identical to current schema — parallelization is invisible to consumers, files array sorted by path
- No thread metadata in the main output structure

**Performance feedback:**
- Timing information (e.g., "Analyzed 1,234 files in 0.8s") shown only with `--verbose`
- Total elapsed time only — no per-stage breakdown
- JSON output includes `elapsed_ms` and `thread_count` in metadata section (for CI performance tracking)
- No progress indicator (spinner/bar) — tool targets sub-2s execution, progress display is unnecessary

### Claude's Discretion

- Error handling strategy for parallel parse failures (continue vs fail-fast, error collection approach)
- Thread pool implementation details (work-stealing, fixed queue, etc.)
- Memory management strategy for parallel allocations
- Cross-compilation build configuration details
- Binary size optimization if parallelization adds weight

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PERF-01 | Tool analyzes 10,000 TypeScript files in under 2 seconds | Thread pool parallelizes parse+metrics per file; 8-16x speedup expected on 8+ core hardware |
| PERF-02 | Tool processes files in parallel via thread pool | `std.Thread.Pool` with `spawnWg` is the correct Zig primitive; one parser per thread for tree-sitter safety |
| DIST-01 | Tool compiles to single static binary under 5 MB | Zig cross-compile with `-Doptimize=ReleaseSafe -fstrip`; CI already does this in release.yml |
| DIST-02 | Tool cross-compiles to x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows | CI workflow release.yml already builds all 5 targets; may need threading adjustments per platform |
</phase_requirements>

## Summary

Phase 12 has two distinct concerns: parallelizing the analysis pipeline and verifying cross-platform distribution. The cross-compilation infrastructure is already complete — `release.yml` already builds all 5 target platforms using a single Ubuntu runner and Zig's built-in cross-compilation. The `--threads` flag and `threads` config field are already parsed and stored in `cfg.analysis.threads`. What is missing is the actual thread pool wiring in `main.zig` and the parallel execution of the per-file pipeline.

The performance data from Phase 10.1 benchmarks makes the challenge concrete: on an 8-core AMD Ryzen 7 5700U, VS Code (5,071 files) takes 19.8s single-threaded; webpack (6,889 files) takes 1.76s. The target is 10,000 files in under 2 seconds. Parsing dominates at 40–64% of pipeline time. With 8 cores and near-linear speedup on the parse stage, a 10,000-file workload is achievable: the webpack result (6,889 files in 1.76s single-threaded) suggests 10,000 files would take ~2.6s single-threaded, which with 8x parallelism would be well under 0.5s.

The key constraint is tree-sitter thread safety: `TSParser` objects are NOT thread-safe and cannot be shared. Each worker thread must own its own parser instance (create at thread start, destroy at thread end). `TSTree` instances are also not thread-safe but are owned per result and never shared between threads in this architecture. The recommended approach is a per-file work item dispatched to a thread pool, where each thread locally creates a parser, reads the file, runs all metrics, and writes the result to a mutex-protected output list.

**Primary recommendation:** Implement a `src/pipeline/parallel.zig` module that wraps the current per-file pipeline in a thread pool work item. Each work item owns its own parser, performs parse + all metric passes, and appends to a shared mutex-protected results list. After `wg.wait()`, main thread sorts by path and proceeds to output unchanged.

## Standard Stack

### Core (all stdlib, no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `std.Thread.Pool` | Zig 0.15 stdlib | Work-stealing thread pool | Built into Zig stdlib, no external dep, auto-detects CPU count |
| `std.Thread.WaitGroup` | Zig 0.15 stdlib | Barrier for all pool jobs to complete | Pairs with `spawnWg` for clean join semantics |
| `std.Thread.Mutex` | Zig 0.15 stdlib | Protects shared results list | Low contention — only locked during result append |
| `std.Thread.getCpuCount()` | Zig 0.15 stdlib | Detect logical CPU count for `--threads auto` | Cross-platform, returns error on failure (safe fallback to 1) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `std.heap.ThreadSafeAllocator` | Zig 0.15 stdlib | Thread-safe allocator wrapper | If a single allocator must be shared across threads |
| Per-thread arena allocators | Zig 0.15 stdlib | Independent allocation per work item | Preferred: each work item allocates from its own arena, avoids contention |

**No new build.zig.zon dependencies needed.**

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `std.Thread.Pool` | Manual `std.Thread.spawn` per file | Pool reuses threads (no spawn overhead per file), better for 10K files |
| Per-thread arena | `std.heap.ThreadSafeAllocator` | Arena per work item = zero contention, simpler cleanup; ThreadSafeAllocator adds lock overhead |
| Mutex-protected append | Atomic index pre-allocation | Pre-allocate output slice, each thread writes to its own index; eliminates mutex but requires knowing count upfront |

## Architecture Patterns

### Recommended Project Structure

The parallelization can be added as a thin wrapper around the existing per-file pipeline. No restructuring of metrics modules is needed.

```
src/
├── main.zig                   # Wire thread count from cfg; call parallel.analyzeFilesParallel
├── pipeline/
│   └── parallel.zig           # NEW: thread pool dispatch, work items, result collection
├── parser/
│   └── parse.zig              # parseFile() unchanged — each thread calls it independently
├── metrics/                   # All metric analyzers unchanged — stateless, safe to call from any thread
└── output/                    # Output modules unchanged — called after all threads complete
```

The existing `parseFiles()` function in `parse.zig` is the single-threaded entrypoint. The new parallel module replaces its call in `main.zig` with a parallelized version that returns the same `ParseSummary` structure, keeping all downstream code unchanged.

### Pattern 1: Thread Pool with WaitGroup

**What:** Initialize pool once, spawn one work item per file, wait for all to complete.
**When to use:** Fixed batch of N work items with no inter-item dependencies.

```zig
// Source: Zig stdlib github.com/ziglang/zig/blob/master/lib/std/Thread/Pool.zig
var pool: std.Thread.Pool = undefined;
try pool.init(.{
    .allocator = allocator,
    .n_jobs = thread_count,  // null = auto-detect CPU count
});
defer pool.deinit();

var wg: std.Thread.WaitGroup = .{};

for (file_paths) |path| {
    pool.spawnWg(&wg, analyzeFileWorker, .{ ctx, path });
}

wg.wait();
```

Key: `n_jobs = null` makes the pool auto-use CPU count (matches `--threads` default behavior). For `--threads 1`, skip the pool entirely and call `analyzeFileSerial()` directly.

### Pattern 2: Per-Work-Item Arena Allocator

**What:** Each worker function receives its own arena allocator, allocates freely, appends to shared list, then frees its arena.
**When to use:** Work items have bounded memory usage and results need to be appended to a shared container.

```zig
fn analyzeFileWorker(ctx: *WorkerContext, path: []const u8) void {
    // Each worker has its own arena — no lock needed for allocation
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const result = analyzeFile(alloc, path) catch |err| {
        ctx.mutex.lock();
        defer ctx.mutex.unlock();
        ctx.errors.append(alloc, FileError{ .path = path, .err = err }) catch {};
        return;
    };

    // Lock only for the append — result is already computed
    ctx.mutex.lock();
    defer ctx.mutex.unlock();
    ctx.results.append(ctx.main_allocator, result) catch {};
}
```

**Critical:** Results appended to `ctx.results` must be allocated from `ctx.main_allocator` (the arena passed from main), not from the per-worker arena which is freed at function return. The worker constructs the result locally and then either copies or moves it into main-allocator-owned memory before appending.

### Pattern 3: `--threads 1` Fast Path

**What:** When thread count is 1, skip pool entirely and call the existing sequential logic.
**When to use:** Debugging, deterministic profiling, or systems where threading has high overhead.

```zig
if (effective_thread_count == 1) {
    // Existing single-threaded path — zero changes needed
    var parse_summary = try parse.parseFiles(allocator, file_paths);
    // ... continue as today
} else {
    // Parallel path
    var results = try parallel.analyzeFilesParallel(allocator, file_paths, effective_thread_count);
    // ... continue with sorted results
}
```

### Pattern 4: Deterministic Output via Sort

**What:** After all workers complete, sort results slice by file path before output.
**When to use:** Always — required per locked decision.

```zig
// Sort results by path after wg.wait()
std.mem.sort(FileAnalysisResult, results.items, {}, struct {
    fn lessThan(_: void, a: FileAnalysisResult, b: FileAnalysisResult) bool {
        return std.mem.lessThan(u8, a.path, b.path);
    }
}.lessThan);
```

### Pattern 5: Timing for `--verbose` and JSON metadata

**What:** Capture wall-clock start time before pool dispatch, compute elapsed after `wg.wait()`.

```zig
const start_time = std.time.nanoTimestamp();
// ... dispatch all work items and wg.wait() ...
const elapsed_ns = std.time.nanoTimestamp() - start_time;
const elapsed_ms = @divTrunc(elapsed_ns, 1_000_000);

if (verbose) {
    try stdout.print("Analyzed {d} files in {d}ms\n", .{ file_count, elapsed_ms });
}

// For JSON metadata section:
// elapsed_ms: elapsed_ms
// thread_count: effective_thread_count
```

### Anti-Patterns to Avoid

- **Sharing a TSParser across threads:** TSParser is NOT thread-safe. Each worker must create its own `tree_sitter.Parser.init()` and `defer parser.deinit()`. Confirmed by tree-sitter official docs: only TSTree instances support safe multi-threaded access via `ts_tree_copy()`, but parsers do not.
- **Sharing TSTree across threads:** TSTree instances are also not thread-safe (docs: "Individual TSTree instances are not thread safe"). In this architecture, each worker owns its tree and never passes it to another thread — trees live only within the worker function scope.
- **Using the arena from main as the worker allocator:** The main arena stays alive for the full CLI lifecycle. Worker arenas must be separate so they can be freed individually. Pass the main allocator (from the outer arena) for result storage, not for intermediate computation.
- **Locking the mutex for the entire compute phase:** Lock ONLY during append. Compute the result without holding the lock, then lock only to write to the shared list. This is the critical pattern for parallel speedup.
- **Forgetting to handle the single-threaded case:** `--threads 1` must bypass the pool entirely. Pool overhead (thread management, synchronization) is measurable and would hurt single-file or small-project performance.
- **Not sorting results:** Without sorting, output order is non-deterministic. Always sort by path after `wg.wait()` before passing to output formatters.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread pool with work queue | Custom queue + semaphore + goroutine equivalent | `std.Thread.Pool` | Zig stdlib Pool uses work-stealing for efficiency; handles thread lifecycle, CPU count detection |
| CPU core detection | Parse /proc/cpuinfo or syscall | `std.Thread.getCpuCount()` | Cross-platform (Linux, macOS, Windows), handles errors gracefully |
| Thread-safe allocator | Custom mutex-wrapped allocator | `std.heap.ThreadSafeAllocator` or per-worker arenas | Per-worker arenas are simpler and faster — no shared allocator needed |
| Barrier/join mechanism | Condition variable + counter | `std.Thread.WaitGroup` with `pool.spawnWg()` | Exact primitive for N jobs to complete before continuing |

**Key insight:** The Zig standard library provides all required threading primitives. Adding any third-party threading library would be wrong — there are none needed and `std.Thread.Pool` was specifically designed for workloads exactly like this one.

## Common Pitfalls

### Pitfall 1: TSParser Not Thread-Safe

**What goes wrong:** Sharing a single `TSParser` across worker threads causes data corruption, crashes, or incorrect parse trees. The parser maintains internal mutable state.
**Why it happens:** The tree-sitter C API documentation confirms TSTree copies are cheap but does NOT guarantee parser thread safety. TSParser is a stateful object.
**How to avoid:** Each worker function must call `tree_sitter.Parser.init()` at the start and `defer parser.deinit()` immediately after. This is the only correct pattern.
**Warning signs:** Intermittent crash or incorrect AST results that disappear under `--threads 1`.

### Pitfall 2: Memory Lifetime Mismatch Between Worker and Main Arenas

**What goes wrong:** Worker appends a slice to the shared results list that was allocated from its own arena. After the worker returns, the arena is freed, leaving dangling pointers in the results list.
**Why it happens:** Zig arenas free all allocations when `deinit()` is called. If results point into a freed arena, subsequent reads are undefined behavior.
**How to avoid:** Compute results in the worker arena, then `allocPrint`/`dupe` the path and any owned slices into the main allocator before appending to the shared list. OR pre-allocate the results slice in the main arena before dispatching workers, and let each worker write to a pre-assigned index (atomic counter or mutex-protected index assignment).
**Warning signs:** `std.testing.allocator` leak detection will not catch this — only valgrind or address sanitizer will. The bug may be silent with the arena allocator used in production.

### Pitfall 3: Contention from Over-Locking

**What goes wrong:** Holding the mutex during the entire per-file analysis (parse + all metrics) serializes all workers — no parallelism achieved.
**Why it happens:** Simple implementation puts the lock at the top of the worker function.
**How to avoid:** Lock only for the append at the very end of the worker. All parsing and metric computation happens outside the lock.
**Warning signs:** Performance with N threads is the same as with 1 thread.

### Pitfall 4: Thread Safety of `std.ArrayList.append` with Shared Allocator

**What goes wrong:** Two workers call `ArrayList.append(allocator, ...)` concurrently on the same list without a mutex, corrupting the list's internal state.
**Why it happens:** ArrayList is not thread-safe. `append` may trigger a realloc, which races with another thread reading or writing the list.
**How to avoid:** All writes to any shared ArrayList (results list, errors list) must be within a `mutex.lock()`/`defer mutex.unlock()` critical section. Alternatively, pre-allocate with a known capacity and use atomic index assignment for writes.
**Warning signs:** Crash in `std.mem.Allocator.resize` or corrupted results.

### Pitfall 5: Missing `elapsed_ms`/`thread_count` in JSON Output

**What goes wrong:** JSON output doesn't include the metadata fields required by the locked decision.
**Why it happens:** The JSON schema needs to be updated to carry timing and thread count, but this is often forgotten as an afterthought.
**How to avoid:** Plan the JSON metadata section update as part of the parallel pipeline implementation, not after. The fields are: `elapsed_ms: u64`, `thread_count: u32` in the existing `metadata` section of JSON output.
**Warning signs:** JSON consumers (CI scripts) break when they expect these fields.

### Pitfall 6: Cross-Compilation Binary Size Regression

**What goes wrong:** Adding thread pool support increases binary size beyond 5 MB (DIST-01).
**Why it happens:** `std.Thread.Pool` pulls in additional stdlib code. On some targets, stack management for threads adds to the binary.
**How to avoid:** Measure binary size after implementation with `-Doptimize=ReleaseSafe`. If over 5 MB, add `-fstrip` to the release builds (already used in CI). `ReleaseSmall` can also be used but trades safety checks for size.
**Warning signs:** Check `ls -lh zig-out/bin/complexity-guard` after cross-compile.

### Pitfall 7: Windows Threading Differences

**What goes wrong:** `std.Thread.Pool` may behave differently on Windows targets (e.g., different stack sizes, different CPU count reporting).
**Why it happens:** Windows uses a different threading model internally; `std.Thread.getCpuCount()` returns logical processors which may differ from expected.
**How to avoid:** Test cross-compiled Windows binary via CI. The existing CI workflow already tests Windows cross-compilation — add a thread pool smoke test.
**Warning signs:** Windows CI job fails on thread-related code that works on Linux.

## Code Examples

Verified patterns from official sources:

### Thread Pool Init and WaitGroup (Zig 0.15)

```zig
// Source: github.com/ziglang/zig/blob/master/lib/std/Thread/Pool.zig
// Confirmed API for Zig 0.15.2 (mtsoukalos.eu/2026/01/thread-pool-in-zig)

var pool: std.Thread.Pool = undefined;
try pool.init(.{
    .allocator = allocator,
    .n_jobs = null,  // null = auto-detect CPU count via std.Thread.getCpuCount()
});
defer pool.deinit();

var wg: std.Thread.WaitGroup = .{};

for (file_paths) |path| {
    pool.spawnWg(&wg, workerFn, .{ ctx, path });
}

wg.wait();
```

### Safe Per-Worker Parser Pattern (tree-sitter)

```zig
// Each worker creates its own parser — TSParser is NOT thread-safe
fn analyzeFileWorker(ctx: *WorkerContext, path: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const worker_alloc = arena.allocator();

    // Create parser per-thread
    const parser = tree_sitter.Parser.init() catch return;
    defer parser.deinit();

    const result = parseAndAnalyze(worker_alloc, parser, path) catch |err| {
        recordError(ctx, path, err);
        return;
    };

    // Copy path and owned data to main allocator before appending
    const result_owned = copyResultToMainAlloc(ctx.allocator, result) catch return;

    ctx.mutex.lock();
    defer ctx.mutex.unlock();
    ctx.results.append(ctx.allocator, result_owned) catch {};
}
```

### CPU Count for `--threads` Auto Mode

```zig
// Source: cookbook.ziglang.cc/08-01-cpu-count (Zig stdlib std.Thread)
const cpu_count = std.Thread.getCpuCount() catch 1;
const effective_threads: usize = if (cfg.analysis.?.threads) |n| n else cpu_count;
```

### Determining Cross-Compile Targets in build.zig

```zig
// Current release.yml already does this via CLI:
//   zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSafe
// No build.zig changes needed for cross-compilation itself.
// Cross-compilation is invoked via -Dtarget flag, handled by standardTargetOptions.
```

### Timing Capture

```zig
const start_ns = std.time.nanoTimestamp();
// ... parallel work ...
wg.wait();
const elapsed_ms: u64 = @intCast(@divTrunc(std.time.nanoTimestamp() - start_ns, 1_000_000));
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sequential per-file analysis | Parallel file dispatch via thread pool | Phase 12 | Linear speedup with core count for parse-heavy workload |
| Unordered output (hypothetical) | Sort by path after parallel collection | Phase 12 | Deterministic output regardless of scheduling |

**Current state (pre-Phase 12):**
- `--threads` flag is parsed and stored in `cfg.analysis.threads` but has NO effect (unused)
- The entire pipeline runs sequentially in `main.zig`'s `for (parse_summary.results)` loop
- Performance: VS Code (5071 files) = 19.8s; webpack (6889 files) = 1.76s; target: 10K files < 2s

## Open Questions

1. **Memory strategy for worker-to-main result transfer**
   - What we know: Worker arenas must not own data that outlives the worker. Results need to live in the main arena.
   - What's unclear: Whether `copyResultToMainAlloc` is necessary or if pre-allocating output slice + atomic index is cleaner.
   - Recommendation: For simplicity in this phase, copy paths and metric slices to main allocator inside the mutex. If allocation inside the lock proves a bottleneck (unlikely), switch to pre-allocated atomic index approach.

2. **Error collection from failed workers**
   - What we know: CONTEXT.md marks error handling strategy as Claude's discretion.
   - What's unclear: Whether to use continue-on-error or fail-fast.
   - Recommendation: Use continue-on-error (consistent with existing `parseFiles()` behavior which collects errors and continues). Workers that fail a file add to a mutex-protected errors list; results for that file are simply omitted from output. Failed parse count is preserved in the summary.

3. **Whether to update `benchmarks/src/benchmark.zig` for parallel measurement**
   - What we know: The benchmark currently profiles each subsystem sequentially. Parallelization changes the meaning of subsystem timings.
   - Recommendation: Keep existing subsystem profiler as-is (it measures serial baseline). Add a separate `--parallel N` mode to `complexity-bench` if needed, or rely on hyperfine for end-to-end parallel measurement.

4. **Binary size impact of thread pool on all 5 targets**
   - What we know: `std.Thread.Pool` is part of stdlib, adds minimal code. DIST-01 requires < 5 MB.
   - Recommendation: Verify after implementation. Current binaries are well under 5 MB (tree-sitter is the largest contributor). Thread pool adds negligible size.

## Sources

### Primary (HIGH confidence)

- `github.com/ziglang/zig/blob/master/lib/std/Thread/Pool.zig` — exact `Options` struct, `init`, `spawn`, `spawnWg`, `deinit` signatures verified
- `github.com/ziglang/zig/blob/master/lib/std/Thread/WaitGroup.zig` — WaitGroup API confirmed
- `tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html` — TSTree not thread safe, ts_tree_copy for multi-thread, no parser safety guarantee
- `/home/ben/code/complexity-guard/.github/workflows/release.yml` — confirms existing 5-target cross-compile CI already complete
- `/home/ben/code/complexity-guard/src/cli/args.zig` — `threads: ?[]const u8` field already exists
- `/home/ben/code/complexity-guard/src/cli/config.zig` — `threads: ?u32` in `AnalysisConfig` already exists, validated (rejects 0)
- `/home/ben/code/complexity-guard/src/cli/merge.zig` — `--threads` already parsed into `cfg.analysis.threads`
- `/home/ben/code/complexity-guard/benchmarks/results/baseline-2026-02-21/` — actual performance numbers from profiling

### Secondary (MEDIUM confidence)

- `mtsoukalos.eu/2026/01/thread-pool-in-zig/` — Zig 0.15.2 Thread.Pool usage example confirming API
- `bradcypert.com/multithreading-zig/` — spawnWg/WaitGroup pattern, Zig 0.14 but API compatible with 0.15
- `cookbook.ziglang.cc/08-01-cpu-count/` — `std.Thread.getCpuCount()` usage

### Tertiary (LOW confidence)

- WebSearch results about ThreadSafeAllocator and per-thread arena patterns — consistent across multiple sources but not verified against Zig 0.15 stdlib source directly

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Zig stdlib APIs verified from source; no external libraries
- Architecture: HIGH — existing code structure clearly shows where thread pool wires in; `--threads` scaffold already in place
- Tree-sitter thread safety: HIGH — verified from official docs (TSTree not safe, no parser guarantee)
- Cross-compilation (DIST-01/DIST-02): HIGH — CI workflow already implements this completely
- Pitfalls: MEDIUM — threading pitfalls based on Zig stdlib semantics and tree-sitter docs; actual numbers need post-implementation measurement

**Research date:** 2026-02-21
**Valid until:** 2026-04-21 (Zig 0.15.2 is locked; stable for 60 days)
