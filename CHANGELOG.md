# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/benvds/complexity-guard/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/benvds/complexity-guard/releases/tag/v0.1.0
