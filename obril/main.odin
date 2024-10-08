package obril

import "core:bufio"
import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:log"
import "core:os"

main :: proc() {
	context.logger = log.create_console_logger(.Info)

	cli_opts: CliOpts
	flags.parse_or_exit(&cli_opts, os.args, style = .Unix)

	rdr: bufio.Reader
	rdr_buf: [4096 * 8]u8
	bufio.reader_init_with_buf(&rdr, os.stream_from_handle(os.stdin), rdr_buf[:])

	buf: [4096]u8
	bytes_read := 0
	for bytes_read < len(buf) {
		n_bytes, _ := bufio.reader_read(&rdr, buf[bytes_read:])
		if n_bytes == 0 do break
		bytes_read += n_bytes
	}

	program_in: Program
	_jinerr := json.unmarshal(buf[:bytes_read], &program_in)

	bb := bril2basic_blocks(program_in)

	// unoptimized
	if cli_opts.unoptimized {
		program_out := basic_blocks2bril(bb)
		write_json(program_out)
	}

	cfg := basic_blocks2control_flow_graph(bb)
	if cli_opts.control_flow_graph {
		write_json(cfg)
	}

	dead_code_elimination_globally_unused(&bb)
	dead_code_elimination_locally_killed(&bb)
	if cli_opts.dead_code_elimination {
		out := basic_blocks2bril(bb)
		write_json(out)
	}
}

write_json :: proc(val: any) {
	j_out, _jout_err := json.marshal(val, {use_enum_names = true})
	fmt.print(transmute(string)j_out)
}

CliOpts :: struct {
	unoptimized:           bool `usage:"Unoptimized output"`,
	control_flow_graph:    bool `usage:"Control flow graph"`,
	dead_code_elimination: bool `usage:"Dead code elimination"`,
}
