# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-02-17

### Added

- Console and JSON output integration for cognitive complexity
- Pipeline integration — run both metrics, merge into ThresholdResult
- Register cognitive module in main.zig test block
- Implement cognitive complexity algorithm
- Create cognitive test fixture and extend ThresholdResult

### Fixed

- Revise plans based on checker feedback

## [0.1.9] - 2026-02-16

### Added

- Backfill CHANGELOG.md for v0.1.1 through v0.1.8
- Add changelog generation to release script

### Fixed

- Update GitHub release name to complexity-guard@version format

## [0.1.8] - 2026-02-16

### Added

- Create platform binary package READMEs
- Create main npm package README
- Add initial npm publish script

## [0.1.7] - 2026-02-16

### Added

- Switch npm publish to OIDC trusted publishing (no token needed)

### Fixed

- Normalize npm package.json repository URLs to git+https format

## [0.1.6] - 2026-02-16

### Fixed

- Update optionalDependencies versions and automate future bumps

## [0.1.5] - 2026-02-16

## [0.1.4] - 2026-02-16

### Fixed

- Add validate to npm-publish job needs for version access

## [0.1.3] - 2026-02-16

### Fixed

- Replace std.posix.getenv with cross-platform APIs

## [0.1.2] - 2026-02-16

### Added

- Update path references to publication/ directory
- Add confirmation and push to release script
- Add tag push trigger and conditional logic to release workflow

### Fixed

- Add submodule checkout to CI workflows

## [0.1.1] - 2026-02-15

### Added

- CI test workflow with GitHub Actions
- Release script for automated version bumping
- GitHub Actions release workflow with cross-platform builds
- npm platform packages and wrapper script
- Homebrew formula template
- Comprehensive user documentation (getting started, CLI reference, examples)
- Release process documentation

## [0.1.0] - 2026-02-15

### Added

- Cyclomatic complexity analysis for TypeScript/JavaScript functions
- Console output with ESLint-style formatting and threshold indicators
- JSON output format for CI integration
- Configuration file support (.complexityguard.json)
- Configurable thresholds (warning: 10, error: 20)
- Recursive file discovery with extension filtering (.ts, .tsx, .js, .jsx)
- Tree-sitter based parsing with error-tolerant syntax handling
- CLI with --help, --version, --verbose, --quiet, --format, --output, --config, --init flags

[Unreleased]: https://github.com/benvds/complexity-guard/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/benvds/complexity-guard/compare/v0.1.9...v0.2.0
[0.1.9]: https://github.com/benvds/complexity-guard/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/benvds/complexity-guard/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/benvds/complexity-guard/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/benvds/complexity-guard/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/benvds/complexity-guard/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/benvds/complexity-guard/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/benvds/complexity-guard/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/benvds/complexity-guard/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/benvds/complexity-guard/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/benvds/complexity-guard/releases/tag/v0.1.0
