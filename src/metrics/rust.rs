//! Source-level Rust metrics. Macros are not expanded and `cfg` is not evaluated.

use std::path::Path;

use rustc_hash::FxHashMap;
use tree_sitter::Node;

use crate::metrics::{duplication, scoring, structural};
use crate::types::{
    AnalysisConfig, FileAnalysisResult, FunctionAnalysisResult, SkipReason, SkippedItem,
    MAX_FUNCTION_LINES,
};

pub struct RustFunction<'a> {
    pub node: Node<'a>,
    pub name: String,
}

/// Collect functions in source order. Trait signatures have no executable body.
pub fn collect_functions<'a>(root: Node<'a>, source: &[u8]) -> Vec<RustFunction<'a>> {
    let mut result = Vec::new();
    collect(root, source, "", &mut result);
    result
}

fn collect<'a>(node: Node<'a>, source: &[u8], scope: &str, result: &mut Vec<RustFunction<'a>>) {
    let kind = node.kind();
    let mut child_scope = scope.to_string();
    if matches!(kind, "impl_item" | "trait_item" | "mod_item") {
        if let Some(name) = scope_name(node, source) {
            child_scope = if scope.is_empty() {
                name
            } else {
                format!("{scope}::{name}")
            };
        }
    }

    if kind == "function_item" && body(node).is_some() {
        let name = node
            .child_by_field_name("name")
            .or_else(|| direct_child(node, "identifier"))
            .and_then(|n| n.utf8_text(source).ok())
            .unwrap_or("<anonymous>");
        let name = if scope.is_empty() {
            name.to_string()
        } else {
            format!("{scope}::{name}")
        };
        result.push(RustFunction {
            node,
            name: name.clone(),
        });
        child_scope = name;
    } else if kind == "closure_expression" {
        let line = node.start_position().row + 1;
        let local_name = if let Some(parent) = node.parent() {
            if parent.kind() == "let_declaration" {
                direct_child(parent, "identifier")
                    .and_then(|n| n.utf8_text(source).ok())
                    .map(str::to_string)
                    .unwrap_or_else(|| format!("<closure@{line}>"))
            } else {
                format!("<closure@{line}>")
            }
        } else {
            format!("<closure@{line}>")
        };
        let name = if scope.is_empty() {
            local_name
        } else {
            format!("{scope}::{local_name}")
        };
        result.push(RustFunction {
            node,
            name: name.clone(),
        });
        child_scope = name;
    }

    for i in 0..node.named_child_count() {
        if let Some(child) = node.named_child(i as u32) {
            collect(child, source, &child_scope, result);
        }
    }
}

fn scope_name(node: Node, source: &[u8]) -> Option<String> {
    if node.kind() == "mod_item" {
        return direct_child(node, "identifier")?
            .utf8_text(source)
            .ok()
            .map(str::to_string);
    }
    let mut name = None;
    for i in 0..node.named_child_count() {
        let child = node.named_child(i as u32)?;
        if matches!(
            child.kind(),
            "type_identifier" | "generic_type" | "scoped_type_identifier"
        ) {
            name = child.utf8_text(source).ok().map(str::to_string);
        }
    }
    name
}

fn direct_child<'a>(node: Node<'a>, kind: &str) -> Option<Node<'a>> {
    (0..node.named_child_count())
        .filter_map(|i| node.named_child(i as u32))
        .find(|n| n.kind() == kind)
}

fn body(node: Node) -> Option<Node> {
    direct_child(node, "block").or_else(|| {
        if node.kind() == "closure_expression" {
            node.named_child(node.named_child_count().saturating_sub(1) as u32)
        } else {
            None
        }
    })
}

fn is_boundary(kind: &str) -> bool {
    matches!(kind, "function_item" | "closure_expression")
}

pub fn analyze_file(
    path: &Path,
    root: Node,
    source: &[u8],
    has_error: bool,
    config: &AnalysisConfig,
) -> (FileAnalysisResult, Vec<SkippedItem>) {
    let mut functions = Vec::new();
    let mut scores = Vec::new();
    let mut skipped = Vec::new();

    for item in collect_functions(root, source) {
        let Some(body) = body(item.node) else {
            continue;
        };
        let length = structural::count_logical_lines(source, body.start_byte(), body.end_byte());
        if length > MAX_FUNCTION_LINES {
            skipped.push(SkippedItem {
                path: path.to_path_buf(),
                function_name: Some(item.name),
                start_line: item.node.start_position().row + 1,
                reason: SkipReason::FunctionTooLarge {
                    lines: length,
                    max_lines: MAX_FUNCTION_LINES,
                },
            });
            continue;
        }
        let cyclomatic = 1 + decision_points(body, true);
        let cognitive = cognitive_complexity(body);
        let params_count = parameter_count(item.node);
        let nesting_depth = nesting_depth(body, 0);
        let (volume, difficulty, effort, time, bugs) = halstead(body, source);
        let health_score = scoring::compute_function_score(
            cyclomatic,
            cognitive,
            volume,
            length,
            params_count,
            nesting_depth,
            &config.scoring_weights,
            &config.rust_scoring_thresholds,
        );
        scores.push(health_score);
        functions.push(FunctionAnalysisResult {
            is_rust: true,
            name: item.name,
            start_line: item.node.start_position().row + 1,
            end_line: item.node.end_position().row + 1,
            start_col: item.node.start_position().column,
            cyclomatic,
            cognitive,
            halstead_volume: volume,
            halstead_difficulty: difficulty,
            halstead_effort: effort,
            halstead_time: time,
            halstead_bugs: bugs,
            function_length: length,
            params_count,
            nesting_depth,
            health_score,
        });
    }

    let tokens = if config.duplication.enabled {
        duplication::tokenize_rust(root)
    } else {
        Vec::new()
    };
    let result = FileAnalysisResult {
        path: path.to_path_buf(),
        functions,
        tokens,
        file_score: scoring::compute_file_score(&scores),
        file_length: structural::count_logical_lines(source, 0, source.len()),
        export_count: public_item_count(root),
        error: has_error,
    };
    (result, skipped)
}

fn parameter_count(node: Node) -> u32 {
    let Some(params) =
        direct_child(node, "parameters").or_else(|| direct_child(node, "closure_parameters"))
    else {
        return 0;
    };
    (0..params.named_child_count())
        .filter_map(|i| params.named_child(i as u32))
        .filter(|n| matches!(n.kind(), "parameter" | "identifier" | "tuple_pattern"))
        .count() as u32
}

fn public_item_count(node: Node) -> u32 {
    let mut count = 0;
    for i in 0..node.named_child_count() {
        let Some(child) = node.named_child(i as u32) else {
            continue;
        };
        if child.kind() == "visibility_modifier" {
            continue;
        }
        if direct_child(child, "visibility_modifier").is_some() {
            count += 1;
        }
        if matches!(
            child.kind(),
            "source_file" | "declaration_list" | "impl_item" | "trait_item" | "mod_item"
        ) {
            count += public_item_count(child);
        }
    }
    count
}

fn decision_points(node: Node, is_root: bool) -> u32 {
    if !is_root && is_boundary(node.kind()) {
        return 0;
    }
    let mut count = match node.kind() {
        "if_expression" | "while_expression" | "for_expression" | "loop_expression" => 1,
        "match_expression" => match_arms(node).saturating_sub(1),
        "let_declaration" if has_direct_token(node, "else") => 1,
        "binary_expression" if has_direct_token(node, "&&") || has_direct_token(node, "||") => 1,
        _ => 0,
    };
    if node.kind() == "match_pattern" && has_direct_token(node, "if") {
        count += 1;
    }
    for i in 0..node.named_child_count() {
        if let Some(child) = node.named_child(i as u32) {
            count += decision_points(child, false);
        }
    }
    count
}

fn match_arms(node: Node) -> u32 {
    let mut count = 0;
    for i in 0..node.named_child_count() {
        let Some(child) = node.named_child(i as u32) else {
            continue;
        };
        if child.kind() == "match_arm" {
            count += 1;
        }
        if child.kind() == "match_block" {
            count += (0..child.named_child_count())
                .filter_map(|j| child.named_child(j as u32))
                .filter(|arm| arm.kind() == "match_arm")
                .count() as u32;
        }
    }
    count
}

fn has_direct_token(node: Node, token: &str) -> bool {
    (0..node.child_count())
        .filter_map(|i| node.child(i as u32))
        .any(|n| n.kind() == token)
}

fn cognitive_complexity(body: Node) -> u32 {
    let mut score = 0;
    cognitive_walk(body, 0, true, &mut score);
    score
}

fn cognitive_walk(node: Node, depth: u32, is_root: bool, score: &mut u32) {
    if !is_root && is_boundary(node.kind()) {
        return;
    }
    let kind = node.kind();
    let branch = matches!(
        kind,
        "if_expression"
            | "while_expression"
            | "for_expression"
            | "loop_expression"
            | "match_expression"
    ) || (kind == "let_declaration" && has_direct_token(node, "else"));
    if branch {
        *score += 1 + depth;
    }
    if kind == "match_pattern" && has_direct_token(node, "if") {
        *score += 1;
    }
    if kind == "else_clause" && direct_child(node, "if_expression").is_none() {
        *score += 1;
    }
    if kind == "binary_expression" && (has_direct_token(node, "&&") || has_direct_token(node, "||"))
    {
        *score += 1;
    }
    let next_depth = depth + u32::from(branch);
    for i in 0..node.named_child_count() {
        if let Some(child) = node.named_child(i as u32) {
            // An else-if is a continuation rather than another nesting level.
            let child_depth = if kind == "else_clause" && child.kind() == "if_expression" {
                depth.saturating_sub(1)
            } else {
                next_depth
            };
            cognitive_walk(child, child_depth, false, score);
        }
    }
}

fn nesting_depth(node: Node, current: u32) -> u32 {
    let mut max = current;
    for i in 0..node.named_child_count() {
        let Some(child) = node.named_child(i as u32) else {
            continue;
        };
        if is_boundary(child.kind()) {
            continue;
        }
        let nested = matches!(
            child.kind(),
            "if_expression"
                | "while_expression"
                | "for_expression"
                | "loop_expression"
                | "match_expression"
        );
        max = max.max(nesting_depth(child, current + u32::from(nested)));
    }
    max
}

fn halstead(body: Node, source: &[u8]) -> (f64, f64, f64, f64, f64) {
    let mut operators: FxHashMap<&str, u32> = FxHashMap::default();
    let mut operands: FxHashMap<&str, u32> = FxHashMap::default();
    collect_halstead(body, source, true, &mut operators, &mut operands);
    let n1 = operators.len() as f64;
    let n2 = operands.len() as f64;
    let total_ops: u32 = operators.values().sum();
    let total_operands: u32 = operands.values().sum();
    let vocabulary = n1 + n2;
    let volume = if vocabulary <= 1.0 {
        0.0
    } else {
        f64::from(total_ops + total_operands) * vocabulary.log2()
    };
    let difficulty = if n2 == 0.0 {
        0.0
    } else {
        (n1 / 2.0) * (f64::from(total_operands) / n2)
    };
    let effort = difficulty * volume;
    (volume, difficulty, effort, effort / 18.0, volume / 3000.0)
}

fn collect_halstead<'a>(
    node: Node,
    source: &'a [u8],
    is_root: bool,
    operators: &mut FxHashMap<&'a str, u32>,
    operands: &mut FxHashMap<&'a str, u32>,
) {
    if !is_root && is_boundary(node.kind()) {
        return;
    }
    if matches!(
        node.kind(),
        "type_arguments"
            | "type_parameters"
            | "type_annotation"
            | "generic_type"
            | "line_comment"
            | "block_comment"
            | "attribute_item"
            | "macro_invocation"
    ) {
        return;
    }
    if node.child_count() == 0 {
        let kind = node.kind();
        if matches!(
            kind,
            "identifier"
                | "field_identifier"
                | "integer_literal"
                | "float_literal"
                | "string_literal"
                | "raw_string_literal"
                | "char_literal"
                | "boolean_literal"
                | "true"
                | "false"
                | "self"
        ) {
            if let Ok(text) = node.utf8_text(source) {
                *operands.entry(text).or_default() += 1;
            }
        } else if matches!(
            kind,
            "if" | "else"
                | "match"
                | "for"
                | "while"
                | "loop"
                | "let"
                | "return"
                | "break"
                | "continue"
                | "&&"
                | "||"
                | "!"
                | "?"
                | "+"
                | "-"
                | "*"
                | "/"
                | "%"
                | "="
                | "=="
                | "!="
                | "<"
                | ">"
                | "<="
                | ">="
                | "&"
                | "|"
                | "^"
                | "::"
                | "."
                | "=>"
                | "+="
                | "-="
                | "*="
                | "/="
                | "%="
        ) {
            *operators.entry(kind).or_default() += 1;
        }
        return;
    }
    for i in 0..node.child_count() {
        if let Some(child) = node.child(i as u32) {
            collect_halstead(child, source, false, operators, operands);
        }
    }
}
