---
created: 2026-02-26T06:04:48.841Z
title: Add cargo install publication via crates.io
area: general
files:
  - Cargo.toml
  - publication/
---

## Problem

The project currently supports npm install and Homebrew as distribution channels, but Rust users cannot install via `cargo install complexity-guard`. Publishing to crates.io would provide an additional installation method for users who already have the Rust toolchain installed, without needing Node.js or Homebrew.

The current Cargo.toml is missing required crates.io metadata fields: `description`, `license`, `repository`, `keywords`, `categories`, and optionally `homepage` and `documentation`.

## Solution

1. Add required crates.io metadata to `Cargo.toml`:
   - `description`: short description of the tool
   - `license`: project license (check existing LICENSE file)
   - `repository`: GitHub repo URL
   - `keywords`: e.g. `["complexity", "typescript", "javascript", "static-analysis", "code-quality"]`
   - `categories`: e.g. `["command-line-utilities", "development-tools"]`
   - `exclude`: patterns for files not needed in the crate (benchmarks/, .planning/, publication/, tests/fixtures/)
2. Add a `cargo publish` step to the release workflow (`.github/workflows/`)
3. Update README.md and docs to list `cargo install complexity-guard` as an installation option
4. Update publication READMEs to stay in sync
