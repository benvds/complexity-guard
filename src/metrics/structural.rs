use crate::metrics::{is_function_node, PUNCTUATION};
use crate::types::{FileStructuralResult, StructuralResult};

/// Analyze all functions in the AST and return structural metrics for each.
pub fn analyze_functions(root: tree_sitter::Node, source: &[u8]) -> Vec<StructuralResult> {
    let mut results = Vec::new();
    walk_and_analyze(root, source, &mut results, None);
    results
}

/// Compute file-level structural metrics.
pub fn analyze_file(source: &[u8], root: tree_sitter::Node) -> FileStructuralResult {
    let file_length = count_logical_lines(source, 0, source.len());
    let export_count = count_exports(root);
    FileStructuralResult {
        file_length,
        export_count,
    }
}

/// Name context passed from parent nodes to resolve anonymous function names.
struct NameContext {
    name: String,
    class_name: Option<String>,
}

fn walk_and_analyze(
    node: tree_sitter::Node,
    source: &[u8],
    results: &mut Vec<StructuralResult>,
    parent_ctx: Option<&NameContext>,
) {
    let kind = node.kind();

    if is_function_node(kind) {
        let mut name = crate::metrics::extract_function_name(&node, source);

        // Apply parent context naming
        if let Some(ctx) = parent_ctx {
            if let Some(ref class_name) = ctx.class_name {
                if kind == "method_definition" && name != "<anonymous>" {
                    name = format!("{}.{}", class_name, name);
                }
            } else if name == "<anonymous>" && !ctx.name.is_empty() {
                name = ctx.name.clone();
            }
        }

        let start = node.start_position();
        let end = node.end_position();

        // Compute function_length and nesting_depth
        let mut function_length: u32 = 1; // default for expression-body arrows
        let mut nesting_depth: u32 = 0;

        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() == "statement_block" {
                    function_length = count_logical_lines(
                        source,
                        child.start_byte(),
                        child.end_byte(),
                    );
                    nesting_depth = max_nesting_depth(child);
                    break;
                }
            }
        }

        let params_count = count_parameters(node);

        results.push(StructuralResult {
            name,
            function_length,
            params_count,
            nesting_depth,
            start_line: start.row + 1,
            end_line: end.row + 1,
            start_col: start.column,
        });

        // Don't recurse into nested functions
        return;
    }

    // Build naming context for children
    let mut child_ctx: Option<NameContext> = None;

    if kind == "variable_declarator" {
        if let Some(name_node) = node.child_by_field_name("name") {
            if let Ok(text) = name_node.utf8_text(source) {
                child_ctx = Some(NameContext {
                    name: text.to_string(),
                    class_name: None,
                });
            }
        }
    } else if kind == "class_declaration" || kind == "class" {
        let mut class_name = "class".to_string();
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                let ct = child.kind();
                if ct == "identifier" || ct == "type_identifier" {
                    if let Ok(text) = child.utf8_text(source) {
                        class_name = text.to_string();
                    }
                    break;
                }
            }
        }
        child_ctx = Some(NameContext {
            name: "<anonymous>".to_string(),
            class_name: Some(class_name),
        });
    } else if kind == "class_body" || kind == "arguments" {
        if let Some(ctx) = parent_ctx {
            child_ctx = Some(NameContext {
                name: ctx.name.clone(),
                class_name: ctx.class_name.clone(),
            });
        }
    }

    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            walk_and_analyze(child, source, results, child_ctx.as_ref().or(parent_ctx));
        }
    }
}

/// Count logical lines in a byte range of source text.
///
/// Skips blank lines, single-line comments (//), block comment interiors,
/// and standalone brace lines ({, }, };, },).
pub fn count_logical_lines(source: &[u8], start_byte: usize, end_byte: usize) -> u32 {
    let bounded_end = end_byte.min(source.len());
    if start_byte >= bounded_end {
        return 0;
    }

    let text = &source[start_byte..bounded_end];
    let text_str = String::from_utf8_lossy(text);
    let mut count: u32 = 0;
    let mut in_block_comment = false;

    for raw_line in text_str.split('\n') {
        let line = raw_line.trim();

        if in_block_comment {
            if let Some(close_idx) = line.find("*/") {
                in_block_comment = false;
                let after_close = line[close_idx + 2..].trim();
                if !after_close.is_empty() {
                    count += 1;
                }
            }
            continue;
        }

        // Skip blank lines
        if line.is_empty() {
            continue;
        }

        // Skip standalone brace-only lines
        if line == "{" || line == "}" || line == "};" || line == "}," {
            continue;
        }

        // Skip single-line comments
        if line.starts_with("//") {
            continue;
        }

        // Handle block comment start
        if line.starts_with("/*") {
            if let Some(close_idx) = line[2..].find("*/") {
                // Inline block comment -- check for code after
                let after_close = line[2 + close_idx + 2..].trim();
                if !after_close.is_empty() {
                    count += 1;
                }
            } else {
                in_block_comment = true;
            }
            continue;
        }

        // Skip lines that are part of block comment body (e.g., " * text")
        if line.starts_with('*') && in_block_comment {
            continue;
        }

        count += 1;
    }

    count
}

/// Count parameters for a function node.
///
/// Counts non-punctuation children of `formal_parameters` and `type_parameters`.
pub fn count_parameters(function_node: tree_sitter::Node) -> u32 {
    let mut count: u32 = 0;

    for i in 0..function_node.child_count() as u32 {
        if let Some(child) = function_node.child(i) {
            let child_type = child.kind();

            if child_type == "formal_parameters" || child_type == "type_parameters" {
                for j in 0..child.child_count() as u32 {
                    if let Some(param) = child.child(j) {
                        let param_type = param.kind();
                        if !PUNCTUATION.contains(&param_type) {
                            count += 1;
                        }
                    }
                }
            }
        }
    }

    count
}

/// Check if a node kind is a nesting construct.
fn is_nesting_construct(kind: &str) -> bool {
    matches!(
        kind,
        "if_statement"
            | "for_statement"
            | "for_in_statement"
            | "while_statement"
            | "do_statement"
            | "switch_statement"
            | "catch_clause"
            | "ternary_expression"
    )
}

/// Compute the maximum nesting depth within a function body node.
fn max_nesting_depth(function_body: tree_sitter::Node) -> u32 {
    let mut max_depth: u32 = 0;
    for i in 0..function_body.child_count() as u32 {
        if let Some(child) = function_body.child(i) {
            walk_nesting(child, 0, &mut max_depth);
        }
    }
    max_depth
}

fn walk_nesting(node: tree_sitter::Node, current_depth: u32, max_depth: &mut u32) {
    let kind = node.kind();

    // Stop at nested function boundaries
    if is_function_node(kind) {
        return;
    }

    if is_nesting_construct(kind) {
        let new_depth = current_depth + 1;
        if new_depth > *max_depth {
            *max_depth = new_depth;
        }
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                walk_nesting(child, new_depth, max_depth);
            }
        }
    } else {
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                walk_nesting(child, current_depth, max_depth);
            }
        }
    }
}

/// Count export_statement nodes at program root level.
fn count_exports(root: tree_sitter::Node) -> u32 {
    let mut count: u32 = 0;
    for i in 0..root.child_count() as u32 {
        if let Some(child) = root.child(i) {
            if child.kind() == "export_statement" {
                count += 1;
            }
        }
    }
    count
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn parse_ts(source: &str) -> (tree_sitter::Tree, Vec<u8>) {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let bytes = source.as_bytes().to_vec();
        let tree = parser.parse(&bytes, None).unwrap();
        (tree, bytes)
    }

    fn find_by_name<'a>(
        results: &'a [StructuralResult],
        name: &str,
    ) -> Option<&'a StructuralResult> {
        results.iter().find(|r| r.name == name)
    }

    #[test]
    fn logical_lines_code_only() {
        let source = b"{\n  const a = 1;\n  const b = 2;\n  return a + b;\n}";
        assert_eq!(count_logical_lines(source, 0, source.len()), 3);
    }

    #[test]
    fn logical_lines_skips_blanks() {
        let source = b"{\n  const a = 1;\n\n  const b = 2;\n\n  return a + b;\n}";
        assert_eq!(count_logical_lines(source, 0, source.len()), 3);
    }

    #[test]
    fn logical_lines_skips_comments() {
        let source = b"{\n  // comment\n  const a = 1;\n  // another\n  return a;\n}";
        assert_eq!(count_logical_lines(source, 0, source.len()), 2);
    }

    #[test]
    fn logical_lines_skips_block_comments() {
        let source = b"{\n  /*\n   * Block\n   */\n  const a = 1;\n  return a;\n}";
        assert_eq!(count_logical_lines(source, 0, source.len()), 2);
    }

    #[test]
    fn logical_lines_empty_range() {
        let source = b"some source";
        assert_eq!(count_logical_lines(source, 5, 5), 0);
    }

    #[test]
    fn arrow_function_expression_body_length_1() {
        let (tree, bytes) = parse_ts("const double = (x: number) => x * 2;");
        let root = tree.root_node();
        let results = analyze_functions(root, &bytes);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].function_length, 1);
        assert_eq!(results[0].name, "double");
    }

    #[test]
    fn structural_cases_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/structural_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let (tree, bytes) = parse_ts(&source);
        let root = tree.root_node();
        let results = analyze_functions(root, &bytes);

        // shortFunction: line_count=3, params_count=1, nesting_depth=0
        let r = find_by_name(&results, "shortFunction").unwrap();
        assert_eq!(r.function_length, 3);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 0);

        // longFunctionWithComments: line_count=4, params_count=1, nesting_depth=0
        let r = find_by_name(&results, "longFunctionWithComments").unwrap();
        assert_eq!(r.function_length, 4);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 0);

        // singleExpressionArrow: line_count=1, params_count=1, nesting_depth=0
        let r = find_by_name(&results, "singleExpressionArrow").unwrap();
        assert_eq!(r.function_length, 1);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 0);

        // manyParams: line_count=1, params_count=7, nesting_depth=0
        let r = find_by_name(&results, "manyParams").unwrap();
        assert_eq!(r.function_length, 1);
        assert_eq!(r.params_count, 7);
        assert_eq!(r.nesting_depth, 0);

        // noParams: line_count=1, params_count=0, nesting_depth=0
        let r = find_by_name(&results, "noParams").unwrap();
        assert_eq!(r.function_length, 1);
        assert_eq!(r.params_count, 0);
        assert_eq!(r.nesting_depth, 0);

        // destructuredParams: line_count=1, params_count=2, nesting_depth=0
        let r = find_by_name(&results, "destructuredParams").unwrap();
        assert_eq!(r.function_length, 1);
        assert_eq!(r.params_count, 2);
        assert_eq!(r.nesting_depth, 0);

        // flatFunction: line_count=2, params_count=1, nesting_depth=0
        let r = find_by_name(&results, "flatFunction").unwrap();
        assert_eq!(r.function_length, 2);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 0);

        // deeplyNested: line_count=8, params_count=1, nesting_depth=4
        let r = find_by_name(&results, "deeplyNested").unwrap();
        assert_eq!(r.function_length, 8);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 4);

        // nestedFunctionScope: line_count=8, params_count=1, nesting_depth=1
        let r = find_by_name(&results, "nestedFunctionScope").unwrap();
        assert_eq!(r.function_length, 8);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 1);

        // File-level metrics
        let file_result = analyze_file(&bytes, root);
        assert_eq!(file_result.file_length, 41);
        assert_eq!(file_result.export_count, 4);
    }

    #[test]
    fn count_parameters_with_type_params() {
        let (tree, _bytes) = parse_ts("function f<T, U>(a: T, b: U): void {}");
        let root = tree.root_node();
        if let Some(func_node) = root.child(0) {
            let count = count_parameters(func_node);
            assert_eq!(count, 4); // 2 type params + 2 runtime params
        }
    }
}
