use std::path::Path;

use crate::types::{FunctionInfo, ParseError, ParseResult};

/// Select the tree-sitter language grammar based on file extension.
///
/// Maps `.ts` to TypeScript, `.tsx` to TSX, `.js` and `.jsx` to JavaScript.
/// Returns `ParseError` for unsupported or missing extensions.
pub fn select_language(path: &Path) -> Result<tree_sitter::Language, ParseError> {
    match path.extension().and_then(|e| e.to_str()) {
        Some("ts") => Ok(tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()),
        Some("tsx") => Ok(tree_sitter_typescript::LANGUAGE_TSX.into()),
        Some("js") | Some("jsx") => Ok(tree_sitter_javascript::LANGUAGE.into()),
        Some(ext) => Err(ParseError::UnsupportedExtension(ext.to_string())),
        None => Err(ParseError::NoExtension),
    }
}

/// Parse a source file and extract function information.
///
/// Reads the file, selects the grammar by extension, parses with tree-sitter,
/// and extracts all function declarations into owned `FunctionInfo` structs.
/// No tree-sitter `Node` or `Tree` references escape this function.
pub fn parse_file(path: &Path) -> Result<ParseResult, ParseError> {
    // First check extension before attempting I/O
    let language = select_language(path)?;

    let source = std::fs::read(path)?;

    let mut parser = tree_sitter::Parser::new();
    parser
        .set_language(&language)
        .map_err(|e| ParseError::LanguageError(e.to_string()))?;

    let tree = parser.parse(&source, None).ok_or(ParseError::ParseFailed)?;

    let root = tree.root_node();
    let has_error = root.has_error();
    let functions = extract_functions(root, &source);

    Ok(ParseResult {
        path: path.to_path_buf(),
        functions,
        source_len: source.len(),
        error: has_error,
    })
}

/// Extract function declarations from the CST using DFS traversal.
///
/// Matches: `function_declaration`, `method_definition`, and `arrow_function`
/// when assigned to a variable via `variable_declarator` or `lexical_declaration`.
fn extract_functions(root: tree_sitter::Node, source: &[u8]) -> Vec<FunctionInfo> {
    let mut functions = Vec::new();
    let mut cursor = root.walk();

    traverse(&mut cursor, source, &mut functions);
    functions
}

fn traverse(
    cursor: &mut tree_sitter::TreeCursor,
    source: &[u8],
    functions: &mut Vec<FunctionInfo>,
) {
    loop {
        let node = cursor.node();

        match node.kind() {
            "function_declaration" | "method_definition" => {
                if let Some(name_node) = node.child_by_field_name("name") {
                    if let Ok(name) = name_node.utf8_text(source) {
                        functions.push(FunctionInfo {
                            name: name.to_string(),
                            start_line: node.start_position().row + 1,
                            start_column: node.start_position().column,
                            end_line: node.end_position().row + 1,
                        });
                    }
                }
            }
            // Arrow functions assigned to variables: const X = () => ...
            "variable_declarator" => {
                if has_arrow_function_value(&node) {
                    if let Some(name_node) = node.child_by_field_name("name") {
                        if let Ok(name) = name_node.utf8_text(source) {
                            // Get the arrow function node for position info
                            if let Some(value_node) = node.child_by_field_name("value") {
                                let arrow = if value_node.kind() == "arrow_function" {
                                    value_node
                                } else {
                                    // Could be a type assertion wrapping the arrow
                                    find_arrow_child(&value_node).unwrap_or(value_node)
                                };
                                functions.push(FunctionInfo {
                                    name: name.to_string(),
                                    start_line: arrow.start_position().row + 1,
                                    start_column: arrow.start_position().column,
                                    end_line: arrow.end_position().row + 1,
                                });
                            }
                        }
                    }
                }
            }
            _ => {}
        }

        // DFS: descend, advance sibling, or retreat
        if cursor.goto_first_child() {
            continue;
        }
        if cursor.goto_next_sibling() {
            continue;
        }
        loop {
            if !cursor.goto_parent() {
                return;
            }
            if cursor.goto_next_sibling() {
                break;
            }
        }
    }
}

/// Check if a variable_declarator has an arrow_function as its value
/// (possibly wrapped in a type assertion like `as React.FC<...>`).
fn has_arrow_function_value(node: &tree_sitter::Node) -> bool {
    if let Some(value) = node.child_by_field_name("value") {
        if value.kind() == "arrow_function" {
            return true;
        }
        // Check for type assertion wrapping: `X: Type = () => ...` or `X = () => ... as Type`
        if value.kind() == "as_expression"
            || value.kind() == "satisfies_expression"
            || value.kind() == "type_assertion"
        {
            return find_arrow_child(&value).is_some();
        }
    }
    false
}

/// Find an arrow_function child within a node (for unwrapping type assertions).
fn find_arrow_child<'a>(node: &'a tree_sitter::Node<'a>) -> Option<tree_sitter::Node<'a>> {
    let mut cursor = node.walk();
    if cursor.goto_first_child() {
        loop {
            if cursor.node().kind() == "arrow_function" {
                return Some(cursor.node());
            }
            if !cursor.goto_next_sibling() {
                break;
            }
        }
    }
    None
}
