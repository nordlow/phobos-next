/** Hybrid array containers.
 */
module nxt.hybrid_array;

import std.traits : isIntegral;
import nxt.filters : isDynamicDenseSetFilterable;
import std.experimental.allocator.mallocator : Mallocator;

/** Hybrid container combining `DynamicDenseSetFilter` growable into `DynamicArray`.
 *
 * Has O(1) unordered element access via slicing.
 *
 * For use in graph algorithms with limited index ranges.
 *
 * TODO: better name?
 */
struct DynamicDenseSetFilterGrowableArray(E, Allocator = Mallocator)
if (isDynamicDenseSetFilterable!E) {
	import nxt.filters : DynamicDenseSetFilter, Growable, Copyable;
	import nxt.container.dynamic_array : DynamicArray;

	alias ElementType = E;

	this(this) @disable;

	pragma(inline, true):

	/** Insert element `e`.
		Returns: precense status of element before insertion.
	*/
	bool insert()(E e) /*tlm*/ {
		/+ TODO: this doesn’t seem right: +/
		const hit = _set.insert(e);
		if (!hit)
			_array.insertBack(e);
		return hit;
	}
	alias put = insert;		 // OutputRange compatibility

	/// Check if element `e` is stored/contained.
	bool contains()(E e) const => _set.contains(e); /*tlm*/
	/// ditto
	bool opBinaryRight(string op)(E e) const if (op == "in") => contains(e);

	/// Get length.
	@property size_t length() const => _array.length;

	/// Non-mutable slicing.
	auto opSlice() const => _array.opSlice; /*tlm*/

	/// Clear contents.
	void clear()() /*tlm*/ {
		_set.clear();
		_array.clear();
	}

private:
	/+ TODO: merge into store with only one length and capcity +/
	DynamicDenseSetFilter!(E, Growable.yes, Copyable.no) _set;
	DynamicArray!(E, Allocator) _array;
}

pure nothrow @safe @nogc:

unittest {
	DynamicDenseSetFilterGrowableArray!uint x;

	assert(!x.insert(42));
	assert(x.contains(42));
	assert(x[] == [42].s);

	assert(x.insert(42));
	assert(x.contains(42));
	assert(x[] == [42].s);

	assert(!x.insert(43));
	assert(x.contains(43));
	assert(x[] == [42, 43].s);

	x.clear();
	assert(x.length == 0);

	assert(!x.insert(44));
	assert(x.contains(44));
	assert(x[] == [44].s);
}

version (unittest) {
	import nxt.array_help : s;
}
