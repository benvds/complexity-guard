use crate::metrics::is_function_node;
use crate::types::CognitiveResult;

/// Analyze all functions in the AST and return cognitive complexity for each.
pub fn analyze_functions(root: tree_sitter::Node, source: &[u8]) -> Vec<CognitiveResult> {
    let mut results = Vec::new();
    walk_and_analyze(root, source, &mut results, None);
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
    results: &mut Vec<CognitiveResult>,
    parent_ctx: Option<&NameContext>,
) {
    let kind = node.kind();

    if is_function_node(kind) {
        let mut name = crate::metrics::extract_function_name(&node, source);

        if let Some(ctx) = parent_ctx {
            if let Some(ref class_name) = ctx.class_name {
                if kind == "method_definition" && name != "<anonymous>" {
                    name = format!("{}.{}", class_name, name);
                }
            } else if name == "<anonymous>" && !ctx.name.is_empty() {
                name = ctx.name.clone();
            }
        }

        let complexity = calculate_cognitive_complexity(&node, source, &name);
        let start = node.start_position();
        let end = node.end_position();

        results.push(CognitiveResult {
            name,
            complexity,
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

/// Calculate cognitive complexity for a function node.
fn calculate_cognitive_complexity(
    node: &tree_sitter::Node,
    source: &[u8],
    function_name: &str,
) -> u32 {
    let mut complexity: u32 = 0;
    let mut nesting: u32 = 0;

    // Find statement_block body
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            if child.kind() == "statement_block" {
                for j in 0..child.child_count() as u32 {
                    if let Some(stmt) = child.child(j) {
                        visit_node_with_arrows(
                            stmt,
                            source,
                            &mut complexity,
                            &mut nesting,
                            function_name,
                        );
                    }
                }
                return complexity;
            }
        }
    }

    // Expression body arrow function
    if node.kind() == "arrow_function" {
        let mut found_arrow = false;
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() == "=>" {
                    found_arrow = true;
                    continue;
                }
                if found_arrow {
                    visit_node_with_arrows(
                        child,
                        source,
                        &mut complexity,
                        &mut nesting,
                        function_name,
                    );
                    return complexity;
                }
            }
        }
    }

    complexity
}

/// Arrow-aware visitor. Arrow functions inside a function body are treated as
/// callbacks (structural increment) rather than scope boundaries.
fn visit_node_with_arrows(
    node: tree_sitter::Node,
    source: &[u8],
    complexity: &mut u32,
    nesting: &mut u32,
    function_name: &str,
) {
    let kind = node.kind();

    // Arrow functions inside body = callbacks
    if kind == "arrow_function" {
        visit_arrow_callback(node, source, complexity, nesting, function_name);
        return;
    }

    // All other function nodes: stop (scope isolation)
    if is_function_node(kind) {
        return;
    }

    // if_statement: structural increment + recurse
    if kind == "if_statement" {
        *complexity += 1 + *nesting;
        *nesting += 1;
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() != "else_clause" {
                    visit_node_with_arrows(child, source, complexity, nesting, function_name);
                }
            }
        }
        *nesting -= 1;
        // Handle else clauses
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() == "else_clause" {
                    visit_else_clause_with_arrows(
                        child,
                        source,
                        complexity,
                        nesting,
                        function_name,
                    );
                }
            }
        }
        return;
    }

    if kind == "else_clause" {
        visit_else_clause_with_arrows(node, source, complexity, nesting, function_name);
        return;
    }

    // Structural increments: for/while/do/switch/ternary/catch
    if kind == "for_statement"
        || kind == "for_in_statement"
        || kind == "while_statement"
        || kind == "do_statement"
        || kind == "switch_statement"
        || kind == "ternary_expression"
    {
        *complexity += 1 + *nesting;
        *nesting += 1;
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
            }
        }
        *nesting -= 1;
        return;
    }

    if kind == "catch_clause" {
        *complexity += 1 + *nesting;
        *nesting += 1;
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
            }
        }
        *nesting -= 1;
        return;
    }

    // binary_expression: per-operator counting deviation
    if kind == "binary_expression" {
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                let ct = child.kind();
                if ct == "&&" || ct == "||" || ct == "??" {
                    *complexity += 1;
                } else {
                    visit_node_with_arrows(child, source, complexity, nesting, function_name);
                }
            }
        }
        return;
    }

    // call_expression: recursion detection
    if kind == "call_expression" {
        if let Some(callee) = node.child(0) {
            if callee.kind() == "identifier" {
                if let Ok(text) = callee.utf8_text(source) {
                    if !function_name.is_empty() && text == function_name {
                        *complexity += 1;
                    }
                }
            }
        }
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
            }
        }
        return;
    }

    // break/continue with label
    if kind == "break_statement" || kind == "continue_statement" {
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                if child.kind() == "statement_identifier" {
                    *complexity += 1;
                    break;
                }
            }
        }
        return;
    }

    // Default: recurse
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            visit_node_with_arrows(child, source, complexity, nesting, function_name);
        }
    }
}

/// Handle else_clause with arrow awareness.
fn visit_else_clause_with_arrows(
    node: tree_sitter::Node,
    source: &[u8],
    complexity: &mut u32,
    nesting: &mut u32,
    function_name: &str,
) {
    // +1 flat for the else
    *complexity += 1;

    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            let ct = child.kind();
            if ct == "else" {
                continue;
            }
            if ct == "if_statement" {
                // else if: continuation at current nesting
                visit_if_as_continuation_with_arrows(
                    child,
                    source,
                    complexity,
                    nesting,
                    function_name,
                );
                return;
            } else {
                // else { block }: increase nesting for block contents
                *nesting += 1;
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
                *nesting -= 1;
                return;
            }
        }
    }
}

/// Visit an if_statement as an "else if" continuation.
fn visit_if_as_continuation_with_arrows(
    node: tree_sitter::Node,
    source: &[u8],
    complexity: &mut u32,
    nesting: &mut u32,
    function_name: &str,
) {
    *complexity += 1 + *nesting;
    *nesting += 1;
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            if child.kind() != "else_clause" {
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
            }
        }
    }
    *nesting -= 1;
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            if child.kind() == "else_clause" {
                visit_else_clause_with_arrows(
                    child,
                    source,
                    complexity,
                    nesting,
                    function_name,
                );
            }
        }
    }
}

/// Visit an arrow_function as a callback (structural increment + nesting).
fn visit_arrow_callback(
    node: tree_sitter::Node,
    source: &[u8],
    complexity: &mut u32,
    nesting: &mut u32,
    function_name: &str,
) {
    *complexity += 1 + *nesting;
    *nesting += 1;
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            let ct = child.kind();
            if ct == "statement_block" {
                // Visit children of the block
                for j in 0..child.child_count() as u32 {
                    if let Some(stmt) = child.child(j) {
                        visit_node_with_arrows(stmt, source, complexity, nesting, function_name);
                    }
                }
            } else if ct != "formal_parameters"
                && ct != "identifier"
                && ct != "=>"
                && ct != "("
                && ct != ")"
                && ct != "type_annotation"
            {
                // Expression body arrow
                visit_node_with_arrows(child, source, complexity, nesting, function_name);
            }
        }
    }
    *nesting -= 1;
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn parse_and_analyze(source: &str) -> Vec<CognitiveResult> {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();
        analyze_functions(root, source.as_bytes())
    }

    fn find_by_name<'a>(
        results: &'a [CognitiveResult],
        name: &str,
    ) -> Option<&'a CognitiveResult> {
        results.iter().find(|r| r.name == name)
    }

    #[test]
    fn cognitive_cases_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/cognitive_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let results = parse_and_analyze(&source);

        assert_eq!(find_by_name(&results, "baseline").unwrap().complexity, 0);
        assert_eq!(find_by_name(&results, "singleIf").unwrap().complexity, 1);
        assert_eq!(
            find_by_name(&results, "ifElseChain").unwrap().complexity,
            4
        );
        assert_eq!(
            find_by_name(&results, "nestedIfInLoop").unwrap().complexity,
            6
        );
        assert_eq!(
            find_by_name(&results, "logicalOps").unwrap().complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "mixedLogicalOps").unwrap().complexity,
            4
        );
        assert_eq!(
            find_by_name(&results, "factorial").unwrap().complexity,
            2
        );
        assert_eq!(
            find_by_name(&results, "topLevelArrow").unwrap().complexity,
            1
        );
        assert_eq!(
            find_by_name(&results, "withCallback").unwrap().complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "switchStatement").unwrap().complexity,
            1
        );
        assert_eq!(
            find_by_name(&results, "tryCatch").unwrap().complexity,
            1
        );
        assert_eq!(
            find_by_name(&results, "ternaryNested").unwrap().complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "MyClass.classMethod")
                .unwrap()
                .complexity,
            3
        );
        assert_eq!(
            find_by_name(&results, "deeplyNested").unwrap().complexity,
            10
        );
        assert_eq!(
            find_by_name(&results, "labeledBreak").unwrap().complexity,
            7
        );
        assert_eq!(
            find_by_name(&results, "noIncrement").unwrap().complexity,
            0
        );
    }

    #[test]
    fn complex_nested_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/complex_nested.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let results = parse_and_analyze(&source);

        assert_eq!(
            find_by_name(&results, "processData").unwrap().complexity,
            35
        );
    }

    #[test]
    fn per_operator_counting_deviation() {
        // Each && and || counts as +1 individually, not grouped
        let source = r#"
function test(a: boolean, b: boolean, c: boolean, d: boolean): boolean {
    return a && b && c || d;
}
"#;
        let results = parse_and_analyze(source);
        // 3 operators: &&, &&, || = 3 flat
        assert_eq!(results[0].complexity, 3);
    }

    #[test]
    fn else_if_continuation_flat() {
        let source = r#"
function test(x: number): string {
    if (x > 0) {
        return "a";
    } else if (x < 0) {
        return "b";
    }
    return "c";
}
"#;
        let results = parse_and_analyze(source);
        // if (+1 at nesting 0) + else (+1 flat) + if continuation (+1 at nesting 0) = 3
        assert_eq!(results[0].complexity, 3);
    }
}
