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

Cross-compile for all platforms (from the `zig/` directory):

```sh
cd zig

zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard ../npm/darwin-arm64/

zig build -Dtarget=x86_64-macos -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard ../npm/darwin-x64/

zig build -Dtarget=aarch64-linux -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard ../npm/linux-arm64/

zig build -Dtarget=x86_64-linux -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard ../npm/linux-x64/

zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSafe
cp zig-out/bin/complexity-guard.exe ../npm/windows-x64/
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
