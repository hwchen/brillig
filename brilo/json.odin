package bril

Program :: struct {
    functions: []Function,
}

Function :: struct {
    name:   string,
    args:   []string,
    type:   Maybe(string),
    instrs: []LabelOrInstruction,
}

// this does not work with json unmarshaling,
// as neither struct will error, so the first always succeeds.
// (missing field does not create an error)
LabelOrInstruction :: union {
    Instruction,
    Label,
}

Label :: struct {
    label: string,
}

Instruction :: struct {
    op:     string,
    dest:   Maybe(string),
    type:   Maybe(string),
    args:   []string,
    funcs:  []string,
    labels: []string,
}
