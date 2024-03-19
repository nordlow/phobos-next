/** Conversions between integral values and numerals. */
module nxt.numerals;

import std.conv: to;
import std.traits: isIntegral, isUnsigned, isSomeString;

/** Get English ordinal number of unsigned integer $(D n) default to
 * `defaultOrdinal` if `n` is too large.
 *
 * See_Also: https://en.wikipedia.org/wiki/Ordinal_number_(linguistics)
 */
string toEnglishOrdinal(T)(T n, string defaultOrdinal)
if (isUnsigned!T)
{
	switch (n)
	{
		case 0: return `zeroth`;
		case 1: return `first`;
		case 2: return `second`;
		case 3: return `third`;
		case 4: return `fourth`;
		case 5: return `fifth`;
		case 6: return `sixth`;
		case 7: return `seventh`;
		case 8: return `eighth`;
		case 9: return `ninth`;
		case 10: return `tenth`;
		case 11: return `eleventh`;
		case 12: return `twelveth`;
		case 13: return `thirteenth`;
		case 14: return `fourteenth`;
		case 15: return `fifteenth`;
		case 16: return `sixteenth`;
		case 17: return `seventeenth`;
		case 18: return `eighteenth`;
		case 19: return `nineteenth`;
		case 20: return `twentieth`;
		default: return defaultOrdinal;
	}
}

/** Get English ordinal number of unsigned integer $(D n).
 *
 * See_Also: https://en.wikipedia.org/wiki/Ordinal_number_(linguistics)
 */
T fromEnglishOrdinalTo(T)(scope const(char)[] ordinal)
if (isUnsigned!T)
{
	switch (ordinal)
	{
	case `zeroth`: return 0;
	case `first`: return 1;
	case `second`: return 2;
	case `third`: return 3;
	case `fourth`: return 4;
	case `fifth`: return 5;
	case `sixth`: return 6;
	case `seventh`: return 7;
	case `eighth`: return 8;
	case `ninth`: return 9;
	case `tenth`: return 10;
	case `eleventh`: return 11;
	case `twelveth`: return 12;
	case `thirteenth`: return 13;
	case `fourteenth`: return 14;
	case `fifteenth`: return 15;
	case `sixteenth`: return 16;
	case `seventeenth`: return 17;
	case `eighteenth`: return 18;
	case `nineteenth`: return 19;
	case `twentieth`: return 20;
	default:
		// import nxt.algorithm.searching : skipOver;
		// assert(ordinal.skipOver(`th`));
		assert(0, `Handle this case`);
	}
}

pure nothrow @safe @nogc unittest {
	assert(`zeroth`.fromEnglishOrdinalTo!uint == 0);
	assert(`fourteenth`.fromEnglishOrdinalTo!uint == 14);
}

enum onesNumerals = [ `zero`, `one`, `two`, `three`, `four`,
					  `five`, `six`, `seven`, `eight`, `nine` ];
enum singleWords = onesNumerals ~ [ `ten`, `eleven`, `twelve`, `thirteen`, `fourteen`,
									`fifteen`, `sixteen`, `seventeen`, `eighteen`, `nineteen` ];
enum tensNumerals = [ null, `ten`, `twenty`, `thirty`, `forty`,
					  `fifty`, `sixty`, `seventy`, `eighty`, `ninety`, ];

enum englishNumeralsMap = [ `zero`:0, `one`:1, `two`:2, `three`:3, `four`:4,
							`five`:5, `six`:6, `seven`:7, `eight`:8, `nine`:9,
							`ten`:10, `eleven`:11, `twelve`:12, `thirteen`:13, `fourteen`:14,
							`fifteen`:15, `sixteen`:16, `seventeen`:17, `eighteen`:18, `nineteen`:19,
							`twenty`:20,
							`thirty`:30,
							`forty`:40,
							`fourty`:40, // common missspelling
							`fifty`:50,
							`sixty`:60,
							`seventy`:70,
							`eighty`:80,
							`ninety`:90,
							`hundred`:100,
							`thousand`:1_000,
							`million`:1_000_000,
							`billion`:1_000_000_000,
							`trillion`:1_000_000_000_000 ];

/** Check if $(D c) is an English atomic numeral. */
bool isEnglishAtomicNumeral(S)(S s)
if (isSomeString!S)
{
	return s.among!(`zero`, `one`, `two`, `three`, `four`,
					`five`, `six`, `seven`, `eight`, `nine`,
					`ten`, `eleven`, `twelve`, `thirteen`, `fourteen`,
					`fifteen`, `sixteen`, `seventeen`, `eighteen`, `nineteen`,
					`twenty`, `thirty`, `forty`, `fourty`,  // common missspelling
					`fifty`, `sixty`, `seventy`, `eighty`, `ninety`,
					`hundred`, `thousand`, `million`, `billion`, `trillion`, `quadrillion`);
}

static immutable ubyte[string] _onesPlaceWordsAA;

/* NOTE Be careful with this logic
   This fails: foreach (ubyte i, e; onesNumerals) { _onesPlaceWordsAA[e] = i; }
   See_Also: http://forum.dlang.org/thread/vtenbjmktplcxxmbyurt@forum.dlang.org#post-iejbrphbqsszlxcxjpef:40forum.dlang.org
   */
shared static this()
{
	import std.exception: assumeUnique;
	ubyte[string] tmp;
	foreach (immutable i, e; onesNumerals)
	{
		tmp[e] = cast(ubyte)i;
	}
	_onesPlaceWordsAA = assumeUnique(tmp); /* Don't alter tmp from here on. */
}

import std.traits: isIntegral;

/** Convert the number $(D number) to its English textual representation
	(numeral) also called cardinal number.
	Opposite: fromNumeral
	See_Also: https://en.wikipedia.org/wiki/Numeral_(linguistics)
	See_Also: https://en.wikipedia.org/wiki/Cardinal_number_(linguistics)
*/
string toNumeral(T)(T number, string minusName = `minus`)
if (isIntegral!T)
{
	string word;

	if (number == 0)
		return `zero`;

	if (number < 0)
	{
		word = minusName ~ ' ';
		number = -number;
	}

	while (number)
	{
		if (number < 100)
		{
			if (number < singleWords.length)
			{
				word ~= singleWords[cast(int) number];
				break;
			}
			else
			{
				auto tens = number / 10;
				word ~= tensNumerals[cast(int) tens];
				number = number % 10;
				if (number)
					word ~= `-`;
			}
		}
		else if (number < 1_000)
		{
			auto hundreds = number / 100;
			word ~= onesNumerals[cast(int) hundreds] ~ ` hundred`;
			number = number % 100;
			if (number)
				word ~= ` and `;
		}
		else if (number < 1_000_000)
		{
			auto thousands = number / 1_000;
			word ~= toNumeral(thousands) ~ ` thousand`;
			number = number % 1_000;
			if (number)
				word ~= `, `;
		}
		else if (number < 1_000_000_000)
		{
			auto millions = number / 1_000_000;
			word ~= toNumeral(millions) ~ ` million`;
			number = number % 1_000_000;
			if (number)
				word ~= `, `;
		}
		else if (number < 1_000_000_000_000)
		{
			auto n = number / 1_000_000_000;
			word ~= toNumeral(n) ~ ` billion`;
			number = number % 1_000_000_000;
			if (number)
				word ~= `, `;
		}
		else if (number < 1_000_000_000_000_000)
		{
			auto n = number / 1_000_000_000_000;
			word ~= toNumeral(n) ~ ` trillion`;
			number = number % 1_000_000_000_000;
			if (number)
				word ~= `, `;
		}
		else
		{
			return to!string(number);
		}
	}

	return word;
}
alias toTextual = toNumeral;

pure nothrow @safe unittest {
	assert(1.toNumeral == `one`);
	assert(5.toNumeral == `five`);
	assert(13.toNumeral == `thirteen`);
	assert(54.toNumeral == `fifty-four`);
	assert(178.toNumeral == `one hundred and seventy-eight`);
	assert(592.toNumeral == `five hundred and ninety-two`);
	assert(1_234.toNumeral == `one thousand, two hundred and thirty-four`);
	assert(10_234.toNumeral == `ten thousand, two hundred and thirty-four`);
	assert(105_234.toNumeral == `one hundred and five thousand, two hundred and thirty-four`);
	assert(7_105_234.toNumeral == `seven million, one hundred and five thousand, two hundred and thirty-four`);
	assert(3_007_105_234.toNumeral == `three billion, seven million, one hundred and five thousand, two hundred and thirty-four`);
	assert(555_555.toNumeral == `five hundred and fifty-five thousand, five hundred and fifty-five`);
	assert(900_003_007_105_234.toNumeral == `nine hundred trillion, three billion, seven million, one hundred and five thousand, two hundred and thirty-four`);
	assert((-5).toNumeral == `minus five`);
}

import std.typecons: Nullable;

version = show;

/** Convert the number $(D number) to its English textual representation.
	Opposite: toNumeral.
	TODO: Throw if number doesn't fit in long.
	TODO: Add variant to toTextualBigIntegerMaybe.
	TODO: Could this be merged with to!(T)(string) if (isInteger!T) ?
*/
Nullable!long fromNumeral(T = long, S)(S x) @safe pure
if (isSomeString!S)
{
	import std.algorithm: splitter, countUntil, skipOver, findSplit;
	import nxt.algorithm.searching : endsWith;
	import std.range: empty;

	typeof(return) total;

	T sum = 0;
	bool defined = false;
	bool negative = false;

	auto terms = x.splitter(`,`); // comma separate terms
	foreach (term; terms)
	{
		auto factors = term.splitter; // split factors by whitespace

		// prefixes
		factors.skipOver(`plus`); // no semantic effect
		if (factors.skipOver(`minus`) ||
			factors.skipOver(`negative`))
			negative = true;
		factors.skipOver(`plus`); // no semantic effect

		// main
		T product = 1;
		bool tempSum = false;
		foreach (const factor; factors)
		{
			if (factor == `and`)
				tempSum = true;
			else
			{
				T subSum = 0;
				foreach (subTerm; factor.splitter(`-`)) // split for example fifty-five to [`fifty`, `five`]
				{
					if (const value = subTerm in englishNumeralsMap)
					{
						subSum += *value;
						defined = true;
					}
					else if (subTerm.endsWith(`s`)) // assume plural s for common misspelling millions instead of million
					{
						if (const value = subTerm[0 .. $ - 1] in englishNumeralsMap) // without possible plural s
						{
							subSum += *value;
							defined = true;
						}
					}
					else
					{
						return typeof(return).init; // could not process
					}
				}
				if (tempSum)
				{
					product += subSum;
					tempSum = false;
				}
				else
					product *= subSum;
			}
		}

		sum += product;
	}

	if (defined)
		return typeof(return)(negative ? -sum : sum);
	else
		return typeof(return).init;
}

pure @safe unittest {
	import std.range: chain, iota;

	// undefined cases
	assert(``.fromNumeral.isNull);
	assert(`dum`.fromNumeral.isNull);
	assert(`plus`.fromNumeral.isNull);
	assert(`minus`.fromNumeral.isNull);

	foreach (i; chain(iota(0, 20),
					  iota(20, 100, 10),
					  iota(100, 1000, 100),
					  iota(1000, 10000, 1000),
					  iota(10000, 100000, 10000),
					  iota(100000, 1000000, 100000),
					  [55, 1_200, 105_000, 155_000, 555_555, 150_000, 3_001_200]))
	{
		const ti = i.toNumeral;
		assert(-i == (`minus ` ~ ti).fromNumeral);
		assert(+i == (`plus ` ~ ti).fromNumeral);
		assert(+i == ti.fromNumeral);
	}

	assert(`nine thousands`.fromNumeral == 9_000);
	assert(`two millions`.fromNumeral == 2_000_000);
	assert(`twenty-two hundred`.fromNumeral == 2200);
	assert(`two fifty`.fromNumeral == 100);
	assert(`two tens`.fromNumeral == 20);
	assert(`two ten`.fromNumeral == 20);
}
