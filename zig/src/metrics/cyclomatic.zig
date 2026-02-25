const std = @import("std");
const tree_sitter = @import("../parser/tree_sitter.zig");
const types = @import("../core/types.zig");
const parse = @import("../parser/parse.zig");
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
    /// Warning threshold (default: 10)
    warning_threshold: u32 = 10,
    /// Error threshold (default: 20)
    error_threshold: u32 = 20,

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

/// Threshold status for a function
pub const ThresholdStatus = enum {
    ok,      // Below warning threshold
    warning, // At or above warning, below error
    @"error", // At or above error threshold
};

/// Threshold validation result
pub const ThresholdResult = struct {
    complexity: u32,
    status: ThresholdStatus,
    function_name: []const u8,
    function_kind: []const u8,
    start_line: u32,
    start_col: u32,
    /// Cognitive complexity score (0 until Phase 6 populates it)
    cognitive_complexity: u32,
    /// Cognitive complexity threshold status (ok until Phase 6 populates it)
    cognitive_status: ThresholdStatus,
    // Halstead (Phase 7)
    halstead_volume: f64 = 0,
    halstead_difficulty: f64 = 0,
    halstead_effort: f64 = 0,
    halstead_bugs: f64 = 0,
    halstead_volume_status: ThresholdStatus = .ok,
    halstead_difficulty_status: ThresholdStatus = .ok,
    halstead_effort_status: ThresholdStatus = .ok,
    halstead_bugs_status: ThresholdStatus = .ok,
    // Structural (Phase 7)
    function_length: u32 = 0,
    params_count: u32 = 0,
    nesting_depth: u32 = 0,
    end_line: u32 = 0,
    function_length_status: ThresholdStatus = .ok,
    params_count_status: ThresholdStatus = .ok,
    nesting_depth_status: ThresholdStatus = .ok,
    // Composite health score (Phase 8)
    health_score: f64 = 0.0,
};

/// Per-function complexity result
pub const FunctionComplexity = struct {
    /// Function name extracted from AST
    name: []const u8,
    /// Function kind (function, method, arrow, generator)
    kind: []const u8,
    /// Computed cyclomatic complexity
    complexity: u32,
    /// Start line (1-indexed)
    start_line: u32,
    /// End line (1-indexed)
    end_line: u32,
    /// Start column (0-indexed)
    start_col: u32,
};

/// Validate complexity against thresholds
pub fn validateThreshold(complexity: u32, warning: u32, err_level: u32) ThresholdStatus {
    if (complexity >= err_level) return .@"error";
    if (complexity >= warning) return .warning;
    return .ok;
}

/// Validate floating-point metric against thresholds
pub fn validateThresholdF64(value: f64, warning: f64, err_level: f64) ThresholdStatus {
    if (value >= err_level) return .@"error";
    if (value >= warning) return .warning;
    return .ok;
}

/// Function information extracted from AST
pub const FunctionInfo = struct {
    name: []const u8,
    kind: []const u8,
};

/// Check if a node represents a function
pub fn isFunctionNode(node: tree_sitter.Node) bool {
    const node_type = node.nodeType();
    return std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "function") or
        std.mem.eql(u8, node_type, "function_expression") or
        std.mem.eql(u8, node_type, "arrow_function") or
        std.mem.eql(u8, node_type, "method_definition") or
        std.mem.eql(u8, node_type, "generator_function") or
        std.mem.eql(u8, node_type, "generator_function_declaration");
}

/// Extract function name and kind from AST node
pub fn extractFunctionInfo(node: tree_sitter.Node, source: []const u8) FunctionInfo {
    const node_type = node.nodeType();

    // Determine kind based on node type
    const kind = if (std.mem.eql(u8, node_type, "function_declaration"))
        "function"
    else if (std.mem.eql(u8, node_type, "generator_function_declaration"))
        "generator"
    else if (std.mem.eql(u8, node_type, "generator_function"))
        "generator"
    else if (std.mem.eql(u8, node_type, "method_definition"))
        "method"
    else if (std.mem.eql(u8, node_type, "arrow_function"))
        "arrow"
    else if (std.mem.eql(u8, node_type, "function") or std.mem.eql(u8, node_type, "function_expression"))
        "function"
    else
        "function";

    // For function/generator declarations and named function expressions, look for identifier child
    if (std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "function_expression") or
        std.mem.eql(u8, node_type, "generator_function_declaration"))
    {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    const start_byte = child.startByte();
                    const end_byte = child.endByte();
                    if (start_byte < source.len and end_byte <= source.len) {
                        return FunctionInfo{
                            .name = source[start_byte..end_byte],
                            .kind = kind,
                        };
                    }
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
                    const start_byte = child.startByte();
                    const end_byte = child.endByte();
                    if (start_byte < source.len and end_byte <= source.len) {
                        return FunctionInfo{
                            .name = source[start_byte..end_byte],
                            .kind = kind,
                        };
                    }
                }
            }
        }
    }

    // For arrow functions and function expressions, return anonymous
    // (name extraction requires parent context which we don't have here)
    return FunctionInfo{
        .name = "<anonymous>",
        .kind = kind,
    };
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
    kind: []const u8,
    /// Class name when walking inside a class_declaration (for "ClassName.method" naming)
    class_name: ?[]const u8 = null,
    /// Object key name when walking inside a pair node (for object literal methods)
    object_key: ?[]const u8 = null,
    /// Call expression callee name when function is an argument (for "callee callback" naming)
    call_name: ?[]const u8 = null,
    /// Whether function is a direct child of export default (for "default export" naming)
    is_default_export: bool = false,
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

/// Analyze a parsed file and return threshold results
pub fn analyzeFile(
    allocator: Allocator,
    parse_result: parse.ParseResult,
    config: CyclomaticConfig,
) ![]ThresholdResult {
    // If parse failed or tree is null, return empty slice
    if (parse_result.tree == null) {
        return &[_]ThresholdResult{};
    }

    const tree = parse_result.tree.?;
    const root = tree.rootNode();

    // Get function complexities
    const function_complexities = try analyzeFunctions(
        allocator,
        root,
        config,
        parse_result.source,
    );
    defer allocator.free(function_complexities);

    // Convert to threshold results
    var results = std.ArrayList(ThresholdResult).empty;
    errdefer results.deinit(allocator);

    for (function_complexities) |fc| {
        const status = validateThreshold(
            fc.complexity,
            config.warning_threshold,
            config.error_threshold,
        );

        try results.append(allocator, ThresholdResult{
            .complexity = fc.complexity,
            .status = status,
            .function_name = fc.name,
            .function_kind = fc.kind,
            .start_line = fc.start_line,
            .start_col = fc.start_col,
            .cognitive_complexity = 0,
            .cognitive_status = .ok,
        });
    }

    return try results.toOwnedSlice(allocator);
}

/// Convert FunctionComplexity results to FunctionResult structs
pub fn toFunctionResults(
    allocator: Allocator,
    function_complexities: []const FunctionComplexity,
) ![]types.FunctionResult {
    var results = std.ArrayList(types.FunctionResult).empty;
    errdefer results.deinit(allocator);

    for (function_complexities) |fc| {
        try results.append(allocator, types.FunctionResult{
            .name = fc.name,
            .start_line = fc.start_line,
            .end_line = fc.end_line,
            .start_col = fc.start_col,
            .params_count = 0, // Not populated yet (future phase)
            .line_count = 0, // Not populated yet (future phase)
            .nesting_depth = 0, // Not populated yet (future phase)
            .cyclomatic = fc.complexity,
            .cognitive = null,
            .halstead_volume = null,
            .halstead_difficulty = null,
            .halstead_effort = null,
            .health_score = null,
        });
    }

    return try results.toOwnedSlice(allocator);
}

/// Recursive walker that finds functions and analyzes them
fn walkAndAnalyze(
    allocator: Allocator,
    node: tree_sitter.Node,
    results: *std.ArrayList(FunctionComplexity),
    config: CyclomaticConfig,
    source: []const u8,
    parent_context: ?FunctionContext,
) !void {
    const node_type = node.nodeType();

    // Check if this is a function node
    if (isFunctionNode(node)) {
        // Extract function name and kind
        const func_info = extractFunctionInfo(node, source);
        var func_name = func_info.name;
        const func_kind = func_info.kind;

        // Apply naming priority from parent context
        if (parent_context) |ctx| {
            if (ctx.name.len > 0 and !std.mem.eql(u8, ctx.name, "<anonymous>")) {
                // Priority 1: explicit variable name from variable_declarator
                // (ctx.name is set directly for variable_declarator nodes)
                if (ctx.class_name == null and ctx.object_key == null and ctx.call_name == null and !ctx.is_default_export) {
                    func_name = ctx.name;
                }
            }

            // Priority 2: class method — compose "ClassName.methodName"
            if (ctx.class_name) |class_name| {
                if (std.mem.eql(u8, func_kind, "method")) {
                    // func_info.name already has the method name from extractFunctionInfo
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

            // Priority 4: callback naming — "callee callback" or "event handler"
            if (ctx.call_name) |call_name| {
                if (std.mem.eql(u8, func_info.name, "<anonymous>") or std.mem.eql(u8, func_kind, "arrow")) {
                    // check if ctx.name encodes a handler format (from addEventListener)
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

        // Calculate complexity
        const complexity = calculateComplexity(node, config, source);

        // Get position info (1-indexed for lines, 0-indexed for columns)
        const start = node.startPoint();
        const end = node.endPoint();

        // Add result
        try results.append(allocator, FunctionComplexity{
            .name = func_name,
            .kind = func_kind,
            .complexity = complexity,
            .start_line = start.row + 1,
            .end_line = end.row + 1,
            .start_col = start.column,
        });

        // Don't recurse into nested functions - they'll be analyzed separately
        return;
    }

    // Track variable declarations that might contain function expressions
    var child_context: ?FunctionContext = null;

    if (std.mem.eql(u8, node_type, "variable_declarator")) {
        // Look for identifier child to use as function name
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier")) {
                    // Extract identifier text from source using byte offsets
                    const id_start_byte = child.startByte();
                    const id_end_byte = child.endByte();
                    if (id_start_byte < source.len and id_end_byte <= source.len) {
                        child_context = FunctionContext{
                            .name = source[id_start_byte..id_end_byte],
                            .kind = "variable", // Placeholder, will be overridden by actual function kind
                        };
                    }
                    break;
                }
            }
        }
    }
    // Track class declarations for "ClassName.method" naming
    else if (std.mem.eql(u8, node_type, "class_declaration") or std.mem.eql(u8, node_type, "class")) {
        // Find identifier child = class name
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.nodeType();
                if (std.mem.eql(u8, child_type, "identifier") or std.mem.eql(u8, child_type, "type_identifier")) {
                    const id_start = child.startByte();
                    const id_end = child.endByte();
                    if (id_start < source.len and id_end <= source.len) {
                        child_context = FunctionContext{
                            .name = "<anonymous>",
                            .kind = "class",
                            .class_name = source[id_start..id_end],
                        };
                    }
                    break;
                }
            }
        }
        if (child_context == null) {
            child_context = FunctionContext{ .name = "<anonymous>", .kind = "class", .class_name = "class" };
        }
    }
    // Track object literal pair key for method naming: { handler: () => {} }
    else if (std.mem.eql(u8, node_type, "pair")) {
        // First child is the key (property_identifier or string)
        if (node.child(0)) |key_node| {
            const key_type = key_node.nodeType();
            if (std.mem.eql(u8, key_type, "property_identifier") or std.mem.eql(u8, key_type, "string")) {
                const key_start = key_node.startByte();
                const key_end = key_node.endByte();
                if (key_start < source.len and key_end <= source.len) {
                    var key_text = source[key_start..key_end];
                    // Strip quotes from string keys
                    if (std.mem.startsWith(u8, key_text, "\"") or std.mem.startsWith(u8, key_text, "'")) {
                        key_text = key_text[1 .. key_text.len - 1];
                    }
                    child_context = FunctionContext{
                        .name = "<anonymous>",
                        .kind = "pair",
                        .object_key = key_text,
                    };
                }
            }
        }
    }
    // Track call expression callee for "X callback" or "event handler" naming
    else if (std.mem.eql(u8, node_type, "call_expression")) {
        // First child is the callee
        if (node.child(0)) |callee| {
            const callee_type = callee.nodeType();
            if (std.mem.eql(u8, callee_type, "identifier")) {
                // Simple identifier callee: map, forEach, etc.
                const id_start = callee.startByte();
                const id_end = callee.endByte();
                if (id_start < source.len and id_end <= source.len) {
                    const callee_name = source[id_start..id_end];
                    if (std.mem.eql(u8, callee_name, "addEventListener")) {
                        // Special case: read first argument string for "event handler"
                        var event_name: ?[]const u8 = null;
                        if (node.child(1)) |args_node| {
                            if (std.mem.eql(u8, args_node.nodeType(), "arguments")) {
                                var j: u32 = 0;
                                while (j < args_node.childCount()) : (j += 1) {
                                    if (args_node.child(j)) |arg| {
                                        const arg_type = arg.nodeType();
                                        if (std.mem.eql(u8, arg_type, "string")) {
                                            const s_start = arg.startByte();
                                            const s_end = arg.endByte();
                                            if (s_start < source.len and s_end <= source.len) {
                                                var str_text = source[s_start..s_end];
                                                // Strip quotes
                                                if (str_text.len >= 2) {
                                                    str_text = str_text[1 .. str_text.len - 1];
                                                }
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
                            child_context = FunctionContext{
                                .name = "<anonymous>",
                                .kind = "call",
                                .call_name = handler_name,
                            };
                        } else {
                            child_context = FunctionContext{
                                .name = "<anonymous>",
                                .kind = "call",
                                .call_name = "addEventListener handler",
                            };
                        }
                    } else {
                        child_context = FunctionContext{
                            .name = "<anonymous>",
                            .kind = "call",
                            .call_name = callee_name,
                        };
                    }
                }
            } else if (std.mem.eql(u8, callee_type, "member_expression")) {
                // Member expression: arr.map, obj.forEach — extract last segment
                const last_seg = getLastMemberSegment(callee, source);
                if (last_seg) |seg| {
                    if (std.mem.eql(u8, seg, "addEventListener")) {
                        // Special case: extract event name from first string argument
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
                            child_context = FunctionContext{ .name = "<anonymous>", .kind = "call", .call_name = handler_name };
                        } else {
                            child_context = FunctionContext{ .name = "<anonymous>", .kind = "call", .call_name = "addEventListener handler" };
                        }
                    } else {
                        child_context = FunctionContext{
                            .name = "<anonymous>",
                            .kind = "call",
                            .call_name = seg,
                        };
                    }
                }
            }
        }
    }
    // Track export default for "default export" naming
    else if (std.mem.eql(u8, node_type, "export_statement")) {
        // Check if this is a default export
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.nodeType(), "default")) {
                    child_context = FunctionContext{
                        .name = "<anonymous>",
                        .kind = "export",
                        .is_default_export = true,
                    };
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

/// Extract the last identifier segment from a member_expression node (e.g., arr.map → "map")
fn getLastMemberSegment(node: tree_sitter.Node, source: []const u8) ?[]const u8 {
    // member_expression typically: object "." property_identifier
    // Walk children to find the last property_identifier
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

test "CyclomaticConfig.default returns expected values" {
    const config = CyclomaticConfig.default();
    try std.testing.expect(config.count_logical_operators);
    try std.testing.expect(config.count_nullish_coalescing);
    try std.testing.expect(config.count_optional_chaining);
    try std.testing.expect(config.count_ternary);
    try std.testing.expect(config.count_default_params);
    try std.testing.expectEqual(CyclomaticConfig.SwitchCaseMode.classic, config.switch_case_mode);
    try std.testing.expectEqual(@as(u32, 10), config.warning_threshold);
    try std.testing.expectEqual(@as(u32, 20), config.error_threshold);
}

test "validateThreshold: complexity below warning" {
    const status = validateThreshold(5, 10, 20);
    try std.testing.expectEqual(ThresholdStatus.ok, status);
}

test "validateThreshold: complexity at warning" {
    const status = validateThreshold(10, 10, 20);
    try std.testing.expectEqual(ThresholdStatus.warning, status);
}

test "validateThreshold: complexity between warning and error" {
    const status = validateThreshold(15, 10, 20);
    try std.testing.expectEqual(ThresholdStatus.warning, status);
}

test "validateThreshold: complexity at error" {
    const status = validateThreshold(20, 10, 20);
    try std.testing.expectEqual(ThresholdStatus.@"error", status);
}

test "validateThreshold: complexity above error" {
    const status = validateThreshold(25, 10, 20);
    try std.testing.expectEqual(ThresholdStatus.@"error", status);
}

test "validateThreshold: custom thresholds warning" {
    const status = validateThreshold(5, 5, 15);
    try std.testing.expectEqual(ThresholdStatus.warning, status);
}

test "validateThreshold: custom thresholds error" {
    const status = validateThreshold(15, 5, 15);
    try std.testing.expectEqual(ThresholdStatus.@"error", status);
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
    // Verify actual names are extracted
    try std.testing.expectEqualStrings("foo", results[0].name);
    try std.testing.expectEqualStrings("bar", results[1].name);
    try std.testing.expectEqualStrings("function", results[0].kind);
    try std.testing.expectEqualStrings("function", results[1].kind);
}

test "analyzeFile: simple parsed file" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    const source = "function foo() { return 1; }";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const parse_result = parse.ParseResult{
        .path = "test.ts",
        .tree = tree,
        .language = .typescript,
        .has_errors = false,
        .source = source,
    };

    const config = CyclomaticConfig.default();
    const results = try analyzeFile(std.testing.allocator, parse_result, config);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 1), results.len);
    try std.testing.expectEqual(@as(u32, 1), results[0].complexity);
    try std.testing.expectEqual(ThresholdStatus.ok, results[0].status);
    try std.testing.expectEqual(@as(u32, 1), results[0].start_line);
}

test "analyzeFile: null tree returns empty slice" {
    const parse_result = parse.ParseResult{
        .path = "test.ts",
        .tree = null,
        .language = .typescript,
        .has_errors = true,
        .source = "",
    };

    const config = CyclomaticConfig.default();
    const results = try analyzeFile(std.testing.allocator, parse_result, config);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 0), results.len);
}

test "toFunctionResults: populates cyclomatic field" {
    const function_complexities = [_]FunctionComplexity{
        .{
            .name = "foo",
            .kind = "function",
            .complexity = 5,
            .start_line = 1,
            .end_line = 10,
            .start_col = 0,
        },
        .{
            .name = "bar",
            .kind = "function",
            .complexity = 12,
            .start_line = 15,
            .end_line = 25,
            .start_col = 4,
        },
    };

    const results = try toFunctionResults(std.testing.allocator, &function_complexities);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);

    // First function
    try std.testing.expectEqualStrings("foo", results[0].name);
    try std.testing.expectEqual(@as(u32, 1), results[0].start_line);
    try std.testing.expectEqual(@as(u32, 10), results[0].end_line);
    try std.testing.expectEqual(@as(u32, 0), results[0].start_col);
    try std.testing.expectEqual(@as(?u32, 5), results[0].cyclomatic);
    try std.testing.expectEqual(@as(?u32, null), results[0].cognitive);
    try std.testing.expectEqual(@as(u32, 0), results[0].params_count);
    try std.testing.expectEqual(@as(u32, 0), results[0].line_count);
    try std.testing.expectEqual(@as(u32, 0), results[0].nesting_depth);

    // Second function
    try std.testing.expectEqualStrings("bar", results[1].name);
    try std.testing.expectEqual(@as(?u32, 12), results[1].cyclomatic);
}

test "integration: cyclomatic_cases.ts fixture" {
    const parser = try tree_sitter.Parser.init();
    defer parser.deinit();
    try parser.setLanguage(.typescript);

    // Read the fixture file
    const fixture_path = "tests/fixtures/typescript/cyclomatic_cases.ts";
    const file = try std.fs.cwd().openFile(fixture_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(std.testing.allocator, 1024 * 1024);
    defer std.testing.allocator.free(source);

    // Parse the fixture
    const tree = try parser.parseString(source);
    defer tree.deinit();

    // Use arena allocator: composed names (e.g., "DataProcessor.process") are allocPrint'd
    // into the arena and freed together with arena.deinit()
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const root = tree.rootNode();
    const config = CyclomaticConfig.default();
    const results = try analyzeFunctions(alloc, root, config, source);

    // Expected complexities based on fixture comments
    // Note: The fixture contains functions with the following expected complexities:
    // baseline: 1, simpleConditionals: 3, loopWithConditions: 5,
    // switchStatement: 5, errorHandling: 3, ternaryAndLogical: 3,
    // nullishCoalescing: 3, nestedFunctions outer: 2,
    // arrowFunc: 2, complexLogical: 5, DataProcessor.process: 2
    // Class methods are now named "ClassName.methodName" (e.g., "DataProcessor.process")

    // We should find at least 11 functions (not counting the class itself)
    try std.testing.expect(results.len >= 11);

    // Verify some specific functions by checking their complexity values
    var found_complexity_1 = false;
    var found_complexity_2 = false;
    var found_complexity_3 = false;
    var found_complexity_5 = false;
    var found_baseline = false;
    var found_arrow = false;
    var found_method = false;

    for (results) |result| {
        if (result.complexity == 1) found_complexity_1 = true;
        if (result.complexity == 2) found_complexity_2 = true;
        if (result.complexity == 3) found_complexity_3 = true;
        if (result.complexity == 5) found_complexity_5 = true;

        // Verify actual names are extracted
        if (std.mem.eql(u8, result.name, "baseline")) {
            found_baseline = true;
            try std.testing.expectEqualStrings("function", result.kind);
        }
        if (std.mem.eql(u8, result.name, "arrowFunc")) {
            found_arrow = true;
            try std.testing.expectEqualStrings("arrow", result.kind);
        }
        if (std.mem.eql(u8, result.name, "DataProcessor.process")) {
            found_method = true;
            try std.testing.expectEqualStrings("method", result.kind);
        }

        // Verify no placeholder names exist
        try std.testing.expect(!std.mem.eql(u8, result.name, "<function>"));
        try std.testing.expect(!std.mem.eql(u8, result.name, "<method>"));
        try std.testing.expect(!std.mem.eql(u8, result.name, "<variable>"));

        // Verify line numbers are 1-indexed
        try std.testing.expect(result.start_line > 0);
        try std.testing.expect(result.end_line >= result.start_line);
    }

    // Verify we found functions with different complexity levels
    try std.testing.expect(found_complexity_1);
    try std.testing.expect(found_complexity_2);
    try std.testing.expect(found_complexity_3);
    try std.testing.expect(found_complexity_5);
    // Verify specific named functions were found
    try std.testing.expect(found_baseline);
    try std.testing.expect(found_arrow);
    try std.testing.expect(found_method);
}


