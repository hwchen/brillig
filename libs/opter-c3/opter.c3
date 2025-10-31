// Basic lexer for cli options.
// Supports:
// - short opts
// - long opts
// - positional args
// - options with multiple arguments
// - -- marks the end of options
// - ' ' or = or (unseparated short) for opt-value separator
// - short -abc

// Footgun: it's easy to get confused between Arg.value and Opter.value()

// === Error Handling ===
//
// Opter is fairly simple, but will write a nice-ish error message before returning an error.
//
// Some basic value parsing (int, path) is currently implemented, and will automatically print a nice-ish error message.
//
// Open to suggestions for improved error handling API, as some might not want the automatic error message.
//
// Thought: I can store some data structure for error info, instead of just a string. Then when it's time to print the error message, user can either
// - print canned message, which would be lazily generated from the error data
// - use the error data to construct a custom message.
//
// This way, if user wants to create a custom message, they don't have to parse the error message. And this also is a good way to carry the error data in a sidecar, instead of trying to print the error message directly before bubbling up.

module opter;
import std::collections::list;
import std::core::string;
import std::io;

typedef Value = String;

struct Opter {
	String[] args;
	// index into args
	ulong idx_args;
	// index into the current arg
	// for multiple chars and non-space separator
	ulong idx_arg;
	// Allocator for error messages
	Allocator alloc;
	String err_msg;
}

fn void Opter.init(&opter, String[] args, Allocator alloc = mem) {
	opter.args = args;
	opter.idx_args = 1;
	opter.idx_arg = 0;
	opter.alloc = alloc;
	opter.err_msg = "";
}

fn Arg? Opter.next(&o) {
	// Valid end of args
	if (o.idx_args == o.args.len) return { .type = EOF };

	String curr_arg = o.args[o.idx_args];
	Arg arg;
	if (o.idx_arg == 0) {
		// At beginning of curr_arg
		switch {
			// LONG at beginning of arg
			case curr_arg.len >= 2 && curr_arg[0:2] == "--":
				// Valid end of args --
				if (curr_arg.len == 2) return { .type = EOF };
				arg.type = LONG;
				o.idx_arg = curr_arg.index_of_char('=') ?? curr_arg.len;
				// TODO disallow = directly after --?
				arg.long_name = curr_arg[2..o.idx_arg - 1];
				if (o.idx_arg == curr_arg.len) {
					o.idx_args += 1;
					o.idx_arg = 0;
				} else {
					o.idx_arg += 1;
				}

			// SHORT at beginning of arg
			// or VALUE if it's just a dash
			case curr_arg[0] == '-':
				if (curr_arg.len == 1) {
					nextcase default;
				}
				arg.type = SHORT;
				arg.short_name = curr_arg[1];
				if (curr_arg.len == 2) {
					o.idx_args += 1;
				} else if (curr_arg[2] == '=') {
					o.idx_arg += 3;
				} else {
					o.idx_arg += 2;
				}

			// VALUE at beginning of arg
			default:
				arg.type = VALUE;
				arg.value = (Value)curr_arg;
				o.idx_args += 1;
		}
	} else {
		// collected shorts in the middle of the arg
		// If user wants a value following a short, they should call 'value()'
		// There's one possible error here, it should be the only one in `next()`.

		// o.idx_arg == curr_arg.len should be unreachable; if was at end of an arg,
		// should have moved to the next
		assert(o.idx_arg < curr_arg.len);
		// TODO improve this error
		if (curr_arg[0:2] == "--") {
			o.err_custom_msg("attempted to parse a flag or positional argument, only values allowed afer '='")!;
		}
		// TODO `-=` is ok, but `-o=` is not
		arg.type = SHORT;
		arg.short_name = curr_arg[o.idx_arg];
		if (o.idx_arg == curr_arg.len - 1) {
			o.idx_args += 1;
			o.idx_arg = 0;
		} else {
			o.idx_arg += 1;
		}
	}
	return arg;
}

// Always reads to the end of the word. So things like
// -aone-btwo are read as "-a" "one-btwo" and not "-a" "one" "-b" "two"
fn Value? Opter.value(&o) {
	// Error if there's no more words to read.
	if (o.idx_args >= o.args.len) {
		o.err_missing_value()!;
	}

	// If in the middle of an arg, reads the rest of it.
	// If at the beginning reads the entire thing.
	String curr_arg = o.args[o.idx_args];
	String res = curr_arg[o.idx_arg..];
	o.idx_args += 1;
	o.idx_arg = 0;
	return (Value)res;
}

fn Value[]? Opter.values(&o, Allocator alloc = allocator::heap()) {
	@pool() {
		List{Value} values;
		values.tinit();
		// if called in middle of word, then return until the end of that word only.
		if (o.idx_arg != 0) {
			Value val = o.value()!!;
			values.push((Value)val);
			return values.to_array(alloc);
		}

		// returns all args until the end, or the next arg starts with '-'
		String curr_arg = o.args[o.idx_args];

		values.push((Value)curr_arg[o.idx_arg..]);
		o.idx_args += 1;
		o.idx_arg = 0;
		while (o.idx_args < o.args.len) {
			String curr_value = o.args[o.idx_args];
			// breaks on short or long flag
			if (curr_value[0] == '-') break;
			values.push((Value)curr_value);
			o.idx_args += 1;
		}
		return values.to_array(alloc);
	};
}

faultdef OPTER_ERROR;

// For use in error messages.
fn String Opter.last_processed_arg(&o) @private {
	if (o.idx_arg == 0) {
		return o.args[o.idx_args - 1];
	} else {
		return o.args[o.idx_args][:o.idx_arg];
	}
}

fn void? Opter.err_custom_msg(&o, String m) @private {
	String arg = o.last_processed_arg();
	DString msg;
	msg.init(allocator: o.alloc);
	msg.appendf("Error at \"%s\": %s", arg, m);
	o.err_msg = msg.str_view();
	return OPTER_ERROR?;
}

fn void? Opter.err_missing_value(&o) @private {
	String arg = o.last_processed_arg();
	DString msg;
	msg.init(allocator: o.alloc);
	msg.appendf("Missing value after argument \"%s\"", arg);
	o.err_msg = msg.str_view();
	return OPTER_ERROR?;
}

// User should call this in default case when switching on `Arg arg = parser.next()!`
fn void? Opter.err_unexpected_arg(&o) {
	String arg = o.last_processed_arg();
	DString msg;
	msg.init(allocator: o.alloc);
	msg.appendf("Found unexpected argument \"%s\"", arg);
	o.err_msg = msg.str_view();
	return OPTER_ERROR?;
}

// Currently used by users. But in future, Opter may handle parsing internally.
fn void? Opter.create_err_parse_value(&o, fault err) {
	String arg = o.last_processed_arg();
	DString msg;
	msg.init(allocator: o.alloc);
	msg.appendf("Error parsing argument \"%s\": %s", arg, err);
	o.err_msg = msg.str_view();
	return OPTER_ERROR?;
}

struct Arg {
	ArgType type;
	union {
		char short_name;
		String long_name;
		Value value;
	}
}

enum ArgType {
	EOF,
	SHORT,
	LONG,
	VALUE,
}

macro bool Arg.is(&arg, ArgType $type, ...) {
	$switch ($type):
		$case SHORT:
			$assert($vacount == 1);
			return arg.type == SHORT && $vaexpr[0] == arg.short_name;
		$case LONG:
			$assert($vacount == 1);
			return arg.type == LONG && $vaexpr[0] == arg.long_name;
		$case VALUE:
			$assert($vacount == 0);
			return arg.type == VALUE;
	$endswitch
}

fn String Value.as_str(value) {
	return (String)value;
}

fn Path? Value.as_path(value, Allocator alloc = allocator::heap(), PathEnv path_env = path::DEFAULT_ENV) {
	Path? path = path::new(alloc, (String)value, path_env);
	if (catch err = path) {
		io::fprintfn(io::stdout(), "Error parsing argument \"%s\": %s", value, err);
		return OPTER_ERROR?;
	}
	return path;
}

macro Value.as_int(value, $Type, int base = 10) {
	String s = (String)value;
	// calling to_integer twice is weird, working around some weirdness
	// where $Type! n = s.to_integer($Type, base); gives
	// `Error: It is not possible to cast from 'uint?' to 'uint'.` when called with uint
	if (catch err = s.to_integer($Type, base)) {
		io::fprintfn(io::stdout(), "Error parsing argument \"%s\": %s", value, err);
		return OPTER_ERROR?;
	}
	return s.to_integer($Type, base)!!;
}


// Tests

fn void assert_arg(Arg found, Arg expected) @private {
	assert(found.type == expected.type, "Found %s, expected %s", found.type, expected.type);
	switch (found.type) {
		case SHORT:
			assert(found.short_name == expected.short_name, "Found %c, expected %c", found.short_name, expected.short_name);
		case LONG:
			assert(found.long_name == expected.long_name, "Found %s, expected %s", found.long_name, expected.value);
		case VALUE:
			assert(found.value == expected.value, "Found %s, expected %s", found.value, expected.value);
		case EOF: // covered by assert on .type
	}
}

fn void test_short_no_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_no_value_calls_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	opter.init(input, allocator::temp());
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert(!@ok(opter.value()));
}

fn void test_short_with_value() @test {
	String[] input = { "test", "-n" "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!!.as_str() == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_with_value_no_separator() @test {
	String[] input = { "test", "-none"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!!.as_str() == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_with_value_eq_separator() @test {
	String[] input = { "test", "-n=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!!.as_str() == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_no_value() @test {
	String[] input = { "test", "--number" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "number" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_no_value_calls_value() @test {
	String[] input = { "test", "--foo" };
	Opter opter;
	opter.init(input, allocator::temp());
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert(!@ok(opter.value()));
}

fn void test_long_with_value() @test {
	String[] input = { "test", "--foo", "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert(opter.value()!!.as_str() == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_with_value_eq_separator() @test {
	String[] input = { "test", "--foo=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert(opter.value()!!.as_str() == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_positional() @test {
	String[] input = { "test", "thing" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = VALUE, .long_name = "thing" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_then_another() @test {
	String[] input = { "test", "-n", "-o"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'n' });
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'o' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_then_another() @test {
	String[] input = { "test", "--foo", "--bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "bar" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_positional_then_another() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = VALUE, .value = "foo" });
	assert_arg(opter.next()!!, (Arg) { .type = VALUE, .value = "bar" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_basic() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	@pool() {
		assert(opter.values(allocator::temp())!! == { "foo", "bar" });
	};
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_then_short() @test {
	String[] input = { "test", "foo", "bar", "-a" };
	Opter opter;
	opter.init(input);
	assert(opter.values(allocator::temp())!! == { "foo", "bar" });
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'a' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_then_long() @test {
	String[] input = { "test", "foo", "bar", "--baz" };
	Opter opter;
	opter.init(input);
	assert(opter.values(allocator::temp())!! == { "foo", "bar" });
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_values() @test {
	String[] input = { "test", "-f", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'f' });
	assert(opter.values(allocator::temp())!! == { "bar", "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_values() @test {
	String[] input = { "test", "--foo", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert(opter.values(allocator::temp())!! == { "bar", "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

// values can start in the middle of a word, but will only go to end of that word
fn void test_values_starting_condition() @test {
	String[] input = { "test", "-fbar", "baz", "one" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'f' });
	assert(opter.values(allocator::temp())!! == { "bar" });
}

fn void test_positional_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = VALUE, .value = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_end_mark() @test {
	String[] input = { "test", "-f", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'f' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_end_mark() @test {
	String[] input = { "test", "--foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_value_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.value()!!.as_str() == "foo");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.values(allocator::temp())!! == { "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_cluster() @test {
	String[] input = { "test", "-abc", "--foo" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'a' });
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'b' });
	assert_arg(opter.next()!!, (Arg) { .type = SHORT, .short_name = 'c' });
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_value_single_dash() @test {
	String[] input = { "test", "-" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = VALUE, .value = "-" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_value_as_path() @test {
	String[] input = { "test", "--path", "my-path" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, (Arg) { .type = LONG, .long_name = "path" });
	Path my_path = opter.value()!!.as_path(allocator::temp())!!;
	assert(my_path.str_view() == "my-path");
}
