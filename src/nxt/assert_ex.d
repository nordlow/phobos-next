/** A Better assert.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	TODO: make these pure nothrow @safe @nogc by utilizing dynamic_array and printf

	extend to something like:

	- must!"a == b"(x, y);
	- check!"a == b"(x, y);
	- require!"a == b"(x, y);
*/
module nxt.assert_ex;

// import std.string : format;
import core.exception : AssertError;
import std.conv: to;

@trusted:

/// Returns: true if the expression throws.
bool assertThrows(T:Throwable = Exception, E)(lazy E expression,
											  string msg = T.stringof,
											  string file = __FILE__,
											  int line = __LINE__ ) {
	try {
		std.exception.assertThrown!T(expression, msg, file, line);
		return true;
	} catch (Throwable exc) {
		// FIXTHIS: unhelpful error message
		writeln("failed at ", baseName(file), "(", line, "):",
				" Did not throw \"", msg, "\".");
		return false;
	}
}

nothrow:

/** A Better assert.
	See_Also: http://poita.org/2012/09/02/a-better-assert-for-d.html?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+poita+%28poita.org%29
	TODO: Can we convert args to strings like GCC's __STRING(expression)?
	TODO: Make these be able to be called in unittest placed in struct scopes
*/
void assertTrue(T,
				string file = __FILE__, uint line = __LINE__,
				Args...) (T test, lazy Args args) {
	version (assert) if (!test) {
		throw new AssertError("at \n" ~file~ ":" ~to!string(line)~ ":\n  test: " ~to!string(test));
	}
}
alias assertT = assertTrue;

void assertEqual(T, U,
				 string file = __FILE__, uint line = __LINE__,
				 Args...)(T lhs, U rhs,
						  lazy Args args) /+ TODO: use args +/
{
	version (assert) if (lhs != rhs) {
		throw new AssertError("at \n" ~file~ ":" ~to!string(line)~ ":\n  lhs: " ~to!string(lhs)~ " !=\n  rhs: " ~to!string(rhs));
	}
}
alias assertE = assertEqual;

void assertLessThanOrEqual(T, U,
						   string file = __FILE__,
						   uint line = __LINE__,
						   Args...) (T lhs, U rhs,
									 lazy Args args) /+ TODO: use args +/
{
	version (assert) if (lhs > rhs) {
		throw new AssertError("at \n" ~file~ ":" ~to!string(line)~ ":\n  lhs: " ~to!string(lhs)~ " >\n  rhs: " ~to!string(rhs));
	}
}
alias assertLTE = assertLessThanOrEqual;

void assertLessThan(T, U,
					string file = __FILE__, uint line = __LINE__,
					Args...) (T lhs, U rhs,
							  lazy Args args) /+ TODO: use args +/
{
	version (assert) if (lhs >= rhs) {
		throw new AssertError("at \n" ~file~ ":" ~to!string(line)~ ":\n  lhs: " ~to!string(lhs)~ " >=\n  rhs: " ~to!string(rhs));
	}
}
alias assertLT = assertLessThan;

void assertNotEqual(T, U,
					string file = __FILE__, uint line = __LINE__,
					Args...) (T lhs, U rhs,
							  lazy Args args) /+ TODO: use args +/
{
	version (assert) if (lhs == rhs) {
		throw new AssertError("at \n" ~file~ ":" ~to!string(line)~ ":\n  lhs: " ~to!string(lhs)~ " ==\n  rhs: " ~to!string(rhs));
	}
}
alias assertNE = assertNotEqual;
