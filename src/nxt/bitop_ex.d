/** Various extensions to core.bitop and std.bitmanip.
 *
 * Copyright: Per Nordlöw 2022-.
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB Per Nordlöw)
 *
 * TODO: Add range checking of bit indexes.
 *
 * TODO: Make use of TZCNT and LZCNT either as inline assembly or as builtins: https://github.com/dlang/dmd/pull/6364
 */
module nxt.bitop_ex;

import std.meta : allSatisfy;
import std.traits : isIntegral;

pure nothrow @safe @nogc:

/** Get an unsigned type of size as `T` if possible. */
template UnsignedOfSameSizeAs(T) {
	enum nBits = 8*T.sizeof;
	static	  if (nBits ==  8) alias UnsignedOfSameSizeAs = ubyte;
	else static if (nBits == 16) alias UnsignedOfSameSizeAs = ushort;
	else static if (nBits == 32) alias UnsignedOfSameSizeAs = uint;
	else static if (nBits == 64) alias UnsignedOfSameSizeAs = ulong;
	else static if (nBits == 128) alias UnsignedOfSameSizeAs = ucent;
	else
	{
		import std.conv: to;
		static assert(0, "No Unsigned type of size " ~ to!string(nBits) ~ " found");
	}
}

/** Returns: `T` with only `bix`:th bit set. */
T makeBit(T, I...)(I bixs) @safe
if (isIntegral!T &&
	allSatisfy!(isIntegral, I) &&
	I.length >= 1)
in
{
	foreach (n, const bix; bixs) {
		assert(0 <= bix && bix < 8*T.sizeof,
			   "Bit index " ~ n.stringof ~ " is out of range");
	}
}
do
{
	T x = 0;
	foreach (const bix; bixs)
		x |= cast(T)((cast(T)1) << bix);
	return x;
}
alias btm = makeBit;

/** Returns: `true` iff all `bix`:th bits of `a` are set. */
pragma(inline, true)
bool testBit(T, I...)(in T a, I bixs) @safe
if (isIntegral!T &&
	allSatisfy!(isIntegral, I) &&
	I.length >= 1)
	=> a & makeBit!T(bixs) ? true : false;

/** Returns: `true` iff all `bix`:th bits of `a` are set. */
pragma(inline, true)
bool testBit(T, I...)(in T a, I bixs) @trusted
if ((!(isIntegral!T)) &&
	allSatisfy!(isIntegral, I))
	=> (*(cast(UnsignedOfSameSizeAs!T*)&a)).testBit(bixs); // reuse integer variant

/** Returns: `true` iff all `bix`:th bits of `*a` are set. */
pragma(inline, true)
bool testBit(T, I...)(in T* a, I bixs) @safe
if ((!(isIntegral!T)) &&
	!is(T == size_t) &&	 // avoid stealing `core.bitop.bt`
	allSatisfy!(isIntegral, I) &&
	I.length >= 1)
	=> testBit(*a, bixs);
alias bt = testBit;

///
pure nothrow @safe @nogc unittest {
	static void test(T)() {
		const mn = T.min, mx = T.max;
		enum nBits = 8*T.sizeof;
		foreach (const ix; 0 .. nBits-1)
			assert(!mn.bt(ix));
		assert(mn.bt(nBits - 1));
		foreach (const ix; 0 .. T.sizeof)
			assert(mx.bt(ix));
	}
	test!byte;
	test!short;
	test!int;
	test!long;
}

/** Test and sets the `bix`:th bit of `a` to one.
 *
 * Returns: A non-zero value if the bit was set, and a zero if it was clear.
*/
void setBit(T, I...)(ref T a, I bixs) @safe
if (isIntegral!T &&
	allSatisfy!(isIntegral, I) &&
	I.length >= 1) {
	pragma(inline, true);
	a |= makeBit!T(bixs);
}

/** Sets the `bix`:th bit of `*a` to one.
 */
void setBit(T, I...)(T* a, I bixs) @safe
if (isIntegral!T &&
	!is(T == size_t) && // avoid stealing core.bitop.bt
	allSatisfy!(isIntegral, I) &&
	I.length >= 1) {
	pragma(inline, true);
	*a |= makeBit!T(bixs);
}

/** Sets the `bix`:th bit of `*a` to one.
 */
void setBit(T, I...)(ref T a, I bixs) @trusted
if ((!(isIntegral!T)) &&
	allSatisfy!(isIntegral, I) &&
	I.length >= 1) {
	pragma(inline, true);
	alias U = UnsignedOfSameSizeAs!T;
	(*(cast(U*)&a)) |= makeBit!U(bixs); // reuse integer variant
}
alias bts = setBit;

/* alias btc = complementBit; */
/* alias btr = resetBit; */

/** Set lowest bit of `a` to one. */
pragma(inline, true)
void setLowestBit(T)(ref T a) @safe if (isIntegral!T) => setBit(a, 0);
alias setBottomBit = setLowestBit;
alias setLsbit = setLowestBit;

/** Set highest bit of `a` to one. */
pragma(inline, true)
void setHighestBit(T)(ref T a) @safe if (isIntegral!T) => setBit(a, 8*T.sizeof - 1);
alias setTopBit = setHighestBit;
alias setMsbit = setHighestBit;

/** Get lowest bit of `a`. */
pragma(inline, true)
bool getLowestBit(T)(in T a) @safe
if (isIntegral!T)
	=> (a & 1) != 0;
alias getBottomBit = getLowestBit;
alias getLsbit = getLowestBit;

/** Get highest bit of `a`. */
pragma(inline, true)
bool getHighestBit(T)(in T a) @safe if (isIntegral!T) => (a & (cast(T)1 << 8*T.sizeof - 1)) != 0;	/+ TODO: use core.bitop.bt when T is a size_t +/
alias getTopBit = getHighestBit;
alias getMsbit = getHighestBit;

///
pure nothrow @safe @nogc unittest {
	const ubyte x = 1;
	assert(!x.getTopBit);
	assert(x.getLowestBit);
}

///
pure nothrow @safe @nogc unittest {
	const ubyte x = 128;
	assert(x.getTopBit);
	assert(!x.getLowestBit);
}

/** Reset bits `I` of `a` (to zero). */
void resetBit(T, I...)(ref T a, I bixs) @safe
if (isIntegral!T &&
	allSatisfy!(isIntegral, I)) {
	pragma(inline, true);
	a &= ~makeBit!T(bixs);
}

/** Reset bits `I` of `*a` (to zero). */
void resetBit(T, I...)(T* a, I bixs) @safe
if (isIntegral!T &&
	!is(T == size_t) && // avoid stealing core.bitop.bt
	allSatisfy!(isIntegral, I)) {
	pragma(inline, true);
	*a &= ~makeBit!T(bixs);
}

/** Reset bits `I` of `a` (to zero). */
void resetBit(T, I...)(ref T a, I bixs)
if ((!(isIntegral!T)) &&
	allSatisfy!(isIntegral, I)) {
	pragma(inline, true);
	alias U = UnsignedOfSameSizeAs!T;
	(*(cast(U*)&a)) &= ~makeBit!U(bixs); // reuse integer variant
}

/** Reset lowest bit of `a` (to zero). */
pragma(inline, true)
void resetLowestBit(T)(ref T a) @safe if (isIntegral!T) => resetBit(a, 0);
alias resetBottomBit = resetLowestBit;

/** Reset highest bit of `a` (to zero). */
pragma(inline, true)
void resetHighestBit(T)(ref T a) @safe if (isIntegral!T) => resetBit(a, 8*T.sizeof - 1);
alias resetTopBit = resetHighestBit;

alias btr = resetBit;

///
pure nothrow @nogc unittest {
	alias T = int;
	enum nBits = 8*T.sizeof;
	T a = 0;

	a.bts(0); assert(a == 1);
	a.bts(1); assert(a == 3);
	a.bts(2); assert(a == 7);

	a.btr(0); assert(a == 6);
	a.btr(1); assert(a == 4);
	a.btr(2); assert(a == 0);

	a.bts(0, 1, 2); assert(a == 7);
	a.btr(0, 1, 2); assert(a == 0);

	a.bts(8*T.sizeof - 1); assert(a != 0);
	a.btr(8*T.sizeof - 1); assert(a == 0);

	T b = 0;
	b.bts(nBits - 1);
	assert(b == T.min);
}

///
pure nothrow @safe @nogc unittest {
	static void test(T)() {
		enum nBits = 8*T.sizeof;
		T x = 0;
		x.bts(0);
	}

	test!float;
	test!double;
}

///
pure nothrow @safe @nogc unittest {
	assert(makeBit!int(2) == 4);
	assert(makeBit!int(2, 3) == 12);
	assert(makeBit!uint(0, 31) == 2^^31 + 1);

	import std.meta : AliasSeq;
	foreach (T; AliasSeq!(ubyte, ushort, uint, ulong)) {
		foreach (const n; 0 .. 8*T.sizeof) {
			const x = makeBit!T(n);
			assert(x == 2UL^^n);

			T y = x;
			y.resetBit(n);
			assert(y == 0);

			y.setBit(n);
			assert(y == x);
		}
	}
}
