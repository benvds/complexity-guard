use crate::metrics::is_function_node;
use crate::types::{CyclomaticConfig, CyclomaticResult, SwitchCaseMode};

/// Analyze all functions in the AST and return cyclomatic complexity for each.
///
/// Walks the tree using DFS, finds function nodes via `is_function_node()`,
/// computes decision points for each, and returns base complexity 1 + decision count.
pub fn analyze_functions(
    root: tree_sitter::Node,
    source: &[u8],
    config: &CyclomaticConfig,
) -> Vec<CyclomaticResult> {
    let mut results = Vec::new();
    walk_and_analyze(root, source, config, &mut results, None);
    results
}

/// Name context passed from parent nodes to resolve anonymous function names.
struct NameContext {
    name: String,
    class_name: Option<String>,
}

fn walk_and_analyze(
    node: tree_sitter::Node,
    source: &[u8],
    config: &CyclomaticConfig,
    results: &mut Vec<CyclomaticResult>,
    parent_ctx: Option<&NameContext>,
) {
    let kind = node.kind();

    if is_function_node(kind) {
        let mut name = crate::metrics::extract_function_name(&node, source);

        // Apply parent context naming (variable_declarator -> arrow, class -> method)
        if let Some(ctx) = parent_ctx {
            if let Some(ref class_name) = ctx.class_name {
                // Class method: "ClassName.methodName"
                if kind == "method_definition" && name != "<anonymous>" {
                    name = format!("{}.{}", class_name, name);
                }
            } else if name == "<anonymous>" && !ctx.name.is_empty() {
                name = ctx.name.clone();
            }
        }

        let start = node.start_position();
        let end = node.end_position();
        let complexity = calculate_complexity(&node, config, source);

        results.push(CyclomaticResult {
            name,
            complexity,
            start_line: start.row + 1,
            end_line: end.row + 1,
            start_col: start.column,
        });

        // Don't recurse into nested functions -- they are analyzed separately
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
        // Pass through parent context
        if let Some(ctx) = parent_ctx {
            child_ctx = Some(NameContext {
                name: ctx.name.clone(),
                class_name: ctx.class_name.clone(),
            });
        }
    }

    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            walk_and_analyze(
                child,
                source,
                config,
                results,
                child_ctx.as_ref().or(parent_ctx),
            );
        }
    }
}

/// Calculate cyclomatic complexity for a function node.
/// Base complexity is 1 plus the number of decision points.
fn calculate_complexity(
    node: &tree_sitter::Node,
    config: &CyclomaticConfig,
    source: &[u8],
) -> u32 {
    // Look for statement_block child (function body)
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            if child.kind() == "statement_block" {
                return 1 + count_decision_points(child, config, source);
            }
        }
    }
    // Expression body arrow function: count on whole node
    1 + count_decision_points(*node, config, source)
}

/// Count decision points in an AST subtree.
///
/// Stops recursion at nested function boundaries.
fn count_decision_points(
    node: tree_sitter::Node,
    config: &CyclomaticConfig,
    source: &[u8],
) -> u32 {
    let kind = node.kind();
    let mut count: u32 = 0;

    // Stop at nested function boundaries
    if is_function_node(kind) {
        return 0;
    }

    // Control flow statements that always count
    match kind {
        "if_statement" | "while_statement" | "do_statement" | "for_statement"
        | "for_in_statement" | "catch_clause" => {
            count += 1;
        }
        "ternary_expression" if config.count_ternary => {
            count += 1;
        }
        "switch_statement" if config.switch_case_mode == SwitchCaseMode::Modified => {
            count += 1;
        }
        "switch_case" if config.switch_case_mode == SwitchCaseMode::Classic => {
            // Count each case that has an expression child (not bare default)
            let mut has_expression = false;
            for i in 0..node.child_count() as u32 {
                if let Some(child) = node.child(i) {
                    let ct = child.kind();
                    if ct != "case" && ct != ":" && ct != "default" {
                        has_expression = true;
                        break;
                    }
                }
            }
            if has_expression {
                count += 1;
            }
        }
        "binary_expression" => {
            for i in 0..node.child_count() as u32 {
                if let Some(child) = node.child(i) {
                    let ct = child.kind();
                    if config.count_logical_operators && (ct == "&&" || ct == "||") {
                        count += 1;
                    } else if config.count_nullish_coalescing && ct == "??" {
                        count += 1;
                    }
                }
            }
        }
        "augmented_assignment_expression" => {
            for i in 0..node.child_count() as u32 {
                if let Some(child) = node.child(i) {
                    let ct = child.kind();
                    if config.count_logical_operators && (ct == "&&=" || ct == "||=") {
                        count += 1;
                    }
                }
            }
        }
        _ => {}
    }

    // Optional chaining: check for ?. token in member/call/subscript expressions
    if config.count_optional_chaining
        && (kind == "member_expression"
            || kind == "call_expression"
            || kind == "subscript_expression")
    {
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() == "?." {
                    count += 1;
                    break;
                }
            }
        }
    }

    // Recurse into children
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            count += count_decision_points(child, config, source);
        }
    }

    count
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn parse_and_analyze(source: &str, config: &CyclomaticConfig) -> Vec<CyclomaticResult> {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();
        analyze_functions(root, source.as_bytes(), config)
    }

    fn find_by_name<'a>(
        results: &'a [CyclomaticResult],
        name: &str,
    ) -> Option<&'a CyclomaticResult> {
        results.iter().find(|r| r.name == name)
    }

    #[test]
    fn cyclomatic_cases_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/cyclomatic_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let config = CyclomaticConfig::default();
        let results = parse_and_analyze(&source, &config);

        assert_eq!(find_by_name(&results, "baseline").unwrap().complexity, 1);
        assert_eq!(
            find_by_name(&results, "simpleConditionals")
                .unwrap()
                .complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "loopWithConditions")
                .unwrap()
                .complexity,
            5
        );
        assert_eq!(
            find_by_name(&results, "switchStatement")
                .unwrap()
                .complexity,
            5
        );
        assert_eq!(
            find_by_name(&results, "errorHandling").unwrap().complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "ternaryAndLogical")
                .unwrap()
                .complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "nullishCoalescing")
                .unwrap()
                .complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "nestedFunctions")
                .unwrap()
                .complexity,
            2
        );
        assert_eq!(
            find_by_name(&results, "arrowFunc").unwrap().complexity,
            2
        );
        assert_eq!(
            find_by_name(&results, "complexLogical").unwrap().complexity,
            5
        );
        assert_eq!(
            find_by_name(&results, "DataProcessor.process")
                .unwrap()
                .complexity,
            2
        );
    }

    #[test]
    fn complex_nested_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/complex_nested.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let config = CyclomaticConfig::default();
        let results = parse_and_analyze(&source, &config);

        assert_eq!(
            find_by_name(&results, "processData").unwrap().complexity,
            11
        );
    }

    #[test]
    fn switch_modified_mode() {
        let source = r#"
function test(x: string): number {
    switch (x) {
        case "a": return 1;
        case "b": return 2;
        case "c": return 3;
        default: return 0;
    }
}
"#;
        let mut config = CyclomaticConfig::default();
        config.switch_case_mode = SwitchCaseMode::Modified;
        let results = parse_and_analyze(source, &config);

        // Modified mode: base 1 + 1 for the switch = 2
        assert_eq!(results[0].complexity, 2);
    }
}
