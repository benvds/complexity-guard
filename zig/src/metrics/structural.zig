const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const cyclomatic = @import("cyclomatic.zig");
const Allocator = std.mem.Allocator;

/// Configuration for structural metrics with warning/error threshold pairs.
/// Thresholds based on locked user decisions and research recommendations.
pub const StructuralConfig = struct {
    /// Function length in logical lines: warning=25, error=50
    function_length_warning: u32 = 25,
    function_length_error: u32 = 50,
    /// Parameter count (runtime + generic): warning=3, error=6
    params_count_warning: u32 = 3,
    params_count_error: u32 = 6,
    /// Maximum nesting depth: warning=3, error=5
    nesting_depth_warning: u32 = 3,
    nesting_depth_error: u32 = 5,
    /// File length in logical lines: warning=300, error=600
    file_length_warning: u32 = 300,
    file_length_error: u32 = 600,
    /// Export count: warning=15, error=30
    export_count_warning: u32 = 15,
    export_count_error: u32 = 30,

    /// Returns default configuration
    pub fn default() StructuralConfig {
        return StructuralConfig{};
    }
};

/// Per-function structural metric result
pub const StructuralFunctionResult = struct {
    /// Function name extracted from AST
    name: []const u8,
    /// Function kind (function, method, arrow, generator)
    kind: []const u8,
    /// Start line (1-indexed)
    start_line: u32,
    /// End line (1-indexed)
    end_line: u32,
    /// Start column (0-indexed)
    start_col: u32,
    /// Number of logical lines in the function body
    function_length: u32,
    /// Number of parameters (runtime + generic type params)
    params_count: u32,
    /// Maximum nesting depth within the function
    nesting_depth: u32,
};

/// Per-file structural metric result
pub const FileStructuralResult = struct {
    /// File length in logical lines
    file_length: u32,
    /// Number of export_statement nodes at root level
    export_count: u32,
};

/// Count logical lines in a byte range of source text.
/// Skips blank lines, single-line comments (//) and block comment interiors (/* ... */).
/// Lines with code after a closing */ are counted.
pub fn countLogicalLines(source: []const u8, start_byte: u32, end_byte: u32) u32 {
    const bounded_end = @min(end_byte, @as(u32, @intCast(source.len)));
    if (start_byte >= bounded_end) return 0;

    const text = source[start_byte..bounded_end];
    var count: u32 = 0;
    var in_block_comment = false;

    var line_iter = std.mem.splitScalar(u8, text, '\n');
    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");

        if (in_block_comment) {
            // Check if this line closes the block comment
            if (std.mem.indexOf(u8, line, "*/")) |close_idx| {
                in_block_comment = false;
                // Check if there is code after the closing */
                const after_close = std.mem.trim(u8, line[close_idx + 2 ..], " \t\r");
                if (after_close.len > 0) {
                    count += 1;
                }
            }
            // Still inside block comment, skip the line
            continue;
        }

        // Skip blank lines
        if (line.len == 0) continue;

        // Skip standalone brace-only lines (block delimiters, not logical code)
        if (std.mem.eql(u8, line, "{") or std.mem.eql(u8, line, "}") or
            std.mem.eql(u8, line, "};") or std.mem.eql(u8, line, "},"))
        {
            continue;
        }

        // Skip single-line comments
        if (std.mem.startsWith(u8, line, "//")) continue;

        // Handle block comment start
        if (std.mem.startsWith(u8, line, "/*")) {
            // Check if block comment closes on the same line
            if (std.mem.indexOf(u8, line[2..], "*/")) |close_idx| {
                // Inline block comment - check if there's code after it
                const after_close = std.mem.trim(u8, line[2 + close_idx + 2 ..], " \t\r");
                if (after_close.len > 0) {
                    count += 1;
                }
                // Note: we don't set in_block_comment since it closed on same line
            } else {
                // Multi-line block comment starts here, skip to close
                in_block_comment = true;
            }
            continue;
        }

        // Skip lines that are part of block comment body (e.g., " * text")
        if (std.mem.startsWith(u8, line, "*") and in_block_comment) {
            continue;
        }

        // Count this line as logical code
        count += 1;
    }

    return count;
}

/// Count parameters for a function node.
/// Counts non-punctuation children of formal_parameters PLUS type_parameters.
pub fn countParameters(function_node: tree_sitter.Node) u32 {
    var count: u32 = 0;
    const punctuation = [_][]const u8{ ",", "(", ")", "<", ">", ";" };

    var i: u32 = 0;
    while (i < function_node.childCount()) : (i += 1) {
        if (function_node.child(i)) |child| {
            const child_type = child.nodeType();

            if (std.mem.eql(u8, child_type, "formal_parameters")) {
                // Count non-punctuation direct children
                var j: u32 = 0;
                while (j < child.childCount()) : (j += 1) {
                    if (child.child(j)) |param| {
                        const param_type = param.nodeType();
                        var is_punct = false;
                        for (punctuation) |punct| {
                            if (std.mem.eql(u8, param_type, punct)) {
                                is_punct = true;
                                break;
                            }
                        }
                        if (!is_punct) count += 1;
                    }
                }
            } else if (std.mem.eql(u8, child_type, "type_parameters")) {
                // Count non-punctuation direct children (type params: T, U, V)
                var j: u32 = 0;
                while (j < child.childCount()) : (j += 1) {
                    if (child.child(j)) |param| {
                        const param_type = param.nodeType();
                        var is_punct = false;
                        for (punctuation) |punct| {
                            if (std.mem.eql(u8, param_type, punct)) {
                                is_punct = true;
                                break;
                            }
                        }
                        if (!is_punct) count += 1;
                    }
                }
            }
        }
    }

    return count;
}

/// Nesting context for recursive depth tracking
const NestingContext = struct {
    current_depth: u32,
    max_depth: u32,
};

/// Nesting constructs that increment depth
fn isNestingConstruct(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "if_statement") or
        std.mem.eql(u8, node_type, "for_statement") or
        std.mem.eql(u8, node_type, "for_in_statement") or
        std.mem.eql(u8, node_type, "while_statement") or
        std.mem.eql(u8, node_type, "do_statement") or
        std.mem.eql(u8, node_type, "switch_statement") or
        std.mem.eql(u8, node_type, "catch_clause") or
        std.mem.eql(u8, node_type, "ternary_expression");
}

/// Recursive walker for nesting depth calculation.
/// Stops at nested function boundaries for scope isolation.
fn walkNesting(ctx: *NestingContext, node: tree_sitter.Node) void {
    const node_type = node.nodeType();

    // Stop at nested function boundaries (scope isolation)
    if (cyclomatic.isFunctionNode(node)) return;

    if (isNestingConstruct(node_type)) {
        ctx.current_depth += 1;
        if (ctx.current_depth > ctx.max_depth) {
            ctx.max_depth = ctx.current_depth;
        }

        // Recurse into children at increased depth
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                walkNesting(ctx, child);
            }
        }

        ctx.current_depth -= 1;
    } else {
        // Recurse into children at same depth
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                walkNesting(ctx, child);
            }
        }
    }
}

/// Compute the maximum nesting depth within a function body node.
/// Respects function scope isolation (nested functions don't inflate outer depth).
pub fn maxNestingDepth(function_body_node: tree_sitter.Node) u32 {
    var ctx = NestingContext{
        .current_depth = 0,
        .max_depth = 0,
    };

    var i: u32 = 0;
    while (i < function_body_node.childCount()) : (i += 1) {
        if (function_body_node.child(i)) |child| {
            walkNesting(&ctx, child);
        }
    }

    return ctx.max_depth;
}

/// Count export_statement nodes at program root level.
pub fn countExports(root: tree_sitter.Node) u32 {
    var count: u32 = 0;
    var i: u32 = 0;
    while (i < root.childCount()) : (i += 1) {
        if (root.child(i)) |child| {
            if (std.mem.eql(u8, child.nodeType(), "export_statement")) {
                count += 1;
            }
        }
    }
    return count;
}

/// Analyze all functions in a parsed AST and return structural metrics per function.
pub fn analyzeFunctions(
    allocator: Allocator,
    root: tree_sitter.Node,
    source: []const u8,
) ![]StructuralFunctionResult {
    var results = std.ArrayList(StructuralFunctionResult).empty;
    errdefer results.deinit(allocator);

    try walkAndAnalyze(allocator, root, &results, source, null);

    return try results.toOwnedSlice(allocator);
}

/// Compute structural metrics for a single file.
pub fn analyzeFile(source: []const u8, root: tree_sitter.Node) FileStructuralResult {
    const file_length = countLogicalLines(source, 0, @intCast(source.len));
    const export_count = countExports(root);
    return FileStructuralResult{
        .file_length = file_length,
        .export_count = export_count,
    };
}

/// Context for variable name extraction (mirrors cyclomatic.zig pattern)
const FunctionNameContext = struct {
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

/// Recursive walker that discovers functions and computes structural metrics
fn walkAndAnalyze(
    allocator: Allocator,
    node: tree_sitter.Node,
    results: *std.ArrayList(StructuralFunctionResult),
    source: []const u8,
    parent_context: ?FunctionNameContext,
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

        const start = node.startPoint();
        const end = node.endPoint();

        // Compute function_length
        // For arrow functions with expression body (not statement_block), count as 1
        var function_length: u32 = 1;
        var nesting_depth: u32 = 0;

        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "statement_block")) {
                    // Block body: count logical lines and nesting depth
                    function_length = countLogicalLines(source, child.startByte(), child.endByte());
                    nesting_depth = maxNestingDepth(child);
                    break;
                }
            }
        }
        // If no statement_block found (expression body arrow function), stays at 1

        // Compute params_count
        const params_count = countParameters(node);

        try results.append(allocator, StructuralFunctionResult{
            .name = func_name,
            .kind = func_kind,
            .start_line = start.row + 1,
            .end_line = end.row + 1,
            .start_col = start.column,
            .function_length = function_length,
            .params_count = params_count,
            .nesting_depth = nesting_depth,
        });

        // Don't recurse into nested functions - they'll be analyzed separately
        return;
    }

    // Track variable declarations that might contain function expressions
    var child_context: ?FunctionNameContext = null;

    if (std.mem.eql(u8, node_type, "variable_declarator")) {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    const id_start = child.startByte();
                    const id_end = child.endByte();
                    if (id_start < source.len and id_end <= source.len) {
                        child_context = FunctionNameContext{
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
                        child_context = FunctionNameContext{ .name = "<anonymous>", .class_name = source[id_start..id_end] };
                    }
                    break;
                }
            }
        }
        if (child_context == null) {
            child_context = FunctionNameContext{ .name = "<anonymous>", .class_name = "class" };
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
                    child_context = FunctionNameContext{ .name = "<anonymous>", .object_key = key_text };
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
                            child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = callee_name };
                    }
                }
            } else if (std.mem.eql(u8, callee_type, "member_expression")) {
                const last_seg = strGetLastMemberSegment(callee, source);
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
                            child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = handler_name };
                        } else {
                            child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = FunctionNameContext{ .name = "<anonymous>", .call_name = seg };
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
                    child_context = FunctionNameContext{ .name = "<anonymous>", .is_default_export = true };
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
fn strGetLastMemberSegment(node: tree_sitter.Node, source: []const u8) ?[]const u8 {
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

test "countLogicalLines: code-only lines" {
    // 3 code statements; standalone { and } are excluded as structural delimiters
    const source = "{\n  const a = 1;\n  const b = 2;\n  return a + b;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 3), count);
}

test "countLogicalLines: skips blank lines" {
    const source = "{\n  const a = 1;\n\n  const b = 2;\n\n  return a + b;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 3), count);
}

test "countLogicalLines: skips single-line comments" {
    const source = "{\n  // This is a comment\n  const a = 1;\n  // Another comment\n  return a;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "countLogicalLines: skips multi-line block comments" {
    const source = "{\n  /*\n   * Block comment line 1\n   * Block comment line 2\n   */\n  const a = 1;\n  return a;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "countLogicalLines: counts line with code after inline block comment" {
    const source = "{\n  /* note */ const a = 1;\n  return a;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "countLogicalLines: skips inline block comment with no code after" {
    const source = "{\n  /* standalone comment */\n  const a = 1;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 1), count);
}

test "countLogicalLines: mixed content" {
    // 3 code statements, 1 blank, 1 single-line comment, 3-line block comment, { and } excluded
    const source = "{\n  // comment\n  const a = 1;\n\n  /* block\n   * continued\n   */\n  const b = 2;\n  return a + b;\n}";
    const count = countLogicalLines(source, 0, @intCast(source.len));
    try std.testing.expectEqual(@as(u32, 3), count);
}

test "countLogicalLines: empty range returns 0" {
    const source = "some source";
    const count = countLogicalLines(source, 5, 5);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "countParameters: runtime-only params" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(a: number, b: string, c: boolean) {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const count = countParameters(func_node);
        try std.testing.expectEqual(@as(u32, 3), count);
    }
}

test "countParameters: runtime + generic params" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f<T, U>(a: T, b: U) {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const count = countParameters(func_node);
        try std.testing.expectEqual(@as(u32, 4), count);
    }
}

test "countParameters: destructured param counts as 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f({a, b}: {a: number, b: string}) {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const count = countParameters(func_node);
        try std.testing.expectEqual(@as(u32, 1), count);
    }
}

test "countParameters: rest param counts as 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(...args: any[]) {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const count = countParameters(func_node);
        try std.testing.expectEqual(@as(u32, 1), count);
    }
}

test "countParameters: no params" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f() {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        const count = countParameters(func_node);
        try std.testing.expectEqual(@as(u32, 0), count);
    }
}

test "maxNestingDepth: flat function returns 0" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x: number): number { const y = x + 1; return y; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        // Find the statement_block body
        var body: ?tree_sitter.Node = null;
        var i: u32 = 0;
        while (i < func_node.childCount()) : (i += 1) {
            if (func_node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "statement_block")) {
                    body = child;
                    break;
                }
            }
        }
        if (body) |b| {
            const depth = maxNestingDepth(b);
            try std.testing.expectEqual(@as(u32, 0), depth);
        }
    }
}

test "maxNestingDepth: single if returns 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function f(x: number): void { if (x > 0) { return; } }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        var body: ?tree_sitter.Node = null;
        var i: u32 = 0;
        while (i < func_node.childCount()) : (i += 1) {
            if (func_node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "statement_block")) {
                    body = child;
                    break;
                }
            }
        }
        if (body) |b| {
            const depth = maxNestingDepth(b);
            try std.testing.expectEqual(@as(u32, 1), depth);
        }
    }
}

test "maxNestingDepth: nested if/for returns 2" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function f(items: number[]): void {
        \\  if (items.length > 0) {
        \\    for (let i = 0; i < items.length; i++) {
        \\      console.log(items[i]);
        \\    }
        \\  }
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        var body: ?tree_sitter.Node = null;
        var i: u32 = 0;
        while (i < func_node.childCount()) : (i += 1) {
            if (func_node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "statement_block")) {
                    body = child;
                    break;
                }
            }
        }
        if (body) |b| {
            const depth = maxNestingDepth(b);
            try std.testing.expectEqual(@as(u32, 2), depth);
        }
    }
}

test "maxNestingDepth: stops at nested function boundary" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function outer(x: number): number {
        \\  if (x > 0) {
        \\    function inner(y: number): number {
        \\      if (y > 100) {
        \\        if (y > 1000) {
        \\          return y;
        \\        }
        \\      }
        \\      return y;
        \\    }
        \\    return inner(x);
        \\  }
        \\  return 0;
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    if (root.child(0)) |func_node| {
        var body: ?tree_sitter.Node = null;
        var i: u32 = 0;
        while (i < func_node.childCount()) : (i += 1) {
            if (func_node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "statement_block")) {
                    body = child;
                    break;
                }
            }
        }
        if (body) |b| {
            // Outer function only has 1 if (the inner function_declaration's ifs don't count)
            const depth = maxNestingDepth(b);
            try std.testing.expectEqual(@as(u32, 1), depth);
        }
    }
}

test "countExports: 3 export statements" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\export { foo };
        \\export { bar, baz };
        \\export default qux;
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const count = countExports(root);
    try std.testing.expectEqual(@as(u32, 3), count);
}

test "countExports: export star" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "export * from './module';";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const count = countExports(root);
    try std.testing.expectEqual(@as(u32, 1), count);
}

test "countExports: no exports" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "const x = 1; function foo() {}";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const count = countExports(root);
    try std.testing.expectEqual(@as(u32, 0), count);
}

test "analyzeFunctions: single-expression arrow function length = 1" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "const double = (x: number) => x * 2;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const results = try analyzeFunctions(std.testing.allocator, root, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqual(@as(u32, 1), results[0].function_length);
    try std.testing.expectEqualStrings("double", results[0].name);
}

test "analyzeFunctions: function with block body counts logical lines" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\function short(x: number): number {
        \\  const a = x + 1;
        \\  const b = a * 2;
        \\  return b;
        \\}
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const results = try analyzeFunctions(std.testing.allocator, root, source);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    // 3 logical lines: 3 code statements (braces excluded as structural delimiters)
    try std.testing.expectEqual(@as(u32, 3), results[0].function_length);
    try std.testing.expectEqualStrings("short", results[0].name);
}

test "analyzeFile: counts file length and exports" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source =
        \\export function foo(): void {}
        \\export function bar(): void {}
        \\const x = 1;
    ;
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const result = analyzeFile(source, root);

    try std.testing.expectEqual(@as(u32, 2), result.export_count);
    try std.testing.expect(result.file_length >= 3);
}

test "integration: structural_cases.ts fixture" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    // Read the fixture file
    const fixture_path = "tests/fixtures/typescript/structural_cases.ts";
    const file = try std.fs.cwd().openFile(fixture_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(std.testing.allocator, 1024 * 1024);
    defer std.testing.allocator.free(source);

    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();

    // Test file-level metrics
    const file_result = analyzeFile(source, root);
    // Fixture has 4 export statements
    try std.testing.expectEqual(@as(u32, 4), file_result.export_count);
    // File has many logical lines
    try std.testing.expect(file_result.file_length > 20);

    // Test per-function metrics
    const results = try analyzeFunctions(std.testing.allocator, root, source);
    defer std.testing.allocator.free(results);

    // Should find at least 7 named functions
    try std.testing.expect(results.len >= 7);

    // Look for specific functions and verify their metrics
    var found_single_expr = false;
    var found_flat = false;
    var found_many_params = false;
    var found_no_params = false;

    for (results) |r| {
        if (std.mem.eql(u8, r.name, "singleExpressionArrow")) {
            found_single_expr = true;
            // Single-expression arrow: function_length = 1
            try std.testing.expectEqual(@as(u32, 1), r.function_length);
        }
        if (std.mem.eql(u8, r.name, "flatFunction")) {
            found_flat = true;
            // Flat function: nesting_depth = 0
            try std.testing.expectEqual(@as(u32, 0), r.nesting_depth);
        }
        if (std.mem.eql(u8, r.name, "manyParams")) {
            found_many_params = true;
            // 3 generic + 4 runtime = 7 params
            try std.testing.expectEqual(@as(u32, 7), r.params_count);
        }
        if (std.mem.eql(u8, r.name, "noParams")) {
            found_no_params = true;
            try std.testing.expectEqual(@as(u32, 0), r.params_count);
        }
    }

    try std.testing.expect(found_single_expr);
    try std.testing.expect(found_flat);
    try std.testing.expect(found_many_params);
    try std.testing.expect(found_no_params);
}
