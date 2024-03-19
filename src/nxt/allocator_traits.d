/** Extra traits for `std.experimental.allocator`;
 */
module nxt.allocator_traits;

/** Is `true` iff `T` is an allocator, otherwise `false`.
 *
 * Only members and `alignment` and `allocate` are required.
 *
 * See_Also: https://dlang.org/phobos/std_experimental_allocator_building_blocks.html
 * See_Also: https://forum.dlang.org/post/uiavxptceyxsjulkxlec@forum.dlang.org
 */
public import std.experimental.allocator.common : isAllocator;

/** State of an allocator or pointer to an allocator.
 *
 * State is zero for `Mallocator`, `GCAllocator`, and `MMapAllocator` and
 * typically non-zero for the other.
 *
 * EMSI containers has this state as their first field.
 *
 * TODO: Move to Phobos and put beside
 * std.experimental.allocator.common.stateSize.
 */
mixin template AllocatorState(Allocator) /+ TODO: add string fieldName parameter +/
if (isAllocator!Allocator ||
	isAllocator!(typeof(*Allocator.init))) {
	private import std.experimental.allocator.common : stateSize;
	static if (stateSize!Allocator == 0)
		alias allocator = Allocator.instance;
	else
		Allocator allocator;
}

version (unittest) {
	pure nothrow @safe @nogc unittest
	{
		mixin AllocatorState!NullAllocator n;
		mixin AllocatorState!GCAllocator g;
		mixin AllocatorState!Mallocator m;
		mixin AllocatorState!MmapAllocator p;
		mixin AllocatorState!(MmapAllocator*) pi;
	}
}

version (unittest) {
	import std.experimental.allocator.building_blocks.null_allocator : NullAllocator;
	import std.experimental.allocator.mallocator : Mallocator;
	import std.experimental.allocator.gc_allocator : GCAllocator;
	import std.experimental.allocator.mmap_allocator : MmapAllocator;
}
