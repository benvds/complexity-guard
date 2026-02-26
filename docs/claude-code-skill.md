# Claude Code Skill

ComplexityGuard ships with a Claude Code skill that lets AI coding agents discover and use it without loading full documentation into context.

## What it is

A Claude Code skill is a compact reference file (`skills/<name>/SKILL.md`) that Claude Code reads on demand. When you use Claude Code in a project with the skill installed, Claude can answer questions about ComplexityGuard's CLI interface, flags, configuration options, and common recipes without you pasting documentation manually.

## Why it matters

CLI tools face context bloat when agents need to understand their full capabilities. Without a skill, you would need to paste the CLI reference into every conversation. With a skill, Claude reads it on demand and keeps your context window free for your actual code.

## Installation

Copy the `skills/complexity-guard/` directory into your project's `.claude/skills/` directory:

```sh
# From inside the complexity-guard repo
cp -r skills/complexity-guard/ /path/to/your-project/.claude/skills/

# Or if complexity-guard is already installed globally via npm,
# find the skill in the package directory and copy it
```

The skill is located at `skills/complexity-guard/SKILL.md` in the ComplexityGuard repository.

## How it works

When Claude Code detects a `skills/` directory in your project, it lists available skills and can read any of them on demand. The complexity-guard skill tells Claude:

- All CLI flags and what they do
- Output formats (console, json, sarif, html)
- Configuration file schema (all 12 threshold categories)
- Exit codes for CI integration
- Common `jq` recipes for JSON output
- Metric family descriptions (cyclomatic, cognitive, halstead, structural, duplication)
- Installation methods

## Example interactions

Once the skill is installed, you can ask Claude Code things like:

- "Analyze the complexity of `src/` and show me the worst functions"
- "Set up a health score baseline at 75 and add it to my CI pipeline"
- "Find all functions with cyclomatic complexity above 15 using JSON output"
- "Generate an HTML report for sharing with stakeholders"
- "Add complexity checks to my GitHub Actions workflow"
- "What does the `--fail-health-below` flag do?"

Claude will reference the skill to answer accurately without you needing to provide the CLI documentation.

## Skill location

The skill file is at: `skills/complexity-guard/SKILL.md`

It covers the complete CLI interface in under 400 lines — designed to fit in context without bloat.

## Links

- [CLI Reference](cli-reference.md) — Full documentation for all flags and configuration options
- [Examples](examples.md) — Real-world usage patterns and CI integration recipes
- [Getting Started](getting-started.md) — Installation and first analysis
