module nxt.functional_ex;

import std.traits;
import std.conv;
import std.variant;

/** Pattern Matching.
	See_Also: http://forum.dlang.org/post/ijjthwfezebkszkzrcgt@forum.dlang.org
 */
auto ref match(Handlers...)(Variant v)
{
	foreach (Handler; Handlers)
	{
		alias P = Parameters!Handler;
		static if (P.length == 1)
		{
			static if (is(P[0] == CMatch!(_), _))
			{
				if (P[0].match(v))
					return Handler(P[0].init);
			}
			else
			{
				if (auto p = v.peek!(P[0]))
					return Handler(*p);
			}
		}
		else
		{
			return Handler();
		}
	}
	assert(0, "No matching pattern");
}

private struct CMatch(T...)
if (T.length == 1)
{
	alias U = typeof(T[0]);
	static bool match(Variant v)
	{
		if (auto p = v.peek!U)
			return *p == T[0];
		return false;
	}
}

///
unittest {
	Variant v = 5;
	string s = v.match!((CMatch!7) => "Lucky number seven",
						(int n)	=> "Not a lucky number: " ~ n.to!string,
						()		 => "No value found!");
	// import std.stdio;
	// writeln(s);
}

/** Turn the function what into a curried function.
 *
 * See_Also: https://stackoverflow.com/questions/58147381/template-for-currying-functions-in-d
 */
template autocurry(alias Fun)
if (isCallable!Fun)
{
	alias P = Parameters!Fun;
	static if (P.length)
	{
		auto autocurry(P[0] arg)
		{
			alias Remainder = P[1 .. $]; // remainder
			auto dg = delegate(Remainder args)
			{
				return Fun(arg, args);
			};
			static if (Remainder.length > 1)
				return &autocurry!dg;
			else
				return dg;
		}
	}
	else
	{
		alias autocurry = Fun;
	}
}

///
pure @safe unittest {
	static float foo(int a, string b, float c) pure nothrow @safe @nogc
		=> a + b.length + c;
	alias foo_ = autocurry!foo; // overloads the auto-curried foo with the original foo
	assert(foo_(52)("alpha")(1) == 58);
}
