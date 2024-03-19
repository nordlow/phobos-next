/** Algorithms for dynamic and static bitarrays based with integral blocks.
 *
 * Algorithms are qualified as `package` because they should only be used by
 * bit-array containers.
 */
module nxt.bitarray_algorithm;

pure nothrow @safe @nogc:

size_t countOnes(Blocks, bool blockAlignedLength = false)(const scope auto ref Blocks blocks, size_t length) @trusted
if (isBlocks!Blocks) {
	alias Block = typeof(Blocks.init[0]);
	enum bitsPerBlock = 8*Block.sizeof;

	typeof(return) result = 0;

	import core.bitop : popcnt;
	const fullBlockCount = length / bitsPerBlock;
	foreach (const block; blocks.ptr[0 .. fullBlockCount]) {
		result += cast(typeof(result))popcnt(block);
	}

	// dbg("bitsPerBlock:", bitsPerBlock,
	//	 " length:", length,
	//	 " fullBlockCount:", fullBlockCount);,

	static if (!blockAlignedLength) {
		const restBitCount = length % bitsPerBlock;
		if (restBitCount) {
			result += cast(typeof(result))popcnt(blocks.ptr[fullBlockCount] & ((1UL << restBitCount)-1));
		}

		// dbg(" restBitCount:", restBitCount);
	}

	return typeof(return)(result);
}

/// Test `countOnes` with full blocks.
pure nothrow @safe @nogc unittest {
	alias Block = size_t;
	enum bitsPerBlock = 8*Block.sizeof;

	enum blockCount = 3;
	Block[blockCount] x;
	const length = 8*x.sizeof;
	assert(countOnes(x, length) == 0);

	x[0] = 1;
	assert(countOnes(x, length) == 1);

	x[0] = 1+2;
	assert(countOnes(x, length) == 2);

	x[0] = 1+2;
	x[1] = 1+2;
	assert(countOnes(x, length) == 4);

	x[0] = 1+2;
	x[1] = 1+2;
	x[2] = 1+2;
	assert(countOnes(x, length) == 6);
}

/// Test `countOnes` with partial blocks.
pure nothrow @safe @nogc unittest {
	alias Block = size_t;
	static void test(uint blockCount)() {
		Block[blockCount] x;
		foreach (const length; 1 .. 8*x.sizeof) {
			assert(countOnes(x, length) == 0);

			x[0] |= 1UL << (length-1);
			assert(countOnes(x, length) == 1);
			x[0] = 0;
		}
	}
	test!1();
	test!2();
	test!3();
}

/** Find index of first cleared (zero) bit or `length` if no bit cleared.
 *
 * Optimized for zeros-sparsity.
 */
size_t indexOfFirstZero(Blocks, bool blockAlignedLength = false)(const scope auto ref Blocks blocks, size_t length)
if (isBlocks!Blocks) {
	static if (blockAlignedLength) {
		foreach (const blockIndex, block; blocks) {
			if (block != block.max) // optimize for zeros-sparsity
			{
				import core.bitop : bsf;
				const hitIndex = blockIndex*8*block.sizeof + bsf(~block); /+ TODO: is there a builtin for `bsf(~block)`? +/
				return hitIndex < length ? hitIndex : length; // if hit beyond end miss
			}
		}
	}
	else
	{
		/+ TODO: handle blocks with garbage in the rest block +/
		foreach (const blockIndex, block; blocks) {
			if (block != block.max) // optimize for zeros-sparsity
			{
				import core.bitop : bsf;
				const hitIndex = blockIndex*8*block.sizeof + bsf(~block); /+ TODO: is there a builtin for `bsf(~block)`? +/
				return hitIndex < length ? hitIndex : length; // if hit beyond end miss
			}
		}
	}
	return length;			  // miss
}

/** Find index of first set (one) bit or `length` if no bit cleared.
 *
 * Optimized for ones-sparsity.
 */
size_t indexOfFirstOne(Blocks, bool blockAlignedLength = false)(const scope auto ref Blocks blocks, size_t length)
if (isBlocks!Blocks) {
	static if (blockAlignedLength) {
		foreach (const blockIndex, const block; blocks) {
			if (block != block.min) // optimize for ones-sparsity
			{
				import core.bitop : bsf;
				const hitIndex = blockIndex*8*block.sizeof + bsf(block);
				return hitIndex < length ? hitIndex : length; // if hit beyond end miss
			}
		}
	}
	else
	{
		/+ TODO: handle blocks with garbage in the rest block +/
		foreach (const blockIndex, const block; blocks) {
			if (block != block.min) // optimize for ones-sparsity
			{
				import core.bitop : bsf;
				const hitIndex = blockIndex*8*block.sizeof + bsf(block);
				return hitIndex < length ? hitIndex : length; // if hit beyond end miss
			}
		}
	}
	return length;			  // miss
}

private enum isBlocks(Blocks) = (is(typeof(Blocks.init[0]) : uint) ||
								 is(typeof(Blocks.init[0]) : ulong));
