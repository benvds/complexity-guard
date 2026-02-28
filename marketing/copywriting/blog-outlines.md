# Blog Post Outlines

## Launch Content (Week 1)

### Post 1: "We Analyzed 83 Open Source TypeScript Projects. Here's What We Found."

**Type:** Data-driven analysis (high share potential)
**Target:** Dev.to + project blog
**SEO:** "typescript code complexity analysis"
**Word count:** 1,500-2,000

**Outline:**
1. Introduction: What does "code complexity" look like across the TypeScript ecosystem?
2. Methodology: 83 projects, 107K files, 321K functions, measured with ComplexityGuard
3. Key findings:
   - Average health score distribution (most projects score 90-96)
   - Correlation between project size and complexity
   - Most common complexity hotspot patterns
   - Which metric family catches the most violations?
4. Interesting individual results (highlight well-known projects)
5. What "good" looks like: the characteristics of high-scoring projects
6. Try it yourself: `npm install -g complexity-guard`

---

### Post 2: "Add a Complexity Gate to Your GitHub Actions Pipeline in 5 Minutes"

**Type:** Tutorial (high utility, SEO value)
**Target:** Dev.to + project blog
**SEO:** "code complexity github actions" "complexity ci pipeline"
**Word count:** 800-1,200

**Outline:**
1. Why complexity gates matter (2 paragraphs, not a lecture)
2. Step 1: Install in your workflow
3. Step 2: Run analysis and interpret the output
4. Step 3: Set your baseline health score
5. Step 4: Configure SARIF for inline PR annotations
6. Full workflow YAML example
7. Customizing thresholds for your team

---

## Month 1 Content

### Post 3: "What Is Cognitive Complexity? A Developer's Guide"

**Type:** Educational (evergreen SEO)
**Target:** Project blog (canonical) + dev.to cross-post
**SEO:** "cognitive complexity" "what is cognitive complexity"
**Word count:** 2,000-2,500

**Outline:**
1. The problem with cyclomatic complexity alone
   - Switch with 10 cases: cyclomatic 10, easy to understand
   - 3 nested if-for-if: cyclomatic 4, hard to understand
2. How cognitive complexity works (SonarSource specification)
   - Increments: control flow breaks
   - Nesting penalty: +1 per nesting level
   - Structural vs. fundamental complexity
3. Real examples from TypeScript code
   - Side-by-side: same cyclomatic, different cognitive
   - When cognitive catches what cyclomatic misses
4. How to measure cognitive complexity
   - Using ComplexityGuard
   - Interpreting the numbers (thresholds, what's "too high")
5. Reducing cognitive complexity (practical refactoring patterns)

---

### Post 4: "AI-Generated Code Has 40% Higher Complexity: What That Means for Your Team"

**Type:** Data-driven thought leadership (high share potential)
**Target:** Dev.to + project blog + HN submission
**SEO:** "ai generated code complexity" "ai code quality"
**Word count:** 1,500-2,000

**Outline:**
1. The data: what research shows about AI-generated code complexity
   - 40% complexity increase in AI-assisted repos
   - 154% increase in PR sizes
   - 30% increase in static analysis warnings
2. Why this happens (AI optimizes for "works", not "maintainable")
3. The silent accumulation problem (no single commit is bad)
4. What to do about it
   - Automated complexity checks on every PR
   - SARIF annotations to focus reviewer attention
   - Baseline + ratchet to prevent regression
5. Setting up the workflow with ComplexityGuard

---

## Month 2 Content

### Post 5: "The Baseline + Ratchet Pattern: Improving Code Quality Without Breaking Existing Code"

**Type:** Strategic guide (mid-funnel, ICP 1 & 3)
**Target:** Project blog
**SEO:** "code quality ratchet" "baseline code quality ci"
**Word count:** 1,200-1,500

**Outline:**
1. The problem: "fix everything at once" doesn't work
2. The baseline + ratchet pattern explained
   - Set baseline at current state
   - Enforce in CI: score can never decrease
   - After improvement, ratchet up
3. Implementation with ComplexityGuard
4. Team dynamics: why this approach gets buy-in
5. Real scenario: from health score 67 to 85 in 3 months

---

### Post 6: "Complexity Comparison: React vs Vue vs Svelte"

**Type:** Data-driven comparison (viral potential)
**Target:** Dev.to + social media
**SEO:** "react vue svelte comparison complexity"
**Word count:** 1,500-2,000

**Outline:**
1. Methodology: analyzed core libraries of each framework
2. Health scores compared
3. Complexity hotspot patterns (how each framework structures complex logic)
4. What this means for users of each framework
5. Caveat: complexity of the framework != complexity of apps built with it

---

## Month 3+ Content

### Post 7: "Why Your ESLint Complexity Rule Isn't Catching the Real Problems"

**Type:** Problem-aware educational (top of funnel)
**Target:** Project blog (SEO)
**SEO:** "eslint complexity rule" "eslint complexity not working"
**Word count:** 1,200-1,500

**Outline:**
1. What ESLint's complexity rule actually measures
2. What it misses (cognitive complexity, Halstead, structural)
3. The false positive problem (switch statements)
4. The false negative problem (deeply nested logic)
5. What comprehensive complexity analysis looks like
6. How to add deeper analysis alongside ESLint

---

### Post 8: "Halstead Metrics Explained: When Branch Counting Isn't Enough"

**Type:** Educational (evergreen SEO)
**Target:** Project blog
**SEO:** "halstead metrics" "halstead complexity"
**Word count:** 1,500-2,000

**Outline:**
1. What Halstead metrics measure (information theory background)
2. The five sub-metrics: vocabulary, length, volume, difficulty, effort
3. When Halstead catches what cyclomatic/cognitive miss
   - Expression-heavy functions (parsers, math)
   - Large vocabulary with low branching
4. Real examples from TypeScript
5. How to interpret Halstead thresholds
6. Practical use: combining Halstead with other metrics

---

### Post 9: "From 0 to Quality Gate: A Step-by-Step Guide for Engineering Teams"

**Type:** Comprehensive tutorial (bottom of funnel)
**Target:** Project blog
**SEO:** "code quality gate setup" "typescript quality pipeline"
**Word count:** 2,500-3,000

**Outline:**
1. What a quality gate is and why it matters
2. Layer 1: Linting (ESLint/Biome)
3. Layer 2: Testing (coverage thresholds)
4. Layer 3: Complexity analysis (ComplexityGuard)
5. Layer 4: Security scanning
6. Putting it all together in CI
7. Maintaining and evolving your quality gates

---

### Post 10: "What 'Good' Code Complexity Looks Like (Based on Real Data)"

**Type:** Data-driven authority piece
**Target:** Project blog + dev.to
**SEO:** "good code complexity" "code complexity benchmarks"
**Word count:** 1,500-2,000

**Outline:**
1. "What should my complexity score be?" — the most common question
2. Data from 83 open-source projects
3. Distribution of health scores, cyclomatic, cognitive
4. Characteristics of high-scoring projects
5. Characteristics of low-scoring projects
6. Setting realistic thresholds for your team
7. Benchmarking against the ecosystem

## Publishing Calendar Summary

| Month | Posts | Focus |
|-------|------:|-------|
| Launch | 2 | Data showcase + CI tutorial |
| Month 1 | 2 | Cognitive complexity education + AI code quality |
| Month 2 | 2 | Ratchet pattern + framework comparison |
| Month 3 | 2 | ESLint gaps + Halstead education |
| Month 4 | 2 | Quality gate guide + benchmarks |
| Ongoing | 2/month | Mix of educational, data-driven, and tutorial |
