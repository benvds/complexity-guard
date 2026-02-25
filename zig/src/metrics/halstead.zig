const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const cyclomatic = @import("cyclomatic.zig");
const Allocator = std.mem.Allocator;

/// Halstead metrics for a function
pub const HalsteadMetrics = struct {
    /// Distinct operators count
    n1: u32,
    /// Distinct operands count
    n2: u32,
    /// Total operator occurrences
    n1_total: u32,
    /// Total operand occurrences
    n2_total: u32,
    /// Vocabulary: n = n1 + n2
    vocabulary: u32,
    /// Length: N = N1 + N2
    length: u32,
    /// Volume: V = N * log2(n)
    volume: f64,
    /// Difficulty: D = (n1/2) * (N2/n2), 0 if n2 == 0
    difficulty: f64,
    /// Effort: E = V * D
    effort: f64,
    /// Time: T = E / 18 (seconds)
    time: f64,
    /// Bugs: B = V / 3000
    bugs: f64,
};

/// Configuration for Halstead analysis
pub const HalsteadConfig = struct {
    /// Volume warning threshold (industry default)
    volume_warning: f64 = 500.0,
    /// Volume error threshold
    volume_error: f64 = 1000.0,
    /// Difficulty warning threshold
    difficulty_warning: f64 = 10.0,
    /// Difficulty error threshold
    difficulty_error: f64 = 20.0,
    /// Effort warning threshold
    effort_warning: f64 = 5000.0,
    /// Effort error threshold
    effort_error: f64 = 10000.0,
    /// Bugs warning threshold
    bugs_warning: f64 = 0.5,
    /// Bugs error threshold
    bugs_error: f64 = 2.0,

    /// Returns default configuration with industry standard thresholds
    pub fn default() HalsteadConfig {
        return HalsteadConfig{};
    }
};

/// Per-function Halstead result
pub const HalsteadFunctionResult = struct {
    /// Function name
    name: []const u8,
    /// Function kind
    kind: []const u8,
    /// Halstead metrics
    metrics: HalsteadMetrics,
    /// Start line (1-indexed)
    start_line: u32,
    /// End line (1-indexed)
    end_line: u32,
    /// Start column (0-indexed)
    start_col: u32,
};

/// Check if a node type is a TypeScript-only type annotation node that should be skipped.
/// Returns true for the node and its entire subtree should be excluded.
pub fn isTypeOnlyNode(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "type_annotation") or
        std.mem.eql(u8, node_type, "type_identifier") or
        std.mem.eql(u8, node_type, "generic_type") or
        std.mem.eql(u8, node_type, "type_parameters") or
        std.mem.eql(u8, node_type, "type_parameter") or
        std.mem.eql(u8, node_type, "predefined_type") or
        std.mem.eql(u8, node_type, "union_type") or
        std.mem.eql(u8, node_type, "intersection_type") or
        std.mem.eql(u8, node_type, "array_type") or
        std.mem.eql(u8, node_type, "object_type") or
        std.mem.eql(u8, node_type, "tuple_type") or
        std.mem.eql(u8, node_type, "function_type") or
        std.mem.eql(u8, node_type, "readonly_type") or
        std.mem.eql(u8, node_type, "type_query") or
        std.mem.eql(u8, node_type, "as_expression") or
        std.mem.eql(u8, node_type, "satisfies_expression") or
        std.mem.eql(u8, node_type, "interface_declaration") or
        std.mem.eql(u8, node_type, "type_alias_declaration");
}

/// Check if a leaf node type is an operator token.
/// Returns true for operators that should be counted in Halstead metrics.
pub fn isOperatorToken(node_type: []const u8) bool {
    // Arithmetic operators
    if (std.mem.eql(u8, node_type, "+") or
        std.mem.eql(u8, node_type, "-") or
        std.mem.eql(u8, node_type, "*") or
        std.mem.eql(u8, node_type, "/") or
        std.mem.eql(u8, node_type, "%") or
        std.mem.eql(u8, node_type, "**")) return true;

    // Comparison operators
    if (std.mem.eql(u8, node_type, "==") or
        std.mem.eql(u8, node_type, "!=") or
        std.mem.eql(u8, node_type, "===") or
        std.mem.eql(u8, node_type, "!==") or
        std.mem.eql(u8, node_type, "<") or
        std.mem.eql(u8, node_type, ">") or
        std.mem.eql(u8, node_type, "<=") or
        std.mem.eql(u8, node_type, ">=")) return true;

    // Logical operators
    if (std.mem.eql(u8, node_type, "&&") or
        std.mem.eql(u8, node_type, "||") or
        std.mem.eql(u8, node_type, "??")) return true;

    // Assignment operators
    if (std.mem.eql(u8, node_type, "=") or
        std.mem.eql(u8, node_type, "+=") or
        std.mem.eql(u8, node_type, "-=") or
        std.mem.eql(u8, node_type, "*=") or
        std.mem.eql(u8, node_type, "/=") or
        std.mem.eql(u8, node_type, "%=") or
        std.mem.eql(u8, node_type, "**=") or
        std.mem.eql(u8, node_type, "&&=") or
        std.mem.eql(u8, node_type, "||=") or
        std.mem.eql(u8, node_type, "??=") or
        std.mem.eql(u8, node_type, "<<=") or
        std.mem.eql(u8, node_type, ">>=") or
        std.mem.eql(u8, node_type, ">>>=") or
        std.mem.eql(u8, node_type, "&=") or
        std.mem.eql(u8, node_type, "|=") or
        std.mem.eql(u8, node_type, "^=")) return true;

    // Bitwise operators
    if (std.mem.eql(u8, node_type, "&") or
        std.mem.eql(u8, node_type, "|") or
        std.mem.eql(u8, node_type, "^") or
        std.mem.eql(u8, node_type, "~") or
        std.mem.eql(u8, node_type, "<<") or
        std.mem.eql(u8, node_type, ">>") or
        std.mem.eql(u8, node_type, ">>>")) return true;

    // Unary keyword operators
    if (std.mem.eql(u8, node_type, "typeof") or
        std.mem.eql(u8, node_type, "void") or
        std.mem.eql(u8, node_type, "delete") or
        std.mem.eql(u8, node_type, "await") or
        std.mem.eql(u8, node_type, "yield")) return true;

    // Unary symbol operators
    if (std.mem.eql(u8, node_type, "!") or
        std.mem.eql(u8, node_type, "++") or
        std.mem.eql(u8, node_type, "--")) return true;

    // Control flow keywords
    if (std.mem.eql(u8, node_type, "if") or
        std.mem.eql(u8, node_type, "else") or
        std.mem.eql(u8, node_type, "for") or
        std.mem.eql(u8, node_type, "while") or
        std.mem.eql(u8, node_type, "do") or
        std.mem.eql(u8, node_type, "switch") or
        std.mem.eql(u8, node_type, "case") or
        std.mem.eql(u8, node_type, "default") or
        std.mem.eql(u8, node_type, "break") or
        std.mem.eql(u8, node_type, "continue") or
        std.mem.eql(u8, node_type, "return") or
        std.mem.eql(u8, node_type, "throw") or
        std.mem.eql(u8, node_type, "try") or
        std.mem.eql(u8, node_type, "catch") or
        std.mem.eql(u8, node_type, "finally") or
        std.mem.eql(u8, node_type, "new") or
        std.mem.eql(u8, node_type, "in") or
        std.mem.eql(u8, node_type, "of") or
        std.mem.eql(u8, node_type, "instanceof")) return true;

    // Punctuation-operators
    if (std.mem.eql(u8, node_type, ",")) return true;

    // Decorator symbol
    if (std.mem.eql(u8, node_type, "@")) return true;

    return false;
}

/// Check if a leaf node type is an operand token.
/// Returns true for identifiers, literals, and special values.
pub fn isOperandToken(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "identifier") or
        std.mem.eql(u8, node_type, "number") or
        std.mem.eql(u8, node_type, "string") or
        std.mem.eql(u8, node_type, "template_string") or
        std.mem.eql(u8, node_type, "regex") or
        std.mem.eql(u8, node_type, "true") or
        std.mem.eql(u8, node_type, "false") or
        std.mem.eql(u8, node_type, "null") or
        std.mem.eql(u8, node_type, "undefined") or
        std.mem.eql(u8, node_type, "this") or
        std.mem.eql(u8, node_type, "property_identifier");
}

/// Compute Halstead derived metrics from base counts.
/// Pure formula computation with edge case guards (no division by zero).
pub fn computeHalsteadMetrics(n1: u32, n2: u32, n1_total: u32, n2_total: u32) HalsteadMetrics {
    const vocabulary: u32 = n1 + n2;
    const length: u32 = n1_total + n2_total;

    // Edge case: empty function or zero vocabulary
    if (vocabulary == 0) {
        return HalsteadMetrics{
            .n1 = n1,
            .n2 = n2,
            .n1_total = n1_total,
            .n2_total = n2_total,
            .vocabulary = 0,
            .length = 0,
            .volume = 0.0,
            .difficulty = 0.0,
            .effort = 0.0,
            .time = 0.0,
            .bugs = 0.0,
        };
    }

    const volume: f64 = @as(f64, @floatFromInt(length)) * std.math.log2(@as(f64, @floatFromInt(vocabulary)));

    // Difficulty: D = (n1/2) * (N2/n2), 0 if n2 == 0
    const difficulty: f64 = if (n2 == 0)
        0.0
    else
        (@as(f64, @floatFromInt(n1)) / 2.0) * (@as(f64, @floatFromInt(n2_total)) / @as(f64, @floatFromInt(n2)));

    const effort: f64 = volume * difficulty;
    const time: f64 = effort / 18.0;
    const bugs: f64 = volume / 3000.0;

    return HalsteadMetrics{
        .n1 = n1,
        .n2 = n2,
        .n1_total = n1_total,
        .n2_total = n2_total,
        .vocabulary = vocabulary,
        .length = length,
        .volume = volume,
        .difficulty = difficulty,
        .effort = effort,
        .time = time,
        .bugs = bugs,
    };
}

/// Context used during Halstead token classification walk
const HalsteadContext = struct {
    /// Maps operator text -> void (for distinct counting)
    operators: std.StringHashMap(void),
    /// Maps operand text -> void (for distinct counting)
    operands: std.StringHashMap(void),
    /// Total operator occurrences
    n1_total: u32,
    /// Total operand occurrences
    n2_total: u32,
};

/// Recursive AST walker that classifies leaf nodes as operators or operands.
/// Handles ternary_expression as a special case (non-leaf node counts as operator).
/// Stops recursion at function boundaries (scope isolation).
fn classifyNode(ctx: *HalsteadContext, node: tree_sitter.Node, source: []const u8) !void {
    const node_type = node.nodeType();

    // Stop at nested function boundaries (scope isolation like cyclomatic/cognitive)
    if (cyclomatic.isFunctionNode(node)) {
        return;
    }

    // Skip TypeScript type-only nodes and their entire subtrees
    if (isTypeOnlyNode(node_type)) {
        return;
    }

    // Special case: ternary_expression — count "?:" as one operator before recursing
    if (std.mem.eql(u8, node_type, "ternary_expression")) {
        const key = "?:";
        try ctx.operators.put(key, {});
        ctx.n1_total += 1;
        // Recurse into children (leaf ? and : tokens will be skipped)
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                try classifyNode(ctx, child, source);
            }
        }
        return;
    }

    // Leaf node classification
    if (node.childCount() == 0) {
        if (isOperatorToken(node_type)) {
            // Use node type string as key (operators identified by syntax type)
            try ctx.operators.put(node_type, {});
            ctx.n1_total += 1;
        } else if (isOperandToken(node_type)) {
            // Use actual source text as key (operands identified by their value)
            const start = node.startByte();
            const end = node.endByte();
            if (start < source.len and end <= source.len) {
                const text = source[start..end];
                try ctx.operands.put(text, {});
                ctx.n2_total += 1;
            }
        }
        // Skip: structural punctuation, TS type tokens, comments
        return;
    }

    // Non-leaf: recurse into children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try classifyNode(ctx, child, source);
        }
    }
}

/// Calculate Halstead metrics for a function body node.
/// Takes the function node itself (body is extracted internally).
pub fn calculateHalstead(allocator: Allocator, func_node: tree_sitter.Node, source: []const u8) !HalsteadMetrics {
    // Initialize context directly — avoids copy-on-assign memory management issues
    var ctx = HalsteadContext{
        .operators = std.StringHashMap(void).init(allocator),
        .operands = std.StringHashMap(void).init(allocator),
        .n1_total = 0,
        .n2_total = 0,
    };
    defer ctx.operators.deinit();
    defer ctx.operands.deinit();

    // Find the function body (statement_block for regular functions, expression for arrows)
    var body_node: ?tree_sitter.Node = null;
    var i: u32 = 0;
    while (i < func_node.childCount()) : (i += 1) {
        if (func_node.child(i)) |child| {
            const child_type = child.nodeType();
            if (std.mem.eql(u8, child_type, "statement_block")) {
                body_node = child;
                break;
            }
        }
    }

    if (body_node) |body| {
        // Walk children of statement_block (not the { } themselves)
        var j: u32 = 0;
        while (j < body.childCount()) : (j += 1) {
            if (body.child(j)) |child| {
                try classifyNode(&ctx, child, source);
            }
        }
    } else {
        // Expression body arrow function: walk the function node directly
        var j: u32 = 0;
        while (j < func_node.childCount()) : (j += 1) {
            if (func_node.child(j)) |child| {
                const child_type = child.nodeType();
                // Skip parameter list and arrow token, only walk the body expression
                if (!std.mem.eql(u8, child_type, "formal_parameters") and
                    !std.mem.eql(u8, child_type, "=>") and
                    !std.mem.eql(u8, child_type, "identifier") and
                    !std.mem.eql(u8, child_type, "type_annotation"))
                {
                    try classifyNode(&ctx, child, source);
                }
            }
        }
    }

    // Extract counts before ctx is deferred-deinit'd
    const n1 = @as(u32, ctx.operators.count());
    const n2 = @as(u32, ctx.operands.count());
    const n1_total = ctx.n1_total;
    const n2_total = ctx.n2_total;

    return computeHalsteadMetrics(n1, n2, n1_total, n2_total);
}

/// Analyze all functions in an AST, returning Halstead results.
/// Follows the walkAndAnalyze pattern from cyclomatic.zig.
pub fn analyzeFunctions(
    allocator: Allocator,
    root: tree_sitter.Node,
    config: HalsteadConfig,
    source: []const u8,
) ![]HalsteadFunctionResult {
    _ = config; // Config used for threshold reporting, not counting
    var results = std.ArrayList(HalsteadFunctionResult).empty;
    errdefer results.deinit(allocator);

    try walkAndAnalyze(allocator, root, &results, source, null);

    return try results.toOwnedSlice(allocator);
}

/// Internal context for variable name extraction (parent context pattern)
const FunctionContext = struct {
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

/// Recursive walker that finds function nodes and computes Halstead metrics
fn walkAndAnalyze(
    allocator: Allocator,
    node: tree_sitter.Node,
    results: *std.ArrayList(HalsteadFunctionResult),
    source: []const u8,
    parent_context: ?FunctionContext,
) !void {
    const node_type = node.nodeType();

    if (cyclomatic.isFunctionNode(node)) {
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

        const metrics = try calculateHalstead(allocator, node, source);

        const start = node.startPoint();
        const end = node.endPoint();

        try results.append(allocator, HalsteadFunctionResult{
            .name = func_name,
            .kind = func_kind,
            .metrics = metrics,
            .start_line = start.row + 1,
            .end_line = end.row + 1,
            .start_col = start.column,
        });

        // Don't recurse into nested functions — they're analyzed separately
        return;
    }

    // Track variable declarations that might contain function expressions
    var child_context: ?FunctionContext = null;

    if (std.mem.eql(u8, node_type, "variable_declarator")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    const id_start = child.startByte();
                    const id_end = child.endByte();
                    if (id_start < source.len and id_end <= source.len) {
                        child_context = FunctionContext{
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
                        child_context = FunctionContext{ .name = "<anonymous>", .class_name = source[id_start..id_end] };
                    }
                    break;
                }
            }
        }
        if (child_context == null) {
            child_context = FunctionContext{ .name = "<anonymous>", .class_name = "class" };
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
                    child_context = FunctionContext{ .name = "<anonymous>", .object_key = key_text };
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
                            child_context = FunctionContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = FunctionContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = FunctionContext{ .name = "<anonymous>", .call_name = callee_name };
                    }
                }
            } else if (std.mem.eql(u8, callee_type, "member_expression")) {
                const last_seg = halGetLastMemberSegment(callee, source);
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
                            child_context = FunctionContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = FunctionContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = FunctionContext{ .name = "<anonymous>", .call_name = seg };
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
                    child_context = FunctionContext{ .name = "<anonymous>", .is_default_export = true };
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
            try walkAndAnalyze(allocator, child, results, source, child_context);
        }
    }
}

/// Extract the last identifier segment from a member_expression node
fn halGetLastMemberSegment(node: tree_sitter.Node, source: []const u8) ?[]const u8 {
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

// TESTS

test "computeHalsteadMetrics: empty function (all zeros)" {
    const m = computeHalsteadMetrics(0, 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0), m.vocabulary);
    try std.testing.expectEqual(@as(u32, 0), m.length);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.volume, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.difficulty, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.effort, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.time, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.bugs, 1e-10);
}

test "computeHalsteadMetrics: zero operands -> difficulty=0, no panic" {
    // n1=3, n2=0, N1=3, N2=0 (only operators, no operands)
    const m = computeHalsteadMetrics(3, 0, 3, 0);
    try std.testing.expectEqual(@as(u32, 3), m.n1);
    try std.testing.expectEqual(@as(u32, 0), m.n2);
    try std.testing.expectEqual(@as(u32, 3), m.vocabulary);
    try std.testing.expectEqual(@as(u32, 3), m.length);
    // volume = 3 * log2(3) ≈ 4.755
    try std.testing.expectApproxEqAbs(@as(f64, 3.0 * std.math.log2(@as(f64, 3.0))), m.volume, 1e-6);
    // difficulty = 0 (n2 == 0)
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.difficulty, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.effort, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.time, 1e-10);
    // bugs = volume / 3000 (non-zero)
    try std.testing.expect(m.bugs > 0.0);
}

test "computeHalsteadMetrics: zero operators -> difficulty=0, no panic" {
    // n1=0, n2=3, N1=0, N2=3 (only operands, no operators)
    const m = computeHalsteadMetrics(0, 3, 0, 3);
    try std.testing.expectEqual(@as(u32, 3), m.vocabulary);
    try std.testing.expectEqual(@as(u32, 3), m.length);
    // difficulty = (0/2) * (N2/n2) = 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.difficulty, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.effort, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.time, 1e-10);
    // volume = 3 * log2(3) ≈ 4.755, bugs = volume/3000
    try std.testing.expect(m.bugs > 0.0);
}

test "computeHalsteadMetrics: simpleAssignment known values" {
    // n1=3, n2=3, N1=3, N2=4
    const m = computeHalsteadMetrics(3, 3, 3, 4);
    try std.testing.expectEqual(@as(u32, 6), m.vocabulary);
    try std.testing.expectEqual(@as(u32, 7), m.length);
    // volume = 7 * log2(6) ≈ 18.09
    const expected_volume = 7.0 * std.math.log2(@as(f64, 6.0));
    try std.testing.expectApproxEqAbs(expected_volume, m.volume, 1e-6);
    // difficulty = (3/2) * (4/3) = 2.0
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), m.difficulty, 1e-6);
    // effort = volume * 2.0
    try std.testing.expectApproxEqAbs(expected_volume * 2.0, m.effort, 1e-6);
    // time = effort / 18
    try std.testing.expectApproxEqAbs(expected_volume * 2.0 / 18.0, m.time, 1e-6);
    // bugs = volume / 3000
    try std.testing.expectApproxEqAbs(expected_volume / 3000.0, m.bugs, 1e-10);
}

test "computeHalsteadMetrics: formula correctness cross-check" {
    // n1=2, n2=2, N1=2, N2=2 (withTypeAnnotations)
    const m = computeHalsteadMetrics(2, 2, 2, 2);
    try std.testing.expectEqual(@as(u32, 4), m.vocabulary);
    try std.testing.expectEqual(@as(u32, 4), m.length);
    // volume = 4 * log2(4) = 8.0
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), m.volume, 1e-6);
    // difficulty = (2/2) * (2/2) = 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), m.difficulty, 1e-6);
    // effort = 8.0 * 1.0 = 8.0
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), m.effort, 1e-6);
    // time = 8.0 / 18 ≈ 0.444
    try std.testing.expectApproxEqAbs(@as(f64, 8.0 / 18.0), m.time, 1e-6);
    // bugs = 8.0 / 3000 ≈ 0.00267
    try std.testing.expectApproxEqAbs(@as(f64, 8.0 / 3000.0), m.bugs, 1e-10);
}

test "isTypeOnlyNode: returns true for all TS type nodes" {
    try std.testing.expect(isTypeOnlyNode("type_annotation"));
    try std.testing.expect(isTypeOnlyNode("type_identifier"));
    try std.testing.expect(isTypeOnlyNode("generic_type"));
    try std.testing.expect(isTypeOnlyNode("type_parameters"));
    try std.testing.expect(isTypeOnlyNode("type_parameter"));
    try std.testing.expect(isTypeOnlyNode("predefined_type"));
    try std.testing.expect(isTypeOnlyNode("union_type"));
    try std.testing.expect(isTypeOnlyNode("intersection_type"));
    try std.testing.expect(isTypeOnlyNode("array_type"));
    try std.testing.expect(isTypeOnlyNode("object_type"));
    try std.testing.expect(isTypeOnlyNode("tuple_type"));
    try std.testing.expect(isTypeOnlyNode("function_type"));
    try std.testing.expect(isTypeOnlyNode("readonly_type"));
    try std.testing.expect(isTypeOnlyNode("type_query"));
    try std.testing.expect(isTypeOnlyNode("as_expression"));
    try std.testing.expect(isTypeOnlyNode("satisfies_expression"));
    try std.testing.expect(isTypeOnlyNode("interface_declaration"));
    try std.testing.expect(isTypeOnlyNode("type_alias_declaration"));
}

test "isTypeOnlyNode: returns false for non-type nodes" {
    try std.testing.expect(!isTypeOnlyNode("identifier"));
    try std.testing.expect(!isTypeOnlyNode("binary_expression"));
    try std.testing.expect(!isTypeOnlyNode("return_statement"));
    try std.testing.expect(!isTypeOnlyNode("number"));
}

test "isOperatorToken: arithmetic operators" {
    try std.testing.expect(isOperatorToken("+"));
    try std.testing.expect(isOperatorToken("-"));
    try std.testing.expect(isOperatorToken("*"));
    try std.testing.expect(isOperatorToken("/"));
    try std.testing.expect(isOperatorToken("%"));
    try std.testing.expect(isOperatorToken("**"));
}

test "isOperatorToken: control flow keywords" {
    try std.testing.expect(isOperatorToken("if"));
    try std.testing.expect(isOperatorToken("else"));
    try std.testing.expect(isOperatorToken("for"));
    try std.testing.expect(isOperatorToken("return"));
    try std.testing.expect(isOperatorToken("new"));
}

test "isOperandToken: identifiers and literals" {
    try std.testing.expect(isOperandToken("identifier"));
    try std.testing.expect(isOperandToken("number"));
    try std.testing.expect(isOperandToken("string"));
    try std.testing.expect(isOperandToken("true"));
    try std.testing.expect(isOperandToken("false"));
    try std.testing.expect(isOperandToken("null"));
    try std.testing.expect(isOperandToken("this"));
    try std.testing.expect(isOperandToken("property_identifier"));
}

test "isOperandToken: returns false for non-operand tokens" {
    try std.testing.expect(!isOperandToken("{"));
    try std.testing.expect(!isOperandToken(";"));
    try std.testing.expect(!isOperandToken("("));
    try std.testing.expect(!isOperandToken("return"));
}

test "calculateHalstead: empty function body produces all zeros" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function empty(): void {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const func_node = root.child(0).?;

    const m = try calculateHalstead(std.testing.allocator, func_node, source);
    try std.testing.expectEqual(@as(u32, 0), m.n1);
    try std.testing.expectEqual(@as(u32, 0), m.n2);
    try std.testing.expectEqual(@as(u32, 0), m.vocabulary);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m.volume, 1e-10);
}

test "calculateHalstead: simpleAssignment base counts" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    // Use JS-equivalent (no type annotations) to test counting
    const source = "function simpleAssignment(x) { const result = x + 1; return result; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const func_node = root.child(0).?;

    const m = try calculateHalstead(std.testing.allocator, func_node, source);
    // Operators: {=, +, return} -> n1=3, N1=3
    try std.testing.expectEqual(@as(u32, 3), m.n1);
    try std.testing.expectEqual(@as(u32, 3), m.n1_total);
    // Operands: {result, x, 1} -> n2=3, N2=4 (result appears twice)
    try std.testing.expectEqual(@as(u32, 3), m.n2);
    try std.testing.expectEqual(@as(u32, 4), m.n2_total);
}

test "calculateHalstead: TypeScript types excluded from counts" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const ts_source = "function f(age: number): boolean { return age > 0; }";
    const js_source = "function f(age) { return age > 0; }";

    const ts_tree = try parser.parseString(ts_source);
    defer ts_tree.deinit();
    const js_tree = try parser.parseString(js_source);
    defer js_tree.deinit();

    const ts_root = ts_tree.rootNode();
    const js_root = js_tree.rootNode();

    const ts_m = try calculateHalstead(std.testing.allocator, ts_root.child(0).?, ts_source);
    const js_m = try calculateHalstead(std.testing.allocator, js_root.child(0).?, js_source);

    // TypeScript version should produce same counts as JavaScript version
    try std.testing.expectEqual(js_m.n1, ts_m.n1);
    try std.testing.expectEqual(js_m.n2, ts_m.n2);
    try std.testing.expectEqual(js_m.n1_total, ts_m.n1_total);
    try std.testing.expectEqual(js_m.n2_total, ts_m.n2_total);
}

test "analyzeFunctions: fixture file produces results" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const fixture_path = "tests/fixtures/typescript/halstead_cases.ts";
    const file = try std.fs.cwd().openFile(fixture_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(std.testing.allocator, 1024 * 1024);
    defer std.testing.allocator.free(source);

    const tree = try parser.parseString(source);
    defer tree.deinit();

    // Use arena allocator: composed names (e.g., "ServiceClass.method") are allocPrint'd
    // into the arena and freed together with arena.deinit()
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const root = tree.rootNode();
    const config = HalsteadConfig.default();
    const results = try analyzeFunctions(alloc, root, config, source);

    // Should find at least the major functions in the fixture
    try std.testing.expect(results.len >= 5);

    // simpleAssignment should have non-zero metrics
    var found_simple = false;
    var found_empty = false;
    for (results) |r| {
        if (std.mem.eql(u8, r.name, "simpleAssignment")) {
            found_simple = true;
            try std.testing.expect(r.metrics.volume > 0.0);
        }
        if (std.mem.eql(u8, r.name, "emptyFunction")) {
            found_empty = true;
            try std.testing.expectApproxEqAbs(@as(f64, 0.0), r.metrics.volume, 1e-10);
        }
    }
    try std.testing.expect(found_simple);
    try std.testing.expect(found_empty);
}

test "HalsteadConfig.default returns expected thresholds" {
    const config = HalsteadConfig.default();
    try std.testing.expectApproxEqAbs(@as(f64, 500.0), config.volume_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), config.volume_error, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), config.difficulty_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), config.difficulty_error, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 5000.0), config.effort_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 10000.0), config.effort_error, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), config.bugs_warning, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), config.bugs_error, 1e-6);
}
