package obril

//! A bril Program data structure

Program :: struct {
	functions: []Function,
}

Function :: struct {
	name:   string,
	args:   Maybe([]FunctionArg) `json:",omitempty"`,
	type:   Maybe(Type) `json:",omitempty"`,
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
	label:  Maybe(string) `json:",omitempty"`,
	// if instr
	op:     Maybe(Op) `json:",omitempty"`,
	dest:   Maybe(string) `json:",omitempty"`,
	type:   Maybe(Type) `json:",omitempty"`,
	args:   Maybe([]string) `json:",omitempty"`,
	funcs:  Maybe([]string) `json:",omitempty"`,
	labels: Maybe([]string) `json:",omitempty"`,
	// for constant
	value:  Value `json:",omitempty"`, // unions have nil value
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
