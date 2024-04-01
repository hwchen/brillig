package brilo

ordered_remove_slice :: proc(s: ^$S/[]$E, i: int) {
    if s == nil {
        return
    }
    if i >= 0 && i < len(s) {
        copy(s[i:], s[i + 1:])
        s^ = s[:len(s) - 1]
    }
}
