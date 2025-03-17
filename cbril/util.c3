module cbril;
import std::core::mem;
import std::core::test;

// Modifies original slice, cannot free the
// slice correctly after this.
macro void ordered_remove_slice(s, idx) {
	if (s.len == 0) return;
	if (idx >= 0 && idx < s.len) {
		// TODO could use copy or move.
		for (int i = idx + 1; i < s.len; i += 1) {
			(*s)[i - 1] = (*s)[i];
		}
		*s = (*s)[:s.len - 1];
	}
}

fn void test_slice_ordered_remove() @test {
	char[] s = mem::temp_array(char, 3);
	s[0] = 10;
	s[1] = 11;
	s[2] = 12;
	ordered_remove_slice(&s, 1);
	test::eq(s, (char[]){10, 12});
}
