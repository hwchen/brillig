package brilo

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"

main :: proc() {
    context.logger = log.create_console_logger(.Info)

    buf: [4096]u8
    bytes_read, _ := os.read(os.stdin, buf[:])

    program_in: Program
    _jinerr := json.unmarshal(buf[:bytes_read], &program_in)

    bb := bril2basic_blocks(program_in)

    program_out := basic_blocks2bril(bb)
    write_json(program_out)
}

write_json :: proc(val: any) {
    j_out, _jout_err := json.marshal(val, {use_enum_names = true})
    fmt.print(transmute(string)j_out)
}
