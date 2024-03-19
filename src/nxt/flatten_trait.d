module nxt.flatten_trait;

/** Is `true` iff a list of types, which are composed of ranges and non ranges,
 * share a common type after flattening the ranges (i.e. `ElementType`)
 *
 * This basically answers the question: $(I Can I combine these ranges and
 * values into a single range of a common type?).
 *
 * See_Also: `meta_ex.FlattenedRanges`
 */
template areFlatteninglyCombinable(Values...)
{
	import std.traits : CommonType;
	import nxt.meta_ex : FlattenedRanges;
	enum areFlatteninglyCombinable = !is(CommonType!(FlattenedRanges!Values) == void);
}

///
unittest {
	static assert(areFlatteninglyCombinable!(int, int, int));
	static assert(areFlatteninglyCombinable!(float[], int, char[]));
	static assert(areFlatteninglyCombinable!(string, int, int));

	// Works with string because:
	import std.traits : CommonType;
	import std.range.primitives : ElementType;

	static assert(is(CommonType!(ElementType!string, int) == uint));

	struct A
	{
	}

	static assert(!areFlatteninglyCombinable!(A, int, int));
	static assert(!areFlatteninglyCombinable!(A[], int[]));
	static assert( areFlatteninglyCombinable!(A[], A[]));
	static assert( areFlatteninglyCombinable!(A[], A[], A));
	static assert(!areFlatteninglyCombinable!(int[], A));
}
