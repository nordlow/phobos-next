module nxt.inplace_substitution;

import std.ascii : isASCII;

/** Returns: in-place substitution `from` by `to` in `source`. */
char[] substituteASCIIInPlace(char from, char to)(return scope char[] source) pure nothrow @safe @nogc
if (isASCII(from) &&
	isASCII(to))
{
	foreach (ref char ch; source)
		if (ch == from)
			ch = to;
	return source;
}

///
pure nothrow @safe @nogc unittest {
	const x = "_a_b_c_";
	char[7] y = x;
	y.substituteASCIIInPlace!('_', ' ');
	assert(y[] == " a b c ");
}
