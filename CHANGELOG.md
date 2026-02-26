# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.1] - 2026-02-26

### Fixed

- Restore npm-publish job to release workflow

## [0.9.0] - 2026-02-25

### Added

- Restore benchmark scripts from main with Rust build commands
- Promote Rust code to project root, update all references
- Add bench-rust-vs-zig.sh benchmark script
- Update releasing docs and sync publication READMEs
- Update main README and docs for Rust binary
- Update release.sh to read version from rust/Cargo.toml
- Add rust-release.yml workflow for GitHub releases
- Extend rust-ci.yml with 5-target cross-compilation matrix
- Add exit code 4 unreachability documentation test
- Write integration test suite with 29 tests covering all requirements
- Fix function name extraction for callback and export patterns
- Rewrite duplication JSON output to match Zig schema
- Rewrite console renderer to Zig consolidated per-function format
- Wire full pipeline into main.rs replacing placeholder stub
- Add pipeline/parallel.rs with rayon-based parallel analysis
- Add pipeline/discover.rs with recursive glob-filtered file discovery
- Implement self-contained HTML report with embedded CSS/JS and minijinja template
- Implement SARIF 2.1.0 output with hand-rolled serde structs
- Implement JSON output renderer with exact Zig schema parity
- Implement console output renderer with ESLint-style format
- Add exit code logic and wire main.rs entry point
- Add CLI modules — args, config, merge, discovery
- Add scoring, duplication, and analyze_file entry point (18-03)
- Add cognitive complexity and Halstead metrics
- Add metrics module with cyclomatic and structural metrics
- Add GitHub Actions CI for Rust crate
- Implement parser with language selection and function extraction
- Scaffold Rust crate with grammar dependencies and core types

### Fixed

- Resolve clippy lint and CI failures, update release script
- Resolve all clippy lint warnings failing CI
- Resolve CI failures for formatting and Windows cross-compile
- Set test working directory to project root in build.zig
- Fix cognitive_error default and arrow callback scope boundary bug
- Revise plans based on checker feedback
- Revise plans based on checker feedback
- Revise plans based on checker feedback
- Revise plans based on checker feedback
- Revise plans based on checker feedback

## [0.7.0] - 2026-02-23

### Added

- Enhance function naming with class, callback, and export context
- Expand --init to generate complete config with all 12 threshold categories
- Remove --save-baseline from source code
- Wire four pipeline gaps in main.zig, exit_codes.zig, parallel.zig
- Add duplication to SARIF output with relatedLocations and HTML report with heatmap
- Add duplication benchmark script and update benchmarks documentation
- Add duplication output to console and JSON formats, update exit codes
- Wire duplication into pipeline, scoring, and threshold system
- Add --duplication CLI flag, DuplicationThresholds config, and merge logic
- Implement Rabin-Karp duplication detection with tokenization and cross-file indexing
- Add example config which always passes
- Add memory-check CI job to test workflow
- Add memory leak and thread-safety check script
- Add elapsed_ms and thread_count to JSON output metadata
- Implement parallel file analysis via thread pool
- Display system specs in benchmark summary and update documentation
- Add system spec capture to bench scripts and create baseline system-info.json
- Port Python scripts to Node.js and replace inline Python in shell scripts with jq
- Create bench-subsystems.sh and add bench-build step
- Create comprehensive benchmark documentation
- Create Zig subsystem benchmark module and bench step
- Create metric accuracy comparison and results summary scripts
- Create hyperfine benchmark scripts (quick, full, stress)
- Create benchmark directory structure and setup.sh clone script
- Add public real world projects index

### Fixed

- Replace helgrind suppressions with universal catch-all
- Clone zod repo for memory stress test in CI
- Add universal Helgrind suppressions to fix CI false positives
- Resolve memory leak and helgrind false positives in check-memory.sh
- Wire all threshold config fields through to analysis and display
- Fix thread safety in parallel analysis — protect shared arena allocator with mutex
- Switch release builds to ReleaseSmall to meet DIST-01 binary size requirement
- Revise plans based on checker feedback

## [0.6.0] - 2026-02-20

### Added

- Replace HTML table with CSS grid and details elements in file breakdown
- Add file table, visualizations, and interactive drill-down
- Wire html_output into main.zig format dispatch
- Create html_output.zig with self-contained HTML report builder

### Fixed

- Use CSS-only middle truncation for text in HTML report
- Cleanup html output for file row
- Fix file path truncation for mobile viewports
- Remove letter grade from HTML report dashboard
- Strip trailing slashes from directory paths to prevent double slashes

## [0.5.0] - 2026-02-18

### Added

- Update docs and READMEs for SARIF output support
- Create SARIF output documentation page
- Wire SARIF output into main.zig format dispatch
- Implement SARIF 2.1.0 output module

### Fixed

- Correct repository URLs from AstroTechDev to benvds

## [0.4.0] - 2026-02-17

### Added

- Add example config
- Simplify --init to always write default config
- Enhanced --init with analysis, weight optimization, and baseline capture
- Add --save-baseline flag and --fail-health-below CLI override
- Wire scoring pipeline into main, console, and JSON output
- Config baseline field, ThresholdResult health_score, determineExitCode baseline_failed param
- Implement scoring module - sigmoid normalization and composite computation

### Fixed

- Copy baseline field in deepCopyConfig

## [0.3.0] - 2026-02-17

### Added

- Wire --metrics flag through to console output layer
- Update output layer for Halstead and structural metrics
- Extend ThresholdResult and wire pipeline in main.zig
- Implement structural metrics core with TDD coverage
- Implement Halstead metrics core with TDD coverage

## [0.2.1] - 2026-02-17

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

[Unreleased]: https://github.com/benvds/complexity-guard/compare/v0.9.1...HEAD
[0.9.1]: https://github.com/benvds/complexity-guard/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/benvds/complexity-guard/compare/v0.7.0...v0.9.0
[0.7.0]: https://github.com/benvds/complexity-guard/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/benvds/complexity-guard/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/benvds/complexity-guard/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/benvds/complexity-guard/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/benvds/complexity-guard/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/benvds/complexity-guard/compare/v0.2.0...v0.2.1
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
