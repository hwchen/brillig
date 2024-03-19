/// Note: for json parsing, missing fields need default values
///
const std = @import("std");
const clap = @import("clap");

const json = @import("json.zig");
const analysis = @import("analysis.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Start set up CLI
    const params = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help and exit.
        \\--input              Display input bril.
        \\--analyzed           Display final analyzed result.
        \\--block-map          Display mapping of label to block.
        \\--control-flow-graph Display control flow graph.
        \\--graphviz           Write graphviz file to stdout.
    );

    var diag = clap.Diagnostic{};
    var opts = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = alloc,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer opts.deinit();
    if (opts.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    // End set up CLI

    const stdin = std.io.getStdIn();
    var in_buf_rdr = std.io.bufferedReader(stdin.reader());
    var r = in_buf_rdr.reader();
    var in_buf: [4096]u8 = undefined;
    const bytes_read = try r.readAll(&in_buf);
    const in_bytes = in_buf[0..bytes_read];
    const in_json = try std.json.parseFromSliceLeaky(json.Program, alloc, in_bytes, .{});

    const basic_blocks = try analysis.basicBlocks(in_json, alloc);
    const block_map = try analysis.blockMap(basic_blocks, alloc);
    const cfg = try analysis.controlFlowGraph(block_map, alloc);

    const stdout = std.io.getStdOut();
    var out_buf_wtr = std.io.bufferedWriter(stdout.writer());
    const w = out_buf_wtr.writer();

    if (opts.args.input != 0) {
        try std.json.stringify(in_json, .{ .emit_null_optional_fields = false }, w);
        _ = try w.write("\n");
    }
    if (opts.args.analyzed != 0) {
        // currently in_json, but should be changed to output of final analyzed result
        try std.json.stringify(in_json, .{ .emit_null_optional_fields = false }, w);
        _ = try w.write("\n");
    }
    if (opts.args.@"block-map" != 0) {
        try std.json.stringify(block_map, .{ .emit_null_optional_fields = false }, w);
        _ = try w.write("\n");
    }
    if (opts.args.@"control-flow-graph" != 0) {
        try std.json.stringify(cfg, .{ .emit_null_optional_fields = false }, w);
        _ = try w.write("\n");
    }
    if (opts.args.graphviz != 0) {
        try writeGraphviz(cfg, w);
        _ = try w.write("\n");
    }

    try out_buf_wtr.flush();
}

// w: Writer
fn writeGraphviz(cfg: analysis.ControlFlowGraph, w: anytype) !void {
    try w.print("digraph cfg {{\n", .{});
    for (cfg.map.keys()) |label| {
        try w.print("  {s};\n", .{label});
    }

    var it = cfg.map.iterator();
    while (it.next()) |kv| {
        const label = kv.key_ptr.*;
        const succs = kv.value_ptr.*;
        for (succs) |succ| {
            try w.print("  {s} -> {s};\n", .{ label, succ });
        }
    }
    try w.print("}}", .{});
}
