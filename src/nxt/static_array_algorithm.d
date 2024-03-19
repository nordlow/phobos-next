module nxt.static_array_algorithm;

import std.range.primitives : ElementType;

/** Overload of `std.array.array` that creates a static array of length `n`.
 *
 * TODO: Better name: {make,array}{N,Exactly}
 * TODO: could we find a way to propagate length at compile-time?
 */
ElementType!R[n] toStaticArray(size_t n, R)(R r)
{
	assert(r.length == n);
	typeof(return) dst;
	import std.algorithm.mutation : copy;
	r.copy(dst[]);
	return dst;
}

/** Static array overload for `std.algorithm.iteration.map`.
 *
 * See_Also: http://forum.dlang.org/thread/rqlittlysttwxwphlnmh@forum.dlang.org
 * TODO: Move to Phobos
 */
typeof(fun(E.init))[n] map(alias fun, E, size_t n)(const E[n] src)
{
	import std.algorithm.iteration : map;
	return src[].map!fun.toStaticArray!n;
}

///
pure nothrow @safe unittest {
	import std.meta : AliasSeq;
	foreach (E; AliasSeq!(int, double))
	{
		enum n = 42;
		E[n] c;
		const result = c.map!(_ => _^^2);
		static assert(c.length == result.length);
		static assert(is(typeof(result) == const(E)[n]));
	}
}

import nxt.traits_ex : allSameTypeRecursive;

/** Returns: tuple `tup` to a static array.
 *
 * See_Also: http://dpaste.dzfl.pl/d0059e6e6c09
 */
inout(T.Types[0])[T.length] toStaticArray1(T)(inout T tup) @trusted
if (allSameTypeRecursive!(T.Types))
{
	return *cast(T.Types[0][T.length]*)&tup; // hackish
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons: tuple;
	const auto tup = tuple("a", "b", "c", "d");
	const string[4] arr = ["a", "b", "c", "d"];
	static assert(is(typeof(tup.toStaticArray1()) == typeof(arr)));
	assert(tup.toStaticArray1() == arr);
}
