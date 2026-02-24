use std::path::Path;

use complexity_guard::parser::parse_file;
use complexity_guard::types::ParseError;

// Helper to get fixture path relative to the rust/ directory
fn fixture_path(relative: &str) -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests")
        .join("fixtures")
        .join(relative)
}

#[test]
fn test_parse_typescript_simple_function() {
    let path = fixture_path("typescript/simple_function.ts");
    let result = parse_file(&path).expect("should parse TypeScript file");

    assert!(!result.error, "fixture should parse without errors");
    assert!(!result.functions.is_empty(), "should find at least one function");

    // Should find the "greet" function at line 5
    let greet = result
        .functions
        .iter()
        .find(|f| f.name == "greet")
        .expect("should find 'greet' function");
    assert_eq!(greet.start_line, 5, "greet starts at line 5");
    // Column 7: tree-sitter function_declaration starts after "export " prefix
    assert_eq!(greet.start_column, 7, "greet function_declaration starts at column 7");
}

#[test]
fn test_parse_tsx_react_component() {
    let path = fixture_path("typescript/react_component.tsx");
    let result = parse_file(&path).expect("should parse TSX file");

    assert!(!result.error, "fixture should parse without errors");

    // Should find "Greeting" function declaration
    let greeting = result
        .functions
        .iter()
        .find(|f| f.name == "Greeting")
        .expect("should find 'Greeting' function");
    assert_eq!(greeting.start_line, 10, "Greeting starts at line 10");

    // Should find "Badge" const arrow function
    let badge = result
        .functions
        .iter()
        .find(|f| f.name == "Badge")
        .expect("should find 'Badge' arrow function");
    assert_eq!(badge.start_line, 22, "Badge arrow starts at line 22");
}

#[test]
fn test_parse_javascript_express_middleware() {
    let path = fixture_path("javascript/express_middleware.js");
    let result = parse_file(&path).expect("should parse JavaScript file");

    assert!(!result.error, "fixture should parse without errors");

    // Should find "errorHandler" function
    let error_handler = result
        .functions
        .iter()
        .find(|f| f.name == "errorHandler")
        .expect("should find 'errorHandler' function");
    assert_eq!(error_handler.start_line, 5, "errorHandler starts at line 5");

    // Should find "rateLimiter" function
    let rate_limiter = result
        .functions
        .iter()
        .find(|f| f.name == "rateLimiter")
        .expect("should find 'rateLimiter' function");
    assert_eq!(rate_limiter.start_line, 22, "rateLimiter starts at line 22");
}

#[test]
fn test_parse_jsx_component() {
    let path = fixture_path("javascript/jsx_component.jsx");
    let result = parse_file(&path).expect("should parse JSX file");

    assert!(!result.error, "fixture should parse without errors");

    // Should find "Card" function
    let card = result
        .functions
        .iter()
        .find(|f| f.name == "Card")
        .expect("should find 'Card' function");
    assert_eq!(card.start_line, 5, "Card starts at line 5");

    // Should find "List" const arrow function
    let list = result
        .functions
        .iter()
        .find(|f| f.name == "List")
        .expect("should find 'List' arrow function");
    assert_eq!(list.start_line, 14, "List arrow starts at line 14");
}

#[test]
fn test_parse_typescript_class_with_methods() {
    let path = fixture_path("typescript/class_with_methods.ts");
    let result = parse_file(&path).expect("should parse TypeScript class file");

    assert!(!result.error, "fixture should parse without errors");

    // Should find class methods
    let method_names: Vec<&str> = result.functions.iter().map(|f| f.name.as_str()).collect();
    assert!(
        method_names.contains(&"constructor"),
        "should find constructor, got: {:?}",
        method_names
    );
    assert!(
        method_names.contains(&"findById"),
        "should find findById method, got: {:?}",
        method_names
    );
    assert!(
        method_names.contains(&"updateEmail"),
        "should find updateEmail method, got: {:?}",
        method_names
    );
    assert!(
        method_names.contains(&"isValidEmail"),
        "should find isValidEmail method, got: {:?}",
        method_names
    );
}

#[test]
fn test_unsupported_extension_returns_error() {
    let path = Path::new("test.py");
    let result = parse_file(path);
    assert!(result.is_err(), "should return error for unsupported extension");
    match result.unwrap_err() {
        ParseError::UnsupportedExtension(ext) => assert_eq!(ext, "py"),
        other => panic!("expected UnsupportedExtension, got: {:?}", other),
    }
}

#[test]
fn test_no_extension_returns_error() {
    let path = Path::new("Makefile");
    let result = parse_file(path);
    assert!(result.is_err(), "should return error for no extension");
    match result.unwrap_err() {
        ParseError::NoExtension => {}
        other => panic!("expected NoExtension, got: {:?}", other),
    }
}

#[test]
fn test_function_line_numbers_are_one_indexed() {
    let path = fixture_path("typescript/simple_function.ts");
    let result = parse_file(&path).expect("should parse");

    for func in &result.functions {
        assert!(
            func.start_line >= 1,
            "start_line should be 1-indexed, got {} for {}",
            func.start_line,
            func.name
        );
        assert!(
            func.end_line >= func.start_line,
            "end_line should be >= start_line for {}",
            func.name
        );
    }
}
