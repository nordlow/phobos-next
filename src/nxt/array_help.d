module nxt.array_help;

import core.internal.traits : Unqual;

@safe:

/** Returns: statically (stack) allocated array with elements of type `T` of
 * length `n`.
 *
 * For more convenient usage alias it as `s' together with UFCS for the
 * following convenient notation:
 *
 * const x = [1, 2, 3].s;
 *
 * TODO: Replace with Phobos `staticArray` when dmd automatically does move for uncopyable `T`.
 *
 * TODO: Fix problems discussed here: http://forum.dlang.org/post/otrsanpgmokzpzqmfyvx@forum.dlang.org
 * TODO: File a bug report: http://forum.dlang.org/post/otrsanpgmokzpzqmfyvx@forum.dlang.org
 *
 * TODO: fix compiler so that move kicks in here automatically and remove
 * special case on `isCopyable`
 *
 * See_Also: http://dpaste.dzfl.pl/d0059e6e6c09
 * See_Also: http://forum.dlang.org/post/oq0cd1$2ji3$1@digitalmars.com
 */
Unqual!T[n] staticArray(T, size_t n)(T[n] x...) @trusted
{
	static if (__traits(isCopyable, T))  /+ TODO: remove when compiler does move for us +/
		return x[];
	else					  /+ TODO: remove `move` when compiler does it for us +/
	{
		/+ TODO: remove `move` when compiler does it for us: +/
		T[n] y = void;		// initialized below
		import core.internal.traits : hasElaborateDestructor;
		static if (hasElaborateDestructor!T) {
			import core.lifetime : move;
			/* NOTE: moveEmplaceAll doesn't support uncopyable elements
			 * import std.algorithm.mutation : moveEmplaceAll;
			 * moveEmplaceAll(x[], y[]);
			 */
			foreach (const ix, ref value; x)
				move(value, y[ix]);
		}
		else
		{
			import core.stdc.string : memcpy;
			memcpy(y.ptr, x.ptr, n*T.sizeof); // fast
		}
		return y;
	}
}
alias s = staticArray;

pure @safe unittest {
	// assert([].staticArray.ptr == null);
	assert([].s.length == 0);
}

version (none)
pure @safe unittest {
	import std.array : staticArray;
	assert([].staticArray.ptr !is null);
	assert([].staticArray.length == 0);
}

/** Make a static array. */
version (none)
auto staticArrayAlternative() @safe
{
	static struct _staticArray
	{
		T[n] s(T, size_t n)(auto ref T[n] values) @safe @property { return values; }

		T[0][n] opIndex(size_t n = T.length, T...)(T items) {
			typeof(return) arr;
			foreach (index,item; items)
				arr[index] = item;

			return (values) { return values; } (arr);//s!(T[0], n)(arr);
		}
	}
	return _staticArray();
}

version (unittest) {
	static struct US
	{
		this(this) @disable;
		int x;
		void f() { x = 42; }
	}
}

///
pure nothrow @safe @nogc unittest {
	auto a = [1, 2, 3].staticArray;
	static assert(is(typeof(a) == int[a.length]));
	static assert(is(typeof([1, 2, 3].staticArray) == int[a.length]));

	auto b = "hello".s;
	static assert(is(typeof(b) == char[5]));

	auto x = s!ubyte(1, 2, 3);
	static assert(is(typeof(x) == ubyte[3]));
}

/// non-copyable element type in static array
pure nothrow @safe @nogc unittest {
	auto b = [US(42)].s;
	static assert(b.length == 1);
}

///
pure nothrow @safe @nogc unittest {
	auto x = [1, 2, 3].staticArray;

	static assert(is(typeof(x) == int[x.length]));
	static assert(is(typeof([1, 2, 3].staticArray) == int[x.length]));

	static assert(!__traits(compiles, {
		static int[] doNotDoThat() {
			return [1, 2, 3].s;
		}
	}));
}

/** Returns: `x` as a static array of unsigned bytes. */
@property ubyte[T.sizeof] toUbytes(T)(in T x) @trusted pure nothrow @nogc /+ TODO: endian-dependent +/
	=> (cast(ubyte*)(&x))[0 .. x.sizeof];

/** Returns: `x` as a static array with elements of type `E`. */
@property ref inout(E)[T.sizeof] asN(E, T)(inout ref T x) @trusted pure nothrow @nogc /+ TODO: endian-dependent +/
if (T.sizeof % E.sizeof == 0)
	=> (cast(E*)(&x))[0 .. x.sizeof];

///
pure nothrow @safe @nogc unittest {
	immutable ushort x = 17;
	auto y = x.asN!ubyte;
	version(LittleEndian)
		assert(y == [17, 0].s);
}

/// Number of bytes in a word.
private enum wordBytes = size_t.sizeof;

/// Number of bits in a word.
private enum wordBits = 8*wordBytes;

/** Returns: number of words (`size_t`) needed to represent
 * `bitCount` bits.
 */
static size_t wordCountOfBitCount(size_t bitCount) pure nothrow @safe @nogc
	=> ((bitCount / wordBits) +
	(bitCount % wordBits != 0 ? 1 : 0));

static size_t binBlockBytes(size_t bitCount) pure nothrow @safe @nogc
	=> wordBytes*wordCountOfBitCount(bitCount);

/** Returns: an uninitialized bit-array containing `bitCount` number of bits. */
size_t* makeUninitializedBitArray(alias Allocator)(size_t bitCount) @trusted pure nothrow @nogc
	=> cast(typeof(return))Allocator.instance.allocate(binBlockBytes(bitCount));

T[] makeArrayZeroed(T, alias Allocator)(size_t numBytes) @trusted pure nothrow @nogc
{
	import std.experimental.allocator : makeArray;
	/+ TODO: activate +/
	// static if (__traits(isZeroInit, T) &&
	//			__traits(hasMember, Allocator, "allocateZeroed"))
	// {
	// 	return cast(typeof(return))makeArray!(T)(Allocator.instance, numBytes);
	// }
	// else
	{
		import core.stdc.string : memset;
		auto result = makeArray!(T)(Allocator.instance, numBytes);
		memset(result.ptr, 0, numBytes);
		return result;
	}
}

/** Returns: an zero-initialized bit-array containing `bitCount` number of bits. */
size_t[] makeBitArrayZeroed(alias Allocator)(size_t bitCount) @trusted pure nothrow @nogc
{
	version (D_Coverage) {} else pragma(inline, true);
	return cast(typeof(return))makeArrayZeroed!(size_t, Allocator)(binBlockBytes(bitCount)); /+ TODO: check aligned allocate +/
}

/** Returns: `input` reallocated to contain `newBitCount` number of bits. New bits
 * are default-initialized to zero.
 */
size_t* makeReallocatedBitArrayZeroPadded(alias Allocator)(size_t* input,
														   const size_t currentBitCount,
														   const size_t newBitCount) @system
if (__traits(hasMember, Allocator, "reallocate")) {
	assert(currentBitCount < newBitCount, "no use reallocate to same size");

	immutable currentWordCount = wordCountOfBitCount(currentBitCount);
	immutable newWordCount = wordCountOfBitCount(newBitCount);

	auto rawArray = cast(void[])(input[0 .. currentWordCount]);

	const ok = Allocator.instance.reallocate(rawArray, newWordCount*wordBytes);
	assert(ok, "couldn't reallocate input");
	input = cast(size_t*)rawArray.ptr;

	// See: https://forum.dlang.org/post/puolgthmxgacveqasqkk@forum.dlang.org
	input[currentWordCount .. newWordCount] = 0;

	return input;
}

///
@trusted pure nothrow @nogc unittest {
	enum bitCount = 8*size_t.sizeof + 1;

	size_t* x = makeUninitializedBitArray!(Allocator)(bitCount);
	Allocator.instance.deallocate(cast(void[])(x[0 .. wordCountOfBitCount(bitCount)]));
}

///
@trusted pure nothrow @nogc unittest {
	size_t bitCount = 1;
	size_t* y = makeBitArrayZeroed!(Allocator)(bitCount).ptr; // start empty
	while (bitCount < 100_000) {
		const newBitCount = bitCount * 2;
		y = makeReallocatedBitArrayZeroPadded!(Allocator)(y, bitCount, newBitCount);
		bitCount = newBitCount;

		// check contents
		foreach (immutable bitIndex; 0 .. bitCount)
			assert(bt(y, bitIndex) == 0);
	}
	Allocator.instance.deallocate(cast(void[]) (y[0 .. wordCountOfBitCount(bitCount)]));
}

version (unittest) {
	import core.bitop : bt;
	import std.experimental.allocator.mallocator : Allocator = Mallocator;
}
