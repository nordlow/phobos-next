module nxt.masking;

/// Enumerates the possible units of a mask.
enum MaskKind {Byte, Nibble, Bit}

/**
 * Masks, at compile-time, a byte, a nibble or a bit in the argument.
 *
 * Params:
 *	  index = the position, 0-based, of the element to mask.
 *	  kind = the kind of the element to mask.
 *	  value = the value mask.
 *
 * Returns:
 *	  The input argument with the element masked.
 */
auto mask(size_t index, MaskKind kind = MaskKind.Byte, T)(const T value) nothrow @safe pure
if ((kind == MaskKind.Byte && index <= T.sizeof) ||
	(kind == MaskKind.Nibble && index <= T.sizeof * 2) ||
	(kind == MaskKind.Bit && index <= T.sizeof * 8))
{
	T _mask;
	static if (kind == MaskKind.Byte)
		_mask = T.min - 1 - (0xFF << index * 8);
	else static if (kind == MaskKind.Nibble)
		_mask = T.min - 1 - (0xF << index * 4);
	else static if (kind == MaskKind.Bit)
		_mask = T.min - 1 - (0x1 << index);
	return value & _mask;
}
///
nothrow @safe @nogc pure unittest {
	// MaskKind.Byte by default.
	static assert(mask!1(0x12345678) == 0x12340078);
	static assert(mask!(1,MaskKind.Nibble)(0x12345678) == 0x12345608);
}

/// Compile-time $(D mask()) partially specialized for nibble-masking.
auto maskNibble(size_t index, T)(const T value) nothrow @safe pure
	=> mask!(index, MaskKind.Nibble)(value);
// note: aliasing prevents template parameter type deduction,
// e.g alias maskNibble(size_t index, T) = mask!(index, MaskKind.Nibble, T);

///
nothrow @safe @nogc pure unittest {
	static assert(maskNibble!1(0x12345678) == 0x12345608);
}

/// Compile-time $(D mask()) partially specialized for bit-masking.
auto maskBit(size_t index, T)(const T value) nothrow @safe pure
	=> mask!(index, MaskKind.Bit)(value);

///
nothrow @safe @nogc pure unittest {
	static assert(maskBit!1(0b1111) == 0b1101);
}

/**
 * Masks, at run-time, a byte, a nibble or a bit in the argument.
 *
 * Params:
 *	  index = the position, 0-based, of the element to mask.
 *	  kind = the kind of the element to mask.
 *	  value = the value mask.
 *
 * Returns:
 *	  The input argument with the element masked.
 */
auto mask(MaskKind kind = MaskKind.Byte, T)(const T value, size_t index)
nothrow @safe pure
{
	static immutable byteMasker =
	[
		0xFFFFFFFFFFFFFF00,
		0xFFFFFFFFFFFF00FF,
		0xFFFFFFFFFF00FFFF,
		0xFFFFFFFF00FFFFFF,
		0xFFFFFF00FFFFFFFF,
		0xFFFF00FFFFFFFFFF,
		0xFF00FFFFFFFFFFFF,
		0x00FFFFFFFFFFFFFF
	];

	static immutable nibbleMasker =
	[
		0xFFFFFFFFFFFFFFF0,
		0xFFFFFFFFFFFFFF0F,
		0xFFFFFFFFFFFFF0FF,
		0xFFFFFFFFFFFF0FFF,
		0xFFFFFFFFFFF0FFFF,
		0xFFFFFFFFFF0FFFFF,
		0xFFFFFFFFF0FFFFFF,
		0xFFFFFFFF0FFFFFFF,
		0xFFFFFFF0FFFFFFFF,
		0xFFFFFF0FFFFFFFFF,
		0xFFFFF0FFFFFFFFFF,
		0xFFFF0FFFFFFFFFFF,
		0xFFF0FFFFFFFFFFFF,
		0xFF0FFFFFFFFFFFFF,
		0xF0FFFFFFFFFFFFFF,
		0x0FFFFFFFFFFFFFFF
	];
	static if (kind == MaskKind.Byte)
		return value & byteMasker[index];
	else static if (kind == MaskKind.Nibble)
		return value & nibbleMasker[index];
	else
		return value & (0xFFFFFFFFFFFFFFFF - (1UL << index));
}
///
nothrow @safe @nogc pure unittest {
	// MaskKind.Byte by default.
	assert(mask(0x12345678,1) == 0x12340078);
	assert(mask!(MaskKind.Nibble)(0x12345678,1) == 0x12345608);
}

/*
First version: less byte code but more latency do to memory access
This version: no memory access but similar latency due to more byte code.
auto mask(MaskKind kind = MaskKind.Byte, T)(const T value, size_t index) nothrow
{
	static immutable T _max = - 1;
	static if (kind == MaskKind.Byte)
		return value & (_max - (0xFF << index * 8));
	else static if (kind == MaskKind.Nibble)
		return value & (_max - (0xF << index * 4));
	else
		return value & (_max - (0x1 << index));
}
*/

/// Run-time $(D mask()) partially specialized for nibble-masking.
auto maskNibble(T)(const T value, size_t index)
	=> mask!(MaskKind.Nibble)(value, index);

///
nothrow @safe @nogc pure unittest {
	assert(maskNibble(0x12345678,1) == 0x12345608);
}

/// Run-time $(D mask()) partially specialized for bit-masking.
auto maskBit(T)(const T value, size_t index) nothrow @safe pure
	=> mask!(MaskKind.Bit)(value, index);

///
nothrow @safe pure @nogc unittest {
	assert(maskBit(0b1111,1) == 0b1101);
}

nothrow @safe pure @nogc unittest {
	enum v0 = 0x44332211;
	static assert(mask!0(v0) == 0x44332200);
	static assert(mask!1(v0) == 0x44330011);
	static assert(mask!2(v0) == 0x44002211);
	static assert(mask!3(v0) == 0x00332211);

	assert(mask(v0,0) == 0x44332200);
	assert(mask(v0,1) == 0x44330011);
	assert(mask(v0,2) == 0x44002211);
	assert(mask(v0,3) == 0x00332211);

	enum v1 = 0x87654321;
	static assert(mask!(0, MaskKind.Nibble)(v1) == 0x87654320);
	static assert(mask!(1, MaskKind.Nibble)(v1) == 0x87654301);
	static assert(mask!(2, MaskKind.Nibble)(v1) == 0x87654021);
	static assert(mask!(3, MaskKind.Nibble)(v1) == 0x87650321);
	static assert(mask!(7, MaskKind.Nibble)(v1) == 0x07654321);

	assert(mask!(MaskKind.Nibble)(v1,0) == 0x87654320);
	assert(mask!(MaskKind.Nibble)(v1,1) == 0x87654301);
	assert(mask!(MaskKind.Nibble)(v1,2) == 0x87654021);
	assert(mask!(MaskKind.Nibble)(v1,3) == 0x87650321);
	assert(mask!(MaskKind.Nibble)(v1,7) == 0x07654321);

	enum v2 = 0b11111111;
	static assert(mask!(0, MaskKind.Bit)(v2) == 0b11111110);
	static assert(mask!(1, MaskKind.Bit)(v2) == 0b11111101);
	static assert(mask!(7, MaskKind.Bit)(v2) == 0b01111111);

	assert(maskBit(v2,0) == 0b11111110);
	assert(maskBit(v2,1) == 0b11111101);
	assert(mask!(MaskKind.Bit)(v2,7) == 0b01111111);
}
