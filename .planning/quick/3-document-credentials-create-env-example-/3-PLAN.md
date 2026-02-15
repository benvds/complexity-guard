---
phase: quick-3
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .env.example
  - .gitignore
  - scripts/publish.sh
  - PUBLISHING.md
autonomous: true

must_haves:
  truths:
    - ".env.example documents NPM_TOKEN as required credential for local publishing"
    - "scripts/publish.sh loads .env and publishes all 6 npm packages (main + 5 platform) from local machine"
    - ".env is gitignored so secrets are never committed"
    - "PUBLISHING.md documents both local publish workflow and GitHub Actions secrets setup"
  artifacts:
    - path: ".env.example"
      provides: "Template showing required environment variables"
      contains: "NPM_TOKEN"
    - path: "scripts/publish.sh"
      provides: "Local npm publish script that loads .env and publishes all packages"
      contains: "npm publish"
    - path: "PUBLISHING.md"
      provides: "Documentation for credentials, local publishing, and CI secrets"
      contains: "NPM_TOKEN"
  key_links:
    - from: "scripts/publish.sh"
      to: ".env"
      via: "source .env to load NPM_TOKEN"
      pattern: "source.*\\.env"
    - from: "scripts/publish.sh"
      to: "npm/*/package.json"
      via: "publishes each platform package directory"
      pattern: "npm publish"
---

<objective>
Create credential documentation, .env.example, and a local publish script so the user can publish npm packages from their shell without relying on GitHub Actions.

Purpose: Enable local npm publishing workflow and document all credentials needed for both local and CI release.
Output: .env.example, scripts/publish.sh, .gitignore update, PUBLISHING.md
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/05.1-ci-cd-release-pipeline-documentation/05.1-CONTEXT.md
@.planning/phases/05.1-ci-cd-release-pipeline-documentation/05.1-02-PLAN.md
@.planning/phases/05.1-ci-cd-release-pipeline-documentation/05.1-04-PLAN.md
@.gitignore
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create .env.example and update .gitignore</name>
  <files>.env.example, .gitignore</files>
  <action>
Create `.env.example` with:
```
# npm authentication token for publishing packages
# Generate at: https://www.npmjs.com/ -> Access Tokens -> Generate New Token (Classic) -> Automation
NPM_TOKEN=npm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Update `.gitignore` to add these entries at the bottom (under a new `# Secrets` comment section):
```
# Secrets
.env
.env.local
.env.*.local
```

Also add entries for npm binary artifacts (needed by Phase 5.1 Plan 02 later, but correct to add now since .gitignore is being touched):
```
# npm platform binaries (placed by release workflow)
npm/*/complexity-guard
npm/*/complexity-guard.exe
```
  </action>
  <verify>
Verify `.env.example` exists and contains NPM_TOKEN placeholder.
Verify `.gitignore` contains `.env` entry.
Verify `.gitignore` contains `npm/*/complexity-guard` entry.
  </verify>
  <done>.env.example has NPM_TOKEN with instructions for obtaining it. .gitignore excludes .env files and npm platform binaries.</done>
</task>

<task type="auto">
  <name>Task 2: Create local publish script and publishing documentation</name>
  <files>scripts/publish.sh, PUBLISHING.md</files>
  <action>
**scripts/publish.sh** (make executable with chmod +x):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Local npm publish script for complexity-guard
# Publishes main package + all 5 platform packages to npm
#
# Prerequisites:
#   1. Copy .env.example to .env and fill in NPM_TOKEN
#   2. Platform binaries must exist in npm/<platform>/ directories
#      (either from local Zig cross-compilation or downloaded from a release)
#
# Usage: ./scripts/publish.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env if present
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
else
  echo "Error: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and set NPM_TOKEN"
  exit 1
fi

# Verify NPM_TOKEN is set
if [ -z "${NPM_TOKEN:-}" ]; then
  echo "Error: NPM_TOKEN is not set in .env"
  exit 1
fi

export NODE_AUTH_TOKEN="$NPM_TOKEN"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  echo "=== DRY RUN MODE ==="
  echo ""
fi

# Platform packages to publish (order doesn't matter, but publish before main)
PLATFORMS=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-x64"
  "windows-x64"
)

echo "Publishing platform packages..."
echo ""

for platform in "${PLATFORMS[@]}"; do
  pkg_dir="$PROJECT_ROOT/npm/$platform"
  if [ ! -f "$pkg_dir/package.json" ]; then
    echo "Warning: $pkg_dir/package.json not found, skipping"
    continue
  fi
  echo "  Publishing @complexity-guard/$platform..."
  (cd "$pkg_dir" && npm publish --access public $DRY_RUN)
done

echo ""
echo "Publishing main package (complexity-guard)..."
(cd "$PROJECT_ROOT" && npm publish --access public $DRY_RUN)

echo ""
echo "Done! All packages published."
```

**PUBLISHING.md** (project root):

```markdown
# Publishing

How to publish complexity-guard to npm, both locally and via CI.

## Credentials

### npm Token

Required for publishing to the npm registry.

1. Go to [npmjs.com](https://www.npmjs.com/) and sign in
2. Click your avatar -> Access Tokens
3. Generate New Token -> Classic -> Automation
4. Copy the token (starts with `npm_`)

### Local Setup

```sh
cp .env.example .env
# Edit .env and paste your NPM_TOKEN
```

### GitHub Actions Setup

Add these secrets to your GitHub repository (Settings -> Secrets and variables -> Actions):

| Secret | Purpose | How to obtain |
|--------|---------|---------------|
| `NPM_TOKEN` | npm package publishing | npmjs.com -> Access Tokens -> Automation |

The release workflow (`.github/workflows/release.yml`) uses `NPM_TOKEN` to publish packages.

## Publishing Locally

The `scripts/publish.sh` script publishes all npm packages from your local machine.

### Prerequisites

1. `.env` file with `NPM_TOKEN` set (see above)
2. Platform binaries in `npm/<platform>/` directories

### Building binaries locally

Cross-compile for all platforms:

```sh
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard npm/darwin-arm64/

zig build -Dtarget=x86_64-macos -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard npm/darwin-x64/

zig build -Dtarget=aarch64-linux -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard npm/linux-arm64/

zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard npm/linux-x64/

zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard.exe npm/windows-x64/
```

### Dry run

Test without actually publishing:

```sh
./scripts/publish.sh --dry-run
```

### Publish for real

```sh
./scripts/publish.sh
```

This publishes all 5 platform packages first, then the main `complexity-guard` package.

## Publishing via CI

The GitHub Actions release workflow handles publishing automatically:

1. Go to Actions -> Release -> Run workflow
2. Enter the version (e.g., `0.2.0`)
3. The workflow builds binaries, creates a GitHub release, and publishes to npm

See `.github/workflows/release.yml` for details (created in Phase 5.1 Plan 04).
```

Ensure the PUBLISHING.md uses backtick fences for all code blocks and a clean table for secrets.
  </action>
  <verify>
Verify `scripts/publish.sh` exists and is executable (`ls -la scripts/publish.sh`).
Run `bash -n scripts/publish.sh` to verify shell syntax.
Verify `PUBLISHING.md` exists and contains sections for local and CI publishing.
  </verify>
  <done>scripts/publish.sh loads .env, validates NPM_TOKEN, publishes all 6 packages with --dry-run support. PUBLISHING.md documents credential setup for both local and GitHub Actions workflows.</done>
</task>

</tasks>

<verification>
- `.env.example` contains NPM_TOKEN placeholder with instructions
- `.gitignore` has `.env` and npm binary exclusions
- `scripts/publish.sh` is executable and passes `bash -n` syntax check
- `scripts/publish.sh` loads .env, checks NPM_TOKEN, publishes platform packages then main package
- `PUBLISHING.md` documents npm token creation, local setup, GitHub secrets, and both publish workflows
</verification>

<success_criteria>
- Developer can copy .env.example to .env, fill in NPM_TOKEN, and run scripts/publish.sh to publish locally
- .env is gitignored so secrets are never accidentally committed
- GitHub Actions secrets are documented with exact names and where to obtain them
- --dry-run flag allows testing the publish flow without actually publishing
</success_criteria>

<output>
After completion, create `.planning/quick/3-document-credentials-create-env-example-/3-SUMMARY.md`
</output>
