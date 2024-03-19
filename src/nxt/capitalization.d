module nxt.capitalization;

import std.traits : isSomeString;

@safe:

/** Check if `s` is a lowercased ASCII string. */
bool isLowercasedASCII(in char[] s) pure @safe nothrow @nogc {
	import std.ascii : isLower;
	foreach (const c; s)
		if (!c.isLower)
			return false;
	return true;
}

/// ditto
pure @safe nothrow @nogc unittest {
	assert(!`A`.isLowercasedASCII);
	assert(`a`.isLowercasedASCII);
	assert(`alpha`.isLowercasedASCII);
	assert(!`ALPHA`.isLowercasedASCII);
	assert(!`aThing`.isLowercasedASCII);
	assert(!`Alpha`.isLowercasedASCII);
	assert(!`Jack London`.isLowercasedASCII);
}

/** Check if `s` is an uppercased ASCII string. */
bool isUppercasedASCII(in char[] s) pure @safe nothrow @nogc {
	import std.ascii : isUpper;
	foreach (const c; s)
		if (!c.isUpper)
			return false;
	return true;
}

/// ditto
pure @safe nothrow @nogc unittest {
	assert(`A`.isUppercasedASCII);
	assert(!`a`.isUppercasedASCII);
	assert(!`alpha`.isUppercasedASCII);
	assert(`ALPHA`.isUppercasedASCII);
	assert(!`aThing`.isUppercasedASCII);
	assert(!`Alpha`.isUppercasedASCII);
	assert(!`Jack London`.isUppercasedASCII);
}

/** Check if `s` starts with a capital letter followed by a lower letter. */
bool isCapitalizedASCII(in char[] s) pure @safe nothrow @nogc {
	import std.ascii : isUpper, isLower;
	return (s.length >= 2 &&
			s[0].isUpper &&
			s[1].isLower);
}

/// ditto
pure @safe nothrow @nogc unittest {
	assert(!`A`.isCapitalizedASCII);
	assert(!`a`.isCapitalizedASCII);
	assert(!`alpha`.isCapitalizedASCII);
	assert(!`ALPHA`.isCapitalizedASCII);
	assert(!`aThing`.isCapitalizedASCII);
	assert(`Alpha`.isCapitalizedASCII);
	assert(`Jack London`.isCapitalizedASCII);
}

/** Check if `s` starts with a capital letter followed by a lower letter.
 */
bool isCapitalizedSimple(S)(S s) if (isSomeString!S) {
	import std.range.primitives : empty, front, popFront;
	import std.uni : isUpper, isLower;
	if (s.empty) { return false; }
	const firstUpper = s.front.isUpper;
	if (!firstUpper) return false;
	s.popFront();
	if (s.empty) { return false; }
	return s.front.isLower;
}

/// ditto
pure @safe unittest {
	assert(!`A`.isCapitalizedSimple);
	assert(!`a`.isCapitalizedSimple);
	assert(!`alpha`.isCapitalizedSimple);
	assert(!`ALPHA`.isCapitalizedSimple);
	assert(!`aThing`.isCapitalizedSimple);
	assert(`Alpha`.isCapitalizedSimple);
	assert(`Jack London`.isCapitalizedSimple);
}

/** Check if `s` lowercased, that is only contains lower-case characters.
 */
bool isLowercased(S)(S s) if (isSomeString!S) {
	import std.uni : isLower;
	import std.algorithm.searching : all;
	import std.traits : isNarrowString;
	import std.utf : byUTF;
	alias pred = isLower;
	/+ TODO: functionize +/
	static if (isNarrowString!S)
		return s.byUTF!dchar.all!(ch => pred(ch));
	else
		return t.map!(ch => pred(ch));
}

///
pure @safe unittest {
	assert(!`A`.isLowercased);
	assert(`a`.isLowercased);
	assert(!`Ä`.isLowercased);
	assert(`ä`.isLowercased);
}

/** Check if `s` uppercased, that is only contains upper-case characters.
 */
bool isUppercased(S)(S s) if (isSomeString!S) {
	import std.uni : isUpper;
	import std.algorithm.searching : all;
	import std.traits : isNarrowString;
	import std.utf : byUTF;
	alias pred = isUpper;
	/+ TODO: functionize +/
	static if (isNarrowString!S)
		return s.byUTF!dchar.all!(ch => pred(ch));
	else
		return t.map!(ch => pred(ch));
}

pure @safe unittest {
	assert(`A`.isUppercased);
	assert(!`a`.isUppercased);
	assert(`Ä`.isUppercased);
	assert(!`ä`.isUppercased);
}

/** Check if `s` has proper noun capitalization.
 *
 * That is, `s` starts with a capital letter followed by only lower letters.
 */
bool isCapitalized(S)(S s) if (isSomeString!S) {
	import std.range.primitives : empty, front, popFront;

	if (s.empty) { return false; }

	import std.ascii : isDigit;
	import std.uni : isUpper;
	const firstDigit = s.front.isDigit;
	const firstUpper = s.front.isUpper;

	if (!(firstDigit ||
		  firstUpper))
		return false;

	s.popFront();

	if (s.empty)
		return firstDigit;
	else {
		import std.uni : isLower;
		import std.algorithm.searching : all;
		return s.all!(x => (x.isDigit ||
							x.isLower));
	}
}

///
pure @safe unittest {
	assert(!``.isCapitalized);
	assert(!`alpha`.isCapitalized);
	assert(!`ALPHA`.isCapitalized);
	assert(!`aThing`.isCapitalized);
	assert(`Alpha`.isCapitalized);
	assert(!`Jack London`.isCapitalized);
}

/** Return `true` if `s` has proper name capitalization, such as in
 * "Africa" or "South Africa".
 */
bool isProperNameCapitalized(S)(S s) if (isSomeString!S) {
	import nxt.splitter_ex : splitterASCII;
	import std.algorithm.comparison : among;
	import std.algorithm.searching : all;
	import std.ascii : isWhite;
	import std.uni : isUpper;
	size_t index = 0;
	foreach (const word; s.splitterASCII!(s => (s.isWhite || s == '-'))) {
		const bool ok = ((index >= 1 &&
						  (word.all!(word => word.isUpper) || // Henry II
						   word.among!(`of`, `upon`))) ||
						 word.isCapitalized);
		if (!ok) { return false; }
		index += 1;
	}
	return true;
}

///
pure @safe unittest {
	assert(!`alpha`.isProperNameCapitalized);
	assert(!`alpha centauri`.isProperNameCapitalized);
	assert(!`ALPHA`.isProperNameCapitalized);
	assert(!`ALPHA CENTAURI`.isProperNameCapitalized);
	assert(!`aThing`.isProperNameCapitalized);
	assert(`Alpha`.isProperNameCapitalized);
	assert(`Alpha Centauri`.isProperNameCapitalized);
	assert(`11104 Airion`.isProperNameCapitalized);
	assert(`New York City`.isProperNameCapitalized);
	assert(`1-Hexanol`.isProperNameCapitalized);
	assert(`11-Hexanol`.isProperNameCapitalized);
	assert(`22nd Army`.isProperNameCapitalized);
	assert(!`22nd army`.isProperNameCapitalized);
	assert(`2nd World War`.isProperNameCapitalized);
	assert(`Second World War`.isProperNameCapitalized);
	assert(`Värmland`.isProperNameCapitalized);
	assert(!`The big sky`.isProperNameCapitalized);
	assert(`Suur-London`.isProperNameCapitalized);
	assert(`Kingdom of Sweden`.isProperNameCapitalized);
	assert(`Stratford upon Avon`.isProperNameCapitalized);
	assert(`Henry II`.isProperNameCapitalized);
}
