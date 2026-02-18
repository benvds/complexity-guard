# @complexity-guard/linux-arm64

This package contains the ComplexityGuard binary for Linux (ARM64).

## Do not install directly

This package is automatically installed as a dependency of the main [`complexity-guard`](https://www.npmjs.com/package/complexity-guard) package. Install that instead:

```sh
npm install -g complexity-guard
```

## What ComplexityGuard Measures

- **Cyclomatic Complexity** — independent code paths (testability)
- **Cognitive Complexity** — nesting-penalized readability score
- **Halstead Metrics** — vocabulary density, volume, difficulty, effort, estimated bugs
- **Structural Metrics** — function length, parameters, nesting depth, file length, exports
- **Health Score** — composite 0–100 score combining all metrics; enforce in CI with `--fail-health-below`
- **SARIF Output** — `--format sarif` generates SARIF 2.1.0 for GitHub Code Scanning inline PR annotations

## Links

- [complexity-guard on npm](https://www.npmjs.com/package/complexity-guard)
- [GitHub](https://github.com/benvds/complexity-guard)
- [Documentation](https://github.com/benvds/complexity-guard#documentation)

## License

MIT
