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

Cross-compile for all platforms using cargo-zigbuild (for musl targets) or native cargo:

```sh
# Install cargo-zigbuild for Linux musl targets
pip3 install ziglang
cargo install --locked cargo-zigbuild

# Linux x86_64 (musl static binary)
cargo zigbuild --release --target x86_64-unknown-linux-musl
cp target/x86_64-unknown-linux-musl/release/complexity-guard publication/npm/packages/linux-x64/

# Linux ARM64 (musl static binary)
cargo zigbuild --release --target aarch64-unknown-linux-musl
cp target/aarch64-unknown-linux-musl/release/complexity-guard publication/npm/packages/linux-arm64/

# macOS ARM64
cargo build --release --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/complexity-guard publication/npm/packages/darwin-arm64/

# macOS x86_64
cargo build --release --target x86_64-apple-darwin
cp target/x86_64-apple-darwin/release/complexity-guard publication/npm/packages/darwin-x64/

# Windows x86_64 (build on Windows or via cross-compilation)
cargo build --release --target x86_64-pc-windows-msvc
cp target/x86_64-pc-windows-msvc/release/complexity-guard.exe publication/npm/packages/windows-x64/
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
