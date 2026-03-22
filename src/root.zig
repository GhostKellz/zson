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
pub const ErrorInfo = parser.ErrorInfo;
pub const StringifyOptions = stringify.StringifyOptions;

/// Result type for parsing with error info
pub const ParseResult = struct {
    value: ?Value,
    error_info: ?ErrorInfo,

    pub fn isOk(self: ParseResult) bool {
        return self.value != null;
    }
};

/// Parse ZSON string into a Value
pub fn parse(allocator: std.mem.Allocator, source: []const u8) !Value {
    var lex = Lexer.init(source);
    var p = try Parser.init(allocator, &lex);
    return try p.parse();
}

/// Parse ZSON string with detailed error information
pub fn parseWithInfo(allocator: std.mem.Allocator, source: []const u8) ParseResult {
    var lex = Lexer.init(source);
    var p = Parser.init(allocator, &lex) catch {
        return .{ .value = null, .error_info = null };
    };

    const value = p.parse() catch {
        return .{ .value = null, .error_info = p.getErrorInfo() };
    };

    return .{ .value = value, .error_info = null };
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
