const std = @import("std");
const json = @import("json.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Block = []json.Code;
const Blocks = []Block;

pub fn basicBlocks(program: json.Program, alloc: Allocator) !Blocks {
    var blocks = ArrayList(Block).init(alloc);
    for (program.functions) |function| {
        var block = ArrayList(json.Code).init(alloc);
        for (function.instrs) |code| {
            switch (code) {
                .Label => |_| {
                    try blocks.append(try block.toOwnedSlice());
                    block = ArrayList(json.Code).init(alloc);
                    try block.append(code);
                },
                .Instruction => |instr| {
                    try block.append(code);
                    // zig fmt: off
                    const is_terminal = mem.eql(u8, instr.op, "jmp")
                        or mem.eql(u8, instr.op, "br")
                        or mem.eql(u8, instr.op, "ret");
                    // zig fmt:on
                    if (is_terminal) {
                        try blocks.append(try block.toOwnedSlice());
                        block = ArrayList(json.Code).init(alloc);
                    }
                },
            }
        }
        try blocks.append(try block.toOwnedSlice());
    }
    return try blocks.toOwnedSlice();
}
