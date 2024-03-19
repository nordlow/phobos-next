/** Cyclic array-like container.
 *
 * See_Also: https://en.wikipedia.org/wiki/Sorted_array
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -preview=in -debug -g -unittest -checkaction=context -allinst -main -unittest -I../.. -i -run cyclic.d
 */
module nxt.container.cyclic;

import std.algorithm.comparison : max;

private enum PAGESIZE = 4096;	// Linux $(shell getconf PAGESIZE)

/** Cyclic array-like container.
 *
 * Set `capacity_` to `size_t.max` for array with dynamic length.
 *
 * TODO: replace PAGESIZE / T.sizeof with standard logic and Allocator
 * TODO: replace throw staticError!CyclicRangeError with onRangeError
 *
 * See_Also: `nxt.container.sorted.Sorted`.
 */
struct CyclicArray(T, size_t capacity_ = max(8, PAGESIZE / T.sizeof)) {
	import core.internal.traits : hasElaborateDestructor;
	import std.traits : isMutable;
	import std.range.primitives;
	/+ TODO: Make the child container type a template parameter and remove this import: +/
	import std.container.array : Array;
	import nxt.container.traits : mustAddGCRange;

	alias capacity = capacity_; // for public use
	enum isDynamic = capacity == capacity.max;

private:
	static if (capacity >= capacity.max) {
		private size_t reserve(size_t length) nothrow @nogc
		{
			assert(length > 0);
			array.length = length;
			return length;
		}
		Array!T array;
	}
	else
		T[capacity] array;
	size_t start;
	size_t size;

public:
	static if (isDynamic) {
		invariant { assert(array.length > 0); }

		// @disable this(); /+ TODO: this triggers bug in dmd: https://issues.dlang.org/show_bug.cgi?id=20934 +/

		this(Array!T array) @nogc
		{
			assert(array.length > 0);
			this.array = array;
		}

		this(size_t length) @nogc
		{
			assert(length > 0);
			array = Array!T();
			reserve(length);
		}

		this(size_t n)(T[n] val) {
			array = Array!T();
			reserve(max(8, PAGESIZE / T.sizeof));
			static if (capacity != 0)
				static assert(n <= capacity);
			foreach (const ref v; val) {
				put(v);
			}
		}

		this(Range)(Range val)
		if (__traits(compiles, ElementType!Range) && is(ElementType!Range : T)) {
			array = Array!T();
			reserve(max(8, PAGESIZE / T.sizeof));
			foreach (const ref v; val)
				put(v);
		}

		this(Args...)(Args val) {
			array = Array!T();
			reserve(max(8, PAGESIZE / T.sizeof));
			foreach (const ref v; val)
				put(v);
		}
	}
	else
	{
		this(size_t n)(T[n] val) {
			static if (!isDynamic)
				static assert(n <= capacity_);
			foreach (ref v; val)
				put(v);
		}

		this(Range)(Range val)
			if (__traits(compiles, ElementType!Range) && is(ElementType!Range : T)) {
			foreach (const ref v; val)
				put(v);
		}

		this(Args...)(Args val) {
			foreach (ref v; val)
				put(v);
		}
	}

	mixin CyclicRangePrimitives!(T, q{
			static if (capacity_ == size_t.max)
				auto copy = typeof(cast() this)(array.length);
			else
				typeof(cast() this) copy;
	});

	static if (!isDynamic)
		CyclicRange!T byRef() @property @nogc @safe => typeof(return)(array[], start, size);

	size_t length() const @property @nogc @safe => size;

	size_t length(size_t val) @property
	{
		if (size > array.length)
			assert(false);
		if (val == 0) {
			clear();
			return size;
		}
		if (val > size)
			foreach (const i; size .. val)
				array[(start + i) % array.length] = T.init;
		else if (val < size) {
			static if (hasElaborateDestructor!T)
				foreach (const i; val .. size)
					destroy(array[(start + i) % array.length]);
			else static if (mustAddGCRange!T)
				foreach (const i; val .. size)
					array[(start + i) % array.length] = T.init; // avoid GC mark-phase dereference
		}
		return size = val;
	}

	void clear() {
		static if (hasElaborateDestructor!T)
			foreach (const i; 0 .. size)
				destroy(array[(start + i) % array.length]);
		start = 0; // optimize clears
		size = 0;
	}

	auto opBinary(string op : "~")(T rhs) const
	{
		auto copy = this.dup;
		copy.put(rhs);
		return copy;
	}

	auto opBinary(string op : "~", size_t n)(T[n] rhs) const
	{
		auto copy = this.dup;
		copy ~= rhs;
		return copy;
	}

	auto opBinary(string op : "~", Range)(Range rhs) const
		if (isInputRange!Range && is(ElementType!Range : T)) {
			auto copy = this.dup;
			copy ~= rhs;
			return copy;
		}

	void opOpAssign(string op : "~")(T rhs) {
		put(rhs);
	}

	void opOpAssign(string op : "~", size_t n)(T[n] rhs) {
		foreach (const ref c; rhs)
			put(c);
	}

	void opOpAssign(string op : "~", size_t n)(CyclicArray!(T, n) rhs) {
		foreach (const i; 0 .. rhs.size)
			put(rhs.array[(rhs.start + i) % rhs.array.length]);
	}

	void opOpAssign(string op : "~", Range)(Range rhs)
		if (__traits(compiles, ElementType!Range) && is(ElementType!Range : T)) {
		foreach (const ref c; rhs)
			put(c);
	}

	static if (capacity_ == size_t.max) {
		CyclicArray!(T, capacity_) dup() const
		{
			auto ret = CyclicArray!(T, capacity_)(array);
			ret.start = start;
			ret.size = size;
			return ret;
		}
	}
	else
	{
		CyclicArray!(T, capacity_) dup() const
		{
			CyclicArray!(T, capacity_) ret;
			ret.array = cast(typeof(ret.array)) array;
			ret.start = start;
			ret.size = size;
			return ret;
		}
	}

	static if (!isDynamic) {
		int opApply(int delegate(ref T) @nogc dg) @nogc
		{
			int result = 0;
			foreach (const i; 0 .. size) {
				result = dg(array[(i + start) % array.length]);
				if (result)
					break;
			}
			return result;
		}

		int opApply(int delegate(size_t, ref T) @nogc dg) @nogc
		{
			int result = 0;
			foreach (const i; 0 .. size) {
				result = dg(i, array[(i + start) % array.length]);
				if (result)
					break;
			}
			return result;
		}
	}

	bool opEquals(in CyclicArray!(T, capacity_) b) {
		if (size != b.size)
			return false;
		foreach (const i; 0 .. size)
			if (array[(i + start) % array.length] !=
				b.array[(i + b.start) % b.array.length])
				return false;
		return true;
	}

	bool opEquals(size_t n)(T[n] b) {
		if (size != n)
			return false;
		foreach (const i; 0 .. size)
			if (array[(i + start) % array.length] != b[i])
				return false;
		return true;
	}

	bool opEquals(Range)(Range b) if (hasLength!Range && is(ElementType!Range : T)) {
		if (size != b.length)
			return false;
		auto r = b.save;
		foreach (const i; 0 .. size) {
			if (array[(i + start) % array.length] != r.front)
				return false;
			r.popFront();
		}
		return true;
	}
}

struct CyclicRange(T) {
	T[] array;
	size_t start, size;
	mixin CyclicRangePrimitives!T;
	CyclicRange!T dup() const => cast(CyclicRange!T) this;
}

private mixin template CyclicRangePrimitives(T, string makeCopy = "typeof(cast() this) copy;") {
	import core.internal.traits : hasElaborateDestructor;
	import std.traits : isMutable;
	import nxt.container.traits : mustAddGCRange;

	size_t capacity() const @property @nogc @safe => array.length;
	size_t length() const @property @nogc @safe => size;

	void put()(auto ref T val) {
		if (size >= array.length)
			throw staticError!CyclicRangeError("array capacity overflow", __FILE__, __LINE__);
		array[(start + size) % array.length] = val;
		size++;
	}
	/// ditto
	void put()(const auto ref T val) {
		if (size >= array.length)
			throw staticError!CyclicRangeError("array capacity overflow", __FILE__, __LINE__);
		array[(start + size) % array.length] = val;
		size++;
	}
	/// ditto
	void put(size_t n)(T[n] rhs) {
		foreach (const ref c; rhs)
			put(c);
	}
	/// ditto
	void put(Range)(Range rhs)
		if (__traits(compiles, ElementType!Range) &&
			is(ElementType!Range : T)) {
		foreach (const ref c; rhs)
			put(c);
	}
	/// ditto
	alias opOpAssign(string op : "~") = put;
	alias insertBack = put;
	alias stableInsertBack = insertBack;

	void insertFront()(auto ref T val) {
		if (size >= array.length)
			throw staticError!CyclicRangeError("array capacity overflow", __FILE__, __LINE__);
		start = (start + array.length - 1) % array.length;
		array[start] = val;
		size++;
	}

	void popFront() {
		if (size == 0)
			throw staticError!CyclicRangeError("trying to pop an empty array", __FILE__, __LINE__);
		static if (hasElaborateDestructor!T)
			destroy(array[start]);
		else static if (mustAddGCRange!T)
			array[start] = T.init; // avoid GC mark-phase dereference
		start = (start + 1) % array.length;
		size--;
	}

	auto save() => this;

	bool empty() @nogc @safe @property const => size == 0;

	ref auto front() @nogc @safe @property inout
	{
		if (size == 0)
			throw staticError!CyclicRangeError("trying to call front on empty array",
											   __FILE__, __LINE__);
		return array[start];
	}

	void popBack() {
		if (size == 0)
			throw staticError!CyclicRangeError("trying to pop an empty array", __FILE__, __LINE__);
		size--;
		static if (hasElaborateDestructor!T)
			destroy(array[(start + size) % array.length]);
		else static if (mustAddGCRange!T)
			array[(start + size) % array.length] = T.init; // avoid GC mark-phase dereference
	}

	ref auto back() @property
	{
		if (size == 0)
			throw staticError!CyclicRangeError("trying to call back on empty array",
											   __FILE__, __LINE__);
		return array[(start + size - 1) % array.length];
	}

	auto back() @property const
	{
		if (size == 0)
			throw staticError!CyclicRangeError("trying to call back on empty array",
											   __FILE__, __LINE__);
		return array[(start + size - 1) % array.length];
	}

	size_t opDollar() @nogc @safe const => length;

	ref inout(T) opIndex(size_t v) inout
	{
		if (v >= size)
			throw staticError!CyclicRangeError("out of range", __FILE__, __LINE__);
		else
			return array[(v + start) % array.length];
	}

	auto opIndex() const => this.dup();

	private void validateRange(size_t[2] range) {
		const size_t from = range[0];
		const size_t to = range[1];
		if (to > size)
			throw staticError!CyclicRangeError("trying to slice over array size",
											   __FILE__, __LINE__);
		if (from > to)
			throw staticError!CyclicRangeError("trying to negative slice", __FILE__, __LINE__);
		if (from != to && from >= size || to - from > size)
			throw staticError!CyclicRangeError("trying to slice over array bounds",
											   __FILE__, __LINE__);
	}

	auto opIndex(size_t[2] range) {
		const size_t from = range[0];
		const size_t to = range[1];
		validateRange(range);

		mixin(makeCopy);
		copy.start = 0;
		copy.size = to - from;

		foreach (const i; 0 .. copy.size)
			copy.array[i] = array[(i + start + from) % array.length];
		return copy;
	}

	static if (isMutable!T) {
		void opIndexUnary(string op)() {
			foreach (const i; 0 .. size)
				mixin(op ~ "array[(i + start) % array.length];");
		}

		auto opIndexUnary(string op)(size_t i) {
			return mixin(op ~ "array[(i + start) % array.length]");
		}

		void opIndexUnary(string op)(size_t[2] range) {
			const size_t from = range[0];
			const size_t to = range[1];
			validateRange(range);

			foreach (const i; 0 .. to - from)
				mixin(op ~ "array[(i + start + from) % array.length];");
		}

		void opIndexAssign(U)(U val) {
			foreach (const i; 0 .. size)
				array[(i + start) % array.length] = val;
		}

		void opIndexAssign(U)(U val, size_t i) {
			opIndex(i) = val;
		}

		void opIndexAssign(U)(U val, size_t[2] range) {
			const size_t from = range[0];
			const size_t to = range[1];
			validateRange(range);

			foreach (const i; 0 .. to - from)
				array[(i + start + from) % array.length] = val;
		}

		void opIndexOpAssign(string op, U)(U val) {
			foreach (const i; 0 .. size)
				mixin("array[(i + start) % array.length] " ~ op ~ "= val;");
		}

		void opIndexOpAssign(string op, U)(U val, size_t i) {
			mixin("array[(i + start) % array.length] " ~ op ~ "= val;");
		}

		void opIndexOpAssign(string op, U)(U val, size_t[2] range) {
			const size_t from = range[0];
			const size_t to = range[1];
			validateRange(range);

			foreach (const i; 0 .. to - from)
				mixin("array[(i + start + from) % array.length] " ~ op ~ "= val;");
		}
	}

	static if (isMutable!T) {
		import std.algorithm.mutation : move;

		T moveFront() {
			if (size == 0)
				throw staticError!CyclicRangeError("trying to move in empty array",
												   __FILE__, __LINE__);
			return move(array[0]);
		}

		T moveBack() {
			if (size == 0)
				throw staticError!CyclicRangeError("trying to move in empty array",
												   __FILE__, __LINE__);
			return move(array[(start + size - 1) % array.length]);
		}

		T moveAt(size_t i) {
			if (i >= size)
				throw staticError!CyclicRangeError("trying to move outside range",
												   __FILE__, __LINE__);
			return move(array[(start + i) % array.length]);
		}
	}

	size_t[2] opSlice(size_t i : 0)() const => [0, size];
	size_t[2] opSlice(size_t i : 0)(size_t from, size_t to) const => [from, to];

	/**
	 * Removes the last element from the array and returns it.
	 * Both stable and non-stable versions behave the same and guarantee
	 * that ranges iterating over the array are never invalidated.
	 *
	 * Precondition: `empty == false`
	 *
	 * Returns: The element removed.
	 *
	 * Complexity: $(BIGOH 1).
	 *
	 * Throws: `Exception` if the array is empty.
	 */
	T removeAny() {
		auto result = back;
		removeBack();
		return result;
	}

	alias stableRemoveAny = removeAny;

	/**
	 * Removes the value from the back of the array. Both stable and non-stable
	 * versions behave the same and guarantee that ranges iterating over the
	 * array are never invalidated.
	 *
	 * Precondition: `empty == false`
	 *
	 * Complexity: $(BIGOH 1).
	 *
	 * Throws: `Exception` if the array is empty.
	 */
	void removeBack() => popBack();

	/// ditto
	alias stableRemoveBack = removeBack;

	void removeBack(int howMany) {
		foreach (const i; 0 .. howMany)
			popBack();
	}
}

/// @nogc array without memory management using a cyclic array internally
/// Should be treated like a static array when no capacity_ is set (copies on assignment)
/// The maximum capacity is static and by default so many elements that it fills at most 4KiB, but at least 8 elements (even if that is more than 4KiB).
/// Set length to 0 to make it a std.container.Array based array
/// Bugs: foreach with ref value requires @nogc body to make this @nogc compatible
///
@nogc @safe unittest {
	CyclicArray!int array;
	assert(array.length == 0);
	array ~= 5;
	assert(!array.empty);
	assert(array.front == 5);
	assert(array[0] == 5);
	array ~= [4, 3];

	assert(array == [5, 4, 3]);

	// same efficiency as insertBack/put/concat
	array.insertFront(5);
}

@nogc @system unittest {
	// heap array using std.container.Array with 16 elements
	auto heapArray = CyclicArray!(int, size_t.max)(16);

	// custom memory using Array
	auto myArray = Array!int(0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
	auto customArray = CyclicArray!(int, size_t.max)(myArray[0 .. 6]);
}

class CyclicRangeError : Error
{
	@nogc @safe pure nothrow this(string msg, string file = __FILE__,
								  size_t line = __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}

// TLS storage shared for all errors, chaining might create circular reference
private void[128] _store;

// only Errors for now as those are rarely chained
private T staticError(T, Args...)(auto ref Args args) @trusted if (is(T : Error)) {
	// pure hack, what we actually need is @noreturn and allow to call that in pure functions
	static T get() {
		static assert(__traits(classInstanceSize, T) <= _store.length,
					  T.stringof ~ " is too large for staticError()");

		_store[0 .. __traits(classInstanceSize, T)] = typeid(T).initializer[];
		return cast(T) _store.ptr;
	}

	auto res = (cast(T function() @trusted pure nothrow @nogc)&get)();
	res.__ctor(args);
	return res;
}

// lots of unittests taken from std.container.array

// Give the Range object some testing.
@system unittest {
	import std.algorithm.comparison : equal;
	import std.range : retro;

	auto a = CyclicArray!int(0, 1, 2, 3, 4, 5, 6)[];
	assert(equal(a, [0, 1, 2, 3, 4, 5, 6]));
	assert(equal(a[], [0, 1, 2, 3, 4, 5, 6]));
	assert(equal(a[0 .. $], [0, 1, 2, 3, 4, 5, 6]));
	auto b = CyclicArray!int(6, 5, 4, 3, 2, 1, 0)[];
	alias A = typeof(a);
	alias ARef = typeof(a.byRef);

	static assert(isRandomAccessRange!A);
	static assert(hasSlicing!A);
	static assert(hasAssignableElements!A);
	static assert(hasMobileElements!A);

	static assert(isRandomAccessRange!ARef);
	static assert(hasSlicing!ARef);
	static assert(hasAssignableElements!ARef);
	static assert(hasMobileElements!ARef);

	assert(equal(retro(b), a));
	assert(a.length == 7);
	assert(equal(a[1 .. 4], [1, 2, 3]));
}

@system unittest {
	alias S = structBug5920;
	uint dMask;

	auto arr = CyclicArray!S(cast(S[])[]);
	foreach (const i; 0 .. 8)
		arr.insertBack(S(i, &dMask));
	{
	// don't check dMask now as S may be copied multiple times (it's ok?)
		assert(arr.length == 8);
		dMask = 0;
		arr.length = 6;
		assert(arr.length == 6); // make sure shrinking calls the d'tor
		assert(dMask == 0b1100_0000);
		arr.removeBack();
		assert(arr.length == 5); // make sure removeBack() calls the d'tor
		assert(dMask == 0b1110_0000);
		arr.removeBack(3);
		assert(arr.length == 2); // ditto
		assert(dMask == 0b1111_1100);
		arr.clear();
		assert(arr.length == 0); // make sure clear() calls the d'tor
		assert(dMask == 0b1111_1111);
	}
	assert(dMask == 0b1111_1111); // make sure the d'tor is called once only.
}

@system unittest {
	auto a = CyclicArray!(int[])([[1, 2], [3, 4]]);
	assert(a.length == 2);
	assert(a[0] == [1, 2]);
	assert(a[1] == [3, 4]);
}

@system unittest {
	import std.algorithm.comparison : equal;

	//Test "array-wide" operations
	auto a = CyclicArray!int([0, 1, 2]); //CyclicArray
	a[] += 5;
	assert(a[].equal([5, 6, 7]));
	++a[];
	assert(a[].equal([6, 7, 8]));
	import std.stdio;

	a[1 .. 3] *= 5;
	assert(a[].equal([6, 35, 40]));
	a[0 .. 2] = 0;
	assert(a[].equal([0, 0, 40]));

	//Test empty array
	auto a2 = CyclicArray!int.init;
	++a2[];
	++a2[0 .. 0];
	a2[] = 0;
	a2[0 .. 0] = 0;
	a2[] += 0;
	a2[0 .. 0] += 0;

	//Test "range-wide" operations
	auto r = CyclicArray!int([0, 1, 2])[]; //CyclicArray.Range
	r[] += 5;
	assert(r.equal([5, 6, 7]));
	++r[];
	assert(r.equal([6, 7, 8]));
	r[1 .. 3] *= 5;
	assert(r.equal([6, 35, 40]));
	r[0 .. 2] = 0;
	assert(r.equal([0, 0, 40]));

	//Test empty Range
	auto r2 = CyclicArray!int.init[];
	++r2[];
	++r2[0 .. 0];
	r2[] = 0;
	r2[0 .. 0] = 0;
	r2[] += 0;
	r2[0 .. 0] += 0;
}

// Test issue
@system unittest {
	static struct S
	{
		int i = 1337;
		void* p;
		this(this) {
			assert(i == 1337);
		}

		~this() nothrow @nogc
		{
			assert(i == 1337);
		}
	}

	CyclicArray!S arr;
	S s;
	arr ~= s;
	arr ~= s;
}

@system unittest {
	import std.algorithm.iteration : filter;

	auto a = CyclicArray!int([1, 2, 2].filter!"true"());
}

@safe unittest {
	auto arr = new CyclicArray!int;
}

@system unittest  //6998
{
	static int i = 0;
	class C
	{
		int dummy = 1;
		this() {
			++i;
		}

		~this() nothrow @nogc
		{
			--i;
		}
	}

	assert(i == 0);
	auto c = new C();
	assert(i == 1);

	//scope
	{
		auto arr = CyclicArray!C(c);
		assert(i == 1);
	}
	//CyclicArray should not have destroyed the class instance
	assert(i == 1);

	//Just to make sure the GC doesn't collect before the above test.
	assert(c.dummy == 1);
}

@system unittest  //6998-2
{
	static class C
	{
		int i;
	}

	auto c = new C;
	c.i = 42;
	CyclicArray!C a;
	a ~= c;
	a.clear;
	assert(c.i == 42); //fails
}

@nogc:
unittest {
	alias IntArray = CyclicArray!int;
	alias IntRange = CyclicRange!int;

	static assert(isInputRange!IntArray);
	static assert(isOutputRange!(IntArray, int));
	static assert(isForwardRange!IntArray);
	static assert(isBidirectionalRange!IntArray);
	static assert(isRandomAccessRange!IntArray);
	static assert(hasMobileElements!IntArray);
	static assert(is(ElementType!IntArray == int));
	static assert(hasSwappableElements!IntArray);
	static assert(hasAssignableElements!IntArray);
	static assert(hasLvalueElements!IntArray);
	static assert(hasLength!IntArray);
	static assert(hasSlicing!IntArray);

	static assert(isInputRange!IntRange);
	static assert(isOutputRange!(IntRange, int));
	static assert(isForwardRange!IntRange);
	static assert(isBidirectionalRange!IntRange);
	static assert(isRandomAccessRange!IntRange);
	static assert(hasMobileElements!IntRange);
	static assert(is(ElementType!IntRange == int));
	static assert(hasSwappableElements!IntRange);
	static assert(hasAssignableElements!IntRange);
	static assert(hasLvalueElements!IntRange);
	static assert(hasLength!IntRange);
	static assert(hasSlicing!IntRange);

	IntArray array;
	assert(array.length == 0);
	assert(array.empty);
	array ~= 5;
	assert(!array.empty);
	assert(array.length == 1);
	assert(array.front == 5);
	assert(array[0] == 5);
	assert(array[0 .. 1].front == 5);
	assert(array[0 .. 0].empty);
	array ~= cast(int[2])[4, 3];
	assert(array.length == 3);
	assert(array[1] == 4);
	assert(array[2] == 3);

	foreach (const i; 0 .. 50000) {
		array ~= i;
		array.popFront();
	}

	assert(array.length == 3);

	array ~= array;
	assert(array.length == 6);
	assert((array ~ array).length == 12);
	assert(array.length == 6);

	array[5] = 1;
	assert(array[5] == 1);
	auto copy = array;
	copy[5] = 2;
	assert(array[5] == 1);
	array[][5] = 1;
	assert(array[5] == 1);

	foreach (ref v; array.byRef)
		v = 42;

	assert(array[5] == 42);
}

unittest {
	alias IntArray = CyclicArray!(int, size_t.max);

	static assert(isInputRange!IntArray);
	static assert(isOutputRange!(IntArray, int));
	static assert(isForwardRange!IntArray);
	static assert(isBidirectionalRange!IntArray);
	static assert(isRandomAccessRange!IntArray);
	static assert(hasMobileElements!IntArray);
	static assert(is(ElementType!IntArray == int));
	static assert(hasSwappableElements!IntArray);
	static assert(hasAssignableElements!IntArray);
	static assert(hasLvalueElements!IntArray);
	static assert(hasLength!IntArray);
	static assert(hasSlicing!IntArray);

	auto array = IntArray(1024);
	assert(array.length == 0);
	assert(array.empty);
	array ~= 5;
	assert(!array.empty);
	assert(array.length == 1);
	assert(array.front == 5);
	assert(array[0] == 5);
	assert(array[0 .. 1].front == 5);
	assert(array[0 .. 0].empty);
	array ~= cast(int[2])[4, 3];
	assert(array.length == 3);
	assert(array[1] == 4);
	assert(array[2] == 3);

	foreach (const i; 0 .. 50000) {
		array ~= i;
		array.popFront();
	}

	assert(array.length == 3);

	array ~= array;
	assert(array.length == 6);
	assert((array ~ array).length == 12);
	assert(array.length == 6);

	array[5] = 1;
	assert(array[5] == 1);
	auto copy = array[];
	copy[5] = 2;
	assert(array[5] == 1);
	array[][5] = 1;
	assert(array[5] == 1);
}

@system unittest {
	CyclicArray!int a;
	assert(a.empty);
}

@system unittest {
	CyclicArray!int a;
	a.length = 10;
	assert(a.length == 10);
	assert(a.capacity >= a.length);
}

@system unittest {
	struct Dumb
	{
		int x = 5;
	}

	CyclicArray!Dumb a;
	a.length = 10;
	assert(a.length == 10);
	assert(a.capacity >= a.length);
	const cap = a.capacity;
	foreach (ref e; a)
		e.x = 10;
	a.length = 5;
	assert(a.length == 5);
	foreach (ref e; a)
		assert(e.x == 10);

	a.length = 8;
	assert(a.length == 8);
	assert(Dumb.init.x == 5);
	foreach (const i; 0 .. 5)
		assert(a[i].x == 10);
	foreach (const i; 5 .. a.length)
		assert(a[i].x == Dumb.init.x);

	a[] = Dumb(1);
	a.length = 20;
	foreach (const i; 0 .. 8)
		assert(a[i].x == 1);
	foreach (const i; 8 .. a.length)
		assert(a[i].x == Dumb.init.x);

	// check if overlapping elements properly initialized
	a.length = 1;
	a.length = 20;
	assert(a[0].x == 1);
	foreach (e; a[1 .. $])
		assert(e.x == Dumb.init.x);
}

@system unittest {
	CyclicArray!int a = CyclicArray!int(1, 2, 3);
	//a._data._refCountedDebug = true;
	auto b = a.dup;
	assert(b == CyclicArray!int(1, 2, 3));
	b.front = 42;
	assert(b == CyclicArray!int(42, 2, 3));
	assert(a == CyclicArray!int(1, 2, 3));
}

@system unittest {
	auto a = CyclicArray!int(1, 2, 3);
	assert(a.length == 3);
}

@system unittest {
	const CyclicArray!int a = [1, 2];

	assert(a[0] == 1);
	assert(a.front == 1);
	assert(a.back == 2);

	static assert(!__traits(compiles, { a[0] = 1; }));
	static assert(!__traits(compiles, { a.front = 1; }));
	static assert(!__traits(compiles, { a.back = 1; }));

	auto r = a[];
	size_t i;
	foreach (e; r) {
		assert(e == i + 1);
		i++;
	}
}

@system unittest {
	auto a = CyclicArray!int(1, 2, 3);
	a[1] *= 42;
	assert(a[1] == 84);
}

@system unittest {
	auto a = CyclicArray!int(1, 2, 3);
	auto b = CyclicArray!int(11, 12, 13);
	auto c = a ~ b;
	assert(c == CyclicArray!int(1, 2, 3, 11, 12, 13));
	assert(a ~ b[] == CyclicArray!int(1, 2, 3, 11, 12, 13));
	assert(a ~ [4, 5] == CyclicArray!int(1, 2, 3, 4, 5));
}

@system unittest {
	auto a = CyclicArray!int(1, 2, 3);
	auto b = CyclicArray!int(11, 12, 13);
	a ~= b;
	assert(a == CyclicArray!int(1, 2, 3, 11, 12, 13));
}

@system unittest {
	auto a = CyclicArray!int(1, 2, 3, 4);
	assert(a.removeAny() == 4);
	assert(a == CyclicArray!int(1, 2, 3));
}

private struct structBug5920
{
	int order;
	uint* pDestructionMask;
	~this() nothrow @nogc
	{
		if (pDestructionMask)
			*pDestructionMask += 1 << order;
	}
}

@system unittest {
	auto a = CyclicArray!int([1, 1]);
	a[1] = 0; //Check CyclicArray.opIndexAssign
	assert(a[1] == 0);
	a[1] += 1; //Check CyclicArray.opIndexOpAssign
	assert(a[1] == 1);

	//Check CyclicArray.opIndexUnary
	++a[0];
	//a[0]++ //op++ doesn't return, so this shouldn't work, even with 5044 fixed
	assert(a[0] == 2);
	assert(+a[0] == +2);
	assert(-a[0] == -2);
	assert(~a[0] == ~2);

	auto r = a[];
	r[1] = 0; //Check CyclicArray.Range.opIndexAssign
	assert(r[1] == 0);
	r[1] += 1; //Check CyclicArray.Range.opIndexOpAssign
	assert(r[1] == 1);

	//Check CyclicArray.Range.opIndexUnary
	++r[0];
	//r[0]++ //op++ doesn't return, so this shouldn't work, even with 5044 fixed
	assert(r[0] == 3);
	assert(+r[0] == +3);
	assert(-r[0] == -3);
	assert(~r[0] == ~3);
}

@safe unittest {
	static struct S
	{
		bool b;
		alias b this;
	}

	alias A = CyclicArray!S;
	alias B = CyclicArray!(shared bool);
}

@system unittest {
	CyclicArray!int ai;
	ai ~= 1;
	assert(ai.front == 1);

	static const arr = [1, 2, 3];
	ai.insertBack(arr);
}

version (unittest) {
	import std.range.primitives;
	import std.container.array : Array;
}
