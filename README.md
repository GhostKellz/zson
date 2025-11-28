<p align="center">
  <img src="https://raw.githubusercontent.com/ziglang/logo/master/zig-logo.svg" width="80" height="80" alt="Zig Logo">
</p>

<h1 align="center">ZSON</h1>

<p align="center">
  <strong>ZigScript Object Notation</strong><br>
  A human-friendly superset of JSON built with Zig
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Built_with-Zig-F7A41D?style=for-the-badge&logo=zig&logoColor=white" alt="Built with Zig">
  <img src="https://img.shields.io/badge/Language-Zig_0.16+-F7A41D?style=for-the-badge&logo=zig&logoColor=white" alt="Zig 0.16+">
  <img src="https://img.shields.io/badge/Format-JSON_Superset-00ADD8?style=for-the-badge&logo=json&logoColor=white" alt="JSON Superset">
  <img src="https://img.shields.io/badge/Platform-Cross_Platform-4EAA25?style=for-the-badge&logo=linux&logoColor=white" alt="Cross Platform">
</p>

---

## Overview

ZSON is a developer-friendly data serialization format that extends JSON with modern conveniences while maintaining full backwards compatibility. Every valid JSON file is automatically valid ZSON.

```zson
{
  // Configuration with comments!
  app: {
    name: "MyApp",
    version: "1.0.0",
    debug: true,
  },

  database: {
    host: 'localhost',    // Single quotes work too
    port: 5432,
    max_connections: 100,
  },

  features: [
    "logging",
    "caching",
    "metrics",           // Trailing commas allowed
  ],
}
```

## Features

| Feature | JSON | ZSON |
|---------|:----:|:----:|
| Comments | - | **Single-line `//` and multi-line `/* */`** |
| Trailing Commas | - | **Allowed everywhere** |
| Unquoted Keys | - | **Valid identifiers don't need quotes** |
| Single Quotes | - | **`'strings'` work like `"strings"`** |
| Multiline Strings | - | **Triple quotes `"""..."""`** |
| Hex Numbers | - | **`0xFF00FF`** |
| Binary Numbers | - | **`0b10101010`** |
| Infinity/NaN | - | **`Infinity`, `-Infinity`, `NaN`** |
| Type Hints | - | **`42 @i32`, `[1,2,3] @[i32]`** |

## Installation

### As a Dependency

```bash
zig fetch --save https://github.com/ghostkellz/zson/archive/main.tar.gz
```

### Building from Source

```bash
git clone https://github.com/ghostkellz/zson.git
cd zson
zig build
```

## Usage

### As a Library

```zig
const std = @import("std");
const zson = @import("zson");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const source =
        \\{
        \\  name: "Alice",
        \\  age: 30,
        \\  active: true,
        \\}
    ;

    // Parse ZSON
    var value = try zson.parse(allocator, source);
    defer value.deinit(allocator);

    // Convert back to ZSON (with formatting options)
    const formatted = try zson.toZson(allocator, value, .{
        .indent = 2,
        .use_unquoted_keys = true,
        .use_trailing_commas = true,
    });
    defer allocator.free(formatted);

    // Convert to strict JSON
    const json = try zson.toJson(allocator, value);
    defer allocator.free(json);
}
```

### Command Line Interface

```bash
# Format a ZSON file
zson format config.zson

# Validate ZSON syntax
zson validate config.zson

# Convert ZSON to strict JSON
zson to-json config.zson

# Show version
zson version
```

## Syntax Reference

### Comments

```zson
{
  // Single-line comment
  "key": "value",

  /* Multi-line
     comment */
  "another": 42
}
```

### Unquoted Keys

Keys that are valid identifiers don't need quotes:

```zson
{
  name: "Alice",           // No quotes needed
  user_id: 123,            // Underscores allowed
  "special-key": "value"   // Quotes required for special chars
}
```

### String Variations

```zson
{
  double: "Hello \"world\"",
  single: 'Hello "world"',
  multiline: """
    This spans
    multiple lines
  """
}
```

### Number Formats

```zson
{
  decimal: 42,
  negative: -17,
  float: 3.14159,
  scientific: 6.022e23,
  hex: 0xFF00FF,
  binary: 0b10101010,
  infinity: Infinity,
  neg_infinity: -Infinity,
  not_a_number: NaN
}
```

### Type Hints

Optional type annotations for tooling integration:

```zson
{
  id: 42 @i32,
  score: 98.5 @f64,
  name: "Alice" @string,
  tags: ["dev", "admin"] @[string]
}
```

## Architecture

```
src/
├── root.zig       # Public API and module exports
├── lexer.zig      # Tokenizer for ZSON syntax
├── parser.zig     # Recursive descent parser
├── ast.zig        # Abstract syntax tree definitions
├── stringify.zig  # Value to string serialization
└── main.zig       # CLI application
```

## Running Tests

```bash
zig build test
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Specification

See [SPEC.md](SPEC.md) for the complete ZSON specification.
