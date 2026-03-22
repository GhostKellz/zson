# ZSON Documentation

ZSON (ZigScript Object Notation) is a developer-friendly superset of JSON built in Zig.

## Contents

- [Specification](specification.md) - Complete ZSON language specification
- [API Reference](api.md) - Zig library API documentation
- [Examples](examples.md) - Usage examples and patterns

## Quick Start

```zig
const zson = @import("zson");

// Parse ZSON
var value = try zson.parse(allocator, source);
defer value.deinit(allocator);

// Convert to JSON
const json = try zson.toJson(allocator, value);
defer allocator.free(json);
```

## Features

| Feature | JSON | ZSON |
|---------|------|------|
| Comments | No | Yes (`//` and `/* */`) |
| Trailing commas | No | Yes |
| Unquoted keys | No | Yes |
| Single quotes | No | Yes |
| Hex numbers | No | Yes (`0xFF`) |
| Binary numbers | No | Yes (`0b1010`) |
| Octal numbers | No | Yes (`0o755`) |
| Infinity/NaN | No | Yes |
| Type hints | No | Yes (`@i32`) |

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .zson = .{
        .url = "https://github.com/your-repo/zson/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...",
    },
},
```

Then in `build.zig`:

```zig
const zson = b.dependency("zson", .{});
exe.root_module.addImport("zson", zson.module("zson"));
```
