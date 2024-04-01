package brilo

Block :: []Instruction
BasicBlocks :: struct {
    blocks:     []Block,
    // if there's no label, then the implied label is the index in blocks
    blk_to_lbl: map[int]string,
    lbl_to_blk: map[string]int,

    // Carried over from Function so we don't lose info when converting back.
    name:       string,
    args:       Maybe([]FunctionArg),
    type:       Maybe(Type),
}
ProgramBasicBlocks :: struct {
    functions: map[string]BasicBlocks,
}

basic_blocks2bril :: proc(pbb: ProgramBasicBlocks) -> Program {
    fns: [dynamic]Function
    pbb_fns := pbb.functions
    for _, bb in pbb_fns {
        instrs: [dynamic]Instruction
        for block, blk_idx in bb.blocks {
            if label, lok := bb.blk_to_lbl[blk_idx]; lok {
                append(&instrs, Instruction{label = label})
            }
            append(&instrs, ..block)
        }
        append(&fns, Function{name = bb.name, args = bb.args, type = bb.type, instrs = instrs[:]})
    }
    return Program{functions = fns[:]}
}

bril2basic_blocks :: proc(program: Program) -> ProgramBasicBlocks {
    fbb: map[string]BasicBlocks
    for func in program.functions {
        blocks: [dynamic]Block
        blk_to_lbl: map[int]string
        lbl_to_blk: map[string]int
        block: [dynamic]Instruction
        for instr, instr_idx in func.instrs {
            if instruction_is_label(instr) {
                // if label comes after the first instruction, and if previous block ended in non-terminal
                // append the block before starting a new one.
                // If it's the first instruction, or block before label ended in a terminal, the previous
                // block will be empty.
                if instr_idx != 0 && len(block) != 0 {
                    append(&blocks, block[:])
                    block = make([dynamic]Instruction)
                }
                blk_to_lbl[len(blocks)] = instr.label.?
                lbl_to_blk[instr.label.?] = len(blocks)
            } else {
                // Don't need to generate label for block, it's just the index in blocks
                append(&block, instr)
                if op_is_terminal(instr.op.?) {
                    append(&blocks, block[:])
                    block = make([dynamic]Instruction)
                }
            }
        }
        // Don't append again if the last instruction was a terminal, which already appends block
        if len(block) != 0 do append(&blocks, block[:])
        fbb[func.name] = BasicBlocks {
            blocks     = blocks[:],
            blk_to_lbl = blk_to_lbl,
            lbl_to_blk = lbl_to_blk,
            name       = func.name,
            args       = func.args,
            type       = func.type,
        }
    }
    return ProgramBasicBlocks{functions = fbb}
}
