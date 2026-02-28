# Landing Page Copy

## Hero Section

### Headline
**Fast complexity analysis for TypeScript/JavaScript**

### Subheadline
Five metric families. One health score. Zero setup. Drop a single binary into your CI pipeline and know exactly where complexity lives in your codebase.

### CTA
```
npm install -g complexity-guard
```
[View on GitHub] [Read the Docs]

### Hero Visual
Terminal output showing a real analysis with health score, hotspot rankings, and color-coded violations.

---

## Social Proof Bar

> Benchmarked across 83 open-source projects | 107K files | 321K functions analyzed

---

## Problem Section

### Headline: Your codebase is getting more complex. Can you prove it?

Every team feels it. Some functions are "scary to touch." Code review takes longer every sprint. New engineers take weeks to get productive. But when you ask for refactoring time, the answer is: "Show me the data."

ESLint's complexity rule catches the obvious cases. SonarQube catches everything — if you have time to set up and maintain a server. What if you could get deep complexity analysis from a single command?

---

## Solution Section

### Headline: Five metrics. One score. Three seconds.

ComplexityGuard analyzes your TypeScript and JavaScript code across five complementary metric families and combines them into a single health score (0-100) you can enforce in CI.

### Metric Cards

**Cyclomatic Complexity**
Counts independent code paths. Tells you how many test cases you need. Based on McCabe's metric, aligned with ESLint's counting rules.

**Cognitive Complexity**
Measures how hard code is to understand. Nesting depth matters — deeply nested code costs more than flat branches. Based on SonarSource's specification.

**Halstead Metrics**
Information-theoretic analysis: vocabulary density, volume, difficulty, effort, and estimated bugs. Catches functions with high mental load even when branch count is low.

**Structural Metrics**
Function length, parameter count, nesting depth, file length, and export count. The practical code smell detectors.

**Duplication Detection**
Rabin-Karp rolling hash detects exact and renamed-variable code clones across files. Find your copy-paste debt.

---

## Speed Section

### Headline: Analyzed 59,316 functions in 3.3 seconds

Built in Rust with tree-sitter parsing. No VM overhead, no server, no waiting.

| Project | Files | Functions | Time |
|---------|------:|----------:|-----:|
| lodash | 26 | 79 | 13ms |
| axios | 160 | 472 | 22ms |
| excalidraw | 380 | 1,909 | 74ms |
| vite | 1,182 | 2,639 | 83ms |
| three.js | 1,537 | 10,133 | 705ms |
| vscode | 5,071 | 59,316 | 3.3s |

Parallel analysis across all CPU cores. 3.9x median speedup. 1.2-2.2x lower memory than Node.js-based tools.

---

## Output Section

### Headline: Output for every audience

**Console** — Color-coded terminal output with hotspot rankings. For developers in the flow.

**JSON** — Machine-readable for custom pipelines, artifact storage, and `jq` filtering. For automation.

**SARIF** — GitHub Code Scanning integration. Inline complexity annotations directly on your PR diffs. For code review.

**HTML** — Self-contained interactive report with treemap visualization and sortable tables. For stakeholders.

[Screenshots of each output format]

---

## CI Integration Section

### Headline: One line in your pipeline

```yaml
# GitHub Actions
- name: Complexity Check
  run: |
    npm install -g complexity-guard
    complexity-guard src/ --fail-health-below 80 --format sarif --output results.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

Works with GitHub Actions, GitLab CI, CircleCI, Jenkins, and any CI that can run a binary.

Exit codes: 0 (pass), 1 (errors found), 2 (warnings, with `--fail-on warning`).

---

## Health Score Section

### Headline: One number for your entire codebase

The composite health score (0-100) combines all five metric families with configurable weights:

- **90-100:** Clean codebase, well-maintained
- **80-89:** Good shape, minor hotspots
- **60-79:** Attention needed, refactoring targets identified
- **Below 60:** Significant complexity debt

**Baseline + Ratchet:** Set your score today. Enforce it in CI. Never go backwards. Improve incrementally.

```sh
# Set baseline
complexity-guard src/  # Health: 73

# Enforce in CI
complexity-guard src/ --fail-health-below 73
```

---

## Configuration Section

### Headline: Zero config to start. Full control when you need it.

Works out of the box with sensible defaults. Customize everything when you're ready:

```json
{
  "analysis": {
    "thresholds": {
      "cyclomatic": { "warning": 10, "error": 20 },
      "cognitive": { "warning": 15, "error": 25 }
    }
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15,
    "duplication": 0.20
  },
  "baseline": 73
}
```

---

## CTA Section

### Headline: Know your complexity in 3 seconds

```sh
npm install -g complexity-guard
complexity-guard src/
```

MIT licensed. No telemetry. No cloud dependency. Single binary, zero runtime dependencies.

[View on GitHub] [Read the Docs] [See Benchmarks]

---

## FAQ Section (For SEO)

**Q: How is ComplexityGuard different from ESLint's complexity rule?**
A: ESLint measures cyclomatic complexity only, at the function level, with no aggregation. ComplexityGuard measures five metric families (cyclomatic, cognitive, Halstead, structural, duplication), combines them into a composite health score, and outputs in four formats including SARIF for GitHub Code Scanning.

**Q: How is it different from SonarQube?**
A: SonarQube is a comprehensive code quality platform covering 27+ languages, bugs, security, and code smells. It requires a server (or cloud subscription). ComplexityGuard is a focused complexity analyzer for TypeScript/JavaScript that runs as a single binary with zero setup. If you only need complexity analysis for TS/JS, ComplexityGuard is faster and simpler.

**Q: Does it support TypeScript?**
A: Yes. ComplexityGuard natively parses TypeScript, TSX, JavaScript, and JSX using tree-sitter grammars compiled into the binary.

**Q: Can I use it in CI/CD?**
A: Yes. It works with any CI system. Use `--fail-health-below N` to fail the pipeline when the health score drops below your threshold. Use `--format sarif` for GitHub Code Scanning integration.

**Q: Is it free?**
A: Yes. ComplexityGuard is MIT licensed and free to use. The CLI binary has full functionality with no artificial limits.

**Q: What platforms does it support?**
A: Linux (x86_64, ARM64), macOS (Intel, Apple Silicon), and Windows (x64). Available via npm or direct binary download.
