module nxt.assuming;

import std.traits : isFunctionPointer, isDelegate, functionAttributes, FunctionAttribute, SetFunctionAttributes, functionLinkage;

/**
   * See_Also: http://forum.dlang.org/post/nq4eol$2h34$1@digitalmars.com
   * See_Also: https://dpaste.dzfl.pl/8c5ec90c5b39
   */
void assumeNogc(alias fun, T...)(T xs) @nogc {
	static auto assumeNogcPtr(T)(T f)
	if (isFunctionPointer!T || isDelegate!T) {
		enum attrs = functionAttributes!T | FunctionAttribute.nogc;
		return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) f;
	}
	assumeNogcPtr(&fun!T)(xs);
}

/** Return `T` assumed to be `pure`.
 *
 * Copied from: https://dlang.org/phobos/std_traits.html#SetFunctionAttributes.
 * See_Also: https://forum.dlang.org/post/hmucolyghbomttqpsili@forum.dlang.org
 */
auto assumePure(T)(T t)
if (isFunctionPointer!T || isDelegate!T) {
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

version (unittest) {
	static int f(int x) => x + 1;
	static void g() pure {
		static assert(!__traits(compiles, { auto x = f(42); }));
		auto pureF = assumePure(&f);
		assert(pureF(42) == 43);
	}
}

auto assumePureNogc(T)(T t) if (isFunctionPointer!T || isDelegate!T) {
	enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nogc;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}
