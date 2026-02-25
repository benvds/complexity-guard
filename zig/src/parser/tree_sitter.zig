const std = @import("std");

// Import tree-sitter C API
const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

// External language functions provided by compiled parser.c files
extern fn tree_sitter_typescript() *const c.TSLanguage;
extern fn tree_sitter_tsx() *const c.TSLanguage;
extern fn tree_sitter_javascript() *const c.TSLanguage;

/// Supported programming languages
pub const Language = enum {
    typescript,
    tsx,
    javascript,

    /// Get the C language struct for this language
    pub fn toTSLanguage(self: Language) *const c.TSLanguage {
        return switch (self) {
            .typescript => tree_sitter_typescript(),
            .tsx => tree_sitter_tsx(),
            .javascript => tree_sitter_javascript(),
        };
    }
};

/// Point in source code (line, column)
pub const Point = struct {
    row: u32,
    column: u32,
};

/// AST node wrapper
pub const Node = struct {
    inner: c.TSNode,

    /// Check if this node or any descendant has an error
    pub fn hasError(self: Node) bool {
        return c.ts_node_has_error(self.inner);
    }

    /// Get the number of direct children
    pub fn childCount(self: Node) u32 {
        return c.ts_node_child_count(self.inner);
    }

    /// Get the node type as a string
    pub fn nodeType(self: Node) []const u8 {
        const type_ptr = c.ts_node_type(self.inner);
        return std.mem.span(type_ptr);
    }

    /// Get the start position of this node
    pub fn startPoint(self: Node) Point {
        const pt = c.ts_node_start_point(self.inner);
        return Point{
            .row = pt.row,
            .column = pt.column,
        };
    }

    /// Get the end position of this node
    pub fn endPoint(self: Node) Point {
        const pt = c.ts_node_end_point(self.inner);
        return Point{
            .row = pt.row,
            .column = pt.column,
        };
    }

    /// Get the byte offset where this node starts
    pub fn startByte(self: Node) u32 {
        return c.ts_node_start_byte(self.inner);
    }

    /// Get the byte offset where this node ends
    pub fn endByte(self: Node) u32 {
        return c.ts_node_end_byte(self.inner);
    }

    /// Get a child node by index, returns null if out of bounds
    pub fn child(self: Node, index: u32) ?Node {
        const child_node = c.ts_node_child(self.inner, index);
        if (c.ts_node_is_null(child_node)) {
            return null;
        }
        return Node{ .inner = child_node };
    }
};

/// Parsed syntax tree
pub const Tree = struct {
    inner: *c.TSTree,

    /// Get the root node of the tree
    pub fn rootNode(self: Tree) Node {
        return Node{ .inner = c.ts_tree_root_node(self.inner) };
    }

    /// Free the tree
    pub fn deinit(self: Tree) void {
        c.ts_tree_delete(self.inner);
    }
};

/// Parser for creating syntax trees from source code
pub const Parser = struct {
    inner: *c.TSParser,

    /// Create a new parser
    pub fn init() !Parser {
        const parser = c.ts_parser_new();
        if (parser == null) {
            return error.ParserCreationFailed;
        }
        return Parser{ .inner = parser.? };
    }

    /// Free the parser
    pub fn deinit(self: Parser) void {
        c.ts_parser_delete(self.inner);
    }

    /// Set the language for this parser
    pub fn setLanguage(self: Parser, language: Language) !void {
        const success = c.ts_parser_set_language(self.inner, language.toTSLanguage());
        if (!success) {
            return error.LanguageSetFailed;
        }
    }

    /// Parse a string and return the syntax tree
    pub fn parseString(self: Parser, source: []const u8) !Tree {
        const tree = c.ts_parser_parse_string(
            self.inner,
            null, // old_tree
            source.ptr,
            @intCast(source.len),
        );
        if (tree == null) {
            return error.ParseFailed;
        }
        return Tree{ .inner = tree.? };
    }
};

// TESTS

test "parser can be created and destroyed" {
    const parser = try Parser.init();
    defer parser.deinit();
}

test "parser can set TypeScript language" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);
}

test "parser can set TSX language" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.tsx);
}

test "parser can set JavaScript language" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.javascript);
}

test "parser can parse simple TypeScript string" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(!root.hasError());
}

test "root node type is program" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const node_type = root.nodeType();
    try std.testing.expectEqualStrings("program", node_type);
}

test "root node has children" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(root.childCount() > 0);
}

test "can get child nodes" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const first_child = root.child(0);
    try std.testing.expect(first_child != null);
}

test "child returns null for out of bounds index" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const invalid_child = root.child(999);
    try std.testing.expect(invalid_child == null);
}

test "node has start and end points" {
    const parser = try Parser.init();
    defer parser.deinit();

    try parser.setLanguage(.typescript);

    const source = "const x = 1;";
    const tree = try parser.parseString(source);
    defer tree.deinit();

    const root = tree.rootNode();
    const start = root.startPoint();
    const end = root.endPoint();

    // Root node should start at 0,0
    try std.testing.expectEqual(@as(u32, 0), start.row);
    try std.testing.expectEqual(@as(u32, 0), start.column);

    // End point should be after the source
    try std.testing.expect(end.column > 0 or end.row > 0);
}
