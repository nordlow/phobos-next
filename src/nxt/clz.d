/** Count leading zeros.
 */
module nxt.clz;

import std.traits : Unqual;

/*******************************************************************************
 *
 * Count leading zeroes.
 *
 * Params:
 *   u = the unsigned value to scan
 *
 * Returns:
 *   The number of leading zero bits before the first one bit. If `u` is `0`,
 *   the result is undefined.
 *
 **************************************/
version (DigitalMars) {
	pragma(inline, true)
	U clz(U)(U u) @safe @nogc pure nothrow
	if (is(Unqual!U == uint) ||
		is(Unqual!U == size_t))
		=> (cast(U)(8 * U.sizeof - 1)) - bsr(u);

	static if (isX86) {
		pragma(inline, true)
		uint clz(U)(U u) @safe @nogc pure nothrow
		if (is(Unqual!U == ulong)) {
			uint hi = u >> 32;
			return hi ? 31 - bsr(hi) : 63 - bsr(cast(uint)u);
		}
	}
}
else version (GNU) {
	import gcc.builtins;
	alias clz = __builtin_clz;
	static if (isX86) {
		@safe @nogc pure nothrow uint
		clz(ulong u) {
			uint hi = u >> 32;
			return hi ? __builtin_clz(hi) : 32 + __builtin_clz(cast(uint)u);
		}
	}
	else alias clz = __builtin_clzl;
}
else version (LDC) {
	import ldc.intrinsics;
	pragma(inline, true)
	U clz(U)(U u) @safe @nogc pure nothrow
	if (is(Unqual!U == uint) || is(Unqual!U == size_t))
		=> llvm_ctlz(u, false);

	static if (isX86) {
		pragma(inline, true)
		uint clz(U)(U u) @safe @nogc pure nothrow
		if (is(Unqual!U == ulong))
			=> cast(uint)llvm_ctlz(u, false);
	}
}

version (X86_64) {
	private enum isAMD64 = true;
	private enum isX86   = false;
}
else version (X86) {
	private enum isAMD64 = false;
	private enum isX86   = true;
}

version (X86_64)
	private enum hasSSE2 = true;
else
	private enum hasSSE2 = false;

static import core.bitop;

alias bsr = core.bitop.bsr;
alias bsf = core.bitop.bsf;

pure nothrow @safe @nogc unittest {
	assert(clz(uint(0x01234567)) == 7);
	assert(clz(ulong(0x0123456701234567)) == 7);
	assert(clz(ulong(0x0000000001234567)) == 7+32);
	assert(bsr(uint(0x01234567)) == 24);
	assert(bsr(ulong(0x0123456701234567)) == 24+32);
	assert(bsr(ulong(0x0000000001234567)) == 24);
	assert(bsf(uint(0x76543210)) == 4);
	assert(bsf(ulong(0x7654321076543210)) == 4);
	assert(bsf(ulong(0x7654321000000000)) == 4+32);
}
