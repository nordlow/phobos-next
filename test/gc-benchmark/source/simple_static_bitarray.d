/**
 * Static bit array container for internal usage.
 */
module simple_static_bitarray;

@safe:

alias DefaultBlock = size_t;	///< Default block type.

@safe struct StaticBitArray(uint capacity)
{
	pure nothrow @nogc:
	import core.bitop : bt, bts, btr;

	/** Number of bits. */
	enum length = capacity;

	alias Block = DefaultBlock; ///< Block type.

	/** Number of bits per `Block`. */
	enum bitsPerBlock = 8*Block.sizeof;

	/** Number of blocks of type `Block`. */
	enum blockCount = (capacity + (bitsPerBlock-1)) / bitsPerBlock;

	/** Reset all bits (to zero). */
	void reset()
	{
		version (D_Coverage) {} else pragma(inline, true);
		_blocks[] = 0;		  /+ TODO: is this the fastest way? +/
	}

	/** Gets the $(D idx)'th bit. */
	bool opIndex(size_t idx) const @trusted
	in(idx < length)			/+ TODO: nothrow or not? +/
	{
		version (D_Coverage) {} else pragma(inline, true);
		return cast(bool)bt(_blocks.ptr, idx);
	}

	/** Sets the $(D idx)'th bit. */
	bool opIndexAssign(bool b, size_t idx) @trusted
	in(idx < length)			/+ TODO: nothrow or not? +/
	{
		version (D_Coverage) {} else pragma(inline, true);
		if (b)
			bts(_blocks.ptr, cast(size_t)idx);
		else
			btr(_blocks.ptr, cast(size_t)idx);
		return b;
	}

	/** Find index of first cleared (zero) bit or `typeof(return).max` if no bit set.
	 *
	 * Optimized for zeros-sparsity.
	 */
	size_t indexOfFirstZero()() const
	{
		import nxt.bitarray_algorithm;
		enum bool blockAlignedLength = capacity % (8*Block.sizeof) == 0;
		return nxt.bitarray_algorithm.indexOfFirstZero!(const(Block)[blockCount],
														blockAlignedLength)(_blocks, length);
	}

	/** Find index of first set (one) bit or `typeof(return).max` if no bit set.
	 *
	 * Optimized for ones-sparsity.
	 */
	size_t indexOfFirstOne()() const
	{
		import nxt.bitarray_algorithm;
		enum bool blockAlignedLength = capacity % (8*Block.sizeof) == 0;
		return nxt.bitarray_algorithm.indexOfFirstOne!(const(Block)[blockCount],
													   blockAlignedLength)(_blocks, length);
	}

	private Block[blockCount] _blocks;
}

///
@trusted pure unittest {
	enum blockCount = 2;
	enum length = blockCount * 8*DefaultBlock.sizeof - 1; // 2 blocks minus one

	StaticBitArray!(length) x;
	static assert(x.blockCount == blockCount);

	// import std.exception: assertThrown;
	// import core.exception : AssertError;
	// assertThrown!AssertError(x[length] = false);

	x[length/2 - 1] = true;
	assert(x[length/2 - 1]);

	x[length/2 - 1] = false;
	assert(!x[length/2 - 1]);

	x[length - 1] = true;
	assert(x[length - 1]);

	x[length - 1] = false;
	assert(!x[length - 1]);
}

/// Test `indexOfFirstZero` for multi set zeros.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)()
	{
		static if (blockAlignedLength)
			const n = 2 * 8*DefaultBlock.sizeof;
		else
			const n = 2 * 8*DefaultBlock.sizeof + 1;
		alias BA = StaticBitArray!(n);

		auto a = BA();

		a[0] = false;
		a[BA.bitsPerBlock/2] = false;
		a[BA.bitsPerBlock - 1] = false;
		assert(a.indexOfFirstZero == 0);
	}
	test!(false)();
	test!(true)();
}

/// Test `indexOfFirstOne` for multi set ones.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)()
	{
		static if (blockAlignedLength)
			const n = 2 * 8*Block.sizeof;
		else
			const n = 2 * 8*DefaultBlock.sizeof + 1;
		alias BA = StaticBitArray!(n);

		auto a = BA();

		a[0] = true;
		a[BA.bitsPerBlock/2] = true;
		a[BA.bitsPerBlock - 1] = true;
		assert(a.indexOfFirstOne == 0);
	}
	test!(false)();
}
