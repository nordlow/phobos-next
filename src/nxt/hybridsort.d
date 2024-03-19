module nxt.hybridsort;

import nxt.bijections : IntegralBijectableTypes;

static immutable size_t[IntegralBijectableTypes.length] radixSortMinLength;

shared static this()
{
	foreach (i, E; IntegralBijectableTypes)
	{
		/+ TODO: Calculate radixSortMinLength for E +/
		radixSortMinLength[i] = 0; // calulate limit
	}
}

import std.range.primitives : isRandomAccessRange;

/** Perform either radix or standard sort depending on `ElementType` of `Range`.
 */
auto hybridSort(alias less = "a < b", Range)(Range r)
if (isRandomAccessRange!Range)
{
	import std.range.primitives : ElementType;
	import std.traits : isNumeric;
	static if (isNumeric!(ElementType!Range))
	{
		import nxt.integer_sorting : radixSort;
		return radixSort(r);
	}
	else
	{
		import std.algorithm.sorting : sort;
		return sort!less(r);
	}
}

///
unittest {
	import std.meta : AliasSeq;
	const n = 10_000;
	foreach (ix, T; AliasSeq!(byte, short))
	{
		import std.container : Array;
		import std.algorithm : isSorted, swap;
		import nxt.random_ex : randInPlace;

		auto a = Array!T();
		a.length = n;

		randInPlace(a[]);

		auto b = a.dup;

		hybridSort(a[]);
		assert(a[].isSorted);

		import std.algorithm.sorting : sort;
		sort(b[]);
		assert(b[].isSorted);

		assert(a == b);

		swap(a, b);
	}
}
