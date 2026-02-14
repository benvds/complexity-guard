# Architecture Research

**Domain:** Static Code Analysis Tools (Complexity Metrics)
**Researched:** 2026-02-14
**Confidence:** MEDIUM

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                          CLI Layer                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Arg Parser   │→ │ Config Loader│→ │ File Scanner │                 │
│  └──────────────┘  └──────────────┘  └──────┬───────┘                 │
├──────────────────────────────────────────────┼──────────────────────────┤
│                    Orchestration Layer       │                         │
│  ┌──────────────────────────────────────────┼──────────────────────┐   │
│  │              Thread Pool Coordinator      │                      │   │
│  │  ┌─────────────────────────────────────┐ │                      │   │
│  │  │ Work Queue (file paths)             │ │                      │   │
│  │  └─────────────────────────────────────┘ │                      │   │
│  │                  │  │  │  │              │                      │   │
│  └──────────────────┼──┼──┼──┼──────────────┘                      │   │
├────────────────────┼──┼──┼──┼───────────────────────────────────────┤
│  Analysis Pipeline  │  │  │  │  (per-file, parallel)                │
│  ┌─────────────────▼──▼──▼──▼──────────────────────────────────┐   │
│  │                    Per-File Analysis                         │   │
│  │  ┌──────────┐   ┌────────────┐   ┌─────────────────────┐    │   │
│  │  │ Parser   │ → │ AST Walker │ → │ Metric Collectors   │    │   │
│  │  │(tree-    │   │ (Visitor)  │   │ (5 families)        │    │   │
│  │  │ sitter)  │   └────────────┘   └──────────┬──────────┘    │   │
│  │  └──────────┘                               │               │   │
│  │                                              ▼               │   │
│  │                                    ┌─────────────────┐      │   │
│  │                                    │ File Results    │      │   │
│  │                                    └────────┬────────┘      │   │
│  └─────────────────────────────────────────────┼──────────────┘   │
├────────────────────────────────────────────────┼──────────────────┤
│            Cross-File Analysis Layer           ▼                 │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Duplication Detector (Rabin-Karp)                       │    │
│  │  - Tokenize all files                                    │    │
│  │  - Build hash index across file results                  │    │
│  │  - Match & verify clones                                 │    │
│  └───────────────────────────────────┬──────────────────────┘    │
├────────────────────────────────────────┼─────────────────────────┤
│            Aggregation Layer           ▼                         │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Composite Score Calculator                              │    │
│  │  - Normalize metrics                                     │    │
│  │  - Apply weights                                         │    │
│  │  - Calculate health scores (file + project)              │    │
│  └───────────────────────────────────┬──────────────────────┘    │
├────────────────────────────────────────┼─────────────────────────┤
│              Output Layer              ▼                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Console  │ │  JSON    │ │  SARIF   │ │  HTML    │            │
│  │ Formatter│ │Formatter │ │Formatter │ │Generator │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **CLI Layer** | Parse arguments, load config, discover files | Zig `std.process.args`, JSON parser for config, glob matching for file discovery |
| **File Scanner** | Recursively find matching files, apply include/exclude patterns | Directory walking with pattern matching |
| **Thread Pool Coordinator** | Distribute file analysis across worker threads | Zig `std.Thread.Pool`, work queue of file paths |
| **Parser (tree-sitter)** | Convert source text to concrete syntax tree | C FFI to tree-sitter library, one parser instance per thread |
| **AST Walker** | Traverse syntax tree nodes | Visitor pattern with callbacks for node types |
| **Metric Collectors** | Compute individual metrics during AST walk | Independent collectors (cyclomatic, cognitive, Halstead, structural) run in single pass |
| **Duplication Detector** | Find code clones across files | Rabin-Karp rolling hash on token sequences, runs after per-file analysis |
| **Composite Score Calculator** | Combine weighted metrics into health score | Normalization + weighted sum formula |
| **Output Formatters** | Serialize results to different formats | Template-based for HTML, structured serialization for JSON/SARIF |

## Recommended Project Structure

Based on Zig conventions and the PRD specification:

```
complexityguard/
├── build.zig                     # Zig build script (dependencies, targets, tests)
├── build.zig.zon                 # Package manifest (if using external Zig packages)
├── src/
│   ├── main.zig                  # Entry point, CLI orchestration
│   ├── config.zig                # Config file parsing and validation
│   │                             #   - ConfigLoader struct
│   │                             #   - Default values
│   │                             #   - JSON deserialization
│   ├── scanner.zig               # File discovery and filtering
│   │                             #   - FileScanner struct
│   │                             #   - Glob pattern matching
│   │                             #   - Include/exclude logic
│   ├── parser.zig                # tree-sitter C FFI integration
│   │                             #   - Parser struct (wraps TSParser*)
│   │                             #   - Language initialization
│   │                             #   - Error-tolerant parsing
│   ├── ast/
│   │   ├── walker.zig            # Generic AST traversal
│   │   │                         #   - ASTVisitor trait/interface
│   │   │                         #   - Depth-first traversal
│   │   │                         #   - Node type dispatch
│   │   └── types.zig             # AST node type mappings
│   │                             #   - tree-sitter node → domain types
│   ├── metrics/
│   │   ├── collector.zig         # Base collector interface
│   │   │                         #   - MetricCollector trait
│   │   │                         #   - Result aggregation
│   │   ├── cyclomatic.zig        # McCabe cyclomatic complexity
│   │   │                         #   - CyclomaticCollector
│   │   │                         #   - Branch point detection
│   │   ├── cognitive.zig         # SonarSource cognitive complexity
│   │   │                         #   - CognitiveCollector
│   │   │                         #   - Nesting tracker
│   │   │                         #   - Boolean operator sequences
│   │   ├── halstead.zig          # Halstead metrics
│   │   │                         #   - HalsteadCollector
│   │   │                         #   - Operator/operand classification
│   │   │                         #   - Volume/difficulty/effort calculations
│   │   ├── structural.zig        # Structural metrics
│   │   │                         #   - StructuralCollector
│   │   │                         #   - Function length, params, nesting depth
│   │   ├── duplication.zig       # Rabin-Karp duplication detection
│   │   │                         #   - DuplicationDetector
│   │   │                         #   - Token hasher
│   │   │                         #   - Clone group matching
│   │   └── composite.zig         # Weighted health score
│   │                             #   - CompositeCalculator
│   │                             #   - Normalization functions
│   │                             #   - Weight application
│   ├── results/
│   │   ├── types.zig             # Result data structures
│   │   │                         #   - FunctionResult
│   │   │                         #   - FileResult
│   │   │                         #   - ProjectResult
│   │   └── aggregator.zig        # Aggregate file results to project level
│   ├── output/
│   │   ├── console.zig           # Terminal formatter
│   │   │                         #   - Color support detection
│   │   │                         #   - Table rendering
│   │   ├── json.zig              # JSON output
│   │   │                         #   - JSON serialization
│   │   ├── sarif.zig             # SARIF 2.1.0 output
│   │   │                         #   - SARIF schema compliance
│   │   │                         #   - Rule/result mapping
│   │   └── html.zig              # HTML report generator
│   │                             #   - Embedded CSS/JS
│   │                             #   - Self-contained output
│   └── thread_pool.zig           # Thread pool coordinator
│                                 #   - WorkQueue
│                                 #   - Result collection
├── grammars/                     # tree-sitter grammar source
│   ├── tree-sitter-typescript/   # Submodule or vendored C source
│   ├── tree-sitter-tsx/
│   ├── tree-sitter-javascript/
│   └── tree-sitter-jsx/
├── tests/
│   ├── fixtures/                 # Test TypeScript/JavaScript files
│   │   ├── cyclomatic/
│   │   ├── cognitive/
│   │   ├── halstead/
│   │   └── duplication/
│   ├── unit/
│   │   ├── config_test.zig
│   │   ├── cyclomatic_test.zig
│   │   ├── cognitive_test.zig
│   │   └── ...
│   └── integration/
│       └── e2e_test.zig          # Full pipeline tests
└── README.md
```

### Structure Rationale

- **Flat `src/` for core modules:** Zig convention — `config.zig`, `scanner.zig`, `parser.zig` at top level. These are single-responsibility modules.

- **`metrics/` subdirectory:** Groups related metric collectors. Each is independent but shares a common `MetricCollector` interface defined in `collector.zig`.

- **`ast/` subdirectory:** Separates generic AST traversal (`walker.zig`) from metric-specific logic. `types.zig` maps tree-sitter node types to domain enums.

- **`results/` subdirectory:** Centralizes result data structures. Keeps domain models separate from metric calculation logic.

- **`output/` subdirectory:** One file per output format. Each is self-contained and takes a `ProjectResult` as input.

- **`grammars/` outside `src/`:** C code for tree-sitter grammars. These compile to object files linked during build. Not Zig source.

- **`tests/fixtures/` separate from `tests/unit/`:** Fixtures are data, tests are code. Makes it clear what's a test input vs. test logic.

## Architectural Patterns

### Pattern 1: Single-Pass Multi-Collector

**What:** Run multiple metric collectors simultaneously during a single AST walk.

**When to use:** When metrics are independent and can compute from the same traversal. Cyclomatic, cognitive, Halstead, and structural metrics all analyze the same AST without needing separate passes.

**Trade-offs:**
- **Pro:** Dramatically faster than multiple passes (4x speedup from avoiding re-parsing and re-walking).
- **Pro:** Simplifies code — one walker, multiple observers.
- **Con:** Collectors must be stateless or manage their own state (can't assume exclusive AST access).
- **Con:** Memory footprint is sum of all collectors' state.

**Example:**
```zig
// ast/walker.zig
pub const ASTWalker = struct {
    collectors: []MetricCollector,

    pub fn walk(self: *ASTWalker, node: TSNode) !void {
        // Pre-order: notify all collectors before children
        for (self.collectors) |*collector| {
            try collector.visitNode(node);
        }

        // Recurse to children
        var i: u32 = 0;
        while (i < ts_node_child_count(node)) : (i += 1) {
            try self.walk(ts_node_child(node, i));
        }

        // Post-order: notify collectors after children
        for (self.collectors) |*collector| {
            try collector.exitNode(node);
        }
    }
};

// metrics/collector.zig
pub const MetricCollector = struct {
    visitNode: *const fn(*MetricCollector, TSNode) anyerror!void,
    exitNode: *const fn(*MetricCollector, TSNode) anyerror!void,
    // ... implementation-specific fields
};
```

### Pattern 2: Two-Phase Analysis (Per-File → Cross-File)

**What:** Separate independent file analysis from cross-file analysis that requires all files' results.

**When to use:** Always for duplication detection. Rabin-Karp hashing needs to compare token sequences across files, which can't happen until all files are parsed.

**Trade-offs:**
- **Pro:** Per-file analysis parallelizes perfectly (embarrassingly parallel workload).
- **Pro:** Cross-file phase can use aggregated data structures (global hash index).
- **Con:** Requires materializing all per-file results in memory before cross-file phase.
- **Con:** Two distinct pipeline stages complicate error handling.

**Data flow:**
```
Phase 1 (parallel):
  File 1 → Parse → Collect metrics → FileResult₁
  File 2 → Parse → Collect metrics → FileResult₂
  ...
  File N → Parse → Collect metrics → FileResultₙ
           ↓
       [All FileResults in memory]
           ↓
Phase 2 (sequential or parallel over hash buckets):
  Duplication Detector:
    - Tokenize all FileResults
    - Build hash index (hash → [file locations])
    - Match hash collisions → CloneGroups
           ↓
       ProjectResult (includes duplication data)
```

**Implementation note:** FileResult must include enough information for duplication detection (token sequence or re-parseable source). Trade-off: store tokens (memory) vs. re-parse (CPU). For 10K files, storing tokens is acceptable.

### Pattern 3: Thread-Pool Work Queue

**What:** Distribute file analysis across worker threads using a shared work queue.

**When to use:** Always for parallel file processing. Standard pattern for CPU-bound embarrassingly parallel tasks.

**Trade-offs:**
- **Pro:** Scales to CPU core count automatically.
- **Pro:** Handles variable file sizes well (dynamic load balancing).
- **Con:** Requires thread-safe result collection.
- **Con:** Parser instances can't be shared across threads (tree-sitter parsers are not thread-safe).

**Example:**
```zig
// thread_pool.zig
pub fn analyzeFiles(allocator: Allocator, files: [][]const u8, config: Config) !ProjectResult {
    var pool = try std.Thread.Pool.init(.{
        .allocator = allocator,
        .n_jobs = config.threadCount,
    });
    defer pool.deinit();

    var results = std.ArrayList(FileResult).init(allocator);
    defer results.deinit();

    var mutex = std.Thread.Mutex{};

    for (files) |file_path| {
        try pool.spawn(analyzeFile, .{
            file_path,
            config,
            &results,
            &mutex,
        });
    }

    pool.waitAndWork(); // Block until all work completes

    // Phase 2: Cross-file duplication detection
    const duplication = try detectDuplication(allocator, results.items);

    return ProjectResult{
        .files = results.toOwnedSlice(),
        .duplication = duplication,
    };
}

fn analyzeFile(
    file_path: []const u8,
    config: Config,
    results: *std.ArrayList(FileResult),
    mutex: *std.Thread.Mutex,
) void {
    // Each thread gets its own parser instance
    var parser = Parser.init() catch return;
    defer parser.deinit();

    const result = parser.analyze(file_path, config) catch return;

    mutex.lock();
    defer mutex.unlock();
    results.append(result) catch return;
}
```

**Critical detail:** Each worker thread must have its own tree-sitter parser instance. Parsers are not thread-safe and cannot be shared.

### Pattern 4: Visitor Pattern for AST Traversal

**What:** Use a visitor interface that metric collectors implement. The walker dispatches to visitors based on node type.

**When to use:** When you have multiple different operations on the same tree structure (exactly this use case — different metrics on the same AST).

**Trade-offs:**
- **Pro:** Separates traversal logic from metric logic.
- **Pro:** Easy to add new metrics (just implement the visitor interface).
- **Pro:** Collectors can maintain their own state during traversal.
- **Con:** Slightly more complex than direct tree walking in metric code.
- **Con:** Dynamic dispatch overhead (negligible for this workload).

**Example:**
```zig
// metrics/cognitive.zig
pub const CognitiveCollector = struct {
    nesting_level: u32 = 0,
    score: u32 = 0,

    pub fn visitNode(self: *CognitiveCollector, node: TSNode) !void {
        const node_type = ts_node_type(node);

        if (isNestingIncrement(node_type)) {
            self.nesting_level += 1;
        }

        if (isComplexityIncrement(node_type)) {
            self.score += 1 + self.nesting_level;
        }
    }

    pub fn exitNode(self: *CognitiveCollector, node: TSNode) !void {
        const node_type = ts_node_type(node);

        if (isNestingIncrement(node_type)) {
            self.nesting_level -= 1;
        }
    }
};
```

### Pattern 5: Rabin-Karp Rolling Hash for Duplication

**What:** Use a rolling hash function to efficiently detect duplicate token sequences of variable length.

**When to use:** Always for duplication detection. Standard algorithm for substring matching.

**Trade-offs:**
- **Pro:** O(n) time complexity for hashing all windows in a file.
- **Pro:** Can detect Type 1 (exact) and Type 2 (renamed identifiers) clones with token normalization.
- **Con:** Hash collisions require verification step (compare actual tokens).
- **Con:** Requires tuning hash function and modulus to minimize collisions.

**Algorithm:**
```
1. Tokenize file (strip whitespace, comments)
2. Normalize tokens for Type 2 clones:
   - Replace identifiers with placeholder "ID"
   - Replace literals with placeholder "LIT"
3. Slide window of size W (e.g., 25 tokens) across token sequence
4. For each window:
   - Compute hash H = (t₀·B⁰ + t₁·B¹ + ... + tᵥ₋₁·Bᵂ⁻¹) mod M
   - Store (H → file location) in global hash table
5. After all files hashed, check for hash collisions:
   - If H appears >1 time, verify token sequences match
   - Merge overlapping matches into maximal clone groups
```

**Implementation detail:** Use a large prime for modulus M (e.g., 2³¹-1) and prime base B (e.g., 31) to minimize collisions. Pre-compute B^W for rolling updates.

## Data Flow

### Request Flow (CLI Invocation)

```
User runs: complexityguard src/ --format json --fail-on error

main.zig
    ↓
1. Parse CLI args (std.process.args)
    ↓
2. Load config (.complexityguard.json + CLI overrides)
    ↓
3. Scan files (src/ → apply include/exclude patterns)
    ↓
   [List of file paths]
    ↓
4. Initialize thread pool (n_jobs = CPU count or --threads value)
    ↓
5. Spawn workers: for each file, enqueue analyzeFile task
    ↓
    ┌─────────────────────────────────────────────────────┐
    │         Worker Thread (per file)                    │
    │                                                     │
    │  a. Initialize parser (tree-sitter)                │
    │  b. Parse source text → CST                        │
    │  c. Walk CST with multi-collector visitor          │
    │     - CyclomaticCollector                          │
    │     - CognitiveCollector                           │
    │     - HalsteadCollector                            │
    │     - StructuralCollector                          │
    │  d. Produce FileResult                             │
    │  e. Append to shared results (mutex-protected)     │
    └─────────────────────────────────────────────────────┘
    ↓
6. Wait for all workers to complete
    ↓
   [All FileResults collected]
    ↓
7. Run duplication detector (Phase 2)
   - Tokenize all files
   - Build Rabin-Karp hash index
   - Find clone groups
    ↓
8. Aggregate results → ProjectResult
   - Calculate composite scores per file
   - Calculate project-level composite score
    ↓
9. Format output (JSON in this example)
    ↓
10. Write to stdout or file
    ↓
11. Determine exit code (0 if no errors, 1 if errors found)
    ↓
   Exit
```

### State Management

No global mutable state. All state flows through function parameters:

```
main()
  config: Config (immutable after load)
  files: []const u8 (immutable list of paths)
    ↓
analyzeFiles(config, files) → ProjectResult
  results: ArrayList(FileResult) (append-only, mutex-protected)
    ↓
analyzeFile(file_path, config) → FileResult
  parser: Parser (thread-local)
  collectors: [..]MetricCollector (thread-local)
    ↓
walker.walk(node, collectors)
  (traversal state on call stack)
```

**Why this works:**
- Config is read-only after parsing (safe to share across threads)
- Each thread has its own parser and collectors (no sharing)
- Results are collected via mutex (thread-safe append)
- Duplication detection runs after all threads complete (no concurrency)

### Key Data Structures

```zig
// results/types.zig

pub const MetricValue = struct {
    value: f64,
    threshold: enum { ok, warning, error },
};

pub const FunctionResult = struct {
    name: []const u8,
    start_line: u32,
    end_line: u32,
    cyclomatic: MetricValue,
    cognitive: MetricValue,
    halstead_volume: MetricValue,
    halstead_difficulty: MetricValue,
    halstead_effort: MetricValue,
    halstead_bugs: MetricValue,
    length: MetricValue,        // lines
    param_count: MetricValue,
    nesting_depth: MetricValue,
};

pub const FileResult = struct {
    path: []const u8,
    functions: []FunctionResult,
    file_length: MetricValue,
    export_count: MetricValue,
    health_score: f64,          // 0-100
    tokens: []Token,            // For duplication detection
};

pub const CloneGroup = struct {
    token_count: u32,
    instances: []CloneInstance,
};

pub const CloneInstance = struct {
    file_path: []const u8,
    start_line: u32,
    end_line: u32,
};

pub const ProjectResult = struct {
    files: []FileResult,
    duplication: struct {
        percentage: f64,
        clone_groups: []CloneGroup,
    },
    health_score: f64,
    summary: struct {
        total_files: u32,
        total_functions: u32,
        error_count: u32,
        warning_count: u32,
    },
};
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **0-1000 files** | Single-threaded is fine. Duplication detection memory footprint is negligible. |
| **1000-10,000 files** | Use thread pool with n_jobs = CPU count. Duplication hash index ~10-50 MB. All results fit in memory. |
| **10,000-100,000 files** | Memory becomes a concern. Consider streaming duplication detection (process hash buckets incrementally). May need to write intermediate results to disk. |
| **100,000+ files** | Re-architect for distributed processing. Split files across machines. Aggregate results with a reduce step. Not a v1.0 target. |

### Scaling Priorities

1. **First bottleneck: Per-file parsing (CPU-bound)**
   - **Symptom:** High CPU usage, low file throughput
   - **Fix:** Increase thread count (--threads). Ensure thread count ≤ CPU cores to avoid context switching overhead.
   - **Expected:** ComplexityGuard should saturate all CPU cores when analyzing large codebases.

2. **Second bottleneck: Duplication detection (memory-bound)**
   - **Symptom:** High memory usage during Phase 2, potential OOM on large codebases
   - **Fix:** Stream hash index to disk for very large projects. Or: partition files into buckets, detect duplication within buckets first.
   - **Expected:** For 10K files × 500 LOC avg × 25 tokens/LOC = ~125M tokens. Hash index with 25-token windows = ~125M entries × (8 bytes hash + 16 bytes location) ≈ 3 GB. Manageable but non-trivial.

## Anti-Patterns

### Anti-Pattern 1: Shared Parser Across Threads

**What people do:** Initialize one tree-sitter parser globally and call it from multiple threads.

**Why it's wrong:** tree-sitter parsers maintain internal state and are NOT thread-safe. Concurrent calls lead to memory corruption, segfaults, or wrong results.

**Do this instead:** Each worker thread gets its own parser instance. Initialize in thread-local storage or pass as a parameter.

```zig
// WRONG
var global_parser = Parser.init(); // Don't do this

fn worker(file: []const u8) void {
    global_parser.parse(file); // Race condition!
}

// RIGHT
fn worker(file: []const u8) void {
    var parser = Parser.init(); // Thread-local
    defer parser.deinit();
    parser.parse(file);
}
```

### Anti-Pattern 2: Multiple AST Passes for Independent Metrics

**What people do:** Walk the AST once per metric (5 separate passes for 5 metrics).

**Why it's wrong:** Parses and re-walks the tree 5x unnecessarily. tree-sitter parsing is fast but not free. Re-walking wastes CPU cache.

**Do this instead:** Use the multi-collector pattern (Pattern 1 above). All independent metrics collect in a single pass.

### Anti-Pattern 3: Blocking I/O in Worker Threads

**What people do:** Read file synchronously in worker thread, blocking on disk I/O.

**Why it's wrong:** With many threads, this can cause thread pool starvation. Threads wait on disk instead of doing CPU work.

**Do this instead:** For v1.0, synchronous I/O is acceptable (files are small, modern OSes cache aggressively). For v1.x with watch mode, use async I/O or a separate I/O thread pool.

**When it matters:** Only on slow storage (network filesystems, spinning disks). On SSDs with OS page cache, this is negligible.

### Anti-Pattern 4: Premature Optimization of Hash Function

**What people do:** Spend time optimizing Rabin-Karp hash function before measuring whether it's a bottleneck.

**Why it's wrong:** Duplication detection is Phase 2, which runs AFTER all parsing completes. Parsing is almost certainly the bottleneck (tree-sitter is doing syntax analysis, we're doing simple rolling hash).

**Do this instead:** Use a simple, correct hash function first. Measure with real workloads. Optimize only if profiling shows it's >5% of total time.

### Anti-Pattern 5: Storing Full Source Text in FileResult

**What people do:** Include `source: []const u8` field in FileResult for later re-analysis.

**Why it's wrong:** For 10K files × 10 KB avg source = 100 MB just for source text. We only need tokens for duplication detection, which are much smaller.

**Do this instead:** Store only tokens in FileResult. If source is needed later (e.g., for blame integration in v1.x), re-read from disk on demand.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **tree-sitter (C library)** | C FFI via Zig's `@cImport` or manual extern declarations | Link tree-sitter-typescript.a and tree-sitter-javascript.a into binary. Initialize parsers with language grammars. |
| **File system** | Zig `std.fs` for directory walking, file reading | Use `std.fs.cwd().openIterableDir()` for recursive traversal. Handle symlinks gracefully (skip or follow, configurable). |
| **JSON parsing** | Zig `std.json` for config loading and output serialization | Deserialize `.complexityguard.json` into Config struct. Serialize ProjectResult to JSON. |
| **SARIF schema** | Manual struct definition matching SARIF 2.1.0 spec | Define `SARIFReport`, `SARIFResult`, etc. structs. Serialize to JSON following schema. Validate with official SARIF schema validator in tests. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **main.zig ↔ thread_pool.zig** | Function call with Config + file list → ProjectResult | main orchestrates, thread_pool executes analysis. |
| **thread_pool.zig ↔ parser.zig** | Function call per file: parser.analyze(file, config) → FileResult | Parser encapsulates tree-sitter details. |
| **parser.zig ↔ ast/walker.zig** | Parser creates walker, passes collectors, calls walker.walk() | Walker is generic, doesn't know about tree-sitter. |
| **ast/walker.zig ↔ metrics/**.zig** | Walker calls collector.visitNode() / exitNode() callbacks | Visitor pattern. Metrics are observers. |
| **metrics/duplication.zig ↔ results/** | Takes all FileResults, outputs CloneGroups | Duplication is special — needs cross-file view. |
| **results/aggregator.zig ↔ output/**.zig** | Aggregator produces ProjectResult, output formatters consume it | Clean separation: aggregation logic vs. presentation logic. |

## Build Order Implications

Suggested implementation order based on dependencies:

### Phase 1: Foundation (no metric logic yet)
1. **Config loading** (`config.zig`) — No dependencies. Pure JSON parsing.
2. **File scanner** (`scanner.zig`) — Depends on Config. Filesystem + glob matching.
3. **Parser integration** (`parser.zig`) — tree-sitter C FFI. Can test with dummy "just parse and return node count" logic.

### Phase 2: Single Metric (prove the pipeline)
4. **AST walker** (`ast/walker.zig`) — Depends on Parser. Generic visitor infrastructure.
5. **Cyclomatic metric** (`metrics/cyclomatic.zig`) — Simplest metric. Proves walker works.
6. **Result types** (`results/types.zig`) — Define FunctionResult, FileResult.
7. **Console output** (`output/console.zig`) — Display cyclomatic results. Quick feedback loop.

### Phase 3: Remaining Metrics (parallel work)
8. **Cognitive metric** (`metrics/cognitive.zig`) — More complex than cyclomatic. Nesting tracking.
9. **Halstead metric** (`metrics/halstead.zig`) — Independent of others. Token classification.
10. **Structural metrics** (`metrics/structural.zig`) — Simple. Function length, params, nesting depth.

### Phase 4: Cross-File Analysis
11. **Duplication detector** (`metrics/duplication.zig`) — Depends on FileResult including tokens. Rabin-Karp implementation.

### Phase 5: Aggregation & Scoring
12. **Composite score** (`metrics/composite.zig`) — Depends on all metrics producing results. Normalization + weighting.
13. **Results aggregator** (`results/aggregator.zig`) — Combines per-file into project-level. Calculates summary stats.

### Phase 6: Output Formats
14. **JSON output** (`output/json.zig`) — Straightforward serialization.
15. **SARIF output** (`output/sarif.zig`) — Requires mapping metrics to SARIF schema.
16. **HTML output** (`output/html.zig`) — Most complex. Templating, embedded CSS/JS.

### Phase 7: Parallelization
17. **Thread pool** (`thread_pool.zig`) — Last, because single-threaded version proves correctness first. Parallelization is optimization.

**Rationale:** Build vertically (one metric end-to-end) before horizontally (all metrics). Proves the architecture early. Each phase delivers testable value.

## Sources

**Source confidence: MEDIUM-LOW**

This architecture research is based on:

1. **PRD specification** (provided project context) — HIGH confidence for project-specific details
2. **Common static analysis tool patterns** (ESLint, SonarQube, oxlint, Rome/Biome architectures) — MEDIUM confidence based on training data, not verified with current sources
3. **Zig project structure conventions** — MEDIUM-LOW confidence, could not verify with official Zig documentation due to tool restrictions
4. **tree-sitter integration patterns** — MEDIUM-LOW confidence, could not verify with official tree-sitter documentation due to tool restrictions
5. **Multi-pass analysis pipeline patterns** — MEDIUM confidence, standard pattern in compilers and analyzers
6. **Thread pool patterns in Zig** — MEDIUM-LOW confidence based on Zig stdlib knowledge, not verified with current docs

**Verification gaps:**
- Zig project structure conventions not verified with current official docs
- tree-sitter C API integration patterns not verified with current official docs
- Zig `std.Thread.Pool` API details not verified (may have changed since training data)

**Recommendations:**
- Verify Zig stdlib Thread.Pool API in official docs before implementing Phase 7
- Check tree-sitter C API documentation for parser thread-safety guarantees
- Review existing Zig projects using tree-sitter for integration patterns (e.g., zls, zig-tree-sitter)

---
*Architecture research for: ComplexityGuard*
*Researched: 2026-02-14*
