const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringMap = std.json.ArrayHashMap; // Needed to get json serialization

const bril = @import("bril.zig");

const Block = []bril.Instruction;
const BasicBlocks = struct {
    blocks: []Block,
    // if there's no label, then the implied label is the index in blocks
    blk_to_lbl: IntStringMap,
    lbl_to_blk: StringMap(usize),
    fn_to_blk: StringMap(usize),
};
// thin wrapper, to make it serializable to json
const IntStringMap = struct {
    map: std.AutoHashMapUnmanaged(usize, []const u8) = std.AutoHashMapUnmanaged(usize, []const u8){},
    alloc: Allocator, // TODO a bit messy to have a managed hashmap but also carry an alloc

    pub fn jsonStringify(self: @This(), stream: anytype) !void {
        var value = StringMap([]const u8){};
        var it = self.map.iterator();
        while (it.next()) |entry| {
            const k = std.fmt.allocPrint(self.alloc, "{d}", .{entry.key_ptr.*}) catch return;
            value.map.put(self.alloc, k, entry.value_ptr.*) catch return;
        }
        try stream.write(value);
    }
};

pub fn genBasicBlocks(program: bril.Program, alloc: Allocator) !BasicBlocks {
    var blocks = ArrayList(Block).init(alloc);
    var blk_to_lbl = IntStringMap{ .alloc = alloc };
    var lbl_to_blk = StringMap(usize){};
    var fn_to_blk = StringMap(usize){};
    for (program.functions) |function| {
        var block = ArrayList(bril.Instruction).init(alloc);
        for (function.instrs, 0..) |code, code_idx| {
            if (code_idx == 0) try fn_to_blk.map.put(alloc, function.name, blocks.items.len);
            switch (code) {
                .Label => |lbl| {
                    // if label is at the first instruction, don't append the empty block
                    if (code_idx != 0) {
                        try blocks.append(try block.toOwnedSlice());
                        block = ArrayList(bril.Instruction).init(alloc);
                    }
                    try blk_to_lbl.map.put(alloc, blocks.items.len - 1, lbl.label);
                    try lbl_to_blk.map.put(alloc, lbl.label, blocks.items.len - 1);
                },
                .Instruction => |instr| {
                    // Don't need to generate label for block, it's just the index in blocks
                    try block.append(instr);
                    if (instr.op.isTerminal()) {
                        try blocks.append(try block.toOwnedSlice());
                        block = ArrayList(bril.Instruction).init(alloc);
                    }
                },
            }
        }
        // Don't append again if the last instruction was a terminal, which already appends block
        if (block.items.len != 0) try blocks.append(try block.toOwnedSlice());
    }

    return .{ .blocks = try blocks.toOwnedSlice(), .blk_to_lbl = blk_to_lbl, .lbl_to_blk = lbl_to_blk, .fn_to_blk = fn_to_blk };
}

//pub const ControlFlowGraph = StringMap([]const []const u8);
//
//pub fn controlFlowGraph(basic_blocks: BasicBlocks, alloc: Allocator) !ControlFlowGraph {
//    var cfg = ControlFlowGraph{};
//    const blk_labels = block_map.map.keys();
//    const blks = block_map.map.values();
//    for (0..block_map.map.count()) |blk_idx| {
//        const blk_label = blk_labels[blk_idx];
//        const blk = blks[blk_idx];
//        var succs = ArrayList([]const u8).init(alloc);
//        for (blk, 0..) |code, code_idx| {
//            switch (code) {
//                .Label => unreachable,
//                // Note that we can assume that instr.labels only exists on control ops w/ labels (jmp, br)
//                .Instruction => |instr| if (instr.op == .ret) continue else if (instr.labels) |instr_labels| {
//                    try succs.appendSlice(instr_labels);
//                } else if (code_idx >= blk.len - 1 and blk_idx <= blks.len) {
//                    // last instruction in block, and is not the last block
//                    try succs.append(try std.fmt.allocPrint(alloc, "{s}", .{blk_labels[blk_idx + 1]}));
//                },
//            }
//        }
//        try cfg.map.put(alloc, blk_label, try succs.toOwnedSlice());
//    }
//    return cfg;
//}
