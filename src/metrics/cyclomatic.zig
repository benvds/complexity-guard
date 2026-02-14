const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const Allocator = std.mem.Allocator;

/// Configuration for cyclomatic complexity calculation
pub const CyclomaticConfig = struct {
    /// Count logical operators (&& and ||) as decision points
    count_logical_operators: bool = true,
    /// Count nullish coalescing (??) as decision point
    count_nullish_coalescing: bool = true,
    /// Count optional chaining (?.) as decision point
    count_optional_chaining: bool = true,
    /// Count ternary expressions (? :) as decision points
    count_ternary: bool = true,
    /// Count default parameter values as decision points
    count_default_params: bool = true,
    /// Switch/case counting mode
    switch_case_mode: SwitchCaseMode = .classic,

    /// Switch/case counting modes
    pub const SwitchCaseMode = enum {
        /// Each case increments complexity (+1 per case)
        classic,
        /// Entire switch counts as single decision (+1 total)
        modified,
    };

    /// Returns default configuration (all modern features enabled, classic switch mode)
    pub fn default() CyclomaticConfig {
        return CyclomaticConfig{};
    }
};

/// Per-function complexity result
pub const FunctionComplexity = struct {
    /// Function name extracted from AST
    name: []const u8,
    /// Computed cyclomatic complexity
    complexity: u32,
    /// Start line (1-indexed)
    start_line: u32,
    /// End line (1-indexed)
    end_line: u32,
    /// Start column (0-indexed)
    start_col: u32,
};

/// Check if a node represents a function
pub fn isFunctionNode(node: tree_sitter.Node) bool {
    const node_type = node.nodeType();
    return std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "function") or
        std.mem.eql(u8, node_type, "arrow_function") or
        std.mem.eql(u8, node_type, "method_definition") or
        std.mem.eql(u8, node_type, "generator_function") or
        std.mem.eql(u8, node_type, "generator_function_declaration");
}

/// Extract function name from AST node
pub fn extractFunctionName(node: tree_sitter.Node, source: []const u8) []const u8 {
    _ = source;
    const node_type = node.nodeType();

    // For function/generator declarations, look for identifier child
    if (std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "generator_function_declaration"))
    {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    const start = child.startPoint();
                    const end = child.endPoint();
                    // TODO: Extract actual name from source using points
                    // For now, we'll handle this in analyzeFunctions which has full context
                    _ = start;
                    _ = end;
                    return "<function>";
                }
            }
        }
    }

    // For method definitions, look for property_identifier child
    if (std.mem.eql(u8, node_type, "method_definition")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "property_identifier")) {
                    return "<method>";
                }
            }
        }
    }

    // For arrow functions and function expressions, return anonymous
    // (name extraction requires parent context which we don't have here)
    return "<anonymous>";
}

/// Count decision points in an AST subtree
fn countDecisionPoints(node: tree_sitter.Node, config: CyclomaticConfig, source: []const u8) u32 {
    const node_type = node.nodeType();
    var count: u32 = 0;

    // If we encounter a nested function, stop recursing (each function has its own scope)
    if (isFunctionNode(node)) {
        return 0;
    }

    // Control flow statements that always count
    if (std.mem.eql(u8, node_type, "if_statement")) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "while_statement")) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "do_statement")) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "for_statement")) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "for_in_statement")) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "catch_clause")) {
        count += 1;
    }
    // Ternary expression (configurable)
    else if (std.mem.eql(u8, node_type, "ternary_expression") and config.count_ternary) {
        count += 1;
    }
    // Switch statement handling
    else if (std.mem.eql(u8, node_type, "switch_statement") and config.switch_case_mode == .modified) {
        count += 1;
    } else if (std.mem.eql(u8, node_type, "switch_case") and config.switch_case_mode == .classic) {
        // In classic mode, count each case except default (which has no expression)
        // Check if this case has an expression child (non-default cases have one)
        var has_expression = false;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                // Skip "case" keyword and ":" punctuation, look for actual expression
                if (!std.mem.eql(u8, child_type, "case") and
                    !std.mem.eql(u8, child_type, ":") and
                    !std.mem.eql(u8, child_type, "default"))
                {
                    has_expression = true;
                    break;
                }
            }
        }
        if (has_expression) {
            count += 1;
        }
    }
    // Binary expressions - check for logical operators
    else if (std.mem.eql(u8, node_type, "binary_expression")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (config.count_logical_operators and
                    (std.mem.eql(u8, child_type, "&&") or std.mem.eql(u8, child_type, "||")))
                {
                    count += 1;
                } else if (config.count_nullish_coalescing and std.mem.eql(u8, child_type, "??")) {
                    count += 1;
                }
            }
        }
    }
    // Augmented assignment expressions - check for logical assignments
    else if (std.mem.eql(u8, node_type, "augmented_assignment_expression")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (config.count_logical_operators and
                    (std.mem.eql(u8, child_type, "&&=") or std.mem.eql(u8, child_type, "||=")))
                {
                    count += 1;
                }
            }
        }
    }

    // Optional chaining - check for ?. token in member/call expressions
    // Note: tree-sitter may represent this differently, we'll check during testing
    if (config.count_optional_chaining) {
        if (std.mem.eql(u8, node_type, "member_expression") or
            std.mem.eql(u8, node_type, "call_expression") or
            std.mem.eql(u8, node_type, "subscript_expression"))
        {
            var i: u32 = 0;
            while (i < node.childCount()) : (i += 1) {
                if (node.child(i)) |child| {
                    const child_type = child.nodeType();
                    if (std.mem.eql(u8, child_type, "?.")) {
                        count += 1;
                        break;
                    }
                }
            }
        }
    }

    // Default parameters - defer to Plan 02 if tree-sitter representation is complex
    // This is marked as configurable but not implemented in this plan
    _ = config.count_default_params;

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            count += countDecisionPoints(child, config, source);
        }
    }

    return count;
}

/// Calculate cyclomatic complexity for a function node
pub fn calculateComplexity(node: tree_sitter.Node, config: CyclomaticConfig, source: []const u8) u32 {
    // Base complexity is 1
    // We need to find the function body (statement_block or expression for arrow functions)
    var body_node: ?tree_sitter.Node = null;

    // Look for statement_block child (for regular functions/methods)
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const child_type = child.nodeType();
            if (std.mem.eql(u8, child_type, "statement_block")) {
                body_node = child;
                break;
            }
        }
    }

    // If we found a body, count decision points in it
    if (body_node) |body| {
        return 1 + countDecisionPoints(body, config, source);
    }

    // If no body found (e.g., expression body arrow function), count on the whole node
    return 1 + countDecisionPoints(node, config, source);
}

/// Context for tracking function scope during traversal
const FunctionContext = struct {
    name: []const u8,
    node: tree_sitter.Node,
};

/// Analyze all functions in an AST, returning complexity results
pub fn analyzeFunctions(
    allocator: Allocator,
    root: tree_sitter.Node,
    config: CyclomaticConfig,
    source: []const u8,
) ![]FunctionComplexity {
    var results = std.ArrayList(FunctionComplexity).empty;
    errdefer results.deinit(allocator);

    try walkAndAnalyze(allocator, root, &results, config, source, null);

    return try results.toOwnedSlice(allocator);
}

/// Recursive walker that finds functions and analyzes them
fn walkAndAnalyze(
    allocator: Allocator,
    node: tree_sitter.Node,
    results: *std.ArrayList(FunctionComplexity),
    config: CyclomaticConfig,
    source: []const u8,
    parent_context: ?[]const u8,
) !void {
    const node_type = node.nodeType();

    // Check if this is a function node
    if (isFunctionNode(node)) {
        // Extract function name with context
        var func_name = extractFunctionName(node, source);

        // Override name if we have parent context (e.g., variable assignment)
        if (parent_context) |ctx| {
            func_name = ctx;
        }

        // Calculate complexity
        const complexity = calculateComplexity(node, config, source);

        // Get position info (1-indexed for lines, 0-indexed for columns)
        const start = node.startPoint();
        const end = node.endPoint();

        // Add result
        try results.append(allocator, FunctionComplexity{
            .name = func_name,
            .complexity = complexity,
            .start_line = start.row + 1,
            .end_line = end.row + 1,
            .start_col = start.column,
        });

        // Don't recurse into nested functions - they'll be analyzed separately
        return;
    }

    // Track variable declarations that might contain function expressions
    var child_context: ?[]const u8 = null;

    if (std.mem.eql(u8, node_type, "variable_declarator")) {
        // Look for identifier child to use as function name
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    // Extract identifier text from source
                    const id_start = child.startPoint();
                    const id_end = child.endPoint();
                    const start_byte = id_start.row * 1000 + id_start.column; // Simplified byte offset
                    const end_byte = id_end.row * 1000 + id_end.column;

                    // For now, use placeholder - proper implementation needs byte offsets
                    child_context = "<variable>";
                    _ = start_byte;
                    _ = end_byte;
                    break;
                }
            }
        }
    }

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try walkAndAnalyze(allocator, child, results, config, source, child_context);
        }
    }
}

// TESTS

test "CyclomaticConfig.default returns expected values" {
    const config = CyclomaticConfig.default();
    try std.testing.expect(config.count_logical_operators);
    try std.testing.expect(config.count_nullish_coalescing);
    try std.testing.expect(config.count_optional_chaining);
    try std.testing.expect(config.count_ternary);
    try std.testing.expect(config.count_default_params);
    try std.testing.expectEqual(CyclomaticConfig.SwitchCaseMode.classic, config.switch_case_mode);
}

test "isFunctionNode identifies function_declaration" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function foo() { return 1; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    // Root is "program", first child should be function_declaration
    if (root.child(0)) |func_node| {
        try std.testing.expect(isFunctionNode(func_node));
    }
}

test "simple function has complexity 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f() { return 1; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 1), complexity);
    }
}

test "if statement adds 1 to complexity" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x) { if (x) { return 1; } return 0; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "if/else if has complexity 3" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x) { if (x > 0) {} else if (x < 0) {} }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 3), complexity);
    }
}

test "for loop has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(arr) { for (let i = 0; i < arr.length; i++) {} }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "while loop has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f() { while (true) {} }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "switch with 3 cases has complexity 4 in classic mode" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x) { switch(x) { case 1: break; case 2: break; case 3: break; default: break; } }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 4), complexity);
    }
}

test "catch clause has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f() { try {} catch(e) {} }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "ternary has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x) { return x ? 1 : 0; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "logical AND has complexity 3" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(a, b) { if (a && b) {} }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 3), complexity);
    }
}

test "logical OR has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(a, b) { return a || b; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "nullish coalescing has complexity 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(a) { return a ?? 0; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "nested functions do not inflate parent complexity" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function outer(x) {
        \\  if (x > 0) {
        \\    function inner(y) {
        \\      if (y > 10) {
        \\        return "large";
        \\      }
        \\      return "small";
        \\    }
        \\    return inner(x);
        \\  }
        \\  return "negative";
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const config = CyclomaticConfig.default();
        const complexity = calculateComplexity(func_node, config, source);
        // Outer function should have complexity 2 (base 1 + if statement)
        // Inner function's if statement should NOT count
        try std.testing.expectEqual(@as(u32, 2), complexity);
    }
}

test "analyzeFunctions finds multiple functions" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function foo() { return 1; }
        \\function bar(x) { if (x) { return 2; } return 0; }
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CyclomaticConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
    try std.testing.expectEqual(@as(u32, 2), results[1].complexity);
}
