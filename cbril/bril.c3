module cbril::bril;
import std::collections::maybe;
import json;

// A bril Program data structure

struct Program {
	Function[] functions;
}

struct Function {
	String name;
	Maybe{FunctionArg[]} args @tag("json", "skip_empty");
	Maybe{Type} type          @tag("json", "skip_empty");
	Instruction[] instrs;
}

struct FunctionArg {
	String name;
	Type type;
}

/// We don't add any additional structure to the deserialized instruction.
/// Decided it's not worth it in terms of additional code :) . And shouldn't
/// be particularly error-prone to differentiate between instructions.
///
/// Labels use the `label` field only
/// Instructions must have an `op` field.
/// `value` is a field only used for `const`
struct Instruction {
	// if label
	Maybe{String}   label  @tag("json", "skip_empty");
	// if instr
	Maybe{Op}       op     @tag("json", "skip_empty");
	Maybe{String}   dest   @tag("json", "skip_empty");
	Maybe{Type}     type   @tag("json", "skip_empty");
	Maybe{String[]} args   @tag("json", "skip_empty");
	Maybe{String[]} funcs  @tag("json", "skip_empty");
	Maybe{String[]} labels @tag("json", "skip_empty");
	// for constant
	// TODO start here
	Maybe{Value}    value  @tag("json", "skip_empty");
}

fn bool Instruction.is_label(&self) {
	return self.label.has_value;
}

struct Value {
	Type type;
	union {
		bool boolean;
		int integer;
	}
}

fn void? Value.parse_json(&self, Allocator alloc, Lexer* lex) {
	switch (lex.next()!!) {
		case TRUE:
			self.type = BOOL;
			self.boolean = true;
		case FALSE:
			self.type = BOOL;
			self.boolean = false;
		case NUM:
			self.type = INT;
			self.integer = ((String)lex.token_slice).to_int()!!;
		default:
			return deserialize::PARSE_ERROR?;
	}
}

fn void? Value.to_json(&self, DString* dest) {
	switch (self.type) {
		case BOOL:
			serialize::add_json(self.boolean, dest)!;
		case INT:
			serialize::add_json(self.integer, dest)!;
	}
}

enum Type : char (String json_repr){
	BOOL = "bool",
	INT = "int",
}

enum Op : char (String json_repr) {
	ADD = "add", MUL = "mul", SUB = "sub", DIV = "div",
	EQ = "eq", LT = "lt", GT = "gt", LE = "le", GE = "ge",
	NOT = "not", AND = "and", OR = "or",
	JMP = "jmp", BR = "br", CALL = "call", RET = "ret",
	CONST = "const", PRINT = "print",
	NOP = "nop",
}

fn bool Op.is_terminal(op) {
	switch (op) {
		case JMP:
		case BR:
		case RET:
			return true;
		default:
			return false;
	}
}
