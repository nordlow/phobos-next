/** Extensions to skipOver.
 *
 * See_Also: https://forum.dlang.org/post/tswdobtabsjarszfkmbt@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/ybamybeakxwxwleebnwb@forum.dlang.org
 */
module nxt.skip_ex;

import std.functional : binaryFun;
import std.range.primitives : front, back, save, empty, popBack, hasSlicing, isBidirectionalRange, ElementType;

version (unittest)
{
	import nxt.array_help : s;
}

/** Skip over the ending portion of `haystack` that matches `needle`, or nothing upon no match.
 *
 * See_Also: std.algorithm.searching.skipOver.
 */
bool skipOverBack(Haystack, Needle)(scope ref Haystack haystack,
									scope Needle needle) // non`const` because may be range with mutable range primitives
if (isBidirectionalRange!Haystack &&
	isBidirectionalRange!Needle &&
	is(typeof(haystack.back == needle.back)))
{
	static if (is(typeof(haystack[] == needle) : bool) &&
			   is(typeof(needle.length > haystack.length) : bool) &&
			   is(typeof(haystack = haystack[])))
	{
		if (haystack.length >= needle.length &&
			haystack[$ - needle.length .. $] == needle)
		{
			haystack = haystack[0 .. haystack.length - needle.length];
			return true;
		}
		return false;
	}
	else
	{
		return skipOverBack!((a, b) => a == b)(haystack, needle);
	}
}

///
bool skipOverBack(alias pred, Haystack, Needle)(scope ref Haystack haystack,
												scope Needle needle) // non`const` because may be range with mutable range primitives
if (isBidirectionalRange!Haystack &&
	isBidirectionalRange!Needle &&
	is(typeof(binaryFun!pred(haystack.back, needle.back)))) /+ TODO: Needle doesn't have to bi-directional if Haystack is RandomAccess and Needle.hasLength +/
{
	import std.range.primitives : hasLength;
	static if (hasLength!Haystack && hasLength!Needle)
	{
		if (haystack.length < needle.length) { return false; } // fast discardal
	}
	auto r = haystack.save;
	while (!needle.empty &&
		   !r.empty &&
		   binaryFun!pred(r.back, needle.back))
	{
		r.popBack();
		needle.popBack();
	}
	if (needle.empty)
	{
		haystack = r;
	}
	return needle.empty;
}

///
pure nothrow @safe @nogc unittest {
	auto s1_ = [1, 2, 3].s;
	auto s1 = s1_[];
	const s2_ = [2, 3].s;
	const s2 = s2_[];
	s1.skipOverBack(s2);
	assert(s1 == [1].s);
	s1.skipOverBack(s2);		// no effect
	assert(s1 == [1].s);
}

pure nothrow @safe @nogc unittest {
	import std.algorithm : equal;
	auto s1 = "Hello world";
	assert(!skipOverBack(s1, "Ha"));
	assert(s1 == "Hello world");
	assert(skipOverBack(s1, "world") && s1 == "Hello ");
}

/** Variadic version of $(D skipOver).
 *
 * Returns: index + 1 into matching $(D needles), 0 otherwise.
 *
 * TODO: Reuse `skipOver with many needles` or write own array-version of `skipOver` that's faster.
 */
size_t skipOverAmong(alias pred = "a == b", Range, Ranges...)(scope ref Range haystack,
															   scope Ranges needles)
if (Ranges.length >= 2)
{
	import nxt.array_traits : isSameSlices;
	foreach (const index, const ref needle; needles)
	{
		static if (pred == "a == b" &&
				   isSameSlices!(Range, Ranges)) // fast
		{
			// `nothrow` char[] fast path
			if (haystack.length >= needle.length &&
				haystack[0 .. needle.length] == needle) /+ TODO: `haystack.ptr` +/
			{
				haystack = haystack[needle.length .. haystack.length]; /+ TODO: `haystack.ptr` +/
				return index + 1;
			}
		}
		else
		{
			import std.algorithm.searching : skipOver;
			if (haystack.skipOver(needle)) /+ TODO: nothrow +/
				return index + 1;
		}
	}
	return 0;
}

@safe pure nothrow /* TODO: nothrow @nogc */ unittest {
	import std.algorithm.searching : startsWith;
	auto x = "beta version";
	assert(x.startsWith("beta"));
}

@safe pure /* TODO: nothrow @nogc */ unittest {
	import std.algorithm.searching : skipOver;
	auto x = "beta version";
	assert(x.skipOver("beta"));
	assert(x == " version");
}

pure nothrow @safe @nogc unittest {
	auto x = "beta version";
	assert(x.skipOverAmong("beta", "be") == 1);
	assert(x == " version");
}

pure nothrow @safe @nogc unittest {
	auto x = "beta version";
	assert(x.skipOverAmong("be", "_") == 1);
}

pure nothrow @safe @nogc unittest {
	auto x = "beta version";
	assert(x.skipOverAmong("x", "y") == 0);
}

pure nothrow @safe @nogc unittest {

	auto x = "beta version";
	assert(x.skipOverAmong("x", "y") == 0);
}

/** Skip Over Shortest Matching prefix in $(D needles) that prefixes $(D haystack).
 *
 * TODO: Make return value a specific type that has bool conversion so we can
 * call it as
 * if (auto hit = r.skipOverShortestOf(...)) { ... }
 */
size_t skipOverShortestOf(alias pred = "a == b",
						  Range,
						  Ranges...)(scope ref Range haystack,
									 scope Ranges needles)
if (Ranges.length >= 2)
{
	import std.algorithm.searching : startsWith;
	const hit = startsWith!pred(haystack, needles);
	if (hit)
	{
		// get needle lengths
		size_t[needles.length] lengths;
		foreach (const index, ref needle; needles)
		{
			import std.traits : isSomeString, isSomeChar;
			import std.range.primitives : ElementType;
			import core.internal.traits : Unqual;

			alias Needle = Unqual!(typeof(needle));

			static if (is(Unqual!Range ==
						  Needle))
			{
				lengths[index] = needle.length;
			}
			else static if (is(Unqual!(ElementType!Range) ==
							   Unqual!(ElementType!Needle)))
			{
				lengths[index] = needle.length;
			}
			else static if (isSomeString!Range &&
							isSomeString!Needle)
			{
				lengths[index] = needle.length;
			}
			else static if (isSomeChar!(ElementType!Range) &&
							isSomeChar!Needle)
			{
				lengths[index] = 1;
			}
			else static if (is(Unqual!(ElementType!Range) ==
							   Needle))
			{
				lengths[index] = 1;
			}
			else
			{
				static assert(0,
							  "Cannot handle needle of type " ~ Needle.stringof ~
							  " when haystack has ElementType " ~ (ElementType!Range).stringof);
			}
		}

		import std.range: popFrontN;
		haystack.popFrontN(lengths[hit - 1]);
	}

	return hit;

}

pure @safe unittest {
	auto x = "beta version";
	assert(x.skipOverShortestOf("beta", "be") == 2);
	assert(x == "ta version");
}

pure @safe unittest {
	auto x = "beta version";
	assert(x.skipOverShortestOf("be", "beta") == 1);
	assert(x == "ta version");
}

pure @safe unittest {
	auto x = "beta version";
	assert(x.skipOverShortestOf('b', "be", "beta") == 1);
	assert(x == "eta version");
}

/** Skip Over Longest Matching prefix in $(D needles) that prefixes $(D haystack).
 */
SkipOverLongest skipOverLongestOf(alias pred = "a == b", Range, Ranges...)(scope ref Range haystack,
																		   scope Ranges needles)
{
	/+ TODO: figure out which needles that are prefixes of other needles by first +/
	// sorting them and then use some adjacent filtering algorithm
	static assert(0, "TODO: implement");
}

/** Skip Over Back Shortest Match of `needles` in `haystack`. */
size_t skipOverBackShortestOf(alias pred = "a == b", Range, Ranges...)(scope ref Range haystack,
																	   scope Ranges needles) @trusted
/+ TODO: We cannot prove that cast(ubyte[]) of a type that have no directions is safe +/
if (Ranges.length >= 2)
{
	import std.range: retro, ElementType;
	import std.traits: hasIndirections;
	import core.internal.traits : Unqual;
	import std.meta: staticMap, AliasSeq;
	// import nxt.traits_ex: allSame;

	static if ((!hasIndirections!(ElementType!Range))/*  && */
			   /* allSame!(Unqual!Range, staticMap!(Unqual, Ranges)) */)
	{
		auto retroHaystack = (cast(ubyte[])haystack).retro;

		alias Retro(Range) = typeof((ubyte[]).init.retro);
		AliasSeq!(staticMap!(Retro, Ranges)) retroNeedles;
		foreach (const index, const ref needle; needles)
		{
			retroNeedles[index] = (cast(ubyte[])needle).retro;
		}

		const retroHit = retroHaystack.skipOverShortestOf(retroNeedles);
		haystack = haystack[0.. $ - (haystack.length - retroHaystack.length)];

		return retroHit;
	}
	else
	{
		static assert(0, "Unsupported combination of haystack type " ~ Range.stringof ~
					  " with needle types " ~ Ranges.stringof);
	}
}

pure nothrow @safe @nogc unittest {
	auto x = "alpha_beta";
	assert(x.skipOverBackShortestOf("x", "beta") == 2);
	assert(x == "alpha_");
}

pure nothrow @safe @nogc unittest {
	auto x = "alpha_beta";
	assert(x.skipOverBackShortestOf("a", "beta") == 1);
	assert(x == "alpha_bet");
}

/** Drop $(D prefixes) in $(D s).
 *
 * TODO: Use multi-argument skipOver when it becomes available
 * http://forum.dlang.org/thread/bug-12335-3@https.d.puremagic.com%2Fissues%2F
*/
void skipOverPrefixes(R, A)(scope ref R s,
							const scope A prefixes)
{
	import std.algorithm.searching : skipOver;
	foreach (prefix; prefixes)
	{
		if (s.length > prefix.length &&
			s.skipOver(prefix))
		{
			break;
		}
	}
}

/** Drop $(D suffixes) in $(D s).
 */
void skipOverSuffixes(R, A)(scope ref R s,
							const scope A suffixes)
{
	foreach (suffix; suffixes)
	{
		if (s.length > suffix.length &&
			s.endsWith(suffix))
		{
			s = s[0 .. $ - suffix.length]; /+ TODO: .ptr +/
			break;
		}
	}
}

/** Drop either both prefix `frontPrefix` and suffix `backSuffix` or do nothing.
 *
 * Returns: `true` upon drop, `false` otherwise.
 */
bool skipOverFrontAndBack(alias pred = "a == b", R, E, F)(scope ref R r,
														  scope E frontPrefix,
														  scope F backSuffix)
if (isBidirectionalRange!R &&
	is(typeof(binaryFun!pred(ElementType!R.init, E.init))) &&
	is(typeof(binaryFun!pred(ElementType!R.init, F.init))))
{
	import core.internal.traits : Unqual;
	import std.traits : isArray;
	static if (isArray!R &&
			   is(Unqual!(typeof(R.init[0])) == E)) // for instance if `R` is `string` and `E` is `char`
	{
		if (r.length >= 2 &&
			r[0] == frontPrefix &&
			r[$ - 1] == backSuffix)
		{
			r = r[1 .. $ - 1];
			return true;
		}
	}
	else
	{
		if (r.length >= 2 && /+ TODO: express this requirement in `r` as `hasLength` +/
			binaryFun!pred(r.front, frontPrefix) &&
			binaryFun!pred(r.back, backSuffix))
		{
			import std.range.primitives : popBack, popFront;
			r.popFront();
			r.popBack();
			return true;
		}
	}
	return false;
}

pure nothrow @safe @nogc unittest {
	auto expr = `"alpha"`;
	assert(expr.skipOverFrontAndBack('"', '"'));
	assert(expr == `alpha`);
}

pure nothrow @safe @nogc unittest {
	auto expr_ = `"alpha"`;
	auto expr = expr_;
	assert(!expr.skipOverFrontAndBack(',', '"'));
	assert(expr == expr_);
}

pure nothrow @safe @nogc unittest {
	auto expr_ = `"alpha`;
	auto expr = expr_;
	assert(!expr.skipOverFrontAndBack('"', '"'));
	assert(expr == expr_);
}

pure nothrow @safe @nogc unittest {
	auto expr_ = `alpha"`;
	auto expr = expr_;
	assert(!expr.skipOverFrontAndBack('"', '"'));
	assert(expr == expr_);
}
