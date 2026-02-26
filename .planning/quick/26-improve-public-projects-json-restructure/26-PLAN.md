---
phase: quick-26
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/public-projects.json
  - benchmarks/scripts/setup.sh
  - benchmarks/scripts/bench-quick.sh
autonomous: true
requirements: [QUICK-26]

must_haves:
  truths:
    - "Every entry in public-projects.json has category from exactly {library, application, framework-and-build-tool}"
    - "Every entry has repo_size from {small, medium, large}"
    - "Every entry has test_sets array with 'full' always present"
    - "The 'quick' test set covers one repo per unique (category x repo_size x quality_tier) combination"
    - "The 'normal' test set covers multiple repos per combination but not all"
    - "comparison_group field is removed from all entries"
    - "setup.sh reads test_sets from JSON instead of hardcoded suite lists"
    - "bench-quick.sh reads test_sets from JSON instead of hardcoded QUICK_SUITE"
  artifacts:
    - path: "tests/public-projects.json"
      provides: "Restructured project registry with 3 categories, repo_size, test_sets"
      contains: "framework-and-build-tool"
    - path: "benchmarks/scripts/setup.sh"
      provides: "Setup script using test_sets from JSON"
      contains: "test_sets"
    - path: "benchmarks/scripts/bench-quick.sh"
      provides: "Quick benchmark using test_sets from JSON"
      contains: "test_sets"
  key_links:
    - from: "benchmarks/scripts/setup.sh"
      to: "tests/public-projects.json"
      via: "jq filter on test_sets array"
      pattern: "test_sets.*quick"
    - from: "benchmarks/scripts/bench-quick.sh"
      to: "tests/public-projects.json"
      via: "jq filter on test_sets array"
      pattern: "test_sets.*quick"
---

<objective>
Restructure tests/public-projects.json to use 3 categories (library, application, framework-and-build-tool), add repo_size and test_sets fields, remove comparison_group, verify/fix git URLs and tags, and update benchmark scripts to use test_sets from JSON.

Purpose: Make the project registry more useful for targeted benchmarking with clear category taxonomy and size-based test set selection.
Output: Updated public-projects.json with new schema, updated setup.sh and bench-quick.sh using JSON-driven test sets.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@tests/public-projects.json
@benchmarks/scripts/setup.sh
@benchmarks/scripts/bench-quick.sh
@benchmarks/scripts/bench-full.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restructure public-projects.json schema</name>
  <files>tests/public-projects.json</files>
  <action>
Rewrite tests/public-projects.json with the following changes to every entry:

**1. Replace category field** with exactly one of these 3 values:
- "library" — standalone libraries: zod, lodash, dayjs, got, axios, chalk, dotenv, wretch, undici, date-fns, luxon, rrule, moment, joi, yup, valibot, superstruct, zustand, jotai, mobx, xstate, redux, tanstack-query, rxjs, pino, signale, debug, winston, commander, yargs, effect, supabase-js, mongodb-node-driver, socket.io, request
- "application" — applications/editors: vscode, excalidraw, n8n, storybook, deno, strapi, keystonejs, pm2
- "framework-and-build-tool" — frameworks and build tools: vite, webpack, grunt, vitest, jest, mocha, ava, jasmine, karma, nestjs, express, fastify, hono, koa, h3, next.js, remix, redwoodjs, prettier, biome, eslint, jshint, tailwindcss, angular, vue-core, ant-design, chakra-ui, trpc, prisma, typeorm, sequelize, apollo-client

**2. Remove comparison_group** from every entry entirely.

**3. Add repo_size** to each entry. Determine size based on the repository's TS/JS source code volume (not including node_modules, tests, docs):
- "small" — tiny repos with few files (< ~50 source files): zod, chalk, dotenv, debug, signale, zustand, jotai, wretch, h3, pino, got, dayjs, superstruct, valibot, rrule, koa, commander, yargs, request, grunt, ava, lodash, moment, mocha, jasmine, karma, jshint
- "medium" — moderate repos (~50-500 source files): vite, vitest, effect, rxjs, mobx, xstate, redux, tanstack-query, luxon, date-fns, joi, yup, axios, undici, hono, fastify, express, nestjs, trpc, biome, eslint, supabase-js, typeorm, sequelize, apollo-client, chakra-ui, socket.io, winston, pm2, mongodb-node-driver, tailwindcss, prettier, remix
- "large" — massive repos (500+ source files): vscode, next.js, angular, vue-core, ant-design, webpack, typescript, deno, storybook, strapi, keystonejs, n8n, excalidraw, prisma, jest, redwoodjs

**4. Add test_sets** array to each entry. Every entry gets "full". Then assign:

For "quick" set — pick ONE representative repo per unique (category x repo_size x quality_tier) combo:
- library / small / high: zod
- library / small / medium: commander
- library / small / low: moment
- library / medium / high: got
- library / medium / medium: axios
- library / medium / low: socket.io
- library / large / high: (none exist — skip)
- library / large / medium: (none exist — skip)
- library / large / low: mongodb-node-driver (if large, else skip)
- application / small / high: (none exist — skip)
- application / small / medium: (none exist — skip)
- application / small / low: pm2
- application / medium / high: (none exist — skip)
- application / medium / medium: (none exist — skip)
- application / medium / low: (none exist — skip)
- application / large / high: vscode
- application / large / medium: excalidraw
- application / large / low: (none exist — skip)
- framework-and-build-tool / small / high: (none exist — skip)
- framework-and-build-tool / small / medium: (none exist — skip)
- framework-and-build-tool / small / low: grunt
- framework-and-build-tool / medium / high: hono
- framework-and-build-tool / medium / medium: nestjs
- framework-and-build-tool / medium / low: express
- framework-and-build-tool / large / high: vue-core
- framework-and-build-tool / large / medium: next.js
- framework-and-build-tool / large / low: webpack

For "normal" set — include all "quick" entries PLUS additional repos to have 2-3 per populated combo:
- All "quick" entries get "normal" too
- Add: dayjs (lib/small/high), chalk (lib/small/high), dotenv (lib/small/high)
- Add: yargs (lib/small/medium)
- Add: request (lib/small/low), jshint (lib/small/low)
- Add: wretch (lib/medium/high), pino (lib/medium/high)
- Add: undici (lib/medium/medium), redux (lib/medium/medium)
- Add: winston (lib/medium/medium)
- Add: deno (app/large/high)
- Add: n8n (app/large/medium), storybook (app/large/medium)
- Add: vite (fw/medium/high), vitest (fw/medium/high)
- Add: fastify (fw/medium/medium), biome (fw/medium/high — if medium size)
- Add: karma (fw/small/low), mocha (fw/small/low)
- Add: angular (fw/large/medium), ant-design (fw/large/medium)
- Add: typescript (fw/large/high — if typescript is categorized as framework)

Note: typescript should be categorized as "library" (it's a compiler/language tool, not a framework). Adjust its category to "library" and size to "large". Then: library/large/high = typescript (quick), library/large/medium = (none or lodash if reassigned).

Actually, re-evaluate: TypeScript is a language compiler — classify as "library". Prisma is an ORM — classify as "framework-and-build-tool". Adjust test_sets accordingly.

**5. Verify git URLs and tags**: For each entry, the git_url should follow pattern `https://github.com/{org}/{repo}.git`. Check that github_org and github_repo match the git_url. Do NOT make network calls — just verify internal consistency. Keep existing tag values (they were set at generation time and may drift, but that's expected).

**6. Update meta section**:
- Update categories array to: ["library", "application", "framework-and-build-tool"]
- Remove comparison_groups entirely
- Update total_libraries count if it changed
- Update quality_tiers counts
- Add repo_sizes count object: {"small": N, "medium": N, "large": N}
- Add test_sets summary: {"quick": N, "normal": N, "full": N}

Keep all other fields (name, npm_package, github_org, github_repo, git_url, latest_stable_tag, quality_tier, primary_language, reason) unchanged.
  </action>
  <verify>
Verify with jq:
- `jq '[.libraries[].category] | unique' tests/public-projects.json` returns exactly ["application", "framework-and-build-tool", "library"]
- `jq '[.libraries[].repo_size] | unique' tests/public-projects.json` returns exactly ["large", "medium", "small"]
- `jq '[.libraries[] | select(.comparison_group)] | length' tests/public-projects.json` returns 0
- `jq '[.libraries[] | select(.test_sets | contains(["full"])) ] | length' tests/public-projects.json` equals total count
- `jq '[.libraries[] | select(.test_sets | contains(["quick"])) ] | length' tests/public-projects.json` returns count between 10-20
- `jq '.libraries | length' tests/public-projects.json` returns 76
  </verify>
  <done>
All 76 entries have: new 3-value category, repo_size, test_sets array (always includes "full"), no comparison_group. Meta section updated. Quick set covers representative combos. Normal set provides broader coverage.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update benchmark scripts to use test_sets from JSON</name>
  <files>benchmarks/scripts/setup.sh, benchmarks/scripts/bench-quick.sh</files>
  <action>
**Update setup.sh:**
1. Remove the hardcoded `QUICK_SUITE` and `STRESS_SUITE` variables
2. For `--suite quick`: use jq to extract project names where test_sets contains "quick":
   `jq -r '.libraries[] | select(.test_sets | contains(["quick"])) | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"`
3. For `--suite full`: keep existing behavior (all libraries)
4. Add `--suite normal` option: extract names where test_sets contains "normal":
   `jq -r '.libraries[] | select(.test_sets | contains(["normal"])) | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"`
5. For `--suite stress`: filter for large repo_size entries:
   `jq -r '.libraries[] | select(.repo_size == "large") | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"`
6. Update the validation to accept "quick", "normal", "full", or "stress"
7. Update the comment header to reflect the new suite options

**Update bench-quick.sh:**
1. Remove the hardcoded `QUICK_SUITE` array on line 119
2. Instead, build the project list dynamically from JSON:
   `QUICK_SUITE=($(jq -r '.libraries[] | select(.test_sets | contains(["quick"])) | .name' "$PROJECTS_JSON"))`
3. Add `PROJECTS_JSON="$PROJECT_ROOT/tests/public-projects.json"` variable (like bench-full.sh has)
4. Update header comment to mention test_sets-driven selection
5. Keep all other benchmark logic (hyperfine, FTA, results) unchanged
  </action>
  <verify>
- `bash -n benchmarks/scripts/setup.sh` exits 0 (valid syntax)
- `bash -n benchmarks/scripts/bench-quick.sh` exits 0 (valid syntax)
- `grep -c 'QUICK_SUITE=.*zod.*got.*dayjs' benchmarks/scripts/setup.sh` returns 0 (hardcoded list removed)
- `grep -c 'QUICK_SUITE=.*zod.*got.*dayjs' benchmarks/scripts/bench-quick.sh` returns 0 (hardcoded list removed)
- `grep 'test_sets' benchmarks/scripts/setup.sh` shows jq filter usage
- `grep 'test_sets' benchmarks/scripts/bench-quick.sh` shows jq filter usage
  </verify>
  <done>
setup.sh and bench-quick.sh read project lists from test_sets field in public-projects.json. No hardcoded project lists remain. New "normal" suite option added to setup.sh. Scripts pass bash syntax check.
  </done>
</task>

</tasks>

<verification>
1. `jq '.meta.categories' tests/public-projects.json` shows exactly 3 categories
2. `jq '.meta | has("comparison_groups")' tests/public-projects.json` returns false
3. `jq '.meta.repo_sizes' tests/public-projects.json` shows small/medium/large counts
4. `jq '.meta.test_sets' tests/public-projects.json` shows quick/normal/full counts
5. `jq '[.libraries[] | select(.test_sets | contains(["quick"])) | {combo: "\(.category)/\(.repo_size)/\(.quality_tier)"}] | unique | length' tests/public-projects.json` shows number of unique combos covered
6. `bash -n benchmarks/scripts/setup.sh && bash -n benchmarks/scripts/bench-quick.sh` both pass
</verification>

<success_criteria>
- public-projects.json has 76 entries, each with 3-value category, repo_size, test_sets (always includes "full"), no comparison_group
- Quick test set covers ~15-20 repos spanning all populated (category x repo_size x quality_tier) combos
- Normal test set covers ~30-40 repos with 2-3 per populated combo
- Benchmark scripts dynamically read from test_sets, no hardcoded project lists
- All scripts pass bash syntax validation
</success_criteria>

<output>
After completion, create `.planning/quick/26-improve-public-projects-json-restructure/26-SUMMARY.md`
</output>
