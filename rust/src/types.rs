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
