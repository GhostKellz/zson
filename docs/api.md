# ZSON API Reference

## Module: `zson`

### Types

#### `Value`

Tagged union representing a ZSON value.

```zig
pub const Value = union(enum) {
    object: Object,
    array: Array,
    string: []const u8,
    number: Number,
    boolean: bool,
    null_value,
    undefined_value,
};
```

**Methods:**

- `deinit(allocator: Allocator) void` - Free all memory associated with the value

#### `Value.Object`

```zig
pub const Object = std.StringHashMap(Value);
```

#### `Value.Array`

```zig
pub const Array = std.ArrayList(Value);
```

#### `Value.Number`

```zig
pub const Number = union(enum) {
    integer: i64,
    float: f64,
    hex: u64,
    binary: u64,
    octal: u64,
};
```

#### `StringifyOptions`

```zig
pub const StringifyOptions = struct {
    indent: usize = 2,
    use_unquoted_keys: bool = true,
    use_trailing_commas: bool = true,
    use_single_quotes: bool = false,
    compact: bool = false,
};
```

#### `ErrorInfo`

```zig
pub const ErrorInfo = struct {
    line: usize,
    column: usize,
    message: []const u8,
};
```

#### `ParseResult`

```zig
pub const ParseResult = struct {
    value: ?Value,
    error_info: ?ErrorInfo,

    pub fn isOk(self: ParseResult) bool;
};
```

---

### Functions

#### `parse`

```zig
pub fn parse(allocator: Allocator, source: []const u8) !Value
```

Parse a ZSON string into a Value.

**Parameters:**
- `allocator` - Memory allocator for the parsed value
- `source` - ZSON source string

**Returns:** Parsed `Value` or error

**Errors:**
- `ParseError.UnexpectedToken`
- `ParseError.InvalidSyntax`
- `ParseError.UnterminatedString`
- `error.OutOfMemory`

---

#### `parseWithInfo`

```zig
pub fn parseWithInfo(allocator: Allocator, source: []const u8) ParseResult
```

Parse with detailed error information.

**Parameters:**
- `allocator` - Memory allocator
- `source` - ZSON source string

**Returns:** `ParseResult` with value or error info

---

#### `toZson`

```zig
pub fn toZson(allocator: Allocator, value: Value, options: StringifyOptions) ![]const u8
```

Convert a Value to a ZSON string.

**Parameters:**
- `allocator` - Memory allocator for output
- `value` - Value to stringify
- `options` - Formatting options

**Returns:** Owned ZSON string (caller must free)

---

#### `toJson`

```zig
pub fn toJson(allocator: Allocator, value: Value) ![]const u8
```

Convert a Value to strict JSON (no ZSON extensions).

**Parameters:**
- `allocator` - Memory allocator for output
- `value` - Value to stringify

**Returns:** Owned JSON string (caller must free)

---

### Low-Level API

#### `Lexer`

```zig
pub const Lexer = struct {
    pub fn init(source: []const u8) Lexer;
    pub fn nextToken(self: *Lexer) !Token;
};
```

#### `Parser`

```zig
pub const Parser = struct {
    pub fn init(allocator: Allocator, lexer: *Lexer) !Parser;
    pub fn parse(self: *Parser) !Value;
    pub fn getErrorInfo(self: *Parser) ?ErrorInfo;
};
```

---

## Usage Patterns

### Basic Parsing

```zig
const zson = @import("zson");

var value = try zson.parse(allocator, source);
defer value.deinit(allocator);
```

### Error Handling

```zig
const result = zson.parseWithInfo(allocator, source);
if (result.value) |value| {
    defer value.deinit(allocator);
    // use value
} else if (result.error_info) |err| {
    std.debug.print("Error at {}\n", .{err});
}
```

### Compact Output

```zig
const compact = try zson.toZson(allocator, value, .{ .compact = true });
```

### JSON Conversion

```zig
const json = try zson.toJson(allocator, value);
```
