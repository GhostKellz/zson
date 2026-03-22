const std = @import("std");
const zson = @import("zson");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Parse command line arguments
    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_iter.deinit();

    // Skip program name
    _ = args_iter.next();

    const command = args_iter.next() orelse {
        printUsage();
        return;
    };

    if (std.mem.eql(u8, command, "format")) {
        const filename = args_iter.next() orelse {
            std.debug.print("Usage: zson format <file>\n", .{});
            return;
        };
        try formatFile(allocator, io, filename);
    } else if (std.mem.eql(u8, command, "validate")) {
        const filename = args_iter.next() orelse {
            std.debug.print("Usage: zson validate <file>\n", .{});
            return;
        };
        try validateFile(allocator, io, filename);
    } else if (std.mem.eql(u8, command, "to-json")) {
        const filename = args_iter.next() orelse {
            std.debug.print("Usage: zson to-json <file>\n", .{});
            return;
        };
        try convertToJson(allocator, io, filename);
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("ZSON v0.1.0\n", .{});
    } else {
        printUsage();
    }
}

fn printUsage() void {
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
    std.debug.print("{s}\n", .{usage});
}

fn formatFile(allocator: std.mem.Allocator, io: std.Io, filename: []const u8) !void {
    // Read file
    const source = try std.Io.Dir.cwd().readFileAlloc(io, filename, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(source);

    // Parse
    var value = zson.parse(allocator, source) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
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
    std.debug.print("{s}\n", .{formatted});
}

fn validateFile(allocator: std.mem.Allocator, io: std.Io, filename: []const u8) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(io, filename, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(source);

    var value = zson.parse(allocator, source) catch |err| {
        std.debug.print("Invalid ZSON: {}\n", .{err});
        return;
    };
    defer value.deinit(allocator);

    std.debug.print("Valid ZSON\n", .{});
}

fn convertToJson(allocator: std.mem.Allocator, io: std.Io, filename: []const u8) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(io, filename, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(source);

    var value = zson.parse(allocator, source) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    defer value.deinit(allocator);

    // Stringify as strict JSON
    const json = try zson.toJson(allocator, value);
    defer allocator.free(json);

    std.debug.print("{s}\n", .{json});
}
