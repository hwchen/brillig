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

pub fn genBasicBlocks(program: bril.Program, alloc: Allocator) !BasicBlocks {
    var blocks = ArrayList(Block).init(alloc);
    var blk_to_lbl = IntStringMap{};
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
                    try blk_to_lbl.map.put(alloc, blocks.items.len, lbl.label);
                    try lbl_to_blk.map.put(alloc, lbl.label, blocks.items.len);
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

pub const ControlFlowGraph = StringMap([]const []const u8);

pub fn controlFlowGraph(bb: BasicBlocks, alloc: Allocator) !ControlFlowGraph {
    var cfg = ControlFlowGraph{};
    const blks = bb.blocks;
    for (blks, 0..) |blk, blk_idx| {
        const blk_lbl = bb.blk_to_lbl.map.get(blk_idx) orelse try printLabel(alloc, blk_idx);
        var succs = StringMap(void){};
        for (blk, 0..) |instr, instr_idx| {
            switch (instr.op) {
                .ret => continue,
                .br, .jmp => {
                    for (instr.labels.?) |lbl| {
                        try succs.map.put(alloc, lbl, {});
                    }
                },
                .call => {
                    // Assume just one function called at a time?
                    const called_blk_idx = bb.fn_to_blk.map.get(instr.funcs.?[0]).?;
                    const lbl = bb.blk_to_lbl.map.get(called_blk_idx) orelse try printLabel(alloc, called_blk_idx);
                    try succs.map.put(alloc, lbl, {});
                },
                else => if (instr_idx >= blk.len - 1 and blk_idx < blks.len - 1) {
                    // last instruction in block, and is not the last block
                    const lbl = bb.blk_to_lbl.map.get(blk_idx + 1) orelse try printLabel(alloc, blk_idx + 1);
                    try succs.map.put(alloc, lbl, {});
                },
            }
        }
        try cfg.map.put(alloc, blk_lbl, succs.map.keys());
    }
    return cfg;
}

// given block index, print label
// Factored out in case I want to change label formatting easily.
// Don't forget that IntStringMap has a separate formatting for the label.
fn printLabel(alloc: Allocator, idx: usize) ![]const u8 {
    return try std.fmt.allocPrint(alloc, "{d}", .{idx});
}
