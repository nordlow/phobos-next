/** Bitarray.
 */
module nxt.container.bitarray;

@safe:

/** Array of bits.
 *
 * Like `std.bitmanip.BitArray` but pure nothrow @safe @nogc.
 *
 * Set `blockAlignedLength` to true if `this.length` is always a multiple of
 * `Block.size`.
 *
 * TODO: use `Flag` instead, or wrap in `BlockAlignedBitArray` where this class
 * is made private _BitArray and alias BitArray = _BitArray!(true).
 *
 * TODO: support append bit via `pushBack(bool)`.
 */
struct BitArray(bool blockAlignedLength = false,
				alias Allocator = null) /* TODO: use Allocator */
{
	import core.bitop : bt, bts, btr;
	import nxt.bitarray_algorithm;

	pure nothrow @safe @nogc:

	/** Helper constructor for `length` number of bits. */
	private this(size_t length) @trusted
	in {
		static if (blockAlignedLength)
			assert(length % bitsPerBlock == 0,
				   "Parameter `length` is not a multiple `Block` bit size " ~ bitsPerBlock.stringof);
	} do {
		static if (blockAlignedLength)
			_blockCount = length / bitsPerBlock; // number of whole blocks
		else {
			_blockCount = (length + bitsPerBlock-1) / bitsPerBlock;
			_length = length;
		}
		_blockPtr = cast(Block*)fakePureCalloc(bitsPerBlock, _blockCount); /* TODO: use `Allocator` */
	}

	/** Helper constructor. */
	private this(size_t length, const scope Block[] blocks) @trusted {
		_blockCount = blocks.length;
		_blockPtr = cast(Block*)fakePureMalloc(bitsPerBlock * _blockCount); /* TODO: use `Allocator` */
		_blocks[] = blocks; // copy block array
		static if (!blockAlignedLength) {
			_length = length;
		}
	}

	/** Construct with `length` number of zero bits stored in `blocks`. */
	private static typeof(this) withLengthAndBlocks(size_t length, const scope Block[] blocks)
		=> typeof(return)(length, blocks);

	/// Destroy.
	~this() nothrow @nogc => release();

	/// Explicit copying (duplicate).
	typeof(this) dup() => typeof(this).withLengthAndBlocks(_length, _blocks);

	/// Empty.
	void clear() {
		release();
		resetInternalData();
	}

	/// Release internal store.
	private void release() @trusted @nogc => fakePureFree(_blockPtr);

	/// Reset internal data.
	private void resetInternalData() {
		_blockPtr = null;
		_blockCount = 0;
		static if (!blockAlignedLength)
			_length = 0;
	}

	/// Set length.
	@property void length(size_t newLength) {
		if (newLength == length)
			return;
		auto that = typeof(this)(newLength);
		that._blocks[0 .. _blocks.length] = this._blocks;
		import std.algorithm.mutation : move;
		this = move(that);
	}

	/// Get length.
	@property size_t length() const => _length;
	alias opDollar = length;	/// ditto

	/// Get capacity in number of bits.
	@property size_t capacity() const => bitsPerBlock*_blockCount;

	/** Get the `i`'th bit. */
	bool opIndex(size_t i) const @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		assert(i < length);		/* TODO: nothrow or not? */
		return cast(bool)bt(_blockPtr, i);
	}

	/** Set the `i`'th bit to `value`. */
	bool opIndexAssign(bool value, size_t i) @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		if (value)
			bts(_blockPtr, i);
		else
			btr(_blockPtr, i);
		return value;
	}

	/** Set all bits to `value` via slice assignment syntax. */
	ref typeof(this) opSliceAssign(bool value) {
		if (value)
			one();
		else
			zero();
		return this;
	}

	/** Clear all bits (to zero). */
	private void zero() {
		foreach (ref block; _blocks)
			block = Block.min;
	}

	/** Set all bits (to one). */
	private void one() {
		foreach (ref block; _blocks)
			block = Block.max;
	}

	version (none)			   /* TODO: activate? */
	bool opCast(T : bool)() const => !this.allZero;

	/** Check if `this` has only zeros. */
	bool allZero()() const pure nothrow @safe @nogc {
		foreach (const block; _fullBlocks)
			if (block != Block.min)
				return false;
		static if (!blockAlignedLength)
			if (_restBlockZeroPadded != Block.min)
				return false;
		return true;
	}

	/** Check if `this` has only ones. */
	bool allOne()() const pure nothrow @safe @nogc {
		foreach (const block; _fullBlocks)
			if (block != Block.max)
				return false;
		static if (!blockAlignedLength)
			if (_restBlockOnePadded != Block.max)
				return false;
		return true;
	}

	/** Get number of bits set (to one). */
	size_t countOnes()() const /*tlm*/
		=> nxt.bitarray_algorithm.countOnes!(const(Block)[], blockAlignedLength)(_blocks, length);

	/** Get number of bits cleared (to zero). */
	size_t countZeros()() const /*tlm*/
		=> length - countOnes;

	/** Find index of first set (one) bit or `length` if no bit set.
	 *
	 * Optimized for ones-sparsity.
	 */
	size_t indexOfFirstOne()() const /*tlm*/
		=> nxt.bitarray_algorithm.indexOfFirstOne!(const(Block)[], blockAlignedLength)(_blocks, length);

	/** Find index of first cleared (zero) bit or `length` if no bit cleared.
	 *
	 * Optimized for zeros-sparsity.
	 */
	size_t indexOfFirstZero()() const /*tlm*/
		=> nxt.bitarray_algorithm.indexOfFirstZero!(const(Block)[], blockAlignedLength)(_blocks, length);

	/** Equality, operators == and !=. */
	bool opEquals(const scope ref typeof(this) rhs) const @trusted /* TODO: use `in ref` when it compiles */
	{
		static if (!blockAlignedLength)
			if (length != rhs.length)
				return false;
		if (_fullBlocks != rhs._fullBlocks)
			return false;
		static if (!blockAlignedLength) {
			const restBitCount = length % bitsPerBlock;
			if (restBitCount)
				return _restBlockZeroPadded == rhs._restBlockZeroPadded;
		}
		return true;
	}

	/** Only explicit copying via `.dup` for now. */
	this(this) @disable;

private:

	/** Get all blocks including the last being potentially not fully occupied. */
	inout(Block)[] _blocks() inout @trusted => _blockPtr[0 .. _blockCount];

	/** Get Blocks where all the bits are used (not ignored). */
	static if (blockAlignedLength)
		inout(Block)[] _fullBlocks() inout @trusted => _blocks;	 // all bits of all blocks are used
	else {
		inout(Block)[] _fullBlocks() inout @trusted => _blocks.ptr[0 .. (length / bitsPerBlock)];
		/** Return rest `Block` with all padding bits set to zero. */
		Block _restBlockZeroPadded() const @trusted => _blocks[$-1] & ((1UL << (length % bitsPerBlock)) - 1);
	}

	alias Block = size_t;
	enum bitsPerBlock = 8*Block.sizeof; /// Number of bits per `Block`.

	/** Number of Block's allocated at `_blockPtr`. */
	size_t _blockCount;

	static if (is(Allocator == std.experimental.allocator.gc_allocator.GCAllocator))
		Block* _blockPtr;	   // GC-allocated store pointer
	else {
		import nxt.gc_traits : NoGc;
		@NoGc Block* _blockPtr; // non-GC-allocated store pointer
	}

	static if (blockAlignedLength)
		@property size_t _length() const => bitsPerBlock * _blockCount;
	else
		size_t _length;
}

/// Test `_blockCount` and `_fullBlocks.length`.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		import nxt.construction : makeOfLength;
		alias BA = BitArray!(blockAlignedLength);

		assert(makeOfLength!BA(0)._blockCount == 0);
		assert(makeOfLength!BA(1)._blockCount == 1);

		{
			auto a = makeOfLength!BA(1*BA.bitsPerBlock - 1);
			assert(a._blockCount == 1);
			assert(a._fullBlocks.length == 0);
		}

		{
			auto a = makeOfLength!BA(1*BA.bitsPerBlock + 0);
			assert(a._blockCount == 1);
			assert(a._fullBlocks.length == 1);
		}

		{
			auto a = makeOfLength!BA(1*BA.bitsPerBlock + 1);
			assert(a._blockCount == 2);
			assert(a._fullBlocks.length == 1);
		}

		{
			auto a = makeOfLength!BA(2*BA.bitsPerBlock - 1);
			assert(a._blockCount == 2);
			assert(a._fullBlocks.length == 1);
		}

		{
			auto a = makeOfLength!BA(2*BA.bitsPerBlock + 0);
			assert(a._blockCount == 2);
			assert(a._fullBlocks.length == 2);
		}

		{
			auto a = makeOfLength!BA(2*BA.bitsPerBlock + 1);
			assert(a._blockCount == 3);
			assert(a._fullBlocks.length == 2);
		}
	}
	test!(false)();
}

/// Test indexing and element assignment.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)(size_t length) {
		alias BA = BitArray!(blockAlignedLength);

		auto a = makeOfLength!BA(length);

		assert(a.length == length);
		foreach (const i; 0 .. length)
			assert(!a[i]);

		a[0] = true;
		assert(a[0]);
		foreach (const i; 1 .. length)
			assert(!a[i]);

		assert(!a[1]);
		a[1] = true;
		assert(a[1]);
		a[1] = false;
		assert(!a[1]);
	}
	test!(false)(100);
	test!(true)(64);
}

/// Test `countOnes` and `countZeros`.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		foreach (const n; 1 .. 5*BA.bitsPerBlock) {
			static if (blockAlignedLength)
				if (n % BA.bitsPerBlock != 0) // if block aligned length
					continue;

			auto a = makeOfLength!BA(n);

			// set bits forwards
			foreach (const i; 0 .. n) {
				assert(a.countOnes == i);
				assert(a.countZeros == n - i);
				a[i] = true;
				assert(a.countOnes == i + 1);
				assert(a.countZeros == n - (i + 1));
			}

			assert(a.countOnes == n);
			assert(a.countZeros == 0);

			auto b = a.dup;
			assert(b.countOnes == n);
			assert(b.countZeros == 0);

			assert(a == b);

			// clear `a` bits forwards
			foreach (const i; 0 .. n) {
				assert(a.countOnes == n - i);
				assert(a.countZeros == i);
				a[i] = false;
				assert(a.countOnes == n - (i + 1));
				assert(a.countZeros == i + 1);
			}

			b[] = false;
			assert(a == b);

			// set bits backwards
			foreach (const i; 0 .. n) {
				assert(a.countOnes == i);
				a[n-1 - i] = true;
				assert(a.countOnes == i + 1);
			}

			b[] = true;
			assert(a == b);
		}
	}
	test!(false)();
	test!(true)();
}

/// Test emptying (resetting) via `.clear` and explicit copying with `.dup`.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 5 * BA.bitsPerBlock;
		else
			const n = 5 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		assert(a.length == n);

		a.clear();
		assert(a.length == 0);

		a = makeOfLength!BA(n);
		assert(a.length == n);

		auto b = a.dup;
		assert(b.length == n);

		a.clear();
		assert(a.length == 0);
	}
	test!(false)();
	test!(true)();
}

/// Test `indexOfFirstOne` for single set ones.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		assert(a.length == n);
		assert(a.indexOfFirstOne == n); // miss

		a[0] = true;
		assert(a.indexOfFirstOne == 0);
		a[] = false;

		a[2] = true;
		assert(a.indexOfFirstOne == 2);
		a[] = false;

		a[n/2-1] = true;
		assert(a.indexOfFirstOne == n/2-1);
		a[] = false;

		a[n/2] = true;
		assert(a.indexOfFirstOne == n/2);
		a[] = false;

		a[n/2+1] = true;
		assert(a.indexOfFirstOne == n/2+1);
		a[] = false;

		a[n-1] = true;
		assert(a.indexOfFirstOne == n-1);
		a[] = false;

		assert(a.indexOfFirstOne == n); // miss
	}
	test!(false)();
	test!(true)();
}

/// Test `indexOfFirstOne` for multi set ones.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		a[0] = true;
		a[BA.bitsPerBlock/2] = true;
		a[BA.bitsPerBlock - 1] = true;
		assert(a.indexOfFirstOne == 0);
	}
	test!(false)();
	test!(true)();
}

/// Test `indexOfFirstZero` for single set zeros.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		a[] = true;

		assert(a.length == n);
		assert(a.indexOfFirstZero == n); // miss

		a[0] = false;
		assert(a.indexOfFirstZero == 0);
		a[0] = true;

		a[2] = false;
		assert(a.indexOfFirstZero == 2);
		a[2] = true;

		a[n/2-1] = false;
		assert(a.indexOfFirstZero == n/2-1);
		a[n/2-1] = true;

		a[n/2] = false;
		assert(a.indexOfFirstZero == n/2);
		a[n/2] = true;

		a[n/2+1] = false;
		assert(a.indexOfFirstZero == n/2+1);
		a[n/2+1] = true;

		a[n-1] = false;
		assert(a.indexOfFirstZero == n-1);
		a[n-1] = true;

		assert(a.indexOfFirstZero == n); // miss
	}
	test!(false)();
	test!(true)();
}

pure nothrow @safe @nogc unittest {
	alias BA = BitArray!(false);
	static assert(BitArray!(false).sizeof == 3*BA.Block.sizeof); // one extra word for `length`
	static assert(BitArray!(true).sizeof == 2*BA.Block.sizeof);
}

/// Test `indexOfFirstZero` for multi set zeros.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		a[] = true;

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
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		a[] = false;

		a[0] = true;
		a[BA.bitsPerBlock/2] = true;
		a[BA.bitsPerBlock - 1] = true;
		assert(a.indexOfFirstOne == 0);
	}
	test!(false)();
	test!(true)();
}

/// Test casting to `bool`.
pure nothrow @safe @nogc unittest {
	static void test(bool blockAlignedLength)() {
		alias BA = BitArray!(blockAlignedLength);

		static if (blockAlignedLength)
			const n = 2 * BA.bitsPerBlock;
		else
			const n = 2 * BA.bitsPerBlock + 1;
		auto a = makeOfLength!BA(n);

		assert(a.allZero);

		a[0] = true;
		assert(!a.allZero);
		a[0] = false;
		assert(a.allZero);
	}
	test!(false)();
}

///
@trusted pure unittest {
	import std.exception: assertThrown;
	import core.exception : AssertError;
	alias BA = BitArray!(true);
	assertThrown!AssertError(makeOfLength!BA(1));
}

extern (C) private pure @system @nogc nothrow {
	pragma(mangle, "malloc") void* fakePureMalloc(size_t);
	pragma(mangle, "calloc") void* fakePureCalloc(size_t nmemb, size_t size);
	pragma(mangle, "realloc") void* fakePureRealloc(void* ptr, size_t size);
	pragma(mangle, "free") void fakePureFree(void* ptr);
}

version (unittest) {
	import nxt.construction : makeOfLength;
}
