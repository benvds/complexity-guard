# Revenue Model & Pricing Strategy

## Revenue Philosophy

ComplexityGuard follows the proven open-core model: the CLI binary is free and open-source forever (MIT license). Revenue comes from services built on top of the core that solve team-scale and enterprise problems the CLI cannot.

The free CLI is the acquisition engine. The cloud layer is the business.

## Revenue Options Analysis

### Option 1: Pure Open Source + Sponsorship

**Model:** Free tool, revenue from GitHub Sponsors and Open Collective corporate sponsors.
**Ceiling:** ~$200K/year (ESLint's 2025 revenue with massive adoption).
**Verdict:** Not viable as a business. Good as supplementary income during early growth. Requires constant fundraising. Tidelift revenue declining industry-wide.

**Action:** Enable GitHub Sponsors and Open Collective from day one. Don't depend on it.

### Option 2: Open-Core + Cloud Dashboard (Recommended Primary Model)

**Model:** Free CLI binary with full functionality. Paid cloud service adds:
- **Trend tracking:** Complexity score over time, delta per PR, regression alerts
- **Team dashboard:** Multi-repo rollup, team comparisons, health score leaderboards
- **PR decoration:** GitHub/GitLab bot that comments complexity analysis on every PR
- **Policy engine:** Custom rules beyond thresholds (e.g., "no function may exceed cognitive 20 in `src/core/`")
- **Jira/Linear integration:** Auto-create refactoring tickets from hotspot analysis

This is the model used by Codecov (coverage), Semgrep (security), and Snyk (vulnerabilities).

**Pricing tiers:**

| Tier | Price | Includes |
|------|-------|---------|
| **Free** | $0 | Full CLI, all metrics, all output formats, CI integration |
| **Team** | $15/contributor/month | Trend tracking, team dashboard, PR bot, 5 repos |
| **Business** | $25/contributor/month | Unlimited repos, policy engine, Jira/Linear integration, API access |
| **Enterprise** | Custom (annual) | SSO/SAML, audit logs, on-prem support, SLA, dedicated CSM |

**Revenue projections (conservative):**

| Milestone | Customers | Avg. Seats | Monthly Revenue | ARR |
|-----------|----------:|----------:|--------------:|-----:|
| Year 1 | 10 teams | 8 | $1,200 | $14K |
| Year 2 | 50 teams | 12 | $9,000 | $108K |
| Year 3 | 200 teams | 15 | $45,000 | $540K |
| Year 3 + 5 enterprise | +5 | 100+ | +$25,000 | +$300K |

### Option 3: GitHub Marketplace App

**Model:** Publish a GitHub App that runs ComplexityGuard on every PR and posts results as a check. Free tier with limited analysis; paid for full metrics and trend history.

**Advantages:** Frictionless discovery through GitHub Marketplace. Low-touch sales. GitHub handles billing.
**Disadvantages:** Platform dependency. GitHub takes a cut. Limited to GitHub ecosystem.

**Verdict:** Excellent distribution channel. Build as part of the cloud dashboard, not as a standalone product. The GitHub App is the acquisition funnel for the cloud dashboard.

### Option 4: Enterprise Compliance Package

**Model:** Annual contracts for organizations that need:
- SOC 2 / ISO 27001 compliance reports showing code quality gates are enforced
- SARIF export to SIEM systems for audit trails
- On-premise deployment (Rust binary already supports this naturally)
- SLA with response time guarantees
- Dedicated customer success manager

**Price range:** $25K-$150K/year depending on organization size.

**Verdict:** High-value but requires sales effort. Target after reaching 500+ free users and 50+ cloud customers. The compliance narrative is compelling: "prove to auditors that code complexity gates are enforced on every merge."

### Option 5: Consulting & Training

**Model:** Paid workshops on code complexity reduction. Complexity audits for legacy codebases. Integration consulting.

**Price range:** $2K-$10K per engagement.

**Verdict:** Good early revenue to bootstrap. Doesn't scale. Use strategically for case study generation and customer development, not as core business.

### Option 6: White-Label / OEM Licensing

**Model:** License the ComplexityGuard engine for embedding in other developer tools, IDEs, or platforms.

**Verdict:** Premature. Revisit if demand emerges from tool vendors.

## Recommended Revenue Roadmap

### Phase 1: Foundation (Months 1-6)
- **Revenue sources:** GitHub Sponsors + Open Collective
- **Focus:** Maximize free adoption, build community, establish brand
- **Target:** 1,000+ weekly npm downloads, 500+ GitHub stars
- **Expected revenue:** $0-2K/month (sponsorship only)

### Phase 2: Cloud MVP (Months 6-12)
- **Revenue sources:** Cloud dashboard (Team tier)
- **Focus:** Ship trend tracking + PR bot. Convert power users to paid.
- **Target:** 10-20 paying teams
- **Expected revenue:** $2K-5K/month

### Phase 3: Scale (Months 12-24)
- **Revenue sources:** Cloud dashboard (Team + Business) + first enterprise contracts
- **Focus:** Multi-repo dashboard, policy engine, Jira integration
- **Target:** 50-100 paying teams + 3-5 enterprise contracts
- **Expected revenue:** $15K-50K/month

### Phase 4: Enterprise (Months 24+)
- **Revenue sources:** Full suite (Cloud + Enterprise + GitHub Marketplace)
- **Focus:** SSO, compliance, on-prem, dedicated support
- **Target:** $500K+ ARR
- **Expected revenue:** $40K-80K/month

## Pricing Psychology

Key insights from developer tools pricing research:

1. **Developers evaluate ROI as time saved / cost.** A tool saving 2 hours of code review per week per developer is easily worth $30/month. The obstacle is friction, not price.
2. **Teams upgrade for reporting.** The #1 reason teams move from free to paid: visibility for non-technical stakeholders. HTML reports already signal this capability.
3. **Enterprise upgrades for compliance.** 78% of enterprise purchases are driven by security/compliance features: SSO, audit logs, SIEM integration.
4. **Per-contributor pricing aligns incentives.** Scales naturally with team size. Avoids penalizing small teams with large codebases (unlike LOC-based pricing).
5. **Free must be genuinely free.** No artificial limits on files, functions, or metrics. The CLI does everything. The cloud adds *new capabilities* (trends, collaboration, automation), not gated versions of existing features.

## Monetization Risks

| Risk | Mitigation |
|------|------------|
| Users stay on free forever | Cloud adds genuinely new value (trends, PR bot) that CLI can't provide |
| Competitors copy the model | First-mover advantage in "complexity-focused, Rust-native" niche |
| Enterprise sales cycles are long | Start with self-serve cloud; enterprise comes from inbound |
| Open source fork competes | MIT license intentional — community goodwill > fork prevention |
| Cloud infrastructure costs | Rust binary is compute-efficient; results are small JSON payloads |
