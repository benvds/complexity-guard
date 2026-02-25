const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const cyclomatic = @import("cyclomatic.zig");
const parse = @import("../parser/parse.zig");
const Allocator = std.mem.Allocator;

/// Configuration for cognitive complexity calculation.
/// Uses SonarSource defaults with ComplexityGuard deviations (see module docs).
pub const CognitiveConfig = struct {
    /// Warning threshold (SonarSource default)
    warning_threshold: u32 = 15,
    /// Error threshold (SonarSource critical zone)
    error_threshold: u32 = 25,

    /// Returns default configuration
    pub fn default() CognitiveConfig {
        return CognitiveConfig{};
    }
};

/// Per-function cognitive complexity result
pub const CognitiveFunctionResult = struct {
    /// Function name
    name: []const u8,
    /// Function kind (function, method, arrow, generator)
    kind: []const u8,
    /// Computed cognitive complexity
    complexity: u32,
    /// Start line (1-indexed)
    start_line: u32,
    /// End line (1-indexed)
    end_line: u32,
    /// Start column (0-indexed)
    start_col: u32,
};

/// Internal context for tracking state during AST traversal
const CognitiveContext = struct {
    nesting_level: u32,
    function_name: []const u8,
    complexity: u32,
    source: []const u8,
};

/// Check if the given string matches a node's text content in source
fn nodeText(node: tree_sitter.Node, source: []const u8) []const u8 {
    const start = node.startByte();
    const end = node.endByte();
    if (start < source.len and end <= source.len) {
        return source[start..end];
    }
    return "";
}

/// Recursive node visitor for cognitive complexity calculation.
/// Implements SonarSource cognitive complexity algorithm with ComplexityGuard deviations:
///   - Each &&, ||, ?? counts as +1 flat individually (not grouped by same-operator sequences)
///   - ?? counts as +1 flat (like && and ||)
///   - ?. (optional chaining) does NOT count
///   - Top-level arrow functions do NOT add nesting (handled at walkAndAnalyze level)
///   - Arrow function callbacks DO increase nesting depth
fn visitNode(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    const node_type = node.nodeType();

    // Scope isolation: stop when we hit any function node.
    // Each function is analyzed independently by walkAndAnalyze.
    if (cyclomatic.isFunctionNode(node)) {
        return;
    }

    // if_statement: structural increment + recurse into body at increased nesting
    if (std.mem.eql(u8, node_type, "if_statement")) {
        // Add structural increment: 1 + nesting_level
        ctx.complexity += 1 + ctx.nesting_level;
        // Recurse into children at increased nesting
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                // Skip else_clause here — it will be handled separately
                if (!std.mem.eql(u8, ct, "else_clause")) {
                    visitNode(ctx, child);
                }
            }
        }
        ctx.nesting_level -= 1;
        // Now handle else_clause (if any) at original nesting level
        var j: u32 = 0;
        while (j < node.childCount()) : (j += 1) {
            if (node.child(j)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "else_clause")) {
                    visitElseClause(ctx, child);
                }
            }
        }
        return;
    }

    // else_clause: handled separately via visitElseClause (called from if_statement)
    if (std.mem.eql(u8, node_type, "else_clause")) {
        // This should only be reached if else_clause appears outside if_statement context.
        // In tree-sitter TS grammar, else_clause is always a child of if_statement,
        // so this path should not be hit in practice.
        visitElseClause(ctx, node);
        return;
    }

    // Structural increments: for/while/do/switch/catch/ternary
    if (std.mem.eql(u8, node_type, "for_statement") or
        std.mem.eql(u8, node_type, "for_in_statement") or
        std.mem.eql(u8, node_type, "while_statement") or
        std.mem.eql(u8, node_type, "do_statement") or
        std.mem.eql(u8, node_type, "switch_statement") or
        std.mem.eql(u8, node_type, "ternary_expression"))
    {
        ctx.complexity += 1 + ctx.nesting_level;
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNode(ctx, child);
            }
        }
        ctx.nesting_level -= 1;
        return;
    }

    // catch_clause: structural increment (try has no increment, finally has no increment)
    if (std.mem.eql(u8, node_type, "catch_clause")) {
        ctx.complexity += 1 + ctx.nesting_level;
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNode(ctx, child);
            }
        }
        ctx.nesting_level -= 1;
        return;
    }

    // binary_expression: check for logical operators && || ??
    // Each counts as +1 flat (ComplexityGuard deviation: per-operator, not per-group)
    if (std.mem.eql(u8, node_type, "binary_expression")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "&&") or
                    std.mem.eql(u8, ct, "||") or
                    std.mem.eql(u8, ct, "??"))
                {
                    ctx.complexity += 1;
                } else {
                    visitNode(ctx, child);
                }
            }
        }
        return;
    }

    // call_expression: check for recursion (direct self-call by name)
    if (std.mem.eql(u8, node_type, "call_expression")) {
        // Check if callee is a bare identifier matching the current function name
        if (node.child(0)) |callee| {
            const callee_type = callee.nodeType();
            if (std.mem.eql(u8, callee_type, "identifier")) {
                const callee_text = nodeText(callee, ctx.source);
                if (ctx.function_name.len > 0 and std.mem.eql(u8, callee_text, ctx.function_name)) {
                    ctx.complexity += 1;
                }
            }
        }
        // Recurse into all children
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNode(ctx, child);
            }
        }
        return;
    }

    // break_statement / continue_statement: +1 flat if labeled
    if (std.mem.eql(u8, node_type, "break_statement") or
        std.mem.eql(u8, node_type, "continue_statement"))
    {
        // Check for a label identifier child (not the keyword itself)
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "statement_identifier")) {
                    ctx.complexity += 1;
                    break;
                }
            }
        }
        return;
    }

    // Default: recurse into all children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            visitNode(ctx, child);
        }
    }
}

/// Handle else_clause node.
/// Adds +1 flat for the else. If the first meaningful child is an if_statement
/// (i.e., "else if"), visits that if_statement as a continuation at current
/// nesting level (not incrementing nesting for the else itself).
/// If the else body is a statement_block, increases nesting for the block.
fn visitElseClause(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    // +1 flat for the else
    ctx.complexity += 1;

    // Check if first non-keyword child is an if_statement (else if pattern)
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            // Skip "else" keyword
            if (std.mem.eql(u8, ct, "else")) continue;

            if (std.mem.eql(u8, ct, "if_statement")) {
                // else if: visit the if_statement as a continuation at current nesting
                // The if_statement handler adds its own structural increment (1 + nesting_level)
                // but does NOT add extra nesting for the else wrapper.
                visitIfAsContinuation(ctx, child);
                return;
            } else {
                // else { block }: increase nesting for the block contents
                ctx.nesting_level += 1;
                visitNode(ctx, child);
                ctx.nesting_level -= 1;
                return;
            }
        }
    }
}

/// Visit an if_statement as an "else if" continuation.
/// The if structural increment uses the CURRENT nesting level (no additional nesting for else).
/// This prevents double-counting.
fn visitIfAsContinuation(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    // Structural increment for the if at current nesting level
    ctx.complexity += 1 + ctx.nesting_level;
    // Recurse into children at increased nesting
    ctx.nesting_level += 1;
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (!std.mem.eql(u8, ct, "else_clause")) {
                visitNode(ctx, child);
            }
        }
    }
    ctx.nesting_level -= 1;
    // Handle else_clause
    var j: u32 = 0;
    while (j < node.childCount()) : (j += 1) {
        if (node.child(j)) |child| {
            if (std.mem.eql(u8, child.nodeType(), "else_clause")) {
                visitElseClause(ctx, child);
            }
        }
    }
}

/// Visit a node known to be an arrow_function callback (nested inside another function body).
/// This is called from walkAndAnalyze when we encounter an arrow_function during traversal
/// that is NOT a top-level definition.
fn visitArrowCallback(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    // Structural increment for the callback arrow
    ctx.complexity += 1 + ctx.nesting_level;
    ctx.nesting_level += 1;
    // Visit the body of the arrow function
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            // Visit body (statement_block or expression), skip parameters and =>
            if (std.mem.eql(u8, ct, "statement_block") or
                std.mem.eql(u8, ct, "expression"))
            {
                visitNode(ctx, child);
            } else if (!std.mem.eql(u8, ct, "formal_parameters") and
                !std.mem.eql(u8, ct, "identifier") and
                !std.mem.eql(u8, ct, "=>") and
                !std.mem.eql(u8, ct, "(") and
                !std.mem.eql(u8, ct, ")"))
            {
                // For expression body arrows (x => expr), visit the expression
                visitNode(ctx, child);
            }
        }
    }
    ctx.nesting_level -= 1;
}

/// Internal version of visitNode that is arrow-function-aware.
/// When we encounter an arrow_function inside a function body traversal,
/// we need to treat it as a structural increment (callback) rather than
/// stopping traversal (as isFunctionNode would cause).
/// This function is called instead of visitNode for general child traversal.
fn visitNodeWithArrows(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    const node_type = node.nodeType();

    // Arrow functions inside a function body = callbacks (structural increment)
    if (std.mem.eql(u8, node_type, "arrow_function")) {
        visitArrowCallback(ctx, node);
        return;
    }

    // All other function nodes: stop (scope isolation)
    if (cyclomatic.isFunctionNode(node)) {
        return;
    }

    // if_statement: structural increment + recurse
    if (std.mem.eql(u8, node_type, "if_statement")) {
        ctx.complexity += 1 + ctx.nesting_level;
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (!std.mem.eql(u8, ct, "else_clause")) {
                    visitNodeWithArrows(ctx, child);
                }
            }
        }
        ctx.nesting_level -= 1;
        // Handle else
        var j: u32 = 0;
        while (j < node.childCount()) : (j += 1) {
            if (node.child(j)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "else_clause")) {
                    visitElseClauseWithArrows(ctx, child);
                }
            }
        }
        return;
    }

    if (std.mem.eql(u8, node_type, "else_clause")) {
        visitElseClauseWithArrows(ctx, node);
        return;
    }

    // Structural increments: for/while/do/switch/catch/ternary
    if (std.mem.eql(u8, node_type, "for_statement") or
        std.mem.eql(u8, node_type, "for_in_statement") or
        std.mem.eql(u8, node_type, "while_statement") or
        std.mem.eql(u8, node_type, "do_statement") or
        std.mem.eql(u8, node_type, "switch_statement") or
        std.mem.eql(u8, node_type, "ternary_expression"))
    {
        ctx.complexity += 1 + ctx.nesting_level;
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNodeWithArrows(ctx, child);
            }
        }
        ctx.nesting_level -= 1;
        return;
    }

    // catch_clause
    if (std.mem.eql(u8, node_type, "catch_clause")) {
        ctx.complexity += 1 + ctx.nesting_level;
        ctx.nesting_level += 1;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNodeWithArrows(ctx, child);
            }
        }
        ctx.nesting_level -= 1;
        return;
    }

    // binary_expression: logical operators
    if (std.mem.eql(u8, node_type, "binary_expression")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "&&") or
                    std.mem.eql(u8, ct, "||") or
                    std.mem.eql(u8, ct, "??"))
                {
                    ctx.complexity += 1;
                } else {
                    visitNodeWithArrows(ctx, child);
                }
            }
        }
        return;
    }

    // call_expression: recursion detection
    if (std.mem.eql(u8, node_type, "call_expression")) {
        if (node.child(0)) |callee| {
            const callee_type = callee.nodeType();
            if (std.mem.eql(u8, callee_type, "identifier")) {
                const callee_text = nodeText(callee, ctx.source);
                if (ctx.function_name.len > 0 and std.mem.eql(u8, callee_text, ctx.function_name)) {
                    ctx.complexity += 1;
                }
            }
        }
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                visitNodeWithArrows(ctx, child);
            }
        }
        return;
    }

    // break/continue with label
    if (std.mem.eql(u8, node_type, "break_statement") or
        std.mem.eql(u8, node_type, "continue_statement"))
    {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "statement_identifier")) {
                    ctx.complexity += 1;
                    break;
                }
            }
        }
        return;
    }

    // Default: recurse
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            visitNodeWithArrows(ctx, child);
        }
    }
}

/// Arrow-aware version of visitElseClause
fn visitElseClauseWithArrows(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    ctx.complexity += 1;

    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (std.mem.eql(u8, ct, "else")) continue;

            if (std.mem.eql(u8, ct, "if_statement")) {
                visitIfAsContinuationWithArrows(ctx, child);
                return;
            } else {
                ctx.nesting_level += 1;
                visitNodeWithArrows(ctx, child);
                ctx.nesting_level -= 1;
                return;
            }
        }
    }
}

/// Arrow-aware version of visitIfAsContinuation
fn visitIfAsContinuationWithArrows(ctx: *CognitiveContext, node: tree_sitter.Node) void {
    ctx.complexity += 1 + ctx.nesting_level;
    ctx.nesting_level += 1;
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (!std.mem.eql(u8, ct, "else_clause")) {
                visitNodeWithArrows(ctx, child);
            }
        }
    }
    ctx.nesting_level -= 1;
    var j: u32 = 0;
    while (j < node.childCount()) : (j += 1) {
        if (node.child(j)) |child| {
            if (std.mem.eql(u8, child.nodeType(), "else_clause")) {
                visitElseClauseWithArrows(ctx, child);
            }
        }
    }
}

/// Calculate cognitive complexity for a given function node.
/// Finds the function body and traverses it with nesting tracking starting at 0.
pub fn calculateCognitiveComplexity(
    node: tree_sitter.Node,
    source: []const u8,
    function_name: []const u8,
) u32 {
    var ctx = CognitiveContext{
        .nesting_level = 0,
        .function_name = function_name,
        .complexity = 0,
        .source = source,
    };

    const node_type = node.nodeType();

    // Find the function body
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (std.mem.eql(u8, ct, "statement_block")) {
                // Visit all children of the statement_block
                var j: u32 = 0;
                while (j < child.childCount()) : (j += 1) {
                    if (child.child(j)) |stmt| {
                        visitNodeWithArrows(&ctx, stmt);
                    }
                }
                return ctx.complexity;
            }
        }
    }

    // For arrow functions with expression bodies (x => expr), the body is not a statement_block
    // Find the body after the => token
    if (std.mem.eql(u8, node_type, "arrow_function")) {
        var found_arrow = false;
        var k: u32 = 0;
        while (k < node.childCount()) : (k += 1) {
            if (node.child(k)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "=>")) {
                    found_arrow = true;
                    continue;
                }
                if (found_arrow) {
                    visitNodeWithArrows(&ctx, child);
                    return ctx.complexity;
                }
            }
        }
    }

    return ctx.complexity;
}

/// Analyze all functions in an AST, returning cognitive complexity results
pub fn analyzeFunctions(
    allocator: Allocator,
    root: tree_sitter.Node,
    config: CognitiveConfig,
    source: []const u8,
) ![]CognitiveFunctionResult {
    var results = std.ArrayList(CognitiveFunctionResult).empty;
    errdefer results.deinit(allocator);

    try walkAndAnalyze(allocator, root, &results, config, source, null);

    return try results.toOwnedSlice(allocator);
}

/// Context passed down to child walkers for function naming
const WalkContext = struct {
    name: []const u8,
    /// Class name when walking inside a class_declaration (for "ClassName.method" naming)
    class_name: ?[]const u8 = null,
    /// Object key name when walking inside a pair node (for object literal methods)
    object_key: ?[]const u8 = null,
    /// Call expression callee name when function is an argument (for "callee callback" naming)
    call_name: ?[]const u8 = null,
    /// Whether function is a direct child of export default (for "default export" naming)
    is_default_export: bool = false,
};

/// Recursive walker that finds functions and analyzes their cognitive complexity
fn walkAndAnalyze(
    allocator: Allocator,
    node: tree_sitter.Node,
    results: *std.ArrayList(CognitiveFunctionResult),
    config: CognitiveConfig,
    source: []const u8,
    parent_context: ?WalkContext,
) !void {
    const node_type = node.nodeType();

    if (cyclomatic.isFunctionNode(node)) {
        // Extract function info
        const func_info = cyclomatic.extractFunctionInfo(node, source);
        var func_name = func_info.name;
        const func_kind = func_info.kind;

        // Apply naming priority from parent context
        if (parent_context) |ctx| {
            if (ctx.name.len > 0 and !std.mem.eql(u8, ctx.name, "<anonymous>")) {
                // Priority 1: explicit variable name from variable_declarator
                if (ctx.class_name == null and ctx.object_key == null and ctx.call_name == null and !ctx.is_default_export) {
                    func_name = ctx.name;
                }
            }

            // Priority 2: class method — compose "ClassName.methodName"
            if (ctx.class_name) |class_name| {
                if (std.mem.eql(u8, func_kind, "method")) {
                    const method_name = func_info.name;
                    if (!std.mem.eql(u8, method_name, "<anonymous>")) {
                        func_name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ class_name, method_name });
                    } else {
                        func_name = class_name;
                    }
                }
            }

            // Priority 3: object key name
            if (ctx.object_key) |key| {
                if (std.mem.eql(u8, func_info.name, "<anonymous>") or std.mem.eql(u8, func_kind, "arrow")) {
                    func_name = key;
                }
            }

            // Priority 4: callback naming
            if (ctx.call_name) |call_name| {
                if (std.mem.eql(u8, func_info.name, "<anonymous>") or std.mem.eql(u8, func_kind, "arrow")) {
                    if (std.mem.endsWith(u8, call_name, " handler")) {
                        func_name = call_name;
                    } else {
                        func_name = try std.fmt.allocPrint(allocator, "{s} callback", .{call_name});
                    }
                }
            }

            // Priority 5: default export
            if (ctx.is_default_export) {
                if (std.mem.eql(u8, func_info.name, "<anonymous>")) {
                    func_name = "default export";
                }
            }
        }

        // Calculate cognitive complexity
        const complexity = calculateCognitiveComplexity(node, source, func_name);

        // Get position info
        const start = node.startPoint();
        const end = node.endPoint();

        try results.append(allocator, CognitiveFunctionResult{
            .name = func_name,
            .kind = func_kind,
            .complexity = complexity,
            .start_line = start.row + 1,
            .end_line = end.row + 1,
            .start_col = start.column,
        });

        // Do not recurse into this function's body — nested functions are not
        // discovered separately (they would have scope isolation from the outer function).
        // This matches cyclomatic.zig's behavior.
        return;
    }

    // Track variable declarations that might contain arrow functions
    var child_context: ?WalkContext = null;

    if (std.mem.eql(u8, node_type, "variable_declarator")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "identifier")) {
                    const id_start = child.startByte();
                    const id_end = child.endByte();
                    if (id_start < source.len and id_end <= source.len) {
                        child_context = WalkContext{
                            .name = source[id_start..id_end],
                        };
                    }
                    break;
                }
            }
        }
    }
    // Track class declarations for "ClassName.method" naming
    else if (std.mem.eql(u8, node_type, "class_declaration") or std.mem.eql(u8, node_type, "class")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const ct = child.nodeType();
                if (std.mem.eql(u8, ct, "identifier") or std.mem.eql(u8, ct, "type_identifier")) {
                    const id_start = child.startByte();
                    const id_end = child.endByte();
                    if (id_start < source.len and id_end <= source.len) {
                        child_context = WalkContext{
                            .name = "<anonymous>",
                            .class_name = source[id_start..id_end],
                        };
                    }
                    break;
                }
            }
        }
        if (child_context == null) {
            child_context = WalkContext{ .name = "<anonymous>", .class_name = "class" };
        }
    }
    // Track object literal pair key for method naming
    else if (std.mem.eql(u8, node_type, "pair")) {
        if (node.child(0)) |key_node| {
            const key_type = key_node.nodeType();
            if (std.mem.eql(u8, key_type, "property_identifier") or std.mem.eql(u8, key_type, "string")) {
                const key_start = key_node.startByte();
                const key_end = key_node.endByte();
                if (key_start < source.len and key_end <= source.len) {
                    var key_text = source[key_start..key_end];
                    if (std.mem.startsWith(u8, key_text, "\"") or std.mem.startsWith(u8, key_text, "'")) {
                        key_text = key_text[1 .. key_text.len - 1];
                    }
                    child_context = WalkContext{
                        .name = "<anonymous>",
                        .object_key = key_text,
                    };
                }
            }
        }
    }
    // Track call expression callee for "X callback" or "event handler" naming
    else if (std.mem.eql(u8, node_type, "call_expression")) {
        if (node.child(0)) |callee| {
            const callee_type = callee.nodeType();
            if (std.mem.eql(u8, callee_type, "identifier")) {
                const id_start = callee.startByte();
                const id_end = callee.endByte();
                if (id_start < source.len and id_end <= source.len) {
                    const callee_name = source[id_start..id_end];
                    if (std.mem.eql(u8, callee_name, "addEventListener")) {
                        var event_name: ?[]const u8 = null;
                        if (node.child(1)) |args_node| {
                            if (std.mem.eql(u8, args_node.nodeType(), "arguments")) {
                                var j: u32 = 0;
                                while (j < args_node.childCount()) : (j += 1) {
                                    if (args_node.child(j)) |arg| {
                                        if (std.mem.eql(u8, arg.nodeType(), "string")) {
                                            const s_start = arg.startByte();
                                            const s_end = arg.endByte();
                                            if (s_start < source.len and s_end <= source.len) {
                                                var str_text = source[s_start..s_end];
                                                if (str_text.len >= 2) str_text = str_text[1 .. str_text.len - 1];
                                                event_name = str_text;
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        if (event_name) |ev| {
                            const handler_name = try std.fmt.allocPrint(allocator, "{s} handler", .{ev});
                            child_context = WalkContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = WalkContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = WalkContext{ .name = "<anonymous>", .call_name = callee_name };
                    }
                }
            } else if (std.mem.eql(u8, callee_type, "member_expression")) {
                const last_seg = cogGetLastMemberSegment(callee, source);
                if (last_seg) |seg| {
                    if (std.mem.eql(u8, seg, "addEventListener")) {
                        var event_name: ?[]const u8 = null;
                        if (node.child(1)) |args_node| {
                            if (std.mem.eql(u8, args_node.nodeType(), "arguments")) {
                                var j: u32 = 0;
                                while (j < args_node.childCount()) : (j += 1) {
                                    if (args_node.child(j)) |arg| {
                                        if (std.mem.eql(u8, arg.nodeType(), "string")) {
                                            const s_start = arg.startByte();
                                            const s_end = arg.endByte();
                                            if (s_start < source.len and s_end <= source.len) {
                                                var str_text = source[s_start..s_end];
                                                if (str_text.len >= 2) str_text = str_text[1 .. str_text.len - 1];
                                                event_name = str_text;
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        if (event_name) |ev| {
                            const handler_name = try std.fmt.allocPrint(allocator, "{s} handler", .{ev});
                            child_context = WalkContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = WalkContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = WalkContext{ .name = "<anonymous>", .call_name = seg };
                    }
                }
            }
        }
    }
    // Track export default for "default export" naming
    else if (std.mem.eql(u8, node_type, "export_statement")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "default")) {
                    child_context = WalkContext{ .name = "<anonymous>", .is_default_export = true };
                    break;
                }
            }
        }
    }
    // Pass class context through class_body (container node — no context change)
    else if (std.mem.eql(u8, node_type, "class_body")) {
        child_context = parent_context;
    }
    // Pass call context through arguments (container for callback function arguments)
    else if (std.mem.eql(u8, node_type, "arguments")) {
        child_context = parent_context;
    }

    // Recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try walkAndAnalyze(allocator, child, results, config, source, child_context);
        }
    }
}

/// Extract the last identifier segment from a member_expression node
fn cogGetLastMemberSegment(node: tree_sitter.Node, source: []const u8) ?[]const u8 {
    var last: ?[]const u8 = null;
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            const ct = child.nodeType();
            if (std.mem.eql(u8, ct, "property_identifier") or std.mem.eql(u8, ct, "identifier")) {
                const s = child.startByte();
                const e = child.endByte();
                if (s < source.len and e <= source.len) {
                    last = source[s..e];
                }
            }
        }
    }
    return last;
}

/// Analyze a parsed file and return threshold results with cognitive complexity populated.
/// Note: Returns ThresholdResult with cognitive fields set and cyclomatic fields at 0.
/// The integration in main.zig (Plan 02) will merge both metrics.
pub fn analyzeFile(
    allocator: Allocator,
    parse_result: parse.ParseResult,
    config: CognitiveConfig,
) ![]cyclomatic.ThresholdResult {
    if (parse_result.tree == null) {
        return &[_]cyclomatic.ThresholdResult{};
    }

    const tree = parse_result.tree.?;
    const root = tree.rootNode();

    const cog_results = try analyzeFunctions(
        allocator,
        root,
        config,
        parse_result.source,
    );
    defer allocator.free(cog_results);

    var results = std.ArrayList(cyclomatic.ThresholdResult).empty;
    errdefer results.deinit(allocator);

    for (cog_results) |cr| {
        const cog_status = cyclomatic.validateThreshold(
            cr.complexity,
            config.warning_threshold,
            config.error_threshold,
        );

        try results.append(allocator, cyclomatic.ThresholdResult{
            .complexity = 0, // cyclomatic not computed here
            .status = .ok, // cyclomatic status not computed here
            .function_name = cr.name,
            .function_kind = cr.kind,
            .start_line = cr.start_line,
            .start_col = cr.start_col,
            .cognitive_complexity = cr.complexity,
            .cognitive_status = cog_status,
        });
    }

    return try results.toOwnedSlice(allocator);
}

// TESTS

test "CognitiveConfig.default returns expected values" {
    const config = CognitiveConfig.default();
    try std.testing.expectEqual(@as(u32, 15), config.warning_threshold);
    try std.testing.expectEqual(@as(u32, 25), config.error_threshold);
}

test "cognitive: simple function has complexity 0" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function baseline() { return 42; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqual(@as(u32, 0), results[0].complexity);
    try std.testing.expectEqualStrings("baseline", results[0].name);
}

test "cognitive: single if has complexity 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function singleIf(x) { if (x > 0) { return 1; } return 0; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
}

test "cognitive: if/else if/else chain has complexity 4" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function ifElseChain(x) {
        \\  if (x > 0) {
        \\    return "pos";
        \\  } else if (x < 0) {
        \\    return "neg";
        \\  } else {
        \\    return "zero";
        \\  }
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // if (+1 nesting 0) + else (+1 flat) + if_continuation (+1 nesting 0) + else (+1 flat) = 4
    try std.testing.expectEqual(@as(u32, 4), results[0].complexity);
}

test "cognitive: nested if in for loop has complexity 6" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function nestedIfInLoop(items) {
        \\  for (const item of items) {
        \\    if (item.active) {
        \\      if (item.score > 50) {
        \\        return item;
        \\      }
        \\    }
        \\  }
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // for (+1 nesting 0) + if (+1+1 nesting 1) + if (+1+2 nesting 2) = 1+2+3 = 6
    try std.testing.expectEqual(@as(u32, 6), results[0].complexity);
}

test "cognitive: logical operators each count +1 flat" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function logicalOps(a, b, c) { if (a && b && c) { return true; } return false; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // if (+1) + && (+1) + && (+1) = 3
    try std.testing.expectEqual(@as(u32, 3), results[0].complexity);
}

test "cognitive: recursion adds +1 flat" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function factorial(n) {
        \\  if (n <= 1) { return 1; }
        \\  return n * factorial(n - 1);
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // if (+1 nesting 0) + recursion (+1 flat) = 2
    try std.testing.expectEqual(@as(u32, 2), results[0].complexity);
}

test "cognitive: top-level arrow does not add nesting" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "const topLevelArrow = (x) => { if (x > 0) { return 1; } return 0; };";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // Top-level arrow: starts at nesting 0 (treated like function declaration)
    // if at nesting 0: +1
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
    try std.testing.expectEqualStrings("topLevelArrow", results[0].name);
}

test "cognitive: callback arrow increases nesting" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function withCallback(items) {
        \\  return items.filter((x) => {
        \\    if (x > 0) { return true; }
        \\    return false;
        \\  });
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    // Should find withCallback only (the arrow callback is internal)
    try std.testing.expectEqual(@as(usize, 1), results.len);
    // arrow callback (+1 at nesting 0) + if inside (+1+1 at nesting 1) = 3
    try std.testing.expectEqual(@as(u32, 3), results[0].complexity);
}

test "cognitive: switch adds +1 structural, cases do not count" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function switchStatement(x) {
        \\  switch (x) {
        \\    case 1: return "one";
        \\    case 2: return "two";
        \\    default: return "other";
        \\  }
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // switch (+1 at nesting 0) = 1
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
}

test "cognitive: catch adds +1 structural, try/finally do not" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function tryCatch() {
        \\  try { return JSON.parse("{}"); }
        \\  catch (e) { return null; }
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // catch (+1 at nesting 0) = 1
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
}

test "cognitive: ternary adds structural increment with nesting" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function ternaryNested(x) {
        \\  return x > 0 ? (x > 100 ? "large" : "small") : "negative";
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // outer ternary (+1 at nesting 0) + nested ternary (+1+1 at nesting 1) = 3
    try std.testing.expectEqual(@as(u32, 3), results[0].complexity);
}

test "cognitive: nested function scope isolation" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function outer(x) {
        \\  if (x > 0) {
        \\    function inner(y) {
        \\      if (y > 10) { return "large"; }
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
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    // Only outer is discovered at the top level; inner is inside outer's body
    // and is not registered separately (same behavior as cyclomatic.zig)
    try std.testing.expectEqual(@as(usize, 1), results.len);

    // outer: if (+1 at nesting 0) = 1 (inner's if does NOT count due to scope isolation)
    try std.testing.expectEqualStrings("outer", results[0].name);
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
}

test "cognitive: nullish coalescing ?? counts as +1 flat" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(a, b) { return a ?? b ?? 'default'; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(std.testing.allocator, root, config, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // ?? (+1) + ?? (+1) = 2
    try std.testing.expectEqual(@as(u32, 2), results[0].complexity);
}

test "cognitive: integration test against cognitive_cases.ts fixture" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const fixture_path = "tests/fixtures/typescript/cognitive_cases.ts";
    const file = try std.fs.cwd().openFile(fixture_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(std.testing.allocator, 1024 * 1024);
    defer std.testing.allocator.free(source);

    const tree = try parser.parseString(source);
    defer tree.deinit();

    // Use arena allocator: composed names (e.g., "MyClass.classMethod") are allocPrint'd
    // into the arena and freed together with arena.deinit()
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const root = tree.rootNode();
    const config = CognitiveConfig.default();
    const results = try analyzeFunctions(alloc, root, config, source);

    // Should find multiple functions
    try std.testing.expect(results.len >= 10);

    // Check specific function scores by name
    const expected = [_]struct { name: []const u8, score: u32 }{
        .{ .name = "baseline", .score = 0 },
        .{ .name = "singleIf", .score = 1 },
        .{ .name = "ifElseChain", .score = 4 },
        .{ .name = "nestedIfInLoop", .score = 6 },
        .{ .name = "logicalOps", .score = 3 },
        .{ .name = "mixedLogicalOps", .score = 4 },
        .{ .name = "factorial", .score = 2 },
        .{ .name = "topLevelArrow", .score = 1 },
        .{ .name = "switchStatement", .score = 1 },
        .{ .name = "tryCatch", .score = 1 },
        .{ .name = "ternaryNested", .score = 3 },
        .{ .name = "deeplyNested", .score = 10 },
    };

    for (expected) |exp| {
        var found = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.name, exp.name)) {
                found = true;
                if (r.complexity != exp.score) {
                    std.debug.print("FAIL: {s} expected {d}, got {d}\n", .{ exp.name, exp.score, r.complexity });
                }
                try std.testing.expectEqual(exp.score, r.complexity);
                break;
            }
        }
        if (!found) {
            std.debug.print("NOT FOUND: {s}\n", .{exp.name});
            try std.testing.expect(found);
        }
    }
}
