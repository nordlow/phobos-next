module nxt.container.fixed_dynamic_array;

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.common : isAllocator;

/** Dynamically allocated (heap) array with fixed length.
	TODO: Move as many of members as possible to `FixedArrayStore`.
 */
struct FixedDynamicArray(T, Allocator = Mallocator)
if (isAllocator!Allocator) {
@safe:
	import core.exception : onOutOfMemoryError;
	import core.memory : pureMalloc, pureFree; /+ TODO: replace with `Allocator` +/
	import std.traits : hasFunctionAttributes;

pragma(inline, true):

	/** Make and return uninitialized array of `length`.
	 *
	 * Unlike `@trusted pureMalloc` this must be `@system` because the return
	 * value of this factory function can be accessed in @safe code.
	 */
	static typeof(this) makeUninitializedOfLength(size_t length) @system {
		version (DigitalMars) pragma(inline, false); // DMD cannot inline
		auto ptr = pureMalloc(length * T.sizeof);
		if (ptr is null && length >= 1)
			onOutOfMemoryError();
		return typeof(return)(FixedArrayStore(length, cast(T*)ptr));
	}

	/// Construct from `store`.
	private this(FixedArrayStore store) {
		_store = store;
	}

	/// Construct uninitialized array of `length`.
	private this(in size_t length) @system {
		_store.length = length;
		auto ptr = pureMalloc(length * T.sizeof);
		if (ptr is null &&
			length >= 1)
			onOutOfMemoryError();
		_store.ptr = cast(T*)ptr;
	}

	/// Destruct.
	~this() nothrow @trusted @nogc {
		pureFree(_store.ptr);
	}

	// disable copying
	this(this) @disable;

	/// Get element at index `i`.
	ref inout(T) opIndex(size_t i) inout @trusted return scope
		=> (*(cast(inout(T)[]*)&_store))[i];

	/// Slice support.
	inout(T)[] opSlice(size_t i, size_t j) inout @trusted return scope
		=> (*(cast(inout(T)[]*)&_store))[i .. j];
	/// ditto
	inout(T)[] opSlice() inout @trusted return scope
		=> (*(cast(inout(T)[]*)&_store))[0 .. _store.length];

	/// Slice assignment support.
	T[] opSliceAssign(U)(U value) return scope
		=> (*(cast(inout(T)[]*)&_store))[0 .. _store.length] = value;
	/// ditto
	T[] opSliceAssign(U)(U value, size_t i, size_t j) return scope
		=> (*(cast(inout(T)[]*)&_store))[i .. j] = value;

private:
	static struct FixedArrayStore { /+ TODO: move to `array_store.FixedArrayStore` +/
		size_t length;
		static if (hasFunctionAttributes!(Allocator.allocate, "@nogc")) {
			import nxt.gc_traits : NoGc;
			@NoGc T* ptr;	   // non-GC-allocated
		} else
			T* ptr;			 // GC-allocated
	}
	FixedArrayStore _store;
}

@safe pure nothrow @nogc unittest {
	alias A = FixedDynamicArray!(int);
	auto y = A();
	// assert(y.length = 0);
}

@trusted pure nothrow @nogc unittest {
	auto x = FixedDynamicArray!(int).makeUninitializedOfLength(7);
	x[0] = 11;
	assert(x[0] == 11);
}

version (unittest) {
	import nxt.array_help : s;
}
