/** Helpers used by containers.
 */
module nxt.container.common;

/** Flag for use of dynamic version of Rust-style ownership-and borrowing.
 */
enum BorrowCheckFlag : ubyte { no, yes }

/** Flag that a container is grow-only, that doesn’t support any removals of elements.
 */
enum GrowOnlyFlag : ubyte { no, yes }

/** Growth strategy.
 */
enum GrowthStrategy {
	grow_2,						// 2.0
	grow_3over2,				// 1.5
}

/** Reserve room for `extra` more elements in `x`.
 */
size_t reserveWithGrowth(GrowthStrategy gs, T)(ref T x, size_t extra)
if (is(typeof(T.init.capacity) : size_t) &&
	is(typeof(x.reserve(size_t.init)) == size_t)) {
	const newCapacity = x.capacity + extra;
	static	  if (gs == GrowthStrategy.grow_2)
		return x.reserve(newCapacity);
	else static if (gs == GrowthStrategy.grow_3over2)
		return x.reserve(newCapacity);
	else
		static assert(0, "Unknown growth strategy " ~ gs.stringof);
}

pure nothrow @safe unittest {
	int[] x;
	x.reserve(2);
	x.reserveWithGrowth!(GrowthStrategy.grow_2)(1);
	assert(x.capacity >= 3);
}

/** Try to pop first occurrence of `needle` in `haystack` (if any).
	Returns: `true` iff pop was made, `false` otherwise.
 */
bool popFirstMaybe(alias pred = "a == b", C, E)(ref C haystack, in E needle)
if (__traits(hasMember, C, "length") &&
	__traits(hasMember, C, "popAt"))
	/+ TODO: activate this restriction +/
	// if (hasSlicing!C &&
	//	 is(ElementType!C == E.init))
{
	import std.functional : binaryFun;
	// doesn't work for uncopyable element types: import std.algorithm.searching : countUntil;
	size_t offset = 0;
	foreach (const ref e; haystack[]) {
		if (binaryFun!pred(e, needle))
			break;
		offset += 1;
	}
	if (offset != haystack.length) {
		haystack.popAt(offset);
		return true;
	}
	return false;
}

/** Remove element at index `index` in `r`.
 *
 * TODO: reuse in array*.d
 * TODO: better name removeAt
 */
void shiftToFrontAt(T)(T[] r, size_t index) @trusted
{
	assert(index + 1 <= r.length);

	/+ TODO: use this instead: +/
	// immutable si = index + 1;   // source index
	// immutable ti = index;	   // target index
	// immutable restLength = this.length - (index + 1);
	// moveEmplaceAll(_store.ptr[si .. si + restLength],
	//				_store.ptr[ti .. ti + restLength]);

	// for each element index that needs to be moved
	foreach (immutable i; 0 .. r.length - (index + 1)) {
		immutable si = index + i + 1; // source index
		immutable ti = index + i;	 // target index
		import core.lifetime : moveEmplace;
		moveEmplace(r.ptr[si], /+ TODO: remove when compiler does this +/
					r.ptr[ti]);
	}
}

pure nothrow @safe @nogc unittest {
	int[4] x = [11, 12, 13, 14];
	x[].shiftToFrontAt(1);
	assert(x == [11, 13, 14, 14]);
}
