const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const stdin = std.io.getStdIn();
    var buf = std.io.bufferedReader(stdin.reader());
    var r = buf.reader();
    var in_buf: [4096]u8 = undefined;
    const bytes_read = try r.readAll(&in_buf);
    const in = in_buf[0..bytes_read];
    const bril_json = try std.json.parseFromSliceLeaky(Program, alloc, in, .{});
    std.debug.print("{s}", .{bril_json});
}

const Program = struct {
    functions: []Function,
};

const Function = struct {
    name: []const u8,
    args: []const []const u8,
    type: ?[]const u8,
    instrs: []LabelOrInstruction,
};

const LabelOrInstruction = union(enum) {
    Instruction: Instruction,
    Label: Label,
};

const Label = struct {
    label: []const u8,
};

const Instruction = struct {
    op: []const u8,
    dest: ?[]const u8,
    type: ?[]const u8,
    args: []const []const u8,
    funcs: []const []const u8,
    labels: []const []const u8,
};
