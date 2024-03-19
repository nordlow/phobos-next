module nxt.sso_string;

/** Small-size-optimized (SSO) variant of `string`.
 *
 * Storage is placed on the stack if the number of `char`s is less than
 * `smallCapacity`, otherwise as a normal (large) `string`. The large `string`
 * will be allocated on the GC-heap if the `SSOString` is constructed from a
 * non-`string` (non-`immutable` `char[]`) parameter.
 *
 * Because `SSOString` doesn't have a destructor it can safely allocate using a
 * GC-backed region allocator without relying on a GC finalizer.
 *
 * In order to mimic `string/array/slice`-behaviour, opCast returns `false` for
 * `SSOString()` and `true` for `SSOString("")`. This requires `SSOString()` to
 * default to a large string in which large pointer is set to `null`.
 *
 * Big-endian platform support hasn't been verified.
 *
 * See_Also: https://forum.dlang.org/post/pb87rn$2icb$1@digitalmars.com
 * See_Also: https://issues.dlang.org/show_bug.cgi?id=18792
 * See_Also: https://forum.dlang.org/post/agzznbzkacfhyqvoezht@forum.dlang.org
 *
 * TODO: Use extra bits in `Short.length` for these special text encodings:
 * - 5-bit lowercase English letter into 128/5 = 25 chars
 * - 5-bit uppercase English letter into 120/5 = 25 chars
 * - 6-bit mixedcase English letter into 120/6 = 20 chars
 *
 * TODO: Move to Phobos' std.typecons or std.array or std.string
 */
@safe struct SSOString
{
	@property void toString(Sink)(ref scope Sink sink) const scope {
		sink(opSlice());
	}

pure:

	/** Construct from `source`, which potentially needs GC-allocation (iff
	 * `source.length > smallCapacity` and `source` is not a `string`).
	 */
	this(Chars)(const scope auto ref Chars source) @trusted nothrow
	if (is(Chars : const(char)[])) // `isCharArray`
	{
		static if (__traits(isStaticArray, Chars)) {
			static if (source.length <= smallCapacity) { // inferred @nogc
				small.data[0 .. source.length] = source;
				small.length = cast(typeof(small.length))(encodeSmallLength(source.length));
			} else {
				static if (is(typeof(source[0]) == immutable(char)))
					raw.ptr[0 .. source.length] = source; // copy elements
				else
					raw.ptr = source.idup.ptr; // GC-allocate
				raw.length = encodeLargeLength(source.length);
			}
		} else {					// `Chars` is a (dynamic) array slice
			if (source.length <= smallCapacity) {
				(cast(char*)small.data.ptr)[0 .. source.length] = source;
				small.length = cast(typeof(small.length))(encodeSmallLength(source.length));
			} else {
				static if (is(typeof(source[0]) == immutable(char)))
					raw.ptr = source.ptr; // already immutable so no duplication needed
				else
					raw.ptr = source.idup.ptr; // GC-allocate
				raw.length = encodeLargeLength(source.length);
			}
		}
	}

	/** Construct from `source` of `dchar`
	 */
	this(Source)(scope Source source) @trusted
	if (is(typeof({ foreach (const dchar elem; Source.init) {} })) && /+ TODO: `isConstRefIterable` +/
		is(typeof(Source.init.front) == dchar))
	{
		import std.utf : encode;

		// pre-calculate number of `char`s needed
		size_t charCount = 0;
		foreach (const e; source) {
			char[4] chars;	  /+ TODO: `= void` +/
			charCount += encode(chars, e);
		}

		if (charCount <= smallCapacity) { // fits in small
			size_t offset = 0;
			foreach (const e; source) {
				char[4] chars;
				const count = encode(chars, e);
				(cast(char[])(small.data))[offset .. offset + count] = chars[0 .. count];
				offset += count;
			}
			assert(offset <= smallCapacity);
			small.length = cast(typeof(small.length))(encodeSmallLength(offset));
		} else {				// needs large
			large = new immutable(char)[charCount];
			size_t offset = 0;
			foreach (const e; source) {
				char[4] chars;
				const count = encode(chars, e);
				(cast(char[])(large))[offset .. offset + count] = chars[0 .. count]; // NOTE modifies immutable data
				offset += count;
			}
			raw.length = encodeLargeLength(charCount);
		}
	}

nothrow:

	/** Return `this` converted to a `string`, without any GC-allocation because
	 * `this` is `immutable`.
	 */
	@property string toString() immutable @trusted return pure nothrow @nogc { // never allocates
		version (D_Coverage) {} else pragma(inline, true);
		return opSlice();
	}

	/** Return `this` converted to a `string`, which potentially needs
	 * GC-allocation (iff `length > smallCapacity`).
	 *
	 * implementation kept in sync with `opSlice`.
	 */
	@property string toString() const return @trusted pure nothrow { // may GC-allocate
		if (isLarge)
			// GC-allocated slice has immutable members so ok to cast
			return cast(typeof(return))raw.ptr[0 .. decodeRawLength(raw.length)]; // no allocation
		else
			return small.data.ptr[0 .. decodeRawLength(small.length)].idup; // need duplicate to make `immutable`
	}

	@nogc:

	/** Get hash of `this`, with extra fast computation for the small case.
	 */
	@property hash_t toHash() const scope @trusted {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		import core.internal.hash : hashOf;
		import nxt.hash_functions : lemireHash64;
		if (isLarge)
			return hashOf(opSliceLarge()); // use default
		else					// fast path for small string
			return (lemireHash64(words[0] >> 1) ^ // shift away LS-bit being a constant for a small string
					lemireHash64(words[1]));
	}

	/** Get length. */
	@property size_t length() const scope @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		if (isLarge)
			return decodeRawLength(large.length); // skip first bit
		else
			return decodeRawLength(small.length); // skip fist bit
	}
	/// ditto
	alias opDollar = length;

	/** Check if `this` is empty. */
	bool empty() const @property scope pure nothrow @safe @nogc {
		return length == 0;
	}

	/** Check if `this` is `null`. */
	@property bool isNull() const scope @trusted pure nothrow @nogc	{
		return raw.length == 0;
	}

	/** Return a slice to either the whole large or whole small `string`.
	 *
	 * Implementation is kept in sync with `toString`.
	 */
	inout(char)[] opSlice() inout scope return @trusted @nogc {
		version (D_Coverage) {} else pragma(inline, true);   /+ TODO: maybe remove +/
		if (isLarge)
			return opSliceLarge();
		else
			return opSliceSmall();
	}

	/** Return a slice at `[i .. j]` to either the internally stored large or small `string`.
	 *
	 * Implementation is kept in sync with `toString`.
	 */
	inout(char)[] opSlice(size_t i, size_t j) inout return @safe {
		version (D_Coverage) {} else pragma(inline, true);
		return opSlice()[i .. j];
	}

	private inout(char)[] opSliceLarge() inout return scope @system @nogc
	in { version (unittest) assert(isLarge); }
	do {
		version (D_Coverage) {} else pragma(inline, true);
		return cast(typeof(return))raw.ptr[0 .. decodeRawLength(raw.length)]; // no allocation
		// alternative:  return large.ptr[0 .. large.length/2];
	}

	private inout(char)[] opSliceSmall() inout return @trusted @nogc
	in { version (unittest) assert(!isLarge); }
    do {
		version (D_Coverage) {} else pragma(inline, true);
		return cast(typeof(return))small.data.ptr[0 .. decodeRawLength(small.length)]; // scoped
	}

	/** Return the `index`ed `char` of `this`.
	 */
	ref inout(char) opIndex(size_t index) inout return @trusted	{
		version (D_Coverage) {} else pragma(inline, true);
		return opSlice()[index]; // does range check
	}

	/// Get pointer to the internally stored `char`s.
	@property private immutable(char)* ptr() const return @trusted {
		if (isLarge)
			return large.ptr;   // GC-heap pointer
		else
			return small.data.ptr; // stack pointer
	}

	/** Check if `this` is equal to `rhs`. */
	bool opEquals()(const scope auto ref typeof(this) rhs) const scope @trusted	{
		version (D_Coverage) {} else pragma(inline, true);
		return opSlice() == rhs.opSlice();
	}

	/** Check if `this` is equal to `rhs`. */
	bool opEquals()(const scope const(char)[] rhs) const scope @trusted	{
		version (D_Coverage) {} else pragma(inline, true);
		return opSlice() == rhs;
	}

	/** Compare `this` with `that`.
	 *
	 * See_Also: https://forum.dlang.org/post/muhfypwftdivluqdbmdf@forum.dlang.org
	 */
	@property int opCmp()(const scope typeof(this) that) const scope /*tlm*/ {
		version (D_Coverage) {} else pragma(inline, true);
		scope const a = this.opSlice();
		scope const b = that.opSlice();
		return a < b ? -1 : (a > b);
		// import core.internal.array.comparison : __cmp; // instead of `std.algorithm.comparison : cmp`;
		// return __cmp(this[], that[]);
	}

	bool opCast(T : bool)() const scope @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		if (isLarge)
			return large !is null;
		else
			return small.length != 0;
	}

	/** Support trait `isNullable`. */
	static immutable nullValue = typeof(this).init;

	/** Support trait `isHoleable`. */
	static immutable holeValue = typeof(this).asHole();

	/** Check if this a hole, meaning a removed/erase value. */
	bool isHole() const scope @safe nothrow @nogc {
		return words[0] == size_t.max;
	}

	/** That this a hole, meaning a removed/erase value. */
	void holeify() @system @nogc scope {
		words[0] = size_t.max;
		words[1] = size_t.max;
	}

	/** Returns: a holed `SSOString`, meaning a removed/erase value. */
	private static typeof(this) asHole() @system {
		typeof(return) result = void;
		result.holeify();
		return result;
	}

	/** Check if `this` is a small ASCII string. */
	bool isSmallASCII() const scope @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		static assert(largeLengthTagBitOffset == 0);// bit 0 of lsbyte not set => small
		// should be fast on 64-bit platforms:
		return ((words[0] & 0x_80_80_80_80__80_80_80_01UL) == 1 && // bit 0 of lsbyte is set => small
				(words[1] & 0x_80_80_80_80__80_80_80_80UL) == 0);
	}

private:

	/** Returns: `true` iff this is a large string, otherwise `false.` */
	@property bool isLarge() const scope @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		return !(large.length & (1 << largeLengthTagBitOffset)); // first bit discriminates small from large
	}

	alias Large = immutable(char)[];

	public enum smallCapacity = Large.sizeof - Small.length.sizeof;
	static assert(smallCapacity > 0, "No room for small source for immutable(char) being " ~ immutable(char).stringof);

	enum largeLengthTagBitOffset = 0; ///< bit position for large tag in length.
	enum smallLengthBitCount = 4;
	static assert(smallCapacity == 2^^smallLengthBitCount-1);

	enum metaBits = 3;			   ///< Number of bits used for metadata.
	enum metaMask = (2^^metaBits-1); ///< Mask for metadata shifted to bottom.
	enum tagsBitCount = 1 + metaBits; ///< Number of bits used for small discriminator plus extra meta data.
	static assert(smallLengthBitCount + tagsBitCount == 8);

	/// Get metadata byte with first `metaBits` bits set.
	@property ubyte metadata() const pure nothrow @safe @nogc {
		return (small.length >> (1 << largeLengthTagBitOffset)) & metaMask; // git bits [1 .. 1+metaBits]
	}

	/// Set metadata.
	@property void metadata(ubyte data) @trusted pure nothrow @nogc in(data < (1 << metaBits)) {
		if (isLarge)
			raw.length = encodeLargeLength(length) | ((data & metaMask) << (largeLengthTagBitOffset + 1));
		else
			small.length = cast(ubyte)encodeSmallLength(length) | ((data & metaMask) << (largeLengthTagBitOffset + 1));
	}

	/// Decode raw length `rawLength` by shifting away tag bits.
	static size_t decodeRawLength(size_t rawLength) pure nothrow @safe @nogc {
		return rawLength >> tagsBitCount;
	}

	/// Encode `Large` length from `Length`.
	static size_t encodeLargeLength(size_t length) pure nothrow @safe @nogc {
		return (length << tagsBitCount);
	}

	/// Encode `Small` length from `Length`.
	static size_t encodeSmallLength(size_t length) pure nothrow @safe @nogc
	in(length <= smallCapacity) {
		return (length << tagsBitCount) | (1 << largeLengthTagBitOffset);
	}

	version (LittleEndian) { // See: http://forum.dlang.org/posting/zifyahfohbwavwkwbgmw
		struct Small {
			/* TODO: only first 4 bits are needed to represent a length between
			 * 0-15, use other 4 bits.
			 */
			ubyte length = 0;
			immutable(char)[smallCapacity] data = [0,0,0,0,0,
												   0,0,0,0,0,
												   0,0,0,0,0]; // explicit init needed for `__traits(isZeroInit)` to be true.
		}
	} else {
		struct Small {
			immutable(char)[smallCapacity] data = [0,0,0,0,0,
												   0,0,0,0,0,
												   0,0,0,0,0]; // explicit init needed for `__traits(isZeroInit)` to be true.
			/* TODO: only first 4 bits are needed to represent a length between
			 * 0-15, use other 4 bits.
			 */
			ubyte length;
		}
		static assert(0, "TODO: add BigEndian support and test");
	}

	struct Raw {				  // same memory layout as `immutable(char)[]`
		size_t length = 0;	  // can be bit-fiddled without GC allocation
		immutable(char)* ptr = null;
	}

	union {
		Raw raw;
		Large large;
		Small small;
		size_t[2] words;
	}
}
version (unittest) static assert(SSOString.sizeof == string.sizeof);

/** Returns: `x` lowercased. */
SSOString toLower()(const SSOString x) @trusted /*tlm*/
{
	if (x.isSmallASCII)	{		 // small ASCII fast-path
		typeof(return) result = void;
		result.small.length = x.small.length;
		import std.ascii : toLower;
		foreach (const index; 0 .. x.smallCapacity)
			(cast(char[])(result.small.data))[index] = toLower(x.small.data[index]);
		return result;
	} else if (x.isLarge) {
		import std.uni : asLowerCase;
		import std.conv : to;
		return typeof(return)(x.opSlice().asLowerCase.to!string); /+ TODO: make .to!string nothrow +/
	} else {				   // small non-ASCII path usually without GC-allocation
		typeof(return) result = x; // copy
		import std.uni : toLowerInPlace;
		auto slice = cast(char[])(result.opSlice()); // need ref to slice
		toLowerInPlace(slice);
		if (slice is result.opSlice() || // no reallocation
			slice.length == result.length) // or same length (happens for German double-s)
			return result;
		else
			// version (none)
			// {
			//	 import nxt.debugio;
			//	 dbg(`toLowerInPlace reallocated from "`,
			//		 result.opSlice(), `" of length `, result.opSlice().length,
			//		 ` to "`
			//		 , slice, `" of length `, slice.length);
			// }
			return typeof(return)(slice); // reallocation occurred
	}
}

/** Returns: `x` uppercased. */
SSOString toUpper()(const SSOString x) @trusted /*tlm*/
{
	if (x.isSmallASCII)	{		 // small ASCII fast-path
		typeof(return) result = void;
		result.small.length = x.small.length;
		import std.ascii : toUpper;
		foreach (const index; 0 .. x.smallCapacity)
			(cast(char[])(result.small.data))[index] = toUpper(x.small.data[index]);
		return result;
	} else if (x.isLarge) {
		import std.uni : asUpperCase;
		import std.conv : to;
		return typeof(return)(x.opSlice().asUpperCase.to!string); /+ TODO: make .to!string nothrow +/
	} else {				   // small non-ASCII path usually without GC-allocation
		typeof(return) result = x; // copy
		import std.uni : toUpperInPlace;
		auto slice = cast(char[])(result.opSlice()); // need ref to slice
		toUpperInPlace(slice);
		if (slice is result.opSlice() || // no reallocation
			slice.length == result.length) // or same length (happens for German double-s)
			return result;
		else
			// version (none)
			// {
			//	 import nxt.debugio;
			//	 dbg(`toUpperInPlace reallocated from "`,
			//		 result.opSlice(), `" of length `, result.opSlice().length,
			//		 ` to "`
			//		 , slice, `" of length `, slice.length);
			// }
			return typeof(return)(slice); // reallocation occurred
	}
}

/// construct from non-immutable source is allowed in non-`@nogc`-scope
pure nothrow @safe unittest {
	alias S = SSOString;

	scope const char[] x0;
	const s0 = SSOString(x0);		   // no .idup

	scope const char[] x16 = new char[16];
	const s16 = SSOString(x16);		 // will call .idup
}

/// construct from non-immutable source is not allowed in `@nogc`-scope
pure nothrow @safe @nogc unittest {
	scope const char[] s;
	/+ TODO: why does this fail? static assert(!__traits(compiles, { const _ = SSOString(s); })); +/
}

/// verify `isNull` when @nogc constructing from small static array of `char`s
@trusted pure nothrow @nogc unittest {
	static foreach (const n; 0 .. SSOString.smallCapacity + 1) {
		{
			immutable(char)[n] x;
			assert(!SSOString(x).isNull);
		}
	}
}

/// verify `isNull` when constructing from large static array of `char`s
@trusted pure nothrow unittest {
	static foreach (const n; SSOString.smallCapacity + 1 .. 32) {
		{
			immutable(char)[n] x;
			assert(!SSOString(x).isNull);
		}
	}
}

/// verify `isNull` when constructing from dynamic array of `char`s
@trusted pure nothrow unittest {
	foreach (const n; 0 .. 32) {
		scope x = new immutable(char)[n];
		assert(!SSOString(x).isNull);
	}
}

/// test behaviour of `==` and `is` operator
@trusted pure nothrow @nogc unittest {
	const SSOString x = "42";
	assert(!x.isNull);
	assert(x == "42");

	const SSOString y = "42";
	assert(!y.isNull);
	assert(y == "42");

	assert(x == y);
	assert(x == y[]);
	assert(x[] == y);
	assert(x[] == y[]);
	assert(x[] is x[]);
	assert(y[] is y[]);
	assert(x[] !is y[]);
	assert(x.ptr !is y.ptr);

	const SSOString z = "43";
	assert(!z.isNull);
	assert(z == "43");
	assert(x != z);
	assert(x[] != z[]);
	assert(x !is z);
	assert(x[] !is z[]);
}

///
pure nothrow @safe @nogc unittest {
	static assert(SSOString.smallCapacity == 15);

	import nxt.gc_traits : mustAddGCRange;
	static assert(mustAddGCRange!SSOString); // `Large large.ptr` must be scanned

	static assert(__traits(isZeroInit, SSOString));
	/+ TODO: assert(SSOString.init == SSOString.nullValue); +/

	auto s0 = SSOString.init;
	assert(s0.isNull);
	assert(s0.length == 0);
	assert(s0.isLarge);
	assert(s0[] == []);

	char[SSOString.smallCapacity] charsSmallCapacity = "123456789_12345"; // fits in small string
	const sSmallCapacity = SSOString(charsSmallCapacity);
	assert(!sSmallCapacity.isLarge);
	assert(sSmallCapacity.length == SSOString.smallCapacity);
	() @trusted { assert(sSmallCapacity == charsSmallCapacity); }(); // TODO: -dip1000 without @trusted

	const s0_ = SSOString("");
	assert(!s0_.isNull);		 // cannot distinguish
	() @trusted { assert(s0 == s0_); }(); // TODO: -dip1000 without @trusted

	const s7 = SSOString("0123456");
	assert(!s7.isNull);

	const s7_ = SSOString("0123456_"[0 .. $ - 1]);
	assert(s7.ptr !is s7_.ptr); // string data shall not overlap
	() @trusted { assert(s7 == s7_); }(); // TODO: -dip1000 without @trusted

	const _s7 = SSOString("_0123456"[1 .. $]); // source from other string literal
	assert(s7.ptr !is _s7.ptr); // string data shall not overlap
	() @trusted { assert(s7 == _s7); }(); // TODO: -dip1000 without @trusted

	assert(!s7.isLarge);
	assert(s7.length == 7);
	assert(s7[] == "0123456");
	assert(s7[] == "_0123456"[1 .. $]);
	assert(s7[] == "0123456_"[0 .. $ - 1]);
	assert(s7[0 .. 4] == "0123");

	const s15 = SSOString("0123456789abcde");
	assert(!s15.isNull);
	static assert(is(typeof(s15[]) == const(char)[]));
	assert(!s15.isLarge);
	assert(s15.length == 15);
	assert(s15[] == "0123456789abcde");
	assert(s15[0 .. 4] == "0123");
	assert(s15[10 .. 15] == "abcde");
	assert(s15[10 .. $] == "abcde");

	const s16 = SSOString("0123456789abcdef");
	assert(!s16.isNull);
	static assert(is(typeof(s16[]) == const(char)[]));
	assert(s16.isLarge);

	const s16_ = SSOString("0123456789abcdef_"[0 .. s16.length]);
	assert(s16.length == s16_.length);
	assert(s16[] == s16_[]);
	assert(s16.ptr !is s16_.ptr); // string data shall not overlap
	() @trusted { assert(s16 == s16_); }(); // but contents is equal // TODO: -dip1000 without @trusted

	const _s16 = SSOString("_0123456789abcdef"[1 .. $]);
	assert(s16.length == _s16.length);
	assert(s16[] == _s16[]);	// contents is equal
	() @trusted { assert(s16 == _s16); }(); // contents is equal // TODO: -dip1000 without @trusted

	assert(s16.length == 16);
	assert(s16[] == "0123456789abcdef");
	assert(s16[0] == '0');
	assert(s16[10] == 'a');
	assert(s16[15] == 'f');
	assert(s16[0 .. 4] == "0123");
	assert(s16[10 .. 16] == "abcdef");
	assert(s16[10 .. $] == "abcdef");
}

/// metadata for null string
pure nothrow @safe @nogc unittest {
	auto s = SSOString.init;
	assert(s.isNull);
	foreach (const i; 0 .. 8) {
		s.metadata = i;
		assert(s.metadata == i);
		assert(s.length == 0);
	}
}

/// metadata for small string
pure nothrow @safe @nogc unittest {
	auto s = SSOString("0123456");
	assert(!s.isNull);
	assert(!s.isLarge);
	foreach (const i; 0 .. 8) {
		s.metadata = i;
		assert(s.metadata == i);
		assert(s.length == 7);
		assert(!s.isLarge);
		assert(!s.isNull);
	}
}

/// metadata for small string with maximum length
pure nothrow @safe @nogc unittest {
	auto s = SSOString("0123456789abcde");
	assert(s.length == SSOString.smallCapacity);
	assert(!s.isNull);
	assert(!s.isLarge);
	foreach (const i; 0 .. 8) {
		s.metadata = i;
		assert(s.metadata == i);
		assert(s.length == 15);
		assert(!s.isLarge);
		assert(!s.isNull);
	}
}

/// metadata for large string with minimum length
pure nothrow @safe @nogc unittest {
	auto s = SSOString("0123456789abcdef");
	assert(s.length == SSOString.smallCapacity + 1);
	assert(!s.isNull);
	assert(s.isLarge);
	assert(!s.empty);
	foreach (const i; 0 .. 8) {
		s.metadata = i;
		assert(s.metadata == i);
		assert(s.length == 16);
		assert(s.isLarge);
		assert(!s.isNull);
	}
}

/// equality and equivalence
pure nothrow @safe @nogc unittest {
	() @trusted { assert(SSOString() == SSOString("")); }(); // TODO: -dip1000 without @trusted
	() @trusted { assert(SSOString() !is SSOString("")); }(); // TODO: -dip1000 without @trusted
}

/// hashing of null, empty and non-empty
pure nothrow @safe @nogc unittest {
	assert(SSOString().toHash == 0);
	assert(SSOString("").toHash == 0);
	assert(SSOString("a").toHash != 0);
	assert(SSOString("0123456789abcdef").toHash != 0);
}

/// construct from static array larger than `smallCapacity`
pure nothrow @safe unittest {
	char[SSOString.smallCapacity + 1] charsMinLargeCapacity;
	const _ = SSOString(charsMinLargeCapacity);
}

// test construction from range
pure @safe unittest {
	static void test(const scope char[] x, const bool isLarge) @safe pure {
		import std.utf : byDchar;
		const scope s = SSOString(x.byDchar);
		() @trusted { assert(s == x); }(); // TODO: -dip1000 without @trusted
		assert(s.isLarge == isLarge);
	}
	test("", false);
	test("_", false);
	test("123456789_12345", false);
	test("123456789_123456", true);
	test("123456789_123456789_123456789_", true);
}

/// hole handling
@trusted pure nothrow @nogc unittest {
	assert(!SSOString.init.isHole);
	assert(!SSOString("").isHole);
	assert(!SSOString("a").isHole);
	assert(SSOString.asHole.isHole);
}

/// DIP-1000 return ref escape analysis
pure nothrow @safe unittest {
	static if (hasPreviewDIP1000)
	{
		static assert(!__traits(compiles, { immutable(char)* f1() @safe pure nothrow { SSOString x; return x.ptr; } }));
		static assert(!__traits(compiles, { string f1() @safe pure nothrow { SSOString x; return x[]; } }));
		static assert(!__traits(compiles, { string f2() @safe pure nothrow { SSOString x; return x.toString; } }));
		static assert(!__traits(compiles, { ref immutable(char) g() pure nothrow @safe @nogc { SSOString x; return x[0]; } }));
	}
}

/// ASCII purity and case-conversion
pure nothrow @safe @nogc unittest {
	// these are all small ASCII
	assert( SSOString("a").isSmallASCII);
	assert( SSOString("b").isSmallASCII);
	assert( SSOString("z").isSmallASCII);
	assert( SSOString("_").isSmallASCII);
	assert( SSOString("abcd").isSmallASCII);
	assert( SSOString("123456789_12345").isSmallASCII);

	// these are not
	assert(!SSOString("123456789_123456").isSmallASCII); // too large
	assert(!SSOString("123456789_123ö").isSmallASCII);
	assert(!SSOString("ö").isSmallASCII);
	assert(!SSOString("Ö").isSmallASCII);
	assert(!SSOString("åäö").isSmallASCII);
	assert(!SSOString("ö-värld").isSmallASCII);
}

/// ASCII purity and case-conversion
pure @safe unittest {
	assert(SSOString("A").toLower[] == "a");
	assert(SSOString("a").toUpper[] == "A");
	assert(SSOString("ABCDEFGHIJKLMNO").toLower[] == "abcdefghijklmno"); // small
	assert(SSOString("abcdefghijklmno").toUpper[] == "ABCDEFGHIJKLMNO"); // small
	assert(SSOString("ÅÄÖ").toLower[] == "åäö");
	assert(SSOString("åäö").toUpper[] == "ÅÄÖ");
	assert(SSOString("ABCDEFGHIJKLMNOP").toLower[] == "abcdefghijklmnop"); // large
	assert(SSOString("abcdefghijklmnop").toUpper[] == "ABCDEFGHIJKLMNOP"); // large

	char[6] x = "ÅÄÖ";
	import std.uni : toLowerInPlace;
	auto xref = x[];
	() @trusted { toLowerInPlace(xref); }(); // TODO: -dip1000 without @trusted
	assert(x == "åäö");
	assert(xref == "åäö");
}

/// lexicographic comparison
pure @safe unittest {
	const SSOString a = SSOString("a");
	() @trusted { assert(a == SSOString("a")); }(); // TODO: -dip1000 without @trusted

	immutable SSOString b = SSOString("b");

	() @trusted { assert(a < b); }(); // TODO: -dip1000 without @trusted
	() @trusted { assert(b > a); }(); // TODO: -dip1000 without @trusted
	assert(a[] < b[]);

	assert("a" < "b");
	assert("a" < "å");
	assert("Å" < "å");
	() @trusted { assert(SSOString("a") < SSOString("å")); }(); // TODO: -dip1000 without @trusted
	() @trusted { assert(SSOString("ÅÄÖ") < SSOString("åäö")); }(); // TODO: -dip1000 without @trusted
}

/// cast to bool
pure @safe unittest {
	// mimics behaviour of casting of `string` to `bool`
	() @trusted { assert(!SSOString()); }(); // TODO: -dip1000 without @trusted
	() @trusted { assert(SSOString("")); }(); // TODO: -dip1000 without @trusted
	() @trusted { assert(SSOString("abc")); }(); // TODO: -dip1000 without @trusted
}

/// to string conversion
pure @safe unittest {
	// mutable small will GC-allocate
	{
		SSOString s = SSOString("123456789_12345");
		assert(s.ptr is &s.opSlice()[0]);
		assert(s.ptr !is &s.toString()[0]);
	}

	// const small will GC-allocate
	{
		const SSOString s = SSOString("123456789_12345");
		assert(s.ptr is &s.opSlice()[0]);
		assert(s.ptr !is &s.toString()[0]);
	}

	// immutable small will not allocate
	{
		immutable SSOString s = SSOString("123456789_12345");
		assert(s.ptr is &s.opSlice()[0]);
		assert(s.ptr is &s.toString()[0]);
		/+ TODO: check return via -dip1000 +/
	}

	/* Forbid return of possibly locally scoped `Smll` small stack object
	 * regardless of head-mutability.
	 */
	static if (hasPreviewDIP1000) {
		static assert(!__traits(compiles, { immutable(char)* f1() @safe pure nothrow { SSOString x; return x.ptr; } }));
		static assert(!__traits(compiles, { immutable(char)* f1() @safe pure nothrow { const SSOString x; return x.ptr; } }));
		static assert(!__traits(compiles, { immutable(char)* f1() @safe pure nothrow { immutable SSOString x; return x.ptr; } }));

		/** TODO: Enable the following line when DIP-1000 works for opSlice()
		 *
		 * See_Also: https://issues.dlang.org/show_bug.cgi?id=18792
		 */
		// static assert(!__traits(compiles, { string f1() @safe pure nothrow { immutable SSOString x; return x[]; } }));
	}

	// large will never allocate regardless of head-mutability
	{
		SSOString s = SSOString("123456789_123456");
		assert(s.ptr is &s.opSlice()[0]);
		assert(s.ptr is &s.toString()[0]); // shouldn't this change?
	}
}

version (unittest)
{
	import nxt.dip_traits : hasPreviewDIP1000;
}
