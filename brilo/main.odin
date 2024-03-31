package bril

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"

main :: proc() {
    context.logger = log.create_console_logger(.Info)

    buf: [4096]u8
    bytes_read, _ := os.read(os.stdin, buf[:])


    json_program: JsonProgram
    _jin_err := json.unmarshal(buf[:bytes_read], &json_program)
    j_out, _jout_err := json.marshal(json_program, {})
    fmt.print(transmute(string)j_out)
}
