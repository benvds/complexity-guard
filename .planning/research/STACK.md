# Stack Research

**Domain:** Code Complexity Analysis (Zig + tree-sitter)
**Researched:** 2026-02-14
**Confidence:** HIGH (stack is prescribed by PRD; Zig and tree-sitter are mature, well-documented choices)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Zig | 0.14.x (latest stable) | Implementation language | Single static binary output, C ABI compatibility for tree-sitter, cross-compilation to all targets from any host, explicit memory management without GC overhead, fast compile times |
| tree-sitter | 0.24.x | Parser framework | Proven TS/TSX/JS/JSX grammars, error-tolerant parsing, incremental parsing for future LSP/watch mode, C library callable from Zig |
| tree-sitter-typescript | latest | TypeScript + TSX grammars | Official grammar maintained by tree-sitter org, covers modern TypeScript syntax, includes separate TSX grammar |
| tree-sitter-javascript | latest | JavaScript + JSX grammars | Official grammar, TSX grammar depends on it, handles JSX via separate parser |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| zig-tree-sitter | latest | Zig bindings for tree-sitter C API | Alternative to raw `@cImport` — provides idiomatic Zig wrapper over tree-sitter C functions. Evaluate whether raw C interop or wrapper is simpler. |
| std.json (Zig stdlib) | built-in | JSON parsing/serialization | Config file loading (`.complexityguard.json`), JSON output format, SARIF output (JSON-based) |
| std.Thread (Zig stdlib) | built-in | Thread pool for parallel analysis | File-level parallelism — each file analyzed independently in a worker thread |
| std.fs (Zig stdlib) | built-in | File system operations | Directory walking, file reading, glob matching for include/exclude patterns |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| zig build | Build system | Configure in `build.zig`, handles C library compilation and linking |
| zig test | Unit testing | Built into language, test blocks alongside source code |
| tree-sitter CLI | Grammar development/debugging | `tree-sitter parse file.ts` to inspect CSTs, useful for understanding node types |
| SARIF validator | Validate SARIF output | `npm i -g @microsoft/sarif-multitool` then `sarif validate output.sarif` |
| Valgrind / AddressSanitizer | Memory leak detection | Critical for Zig/C boundary — tree-sitter objects need manual cleanup |

## Installation

```bash
# Install Zig (use zigup or system package manager)
# zigup is recommended for version management
curl -sS https://raw.githubusercontent.com/nicholass/zigup/main/bootstrap.sh | bash
zigup 0.14.0

# tree-sitter grammars are compiled from C source
# Include as git submodules or vendor the C files directly
git submodule add https://github.com/tree-sitter/tree-sitter-typescript grammars/tree-sitter-typescript
git submodule add https://github.com/tree-sitter/tree-sitter-javascript grammars/tree-sitter-javascript

# tree-sitter core (C library)
# Either: use zig-tree-sitter package, or vendor tree-sitter/lib/ directly
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Zig | Rust | If team has Rust experience and wants mature ecosystem (cargo, crates.io). Rust has longer compile times but richer library ecosystem. |
| Zig | C/C++ | If you need maximum ecosystem compatibility. Worse developer experience, manual build system setup. |
| Zig | Go | If you prioritize development speed over binary size/performance. Go binaries are larger, GC pauses possible. |
| tree-sitter | swc_ecma_parser (Rust) | If building in Rust. swc parser is very fast and TypeScript-native but Rust-only. |
| tree-sitter | oxc_parser (Rust) | If building in Rust. Newest, fastest JS/TS parser but Rust-only, less mature. |
| tree-sitter | Manual recursive descent | If you need full control over AST shape. Enormous engineering effort, not justified for this project. |
| Vendored C source | Zig package manager | When zig package ecosystem matures and tree-sitter grammars are available as zig packages. Currently vendor or submodule is more reliable. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| TypeScript compiler API (ts.createProgram) | Requires Node.js runtime, extremely slow for analysis-only use, heavy dependency | tree-sitter — parses without type-checking, orders of magnitude faster |
| ESLint's parser (@typescript-eslint/parser) | JavaScript runtime, slow, designed for lint rules not metrics | tree-sitter — C library, callable from Zig, faster parsing |
| Babel parser | JavaScript runtime, designed for transpilation, doesn't handle TSX well | tree-sitter — dedicated TS/TSX grammars |
| ANTLR | Java runtime, complex grammar format, slower than tree-sitter | tree-sitter — C-native, simpler integration with Zig |
| Regular expressions for parsing | Breaks on complex syntax, unmaintainable, incorrect | tree-sitter — proper CST with error recovery |
| Zig's std.heap.GeneralPurposeAllocator for production | Debug allocator, tracks allocations, slower | std.heap.c_allocator or arena allocators for release builds |

## Stack Patterns by Variant

**If targeting minimal binary size (< 3 MB):**
- Compile with `-Doptimize=ReleaseSmall`
- Strip debug symbols
- Consider: do you need all 4 grammars? TypeScript grammar includes JavaScript support

**If targeting maximum performance:**
- Compile with `-Doptimize=ReleaseFast`
- Use arena allocators per-file (bulk free after each file)
- Profile with `zig build -Doptimize=ReleaseFast` + perf/instruments

**If developing/debugging:**
- Compile with `-Doptimize=Debug`
- Use GeneralPurposeAllocator with safety checks
- Enable AddressSanitizer via `-fsanitize=address`

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Zig 0.14.x | tree-sitter C API | Zig's C interop is stable; tree-sitter's C API is stable. No compatibility issues expected. |
| tree-sitter-typescript | tree-sitter 0.24.x | Grammar version must match core library version. Pin both. |
| tree-sitter-javascript | tree-sitter-typescript | TSX grammar depends on JavaScript grammar. Must include both. |

## Sources

- PRD specification (provided) — stack choices and rationale (HIGH confidence)
- Zig language documentation — memory management, C interop, build system (MEDIUM confidence, training data)
- tree-sitter documentation — parser API, grammar structure (MEDIUM confidence, training data)
- Comparable projects: oxlint (Rust/oxc), Biome (Rust), zls (Zig/tree-sitter) — architecture patterns (MEDIUM confidence)

---
*Stack research for: Code Complexity Analysis (Zig + tree-sitter)*
*Researched: 2026-02-14*
