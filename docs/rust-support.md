# Rust support

ComplexityGuard analyzes `.rs` files in ordinary Cargo packages, workspaces, and mixed-language repositories. Point it at a source directory or workspace root:

```sh
complexity-guard src/
complexity-guard --format sarif . > complexity.sarif
complexity-guard --duplication crates/
```

Directory scans respect `.gitignore` and skip `target/`, `vendor/`, and other generated directories. An explicitly named source file is analyzed even if it is ignored. ComplexityGuard scans files; it does not invoke Cargo, compile the project, or resolve workspace target selection. Use `--include` and `--exclude` for a narrower source set.

## What is measured

- Free functions, methods in `impl` blocks, trait methods with a body, and closures are analyzed separately. Trait signatures without a body are skipped. Methods are named `Type::method` or `Trait::method`; a closure assigned to a simple `let` binding uses that binding name.
- Cyclomatic complexity starts at one and counts `if`/`if let`, `while`/`while let`, `for`, `loop`, `let else`, logical `&&` and `||`, and alternatives in `match`. A `match` with *n* arms adds *n − 1*; multiple patterns in one arm remain one arm. A match guard adds one. `?` is excluded from cyclomatic complexity because it is a common Rust propagation idiom.
- Cognitive complexity adds nesting costs for branches and loops. Structural metrics count executable lines, value parameters (excluding `self` and generic type parameters), and nesting depth.
- Halstead metrics count operators and operands in executable bodies. Rust type arguments, attributes, comments, and macro invocations are not counted in Halstead. Duplication detection normalizes Rust identifiers and compares Rust files with Rust files; it does not report clones across different languages.
- The JSON `export_count` field counts items with an explicit `pub` visibility modifier, including `pub(crate)` and visible methods in `impl` blocks. This is a source-level visibility count, not an exact compiled public API size.
- JSON file entries identify the parser with `language: "rust"` (or `"typescript"` / `"javascript"` in mixed projects). Existing console, SARIF, and HTML reports also include Rust results.

## Rust defaults

Rust uses the existing cyclomatic, Halstead, and nesting defaults. Its cognitive warning/error levels are 26/40, executable line levels are 101/200, and value parameter levels are 8/10. Warnings start just above [Clippy's configurable maxima](https://doc.rust-lang.org/clippy/lint_configuration.html) of 25, 100, and 7; ComplexityGuard's formulas and error levels are its own. The health score uses the matching Rust thresholds. Explicit thresholds in `.complexityguard.json` apply to both Rust and JavaScript/TypeScript files:

```json
{
  "analysis": {
    "thresholds": {
      "cognitive": { "warning": 20, "error": 35 },
      "line_count": { "warning": 80, "error": 160 },
      "params_count": { "warning": 6, "error": 9 }
    }
  }
}
```

## Source-level limitations

Rust macros are not expanded. Complexity inside a macro invocation is therefore not analyzed as normal Rust code. `#[cfg]` and `cfg_attr` are not evaluated: source items are counted even if they would be excluded by a particular target, feature set, or test build. Results should be read as source-level estimates. Use `cargo clippy` alongside ComplexityGuard for compiler-aware diagnostics and idiomatic Rust guidance.
