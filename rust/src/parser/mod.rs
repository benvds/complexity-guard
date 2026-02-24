use std::path::Path;

use crate::types::{ParseError, ParseResult};

/// Select the tree-sitter language based on file extension.
pub fn select_language(_path: &Path) -> Result<tree_sitter::Language, ParseError> {
    todo!("implement language selection")
}

/// Parse a file and extract function information.
pub fn parse_file(_path: &Path) -> Result<ParseResult, ParseError> {
    todo!("implement file parsing")
}
