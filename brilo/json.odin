package bril

JsonProgram :: struct {
    functions: []JsonFunction,
}

JsonFunction :: struct {
    name:   string,
    args:   Maybe([]string),
    type:   Maybe(string),
    instrs: []JsonLabelOrInstruction,
}

// odin json serde currently requires that we first parse into
// a more "raw" repr. for example, multiple struct variants in
// union wouldn't error on parse, so the first one is taken.
// And there's no way to insert a custom parse phase like in zig.
JsonLabelOrInstruction :: struct {
    // if label
    label:  Maybe(string),
    // if instr
    op:     Maybe(string),
    dest:   Maybe(string),
    type:   Maybe(string),
    args:   Maybe([]string),
    funcs:  Maybe([]string),
    labels: Maybe([]string),
}
