const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.json.ArrayHashMap; // Needed to get json serialization

const bril = @import("bril.zig");

const Block = []bril.Code;
const BasicBlocks = []Block;
const BlockMap = HashMap(Block);

// TODO handle funcs. (probably need a map of fn -> fnblocks)
pub fn basicBlocks(program: bril.Program, alloc: Allocator) !BasicBlocks {
    var blocks = ArrayList(Block).init(alloc);
    for (program.functions) |function| {
        var block = ArrayList(bril.Code).init(alloc);
        for (function.instrs) |code| {
            switch (code) {
                .Label => |_| {
                    try blocks.append(try block.toOwnedSlice());
                    block = ArrayList(bril.Code).init(alloc);
                    try block.append(code);
                },
                .Instruction => |instr| {
                    try block.append(code);
                    if (instr.op.isTerminal()) {
                        try blocks.append(try block.toOwnedSlice());
                        block = ArrayList(bril.Code).init(alloc);
                    }
                },
            }
        }
        // Don't append again if the last instruction was a terminal, which already appends block
        if (block.items.len != 0) {
            try blocks.append(try block.toOwnedSlice());
        }
    }

    return try blocks.toOwnedSlice();
}

pub fn blockMap(blocks: BasicBlocks, alloc: Allocator) !BlockMap {
    var block_map = BlockMap{};
    for (blocks, 0..) |block, i| {
        const first_code = block[0]; // Block cannot be empty
        switch (first_code) {
            .Label => |l| try block_map.map.put(alloc, l.label, block[1..]), // TODO slice to OwnedSlice ok?
            else => {
                const l = try std.fmt.allocPrint(alloc, "b{d:0>3}", .{i});
                try block_map.map.put(alloc, l, block);
            },
        }
    }
    return block_map;
}

pub const ControlFlowGraph = HashMap([]const []const u8);

pub fn controlFlowGraph(block_map: BlockMap, alloc: Allocator) !ControlFlowGraph {
    var cfg = ControlFlowGraph{};
    const blk_labels = block_map.map.keys();
    const blks = block_map.map.values();
    for (0..block_map.map.count()) |blk_idx| {
        const blk_label = blk_labels[blk_idx];
        const blk = blks[blk_idx];
        var succs = ArrayList([]const u8).init(alloc);
        for (blk, 0..) |code, code_idx| {
            switch (code) {
                .Label => unreachable,
                // Note that we can assume that instr.labels only exists on control ops w/ labels (jmp, br)
                .Instruction => |instr| if (instr.op == .ret) continue else if (instr.labels) |instr_labels| {
                    try succs.appendSlice(instr_labels);
                } else if (code_idx >= blk.len - 1 and blk_idx <= blks.len) {
                    // last instruction in block, and is not the last block
                    try succs.append(try std.fmt.allocPrint(alloc, "{s}", .{blk_labels[blk_idx + 1]}));
                },
            }
        }
        try cfg.map.put(alloc, blk_label, try succs.toOwnedSlice());
    }
    return cfg;
}
