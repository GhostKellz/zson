const std = @import("std");
const ast = @import("ast.zig");

pub const StringifyOptions = struct {
    indent: usize = 2,
    use_unquoted_keys: bool = true,
    use_trailing_commas: bool = true,
    use_single_quotes: bool = false,
};

pub fn stringify(
    allocator: std.mem.Allocator,
    value: ast.Value,
    options: StringifyOptions,
) ![]const u8 {
    var buffer = std.ArrayList(u8){};
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
        if (options.use_unquoted_keys and isValidIdentifier(key)) {
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
    switch (num) {
        .integer => |i| {
            const str = try std.fmt.allocPrint(allocator, "{d}", .{i});
            defer allocator.free(str);
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
                const str = try std.fmt.allocPrint(allocator, "{d}", .{f});
                defer allocator.free(str);
                try buffer.appendSlice(allocator, str);
            }
        },
        .hex => |h| {
            const str = try std.fmt.allocPrint(allocator, "0x{X}", .{h});
            defer allocator.free(str);
            try buffer.appendSlice(allocator, str);
        },
        .binary => |b| {
            const str = try std.fmt.allocPrint(allocator, "0b{b}", .{b});
            defer allocator.free(str);
            try buffer.appendSlice(allocator, str);
        },
    }
}

fn writeIndent(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), indent: usize, depth: usize) std.mem.Allocator.Error!void {
    const total = indent * depth;
    for (0..total) |_| {
        try buffer.append(allocator, ' ');
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

// Tests
test "stringify simple object" {
    var obj = ast.Value.Object.init(std.testing.allocator);
    defer obj.deinit();

    try obj.put("name", ast.Value{ .string = "Alice" });
    try obj.put("age", ast.Value{ .number = .{ .integer = 30 } });

    const value = ast.Value{ .object = obj };

    const result = try stringify(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(result);

    // Just check it doesn't crash
    try std.testing.expect(result.len > 0);
}
