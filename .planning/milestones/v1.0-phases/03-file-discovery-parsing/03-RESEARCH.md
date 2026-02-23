# Phase 3: File Discovery & Parsing - Research

**Researched:** 2026-02-14
**Domain:** Tree-sitter C API integration with Zig, filesystem traversal, glob pattern matching
**Confidence:** MEDIUM-HIGH

## Summary

Phase 3 implements file discovery and parsing for TypeScript/JavaScript files using Zig's standard library for filesystem traversal and tree-sitter's C API for parsing. The primary technical challenges are: (1) proper C/Zig boundary memory management with tree-sitter parsers, (2) handling Zig 0.15.2 API changes from the ecosystem's typical examples, and (3) deciding between hand-rolled glob matching vs external libraries.

Tree-sitter provides battle-tested, error-tolerant parsers for TypeScript, TSX, JavaScript, and JSX through separate grammar modules. The C API requires explicit lifecycle management for parsers and trees. Zig's `std.fs.Dir.walk()` provides recursive directory traversal with built-in memory management through allocators.

**Primary recommendation:** Use tree-sitter C API directly via `@cImport` (avoid zig-tree-sitter wrapper for Zig 0.15.2 compatibility), implement file extension filtering with `std.mem.endsWith()`, and defer glob pattern matching to Phase 4 (config integration) to avoid premature external dependencies.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tree-sitter (C API) | Latest stable | Parse TS/JS/TSX/JSX into ASTs | De-facto parsing library, error-tolerant, incremental, proven grammars |
| tree-sitter-typescript | Latest | TypeScript & TSX grammars | Official TypeScript grammar, maintained by tree-sitter org |
| tree-sitter-javascript | Latest | JavaScript & JSX grammar | Required dependency for TypeScript, handles JSX |
| Zig std.fs | stdlib (0.15.2) | Directory traversal | Built-in, no external deps, works with allocators |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| zlob | 0.15.2 only | Fast POSIX/gitignore-style glob matching | If complex patterns needed (requires exact Zig version match) |
| glob.zig | 0.16.0-dev | Pure Zig glob matching | If targeting Zig 0.16+ in future (currently incompatible) |
| std.mem.endsWith | stdlib | Simple extension checks | For basic .ts/.tsx/.js/.jsx filtering (recommended for Phase 3) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct C API | zig-tree-sitter wrapper | Wrapper adds convenience but Zig version compatibility unknown for 0.15.2 |
| std.mem.endsWith | zlob library | zlob adds SIMD performance but locks to exact Zig 0.15.2, overkill for extension checks |
| Hand-rolled glob | glob.zig | Pure Zig but targets 0.16.0-dev (incompatible with current 0.15.2) |

**Installation:**

Tree-sitter parsers are typically cloned as git submodules or vendored, then compiled from C source:

```bash
# Clone parser repositories
git submodule add https://github.com/tree-sitter/tree-sitter vendor/tree-sitter
git submodule add https://github.com/tree-sitter/tree-sitter-typescript vendor/tree-sitter-typescript
git submodule add https://github.com/tree-sitter/tree-sitter-javascript vendor/tree-sitter-javascript

# Build into static library via build.zig (see Architecture Patterns)
```

## Architecture Patterns

### Recommended Project Structure
```
src/
├── core/
│   ├── types.zig          # Existing: FunctionResult, FileResult, etc.
│   ├── json.zig           # Existing: JSON serialization
├── parser/
│   ├── tree_sitter.zig    # Tree-sitter C API bindings (@cImport wrapper)
│   ├── typescript.zig     # TypeScript/TSX parser lifecycle
│   ├── javascript.zig     # JavaScript/JSX parser lifecycle
│   └── ast.zig            # AST traversal utilities (future)
├── discovery/
│   ├── walker.zig         # Recursive directory traversal
│   └── filter.zig         # File extension filtering
├── main.zig              # Entry point
└── test_helpers.zig      # Existing test builders

vendor/                   # Git submodules for tree-sitter parsers
├── tree-sitter/
├── tree-sitter-typescript/
└── tree-sitter-javascript/
```

### Pattern 1: Tree-sitter C API Lifecycle

**What:** Create parser, set language, parse string, check for errors, clean up resources

**When to use:** Every file parsing operation

**Example:**
```zig
// Source: https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h
// and https://tree-sitter.github.io/tree-sitter/using-parsers/1-getting-started.html

const c = @cImport({
    @cInclude("tree_sitter/api.h");
    @cDefine("tree_sitter_typescript", {});
    @cInclude("tree-sitter-typescript/typescript/src/parser.c");
});

pub fn parseTypeScriptFile(allocator: Allocator, source: []const u8) !ParseResult {
    // Create parser
    const parser = c.ts_parser_new();
    defer c.ts_parser_delete(parser);

    // Set language
    const lang = c.tree_sitter_typescript();
    if (!c.ts_parser_set_language(parser, lang)) {
        return error.LanguageVersionMismatch;
    }

    // Parse source
    const tree = c.ts_parser_parse_string(
        parser,
        null, // old_tree for incremental parsing
        source.ptr,
        @intCast(source.len),
    );
    defer c.ts_tree_delete(tree);

    if (tree == null) return error.ParseFailed;

    // Get root node
    const root = c.ts_tree_root_node(tree);

    // Check for syntax errors
    if (c.ts_node_has_error(root)) {
        // Tree contains ERROR or MISSING nodes - still usable!
        // Report error but continue processing
    }

    // Process AST...
    return ParseResult{ /* ... */ };
}
```

### Pattern 2: Recursive Directory Walking with File Filtering

**What:** Walk directory tree, filter by extension, collect matching files

**When to use:** File discovery phase before parsing

**Example:**
```zig
// Source: https://pyk.sh/cookbooks/zig/walk-directory-tree-collect-matching-files/
// and https://pedropark99.github.io/zig-book/Chapters/12-file-op.html

pub fn discoverFiles(
    allocator: Allocator,
    base_path: []const u8,
) !std.ArrayList([]const u8) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    var files = std.ArrayList([]const u8).init(allocator);
    errdefer files.deinit();

    // Open directory with iterate permission
    var dir = try std.fs.cwd().openDir(base_path, .{
        .iterate = true,
    });
    defer dir.close();

    // Create walker - allocates internal state
    var walker = try dir.walk(arena_allocator);
    defer walker.deinit();

    // Iterate entries
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        // Filter by extension
        if (isTargetFile(entry.path)) {
            // CRITICAL: entry.path is owned by walker, must copy!
            const path_copy = try allocator.dupe(u8, entry.path);
            try files.append(path_copy);
        }
    }

    return files;
}

fn isTargetFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".ts") or
           std.mem.endsWith(u8, path, ".tsx") or
           std.mem.endsWith(u8, path, ".js") or
           std.mem.endsWith(u8, path, ".jsx");
}
```

### Pattern 3: Build Integration for Tree-sitter Parsers

**What:** Compile tree-sitter C sources and link into Zig binary

**When to use:** build.zig setup for Phase 3

**Example:**
```zig
// Source: https://zig.news/almmiko/building-zig-libraries-with-c-dependencies-25a
// and https://medium.com/@eddo2626/lets-learn-zig-4-using-c-libraries-in-zig-5fcc3206f0dc

pub fn build(b: *std.Build) void {
    // ... existing setup ...

    // Link libc for C interop
    exe.linkLibC();

    // Add tree-sitter core
    exe.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter/lib/src/lib.c"),
        .flags = &.{"-std=c11"},
    });

    // Add TypeScript parser (includes both typescript and tsx)
    exe.addIncludePath(b.path("vendor/tree-sitter-typescript/typescript/src"));
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/typescript/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/typescript/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });

    // Add TSX parser (separate grammar!)
    exe.addIncludePath(b.path("vendor/tree-sitter-typescript/tsx/src"));
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/tsx/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/tsx/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });

    // Add JavaScript parser (dependency for TypeScript)
    exe.addIncludePath(b.path("vendor/tree-sitter-javascript/src"));
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-javascript/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-javascript/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
}
```

### Pattern 4: Parser Selection by File Extension

**What:** Route to correct parser based on file extension

**When to use:** Before parsing each discovered file

**Example:**
```zig
// Source: https://github.com/tree-sitter/tree-sitter-typescript
// "Because TSX and TypeScript are actually two different dialects, this module defines two grammars"

pub const ParserType = enum {
    typescript,
    tsx,
    javascript,
};

pub fn selectParser(file_path: []const u8) ParserType {
    if (std.mem.endsWith(u8, file_path, ".tsx")) {
        return .tsx;
    } else if (std.mem.endsWith(u8, file_path, ".ts")) {
        return .typescript;
    } else if (std.mem.endsWith(u8, file_path, ".jsx")) {
        return .javascript; // JS parser handles JSX
    } else if (std.mem.endsWith(u8, file_path, ".js")) {
        return .javascript;
    }
    unreachable; // Should only call after extension filtering
}

pub fn getLanguage(parser_type: ParserType) *c.TSLanguage {
    return switch (parser_type) {
        .typescript => c.tree_sitter_typescript(),
        .tsx => c.tree_sitter_tsx(),
        .javascript => c.tree_sitter_javascript(),
    };
}
```

### Anti-Patterns to Avoid

- **Not using defer for cleanup:** Tree-sitter objects MUST be freed explicitly - missing `defer c.ts_tree_delete(tree)` or `defer c.ts_parser_delete(parser)` causes memory leaks
- **Storing walker entry paths directly:** `entry.path` from `walker.next()` is reused each iteration - must use `allocator.dupe()` to copy
- **Opening directory without .iterate:** `openDir()` must include `.iterate = true` option or `walk()` will fail
- **Failing on syntax errors:** Tree-sitter returns valid trees even with ERROR nodes - check `ts_node_has_error()` but continue processing
- **Using zig-tree-sitter without version check:** Wrapper may not support Zig 0.15.2 (compatibility unverified in research)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TypeScript/JavaScript parser | Custom recursive descent parser | tree-sitter with official grammars | TypeScript grammar is 10,000+ lines, TSX/JSX context-sensitive, incremental parsing complex, error recovery non-trivial |
| Directory traversal with symlink handling | Manual readdir + recursion | std.fs.Dir.walk() | Handles symlink cycles, cross-device boundaries, platform differences (Windows vs POSIX) |
| File extension detection | String manipulation | std.mem.endsWith() | Edge cases: ".d.ts" files, case sensitivity on different OSes, unicode normalization |
| Glob pattern matching (if needed) | Regex or manual wildcards | zlob or defer to config phase | Character classes, brace expansion, gitignore syntax, POSIX compliance - surprising complexity |

**Key insight:** Parsing is deceptively complex. Tree-sitter handles not just grammar but error recovery, incremental updates, query systems, and cross-language injections. The 6+ years of production use across thousands of projects represents millions of hours of edge case discovery that cannot be replicated in a greenfield implementation.

## Common Pitfalls

### Pitfall 1: Memory Leaks at C/Zig Boundary

**What goes wrong:** Tree-sitter C objects (TSParser, TSTree) allocated but never freed, causing gradual memory exhaustion

**Why it happens:** Zig's allocator-based memory model doesn't apply to C code - C API requires manual malloc/free equivalent (ts_parser_new/ts_parser_delete)

**How to avoid:**
- Use `defer` immediately after creation: `const parser = c.ts_parser_new(); defer c.ts_parser_delete(parser);`
- Use arena allocator for Zig-side allocations (file paths, result structs) but NOT for C objects
- Run tests with leak detection: `std.testing.allocator` will catch Zig leaks but not C leaks - use valgrind for full checking

**Warning signs:** Increasing memory usage when processing multiple files, test failures with leak-detecting allocators

### Pitfall 2: Walker Entry Path Lifetime Confusion

**What goes wrong:** Storing `entry.path` pointers from `walker.next()` results in all stored paths pointing to the same reused buffer

**Why it happens:** Walker reuses internal buffer for path strings to avoid allocation on each entry - paths are only valid until next `walker.next()` call

**How to avoid:**
- Always use `allocator.dupe(u8, entry.path)` when storing paths beyond current iteration
- Use arena allocator for temporary path storage during discovery phase
- Document in code that walker paths are borrowed, not owned

**Warning signs:** All discovered file paths are identical (last file seen), use-after-free in tests, corrupted paths in results

### Pitfall 3: Zig 0.15.2 API Changes Break Examples

**What goes wrong:** Following ecosystem examples for ArrayList, File I/O, etc. causes compile errors due to Zig 0.15.2 breaking changes

**Why it happens:** Most Zig tutorials/examples target 0.11-0.14. Zig 0.15 redesigned ArrayList (now "managed" requires allocator per method), Reader/Writer interfaces completely overhauled, deprecated many types

**How to avoid:**
- Check Zig version in all example code before copying
- Prefer stdlib source code over tutorials: `zig/lib/std/fs.zig` is authoritative
- Use `zig build --verbose` to see full compiler errors (helps identify API changes)
- Reference: https://sngeth.com/zig/systems-programming/breaking-changes/2025/10/24/zig-0-15-migration-roadblocks/

**Warning signs:** Compiler errors about missing methods, deprecation warnings, "expected X arguments, found Y" for stdlib functions

### Pitfall 4: Treating Syntax Errors as Parse Failures

**What goes wrong:** Aborting when `ts_node_has_error()` returns true, causing tool to skip files with minor syntax errors

**Why it happens:** Assumption that parse errors mean unusable AST, like traditional parsers

**How to avoid:**
- Tree-sitter always returns a valid tree (unless ts_parser_parse returns NULL, which is rare)
- Use ERROR and MISSING nodes for error reporting, but continue analysis on valid subtrees
- Design FileResult to include both metrics AND error information
- Philosophy: "best effort analysis" better than "all or nothing"

**Warning signs:** Tool completely skips files with one typo, metrics are zero for partially valid files, poor user experience with real-world codebases

### Pitfall 5: TSX vs TypeScript Parser Confusion

**What goes wrong:** Using TypeScript parser for .tsx files fails to recognize JSX syntax, produces error nodes

**Why it happens:** "Because TSX and TypeScript are actually two different dialects" - separate grammars required

**How to avoid:**
- Map .tsx extension -> `tree_sitter_tsx()` language
- Map .ts extension -> `tree_sitter_typescript()` language
- Map .jsx/.js extensions -> `tree_sitter_javascript()` language (JS parser handles JSX)
- Test with fixture files for each extension to verify correct routing

**Warning signs:** JSX syntax reported as errors in .tsx files, confusion in logs about which parser was used, unexpected ERROR nodes in known-valid code

### Pitfall 6: Forgetting to Link libc

**What goes wrong:** Linker errors about undefined symbols (malloc, free, memcpy) when using tree-sitter C code

**Why it happens:** Tree-sitter C code depends on libc, but Zig doesn't link libc by default

**How to avoid:**
- Add `exe.linkLibC();` in build.zig before adding C source files
- Also required for `@cImport` to work correctly
- Document in build.zig comments why libc is needed

**Warning signs:** Linker errors mentioning C stdlib functions, successful compile but failed link step

## Code Examples

Verified patterns from official sources:

### Checking for Syntax Errors in Parsed Tree

```zig
// Source: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html
// and https://github.com/tree-sitter/tree-sitter/issues/1136

const root = c.ts_tree_root_node(tree);

// Check if tree contains any errors
if (c.ts_node_has_error(root)) {
    // Tree contains ERROR or MISSING nodes
    // ERROR: parser encountered unrecognizable text
    // MISSING: parser inserted missing token for error recovery

    // Can still analyze valid portions of tree!
    // Query for (ERROR) and (MISSING) nodes to report specifics
}

// Check if specific node is error
if (c.ts_node_is_error(node)) {
    // This specific node is an ERROR node
}
```

### Arena Allocator Pattern for Directory Walking

```zig
// Source: https://zig.guide/standard-library/allocators/
// and https://www.huy.rocks/everyday/01-12-2022-zig-how-arenaallocator-works

pub fn discoverFiles(allocator: Allocator, path: []const u8) ![][]const u8 {
    // Use arena for temporary allocations during walking
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit(); // Frees ALL arena allocations at once

    const arena_alloc = arena.allocator();

    // Use main allocator for results that outlive function
    var results = std.ArrayList([]const u8).init(allocator);
    errdefer {
        // Clean up on error
        for (results.items) |item| allocator.free(item);
        results.deinit();
    }

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    // Walker uses arena - freed automatically by arena.deinit()
    var walker = try dir.walk(arena_alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file and isTargetFile(entry.path)) {
            // Use MAIN allocator for results (outlive arena)
            const path_copy = try allocator.dupe(u8, entry.path);
            try results.append(path_copy);
        }
    }

    return results.toOwnedSlice();
}
```

### File Extension Filtering

```zig
// Source: https://zig.guide/standard-library/filesystem/
// and https://www.huy.rocks/everyday/12-11-2022-zig-using-zig-for-advent-of-code

const std = @import("std");

pub fn isTargetFile(path: []const u8) bool {
    // TypeScript files
    if (std.mem.endsWith(u8, path, ".ts")) return true;
    if (std.mem.endsWith(u8, path, ".tsx")) return true;

    // JavaScript files
    if (std.mem.endsWith(u8, path, ".js")) return true;
    if (std.mem.endsWith(u8, path, ".jsx")) return true;

    // Could also check for .d.ts (TypeScript declarations)
    // but those don't contain implementation code to analyze

    return false;
}

// Alternative: array-based for easier configuration
const TARGET_EXTENSIONS = [_][]const u8{ ".ts", ".tsx", ".js", ".jsx" };

pub fn isTargetFileArray(path: []const u8) bool {
    for (TARGET_EXTENSIONS) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }
    return false;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Regex-based parsers | Tree-sitter incremental parsing | ~2018 (tree-sitter 0.1) | Error-tolerant parsing enables real-time editor features |
| Single TypeScript grammar | Separate TS and TSX grammars | TypeScript grammar inception | Must route .tsx to tsx parser, not typescript parser |
| Zig ArrayList.init(allocator) | ArrayList with per-call allocator | Zig 0.15 (Jan 2025) | "Managed" variant requires allocator on every method call |
| std.fs.File.reader() | std.fs.File.Reader | Zig 0.15 (Jan 2025) | Reader/Writer interface redesign for performance |
| zig-tree-sitter high-level wrapper | Direct C API via @cImport | Ongoing (Zig 0.15 ecosystem lag) | Many Zig libs incompatible with 0.15 API changes, C FFI more stable |

**Deprecated/outdated:**
- **zig-clap, yazap:** CLI parsing libraries incompatible with Zig 0.15 (Phase 2 already addressed with hand-rolled parser)
- **known-folders:** Config path detection library incompatible with Zig 0.15 (Phase 2 already addressed with XDG detection)
- **std.fs.File.reader()/writer():** Now deprecated in favor of direct Reader/Writer types (Zig 0.15)
- **ArrayList.init() without allocator:** Now requires passing allocator to individual methods (Zig 0.15)

## Open Questions

1. **Should we use zig-tree-sitter wrapper or direct C API?**
   - What we know: Direct C API is stable, documented at https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h
   - What's unclear: zig-tree-sitter Zig version compatibility (no explicit 0.15.2 support documented)
   - Recommendation: Start with direct C API via `@cImport` for maximum control and Zig 0.15.2 compatibility. Can refactor to wrapper later if verified compatible.

2. **When should glob pattern matching be implemented?**
   - What we know: Phase 3 requirements mention "glob patterns from config file", but Phase 4 is config integration
   - What's unclear: Should Phase 3 implement glob matching infrastructure or just extension filtering?
   - Recommendation: Phase 3 uses simple extension filtering (`std.mem.endsWith`). Defer glob matching to Phase 4 when config patterns are actually available. Avoids premature zlob dependency with strict version lock.

3. **How should we handle .d.ts files?**
   - What we know: TypeScript declaration files contain type signatures, not implementation
   - What's unclear: Are .d.ts files in scope for complexity analysis?
   - Recommendation: Exclude .d.ts from Phase 3 filtering. They lack function implementations so complexity metrics would be zero/misleading. Can revisit if users request it.

4. **Should we vendor tree-sitter sources or use system library?**
   - What we know: Project goal is "single static binary", vendoring ensures version control
   - What's unclear: Build complexity vs dependency management tradeoff
   - Recommendation: Vendor tree-sitter as git submodules (git submodule add). Ensures reproducible builds, no system dependencies, supports static binary goal. Trade build time for deployment simplicity.

5. **How to handle symbolic links during directory traversal?**
   - What we know: `std.fs.Dir.walk()` handles symlinks, but default behavior unclear
   - What's unclear: Does walker follow symlinks? Could this cause cycles or cross-device issues?
   - Recommendation: Test with symlink fixtures in tests/fixtures/. Document behavior. May need to track visited inodes if cycles detected.

## Sources

### Primary (HIGH confidence)

**Tree-sitter Official Documentation:**
- [Using Parsers - Tree-sitter](https://tree-sitter.github.io/tree-sitter/using-parsers/) - Core API concepts
- [Tree-sitter C API Header](https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h) - Function signatures and memory management
- [Getting Started - Tree-sitter](https://tree-sitter.github.io/tree-sitter/using-parsers/1-getting-started.html) - Parser lifecycle examples
- [Basic Syntax - Tree-sitter Queries](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html) - ERROR and MISSING node handling

**Tree-sitter Grammar Repositories:**
- [tree-sitter-typescript](https://github.com/tree-sitter/tree-sitter-typescript) - TypeScript and TSX grammars (separate!)
- [tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript) - JavaScript with JSX support

**Zig Official Documentation:**
- [Zig Filesystem Guide](https://zig.guide/standard-library/filesystem/) - std.fs.Dir.walk() and iteration
- [Zig Allocators Guide](https://zig.guide/standard-library/allocators/) - ArenaAllocator pattern
- [Zig cImport Guide](https://zig.guide/working-with-c/c-import/) - C interop basics
- [Zig 0.15.1 Release Notes](https://ziglang.org/download/0.15.1/release-notes.html) - API changes

**Zig Cookbook/Tutorials:**
- [Walk Directory Tree - Zig Cookbook](https://pyk.sh/cookbooks/zig/walk-directory-tree-collect-matching-files/) - Complete walker example
- [Zig Book - Filesystem Chapter](https://pedropark99.github.io/zig-book/Chapters/12-file-op.html) - Dir.walk() and iterate patterns
- [Zig Book - Memory Chapter](https://pedropark99.github.io/zig-book/Chapters/01-memory.html) - Allocator fundamentals

### Secondary (MEDIUM confidence)

**Zig Build System:**
- [Building Zig Libraries with C Dependencies](https://zig.news/almmiko/building-zig-libraries-with-c-dependencies-25a) - addCSourceFile patterns
- [Let's Learn Zig #4 - Using C Libraries](https://medium.com/@eddo2626/lets-learn-zig-4-using-c-libraries-in-zig-5fcc3206f0dc) - linkLibC and @cImport
- [Zig Build System Official](https://ziglang.org/learn/build-system/) - build.zig reference

**Tree-sitter Community:**
- [zig-tree-sitter](https://github.com/tree-sitter/zig-tree-sitter) - Official Zig bindings (version compatibility unclear)
- [Tree-sitter Memory Leak Case Study](https://cosine.sh/blog/tree-sitter-memory-leak) - Real-world memory management pitfall
- [Building tree-sitter parsers](https://tree-sitter.github.io/tree-sitter/cli/build.html) - parser.c and scanner.c compilation

**Zig 0.15 Migration:**
- [Migrating to Zig 0.15 Roadblocks](https://sngeth.com/zig/systems-programming/breaking-changes/2025/10/24/zig-0-15-migration-roadblocks/) - ArrayList and API changes
- [ArrayList and allocator: updating to 0.15](https://ziggit.dev/t/arraylist-and-allocator-updating-code-to-0-15/12167) - Managed variant changes

### Tertiary (LOW confidence - needs validation)

**Glob Libraries:**
- [zlob](https://github.com/dmtrKovalenko/zlob) - Fast glob library (REQUIRES exact Zig 0.15.2, not confirmed tested)
- [glob.zig](https://github.com/xcaeser/glob.zig) - Pure Zig glob (targets 0.16.0-dev, incompatible with 0.15.2)

**Community Discussions:**
- [How do I match glob patterns in Zig?](https://ziggit.dev/t/how-do-i-match-glob-patterns-in-zig/4769) - Community recommendations
- [std.fs.Dir.walk wrapper](https://ziggit.dev/t/a-small-wrapper-over-std-fs-dir-walker/4411) - Alternative approaches

## Metadata

**Confidence breakdown:**
- Tree-sitter C API: HIGH - Official docs, header file, proven in production
- Zig std.fs.Dir.walk(): HIGH - Stdlib, official examples, cookbook verified
- Tree-sitter/Zig integration: MEDIUM - No official Zig 0.15.2 binding verification, C API direct usage has risk
- Glob libraries: LOW - Version compatibility not field-tested, recommend deferring to Phase 4
- Memory management patterns: MEDIUM-HIGH - Official docs strong, but C/Zig boundary needs testing

**Research date:** 2026-02-14
**Valid until:** ~30 days (2026-03-16) - Zig ecosystem evolving, tree-sitter stable

**Critical items for validation:**
1. Test direct C API @cImport with tree-sitter - confirm no linker/header issues
2. Verify walker.next() path lifetime with actual tests - critical for correctness
3. Build tree-sitter parsers from vendored sources - confirm build.zig patterns work
4. Test with fixture files for .ts/.tsx/.js/.jsx - verify parser routing correct
5. Memory leak testing with both std.testing.allocator (Zig) and valgrind (C)
