use rustc_hash::FxHashMap;

use crate::metrics::is_function_node;
use crate::types::HalsteadResult;

/// Analyze all functions in the AST and return Halstead metrics for each.
pub fn analyze_functions(root: tree_sitter::Node, source: &[u8]) -> Vec<HalsteadResult> {
    let mut results = Vec::new();
    walk_and_analyze(root, source, &mut results, None);
    results
}

/// Name context passed from parent nodes.
struct NameContext {
    name: String,
    class_name: Option<String>,
}

fn walk_and_analyze(
    node: tree_sitter::Node,
    source: &[u8],
    results: &mut Vec<HalsteadResult>,
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

        let (volume, difficulty, effort, time, bugs) = calculate_halstead(&node, source);
        let start = node.start_position();
        let end = node.end_position();

        results.push(HalsteadResult {
            name,
            volume,
            difficulty,
            effort,
            time,
            bugs,
            start_line: start.row + 1,
            end_line: end.row + 1,
            start_col: start.column,
        });

        return;
    }

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

/// Calculate Halstead metrics for a function node.
/// Returns (volume, difficulty, effort, time, bugs).
fn calculate_halstead(
    node: &tree_sitter::Node,
    source: &[u8],
) -> (f64, f64, f64, f64, f64) {
    let mut operators: FxHashMap<String, u32> = FxHashMap::default();
    let mut operands: FxHashMap<String, u32> = FxHashMap::default();
    let mut n1_total: u32 = 0;
    let mut n2_total: u32 = 0;

    // Find function body
    let mut found_body = false;
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            if child.kind() == "statement_block" {
                // Walk children of statement_block
                for j in 0..child.child_count() as u32 {
                    if let Some(stmt) = child.child(j) {
                        classify_node(
                            stmt,
                            source,
                            &mut operators,
                            &mut operands,
                            &mut n1_total,
                            &mut n2_total,
                        );
                    }
                }
                found_body = true;
                break;
            }
        }
    }

    if !found_body {
        // Expression body arrow function
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                let ct = child.kind();
                if ct != "formal_parameters"
                    && ct != "=>"
                    && ct != "identifier"
                    && ct != "type_annotation"
                {
                    classify_node(
                        child,
                        source,
                        &mut operators,
                        &mut operands,
                        &mut n1_total,
                        &mut n2_total,
                    );
                }
            }
        }
    }

    let n1 = operators.len() as u32;
    let n2 = operands.len() as u32;

    compute_halstead_metrics(n1, n2, n1_total, n2_total)
}

/// Recursive AST walker that classifies leaf nodes as operators or operands.
fn classify_node(
    node: tree_sitter::Node,
    source: &[u8],
    operators: &mut FxHashMap<String, u32>,
    operands: &mut FxHashMap<String, u32>,
    n1_total: &mut u32,
    n2_total: &mut u32,
) {
    let kind = node.kind();

    // Stop at nested function boundaries
    if is_function_node(kind) {
        return;
    }

    // Skip TypeScript type-only nodes
    if is_type_only_node(kind) {
        return;
    }

    // Special case: ternary_expression -> count "?:" as one operator
    if kind == "ternary_expression" {
        *operators.entry("?:".to_string()).or_insert(0) += 1;
        *n1_total += 1;
        for i in 0..node.child_count() as u32 {
            if let Some(child) = node.child(i) {
                classify_node(child, source, operators, operands, n1_total, n2_total);
            }
        }
        return;
    }

    // Leaf node classification
    if node.child_count() == 0 {
        if is_operator_token(kind) {
            *operators.entry(kind.to_string()).or_insert(0) += 1;
            *n1_total += 1;
        } else if is_operand_token(kind) {
            if let Ok(text) = node.utf8_text(source) {
                *operands.entry(text.to_string()).or_insert(0) += 1;
                *n2_total += 1;
            }
        }
        return;
    }

    // Non-leaf: recurse
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            classify_node(child, source, operators, operands, n1_total, n2_total);
        }
    }
}

/// Check if a node kind is a TypeScript type-only node that should be skipped.
pub fn is_type_only_node(kind: &str) -> bool {
    matches!(
        kind,
        "type_annotation"
            | "type_identifier"
            | "generic_type"
            | "type_parameters"
            | "type_parameter"
            | "predefined_type"
            | "union_type"
            | "intersection_type"
            | "array_type"
            | "object_type"
            | "tuple_type"
            | "function_type"
            | "readonly_type"
            | "type_query"
            | "as_expression"
            | "satisfies_expression"
            | "interface_declaration"
            | "type_alias_declaration"
    )
}

/// Check if a leaf node kind is an operator token.
fn is_operator_token(kind: &str) -> bool {
    matches!(
        kind,
        // Arithmetic
        "+" | "-" | "*" | "/" | "%" | "**"
        // Comparison
        | "==" | "!=" | "===" | "!==" | "<" | ">" | "<=" | ">="
        // Logical
        | "&&" | "||" | "??"
        // Assignment
        | "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "**="
        | "&&=" | "||=" | "??="
        | "<<=" | ">>=" | ">>>="
        | "&=" | "|=" | "^="
        // Bitwise
        | "&" | "|" | "^" | "~" | "<<" | ">>" | ">>>"
        // Unary keyword
        | "typeof" | "void" | "delete" | "await" | "yield"
        // Unary symbol
        | "!" | "++" | "--"
        // Control flow keywords
        | "if" | "else" | "for" | "while" | "do"
        | "switch" | "case" | "default"
        | "break" | "continue" | "return" | "throw"
        | "try" | "catch" | "finally"
        | "new" | "in" | "of" | "instanceof"
        // Punctuation-operators
        | ","
        // Decorator
        | "@"
    )
}

/// Check if a leaf node kind is an operand token.
fn is_operand_token(kind: &str) -> bool {
    matches!(
        kind,
        "identifier"
            | "number"
            | "string"
            | "template_string"
            | "regex"
            | "true"
            | "false"
            | "null"
            | "undefined"
            | "this"
            | "property_identifier"
    )
}

/// Compute Halstead derived metrics from base counts.
fn compute_halstead_metrics(n1: u32, n2: u32, n1_total: u32, n2_total: u32) -> (f64, f64, f64, f64, f64) {
    let vocabulary = n1 + n2;
    let length = n1_total + n2_total;

    if vocabulary == 0 {
        return (0.0, 0.0, 0.0, 0.0, 0.0);
    }

    let volume = (length as f64) * (vocabulary as f64).log2();
    let difficulty = if n2 == 0 {
        0.0
    } else {
        (n1 as f64 / 2.0) * (n2_total as f64 / n2 as f64)
    };
    let effort = volume * difficulty;
    let time = effort / 18.0;
    let bugs = volume / 3000.0;

    (volume, difficulty, effort, time, bugs)
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    fn parse_and_analyze(source: &str) -> Vec<HalsteadResult> {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();
        analyze_functions(root, source.as_bytes())
    }

    fn find_by_name<'a>(
        results: &'a [HalsteadResult],
        name: &str,
    ) -> Option<&'a HalsteadResult> {
        results.iter().find(|r| r.name == name)
    }

    fn assert_float_eq(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-6,
            "{}: expected {}, got {} (diff {})",
            label,
            expected,
            actual,
            (actual - expected).abs()
        );
    }

    #[test]
    fn halstead_cases_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/halstead_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let results = parse_and_analyze(&source);

        // simpleAssignment
        let r = find_by_name(&results, "simpleAssignment").unwrap();
        assert_float_eq(r.volume, 18.094737505048094, "simpleAssignment volume");
        assert_float_eq(r.difficulty, 2.0, "simpleAssignment difficulty");
        assert_float_eq(r.effort, 36.18947501009619, "simpleAssignment effort");
        assert_float_eq(r.bugs, 0.006031579168349364, "simpleAssignment bugs");

        // withTypeAnnotations
        let r = find_by_name(&results, "withTypeAnnotations").unwrap();
        assert_float_eq(r.volume, 8.0, "withTypeAnnotations volume");
        assert_float_eq(r.difficulty, 1.0, "withTypeAnnotations difficulty");
        assert_float_eq(r.effort, 8.0, "withTypeAnnotations effort");
        assert_float_eq(r.bugs, 0.0026666666666666666, "withTypeAnnotations bugs");

        // emptyFunction
        let r = find_by_name(&results, "emptyFunction").unwrap();
        assert_float_eq(r.volume, 0.0, "emptyFunction volume");
        assert_float_eq(r.difficulty, 0.0, "emptyFunction difficulty");
        assert_float_eq(r.effort, 0.0, "emptyFunction effort");
        assert_float_eq(r.bugs, 0.0, "emptyFunction bugs");

        // singleExpressionArrow
        let r = find_by_name(&results, "singleExpressionArrow").unwrap();
        assert_float_eq(r.volume, 4.754887502163468, "singleExpressionArrow volume");
        assert_float_eq(r.difficulty, 0.5, "singleExpressionArrow difficulty");
        assert_float_eq(r.effort, 2.377443751081734, "singleExpressionArrow effort");
        assert_float_eq(r.bugs, 0.001584962500721156, "singleExpressionArrow bugs");

        // complexLogic
        let r = find_by_name(&results, "complexLogic").unwrap();
        assert_float_eq(r.volume, 65.72920075410865, "complexLogic volume");
        assert_float_eq(r.difficulty, 6.125, "complexLogic difficulty");
        assert_float_eq(r.effort, 402.59135461891543, "complexLogic effort");
        assert_float_eq(r.bugs, 0.02190973358470288, "complexLogic bugs");

        // ServiceClass.processValue
        let r = find_by_name(&results, "ServiceClass.processValue").unwrap();
        assert_float_eq(r.volume, 31.69925001442312, "processValue volume");
        assert_float_eq(r.difficulty, 2.4, "processValue difficulty");
        assert_float_eq(r.effort, 76.07820003461549, "processValue effort");
        assert_float_eq(r.bugs, 0.010566416671474373, "processValue bugs");

        // withNullishAndOptional
        let r = find_by_name(&results, "withNullishAndOptional").unwrap();
        assert_float_eq(r.volume, 8.0, "withNullishAndOptional volume");
        assert_float_eq(r.difficulty, 1.0, "withNullishAndOptional difficulty");
        assert_float_eq(r.effort, 8.0, "withNullishAndOptional effort");
        assert_float_eq(r.bugs, 0.0026666666666666666, "withNullishAndOptional bugs");

        // withTernary
        let r = find_by_name(&results, "withTernary").unwrap();
        assert_float_eq(r.volume, 11.60964047443681, "withTernary volume");
        assert_float_eq(r.difficulty, 1.5, "withTernary difficulty");
        assert_float_eq(r.effort, 17.414460711655217, "withTernary effort");
        assert_float_eq(r.bugs, 0.0038698801581456034, "withTernary bugs");
    }

    #[test]
    fn type_annotations_not_inflated() {
        // withTypeAnnotations has volume=8.0, same as plain JS equivalent
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../tests/fixtures/typescript/halstead_cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let results = parse_and_analyze(&source);
        let r = find_by_name(&results, "withTypeAnnotations").unwrap();
        assert_float_eq(r.volume, 8.0, "TS type annotations should not inflate volume");
    }
}
