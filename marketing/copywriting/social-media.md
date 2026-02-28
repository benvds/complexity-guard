# Social Media Copy

## Twitter/X Posts

### Launch Thread (5 tweets)

**Tweet 1/5:**
We just open-sourced ComplexityGuard — a Rust-based complexity analyzer for TypeScript/JavaScript.

5 metric families. Single binary. Analyzes the VS Code codebase (59K functions) in 3.3 seconds.

[terminal screenshot]

**Tweet 2/5:**
Most tools measure one thing. ESLint checks cyclomatic complexity. That's like checking temperature to assess someone's health.

ComplexityGuard measures:
- Cyclomatic (testability)
- Cognitive (readability)
- Halstead (mental load)
- Structural (code smells)
- Duplication (copy-paste debt)

Combined into a health score (0-100).

**Tweet 3/5:**
We benchmarked it across 83 open-source projects (107K files, 321K functions):

lodash: 13ms
axios: 22ms
vite: 83ms
three.js: 705ms
vscode: 3.3s

[benchmark table screenshot]

**Tweet 4/5:**
Drop it into your CI pipeline:

npm install -g complexity-guard
complexity-guard src/ --fail-health-below 80

Outputs: console, JSON, SARIF (GitHub Code Scanning), and interactive HTML reports.

[SARIF screenshot in VS Code]

**Tweet 5/5:**
MIT licensed. No telemetry. No cloud dependency.

npm install -g complexity-guard

[GitHub link]

---

### Standalone Posts (Ongoing)

**AI Code Quality Angle:**
AI coding assistants produce code with 40% higher complexity.

Your tests still pass. Your linter is happy. But Halstead volume is creeping up, cognitive complexity is compounding, and nobody notices until velocity drops.

complexity-guard src/

One command. 3 seconds. Know where you stand.

---

**Benchmark Post:**
We ran ComplexityGuard on [popular project]:

Health Score: [score]
Files: [n] | Functions: [n]
Analysis time: [ms]

Top 3 complexity hotspots:
1. [function] — cyclomatic [n], cognitive [n]
2. [function] — cyclomatic [n], cognitive [n]
3. [function] — cyclomatic [n], cognitive [n]

Surprises? [one insight]

---

**Educational Post:**
Cyclomatic complexity 10 vs. cognitive complexity 10 are not the same thing.

Cyclomatic counts paths. A switch with 10 cases = cyclomatic 10. Easy to test, easy to read.

Cognitive counts understanding cost. 3 nested if-for-if loops = cognitive 10. Hard to follow, hard to reason about.

Your tool should measure both. ComplexityGuard does.

---

**SARIF Demo Post:**
Did you know you can get inline complexity annotations on your GitHub PRs?

1. Run: complexity-guard src/ --format sarif -o results.sarif
2. Upload SARIF to GitHub Code Scanning
3. Complexity violations appear as annotations on the PR diff

No server. No subscription. Just a CI step.

[VS Code SARIF screenshot]

---

**Health Score Post:**
Your codebase health score is a single number from 0-100.

90+: Clean, well-maintained
80-89: Good, minor hotspots
60-79: Needs attention
<60: Time for a serious talk

What's yours?

npm install -g complexity-guard && complexity-guard src/

---

## LinkedIn Posts

### Launch Announcement

**For engineering leaders who want to ship faster without accumulating debt:**

We open-sourced ComplexityGuard — a code complexity analyzer that gives you one number for your entire TypeScript/JavaScript codebase.

The problem it solves: teams feel their code getting harder to work with, but can't prove it with data. Code review takes longer. Onboarding takes weeks. Refactoring requests get deprioritized because "it's not a bug."

ComplexityGuard measures five types of complexity (cyclomatic, cognitive, Halstead, structural, duplication) and combines them into a health score you can track over time and enforce in CI.

Built in Rust. Analyzes 59K functions in 3.3 seconds. One binary, zero setup.

The health score becomes the data point your tech leads have been missing when asking for refactoring time.

MIT licensed: [GitHub link]

---

### AI Code Quality Post

**AI coding assistants increase code complexity by 40%.**

The latest research from Sonar and CodeRabbit shows a pattern: AI-generated code has fewer obvious bugs but systematically higher complexity. PR sizes are up 154%. Code review time is up 91%.

The code compiles. Tests pass. But the codebase is quietly becoming harder to maintain.

This is exactly the kind of decay that complexity analysis catches — cyclomatic and cognitive complexity, Halstead volume, nesting depth. The metrics that human reviewers miss when skimming larger PRs.

We built ComplexityGuard to be the automated complexity gate for the AI-assisted development era. Run it in CI. Get a health score. Prevent regression one commit at a time.

Because the code your AI writes today becomes the code your team maintains tomorrow.

---

## Reddit Posts

### r/typescript

**Title:** I built a complexity analyzer that measures 5 metrics ESLint can't

ESLint's `complexity` rule measures cyclomatic complexity. That's one metric — and it misses a lot.

I built ComplexityGuard, a Rust binary that measures:
- Cyclomatic complexity (path counting, aligned with ESLint's rules)
- Cognitive complexity (SonarSource's spec — nesting matters)
- Halstead metrics (vocabulary density, effort, estimated bugs)
- Structural (function length, params, nesting depth)
- Duplication detection (Rabin-Karp, cross-file)

It combines them into a health score (0-100) and outputs console, JSON, SARIF, or HTML.

Benchmarked on 83 open-source TS/JS projects. The VS Code codebase (59K functions) takes 3.3 seconds.

`npm install -g complexity-guard && complexity-guard src/`

MIT licensed, no telemetry.

GitHub: [link]

Would love feedback from anyone who's tried to set up complexity analysis in their projects.

---

### r/devops

**Title:** Zero-dependency complexity gate for TypeScript/JavaScript CI pipelines

I was looking for a lightweight complexity analysis step to add to our CI pipeline. SonarQube was overkill. ESLint's complexity rule was too basic. The standalone tools (plato, complexity-report) were all abandoned.

So I built ComplexityGuard — a single Rust binary (no runtime deps) that:
- Measures 5 complexity metric families
- Produces a health score (0-100)
- Exits non-zero when thresholds are exceeded
- Outputs SARIF for GitHub Code Scanning integration

Usage in GitHub Actions:
```yaml
- run: |
    npm install -g complexity-guard
    complexity-guard src/ --fail-health-below 80
```

Exit codes: 0=pass, 1=errors, 2=warnings, 3=config error.

Runs on all platforms (Linux, macOS, Windows). Analyzes 1000+ file projects in under 100ms.

MIT licensed. GitHub: [link]

---

### r/ExperiencedDevs

**Title:** How do you measure codebase complexity? What's worked for your team?

I've been working on code complexity analysis for a while and I'm curious about what experienced devs actually use in practice.

Some questions:
- Do you actively measure complexity, or is it more of a "we know it when we see it" thing?
- If you use tools, what's been most useful? ESLint rules, SonarQube, something else?
- For those who've set up complexity gates in CI — how did you pick thresholds that didn't drive the team crazy?
- Do you find cyclomatic complexity useful, or is cognitive complexity (the SonarSource metric) more meaningful in practice?

I'd be especially interested in hearing from anyone who's dealt with AI-assisted coding and noticed changes in code complexity patterns.

(I work on a complexity analysis tool, but this is a genuine question — I've learned the most from hearing how other teams think about this.)
