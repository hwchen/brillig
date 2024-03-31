package bril

//! A bril Program data structure

Program :: struct {
    functions: []Function,
}

Function :: struct {
    name:   string,
    args:   []FunctionArg,
    type:   Maybe(Type),
    instrs: []Code,
}

FunctionArg :: struct {
    name: string,
    type: Type,
}

Code :: union {
    Instruction,
    Label,
}

Label :: struct {
    label: string,
}

Instruction :: struct {
    op:     Op,
    dest:   Maybe(string),
    type:   Maybe(Type),
    args:   Maybe([]string),
    funcs:  Maybe([]string),
    labels: Maybe([]string),
    value:  Maybe(Value), // for Constant
}

Value :: union {
    bool,
    int,
}

// odinfmt:disable
Op :: enum {
    add, mul, sub, div,
    eq, lt, gt, le, ge,
    not, and, or,
    jmp, br, call, ret,
    const, print,
    nop,
}
// odinfmt:enable

is_op_terminal :: proc(op: Op) -> bool {
    switch self {
    case .jmp, .br, .ret:
        return true
    case:
        return false
    }
}

Type :: enum {
    int,
    bool,
}
