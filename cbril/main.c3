module cbril;
import std::io;
import bril;
import json;

fn int main(String[] args) {
	//context.logger = log.create_console_logger(.Info)

	//cli_opts: CliOpts
	//flags.parse_or_exit(&cli_opts, os.args, style = .Unix)

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

	Program? program = json::from_str(Program, mem, (String)buf[:bytes_read]);
	if (catch err = program) {
		io::eprintfn("Error deserializing program: %s", err);
		return 1;
	}
	String? out_json = json::to_json(program, tmem());
	if (catch err = out_json) {
		io::eprintfn("Error serializing program: %s", err);
		return 1;
	}
	io::printn(out_json);

	//bb := bril2basic_blocks(program_in)

	//if cli_opts.unoptimized {
	//	program_out := basic_blocks2bril(bb)
	//	write_json(program_out)
	//}

	//cfg := basic_blocks2control_flow_graph(bb)
	//if cli_opts.control_flow_graph {
	//	write_json(cfg)
	//}

	//dead_code_elimination_globally_unused(&bb)
	//dead_code_elimination_locally_killed(&bb)
	//if cli_opts.dead_code_elimination {
	//	out := basic_blocks2bril(bb)
	//	write_json(out)
	//}
	return 0;
}

//CliOpts :: struct {
//	unoptimized:           bool `usage:"Unoptimized output"`,
//	control_flow_graph:    bool `usage:"Control flow graph"`,
//	dead_code_elimination: bool `usage:"Dead code elimination"`,
//}
