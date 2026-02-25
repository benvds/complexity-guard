# CLAUDE.md

## Project

ComplexityGuard -- a Rust-based code complexity analyzer for TypeScript/JavaScript. Single static binary using tree-sitter for parsing.

## Build & Test

```sh
cargo build --release    # build binary to target/release/complexity-guard
cargo test               # run all tests
cargo run                # run the binary (debug build)
```

Requires Rust stable toolchain. No Zig required.

## Project Structure

```
src/                    # Rust source code
  main.rs               # entry point, CLI, config, output dispatch
  cli/                  # argument parsing and config resolution
  metrics/              # cyclomatic, cognitive, halstead, structural, duplication
  output/               # console, json, sarif, html renderers
  parser/               # tree-sitter parsing
  pipeline/             # parallel file analysis
  types.rs              # core data structures
Cargo.toml              # Rust project config (single source of truth for version)
Cargo.lock              # dependency lock file
tests/                  # integration tests and test fixtures
  fixtures/             # real-world TS/JS fixture files for testing
  integration_tests.rs  # end-to-end binary tests
  parser_tests.rs       # parser unit tests
.planning/              # roadmap, requirements, phase plans (do not edit unless asked)
```

## GSD Workflow Rules

- When using `/gsd:plan-phase` or `/gsd:quick`, always include tasks to update README.md and docs/ pages (docs/getting-started.md, docs/cli-reference.md, docs/examples.md) to reflect any user-facing changes.
- When using `/gsd:plan-phase` or `/gsd:quick`, if the main README.md is updated, always include tasks to update the publication README files (publication/npm/README.md and publication/npm/packages/*/README.md) to stay in sync.
