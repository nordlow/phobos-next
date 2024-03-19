module nxt.ties;

import std.typecons: tuple, Tuple;
import std.meta: staticMap;
import std.exception: enforce, assertThrown;

//version = chatty; // print stuff on stdout in unittests. comment this out to make them silent
version (chatty) import std.stdio;
alias pointerOf(T) = T*;
template sameTypes(Ts...)
{
	static if (Ts.length <= 1)
		enum sameTypes = true;
	else
		enum sameTypes = is(Ts[0] == Ts[1]) && sameTypes!(Ts[1 .. $]);
}

static assert(sameTypes!(int, int, int));
static assert(!sameTypes!(int, bool, int));
static assert(!sameTypes!(int, bool, string));

auto tie(Ts...)(ref Ts vars)
{
	struct Tie
	{
		staticMap!(pointerOf, Ts) pnts;

		this(ref Ts vars)
		{
			foreach (i, t; Ts)
			{
				pnts[i] = &vars[i];
			}
		}

		void opAssign( Tuple!Ts xs )
		{
			foreach (i, t; Ts)
			{
				*pnts[i] = xs[i];
			}
		}

		static if (sameTypes!Ts)
		{
			import std.conv : text;
			import std.range.primitives : front, popFront, ElementType, hasLength, empty, isInputRange;

			void opAssign(Ts[0][] xs) // redundant but more effective
			{
				enforce(xs.length == Ts.length,
						`tie(...) = ...: array must have ` ~ Ts.length.text ~ ` elements.`);
				foreach (i, t; Ts)
				{
					*pnts[i] = xs[i];
				}
			}

			void opAssign(R)(R xs) if (isInputRange!R &&
									   is(ElementType!R == Ts[0]))
			{
				static if (hasLength!R)
				{
					enforce(xs.length >= Ts.length, `tie(...) = ...: range must have at least ` ~ Ts.length.text ~ ` elements.`);
				}
				foreach (i, t; Ts)
				{
					enforce(!xs.empty, `tie(...) = ...: range must have at least ` ~ Ts.length.text ~ ` elements.`);
					*pnts[i] = xs.front;
					xs.popFront();
				}
			}

			void opIndexAssign(R)(R xs) if (isInputRange!R &&
											is(ElementType!R == Ts[0]))
			{
				foreach (i, t; Ts)
				{
					if (xs.empty) { return; }
					*pnts[i] = xs.front;
					xs.popFront();
				}
			}
		}
	}

	return Tie(vars);
}

@trusted R into(R, Ts...)(Tuple!Ts xs, scope R delegate(Ts) f)
{
	return f(xs.expand);
}

/** Destructured Tuple Assignment in Expression $(EXPR).

	Underscore variables are ignored.

	See_Also: http://forum.dlang.org/thread/hwuiieudmbdvixjejdvi@forum.dlang.org
 */
template let(string expr)
{
	mixin({
			import nxt.algorithm.searching : findSplitAmong;
			import std.string: indexOfAny, indexOfNeither;
			import std.ascii: whitespace;

			// skip whitespace
			enum wsSkip = expr.indexOfNeither(whitespace);

			enum expr_ = expr[wsSkip .. $];

			enum sym0EndIx = expr_.indexOfAny(whitespace ~ `,`);
			enum sym0 = expr_[0 .. sym0EndIx];

			static if (sym0 == `auto`)
			{
				enum qual = sym0;
				enum var0Ix = qual.length;
			}
			else static if (sym0 == `const`)
			{
				enum qual = sym0;
				enum var0Ix = qual.length;
			}
			else static if (sym0 == `immutable`)
			{
				enum qual = sym0;
				enum var0Ix = qual.length;
			}
			else
			{
				enum qual = ""; // variables must be defined previously
				enum var0Ix = 0;
			}

			enum split = expr_[var0Ix .. $].findSplitAmong!('=');

			mixin(`struct S { int ` ~ split[0] ~ `; }`);
			string code = `auto v = ` ~ split[2] ~ `;`; // the right-hand side of the assignment
			foreach (i, _; typeof(S.tupleof))
			{
				enum var = S.tupleof[i].stringof;
				static if (var != `_`) // ignore underscored
				{
					code ~= qual ~ ` ` ~ var ~ ` = v[` ~ i.stringof ~ `]; `;
				}
			}
			return code;
		}());
}

pure @safe nothrow @nogc unittest {
	import std.algorithm.searching: findSplit;
	mixin let!q{ auto c, _, d = `11-12`.findSplit(`-`) };
	assert(c == `11`);
	assert(d == `12`);
	static assert(__traits(compiles, c == c));
	static assert(!__traits(compiles, _ == _)); // assert that it was ignored
}

pure @safe nothrow @nogc unittest {
	import std.algorithm.searching: findSplit;
	mixin let!q{ auto c, _, d = `11-12`.findSplit(`-`) };
	assert(c == `11`);
	assert(d == `12`);
	static assert(__traits(compiles, c == c));
	static assert(!__traits(compiles, _ == _)); // assert that it was ignored
}

pure @safe nothrow @nogc unittest {
	mixin let!q{ auto i, d, s, c = tuple(42, 3.14, `pi`, 'x') };
	assert(i == 42);
	assert(d == 3.14);
	assert(s == `pi`);
	assert(c == 'x');
	static assert(is(typeof(i) == int));
	static assert(is(typeof(d) == double));
	static assert(is(typeof(s) == string));
	static assert(is(typeof(c) == char));
}

pure @safe nothrow @nogc unittest {
	mixin let!q{ const i, d, s, c = tuple(42, 3.14, `pi`, 'x') };
	assert(i == 42);
	assert(d == 3.14);
	assert(s == `pi`);
	assert(c == 'x');
	static assert(is(typeof(i) == const(int)));
	static assert(is(typeof(d) == const(double)));
	static assert(is(typeof(s) == const(string)));
	static assert(is(typeof(c) == const(char)));
}

pure @safe nothrow @nogc unittest {
	mixin let!q{ immutable i, d, s, c = tuple(42, 3.14, `pi`, 'x') };
	assert(i == 42);
	assert(d == 3.14);
	assert(s == `pi`);
	assert(c == 'x');
	static assert(is(typeof(i) == immutable(int)));
	static assert(is(typeof(d) == immutable(double)));
	static assert(is(typeof(s) == immutable(string)));
	static assert(is(typeof(c) == immutable(char)));
}

pure unittest {
	alias T = Tuple!(int, double, string, char);
	T f() { return tuple(42, 3.14, `pi`, 'x'); }
	int i;
	double d;
	string s;
	char ch;
	tie(i, d, s, ch) = f;
}

version (unittest)
@safe pure nothrow auto sampleTuple(int x)
{
	return tuple(x, `bottles`);
}

unittest {
	const x = q{1, 2};
	import std.stdio;
}

pure unittest						// with tuple
{
	int n; string what;
	tie(n, what) = sampleTuple(99);
	version (chatty) writeln(`n=`, n, ` what=`, what);
	assert(n == 99); assert(what == `bottles`);
	version (chatty) writeln(`tie(...) = tuple ok`);
}

pure unittest						// with array
{
	int n, k, i;
	tie(n, k, i) = [3,4,5];
	version (chatty) writeln(`n=`, n, ` k=`, k, ` i=`, i);
	assert(n == 3); assert(k == 4); assert(i == 5);

	assertThrown( tie(n, k, i) = [3,5] ); //throw if not enough data

	// tie(...)[] = ... uses available data and doesn't throw if there are not enough elements
	n = 1; k = 1; i = 1;
	tie(n, k, i)[] = [3,5];
	assert(n == 3); assert(k == 5); assert(i == 1);

	tie(n, k, i) = tuple(10, 20, 30);
	version (chatty) writeln(`n=`, n, ` k=`, k, ` i=`, i);
	assert(n == 10);
	assert(k == 20);
	assert(i == 30);
	version (chatty) writeln(`tie(...) = array ok`);
}

pure unittest						// with range
{
	import std.algorithm, std.conv;
	string[] argv = [`prog`, `100`, `200`];
	int x, y;
	tie(x,y) = argv[1..$].map!(to!int);
	version (chatty) writeln(`x=`, x, ` y=`, y);
	assert(x == 100);
	assert(y == 200);

	assertThrown( tie(x,y) = argv[2..$].map!(to!int) ); //throw if not enough data

	// tie(...)[] = ... uses available data and doesn't throw if there are not enough elements
	x = 1; y = 1;
	tie(x,y)[] = argv[2..$].map!(to!int);
	assert(x == 200);
	assert(y == 1);
	version (chatty) writeln(`tie(...) = range ok`);
}

@safe unittest						// into
{
	version (chatty) tuple(99, `bottles`).into( (int n, string s) => writeln(n, ` `, s) );
	const x = sampleTuple(10).into( (int n, string s) => n + s.length );
	assert(x == 17);
	version (chatty) writeln(`into ok`);
}
