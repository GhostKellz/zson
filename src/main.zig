const stdlib = @import("std");
const zson = @import("zson");

pub fn main() !void {
    var gpa = stdlib.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try stdlib.process.argsAlloc(allocator);
    defer stdlib.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (stdlib.mem.eql(u8, command, "format")) {
        if (args.len < 3) {
            stdlib.debug.print("Usage: zson format <file>\n", .{});
            return;
        }
        try formatFile(allocator, args[2]);
    } else if (stdlib.mem.eql(u8, command, "validate")) {
        if (args.len < 3) {
            stdlib.debug.print("Usage: zson validate <file>\n", .{});
            return;
        }
        try validateFile(allocator, args[2]);
    } else if (stdlib.mem.eql(u8, command, "to-json")) {
        if (args.len < 3) {
            stdlib.debug.print("Usage: zson to-json <file>\n", .{});
            return;
        }
        try convertToJson(allocator, args[2]);
    } else if (stdlib.mem.eql(u8, command, "version")) {
        stdlib.debug.print("ZSON v0.1.0\n", .{});
    } else {
        try printUsage();
    }
}

fn printUsage() !void {
    const usage =
        \\ZSON - ZigScript Object Notation
        \\
        \\Usage:
        \\  zson format <file>      Format a ZSON file
        \\  zson validate <file>    Validate ZSON syntax
        \\  zson to-json <file>     Convert ZSON to strict JSON
        \\  zson version            Show version
        \\
        \\Example:
        \\  zson format config.zson
        \\
    ;
    stdlib.debug.print("{s}\n", .{usage});
}

fn formatFile(allocator: stdlib.mem.Allocator, filename: []const u8) !void {
    // Read file
    const source = try stdlib.fs.cwd().readFileAlloc(filename, allocator, stdlib.Io.Limit.limited(10 * 1024 * 1024));
    defer allocator.free(source);

    // Parse
    var value = zson.parse(allocator, source) catch |err| {
        stdlib.debug.print("Parse error: {}\n", .{err});
        return;
    };
    defer value.deinit(allocator);

    // Stringify with ZSON formatting
    const formatted = try zson.toZson(allocator, value, .{
        .indent = 2,
        .use_unquoted_keys = true,
        .use_trailing_commas = true,
    });
    defer allocator.free(formatted);

    // Print to stdout
    stdlib.debug.print("{s}\n", .{formatted});
}

fn validateFile(allocator: stdlib.mem.Allocator, filename: []const u8) !void {
    const source = try stdlib.fs.cwd().readFileAlloc(filename, allocator, stdlib.Io.Limit.limited(10 * 1024 * 1024));
    defer allocator.free(source);

    var value = zson.parse(allocator, source) catch |err| {
        stdlib.debug.print("❌ Invalid ZSON: {}\n", .{err});
        return;
    };
    defer value.deinit(allocator);

    stdlib.debug.print("✅ Valid ZSON\n", .{});
}

fn convertToJson(allocator: stdlib.mem.Allocator, filename: []const u8) !void {
    const source = try stdlib.fs.cwd().readFileAlloc(filename, allocator, stdlib.Io.Limit.limited(10 * 1024 * 1024));
    defer allocator.free(source);

    var value = zson.parse(allocator, source) catch |err| {
        stdlib.debug.print("Parse error: {}\n", .{err});
        return;
    };
    defer value.deinit(allocator);

    // Stringify as strict JSON
    const json = try zson.toJson(allocator, value);
    defer allocator.free(json);

    stdlib.debug.print("{s}\n", .{json});
}
