module nxt.bit_traits;

version (LDC) static assert(!__traits(compiles, { enum _ = __traits(isZeroInit, T); }),
							"Remove checks for __traits(compiles, { enum _ = __traits(isZeroInit, T); }) now that it compiles with LDC");

/** Get number of bits needed to represent the range (0 .. `length`-1).
 */
template bitsNeeded(size_t length) {
	/+ TODO: optimize by removing need for a linear search +/
	static	  if (length <= 2)   { enum bitsNeeded = 1; }
	else static if (length <= 4)   { enum bitsNeeded = 2; }
	else static if (length <= 8)   { enum bitsNeeded = 3; }
	else static if (length <= 16)  { enum bitsNeeded = 4; }
	else static if (length <= 32)  { enum bitsNeeded = 5; }
	else static if (length <= 64)  { enum bitsNeeded = 6; }
	else static if (length <= 128) { enum bitsNeeded = 7; }
	else static if (length <= 256) { enum bitsNeeded = 8; }
	else static if (length <= 512) { enum bitsNeeded = 9; }
	else						   { static assert(0, `Too large length`); }
}

/** Number of bits required to store a packed instance of `T`.
	See_Also: http://forum.dlang.org/thread/okonqhnxzqlqtxijxsfg@forum.dlang.org

	TODO: Extend to continuous version; use std.numeric.sumOfLog2s. Ask on
	StackExchange Computer Science for the correct terminology.

	See: http://dlang.org/phobos/std_numeric.html#.sumOfLog2s

	TODO: merge with `UsageOf`
   */
template packedBitSizeOf(T) {
	static if (is(T == enum)) {
		static assert(T.min != T.max, "enum T must have at least two enumerators");
		import core.bitop : bsr;
		enum range = T.max - T.min; /+ TODO: use uniqueEnumMembers.length instead? +/
		enum packedBitSizeOf = range.bsr + 1;
	}
	// TODO
	// else static if (isAggregate!T)
	// {
	//	 foreach (E; T.tupleof)
	//	 {
	//		 ....;
	//	 }
	// }
	else
	{
		enum packedBitSizeOf = 8*T.sizeof;
	}
}

pure nothrow @safe @nogc unittest {
	static assert(packedBitSizeOf!ubyte == 8);
	static assert(!__traits(compiles,
							{
								enum E1 { x } static assert(packedBitSizeOf!E1 == 1);
							}));
	enum E2 { x, y }
	static assert(packedBitSizeOf!E2 == 1);
	enum E3 { x, y, z }
	static assert(packedBitSizeOf!E3 == 2);
	enum E4 { x, y, z, w }
	static assert(packedBitSizeOf!E4 == 2);
	enum E5 { a, b, c, d, e }
	static assert(packedBitSizeOf!E5 == 3);
	enum E6 { a, b, c, d, e, f }
	static assert(packedBitSizeOf!E6 == 3);
	enum E7 { a, b, c, d, e, f, g }
	static assert(packedBitSizeOf!E7 == 3);
	enum E8 { a, b, c, d, e, f, g, h }
	static assert(packedBitSizeOf!E8 == 3);
	enum E9 { a, b, c, d, e, f, g, h, i }
	static assert(packedBitSizeOf!E9 == 4);
}


/+ Is the representation of `T.init` known at compile time to consist of nothing
 + but zero bits? Padding between a struct's fields is not considered.
 +/
template isInitAllZeroBits(T) {
	static if (__traits(compiles, { enum _ = __traits(isZeroInit, T); })) {
		enum isInitAllZeroBits = __traits(isZeroInit, T);
		// pragma(msg, "TODO: use `enum isInitAllZeroBits = __traits(isZeroInit, T);` here and in `isAllZeroBits` and remove the test of isInitAllZeroBits");
	}
	else static if (T.sizeof == 0) {
		enum isInitAllZeroBits = true;
	}
	else
	{
		static if (__traits(isStaticArray, T) && __traits(compiles, T.init[0])) {
			enum isInitAllZeroBits = __traits(compiles, {
					static assert(isAllZeroBits!(typeof(T.init[0]), T.init[0]));
				});
		}
		else
		{
			enum isInitAllZeroBits = __traits(compiles, {
					static assert(isAllZeroBits!(T, T.init));
				});
		}
	}
}

@nogc nothrow pure @safe unittest {
	static assert(isInitAllZeroBits!int);
	static assert(isInitAllZeroBits!(Object));
	static assert(isInitAllZeroBits!(void*));
	static assert(isInitAllZeroBits!uint);
	static assert(isInitAllZeroBits!(uint[2]));
	static assert(isInitAllZeroBits!(string));
	static assert(isInitAllZeroBits!(wstring));
	static assert(isInitAllZeroBits!(dstring));

	static assert(!isInitAllZeroBits!float);
	// static assert(isInitAllZeroBits!(float[0]));
	static assert(!isInitAllZeroBits!(float[2]));

	static struct S1
	{
		int a;
	}
	static assert(isInitAllZeroBits!S1);

	static struct S2
	{
		int a = 1;
	}
	static assert(!isInitAllZeroBits!S2);

	static struct S3
	{
		S1 a;
		int b;
	}
	static assert(isInitAllZeroBits!S3);
	static assert(isInitAllZeroBits!(S3[2]));

	static struct S4
	{
		S1 a;
		S2 b;
	}
	static assert(!isInitAllZeroBits!S4);

	static struct S5
	{
		real r = 0;
	}
	static assert(isInitAllZeroBits!S5);

	static struct S6
	{

	}
	static assert(isInitAllZeroBits!S6);

	static struct S7
	{
		float[0] a;
	}
	/+ TODO: static assert(isInitAllZeroBits!S7); +/

	static class C1
	{
		int a = 1;
	}
	static assert(isInitAllZeroBits!C1);

	// Ensure Tuple can be read.
	import std.typecons : Tuple;
	static assert(isInitAllZeroBits!(Tuple!(int, int)));
	static assert(!isInitAllZeroBits!(Tuple!(float, float)));

	// Ensure private fields of structs from other modules
	// are taken into account.
	import std.random : Mt19937;
	static assert(!isInitAllZeroBits!Mt19937);
	// Check that it works with const.
	static assert(isInitAllZeroBits!(const(Mt19937)) == isInitAllZeroBits!Mt19937);
	static assert(isInitAllZeroBits!(const(S5)) == isInitAllZeroBits!S5);
}

/+ Can the representation be determined at compile time to consist of nothing
 + but zero bits? Padding between a struct's fields is not considered.
 +/
template isAllZeroBits(T, T value) {
	static if ((is(T == class) || is(T == typeof(null))) && // need this special case
			   value is null)   // because pointer must be compared with `is` instead of `==` for `SSOString` case below
	{
		enum isAllZeroBits = true;
	}
	else static if (value == T.init && // NOTE `value is T.init` crashes compiler for `SSOString`
					__traits(compiles, { enum _ = __traits(isZeroInit, T); })) {
		enum isAllZeroBits = __traits(isZeroInit, T);
	}
	else
	{
		// pragma(msg, "T: ", T.stringof, " value:", value);
		import std.traits : isDynamicArray;
		static if (isDynamicArray!(T)) {
			enum isAllZeroBits = value is null && value.length is 0;
		}
		else static if (is(typeof(value is null))) {
			enum isAllZeroBits = value is null;
		}
		else static if (is(typeof(value is 0))) {
			enum isAllZeroBits = value is 0;
		}
		else static if (__traits(isStaticArray, T)) {
			enum isAllZeroBits = () {
				// Use index so this works when T.length is 0.
				static foreach (i; 0 .. T.length) {
					if (!isAllZeroBits!(typeof(value[i]), value[i]))
						return false;
				}
				return true;
			}();
		}
		else static if (is(T == struct) ||
						is(T == union)) {
			enum isAllZeroBits = () {
				static foreach (e; value.tupleof) {
					if (!isAllZeroBits!(typeof(e), e))
						return false;
				}
				return true;
			}();
		}
		else
			enum isAllZeroBits = false;
	}
}

@nogc nothrow pure @safe unittest {
	static assert(isAllZeroBits!(int, 0));
	static assert(!isAllZeroBits!(int, 1));

	import std.meta : AliasSeq;
	foreach (Float; AliasSeq!(float, double, real)) {
		assert(isAllZeroBits!(Float, 0.0));
		assert(!isAllZeroBits!(Float, -0.0));
		assert(!isAllZeroBits!(Float, Float.nan));
	}

	static assert(isAllZeroBits!(void*, null));
	static assert(isAllZeroBits!(int*, null));
	static assert(isAllZeroBits!(Object, null));
}

/+ Can the representation be determined at compile time to consist of nothing
but 1 bits? This is reported as $(B false) for structs with padding between
their fields because `opEquals` and hashing may rely on those bits being zero.

Note:
A bool occupies 8 bits so `isAllOneBits!(bool, true) == false`

See_Also:
https://forum.dlang.org/post/hn11oh$1usk$1@digitalmars.com
https://github.com/dlang/phobos/pull/6024
+/
template isAllOneBits(T, T value) {
	import std.traits : isIntegral, isSomeChar, Unsigned;
	static if (isIntegral!T || isSomeChar!T) {
		import core.bitop : popcnt;
		static if (T.min < T(0))
			enum isAllOneBits = popcnt(cast(Unsigned!T) value) == T.sizeof * 8;
		else
			enum isAllOneBits = popcnt(value) == T.sizeof * 8;
	}
	else static if (__traits(isStaticArray, typeof(value))) {
		enum isAllOneBits = () {
			bool b = true;
			// Use index so this works when T.length is 0.
			static foreach (i; 0 .. T.length) {
				b &= isAllOneBits!(typeof(value[i]), value[i]);
				if (b == false)
					return b;
			}

			return b;
		}();
	}
	else static if (is(typeof(value) == struct)) {
		enum isAllOneBits = () {
			bool b = true;
			size_t fieldSizeSum = 0;
			alias v = value.tupleof;
			static foreach (const i, e; v) {
				b &= isAllOneBits!(typeof(e), v[i]);
				if (b == false)
					return b;
				fieldSizeSum += typeof(e).sizeof;
			}
			// If fieldSizeSum == T.sizeof then there can be no gaps
			// between fields.
			return b && fieldSizeSum == T.sizeof;
		}();
	}
	else
	{
		enum isAllOneBits = false;
	}
}

@nogc nothrow pure @safe unittest {
	static assert(isAllOneBits!(char, 0xff));
	static assert(isAllOneBits!(wchar, 0xffff));
	static assert(isAllOneBits!(byte, cast(byte) 0xff));
	static assert(isAllOneBits!(int, 0xffff_ffff));
	static assert(isAllOneBits!(char[4], [0xff, 0xff, 0xff, 0xff]));

	static assert(!isAllOneBits!(bool, true));
	static assert(!isAllOneBits!(wchar, 0xff));
	static assert(!isAllOneBits!(Object, Object.init));

	static struct S1
	{
		char a;
		char b;
	}
	static assert(isAllOneBits!(S1, S1.init));
}

/+ Can the representation be determined at compile time to consist of nothing
but 1 bits? This is reported as $(B false) for structs with padding between
their fields because `opEquals` and hashing may rely on those bits being zero.

See_Also:
https://forum.dlang.org/post/hn11oh$1usk$1@digitalmars.com
https://github.com/dlang/phobos/pull/6024
+/
template isInitAllOneBits(T) {
	static if (__traits(isStaticArray, T) && __traits(compiles, T.init[0])) /+ TODO: avoid traits compiles here +/
		enum isInitAllOneBits = __traits(compiles, { /+ TODO: avoid traits compiles here +/
			static assert(isAllOneBits!(typeof(T.init[0]), T.init[0]));
		});
	else
		enum isInitAllOneBits = __traits(compiles, { /+ TODO: avoid traits compiles here +/
			static assert(isAllOneBits!(T, T.init));
		});
}

///
@nogc nothrow pure @safe unittest {
	static assert(isInitAllOneBits!char);
	static assert(isInitAllOneBits!wchar);
	static assert(!isInitAllOneBits!dchar);

	static assert(isInitAllOneBits!(char[4]));
	static assert(!isInitAllOneBits!(int[4]));
	static assert(!isInitAllOneBits!Object);

	static struct S1
	{
		char a;
		char b;
	}
	static assert(isInitAllOneBits!S1);

	static struct S2
	{
		char a = 1;
	}
	static assert(!isInitAllOneBits!S2);

	static struct S3
	{
		S1 a;
		char b;
	}
	static assert(isInitAllOneBits!S3);
	static assert(isInitAllOneBits!(S3[2]));

	static struct S4
	{
		S1 a;
		S2 b;
	}
	static assert(!isInitAllOneBits!S4);

	static struct Sshort
	{
		short r = cast(short)0xffff;
	}
	static assert(isInitAllOneBits!Sshort);

	static struct Sint
	{
		int r = 0xffff_ffff;
	}
	static assert(isInitAllOneBits!Sint);

	static struct Slong
	{
		long r = 0xffff_ffff_ffff_ffff;
	}
	static assert(isInitAllOneBits!Slong);

	// Verify that when there is padding between fields isInitAllOneBits is false.
	static struct S10
	{
		align(4) char a;
		align(4) char b;
	}
	static assert(!isInitAllOneBits!S10);

	static class C1
	{
		char c;
	}
	static assert(!isInitAllOneBits!C1);
}
