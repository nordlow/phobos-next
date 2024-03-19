/++ Conversion that use result types instead of exception handling.
 +/
module nxt.conv;

import nxt.result : Result;

@safe:

/++ Try to parse `s` as a `T`. +/
Result!(T) tryParse(T)(scope const(char)[] s) pure nothrow @nogc
if (__traits(isArithmetic, T) && __traits(isIntegral, T)) {
	alias R = typeof(return);

	// accumulator type
	static if (__traits(isUnsigned, T))
		alias A = ulong;
	else
		alias A = long;

	if (!s.length) // empty
		return R.invalid;

	// strip optional leading {plus|minus} sign
	bool minus;
	if (s.length) {
		if (s[0] == '-')
			minus = true;
		if (s[0] == '+' || s[0] == '-')
			s = s[1 .. $];
	}

	// accumulate
	A curr = 0; // current accumulated value
    foreach (const c; s) {
        if (c < '0' || c > '9') // non-digit
			return R.invalid;
        A prev = curr;
        curr = 10 * curr + (c - '0'); // accumulate
        if (curr < prev) // overflow
			return R.invalid;
    }

	// range check
	assert(T.min <= curr);
	assert(curr <= T.max);

    return R(cast(T)curr);
}

@safe pure nothrow @nogc unittest {
	foreach (T; IntegralTypes) {
		assert(!"".tryParse!T.isValid); // empty
		assert(!"_".tryParse!T.isValid); // non-digit
		assert(*"+0".tryParse!T == 0);
		assert(!*"+0".tryParse!T);
		assert(*"+1".tryParse!T == 1);
		assert(*"-0".tryParse!T == 0);
		assert(*"0".tryParse!T == 0);
		assert(*"1".tryParse!T == 1);
		assert(*"2".tryParse!T == 2);
		assert(*"10".tryParse!T == 10);
		assert(*"11".tryParse!T == 11);
	}
	// unsigned min
	foreach (T; UnsignedTypes) {
		assert(*"0".tryParse!T == T.min);
		assert(*"+0".tryParse!T == T.min);
	}
	// unsigned max
	assert(*"255".tryParse!ubyte == 255);
	assert(*"65535".tryParse!ushort == 65535);
	assert(*"4294967295".tryParse!uint == 4294967295);
	assert(*"18446744073709551615".tryParse!ulong == ulong.max);
	// signed max
	assert(*"9223372036854775807".tryParse!long == long.max);
	// overflow
	assert(!"18446744073709551616".tryParse!ulong);
}

version (unittest) {
	import std.meta : AliasSeq;
	alias UnsignedTypes = AliasSeq!(ubyte, ushort, uint, ulong);
	alias SignedTypes = AliasSeq!(byte, short, int, long);
	alias IntegralTypes = AliasSeq!(ubyte, ushort, uint, ulong, byte, short, int, long);
}
