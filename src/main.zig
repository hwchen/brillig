/// Note: for json parsing, missing fields need default values
///
const std = @import("std");
const clap = @import("clap");

const bril = @import("bril.zig");
const analysis = @import("analysis.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Start set up CLI
    const params = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help and exit.
        \\--blocks              Display basic blocks, block map.
        \\--control-flow-graph Display control flow graph.
        \\--analyzed           Display final analyzed result.
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

    // io setup
    const stdin = std.io.getStdIn();
    var in_buf_rdr = std.io.bufferedReader(stdin.reader());
    var r = in_buf_rdr.reader();
    var in_buf: [4096]u8 = undefined;
    const bytes_read = try r.readAll(&in_buf);
    const in_bytes = in_buf[0..bytes_read];

    var jdiag = std.json.Diagnostics{};
    var jscanner = std.json.Scanner.initCompleteInput(alloc, in_bytes);
    jscanner.enableDiagnostics(&jdiag);
    const in_json = std.json.parseFromTokenSourceLeaky(bril.Program, alloc, &jscanner, .{}) catch |err| {
        std.debug.print("Error parsing json: {} at line {d} col {d}\n", .{ err, jdiag.getLine(), jdiag.getColumn() });
        return;
    };

    const stdout = std.io.getStdOut();
    const bwtr = std.io.bufferedWriter(stdout.writer());

    // blocks
    // output written immediately to be able to show at least some output in case of crash
    const basic_blocks = try analysis.genBasicBlocks(in_json, alloc);
    if (opts.args.blocks != 0) try writeJson(basic_blocks, bwtr);

    // cfg
    const cfg = try analysis.controlFlowGraph(basic_blocks, alloc);
    if (opts.args.@"control-flow-graph" != 0) try writeJson(cfg, bwtr);
    if (opts.args.graphviz != 0) try writeGraphviz(cfg, bwtr);
}

// bw: buffered writer
// flushes immediately
fn writeGraphviz(pcfg: analysis.ProgramControlFlowGraph, bwtr: anytype) !void {
    var bw = bwtr;
    const w = bw.writer();
    try w.print("digraph cfg {{\n", .{});
    for (pcfg.map.keys(), pcfg.map.values()) |fn_name, cfg| {
        for (cfg.map.keys()) |label| {
            try w.print("  \"{s}::{s}\";\n", .{ fn_name, label });
        }

        for (cfg.map.keys(), cfg.map.values()) |label, succs| {
            for (succs) |succ| {
                try w.print("  \"{s}::{s}\" -> \"{s}::{s}\";\n", .{ fn_name, label, fn_name, succ });
            }
        }
    }
    try w.print("}}\n", .{});
    try bw.flush();
}

// bwtr: buffered writer
// flushes immediately
fn writeJson(v: anytype, bwtr: anytype) !void {
    var bw = bwtr; // TODO is there a way to avoid this reassignment? Should I pass by pointer?
    const w = bw.writer();
    try std.json.stringify(v, .{ .emit_null_optional_fields = false }, w);
    _ = try w.write("\n");
    try bw.flush();
}
