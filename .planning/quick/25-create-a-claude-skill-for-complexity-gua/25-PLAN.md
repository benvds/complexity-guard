---
phase: quick-25
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .claude/skills/complexity-guard/SKILL.md
  - docs/claude-code-skill.md
  - README.md
  - publication/npm/README.md
  - publication/npm/packages/darwin-arm64/README.md
  - publication/npm/packages/darwin-x64/README.md
  - publication/npm/packages/linux-arm64/README.md
  - publication/npm/packages/linux-x64/README.md
  - publication/npm/packages/windows-x64/README.md
autonomous: true
requirements: [QUICK-25]

must_haves:
  truths:
    - "Claude Code can discover the complexity-guard skill from .claude/skills/"
    - "The skill SKILL.md contains all CLI commands, flags, config options, output formats, and exit codes"
    - "A documentation page explains how to install and use the skill"
    - "README.md links to the skill documentation"
  artifacts:
    - path: ".claude/skills/complexity-guard/SKILL.md"
      provides: "Claude Code skill definition for complexity-guard CLI"
      contains: "name: complexity-guard"
    - path: "docs/claude-code-skill.md"
      provides: "User-facing documentation on installing and using the skill"
      contains: "Claude Code"
    - path: "README.md"
      provides: "Updated main README referencing the skill"
      contains: "claude-code-skill"
  key_links:
    - from: "README.md"
      to: "docs/claude-code-skill.md"
      via: "markdown link in Documentation section"
      pattern: "claude-code-skill"
    - from: "docs/claude-code-skill.md"
      to: ".claude/skills/complexity-guard/SKILL.md"
      via: "references skill location"
      pattern: "\\.claude/skills/complexity-guard"
---

<objective>
Create a Claude Code skill for the ComplexityGuard CLI tool so coding agents can discover and use it without context bloat.

Purpose: CLI tools benefit from skills because agents need to understand capabilities without loading full documentation into context. The skill lets Claude Code query on-demand.
Output: SKILL.md in .claude/skills/complexity-guard/, a docs page explaining usage, README updates.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@README.md
@docs/cli-reference.md
@docs/getting-started.md
@docs/examples.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create the Claude Code skill SKILL.md</name>
  <files>.claude/skills/complexity-guard/SKILL.md</files>
  <action>
Create `.claude/skills/complexity-guard/SKILL.md` following the Claude Code skill format.

YAML frontmatter:
```yaml
---
name: complexity-guard
description: "Analyzes TypeScript/JavaScript code complexity. Use when the user needs to check code quality, measure cyclomatic/cognitive/halstead/structural complexity, detect duplication, generate health scores, or enforce complexity thresholds in CI. Runs as a single static binary with zero dependencies."
---
```

Markdown content should be organized into these sections, derived from the CLI reference and examples docs. Keep under 500 lines total. Be concise but complete — this is the agent's reference, not a tutorial.

**Quick start:**
- Basic analysis: `complexity-guard src/`
- Init config: `complexity-guard --init src/`
- JSON output: `complexity-guard --format json src/`
- Health score check: `complexity-guard --fail-health-below 70 src/`

**Commands and flags** (organized by category):
- General: --help, --version, --init
- Output: --format (console/json/sarif/html), --output, --color, --no-color, --verbose, --quiet
- Analysis: --metrics (cyclomatic,cognitive,halstead,structural,duplication), --duplication, --no-duplication, --threads, --baseline
- File filtering: --include, --exclude (repeatable glob patterns)
- Thresholds: --fail-on (warning/error/none), --fail-health-below N
- Configuration: --config

**Output formats:**
- console (default): human-readable with colors, shows only problems unless --verbose
- json: machine-readable, pipe to jq for filtering
- sarif: SARIF 2.1.0 for GitHub Code Scanning
- html: self-contained report with dashboard, treemap, bar chart (use --output)

**Exit codes:** 0 success, 1 errors/health-below, 2 warnings (--fail-on warning), 3 config error, 4 parse error

**Configuration file:** .complexityguard.json — include the full schema showing files (include/exclude), thresholds (all 12 categories), counting_rules, weights, baseline, analysis (threads, duplication_enabled), output format.

**Common jq recipes:**
- Get health score: `complexity-guard --format json src/ | jq '.summary.health_score'`
- Find error functions: `complexity-guard --format json src/ | jq '.files[].functions[] | select(.status == "error")'`
- Sort by complexity: `complexity-guard --format json src/ | jq '[.files[].functions[]] | sort_by(.cyclomatic) | reverse | .[0:5]'`

**CI integration examples:**
- GitHub Actions: curl download + run with --fail-on warning
- Baseline ratchet: --fail-health-below N or baseline field in config

**Installation:**
- npm: `npm install -g complexity-guard`
- Direct download from GitHub Releases (5 platforms)
- Build from source: `cargo build --release`

**Metric families (brief description of each):**
- cyclomatic: McCabe path counting for testability
- cognitive: SonarSource nesting-aware readability
- halstead: vocabulary density, volume, difficulty, effort, bugs
- structural: function length, params, nesting depth, file length, exports
- duplication: Rabin-Karp cross-file clone detection (opt-in)

Do NOT include `allowed-tools` since complexity-guard is a standard CLI binary, not a Claude Code tool.
  </action>
  <verify>
Test the file exists, has valid YAML frontmatter, and is under 500 lines:
```
test -f .claude/skills/complexity-guard/SKILL.md && head -5 .claude/skills/complexity-guard/SKILL.md | grep -q "name: complexity-guard" && wc -l < .claude/skills/complexity-guard/SKILL.md
```
  </verify>
  <done>SKILL.md exists at .claude/skills/complexity-guard/SKILL.md with valid frontmatter (name, description) and comprehensive CLI reference under 500 lines.</done>
</task>

<task type="auto">
  <name>Task 2: Create docs page and update READMEs</name>
  <files>
    docs/claude-code-skill.md
    README.md
    publication/npm/README.md
    publication/npm/packages/darwin-arm64/README.md
    publication/npm/packages/darwin-x64/README.md
    publication/npm/packages/linux-arm64/README.md
    publication/npm/packages/linux-x64/README.md
    publication/npm/packages/windows-x64/README.md
  </files>
  <action>
**1. Create `docs/claude-code-skill.md`:**

Title: "Claude Code Skill"

Explain:
- What it is: A Claude Code skill that lets coding agents discover and use ComplexityGuard without loading full docs into context
- Why it matters: CLI tools face context bloat when agents need to understand capabilities; skills enable on-demand discovery
- How to install: Copy `.claude/skills/complexity-guard/` into your project's `.claude/skills/` directory, or if complexity-guard is already a dependency/installed, the skill is available at the repo level
- How it works: When you use Claude Code in a project with the skill installed, Claude can reference ComplexityGuard's CLI interface, flags, config options, and common recipes without you pasting docs
- Example interactions: "Analyze the complexity of src/", "Set up a health score baseline", "Add complexity checks to my CI pipeline", "Find the most complex functions in JSON format"
- Link to the SKILL.md location: `.claude/skills/complexity-guard/SKILL.md`
- Link back to CLI Reference for full details

Keep concise — under 80 lines.

**2. Update `README.md`:**

In the Documentation section (after the line with "Releasing"), add a new bullet:
```
- **[Claude Code Skill](docs/claude-code-skill.md)** — Use ComplexityGuard with Claude Code AI agents
```

Do NOT modify any other part of the README.

**3. Update publication READMEs:**

Read each publication README first. For each one that has a Documentation section, add the same Claude Code Skill link. If a publication README does not have a Documentation section, skip it. The publication READMEs are:
- publication/npm/README.md
- publication/npm/packages/darwin-arm64/README.md
- publication/npm/packages/darwin-x64/README.md
- publication/npm/packages/linux-arm64/README.md
- publication/npm/packages/linux-x64/README.md
- publication/npm/packages/windows-x64/README.md
  </action>
  <verify>
Verify docs page exists, README links are correct, and publication READMEs are updated:
```
test -f docs/claude-code-skill.md && grep -q "claude-code-skill" README.md && grep -q "claude-code-skill" publication/npm/README.md
```
  </verify>
  <done>docs/claude-code-skill.md exists with installation and usage instructions. README.md Documentation section links to the new page. Publication READMEs are updated to match.</done>
</task>

</tasks>

<verification>
- `.claude/skills/complexity-guard/SKILL.md` exists with valid YAML frontmatter
- SKILL.md is under 500 lines and covers all CLI flags, config schema, exit codes, and common recipes
- `docs/claude-code-skill.md` exists with clear install/usage instructions
- `README.md` Documentation section includes Claude Code Skill link
- Publication READMEs include matching link
- `grep -r "complexity-guard" .claude/skills/` returns the SKILL.md
</verification>

<success_criteria>
- A Claude Code agent opening a project with this skill can discover complexity-guard's full CLI interface
- Users can find the skill documentation from the README
- All README variants (main + publication) are in sync
</success_criteria>

<output>
After completion, create `.planning/quick/25-create-a-claude-skill-for-complexity-gua/25-SUMMARY.md`
</output>
