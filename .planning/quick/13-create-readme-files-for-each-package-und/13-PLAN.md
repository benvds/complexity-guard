---
phase: quick-13
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - publication/npm/README.md
  - publication/npm/packages/darwin-arm64/README.md
  - publication/npm/packages/darwin-x64/README.md
  - publication/npm/packages/linux-arm64/README.md
  - publication/npm/packages/linux-x64/README.md
  - publication/npm/packages/windows-x64/README.md
autonomous: true
must_haves:
  truths:
    - "Main npm package page shows install instructions and usage"
    - "Each platform package page directs users to install the main package"
    - "All 6 packages have README.md files"
  artifacts:
    - path: "publication/npm/README.md"
      provides: "Main package README for npmjs.com"
    - path: "publication/npm/packages/darwin-arm64/README.md"
      provides: "Platform redirect README"
    - path: "publication/npm/packages/darwin-x64/README.md"
      provides: "Platform redirect README"
    - path: "publication/npm/packages/linux-arm64/README.md"
      provides: "Platform redirect README"
    - path: "publication/npm/packages/linux-x64/README.md"
      provides: "Platform redirect README"
    - path: "publication/npm/packages/windows-x64/README.md"
      provides: "Platform redirect README"
  key_links: []
---

<objective>
Create README.md files for all 6 npm packages so that each package page on npmjs.com shows useful information.

Purpose: npm automatically displays README.md on package pages. Without READMEs, the pages are blank and unhelpful to users.
Output: 6 README.md files (1 main + 5 platform).
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@README.md
@publication/npm/package.json
@publication/npm/packages/darwin-arm64/package.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create main npm package README</name>
  <files>publication/npm/README.md</files>
  <action>
Create `publication/npm/README.md` for the `complexity-guard` main package. This is what users see on https://www.npmjs.com/package/complexity-guard.

Content structure:
1. Heading: `# ComplexityGuard`
2. Tagline: "Fast complexity analysis for TypeScript/JavaScript -- single static binary, zero dependencies."
3. Install section: `npm install -g complexity-guard` (global) and `npm install --save-dev complexity-guard` (local/CI)
4. Usage section: `complexity-guard src/` with the example output block from the project README (the src/auth/login.ts example showing ok/warning/error output and summary)
5. Features section: bullet list matching the project README features (Cyclomatic Complexity, Console + JSON Output, Configurable Thresholds, Zero Config, Single Binary, Error-Tolerant Parsing) -- keep descriptions brief, one line each
6. Configuration section: show the `.complexityguard.json` example from the project README
7. Links section with:
   - GitHub: https://github.com/benvds/complexity-guard
   - Documentation: https://github.com/benvds/complexity-guard#documentation
8. License: MIT

Keep it concise but complete. This is a npm-focused version of the project README -- no "Building from Source" section since npm users get the binary.
  </action>
  <verify>File exists at publication/npm/README.md and contains install instructions, usage example, features list, and GitHub link.</verify>
  <done>publication/npm/README.md exists with npm-focused content including install, usage, features, configuration, and links to GitHub.</done>
</task>

<task type="auto">
  <name>Task 2: Create platform binary package READMEs</name>
  <files>
publication/npm/packages/darwin-arm64/README.md
publication/npm/packages/darwin-x64/README.md
publication/npm/packages/linux-arm64/README.md
publication/npm/packages/linux-x64/README.md
publication/npm/packages/windows-x64/README.md
  </files>
  <action>
Create README.md for each of the 5 platform binary packages. These are short "redirect" READMEs telling users to install the main package instead.

Each README follows this template (substitute platform-specific values):

```
# @complexity-guard/{platform}

This package contains the ComplexityGuard binary for {os} ({arch}).

## Do not install directly

This package is automatically installed as a dependency of the main [`complexity-guard`](https://www.npmjs.com/package/complexity-guard) package. Install that instead:

\`\`\`sh
npm install -g complexity-guard
\`\`\`

## Links

- [complexity-guard on npm](https://www.npmjs.com/package/complexity-guard)
- [GitHub](https://github.com/benvds/complexity-guard)

## License

MIT
```

Platform values:
- `darwin-arm64`: os="macOS", arch="ARM64 (Apple Silicon)"
- `darwin-x64`: os="macOS", arch="x64 (Intel)"
- `linux-arm64`: os="Linux", arch="ARM64"
- `linux-x64`: os="Linux", arch="x64"
- `windows-x64`: os="Windows", arch="x64"
  </action>
  <verify>All 5 files exist. Each contains the correct platform name, os, arch, and a link to the main package.</verify>
  <done>All 5 platform README.md files exist with correct platform descriptions and redirect to the main complexity-guard package.</done>
</task>

</tasks>

<verification>
All 6 README.md files exist:
- `ls publication/npm/README.md publication/npm/packages/*/README.md` shows 6 files
- Main README contains "npm install" and "complexity-guard src/"
- Each platform README contains "Do not install directly" and links to main package
</verification>

<success_criteria>
- 6 README.md files created (1 main + 5 platform)
- Main package README is npm-user-focused with install, usage, features, config, and GitHub links
- Platform package READMEs redirect users to install the main package
- All READMEs include MIT license mention
</success_criteria>

<output>
After completion, create `.planning/quick/13-create-readme-files-for-each-package-und/13-SUMMARY.md`
</output>
