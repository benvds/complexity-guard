use std::path::{Path, PathBuf};

use globset::{GlobSet, GlobSetBuilder};
use walkdir::WalkDir;

/// Directory names that are always excluded from file discovery.
///
/// Matches the Zig `EXCLUDED_DIRS` constant in `src/discovery/filter.zig`.
pub const EXCLUDED_DIRS: &[&str] = &[
    "node_modules",
    ".git",
    "dist",
    "build",
    ".next",
    "coverage",
    "__pycache__",
    ".svn",
    ".hg",
    "vendor",
];

/// Returns true if the file extension is one of .ts, .tsx, .js, or .jsx.
fn is_target_extension(path: &Path) -> bool {
    match path.extension().and_then(|e| e.to_str()) {
        Some("ts" | "tsx" | "js" | "jsx") => true,
        _ => false,
    }
}

/// Returns true if the path ends with `.d.ts` or `.d.tsx` (TypeScript declaration files).
fn is_declaration_file(path: &Path) -> bool {
    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or_default();
    name.ends_with(".d.ts") || name.ends_with(".d.tsx")
}

/// Constructs a `GlobSet` from a slice of glob pattern strings.
fn build_globset(patterns: &[String]) -> anyhow::Result<GlobSet> {
    let mut builder = GlobSetBuilder::new();
    for pat in patterns {
        builder.add(globset::Glob::new(pat)?);
    }
    Ok(builder.build()?)
}

/// Returns true if the file should be included in analysis.
///
/// A file is included when:
/// - It has a target extension (.ts/.tsx/.js/.jsx)
/// - It is not a TypeScript declaration file (.d.ts/.d.tsx)
/// - It is not matched by any exclude pattern
/// - Either no include patterns are provided, or at least one include pattern matches
fn should_include(path: &Path, exclude: &GlobSet, include: &Option<GlobSet>) -> bool {
    if !is_target_extension(path) {
        return false;
    }
    if is_declaration_file(path) {
        return false;
    }
    if exclude.is_match(path) {
        return false;
    }
    if let Some(inc) = include {
        if !inc.is_match(path) {
            return false;
        }
    }
    true
}

/// Discover all analysable source files under the given paths.
///
/// For each path:
/// - If a directory: recursively walks the tree, pruning `EXCLUDED_DIRS` early,
///   and collects files passing the include/exclude glob filters.
/// - If a file: includes it directly if it passes the filters.
///
/// Returns a `Vec<PathBuf>` with all discovered files (order matches walk order
/// within each input path; caller is responsible for sorting if determinism is needed).
pub fn discover_files(
    paths: &[PathBuf],
    include_patterns: &[String],
    exclude_patterns: &[String],
) -> anyhow::Result<Vec<PathBuf>> {
    let exclude = build_globset(exclude_patterns)?;
    let include = if include_patterns.is_empty() {
        None
    } else {
        Some(build_globset(include_patterns)?)
    };

    let mut result = Vec::new();

    for path in paths {
        if path.is_dir() {
            let walker = WalkDir::new(path)
                .into_iter()
                .filter_entry(|e| {
                    // Prune excluded directory names early to avoid descending into them.
                    if e.file_type().is_dir() {
                        if let Some(name) = e.file_name().to_str() {
                            if EXCLUDED_DIRS.contains(&name) {
                                return false;
                            }
                        }
                    }
                    true
                });

            for entry in walker.filter_map(|e| e.ok()) {
                if entry.file_type().is_file() {
                    let p = entry.into_path();
                    if should_include(&p, &exclude, &include) {
                        result.push(p);
                    }
                }
            }
        } else if should_include(path, &exclude, &include) {
            result.push(path.clone());
        }
    }

    Ok(result)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn test_is_target_extension() {
        assert!(is_target_extension(Path::new("file.ts")));
        assert!(is_target_extension(Path::new("file.tsx")));
        assert!(is_target_extension(Path::new("file.js")));
        assert!(is_target_extension(Path::new("file.jsx")));

        assert!(!is_target_extension(Path::new("file.rs")));
        assert!(!is_target_extension(Path::new("file.py")));
        assert!(!is_target_extension(Path::new("file.json")));
        assert!(!is_target_extension(Path::new("file.css")));
        assert!(!is_target_extension(Path::new("file")));
    }

    #[test]
    fn test_is_declaration_file() {
        assert!(is_declaration_file(Path::new("types.d.ts")));
        assert!(is_declaration_file(Path::new("global.d.tsx")));
        assert!(is_declaration_file(Path::new("path/to/types.d.ts")));

        assert!(!is_declaration_file(Path::new("file.ts")));
        assert!(!is_declaration_file(Path::new("file.tsx")));
        assert!(!is_declaration_file(Path::new("file.js")));
    }

    #[test]
    fn test_excluded_dirs_matches_zig() {
        // Must contain exactly these 10 entries matching src/discovery/filter.zig
        assert_eq!(EXCLUDED_DIRS.len(), 10);
        assert!(EXCLUDED_DIRS.contains(&"node_modules"));
        assert!(EXCLUDED_DIRS.contains(&".git"));
        assert!(EXCLUDED_DIRS.contains(&"dist"));
        assert!(EXCLUDED_DIRS.contains(&"build"));
        assert!(EXCLUDED_DIRS.contains(&".next"));
        assert!(EXCLUDED_DIRS.contains(&"coverage"));
        assert!(EXCLUDED_DIRS.contains(&"__pycache__"));
        assert!(EXCLUDED_DIRS.contains(&".svn"));
        assert!(EXCLUDED_DIRS.contains(&".hg"));
        assert!(EXCLUDED_DIRS.contains(&"vendor"));
    }

    #[test]
    fn test_discover_files_fixture_dir() {
        let fixture_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript");

        let paths = vec![fixture_dir];
        let files = discover_files(&paths, &[], &[]).unwrap();

        // Should find .ts and .tsx files
        assert!(!files.is_empty(), "should find fixture files");
        for f in &files {
            let ext = f.extension().and_then(|e| e.to_str()).unwrap_or("");
            assert!(
                matches!(ext, "ts" | "tsx" | "js" | "jsx"),
                "unexpected extension in {:?}",
                f
            );
            // No declaration files
            let name = f.file_name().and_then(|n| n.to_str()).unwrap_or("");
            assert!(
                !name.ends_with(".d.ts") && !name.ends_with(".d.tsx"),
                "declaration file should be excluded: {:?}",
                f
            );
        }

        // Verify known fixture files are present
        let names: Vec<_> = files
            .iter()
            .filter_map(|f| f.file_name().and_then(|n| n.to_str()))
            .collect();
        assert!(names.contains(&"simple_function.ts"), "should find simple_function.ts");
        assert!(names.contains(&"cyclomatic_cases.ts"), "should find cyclomatic_cases.ts");
    }

    #[test]
    fn test_discover_files_single_file() {
        let fixture = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/simple_function.ts");

        let paths = vec![fixture.clone()];
        let files = discover_files(&paths, &[], &[]).unwrap();

        assert_eq!(files.len(), 1);
        assert_eq!(files[0], fixture);
    }

    #[test]
    fn test_discover_files_exclude_pattern() {
        let fixture_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript");

        let paths = vec![fixture_dir];
        let exclude = vec!["**/*_cases.ts".to_string()];
        let files = discover_files(&paths, &[], &exclude).unwrap();

        // No *_cases.ts files should be present
        for f in &files {
            let name = f.file_name().and_then(|n| n.to_str()).unwrap_or("");
            assert!(
                !name.ends_with("_cases.ts"),
                "excluded file still present: {:?}",
                f
            );
        }

        // But other .ts files should still be present
        let names: Vec<_> = files
            .iter()
            .filter_map(|f| f.file_name().and_then(|n| n.to_str()))
            .collect();
        assert!(names.contains(&"simple_function.ts"), "simple_function.ts should still be included");
    }
}
