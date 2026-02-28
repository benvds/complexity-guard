# Developer Relations Strategy

## Goal

Build trust and adoption within the TypeScript/JavaScript developer community through authentic technical engagement, not marketing. DevRel is the primary acquisition channel for the free CLI tier.

## Channel Strategy

### Channel 1: Hacker News (Primary Launch Channel)

**Why:** HN is where tech leads and staff engineers — our primary ICP — discover new tools. Research shows repositories gain an average of 121 stars in 24 hours, 189 in 48 hours, and 289 in one week from a Show HN post.

**Show HN Post Strategy:**

Title format: `Show HN: ComplexityGuard – Fast TS/JS complexity analysis, single binary, 5 metric families`

Post body (concise, technical, modest):
```
ComplexityGuard analyzes TypeScript/JavaScript codebases for complexity.
It measures cyclomatic, cognitive, Halstead, structural metrics, and
code duplication, combining them into a health score (0-100) you can
enforce in CI.

Built in Rust with tree-sitter. Analyzes the VS Code codebase
(5,071 files, 59,316 functions) in 3.3 seconds. Outputs console,
JSON, SARIF (for GitHub Code Scanning), and interactive HTML reports.

npm install -g complexity-guard
complexity-guard src/

MIT licensed. No telemetry. No cloud dependency.

GitHub: [link]
Docs: [link]
Benchmarks: [link]
```

**Timing:** Tuesday-Thursday, 7-9am US Eastern.

**Rules:**
- No superlatives. Let the benchmarks speak.
- Respond to every comment personally within 2 hours.
- Acknowledge limitations honestly. "We don't have X yet, it's on the roadmap" builds more trust than marketing polish.
- Never edit the title after posting (HN penalizes this).

### Channel 2: Reddit

**Target subreddits and angles:**

| Subreddit | Angle | Post Style |
|-----------|-------|-----------|
| r/typescript | "I built a complexity analyzer that catches what ESLint misses" | Technical, show real output |
| r/javascript | Same as above, focus on JS compatibility | Demo with JS project |
| r/devops | "Zero-dependency complexity gate for CI pipelines" | Focus on SARIF + exit codes |
| r/rust | "Rust + tree-sitter for TypeScript analysis: benchmarks and lessons" | Rust implementation story |
| r/ExperiencedDevs | "How do you measure codebase health?" | Discussion, not promotion |

**Rules:**
- Separate posts for each subreddit, not cross-posts
- Post as a community member sharing work, not a vendor promoting a product
- Lead with value (what problem does this solve?), not features
- r/ExperiencedDevs is discussion-only; don't link to the tool unless asked

### Channel 3: Dev.to / Hashnode

**Format:** Technical tutorials framed as practitioner stories.

Launch articles:
1. "How I Added Complexity Gates to Our TypeScript CI Pipeline" — step-by-step tutorial
2. "We Analyzed 83 Open Source TypeScript Projects — Here's What We Learned" — data-driven, shareable
3. "Cognitive vs. Cyclomatic Complexity: Why You Need Both" — educational, establishes expertise

**Publishing:** At least 2 articles in launch week, then 2/month ongoing.

### Channel 4: Twitter/X

**Strategy:** Build presence in the TypeScript developer community. Engage with technical discussions about code quality, not just promote.

**Content formats:**
- **Benchmark threads:** "We analyzed [popular project]. Here's the complexity breakdown:" with screenshots
- **Insight threads:** "5 things we learned analyzing 321K TypeScript functions"
- **VS screenshots:** Show SARIF annotations in VS Code (highly visual, shareable)
- **Quick tips:** "TIL: The difference between cyclomatic 10 and cognitive 10 is [explanation]"

**Engagement targets:**
- Matt Pocock (TypeScript educator, large following)
- TkDodo (TanStack maintainer)
- Josh Goldberg (typescript-eslint maintainer)
- Kent C. Dodds (testing/quality advocate)

**Rules:** Genuine technical interaction, not pitches. Comment on their content. Share insights. Only mention ComplexityGuard when directly relevant.

### Channel 5: GitHub as a Distribution Channel

**Actions:**
1. **Awesome lists:** Submit to awesome-typescript, awesome-static-analysis, awesome-devops
2. **analysis-tools.dev:** Submit to the directory (lists 64 TypeScript tools already)
3. **GitHub Topics:** Tag repository with `typescript`, `javascript`, `code-quality`, `complexity`, `static-analysis`, `tree-sitter`, `rust`
4. **Discussions:** Enable GitHub Discussions for feature requests and usage questions (indexed by search engines)
5. **README optimization:** Benchmark table, clear install instructions, CI recipe snippet, health score badge

## Launch Sequence

### T-7 days (Pre-Launch)
- [ ] Ensure README has benchmark table, install instructions, CI recipe, HTML report screenshot
- [ ] Submit to analysis-tools.dev directory
- [ ] Prepare Show HN post body
- [ ] Prepare 3 dev.to articles (drafts)
- [ ] Identify 5 popular TS projects to run ComplexityGuard on and screenshot results
- [ ] Create a 60-second GIF showing a real analysis (terminal recording)

### T-0 (Launch Day)
- [ ] Post Show HN (7-9am ET, Tuesday-Thursday)
- [ ] Publish dev.to tutorial article
- [ ] Tweet launch thread with benchmark data and VS Code SARIF screenshot
- [ ] Post to r/typescript and r/devops (not simultaneously, stagger by 2 hours)
- [ ] Monitor HN comments and respond within 2 hours to every question

### T+1 to T+7 (Launch Week)
- [ ] Publish second dev.to article (analysis of 83 projects)
- [ ] Post to r/javascript and r/rust
- [ ] Submit to awesome lists
- [ ] Share in relevant Discord communities (Vercel, Next.js, Remix, Node.js)
- [ ] Email JavaScript Weekly, Bytes, Node Weekly with a brief mention pitch

### T+14 to T+30 (Post-Launch)
- [ ] Publish third dev.to article (cognitive vs. cyclomatic)
- [ ] Write "lessons learned" thread on Twitter/X
- [ ] Follow up with anyone who requested features — show responsiveness
- [ ] Start monthly cadence of community content

## DevRel Copy Templates

### Show HN Comment Response (Feature Request)

> Thanks for the suggestion! [Feature] is actually on our roadmap. Right now we prioritize X, Y, Z, but this is something we've been thinking about. If you're interested, there's a tracking issue at [link] where you can upvote or add context about your use case.

### Show HN Comment Response (Comparison Question)

> Good question. [Competitor] focuses on [their angle], while ComplexityGuard focuses specifically on complexity metrics (cyclomatic, cognitive, Halstead, structural, duplication) and combining them into a composite health score. If you need [competitor's strength], they're a good choice. If you need deep complexity analysis with CI enforcement, that's our wheelhouse.

### Twitter Launch Thread

**Tweet 1/5:**
We just open-sourced ComplexityGuard — a Rust-based complexity analyzer for TypeScript/JavaScript.

5 metric families. Single binary. Analyzes the VS Code codebase (59K functions) in 3.3 seconds.

[screenshot of terminal output]

**Tweet 2/5:**
Most tools measure one thing. ESLint checks cyclomatic complexity. That's like measuring temperature to assess someone's health.

ComplexityGuard measures cyclomatic + cognitive + Halstead + structural + duplication and combines them into a health score (0-100).

**Tweet 3/5:**
We benchmarked it across 83 open-source projects (107K files, 321K functions):

lodash: 13ms
axios: 22ms
vite: 83ms
vscode: 3.3s

[benchmark table screenshot]

**Tweet 4/5:**
Drop it into your CI pipeline:

```
npm install -g complexity-guard
complexity-guard src/ --fail-health-below 80
```

Outputs console, JSON, SARIF (for GitHub Code Scanning annotations), and interactive HTML reports.

**Tweet 5/5:**
MIT licensed. No telemetry. No cloud dependency. One binary, zero runtime deps.

Try it: npm install -g complexity-guard

[GitHub link]

## Success Metrics

| Metric | Launch Week | Month 1 | Month 3 |
|--------|----------:|--------:|--------:|
| GitHub stars | 200+ | 500+ | 1,500+ |
| npm weekly downloads | 500+ | 1,000+ | 3,000+ |
| HN Show HN points | 50+ | — | — |
| dev.to total views | 3,000+ | 10,000+ | 25,000+ |
| Twitter followers | 100+ | 300+ | 800+ |
| Reddit post upvotes | 50+ across subs | — | — |
