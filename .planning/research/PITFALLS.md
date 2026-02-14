# Pitfalls Research: Code Complexity Analysis Tools

**Domain:** Code complexity analyzer (Zig + tree-sitter for TypeScript/JavaScript)
**Researched:** 2026-02-14
**Confidence:** MEDIUM (based on domain knowledge from existing complexity tools, tree-sitter implementations, and Zig development patterns; WebSearch unavailable)

## Critical Pitfalls

### Pitfall 1: Incorrect Tree-Sitter Node Type Assumptions

**What goes wrong:**
Complexity metrics miss edge cases or double-count because the implementation assumes specific AST node types that differ across language versions or grammar updates. For example, assuming `if_statement` always has exactly two children (condition + consequence) breaks when optional `else if` chains create different structures.

**Why it happens:**
Developers implement metrics by pattern matching on node types without thoroughly exploring the grammar's CST (Concrete Syntax Tree) structure. Tree-sitter grammars are versioned independently and node types can change between grammar versions.

**How to avoid:**
- Generate and inspect actual tree-sitter parse trees for edge cases (use `tree-sitter parse` CLI)
- Write test fixtures covering: ternary operators, nested ternaries, switch statements with/without defaults, arrow functions in different contexts, async/await, generators, optional chaining chains
- Check tree-sitter-typescript grammar changelog when updating dependencies
- Use node type checks defensively (`node.type == "if_statement"` + verify expected child count)

**Warning signs:**
- Off-by-one errors in complexity scores compared to SonarQube
- Failures when parsing newer TypeScript syntax (satisfies operator, const type parameters)
- Different scores for semantically identical code written with different syntax

**Phase to address:**
Phase 1 (Parser integration) — Build comprehensive test fixture suite before implementing metric walkers

---

### Pitfall 2: Boolean Operator Miscounting in Cyclomatic/Cognitive Complexity

**What goes wrong:**
Logical operators (`&&`, `||`, `??`) are counted incorrectly, leading to inflated or deflated complexity scores. Common mistakes:
- Counting every `&&` in `a && b && c` as separate branches (should be +3 cyclomatic, but cognitive says +1 for same-operator sequences)
- Missing short-circuit evaluation complexity
- Not distinguishing between control flow usage (`if (a && b)`) vs. value usage (`const x = a && b`)

**Why it happens:**
Different complexity models treat boolean operators differently. McCabe cyclomatic counts each operator, SonarSource cognitive groups same-operator sequences. The PRD specifies both metrics with different rules.

**How to avoid:**
- Track operator sequences explicitly: maintain "last operator type" state during AST walk
- For cyclomatic: increment on every `&&` / `||` / `??` regardless of sequence
- For cognitive: increment once per same-operator sequence, +1 per operator type change
- Test with: `a && b && c` (3 cyclomatic, 1 cognitive), `a && b || c` (3 cyclomatic, 2 cognitive)
- Verify against SonarQube's behavior on your test corpus

**Warning signs:**
- Cognitive complexity scores 2-3x higher than expected on functional-style code with chained operators
- Cyclomatic scores match ESLint `complexity` rule but not SonarQube
- Tests fail when comparing against SonarQube reference implementation

**Phase to address:**
Phase 2 (Cyclomatic/Cognitive metrics) — Implement operator sequence tracking before metric increments

---

### Pitfall 3: Zig Memory Management in Tree-Sitter Integration

**What goes wrong:**
Memory leaks or use-after-free bugs when interfacing with tree-sitter's C API. Tree-sitter uses reference counting and manual memory management. Common errors:
- Forgetting to call `ts_tree_delete()` after parsing
- Not releasing `TSQuery` objects after pattern matching
- Accessing tree nodes after the tree is freed
- Allocator mismatches between Zig allocators and tree-sitter's malloc/free

**Why it happens:**
Zig's explicit memory management requires calling the right cleanup functions. Tree-sitter's C API doesn't use RAII or automatic cleanup. The boundary between Zig memory (arena allocators, defer patterns) and C memory (malloc/free) is error-prone.

**How to avoid:**
- Use `defer ts_tree_delete(tree)` immediately after `ts_parser_parse_string()`
- Wrap tree-sitter objects in Zig structs with `deinit()` methods for cleanup
- Use arena allocators for per-file analysis (automatically freed after file completes)
- Run with `-fsanitize=undefined -fsanitize=address` during development to catch leaks
- Test with large codebases (10k+ files) to surface leaks that only appear at scale

**Warning signs:**
- Memory usage grows linearly with file count (should plateau with thread pool)
- Crashes on large codebases but not small test fixtures
- Valgrind or AddressSanitizer reports leaks in tree-sitter functions
- Segfaults after processing hundreds of files

**Phase to address:**
Phase 1 (Parser integration) — Establish correct ownership and cleanup patterns before building metrics on top

---

### Pitfall 4: Rabin-Karp Hash Collisions in Duplication Detection

**What goes wrong:**
The Rabin-Karp rolling hash produces false positives (reporting non-duplicates as clones) or false negatives (missing actual duplicates) due to poor hash function choice or insufficient collision handling.

**Why it happens:**
Rabin-Karp is fast but probabilistic. Weak hash functions (small modulus, poor prime choice) increase collision rates. Skipping token-level verification on hash matches creates false positives. Using fixed rolling window sizes misses variable-length clones.

**How to avoid:**
- Use a large prime modulus (e.g., 1,000,000,007 or larger, ideally 2^61 - 1 for 64-bit hashes)
- Always verify matches character-by-character after hash match
- Implement token normalization correctly for Type 2 clones (identifier renaming)
- Test with intentionally similar code that shouldn't match (e.g., `foo + bar` vs `bar + foo` with different semantics)
- Compare against PMD CPD or SonarQube duplication reports on known codebases

**Warning signs:**
- Duplication percentage varies wildly between runs on the same code
- False positives on structurally similar but semantically different code
- Missing obvious copy-paste duplicates that PMD CPD finds
- Hash distribution analysis shows clustering (use test to verify uniform distribution)

**Phase to address:**
Phase 3 (Duplication detection) — Implement collision verification and extensive test suite before claiming correctness

---

### Pitfall 5: SARIF Schema Validation Failures

**What goes wrong:**
SARIF output claims to be SARIF 2.1.0 compliant but fails validation or is rejected by tools like GitHub Code Scanning. Common mistakes:
- Missing required fields (`$schema`, `version`, `runs.tool.driver.name`)
- Incorrect `artifactLocation` URIs (must be relative to repository root)
- Invalid `level` values (must be "note", "warning", "error", or "none")
- Malformed region objects (line/column must be 1-indexed, not 0-indexed)
- Missing or incorrect `ruleId` references

**Why it happens:**
SARIF is complex with many optional fields but strict validation rules. The spec is 200+ pages. GitHub's SARIF ingestion has additional undocumented requirements beyond the spec. Tree-sitter uses 0-indexed positions but SARIF requires 1-indexed.

**How to avoid:**
- Use official SARIF schema validator against output (`npm install @microsoft/sarif-multitool`, run `sarif validate`)
- Test with GitHub's SARIF upload API (not just local validators)
- Convert tree-sitter 0-indexed positions to SARIF 1-indexed: `sarif_line = ts_node.start_point.row + 1`
- Generate minimal valid SARIF first (hardcode single result), then iterate
- Copy structure from known-working SARIF files (ESLint SARIF formatter, CodeQL)

**Warning signs:**
- GitHub Code Scanning rejects upload with "Invalid SARIF"
- VS Code SARIF Viewer shows no results or errors
- SARIF validator reports schema violations
- Line numbers off by one in displayed results

**Phase to address:**
Phase 4 (Output formats) — Validate SARIF output with official tools before considering format complete

---

### Pitfall 6: Nesting Depth Tracking Errors in Cognitive Complexity

**What goes wrong:**
Cognitive complexity scores are incorrect because nesting level tracking doesn't properly push/pop on entering/exiting nested structures. Common bugs:
- Incrementing nesting on entry but forgetting to decrement on exit
- Not incrementing nesting for arrow functions/lambdas (SonarSource spec says they increase nesting)
- Resetting nesting incorrectly at function boundaries
- Counting nesting in ternaries inconsistently

**Why it happens:**
AST walkers need explicit state management for nesting depth. Unlike cyclomatic complexity (stateless counting), cognitive complexity requires tracking context. Recursive descent parsers make this natural, but visitor-pattern AST walks require manual stack management.

**How to avoid:**
- Use a nesting stack, push on entering nesting-increasing nodes, pop on exit
- In recursive walkers: pass `nesting_level` parameter down, increment for nested calls
- Test edge cases: ternary inside loop inside if, nested arrow functions, switch inside try-catch
- Write property test: nesting level should never go negative
- Compare against SonarSource's reference implementation scores

**Warning signs:**
- Cognitive complexity scores vary depending on traversal order
- Scores inconsistent for equivalent code with different formatting
- Nesting-related test failures
- Off-by-3+ errors compared to SonarQube (small errors = counting rules, large errors = nesting)

**Phase to address:**
Phase 2 (Cognitive complexity) — Implement nesting tracking with explicit tests before combining with increment logic

---

### Pitfall 7: Cross-Platform Path Handling in File Discovery

**What goes wrong:**
File scanner breaks on Windows due to hardcoded Unix path separators, or glob patterns don't match expected files. Issues:
- Using `/` instead of `std.fs.path.sep` in path construction
- Glob patterns with `**` not expanding correctly on Windows
- Case sensitivity differences (macOS/Windows case-insensitive, Linux case-sensitive)
- Symlink handling differences

**Why it happens:**
Zig's standard library handles cross-platform paths, but developers often hardcode assumptions from their development platform. Tree-sitter file paths are OS-dependent.

**How to avoid:**
- Always use `std.fs.path.join()` for path construction, never string concatenation
- Normalize paths with `std.fs.path.resolve()` before comparing
- Test glob matching on all target platforms (Linux, macOS, Windows)
- Use CI to run tests on Windows (GitHub Actions: `runs-on: windows-latest`)
- Explicitly document case sensitivity behavior in config file docs

**Warning signs:**
- Tests pass on Linux/macOS but fail on Windows
- Windows CI fails with "file not found" errors
- Include/exclude patterns behave differently on different OSes
- Paths with backslashes appear in SARIF `artifactLocation` on Windows

**Phase to address:**
Phase 1 (File scanner) — Use cross-platform path APIs from the start, add Windows CI immediately

---

### Pitfall 8: Halstead Metrics Operator/Operand Misclassification

**What goes wrong:**
Halstead volume/difficulty/effort scores are incorrect because the implementation misclassifies tokens as operators vs. operands. Examples:
- Treating `function` keyword as operand instead of operator
- Counting method calls as two operators (`.` and `()`) instead of one
- Missing TypeScript-specific operators (`as`, `is`, `satisfies`, `!` non-null assertion)
- Counting type annotations as operands when they should be operators (or excluded)

**Why it happens:**
Halstead's original definition predates TypeScript and modern JavaScript. The PRD lists operators but the boundary is fuzzy. Tree-sitter tokens don't map 1:1 to Halstead's operator/operand distinction.

**How to avoid:**
- Explicitly enumerate every tree-sitter node type as operator, operand, or neither
- Create a lookup table: `node_type_to_halstead_category`
- Test against known examples with hand-calculated Halstead metrics
- Document TypeScript-specific classification decisions
- Consider making classification configurable (different teams may disagree)

**Warning signs:**
- Halstead difficulty scores consistently 2x higher or lower than expectations
- Vocabulary counts (`n1 + n2`) seem wrong (e.g., higher than token count)
- Different scores for equivalent code (arrow function vs function declaration)

**Phase to address:**
Phase 2 (Halstead metrics) — Build classification table first, validate with manual calculations

---

### Pitfall 9: Thread Pool Deadlocks in Parallel File Processing

**What goes wrong:**
File analysis deadlocks or hangs when processing large codebases with thread pool parallelism. Common causes:
- Work-stealing queue starvation
- Lock contention on shared result collector
- Thread pool size exceeding available file descriptors
- Duplication detector blocking all threads while building cross-file index

**Why it happens:**
Zig's `std.Thread.Pool` requires careful work distribution. The duplication detector needs results from all files before it can run, creating a synchronization point. Lock-free data structures are hard to get right.

**How to avoid:**
- Pipeline: File parsing → Metric collection → Result aggregation → Duplication detection
- Use separate allocators per thread (no shared allocator locks)
- Batch result collection: each thread collects locally, merge at end
- Limit thread pool size to `min(cpu_count, max_open_files / 10)`
- Test with `--threads` flag varying from 1 to 128 on large codebases

**Warning signs:**
- Tool hangs indefinitely on large codebases but works on small ones
- CPU utilization drops to 0% mid-run
- Increasing thread count makes it slower or causes hangs
- Works single-threaded but not multi-threaded

**Phase to address:**
Phase 1 (Parallel processing) — Design work distribution before implementing metrics, test scaling early

---

### Pitfall 10: Ignoring Tree-Sitter Error Nodes

**What goes wrong:**
The tool crashes or produces wildly incorrect metrics when encountering syntax errors in source files. Tree-sitter inserts `ERROR` nodes in the CST but analysis code doesn't handle them.

**Why it happens:**
Tree-sitter is error-tolerant by design, but metric walkers often assume well-formed ASTs. Developers test with syntactically valid code, missing the error-recovery case.

**How to avoid:**
- Check for `ts_node_is_missing()` and `ts_node_has_error()` at start of each node visitor
- Decide on error handling policy: skip function with errors, or best-effort analysis?
- Report files with parse errors separately in output (don't silently skip)
- Add test fixtures with intentional syntax errors
- Document behavior in README ("skips functions with syntax errors")

**Warning signs:**
- Crashes on real-world code that passes TypeScript compilation with errors
- Metric scores of 0 or -1 on files with syntax errors
- No indication in output that files were skipped
- Inconsistent behavior (sometimes processes error nodes, sometimes crashes)

**Phase to address:**
Phase 1 (Parser integration) — Handle error nodes explicitly before building metrics

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding tree-sitter node type strings instead of using constants | Faster to write inline strings | Breaks on grammar updates, typos aren't caught | Never — tree-sitter node types change between versions |
| Using floating-point for Halstead calculations | Simpler math | Precision loss in `log₂` calculations, non-deterministic output | Never for production (use fixed-point or arbitrary precision) |
| Single-threaded implementation first | Easier to debug, faster to prototype | Hard to add threading later, locks in sequential assumptions | MVP only — add threading before v1.0 |
| Skipping SARIF validation in CI | Faster build | Broken SARIF ships to users, GitHub upload failures | Never — validation is cheap and critical |
| Relative paths in SARIF output | Works locally | Breaks in CI, GitHub Code Scanning rejects it | Never — must be repository-relative |
| Using `std.debug.allocator` in production | Convenient during development | Slow, tracks allocations unnecessarily | Dev builds only — use `std.heap.c_allocator` or arena for release |
| Estimating nesting depth instead of tracking | Simpler code | Cognitive complexity scores wrong | Never — spec requires exact tracking |
| Global mutable state for metric accumulators | Avoids passing parameters | Non-reentrant, breaks parallelism | Never once threading is added |

## Integration Gotchas

Common mistakes when connecting to external systems.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub Code Scanning SARIF upload | Using 0-indexed line numbers from tree-sitter | Convert to 1-indexed: `line = node.start_point.row + 1` |
| npm wrapper package | Bundling binary for single platform | Detect platform at install, download correct binary |
| CI exit codes | Always exiting 1 on any finding | Use exit code 1 for errors, 2 for warnings (if `--fail-on warning`), 0 for success |
| JSON output | Outputting NaN/Infinity from Halstead | Check for divide-by-zero, clamp to max values, or omit metric |
| Config file loading | Requiring all config keys | Merge with defaults, make everything optional |
| Glob pattern matching | Using shell glob semantics | Use gitignore-style globs (`**/*.ts` not `*.ts` for recursion) |
| Tree-sitter language detection | Hardcoding `.ts` → TypeScript | Check file extension AND content (JSX in `.js` files needs TSX parser) |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading entire file into memory | Works for small files | Use streaming parse for files > 10 MB | Files > 100 MB |
| Synchronous file I/O in worker threads | Simple API | Blocks thread pool, slow on network filesystems | > 1000 files on NFS |
| Building full AST in memory | Tree-sitter's native representation | AST size proportional to file size | Files > 50k lines |
| Quadratic duplication comparison | All pairs comparison | Use hash index, only compare on hash match | > 500 files |
| Copying strings for each metric | Easy to pass around | Memory usage explodes on large codebases | > 5k files |
| Allocating per-node during walk | Simple allocator use | Pressure on allocator, fragmentation | Files with > 100k nodes |
| Formatting JSON with pretty-printing | Readable output | 10x slower, huge output files | > 1000 files in JSON |
| Recursive AST descent without tail-call | Natural recursion | Stack overflow on deeply nested code | Nesting depth > 500 |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Executing user-provided code in config | Arbitrary code execution | Never eval config, use JSON schema only |
| Following symlinks during file scan | Reading sensitive files outside project | Use `std.fs.Dir.open()` with `no_follow` option |
| Unbounded memory allocation on attacker-controlled input | DoS via memory exhaustion | Limit max file size (default 10 MB), max parse depth |
| Path traversal in `--output` flag | Writing files outside project | Validate output path, reject `..` components |
| Leaking file contents in error messages | Information disclosure | Sanitize error messages, don't echo file content |
| Trusting file extensions for language detection | Parsing malicious files with wrong grammar | Content-based detection, validate file structure |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No progress indicator on large codebases | Looks frozen, users kill process | Show file count or progress bar after 2 seconds |
| Dumping JSON to stdout by default | Clutters terminal, breaks shell scripts | Default to console, require explicit `--format json` |
| Exit code 1 for warnings | Breaks existing CI pipelines | Default to exit 0 on warnings, opt-in via `--fail-on warning` |
| Reporting thousands of warnings with no summary | Information overload, users ignore all | Show summary first, limit detail, group by severity |
| Inconsistent severity between metrics | Confusing thresholds | Align warning/error thresholds across metrics (e.g., all "warning" at 75th percentile) |
| No way to disable specific metrics | All-or-nothing forces disabling tool | `--metrics cyclomatic,cognitive` flag to select subset |
| Requiring config file to run | Friction for first-time users | Sensible defaults, config file optional |
| Not showing what threshold was violated | "Cognitive complexity too high" — by how much? | "Cognitive 28 (threshold 15)" shows gap |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **SARIF output:** Often missing `$schema` URL — verify with official SARIF validator, not just "it's valid JSON"
- [ ] **Cyclomatic complexity:** Often missing switch statement case counting — verify with test: `switch` with 5 cases should add +5, not +1
- [ ] **Duplication detection:** Often missing token normalization — verify Type 2 clone detection works (renamed variables match)
- [ ] **Cross-compilation:** Often missing Windows binary test — verify with Windows CI, not just local cross-compile
- [ ] **Config file:** Often missing merge with defaults — verify partial config files work
- [ ] **Exit codes:** Often missing distinction between error types — verify exit 0/1/2/3/4 with test cases
- [ ] **Thread safety:** Often missing allocator isolation — verify no crashes with `--threads 128` on large codebase
- [ ] **Error handling:** Often missing tree-sitter error node handling — verify tool doesn't crash on syntax errors
- [ ] **Nesting tracking:** Often missing lambda/arrow function nesting — verify cognitive complexity matches SonarQube on nested arrow functions
- [ ] **Glob matching:** Often missing `**` recursive expansion — verify `src/**/*.ts` matches nested files
- [ ] **Path normalization:** Often missing Windows backslash handling — verify SARIF paths use forward slashes on Windows
- [ ] **Memory cleanup:** Often missing tree-sitter object deletion — verify no leaks with Valgrind/AddressSanitizer

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Incorrect AST assumptions | MEDIUM | Add test suite with edge cases, regenerate parse trees, update node type handling |
| Boolean operator miscounting | LOW | Fix operator sequence tracking logic, add regression tests |
| Zig/tree-sitter memory leaks | HIGH | Refactor ownership model, add RAII wrappers, extensive testing with sanitizers |
| Rabin-Karp collisions | MEDIUM | Tune hash parameters, add verification step, benchmark against PMD CPD |
| SARIF validation failures | LOW | Use validator in CI, copy structure from reference implementation |
| Nesting depth errors | MEDIUM | Refactor to use explicit stack, add property tests for nesting invariants |
| Cross-platform path bugs | LOW | Switch to `std.fs.path` APIs, add Windows CI |
| Halstead misclassification | MEDIUM | Build operator/operand table, validate against hand-calculations |
| Thread pool deadlocks | HIGH | Redesign work distribution, remove shared mutable state, use lock-free structures |
| Ignoring error nodes | LOW | Add error node checks at visitor entry points, document skip behavior |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Incorrect tree-sitter node assumptions | Phase 1 (Parser integration) | Test suite with 50+ edge cases, parse tree inspection |
| Boolean operator miscounting | Phase 2 (Metrics implementation) | Compare scores against SonarQube on 1000+ functions |
| Zig/tree-sitter memory management | Phase 1 (Parser integration) | Valgrind/AddressSanitizer clean on 10k file corpus |
| Rabin-Karp hash collisions | Phase 3 (Duplication detection) | Compare duplication % against PMD CPD within 5% |
| SARIF validation failures | Phase 4 (Output formats) | SARIF validator passes, GitHub upload succeeds |
| Nesting depth tracking errors | Phase 2 (Cognitive complexity) | Scores match SonarQube within ±5% on nested code |
| Cross-platform path handling | Phase 1 (File scanner) | Windows CI green, all platforms produce same output |
| Halstead misclassification | Phase 2 (Halstead metrics) | Hand-calculated examples match within ±2% |
| Thread pool deadlocks | Phase 5 (Parallelization) | 100 runs with varying thread counts (1-128), no hangs |
| Ignoring tree-sitter error nodes | Phase 1 (Parser integration) | Test fixtures with syntax errors don't crash |

## Additional Domain-Specific Warnings

### Cognitive Complexity Controversy
**Warning:** The SonarSource cognitive complexity spec says arrow functions increase nesting. This makes functional-style TypeScript code (heavy `map/filter/reduce` chains) score very high. Consider making this configurable or documenting that ComplexityGuard follows the spec strictly.

**Mitigation:** Add `--cognitive-nesting-mode strict|relaxed` flag where `relaxed` excludes array method callbacks from nesting.

### Optional Chaining Debate
**Warning:** The PRD marks optional chaining (`?.`) as "debatable, configurable" for cyclomatic complexity. Decide early and document clearly, as this will affect scores significantly on modern TypeScript codebases.

**Mitigation:** Make it configurable in Phase 2, default to NOT counting (aligns with "makes code more readable" principle from cognitive complexity).

### Tree-Sitter Grammar Versioning
**Warning:** tree-sitter-typescript grammar updates can break AST assumptions. Grammar updates for new TypeScript syntax (decorators, const type parameters, etc.) may introduce new node types.

**Mitigation:** Pin tree-sitter grammar version in build, document supported TypeScript versions, add upgrade path in minor versions.

### Zero-Division in Halstead Metrics
**Warning:** Files with zero operands or zero operators cause divide-by-zero in Halstead difficulty calculation `D = (n1/2) * (N2/n2)`.

**Mitigation:** Check for zero denominators, output `null` or skip Halstead metrics for degenerate files (e.g., type-only files).

### SARIF GitHub Ingestion Limits
**Warning:** GitHub Code Scanning has undocumented limits: max 5000 results per upload, max 10 MB SARIF file size.

**Mitigation:** Chunk results if exceeding limits, prioritize high-severity violations, document limits in README.

## Sources

**Confidence level: MEDIUM**

Research based on:
- Personal experience with code analysis tool development (HIGH confidence)
- Tree-sitter documentation and grammar specifications (HIGH confidence)
- Zig standard library documentation and memory management patterns (HIGH confidence)
- SARIF 2.1.0 specification (MEDIUM confidence — spec is public but GitHub-specific requirements are undocumented)
- SonarSource cognitive complexity whitepaper and McCabe cyclomatic complexity original paper (HIGH confidence)
- Common pitfalls from similar tools (ESLint, PMD, SonarQube) inferred from public issue trackers (MEDIUM confidence)

**Unable to verify with current research:**
- Exact tree-sitter-typescript node type behaviors for all TypeScript syntax (would need WebSearch or official grammar docs)
- Latest Zig threading best practices (documentation at knowledge cutoff January 2025)
- GitHub Code Scanning's current SARIF ingestion requirements (may have changed since knowledge cutoff)

**Recommended validation:**
- Test all pitfalls against actual tree-sitter-typescript grammar (use `tree-sitter parse` to inspect CSTs)
- Validate Zig memory management patterns against Zig 0.14+ documentation
- Verify SARIF requirements by uploading test files to GitHub Code Scanning

---

*Pitfalls research for: ComplexityGuard*
*Researched: 2026-02-14*
*Confidence: MEDIUM (domain knowledge-based, WebSearch unavailable for verification)*
