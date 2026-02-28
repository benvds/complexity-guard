# Email Sequences

## Sequence 1: New User Onboarding (4 emails)

Triggered when a user signs up for the cloud dashboard or newsletter.

---

### Email 1: Welcome + Quick Win (Day 0)

**Subject:** Your first complexity analysis in 30 seconds

**Body:**

Welcome to ComplexityGuard.

Here's the fastest way to see what it can do:

```
npm install -g complexity-guard
complexity-guard src/
```

That's it. You'll see:
- A health score (0-100) for your codebase
- The top complexity hotspots by function
- Color-coded violations by severity

**Three things to try next:**

1. **See the HTML report:** `complexity-guard src/ --format html -o report.html` — open it in your browser for an interactive dashboard with treemap visualization.

2. **Check a specific metric:** `complexity-guard src/ --metrics cognitive` — focus on the metric that matters most to you.

3. **Add to CI:** `complexity-guard src/ --fail-health-below 80` — prevent complexity regression on every merge.

Questions? Reply to this email or open a GitHub Discussion.

[Your name]

---

### Email 2: Understanding Your Score (Day 3)

**Subject:** What your health score actually means

**Body:**

You've run ComplexityGuard. You have a number. Now what?

**Here's how to read your health score:**

- **90-100:** Your codebase is in great shape. Use the baseline + ratchet pattern to keep it there.
- **80-89:** Good overall, with some hotspots. Check the top cognitive complexity functions — those are the hardest to understand and maintain.
- **60-79:** Attention needed. The hotspot ranking in your output shows exactly which functions to refactor first.
- **Below 60:** This is where most legacy codebases live. Don't panic. Set your current score as baseline and improve incrementally.

**The most actionable metric for most teams is cognitive complexity.** It measures how hard code is to understand — not just how many paths exist. High cognitive complexity = the function that makes new engineers ask "what does this do?"

**Quick tip:** Run `complexity-guard src/ --format html -o report.html` and share the HTML report with your team. The treemap shows at a glance where complexity concentrates.

---

### Email 3: CI Integration (Day 7)

**Subject:** The one CI step that prevents complexity creep

**Body:**

Code complexity grows one commit at a time. No single commit is the problem — it's the accumulation.

The baseline + ratchet pattern stops this:

**Step 1: Record your baseline**
```
complexity-guard src/
# Output: Health: 73
```

**Step 2: Add to your CI pipeline**
```yaml
- run: complexity-guard src/ --fail-health-below 73
```

**Step 3: Improve incrementally**
When you refactor and the score improves (say, to 76), update the baseline to 76. Now the CI gate prevents regression to anything below 76.

The score only ever goes up. Your team can add features freely — the gate only fires when someone pushes code that makes the codebase measurably worse.

**Bonus: SARIF for inline PR annotations**
```yaml
- run: complexity-guard src/ --format sarif -o results.sarif
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

Now complexity violations show up as annotations directly on the PR diff. Reviewers see exactly which functions are problematic without running anything locally.

---

### Email 4: Advanced Usage (Day 14)

**Subject:** 3 things power users do with ComplexityGuard

**Body:**

You've been using ComplexityGuard for two weeks. Here's what experienced users do:

**1. Custom weights for your team's priorities**

Every team cares about different things. Adjust the health score weights:

```json
{
  "weights": {
    "cognitive": 0.40,
    "cyclomatic": 0.20,
    "halstead": 0.10,
    "structural": 0.10,
    "duplication": 0.20
  }
}
```

Higher cognitive weight = "readability matters most to us." Higher duplication = "we hate copy-paste."

**2. Selective analysis for different concerns**

```sh
# Quick check: just cyclomatic and cognitive
complexity-guard src/ --metrics cyclomatic,cognitive

# Full check with duplication (slower but thorough)
complexity-guard src/ --duplication
```

**3. JSON output for custom dashboards**

```sh
complexity-guard src/ --format json | jq '.summary.health_score'
```

Pipe the JSON to your own reporting, Grafana, or Slack bot.

---

## Sequence 2: AI Code Quality Nurture (3 emails)

For users who entered through the AI code quality content.

---

### Email 1: The Problem (Day 0)

**Subject:** AI code complexity: the data and what it means

**Body:**

You're here because AI-generated code complexity is on your radar. Here's what the data shows:

- **40% complexity increase** in AI-assisted repositories (CodeAnt AI research)
- **154% increase in PR size** correlated with AI adoption (CodeRabbit report)
- **30% increase** in static analysis warnings post-AI adoption (Sonar analysis)

The pattern: AI assistants produce code with fewer surface-level bugs but systematically higher complexity. It compiles. Tests pass. But Halstead volume creeps up. Cognitive complexity compounds. Nesting depth grows.

Nobody notices until velocity drops.

ComplexityGuard measures exactly these metrics — automatically, on every PR.

```
npm install -g complexity-guard
complexity-guard src/
```

Try it on a PR that was largely AI-generated. The health score might surprise you.

---

### Email 2: The Solution (Day 4)

**Subject:** A complexity gate for AI-assisted development

**Body:**

The fix isn't to stop using AI coding assistants. The fix is to measure what they produce.

**Before/after workflow:**

Before: developer writes prompt -> AI generates code -> quick review -> merge
After: developer writes prompt -> AI generates code -> complexity check -> review flagged functions -> merge

The complexity check takes 3 seconds and catches what human reviewers miss in larger PRs.

**Set up in your pipeline:**
```yaml
- run: |
    npm install -g complexity-guard
    complexity-guard src/ --fail-health-below 80 --format sarif -o results.sarif
```

The SARIF output shows inline annotations on the PR diff. Reviewers see exactly which AI-generated functions have high complexity — and can focus their review time there instead of scanning everything.

---

### Email 3: The Bigger Picture (Day 10)

**Subject:** Complexity budgets: how teams maintain velocity long-term

**Body:**

AI-generated complexity is a specific case of a general problem: complexity creep.

Every codebase has an invisible complexity budget. When you exceed it:
- Onboarding takes longer
- Bug fix cycles slow down
- Features that used to take a day take a week

The teams that maintain velocity long-term are the ones that make complexity explicit and enforce it.

**The baseline + ratchet pattern:**

1. Measure your current health score
2. Set it as your baseline in CI
3. Refactor to improve
4. Ratchet the baseline up after each improvement
5. Repeat

Your complexity budget becomes a real number, enforced on every merge, visible to everyone on the team.

This is what differentiates "we care about code quality" (aspirational) from "we enforce code quality" (operational).

ComplexityGuard makes the second one possible with one line in your pipeline.

---

## Sequence 3: Team Evaluation (3 emails)

For engineering managers or tech leads evaluating complexity tools for their team.

---

### Email 1: The Case for Complexity Analysis (Day 0)

**Subject:** Code complexity: the metric your team is probably missing

**Body:**

Your team probably has:
- Linting (ESLint, Biome)
- Testing (Jest, Vitest)
- Coverage (Codecov, Istanbul)
- Security scanning (Snyk, Semgrep)

What about complexity analysis?

Coverage tells you how much code is tested. Complexity tells you how hard that code is to understand, test, and maintain. A function with 100% coverage but cognitive complexity 30 is still a maintenance liability.

ComplexityGuard adds complexity analysis to your pipeline in 5 minutes:
1. `npm install -g complexity-guard`
2. `complexity-guard src/ --fail-health-below 80`
3. Done.

No server. No subscription. No vendor lock-in. MIT licensed.

---

### Email 2: The Stakeholder Report (Day 5)

**Subject:** Turn complexity data into a refactoring business case

**Body:**

The hardest part of getting refactoring time isn't knowing what to fix. It's convincing someone to give you the time.

ComplexityGuard's HTML report is designed for this conversation:

```
complexity-guard src/ --format html -o report.html
```

Open it in a browser. You get:
- A single health score (easy to track over time)
- A treemap showing where complexity concentrates (visual, intuitive)
- A ranked hotspot list (specific functions to fix)

When your VP asks "where should we invest refactoring time?" — hand them this report.

When your sprint planning asks "what's the impact?" — the health score improvement is the answer.

---

### Email 3: Comparison Guide (Day 10)

**Subject:** How ComplexityGuard compares to SonarQube, ESLint, and alternatives

**Body:**

Choosing a complexity analysis tool? Here's an honest comparison:

**vs. SonarQube:** SonarQube is comprehensive (27 languages, security, bugs, code smells). If you need all of that, use SonarQube. If you need focused complexity analysis for TypeScript/JavaScript without running a server, ComplexityGuard is faster, simpler, and free.

**vs. ESLint complexity rule:** ESLint measures cyclomatic complexity only. No cognitive complexity, no Halstead, no health score, no SARIF output, no HTML reports. ComplexityGuard goes 5x deeper.

**vs. CodeClimate (Qlty):** Qlty is a SaaS platform at $20-30/contributor/month. ComplexityGuard is a free CLI. Different models for different needs.

**vs. FTA:** Both are Rust-based TS analyzers. ComplexityGuard adds cognitive complexity, duplication detection, SARIF output, HTML reports, and configurable thresholds that FTA doesn't have.

The honest answer: if you need multi-language support and security scanning, SonarQube or Semgrep are better choices. If you need deep, fast, focused complexity analysis for TypeScript/JavaScript — that's what ComplexityGuard is built for.
