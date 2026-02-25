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
///
/// Mirrors the Zig FunctionContext struct, supporting class, object key,
/// callback, and default export naming patterns.
#[derive(Clone)]
struct NameContext {
    /// Variable name (for `const x = () => {}` patterns)
    name: String,
    /// Class name (for `class Foo { bar() {} }` → "Foo.bar")
    class_name: Option<String>,
    /// Object literal key (for `{ handler: () => {} }` → "handler")
    object_key: Option<String>,
    /// Call expression method name (for `arr.map(() => {})` → "map callback")
    call_name: Option<String>,
    /// Whether inside a `export default function() {}` → "default export"
    is_default_export: bool,
}

impl NameContext {
    fn from_name(name: &str) -> Self {
        NameContext {
            name: name.to_string(),
            class_name: None,
            object_key: None,
            call_name: None,
            is_default_export: false,
        }
    }
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

        // Apply parent context naming priorities (matching Zig priority order)
        if let Some(ctx) = parent_ctx {
            // Priority 1: class method → "ClassName.methodName"
            if let Some(ref class_name) = ctx.class_name {
                if kind == "method_definition" && name != "<anonymous>" {
                    name = format!("{}.{}", class_name, name);
                }
            }

            // Priority 2: object key → use key name for anonymous arrow/function
            if let Some(ref key) = ctx.object_key {
                if name == "<anonymous>" || kind == "arrow_function" {
                    name = key.clone();
                }
            }

            // Priority 3: callback naming → "callee callback" or "event handler"
            if let Some(ref call_name) = ctx.call_name {
                if name == "<anonymous>" || kind == "arrow_function" {
                    if call_name.ends_with(" handler") {
                        name = call_name.clone();
                    } else {
                        name = format!("{} callback", call_name);
                    }
                }
            }

            // Priority 4: default export → "default export"
            if ctx.is_default_export && name == "<anonymous>" {
                name = "default export".to_string();
            }

            // Priority 5: variable name (from variable_declarator)
            if name == "<anonymous>" && !ctx.name.is_empty() && ctx.name != "<anonymous>" {
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
                child_ctx = Some(NameContext::from_name(text));
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
            object_key: None,
            call_name: None,
            is_default_export: false,
        });
    } else if kind == "class_body" {
        // Pass through parent context (class context needed for method naming)
        if let Some(ctx) = parent_ctx {
            child_ctx = Some(ctx.clone());
        }
    } else if kind == "arguments" {
        // Pass call context into arguments (contains callback arrow functions)
        if let Some(ctx) = parent_ctx {
            child_ctx = Some(ctx.clone());
        }
    } else if kind == "pair" {
        // Object literal: `{ handler: () => {} }` — key becomes the function name
        if let Some(key_node) = node.child(0) {
            let key_kind = key_node.kind();
            if key_kind == "property_identifier" || key_kind == "string" || key_kind == "identifier" {
                if let Ok(key_text) = key_node.utf8_text(source) {
                    // Strip quotes from string keys
                    let key = if key_text.starts_with('"') || key_text.starts_with('\'') {
                        &key_text[1..key_text.len() - 1]
                    } else {
                        key_text
                    };
                    child_ctx = Some(NameContext {
                        name: "<anonymous>".to_string(),
                        class_name: None,
                        object_key: Some(key.to_string()),
                        call_name: None,
                        is_default_export: false,
                    });
                }
            }
        }
    } else if kind == "call_expression" {
        // Track callee for callback naming: `arr.map(() => {})` → "map callback"
        if let Some(callee) = node.child(0) {
            let callee_kind = callee.kind();
            if callee_kind == "identifier" {
                // Simple identifier: `map(...)`, `forEach(...)`, `addEventListener(...)`
                if let Ok(callee_name) = callee.utf8_text(source) {
                    if callee_name == "addEventListener" {
                        let event_name = extract_event_name(&node, source);
                        let call_name = if let Some(ev) = event_name {
                            format!("{} handler", ev)
                        } else {
                            "addEventListener handler".to_string()
                        };
                        child_ctx = Some(NameContext {
                            name: "<anonymous>".to_string(),
                            class_name: None,
                            object_key: None,
                            call_name: Some(call_name),
                            is_default_export: false,
                        });
                    } else {
                        child_ctx = Some(NameContext {
                            name: "<anonymous>".to_string(),
                            class_name: None,
                            object_key: None,
                            call_name: Some(callee_name.to_string()),
                            is_default_export: false,
                        });
                    }
                }
            } else if callee_kind == "member_expression" {
                // Member expression: `arr.map`, `obj.forEach`, `document.addEventListener`
                if let Some(method_name) = get_last_member_segment(&callee, source) {
                    if method_name == "addEventListener" {
                        let event_name = extract_event_name(&node, source);
                        let call_name = if let Some(ev) = event_name {
                            format!("{} handler", ev)
                        } else {
                            "addEventListener handler".to_string()
                        };
                        child_ctx = Some(NameContext {
                            name: "<anonymous>".to_string(),
                            class_name: None,
                            object_key: None,
                            call_name: Some(call_name),
                            is_default_export: false,
                        });
                    } else {
                        child_ctx = Some(NameContext {
                            name: "<anonymous>".to_string(),
                            class_name: None,
                            object_key: None,
                            call_name: Some(method_name),
                            is_default_export: false,
                        });
                    }
                }
            }
        }
    } else if kind == "export_statement" {
        // Check for `export default function() {}` → "default export"
        let is_default = (0..node.child_count() as u32)
            .filter_map(|i| node.child(i))
            .any(|c| c.kind() == "default");
        if is_default {
            child_ctx = Some(NameContext {
                name: "<anonymous>".to_string(),
                class_name: None,
                object_key: None,
                call_name: None,
                is_default_export: true,
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

/// Extract the event name from the first string argument of a call_expression.
///
/// For `document.addEventListener("click", ...)` returns `Some("click")`.
fn extract_event_name(call_node: &tree_sitter::Node, source: &[u8]) -> Option<String> {
    // Find the `arguments` child
    for i in 0..call_node.child_count() as u32 {
        if let Some(args) = call_node.child(i) {
            if args.kind() == "arguments" {
                // Look for first string literal in arguments
                for j in 0..args.child_count() as u32 {
                    if let Some(arg) = args.child(j) {
                        if arg.kind() == "string" {
                            if let Ok(text) = arg.utf8_text(source) {
                                // Strip surrounding quotes
                                if text.len() >= 2 {
                                    return Some(text[1..text.len() - 1].to_string());
                                }
                            }
                        }
                    }
                }
                break;
            }
        }
    }
    None
}

/// Extract the last identifier segment from a member_expression node.
///
/// For `arr.map` returns `Some("map")`. For `obj.foo.bar` returns `Some("bar")`.
fn get_last_member_segment(node: &tree_sitter::Node, source: &[u8]) -> Option<String> {
    let mut last: Option<String> = None;
    for i in 0..node.child_count() as u32 {
        if let Some(child) = node.child(i) {
            let ct = child.kind();
            if ct == "property_identifier" || ct == "identifier" {
                if let Ok(text) = child.utf8_text(source) {
                    last = Some(text.to_string());
                }
            }
        }
    }
    last
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
            .join("tests/fixtures/typescript/cyclomatic_cases.ts");
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
            .join("tests/fixtures/typescript/complex_nested.ts");
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

    #[test]
    fn naming_edge_cases_fixture() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/naming-edge-cases.ts");
        let source = std::fs::read_to_string(&fixture_path).unwrap();
        let config = CyclomaticConfig::default();
        let results = parse_and_analyze(&source, &config);

        let names: Vec<&str> = results.iter().map(|r| r.name.as_str()).collect();

        // Basic named function
        assert!(names.contains(&"myFunc"), "Should find myFunc: {:?}", names);

        // Variable-assigned arrow
        assert!(names.contains(&"handler"), "Should find handler: {:?}", names);

        // Class methods
        assert!(names.contains(&"Foo.bar"), "Should find Foo.bar: {:?}", names);
        assert!(names.contains(&"Foo.baz"), "Should find Foo.baz: {:?}", names);

        // Object literal methods (key name extraction)
        // { handler: () => {} } → key "handler" conflicts with top-level handler; check "process"
        assert!(names.contains(&"process"), "Should find process (shorthand method): {:?}", names);

        // Array method callbacks
        assert!(names.contains(&"map callback"), "Should find 'map callback': {:?}", names);
        assert!(names.contains(&"forEach callback"), "Should find 'forEach callback': {:?}", names);

        // Event handler
        assert!(names.contains(&"click handler"), "Should find 'click handler': {:?}", names);

        // Default export
        assert!(names.contains(&"default export"), "Should find 'default export': {:?}", names);
    }
}
