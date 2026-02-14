# Feature Landscape

**Domain:** Code Complexity Analysis Tools
**Researched:** 2026-02-14
**Confidence:** MEDIUM (based on training data from established tools; unable to verify with official 2026 documentation due to tool restrictions)

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Cyclomatic complexity | Industry standard metric, universally expected in complexity tools | LOW | Already implemented in ComplexityGuard |
| Configurable thresholds | Users need to set their own acceptable complexity limits per project | LOW | Per-metric warning/error thresholds |
| Multi-file analysis | Analyzing single files is insufficient for real codebases | LOW | Recursive directory scanning |
| JSON output | Required for CI/CD integration and tool interoperability | LOW | Already implemented |
| Exit code on threshold violation | CI pipelines need to fail builds when complexity exceeds limits | LOW | Non-zero exit when thresholds exceeded |
| Function/method-level reporting | Users need to know which specific functions are complex, not just files | MEDIUM | Report per-function metrics with line numbers |
| File ignore patterns | Exclude node_modules, build artifacts, test fixtures from analysis | LOW | .gitignore-style patterns or config file |
| Console output (human-readable) | Developers need to read results in terminal during development | LOW | Already implemented |
| Lines of code metrics | Expected alongside complexity (SLOC, logical lines) | LOW | Context for complexity scores |
| File path in results | Users need to locate the problematic code | LOW | Full or relative file paths in all output formats |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Sub-second performance on large codebases | Most tools are slow; < 1 second for 10K files is exceptional | MEDIUM | Zig performance + tree-sitter parsing. Key selling point. |
| Zero dependencies binary | No npm/pip install, just download and run. Simplifies CI/CD. | LOW | Already achieved with Zig compilation |
| Cognitive complexity | More accurate than cyclomatic for human understanding | MEDIUM | Already implemented. Superior to pure cyclomatic. |
| SARIF output | Modern standard for security/quality tools, integrates with GitHub | MEDIUM | Already implemented. Enables GitHub Code Scanning integration. |
| HTML report generation | Visual, shareable reports for non-technical stakeholders | MEDIUM | Already implemented. Differentiates from CLI-only tools. |
| Cross-platform single binary | Works on Linux/Mac/Windows without runtime dependencies | LOW | Zig advantage. Most competitors need runtime (Node, Python, Java). |
| Halstead metrics | Few tools provide these; useful for code maintainability assessment | MEDIUM | Already implemented. Rare in fast tools. |
| Duplication detection | Finds copy-paste code that increases maintenance burden | HIGH | Rabin-Karp rolling hash. More complex than metrics. |
| Historical trend tracking | Track complexity changes over time (previous vs current) | MEDIUM | Requires storing baseline, comparing runs |
| Incremental analysis | Only analyze changed files (git diff integration) | MEDIUM | Significant performance boost for large repos in CI |
| Structural metrics | Depth of nesting, parameter count, class coupling | MEDIUM | Already implemented. Comprehensive metric coverage. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Auto-fix/refactoring suggestions | Complex to implement correctly, high maintenance, often wrong | Provide clear metrics and let developers refactor. Focus on measurement, not prescription. |
| Built-in code formatting | Out of scope; existing tools (Prettier, ESLint) do this well | Document integration with existing formatters |
| Language-agnostic analysis (beyond JS/TS) | Tree-sitter grammars differ significantly; each language needs dedicated support | Start with TS/JS mastery. Add languages later based on demand. |
| Cloud-hosted SaaS platform | Adds operational complexity, privacy concerns, cost | Remain local-first tool. Users own their data. |
| Real-time IDE integration | Requires editor plugins, protocol implementations, performance overhead | Provide CLI/JSON for IDE extensions to consume. Let IDE ecosystem handle UI. |
| Code quality rules beyond complexity | Scope creep; ESLint/TSLint cover this comprehensively | Stay focused on complexity metrics. Integrate with linters, don't replace them. |
| Graphical desktop application | Maintenance burden, platform-specific code, slow development | HTML reports + terminal output sufficient. Modern web-based reports are portable. |
| Plugin architecture for custom metrics | Adds API surface, versioning, security, performance overhead | Provide comprehensive built-in metrics. Accept feature requests for missing metrics. |

## Feature Dependencies

```
File ignore patterns
    └──requires──> Multi-file analysis

Exit code on threshold violation
    └──requires──> Configurable thresholds

HTML report generation
    └──requires──> File-level metrics
                      └──requires──> Function-level reporting

Historical trend tracking
    └──requires──> JSON output (for baseline storage)
    └──requires──> File ignore patterns (consistent file sets)

Incremental analysis
    └──requires──> Historical trend tracking (to know what changed)
    └──requires──> Git integration

SARIF output
    └──requires──> Function-level reporting (precise locations)
    └──requires──> File path resolution

Duplication detection
    └──enhances──> All metrics (provides additional complexity indicator)
    └──conflicts──> Sub-second performance (computationally expensive on large codebases)
```

### Dependency Notes

- **Exit code requires thresholds:** No point in exit codes without configurable limits
- **HTML reports require structured data:** Need detailed metrics to generate useful visualizations
- **Incremental analysis requires baseline:** Must track what was analyzed before to know what changed
- **SARIF requires precise locations:** GitHub Code Scanning needs file:line:column data
- **Duplication conflicts with performance target:** Full-codebase duplication detection is O(n²) in worst case; may need sampling or opt-in flag

## MVP Recommendation

### Launch With (v1.0)

Minimum viable product - what's needed to validate the concept.

- [x] Cyclomatic complexity - Core metric, universally expected
- [x] Cognitive complexity - Differentiator, more useful than cyclomatic alone
- [x] Halstead metrics - Comprehensive analysis
- [x] Structural metrics - Nesting depth, parameter count
- [x] Console output - Developer workflow
- [x] JSON output - CI/CD integration
- [x] SARIF output - GitHub integration
- [x] HTML report - Stakeholder communication
- [ ] Configurable thresholds - CI/CD exit codes
- [ ] File ignore patterns - Real-world usability
- [ ] Function-level reporting with line numbers - Actionable results
- [ ] Multi-file recursive analysis - Production use

### Add After Validation (v1.x)

Features to add once core is proven.

- [ ] Historical trend tracking - Users request "how is complexity changing?"
- [ ] Incremental analysis (git diff mode) - CI performance optimization
- [ ] Baseline comparison (--compare flag) - Prevent complexity regressions
- [ ] Watch mode (--watch) - Development workflow improvement
- [ ] Custom output templates - Enterprise reporting needs
- [ ] Aggregate metrics (project-level summary) - High-level overview

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Duplication detection at scale - Only if performance target can be maintained
- [ ] Language expansion (Python, Go, Rust) - Once JS/TS is solid
- [ ] IDE extension protocol (LSP-style) - When community requests it
- [ ] Team/organization profiles - If enterprise adoption happens
- [ ] Complexity evolution graphs - If historical tracking proves valuable

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Configurable thresholds | HIGH | LOW | P1 |
| File ignore patterns | HIGH | LOW | P1 |
| Function-level reporting | HIGH | MEDIUM | P1 |
| Exit code on threshold violation | HIGH | LOW | P1 |
| Historical trend tracking | MEDIUM | MEDIUM | P2 |
| Incremental analysis | MEDIUM | MEDIUM | P2 |
| Watch mode | MEDIUM | LOW | P2 |
| Baseline comparison | MEDIUM | LOW | P2 |
| Aggregate metrics | MEDIUM | LOW | P2 |
| Duplication detection | MEDIUM | HIGH | P3 |
| Custom output templates | LOW | MEDIUM | P3 |
| Language expansion | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (blocking v1.0)
- P2: Should have, add when possible (v1.x releases)
- P3: Nice to have, future consideration (v2.0+)

## Competitor Feature Analysis

| Feature | SonarQube | ESLint | CodeClimate | Lizard | Plato | radon | Our Approach |
|---------|-----------|--------|-------------|--------|-------|-------|--------------|
| Cyclomatic complexity | Yes | Yes (rule) | Yes | Yes | Yes | Yes | YES - implemented |
| Cognitive complexity | Yes | No | Yes | No | No | No | YES - implemented (differentiator) |
| Halstead metrics | Yes | No | No | No | Yes | Yes | YES - implemented (differentiator) |
| Duplication detection | Yes | No | Yes | No | No | No | MAYBE - expensive, conflicts with performance |
| SARIF output | Yes | Yes | No | No | No | No | YES - implemented (differentiator) |
| HTML reports | Yes | No | Yes | No | Yes | No | YES - implemented |
| JSON output | Yes | Yes | Yes | Yes | Yes | Yes | YES - implemented |
| Sub-second performance | No (Java) | Yes | No (Ruby) | Yes (Python) | Yes (JS) | Yes (Python) | YES - < 1s for 10K files (differentiator) |
| Zero dependencies | No | No | No | Yes | No | Yes | YES - single binary (differentiator) |
| Historical tracking | Yes (DB) | No | Yes (SaaS) | No | Yes | No | PLANNED - local storage |
| Incremental analysis | No | Yes (cache) | No | No | No | No | PLANNED - git integration |
| Configurable thresholds | Yes | Yes | Yes | Yes | No | Yes | NEEDED - table stakes |
| IDE integration | Yes (plugins) | Yes (native) | Yes (plugins) | No | No | No | NOT PLANNED - anti-feature |

## Category Analysis

### What Makes a Feature "Table Stakes"

Based on analysis of established tools (SonarQube, ESLint, CodeClimate, Lizard, radon, plato):

1. **Core metrics** - Cyclomatic complexity appears in 100% of tools
2. **Threshold configuration** - 83% of tools provide configurable limits
3. **JSON output** - 100% of modern tools provide machine-readable output
4. **File ignore patterns** - Essential for real-world use (node_modules, build dirs)
5. **CI/CD integration** - Exit codes on threshold violation expected by all CI users

### What Makes a Feature "Differentiating"

ComplexityGuard's competitive advantages:

1. **Performance** - < 1 second for 10K files (SonarQube/CodeClimate take minutes)
2. **Zero dependencies** - Single binary (competitors need Java/Ruby/Node/Python)
3. **Cognitive complexity** - Only 33% of tools provide this superior metric
4. **SARIF output** - Modern standard, only 33% support
5. **Comprehensive metrics** - Cyclomatic + Cognitive + Halstead + Structural in one tool

### What Makes a Feature "Anti-Feature"

Features commonly requested but problematic:

1. **Auto-fix** - High complexity, often wrong, out of scope
2. **IDE plugins** - Maintenance burden; provide JSON/LSP for others to consume
3. **SaaS platform** - Privacy concerns, operational cost, local-first principle
4. **Multi-language from day 1** - Scope creep; master TS/JS first

## Implementation Recommendations

### Phase 1: Essential Gaps (blocking v1.0)

1. **Configurable thresholds** - Config file or CLI flags for per-metric limits
2. **File ignore patterns** - Glob patterns to exclude files/directories
3. **Function-level reporting** - Report metrics per function with line numbers
4. **Exit code behavior** - Non-zero exit when thresholds exceeded

### Phase 2: Competitive Features (v1.x)

1. **Historical trend tracking** - Store baseline JSON, compare on subsequent runs
2. **Incremental analysis** - Git diff integration, only analyze changed files
3. **Baseline comparison** - `--compare baseline.json` flag
4. **Watch mode** - Re-run on file changes during development

### Phase 3: Advanced Features (v2.0+)

1. **Duplication detection optimization** - Only if < 1s performance maintained
2. **Language expansion** - Python, Go, Rust tree-sitter grammars
3. **Custom templates** - Allow users to customize HTML/console output

## Sources

**Note:** Research based on training data (January 2025) for established tools. Unable to verify with official 2026 documentation due to tool access restrictions.

- SonarQube: Java-based quality platform with comprehensive metrics (training data)
- ESLint: JavaScript linter with complexity rules (training data)
- CodeClimate: Ruby-based SaaS quality platform (training data)
- Lizard: Python-based complexity analyzer (training data)
- radon: Python complexity tool with Halstead metrics (training data)
- plato: JavaScript complexity visualizer (training data)

**Confidence level:** MEDIUM - Core features stable across tool ecosystem; recent feature additions may not be captured.

---
*Feature research for: Code Complexity Analysis Tools*
*Researched: 2026-02-14*
*Limitations: WebSearch/WebFetch unavailable; analysis based on training data from established tools*
