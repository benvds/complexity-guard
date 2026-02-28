# Product Marketing Context

## Product Overview

**ComplexityGuard** is a fast, deterministic code complexity analyzer for TypeScript and JavaScript. It ships as a single static Rust binary with zero runtime dependencies, analyzing codebases in seconds using tree-sitter parsing.

**Version:** 0.10.0 | **License:** MIT | **Distribution:** npm + GitHub Releases (all platforms)

## Core Principle

> Deterministic code complexity metrics act as a quality gate to keep long-term complexity budget in check.

Every team has a complexity budget — an invisible ceiling on how complex their codebase can become before velocity collapses. ComplexityGuard makes that budget explicit and enforceable. By measuring five complementary metric families and combining them into a single health score, teams gain objective evidence for architectural decisions and a ratchet mechanism that prevents silent decay.

## Value Proposition

**For engineering teams who ship TypeScript/JavaScript**: ComplexityGuard gives you SonarQube-level complexity insights without the server, the setup, or the subscription. Drop a single binary into your CI pipeline and get actionable complexity analysis in seconds — not minutes.

## What Makes ComplexityGuard Different

### 1. Five Complementary Metric Families

Most tools measure one thing (cyclomatic complexity). ComplexityGuard measures five:

| Metric | What It Catches | Why It Matters |
|--------|----------------|----------------|
| **Cyclomatic** | Independent code paths | Testability — how many test cases you need |
| **Cognitive** | Nested, hard-to-read logic | Understandability — how long it takes a new dev to grok it |
| **Halstead** | Vocabulary density and information volume | Mental load — even low-branch code can have high cognitive cost |
| **Structural** | Length, parameters, nesting depth | Code smells — the "this function does too much" signals |
| **Duplication** | Copy-paste clones (Type 1 & 2) | Maintenance debt — fix it in one place, miss it in three |

### 2. Composite Health Score (0-100)

A single number that combines all metric families with configurable weights. Teams define what "complexity" means to them:

- **Default weights:** Cognitive 30%, Cyclomatic 20%, Duplication 20%, Halstead 15%, Structural 15%
- **Interpretation:** 90+ green, 80-89 good, 60-79 needs attention, <60 significant debt
- **Baseline + ratchet:** Set your score once, enforce it in CI, improve over time

### 3. Native Rust Performance

| Project | Files | Functions | Time |
|---------|------:|----------:|-----:|
| lodash | 26 | 79 | 13ms |
| axios | 160 | 472 | 22ms |
| vite | 1,182 | 2,639 | 83ms |
| vscode | 5,071 | 59,316 | 3.3s |

Benchmarked across 83 open-source projects (107k files, 321k functions). 3.9x median parallelization speedup. 1.2-2.2x lower memory than Node.js-based tools.

### 4. Zero Setup, Multiple Outputs

- **Console:** Color-coded terminal output with hotspot rankings
- **JSON:** Machine-readable for custom pipelines
- **SARIF 2.1.0:** GitHub Code Scanning integration with inline PR annotations
- **HTML:** Self-contained interactive reports with treemap visualization

### 5. CI-Native Quality Gate

```sh
# Fail CI if health score drops below 80
complexity-guard src/ --fail-health-below 80
```

Exit codes designed for pipelines: 0 (success), 1 (errors), 2 (warnings), 3 (config error), 4 (parse error).

## Target Audiences

### Primary: Tech Leads & Staff Engineers
**Motivation:** Prove complexity is real, prioritize refactoring, prevent regression
**Entry point:** HN, GitHub, technical blog posts
**Value message:** "Objective evidence for the refactoring sprint you've been arguing for"

### Secondary: Engineering Managers
**Motivation:** Justify refactoring investment, track technical debt trends, benchmark team health
**Entry point:** HTML reports shared by tech leads, complexity trends in sprint retros
**Value message:** "A single number your VP Engineering can understand"

### Tertiary: DevOps / Platform Engineers
**Motivation:** Add quality gates without operational overhead
**Entry point:** CI integration docs, SARIF output for existing GitHub setup
**Value message:** "One binary, one line in your pipeline, zero servers to maintain"

### Emerging: AI-Assisted Development Teams
**Motivation:** Guard against silent complexity growth from Copilot/Cursor/Claude-generated code
**Entry point:** Content about AI code quality crisis
**Value message:** "The complexity gate for AI-assisted TypeScript development"

## Positioning Statement

**For** TypeScript/JavaScript engineering teams **who** need to keep code complexity in check, **ComplexityGuard** is a fast complexity analyzer **that** combines five metric families into one enforceable health score. **Unlike** SonarQube (heavyweight, expensive), ESLint's complexity rule (single metric, no aggregation), or abandoned tools like plato and complexity-report, **ComplexityGuard** runs as a zero-dependency binary in seconds with actionable output for both developers and stakeholders.

## Key Messages

### Tagline
"Fast complexity analysis for TypeScript/JavaScript"

### One-liner
"Drop a single binary into your CI pipeline and get SonarQube-level complexity analysis in seconds."

### Elevator Pitch (30 seconds)
"ComplexityGuard is a Rust-based complexity analyzer for TypeScript and JavaScript. It measures five different complexity metrics — cyclomatic, cognitive, Halstead, structural, and duplication — and combines them into a single health score you can enforce in CI. It analyzes the entire VS Code codebase in 3 seconds. No server, no subscription, no runtime dependencies. Just one binary and one line in your pipeline."

### For the AI Code Quality Angle
"AI coding assistants produce code with 40% higher complexity. ComplexityGuard catches the complexity debt that Copilot and Cursor quietly accumulate — before it compounds."

## Competitive Positioning Matrix

| Dimension | ComplexityGuard | SonarQube | ESLint | FTA | Plato/escomplex |
|-----------|:-:|:-:|:-:|:-:|:-:|
| Metrics | 5 families | Many (complexity secondary) | Cyclomatic only | Halstead + Cyclomatic | Halstead + Cyclomatic |
| Speed | Rust native | Slow (JVM) | Slow (Node.js) | Rust native | Node.js |
| Setup | Zero config | Server required | Config file | npm install | npm install |
| Health score | Yes (composite) | Yes (quality gate) | No | Yes (FTA score) | Maintainability index |
| SARIF output | Yes | No (own format) | With config | No | No |
| HTML reports | Yes (interactive) | Yes (dashboard) | No | No | Yes (basic) |
| Duplication | Yes (Rabin-Karp) | Yes | No | No | No |
| Maintenance | Active | Active | Active | Active | Abandoned |
| Cost | Free (MIT) | From ~30/mo | Free | Free | Free |
