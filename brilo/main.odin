package brilo

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"

main :: proc() {
    context.logger = log.create_console_logger(.Info)

    cli_opts := parse_cli()

    buf: [4096]u8
    bytes_read, _ := os.read(os.stdin, buf[:])

    program_in: Program
    _jinerr := json.unmarshal(buf[:bytes_read], &program_in)

    bb := bril2basic_blocks(program_in)

    // unoptimized
    if cli_opts.unoptimized != 0 {
        program_out := basic_blocks2bril(bb)
        write_json(program_out)
    }
}

write_json :: proc(val: any) {
    j_out, _jout_err := json.marshal(val, {use_enum_names = true})
    fmt.print(transmute(string)j_out)
}

CliOpts :: struct {
    unoptimized: u8,
}

parse_cli :: proc() -> CliOpts {
    out: CliOpts
    for arg in os.args[1:] {
        if arg == "--unoptimized" {
            out.unoptimized += 1
        }
    }
    return out
}
