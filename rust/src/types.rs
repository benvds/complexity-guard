use std::path::PathBuf;

/// Information about a single function extracted from a parsed source file.
///
/// All fields are owned data types suitable for cross-thread use.
/// Line numbers are 1-indexed, columns are 0-indexed.
#[derive(Debug, Clone)]
pub struct FunctionInfo {
    pub name: String,
    pub start_line: usize,
    pub start_column: usize,
    pub end_line: usize,
}

/// Result of parsing a single source file.
///
/// Contains only owned data — no references to tree-sitter `Node` or `Tree`.
#[derive(Debug, Clone)]
pub struct ParseResult {
    pub path: PathBuf,
    pub functions: Vec<FunctionInfo>,
    pub source_len: usize,
    pub error: bool,
}

/// Errors that can occur during file parsing.
#[derive(thiserror::Error, Debug)]
pub enum ParseError {
    #[error("unsupported file extension: {0}")]
    UnsupportedExtension(String),

    #[error("file has no extension")]
    NoExtension,

    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("language setup error: {0}")]
    LanguageError(String),

    #[error("tree-sitter parse returned None")]
    ParseFailed,
}

// --- Metric types ---

/// Switch/case counting modes for cyclomatic complexity.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
pub enum SwitchCaseMode {
    /// Each case increments complexity (+1 per case).
    Classic,
    /// Entire switch counts as single decision (+1 total).
    Modified,
}

/// Configuration for cyclomatic complexity calculation.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CyclomaticConfig {
    pub count_logical_operators: bool,
    pub count_nullish_coalescing: bool,
    pub count_optional_chaining: bool,
    pub count_ternary: bool,
    pub count_default_params: bool,
    pub switch_case_mode: SwitchCaseMode,
    pub warning_threshold: u32,
    pub error_threshold: u32,
}

impl Default for CyclomaticConfig {
    fn default() -> Self {
        Self {
            count_logical_operators: true,
            count_nullish_coalescing: true,
            count_optional_chaining: true,
            count_ternary: true,
            count_default_params: true,
            switch_case_mode: SwitchCaseMode::Classic,
            warning_threshold: 10,
            error_threshold: 20,
        }
    }
}

/// Per-function cyclomatic complexity result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct CyclomaticResult {
    pub name: String,
    pub complexity: u32,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

/// Per-function structural metric result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct StructuralResult {
    pub name: String,
    pub function_length: u32,
    pub params_count: u32,
    pub nesting_depth: u32,
    pub start_line: usize,
    pub end_line: usize,
    pub start_col: usize,
}

/// Per-file structural metric result.
#[derive(Debug, Clone, serde::Serialize)]
pub struct FileStructuralResult {
    pub file_length: u32,
    pub export_count: u32,
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cyclomatic_config_default_matches_zig() {
        let config = CyclomaticConfig::default();
        assert!(config.count_logical_operators);
        assert!(config.count_nullish_coalescing);
        assert!(config.count_optional_chaining);
        assert!(config.count_ternary);
        assert!(config.count_default_params);
        assert_eq!(config.switch_case_mode, SwitchCaseMode::Classic);
        assert_eq!(config.warning_threshold, 10);
        assert_eq!(config.error_threshold, 20);
    }
}
