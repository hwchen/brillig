module cbril::analysis;
import std::collections;
import std::core::string;
import cbril::bril;
import cbril::util;

const String BLOCK_INDEX_LABEL_FORMAT = "%d";

alias Block = Instruction[];
struct BasicBlocks {
	Block[] blocks;
	// if there's no label, then the implied label is the index in blocks
	HashMap{usz,String} blk_to_lbl;
	HashMap{String,usz} lbl_to_blk; 

	// Carried over from Function so we don't lose info when converting back.
	String name;
	Maybe{FunctionArg[]} args;
	Maybe{Type} type;
}
// For future lookups, not sure if we need a map of fn names to function blocks.
// fn name is already carried inside `BasicBlocks`, perhaps that's enough.
struct ProgramBasicBlocks {
	BasicBlocks[] functions;
}

fn Program basic_blocks2bril(Allocator alloc, ProgramBasicBlocks pbb) {
	List{Function} fns;
	@pool() {
		fns.tinit();
		foreach (bb : pbb.functions) {
			List{Instruction} instrs;
			@pool() {
				instrs.tinit();
				foreach (blk_idx, block : bb.blocks) {
					if (try label = bb.blk_to_lbl.get(blk_idx)) {
						instrs.push({ .label = maybe::value{String}(label) });
					}
					foreach (instr : block) {
						instrs.push(instr);
					}
				}
				fns.push({ .name = bb.name, .args = bb.args, .type = bb.type, .instrs = instrs.to_array(alloc)});
			};
		}
		return { .functions = fns.to_array(alloc) };
	};
}

fn ProgramBasicBlocks bril2basic_blocks(Allocator alloc, Program program) {
	List{BasicBlocks} fbb;
	@pool() {
		fbb.tinit();
		foreach (func : program.functions) {
			List{Block} blocks;
			blocks.tinit();
			HashMap{usz,String} blk_to_lbl;
			blk_to_lbl.init(alloc);
			HashMap{String,usz} lbl_to_blk;
			lbl_to_blk.init(alloc);
			List {Instruction} block;
			block.tinit();
			foreach (instr_idx, instr : func.instrs) {
				if (instr.is_label()) {
					String label = instr.label.get()!!;
					// if label comes after the first instruction, and if previous block ended in non-terminal
					// append the block before starting a new one.
					// If it's the first instruction, or block before label ended in a terminal, the previous
					// block will be empty.
					if (instr_idx != 0 && block.len() != 0) {
						blocks.push(block.to_array(alloc));
						block.clear();
					}
					blk_to_lbl.set(blocks.len(), label);
					lbl_to_blk.set(label, blocks.len());
				} else {
					// Don't need to generate label for block, it's just the index in blocks
					block.push(instr);
					if (instr.op.get()!!.is_terminal()) {
						blocks.push(block.to_array(alloc));
						block.clear();
					}
				}
			}
			// Don't append again if the last instruction was a terminal, which already appends block
			if (block.len() != 0 ) blocks.push(block.to_array(alloc));
			fbb.push((BasicBlocks){
				.blocks = blocks.to_array(alloc),
				.blk_to_lbl = blk_to_lbl,
				.lbl_to_blk = lbl_to_blk,
				.name = func.name,
				.args = func.args,
				.type = func.type,
			});
		}
		return { .functions = fbb.to_array(alloc) };
	};
}

alias ControlFlowGraph = HashMap{String,String[]};
alias ProgramControlFlowGraph = HashMap{String,ControlFlowGraph};

fn ProgramControlFlowGraph basic_blocks2control_flow_graph(Allocator alloc, ProgramBasicBlocks pbb) {
	ProgramControlFlowGraph pcfg;
	pcfg.init(alloc);
	foreach (bb : pbb.functions) {
		ControlFlowGraph cfg;
		cfg.init(alloc);
		Block[] blks = bb.blocks;
		foreach (blk_idx, blk : blks) {
			String blk_lbl = bb.blk_to_lbl[blk_idx] ?? string::tformat(BLOCK_INDEX_LABEL_FORMAT, blk_idx);
			Instruction last_instr = blk[^1];
			String[] succs;
			switch (last_instr.op.get()!!) {
			case JMP:
			case BR:
				succs = last_instr.labels.get()!!;
			case RET:
				succs = {};
			default:
				if (blk_idx < blks.len - 1) {
					// is not the last block
					String lbl = bb.blk_to_lbl[blk_idx + 1] ??
						string::tformat(BLOCK_INDEX_LABEL_FORMAT, blk_idx + 1);
					String[] out = allocator::new_array(alloc, String, 1);
					out[0] = lbl;
					succs = out;
				} else {
					succs = {};
				}
			}
			cfg[blk_lbl] = succs;
		}
		pcfg[bb.name] = cfg;
	}
	return pcfg;
}

// Currently operations on basic blocks are mutable.
// Since size of slices only decrease, shouldn't have to allocate.
fn void dead_code_elimination_globally_unused(ProgramBasicBlocks* pbb) {
	foreach (bb : pbb.functions) {
		bool converged = false;
		while (!converged) {
			converged = true;
			HashMap{String,char} used;
			@pool() {
				used.tinit();
				// First loop over all instrs, to collect set of used args
				foreach (b : bb.blocks) {
					foreach (instr : b) {
						if (try args = instr.args.get()) {
							foreach (arg : args) {
								used.set(arg, 0);
							}
						}
					}
				}
				// Second loop over instrs, if instr destination not in `used`, delete instr
				foreach (&instrs : bb.blocks) {
					usz i = instrs.len;
					while (i > 0) {
						i -= 1;
						if (try dest = (*instrs)[i].dest.get()) {
							if (!used.has_key(dest)) {
								util::ordered_remove_slice(&instrs, i);
								converged = false;
							}
						}
					}
				}
			};
		}
	}
}

fn void dead_code_elimination_locally_killed(ProgramBasicBlocks* pbb) {
	foreach (bb : pbb.functions) {
		foreach (&instrs : bb.blocks) {
			HashMap{String, char} declared;
			@pool() {
				declared.tinit();
				usz i = instrs.len;
				while (i > 0) {
					i -= 1;
					Instruction instr = (*instrs)[i];
					if (try args = instr.args.get()) {
						foreach (arg : args) {
							declared.remove(arg);
						}
					}
					if (try dest = instr.dest.get()) {
						if (declared.has_key(dest)) {
							util::ordered_remove_slice(&instrs, i);
						} else {
							declared.set(dest, 0);
						}
					}
				}
			};
		}
	}
}
