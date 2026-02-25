# Phase 22: Cross-Compilation, CI, and Release - Research

**Researched:** 2026-02-25
**Domain:** Rust cross-compilation, GitHub Actions CI, binary release pipeline
**Confidence:** HIGH

## Summary

Phase 22 delivers the release infrastructure for the Rust binary: cross-compilation workflows for five platforms, native binary execution verification, binary size measurement, and a GitHub release pipeline triggered by version tags.

The project already has a working `rust-ci.yml` workflow and a `release.yml` workflow — but the existing release workflow builds the **Zig binary** using `zig build`, not the Rust binary. Phase 22 must port the release infrastructure to Rust. The CI workflow already handles `ubuntu-latest` and `macos-latest` native builds, plus one cross-compile job for `x86_64-unknown-linux-musl`. What is missing: `aarch64-unknown-linux-musl`, `x86_64-apple-darwin`, `aarch64-apple-darwin`, and `x86_64-pc-windows-msvc` targets in CI, and a completely new Rust release workflow.

The current macOS `macos-latest` runner is ARM64 (Apple M-series). GitHub has retired macOS Intel (x86_64) from the free `macos-latest` label. For `x86_64-apple-darwin`, cross-compilation from a `macos-latest` ARM64 runner is the correct approach — add the target via rustup, then `cargo build --target x86_64-apple-darwin`. This is native-cross within macOS (same platform, different arch), which works cleanly since the macOS SDK covers both architectures.

tree-sitter uses `cc::Build` to compile C source at build time. This means every cross-compilation target needs a working C cross-compiler. For Linux musl targets, `cargo-zigbuild` (using Zig as the linker) avoids the complexity of per-target musl toolchains. For macOS targets, native macOS runners (with the macOS SDK already present) are the simplest and most reliable path given recent reported issues with cross-compiling Darwin targets from Linux. For Windows, a native `windows-latest` runner builds against MSVC — the most reliable and well-supported Windows Rust target.

**Primary recommendation:** Use a split runner strategy: `ubuntu-latest` with `cargo-zigbuild` for both Linux musl targets; `macos-latest` (ARM64) natively for `aarch64-apple-darwin` and cross-targeting for `x86_64-apple-darwin`; `windows-latest` natively for Windows. This avoids all cross-platform SDK issues and matches the pattern already validated in STATE.md decisions.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REL-01 | Cross-compilation to Linux x86_64 and aarch64 | cargo-zigbuild on ubuntu-latest covers both musl targets; existing rust-ci.yml already has x86_64-musl as proof of concept |
| REL-02 | Cross-compilation to macOS x86_64 and aarch64 | macos-latest (ARM64) runner: native for aarch64-apple-darwin, cross-target for x86_64-apple-darwin via rustup target add |
| REL-03 | Cross-compilation to Windows x86_64 | windows-latest runner with x86_64-pc-windows-msvc; no extra toolchain needed |
| REL-04 | GitHub Actions CI pipeline with test + release | Extend rust-ci.yml for all 5 targets; create rust-release.yml triggered by v* tags |
| REL-05 | Binary size measured and documented | Measure after each CI build with `ls -lh`; record all 5 targets; document 5 MB baseline is already exceeded on macOS arm64 (5.0 MB) |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| cargo-zigbuild | 0.22.1 (current) | Cross-linker for Linux/musl targets | Zig's cross-compiler handles all Linux musl targets without per-target GCC toolchain setup |
| dtolnay/rust-toolchain | @stable | Install Rust + targets in CI | The standard action for Rust toolchain setup; supports `targets:` field |
| Swatinem/rust-cache | @v2 | Cache cargo registry and build artifacts | Standard for Rust CI; understands workspaces with `workspaces: "rust"` |
| actions/upload-artifact | @v4 | Pass binaries between CI jobs | v3 deprecated Jan 2025; v4 required |
| actions/download-artifact | @v4 | Download binaries in release job | v3 deprecated Jan 2025; v4 required |
| softprops/action-gh-release | @v2 | Create GitHub release and attach archives | Current version (v2.5.0); already used in existing release.yml |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| ziglang (pip) | latest | Zig compiler for cargo-zigbuild | Install via `pip3 install ziglang` on ubuntu runners |
| musl-tools (apt) | system | musl-gcc for direct x86_64-musl (fallback) | Already works in rust-ci.yml without cargo-zigbuild |
| rustup target add | built-in | Add cross-compilation target | Used on macOS runner to add x86_64-apple-darwin target |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| cargo-zigbuild (Linux musl) | `cross` (Docker-based) | cross is more reliable for exotic targets but requires Docker and is slower; cargo-zigbuild is already proven for x86_64-musl in this project |
| macos-latest for macOS | cross-compile macOS from Linux | cargo-zigbuild Linux→Darwin is unreliable with Rust >=1.82 (iconv linker error, Issue #316); native macOS runner is safe |
| windows-latest MSVC | MinGW cross-compile from Linux | MinGW cross-compile has MSYS2 dependency complications; MSVC is the recommended default for Windows Rust |

## Architecture Patterns

### Recommended Project Structure
```
.github/workflows/
├── rust-ci.yml          # existing — extend with all 5 cross-compile targets
├── rust-release.yml     # new — triggered by v* tag, builds + releases Rust binary
├── release.yml          # existing — builds Zig binary (keep separate, untouched)
└── test.yml             # existing — Zig tests (keep untouched)

scripts/
└── release.sh           # existing — update to read version from rust/Cargo.toml
                         # (currently reads from src/main.zig)
```

### Pattern 1: Split Runner Strategy
**What:** Use a matrix across 3 different runner types. ubuntu-latest handles both Linux musl targets via cargo-zigbuild; macos-latest handles both macOS targets (native + cross within macOS); windows-latest handles Windows natively.
**When to use:** When targets have incompatible cross-compilation requirements (musl vs Darwin SDK vs MSVC).

**Rust CI matrix example (rust-ci.yml extension):**
```yaml
strategy:
  matrix:
    include:
      # Linux musl — both targets from ubuntu runner via cargo-zigbuild
      - name: linux-x86_64-musl
        os: ubuntu-latest
        target: x86_64-unknown-linux-musl
        use_zigbuild: true
      - name: linux-aarch64-musl
        os: ubuntu-latest
        target: aarch64-unknown-linux-musl
        use_zigbuild: true
      # macOS — native for aarch64, cross-target for x86_64
      - name: macos-aarch64
        os: macos-latest
        target: aarch64-apple-darwin
        use_zigbuild: false
      - name: macos-x86_64
        os: macos-latest
        target: x86_64-apple-darwin
        use_zigbuild: false
      # Windows — native MSVC
      - name: windows-x86_64
        os: windows-latest
        target: x86_64-pc-windows-msvc
        use_zigbuild: false
```

### Pattern 2: cargo-zigbuild for Linux Musl Targets
**What:** Install Zig via pip, install cargo-zigbuild, then run `cargo zigbuild` instead of `cargo build`.
**When to use:** Cross-compiling from ubuntu-latest to *-unknown-linux-musl targets.

```yaml
# Source: cargo-zigbuild README + existing rust-ci.yml pattern
- name: Install Zig
  run: pip3 install ziglang

- name: Install cargo-zigbuild
  run: cargo install --locked cargo-zigbuild

- name: Install Rust target
  run: rustup target add ${{ matrix.target }}

- name: Build release (zigbuild)
  working-directory: rust
  run: cargo zigbuild --release --target ${{ matrix.target }}
```

### Pattern 3: macOS Cross-Architecture (x86_64 from ARM64 runner)
**What:** On the ARM64 `macos-latest` runner, add `x86_64-apple-darwin` as a Rust target and build. The macOS SDK supports both architectures on the same machine.
**When to use:** Building the macOS Intel binary without needing an Intel runner.

```yaml
# Source: macOS Rust cross-compilation community consensus
- name: Install Rust stable with target
  uses: dtolnay/rust-toolchain@stable
  with:
    targets: ${{ matrix.target }}  # e.g. x86_64-apple-darwin

- name: Build release
  working-directory: rust
  run: cargo build --release --target ${{ matrix.target }}
```

### Pattern 4: Windows Native MSVC Build
**What:** On `windows-latest`, Rust defaults to `x86_64-pc-windows-msvc`. MSVC toolchain is pre-installed. Use `RUSTFLAGS=-C target-feature=+crt-static` for a fully static binary.
**When to use:** Building the Windows binary. Always prefer MSVC over MinGW for CI.

```yaml
- name: Build release (Windows)
  working-directory: rust
  env:
    RUSTFLAGS: "-C target-feature=+crt-static"
  run: cargo build --release --target x86_64-pc-windows-msvc
```

### Pattern 5: Release Workflow Structure
**What:** Separate release workflow triggered by `v*` tag push. Jobs: validate → build (matrix) → github-release.
**When to use:** Tagging a release version.

```yaml
on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
    inputs:
      version:
        description: "Version (e.g., 0.8.0)"
        required: true

jobs:
  validate:
    # Extract and validate semver from tag
  build:
    needs: validate
    strategy:
      matrix:
        include: [all 5 targets]
    # Build + archive + upload-artifact
  release:
    needs: [validate, build]
    permissions:
      contents: write
    # download-artifact + softprops/action-gh-release
```

### Pattern 6: Binary Archive Naming
**What:** Consistent naming convention for the 5 archives.

```
complexity-guard-linux-x86_64-musl.tar.gz
complexity-guard-linux-aarch64-musl.tar.gz
complexity-guard-macos-x86_64.tar.gz
complexity-guard-macos-aarch64.tar.gz
complexity-guard-windows-x86_64.zip
```

Note: Use OS-specific extensions — `.tar.gz` for Unix, `.zip` for Windows.

### Anti-Patterns to Avoid
- **Cross-compiling Darwin from Linux with cargo-zigbuild:** Rust >= 1.82 has reported iconv linker errors (cargo-zigbuild issue #316). Use a native macOS runner instead.
- **Using artifacts/upload-artifact v3:** Deprecated January 2025. All workflows must use v4.
- **Using x86_64-pc-windows-gnu instead of MSVC:** MinGW requires MSYS2 and has C library compatibility complications. MSVC is the standard Windows Rust target.
- **Using `macos-13` for Intel runner:** macOS 13 runner is retiring December 4, 2025. Do not use it. Use `macos-latest` (ARM64) and cross-target for x86_64-apple-darwin.
- **Separate CI jobs per target without matrix:** Duplicate workflow YAML is hard to maintain; use a matrix strategy.
- **Not caching cargo with workspaces:** `Swatinem/rust-cache@v2` needs `workspaces: "rust"` because the crate is in a subdirectory.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Linux musl cross-linking | Manual musl-gcc toolchain per arch | cargo-zigbuild | Zig handles aarch64-musl cross-linking without per-arch toolchain setup |
| Rust toolchain install in CI | Shell scripts | dtolnay/rust-toolchain@stable | Handles caching, components, target registration |
| Cargo build caching | Manual cache actions | Swatinem/rust-cache@v2 | Understands Rust incremental compilation semantics |
| GitHub release creation | gh CLI scripting | softprops/action-gh-release@v2 | Handles race conditions, retries, asset upload |

**Key insight:** tree-sitter's C build (`cc::Build`) means cargo-zigbuild must handle the C cross-compiler as well as the Rust linker — it does this transparently via the Zig toolchain, which is why it's preferred over musl-tools for aarch64-musl.

## Common Pitfalls

### Pitfall 1: Binary Size Already Exceeds 5 MB on macOS
**What goes wrong:** The current release binary on macOS arm64 is 5.0 MB, already at (or slightly exceeding) the documented 5 MB target. Other platforms (musl-stripped) will likely be smaller due to static linking optimizations.
**Why it happens:** tree-sitter + tree-sitter-typescript + tree-sitter-javascript compile substantial C code; minijinja, rayon, clap add further size. The 5 MB target was set when the binary was a stub (279 KB).
**How to avoid:** Measure actual sizes for all 5 targets in CI. Document the measured sizes and revise the target limit based on evidence. Consider `upx` compression as an optional post-processing step (not required for phase).
**Warning signs:** macOS binary at 5.0 MB means the musl binaries will likely be 4-6 MB before stripping. Check with `ls -lh` after each build.

### Pitfall 2: cargo-zigbuild Version vs Zig Version Compatibility
**What goes wrong:** cargo-zigbuild 0.22.x requires a compatible Zig version. If you install Zig via pip as `ziglang`, the version may not match what cargo-zigbuild expects.
**Why it happens:** cargo-zigbuild bundles Zig version requirements per release.
**How to avoid:** Use `pip3 install ziglang` (latest) and `cargo install --locked cargo-zigbuild`. Alternatively, use `cargo install cargo-zigbuild` which installs the current version.
**Warning signs:** Build errors mentioning "zig: command not found" or version mismatch errors.

### Pitfall 3: Cargo Workspace Not in Root
**What goes wrong:** Swatinem/rust-cache defaults to `./` as workspace root, but the Rust crate is in `rust/`. This causes the cache to miss.
**Why it happens:** The project has the Rust crate in a subdirectory (not the repo root).
**How to avoid:** Always set `workspaces: "rust"` in the rust-cache action.
**Warning signs:** Every CI run takes full rebuild time despite cache being configured.

### Pitfall 4: release.sh Still Points to Zig Source of Truth
**What goes wrong:** `scripts/release.sh` reads version from `src/main.zig`. For the Rust binary, the version source of truth is `rust/Cargo.toml`.
**Why it happens:** The script was written for the Zig binary. Phase 22 ships the Rust binary.
**How to avoid:** Update `scripts/release.sh` to read from `rust/Cargo.toml` using `grep '^version' rust/Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/'`.
**Warning signs:** Release script reports wrong version or fails to find version string.

### Pitfall 5: Windows Binary Not Statically Linked
**What goes wrong:** Windows binary dynamically links to MSVCRT, requiring the Visual C++ Redistributable installed on the user's machine.
**Why it happens:** Default MSVC target links CRT dynamically.
**How to avoid:** Set `RUSTFLAGS="-C target-feature=+crt-static"` for Windows builds to produce a fully self-contained binary.
**Warning signs:** Binary works in CI (where MSVC is installed) but fails for users without VS redistributable.

### Pitfall 6: `--version` Flag Test on Wrong Architecture
**What goes wrong:** CI tests the `--version` output but runs the binary on an incompatible architecture (e.g., running an x86_64-musl binary on the ubuntu runner that might be ARM).
**Why it happens:** The success criterion says "each built binary executes `--version` on a native runner". Each target must be tested on a matching runner.
**How to avoid:** For the CI verification step, run `--version` on the same runner that builds the binary. Linux musl x86_64 runs on ubuntu-latest (x86_64), which is compatible. macOS targets run on macos-latest (ARM64), which natively runs aarch64 but can run x86_64 via Rosetta 2. Windows runs on windows-latest (x86_64).

## Code Examples

Verified patterns from existing codebase and official sources:

### cargo-zigbuild Installation and Use (ubuntu-latest)
```yaml
# Based on existing rust-ci.yml pattern + cargo-zigbuild README
- name: Install Zig
  run: pip3 install ziglang

- name: Install cargo-zigbuild
  run: cargo install --locked cargo-zigbuild

- name: Add Rust target
  run: rustup target add aarch64-unknown-linux-musl

- name: Cache cargo
  uses: Swatinem/rust-cache@v2
  with:
    workspaces: "rust"

- name: Build release
  working-directory: rust
  run: cargo zigbuild --release --target aarch64-unknown-linux-musl

- name: Verify binary
  run: ./rust/target/aarch64-unknown-linux-musl/release/complexity-guard --version
  # Note: x86_64 musl binary runs natively on ubuntu-latest (x86_64)
  # aarch64 musl binary cannot run natively — skip execution test for aarch64 on ubuntu
```

### macOS Both Architectures (macos-latest, ARM64 runner)
```yaml
# aarch64-apple-darwin: native build
- name: Build (aarch64-apple-darwin native)
  working-directory: rust
  run: cargo build --release --target aarch64-apple-darwin

- name: Verify binary (aarch64 — native)
  run: ./rust/target/aarch64-apple-darwin/release/complexity-guard --version

# x86_64-apple-darwin: cross-target from ARM64 runner (macOS SDK covers both)
- name: Build (x86_64-apple-darwin cross)
  working-directory: rust
  run: cargo build --release --target x86_64-apple-darwin

- name: Verify binary (x86_64 — runs via Rosetta 2)
  run: ./rust/target/x86_64-apple-darwin/release/complexity-guard --version
```

### Windows Static Binary (windows-latest)
```yaml
# Source: Rust RFC 1721 crt-static + community practice
- name: Build release (Windows, static CRT)
  working-directory: rust
  env:
    RUSTFLAGS: "-C target-feature=+crt-static"
  run: cargo build --release --target x86_64-pc-windows-msvc

- name: Verify binary
  working-directory: rust
  run: ./target/x86_64-pc-windows-msvc/release/complexity-guard.exe --version
```

### Archive Creation Pattern
```bash
# Unix (.tar.gz)
cd rust/target/$TARGET/release
tar czf ../../../../complexity-guard-$NAME.tar.gz complexity-guard
cd ../../../..

# Windows (.zip, on windows-latest)
cd rust/target/x86_64-pc-windows-msvc/release
Compress-Archive -Path complexity-guard.exe -DestinationPath ../../../../complexity-guard-windows-x86_64.zip
```

### Binary Size Measurement
```bash
# After build — record for documentation
ls -lh rust/target/$TARGET/release/complexity-guard
# On Windows
ls -lh rust/target/x86_64-pc-windows-msvc/release/complexity-guard.exe
```

### Release Workflow Trigger Pattern
```yaml
on:
  push:
    branches-ignore:
      - '**'    # ignore all branch pushes
    tags:
      - 'v*'   # only tag pushes of the form v*
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (e.g., 0.8.0)'
        required: true
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| actions/upload-artifact v3 | v4 (required) | Jan 2025 | v3 no longer works; all workflows must use v4 |
| macos-latest = Intel (x86_64) | macos-latest = ARM64 (M-series) | 2024 | x86_64 macOS must be cross-compiled from ARM64 runner or use deprecated macos-13-intel |
| musl-tools for musl cross-compile | cargo-zigbuild (Zig linker) | 2023+ | cargo-zigbuild handles both aarch64 and x86_64 musl without per-arch toolchains |
| macOS 13 Intel runner | Retired Dec 4, 2025 | 2025 | Do not use macos-13; use macos-latest (ARM64) with cross-target |

**Deprecated/outdated:**
- `actions/upload-artifact@v3`: Deprecated January 2025, workflows using v3 fail.
- `macos-13` runner: Retiring December 4, 2025 (already past or imminent at research date).
- `mlugg/setup-zig@v2` in the existing release.yml: Only needed for Zig builds, not Rust.

## Open Questions

1. **Can aarch64-musl binary be execution-tested in CI?**
   - What we know: ubuntu-latest runners are x86_64. An aarch64-musl binary cannot run natively on x86_64.
   - What's unclear: Does the success criterion require *native runner execution* for aarch64-musl specifically? Phase 22 success criterion says "each built binary executes `--version` and produces correct output when run on a native runner of that platform."
   - Recommendation: For aarch64-linux-musl, a "native runner" would be a linux/arm64 runner. GitHub does not provide free arm64 Linux runners for public repos. Options: (a) skip execution test for aarch64-musl and document the gap; (b) use `qemu-user-static` on ubuntu-latest to emulate arm64 execution (medium complexity); (c) accept that the build succeeds and document the limitation. Option (a) or (b) recommended.

2. **Binary size: is the 5 MB target still valid?**
   - What we know: Current macOS arm64 release binary is 5.0 MB. The original 5 MB target was set at 279 KB stub size.
   - What's unclear: Will musl-stripped binaries be over 5 MB too?
   - Recommendation: Measure all 5 targets in CI and revise the documented target to match reality. Musl binaries with `strip = true` in Cargo.toml may be smaller than the macOS binary; record actuals.

3. **Does release.yml (Zig) need to be kept or replaced?**
   - What we know: The project is transitioning from Zig to Rust. The existing release.yml builds the Zig binary. Phase 22 delivers the Rust binary.
   - What's unclear: Whether the Zig release workflow should be retired or kept.
   - Recommendation: Create a separate `rust-release.yml` for the Rust binary. Keep `release.yml` intact but note it's for the legacy Zig binary. The two can coexist until the Rust binary is the official distribution.

4. **Should the release script be updated for Rust?**
   - What we know: `scripts/release.sh` reads version from `src/main.zig`. For v0.8, the version source of truth is `rust/Cargo.toml`.
   - Recommendation: Update `release.sh` to read from `rust/Cargo.toml` and update `rust/Cargo.toml` version (in addition to existing files). This is a small but necessary change for the Rust release flow to work correctly.

## Sources

### Primary (HIGH confidence)
- Existing `/Users/benvds/code/complexity-guard/.github/workflows/rust-ci.yml` — current Rust CI workflow, x86_64-musl already working
- Existing `/Users/benvds/code/complexity-guard/.github/workflows/release.yml` — Zig release workflow structure to adapt
- `/Users/benvds/code/complexity-guard/.planning/STATE.md` — decision: "cargo-zigbuild for Linux/macOS targets, native windows-latest runner for Windows"
- cargo-zigbuild README (https://github.com/rust-cross/cargo-zigbuild) — target support, pip installation, v0.22.1 current
- GitHub Actions runner docs (https://docs.github.com/en/actions/reference/runners/github-hosted-runners) — macos-latest = ARM64, windows-latest = x86_64

### Secondary (MEDIUM confidence)
- GitHub Changelog: macOS 13 retiring December 4, 2025 (https://github.blog/changelog/2025-09-19-github-actions-macos-13-runner-image-is-closing-down/)
- GitHub Actions Artifact v3 deprecation notice (https://github.blog/changelog/2024-04-16-deprecation-notice-v3-of-the-artifact-actions/) — verified: v4 required from January 2025
- cargo-zigbuild issue #316 (https://github.com/rust-cross/cargo-zigbuild/issues/316) — Rust >=1.82 macOS cross-compile iconv error from Linux
- Rust RFC 1721 crt-static (https://rust-lang.github.io/rfcs/1721-crt-static.html) — RUSTFLAGS for Windows static CRT

### Tertiary (LOW confidence)
- Binary size comparison data from WebSearch: musl binaries before/after strip can be 263KB–4MB range depending on dependencies; our tree-sitter binary will be larger

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — tools are well-documented, existing workflow validated x86_64-musl pattern, runner specs confirmed via official docs
- Architecture: HIGH — split runner strategy is directly derived from existing project decisions in STATE.md
- Pitfalls: HIGH (macOS deprecation, artifact v3, Windows CRT) / MEDIUM (binary size estimates) — deprecations confirmed via official changelogs

**Research date:** 2026-02-25
**Valid until:** 2026-05-25 (stable tooling — GitHub Actions runner changes are the main expiry risk)
