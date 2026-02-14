---
created: 2026-02-14T21:00:10.598Z
title: Add multi-language support via language profile abstraction
area: general
files:
  - src/metrics/cyclomatic.zig
  - src/parser/tree_sitter.zig
  - src/parser/parse.zig
  - src/discovery/filter.zig
  - build.zig
---

## Problem

ComplexityGuard is hardcoded to TypeScript/JavaScript only. Tree-sitter supports 150+ languages, but the codebase has language-specific assumptions baked in at every layer:

- **build.zig**: Only compiles TS/TSX/JS grammars
- **tree_sitter.zig**: `Language` enum has only 3 variants with hardcoded `extern fn` declarations
- **filter.zig**: `TARGET_EXTENSIONS` is hardcoded to `.ts`, `.tsx`, `.js`, `.jsx`
- **parse.zig**: `selectLanguage()` only handles TS/JS extensions
- **cyclomatic.zig**: 20+ hardcoded AST node type strings specific to TS/JS (e.g., `arrow_function`, `ternary_expression`, `for_in_statement`)

The mechanical plumbing per language is ~20 lines, but each language needs its own AST node type mappings since every tree-sitter grammar uses different node names for equivalent constructs (e.g., Python `conditional_expression` vs TS `ternary_expression`, Rust `if_expression` vs TS `if_statement`).

## Solution

1. **Introduce a `LanguageProfile` abstraction** — a struct containing arrays of node type strings for function detection, branch nodes, loop nodes, logical operators, etc. Each language provides its own profile.

2. **Make the cyclomatic calculator language-agnostic** — refactor `isFunctionNode()`, `isBranchNode()`, etc. to use the profile's node lists instead of hardcoded string comparisons.

3. **Create a language registry** — maps file extensions to `(LanguageProfile, TSLanguage)` pairs.

4. **Prioritize high-value languages first**: Python, Go, Java, Rust — each requires studying the grammar's `node-types.json` and writing test fixtures.

5. **Build system**: Each new language adds a git submodule + ~10 lines in `build.zig`.
