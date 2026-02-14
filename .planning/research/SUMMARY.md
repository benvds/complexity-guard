# Project Research Summary

**Project:** ComplexityGuard
**Domain:** Static Code Complexity Analysis Tool (TypeScript/JavaScript)
**Researched:** 2026-02-14
**Confidence:** MEDIUM-HIGH

## Executive Summary

ComplexityGuard is a static analysis tool for TypeScript/JavaScript codebases that measures code complexity through multiple metrics (cyclomatic, cognitive, Halstead, structural) and duplication detection. The recommended approach combines Zig as the implementation language (for single-binary deployment and performance) with tree-sitter for parsing (for error-tolerant, incremental parsing). This stack is prescribed by the PRD and well-validated by similar tools in the ecosystem.

The key architectural insight is to use a two-phase analysis pipeline: parallel per-file metric collection (embarrassingly parallel, scales with CPU cores) followed by cross-file duplication detection (requires global hash index). This structure supports the performance target of < 1 second for 10,000 files while providing comprehensive analysis. The tool must output multiple formats (console, JSON, SARIF, HTML) to serve different use cases: developer workflow, CI/CD integration, GitHub Code Scanning, and stakeholder reporting.

Critical risks center on tree-sitter integration complexity (memory management across the Zig/C boundary, AST node type assumptions that break on grammar updates) and metric correctness (particularly cognitive complexity nesting tracking and Rabin-Karp hash collisions in duplication detection). These risks are well-understood with clear mitigation strategies: comprehensive test fixtures, memory sanitizers, reference implementation comparison (SonarQube, PMD CPD), and SARIF validation. The MVP already has most core metrics implemented; the gap is production-readiness features (configurable thresholds, file ignore patterns, function-level reporting, exit codes).

## Key Findings

### Recommended Stack

Zig + tree-sitter is the optimal choice for this domain. Zig provides single-binary deployment (zero dependencies), excellent C interop for tree-sitter integration, fast compile times, and cross-compilation from any host to all targets. Tree-sitter offers battle-tested TypeScript/JavaScript grammars, error-tolerant parsing (critical for real-world code), and incremental parsing support for future LSP/watch mode features.

**Core technologies:**
- **Zig 0.14.x**: Implementation language — single static binary output, C ABI compatibility, explicit memory management without GC overhead
- **tree-sitter 0.24.x**: Parser framework — proven TS/TSX/JS/JSX grammars, error-tolerant parsing, incremental parsing capability
- **tree-sitter-typescript**: TypeScript + TSX grammars — official grammar maintained by tree-sitter org, covers modern TypeScript syntax
- **Zig stdlib**: JSON (config/output), threading (parallel analysis), filesystem (directory walking) — built-in capabilities, no external dependencies

**Supporting libraries (all built-in or vendored):**
- zig-tree-sitter for idiomatic Zig wrappers (optional, evaluate vs raw C interop)
- std.Thread for thread pool parallelism
- std.json for config loading and JSON/SARIF output
- std.fs for file discovery and glob matching

### Expected Features

The feature landscape divides into three categories: table stakes (must-have), differentiators (competitive advantage), and anti-features (explicitly avoid).

**Must have (table stakes):**
- Cyclomatic complexity — industry standard, universally expected
- Configurable thresholds — per-metric warning/error limits via config file
- Multi-file recursive analysis — essential for real codebases
- JSON output — required for CI/CD integration
- Exit code on threshold violation — CI pipelines need build failures
- Function-level reporting — users need to know which functions are complex
- File ignore patterns — exclude node_modules, build artifacts
- Console output — developer workflow in terminal
- File paths in results — locate problematic code

**Should have (competitive differentiators):**
- Sub-second performance on large codebases — < 1 second for 10K files (key selling point)
- Zero dependencies binary — download and run, no npm/pip install
- Cognitive complexity — more accurate than cyclomatic for human understanding (already implemented)
- SARIF output — GitHub Code Scanning integration (already implemented)
- HTML report generation — visual reports for stakeholders (already implemented)
- Halstead metrics — rare in fast tools (already implemented)
- Structural metrics — nesting depth, parameter count (already implemented)
- Cross-platform single binary — Linux/Mac/Windows without runtime

**Defer (v2+):**
- Historical trend tracking — track complexity changes over time
- Incremental analysis — git diff integration, only analyze changed files
- Duplication detection at scale — only if performance target maintained
- Language expansion — Python, Go, Rust tree-sitter grammars
- IDE extension protocol — LSP-style integration when community requests
- Auto-fix/refactoring — explicitly anti-feature, out of scope

**Anti-features (do NOT build):**
- Auto-fix/refactoring suggestions — complex, often wrong, focus on measurement not prescription
- Built-in code formatting — out of scope, Prettier/ESLint handle this
- Language-agnostic analysis beyond JS/TS — each language needs dedicated support
- Cloud-hosted SaaS platform — operational complexity, privacy concerns
- Real-time IDE integration — provide CLI/JSON for others to consume
- Plugin architecture — API surface, versioning overhead

### Architecture Approach

The standard architecture for static analysis tools applies: CLI layer (arg parsing, config loading, file discovery) → orchestration layer (thread pool coordinator) → analysis pipeline (per-file parallel + cross-file sequential) → aggregation → output formatting. The critical pattern is single-pass multi-collector: run all independent metrics (cyclomatic, cognitive, Halstead, structural) simultaneously during one AST walk, avoiding redundant parsing.

**Major components:**
1. **CLI Layer** (config.zig, scanner.zig) — Parse arguments, load .complexityguard.json, discover files with glob patterns
2. **Thread Pool Coordinator** (thread_pool.zig) — Distribute file analysis across workers, each thread has its own parser instance
3. **Parser Integration** (parser.zig) — C FFI to tree-sitter, wraps TSParser*, handles memory cleanup
4. **AST Walker** (ast/walker.zig) — Generic visitor pattern, dispatches to metric collectors on each node
5. **Metric Collectors** (metrics/*.zig) — Independent collectors for cyclomatic, cognitive, Halstead, structural, composite score
6. **Duplication Detector** (metrics/duplication.zig) — Phase 2, Rabin-Karp rolling hash across all file results
7. **Output Formatters** (output/*.zig) — Console, JSON, SARIF, HTML — each consumes ProjectResult

**Key patterns:**
- **Single-pass multi-collector**: All metrics collect in one AST traversal (4x speedup vs separate passes)
- **Two-phase analysis**: Per-file parallel → cross-file duplication sequential (memory efficiency)
- **Thread-pool work queue**: Dynamic load balancing, scales to CPU core count
- **Visitor pattern**: Metric collectors implement visitNode/exitNode callbacks
- **Arena allocators**: Per-file memory, bulk free after analysis completes

### Critical Pitfalls

1. **Incorrect tree-sitter node type assumptions** — Complexity metrics miss edge cases or double-count due to AST structure assumptions. Mitigation: generate and inspect parse trees for edge cases (ternary operators, switch statements, async/await), build comprehensive test fixtures covering all TypeScript syntax variants.

2. **Boolean operator miscounting in cyclomatic/cognitive complexity** — Logical operators (&&, ||, ??) counted incorrectly. Cyclomatic counts each operator, cognitive groups same-operator sequences. Mitigation: track operator sequences explicitly, test with `a && b && c` (3 cyclomatic, 1 cognitive) vs `a && b || c` (3 cyclomatic, 2 cognitive), verify against SonarQube.

3. **Zig memory management in tree-sitter integration** — Memory leaks or use-after-free at Zig/C boundary. Tree-sitter uses manual memory management (malloc/free), Zig uses explicit allocators. Mitigation: use `defer ts_tree_delete(tree)` immediately after parsing, wrap tree-sitter objects in Zig structs with deinit() methods, run with AddressSanitizer during development.

4. **Rabin-Karp hash collisions in duplication detection** — False positives or false negatives due to poor hash function or missing verification. Mitigation: use large prime modulus (2^61 - 1), always verify matches token-by-token after hash match, test against PMD CPD on known codebases.

5. **SARIF schema validation failures** — Output rejected by GitHub Code Scanning due to missing required fields or incorrect schema. Mitigation: use official SARIF validator (@microsoft/sarif-multitool) in CI, convert tree-sitter 0-indexed positions to SARIF 1-indexed, test with GitHub upload API.

6. **Nesting depth tracking errors in cognitive complexity** — Incorrect scores due to improper push/pop on entering/exiting nested structures. Mitigation: use explicit nesting stack or pass nesting_level parameter in recursive walks, test edge cases (ternary inside loop inside if), compare against SonarQube reference implementation.

7. **Cross-platform path handling** — File scanner breaks on Windows due to hardcoded Unix path separators. Mitigation: always use std.fs.path.join() for path construction, normalize with std.fs.path.resolve(), run CI on Windows/Linux/macOS.

8. **Thread pool deadlocks** — Tool hangs on large codebases due to lock contention or work queue starvation. Mitigation: use separate allocators per thread, batch result collection (merge at end), limit thread pool size to min(cpu_count, max_open_files/10), test with varying thread counts (1-128).

9. **Ignoring tree-sitter error nodes** — Crashes or incorrect metrics when encountering syntax errors. Mitigation: check ts_node_has_error() at start of each visitor, decide on error handling policy (skip or best-effort), report parse errors separately in output.

10. **Halstead metrics operator/operand misclassification** — Incorrect volume/difficulty/effort due to token misclassification. Mitigation: explicitly enumerate every tree-sitter node type as operator/operand/neither, create lookup table, test against hand-calculated examples.

## Implications for Roadmap

Based on combined research, a vertical-slice approach is optimal: build end-to-end pipeline with one metric first (proves architecture), then add remaining metrics (parallel work), then cross-file analysis, then parallelization. This matches the architecture's dependency structure and allows early validation.

### Phase 1: Foundation & Parser Integration
**Rationale:** Core infrastructure before metric logic. Establish correct tree-sitter integration patterns (memory management, error handling) before building complexity metrics on top. Critical pitfalls (memory leaks, cross-platform paths, error nodes) must be addressed here.

**Delivers:** CLI argument parsing, config file loading, file scanner with glob patterns, tree-sitter parser integration with proper memory cleanup, basic test infrastructure

**Addresses:**
- Config loading (table stakes)
- Multi-file recursive analysis (table stakes)
- File ignore patterns (table stakes)
- Cross-platform support (differentiator)

**Avoids:**
- Pitfall 3 (Zig/tree-sitter memory management) — establish cleanup patterns early
- Pitfall 7 (cross-platform paths) — use std.fs.path from start
- Pitfall 10 (ignoring error nodes) — handle parse errors explicitly

**Research flags:** Standard patterns, skip phase-level research. Zig stdlib and tree-sitter C API are well-documented.

### Phase 2: Single Metric Vertical Slice
**Rationale:** Prove the analysis pipeline end-to-end with cyclomatic complexity (simplest metric). This validates AST walker design, visitor pattern, result data structures, and console output before adding complexity. Fast feedback loop for architecture validation.

**Delivers:** AST walker with visitor pattern, cyclomatic complexity collector, FunctionResult/FileResult data structures, console output formatter

**Addresses:**
- Cyclomatic complexity (table stakes, already implemented)
- Console output (table stakes, already implemented)
- Function-level reporting (table stakes, currently missing line numbers)

**Avoids:**
- Pitfall 1 (incorrect node type assumptions) — comprehensive test fixtures
- Pitfall 2 (boolean operator miscounting) — operator sequence tracking

**Research flags:** Skip phase research. Cyclomatic complexity is well-documented (McCabe's original paper), visitor pattern is standard.

### Phase 3: Remaining Core Metrics
**Rationale:** Once pipeline is proven, add cognitive, Halstead, and structural metrics in parallel. All are independent and use the same walker infrastructure. Cognitive complexity is the most complex (nesting tracking), so prioritize testing there.

**Delivers:** Cognitive complexity collector, Halstead metrics collector, structural metrics collector (nesting depth, parameter count, function length), composite health score calculator

**Addresses:**
- Cognitive complexity (differentiator, already implemented, needs validation)
- Halstead metrics (differentiator, already implemented, needs validation)
- Structural metrics (differentiator, already implemented, needs validation)
- Configurable thresholds (table stakes, currently missing)

**Avoids:**
- Pitfall 6 (nesting depth tracking) — explicit stack management, test against SonarQube
- Pitfall 8 (Halstead misclassification) — operator/operand lookup table
- Pitfall 2 (boolean operators) — different rules for cyclomatic vs cognitive

**Research flags:** Moderate research needed for cognitive complexity. SonarSource whitepaper is authoritative but has controversial edge cases (arrow function nesting). Consider `/gsd:research-phase` for cognitive complexity specification details.

### Phase 4: Output Formats
**Rationale:** With metrics proven correct, add remaining output formats for different use cases. JSON and SARIF are critical for CI/CD and GitHub integration. HTML provides stakeholder value. Each format is independent.

**Delivers:** JSON output formatter, SARIF 2.1.0 output formatter, HTML report generator with embedded CSS/JS, exit code logic based on thresholds

**Addresses:**
- JSON output (table stakes, already implemented)
- SARIF output (differentiator, already implemented)
- HTML reports (differentiator, already implemented)
- Exit code on threshold violation (table stakes, currently missing)

**Avoids:**
- Pitfall 5 (SARIF validation failures) — use official validator in CI, test GitHub upload
- SARIF 0-indexed vs 1-indexed line numbers (integration gotcha)

**Research flags:** Skip phase research for JSON/HTML. SARIF may need specification review if validation fails. GitHub Code Scanning has undocumented requirements; use trial-and-error with test uploads.

### Phase 5: Duplication Detection
**Rationale:** Cross-file analysis requires all per-file results in memory, so must come after core metrics are stable. Rabin-Karp algorithm is well-documented but tuning hash parameters for acceptable collision rate requires experimentation.

**Delivers:** Rabin-Karp rolling hash implementation, token normalization for Type 2 clones, CloneGroup detection and reporting, duplication percentage calculation

**Addresses:**
- Duplication detection (differentiator, planned for v1.x)

**Avoids:**
- Pitfall 4 (Rabin-Karp collisions) — large prime modulus, token verification, benchmark against PMD CPD
- Performance conflict with < 1s target — may need sampling or opt-in flag for large codebases

**Research flags:** Needs research. Rabin-Karp basics are standard, but optimal hash parameters, window sizes, and token normalization strategy for TypeScript/JavaScript are domain-specific. Consider `/gsd:research-phase` for duplication detection algorithms and PMD CPD comparison.

### Phase 6: Parallelization & Performance
**Rationale:** Last, because single-threaded version proves correctness first. Parallelization is optimization. Thread pool introduces concurrency bugs (deadlocks, race conditions, allocator contention) that are much harder to debug if metrics are also buggy.

**Delivers:** Thread pool coordinator with work queue, per-thread parser instances, mutex-protected result collection, performance benchmarking, thread count configuration

**Addresses:**
- Sub-second performance target (differentiator, < 1 second for 10K files)
- Thread pool parallelism (implied by performance target)

**Avoids:**
- Pitfall 9 (thread pool deadlocks) — separate allocators per thread, batch result collection
- Shared parser across threads (anti-pattern) — each thread gets own parser instance
- Lock contention on result collection — use thread-local accumulators, merge at end

**Research flags:** Skip phase research. Zig std.Thread.Pool is documented. Verify API details when implementing, but pattern is standard (work queue + worker threads).

### Phase 7: Production Hardening (v1.x)
**Rationale:** After v1.0 launch with core features, add polish and convenience features based on user feedback.

**Delivers:** Historical trend tracking (baseline comparison), incremental analysis (git diff mode), watch mode (re-run on file changes), aggregate project-level metrics, custom output templates

**Addresses:**
- Historical trend tracking (planned v1.x)
- Incremental analysis (planned v1.x)
- Watch mode (planned v1.x)

**Research flags:** Needs research for git integration. Historical tracking and watch mode are standard patterns, but git diff integration and LSP-style file watching have domain-specific considerations. Defer research until post-v1.0.

### Phase Ordering Rationale

- **Phase 1 before 2**: Cannot collect metrics without parser infrastructure. Memory management patterns must be correct before building on top.
- **Phase 2 before 3**: Prove pipeline with simplest metric (cyclomatic) before adding complex metrics (cognitive with nesting tracking).
- **Phase 3 before 4**: Output formats need stable metrics to serialize. Don't format incorrect data.
- **Phase 4 before 5**: Duplication detection produces additional results that need formatting. SARIF can include duplication findings.
- **Phase 5 before 6**: Parallelization is optimization, correctness first. Duplication detector needs correct sequential version before optimizing.
- **Phase 6 before 7**: Performance target must be met before adding convenience features. Watch mode is meaningless if analysis is slow.

This ordering matches the architecture's build order (Foundation → Single Metric → Remaining Metrics → Cross-File → Parallelization) and the feature priority matrix (P1 table stakes → P2 differentiators → P3 future). Each phase delivers testable value and reduces risk incrementally.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Cognitive Complexity)**: SonarSource specification has controversial edge cases (arrow function nesting, optional chaining). May need `/gsd:research-phase` to clarify handling of functional-style TypeScript code.
- **Phase 5 (Duplication Detection)**: Rabin-Karp parameter tuning (hash modulus, window size), token normalization strategy for TypeScript. Recommend `/gsd:research-phase` to study PMD CPD algorithm and compare against SonarQube duplication.
- **Phase 7 (Git Integration)**: Historical tracking and incremental analysis need git diff API research. Defer until post-v1.0, but flag for research when starting phase.

**Phases with standard patterns (skip phase-level research):**
- **Phase 1 (Foundation)**: Zig stdlib APIs, tree-sitter C FFI — well-documented, training data sufficient
- **Phase 2 (Cyclomatic Complexity)**: McCabe's algorithm is textbook material, no ambiguity
- **Phase 4 (Output Formats)**: JSON serialization is trivial, SARIF schema is public (trial-and-error with GitHub is acceptable), HTML templating is standard
- **Phase 6 (Parallelization)**: Thread pool pattern is standard, Zig documentation covers std.Thread.Pool

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zig and tree-sitter are prescribed by PRD. Both are mature, well-documented. Training data from January 2025 is recent enough for stability. Version compatibility understood. |
| Features | MEDIUM-HIGH | Feature landscape based on competitor analysis (SonarQube, ESLint, CodeClimate, Lizard, radon, plato). Core features stable across ecosystem. Edge cases (cognitive complexity nesting rules) need validation. |
| Architecture | MEDIUM | Common patterns for static analysis tools. Single-pass multi-collector, two-phase analysis, thread pool are standard. Zig-specific details (std.Thread.Pool API) not verified with current docs but pattern is sound. |
| Pitfalls | MEDIUM | Based on domain knowledge from similar tools and tree-sitter integration patterns. Memory management, nesting tracking, hash collisions are known issues. Zig 0.14.x specifics not verified with current documentation. |

**Overall confidence:** MEDIUM-HIGH

The stack and feature research is solid (prescribed stack, well-researched features). Architecture and pitfalls are sound in principle but have verification gaps (Zig stdlib API details, tree-sitter grammar node types for TypeScript 5.x syntax). These gaps are acceptable because:
1. Patterns are standard and proven in similar tools (zls, oxlint, Biome)
2. Verification can happen during implementation (test-driven development catches API mismatches early)
3. PRD already validates the high-level approach (complexity metrics, tree-sitter, Zig)

### Gaps to Address

**During Phase 1 (Foundation):**
- Verify Zig 0.14.x std.Thread.Pool API with official documentation (training data may be outdated)
- Confirm tree-sitter C API thread-safety guarantees (each thread needs own parser — verify this is still true)
- Test cross-platform build on Windows CI immediately (don't assume path handling works)

**During Phase 2 (Metrics):**
- Generate comprehensive tree-sitter parse trees for TypeScript 5.x syntax (decorators, const type parameters, satisfies operator) to validate node type assumptions
- Compare cyclomatic complexity scores against ESLint `complexity` rule on 1000+ function corpus to validate correctness

**During Phase 3 (Cognitive Complexity):**
- Resolve arrow function nesting controversy: follow SonarSource spec strictly or make configurable? Decision impacts functional-style TypeScript codebases significantly. Consider user research or default to "relaxed" mode.

**During Phase 4 (SARIF):**
- Upload test SARIF to GitHub Code Scanning to discover undocumented requirements beyond SARIF 2.1.0 spec. Documentation lags reality for GitHub-specific constraints (5000 result limit, 10 MB file size).

**During Phase 5 (Duplication):**
- Benchmark Rabin-Karp hash function collision rate with large TypeScript codebase (e.g., VS Code, TypeScript compiler itself). Tune modulus and window size based on empirical results.
- Decide on duplication detection performance trade-off: is it opt-in flag (`--check-duplication`) or always-on? < 1s target may not be achievable with full duplication on 10K files.

**Post-v1.0:**
- Language expansion (Python, Go, Rust) requires separate tree-sitter grammar research per language. Defer until JavaScript/TypeScript is proven.
- Historical tracking needs git repository integration research (libgit2 bindings? shell out to git CLI?). Not critical for v1.0.

## Sources

### Primary (HIGH confidence)
- **PRD specification** (provided project context) — stack choices (Zig + tree-sitter), metric definitions, performance targets, output formats
- **FEATURES.md research** (own work) — competitor analysis (SonarQube, ESLint, CodeClimate, Lizard, radon, plato) based on training data
- **STACK.md research** (own work) — Zig language documentation, tree-sitter documentation, version compatibility from training data

### Secondary (MEDIUM confidence)
- **ARCHITECTURE.md research** (own work) — common static analysis tool patterns (ESLint, SonarQube, oxlint, Biome architectures) inferred from training data
- **PITFALLS.md research** (own work) — domain knowledge from code analysis tool development, tree-sitter integration patterns, Zig memory management
- **Zig project structure conventions** — training data from Zig community, not verified with official 2026 documentation
- **tree-sitter grammar details** — training data from tree-sitter documentation, node types may have changed for TypeScript 5.x support

### Tertiary (LOW confidence)
- **Cognitive complexity specification edge cases** — SonarSource whitepaper is authoritative but arrow function nesting rules are controversial. Community interpretation varies.
- **GitHub Code Scanning SARIF requirements** — official SARIF 2.1.0 spec is public, but GitHub has undocumented constraints discovered through trial-and-error
- **Rabin-Karp parameters for TypeScript** — general algorithm is well-known, but optimal window size and hash modulus for this domain are empirical

**Verification gaps:**
- Zig 0.14.x stdlib API details not verified (std.Thread.Pool, std.fs.path, std.json) — may have changed since training data (January 2025)
- tree-sitter-typescript grammar node types for TypeScript 5.x — decorators, const type parameters, satisfies operator may introduce new node types
- GitHub Code Scanning SARIF ingestion limits — documentation lags implementation, actual limits unknown without testing

**Mitigation:**
- Phase 1: Verify Zig APIs with official docs during implementation
- Phase 2: Generate parse trees for edge cases with `tree-sitter parse` CLI
- Phase 4: Test SARIF upload with GitHub API in CI
- All phases: Test-driven development catches API mismatches early

---

*Research completed: 2026-02-14*
*Ready for roadmap: yes*
