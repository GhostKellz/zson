const std = @import("std");

pub const TokenType = enum {
    // Delimiters
    left_brace,    // {
    right_brace,   // }
    left_bracket,  // [
    right_bracket, // ]
    colon,         // :
    comma,         // ,

    // Literals
    string,        // "hello" or 'hello' or """multiline"""
    number,        // 42, 3.14, 0xFF, 0b1010
    true_lit,      // true
    false_lit,     // false
    null_lit,      // null
    undefined_lit, // undefined
    infinity,      // Infinity
    nan,           // NaN

    // Special
    identifier,    // unquoted key
    type_hint,     // @i32, @string
    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    column: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .column = 1,
        };
    }

    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespaceAndComments();

        if (self.isAtEnd()) {
            return Token{
                .type = .eof,
                .lexeme = "",
                .line = self.line,
                .column = self.column,
            };
        }

        const start = self.pos;
        const start_column = self.column;
        const c = self.advance();

        return switch (c) {
            '{' => self.makeToken(.left_brace, start, start_column),
            '}' => self.makeToken(.right_brace, start, start_column),
            '[' => self.makeToken(.left_bracket, start, start_column),
            ']' => self.makeToken(.right_bracket, start, start_column),
            ':' => self.makeToken(.colon, start, start_column),
            ',' => self.makeToken(.comma, start, start_column),

            '"' => try self.scanString('"', start, start_column),
            '\'' => try self.scanString('\'', start, start_column),

            '@' => try self.scanTypeHint(start, start_column),

            '0'...'9' => try self.scanNumber(start, start_column),
            '-' => try self.scanNumberOrNeg(start, start_column),

            'a'...'z', 'A'...'Z', '_' => try self.scanIdentifierOrKeyword(start, start_column),

            else => error.UnexpectedCharacter,
        };
    }

    fn makeToken(self: *Lexer, token_type: TokenType, start: usize, start_column: usize) Token {
        return Token{
            .type = token_type,
            .lexeme = self.source[start..self.pos],
            .line = self.line,
            .column = start_column,
        };
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    self.column = 0;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        // Single-line comment
                        while (!self.isAtEnd() and self.peek() != '\n') {
                            _ = self.advance();
                        }
                    } else if (self.peekNext() == '*') {
                        // Multi-line comment
                        _ = self.advance(); // /
                        _ = self.advance(); // *
                        while (!self.isAtEnd()) {
                            if (self.peek() == '*' and self.peekNext() == '/') {
                                _ = self.advance(); // *
                                _ = self.advance(); // /
                                break;
                            }
                            if (self.peek() == '\n') {
                                self.line += 1;
                                self.column = 0;
                            }
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn scanString(self: *Lexer, quote: u8, start: usize, start_column: usize) !Token {
        // Check for multiline string """
        if (quote == '"' and self.peek() == '"' and self.peekNext() == '"') {
            _ = self.advance(); // second "
            _ = self.advance(); // third "
            return try self.scanMultilineString(start, start_column);
        }

        // Regular string
        while (!self.isAtEnd() and self.peek() != quote) {
            if (self.peek() == '\\') {
                _ = self.advance(); // escape
                if (!self.isAtEnd()) {
                    _ = self.advance(); // escaped char
                }
            } else if (self.peek() == '\n') {
                return error.UnterminatedString;
            } else {
                _ = self.advance();
            }
        }

        if (self.isAtEnd()) {
            return error.UnterminatedString;
        }

        _ = self.advance(); // closing quote

        return self.makeToken(.string, start, start_column);
    }

    fn scanMultilineString(self: *Lexer, start: usize, start_column: usize) !Token {
        while (!self.isAtEnd()) {
            if (self.peek() == '"' and self.peekNext() == '"') {
                if (self.pos + 2 < self.source.len and self.source[self.pos + 2] == '"') {
                    _ = self.advance(); // "
                    _ = self.advance(); // "
                    _ = self.advance(); // "
                    return self.makeToken(.string, start, start_column);
                }
            }
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 0;
            }
            _ = self.advance();
        }

        return error.UnterminatedString;
    }

    fn scanTypeHint(self: *Lexer, start: usize, start_column: usize) !Token {
        // @i32, @string, @[i32]
        while (!self.isAtEnd() and (isAlphaNumeric(self.peek()) or self.peek() == '[' or self.peek() == ']')) {
            _ = self.advance();
        }
        return self.makeToken(.type_hint, start, start_column);
    }

    fn scanNumber(self: *Lexer, start: usize, start_column: usize) !Token {
        const first = self.source[start];

        // Hex: 0x...
        if (first == '0' and !self.isAtEnd() and (self.peek() == 'x' or self.peek() == 'X')) {
            _ = self.advance();
            while (!self.isAtEnd() and isHexDigit(self.peek())) {
                _ = self.advance();
            }
            return self.makeToken(.number, start, start_column);
        }

        // Binary: 0b...
        if (first == '0' and !self.isAtEnd() and (self.peek() == 'b' or self.peek() == 'B')) {
            _ = self.advance();
            while (!self.isAtEnd() and (self.peek() == '0' or self.peek() == '1')) {
                _ = self.advance();
            }
            return self.makeToken(.number, start, start_column);
        }

        // Decimal integer/float
        while (!self.isAtEnd() and isDigit(self.peek())) {
            _ = self.advance();
        }

        // Check for decimal point
        if (!self.isAtEnd() and self.peek() == '.' and self.pos + 1 < self.source.len and isDigit(self.source[self.pos + 1])) {
            _ = self.advance(); // .
            while (!self.isAtEnd() and isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        // Check for exponent
        if (!self.isAtEnd() and (self.peek() == 'e' or self.peek() == 'E')) {
            _ = self.advance();
            if (!self.isAtEnd() and (self.peek() == '+' or self.peek() == '-')) {
                _ = self.advance();
            }
            while (!self.isAtEnd() and isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return self.makeToken(.number, start, start_column);
    }

    fn scanNumberOrNeg(self: *Lexer, start: usize, start_column: usize) !Token {
        // Check if it's -Infinity
        if (self.matchKeyword("Infinity")) {
            return self.makeToken(.infinity, start, start_column);
        }

        // Otherwise it's a negative number
        if (!self.isAtEnd() and isDigit(self.peek())) {
            return try self.scanNumber(start, start_column);
        }

        return error.UnexpectedCharacter;
    }

    fn scanIdentifierOrKeyword(self: *Lexer, start: usize, start_column: usize) !Token {
        while (!self.isAtEnd() and isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        const lexeme = self.source[start..self.pos];

        const token_type = if (std.mem.eql(u8, lexeme, "true"))
            TokenType.true_lit
        else if (std.mem.eql(u8, lexeme, "false"))
            TokenType.false_lit
        else if (std.mem.eql(u8, lexeme, "null"))
            TokenType.null_lit
        else if (std.mem.eql(u8, lexeme, "undefined"))
            TokenType.undefined_lit
        else if (std.mem.eql(u8, lexeme, "Infinity"))
            TokenType.infinity
        else if (std.mem.eql(u8, lexeme, "NaN"))
            TokenType.nan
        else
            TokenType.identifier;

        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .line = self.line,
            .column = start_column,
        };
    }

    fn matchKeyword(self: *Lexer, keyword: []const u8) bool {
        if (self.pos + keyword.len > self.source.len) {
            return false;
        }

        const slice = self.source[self.pos .. self.pos + keyword.len];
        if (std.mem.eql(u8, slice, keyword)) {
            self.pos += keyword.len;
            self.column += keyword.len;
            return true;
        }

        return false;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.pos + 1 >= self.source.len) return 0;
        return self.source[self.pos + 1];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        self.column += 1;
        return c;
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isHexDigit(c: u8) bool {
        return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }
};

// Tests
test "lexer basic tokens" {
    const source = "{ } [ ] : ,";
    var lexer = Lexer.init(source);

    const tokens = [_]TokenType{
        .left_brace,
        .right_brace,
        .left_bracket,
        .right_bracket,
        .colon,
        .comma,
        .eof,
    };

    for (tokens) |expected| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(expected, token.type);
    }
}

test "lexer strings" {
    const source =
        \\"hello" 'world' """multiline
        \\text"""
    ;
    var lexer = Lexer.init(source);

    const t1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, t1.type);

    const t2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, t2.type);

    const t3 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, t3.type);
}

test "lexer numbers" {
    const source = "42 3.14 0xFF 0b1010 -5";
    var lexer = Lexer.init(source);

    for (0..5) |_| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(TokenType.number, token.type);
    }
}

test "lexer keywords" {
    const source = "true false null undefined Infinity NaN";
    var lexer = Lexer.init(source);

    const types = [_]TokenType{ .true_lit, .false_lit, .null_lit, .undefined_lit, .infinity, .nan };

    for (types) |expected| {
        const token = try lexer.nextToken();
        try std.testing.expectEqual(expected, token.type);
    }
}

test "lexer comments" {
    const source =
        \\{
        \\  // single line comment
        \\  "key": "value",
        \\  /* multi
        \\     line
        \\     comment */
        \\  "key2": 42
        \\}
    ;
    var lexer = Lexer.init(source);

    const token1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.left_brace, token1.type);

    const token2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.string, token2.type);
}
