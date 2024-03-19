/** Extensions to std.algorithm.searching.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.searching_ex;

/** This function returns the index of the `value` if it exist among `values`,
	`size_t.max` otherwise.

	TODO: Should we extend to isRandomAccessRange support? In that case we don't
	get static array support by default.
*/
size_t binarySearch(R, E)(const R[] values, in E value)
	if (is(typeof(values[0].init == E.init))) /+ TODO: SortedRange support +/
{
	// value is not in the array if the array is empty
	if (values.length == 0) { return typeof(return).max; }

	immutable mid = values.length / 2; // mid offset
	if (value == values[mid])
		return mid; // direct hit
	else if (value < values[mid])
		return binarySearch(values[0 .. mid], value); // recurse left
	else
	{
		const index = binarySearch(values[mid + 1 .. $], value); // recurse right
		if (index != typeof(return).max)
			return index + mid + 1; // adjust the index; it is 0-based in the right-hand side slice.
		return index;
	}
}

///
pure nothrow @safe @nogc unittest {
	const int[9] x = [1, 3, 5, 6, 8, 9, 10, 13, 15];
	assert(x.binarySearch(0) == size_t.max);
	assert(x.binarySearch(1) == 0);
	assert(x.binarySearch(2) == size_t.max);
	assert(x.binarySearch(3) == 1);
	assert(x.binarySearch(4) == size_t.max);
	assert(x.binarySearch(5) == 2);
	assert(x.binarySearch(6) == 3);
	assert(x.binarySearch(7) == size_t.max);
	assert(x.binarySearch(8) == 4);
	assert(x.binarySearch(9) == 5);
	assert(x.binarySearch(10) == 6);
	assert(x.binarySearch(11) == size_t.max);
	assert(x.binarySearch(12) == size_t.max);
	assert(x.binarySearch(13) == 7);
	assert(x.binarySearch(14) == size_t.max);
	assert(x.binarySearch(15) == 8);
}

import std.range : ElementType, SearchPolicy, SortedRange;

/** Same as `range.contains()` but also outputs `index` where last occurrence of
	`key` is either currently stored (if `true` is returned) or should be stored
	(if `false` is returned) in order to preserve sortedness of `range`.

	The elements of `range` are assumed to be sorted in default (ascending)
	order.

	TODO: Move to member of `SortedRange` either as a new name or as an
	`contains`-overload take an extra `index` as argument.
 */
bool containsStoreIndex(SearchPolicy sp = SearchPolicy.binarySearch, R, V)
					   (R range, V value, out size_t index)
	if (is(typeof(ElementType!R.init == V.init)) &&
		is(R == SortedRange!(_), _)) /+ TODO: check for comparsion function +/
{
	/+ TODO: should we optimize for this case? +/
	// if (range.empty)
	// {
	//	 index = 0;
	//	 return false;		   // no hit
	// }
	index = range.length - range.upperBound!sp(value).length; // always larger than zero
	if (index >= 1 && range[index - 1] == value)
	{
		--index;							 // make index point to last occurrence of `value`
		assert(range.contains(value)); // assert same behaviour as existing contains
		return true;
	}
	assert(!range.contains(value)); // assert same behaviour as existing contains
	return false;
}

///
pure nothrow @safe @nogc unittest {
	const int[0] x;
	size_t index;
	import std.range : assumeSorted;
	assert(!x[].assumeSorted.containsStoreIndex(int.min, index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(-1,	  index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(0,	   index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(1,	   index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(int.max, index) && index == 0);
}

///
pure nothrow @safe @nogc unittest {
	const int[2] x = [1, 3];
	size_t index;
	import std.range : assumeSorted;
	assert(!x[].assumeSorted.containsStoreIndex(int.min, index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(-1,	  index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(0,	   index) && index == 0);
	assert( x[].assumeSorted.containsStoreIndex(1,	   index) && index == 0);
	assert(!x[].assumeSorted.containsStoreIndex(2,	   index) && index == 1);
	assert( x[].assumeSorted.containsStoreIndex(3,	   index) && index == 1);
	assert(!x[].assumeSorted.containsStoreIndex(4,	   index) && index == 2);
	assert(!x[].assumeSorted.containsStoreIndex(5,	   index) && index == 2);
	assert(!x[].assumeSorted.containsStoreIndex(int.max, index) && index == 2);
}
