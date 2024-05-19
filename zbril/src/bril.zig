const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const Program = struct {
    functions: []Function,
};

pub const Function = struct {
    name: []const u8,
    args: ?[]const FunctionArg = null,
    type: ?Type = null,
    instrs: []Code,
};

pub const FunctionArg = struct {
    name: []const u8,
    type: Type,
};

pub const Code = union(enum) {
    instruction: Instruction,
    label: Label,

    pub fn jsonParse(alloc: Allocator, source: anytype, options: json.ParseOptions) !@This() {
        return try jsonParseFromValue(alloc, try json.innerParse(json.Value, alloc, source, options), options);
    }

    pub fn jsonParseFromValue(alloc: Allocator, source: json.Value, options: json.ParseOptions) !@This() {
        switch (source) {
            .object => |object| if (object.contains("label")) {
                const label = try json.innerParseFromValue(Label, alloc, source, options);
                return Code{ .label = label };
            } else {
                const instr = try json.innerParseFromValue(Instruction, alloc, source, options);
                return Code{ .instruction = instr };
            },
            else => return error.UnexpectedToken,
        }
    }

    pub fn jsonStringify(self: @This(), stream: anytype) !void {
        switch (self) {
            inline else => |value| try stream.write(value),
        }
    }
};

pub const Label = struct {
    label: []const u8,
};

pub const Instruction = struct {
    op: Op,
    dest: ?[]const u8 = null,
    type: ?Type = null,
    args: ?[][]const u8 = null,
    funcs: ?[][]const u8 = null,
    labels: ?[][]const u8 = null,
    value: ?Value = null, // for Constant
};

pub const Value = union(enum) {
    bool: bool,
    int: i64,

    pub fn jsonParse(alloc: Allocator, source: anytype, options: json.ParseOptions) !@This() {
        return try jsonParseFromValue(alloc, try json.innerParse(json.Value, alloc, source, options), options);
    }

    pub fn jsonParseFromValue(alloc: Allocator, source: json.Value, options: json.ParseOptions) !@This() {
        _ = alloc;
        _ = options;
        switch (source) {
            .bool => |b| return Value{ .bool = b },
            .integer => |i| return Value{ .int = i },
            else => return error.UnexpectedToken,
        }
    }

    pub fn jsonStringify(self: @This(), stream: anytype) !void {
        switch (self) {
            inline else => |value| try stream.write(value),
        }
    }
};

pub const Op = enum {
    // zig fmt: off
    add, mul, sub, div,
    eq, lt, gt, le, ge,
    not, @"and", @"or",
    jmp, br, call, ret,
    @"const", print,
    nop,
    // zig fmt: on

    pub fn isTerminal(self: Op) bool {
        return switch (self) {
            .jmp, .br, .ret => true,
            else => false,
        };
    }
};

pub const Type = enum {
    int,
    bool,
};
