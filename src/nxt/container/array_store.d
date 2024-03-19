module nxt.container.array_store;

import std.experimental.allocator.common : isAllocator;

@safe:

/++ Array storage.
 +/
struct ArrayStore(T, Allocator = GCAllocator, Capacity = size_t)
if (!is(immutable T == immutable bool) && // use `BitArray` instead for now
	(is(Capacity == ulong) || // three 64-bit words
	 is(Capacity == uint)) && // two 64-bit words
	isAllocator!Allocator) { /+ TODO: extract to separate D module ArrayStore +/
pragma(inline, true):

	this(T[] slice, in Capacity length) @trusted pure nothrow @nogc { // construct from slice
		static if (__traits(hasMember, this, "_slice"))
			_slice = slice;
		else {
			_ptr = slice.ptr;
			assert(slice.length <= Capacity.max);
			_capacity = cast(Capacity)slice.length; // trusted within this module. TODO: try to get rid of this
		}
		_length = length;
	}

	this(T* ptr, in Capacity capacityAndLength) @trusted pure nothrow @nogc {
		version (DigitalMars) pragma(inline, false);
		static if (__traits(hasMember, this, "_slice"))
			_slice = ptr[0 .. capacityAndLength];
		else {
			_ptr = ptr;
			_capacity = capacityAndLength;
		}
		_length = capacityAndLength;
	}

	this(T* ptr, in Capacity capacity, in Capacity length) @trusted pure nothrow @nogc {
		version (DigitalMars) pragma(inline, false);
		static if (__traits(hasMember, this, "_slice"))
			_slice = ptr[0 .. capacity];
		else {
			_ptr = ptr;
			_capacity = capacity;
		}
		_length = length;
	}

	inout(T)* ptr() inout @trusted pure nothrow @nogc {
		static if (__traits(hasMember, this, "_slice"))
			return _slice.ptr;
		else
			return _ptr;
	}

	Capacity capacity() const @trusted pure nothrow @nogc {
		static if (__traits(hasMember, this, "_slice"))
			return _slice.length;
		else
			return _capacity;
	}

	Capacity length() const @trusted pure nothrow @nogc {
		return _length;
	}

	inout(T)[] opSlice() inout @trusted pure nothrow @nogc {
		static if (__traits(hasMember, this, "_slice"))
			return _slice;
		else
			return _ptr[0 .. _capacity];
	}

package:
	import std.traits : hasFunctionAttributes;
	enum isNoGc = hasFunctionAttributes!(Allocator.allocate, "@nogc");
	static if (isNoGc)
		import nxt.gc_traits : NoGc;
	static if (is(Capacity == size_t)) {
		static if (isNoGc) {
			@NoGc T[] _slice; // non-GC-allocated
			/+ TODO: static assert(!mustAddGCRange!(typeof(slice))); +/
		} else
			T[] _slice; // GC-allocated
		Capacity _length;
	} else {
		static if (isNoGc)
			@NoGc T* _ptr; // non-GC-allocated
		else
			T* _ptr; // GC-allocated
		Capacity _capacity;
		Capacity _length;
	}
}
