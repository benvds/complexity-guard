---
phase: quick-27
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/public-projects.json
autonomous: true
requirements: [QUICK-27]
---

<objective>
Add 8 new repos to fill all missing category/repo_size/quality_tier combos, then restrict quick test set to small repos only (9 repos total: one per category × quality_tier combo).

Purpose: Complete test coverage of all combo dimensions and make quick benchmark truly fast by using only small repos.
Output: Updated public-projects.json with 84 entries, all 27 combos populated, quick set = 9 small repos.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@tests/public-projects.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 8 new repos and restructure test sets</name>
  <files>tests/public-projects.json</files>
  <action>
**1. Add 8 new repo entries** to fill missing combos. Insert alphabetically among existing entries:

```json
{
  "name": "json-server",
  "npm_package": "json-server",
  "github_org": "typicode",
  "github_repo": "json-server",
  "git_url": "https://github.com/typicode/json-server.git",
  "latest_stable_tag": "v1.0.0-beta.9",
  "category": "application",
  "quality_tier": "high",
  "repo_size": "small",
  "test_sets": ["full", "normal", "quick"],
  "primary_language": "javascript",
  "reason": "Zero-config REST API server; extremely small and clean — ideal small high-quality application baseline"
}
```

```json
{
  "name": "npkill",
  "npm_package": "npkill",
  "github_org": "voidcosmos",
  "github_repo": "npkill",
  "git_url": "https://github.com/voidcosmos/npkill.git",
  "latest_stable_tag": "v0.12.2",
  "category": "application",
  "quality_tier": "medium",
  "repo_size": "small",
  "test_sets": ["full", "normal", "quick"],
  "primary_language": "typescript",
  "reason": "Interactive CLI to find and remove node_modules; small codebase with moderate file-scanning complexity"
}
```

```json
{
  "name": "nodemon",
  "npm_package": "nodemon",
  "github_org": "remy",
  "github_repo": "nodemon",
  "git_url": "https://github.com/remy/nodemon.git",
  "latest_stable_tag": "v3.1.14",
  "category": "application",
  "quality_tier": "low",
  "repo_size": "small",
  "test_sets": ["full", "normal", "quick"],
  "primary_language": "javascript",
  "reason": "Aging file watcher with legacy patterns in config resolution and process management; complex for its small size"
}
```

```json
{
  "name": "slidev",
  "npm_package": "@slidev/cli",
  "github_org": "slidevjs",
  "github_repo": "slidev",
  "git_url": "https://github.com/slidevjs/slidev.git",
  "latest_stable_tag": "v52.12.0",
  "category": "application",
  "quality_tier": "high",
  "repo_size": "medium",
  "test_sets": ["full", "normal"],
  "primary_language": "typescript",
  "reason": "Well-maintained presentation tool with clean architecture; good medium high-quality application baseline"
}
```

```json
{
  "name": "verdaccio",
  "npm_package": "verdaccio",
  "github_org": "verdaccio",
  "github_repo": "verdaccio",
  "git_url": "https://github.com/verdaccio/verdaccio.git",
  "latest_stable_tag": "v6.2.9",
  "category": "application",
  "quality_tier": "medium",
  "repo_size": "medium",
  "test_sets": ["full", "normal"],
  "primary_language": "typescript",
  "reason": "Private npm registry with moderate complexity in package storage and auth handling"
}
```

```json
{
  "name": "rocketchat",
  "npm_package": null,
  "github_org": "RocketChat",
  "github_repo": "Rocket.Chat",
  "git_url": "https://github.com/RocketChat/Rocket.Chat.git",
  "latest_stable_tag": "8.1.1",
  "category": "application",
  "quality_tier": "low",
  "repo_size": "large",
  "test_sets": ["full"],
  "primary_language": "typescript",
  "reason": "Large chat platform with complex legacy patterns in real-time messaging, permissions, and federation code"
}
```

```json
{
  "name": "three.js",
  "npm_package": "three",
  "github_org": "mrdoob",
  "github_repo": "three.js",
  "git_url": "https://github.com/mrdoob/three.js.git",
  "latest_stable_tag": "r183",
  "category": "library",
  "quality_tier": "medium",
  "repo_size": "large",
  "test_sets": ["full", "normal"],
  "primary_language": "javascript",
  "reason": "111k stars; massive 3D library with moderate quality — clean API but complex renderer and math internals"
}
```

```json
{
  "name": "pdf.js",
  "npm_package": "pdfjs-dist",
  "github_org": "mozilla",
  "github_repo": "pdf.js",
  "git_url": "https://github.com/mozilla/pdf.js.git",
  "latest_stable_tag": "v5.4.624",
  "category": "library",
  "quality_tier": "low",
  "repo_size": "large",
  "test_sets": ["full"],
  "primary_language": "javascript",
  "reason": "Complex PDF parsing and rendering with deeply nested conditional paths; high cyclomatic complexity throughout"
}
```

**2. Update quick test set — restrict to small repos only (9 repos)**

Remove "quick" from ALL entries that have repo_size != "small". Then ensure exactly these 9 small repos have "quick" in test_sets:

| Combo | Repo |
|-------|------|
| library/small/high | zod |
| library/small/medium | commander |
| library/small/low | moment |
| application/small/high | json-server (new) |
| application/small/medium | npkill (new) |
| application/small/low | nodemon (new) |
| framework-and-build-tool/small/high | h3 |
| framework-and-build-tool/small/medium | koa |
| framework-and-build-tool/small/low | grunt |

Specifically:
- REMOVE "quick" from: got, typescript, nestjs, webpack, socket.io, pm2, axios, hono, express, vscode, next.js, vue-core, excalidraw, commander (wait, commander IS small — keep it)
- Actually just: remove "quick" from all non-small repos: got (medium), typescript (large), nestjs (medium), webpack (large), socket.io (medium), pm2 (medium), axios (medium), hono (medium), express (medium), vscode (large), next.js (large), vue-core (large), excalidraw (large)
- ADD "quick" to: h3 (small/high), koa (small/medium) — they exist but don't have "quick"
- Keep "quick" on: zod (small/high), commander (small/medium), moment (small/low), grunt (small/low)

**3. Update normal test set — add coverage for new repos**

Add "normal" to these entries that currently only have "full":
- h3: add "normal" (small/high fw)
- koa: add "normal" (small/medium fw)
- ava: add "normal" (small/high fw)
- jasmine: add "normal" (small/low fw)
- lodash: add "normal" (small/medium lib)
- rrule: add "normal" (small/medium lib)
- superstruct: add "normal" (small/high lib)
- valibot: add "normal" (small/high lib)
- zustand: add "normal" (small/high lib)
- jotai: add "normal" (small/high lib)
- signale: add "normal" (small/high lib)
- debug: add "normal" (small/high lib)

**4. Update meta section**

Update counts:
- total_libraries: 84
- quality_tiers: recount (high, medium, low)
- repo_sizes: recount (small, medium, large)
- test_sets: quick should be 9, recount normal and full (84)

  </action>
  <verify>
Verify with jq:
- `jq '.libraries | length' tests/public-projects.json` returns 84
- `jq '[.libraries[] | select(.test_sets | contains(["quick"])) ] | length' tests/public-projects.json` returns 9
- `jq '[.libraries[] | select(.test_sets | contains(["quick"])) | .repo_size] | unique' tests/public-projects.json` returns ["small"]
- `jq '[.libraries[] | select(.test_sets | contains(["quick"])) | "\(.category)/\(.quality_tier)"] | unique | length' tests/public-projects.json` returns 9
- All 27 category/repo_size/quality_tier combos populated: `jq '[.libraries[] | "\(.category)/\(.repo_size)/\(.quality_tier)"] | unique | length' tests/public-projects.json` returns 27 (or close — some combos may genuinely not exist)
  </verify>
  <done>
84 entries total. Quick set = 9 small repos (one per category × quality_tier). All gaps filled with popular, current repos. Normal expanded. Meta updated.
  </done>
</task>

</tasks>

<output>
After completion, create `.planning/quick/27-add-missing-combo-repos-and-restrict-qui/27-SUMMARY.md`
</output>
