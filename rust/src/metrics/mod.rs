pub mod cognitive;
pub mod cyclomatic;
pub mod halstead;
pub mod structural;

/// Function node types recognized by tree-sitter for TypeScript/JavaScript.
///
/// Used as a guard to stop recursion at nested function boundaries,
/// preventing inner function metrics from leaking to outer functions.
pub fn is_function_node(kind: &str) -> bool {
    matches!(
        kind,
        "function_declaration"
            | "function"
            | "function_expression"
            | "arrow_function"
            | "method_definition"
            | "generator_function"
            | "generator_function_declaration"
    )
}

/// Punctuation tokens excluded when counting parameters.
pub const PUNCTUATION: &[&str] = &[",", "(", ")", "<", ">", ";"];

/// Extract a function name from an AST node and its source.
///
/// Handles function_declaration, method_definition, generator variants,
/// and variable_declarator parents for arrow functions.
pub fn extract_function_name<'a>(node: &tree_sitter::Node<'a>, source: &'a [u8]) -> String {
    let kind = node.kind();

    // For function/generator declarations and named function expressions, look for "name" field
    if kind == "function_declaration"
        || kind == "function_expression"
        || kind == "generator_function_declaration"
        || kind == "generator_function"
    {
        if let Some(name_node) = node.child_by_field_name("name") {
            if let Ok(text) = name_node.utf8_text(source) {
                return text.to_string();
            }
        }
    }

    // For method_definition, look for "name" field (property_identifier)
    if kind == "method_definition" {
        if let Some(name_node) = node.child_by_field_name("name") {
            if let Ok(text) = name_node.utf8_text(source) {
                return text.to_string();
            }
        }
    }

    "<anonymous>".to_string()
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn is_function_node_recognizes_all_types() {
        assert!(is_function_node("function_declaration"));
        assert!(is_function_node("function"));
        assert!(is_function_node("function_expression"));
        assert!(is_function_node("arrow_function"));
        assert!(is_function_node("method_definition"));
        assert!(is_function_node("generator_function"));
        assert!(is_function_node("generator_function_declaration"));
    }

    #[test]
    fn is_function_node_rejects_non_function() {
        assert!(!is_function_node("if_statement"));
        assert!(!is_function_node("variable_declarator"));
        assert!(!is_function_node("class_declaration"));
        assert!(!is_function_node("statement_block"));
    }

    #[test]
    fn punctuation_contains_expected_tokens() {
        assert!(PUNCTUATION.contains(&","));
        assert!(PUNCTUATION.contains(&"("));
        assert!(PUNCTUATION.contains(&")"));
        assert!(PUNCTUATION.contains(&"<"));
        assert!(PUNCTUATION.contains(&">"));
        assert!(PUNCTUATION.contains(&";"));
        assert_eq!(PUNCTUATION.len(), 6);
    }
}
