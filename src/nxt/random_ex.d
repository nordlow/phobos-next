/** Randomize existing instances and generate randomized instances of a given type.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	See_Also: http://forum.dlang.org/thread/byonwfghdqgcirdjyboh@forum.dlang.org

	TODO: Can these be tagged with @nogc? Currently std.random.uniform may allocate.

	TODO: Tags as nothrow when std.random gets there.

	TODO: How to handle possibly null reference (class, dynamic types) types?
	Answer relates to how to randomize empty/null variable length structures
	(arrays, strings, etc).

	- Maybe some kind of length randomization?
 */
module nxt.random_ex;

import std.traits: isIntegral, isFloatingPoint, isNumeric, isIterable, isArray, hasIndirections, isSomeString, isScalarType, isBoolean;
import std.range: ElementType, hasAssignableElements;
import std.random: uniform;

version (unittest) private enum testLength = 64;

/** Randomize value $(D x). */
ref E randInPlace(E)(return ref E x)
if (isBoolean!E)
{
	return x = cast(bool)uniform(0, 2);
}

/** Randomize value $(D x), optionally in range [$(D low), $(D high)]. */
ref E randInPlace(E)(return ref E x)
if (isIntegral!E)
{
	return x = uniform(E.min, E.max);	// BUG: Never assigns the value E.max
}

/** Randomize value $(D x), optional in range [$(D low), $(D high)]. */
ref E randInPlace(E)(return ref E x)
if (isFloatingPoint!E)
{
	return x = uniform(cast(E)0, cast(E)1);
}

/** Randomize value $(D x), optionally in range [$(D low), $(D high)]. */
ref E randInPlaceWithRange(E)(return ref E x,
							  E low,
							  E high)
if (isIntegral!E)
{
	return x = uniform(low, high);	// BUG: Never assigns the value E.max
}

/** Randomize value of $(D x), optional in range [$(D low), $(D high)]. */
ref E randInPlaceWithRange(E)(return ref E x,
							  E low /* E.min_normal */,
							  E high /* E.max */)
if (isFloatingPoint!E)
{
	return x = uniform(low, high);
}

version (unittest)
{
	import nxt.rational: Rational, rational;
}

/** Randomize value of $(D x). */
ref Rational!E randInPlace(Rational, E)(return ref Rational!E x) @trusted
if (isIntegral!E)
{
	return x = rational(uniform(E.min, E.max),
						uniform(1, E.max));
}

@safe unittest {
	Rational!int x;
	x.randInPlace();
}

/** Generate random value of $(D x).
	See_Also: http://forum.dlang.org/thread/emlgflxpgecxsqweauhc@forum.dlang.org
 */
ref dchar randInPlace(return ref dchar x) @trusted
{
	auto ui = uniform(0,
					  0xD800 +
					  (0x110000 - 0xE000) - 2 // minus two for U+FFFE and U+FFFF
		);
	if (ui < 0xD800)
		return x = ui;
	else
	{
		ui -= 0xD800;
		ui += 0xE000;

		// skip undefined
		if (ui < 0xFFFE)
			return x = ui;
		else
			ui += 2;

		assert(ui < 0x110000);
		return x = ui;
	}
}

unittest {
	dstring d = "alphaalphaalphaalphaalphaalphaalphaalphaalphaalpha";
	auto r = d.randomize; /+ TODO: Use Phobos function to check if string is legally coded. +/
}

/** Randomize value of $(D x). */
dstring randInPlace(dstring x) @trusted
{
	typeof(x) y;
	foreach (ix; 0 .. x.length)
		y ~= randomized!dchar; /+ TODO: How to do this in a better way? +/
	x = y;
	return x;
}

/** Randomize value of $(D x).
 */
R randInPlace(R)(R x)
if (isIterable!R &&
	hasAssignableElements!R)
{
	import core.lifetime : move;
	foreach (ref e; x)
		e.randInPlace();
	return move(x);			 /+ TODO: remove when compiler does this for us +/
}

/** Randomize all elements of $(D x).
	Each element is randomized within range `[elementLow, elementHigh]`.
 */
R randInPlaceWithElementRange(R, E)(R x,
									E elementLow,
									E elementHigh)
if (isIterable!R &&
	hasAssignableElements!R &&
	is(ElementType!R == E))
{
	import core.lifetime : move;
	foreach (ref e; x)
		e.randInPlaceWithRange(elementLow, elementHigh);
	return move(x);
}

@safe unittest {
	void testDynamic(T)()
	{
		auto x = new T[testLength];
		auto y = x.dup;
		x.randInPlace();
		y.randInPlace();
		assert(y != x);
	}
	testDynamic!int;
	testDynamic!float;
	testDynamic!bool;
}

/** Randomize elements of $(D x).
 */
ref T randInPlace(T)(return ref T x)
if (__traits(isStaticArray, T))
{
	foreach (ref e; x)
		e.randInPlace();
	return x;
}

@safe unittest {
	void testStatic(T)()
	{
		T[testLength] x;
		auto y = x;
		x.randInPlace();
		y.randInPlace();
		assert(y != x);
	}
	testStatic!bool;
	testStatic!int;
	testStatic!real;
	enum E { a, b, c, d, e, f, g, h,
			 i, j, k, l, m, n, o, p }
	testStatic!E;
}

/** Blockwise-randomize elements of $(D x) of array type $(D A).
	Randomizes in array blocks of type $(D B).
 */
ref A randInPlaceBlockwise(B = size_t, A)(ref A x)
if (isArray!A &&
	isIntegral!(ElementType!A))
{
	alias E = ElementType!A;
	static assert(E.sizeof < B.sizeof);
	enum mult = B.sizeof / E.sizeof; // block multiplicity

	immutable n = x.length;

	// beginning unaligned bytes
	auto p = cast(size_t)x.ptr;
	immutable size_t mask = B.sizeof - 1;
	immutable r = (p & mask) / E.sizeof; // element-offset from B-aligned address before x
	size_t k = 0; // E-index to first B-block
	if (r)
	{
		import std.algorithm.comparison : min;
		k = min(n, mult - r); // at first aligned B-block
		foreach (i, ref e; x[0 .. k])
			e.randInPlace();
	}

	// mid blocks of type B
	auto bp = cast(B*)(x.ptr + k); // block pointer
	immutable nB = (n - k) / mult; // number of B-blocks
	foreach (ref b; 0 .. nB) // for each block index
		bp[b].randInPlace();

	// ending unaligned bytes
	foreach (i, ref e; x[k + nB*mult .. $])
		e.randInPlace();

	return x;
}

unittest {
	static void test(B = size_t, T)()
	{
		enum n = 1024;

		// dynamic array
		for (size_t i = 0; i < n; i++)
		{
			T[] da = new T[i];
			da.randInPlaceBlockwise!B;
			size_t j = randomInstanceOf!(typeof(i))(0, n/2);
			da.randInPlaceBlockwise!B;
		}

		// static array
		T[n] sa;
		auto sa2 = sa[1 .. $];
		sa2.randInPlaceBlockwise!B;
	}

	import std.meta : AliasSeq;
	foreach (T; AliasSeq!(byte, short, int, ubyte, ushort, uint))
		test!(size_t, T);
}

/** Randomize members of $(D x).
 */
auto ref randInPlace(T)(return ref T x)
if (is(T == struct))
{
	foreach (ref e; x.tupleof)
		e.randInPlace();
	return x;
}

@safe unittest {
	struct T { ubyte a, b, c, d; }
	T[testLength] x;
	auto y = x;
	x.randInPlace();
	y.randInPlace();
	assert(y != x);
}

/** Randomize members of $(D x).
 */
auto ref randInPlace(T)(T x)
if (is(T == class))
{
	foreach (ref e; x.tupleof)
		e.randInPlace();
	return x;
}

alias randomize = randInPlace;

unittest {
	void testClass(E)()
	{
		class T { E a, b; }
		auto x = new T;
		auto y = new T;
		x.randInPlace();
		y.randInPlace();
		assert(y != x);
	}
	testClass!bool;
	testClass!int;
	testClass!float;
}

/** Returns: randomized instance of type $(D T).
 */
T randomInstanceOf(T)()
{
	/* TODO: recursively only void-initialize parts of T that are POD, not
	 reference types */
	static if (hasIndirections!T)
		T x;
	else
		/* don't init - randInPlace below fills in everything safely */
		T x = void;
	x.randInPlace();
	return x;
}

/** Returns: randomized instance of type $(D T).
 */
T randomInstanceOf(T)(T low = T.min,
					  T high = T.max)
if (isNumeric!T)
{
	/* TODO: recursively only void-initialize parts of T that are POD, not
	   reference types */
	static if (hasIndirections!T)
		T x;
	else
		/* don't init - `randInPlace()` below fills in everything safely */
		T x = void;
	return x.randInPlaceWithRange(low, high);
}

alias randomized = randomInstanceOf;

unittest {
	auto x = randomized!dchar;
	assert(x == x);
}

/** Random number generator xoroshiro128+

	See_Also: http://xoroshiro.di.unimi.it/
	See_Also: http://forum.dlang.org/post/kdobdorqztlsomweftmi@forum.dlang.org
	See_Also: https://www.reddit.com/r/programming/comments/4gtlfz/xoroshiro128_the_fastest_fullperiod_pseudorandom/
 */
struct Xoroshiro128plus
{
pure nothrow @safe @nogc:
	public:

	enum ulong min = ulong.min;
	enum ulong max = ulong.max;

	enum bool isUniformRandom = true;

	/// Range primitives
	enum bool empty = false;

	/// ditto
	ulong front() @property
	{
		return s[0] + s[1];
	}

	/// ditto
	void popFront()
	{
		import core.bitop : rol;
		immutable ulong s1 = s[1] ^ s[0];
		s[0] = rol(s[0], 55) ^ s1 ^ (s1 << 14);
		s[1] = rol(s1, 36);
	}

	void seed(ulong s0, ulong s1)
	in
	{
		// seeds are not both 0
		assert(!(!s0 && !s1));
	}
	do
	{
		s[0] = s0;
		s[1] = s1;
	}

	void seed(ulong[2] s01)
	in
	{
		// seeds are not both 0
		assert(!(!s01[0] && !s01[1]));
	}
	do
	{
		s[] = s01[];
	}

private:
	ulong[2] s;
}

pure nothrow @safe unittest {
	Xoroshiro128plus gen;
	gen.seed(150078950, 1313143614);
	import std.random : uniform;
	import std.range : generate, take;
	auto x = generate!(() => uniform!int(gen)).take(103);
}
