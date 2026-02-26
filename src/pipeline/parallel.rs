use std::path::PathBuf;

use rayon::prelude::*;

use crate::metrics::analyze_file;
use crate::types::{AnalysisConfig, FileAnalysisResult, SkipReason, SkippedItem, MAX_FILE_LINES};

/// Outcome of processing a single file in the parallel pipeline.
enum FileOutcome {
    Analyzed(Result<(FileAnalysisResult, Vec<SkippedItem>), crate::types::ParseError>),
    Skipped(SkippedItem),
}

/// Analyze a collection of files in parallel using a rayon thread pool.
///
/// Uses a local thread pool (not the global one) to avoid interference between
/// concurrent test runs. Results are sorted by path for deterministic output.
///
/// Files exceeding `MAX_FILE_LINES` lines are skipped entirely (no parsing).
/// Functions exceeding `MAX_FUNCTION_LINES` lines are excluded from results.
///
/// Returns a tuple of `(results, has_parse_errors, skipped)` where:
/// - `results` is the sorted list of successfully analyzed files
/// - `has_parse_errors` is `true` if any file failed to parse
/// - `skipped` is the list of files/functions that were skipped due to size limits
pub fn analyze_files_parallel(
    paths: &[PathBuf],
    config: &AnalysisConfig,
    threads: u32,
) -> (Vec<FileAnalysisResult>, bool, Vec<SkippedItem>) {
    // Use a large stack size (64 MiB) to prevent stack overflow when traversing
    // deeply nested ASTs in large real-world TypeScript files (e.g. the TypeScript
    // compiler itself). The default rayon stack (~2–8 MiB) is too small for
    // recursive metric walkers operating on ASTs with nesting depths in the
    // hundreds or thousands.
    const STACK_SIZE: usize = 64 * 1024 * 1024; // 64 MiB

    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(threads as usize)
        .stack_size(STACK_SIZE)
        .build()
        .expect("failed to build rayon thread pool");

    let outcomes: Vec<FileOutcome> = pool.install(|| {
        paths
            .par_iter()
            .map(|p| {
                // Fast pre-check: read file bytes and count newlines to enforce file size limit.
                // This avoids invoking tree-sitter on pathologically large files.
                let bytes = match std::fs::read(p) {
                    Ok(b) => b,
                    Err(_) => {
                        // Let analyze_file handle I/O errors properly
                        return FileOutcome::Analyzed(analyze_file(p, config));
                    }
                };
                let line_count = bytes.iter().filter(|&&b| b == b'\n').count() + 1;
                if line_count > MAX_FILE_LINES {
                    return FileOutcome::Skipped(SkippedItem {
                        path: p.clone(),
                        function_name: None,
                        start_line: 0,
                        reason: SkipReason::FileTooLarge {
                            lines: line_count,
                            max_lines: MAX_FILE_LINES,
                        },
                    });
                }
                FileOutcome::Analyzed(analyze_file(p, config))
            })
            .collect()
    });

    let mut files: Vec<FileAnalysisResult> = Vec::new();
    let mut skipped: Vec<SkippedItem> = Vec::new();
    let mut has_parse_errors = false;

    for outcome in outcomes {
        match outcome {
            FileOutcome::Skipped(item) => {
                skipped.push(item);
            }
            FileOutcome::Analyzed(Ok((file_result, fn_skipped))) => {
                skipped.extend(fn_skipped);
                files.push(file_result);
            }
            FileOutcome::Analyzed(Err(_)) => {
                has_parse_errors = true;
            }
        }
    }

    // Sort by path for deterministic, cross-platform output (PIPE-03).
    files.sort_by(|a, b| a.path.cmp(&b.path));

    (files, has_parse_errors, skipped)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn fixture(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript")
            .join(name)
    }

    #[test]
    fn test_analyze_parallel_single_file() {
        let paths = vec![fixture("simple_function.ts")];
        let config = AnalysisConfig::default();
        let (results, has_errors, skipped) = analyze_files_parallel(&paths, &config, 1);

        assert_eq!(results.len(), 1, "should return one result");
        assert!(
            !has_errors,
            "simple fixture should not produce parse errors"
        );
        assert!(skipped.is_empty(), "no files should be skipped");

        let result = &results[0];
        assert_eq!(result.functions.len(), 1);
        assert_eq!(result.functions[0].name, "greet");
    }

    #[test]
    fn test_analyze_parallel_multiple_files() {
        let paths = vec![
            fixture("simple_function.ts"),
            fixture("cyclomatic_cases.ts"),
            fixture("cognitive_cases.ts"),
        ];
        let config = AnalysisConfig::default();
        let (results, has_errors, skipped) = analyze_files_parallel(&paths, &config, 2);

        assert_eq!(results.len(), 3, "all three files should be analyzed");
        assert!(!has_errors, "fixture files should parse cleanly");
        assert!(skipped.is_empty(), "no files should be skipped");

        // Results must be sorted by path
        for i in 1..results.len() {
            assert!(
                results[i - 1].path <= results[i].path,
                "results should be sorted by path: {:?} > {:?}",
                results[i - 1].path,
                results[i].path
            );
        }
    }

    #[test]
    fn test_analyze_parallel_deterministic_order() {
        let paths = vec![
            fixture("structural_cases.ts"),
            fixture("halstead_cases.ts"),
            fixture("cognitive_cases.ts"),
            fixture("cyclomatic_cases.ts"),
        ];
        let config = AnalysisConfig::default();

        let (results1, _, _) = analyze_files_parallel(&paths, &config, 4);
        let (results2, _, _) = analyze_files_parallel(&paths, &config, 4);

        assert_eq!(
            results1.len(),
            results2.len(),
            "both runs should return same count"
        );
        for (r1, r2) in results1.iter().zip(results2.iter()) {
            assert_eq!(
                r1.path, r2.path,
                "paths should be in identical order across runs"
            );
        }
    }

    #[test]
    fn test_analyze_parallel_invalid_file_returns_error() {
        // A .rs file is not a supported language; analyze_file returns an error for it.
        let invalid = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("src/lib.rs");
        let valid = fixture("simple_function.ts");

        let paths = vec![invalid, valid];
        let config = AnalysisConfig::default();
        let (results, has_errors, _skipped) = analyze_files_parallel(&paths, &config, 2);

        assert!(
            has_errors,
            "unsupported file should trigger parse error flag"
        );
        // The valid .ts file should still produce a result
        assert_eq!(results.len(), 1, "valid file should still be analyzed");
        let name = results[0]
            .path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("");
        assert_eq!(name, "simple_function.ts");
    }
}
