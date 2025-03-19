module cbril;
import std::io;
import json;
import opter;

import cbril::bril;
import cbril::analysis;

fn int main(String[] args) {
	CliOpts cli_opts;
	if (catch err = parse_cli(&cli_opts, args)) {
		io::eprintfn("Cli error: %s", err);
		return 1;
	}

	ReadBuffer rdr;
	char[4096 * 8] rdr_buf;
	rdr.init(io::stdin(), &rdr_buf);

	char[4096 * 8] buf;
	ulong bytes_read;
	while (bytes_read < buf.len) {
		ulong? n_bytes = rdr.read(buf[bytes_read..]);
		if (catch err = n_bytes) {
			if (err == io::EOF) break;
			io::eprintfn("Error reading file");
			return 1;
		}
		if (n_bytes == 0) break;
		bytes_read += n_bytes;
	}

	Program? program_in = json::from_str(Program, mem, (String)buf[:bytes_read]);
	if (catch err = program_in) {
		io::eprintfn("Error deserializing program: %s", err);
		return 1;
	}

	ProgramBasicBlocks bb = analysis::bril2basic_blocks(tmem(), program_in);

	if (cli_opts.unoptimized) {
		Program program_out = analysis::basic_blocks2bril(tmem(), bb);
		write_json(program_out)!!;
	}

	ProgramControlFlowGraph cfg = analysis::basic_blocks2control_flow_graph(tmem(), bb);
	if (cli_opts.control_flow_graph) {
		write_json(cfg)!!;
	}

	//dead_code_elimination_globally_unused(&bb)
	//dead_code_elimination_locally_killed(&bb)
	//if cli_opts.dead_code_elimination {
	//	out := basic_blocks2bril(bb)
	//	write_json(out)
	//}
	return 0;
}

macro void? write_json(program_out) {
	String? out_json = json::to_json(program_out, tmem());
	if (catch err = out_json) {
		io::eprintfn("Error serializing program: %s", err);
		return err?;
	}
	io::printn(out_json);
}

struct CliOpts {
	bool unoptimized;
	bool control_flow_graph;
	bool dead_code_elimination;
}

fn void? parse_cli(CliOpts* opts, String[] args) {
	Opter opter;
	opter.init(args);

	while (try arg = opter.next()) {
		if (arg.type == EOF) break;
		switch {
			case arg.is(LONG, "unoptimized"):
				opts.unoptimized = true;
			case arg.is(LONG, "control-flow-graph"):
				opts.control_flow_graph = true;
			case arg.is(LONG, "dead-code-elimination"):
				opts.dead_code_elimination = true;
			default:
				return opter.err_unexpected_arg();
		}
	}
}
