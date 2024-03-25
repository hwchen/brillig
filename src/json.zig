//! Module for miscellaneous types (not bril program types) to have serde to json.
//! Json happens to be the easiest way to have a debug repr.

const std = @import("std");

// thin wrapper, to make it serializable to json
pub const IntStringMap = struct {
    map: std.AutoHashMapUnmanaged(usize, []const u8) = std.AutoHashMapUnmanaged(usize, []const u8){},

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        var buf: [32]u8 = undefined; //32 chars should be plenty for numeric label?
        try jws.beginObject();
        var it = self.map.iterator();
        while (it.next()) |kv| {
            const k = try std.fmt.bufPrint(&buf, "{d}", .{kv.key_ptr.*});
            try jws.objectField(k);
            try jws.write(kv.value_ptr.*);
        }
        try jws.endObject();
    }
};
