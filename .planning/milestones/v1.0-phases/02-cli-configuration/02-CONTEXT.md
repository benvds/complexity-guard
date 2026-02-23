# Phase 2: CLI & Configuration - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can invoke `complexityguard` with flags and load configuration from files. Covers argument parsing (CLI-01 through CLI-12), config file loading (CFG-01 through CFG-07), and an interactive `--init` command. Does not cover output formatting (Phase 8), file discovery (Phase 3), or any metric computation.

</domain>

<decisions>
## Implementation Decisions

### Config file structure
- Top-level keys grouped by concern: `output` (format, file), `analysis` (metrics, thresholds), `files` (include, exclude), `weights`, `overrides`
- Thresholds nested by metric: `{ "cyclomatic": { "warning": 10, "error": 20 }, "cognitive": { ... } }`
- Per-path overrides array with glob patterns, like ESLint: `"overrides": [{ "files": ["tests/**"], "analysis": { ... } }]`

### Config file naming & formats
- Four config file names supported: `.complexityguard.json`, `complexityguard.config.json`, `.complexityguard.toml`, `complexityguard.config.toml`
- JSON and TOML both supported as formats
- First found wins (search order: dotfile JSON, config JSON, dotfile TOML, config TOML)

### Config discovery
- Search upward from CWD, stop at nearest `.git` directory
- Also check user-level config: `~/.config/complexityguard/config.json` or `~/.config/complexityguard/config.toml`
- Project config wins entirely over user config (no merge — if project config exists, user config is ignored)
- `--config` flag overrides all discovery

### Default behavior
- Bare `complexityguard` (no args, no config) analyzes current directory recursively for TS/JS files
- Equivalent to `complexityguard .`

### Init command
- `complexityguard --init` runs interactive setup, asks a few questions, generates config file
- Produces config with chosen settings plus comments explaining options

### Help output
- Compact style like ripgrep — short descriptions per flag, grouped by category, fits in one screen
- Groups: General, Output, Analysis, Files, Thresholds

### Error reporting
- Invalid flags: error + did-you-mean suggestion (Levenshtein distance matching)
- Invalid config: hard fail with exit code 3, clear error message pointing to the problem
- No lenient mode — broken config is always a hard stop

### Color output
- Auto-detect TTY: color when stdout is a terminal, plain when piped
- `--color` / `--no-color` flags to override

### Flag conventions
- Short aliases for key flags only: `-f` (format), `-o` (output), `-v` (verbose), `-q` (quiet), `-c` (config)
- `--metrics` accepts comma-separated values: `--metrics cyclomatic,cognitive,halstead`
- Results to stdout, diagnostics/errors/progress to stderr (pipeable)
- Flag values override config file values (CFG-07)

### CLI personality
- Inspired by ripgrep/fd: fast, focused, great defaults, compact help
- Respects `.gitignore` patterns when discovering files (in addition to include/exclude config)

### Claude's Discretion
- Exact flag grouping in help text
- `--init` question flow and default choices
- TOML parsing library choice (or hand-rolled)
- Config validation error message formatting
- Short flag assignments beyond the five listed above

</decisions>

<specifics>
## Specific Ideas

- "I want it to feel like ripgrep/fd" — fast, focused CLI with great defaults and compact help
- ESLint-style overrides array for per-path threshold customization
- XDG-like user config location (`~/.config/complexityguard/`)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-cli-configuration*
*Context gathered: 2026-02-14*
