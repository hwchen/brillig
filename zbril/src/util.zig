const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

// To make sure that block index labels are always formatted the same.
pub const BLOCK_INDEX_LABEL_FORMAT = "{d}";

// thin wrapper, to make it serializable to json
pub const IntStringMap = struct {
    map: std.AutoHashMapUnmanaged(usize, []const u8) = std.AutoHashMapUnmanaged(usize, []const u8){},

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        var buf: [32]u8 = undefined; //32 chars should be plenty for numeric label?
        try jws.beginObject();
        var it = self.map.iterator();
        while (it.next()) |kv| {
            const k = try fmt.bufPrint(&buf, BLOCK_INDEX_LABEL_FORMAT, .{kv.key_ptr.*});
            try jws.objectField(k);
            try jws.write(kv.value_ptr.*);
        }
        try jws.endObject();
    }
};

pub fn orderedRemoveSlice(comptime T: type, s: *[]T, i: usize) void {
    if (s.len == 0) {
        return;
    }
    if (i >= 0 and i < s.len) {
        mem.copyForwards(T, s.*[i..], s.*[i + 1 ..]);
        s.* = s.*[0 .. s.len - 1];
    }
}
