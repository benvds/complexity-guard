---
status: resolved
issue_type: uat-diagnosis
trigger: "Publication files (package.json, bin/, npm/, homebrew/) are at project root. User wants them scoped to publication/npm/ and publication/homebrew/"
created: 2026-02-15T17:00:00Z
updated: 2026-02-15T17:15:00Z
---

## ROOT CAUSE ANALYSIS

### Why Files Are at Project Root

Publication-related files were placed at the project root during Phase 5.1 (CI/CD Release Pipeline) implementation. The structure follows a pragmatic pattern:

1. **Main package.json** at root — npm convention for published packages (required for `npm publish` to work)
2. **bin/complexity-guard.js** at root — npm `bin` field references relative path `bin/complexity-guard.js`, which must be relative to package.json location
3. **npm/\*/** directories at root — Store platform-specific packages with their own package.json files; referenced directly in release workflows
4. **homebrew/complexity-guard.rb** at root — Homebrew formula file

This design is functional but violates the user's project organization preference for publication artifacts to be scoped to a `publication/` folder.

---

## ARTIFACTS TO MOVE

### Files Requiring Movement

1. **package.json** (root)
   - Current: `/Users/benvds/code/complexity-guard/package.json`
   - Target: `/Users/benvds/code/complexity-guard/publication/npm/package.json`
   - Note: This is the MAIN package (not platform-specific)

2. **bin/complexity-guard.js** (entire directory)
   - Current: `/Users/benvds/code/complexity-guard/bin/complexity-guard.js`
   - Target: `/Users/benvds/code/complexity-guard/publication/npm/bin/complexity-guard.js`

3. **npm/** (entire directory with all platform packages)
   - Current: `/Users/benvds/code/complexity-guard/npm/`
   - Target: `/Users/benvds/code/complexity-guard/publication/npm/npm/`
   - Contents:
     - `npm/darwin-arm64/package.json`
     - `npm/darwin-x64/package.json`
     - `npm/linux-arm64/package.json`
     - `npm/linux-x64/package.json`
     - `npm/windows-x64/package.json`
   - Plus binaries (added during release): `complexity-guard`, `complexity-guard.exe`

4. **homebrew/** (entire directory)
   - Current: `/Users/benvds/code/complexity-guard/homebrew/complexity-guard.rb`
   - Target: `/Users/benvds/code/complexity-guard/publication/homebrew/complexity-guard.rb`

---

## FILES THAT REFERENCE THESE PATHS

### Critical References Requiring Updates

#### 1. **.github/workflows/release.yml** (18 references)
   - **Line 177-189**: Extract binaries to `npm/\*` directories
     ```yaml
     tar xzf complexity-guard-x86_64-linux.tar.gz -C npm/linux-x64/
     tar xzf complexity-guard-aarch64-linux.tar.gz -C npm/linux-arm64/
     tar xzf complexity-guard-x86_64-macos.tar.gz -C npm/darwin-x64/
     tar xzf complexity-guard-aarch64-macos.tar.gz -C npm/darwin-arm64/
     unzip -o complexity-guard-x86_64-windows.zip -d npm/windows-x64/
     ```
     → Update to: `publication/npm/npm/\*`

   - **Line 192-200**: Verify binaries in `npm/$pkg/` and `npm/windows-x64/`
     ```yaml
     if [ ! -f "npm/$pkg/complexity-guard" ]; then
     if [ ! -f "npm/windows-x64/complexity-guard.exe" ]; then
     ```
     → Update to: `publication/npm/npm/\*`

   - **Line 213**: Update versions in platform package.json files
     ```yaml
     for pkg in npm/darwin-arm64 npm/darwin-x64 npm/linux-arm64 npm/linux-x64 npm/windows-x64; do
       sed -i.bak "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" "$pkg/package.json"
     ```
     → Update to: `publication/npm/npm/\*`

   - **Line 209**: Update main package.json version
     ```yaml
     sed -i.bak "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" package.json
     ```
     → Update to: `publication/npm/package.json`

   - **Line 219**: Update optionalDependencies in main package.json
     ```yaml
     sed -i.bak -E "s/.../" package.json
     ```
     → Update to: `publication/npm/package.json`

   - **Line 227**: Publish each platform package
     ```yaml
     for pkg in npm/darwin-arm64 npm/darwin-x64 npm/linux-arm64 npm/linux-x64 npm/windows-x64; do
       cd "$pkg"
     ```
     → Update to: `publication/npm/npm/\*`

   - **Line 238**: Publish main package
     ```yaml
     npm publish --access public  # from root directory context
     ```
     → Must be run from: `publication/npm/`

   - **Line 278-286**: Update Homebrew formula version and SHA256 placeholders
     ```yaml
     sed -i.bak "s/version \".*\"/version \"$VERSION\"/" homebrew/complexity-guard.rb
     sed -i.bak "s/PLACEHOLDER_SHA256_AARCH64_MACOS/..." homebrew/complexity-guard.rb
     ```
     → Update to: `publication/homebrew/complexity-guard.rb`

   - **Line 294**: Manual copy instruction
     ```yaml
     echo "::notice::Manual step: Copy homebrew/complexity-guard.rb to Homebrew tap repository."
     ```
     → Update to: `publication/homebrew/complexity-guard.rb`

#### 2. **scripts/release.sh** (1 reference)
   - **Line 54-56**: Update main package.json
     ```bash
     sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" package.json
     ```
     → Update to: `publication/npm/package.json`

   - **Line 61-67**: Update platform package.json files
     ```bash
     for pkg_json in npm/*/package.json; do
       sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" "$pkg_json"
       git add "$pkg_json"
     done
     ```
     → Update to: `publication/npm/npm/*/package.json`

#### 3. **scripts/publish.sh** (4 references)
   - **Line 56**: Construct platform package directory path
     ```bash
     pkg_dir="$PROJECT_ROOT/npm/$platform"
     ```
     → Update to: `$PROJECT_ROOT/publication/npm/npm/$platform`

   - **Line 57**: Check platform package.json exists
     ```bash
     if [ ! -f "$pkg_dir/package.json" ]; then
     ```
     → No change (uses variable)

   - **Line 62**: Publish from platform directory
     ```bash
     (cd "$pkg_dir" && npm publish ...)
     ```
     → No change (uses variable)

   - **Line 67**: Publish main package
     ```bash
     (cd "$PROJECT_ROOT" && npm publish ...)
     ```
     → Update to: `(cd "$PROJECT_ROOT/publication/npm" && npm publish ...)`

#### 4. **package.json** (1 reference)
   - **Line 6**: Bin field references local script
     ```json
     "bin": {
       "complexity-guard": "bin/complexity-guard.js"
     }
     ```
     → Must remain: `bin/complexity-guard.js` (relative to its new location at `publication/npm/package.json`)

#### 5. **.gitignore** (2 references)
   - **Line 27-28**: Ignore platform binaries
     ```
     npm/*/complexity-guard
     npm/*/complexity-guard.exe
     ```
     → Update to: `publication/npm/npm/*/complexity-guard` and `publication/npm/npm/*/complexity-guard.exe`

#### 6. **PUBLISHING.md** (3 references)
   - **Line 40**: Prerequisites reference `npm/<platform>/`
     ```
     Platform binaries in `npm/<platform>/` directories
     ```
     → Update to: `publication/npm/npm/<platform>/`

   - **Line 48-60**: Cross-compile example paths
     ```
     cp zig-out/bin/complexity-guard npm/darwin-arm64/
     cp zig-out/bin/complexity-guard npm/darwin-x64/
     ...
     cp zig-out/bin/complexity-guard.exe npm/windows-x64/
     ```
     → Update to: `publication/npm/npm/\*`

   - **Line 75**: Script documentation
     ```
     ./scripts/publish.sh
     ```
     → No change (script path remains same)

#### 7. **CLAUDE.md** (1 reference)
   - Mentions project structure but may reference paths
   - Review for any hardcoded publication paths

#### 8. **.planning/phases/05.1-ci-cd-release-pipeline-documentation/05.1-UAT.md** (Documentation)
   - Line 32: UAT test 4 explicitly states issue
   - Gap documented: "Publication files scoped to publication/ folder"

---

## MISSING STRUCTURES

### Directory Creation Needed

```
publication/
├── npm/
│   ├── package.json (main package, moved from root)
│   ├── bin/
│   │   └── complexity-guard.js (moved from /bin/)
│   └── npm/
│       ├── darwin-arm64/
│       │   ├── package.json
│       │   └── [binaries added at release time]
│       ├── darwin-x64/
│       │   ├── package.json
│       │   └── [binaries added at release time]
│       ├── linux-arm64/
│       │   ├── package.json
│       │   └── [binaries added at release time]
│       ├── linux-x64/
│       │   ├── package.json
│       │   └── [binaries added at release time]
│       └── windows-x64/
│           ├── package.json
│           └── [binaries added at release time]
└── homebrew/
    └── complexity-guard.rb (moved from /homebrew/)
```

---

## SUMMARY OF CHANGES REQUIRED

### File Moves (8 items)
1. `package.json` → `publication/npm/package.json`
2. `bin/complexity-guard.js` → `publication/npm/bin/complexity-guard.js`
3. `npm/darwin-arm64/` → `publication/npm/npm/darwin-arm64/`
4. `npm/darwin-x64/` → `publication/npm/npm/darwin-x64/`
5. `npm/linux-arm64/` → `publication/npm/npm/linux-arm64/`
6. `npm/linux-x64/` → `publication/npm/npm/linux-x64/`
7. `npm/windows-x64/` → `publication/npm/npm/windows-x64/`
8. `homebrew/complexity-guard.rb` → `publication/homebrew/complexity-guard.rb`

### Workflow/Script Updates (4 files)
1. `.github/workflows/release.yml` — 18 path references
2. `scripts/release.sh` — 2 path references
3. `scripts/publish.sh` — 2 path references
4. `.gitignore` — 2 path references

### Documentation Updates (2 files)
1. `PUBLISHING.md` — 3 path references
2. `CLAUDE.md` — Structure documentation (review for hardcoded paths)

### Total Impact
- **8 files/directories to move**
- **4 configuration files to update** (23+ total path references)
- **2 documentation files to update** (5+ path references)

---

## IMPLEMENTATION NOTES

### Considerations
1. **npm publishing location** — When publishing, `npm publish` must be run from directory containing `package.json`; workflow must cd into `publication/npm/`
2. **Relative paths** — `bin/complexity-guard.js` reference in package.json remains correct (relative to its new location)
3. **Git tracking** — Platform binaries are gitignored; .gitkeep files in npm/ subdirectories should also be moved
4. **Release workflow complexity** — Multiple path changes will require careful sed pattern updates to avoid breaking the workflow

---

## UAT REQUIREMENT MET

This diagnosis addresses the UAT test 4 failure:
- **Issue**: "why is this placed in the root of the directory? i'd rather have publications scoped to a folder, so: publication/npm and publication/homebrew"
- **Resolution**: Complete mapping of all files to move and all references to update to achieve desired structure
