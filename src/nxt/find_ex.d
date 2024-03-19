module nxt.find_ex;

import std.typecons: Tuple, tuple;
import std.string: CaseSensitive;

enum FindContext { inWord, inSymbol,
				   asWord, asSymbol }

/** Return true if $(D a) is a C-style Identifier symbol character. */
bool isSymbol(T)(in T a) pure nothrow @safe @nogc
{
	import std.ascii: isAlpha;
	return a.isAlpha || a == '_';
}

bool isSymbolASCII(in string rest, ptrdiff_t off, size_t end) pure nothrow @safe @nogc
in(end <= rest.length)
{
	import std.ascii: isAlphaNum;
	return ((off == 0 || // either beginning of line
			 !rest[off - 1].isAlphaNum &&
			 rest[off - 1] != '_') &&
			(end == rest.length || // either end of line
			 !rest[end].isAlphaNum &&
			 rest[end] != '_'));
}

///
pure nothrow @safe @nogc unittest {
	assert(isSymbolASCII("alpha", 0, 5));
	assert(isSymbolASCII(" alpha ", 1, 6));
	assert(!isSymbolASCII("driver", 0, 5));
	assert(!isSymbolASCII("a_word", 0, 1));
	assert(!isSymbolASCII("first_a_word", 6, 7));
}

bool isWordASCII(in string rest, ptrdiff_t off, size_t end) pure nothrow @safe @nogc
in(end <= rest.length)
{
	import std.ascii: isAlphaNum;
	return ((off == 0 || // either beginning of line
			 !rest[off - 1].isAlphaNum) &&
			(end == rest.length || // either end of line
			 !rest[end].isAlphaNum));
}

///
pure nothrow @safe @nogc unittest {
	assert(isSymbolASCII("alpha", 0, 5));
	assert(isSymbolASCII(" alpha ", 1, 6));
	assert(!isSymbolASCII("driver", 0, 5));
	assert(isWordASCII("a_word", 0, 1));
	assert(isWordASCII("first_a_word", 6, 7));
	assert(isWordASCII("first_a", 6, 7));
}

// Parameterize on isAlpha and isSymbol.

/** Find $(D needle) as Word or Symbol Acronym at $(D haystackOffset) in $(D haystack).
	TODO: Make it compatible (specialized) for InputRange or BidirectionalRange.
*/
Tuple!(R, ptrdiff_t[]) findAcronymAt(alias pred = "a == b",
									 R,
									 E)(R haystack,
										in E needle,
										FindContext ctx = FindContext.inWord,
										CaseSensitive cs = CaseSensitive.yes, /+ TODO: Use this +/
										size_t haystackOffset = 0) @safe pure
{
	import std.ascii: isAlpha;
	import std.algorithm: find;
	import std.range: empty;

	auto aOffs = new ptrdiff_t[needle.length]; // acronym hit offsets

	auto rest = haystack[haystackOffset..$];
	while (needle.length <= rest.length) // for each new try at finding the needle at remainding part of haystack
	{
		/* debug dbg(needle, ", ", rest); */

		// find first character
		size_t nIx = 0;		 // needle index
		rest = rest.find!pred(needle[nIx]); // reuse std.algorithm: find!
		if (rest.empty) { return tuple(rest, ptrdiff_t[].init); } // degenerate case
		aOffs[nIx++] = &rest[0] - &haystack[0]; // store hit offset and advance acronym
		rest = rest[1 .. $];
		const ix0 = aOffs[0];

		// check context before point
		final switch (ctx)
		{
			case FindContext.inWord:   break; /+ TODO: find word characters before point and set start offset +/
			case FindContext.inSymbol: break; /+ TODO: find symbol characters before point and set start offset +/
			case FindContext.asWord:
				if (ix0 >= 1 && haystack[ix0-1].isAlpha) { goto miss; } // quit if not word start
				break;
			case FindContext.asSymbol:
				if (ix0 >= 1 && haystack[ix0-1].isSymbol) { goto miss; } // quit if not symbol stat
				break;
		}

		while (rest)			// while elements left in haystack
		{

			// Check elements in between
			ptrdiff_t hit = -1;
			import std.algorithm: countUntil;
			import std.functional: binaryFun;
			final switch (ctx)
			{
				case FindContext.inWord:
				case FindContext.asWord:
					hit = rest.countUntil!(x => (binaryFun!pred(x, needle[nIx])) || !x.isAlpha); break;
				case FindContext.inSymbol:
				case FindContext.asSymbol:
					hit = rest.countUntil!(x => (binaryFun!pred(x, needle[nIx])) || !x.isSymbol); break;
			}
			if (hit == -1) { goto miss; } // no hit this time

			// Check if hit
			if (hit == rest.length || // if we searched till the end
				rest[hit] != needle[nIx]) // acronym letter not found
			{
				rest = haystack[aOffs[0]+1 .. $]; // try beyond hit
				goto miss;	  // no hit this time
			}

			aOffs[nIx++] = (&rest[0] - &haystack[0]) + hit; // store hit offset and advance acronym
			if (nIx == needle.length) // if complete acronym found
			{
				return tuple(haystack[aOffs[0] .. aOffs[$-1] + 1], aOffs) ; // return its length
			}
			rest = rest[hit+1 .. $]; // advance in source beyound hit
		}
	miss:
		continue;
	}
	return tuple(R.init, ptrdiff_t[].init); // no hit
}

///
pure @safe unittest {
	assert("size_t".findAcronymAt("sz_t", FindContext.inWord)[0] == "size_t");
	assert("size_t".findAcronymAt("sz_t", FindContext.inSymbol)[0] == "size_t");
	assert("åäö_ab".findAcronymAt("ab")[0] == "ab");
	assert("fopen".findAcronymAt("fpn")[0] == "fopen");
	assert("fopen_".findAcronymAt("fpn")[0] == "fopen");
	assert("_fopen".findAcronymAt("fpn", FindContext.inWord)[0] == "fopen");
	assert("_fopen".findAcronymAt("fpn", FindContext.inSymbol)[0] == "fopen");
	assert("f_open".findAcronymAt("fpn", FindContext.inWord)[0] == []);
	assert("f_open".findAcronymAt("fpn", FindContext.inSymbol)[0] == "f_open");
}
