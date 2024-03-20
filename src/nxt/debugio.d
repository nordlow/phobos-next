/** Various debug printing tools for debug printing in `pure nothrow @safe @nogc` code.
 *
 * Copyright: Per Nordlöw 2022-.
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB Per Nordlöw)
 *
 * See_Also: https://forum.dlang.org/post/svjjawiezudnugdyriig@forum.dlang.org
 */
module nxt.debugio;

public import nxt.stdio : Format;

@safe pure:

/** Debug print `args` followed by a newline.
 *
 * See_Also: https://forum.dlang.org/post/ypxsqtddxvdxunsoluas@forum.dlang.org
 * See_Also: https://dlang.org/changelog/2.079.0.html#default_after_variadic
 *
 * See_Also: https://doc.rust-lang.org/std/macro.dbg.html
 * See_Also: https://blog.rust-lang.org/2019/01/17/Rust-1.32.0.html#the-dbg-macro
 * See_Also: https://forum.dlang.org/post/svjjawiezudnugdyriig@forum.dlang.org
 * See_Also: http://forum.dlang.org/thread/yczwqrbkxdiqijtiynrh@forum.dlang.org?page=1
 */
void dbg(Args...)(scope auto ref Args args, in string file = __FILE_FULL_PATH__, in uint line = __LINE__) {
	import nxt.stdio : pwriteln;
	debug pwriteln(Format.debugging, file, "(", line, "):", " Debug: ", args, "");
	debug _fflush(); // most often what we want before a potentially crash happens
}

void pdbg(Args...)(in Format fmt, scope auto ref Args args, in string file = __FILE_FULL_PATH__, in uint line = __LINE__) {
	import nxt.stdio : pwriteln;
	debug pwriteln(fmt, file, "(", line, "):", " Debug: ", args, "");
	debug _fflush(); // most often what we want before a potentially crash happens
}

void dbgf(Args...)(scope Args args, const string file = __FILE_FULL_PATH__, in uint line = __LINE__, const string fun = __FUNCTION__) {
	import nxt.stdio : pwriteln;
	debug pwriteln(Format.debugging, file, "(", line, "): ", fun, ": Debug: ", args, "");
	debug _fflush(); // most often what we want before a potentially crash happens
}

private void _fflush() @trusted {
	import core.stdc.stdio : stdout, fflush;
	debug fflush(stdout);
}

///
pure nothrow @safe @nogc unittest {
	static assert(__traits(compiles, { dbg(); })); // ok for dln to discard function qualifiers
}

enum DumpFormat {
	dmd,
	rust,
	/+ TODO: gcc, +/
}

/** Debug dump arguments `args` to standard error (`stderr`).
 *
 * See_Also: https://forum.dlang.org/post/myxzyfgtcewixwbhvalp@forum.dlang.org
 */
template dump(args...) {
	enum fmt = DumpFormat.dmd;
	static if (fmt == DumpFormat.dmd)
		static immutable header = "%s(%s,1): Debug: [%s]: ";
	else static if (fmt == DumpFormat.rust)
		static immutable header = "[%s:%s (%s)] ";
	import std.traits : isBuiltinType, isAggregateType, FieldNameTuple, isSomeString, isSomeChar;
	private void dump(string file = __FILE__, uint line = __LINE__, string fun = __FUNCTION__) {
		debug static foreach (arg; args) {{
			alias Arg = typeof(arg);
			static if (isBuiltinType!(Arg)) {
				static immutable isString = isSomeString!Arg;
				static immutable isChar = isSomeChar!Arg;
				static immutable wrap = isString ? `"` : isChar ? `'` : ``;
				stderr.writefln(header ~ "%s: %s%s%s [%s]",
								file, line, fun,
								__traits(identifier, arg),
								wrap, arg, wrap,
								Arg.stringof);
			}
			else static if (isAggregateType!(Arg)) {
				/+ TODO: alias this? +/
				stderr.writefln(header ~ "%s: { %s } [%s]",
								file, line, fun,
								__traits(identifier, arg),
								toDbgString(arg),
								Arg.stringof);
			}
		}}
	}
	private string toDbgString(Arg)(Arg o) {
		string result;
		import std.format;
		static foreach (f; FieldNameTuple!(typeof(o))) {
			{
				alias Member = typeof(__traits(getMember, o, f));
				static if (isBuiltinType!(Member))
					result ~= format("%s:%s [%s], ",
									 f, __traits(getMember, o, f),
									 Member.stringof); /+ TODO: avoid ~ +/
				else static if (isAggregateType!(Member))
					result ~= format("%s = %s [%s], ",
									 f, toDbgString(__traits(getMember, o, f)),
									 Member.stringof); // TOOD: avoid ~
			}
		}
		return result[0..$-2];
	}
}

///
version (none)
pure @safe unittest {
	struct Bar { auto c = 'c';}
	struct Foo { int s = 2; bool b = false; Bar bar;}
	class FooBar { int t; Foo f; }

	int i;
	float f = 3.14;
	char c = 'D';
	string s = "some string";
	Foo foo;
	Bar bar;

	dump!(i, c, f, s, foo, 1+3, foo, bar); /+ TODO: don’t print variable name for `1+3` +/
}
