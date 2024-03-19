module nxt.math_ex;

import std.traits : isIntegral, isUnsigned, isNumeric;

/** Check if `x` is an exact (binary) power of 2.
 *
 * See_Also: http://forum.dlang.org/thread/zumhmosfkvwjymjhmtlt@forum.dlang.org#post-fvnmurrctavpfkunssdf:40forum.dlang.org
 * See_Also: http://forum.dlang.org/post/hloonbgclzloqemycnth@forum.dlang.org
*/
bool isPow2(T)(T x)
	if (isNumeric!T)
{
	import std.math : isPowerOf2; // https://github.com/dlang/phobos/pull/4327/files
	return isPowerOf2(x);
}
alias isPowerOf2 = isPow2;
/// ditto
bool isPow2A(T)(T x) if (isIntegral!T) => x && !(x & (x - 1));
/// ditto
bool isPow2B(T)(T x) if (isIntegral!T) => (x & -x) > (x - 1);
/// ditto
bool isPow2D(T)(T x) if (isIntegral!T) => (x > 0) && !(x & (x - 1));
/// ditto, avoids a jump instruction.
bool isPow2E(T)(T x) if (isIntegral!T) => (x > 0) & !(x & (x - 1));
/// ditto
bool isPow2F(T)(T x) if (isIntegral!T) => (x & -x) > (x >>> 1);

///
pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;
	foreach (fn; AliasSeq!(isPow2, isPow2A, isPow2D, isPow2E, isPow2F))
	{
		// run-time
		assert(!fn(7));
		assert(fn(8));
		assert(!fn(9));

		// compile-time
		static assert(!fn(7));
		static assert(fn(8));
		static assert(!fn(9));

		assert(!fn(0));
		assert(fn(1));
		assert(fn(2));
		assert(!fn(3));
		assert(fn(4));
		assert(!fn(5));
		assert(!fn(6));
		assert(!fn(7));
		assert(fn(8));
	}
}

/** Check if `x` is an exact (binary) power of 2, except when `x` is zero then
 * zero is returned.
 *
 * See_Also: http://forum.dlang.org/thread/zumhmosfkvwjymjhmtlt@forum.dlang.org#post-fvnmurrctavpfkunssdf:40forum.dlang.org
 * See_Also: http://forum.dlang.org/post/hloonbgclzloqemycnth@forum.dlang.org
*/
bool isPow2fast(T)(T x) if (isUnsigned!T) => (x & (x - 1)) == 0;

pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;
	foreach (fn; AliasSeq!(isPow2fast))
	{
		// run-time
		assert(!fn(7U));
		assert(fn(8U));
		assert(!fn(9U));

		// compile-time
		static assert(!fn(7U));
		static assert(fn(8U));
		static assert(!fn(9U));

		assert(fn(1U));
		assert(fn(2U));
		assert(!fn(3U));
		assert(fn(4U));
		assert(!fn(5U));
		assert(!fn(6U));
		assert(!fn(7U));
		assert(fn(8U));
	}
}
