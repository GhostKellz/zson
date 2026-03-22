const std = @import("std");
const ast = @import("ast.zig");

pub const StringifyOptions = struct {
    indent: usize = 2,
    use_unquoted_keys: bool = true,
    use_trailing_commas: bool = true,
    use_single_quotes: bool = false,
    compact: bool = false, // No whitespace when true
};

pub fn stringify(
    allocator: std.mem.Allocator,
    value: ast.Value,
    options: StringifyOptions,
) ![]const u8 {
    var buffer: std.ArrayList(u8) = .empty;
    errdefer buffer.deinit(allocator);

    try stringifyValue(allocator, &buffer, value, options, 0);

    return try buffer.toOwnedSlice(allocator);
}

fn stringifyValue(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    value: ast.Value,
    options: StringifyOptions,
    depth: usize,
) std.mem.Allocator.Error!void {
    switch (value) {
        .object => |obj| try stringifyObject(allocator, buffer, obj, options, depth),
        .array => |arr| try stringifyArray(allocator, buffer, arr, options, depth),
        .string => |str| try stringifyString(allocator, buffer, str, options),
        .number => |num| try stringifyNumber(allocator, buffer, num),
        .boolean => |b| {
            const str = if (b) "true" else "false";
            try buffer.appendSlice(allocator, str);
        },
        .null_value => try buffer.appendSlice(allocator, "null"),
        .undefined_value => try buffer.appendSlice(allocator, "undefined"),
    }
}

fn stringifyObject(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    obj: ast.Value.Object,
    options: StringifyOptions,
    depth: usize,
) std.mem.Allocator.Error!void {
    if (options.compact) {
        try buffer.append(allocator, '{');
        var iter = obj.iterator();
        var first = true;
        while (iter.next()) |entry| {
            if (!first) try buffer.append(allocator, ',');
            first = false;

            const key = entry.key_ptr.*;
            if (options.use_unquoted_keys and isValidIdentifier(key) and !isReservedWord(key)) {
                try buffer.appendSlice(allocator, key);
            } else {
                try stringifyString(allocator, buffer, key, options);
            }
            try buffer.append(allocator, ':');
            try stringifyValue(allocator, buffer, entry.value_ptr.*, options, depth + 1);
        }
        try buffer.append(allocator, '}');
        return;
    }

    try buffer.appendSlice(allocator, "{\n");

    var iter = obj.iterator();
    var first = true;
    while (iter.next()) |entry| {
        if (!first) {
            try buffer.appendSlice(allocator, ",\n");
        }
        first = false;

        // Indent
        try writeIndent(allocator, buffer, options.indent, depth + 1);

        // Key
        const key = entry.key_ptr.*;
        if (options.use_unquoted_keys and isValidIdentifier(key) and !isReservedWord(key)) {
            try buffer.appendSlice(allocator, key);
        } else {
            try stringifyString(allocator, buffer, key, options);
        }

        try buffer.appendSlice(allocator, ": ");

        // Value
        try stringifyValue(allocator, buffer, entry.value_ptr.*, options, depth + 1);
    }

    if (options.use_trailing_commas and obj.count() > 0) {
        try buffer.appendSlice(allocator, ",");
    }

    try buffer.appendSlice(allocator, "\n");
    try writeIndent(allocator, buffer, options.indent, depth);
    try buffer.appendSlice(allocator, "}");
}

fn stringifyArray(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    arr: ast.Value.Array,
    options: StringifyOptions,
    depth: usize,
) std.mem.Allocator.Error!void {
    if (options.compact) {
        try buffer.append(allocator, '[');
        for (arr.items, 0..) |item, i| {
            if (i > 0) try buffer.append(allocator, ',');
            try stringifyValue(allocator, buffer, item, options, depth);
        }
        try buffer.append(allocator, ']');
        return;
    }

    // Inline arrays if all elements are simple
    const is_simple = blk: {
        for (arr.items) |item| {
            if (std.meta.activeTag(item) == .object or std.meta.activeTag(item) == .array) {
                break :blk false;
            }
        }
        break :blk true;
    };

    if (is_simple) {
        try buffer.appendSlice(allocator, "[");
        for (arr.items, 0..) |item, i| {
            if (i > 0) try buffer.appendSlice(allocator, ", ");
            try stringifyValue(allocator, buffer, item, options, depth);
        }
        if (options.use_trailing_commas and arr.items.len > 0) {
            try buffer.appendSlice(allocator, ",");
        }
        try buffer.appendSlice(allocator, "]");
    } else {
        try buffer.appendSlice(allocator, "[\n");
        for (arr.items, 0..) |item, i| {
            if (i > 0) try buffer.appendSlice(allocator, ",\n");
            try writeIndent(allocator, buffer, options.indent, depth + 1);
            try stringifyValue(allocator, buffer, item, options, depth + 1);
        }
        if (options.use_trailing_commas and arr.items.len > 0) {
            try buffer.appendSlice(allocator, ",");
        }
        try buffer.appendSlice(allocator, "\n");
        try writeIndent(allocator, buffer, options.indent, depth);
        try buffer.appendSlice(allocator, "]");
    }
}

fn stringifyString(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    str: []const u8,
    options: StringifyOptions,
) std.mem.Allocator.Error!void {
    const quote: u8 = if (options.use_single_quotes) '\'' else '"';

    try buffer.append(allocator, quote);
    for (str) |c| {
        switch (c) {
            '\\' => try buffer.appendSlice(allocator, "\\\\"),
            '\n' => try buffer.appendSlice(allocator, "\\n"),
            '\r' => try buffer.appendSlice(allocator, "\\r"),
            '\t' => try buffer.appendSlice(allocator, "\\t"),
            '"' => {
                if (!options.use_single_quotes) {
                    try buffer.appendSlice(allocator, "\\\"");
                } else {
                    try buffer.append(allocator, '"');
                }
            },
            '\'' => {
                if (options.use_single_quotes) {
                    try buffer.appendSlice(allocator, "\\'");
                } else {
                    try buffer.append(allocator, '\'');
                }
            },
            else => try buffer.append(allocator, c),
        }
    }
    try buffer.append(allocator, quote);
}

fn stringifyNumber(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), num: ast.Value.Number) std.mem.Allocator.Error!void {
    // Use stack buffer to avoid allocation
    var buf: [128]u8 = undefined;

    switch (num) {
        .integer => |i| {
            const str = std.fmt.bufPrint(&buf, "{d}", .{i}) catch unreachable;
            try buffer.appendSlice(allocator, str);
        },
        .float => |f| {
            if (std.math.isInf(f)) {
                if (f < 0) {
                    try buffer.appendSlice(allocator, "-Infinity");
                } else {
                    try buffer.appendSlice(allocator, "Infinity");
                }
            } else if (std.math.isNan(f)) {
                try buffer.appendSlice(allocator, "NaN");
            } else {
                const str = std.fmt.bufPrint(&buf, "{d}", .{f}) catch unreachable;
                try buffer.appendSlice(allocator, str);
            }
        },
        .hex => |h| {
            const str = std.fmt.bufPrint(&buf, "0x{X}", .{h}) catch unreachable;
            try buffer.appendSlice(allocator, str);
        },
        .binary => |b| {
            const str = std.fmt.bufPrint(&buf, "0b{b}", .{b}) catch unreachable;
            try buffer.appendSlice(allocator, str);
        },
        .octal => |o| {
            const str = std.fmt.bufPrint(&buf, "0o{o}", .{o}) catch unreachable;
            try buffer.appendSlice(allocator, str);
        },
    }
}

fn writeIndent(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), indent: usize, depth: usize) std.mem.Allocator.Error!void {
    const total = indent * depth;
    if (total > 0) {
        try buffer.appendNTimes(allocator, ' ', total);
    }
}

fn isValidIdentifier(str: []const u8) bool {
    if (str.len == 0) return false;

    const first = str[0];
    if (!((first >= 'a' and first <= 'z') or (first >= 'A' and first <= 'Z') or first == '_')) {
        return false;
    }

    for (str[1..]) |c| {
        if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_')) {
            return false;
        }
    }

    return true;
}

fn isReservedWord(str: []const u8) bool {
    const reserved = [_][]const u8{
        "true",
        "false",
        "null",
        "undefined",
        "Infinity",
        "NaN",
    };
    for (reserved) |word| {
        if (std.mem.eql(u8, str, word)) return true;
    }
    return false;
}

// Tests
test "stringify simple object" {
    // Use allocated strings to avoid double-free issues
    const name_key = try std.testing.allocator.dupe(u8, "name");
    const age_key = try std.testing.allocator.dupe(u8, "age");
    const name_val = try std.testing.allocator.dupe(u8, "Alice");

    var obj = ast.Value.Object.init(std.testing.allocator);

    try obj.put(name_key, ast.Value{ .string = name_val });
    try obj.put(age_key, ast.Value{ .number = .{ .integer = 30 } });

    var value = ast.Value{ .object = obj };
    defer value.deinit(std.testing.allocator);

    const result = try stringify(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(result);

    // Check it produces valid output
    try std.testing.expect(result.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, result, "name") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Alice") != null);
}

test "stringify with escapes" {
    const key = try std.testing.allocator.dupe(u8, "message");
    const val = try std.testing.allocator.dupe(u8, "hello\nworld");

    var obj = ast.Value.Object.init(std.testing.allocator);
    try obj.put(key, ast.Value{ .string = val });

    var value = ast.Value{ .object = obj };
    defer value.deinit(std.testing.allocator);

    const result = try stringify(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(result);

    // Should escape the newline
    try std.testing.expect(std.mem.indexOf(u8, result, "\\n") != null);
}

test "stringify compact mode" {
    const key = try std.testing.allocator.dupe(u8, "x");

    var obj = ast.Value.Object.init(std.testing.allocator);
    try obj.put(key, ast.Value{ .number = .{ .integer = 1 } });

    var value = ast.Value{ .object = obj };
    defer value.deinit(std.testing.allocator);

    const result = try stringify(std.testing.allocator, value, .{ .compact = true });
    defer std.testing.allocator.free(result);

    // Compact mode should have no newlines
    try std.testing.expect(std.mem.indexOf(u8, result, "\n") == null);
}
