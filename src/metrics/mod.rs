pub mod cognitive;
pub mod cyclomatic;
pub mod duplication;
pub mod halstead;
pub mod scoring;
pub mod structural;

use std::path::Path;

use crate::types::{
    AnalysisConfig, FileAnalysisResult, FunctionAnalysisResult, ParseError,
};

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

/// Analyze a single file and produce a complete FileAnalysisResult.
///
/// Runs all metric analyzers on the same parsed tree in a single pass,
/// merges per-function results, computes health scores, and embeds
/// the token sequence for subsequent duplication detection.
pub fn analyze_file(
    path: &Path,
    config: &AnalysisConfig,
) -> Result<FileAnalysisResult, ParseError> {
    let language = crate::parser::select_language(path)?;
    let source = std::fs::read(path)?;

    let mut parser = tree_sitter::Parser::new();
    parser
        .set_language(&language)
        .map_err(|e| ParseError::LanguageError(e.to_string()))?;

    let tree = parser.parse(&source, None).ok_or(ParseError::ParseFailed)?;
    let root = tree.root_node();
    let has_error = root.has_error();

    // Run all metric analyzers on the same root node
    let cyclomatic_results = cyclomatic::analyze_functions(root, &source, &config.cyclomatic);
    let cognitive_results = cognitive::analyze_functions(root, &source);
    let halstead_results = halstead::analyze_functions(root, &source);
    let structural_results = structural::analyze_functions(root, &source);
    let file_structural = structural::analyze_file(&source, root);

    // Tokenize BEFORE tree is dropped (avoids re-parse); skip when disabled
    let tokens = if config.duplication.enabled {
        duplication::tokenize_tree(root, &source)
    } else {
        Vec::new()
    };

    // All walkers discover functions in the same DFS order
    let func_count = cyclomatic_results.len();
    assert_eq!(cognitive_results.len(), func_count, "cognitive and cyclomatic function counts must match");
    assert_eq!(halstead_results.len(), func_count, "halstead and cyclomatic function counts must match");
    assert_eq!(structural_results.len(), func_count, "structural and cyclomatic function counts must match");

    // Merge per-function results and compute health scores
    let mut functions = Vec::with_capacity(func_count);
    let mut function_scores = Vec::with_capacity(func_count);

    for i in 0..func_count {
        let cycl = &cyclomatic_results[i];
        let cogn = &cognitive_results[i];
        let hal = &halstead_results[i];
        let struc = &structural_results[i];

        let health_score = scoring::compute_function_score(
            cycl.complexity,
            cogn.complexity,
            hal.volume,
            struc.function_length,
            struc.params_count,
            struc.nesting_depth,
            &config.scoring_weights,
            &config.scoring_thresholds,
        );

        function_scores.push(health_score);

        functions.push(FunctionAnalysisResult {
            name: cycl.name.clone(),
            start_line: cycl.start_line,
            end_line: cycl.end_line,
            start_col: cycl.start_col,
            cyclomatic: cycl.complexity,
            cognitive: cogn.complexity,
            halstead_volume: hal.volume,
            halstead_difficulty: hal.difficulty,
            halstead_effort: hal.effort,
            halstead_time: hal.time,
            halstead_bugs: hal.bugs,
            function_length: struc.function_length,
            params_count: struc.params_count,
            nesting_depth: struc.nesting_depth,
            health_score,
        });
    }

    let file_score = scoring::compute_file_score(&function_scores);

    Ok(FileAnalysisResult {
        path: path.to_path_buf(),
        functions,
        tokens,
        file_score,
        file_length: file_structural.file_length,
        export_count: file_structural.export_count,
        error: has_error,
    })
}

// TESTS

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    use crate::types::AnalysisConfig;

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
    fn extract_function_name_named_function() {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        let source = b"function myFunc() { return 1; }";
        let tree = parser.parse(source, None).unwrap();
        let root = tree.root_node();
        let func_node = root.child(0).unwrap(); // function_declaration
        let name = extract_function_name(&func_node, source);
        assert_eq!(name, "myFunc");
    }

    #[test]
    fn extract_function_name_anonymous_arrow() {
        let language: tree_sitter::Language =
            tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into();
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&language).unwrap();
        // A bare arrow function node returns <anonymous>; naming context is resolved by cyclomatic walker
        let source = b"const f = () => 1;";
        let tree = parser.parse(source, None).unwrap();
        let root = tree.root_node();
        // Walk to find the arrow_function node
        let lex_decl = root.child(0).unwrap(); // lexical_declaration
        let var_decl = lex_decl.child(1).unwrap(); // variable_declarator
        let arrow = var_decl.child_by_field_name("value").unwrap(); // arrow_function
        assert_eq!(arrow.kind(), "arrow_function");
        let name = extract_function_name(&arrow, source);
        // extract_function_name alone returns <anonymous> for arrow functions
        assert_eq!(name, "<anonymous>");
    }

    #[test]
    fn analyze_file_naming_edge_cases() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/naming-edge-cases.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        let names: Vec<&str> = result.functions.iter().map(|f| f.name.as_str()).collect();

        assert!(names.contains(&"myFunc"), "Should find myFunc: {:?}", names);
        assert!(names.contains(&"handler"), "Should find handler: {:?}", names);
        assert!(names.contains(&"Foo.bar"), "Should find Foo.bar: {:?}", names);
        assert!(names.contains(&"Foo.baz"), "Should find Foo.baz: {:?}", names);
        assert!(names.contains(&"process"), "Should find process: {:?}", names);
        assert!(names.contains(&"map callback"), "Should find 'map callback': {:?}", names);
        assert!(names.contains(&"forEach callback"), "Should find 'forEach callback': {:?}", names);
        assert!(names.contains(&"click handler"), "Should find 'click handler': {:?}", names);
        assert!(names.contains(&"default export"), "Should find 'default export': {:?}", names);
    }

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

    #[test]
    fn analyze_file_simple_function() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/simple_function.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        // simple_function.ts has 1 function: greet
        assert_eq!(result.functions.len(), 1);
        let greet = &result.functions[0];
        assert_eq!(greet.name, "greet");
        assert_eq!(greet.cyclomatic, 1);
        assert_eq!(greet.cognitive, 0);
        assert_float_eq(greet.halstead_volume, 2.0, "greet halstead_volume");
        assert_float_eq(greet.halstead_difficulty, 0.5, "greet halstead_difficulty");
        assert_float_eq(greet.halstead_effort, 1.0, "greet halstead_effort");
        assert_float_eq(greet.halstead_bugs, 0.0006666666666666666, "greet halstead_bugs");
        assert_eq!(greet.function_length, 1);
        assert_eq!(greet.params_count, 1);
        assert_eq!(greet.nesting_depth, 0);

        // Health score should match Zig output
        assert_float_eq(greet.health_score, 82.71258735483063, "greet health_score");

        // File-level metrics
        assert_eq!(result.file_length, 2);
        assert_eq!(result.export_count, 1);
        assert!(!result.error);

        // Tokens should be non-empty
        assert!(result.tokens.len() > 0, "tokens should be non-empty");

        // File score should be between 0 and 100
        assert!(result.file_score >= 0.0 && result.file_score <= 100.0);
    }

    #[test]
    fn analyze_file_cyclomatic_cases() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/cyclomatic_cases.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        // Verify cyclomatic values match fixture expectations
        let find = |name: &str| result.functions.iter().find(|f| f.name == name);

        assert_eq!(find("baseline").unwrap().cyclomatic, 1);
        assert_eq!(find("simpleConditionals").unwrap().cyclomatic, 3);
        assert_eq!(find("loopWithConditions").unwrap().cyclomatic, 5);
        assert_eq!(find("switchStatement").unwrap().cyclomatic, 5);
        assert_eq!(find("errorHandling").unwrap().cyclomatic, 3);
        assert_eq!(find("ternaryAndLogical").unwrap().cyclomatic, 3);
        assert_eq!(find("nullishCoalescing").unwrap().cyclomatic, 3);
        assert_eq!(find("complexLogical").unwrap().cyclomatic, 5);

        // All scores between 0 and 100
        for f in &result.functions {
            assert!(
                f.health_score >= 0.0 && f.health_score <= 100.0,
                "{}: health_score {} out of range",
                f.name,
                f.health_score
            );
        }
    }

    #[test]
    fn analyze_file_cognitive_cases() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/cognitive_cases.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        let find = |name: &str| result.functions.iter().find(|f| f.name == name);

        assert_eq!(find("baseline").unwrap().cognitive, 0);
        assert_eq!(find("singleIf").unwrap().cognitive, 1);
        assert_eq!(find("ifElseChain").unwrap().cognitive, 4);
        assert_eq!(find("nestedIfInLoop").unwrap().cognitive, 6);
        assert_eq!(find("logicalOps").unwrap().cognitive, 3);
        assert_eq!(find("mixedLogicalOps").unwrap().cognitive, 4);
        assert_eq!(find("factorial").unwrap().cognitive, 2);
        assert_eq!(find("topLevelArrow").unwrap().cognitive, 1);
        assert_eq!(find("withCallback").unwrap().cognitive, 3);
        assert_eq!(find("switchStatement").unwrap().cognitive, 1);
        assert_eq!(find("tryCatch").unwrap().cognitive, 1);
        assert_eq!(find("ternaryNested").unwrap().cognitive, 3);
        assert_eq!(find("MyClass.classMethod").unwrap().cognitive, 3);
        assert_eq!(find("deeplyNested").unwrap().cognitive, 10);
        assert_eq!(find("labeledBreak").unwrap().cognitive, 7);
        assert_eq!(find("noIncrement").unwrap().cognitive, 0);
    }

    #[test]
    fn analyze_file_halstead_cases() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/halstead_cases.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        let find = |name: &str| result.functions.iter().find(|f| f.name == name);

        let r = find("simpleAssignment").unwrap();
        assert_float_eq(r.halstead_volume, 18.094737505048094, "simpleAssignment volume");

        let r = find("withTypeAnnotations").unwrap();
        assert_float_eq(r.halstead_volume, 8.0, "withTypeAnnotations volume");

        let r = find("emptyFunction").unwrap();
        assert_float_eq(r.halstead_volume, 0.0, "emptyFunction volume");

        let r = find("complexLogic").unwrap();
        assert_float_eq(r.halstead_volume, 65.72920075410865, "complexLogic volume");
    }

    #[test]
    fn analyze_file_structural_cases() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/structural_cases.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        let find = |name: &str| result.functions.iter().find(|f| f.name == name);

        let r = find("shortFunction").unwrap();
        assert_eq!(r.function_length, 3);
        assert_eq!(r.params_count, 1);
        assert_eq!(r.nesting_depth, 0);

        let r = find("deeplyNested").unwrap();
        assert_eq!(r.nesting_depth, 4);

        let r = find("flatFunction").unwrap();
        assert_eq!(r.function_length, 2);
        assert_eq!(r.nesting_depth, 0);

        // File-level metrics
        assert_eq!(result.file_length, 41);
        assert_eq!(result.export_count, 4);
    }

    #[test]
    fn analyze_file_tokens_embedded() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/simple_function.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        assert!(
            !result.tokens.is_empty(),
            "token sequence should be embedded in result"
        );
    }

    #[test]
    fn analyze_file_score_in_range() {
        let fixture_path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/typescript/simple_function.ts");
        let config = AnalysisConfig::default();
        let result = analyze_file(&fixture_path, &config).unwrap();

        assert!(
            result.file_score >= 0.0 && result.file_score <= 100.0,
            "file_score {} should be between 0 and 100",
            result.file_score
        );
    }
}
