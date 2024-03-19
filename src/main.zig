/// Note: for json parsing, missing fields need default values
///
const std = @import("std");
const json = @import("json.zig");
const analysis = @import("analysis.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const stdin = std.io.getStdIn();
    var in_buf_rdr = std.io.bufferedReader(stdin.reader());
    var r = in_buf_rdr.reader();
    var in_buf: [4096]u8 = undefined;
    const bytes_read = try r.readAll(&in_buf);
    const in_bytes = in_buf[0..bytes_read];
    const in_json = try std.json.parseFromSliceLeaky(json.Program, alloc, in_bytes, .{});

    const basic_blocks = try analysis.basicBlocks(in_json, alloc);
    const block_map = try analysis.blockMap(basic_blocks, alloc);

    const stdout = std.io.getStdOut();
    var out_buf_wtr = std.io.bufferedWriter(stdout.writer());
    const w = out_buf_wtr.writer();
    try std.json.stringify(block_map, .{ .emit_null_optional_fields = false }, w);
    try out_buf_wtr.flush();
}
