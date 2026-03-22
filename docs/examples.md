# ZSON Examples

## Configuration File

```zson
{
  // Application configuration
  app: {
    name: "MyService",
    version: "1.0.0",
    debug: true,
  },

  // Server settings
  server: {
    host: 'localhost',
    port: 8080,
    timeout_ms: 30000,
  },

  // Feature flags
  features: [
    "logging",
    "metrics",
    "caching",
  ],

  // File permissions (octal)
  permissions: {
    config: 0o644,
    secrets: 0o600,
    executable: 0o755,
  },
}
```

## Data with Type Hints

```zson
{
  user_id: 12345 @i64,
  username: "alice" @string,
  scores: [98, 87, 92] @[i32],
  metadata: {
    created: "2024-01-15" @date,
    active: true @bool,
  },
}
```

## Scientific Data

```zson
{
  // Physical constants
  speed_of_light: 2.998e8,
  planck_constant: 6.626e-34,

  // Special values
  undefined_result: NaN,
  infinite_limit: Infinity,
  negative_bound: -Infinity,

  // Bit flags
  flags: 0b11010010,

  // Color codes
  primary_color: 0xFF5733,
  background: 0x1A1A2E,
}
```

## Multiline Strings

```zson
{
  query: """
    SELECT *
    FROM users
    WHERE active = true
    ORDER BY created_at DESC
  """,

  template: """
    Hello {{name}},

    Welcome to our service!

    Best regards,
    The Team
  """,
}
```

## Parsing in Zig

```zig
const std = @import("std");
const zson = @import("zson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\{
        \\  name: "example",
        \\  values: [1, 2, 3],
        \\}
    ;

    // Parse
    var value = try zson.parse(allocator, source);
    defer value.deinit(allocator);

    // Access data
    if (value.object.get("name")) |name| {
        std.debug.print("Name: {s}\n", .{name.string});
    }

    if (value.object.get("values")) |values| {
        for (values.array.items) |item| {
            std.debug.print("Value: {d}\n", .{item.number.integer});
        }
    }

    // Convert to JSON
    const json = try zson.toJson(allocator, value);
    defer allocator.free(json);
    std.debug.print("JSON: {s}\n", .{json});
}
```

## Error Handling

```zig
const zson = @import("zson");

fn parseConfig(allocator: std.mem.Allocator, source: []const u8) !zson.Value {
    const result = zson.parseWithInfo(allocator, source);

    if (result.value) |value| {
        return value;
    }

    if (result.error_info) |err| {
        std.log.err("Parse error at line {d}, column {d}: {s}", .{
            err.line,
            err.column,
            err.message,
        });
    }

    return error.ParseFailed;
}
```

## Output Formatting

```zig
const zson = @import("zson");

// Pretty print with defaults
const pretty = try zson.toZson(allocator, value, .{});

// Compact (minified)
const compact = try zson.toZson(allocator, value, .{ .compact = true });

// JSON-style (quoted keys, no trailing commas)
const json_style = try zson.toZson(allocator, value, .{
    .use_unquoted_keys = false,
    .use_trailing_commas = false,
});

// 4-space indent
const four_space = try zson.toZson(allocator, value, .{ .indent = 4 });

// Strict JSON
const json = try zson.toJson(allocator, value);
```

## CLI Usage

```bash
# Format a file
zson format config.zson

# Validate syntax
zson validate config.zson

# Convert to JSON
zson to-json config.zson > config.json

# Show version
zson version
```
