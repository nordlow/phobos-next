module nxt.static_regex;

/** Statically defined regular expression.
 *
 * See_Also: https://forum.dlang.org/post/mailman.4770.1596218284.31109.digitalmars-d-announce@puremagic.com
 */
auto staticRegex(string reStr)()
{
	import std.regex : regex, Regex;
	static struct Impl
	{
	@safe:
		static typeof(return) re;
		static this()
		{
			re = regex(reStr);
		}
	}
	return Impl.re;
}

//
version (none)				   // disabled for now
@safe unittest {
	// string input;
	scope x = staticRegex!("foo(\\w+)bar");
	// auto result = input.replaceAll(x, `blah $1 bleh`);
}
