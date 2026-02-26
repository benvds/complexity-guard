---
phase: quick-28
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/public-projects.json
autonomous: true
requirements: [QUICK-28]
---

<objective>
Add a "license" SPDX identifier field to every entry in public-projects.json. Fix pm2 github_org from "pm2-hive" to "Unitech".

Purpose: Document the license of each repo for legal transparency.
Output: Updated public-projects.json with license field on all 84 entries.
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
  <name>Task 1: Add license field to all repos and fix pm2 org</name>
  <files>tests/public-projects.json</files>
  <action>
**1. Add "license" field** to every entry, placed right after "latest_stable_tag". Use these exact SPDX values:

| name | license |
|------|---------|
| angular | MIT |
| ant-design | MIT |
| apollo-client | MIT |
| ava | MIT |
| axios | MIT |
| biome | Apache-2.0 |
| chakra-ui | MIT |
| chalk | MIT |
| commander | MIT |
| date-fns | MIT |
| dayjs | MIT |
| debug | MIT |
| deno | MIT |
| dotenv | BSD-2-Clause |
| effect | MIT |
| eslint | MIT |
| excalidraw | MIT |
| express | MIT |
| fastify | MIT |
| got | MIT |
| grunt | MIT |
| h3 | MIT |
| hono | MIT |
| jasmine | MIT |
| jest | MIT |
| joi | BSD-3-Clause |
| jotai | MIT |
| jshint | MIT |
| json-server | MIT |
| karma | MIT |
| keystonejs | MIT |
| koa | MIT |
| lodash | MIT |
| luxon | MIT |
| mobx | MIT |
| mocha | MIT |
| moment | MIT |
| mongodb-node-driver | Apache-2.0 |
| n8n | SEL (Sustainable Use License) |
| nestjs | MIT |
| next.js | MIT |
| nodemon | MIT |
| npkill | MIT |
| pdf.js | Apache-2.0 |
| pino | MIT |
| pm2 | AGPL-3.0 |
| prettier | MIT |
| prisma | Apache-2.0 |
| redux | MIT |
| redwoodjs | MIT |
| remix | MIT |
| request | Apache-2.0 |
| rocketchat | MIT (with EE exception) |
| rrule | BSD-3-Clause |
| rxjs | Apache-2.0 |
| sequelize | MIT |
| signale | MIT |
| slidev | MIT |
| socket.io | MIT |
| storybook | MIT |
| strapi | MIT (with EE exception) |
| supabase-js | MIT |
| superstruct | MIT |
| tailwindcss | MIT |
| tanstack-query | MIT |
| three.js | MIT |
| trpc | MIT |
| typeorm | MIT |
| typescript | Apache-2.0 |
| undici | MIT |
| valibot | MIT |
| verdaccio | MIT |
| vite | MIT |
| vitest | MIT |
| vscode | MIT |
| vue-core | MIT |
| webpack | MIT |
| winston | MIT |
| wretch | MIT |
| xstate | MIT |
| yargs | MIT |
| yup | MIT |
| zod | MIT |
| zustand | MIT |

**2. Fix pm2 entry:**
- Change `github_org` from `"pm2-hive"` to `"Unitech"`
- Change `git_url` from `"https://github.com/pm2-hive/pm2.git"` to `"https://github.com/Unitech/pm2.git"`

**3. Update meta section:**
- Add a `"licenses"` summary object counting each license type, e.g.: `{"MIT": 63, "Apache-2.0": 7, "BSD-2-Clause": 1, "BSD-3-Clause": 2, ...}` (recount from actual data)

  </action>
  <verify>
- `jq '[.libraries[] | select(.license == null)] | length' tests/public-projects.json` returns 0
- `jq '[.libraries[].license] | unique' tests/public-projects.json` shows all license types
- `jq '.libraries[] | select(.name == "pm2") | .github_org' tests/public-projects.json` returns "Unitech"
- `jq '.libraries[] | select(.name == "pm2") | .git_url' tests/public-projects.json` contains "Unitech"
- `jq '.meta.licenses' tests/public-projects.json` shows license counts
  </verify>
  <done>
All 84 entries have license field. pm2 org fixed. Meta updated with license counts.
  </done>
</task>

</tasks>

<output>
After completion, create `.planning/quick/28-add-license-field-to-all-repos-in-public/28-SUMMARY.md`
</output>
