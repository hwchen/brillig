package obril

//! A bril Program data structure

Program :: struct {
    functions: []Function,
}

Function :: struct {
    name:   string,
    args:   Maybe([]FunctionArg),
    type:   Maybe(Type),
    instrs: []Instruction,
}

FunctionArg :: struct {
    name: string,
    type: Type,
}

/// We don't add any additional structure to the deserialized instruction.
/// Decided it's not worth it in terms of additional code :) . And shouldn't
/// be particularly error-prone to differentiate between instructions.
///
/// Labels use the `label` field only
/// Instructions must have an `op` field.
/// `value` is a field only used for `const`
Instruction :: struct {
    // if label
    label:  Maybe(string),
    // if instr
    op:     Maybe(Op),
    dest:   Maybe(string),
    type:   Maybe(Type),
    args:   Maybe([]string),
    funcs:  Maybe([]string),
    labels: Maybe([]string),
    // for constant
    value:  Value, // unions have nil value
}

instruction_is_label :: proc(instr: Instruction) -> bool {
    _, ok := instr.label.?
    return ok
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

op_is_terminal :: proc(op: Op) -> bool {
    #partial switch op {
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
