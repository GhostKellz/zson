const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    InvalidSyntax,
    OutOfMemory,
    UnterminatedString,
    UnexpectedCharacter,
    InvalidCharacter,
    Overflow,
};

/// Detailed error information with location
pub const ErrorInfo = struct {
    line: usize,
    column: usize,
    message: []const u8,

    pub fn format(self: ErrorInfo, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("line {d}, column {d}: {s}", .{ self.line, self.column, self.message });
    }
};

pub const Parser = struct {
    lexer: *lexer.Lexer,
    current: lexer.Token,
    allocator: std.mem.Allocator,
    last_error: ?ErrorInfo = null,

    pub fn init(allocator: std.mem.Allocator, lex: *lexer.Lexer) !Parser {
        var parser = Parser{
            .lexer = lex,
            .current = undefined,
            .allocator = allocator,
            .last_error = null,
        };
        parser.current = try parser.lexer.nextToken();
        return parser;
    }

    pub fn parse(self: *Parser) !ast.Value {
        return try self.parseValue();
    }

    /// Get the last error information (if any)
    pub fn getErrorInfo(self: *Parser) ?ErrorInfo {
        return self.last_error;
    }

    fn setError(self: *Parser, message: []const u8) void {
        self.last_error = ErrorInfo{
            .line = self.current.line,
            .column = self.current.column,
            .message = message,
        };
    }

    fn parseValue(self: *Parser) ParseError!ast.Value {
        return switch (self.current.type) {
            .left_brace => try self.parseObject(),
            .left_bracket => try self.parseArray(),
            .string => try self.parseString(),
            .number => try self.parseNumber(),
            .true_lit => try self.parseBoolean(true),
            .false_lit => try self.parseBoolean(false),
            .null_lit => try self.parseNull(),
            .undefined_lit => try self.parseUndefined(),
            .infinity, .nan => try self.parseSpecialNumber(),
            else => {
                self.setError("unexpected token");
                return ParseError.UnexpectedToken;
            },
        };
    }

    fn parseObject(self: *Parser) !ast.Value {
        try self.consume(.left_brace);

        var obj = ast.Value.Object.init(self.allocator);
        errdefer {
            // Clean up all allocated keys and values on error
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                var val = entry.value_ptr;
                val.deinit(self.allocator);
            }
            obj.deinit();
        }

        while (self.current.type != .right_brace and self.current.type != .eof) {
            // Parse key (identifier or string)
            const key = switch (self.current.type) {
                .identifier => blk: {
                    // Duplicate identifier so we own the memory
                    const k = try self.allocator.dupe(u8, self.current.lexeme);
                    try self.advance();
                    break :blk k;
                },
                .string => blk: {
                    const k = try self.extractString(self.current.lexeme);
                    try self.advance();
                    break :blk k;
                },
                else => return ParseError.UnexpectedToken,
            };
            errdefer self.allocator.free(key);

            try self.consume(.colon);

            // Parse value
            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);

            // Skip optional type hint
            if (self.current.type == .type_hint) {
                try self.advance();
            }

            try obj.put(key, value);

            // Handle trailing comma
            if (self.current.type == .comma) {
                try self.advance();
                // Allow trailing comma before }
                if (self.current.type == .right_brace) {
                    break;
                }
            } else if (self.current.type != .right_brace) {
                return ParseError.UnexpectedToken;
            }
        }

        try self.consume(.right_brace);

        return ast.Value{ .object = obj };
    }

    fn parseArray(self: *Parser) !ast.Value {
        try self.consume(.left_bracket);

        var arr: ast.Value.Array = .empty;
        errdefer {
            // Clean up all allocated values on error
            for (arr.items) |*item| {
                item.deinit(self.allocator);
            }
            arr.deinit(self.allocator);
        }

        while (self.current.type != .right_bracket and self.current.type != .eof) {
            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);

            // Skip optional type hint
            if (self.current.type == .type_hint) {
                try self.advance();
            }

            try arr.append(self.allocator, value);

            // Handle trailing comma
            if (self.current.type == .comma) {
                try self.advance();
                // Allow trailing comma before ]
                if (self.current.type == .right_bracket) {
                    break;
                }
            } else if (self.current.type != .right_bracket) {
                return ParseError.UnexpectedToken;
            }
        }

        try self.consume(.right_bracket);

        return ast.Value{ .array = arr };
    }

    fn parseString(self: *Parser) !ast.Value {
        const str = try self.extractString(self.current.lexeme);
        try self.advance();
        return ast.Value{ .string = str };
    }

    fn extractString(self: *Parser, lexeme: []const u8) ![]const u8 {
        // Remove quotes and handle escapes
        if (lexeme.len < 2) {
            return ParseError.InvalidSyntax;
        }

        // Check for multiline string """
        if (lexeme.len >= 6 and std.mem.startsWith(u8, lexeme, "\"\"\"")) {
            const content = lexeme[3 .. lexeme.len - 3];
            return try self.processEscapes(content);
        }

        // Single or double quoted
        const content = lexeme[1 .. lexeme.len - 1];
        return try self.processEscapes(content);
    }

    fn processEscapes(self: *Parser, content: []const u8) ![]const u8 {
        // Fast path: no escapes
        if (std.mem.indexOfScalar(u8, content, '\\') == null) {
            return try self.allocator.dupe(u8, content);
        }

        var result = std.ArrayList(u8).empty;
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < content.len) {
            if (content[i] == '\\' and i + 1 < content.len) {
                const next = content[i + 1];
                switch (next) {
                    'n' => {
                        try result.append(self.allocator, '\n');
                        i += 2;
                    },
                    't' => {
                        try result.append(self.allocator, '\t');
                        i += 2;
                    },
                    'r' => {
                        try result.append(self.allocator, '\r');
                        i += 2;
                    },
                    '\\' => {
                        try result.append(self.allocator, '\\');
                        i += 2;
                    },
                    '"' => {
                        try result.append(self.allocator, '"');
                        i += 2;
                    },
                    '\'' => {
                        try result.append(self.allocator, '\'');
                        i += 2;
                    },
                    '/' => {
                        try result.append(self.allocator, '/');
                        i += 2;
                    },
                    'b' => {
                        try result.append(self.allocator, 0x08); // backspace
                        i += 2;
                    },
                    'f' => {
                        try result.append(self.allocator, 0x0C); // form feed
                        i += 2;
                    },
                    'u' => {
                        // Unicode escape: \uXXXX
                        if (i + 5 < content.len) {
                            const hex = content[i + 2 .. i + 6];
                            if (std.fmt.parseInt(u21, hex, 16)) |codepoint| {
                                var buf: [4]u8 = undefined;
                                const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                                    // Invalid codepoint, keep as-is
                                    try result.append(self.allocator, content[i]);
                                    i += 1;
                                    continue;
                                };
                                try result.appendSlice(self.allocator, buf[0..len]);
                                i += 6;
                            } else |_| {
                                // Invalid hex, keep as-is
                                try result.append(self.allocator, content[i]);
                                i += 1;
                            }
                        } else {
                            try result.append(self.allocator, content[i]);
                            i += 1;
                        }
                    },
                    else => {
                        // Unknown escape, keep as-is
                        try result.append(self.allocator, content[i]);
                        i += 1;
                    },
                }
            } else {
                try result.append(self.allocator, content[i]);
                i += 1;
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    fn parseNumber(self: *Parser) !ast.Value {
        const lexeme = self.current.lexeme;

        // Hex
        if (std.mem.startsWith(u8, lexeme, "0x") or std.mem.startsWith(u8, lexeme, "0X")) {
            const hex_str = lexeme[2..];
            const value = try std.fmt.parseInt(u64, hex_str, 16);
            try self.advance();
            return ast.Value{ .number = .{ .hex = value } };
        }

        // Binary
        if (std.mem.startsWith(u8, lexeme, "0b") or std.mem.startsWith(u8, lexeme, "0B")) {
            const bin_str = lexeme[2..];
            const value = try std.fmt.parseInt(u64, bin_str, 2);
            try self.advance();
            return ast.Value{ .number = .{ .binary = value } };
        }

        // Octal
        if (std.mem.startsWith(u8, lexeme, "0o") or std.mem.startsWith(u8, lexeme, "0O")) {
            const oct_str = lexeme[2..];
            const value = try std.fmt.parseInt(u64, oct_str, 8);
            try self.advance();
            return ast.Value{ .number = .{ .octal = value } };
        }

        // Float or integer
        if (std.mem.indexOf(u8, lexeme, ".") != null or
            std.mem.indexOf(u8, lexeme, "e") != null or
            std.mem.indexOf(u8, lexeme, "E") != null)
        {
            const value = try std.fmt.parseFloat(f64, lexeme);
            try self.advance();
            return ast.Value{ .number = .{ .float = value } };
        } else {
            const value = try std.fmt.parseInt(i64, lexeme, 10);
            try self.advance();
            return ast.Value{ .number = .{ .integer = value } };
        }
    }

    fn parseBoolean(self: *Parser, value: bool) !ast.Value {
        try self.advance();
        return ast.Value{ .boolean = value };
    }

    fn parseNull(self: *Parser) !ast.Value {
        try self.advance();
        return ast.Value.null_value;
    }

    fn parseUndefined(self: *Parser) !ast.Value {
        try self.advance();
        return ast.Value.undefined_value;
    }

    fn parseSpecialNumber(self: *Parser) !ast.Value {
        const is_infinity = self.current.type == .infinity;
        const is_negative = std.mem.startsWith(u8, self.current.lexeme, "-");

        try self.advance();

        if (is_infinity) {
            const value = if (is_negative) -std.math.inf(f64) else std.math.inf(f64);
            return ast.Value{ .number = .{ .float = value } };
        } else {
            return ast.Value{ .number = .{ .float = std.math.nan(f64) } };
        }
    }

    fn consume(self: *Parser, token_type: lexer.TokenType) !void {
        if (self.current.type != token_type) {
            self.setError("unexpected token");
            return ParseError.UnexpectedToken;
        }
        try self.advance();
    }

    fn advance(self: *Parser) !void {
        self.current = try self.lexer.nextToken();
    }
};

// Tests
test "parse simple object" {
    const source = "{\"name\": \"Alice\", \"age\": 30}";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    try std.testing.expectEqual(ast.Value.object, std.meta.activeTag(value));
}

test "parse array" {
    const source = "[1, 2, 3, true, \"hello\"]";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    try std.testing.expectEqual(ast.Value.array, std.meta.activeTag(value));
    try std.testing.expectEqual(@as(usize, 5), value.array.items.len);
}

test "parse unquoted keys" {
    const source = "{name: \"Alice\", age: 30}";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    try std.testing.expectEqual(ast.Value.object, std.meta.activeTag(value));
}

test "parse trailing commas" {
    const source = "{\"items\": [1, 2, 3,],}";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    try std.testing.expectEqual(ast.Value.object, std.meta.activeTag(value));
}

test "parse escape sequences" {
    const source = "{\"msg\": \"hello\\nworld\\t!\"}";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    const msg = value.object.get("msg").?;
    try std.testing.expectEqualStrings("hello\nworld\t!", msg.string);
}

test "parse octal numbers" {
    const source = "[0o755, 0o644]";
    var lex = lexer.Lexer.init(source);
    var parser = try Parser.init(std.testing.allocator, &lex);

    var value = try parser.parse();
    defer value.deinit(std.testing.allocator);

    try std.testing.expectEqual(ast.Value.array, std.meta.activeTag(value));
    try std.testing.expectEqual(@as(u64, 0o755), value.array.items[0].number.octal);
    try std.testing.expectEqual(@as(u64, 0o644), value.array.items[1].number.octal);
}
