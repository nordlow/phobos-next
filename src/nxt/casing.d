module nxt.casing;

import std.traits : isSomeString;
import nxt.string_traits : isASCIIString;

version (unittest) {
	import std.algorithm : equal;
}

/** Convert string $(S s) to lower-case.
 *
 * String must contain ASCII characters only.
 */
auto toLowerASCII_(S)(S s)
if (isSomeString!S) {
	import std.algorithm.iteration : map;
	import std.ascii : toLower;
	import std.traits : isNarrowString;
	static if (isNarrowString!S) {
		import std.utf : byUTF;
		return s.byUTF!dchar.map!(ch => ch.toLower);
	}
	else
		return t.map!(ch => ch.toLower);
}

/++ Return `s` lowercased if `s` is an ASCII-string, otherwise `defaultValue`. +/
string toLowerIfASCII(scope const(char)[] s, string defaultValue) @safe pure nothrow {
	if (!s.isASCIIString)
		return defaultValue;
	typeof(return) result;
	result.reserve(s.length);
	foreach (const c; s) {
		import std.ascii : toLower;
		result ~= c.toLower;
	}
	return result;
}

/++ Return `s` lowercased if `s` is an ASCII-string, otherwise `s`. +/
inout(char)[] toLowerIfASCII(return scope inout(char)[] s) @safe pure nothrow {
	if (!s.isASCIIString)
		return s;
	typeof(return) result;
	result.reserve(s.length);
	foreach (const c; s) {
		import std.ascii : toLower;
		result ~= c.toLower;
	}
	return result;
}

///
@safe pure /*TODO: nothrow @nogc*/ unittest {
	assert("Lasse".toLowerIfASCII("Lasse").equal("lasse"));
	assert("Åberg".toLowerIfASCII("Åberg").equal("Åberg"));
	assert("Lasse".toLowerIfASCII.equal("lasse"));
	assert("Åberg".toLowerIfASCII.equal("Åberg"));
}

/** Convert string $(S s) to lower-case.
 *
 * String may contain Unicode characters.
 */
auto toLowerUnicode(S)(S s)
if (isSomeString!S) {
	import std.algorithm.iteration : map;
	import std.uni : toLower;
	import std.traits : isNarrowString;
	/+ TODO: functionize +/
	static if (isNarrowString!S) {
		import std.utf : byUTF;
		return s.byUTF!dchar.map!(ch => ch.toLower);
	}
	else
		return t.map!(ch => ch.toLower);
}

///
@safe pure /*TODO: nothrow @nogc*/ unittest {
	assert("Lasse".toLowerUnicode.equal("lasse"));
	assert("Åberg".toLowerUnicode.equal("åberg"));
}

/** Convert D-style camel-cased string $(S s) to lower-cased words.
 */
auto camelCasedToLower(S)(S s)
if (isSomeString!S) {
	import std.algorithm.iteration : map;
	import std.ascii : isUpper; // D symbol names can only be in ASCII
	/+ TODO: Instead of this add std.ascii.as[Lower|Upper]Case and import std.ascii.asLowerCase +/
	import std.uni : asLowerCase;
	import nxt.slicing : preSlicer;
	return s.preSlicer!isUpper.map!asLowerCase;
}

///
pure @safe unittest {
	auto x = "doThis".camelCasedToLower;
	assert(x.front.equal("do"));
	x.popFront();
	assert(x.front.equal("this"));
}

/** Convert D-Style camel-cased string $(S s) to space-separated lower-cased words.
 */
auto camelCasedToLowerSpaced(S, Separator)(S s, const Separator separator = " ")
if (isSomeString!S) {
	import std.algorithm.iteration : joiner;
	return camelCasedToLower(s).joiner(separator);
}

///
pure @safe unittest {
	assert(equal("doThis".camelCasedToLowerSpaced,
				 "do this"));
}

/** Convert enumeration value (enumerator) $(D t) to a range chars.
 */
auto toLowerSpacedChars(T, Separator)(const T t,
									  const Separator separator = " ")
if (is(T == enum)) {
	import nxt.enum_ex : toStringFromEnumWithConsecutiveAliases;
	return t.toStringFromEnumWithConsecutiveAliases
			.camelCasedToLowerSpaced(separator);
}

///
pure @safe unittest {
	enum Things { isUri, isLink }
	assert(Things.isUri.toLowerSpacedChars.equal("is uri"));
	assert(Things.isLink.toLowerSpacedChars.equal("is link"));
}

///
pure @safe unittest {
	enum Things { isURI, isLink }
	auto r = Things.isURI.toLowerSpacedChars;
	alias R = typeof(r);
	import std.range.primitives : ElementType;
	alias E = ElementType!R;
	static assert(is(E == dchar));
}
