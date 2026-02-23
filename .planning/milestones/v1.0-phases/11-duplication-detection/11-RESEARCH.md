# Phase 11: Duplication Detection - Research

**Researched:** 2026-02-22
**Domain:** Code clone detection — Rabin-Karp rolling hash, tokenization, cross-file indexing
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Opt-in by default**: Duplication detection is disabled by default. Three equivalent opt-in paths:
  - `--duplication` dedicated CLI flag
  - `--metrics duplication` (consistent with existing `--metrics` flag)
  - Config file: set duplication enabled in `.complexityguard.json`
- **When not enabled**: Analysis is skipped entirely (zero overhead)

- **Console output**: Location pairs only, no code snippets. Format: `Clone group (42 tokens): file_a.ts:15, file_b.ts:88`. Dedicated "Duplication" section after per-file results. No inline duplication info per file.

- **HTML output**: Sortable table of clone groups (locations, token count, line count) plus heatmap overlay showing which files share the most clones.

- **SARIF output**: One SARIF result per clone group (not per instance). Use `relatedLocations` for all instances. GitHub Code Scanning shows them linked.

- **JSON output**: Clone groups array with locations, token count, and duplication percentages. Consistent with existing JSON structure patterns.

- **Threshold defaults**:
  - File-level duplication warning: 15%
  - File-level duplication error: 25%
  - Project-level duplication warning: 5%
  - Project-level duplication error: 10%

- **Performance benchmarking**: Run with/without duplication, measure wall time and peak memory. Test scaling across 100/1k/10k files. Use quick benchmark suite projects. Reproducible script: `benchmarks/scripts/bench-duplication.sh`. Results documented in `docs/performance.md` (or `docs/benchmarks.md`).

### Claude's Discretion

- Normalization depth (what gets normalized beyond identifiers — string literals, numbers, type annotations)
- JSON output structure for clone groups (field names, nesting)
- Heatmap visualization approach in HTML
- Health score integration (how duplication % maps to 0-100 scale using existing 0.20 weight)
- Internal algorithm details (hash function, table sizing, memory management)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DUP-01 | Tool tokenizes source files stripping comments and whitespace | Tree-sitter leaf node traversal: collect only named, non-comment leaf nodes. Walk AST collecting `startByte`/`endByte` from source slice. |
| DUP-02 | Tool normalizes identifiers for Type 2 clone detection | Replace `identifier` node text with a sentinel string (e.g., `"V"` for variables). Optionally normalize string literals and numbers. Numeric/string normalization improves recall at cost of precision. |
| DUP-03 | Tool uses Rabin-Karp rolling hash with configurable minimum window (default 25 tokens) | Pure Zig hash: `hash = hash * B + token_type_enum`. Rolling update: `hash = (hash - removed_token * B^(N-1)) * B + new_token`. `B = 31` (or 37). Window size is token count, not byte count. |
| DUP-04 | Tool builds cross-file hash index and verifies matches token-by-token | `std.AutoHashMap(u64, std.ArrayList(TokenWindow))` keyed on rolling hash. For each hash collision, verify token-by-token from stored positions. |
| DUP-05 | Tool merges overlapping matches into maximal clone groups | Sort match intervals by file+start_token, then merge overlapping intervals (standard merge-intervals algorithm). Group same-hash matches across files into a clone group. |
| DUP-06 | Tool reports clone groups with locations, token counts, and duplication percentages | Per-file: `(tokens_in_clones / total_file_tokens) * 100`. Project: `(total_cloned_tokens / total_project_tokens) * 100`. Avoid double-counting overlapping clones. |
| DUP-07 | Tool applies configurable thresholds for file duplication % and project duplication % | File-level warning: 15%, error: 25%. Project-level warning: 5%, error: 10%. ThresholdPair fields use `f64` (percentage, not u32). |
</phase_requirements>

---

## Summary

Phase 11 implements code clone detection across TypeScript/JavaScript files using a Rabin-Karp rolling hash approach. The algorithm operates in three sequential stages that must happen **after** per-file parallel analysis completes: (1) tokenize all parsed files using their existing TSTree, (2) build a global hash index scanning each file's token sequence with a rolling window, (3) verify hash collisions token-by-token and merge overlapping matches.

The key architectural challenge is that duplication detection is **inherently cross-file** — it requires all files' token sequences to be available simultaneously, unlike per-file metrics that run independently in the parallel pipeline. This means the duplication pass runs as a sequential post-processing step on the `[]FileAnalysisResult` that `analyzeFilesParallel` (or the sequential path) produces. The performance concern from STATE.md ("may conflict with < 1s performance target on 10K files") is real: hash index construction is O(N_total_tokens), which for 10K files of average 200 tokens = 2M hash operations — feasible in < 0.5s in Zig, but memory for storing O(N) `TokenWindow` entries must be bounded.

The implementation needs no new dependencies. All algorithm components — rolling hash, hash map, interval merging — are hand-rolled in pure Zig using `std.AutoHashMap` and `std.ArrayList`. The existing tree-sitter integration provides the AST needed for tokenization. The biggest discretionary choice is what counts as a "token" for normalization (Type 2 clones): using only leaf node types (keywords, operators) as the token identity, while normalizing all `identifier` text to a sentinel, gives good precision/recall balance without being overly aggressive.

**Primary recommendation:** Implement duplication as a new module `src/metrics/duplication.zig` called as a post-parallel-analysis step in `main.zig`. Store token windows by byte offsets (start/end) to enable line-number reporting without re-parsing.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `std.AutoHashMap(u64, ...)` | Zig 0.15.2 stdlib | Hash index mapping rolling hash to token window list | Built-in, no dependency, proven safe |
| `std.ArrayList(TokenWindow)` | Zig 0.15.2 stdlib | Per-hash bucket of candidate clone locations | Already used everywhere in codebase |
| tree-sitter Node API | Already vendored | Walk AST to collect leaf tokens | Already integrated — same pattern as halstead.zig |
| Rolling hash (hand-rolled) | N/A | O(1) per-token hash update | Rabin-Karp is simple to implement correctly in Zig |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Arena allocator | Token sequence storage during analysis | Use for per-file token sequences (freed after index build) |
| `std.mem.sort` | Sort clone intervals for merging | Already used in codebase for result sorting |
| `std.json.Stringify.valueAlloc` | JSON serialization of clone groups | Existing pattern in json_output.zig |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Rolling hash | Suffix arrays | Suffix arrays give O(N log N) build, O(1) query but complex to implement in Zig; rolling hash is simpler and sufficient |
| Per-token normalization | AST-level comparison | AST comparison requires subtree matching (exponential worst case); token normalization is O(N) |
| AutoHashMap | HashMap with open addressing | AutoHashMap uses chaining; acceptable for this use case, collision handling is built-in |

**Installation:** No new dependencies. Pure Zig standard library.

---

## Architecture Patterns

### Recommended Project Structure

```
src/
├── metrics/
│   ├── duplication.zig          # NEW: core duplication analysis module
│   └── ...existing metrics
├── output/
│   ├── console.zig              # UPDATE: add Duplication section after file output
│   ├── json_output.zig          # UPDATE: add clone_groups array to JsonOutput
│   ├── sarif_output.zig         # UPDATE: add DUP rule + relatedLocations results
│   └── html_output.zig          # UPDATE: add clone table + heatmap section
├── cli/
│   ├── args.zig                 # UPDATE: add --duplication flag
│   ├── config.zig               # UPDATE: add duplication thresholds + enabled field
│   └── merge.zig                # UPDATE: merge --duplication flag
└── main.zig                     # UPDATE: call duplication pass after parallel analysis
```

```
benchmarks/scripts/
└── bench-duplication.sh         # NEW: benchmark with/without --duplication
docs/
└── benchmarks.md               # UPDATE: add duplication performance results
```

### Data Structures

```zig
/// A single token extracted from an AST leaf node.
/// The token identity for hashing is token_kind (normalized type string).
/// For identifier nodes, text is replaced with sentinel "V" for Type 2 clones.
pub const Token = struct {
    kind: []const u8,    // Normalized token type or sentinel "V" for identifiers
    start_byte: u32,     // Byte offset in source (for line-number lookup)
    start_line: u32,     // 1-indexed line number (pre-computed from TSNode)
};

/// A window of consecutive tokens identified by a rolling hash.
pub const TokenWindow = struct {
    file_index: u32,     // Index into the file_paths array
    start_token: u32,    // Start token index in the file's token sequence
    end_token: u32,      // Exclusive end token index
    start_line: u32,     // 1-indexed line number of first token
    end_line: u32,       // 1-indexed line number of last token
};

/// A detected clone group: two or more locations with the same normalized token sequence.
pub const CloneGroup = struct {
    token_count: u32,                   // Number of tokens in the clone
    locations: []const CloneLocation,   // All instances of this clone (2+)
};

pub const CloneLocation = struct {
    file_path: []const u8,  // Relative file path
    start_line: u32,        // 1-indexed
    end_line: u32,          // 1-indexed
};

/// Per-file duplication summary.
pub const FileDuplicationResult = struct {
    path: []const u8,
    total_tokens: u32,
    cloned_tokens: u32,          // Non-overlapping count of tokens in clones
    duplication_pct: f64,        // cloned_tokens / total_tokens * 100
    warning: bool,
    @"error": bool,
};

/// Project-wide duplication result.
pub const DuplicationResult = struct {
    clone_groups: []const CloneGroup,
    file_results: []const FileDuplicationResult,
    total_cloned_tokens: u32,
    total_tokens: u32,
    project_duplication_pct: f64,
    project_warning: bool,
    project_error: bool,
};
```

### Pattern 1: AST Leaf Tokenization

Walk the TSTree from the root, collecting only leaf nodes (nodes with zero named children). Skip comment nodes and whitespace-only nodes. For Type 2 normalization, replace identifier text with a sentinel.

```zig
/// Collect normalized tokens from a tree-sitter AST.
/// Strips comments and whitespace; normalizes identifiers.
/// Source: tree-sitter Node.child() + Node.childCount() API pattern (see halstead.zig).
fn tokenizeNode(
    node: tree_sitter.Node,
    source: []const u8,
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
) !void {
    const count = node.childCount();
    if (count == 0) {
        // Leaf node — classify and collect
        const kind = node.nodeType();
        // Skip comment and whitespace nodes
        if (isSkippedKind(kind)) return;
        // Normalize identifier to sentinel for Type 2 detection
        const normalized_kind = if (std.mem.eql(u8, kind, "identifier") or
            std.mem.eql(u8, kind, "property_identifier") or
            std.mem.eql(u8, kind, "type_identifier"))
            "V"
        else
            kind;
        const start_line = node.startPoint().row + 1; // 1-indexed
        try tokens.append(allocator, Token{
            .kind = normalized_kind,
            .start_byte = node.startByte(),
            .start_line = start_line,
        });
        return;
    }
    // Recurse into children
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        if (node.child(i)) |child| {
            try tokenizeNode(child, source, tokens, allocator);
        }
    }
}

/// Node kinds to skip entirely (comments, whitespace, structural punctuation).
fn isSkippedKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "comment") or
        std.mem.eql(u8, kind, "line_comment") or
        std.mem.eql(u8, kind, "block_comment") or
        std.mem.eql(u8, kind, "{") or
        std.mem.eql(u8, kind, "}") or
        std.mem.eql(u8, kind, "(") or
        std.mem.eql(u8, kind, ")") or
        std.mem.eql(u8, kind, ";") or
        std.mem.eql(u8, kind, ",");
    // Note: braces/parens/semicolons are typically skipped for clone detection
    // to focus on semantic content. This is a discretionary choice.
}
```

**Note on type annotations:** Use the existing `isTypeOnlyNode()` from `halstead.zig` to skip TypeScript type annotations during tokenization. This prevents TypeScript-specific type syntax from interfering with clone detection across JS/TS files.

### Pattern 2: Rabin-Karp Rolling Hash

```zig
// Rolling hash constants
// B = 37 (prime, gives good distribution for token type strings)
// Prime modulus implicitly handled by u64 wraparound (acceptable for this use case)
const HASH_BASE: u64 = 37;

/// Compute hash of a token from its kind string.
fn tokenHash(kind: []const u8) u64 {
    var h: u64 = 0;
    for (kind) |c| {
        h = h *% HASH_BASE +% @as(u64, c);
    }
    return h;
}

/// Rolling hash state for a sliding window over token sequence.
const RollingHasher = struct {
    hash: u64,
    base_pow: u64,  // B^(window_size - 1) for removing leftmost token

    fn init(tokens: []const Token, window: u32) RollingHasher {
        var h: u64 = 0;
        var bpow: u64 = 1;
        for (tokens[0..window], 0..) |tok, i| {
            h = h *% HASH_BASE +% tokenHash(tok.kind);
            if (i < window - 1) bpow *%= HASH_BASE;
        }
        return .{ .hash = h, .base_pow = bpow };
    }

    fn roll(self: *RollingHasher, remove: Token, add: Token) void {
        self.hash = (self.hash -% tokenHash(remove.kind) *% self.base_pow) *%
            HASH_BASE +% tokenHash(add.kind);
    }
};
```

**Key insight:** Token hashing is on the normalized `kind` string, not raw source text. This means two tokens with the same kind hash identically regardless of their exact source text — which is what we want for Type 2 clones.

### Pattern 3: Cross-File Hash Index Build

```zig
/// Build global hash index: hash -> list of (file_idx, start_token, end_token, start_line, end_line).
/// Runs sequentially after all files are tokenized.
fn buildHashIndex(
    allocator: std.mem.Allocator,
    all_tokens: []const []const Token,  // one slice per file
    window: u32,
    index: *std.AutoHashMap(u64, std.ArrayList(TokenWindow)),
) !void {
    for (all_tokens, 0..) |file_tokens, file_idx| {
        if (file_tokens.len < window) continue;

        var hasher = RollingHasher.init(file_tokens, window);
        var start: u32 = 0;

        while (start + window <= file_tokens.len) : (start += 1) {
            const end = start + window;
            const gop = try index.getOrPut(hasher.hash);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(TokenWindow).empty;
            }
            try gop.value_ptr.append(allocator, TokenWindow{
                .file_index = @intCast(file_idx),
                .start_token = start,
                .end_token = end,
                .start_line = file_tokens[start].start_line,
                .end_line = file_tokens[end - 1].start_line,
            });
            if (start + window < file_tokens.len) {
                hasher.roll(file_tokens[start], file_tokens[start + window]);
            }
        }
    }
}
```

### Pattern 4: Verification and Clone Group Formation

After hash index build, filter buckets with 2+ entries (potential clones), verify token-by-token (to handle hash collisions), then group into CloneGroups.

```zig
/// Verify two windows have identical token sequences (hash collision check).
fn tokensMatch(
    a_tokens: []const Token, a_start: u32,
    b_tokens: []const Token, b_start: u32,
    window: u32,
) bool {
    var i: u32 = 0;
    while (i < window) : (i += 1) {
        if (!std.mem.eql(u8, a_tokens[a_start + i].kind, b_tokens[b_start + i].kind)) {
            return false;
        }
    }
    return true;
}
```

### Pattern 5: Interval Merging for Maximal Clone Groups

For each file, sort clone intervals by start_token, then merge overlapping or adjacent windows into maximal spans. This prevents counting the same tokens multiple times in the duplication percentage.

```zig
/// Sort clone intervals by start_token, merge overlapping intervals.
/// Standard O(N log N) sort + O(N) merge.
fn mergeIntervals(intervals: []TokenWindow) ![]TokenWindow {
    // Sort by start_token
    std.mem.sort(TokenWindow, intervals, {}, intervalLessThan);
    // Merge overlapping intervals
    var merged = std.ArrayList(TokenWindow).empty;
    for (intervals) |interval| {
        if (merged.items.len == 0 or interval.start_token > merged.items[merged.items.len - 1].end_token) {
            try merged.append(interval);
        } else {
            merged.items[merged.items.len - 1].end_token = @max(
                merged.items[merged.items.len - 1].end_token,
                interval.end_token,
            );
        }
    }
    return merged.toOwnedSlice();
}
```

### Pattern 6: CLI Integration — opt-in flag

The context specifies three equivalent opt-in paths. The existing `no_duplication: bool` in `CliArgs` and `AnalysisConfig` represents the **opt-out** model. Phase 11 must **invert** this to an **opt-in** model.

The current codebase has `no_duplication = false` as default (duplication conceptually enabled), but since the algorithm doesn't exist yet, it has zero effect. The Phase 11 change is:

1. Add `duplication: bool = false` to `CliArgs` (separate from `no_duplication` — keep `no_duplication` for backward compatibility but document it as deprecated/noop)
2. Add `duplication_enabled: bool` to `AnalysisConfig`
3. Add `--duplication` to the arg parser
4. Add `duplication` to the `--metrics` accepted values
5. Config file: add `analysis.duplication_enabled` field
6. In `main.zig`: check `cfg.analysis.?.duplication_enabled` before calling the duplication pass

**Alternative approach (simpler):** Keep `no_duplication` as the only toggle but default it to `true` when duplication is not yet computed. The CONTEXT says opt-in via `--duplication`, `--metrics duplication`, or config. Cleanest implementation: check if `"duplication"` is in the parsed metrics list OR if `cli_args.duplication` is set.

### Pattern 7: Health Score Integration

The existing `resolveEffectiveWeights()` already excludes duplication from the 4-metric normalization (by design from Phase 8). When duplication IS enabled, the duplication score should blend into the project/file health score.

**Recommended approach (Claude's Discretion):** Add `duplication` to `EffectiveWeights` and re-normalize all 5 weights when duplication is enabled. If duplication is disabled, existing 4-weight normalization is unchanged.

```zig
// In scoring.zig: extend EffectiveWeights
pub const EffectiveWeights = struct {
    cyclomatic: f64,
    cognitive: f64,
    halstead: f64,
    structural: f64,
    duplication: f64,  // 0.0 when disabled, normalized weight when enabled
};
```

Duplication score per file = `100 - duplication_pct` clamped to [0, 100], with sigmoid smoothing at the threshold values (15% warning → 50.0, 25% error → ~20.0).

### Anti-Patterns to Avoid

- **Storing full token text in the index:** Store only token `kind` (normalized type string), not the raw source bytes. Raw text is irrelevant for clone detection and would balloon memory.
- **Double-counting overlapping clones in duplication %:** Sort and merge intervals before computing cloned token count per file.
- **Running duplication in the parallel worker:** Duplication is cross-file — it must run after all workers complete. Don't add it to `analyzeFileWorker`.
- **Hash collision → false clone group:** Always verify token-by-token before creating a clone group. The hash step is a filter, not a final answer.
- **Reporting 1-instance "groups":** Only report clone groups with 2+ distinct locations. Single-file self-matches with identical positions are not clones.
- **Including type annotation tokens:** Skip TypeScript type annotations using `isTypeOnlyNode()` from `halstead.zig` — they create false type-related clones between `.ts` and `.tsx` files.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hash map | Custom open-addressing hash table | `std.AutoHashMap(u64, std.ArrayList(TokenWindow))` | stdlib is correct and maintained |
| Sorting | Custom sort | `std.mem.sort` | Already used in `parallel.zig` for results |
| JSON serialization | Custom JSON writer | `std.json.Stringify.valueAlloc` | Existing pattern in codebase |
| String comparison | Manual byte comparison | `std.mem.eql` | Correct and fast |

**Key insight:** The Rabin-Karp algorithm itself is simple enough (10-20 lines of Zig) that hand-rolling is correct here — there's no library to pull in, and the algorithm has no edge cases that a library would handle better.

---

## Common Pitfalls

### Pitfall 1: Hash Collisions Producing False Clone Groups

**What goes wrong:** Two different token sequences hash to the same value. Without verification, they're reported as clones.

**Why it happens:** u64 hash space is large but finite. With millions of windows across 10K files, collisions are rare but possible.

**How to avoid:** Always perform token-by-token verification when a hash bucket has 2+ entries. Only create a CloneGroup when `tokensMatch()` returns true.

**Warning signs:** Clone groups containing sequences that look obviously different when printed.

---

### Pitfall 2: O(N^2) Verification in Large Hash Buckets

**What goes wrong:** A common token sequence (e.g., 25 tokens of keywords like `if (` ... `return`) hashes to a bucket with thousands of entries. Pairwise verification is O(N^2).

**Why it happens:** Very common normalized token sequences create hash buckets with O(N) entries.

**How to avoid:** Apply a maximum bucket size limit (e.g., discard buckets with more than 1000 entries — these are common patterns, not meaningful clones). Alternatively, increase the minimum window size to 30-40 tokens to reduce bucket collision rate.

**Warning signs:** Analysis time scaling superlinearly with file count on codebases with repeated patterns (test files, boilerplate).

---

### Pitfall 3: Double-Counting Overlapping Clone Intervals

**What goes wrong:** A 50-token clone is detected by multiple overlapping 25-token windows. Counting each window separately inflates the `cloned_tokens` count.

**Why it happens:** The rolling hash produces N-window+1 windows per file, many of which overlap.

**How to avoid:** After finding all clone positions per file, sort intervals by start_token and run the merge-intervals algorithm before summing cloned token counts.

**Warning signs:** `duplication_pct` exceeding 100%.

---

### Pitfall 4: Parallel Analysis Incompatibility

**What goes wrong:** The hash index is built inside workers, creating race conditions on the shared `AutoHashMap`.

**Why it happens:** Duplication looks like a per-file analysis but requires cross-file state.

**How to avoid:** Run duplication analysis as a sequential post-step in `main.zig` after `analyzeFilesParallel` (or the sequential analysis loop) completes. The token sequences need to be re-extracted from the existing parse trees (or re-parsed) at this point — see the tree-lifetime note below.

**Warning signs:** Segfaults or incorrect results in multi-threaded mode.

---

### Pitfall 5: Tree-Sitter Tree Lifetime

**What goes wrong:** The parse trees (`TSTree`) are freed after each file is analyzed in the parallel pipeline (`defer if (result.tree) |tree| tree.deinit()`). The duplication pass needs the ASTs to tokenize.

**Why it happens:** The existing pipeline frees trees as soon as metrics are extracted, to minimize memory usage.

**How to avoid:** Two options:
1. **Re-parse files for tokenization:** Open each file again during the duplication pass. Simple but doubles I/O cost.
2. **Pre-tokenize during analysis:** Add token collection to the parallel worker (store token sequences in the `FileAnalysisResult`), then run the hash index build post-parallel. This is more memory-efficient (one I/O pass) but requires extending `FileAnalysisResult`.

**Recommendation (Claude's Discretion):** Re-parse in the duplication pass. The extra I/O is bounded by OS file caches on a warm run (files already read once). Simpler to implement correctly, avoids increasing worker memory footprint.

---

### Pitfall 6: Line Number Reporting Accuracy

**What goes wrong:** Clone locations report wrong line numbers because token line numbers are not stored.

**Why it happens:** The rolling hash window identifies tokens by index, not by line number.

**How to avoid:** Store `start_line` and `end_line` in each `Token` struct (from `node.startPoint().row + 1`). The `TokenWindow` can then carry first/last line numbers directly.

---

### Pitfall 7: Memory Explosion with Large Codebases

**What goes wrong:** The hash index for 10K files stores O(N_total_tokens) `TokenWindow` entries, each ~20 bytes, totaling hundreds of MB.

**Why it happens:** Every sliding window position across every file creates one `TokenWindow` stored in the index.

**How to avoid:** After building the index, immediately discard entries in single-entry buckets (no duplicates possible). For the remaining entries, verification and clone group formation can be done in-place. Use an arena allocator for the index construction and free it after clone groups are formed.

**Warning signs:** Peak memory during duplication analysis spiking 10x higher than baseline.

---

## Code Examples

### File-Level Duplication Percentage Calculation

```zig
// After interval merging: count non-overlapping cloned tokens
fn computeFileDuplicationPct(
    total_tokens: u32,
    merged_clone_intervals: []const TokenWindow,
) f64 {
    if (total_tokens == 0) return 0.0;
    var cloned: u32 = 0;
    for (merged_clone_intervals) |iv| {
        cloned += iv.end_token - iv.start_token;
    }
    return @as(f64, @floatFromInt(cloned)) / @as(f64, @floatFromInt(total_tokens)) * 100.0;
}
```

### Console Output Format

```
Duplication
-----------
Clone group (42 tokens): src/auth/login.ts:15, src/auth/register.ts:88
Clone group (31 tokens): src/utils/format.ts:42, src/utils/parse.ts:10, src/lib/common.ts:77

File duplication:
  src/auth/login.ts        12.3%  [OK]
  src/auth/register.ts     17.1%  [WARNING]

Project duplication: 4.2%  [OK]
```

### SARIF relatedLocations Structure for Clone Groups

```json
{
  "ruleId": "complexity-guard/duplication",
  "ruleIndex": 10,
  "level": "warning",
  "message": {
    "text": "Clone group: 42 tokens duplicated in 2 locations (file_a.ts:15, file_b.ts:88)"
  },
  "locations": [
    {
      "physicalLocation": {
        "artifactLocation": { "uri": "src/auth/login.ts" },
        "region": { "startLine": 15, "endLine": 22 }
      }
    }
  ],
  "relatedLocations": [
    {
      "id": 1,
      "physicalLocation": {
        "artifactLocation": { "uri": "src/auth/register.ts" },
        "region": { "startLine": 88, "endLine": 95 }
      },
      "message": { "text": "Clone instance 2" }
    }
  ]
}
```

(Source: GitHub SARIF documentation — `relatedLocations` with `id`, `physicalLocation`, `message.text`)

### JSON Output Structure for Clone Groups

```json
{
  "duplication": {
    "enabled": true,
    "project_duplication_pct": 4.2,
    "project_status": "ok",
    "clone_groups": [
      {
        "token_count": 42,
        "locations": [
          { "file": "src/auth/login.ts", "start_line": 15, "end_line": 22 },
          { "file": "src/auth/register.ts", "start_line": 88, "end_line": 95 }
        ]
      }
    ],
    "files": [
      {
        "path": "src/auth/login.ts",
        "total_tokens": 341,
        "cloned_tokens": 42,
        "duplication_pct": 12.3,
        "status": "ok"
      }
    ]
  }
}
```

### Duplication Threshold Pair (config.zig extension)

The existing `ThresholdPair` uses `?u32` for integer metrics. Duplication percentages are `f64`. Add a separate `DuplicationThresholds` struct:

```zig
pub const DuplicationThresholds = struct {
    file_warning: ?f64 = null,   // default 15.0
    file_error: ?f64 = null,     // default 25.0
    project_warning: ?f64 = null, // default 5.0
    project_error: ?f64 = null,  // default 10.0
};
```

Add to `ThresholdsConfig`:
```zig
duplication: ?DuplicationThresholds = null,
```

### Config File Example (JSON)

```json
{
  "analysis": {
    "duplication_enabled": true,
    "thresholds": {
      "duplication": {
        "file_warning": 15.0,
        "file_error": 25.0,
        "project_warning": 5.0,
        "project_error": 10.0
      }
    }
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Line-based duplication count | Token-based duplication count | Industry shift ~2015 (SonarQube 4.7) | Token-based is format-independent, less susceptible to indentation changes |
| Text fingerprinting | AST-based normalization | 2020s | AST normalization is more semantically precise for Type 2 clones |
| 100-token minimum (SonarQube default for non-Java) | 25-token minimum (CG default) | N/A — CG choice | Lower minimum catches more duplications; 25 tokens ≈ 3-5 lines of typical TS code |

**Deprecated/outdated:**
- Suffix tree approach: Academic preference but complex to implement correctly; rolling hash achieves same result with simpler code
- Type 3/4 clone detection (near-miss clones with inserted/deleted lines): Out of scope for Phase 11, much higher algorithmic complexity

---

## Open Questions

1. **Normalization depth beyond identifiers**
   - What we know: CONTEXT.md marks this as Claude's Discretion. Type 2 clones = identical modulo identifiers, literals, whitespace, comments. Normalizing string literals and numbers (`"foo"` → `"S"`, `42` → `"N"`) improves recall but may increase false positives.
   - What's unclear: Whether TS/JS codebases have significant clone patterns where only literals differ (e.g., similar validation functions with different error messages).
   - Recommendation: Normalize only identifiers in Phase 11 (conservative). Add literal normalization as a config option if users request it. Tree-sitter node types for string/number literals are `string` and `number` — easy to add.

2. **Token set definition (what to skip)**
   - What we know: Structural punctuation (`{`, `}`, `(`, `)`, `;`, `,`) is commonly skipped in clone detection to focus on semantic content.
   - What's unclear: Whether skipping `{`/`}` affects detection quality for TypeScript where curly braces carry block-level meaning. Missing braces in the token stream means two functions with different block structures could hash to the same value.
   - Recommendation: Skip pure punctuation (`;`, `,`) but include `{` and `}` in the token stream. This preserves block structure information at the cost of slightly lower recall for reformatted code.

3. **Re-parse vs. pre-tokenize approach for tree lifetime**
   - What we know: Current pipeline frees TSTree after per-file analysis. Two options to get tokens: re-parse files, or extend FileAnalysisResult to carry token sequences.
   - What's unclear: Memory overhead of carrying token sequences through the parallel phase (estimated 200 tokens * ~30 bytes = 6KB per file * 10K files = 60MB extra during analysis).
   - Recommendation: Re-parse for Phase 11 simplicity. If benchmark shows this is a bottleneck, move to pre-tokenize in Phase 12+ optimization.

4. **Health score integration timing**
   - What we know: Duplication score is file-level (file duplication %). Health score is also file-level. The current `computeFileScore` averages function scores — but duplication % is a file-level metric, not function-level.
   - What's unclear: Whether to blend duplication into the existing file health score formula or report it as a separate metric.
   - Recommendation: Add duplication as a file-level adjustment: `file_health = file_health * (1 - dup_weight) + dup_score * dup_weight` where `dup_score = sigmoidScore(dup_pct, warning_threshold, k)`.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase (`/home/ben/code/complexity-guard/src/`) — tree-sitter Node API patterns, Zig stdlib usage, allocator patterns, parallel.zig worker model, ThresholdResult structure
- `/home/ben/code/complexity-guard/src/metrics/halstead.zig` — tokenization pattern using `isTypeOnlyNode()`, leaf node traversal model
- `/home/ben/code/complexity-guard/src/cli/config.zig` — ThresholdPair structure, config extension pattern
- GitHub SARIF documentation (https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning) — `relatedLocations` structure verified

### Secondary (MEDIUM confidence)
- Daniel Lemire, "How fast is rolling Karp-Rabin hashing?" (2024-02-04) — performance benchmarks, B=31 constant
- SonarQube metric definitions documentation — token-based duplication % formula verified: `duplicated_lines / lines_of_code * 100`, 100-token minimum for non-Java
- Wikipedia Rabin-Karp algorithm — rolling hash update formula `hash = (hash - remove * B^N) * B + add`
- CCFinderX academic literature — Type 2 normalization (identifiers only) industry standard

### Tertiary (LOW confidence)
- WebSearch results on clone group merging algorithms — standard merge-intervals pattern applies, not clone-detection-specific
- "Source Code Clone Detection Using Unsupervised Similarity Measures" (SWQD 2024) — rolling hash achieves 93% precision claim (not independently verified)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure Zig stdlib, no new dependencies, existing tree-sitter integration
- Architecture: HIGH — duplication module pattern mirrors halstead.zig, post-parallel pass is clearly correct
- Pitfalls: HIGH — hash collision, double-counting, tree lifetime pitfalls all verified against codebase
- Normalization depth: MEDIUM — identifier normalization standard, literal normalization unclear for TS/JS

**Research date:** 2026-02-22
**Valid until:** 2026-09-01 (stable algorithms, no expiry risk)
