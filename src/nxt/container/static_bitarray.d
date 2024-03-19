/** Statically sized variant of `std.bitmanip.BitArray.
 *
 * Copyright: Per Nordlöw 2022-.
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB Per Nordlöw)
 */
module nxt.container.static_bitarray;

@safe:

alias DefaultBlock = size_t;	///< Default block type.

import std.traits : isUnsigned;

/** A statically sized `std.bitmanip.BitArray`.
 *
 * TODO: Infer `Block` from `len` as is done for `Bound` and `Mod`.
 *
 * TODO: Optimize `allOne`, `allZero` using intrinsic?
 */
struct StaticBitArray(uint capacity, Block = DefaultBlock)
if (isUnsigned!DefaultBlock) {
@safe:
	import std.format : FormatSpec, format;
	import nxt.modulo : Mod;

	/** Number of bits.
	 *
	 * Length equals capacity.
	 */
	enum length = capacity;

	static if (capacity >= 1)
		alias Index = Mod!capacity;

	static if (Block.sizeof == 8)
		import core.bitop : bt, bts, btr;
	else
		import nxt.bitop_ex : bt, bts, btr;

	/** Number of bits per `Block`. */
	enum bitsPerBlock = 8*Block.sizeof;
	/** Number of `Block`s. */
	enum blockCount = (capacity + bitsPerBlock-1) / bitsPerBlock;

	/** Data stored as `Block`s. */
	private Block[blockCount] _blocks;

	/** Data as an array of unsigned bytes. */
	pragma(inline, true)
	inout(ubyte)[] ubytes()() inout @trusted => (cast(ubyte*)&_blocks)[0 .. _blocks.sizeof];

	/** Get pointer to data blocks. */
	pragma(inline, true)
	@property inout(Block*) ptr() inout @system => _blocks.ptr;

	/** Reset all bits (to zero). */
	pragma(inline, true)
	void reset()() {
		_blocks[] = 0;		  /+ TODO: is this fastest way? +/
	}
	alias clear = reset;

	/** Gets the amount of native words backing `this`. */
	pragma(inline, true)
	@property static uint dim() => blockCount;

	/** Bidirectional range into `BitArray`.
	 *
	 * TODO: Provide opSliceAssign for interopability with range algorithms via
	 * private static struct member `Range`.
	 *
	 * TODO: Look at how std.container.array implements this.
	 *
	 * See_Also: https://dlang.org/phobos/std_bitmanip.html#bitsSet
	*/
	struct Range()			  /*tlm*/
	{
		pure nothrow @safe @nogc:
		pragma(inline, true):

		/// Returns: `true` iff `this` is empty.
		bool empty()  const => _i == _j;

		/// Returns: `this` length.
		size_t length() const => _j - _i;

		import std.traits : isMutable;
		static if (isMutable!(typeof(_store)))
			this(this) @disable; // Rust-style mutable reference semantics

		bool front() const in(!empty) => (*_store)[_i];
		bool back() const in(!empty) => (*_store)[_j - 1];
		void popFront() in(!empty) { ++_i; }
		void popBack() in(!empty) { --_j; }

	private:
		StaticBitArray* _store;
		size_t _i = 0;			 // front iterator into _store
		size_t _j = _store.length; // back iterator into _store
	}

	pragma(inline, true)
	scope inout(Range!()) opSlice()() inout return @trusted => typeof(return)(&this);
	pragma(inline, true)
	scope inout(Range!()) opSlice()(in size_t i, size_t j) inout return @trusted => typeof(return)(&this, i, j);

	/** Set all bits to `value` via slice assignment syntax. */
	ref typeof(this) opSliceAssign(bool value) {
		if (value)
			one();
		else
			zero();
		return this;
	}

	/** Set all bits (to zero). */
	private void zero() {
		foreach (ref block; _blocks)
			block = Block.min;
	}

	/** Set all bits (to one). */
	private void one() {
		foreach (ref block; _blocks)
			block = Block.max;
	}

	/** Gets the $(D i)'th bit. */
	pragma(inline, true)
	bool opIndex(in size_t i) const @trusted
	in(i < capacity)			/+ TODO: nothrow or not? +/
	{
		// Andrei: review for @@@64-bit@@@
		static if (Block.sizeof == 8)
			return cast(bool)bt(ptr, i);
		else
			return bt(_blocks[i/bitsPerBlock], i%bitsPerBlock);
	}

	/** Gets the $(D i)'th bit. No range checking needed. */
	static if (capacity >= 1) {
		/** Get the $(D i)'th bit.
		 *
		 * Avoids range-checking because `i` of type is bound to (0 .. capacity-1).
		 */
		bool opIndex(ModUInt)(Mod!(capacity, ModUInt) i) const @trusted
		if (isUnsigned!ModUInt) {
			pragma(inline, true);
			static if (Block.sizeof == 8)
				return cast(bool)bt(ptr, cast(size_t)i);
			else
				return bt(_blocks[i/bitsPerBlock], i%bitsPerBlock);
		}

		/** Get the $(D i)'th bit.
		 *
		 * Statically verifies that i is < StaticBitArray length.
		 */
		pragma(inline, true)
		bool at(size_t i)() const if (i < capacity) => this[i];
	}

	/** Puts the $(D i)'th bit to $(D b). */
	pragma(inline, true)
	void put()(in size_t i, bool b) @trusted { this[i] = b; }

	/** Sets the $(D i)'th bit. */
	import std.traits : isIntegral;
	bool opIndexAssign(Index2)(bool b, Index2 i) @trusted
	if (isIntegral!Index2)
	in(i < capacity)
	in
	{
		// import std.traits: isMutable;
		// See_Also: http://stackoverflow.com/questions/19906516/static-parameter-function-specialization-in-d
		/* static if (!isMutable!Index2) { */
		/*	 import std.conv: to; */
		/*	 static assert(i < capacity, */
		/*				   "Index2 " ~ to!string(i) ~ " must be smaller than StaticBitArray length " ~  to!string(capacity)); */
		/* } */
	}
	do
	{
		pragma(inline, true);
		if (b)
			bts(ptr, cast(size_t)i);
		else
			btr(ptr, cast(size_t)i);
		return b;
	}

	static if (capacity >= 1) {
		/** Sets the $(D i)'th bit. No range checking needed. */
		pragma(inline, true)
		bool opIndexAssign(ModUInt)(bool b, Mod!(capacity, ModUInt) i) @trusted
		if (isUnsigned!ModUInt) {
			if (b)
				bts(ptr, cast(size_t)i);
			else
				btr(ptr, cast(size_t)i);
			return b;
		}
	}

	///
	pure nothrow @safe @nogc unittest
	{
		StaticBitArray!2 bs;
		bs[0] = true;
		assert(bs[0]);
		assert(!bs[1]);
		bs[1] = true;
		assert(bs[1]);
	}

	/** Support for $(D foreach) loops for $(D StaticBitArray). */
	int opApply(scope int delegate(ref bool) dg) @trusted
	{
		int result;
		foreach (const size_t i; 0 .. capacity) {
			bool b = opIndex(i);
			result = dg(b);
			this[i] = b;
			if (result) { break; }
		}
		return result;
	}

	/** ditto */
	int opApply(scope int delegate(bool) dg) const @trusted
	{
		int result;
		foreach (const size_t i; 0 .. capacity) {
			bool b = opIndex(i);
			result = dg(b);
			if (result) { break; }
		}
		return result;
	}

	/** ditto */
	int opApply(scope int delegate(const ref size_t, ref bool) dg) @trusted
	{
		int result;
		foreach (const size_t i; 0 .. capacity) {
			bool b = opIndex(i);
			result = dg(i, b);
			this[i] = b;
			if (result) { break; }
		}
		return result;
	}

	/** ditto */
	int opApply(scope int delegate(in size_t, bool) dg) const @trusted
	{
		int result;
		foreach (const size_t i; 0 .. capacity) {
			bool b = opIndex(i);
			result = dg(i, b);
			if (result) { break; }
		}
		return result;
	}

	///
	unittest
	{
		static bool[] ba = [1,0,1];
		auto a = StaticBitArray!3(ba);
		size_t i;
		foreach (immutable b; a[]) /+ TODO: is `opSlice` the right thing? +/
		{
			switch (i) {
			case 0: assert(b == true); break;
			case 1: assert(b == false); break;
			case 2: assert(b == true); break;
			default: assert(0);
			}
			i++;
		}
		foreach (j, b; a)	   /+ TODO: is `opSlice` the right thing? +/
		{
			switch (j) {
			case 0: assert(b == true); break;
			case 1: assert(b == false); break;
			case 2: assert(b == true); break;
			default: assert(0);
			}
		}
	}

	/** Reverse block `Block`. */
	static @property Block reverseBlock()(in Block block) {
		import core.bitop : bitswap;
		pragma(inline, true);
		static if (Block.sizeof == 4)
			return cast(uint)block.bitswap;
		else static if (Block.sizeof == 8)
			return (((cast(Block)((cast(uint)(block)).bitswap)) << 32) |
					(cast(Block)((cast(uint)(block >> 32)).bitswap)));
		else
			return block;
	}

	/** Reverses the bits of the $(D StaticBitArray) in place. */
	@property typeof(this) reverse()()
	out (result) {
		assert(result == this);
	}
	do
	{
		static if (length == blockCount * bitsPerBlock) {
			static if (blockCount == 1)
				_blocks[0] = reverseBlock(_blocks[0]);
			else static if (blockCount == 2) {
				const tmp = _blocks[1];
				_blocks[1] = reverseBlock(_blocks[0]);
				_blocks[0] = reverseBlock(tmp);
			}
			else static if (blockCount == 3) {
				const tmp = _blocks[2];
				_blocks[2] = reverseBlock(_blocks[0]);
				_blocks[1] = reverseBlock(_blocks[1]);
				_blocks[0] = reverseBlock(tmp);
			}
			else
			{
				size_t lo = 0;
				size_t hi = _blocks.length - 1;
				for (; lo < hi; ++lo, --hi) {
					immutable t = reverseBlock(_blocks[lo]);
					_blocks[lo] = reverseBlock(_blocks[hi]);
					_blocks[hi] = t;
				}
				if (lo == hi)
					_blocks[lo] = reverseBlock(_blocks[lo]);
			}
		}
		else
		{
			static if (length >= 2) {
				size_t lo = 0;
				size_t hi = capacity - 1;
				for (; lo < hi; ++lo, --hi) {
					immutable t = this[lo];
					this[lo] = this[hi];
					this[hi] = t;
				}
			}
		}
		return this;
	}

	///
	pure unittest
	{
		enum capacity = 64;
		static immutable bool[capacity] data = [0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0];
		auto b = StaticBitArray!capacity(data);
		b.reverse();
		foreach (const i; 0 .. data.length)
			assert(b[i] == data[capacity - 1 - i]);
	}

	///
	pure unittest
	{
		enum capacity = 64*2;
		static immutable bool[capacity] data = [0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0];
		auto b = StaticBitArray!capacity(data);
		b.reverse();
		foreach (const i; 0 .. data.length)
			assert(b[i] == data[capacity - 1 - i]);
	}

	///
	pure unittest
	{
		enum capacity = 64*3;
		static immutable bool[capacity] data = [0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0,
										   0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0, 0,1,1,0,1,0,1,0];
		auto b = StaticBitArray!capacity(data);
		b.reverse();
		foreach (const i; 0 .. data.length)
			assert(b[i] == data[capacity - 1 - i]);
	}

	/** Sorts the $(D StaticBitArray)'s elements. */
	@property typeof(this) sort()()
	in(result == this)
	out(result) {
		if (capacity >= 2) {
			size_t lo, hi;
			lo = 0;
			hi = capacity - 1;
			while (1) {
				while (1) {
					if (lo >= hi)
						goto Ldone;
					if (this[lo] == true)
						break;
					lo++;
				}
				while (1) {
					if (lo >= hi)
						goto Ldone;
					if (this[hi] == false)
						break;
					hi--;
				}
				this[lo] = false;
				this[hi] = true;
				lo++;
				hi--;
			}
		}
	Ldone:
		return this;
	}

	/* unittest */
	/*	 { */
	/*		 __gshared size_t x = 0b1100011000; */
	/*		 __gshared StaticBitArray ba = { 10, &x }; */
	/*		 ba.sort(); */
	/*		 for (size_t i = 0; i < 6; ++i) */
	/*			 assert(ba[i] == false); */
	/*		 for (size_t i = 6; i < 10; ++i) */
	/*			 assert(ba[i] == true); */
	/*	 } */


	/** Support for operators == and != for $(D StaticBitArray). */
	bool opEquals(Block2)(in StaticBitArray!(capacity, Block2) a2) const @trusted
	if (isUnsigned!Block2) {
		size_t i;

		if (this.length != a2.length) { return 0; } // not equal
		auto p1 = this.ptr;
		auto p2 = a2.ptr;
		auto n = this.length / bitsPerBlock;
		for (i = 0; i < n; ++i)
			if (p1[i] != p2[i])
				return 0; // not equal

		n = this.length & (bitsPerBlock-1);
		size_t mask = (1 << n) - 1;
		//printf("i = %d, n = %d, mask = %x, %x, %x\n", i, n, mask, p1[i], p2[i]);
		return (mask == 0) || (p1[i] & mask) == (p2[i] & mask);
	}
	///
	nothrow unittest
	{
		auto a = StaticBitArray!(5, ubyte)([1,0,1,0,1]);
		auto b = StaticBitArray!(5, ushort)([1,0,1,1,1]);
		auto c = StaticBitArray!(5, uint)([1,0,1,0,1]);
		auto d = StaticBitArray!(5, ulong)([1,1,1,1,1]);
		assert(a != b);
		assert(a == c);
		assert(a != d);
	}

	/** Supports comparison operators for $(D StaticBitArray). */
	int opCmp(Block2)(in StaticBitArray!(capacity, Block2) a2) const @trusted
	if (isUnsigned!Block2) {
		uint i;

		auto capacity = this.length;
		if (a2.length < capacity) { capacity = a2.length; }
		auto p1 = this.ptr;
		auto p2 = a2.ptr;
		auto n = capacity / bitsPerBlock;
		for (i = 0; i < n; ++i)
			if (p1[i] != p2[i]) { break; } // not equal
		for (size_t j = 0; j < capacity-i * bitsPerBlock; j++) {
			size_t mask = cast(size_t)(1 << j);
			auto c = (cast(long)(p1[i] & mask) - cast(long)(p2[i] & mask));
			if (c) { return c > 0 ? 1 : -1; }
		}
		return cast(int)this.length - cast(int)a2.length;
	}

	///
	nothrow unittest
	{
		auto a = StaticBitArray!(5, ubyte)([1,0,1,0,1]);
		auto b = StaticBitArray!(5, ushort)([1,0,1,1,1]);
		auto c = StaticBitArray!(5, uint)([1,0,1,0,1]);
		auto d = StaticBitArray!(5, ulong)([1,1,1,1,1]);
		assert(a <  b);
		assert(a <= b);
		assert(a == c);
		assert(a <= c);
		assert(a >= c);
		assert(c < d);
	}

	/** Support for hashing for $(D StaticBitArray). */
	extern(D) hash_t toHash() const @trusted pure nothrow
	{
		typeof(return) hash = 3557;
		auto n  = capacity / 8;
		foreach (const i; 0 .. n) {
			hash *= 3559;
			hash += (cast(byte*)this.ptr)[i];
		}
		for (size_t i = 8*n; i < capacity; ++i) {
			hash *= 3571;
			hash += this[i];
		}
		return hash;
	}

	/** Set `this` to the contents of $(D ba). */
	this()(bool[] ba) in(length == ba.length) {
		foreach (immutable i, const b; ba)
			this[i] = b;
	}

	/** Set `this` to the contents of $(D ba). */
	this()(const ref bool[capacity] ba) {
		foreach (immutable i, const b; ba)
			this[i] = b;
	}

	bool opCast(T : bool)() const => !this.allZero;

	/// construct from dynamic array
	@safe nothrow @nogc unittest
	{
		static bool[] ba = [1,0,1,0,1];
		auto a = StaticBitArray!5(ba);
		assert(a);
		assert(!a.allZero);
	}
	/// ditto
	@safe nothrow @nogc unittest
	{
		static bool[] ba = [0,0,0];
		auto a = StaticBitArray!3(ba);
		assert(!a);
		assert(a.allZero);
	}
	/// construct from static array
	@safe nothrow @nogc unittest
	{
		static bool[3] ba = [0,0,0];
		auto a = StaticBitArray!3(ba);
		assert(!a);
		assert(a.allZero);
	}

	static if (capacity >= 1) {
		/** Lazy range of the indices of set bits.

			Similar to: `std.bitmanip.bitsSet`

			See_Also: https://dlang.org/phobos/std_bitmanip.html#bitsSet
		 */
		struct OneIndexes(Store) {
			/+ TODO: if (is(Store == StaticBitArray!(_), _)) +/
			pure nothrow @safe @nogc:

			this(Store* store) {
				this._store = store;

				// pre-adjust front index. TODO: make lazy and move to front
				while (_i < length && !(*_store)[_i])
					++_i;

				// pre-adjust back index. TODO: make lazy and move to front
				while (_j > 1 && !(*_store)[_j])
					--_j;
			}

			import std.traits : isMutable;
			static if (isMutable!(typeof(_store)))
				this(this) @disable; // Rust-style mutable reference semantics

			pragma(inline, true):

			bool empty() const @property => _i > _j;
			Mod!capacity front() const @property in(!empty) => typeof(return)(_i); /+ TODO: use enforce when it's @nogc +/
			Mod!capacity back() const @property in(!empty) => typeof(return)(_j); /+ TODO: use enforce when it's @nogc +/
			void popFront() in(!empty) {
				version (DigitalMars) pragma(inline);
				while (++_i <= _j)
					if ((*_store)[_i])
						break;
			}
			void popBack() in(!empty) {
				while (_i <= --_j)
					if ((*_store)[_j])
						break;
			}

		private:
			Store* _store;				 // copy of store
			int _i = 0;					// front index into `_store`
			int _j = (*_store).length - 1; // back index into `_store`
		}

		/** Returns: a lazy range of the indices of set bits.
		 */
		auto oneIndexes()() const => OneIndexes!(typeof(this))(&this);
		/// ditto
		alias bitsSet = oneIndexes;

		/** Find index of first cleared (zero) bit or `typeof(return).max` if no bit set.
		 *
		 * Optimized for zeros-sparsity.
		 */
		size_t indexOfFirstZero()() const
		{
			import nxt.bitarray_algorithm;
			enum bool blockAlignedLength = capacity % (8*Block.sizeof) == 0;
			return indexOfFirstZero!(const(Block)[blockCount],
									 blockAlignedLength)(_blocks, length);
		}

		/** Find index of first set (one) bit or `typeof(return).max` if no bit set.
		 *
		 * Optimized for ones-sparsity.
		 */
		size_t indexOfFirstOne()() const
		{
			import nxt.bitarray_algorithm : indexOfFirstOne;
			enum bool blockAlignedLength = capacity % (8*Block.sizeof) == 0;
			return indexOfFirstOne!(const(Block)[blockCount],
									blockAlignedLength)(_blocks, length);
		}

		/** Get number of bits set. */
		Mod!(capacity + 1) countOnes()() const	/* tlm. TODO: unite with other definitions */
		{
			import nxt.bitarray_algorithm;
			enum bool blockAlignedLength = capacity % (8*Block.sizeof) == 0;
			return typeof(return)(nxt.bitarray_algorithm.countOnes!(const(Block)[blockCount],
																blockAlignedLength)(_blocks, length));
		}

		/** Get number of (zero) bits unset. */
		size_t countZeros()() const  /*tlm*/
		{
			return length - countOnes;
		}

		/** Get number of bits set divided by length. */
		version (none)
		auto denseness()(int depth = -1) const /*tlm*/
		{
			import nxt.rational : Rational;
			alias Q = Rational!ulong;
			return Q(countOnes, length);
		}

		/** Get number of bits unset divided by length. */
		version (none)
		auto sparseness()(int depth = -1) const /*tlm*/
		{
			import nxt.rational : Rational;
			alias Q = Rational!ulong;
			return 1 - denseness(depth);
		}

		/** Check if `this` has only zeros (is empty). */
		bool allZero()() const pure nothrow @safe @nogc
		{
			foreach (const block; _fullBlocks)
				if (block != Block.min)
					return false;
			static if (blockCount)
				if (_restBlock != Block.min)
					return false;
			return true;
		}

		/** Check if `this` has only ones. */
		bool allOne()() const
		{
			const restBitCount = capacity % bitsPerBlock;
			const hasRest = restBitCount != 0;
			if (_blocks.length >= 1)
				foreach (const block; _blocks[0 .. $ - hasRest])
					if (block != Block.max) { return false; }
			if (restBitCount)
				return _blocks[$ - 1] == 2^^restBitCount - 1;
			else
				return true;
		}

		/** Find index (starting at `currIx`) of first bit that equals `value`.
		 *
		 * Returns: `true` if index was found (hit index is put into `nextIx`), `false` otherwise.
		 *
		 * TODO: block-optimize for large BitSets
		 */
		bool canFindIndexOf(ModUInt)(bool value,
									 Mod!(capacity, ModUInt) currIx,
									 out Mod!(capacity, ModUInt) nextIx) const
		if (isUnsigned!ModUInt) {
			if (currIx >= length) { return false; }
			bool hit = false;
			foreach (immutable ix_; cast(uint)currIx .. cast(uint)length) {
				const bool bit = this[ix_];
				if (bit == value) {
					nextIx = typeof(nextIx)(ix_);
					hit = true;
					break;
				}
			}
			return hit;
		}

		bool canFindIndexOf(UInt)(bool value,
								  UInt currIx,
								  out UInt nextIx) const
		if (isUnsigned!UInt) {
			if (currIx >= length) { return false; }
			bool hit = false;
			foreach (immutable ix_; cast(uint)currIx .. cast(uint)length) {
				const bool bit = this[ix_];
				if (bit == value) {
					nextIx = typeof(nextIx)(ix_);
					hit = true;
					break;
				}
			}
			return hit;
		}

	}

	/**
	 * Map the $(D StaticBitArray) onto $(D v), with $(D numbits) being the number of bits
	 * in the array. Does not copy the data.
	 *
	 * This is the inverse of $(D opCast).
	 */
	/* void init(void[] v, size_t numbits) in { */
	/*	 assert(numbits <= v.length * 8); */
	/*	 assert((v.length & 3) == 0); // must be whole bytes */
	/* } do { */
	/*	 _blocks[] = cast(in size_t*)v.ptr[0..v.length]; */
	/* } */

	/** Convert to $(D void[]). */
	void[] opCast(T : void[])() @trusted => cast(void[])ptr[0 .. dim];

	/** Convert to $(D size_t[]). */
	size_t[] opCast(T : size_t[])() => ptr[0 .. dim];
	///
	nothrow unittest
	{
		static bool[] ba = [1,0,1,0,1];
		auto a = StaticBitArray!5(ba);
		void[] v = cast(void[])a;
		assert(v.length == a.dim * size_t.sizeof);
	}

	/** Complement operator. */
	typeof(this) opCom() const @trusted
	{
		StaticBitArray result;
		foreach (const i; 0 .. dim)
			result.ptr[i] = cast(Block)~cast(ulong)this.ptr[i];
		immutable rem = capacity & (bitsPerBlock-1); // number of rest bits in last block
		if (rem < bitsPerBlock) // rest bits in last block
			// make remaining bits zero in last block
			result.ptr[dim - 1] &= ~(~(cast(Block)0) << rem);
		return result;
	}

	/** Support for binary operator & for $(D StaticBitArray). */
	typeof(this) opBinary(string op)(in typeof(this) e2) const
		if (op == "&") {
		StaticBitArray result;
		result._blocks[] = this._blocks[] & e2._blocks[];
		return result;
	}
	///
	nothrow unittest
	{
		const a = StaticBitArray!5([1,0,1,0,1]);
		auto b = StaticBitArray!5([1,0,1,1,0]);
		const c = a & b;
		auto d = StaticBitArray!5([1,0,1,0,0]);
		assert(c == d);
	}

	/** Support for binary operator | for $(D StaticBitArray). */
	typeof(this) opBinary(string op)(in typeof(this) e2) const if (op == "|") {
		StaticBitArray result;
		result._blocks[] = this._blocks[] | e2._blocks[];
		return result;
	}
	///
	nothrow unittest
	{
		const a = StaticBitArray!5([1,0,1,0,1]);
		auto b = StaticBitArray!5([1,0,1,1,0]);
		const c = a | b;
		auto d = StaticBitArray!5([1,0,1,1,1]);
		assert(c == d);
	}

	/** Support for binary operator ^ for $(D StaticBitArray). */
	typeof(this) opBinary(string op)(in typeof(this) e2) const if (op == "^") {
		StaticBitArray result;
		result._blocks[] = this._blocks[] ^ e2._blocks[];
		return result;
	}
	///
	nothrow unittest
	{
		const a = StaticBitArray!5([1,0,1,0,1]);
		auto b = StaticBitArray!5([1,0,1,1,0]);
		const c = a ^ b;
		auto d = StaticBitArray!5([0,0,0,1,1]);
		assert(c == d);
	}

	/** Support for binary operator - for $(D StaticBitArray).
	 *
	 * $(D a - b) for $(D StaticBitArray) means the same thing as $(D a &amp; ~b).
	 */
	typeof(this) opBinary(string op)(in typeof(this) e2) const if (op == "-") {
		StaticBitArray result;
		result._blocks[] = this._blocks[] & ~e2._blocks[];
		return result;
	}
	///
	nothrow unittest
	{
		const a = StaticBitArray!5([1,0,1,0,1]);
		auto b = StaticBitArray!5([1,0,1,1,0]);
		const c = a - b;
		auto d = StaticBitArray!5([0,0,0,0,1]);
		assert(c == d);
	}

	/** Support for operator &= for $(D StaticBitArray).
	 */
	typeof(this) opOpAssign(string op)(in typeof(this) e2) if (op == "&") {
		_blocks[] &= e2._blocks[];
		return this;
	}
	///
	nothrow unittest
	{
		auto a = StaticBitArray!5([1,0,1,0,1]);
		const b = StaticBitArray!5([1,0,1,1,0]);
		a &= b;
		const c = StaticBitArray!5([1,0,1,0,0]);
		assert(a == c);
	}

	/** Support for operator |= for $(D StaticBitArray).
	 */
	typeof(this) opOpAssign(string op)(in typeof(this) e2) if (op == "|") {
		_blocks[] |= e2._blocks[];
		return this;
	}
	///
	nothrow unittest
	{
		auto a = StaticBitArray!5([1,0,1,0,1]);
		const b = StaticBitArray!5([1,0,1,1,0]);
		a |= b;
		const c = StaticBitArray!5([1,0,1,1,1]);
		assert(a == c);
	}

	/** Support for operator ^= for $(D StaticBitArray).
	 */
	typeof(this) opOpAssign(string op)(in typeof(this) e2) if (op == "^") {
		_blocks[] ^= e2._blocks[];
		return this;
	}
	///
	nothrow unittest
	{
		auto a = StaticBitArray!5([1,0,1,0,1]);
		const b = StaticBitArray!5([1,0,1,1,0]);
		a ^= b;
		const c = StaticBitArray!5([0,0,0,1,1]);
		assert(a == c);
	}

	/** Support for operator -= for $(D StaticBitArray).
	 *
	 * $(D a -= b) for $(D StaticBitArray) means the same thing as $(D a &amp;= ~b).
	 */
	typeof(this) opOpAssign(string op)(in typeof(this) e2) if (op == "-") {
		_blocks[] &= ~e2._blocks[];
		return this;
	}
	///
	nothrow unittest
	{
		auto a = StaticBitArray!5([1,0,1,0,1]);
		const b = StaticBitArray!5([1,0,1,1,0]);
		a -= b;
		const c = StaticBitArray!5([0,0,0,0,1]);
		assert(a == c);
	}

	/** Return a string representation of this StaticBitArray.
	 *
	 * Two format specifiers are supported:
	 * $(LI $(B %s) which prints the bits as an array, and)
	 * $(LI $(B %b) which prints the bits as 8-bit byte packets)
	 * separated with an underscore.
	 */
	void toString(Sink)(ref scope Sink sink, FormatSpec!char fmt) const @trusted
	{
		switch(fmt.spec) {
		case 'b':
			return formatBitString(sink);
		case 's':
			return formatBitSet(sink);
		default:
			throw new Exception("Unknown format specifier: %" ~ fmt.spec);
		}
	}
	///
	unittest
	{
		const b = StaticBitArray!16(([0, 0, 0, 0, 1, 1, 1, 1,
									  0, 0, 0, 0, 1, 1, 1, 1]));
		const s1 = format("%s", b);
		version (none) assert(s1 == "[0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]"); /+ TODO: enable +/

		version (none) const s2 = format("%b", b); /+ TODO: enable +/
		version (none) assert(s2 == "00001111_00001111"); /+ TODO: enable +/
	}

	private void formatBitString(Sink)(ref scope Sink sink) const @trusted
	{
		import std.range.primitives : put;

		static if (length) {
			const leftover = capacity % 8;
			foreach (immutable ix; 0 .. leftover) {
				const bit = this[ix];
				const char[1] res = cast(char)(bit + '0');
				sink.put(res[]);
			}

			if (leftover &&
				capacity > 8)
				sink.put("_");	// separator

			size_t cnt;
			foreach (immutable ix; leftover .. capacity) {
				const bit = this[ix];
				const char[1] res = cast(char)(bit + '0');
				sink.put(res[]);
				if (++cnt == 8 && ix != capacity - 1) {
					sink.put("_");  // separator
					cnt = 0;
				}
			}
		}
	}

	private void formatBitSet(Sink)(ref scope Sink sink) const @trusted
	{
		sink("[");
		foreach (immutable ix; 0 .. capacity) {
			const bit = this[ix];
			const char[1] res = cast(char)(bit + '0');
			sink(res[]);
			if (ix+1 < capacity) { sink(", "); } // separator
		}
		sink("]");
	}

private:
	pragma(inline, true)
	inout(Block)[] _fullBlocks() inout @trusted => _blocks.ptr[0 .. (length / bitsPerBlock)];

	static if (blockCount) {
		Block _restBlock() const @trusted
		{
			const restBitCount = length % bitsPerBlock;
			return _blocks[blockCount-1] & ((1UL << restBitCount) - 1);
		}
	}
}

/// run-time
pure nothrow @safe @nogc unittest {
	import nxt.algorithm.comparison : equal;

	enum m = 256;

	StaticBitArray!m b0;

	import nxt.modulo : Mod;
	static assert(is(typeof(b0.oneIndexes.front()) == Mod!m));

	b0[1] = 1;
	b0[2] = 1;

	b0[m/2 - 11] = 1;
	b0[m/2 - 1] = 1;
	b0[m/2] = 1;
	b0[m/2 + 1] = 1;
	b0[m/2 + 11] = 1;

	b0[m - 3] = 1;
	b0[m - 2] = 1;

	assert(b0.oneIndexes.equal([1, 2,
								m/2 - 11, m/2 - 1, m/2, m/2 + 1, m/2 + 11,
								m - 3,
								m - 2].s[]));
	assert(b0.countOnes == 9);
}

/// run-time
pure nothrow @safe @nogc unittest {
	import nxt.algorithm.comparison : equal;

	enum m = 256;

	StaticBitArray!m b0;

	import nxt.modulo : Mod;
	static assert(is(typeof(b0.oneIndexes.front()) == Mod!m));

	b0[0] = 1;
	b0[1] = 1;
	b0[m/2 - 11] = 1;
	b0[m/2 - 1] = 1;
	b0[m/2] = 1;
	b0[m/2 + 1] = 1;
	b0[m/2 + 11] = 1;
	b0[m - 2] = 1;
	b0[m - 1] = 1;

	assert(b0.oneIndexes.equal([0, 1,
								m/2 - 11, m/2 - 1, m/2, m/2 + 1, m/2 + 11,
								m - 2,
								m - 1].s[]));
	assert(b0.countOnes == 9);
}

/// ditto
pure nothrow @safe @nogc unittest {
	import std.traits : isIterable;
	static assert(isIterable!(StaticBitArray!256));
}

/// test ubyte access
pure nothrow @safe @nogc unittest {
	auto b8 = StaticBitArray!(8, ubyte)();
	b8[0] = 1;
	b8[1] = 1;
	b8[3] = 1;
	b8[6] = 1;

	assert(b8.ubytes == [64 + 8 + 2 + 1].s[]);

	alias Ix = b8.Index;
	Ix nextIx;

	assert(b8.canFindIndexOf(true, Ix(0), nextIx));
	assert(nextIx == 0);

	assert(b8.canFindIndexOf(true, Ix(1), nextIx));
	assert(nextIx == 1);

	assert(b8.canFindIndexOf(true, Ix(2), nextIx));
	assert(nextIx == 3);

	assert(b8.canFindIndexOf(true, Ix(3), nextIx));
	assert(nextIx == 3);

	assert(b8.canFindIndexOf(true, Ix(4), nextIx));
	assert(nextIx == 6);

	assert(!b8.canFindIndexOf(true, Ix(7), nextIx));
}

/// test all zero and all one predicates
pure nothrow @safe @nogc unittest {
	static void test(size_t restBitCount)() {
		enum n = 8*size_t.sizeof + restBitCount;

		auto bs = StaticBitArray!(n, size_t)();

		assert(bs.allZero);
		assert(!bs.allOne);

		foreach (immutable i; 0 .. n - 1) {
			bs[i] = true;
			assert(!bs.allZero);
			assert(!bs.allOne);
		}
		bs[n - 1] = true;

		assert(bs.allOne);
	}
	test!0;
	test!1;
	test!2;
	test!37;
	test!62;
	test!63;
}

/// ditto
version (none) /+ TODO: enable +/
@safe unittest {
	import std.format : format;

	const b0_ = StaticBitArray!0([]);
	const b0 = b0_;
	assert(format("%s", b0) == "[]");
	assert(format("%b", b0) is null);

	const b1_ = StaticBitArray!1([1]);
	const b1 = b1_;
	assert(format("%s", b1) == "[1]");
	assert(format("%b", b1) == "1");

	const b4 = StaticBitArray!4([0, 0, 0, 0]);
	assert(format("%b", b4) == "0000");

	const b8 = StaticBitArray!8([0, 0, 0, 0, 1, 1, 1, 1]);
	assert(format("%s", b8) == "[0, 0, 0, 0, 1, 1, 1, 1]");
	assert(format("%b", b8) == "00001111");

	const b16 = StaticBitArray!16([0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);
	assert(format("%s", b16) == "[0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]");
	assert(format("%b", b16) == "00001111_00001111");

	const b9 = StaticBitArray!9([1, 0, 0, 0, 0, 1, 1, 1, 1]);
	assert(format("%b", b9) == "1_00001111");

	const b17 = StaticBitArray!17([1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1]);
	assert(format("%b", b17) == "1_00001111_00001111");
}

/// test range
pure nothrow @safe unittest {
	static testRange(Block)() {
		StaticBitArray!(6, Block) bs = [false, 1, 0, 0, true, 0];
		bs.put(3, true);

		import nxt.algorithm.comparison : equal;

		assert(bs[0] == false);
		assert(bs[1] == true);
		assert(bs[2] == false);
		assert(bs[3] == true);
		assert(bs[4] == true);
		assert(bs[5] == false);

		assert(bs.at!0 == false);
		assert(bs.at!1 == true);
		assert(bs.at!2 == false);
		assert(bs.at!3 == true);
		assert(bs.at!4 == true);
		assert(bs.at!5 == false);

		// test slicing
		assert(bs[].equal([0, 1, 0, 1, 1, 0].s[]));
		assert(bs[1 .. 4].equal([1, 0, 1].s[]));

		auto rs = bs[1 .. 6 - 1]; /+ TODO: Use opDollar +/
		assert(rs.length == 4);
		assert(rs.front == true);
		assert(rs.back == true);

		rs.popFront();
		assert(rs.front == false);
		assert(rs.back == true);

		rs.popBack();
		assert(rs.front == false);
		assert(rs.back == true);

		rs.popFront();
		assert(rs.front == true);
		assert(rs.back == true);

		rs.popBack();
		assert(rs.length == 0);
		assert(rs.empty);
	}

	import std.meta : AliasSeq;
	foreach (Block; AliasSeq!(ubyte, ushort, uint, ulong, size_t))
		testRange!Block;
}

///
pure nothrow @safe @nogc unittest {
	alias Block = size_t;
	enum blockCount = 2;
	enum n = blockCount * 8*Block.sizeof - 1;
	StaticBitArray!(n) x;
	static assert(x.blockCount == blockCount);

	assert(x.indexOfFirstOne == n);
	x[n - 1] = true;
	assert(x.indexOfFirstOne == x.length - 1);
	x[n - 2] = true;
	assert(x.indexOfFirstOne == x.length - 2);

	x[n/2 + 1] = true;
	assert(x.indexOfFirstOne == x.length/2 + 1);
	x[n/2] = true;
	assert(x.indexOfFirstOne == x.length/2);
	x[n/2 - 1] = true;
	assert(x.indexOfFirstOne == x.length/2 - 1);

	x[0] = true;
	assert(x.indexOfFirstOne == 0);
	assert(x[0]);
	assert(!x[1]);

	x[1] = true;
	assert(x[1]);

	x[1] = false;
	assert(!x[1]);
}

/// Test opSliceAssign.
pure nothrow @safe @nogc unittest {
	alias Block = size_t;
	enum blockCount = 2;
	enum n = blockCount * 8*Block.sizeof - 1;

	StaticBitArray!(n) x;
	assert(x.countOnes == 0);

	x[] = true;
	assert(x.countOnes == n);

	x[] = false;
	assert(x.countOnes == 0);
}

version (unittest) {
	import nxt.array_help : s;
}
