/**
 * Array container with paged allocation for internal usage.
 *
 * Copyright: Copyright Per Nordlöw 2018.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Per Nordlöw
 */
module paged_dynamic_array;

import core.stdc.stdio: printf;

// version = PRINTF;

private static void *os_mem_map(size_t nbytes) nothrow @nogc
{   void *p;

	import core.sys.posix.sys.mman;
	p = mmap(null, nbytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
	return (p == MAP_FAILED) ? null : p;
}

private static int os_mem_unmap(void *base, size_t nbytes) nothrow @nogc
{
	import core.sys.posix.sys.mman;
	return munmap(base, nbytes);
}

private enum PAGESIZE = 4096;	// Linux $(shell getconf PAGESIZE)

struct PagedDynamicArray(T)
{
	import core.internal.traits : hasElaborateDestructor;
	import core.exception : onOutOfMemoryErrorNoGC;

	@safe nothrow @nogc:

	this(this) @disable;

	~this()
	{
		reset();
	}

	void reset()
	{
		length = 0;
	}

	@property size_t length() const
	{
		return _length;
	}

	@property size_t capacityInBytes() const
	{
		version (D_Coverage) {} else pragma(inline, true);
		return _capacityInPages*PAGESIZE;
	}

	/// Set length to `newLength`.
	@property void length(in size_t newLength) @trusted
	{
		if (newLength == 0)	 // if zero `newLength` free stuff
		{
			version (PRINTF) printf("### %s() zeroed\n", __FUNCTION__.ptr);
			if (_ptr != null)
			{
				os_mem_unmap(_ptr, capacityInBytes);
				_ptr = null;
			}
			_capacityInPages = 0;
		}
		else
		{
			capacity = newLength; // set capacity
		}
		_length = newLength;
	}

	/// Set capacity to `newCapacity`.
	@property void capacity(in size_t newCapacity) @trusted
	{
		import core.checkedint : mulu;

		if (newCapacity*T.sizeof > capacityInBytes) // common case first
		{
			bool overflow = false;
			const size_t reqsize = mulu(T.sizeof, newCapacity, overflow);
			const size_t newCapacityInPages = (reqsize + PAGESIZE - 1) / PAGESIZE;
			version (PRINTF) printf("### %s() newCapacityInPages:%lu\n", __FUNCTION__.ptr, newCapacityInPages);
			if (overflow)
			{
				onOutOfMemoryErrorNoGC();
			}

			static if (hasElaborateDestructor!T)
			{
				static assert("destroy T");
				//
				// if (newLength < _length)
				// {
				//	 foreach (ref val; _ptr[newLength .. _length])
				//	 {
				//		 common.destroy(val);
				//	 }
				// }
			}

			const newCapacityInBytes = newCapacityInPages*PAGESIZE;

			T* newPtr;
			version (linux)
			{
				if (_ptr !is null)  // if should do remap
				{
					version (PRINTF) printf("### %s() mremap(%p)\n", __FUNCTION__.ptr, _ptr);
					_ptr = cast(T*)mremap(_ptr, capacityInBytes,
										  newCapacityInBytes,
										  MREMAP_MAYMOVE);
					goto done;
				}
			}

			newPtr = cast(T*)os_mem_map(newCapacityInBytes);
			import core.stdc.string : memcpy;
			if (_ptr !is null)
			{
				memcpy(newPtr, _ptr, capacityInBytes); /+ TODO: can we copy pages faster than this? +/
				os_mem_unmap(_ptr, capacityInBytes);
			}
			_ptr = newPtr;

		done:
			_capacityInPages = newCapacityInPages;

			// rely on mmap zeroing for us
			// if (newLength > _length)
			// {
			//	 foreach (ref val; _ptr[_length .. newLength])
			//	 {
			//		 common.initialize(val);
			//	 }
			// }
		}
	}

	bool empty() const @property
	{
		return !length;
	}

	@property ref inout(T) front() inout
	in { assert(!empty); }
	do
	{
		return _ptr[0];
	}

	@property ref inout(T) back() inout @trusted
	in { assert(!empty); }
	do
	{
		return _ptr[_length - 1];
	}

	ref inout(T) opIndex(size_t idx) inout @trusted
	in { assert(idx < length); }
	do
	{
		return _ptr[idx];
	}

	inout(T)[] opSlice() inout @trusted
	{
		return _ptr[0 .. _length];
	}

	inout(T)[] opSlice(size_t a, size_t b) inout @trusted
	in { assert(a < b && b <= length); }
	do
	{
		return _ptr[a .. b];
	}

	inout(T)* ptr() inout @system
	{
		return _ptr;
	}

	alias length opDollar;

	void insertBack()(auto ref T val) @trusted
	{
		import core.checkedint : addu;
		bool overflow = false;
		const size_t newlength = addu(length, 1, overflow);
		if (overflow)
		{
			onOutOfMemoryErrorNoGC();
		}
		length = newlength;
		back = val;
	}

	void popBack() @system
	{
		if (hasElaborateDestructor!T)
		{
			// destroy back element
		}
		length = length - 1;
	}

	void remove(size_t idx) @system
	in { assert(idx < length); }
	do
	{
		if (hasElaborateDestructor!T)
		{
			// destroy `idx`:th element
		}
		foreach (i; idx .. length - 1)
			_ptr[i] = _ptr[i+1]; /+ TODO: move if hasElaborateDestructor!T +/
		popBack();
	}

	invariant
	{
		/+ TODO: assert(!_ptr == !_length); +/
	}

private:
	T* _ptr;
	size_t _length;
	size_t _capacityInPages;	// of size `PAGESIZE`
}

version (linux)
{
	enum MREMAP_MAYMOVE = 1;
	nothrow @nogc:
	extern(C) void *mremap(void *old_address, size_t old_size,
						   size_t new_size, int flags, ... /* void *new_address */);

}

unittest {
	PagedDynamicArray!size_t ary;

	assert(ary[] == []);
	ary.insertBack(5);
	assert(ary[] == [5]);
	assert(ary[$-1] == 5);
	ary.popBack();
	assert(ary[] == []);
	ary.insertBack(0);
	ary.insertBack(1);
	assert(ary[] == [0, 1]);
	assert(ary[0 .. 1] == [0]);
	assert(ary[1 .. 2] == [1]);
	assert(ary[$ - 2 .. $] == [0, 1]);
	size_t idx;
	foreach (val; ary) assert(idx++ == val);
	foreach_reverse (val; ary) assert(--idx == val);
	foreach (i, val; ary) assert(i == val);
	foreach_reverse (i, val; ary) assert(i == val);

	ary.insertBack(2);
	ary.remove(1);
	assert(ary[] == [0, 2]);

	assert(!ary.empty);
	ary.reset();
	assert(ary.empty);
	ary.insertBack(0);
	assert(!ary.empty);
	destroy(ary);
	assert(ary.empty);

	// not copyable
	static assert(!__traits(compiles, { PagedDynamicArray!size_t ary2 = ary; }));
	PagedDynamicArray!size_t ary2;
	static assert(!__traits(compiles, ary = ary2));
	static void foo(PagedDynamicArray!size_t copy) {}
	static assert(!__traits(compiles, foo(ary)));

	ary2.insertBack(0);
	assert(ary.empty);
	assert(ary2[] == [0]);
}

unittest {
	import core.exception;
	try
	{
		// Overflow ary.length.
		auto ary = PagedDynamicArray!size_t(cast(size_t*)0xdeadbeef, -1);
		ary.insertBack(0);
	}
	catch (OutOfMemoryError)
	{
	}
	try
	{
		// Overflow requested memory size for common.xrealloc().
		auto ary = PagedDynamicArray!size_t(cast(size_t*)0xdeadbeef, -2);
		ary.insertBack(0);
	}
	catch (OutOfMemoryError)
	{
	}
}
