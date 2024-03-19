/** Bijections between scalar types and integers.
 *
 * TOOD extract reinterpret!T(x)
 *
 * TODO: support `real`?
 */
module nxt.bijections;

import std.meta : AliasSeq, staticIndexOf;
import std.traits : Unqual, isUnsigned, isSigned, isIntegral, Unsigned;

/** List of types that are bijectable to builtin integral types. */
alias IntegralBijectableTypes = AliasSeq!(bool, char, wchar, dchar,
										  ubyte, ushort, uint, ulong,
										  byte, short, int, long,
										  float, double);

enum isIntegralBijectableType(T) = staticIndexOf!(Unqual!T, IntegralBijectableTypes) >= 0;

/// check that `bijectToUnsigned` preserves orderness, that is is a bijection
@safe unittest {
	import std.random : Random, uniform;
	auto gen = Random();

	enum maxCount = 1e4;
	import std.algorithm : min;

	static int cmp(T)(T x, T y) => x < y ? -1 : x > y ? 1 : 0;

	foreach (T; AliasSeq!(ubyte, ushort, uint, ulong, byte, short, int, long)) {
		foreach (i; 0 .. min(maxCount, T.max - T.min)) {
			const x = uniform(T.min, T.max, gen);
			const y = uniform(T.min, T.max, gen);

			const expected = cmp(x, y);
			const result = cmp(x.bijectToUnsigned, y.bijectToUnsigned);

			assert(result == expected);
		}
	}

	foreach (T; AliasSeq!(float, double)) {
		foreach (i; 0 .. maxCount) {
			const T x = uniform(-1e20, +1e20, gen);
			const T y = uniform(-1e20, +1e20, gen);

			// import nxt.debugio;
			// dbg(x, ",", y);

			const expected = cmp(x, y);
			const result = cmp(x.bijectToUnsigned, y.bijectToUnsigned);

			assert(result == expected);
		}
	}
}

pragma(inline) pure nothrow @safe @nogc:

/** Biject (shift) a signed `a` "up" to the corresponding unsigned type (for
 * instance before radix sorting an array of `a`).
 */
auto bijectToUnsigned(T)(T a) @trusted
if (isIntegralBijectableType!T) {
	alias UT = Unqual!T;
	static	  if (is(UT == bool))  { return *(cast(ubyte*)&a); } // reinterpret
	else static if (is(UT == char))  { return *(cast(ubyte*)&a); } // reinterpret
	else static if (is(UT == wchar)) { return *(cast(ushort*)&a); } // reinterpret
	else static if (is(UT == dchar)) { return *(cast(uint*)&a); } // reinterpret
	else static if (isIntegral!UT) {
		static	  if (isSigned!UT) {
			alias UUT = Unsigned!UT;
			return cast(UUT)(a + (cast(UUT)1 << (8*UT.sizeof - 1))); // "add up""
		}
		else static if (isUnsigned!UT)
			return a;		   // identity
		else
			static assert(0, "Unsupported integral input type " ~ UT.stringof);
	}
	else static if (is(UT == float))  { return ff(*cast(uint*)(&a)); }
	else static if (is(UT == double)) { return ff(*cast(ulong*)(&a)); }
	else static assert(0, "Unsupported input type " ~ UT.stringof);
}

/** Same as `bijectToUnsigned` with extra argument `descending` that reverses
 * order.
 */
auto bijectToUnsigned(T)(T a, bool descending)
if (isIntegralBijectableType!T) {
	immutable ua = a.bijectToUnsigned;
	return descending ? ua.max-ua : ua;
}

/** Biject (Shift) an unsigned `a` "back down" to the corresponding signed type
 * (for instance after radix sorting an array of `a`).
 */
void bijectFromUnsigned(U)(U a, ref U b) if (isUnsigned!U) {
	b = a; /// Identity.
}

/// ditto
void bijectFromUnsigned(U, V)(U a, ref V b)
if (isUnsigned!U &&
	isIntegral!V && isSigned!V &&
	is(U == Unsigned!V)) {
	b = a - (cast(Unsigned!U)1 << (8*U.sizeof - 1)); // "add down""
}

/// ditto
@trusted void bijectFromUnsigned(ubyte  a, ref  bool b) { b = *cast(typeof(b)*)(&a); }
/// ditto
@trusted void bijectFromUnsigned(ubyte  a, ref  char b) { b = *cast(typeof(b)*)(&a); }
/// ditto
@trusted void bijectFromUnsigned(ushort a, ref wchar b) { b = *cast(typeof(b)*)(&a); }
/// ditto
@trusted void bijectFromUnsigned(ulong  a, ref dchar b) { b = *cast(typeof(b)*)(&a); }
/// ditto
@trusted void bijectFromUnsigned(uint  a, ref float  b) { uint  t = iff(a); b = *cast(float*)(&t); }
/// ditto
@trusted void bijectFromUnsigned(ulong a, ref double b) { ulong t = iff(a); b = *cast(double*)(&t); }

/// check that `bijectToUnsigned` is the opposite of `bijectFromUnsigned`
pure nothrow @safe @nogc unittest {
	foreach (T; AliasSeq!(ubyte, ushort, uint, ulong)) {
		static assert(is(typeof(T.init.bijectToUnsigned) == T));
	}

	foreach (T; AliasSeq!(byte, short, int, long)) {
		static assert(is(typeof(T.init.bijectToUnsigned) == Unsigned!T));
	}

	static assert(is(typeof(char.init.bijectToUnsigned) == ubyte));
	static assert(is(typeof(wchar.init.bijectToUnsigned) == ushort));
	static assert(is(typeof(dchar.init.bijectToUnsigned) == uint));

	const n = 1_000_000;
	foreach (const i; 0 .. n) {
		foreach (T; AliasSeq!(bool, ubyte, ushort, uint, ulong, byte, short,
							  int, long, char, wchar, dchar, float, double)) {
			const T x = cast(T) i;
			auto y = x.bijectToUnsigned;
			// pragma(msg, "T:", T);
			// pragma(msg, "typeof(x):", typeof(x));
			// pragma(msg, "typeof(y):", typeof(y));
			T z;
			y.bijectFromUnsigned(z);
			assert(x == z);
		}
	}
}

/** Map bits of floating point number \p a to unsigned integer that can be radix sorted.
 *
 * Also finds \em sign of \p a.
 *
 * - if it's 1 (negative float), it flips all bits.
 * - if it's 0 (positive float), it flips the sign only.
 */
uint ff(uint f) => f ^ (-cast(uint)  (f >> (8*f.sizeof-1)) | 0x80000000);
/// ditto
ulong ff(ulong f) => f ^ (-cast(ulong) (f >> (8*f.sizeof-1)) | 0x8000000000000000);

/** Map a floating point number \p a back from radix sorting
 *
 * (Inverse of \c radix_flip_float()).
 *
 * - if sign is 1 (negative), it flips the sign bit back
 * - if sign is 0 (positive), it flips all bits back
 */
uint iff(uint f) => f ^ (((f >> (8*f.sizeof-1)) - 1) | 0x80000000);
/// ditto
ulong iff(ulong f) => f ^ (((f >> (8*f.sizeof-1)) - 1) | 0x8000000000000000);
