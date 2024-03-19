module nxt.byline;

/** Type of NewLine Encoding.
 */
enum Newline
{
	any,						// Any of win, mac or unix
	win,						// Windows: "\r\n"
	mac,						// Mac OS: '\r'
	unix,					   // UNIX/Linux: '\n'
	native,					 // Current OS decides: '\n'
}

/** Split Input by line.
 *
 * See_Also: http://forum.dlang.org/thread/fjqpdfzmitcxxzpwlbgb@forum.dlang.org#post-rwxrytxqqurrazifugje:40forum.dlang.org
 *
 * TODO: This should fail with better error message:
 * assert(equal((cast(ubyte[])"a\nb").byLine!(Newline.any), ["a", "b"]));
 */
auto byLine(Newline nl = Newline.any, Range)(Range input)
if (is(typeof(Range.init[0 .. 0])) && // can be sliced
	is(typeof(Range.init[0]) : char)) {
	import nxt.splitter_ex : splitterASCIIAmong;
	static if (nl == Newline.native) {
		version (Windows)
			return input.splitterASCIIAmong!('\r', '\n');
		else version (Posix)
			return input.splitterASCIIAmong!('\n');
		else
			static assert(0, "Neither on Windows nor Posix!");
	}
	else
	{
		static if (nl == Newline.unix)
			return input.splitterASCIIAmong!('\n');
		else static if (nl == Newline.win)
			return input.splitterASCIIAmong!('\r', '\n');
		else static if (nl == Newline.mac)
			return input.splitterASCIIAmong!('\r');
		else static if (nl == Newline.any)
			return input.splitterASCIIAmong!('\r', '\n');
		else
			static assert(0, "Handle Newline." ~ nl.stringof);
	}
}

///
pure nothrow @safe @nogc unittest {
	import std.algorithm.comparison: equal;
	assert(equal("a\nb".byLine!(Newline.native), ["a", "b"].s[]));
	assert(equal("a\r\nb".byLine!(Newline.win), ["a", "b"].s[]));
	assert(equal("a\rb".byLine!(Newline.mac), ["a", "b"].s[]));
	assert(equal("a\nb".byLine!(Newline.unix), ["a", "b"].s[]));
	assert(equal("a\nb".byLine!(Newline.any), ["a", "b"].s[]));
}

version (unittest) {
	import nxt.array_help : s;
}
