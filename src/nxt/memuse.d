/** Memory Usage.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.memuse;

import nxt.csunits;

/** Linear One-Dimensional Growth on index of type $(D D) with $(D ElementSize). */
struct Linear1D(D, size_t ElementSize) {}

/** Quadratic One-Dimensional Growth on index of type $(D D) with $(D ElementSize). */
struct Quadratic1D(D, size_t ElementSize) {}

/** Get Asymptotic Memory Usage of $(D x) in Bytes.
 */
template UsageOf(T)
{
	import std.range: ElementType;
	import std.traits: isDynamicArray, hasIndirections, isScalarType;
	import std.typecons: Nullable;

	static if (!hasIndirections!T)
	{
		enum UsageOf = T.sizeof;
	}
	else static if (isDynamicArray!T &&
					isScalarType!(ElementType!T))
	{
		alias UsageOf = Linear1D!(size_t, ElementType!T.sizeof);
	}
	else static if (isDynamicArray!T &&
					isDynamicArray!(ElementType!T) &&
					isScalarType!(ElementType!(ElementType!T)))
	{
		alias UsageOf = Quadratic1D!(size_t, ElementType!T.sizeof);
	}
	else
	{
		static assert(0, "Type " ~ T.stringof ~ "unsupported.");
	}

	/** Maybe Minimum Usage in bytes. */
	/* size_t min() { return 0; } */

	/** Maybe Maximum Usage in bytes. */
	/* Nullable!size_t max() { return 0; } */
}

pure nothrow @safe @nogc unittest {
	import std.meta: AliasSeq;

	foreach (T; AliasSeq!(byte, short, int, long,
						  ubyte, ushort, uint, ulong, char, wchar, dchar))
	{
		static assert(UsageOf!T == T.sizeof);
	}

	struct S { int x, y; }
	static assert(UsageOf!S == S.sizeof);

	foreach (T; AliasSeq!(byte, short, int, long))
	{
		static assert(is(UsageOf!(T[]) ==
						 Linear1D!(size_t, T.sizeof)));
	}
}
