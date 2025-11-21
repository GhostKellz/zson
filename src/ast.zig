const std = @import("std");

pub const Value = union(enum) {
    object: Object,
    array: Array,
    string: []const u8,
    number: Number,
    boolean: bool,
    null_value,
    undefined_value,

    pub const Object = std.StringHashMap(Value);
    pub const Array = std.ArrayList(Value);

    pub const Number = union(enum) {
        integer: i64,
        float: f64,
        hex: u64,
        binary: u64,
    };

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .object => |*obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    // Free the key string
                    allocator.free(entry.key_ptr.*);
                    // Free the value recursively
                    var val = entry.value_ptr;
                    val.deinit(allocator);
                }
                obj.deinit();
            },
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit(allocator);
            },
            .string => |str| {
                allocator.free(str);
            },
            else => {},
        }
    }
};

pub const TypeHint = struct {
    name: []const u8,
};
