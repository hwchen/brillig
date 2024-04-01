package brilo

import "core:fmt"

BLOCK_INDEX_LABEL_FORMAT := "%d"

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
// For future lookups, not sure if we need a map of fn names to function blocks.
// fn name is already carried inside `BasicBlocks`, perhaps that's enough.
ProgramBasicBlocks :: struct {
    functions: []BasicBlocks,
}

basic_blocks2bril :: proc(pbb: ProgramBasicBlocks) -> Program {
    fns: [dynamic]Function
    for bb in pbb.functions {
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
    fbb: [dynamic]BasicBlocks
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
        append(
            &fbb,
            BasicBlocks {
                blocks = blocks[:],
                blk_to_lbl = blk_to_lbl,
                lbl_to_blk = lbl_to_blk,
                name = func.name,
                args = func.args,
                type = func.type,
            },
        )
    }
    return ProgramBasicBlocks{functions = fbb[:]}
}

ControlFlowGraph :: map[string][]string
ProgramControlFlowGraph :: map[string]ControlFlowGraph

basic_blocks2control_flow_graph :: proc(pbb: ProgramBasicBlocks) -> ProgramControlFlowGraph {
    pcfg: ProgramControlFlowGraph
    for bb in pbb.functions {
        cfg: ControlFlowGraph
        blks := bb.blocks
        for blk, blk_idx in blks {
            blk_lbl :=
                bb.blk_to_lbl[blk_idx] or_else fmt.aprintf(BLOCK_INDEX_LABEL_FORMAT, blk_idx)
            last_instr := blk[len(blk) - 1]
            succs: []string
            switch last_instr.op {
            case .jmp, .br:
                succs = last_instr.labels.?
            case .ret:
                succs = {}
            case:
                if (blk_idx < len(blks) - 1) {
                    // is not the last block
                    lbl :=
                        bb.blk_to_lbl[blk_idx + 1] or_else fmt.aprintf(
                            BLOCK_INDEX_LABEL_FORMAT,
                            blk_idx + 1,
                        )
                    out := make([]string, 1)
                    out[0] = lbl
                    succs = out
                } else {succs = {}}
            }
            cfg[blk_lbl] = succs
        }
        pcfg[bb.name] = cfg
    }
    return pcfg
}

// Currently operations on basic blocks are mutable.
// Since size of slices only decrease, shouldn't have to allocate.
dead_code_elimination_globally_unused :: proc(pbb: ^ProgramBasicBlocks) {
    for bb in pbb.functions {
        converged := false
        for !converged {
            converged = true
            used := make(map[string]struct {}, allocator = context.temp_allocator)
            defer free_all(context.temp_allocator)
            // First loop over all instrs, to collect set of used args
            for b in bb.blocks {
                for instr in b {
                    if args, aok := instr.args.?; aok {
                        for arg in args {
                            used[arg] = {}
                        }
                    }
                }
            }
            // Second loop over instrs, if instr destination not in `used`, delete instr
            for &instrs in bb.blocks {
                i := len(instrs)
                for i > 0 {
                    i -= 1
                    if dest, dok := instrs[i].dest.?; dok {
                        if !(dest in used) {
                            ordered_remove_slice(&instrs, i)
                            converged = false
                        }
                    }
                }
            }
        }
    }
}

dead_code_elimination_locally_killed :: proc(pbb: ^ProgramBasicBlocks) {
    for bb in pbb.functions {
        for &instrs in bb.blocks {
            declared := make(map[string]struct {}, allocator = context.temp_allocator)
            defer free_all(context.temp_allocator)
            i := len(instrs)
            for i > 0 {
                i -= 1
                instr := instrs[i]
                if args, aok := instr.args.?; aok {
                    for arg in args {
                        delete_key(&declared, arg)
                    }
                }
                if dest, dok := instr.dest.?; dok {
                    if dest in declared {
                        ordered_remove_slice(&instrs, i)
                    } else {
                        declared[dest] = {}
                    }
                }
            }
        }
    }
}
