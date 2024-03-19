module nxt.container.dynamic_array;

import std.experimental.allocator.gc_allocator : GCAllocator;
import std.experimental.allocator.common : isAllocator;

/** Dynamic array container.

	TODO: Move members dealing with `Allocator`, such as DynamicArrray.reserve,
    and others to private members of `ArrayStore` and then rerun container
    benchmark for `DynamicArray`. Also include a benchmark of calls to
    `ArrayStore.reserve()`.

	TODO: Generalize to bucket array either via specialized allocator to by
	extra Storage class given as template type parameter. Integrate
	`nxt.bucket_array` for details.

	TODO: Add OutputRange.writer support as
	https://github.com/burner/StringBuffer/blob/master/source/stringbuffer.d#L45

	TODO: Use `std.traits.areCopyCompatibleArrays`

	TODO: Check if using the std::vector-compatible store is faster: struct
	Store { T* begin; T* endData; T* endCapacity; }

    See: http://forum.dlang.org/thread/wswbtzakdvpgaebuhbom@forum.dlang.org See
	also https://github.com/izabera/s */
@safe struct DynamicArray(T, Allocator = GCAllocator, Capacity = size_t)
if (!is(immutable T == immutable bool) && // use `BitArray` instead for now
	(is(Capacity == ulong) || // two 64-bit words
	 is(Capacity == uint)) && // two 64-bit words
	isAllocator!Allocator) {

	/** Growth factor P/Q.
		https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
		Use 1.5 like Facebook's `fbvector` does.
	*/
	enum _growthP = 3;		  // numerator
	/// ditto
	enum _growthQ = 2;		  // denominator

	// import core.exception : onOutOfMemoryError;
	import core.stdc.string : memset;
	import core.internal.traits : Unqual, hasElaborateDestructor;
	import std.experimental.allocator : makeArray;
	import std.range.primitives : isInputRange, ElementType, hasLength, hasSlicing, isInfinite;
	import std.traits : hasIndirections, hasAliasing,
		isMutable, TemplateOf, isArray, isType, isIterable, isPointer;
	import core.lifetime : emplace, move, moveEmplace;

	import nxt.qcmeman : gc_addRange, gc_removeRange;
	import nxt.container.traits : mustAddGCRange, isRvalueAssignable;

	/// Mutable element type.
	private alias MT = Unqual!T;

	/// Is `true` if `U` can be assigned to the elements of `this`.
	enum isElementAssignable(U) = isRvalueAssignable!(MT, U);

	private this(Store store) {
		version (D_Coverage) {} else pragma(inline, true);
		_store = store;
	}

	/// Construct from element `value`.
	this(U)(U value) @trusted if (isElementAssignable!U) {
		_store = Store(typeof(this).allocate(1, false), 1);
		static if (__traits(isPOD, T))
			_mptr[0] = value;
		else
			moveEmplace(value, _mptr[0]); /+ TODO: remove when compiler does this +/
	}

	/// Construct from the element(s) of the dynamic array `values`.
	this(U)(U[] values) @trusted if (isElementAssignable!(U)) {
		/+ TODO: use import emplace_all instead +/
		_store = Store(allocate(values.length, false), values.length);
		foreach (index; 0 .. values.length)
			static if (__traits(isPOD, T))
				_mptr[index] = values[index];
			else
				move(values[index], _mptr[index]);
	}

	/// Construct from the `n` number of element(s) in the static array `values`.
	this(uint n, U)(U[n] values) @trusted
	if (values.length <= Capacity.max && isElementAssignable!(U)) {
		/+ TODO: use import emplace_all instead +/
		_store = Store(allocate(values.length, false), values.length, values.length);
		static foreach (index; 0 .. values.length)
			static if (__traits(isPOD, T))
				_mptr[index] = values[index];
			else
				move(values[index], _mptr[index]);
	}
	/// ditto
	this(R)(scope R values) @trusted
	if (// isRefIterable!R &&
		isElementAssignable!(ElementType!R) &&
		!isArray!R) {
		static if (hasLength!R) {
			reserve(values.length);
			size_t index = 0;
			foreach (ref value; values)
				_mptr[index++] = value;
			_store._length = values.length;
		} else
			foreach (ref value; values)
				insertBack1(value);
	}

	/** Is `true` iff the iterable container `C` can be insert to `this`.
	 */
	private enum isInsertableContainer(C) = (is(C == struct) && // exclude class ranges for aliasing control
											 isRefIterable!C && // elements may be non-copyable
											 !isInfinite!C &&
											 isElementAssignable!(ElementType!C));

	/// Construct from the elements `values`.
	static typeof(this) withElementsOfRange_untested(R)(R values) @trusted
	if (isInsertableContainer!R) {
		typeof(this) result;
		static if (hasLength!R)
			result.reserve(values.length);
		static if (__traits(isPOD, ElementType!R) &&
				   hasLength!R &&
				   hasSlicing!R) {
			import std.algorithm.mutation : copy;
			copy(values[0 .. values.length],
				 result._mptr[0 .. values.length]); /+ TODO: better to use foreach instead? +/
			result._store._length = values.length;
		} else {
			static if (hasLength!R) {
				size_t i = 0;
				foreach (ref value; move(values)) /+ TODO: remove `move` when compiler does it for us +/
					static if (__traits(isPOD, typeof(value)))
						result._mptr[i++] = value;
					else
						moveEmplace(value, result._mptr[i++]);
				result._store._length = values.length;
			} else {
				// import std.algorithm.mutation : moveEmplaceAll;
				/* TODO: optimize with `moveEmplaceAll` that does a raw copy and
				 * zeroing of values */
				foreach (ref value; move(values)) /+ TODO: remove `move` when compiler does it for us +/
					static if (__traits(isPOD, ElementType!R))
						result.insertBack(value);
					else
						result.insertBackMove(value); // steal element
			}
		}
		return result;
	}

	/// No default copying.
	this(this) @disable;

	/+ TODO: this gives error in insertBack. why? +/
	// void opAssign()(typeof(this) rhs) @trusted pure nothrow @nogc /*tlm*/
	// {
	//	 move(rhs, this);
	// }

	/** Destruct.
	 *
	 * TODO: what effect does have here?
	 * See_Also: https://github.com/atilaneves/automem/blob/master/source/automem/vector.d#L92
	 */
	~this() nothrow @nogc /*TODO:scope*/ {
		releaseElementsStore();
	}

	/// Clear.
	void clear() @nogc {
		releaseElementsStore();
		resetInternalData();
	}

	/// Release elements and internal store.
	private void releaseElementsStore() @nogc @trusted {
		foreach (const index; 0 .. _store.length)
			static if (hasElaborateDestructor!T)
				.destroy(_mptr[index]);
			else static if (is(T == class) || isPointer!T || hasIndirections!T)
				_mptr[index] = T.init; // nullify any pointers
		freeStore();
	}

	/// Free internal store.
	private void freeStore() @trusted {
		static if (mustAddGCRange!T)
			gc_removeRange(_mptr);
		allocator.deallocate(cast(void[])_store[]);
	}

	/// Reset internal data.
	private void resetInternalData() @nogc {
		version (D_Coverage) {} else pragma(inline, true);
		_store = Store.init;
	}

	/** Allocate heap region with `initialCapacity` number of elements of type `T`.
	 *
	 * If `initFlag` is `true` elements will be initialized
	 */
	private static MT* allocate(in Capacity initialCapacity, in bool initFlag) @trusted {
		const size_t numBytes = initialCapacity * T.sizeof;
		typeof(return) ptr = null;
		if (initFlag) {
			static if (__traits(isZeroInit, T) &&
					   __traits(hasMember, Allocator, "allocateZeroed") &&
					   is(typeof(allocator.allocateZeroed(numBytes)) == void[]))
				ptr = cast(typeof(return))(allocator.allocateZeroed(numBytes).ptr);
			else {
				ptr = cast(typeof(return))(allocator.allocate(numBytes).ptr);
				static if (__traits(isZeroInit, T))
					memset(ptr, 0, numBytes);
				else
					foreach (i; 0 .. initialCapacity)
						ptr[i] = MT.init;
			}
		} else
			ptr = cast(typeof(return))(allocator.allocate(numBytes).ptr);
		if (ptr is null &&
			initialCapacity >= 1 )
			/+ TODO: onOutOfMemoryError(); +/
			return null;
		static if (mustAddGCRange!T)
			gc_addRange(ptr, numBytes);
		return ptr;
	}

	static if (__traits(isCopyable, T)) {
		/** Allocate heap region with `initialCapacity` number of elements of type `T` all set to `elementValue`.
		 */
		private static MT* allocateWithValue(in Capacity initialCapacity, T elementValue) @trusted {
			const size_t numBytes = initialCapacity * T.sizeof;
			typeof(return) ptr = null;
			ptr = allocator.makeArray!MT(initialCapacity, elementValue).ptr; /+ TODO: set length +/
			if (ptr is null &&
				initialCapacity >= 1)
				/+ TODO: onOutOfMemoryError(); +/
				return null;
			static if (mustAddGCRange!T)
				gc_addRange(ptr, numBytes);
			return ptr;
		}
	}

	/** Comparison for equality. */
	bool opEquals()(const auto ref typeof(this) rhs) const scope /*tlm*/ {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		return opSlice() == rhs.opSlice();
	}

	/// ditto
	pragma(inline, true)
	bool opEquals(U)(const scope U[] rhs) const scope
	if (is(typeof(T[].init == U[].init)))
		=> opSlice() == rhs;

	/// Calculate D associative array (AA) key hash.
	pragma(inline, true)
	hash_t toHash()() const scope @trusted /*tlm*/
		=> .hashOf(length) + .hashOf(opSlice());

	static if (__traits(isCopyable, T)) {
		/** Construct a string representation of `this` at `sink`. */
		void toString(Sink)(ref scope Sink sink) const scope /*tlm*/ {
			import std.conv : to;
			sink("[");
			foreach (const index, ref value; opSlice()) {
				sink(to!string(value));
				if (index + 1 < length) { sink(", "); } // separator
			}
			sink("]");
		}
	}

	/// Get length.
	pragma(inline, true)
	@property Capacity length() const scope => _store.length;
	/// ditto
	alias opDollar = length;

	/** Set length to `newLength`.
	 *
	 * If `newLength` < `length` elements are truncate.
	 * If `newLength` > `length` default-initialized elements are appended.
	 */
	@property void length(in Capacity newLength) @trusted scope {
		if (newLength < length) { // if truncation
			static if (hasElaborateDestructor!T)
				foreach (const index; newLength .. _store.length)
					.destroy(_mptr[index]);
			else static if (mustAddGCRange!T)
				foreach (const index; newLength .. _store.length)
					_mptr[index] = T.init; // avoid GC mark-phase dereference
		} else {
			reserveFitLength(newLength);
			static if (hasElaborateDestructor!T) {
				/+ TODO: remove when compiler does it for us +/
				foreach (const index; _store.length .. newLength) {
					/+ TODO: remove when compiler does it for us: +/
					static if (__traits(isCopyable, T))
						emplace(&_mptr[index], T.init);
					else {
						auto _ = T.init;
						moveEmplace(_, _mptr[index]);
					}
				}
			} else
				_mptr[_store.length .. newLength] = T.init;
		}
		_store._length = newLength;
	}

	/// Get capacity.
	pragma(inline, true)
	@property Capacity capacity() const scope pure nothrow @nogc => _store.capacity;

	/** Ensures sufficient capacity to accommodate for minimumCapacity number of
		elements. If `minimumCapacity` < `capacity`, this method does nothing.
	 */
	Capacity reserve(in Capacity minimumCapacity) @trusted scope pure nothrow {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		if (minimumCapacity <= capacity)
			return capacity;
		return reallocateAndSetCapacity(_growthP * minimumCapacity / _growthQ);
		// import std.math.algebraic : nextPow2;
		// reallocateAndSetCapacity(minimumCapacity.nextPow2);
	}
	/** Ensures exactly sufficient capacity to accommodate for minimumCapacity number of
		elements. If `minimumCapacity` < `capacity`, this method does nothing.
	 */
	private Capacity reserveFitLength(in Capacity minimumCapacity) @trusted scope pure nothrow {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		if (minimumCapacity <= capacity)
			return capacity;
		return reallocateAndSetCapacity(minimumCapacity);
		// import std.math.algebraic : nextPow2;
		// reallocateAndSetCapacity(minimumCapacity.nextPow2);
	}

	/// Reallocate storage.
	private Capacity reallocateAndSetCapacity()(in Capacity newCapacity) @trusted /*tlm*/ {
		static if (mustAddGCRange!T)
			gc_removeRange(_store.ptr);

		/+ TODO: functionize: +/
		auto slice = cast(void[])(_store[]);
		const ok = allocator.reallocate(slice, T.sizeof * newCapacity);

		assert(ok);

		_store = Store(cast(T[])slice, _store.length); /+ TODO: only mutate _store.slice +/

		if (_store.ptr is null &&
			newCapacity >= 1)
			/+ TODO: onOutOfMemoryError(); +/
			return _store.capacity;

		static if (mustAddGCRange!T)
			gc_addRange(_store.ptr, _store.capacity * T.sizeof);

		return _store.capacity;
	}

	/// Slice support.
	pragma(inline, true)
	inout(T)[] opSlice()(in size_t i, in size_t j) inout return scope @trusted /*tlm*/ => _store.ptr[i .. j];
	/// ditto
	pragma(inline, true)
	inout(T)[] opSlice()() inout return scope @trusted /*tlm*/ => _store.ptr[0 .. _store.length];

	/// Slice assignment support.
	pragma(inline, true)
	inout(T)[] opSliceAssign(U)(scope U value) inout return scope @trusted => cast(T[])(opSlice()[]) = value;
	/// ditto
	pragma(inline, true)
	inout(T)[] opSliceAssign(U)(scope U value, in size_t i, in size_t j) inout return scope => cast(T[])(opSlice()[i .. j]) = value;

	/// Index support.
	pragma(inline, true)
	ref inout(T) opIndex()(in size_t i) inout return scope /*tlm*/ => opSlice()[i];

	/// Index assignment support.
	ref T opIndexAssign(U)(scope U value, in size_t i) @trusted return scope {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		static if (!__traits(isPOD, T)) {
			move(*(cast(MT*)(&value)), _mptr[i]); /+ TODO: is this correct? +/
			return opSlice()[i];
		} else static if ((is(T == class) || isPointer!T || hasIndirections!T) && !isMutable!T)
			static assert(0, "Cannot modify constant elements with indirections");
		else
			return opSlice()[i] = value;
	}

	/// Get reference to front element.
	pragma(inline, true)
	@property ref inout(T) front() inout return scope => opSlice()[0];	  // range-checked by default

	/// Get reference to back element.
	pragma(inline, true)
	@property ref inout(T) back() inout return scope => opSlice()[_store.length - 1]; // range-checked by default

	/** Insert `value` into the end of the array.
	 */
	void insertBack(scope T value) scope @trusted {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		static if (__traits(isPOD, T)) {
			reserve(_store.length + 1);
			_mptr[_store.length] = value;
			_store._length += 1;
		} else
			insertBackMove(*cast(MT*)(&value));
	}

	/** Move `value` into the end of the array.
	 */
	void insertBackMove(scope ref T value) scope @trusted {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		reserve(_store.length + 1);
		static if (__traits(isPOD, T))
			_mptr[_store.length] = value;
		else
			moveEmplace(value, _mptr[_store.length]);
		_store._length += 1;
	}

	alias put = insertBack;

	/** Insert the elements `values` into the end of the array.
	 */
	void insertBack(U)(U[] values...) scope @trusted
	if (isElementAssignable!U &&
		__traits(isCopyable, U)) { // prevent accidental move of l-value `values`
		if (values.length == 1) /+ TODO: branch should be detected at compile-time +/
			// twice as fast as array assignment below
			return insertBack(values[0]);
		static if (is(T == immutable(T))) {
			/* An array of immutable values cannot overlap with the `this`
			   mutable array container data, which entails no need to check for
			   overlap.
			*/
			reserve(_store.length + values.length);
			_mptr[_store.length .. _store.length + values.length] = values;
		} else {
			import nxt.overlapping : overlaps;
			if (_store.ptr == values.ptr) { // called for instances as: `this ~= this`
				reserve(2*_store.length); // invalidates `values.ptr`
				foreach (const i; 0 .. _store.length)
					_mptr[_store.length + i] = _store.ptr[i];
			} else if (overlaps(this[], values[]))
				assert(0, `TODO: Handle overlapping arrays`);
			else {
				reserve(_store.length + values.length);
				_mptr[_store.length .. _store.length + values.length] = values;
			}
		}
		_store._length += values.length;
	}

	/** Insert the elements `elements` into the end of the array.
	 */
	void insertBack(R)(scope R elements) @trusted
	if (isInsertableContainer!R) {
		import std.range.primitives : hasLength;
		static if (isInputRange!R &&
				   hasLength!R) {
			reserve(_store.length + elements.length);
			import std.algorithm.mutation : copy;
			copy(elements, _mptr[_store.length .. _store.length + elements.length]);
			_store.length += elements.length;
		} else {
			foreach (ref element; move(elements)) /+ TODO: remove `move` when compiler does it for us +/
				static if (__traits(isCopyable, ElementType!R))
					insertBack(element);
				else
					insertBackMove(element);
		}
	}
	/// ditto
	alias put = insertBack;

	/** Remove last value from the end of the array.
	 */
	void popBack()() @trusted in(length != 0) /*tlm*/ {
		version (D_Coverage) {} else pragma(inline, true);
		_store._length -= 1;
		static if (hasElaborateDestructor!T)
			.destroy(_mptr[_store.length]);
		else static if (mustAddGCRange!T)
			_mptr[_store.length] = T.init; // avoid GC mark-phase dereference
	}

	/** Rmove `n` last values from the end of the array.

		See_Also: http://mir-algorithm.libmir.org/mir_appender.html#.ScopedBuffer.popBackN
	 */
	void popBackN()(in Capacity n) @trusted in(n <= length) /*tlm*/ {
		_store._length -= n;
		static if (hasElaborateDestructor!T)
			foreach (const index; 0 .. n)
				.destroy(_mptr[_store.length + index]);
		else static if (mustAddGCRange!T)
			foreach (const index; 0 .. n)
				_mptr[_store.length + index] = T.init; // avoid GC mark-phase dereference
	}

	/** Pop back element and return it.

		This is well-missed feature of C++'s `std::vector` because of problems
		with exception handling. For more details see
		https://stackoverflow.com/questions/12600330/pop-back-return-value.
	 */
	T takeBack()() @trusted in(length != 0) /*tlm*/ {
		version (D_Coverage) {} else pragma(inline, true);
		_store._length -= 1;
		static if (!__traits(isPOD, T))
			return move(_mptr[_store.length]);
		else static if (is(T == class) || isPointer!T || hasIndirections!T) { // fast, medium, slow path
			T e = void;
			moveEmplace(_mptr[_store.length], e); // reset any pointers at `back`
			return e;
		} else
			return _mptr[_store.length];
	}

	/** Pop element at `index`. */
	void popAt()(in Capacity index) @trusted @("complexity", "O(length)") /*tlm*/
	in(index < this.length) {
		static if (hasElaborateDestructor!T)
			.destroy(_mptr[index]);
		else static if (mustAddGCRange!T)
			_mptr[index] = T.init; // avoid GC mark-phase dereference
		shiftToFrontAt(index);
		_store._length -= 1;
	}

	/** Move element at `index` to return. */
	static if (isMutable!T)
		T moveAt()(in Capacity index) @trusted @("complexity", "O(length)") /*tlm*/
		in(index < this.length) {
			auto value = move(_mptr[index]);
			shiftToFrontAt(index);
			_store._length -= 1;
			return move(value); /+ TODO: remove `move` when compiler does it for us +/
		}

	/** Move element at front. */
	static if (isMutable!T)
		pragma(inline, true)
		T takeFront()() @("complexity", "O(length)") /*tlm*/
			=> moveAt(0);

	private void shiftToFrontAt()(in Capacity index) @trusted /*tlm*/ {
		/+ TODO: use this instead: +/
		// const si = index + 1;   // source index
		// const ti = index;	   // target index
		// const restLength = this.length - (index + 1);
		// import std.algorithm.mutation : moveEmplaceAll;
		// moveEmplaceAll(_mptr[si .. si + restLength],
		//				_mptr[ti .. ti + restLength]);
		foreach (const i; 0 .. this.length - (index + 1)) { // each element index that needs to be moved
			const si = index + i + 1; // source index
			const ti = index + i; // target index
			moveEmplace(_mptr[si], /+ TODO: remove when compiler does this +/
						_mptr[ti]);
		}
	}

	/** Forwards to $(D insertBack(values)). */
	void opOpAssign(string op)(T value) if (op == "~") {
		version (D_Coverage) {} else pragma(inline, true);
		insertBackMove(value);
	}
	/// ditto
	void opOpAssign(string op, U)(U[] values...) @trusted if (op == "~" &&
		isElementAssignable!U &&
		__traits(isCopyable, U))	   // prevent accidental move of l-value `values`
	{
		version (D_Coverage) {} else pragma(inline, true);
		insertBack(values);
	}
	/// ditto
	void opOpAssign(string op, R)(R values) if (op == "~" &&
		isInputRange!R &&
		!isInfinite!R &&
		!isArray!R &&
		isElementAssignable!(ElementType!R)) {
		version (D_Coverage) {} else pragma(inline, true);
		insertBack(values);
	}

	void opOpAssign(string op)(auto ref typeof(this) values) if (op == "~") {
		version (D_Coverage) {} else pragma(inline, true);
		insertBack(values[]);
	}

	/// Unsafe access to store pointer.
	pragma(inline, true)
	@property inout(T)* ptr() inout return @system => _store.ptr;

	/// Convenience access of pointer to mutable store.
	pragma(inline, true)
	private @property MT* _mptr() const return @trusted => cast(typeof(return))_store.ptr;

private:
	import nxt.allocator_traits : AllocatorState;
	mixin AllocatorState!Allocator; // put first as emsi-containers do

	import nxt.container.array_store : ArrayStore;
	alias Store = ArrayStore!(T, Allocator, Capacity);
	Store _store;
}

import std.functional : unaryFun;

/** Remove all elements matching `predicate`.

	Returns: number of elements that were removed.

	TODO: implement version that doesn't use a temporary array `tmp`, which is
	probably faster for small arrays.
 */
size_t remove(alias predicate, C)(ref C c) @trusted @("complexity", "O(length)")
if (is(C == DynamicArray!(_), _...) &&
	is(typeof(unaryFun!predicate(C.init[0])))) {
	C tmp;
	size_t count = 0;
	foreach (const i; 0 .. c.length) {
		if (unaryFun!predicate(c[i])) {
			count += 1;
			import core.internal.traits : hasElaborateDestructor;
			import nxt.container.traits : mustAddGCRange;
			alias T = typeof(c[i]);
			static if (hasElaborateDestructor!(T))
				.destroy(c[i]);
			else static if (mustAddGCRange!(T))
				c[i] = T.init;	// avoid GC mark-phase dereference
		} else
			tmp.insertBackMove(c[i]); /+ TODO: remove unnecessary clearing of `_mptr[i]` +/
	}
	c.freeStore();
	import core.lifetime : moveEmplace;
	moveEmplace(tmp, c);
	return count;
}

pure nothrow @safe @nogc unittest {
	alias T = uint;

	DynamicArray!(T, TestAllocator) s;
	assert(s.length == 0);

	s.insertBack(13U);
	assert(s.length == 1);
	assert(s.back == 13);

	s.insertBack(14U);
	assert(s.length == 2);
	assert(s.back == 14);

	s.popBack();
	assert(s.length == 1);
	s.popBack();
	assert(s.length == 0);
}

pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator, uint);
	static if (size_t.sizeof == 8) // for 64-bit
		static assert(A.sizeof == 2 * size_t.sizeof); // only two words
}

/// construct and append from slices
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([10,11,12].s);
	a ~= a[];
	assert(a[] == [10,11,12, 10,11,12].s);
	a ~= false;
	assert(a[] == [10,11,12, 10,11,12, 0].s);
}

/// construct and append using self
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([10,11,12].s);
	a ~= a;
	assert(a[] == [10,11,12, 10,11,12].s);
}

///
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);
	A a;
	a.length = 1;
	assert(a.length == 1);
	assert(a.capacity == 1);

	a[0] = 10;
	a.insertBack(11, 12);
	a ~= T.init;
	a.insertBack([3].s);
	assert(a[] == [10,11,12, 0, 3].s);

	import std.algorithm.iteration : filter;

	a.insertBack([42].s[].filter!(_ => _ is 42));
	assert(a[] == [10,11,12, 0, 3, 42].s);

	a.insertBack([42].s[].filter!(_ => _ !is 42));
	assert(a[] == [10,11,12, 0, 3, 42].s);

	a ~= a[];
	assert(a[] == [10,11,12, 0, 3, 42,
				   10,11,12, 0, 3, 42].s);
}

///
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T);

	A a;						// default construction allowed
	assert(a.length == 0);
	assert(a.length == 0);
	assert(a.capacity == 0);
	assert(a[] == []);

	alias B = DynamicArray!(int, TestAllocator);
	B b;
	b.length = 3;
	assert(b.length != 0);
	assert(b.length == 3);
	assert(b.capacity == 3);
	b[0] = 1;
	b[1] = 2;
	b[2] = 3;
	assert(b[] == [1, 2, 3].s);

	b[] = [4, 5, 6].s;
	assert(b[] == [4, 5, 6].s);

	auto c = DynamicArray!(int, TestAllocator)();
	c.reserve(3);
	assert(c.length == 0);
	assert(c.capacity >= 3);
	assert(c[] == []);

	version (none) // TODO: enable
	static if (hasPreviewDIP1000)
		static assert(!__traits(compiles, { T[] f() @safe { A a; return a[]; } }));

	const e = DynamicArray!(int, TestAllocator)([1, 2, 3, 4].s);
	assert(e.length == 4);
	assert(e[] == [1, 2, 3, 4].s);
}

///
@trusted pure nothrow @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);

	auto a = A([1, 2, 3].s);
	A b = a.dupShallow;				// copy construction enabled

	assert(a[] == b[]);		  // same content
	assert(&a[0] !is &b[0]); // but not the same

	assert(b[] == [1, 2, 3].s);
	assert(b.length == 3);

	b ~= 4;
	assert(a != b);
	a.clear();
	assert(a != b);
	b.clear();
	assert(a == b);

	const c = A([1, 2, 3].s);
	assert(c.length == 3);
}

/// DIP-1000 return ref escape analysis
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!T;
	version (none) // TODO: enable
	static if (hasPreviewDIP1000)
		static assert(!__traits(compiles, { T[] leakSlice() pure nothrow @safe @nogc { A a; return a[]; } }));
	T* leakPointer() pure nothrow @safe @nogc {
		A a;
		return a._store.ptr;	/+ TODO: shouldn't compile with -dip1000 +/
	}
	const _lp = leakPointer();	/+ TODO: shouldn't compile with -dip1000 +/
}

/// construct and insert from non-copyable element type passed by value
@safe pure nothrow /*@nogc*/ unittest {
	alias E = Uncopyable;
	alias A = DynamicArray!(E);

	A a = A(E(17));
	assert(a[] == [E(17)]);

	a.insertBack(E(18));
	assert(a[] == [E(17),
				   E(18)]);

	a ~= E(19);
	assert(a[] == [E(17),
				   E(18),
				   E(19)]);
}

/// construct from slice of uncopyable type
pure nothrow @safe @nogc unittest {
	alias _A = DynamicArray!(Uncopyable);
	/+ TODO: can we safely support this?: A a = [Uncopyable(17)]; +/
}

// construct from array with uncopyable elements
pure nothrow @safe @nogc unittest {
	alias A = DynamicArray!(Uncopyable);
	const A a;
	assert(a.length == 0);
	/+ TODO: a.insertBack(A.init); +/
	assert(a.length == 0);
	const _ = a.toHash;
}

// construct from ranges of uncopyable elements
pure nothrow @safe @nogc unittest {
	alias T = Uncopyable;
	alias A = DynamicArray!T;
	const A a;
	assert(a.length == 0);
	// import std.algorithm.iteration : map, filter;
	// const b = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => T(_^^2))); // hasLength
	// assert(b.length == 3);
	// assert(b == [T(100), T(400), T(900)].s);
	// const c = A.withElementsOfRange_untested([10, 20, 30].s[].filter!(_ => _ == 30).map!(_ => T(_^^2))); // !hasLength
	// assert(c.length == 1);
	// assert(c[0].x == 900);
}

// construct from ranges of copyable elements
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);

	const A a;
	assert(a.length == 0);

	import std.algorithm.iteration : map, filter;

	const b = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => T(_^^2))); // hasLength
	assert(b.length == 3);
	assert(b == [T(100), T(400), T(900)].s);

	() @trusted {			   /+ TODO: remove @trusted +/
		const c = A.withElementsOfRange_untested([10, 20, 30].s[].filter!(_ => _ == 30).map!(_ => T(_^^2))); // !hasLength
		assert(c == [T(900)].s);
	} ();
}

/// construct with string as element type that needs GC-range
pure nothrow @safe @nogc unittest {
	alias T = string;
	alias A = DynamicArray!(T, TestAllocator);

	A a;
	a ~= `alpha`;
	a ~= `beta`;
	a ~= [`gamma`, `delta`].s;
	assert(a[] == [`alpha`, `beta`, `gamma`, `delta`].s);

	const b = [`epsilon`].s;

	a.insertBack(b);
	assert(a[] == [`alpha`, `beta`, `gamma`, `delta`, `epsilon`].s);

	a ~= b;
	assert(a[] == [`alpha`, `beta`, `gamma`, `delta`, `epsilon`, `epsilon`].s);
}

/// convert to string
version (none)				   /+ TODO: make this work +/
unittest {
	alias T = int;
	alias A = DynamicArray!(T);
	DynamicArray!char sink;
	A([1, 2, 3]).toString(sink.put);
}

/// iteration over mutable elements
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([1, 2, 3].s);
	foreach (const i, const e; a)
		assert(i + 1 == e);
}

/// iteration over `const`ant elements
pure nothrow @safe @nogc unittest {
	alias T = const(int);
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([1, 2, 3].s);
	foreach (const i, const e; a)
		assert(i + 1 == e);
}

/// iteration over immutable elements
pure nothrow @safe @nogc unittest {
	alias T = immutable(int);
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([1, 2, 3].s);
	foreach (const i, const e; a)
		assert(i + 1 == e);
}

/// removal
pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);

	auto a = A([1, 2, 3].s);
	assert(a == [1, 2, 3].s);

	assert(a.takeFront() == 1);
	assert(a == [2, 3].s);

	a.popAt(1);
	assert(a == [2].s);

	a.popAt(0);
	assert(a == []);

	a.insertBack(11);
	assert(a == [11].s);

	assert(a.takeBack == 11);

	a.insertBack(17);
	assert(a == [17].s);
	a.popBack();
	assert(a.length == 0);

	a.insertBack([11, 12, 13, 14, 15].s[]);
	a.popAt(2);
	assert(a == [11, 12, 14, 15].s);
	a.popAt(0);
	assert(a == [12, 14, 15].s);
	a.popAt(2);

	assert(a == [12, 14].s);

	a ~= a;
}

/// removal
pure nothrow @safe unittest {
	import nxt.container.traits : mustAddGCRange;

	size_t mallocCount = 0;
	size_t freeCount = 0;

	struct S {
		pure nothrow @safe @nogc:
		alias E = int;
		import nxt.qcmeman : malloc, free;
		this(E x) @trusted {
			_ptr = cast(E*)malloc(E.sizeof);
			mallocCount += 1;
			*_ptr = x;
		}
		this(this) @disable;
		~this() nothrow @trusted @nogc {
			free(_ptr);
			freeCount += 1;
		}
		import nxt.gc_traits : NoGc;
		@NoGc E* _ptr;
	}

	/* D compilers cannot currently move stuff efficiently when using
	   std.algorithm.mutation.move. A final dtor call to the cleared sourced is
	   always done.
	*/
	const size_t extraDtor = 1;

	alias A = DynamicArray!(S, TestAllocator);
	static assert(!mustAddGCRange!A);
	alias AA = DynamicArray!(A, TestAllocator);
	static assert(!mustAddGCRange!AA);

	assert(mallocCount == 0);

	{
		A a;
		a.insertBack(S(11));
		assert(mallocCount == 1);
		assert(freeCount == extraDtor + 0);
	}

	assert(freeCount == extraDtor + 1);

	// assert(a.front !is S(11));
	// assert(a.back !is S(11));
	// a.insertBack(S(12));
}

/// test `OutputRange` behaviour with std.format
version (none)				   /+ TODO: replace with other exercise of std.format +/
@safe pure /*TODO: nothrow @nogc*/ unittest {
	import std.format : formattedWrite;
	const x = "42";
	alias A = DynamicArray!(char);
	A a;
	a.formattedWrite!("x : %s")(x);
	assert(a == "x : 42");
}

pure nothrow @safe @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator, uint);
	const a = A(17);
	assert(a[] == [17].s);
}

/// check duplication via `dupShallow`
@trusted pure nothrow @nogc unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);
	static assert(!__traits(compiles, { A b = a; })); // copying disabled
	auto a = A([10,11,12].s);
	auto b = a.dupShallow;
	assert(a == b);
	assert(&a[0] !is &b[0]);
}

/// element type is a class
pure nothrow @safe unittest {
	class T {
		this (int x) { this.x = x; }
		~this() nothrow @nogc { x = 42; }
		int x;
	}
	alias A = DynamicArray!(T, TestAllocator);
	auto a = A([new T(10), new T(11), new T(12)].s);
	assert(a.length == 3);
	a.remove!(_ => _.x == 12);
	assert(a.length == 2);
}

/// check filtered removal via `remove`
pure nothrow @safe @nogc unittest {
	struct T { int value; }
	alias A = DynamicArray!(T, TestAllocator);
	static assert(!__traits(compiles, { A b = a; })); // copying disabled

	auto a = A([T(10), T(11), T(12)].s);

	assert(a.remove!"a.value == 13" == 0);
	assert(a[] == [T(10), T(11), T(12)].s);

	assert(a.remove!"a.value >= 12" == 1);
	assert(a[] == [T(10), T(11)].s);

	assert(a.remove!(_ => _.value == 10) == 1);
	assert(a[] == [T(11)].s);

	assert(a.remove!(_ => _.value == 11) == 1);
	assert(a.length == 0);
}

/// construct from map range
pure nothrow @safe unittest {
	import std.algorithm.iteration : map;
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);

	A a = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => _^^2));
	assert(a[] == [100, 400, 900].s);
	a.popBackN(2);
	assert(a.length == 1);
	a.popBackN(1);
	assert(a.length == 0);

	A b = A([10, 20, 30].s[].map!(_ => _^^2));
	assert(b[] == [100, 400, 900].s);
	b.popBackN(2);
	assert(b.length == 1);
	b.popBackN(1);
	assert(b.length == 0);

	A c = A([10, 20, 30].s[]);
	assert(c[] == [10, 20, 30].s);
}

/// construct from map range
@trusted pure nothrow unittest {
	alias T = int;
	alias A = DynamicArray!(T, TestAllocator);

	import std.typecons : RefCounted;
	RefCounted!A x;

	auto z = [1, 2, 3].s;
	x ~= z[];

	auto y = x;
	assert(y[] == z);

	const _ = x.toHash;
}

/// construct from static array
@trusted pure nothrow @nogc unittest {
	alias T = uint;
	alias A = DynamicArray!(T, TestAllocator);

	ushort[3] a = [1, 2, 3];

	const x = A(a);
	assert(x == a);
	assert(x == a[]);
}

/// construct from static array slice
@trusted pure nothrow @nogc unittest {
	alias T = uint;
	alias A = DynamicArray!(T, TestAllocator);
	ushort[3] a = [1, 2, 3];
	ushort[] b = a[];
	const y = A(b); // cannot construct directly from `a[]` because its type is `ushort[3]`
	assert(y == a);
	assert(y == a[]);
}

/// GCAllocator
@trusted pure nothrow unittest {
	import std.experimental.allocator.gc_allocator : GCAllocator;
	alias T = int;
	alias A = DynamicArray!(T, GCAllocator);
	const A a;
	assert(a.length == 0);
}

/// construct with slices as element types
@trusted pure nothrow unittest {
	alias A = DynamicArray!(string);
	const A a;
	assert(a.length == 0);
	alias B = DynamicArray!(char[]);
	const B b;
	assert(b.length == 0);
}

/** Variant of `DynamicArray` with copy construction (postblit) enabled.
 *
 * See_Also: suppressing.d
 * See_Also: http://forum.dlang.org/post/eitlbtfbavdphbvplnrk@forum.dlang.org
 */
struct BasicCopyableArray {
	/** TODO: implement using instructions at:
	 * http://forum.dlang.org/post/eitlbtfbavdphbvplnrk@forum.dlang.org
	 */
}

//+ TODO: Move to Phobos. +/
private enum bool isRefIterable(T) = is(typeof({ foreach (ref elem; T.init) {} }));

version (unittest) {
	import std.experimental.allocator.mallocator : TestAllocator = Mallocator;
	import nxt.array_help : s;
	import nxt.dip_traits : hasPreviewDIP1000;
	import nxt.construction : dupShallow;
	import nxt.debugio;
	private static struct Uncopyable { this(this) @disable; int _x; }
}
