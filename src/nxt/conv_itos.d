module nxt.conv_itos;

@safe:

uint fastLog10(const uint val) pure nothrow @safe @nogc
{
	// in order of probability
	if (val < 1e1) return 0;
	if (val < 1e2) return 1;
	if (val < 1e3) return 2;
	if (val < 1e4) return 3;
	if (val < 1e5) return 4;
	if (val < 1e6) return 5;
	if (val < 1e7) return 6;
	if (val < 1e8) return 7;
	if (val < 1e9) return 8;
	if (val < 1e10) return 9;
	return 9;
}

///
pure @safe unittest {
	assert(fastLog10(1) == 0);
	assert(fastLog10(9) == 0);
	assert(fastLog10(11) == 1);
	assert(fastLog10(99) == 1);
	assert(fastLog10(111) == 2);
	assert(fastLog10(999) == 2);
	assert(fastLog10(1_111) == 3);
	assert(fastLog10(9_999) == 3);
	assert(fastLog10(11_111) == 4);
	assert(fastLog10(99_999) == 4);
	assert(fastLog10(999_999_999) == 8);
	assert(fastLog10(1_000_000_000) == 9);
	assert(fastLog10(uint.max) == 9);
}

uint fastLog10(const ulong val) pure nothrow @safe @nogc
{
	// in order of probability
	if (val < cast(ulong)1e1) return 0;
	if (val < cast(ulong)1e2) return 1;
	if (val < cast(ulong)1e3) return 2;
	if (val < cast(ulong)1e4) return 3;
	if (val < cast(ulong)1e5) return 4;
	if (val < cast(ulong)1e6) return 5;
	if (val < cast(ulong)1e7) return 6;
	if (val < cast(ulong)1e8) return 7;
	if (val < cast(ulong)1e9) return 8;
	if (val < cast(ulong)1e10) return 9;
	if (val < cast(ulong)1e11) return 10;
	if (val < cast(ulong)1e12) return 11;
	if (val < cast(ulong)1e13) return 12;
	if (val < cast(ulong)1e14) return 13;
	if (val < cast(ulong)1e15) return 14;
	if (val < cast(ulong)1e16) return 15;
	if (val < cast(ulong)1e17) return 16;
	if (val < cast(ulong)1e18) return 17;
	if (val < cast(ulong)1e19) return 18;
	if (val < cast(ulong)1e20) return 19;
	return 19;
}

///
pure @safe unittest {
	assert(fastLog10(1UL) == 0);
	assert(fastLog10(9UL) == 0);
	assert(fastLog10(11UL) == 1);
	assert(fastLog10(99UL) == 1);
	/+ TODO: assert(fastLog10(111UL) == 2); +/
	assert(fastLog10(999UL) == 2);
	assert(fastLog10(1_111UL) == 3);
	assert(fastLog10(9_999UL) == 3);
	assert(fastLog10(11_111UL) == 4);
	assert(fastLog10(99_999UL) == 4);
	assert(fastLog10(999_999_999UL) == 8);
	assert(fastLog10(1_000_000_000UL) == 9);
	assert(fastLog10(10_000_000_000UL) == 10);
	assert(fastLog10(100_000_000_000UL) == 11);
	assert(fastLog10(1_000_000_000_000UL) == 12);
	assert(fastLog10(10_000_000_000_000UL) == 13);
	assert(fastLog10(100_000_000_000_000UL) == 14);
	assert(fastLog10(1_000_000_000_000_000UL) == 15);
	assert(fastLog10(10_000_000_000_000_000UL) == 16);
	assert(fastLog10(100_000_000_000_000_000UL) == 17);
	assert(fastLog10(1_000_000_000_000_000_000UL) == 18);
	assert(fastLog10(10_000_000_000_000_000_000UL) == 19);
}

/*@unique*/
private static immutable fastPow10tbl_32bit_unsigned = [
	1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
	];

/** Convert `val` to a `string` and return it.
 */
string uint_to_string(const uint val) @trusted pure nothrow
{
	immutable length = fastLog10(val) + 1;
	char[] result;
	result.length = length;
	foreach (immutable i; 0 .. length) {
		immutable _val = val / fastPow10tbl_32bit_unsigned[i];
		result[length - i - 1] = cast(char)((_val % 10) + '0');
	}
	return cast(string) result;
}

static assert(mixin(uint.max.uint_to_string) == uint.max);

pure @safe unittest {
}
