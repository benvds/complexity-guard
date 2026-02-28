# SEO & Discoverability Strategy

## Goal

Own the search results for "TypeScript complexity analysis" and related queries. SEO is the compound interest channel — slow to start, impossible to beat once established.

## Keyword Strategy

### Tier 1: High Intent (Transactional)
These searchers are actively looking for a tool.

| Keyword | Monthly Volume (est.) | Difficulty | Priority |
|---------|---------------------:|----------:|----------|
| typescript complexity analyzer | 100-300 | Low | Target immediately |
| javascript complexity tool | 200-500 | Medium | Target immediately |
| code complexity checker | 300-800 | Medium | Target Month 1 |
| cyclomatic complexity tool | 200-500 | Low | Target immediately |
| sonarqube alternative javascript | 500-1,000 | Medium | Comparison page |
| code quality cli tool | 100-300 | Low | Target immediately |
| complexity guard | Branded (growing) | Very Low | Own from day 1 |

### Tier 2: Informational (Educational)
These searchers are learning. Content marketing captures them.

| Keyword | Monthly Volume (est.) | Difficulty | Priority |
|---------|---------------------:|----------:|----------|
| cognitive complexity | 2,000-5,000 | Medium | Educational article |
| cyclomatic complexity | 5,000-10,000 | High | Educational article |
| halstead metrics | 500-1,000 | Low | Educational article |
| code complexity metrics | 1,000-3,000 | Medium | Pillar page |
| how to measure code complexity | 500-1,500 | Medium | Tutorial |
| what is cognitive complexity | 1,000-3,000 | Medium | Educational article |

### Tier 3: Comparison (Commercial)
Searchers comparing tools. High conversion intent.

| Keyword | Monthly Volume (est.) | Difficulty | Priority |
|---------|---------------------:|----------:|----------|
| sonarqube vs eslint complexity | 100-300 | Low | Comparison page |
| best code complexity tools 2026 | 200-500 | Medium | Listicle/comparison |
| eslint complexity rule limitations | 100-300 | Low | Blog post |
| plato javascript alternative | 50-200 | Very Low | Migration guide |
| code climate alternative | 200-500 | Medium | Comparison page |

## Page Strategy

### 1. Homepage / Landing Page
**Target:** Branded searches + "typescript complexity analyzer"
**Title:** ComplexityGuard: Fast Complexity Analysis for TypeScript/JavaScript
**H1:** Fast complexity analysis for TypeScript/JavaScript
**Key content:** Value prop, benchmark table, install command, output screenshot

### 2. Comparison Pages
Create dedicated comparison pages for top competitor queries:

- **ComplexityGuard vs SonarQube:** Focus on setup simplicity, speed, cost
- **ComplexityGuard vs ESLint Complexity:** Focus on metric depth, health score, SARIF
- **ComplexityGuard vs CodeClimate (Qlty):** Focus on determinism, self-hosted, free
- **ComplexityGuard vs FTA:** Focus on cognitive complexity, duplication, HTML reports

Format: Honest feature-by-feature comparison table. Acknowledge where competitors are stronger (multi-language support for SonarQube). Win on focus, speed, and depth of complexity analysis.

### 3. Migration Guides
For users of abandoned tools:

- **"Migrating from plato to ComplexityGuard"**
- **"Migrating from complexity-report to ComplexityGuard"**
- **"Migrating from escomplex to ComplexityGuard"**

These pages capture the 19K+ weekly downloads to dead tools.

### 4. Pillar Page: "Code Complexity Metrics"
Long-form reference page covering all five metric families with examples, formulas, and when to use each. Links out to individual metric pages. Targets "code complexity metrics" and related informational queries.

### 5. Documentation SEO
Ensure all docs pages have:
- Descriptive `<title>` tags (not just "Getting Started")
- Meta descriptions
- Schema markup (SoftwareApplication, TechArticle)
- Internal links between related pages
- FAQ schema for common questions

## Directory & Listing Submissions

Submit to all relevant directories on launch day:

| Directory | URL | Status |
|-----------|-----|--------|
| analysis-tools.dev | analysis-tools.dev | Submit immediately |
| awesome-typescript | github.com/dzharii/awesome-typescript | Submit PR |
| awesome-static-analysis | github.com/analysis-tools-dev/static-analysis | Submit PR |
| awesome-devops | github.com/wmariuss/awesome-devops | Submit PR |
| npm | npmjs.com/package/complexity-guard | Already listed |
| crates.io | crates.io | Consider publishing crate |
| alternativeto.com | alternativeto.com | Submit as alternative to SonarQube, plato |
| GitHub Topics | github.com/topics | Tag repository |
| Product Hunt | producthunt.com | Launch day submission |

## Technical SEO

### Site Structure (if/when complexityguard.dev exists)
```
/                           # Landing page
/docs/                      # Documentation hub
/docs/getting-started/      # Install + first run
/docs/cli-reference/        # All flags and options
/docs/metrics/              # Metrics pillar page
/docs/metrics/cyclomatic/   # Individual metric pages
/docs/metrics/cognitive/
/docs/metrics/halstead/
/docs/metrics/structural/
/docs/metrics/duplication/
/blog/                      # Content marketing
/compare/                   # Comparison hub
/compare/sonarqube/
/compare/eslint/
/compare/codeclimate/
/migrate/                   # Migration guides
/migrate/plato/
/migrate/complexity-report/
```

### Schema Markup

```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "ComplexityGuard",
  "applicationCategory": "DeveloperApplication",
  "operatingSystem": "macOS, Linux, Windows",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  }
}
```

## Link Building

### Natural Link Acquisition
- Technical blog posts that other developers reference
- Benchmark data that journalists and bloggers cite
- Comparison pages that review sites link to
- GitHub README badges that link back to the project

### Active Outreach
- **Newsletter editors:** JavaScript Weekly, Bytes, Node Weekly, TLDR Dev
- **"Best of" list maintainers:** "Best TypeScript tools 2026" articles
- **Conference organizers:** CFPs for talks about code complexity
- **Technical bloggers:** Offer to run ComplexityGuard on their codebase for a guest post

## Success Metrics

| Metric | Month 3 | Month 6 | Month 12 |
|--------|--------:|--------:|---------:|
| Indexed pages | 20+ | 40+ | 80+ |
| Organic monthly visitors | 500 | 3,000 | 10,000 |
| Ranking for "typescript complexity" | Top 20 | Top 10 | Top 5 |
| Referring domains | 15+ | 40+ | 100+ |
| Directory listings | 8+ | 12+ | 15+ |
