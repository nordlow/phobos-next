/* Copyright (C) 2017 Olivier Pisano
 * Compute CRC-32C using the Intel crc32 instruction
 *
 * This work is derived from original software in C by Mark Adler.
 * Original C version Copyright (C) 2013 Mark Adler
 *
 * See_Also: https://forum.dlang.org/post/nyngvfryjrnuprjmhred@forum.dlang.org
 */

/*
  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the author be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
	 claim that you wrote the original software. If you use this software
	 in a product, an acknowledgment in the product documentation would be
	 appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
	 misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Mark Adler
  madler@alumni.caltech.edu
 */

module crc32c;

import core.stdc.stdint;

/// CRC-32C (iSCSI) polynomial in reversed bit order.
enum POLY = 0x82f63b78;
enum LONG = 8192;
enum SHORT = 256;

// Generate the lookup tables at compile-time using CTFE
immutable uint[256][8] crc32c_table = create_crc32c_table();
immutable uint[256][4] crc32c_long  = create_crc32c_zeros(LONG);
immutable uint[256][4] crc32c_short = create_crc32c_zeros(SHORT);

// Create an immutable pointer to a CRC32C function
alias CrcFunc = uint function(uint, const(ubyte)[]) pure nothrow @nogc;
immutable CrcFunc crc32c;

/**
 * At startup, initialize the CRC32C pointer to the correct function
 * according to the actual hardware capabilities.
 */
shared static this()
{
	if (hasSSE42())
		crc32c = &crc32c_hw;
	else
		crc32c = &crc32c_sw;
}

/**
 * Table-driven software version as a fall-back.
 * This is about 5 times slower than using the hardware instructions.
 * This assumes little-endian integers, as is the case on Intel
 * processors that the assembler code here is for.
 */
uint crc32c_sw(uint crci, const(ubyte)[] buf) pure nothrow @nogc
{
	ulong crc;

	crc = crci ^ 0xffffffff;
	// handle one byte at a time until we are aligned on 8 bytes
	while (buf.length && (cast(uintptr_t)buf.ptr & 7) != 0)
	{
		crc = crc32c_table[0][(crc ^ buf[0]) & 0xff] ^ (crc >> 8);
		buf = buf[1 .. $];
	}

	// handle 8 bytes at a time
	while (buf.length >= 8)
	{
		crc ^= *(cast(ulong*)buf.ptr);
		crc = crc32c_table[7][crc & 0xff] ^
			  crc32c_table[6][(crc >> 8) & 0xff] ^
			  crc32c_table[5][(crc >> 16) & 0xff] ^
			  crc32c_table[4][(crc >> 24) & 0xff] ^
			  crc32c_table[3][(crc >> 32) & 0xff] ^
			  crc32c_table[2][(crc >> 40) & 0xff] ^
			  crc32c_table[1][(crc >> 48) & 0xff] ^
			  crc32c_table[0][crc >> 56];
		buf = buf[8 .. $];
	}

	// handle the remaining bytes
	while (buf.length)
	{
		crc = crc32c_table[0][(crc ^ buf[0]) & 0xff] ^ (crc >> 8);
		buf = buf[1 .. $];
	}
	return cast(uint)crc ^ 0xffffffff;
}

/**
 * SSE 4.2 hardware optimized version.
 */
uint crc32c_hw(uint crci, const(ubyte)[] buf) pure nothrow @nogc
{
	// Compute byte by byte until we have 8 byte alignment
	ulong crc0 = crci ^ 0xFFFFFFFF;
	while (buf.length && (cast(uintptr_t)buf.ptr & 7) != 0)
	{
		ubyte b = buf.ptr[0];
		asm pure nothrow @nogc
		{
			mov RAX, crc0;
			crc32 RAX, byte ptr b;
			mov crc0, RAX;
		}
		buf = buf[1 .. $];
	}

	/*
	 * Compute the crc on sets of LONG*3 bytes, executing three
	 * independent crc instructions, each on LONG bytes -- this is
	 * optimized for the Nehalem, Westmere, Sandy Bridge, and Ivy Bridge
	 * architectures, which have a throughput of one crc per cycle, but
	 * a latency of three cycles.
	 */
	while (buf.length >= LONG*3)
	{
		ulong crc1, crc2;
		auto temp = buf[0 .. LONG];
		do
		{
			auto p = temp.ptr;
			ulong q0 = *(cast(ulong*)p);
			ulong q1 = *(cast(ulong*)(p+LONG));
			ulong q2 = *(cast(ulong*)(p+LONG*2));
			asm pure nothrow @nogc
			{
				mov RAX, crc0;
				mov R10, crc1;
				mov R11, crc2;
				crc32 RAX, qword ptr q0;
				crc32 R10, qword ptr q1;
				crc32 R11, qword ptr q2;
				mov crc2, R11;
				mov crc1, R10;
				mov crc0, RAX;
			}
			temp = temp[8 .. $];
		} while (temp.length);
		crc0 = crc32c_shift(crc32c_long, crc0) ^ crc1;
		crc0 = crc32c_shift(crc32c_long, crc0) ^ crc2;
		buf = buf[LONG*3 .. $];
	}

	/*
	 * do the same thing, but now on SHORT*3 blocks for the remaining data less
	 * than a LONG*3 block
	 */
	while (buf.length >= SHORT*3)
	{
		ulong crc1, crc2;
		auto temp = buf[0 .. SHORT];
		do
		{
			auto p = temp.ptr;
			ulong q0 = *(cast(ulong*)p);
			ulong q1 = *(cast(ulong*)(p+SHORT));
			ulong q2 = *(cast(ulong*)(p+SHORT*2));
			asm pure nothrow @nogc
			{
				mov RAX, crc0;
				mov R10, crc1;
				mov R11, crc2;
				crc32 RAX, qword ptr q0;
				crc32 R10, qword ptr q1;
				crc32 R11, qword ptr q2;
				mov crc2, R11;
				mov crc1, R10;
				mov crc0, RAX;
			}
			temp = temp[8 .. $];
		} while (temp.length);
		crc0 = crc32c_shift(crc32c_short, crc0) ^ crc1;
		crc0 = crc32c_shift(crc32c_short, crc0) ^ crc2;
		buf = buf[SHORT*3 .. $];
	}

	while (buf.length > 8)
	{
		auto p = buf.ptr;
		ulong q0 = *(cast(ulong*)p);
		asm pure nothrow @nogc
		{
			mov RAX, crc0;
			crc32 RAX, qword ptr q0;
			mov crc0, RAX;
		}
		buf = buf[8 .. $];
	}

	while (buf.length)
	{
		auto p = buf.ptr;
		ubyte b = *p;
		asm pure nothrow @nogc
		{
			mov RAX, crc0;
			crc32 RAX, byte ptr b;
			mov crc0, RAX;
		}
		buf = buf[1 .. $];
	}

	return cast(uint)crc0 ^ 0xFFFFFFFF;
}

private:

/**
 * Returns true if the system has SSE 4.2 instructions,
 * False otherwise.
 */
bool hasSSE42() pure nothrow @nogc
{
	version (X86_64)
	{
		version (DigitalMars)
		{
			uint flag;

			asm pure nothrow @nogc
			{
				naked;
				mov EAX, 1;
				cpuid;
				mov EAX, ECX;
				shr EAX, 20;
				and EAX, 1;
				ret;
			}
		}
		else return false;
	}
	else
		return false;
}

/**
 * CTFE function that generates the crc32c_table global constant.
 */
uint[256][8] create_crc32c_table() pure nothrow @nogc
{
	uint[256][8] result;
	uint crc;

	foreach (n; 0 .. 256)
	{
		crc = n;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		crc = crc & 1 ? (crc >> 1) ^ POLY : crc >> 1;
		result[0][n] = crc;
	}

	foreach (n; 0 .. 256)
	{
		crc = result[0][n];
		foreach (k; 1 .. 8)
		{
			crc = result[0][crc & 0xff] ^ (crc >> 8);
			result[k][n] = crc;
		}
	}

	return result;
}


/**
 * Take a length and build four lookup tables for applying the zeros
 * operator for that length, byte-by-byte on the operand.
 */
uint[256][4] create_crc32c_zeros(size_t len) pure nothrow @nogc
{
	uint[256][4] zeros;
	uint[32] op = crc32c_zeros_op(len);
	foreach (n; 0 .. 256)
	{
		zeros[0][n] = gf2_matrix_times(op, n);
		zeros[1][n] = gf2_matrix_times(op, n << 8);
		zeros[2][n] = gf2_matrix_times(op, n << 16);
		zeros[3][n] = gf2_matrix_times(op, n << 24);
	}
	return zeros;
}

/**
 * Construct an operator to apply len zeros to a crc. len must be a power of
 * two. If len is not a power of two, then the result is the same as for the
 * largest power of two less than len.  The result for len == 0 is the same as
 * for len == 1.  A version of this routine could be easily written for any
 * len, but that is not needed for this application.
 */
uint[32] crc32c_zeros_op(size_t len) pure nothrow @nogc
{
	uint row;
	uint[32] even, odd;

	odd[0] = POLY;
	row = 1;
	foreach (n; 1 .. 32)
	{
		odd[n] = row;
		row <<= 1;
	}

	// put operator for two zero bits in even
	gf2_matrix_square(even, odd);
	// put operator for four zero bits in odd
	gf2_matrix_square(odd, even);

	/* first square will put the operator for one zero byte (eight
	   zero bytes) in even -- next square puts operator or two zero bytes
	   in odd, and so on, until len has been rotated down to zero */
	do
	{
		gf2_matrix_square(even, odd);
		len >>= 1;
		if (len == 0)
			return even;
		gf2_matrix_square(odd, even);
		len >>= 1;
	}
	while (len);

	// answer ended up in odd, copy to even
	even[] = odd[];
	return even;
}

/**
 * Multiply a matrix times a vector over the Galois field of two elements,
 * GF(2).  Each element is a bit in an unsigned integer.  mat must have at
 * least as many entries as the power of two for most significant one bit in
 * vec.
 */
uint gf2_matrix_times(const(uint)[] mat, uint vec) pure nothrow @nogc
{
	uint sum;
	while (vec)
	{
		if (vec & 1)
			sum ^= mat[0];
		vec >>= 1;
		mat = mat[1 .. $];
	}
	return sum;
}

/**
 * Multiply a matrix by itself over GF(2).  Both mat and square must have 32
 * rows.
 */
void gf2_matrix_square(uint[] square, const(uint)[] mat) pure nothrow @nogc
	in(square.length == 32)
	in(mat.length == 32)
{
	foreach (n; 0 .. 32)
	{
		square[n] = gf2_matrix_times(mat, mat[n]);
	}
}

/**
 * Apply the zeros operator table to crc.
 */
uint crc32c_shift(ref immutable uint[256][4] zeros, ulong crc) pure nothrow @nogc
{
	return zeros[0][crc & 0xFF]
			^ zeros[1][(crc >> 8) & 0xFF]
			^ zeros[2][(crc >> 16) & 0xFF]
			^ zeros[3][(crc >> 24) & 0xFF];
}


