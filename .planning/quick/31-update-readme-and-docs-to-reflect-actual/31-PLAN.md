---
phase: quick-31
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - README.md
  - docs/getting-started.md
  - docs/cli-reference.md
  - docs/examples.md
  - publication/npm/README.md
  - publication/npm/packages/darwin-arm64/README.md
  - publication/npm/packages/darwin-x64/README.md
  - publication/npm/packages/linux-arm64/README.md
  - publication/npm/packages/linux-x64/README.md
  - publication/npm/packages/windows-x64/README.md
autonomous: true
must_haves:
  truths:
    - "All config file examples match the actual Rust Config struct schema"
    - "All CLI flag documentation matches actual clap Args definition"
    - "All default threshold values match ResolvedConfig::default()"
    - "Publication READMEs stay in sync with main README"
  artifacts:
    - path: "README.md"
      provides: "Accurate project README with correct config schema"
    - path: "docs/cli-reference.md"
      provides: "CLI reference matching actual binary behavior"
    - path: "docs/getting-started.md"
      provides: "Getting started guide with correct config examples"
    - path: "docs/examples.md"
      provides: "Examples with correct config schemas and flags"
  key_links:
    - from: "README.md"
      to: "src/cli/config.rs"
      via: "Config struct schema"
      pattern: "analysis.*thresholds"
    - from: "docs/cli-reference.md"
      to: "src/cli/args.rs"
      via: "CLI arg definitions"
      pattern: "fail.on|init|metrics"
---

<objective>
Update all documentation files to accurately reflect the actual Rust codebase.

Purpose: The docs were written during/before the Zig-to-Rust rewrite and contain numerous inaccuracies: wrong config file schema (flat `thresholds` key vs actual `analysis.thresholds`), nonexistent `counting_rules` config, `--init` described as working but is a stub, wrong default values, wrong `--fail-on` option names, and references to nonexistent `--error` flag.

Output: All 10 documentation files updated to match actual code behavior.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@README.md
@docs/getting-started.md
@docs/cli-reference.md
@docs/examples.md
@src/cli/args.rs
@src/cli/config.rs
@src/cli/discovery.rs
@src/main.rs
@Cargo.toml
@publication/npm/README.md

<interfaces>
<!-- Actual config file schema from src/cli/config.rs Config struct -->
The actual .complexityguard.json schema is:
```json
{
  "output": {
    "format": "console",        // "console" | "json" | "sarif" | "html"
    "file": "report.json"       // output file path
  },
  "analysis": {
    "metrics": ["cyclomatic", "cognitive", "halstead", "nesting", "line_count", "params_count"],
    "thresholds": {
      "cyclomatic": { "warning": 10, "error": 20 },
      "cognitive": { "warning": 15, "error": 25 },
      "halstead_volume": { "warning": 500, "error": 1000 },
      "halstead_difficulty": { "warning": 10, "error": 20 },
      "halstead_effort": { "warning": 5000, "error": 10000 },
      "halstead_bugs": { "warning": 0.5, "error": 1.0 },
      "nesting_depth": { "warning": 3, "error": 5 },
      "line_count": { "warning": 25, "error": 50 },
      "params_count": { "warning": 3, "error": 6 },
      "file_length": { "warning": 300, "error": 600 },
      "export_count": { "warning": 15, "error": 30 },
      "duplication": { "file_warning": 15.0, "file_error": 25.0, "project_warning": 5.0, "project_error": 10.0 }
    },
    "no_duplication": false,
    "duplication_enabled": false,
    "threads": 4
  },
  "files": {
    "include": ["src/**/*.ts"],
    "exclude": ["**/*.test.ts"]
  },
  "weights": {
    "cognitive": 0.30,
    "cyclomatic": 0.20,
    "halstead": 0.15,
    "structural": 0.15,
    "duplication": 0.20
  },
  "overrides": [{ "files": ["pattern"], "analysis": {...} }],
  "baseline": 73.2
}
```

NOTE: There is NO top-level `thresholds` key. Thresholds are under `analysis.thresholds`.
NOTE: There is NO `counting_rules` config. Cyclomatic counting rules are hardcoded.
NOTE: Threshold field names use `line_count` (not `function_length`), `params_count` (not `params`), `nesting_depth` (not `nesting`), `export_count` (not `exports`).

<!-- Actual CLI from src/cli/args.rs -->
CLI flags: --init (STUB: prints "not yet implemented"), --format/-f, --output/-o, --color, --no-color, --quiet/-q, --verbose/-v, --metrics, --duplication, --no-duplication, --threads, --include, --exclude, --fail-on (accepts "warning", "error", "none"), --fail-health-below, --config/-c, --baseline, --version, --help/-h

<!-- Actual defaults from src/cli/config.rs ResolvedConfig::default() -->
halstead_bugs_error: 1.0 (NOT 2.0 as docs say)
Config discovery: searches upward from CWD to .git boundary. Recognizes .complexityguard.json and complexityguard.config.json. Does NOT check XDG config dir.
Version: 0.10.0 (from Cargo.toml)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix docs/cli-reference.md and docs/getting-started.md config schemas and CLI docs</name>
  <files>docs/cli-reference.md, docs/getting-started.md</files>
  <action>
Fix all discrepancies between documentation and actual code in cli-reference.md and getting-started.md:

1. **Config file schema** (MAJOR): Replace ALL config JSON examples throughout both files to use the actual nested schema. The actual schema nests thresholds under `analysis.thresholds`, NOT top-level `thresholds`. Field names are: `line_count` (not `function_length`), `params_count` (not `params`), `nesting_depth` (not `nesting`), `export_count` (not `exports`). All examples must reflect this.

2. **Remove `counting_rules`** (MAJOR): Delete all `counting_rules` documentation sections from both files. The Rust code has no counting_rules config -- cyclomatic counting rules are hardcoded (logical_operators=true, nullish_coalescing=true, optional_chaining=true, switch_case_mode=Classic). Add a brief note that counting rules follow ESLint defaults and are not configurable in this version.

3. **`--init` is a stub**: Update --init documentation to say it is reserved for future use / not yet implemented in the current version. Remove claims that it generates a comprehensive config file. Keep the flag documented but note it currently prints a message and exits.

4. **`--version` output**: Change the example from `complexityguard 0.1.0` to just say it displays the current version (don't hardcode a version number).

5. **`--fail-on` values**: Change `never` to `none` in all instances (code uses `none`).

6. **`halstead_bugs` error default**: Change from `2.0` to `1.0` in the default thresholds table and all examples.

7. **Config discovery paths**: Remove the XDG config directory mention. Document that it searches upward from CWD through parent directories stopping at `.git` boundary. Also mention `complexityguard.config.json` as an alternative filename.

8. **Remove `--error` flag**: In docs/examples.md there's `--error 25` in the HTML report custom thresholds example -- this flag does not exist. Remove or replace with a valid flag.

9. **Document `--no-duplication` flag**: Add documentation for this flag in cli-reference.md (it exists in args.rs but is undocumented).

10. **JSON output --output behavior**: Fix the claim "When using JSON format with --output, the JSON is written to the file and also printed to stdout" -- the code writes to file OR stdout, not both.

11. **Full Schema in cli-reference.md**: The "Full Schema" JSON example must use the actual nested schema with correct field names.

12. **Config option docs**: Update all `thresholds.*` option descriptions to use the correct nested path (e.g., `analysis.thresholds.cyclomatic.warning` not `thresholds.cyclomatic.warning`). Also update field names: `line_count` not `function_length`, etc.

13. **Remove the Rust note banners**: The "Note: ComplexityGuard is built with Rust..." banners at the top of cli-reference.md and examples.md are no longer needed since the project is exclusively Rust now. Remove them.
  </action>
  <verify>
    <automated>grep -rn "counting_rules\|function_length.*warning\|\"params\".*warning\|\"nesting\".*warning\|\"exports\".*warning\|thresholds.*cyclomatic.*warning.*10\|fail-on never\|halstead_bugs.*2\.0\|XDG\|xdg\|0\.1\.0\|--error 25" docs/cli-reference.md docs/getting-started.md; echo "Exit: $? (expect no matches = exit 1)"</automated>
  </verify>
  <done>cli-reference.md and getting-started.md contain only accurate information matching the actual Rust code: correct nested config schema, correct field names, correct defaults, correct CLI flag behavior, no counting_rules docs, no --init generation claims</done>
</task>

<task type="auto">
  <name>Task 2: Fix README.md, docs/examples.md, and sync publication READMEs</name>
  <files>README.md, docs/examples.md, publication/npm/README.md, publication/npm/packages/darwin-arm64/README.md, publication/npm/packages/darwin-x64/README.md, publication/npm/packages/linux-arm64/README.md, publication/npm/packages/linux-x64/README.md, publication/npm/packages/windows-x64/README.md</files>
  <action>
1. **README.md config example**: Replace the Configuration section JSON example with the actual nested schema. Change top-level `thresholds` to `analysis.thresholds`, rename `function_length` to `line_count`, `params` to `params_count`, `nesting` to `nesting_depth`, `exports` to `export_count`. Remove the `counting_rules` block entirely. Fix `halstead_bugs` error from `2.0` to `1.0`. Keep `output`, `files`, `weights`, `analysis`, `baseline` at the correct nesting level.

2. **README.md --init description**: Change "Set up health score tracking (analyzes your code, suggests weights, saves baseline)" to indicate --init is reserved for future use, or remove that Quick Start line since --init is a stub.

3. **docs/examples.md**: Fix all config JSON examples to use the actual nested schema with correct field names. Remove the top-of-file Rust note banner. Remove the `--error 25` flag usage (no such flag exists). Fix counting_rules examples (Classic McCabe and ESLint-Aligned sections) -- either remove them or note that counting rules are not configurable. Fix any `--fail-on never` to `--fail-on none`.

4. **publication/npm/README.md**: Sync with main README.md changes. Fix the config example to use the actual nested schema. Remove --init Quick Start line if removed from main README. Fix halstead_bugs default.

5. **All 5 package READMEs** (darwin-arm64, darwin-x64, linux-arm64, linux-x64, windows-x64): These are short and mostly correct already (feature bullet points). Add "Automatic Safety Limits" bullet point to match main README features list. Ensure feature list matches current main README.
  </action>
  <verify>
    <automated>grep -rn "counting_rules\|\"function_length\"\|\"params\".*warning\|\"nesting\".*warning\|\"exports\".*warning\|fail-on never\|halstead_bugs.*2\.0\|--error 25" README.md docs/examples.md publication/npm/README.md publication/npm/packages/*/README.md; echo "Exit: $? (expect no matches = exit 1)"</automated>
  </verify>
  <done>README.md, docs/examples.md, and all publication READMEs contain only accurate config schemas, correct field names, correct defaults, and no references to nonexistent flags or features. Publication READMEs are in sync with main README.</done>
</task>

</tasks>

<verification>
After both tasks complete:
1. `grep -rn "counting_rules" README.md docs/ publication/` returns no matches (removed nonexistent feature)
2. `grep -rn '"function_length"' README.md docs/ publication/` returns no matches (renamed to line_count)
3. `grep -rn '"params"' README.md docs/ publication/ | grep -v params_count` returns no matches (renamed to params_count)
4. `grep -rn 'fail-on never' README.md docs/ publication/` returns no matches (changed to none)
5. `grep -rn 'halstead_bugs.*2\.0' README.md docs/ publication/` returns no matches (changed to 1.0)
6. `grep -rn '0\.1\.0' docs/cli-reference.md` returns no matches (removed hardcoded version)
7. All config JSON examples use `analysis.thresholds` nesting (spot-check)
</verification>

<success_criteria>
All documentation files accurately reflect the actual Rust codebase behavior:
- Config schema matches Config struct (nested analysis.thresholds, correct field names)
- CLI flags match Args struct (--fail-on none, --no-duplication documented, --init is stub)
- Default values match ResolvedConfig::default() (halstead_bugs error = 1.0)
- No references to nonexistent features (counting_rules, --error flag)
- Publication READMEs synced with main README
</success_criteria>

<output>
After completion, create `.planning/quick/31-update-readme-and-docs-to-reflect-actual/31-SUMMARY.md`
</output>
