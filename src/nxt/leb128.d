/** LEB128 (Little Endian Base 128).

	See_Also: https://en.wikipedia.org/wiki/LEB128
	See_Also: http://forum.dlang.org/post/ykskvwqdsxlyjispappj@forum.dlang.org

	TODO: Move to Phobos at std/experimental/codings/leb128.d
*/
module nxt.leb128;

import std.range.primitives : isOutputRange;
import std.traits : isUnsigned, isSigned;
import core.internal.traits : Unqual;

/// Encode a LEB128-encoded value of signed integer type `SInt` to `os`.
void encodeLEB128(SInt, Output)(ref Output os, Unqual!SInt value)
	if (isOutputRange!(Output, ubyte) &&
		isSigned!SInt)
{
	bool more = false;
	do
	{
		ubyte byte_ = value & 0x7f;
		// assumes that this signed shift is an arithmetic right shift
		value >>= 7;
		more = !(((value == 0 ) && ((byte_ & 0x40) == 0)) ||
				  ((value == -1) && ((byte_ & 0x40) != 0)));
		if (more)
			byte_ |= 0x80; // mark this byte to show that more bytes will follow
		os.put(byte_);
	}
	while (more);
}

/// Decode a LEB128-encoded value of signed integer type `SInt`.
SInt decodeLEB128(SInt)(ubyte *p, uint *n = null)
{
	const ubyte *orig_p = p;
	SInt value = 0;
	uint shift = 0;
	ubyte byte_;
	do
	{
		byte_ = *p++;
		value |= ((byte_ & 0x7f) << shift);
		shift += 7;
	} while (byte_ >= 128);
	// sign extend negative numbers
	if (byte_ & 0x40)
		/+ TODO: Unsigned!SInt +/
		value |= (cast(ulong)-1) << shift; // value |= (-1ULL) << shift;
	if (n)
		*n = cast(uint)(p - orig_p);
	return value;
}

version (unittest)
{
	import std.algorithm.comparison : equal;

	import std.array : Appender;
	alias Raw = Appender!(ubyte[]);
	// import nxt.container.dynamic_array : DynamicArray;
	// alias Raw = DynamicArray!ubyte;
}

pure nothrow @safe unittest {
	alias SInt = long;
	foreach (immutable i; 0 .. 64)
	{
		Raw os;
		os.encodeLEB128!SInt(i);
		assert(os.data.equal([i]));
		// const value = os.data.decodeLEB128!SInt();
	}
	foreach (immutable i; 64 .. 128)
	{
		Raw os;
		os.encodeLEB128!SInt(i);
		assert(os.data.equal([128 + i, 0]));
	}
}

/// Encode a ULEB128 value to `os`.
void encodeULEB128(UInt, Output)(ref Output os, Unqual!UInt value)
	if (isOutputRange!(Output, ubyte) &&
		isUnsigned!UInt)
{
	do
	{
		ubyte byte_ = value & 0x7f;
		value >>= 7;
		if (value != 0)
			byte_ |= 0x80; // mark this byte to show that more bytes will follow
		os.put(char(byte_));
	}
	while (value != 0);
}

/// Decode a ULEB128 value.
ulong decodeULEB128(ubyte *p, uint *n = null)
{
	const ubyte *orig_p = p;
	ulong value = 0;
	uint shift = 0;
	do
	{
		value += ulong(*p & 0x7f) << shift;
		shift += 7;
	}
	while (*p++ >= 128);
	if (n)
		*n = cast(uint)(p - orig_p);
	return value;
}

pure nothrow @safe unittest {
	alias UInt = ulong;
	foreach (immutable i; 0 .. 128)
	{
		Raw os;
		os.encodeULEB128!UInt(i);
		assert(os.data.equal([i]));
	}
	foreach (immutable i; 128 .. 256)
	{
		Raw os;
		os.encodeULEB128!UInt(i);
		assert(os.data.equal([i, 1]));
	}
	foreach (immutable i; 256 .. 256 + 128)
	{
		Raw os;
		os.encodeULEB128!UInt(i);
		assert(os.data.equal([i - 128, 2]));
	}
	foreach (immutable i; 256 + 128 .. 512)
	{
		Raw os;
		os.encodeULEB128!UInt(i);
		assert(os.data.equal([i - 256, 3]));
	}
}

/** Encode a ULEB128 value to a buffer.
	Returns: length in bytes of the encoded value.
*/
uint encodeULEB128(ulong value, ubyte *p)
{
	ubyte *orig_p = p;
	do
	{
		ubyte byte_ = value & 0x7f;
		value >>= 7;
		if (value != 0)
			byte_ |= 0x80; // mark this byte to show that more bytes will follow
		*p++ = byte_;
	}
	while (value != 0);
	return cast(uint)(p - orig_p);
}
