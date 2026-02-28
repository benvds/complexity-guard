# Launch Strategy

## Launch Philosophy

Launch as a practitioner sharing useful work, not a vendor announcing a product. The developer community responds to authenticity, technical depth, and genuine utility — not marketing polish.

## Pre-Launch Checklist (T-14 to T-1)

### Product Readiness
- [ ] README has benchmark table, clear install instructions, CI recipe, output screenshots
- [ ] npm package published and working (`npm install -g complexity-guard`)
- [ ] GitHub Releases has binaries for all 5 platforms
- [ ] Documentation is complete: getting-started, cli-reference, examples, metric docs
- [ ] `.complexityguard.json` example in README
- [ ] GitHub repository topics tagged: typescript, javascript, code-quality, complexity, static-analysis, rust, tree-sitter

### Content Preparation
- [ ] 60-second terminal recording GIF showing a real analysis (asciinema or similar)
- [ ] Screenshots: console output, SARIF in VS Code (dark + light), HTML report
- [ ] Show HN post body drafted and reviewed
- [ ] Dev.to launch tutorial drafted (CI integration)
- [ ] Dev.to data article drafted (83 projects analysis)
- [ ] Twitter/X launch thread drafted (5 tweets)
- [ ] Reddit posts drafted for r/typescript and r/devops

### Distribution Preparation
- [ ] GitHub Action published to Marketplace (or ready to publish)
- [ ] analysis-tools.dev submission prepared
- [ ] awesome-typescript PR prepared
- [ ] awesome-static-analysis PR prepared
- [ ] Newsletter pitch email drafted for JavaScript Weekly, Bytes, TLDR Dev
- [ ] List of 5 popular TS projects analyzed with screenshots ready

### Community Preparation
- [ ] GitHub Discussions enabled with categories (Show & Tell, Q&A, Ideas, Announcements)
- [ ] CONTRIBUTING.md written
- [ ] 5+ "good first issue" items labeled
- [ ] GitHub Sponsors enabled

## Launch Day (T-0)

**Optimal timing:** Tuesday, Wednesday, or Thursday. 7-9am US Eastern.

### Hour 0: Show HN
Post to Hacker News with the prepared body. This is the primary launch channel.

**Title:** `Show HN: ComplexityGuard – Fast TS/JS complexity analysis, 5 metrics, single binary`

**Rules:**
- Post from a real account with history (not a fresh account)
- No self-upvote rings — this gets you banned
- Respond to every comment within 2 hours
- Be honest about limitations
- Thank people for feedback, even criticism

### Hour 0-1: Dev.to + Social
- Publish CI integration tutorial on dev.to
- Post Twitter/X launch thread
- Share on LinkedIn (different angle: engineering leadership perspective)

### Hour 2-4: Reddit
- Post to r/typescript (technical angle)
- Post to r/devops (CI integration angle)
- Stagger by 2 hours to avoid looking like a spam campaign
- Do NOT cross-post — each subreddit gets unique content

### Hour 4-8: Monitor + Respond
- Respond to every HN comment
- Respond to Reddit comments
- Respond to Twitter replies
- Fix any bugs reported (show responsiveness)
- Share interesting comments/feedback on Twitter

### Hour 8-12: Second Wave
- Submit to analysis-tools.dev directory
- Submit awesome list PRs
- Share in Discord communities: Vercel, Next.js, Remix, Node.js, Rust

## Launch Week (T+1 to T+7)

### Day 1-2
- Publish second dev.to article (83 projects analysis)
- Follow up on any HN feature requests with GitHub issues
- Post to r/javascript and r/rust (staggered)

### Day 3-4
- Send newsletter pitches to JavaScript Weekly, Bytes, TLDR Dev, Node Weekly
- Submit to Console.dev
- Share in Hacker News "Who is hiring?" threads if relevant

### Day 5-7
- Publish a "lessons from launch" reflection on Twitter (meta-content performs well)
- Follow up on any contributor interest
- Announce GitHub Discussions for ongoing community conversation

## Post-Launch (T+8 to T+30)

### Week 2
- Publish cognitive complexity education article
- Start "Complexity of the Week" social series
- Respond to all GitHub issues and discussions

### Week 3
- Publish AI code quality article (the big one)
- Submit to HN as a regular post (not Show HN)
- Pitch Changelog News podcast

### Week 4
- Review launch metrics against targets
- Identify top-performing content and double down
- Plan Month 2 content calendar
- Start working on identified feature requests from community

## Success Metrics

### Launch Day Targets

| Metric | Target | Stretch |
|--------|-------:|--------:|
| HN Show HN points | 50+ | 150+ |
| GitHub stars (day 1) | 100+ | 300+ |
| npm downloads (day 1) | 200+ | 500+ |
| Dev.to article views | 1,000+ | 5,000+ |
| Twitter impressions | 10K+ | 50K+ |
| GitHub issues opened | 5+ | 15+ |

### Launch Week Targets

| Metric | Target | Stretch |
|--------|-------:|--------:|
| GitHub stars (week 1) | 300+ | 1,000+ |
| npm weekly downloads | 500+ | 2,000+ |
| Dev.to total views | 5,000+ | 20,000+ |
| Newsletter mentions | 1+ | 3+ |
| Community contributors (PRs) | 1+ | 5+ |
| Reddit total upvotes | 50+ | 200+ |

### Month 1 Targets

| Metric | Target | Stretch |
|--------|-------:|--------:|
| GitHub stars | 500+ | 2,000+ |
| npm weekly downloads | 1,000+ | 5,000+ |
| Organic Google impressions | 500+ | 2,000+ |
| Email list subscribers | 50+ | 200+ |
| External blog mentions | 3+ | 10+ |

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| HN post doesn't get traction | Reddit and dev.to as backup channels. Try again next week with different angle. |
| Critical bug reported on launch day | Have a release process ready. Ship a fix within hours. Responsiveness > perfection. |
| Negative feedback on a metric | Acknowledge honestly. "That's fair feedback. Here's what we're thinking about for that." |
| Competitor launches same week | Focus on your unique angles. Don't engage in comparison unless asked. |
| Low initial adoption | Double down on content marketing. PMF takes time. 6-month horizon, not 6-day. |

## Launch Narrative Options

Choose the primary angle based on current conversations in the community:

### Angle A: Performance + Depth (Default)
"We built a complexity analyzer in Rust that measures 5 metric families and analyzes 59K functions in 3.3 seconds."
**Use when:** The community is talking about Rust tooling, fast development tools, or benchmark-driven discussion.

### Angle B: AI Code Quality Gate
"AI coding assistants produce code with 40% higher complexity. We built the automated gate."
**Use when:** The community is discussing AI-generated code quality, vibe coding, or technical debt from AI.

### Angle C: SonarQube Alternative
"SonarQube-level complexity analysis without the server, the setup, or the subscription."
**Use when:** Teams are actively complaining about SonarQube complexity or looking for alternatives.

### Angle D: Replacing Abandoned Tools
"plato and complexity-report are abandoned. We built the modern replacement."
**Use when:** Targeting users of legacy tools directly.

## Post-Launch Growth Flywheel

```
Content creates awareness
  -> Developers try the free CLI
    -> Some star the repo / share results
      -> GitHub trending / newsletter mentions
        -> More developers discover the tool
          -> Community grows (Discussions, contributions)
            -> Community creates content (blog posts, tweets)
              -> Content creates awareness (flywheel)
```

The launch is the spark. The flywheel is the growth engine.
