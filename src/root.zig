//! ZSON - ZigScript Object Notation
//! A superset of JSON with developer-friendly features

const std = @import("std");

pub const lexer = @import("lexer.zig");
pub const parser = @import("parser.zig");
pub const ast = @import("ast.zig");
pub const stringify = @import("stringify.zig");

pub const Lexer = lexer.Lexer;
pub const Parser = parser.Parser;
pub const Value = ast.Value;

/// Parse ZSON string into a Value
pub fn parse(allocator: std.mem.Allocator, source: []const u8) !Value {
    var lex = Lexer.init(source);
    var p = try Parser.init(allocator, &lex);
    return try p.parse();
}

/// Convert Value to ZSON string
pub fn toZson(allocator: std.mem.Allocator, value: Value, options: stringify.StringifyOptions) ![]const u8 {
    return try stringify.stringify(allocator, value, options);
}

/// Convert Value to strict JSON string
pub fn toJson(allocator: std.mem.Allocator, value: Value) ![]const u8 {
    return try stringify.stringify(allocator, value, .{
        .use_unquoted_keys = false,
        .use_trailing_commas = false,
        .use_single_quotes = false,
    });
}

test "basic parse and stringify" {
    const source =
        \\{
        \\  name: "Alice",
        \\  age: 30,
        \\  active: true,
        \\}
    ;

    var value = try parse(std.testing.allocator, source);
    defer value.deinit(std.testing.allocator);

    const result = try toZson(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(result);

    try std.testing.expect(result.len > 0);
}
