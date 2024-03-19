module nxt.overlapping;

pure nothrow @safe @nogc:

/** Returns: Slice Overlap of $(D a) and $(D b) in order given by arguments.
 */
inout(T)[] overlapsInOrder(T)(inout(T)[] a,
							  inout(T)[] b)
	@trusted pure nothrow @nogc
{
	if (a.ptr <= b.ptr &&	   // if a-start lies at or before b-start
		b.ptr < a.ptr + a.length) // if b-start lies before b-end
	{
		import std.algorithm: min, max;
		immutable low = max(a.ptr, b.ptr) - a.ptr;
		const n = min(b.length,
					  (b.ptr - a.ptr + 1)); // overlap length
		return a[low..low + n];
	}
	else
	{
		return [];
	}
}

/** Helper for overlap().
	Copied from std.array with simplified return expression.
 */
bool overlaps(T)(in T[] r1,
				 in T[] r2)
	@trusted pure nothrow @nogc
{
	alias U = inout(T);
	static U* max(U* a, U* b) nothrow { return a > b ? a : b; }
	static U* min(U* a, U* b) nothrow { return a < b ? a : b; }

	auto b = max(r1.ptr, r2.ptr);
	auto e = min(r1.ptr + r1.length,
				 r2.ptr + r2.length);
	return b < e;
}

///
unittest {
	auto x = [-11_111, 11, 22, 333_333].s;
	const y = [-22_222, 441, 555, 66].s;

	assert(!overlaps(x, y));
	assert(!overlaps(y, x));

	auto x01 = x[0..1];
	auto x12 = x[1..2];
	auto x23 = x[2..3];

	assert(overlaps(x, x12));
	assert(overlaps(x, x01));
	assert(overlaps(x, x23));
	assert(overlaps(x01, x));
	assert(overlaps(x12, x));
	assert(overlaps(x23, x));
}

/** Returns: Slice Overlap of $(D a) and $(D b) in any order.
	Deprecated by: std.array.overlap
 */
inout(T[]) overlap(T)(inout(T[]) a,
					  inout(T[]) b) /* @safe pure nothrow */
	pure nothrow @safe @nogc
{
	if (inout(T[]) ab = overlapsInOrder(a, b))
	{
		return ab;
	}
	else if (inout(T[]) ba = overlapsInOrder(b, a))
	{
		return ba;
	}
	else
	{
		return [];
	}
}

///
unittest {
	auto x = [-11_111, 11, 22, 333_333].s;
	const y = [-22_222, 441, 555, 66].s;

	assert(!overlap(x, y));
	assert(!overlap(y, x));

	auto x01 = x[0..1];
	auto x12 = x[1..2];
	auto x23 = x[2..3];

	// sub-ranges should overlap completely
	assert(overlap(x, x12) == x12);
	assert(overlap(x, x01) == x01);
	assert(overlap(x, x23) == x23);
	// and commutate f(a,b) == f(b,a)
	assert(overlap(x01, x) == x01);
	assert(overlap(x12, x) == x12);
	assert(overlap(x23, x) == x23);
}

version (unittest)
{
	import nxt.array_help : s;
}
