/** A GC with segregated allocations using D's `static foreach`.
 *
 * Copyright: Copyright Per Nordlöw 2019 - .
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Per Nordlöw
 */
module segregated_gc;

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

// import gc.os : os_mem_map, os_mem_unmap;

import core.gc.config;
import core.gc.gcinterface;

import paged_dynamic_array : Array = PagedDynamicArray;
import simple_static_bitarray : StaticBitArray;

import core.stdc.stdio: printf;
import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;
static import core.memory;

/* debug = PRINTF; */

extern (C) void onOutOfMemoryError(void* pretend_sideffect = null) @trusted pure nothrow @nogc; /* dmd @@@BUG11461@@@ */

private
{
	extern (C)
	{
		// to allow compilation of this module without access to the rt package,
		//  make these functions available from rt.lifetime
		void rt_finalizeFromGC(void* p, size_t size, uint attr) nothrow;
		int rt_hasFinalizerInSegment(void* p, size_t size, uint attr, const scope void[] segment) nothrow;

		// Declared as an extern instead of importing core.exception
		// to avoid inlining - see issue 13725.
		void onInvalidMemoryOperationError() @nogc nothrow;
		void onOutOfMemoryErrorNoGC() @nogc nothrow;
	}
}

enum WORDSIZE = size_t.sizeof;  ///< Size of word type (size_t).
enum PAGESIZE = 4096;		   ///< Page size in bytes. Linux $(shell getconf PAGESIZE).

/// Small slot sizes classes (in bytes).
static immutable smallSizeClasses = [8,
									 16,
									 24, /+ TODO: move +/
									 32,
									 40, /+ TODO: move +/
									 48, /+ TODO: move +/
									 56, /+ TODO: move +/
									 64,
									 72,
									 80,
									 88,
									 96, /+ TODO: move +/
									 104, /+ TODO: move +/
									 112, /+ TODO: move +/
									 120, /+ TODO: move +/
									 128, /+ TODO: 128 +64, +/
									 256, /+ TODO: 256 + 128, +/
									 512, /+ TODO: 512 + 256, +/
									 1024, /+ TODO: 1024 + 512, +/
									 2048, /+ TODO: 2048 + 1024, +/
	];

/// Medium slot sizes classes (in bytes).
version (none)
static immutable mediumSizeClasses = [1 << 12, // 4096
									  1 << 13, // 8192
									  1 << 14, // 16384
									  1 << 15, // 32768
									  1 << 16, // 65536
	];

/// Ceiling to closest to size class of `sz`.
size_t ceilPow2(size_t sz) pure nothrow @safe @nogc
{
	return nextPow2(sz - 1);
}

pure nothrow @safe @nogc unittest {
	/+ TODO: assert(ceilPow2(1) == 1); +/
	assert(ceilPow2(2) == 2);
	assert(ceilPow2(3) == 4);
	assert(ceilPow2(4) == 4);
	assert(ceilPow2(5) == 8);
	assert(ceilPow2(6) == 8);
	assert(ceilPow2(7) == 8);
	assert(ceilPow2(8) == 8);
	assert(ceilPow2(9) == 16);
}

/// Small slot foreach slot contains `wordCount` machine words.
struct SmallSlot(uint wordCount)
if (wordCount >= 1)
{
	size_t[wordCount] words;	// words
}

pure nothrow @safe @nogc unittest {
	SmallSlot!(1) x;
	SmallSlot!(1) y;
}

/// Small page storing slots of size `sizeClass`.
struct SmallPage(uint sizeClass)
if (sizeClass >= smallSizeClasses[0])
{
	enum wordCount = sizeClass/WORDSIZE;
	static assert(sizeClass % WORDSIZE == 0, sizeClass);
	enum slotCount = PAGESIZE/sizeClass;
	alias Slot = SmallSlot!(wordCount);

	Slot[slotCount] slots;
	byte[PAGESIZE-slots.sizeof] __padding;
	static assert(this.sizeof == PAGESIZE); /+ TODO: adjust if pages of different byte sizes are preferred +/
}
enum minimumSmallPageWordCount = PAGESIZE/WORDSIZE; /+ TODO: may be computed +/

struct SmallPageTable(uint sizeClass)
{
	alias Page = SmallPage!(sizeClass);
	Page* pagePtr;
	enum slotCount = PAGESIZE/sizeClass;

	// bit `i` indicates if slot `i` in `*pagePtr` currently contains an initialized value
	StaticBitArray!(slotCount) slotUsages; /+ TODO: benchmark with a byte-array instead for comparison +/

	// bit `i` indicates if slot `i` in `*pagePtr` has been marked
	StaticBitArray!(slotCount) slotMarks;
}

/// Small pool of pages.
struct SmallPool(uint sizeClass, bool pointerFlag)
if (sizeClass >= smallSizeClasses[0])
{
	alias Page = SmallPage!(sizeClass);

	this(size_t pageTableCapacity)
	{
		pageTables.capacity = pageTableCapacity;
	}

	void* allocateNext() @trusted // pure nothrow @nogc
	{
		version (LDC) pragma(inline, true);

		/+ TODO: scan `slotUsages` at slotIndex using core.bitop.bsf to find +/
		// first free page if any. Use modification of `indexOfFirstOne` that
		// takes startIndex being `slotIndex` If no hit set `slotIndex` to
		// `Page.slotCount`
		/+ TODO: instead of this find next set bit at `slotIndex` in +/
		// `slotUsages` unless whole current `slotUsages`-word is all zero.

		immutable pageIndex = slotIndex / Page.slotCount;
		immutable needNewPage = (slotIndex % Page.slotCount == 0);

		if (needNewPage)
		{
			Page* pagePtr = cast(Page*)os_mem_map(PAGESIZE);
			debug(PRINTF) printf("### %s(): pagePtr:%p\n", __FUNCTION__.ptr, pagePtr);
			pageTables.insertBack(SmallPageTable!sizeClass(pagePtr));

			pageTables.ptr[pageIndex].slotUsages[0] = true; // mark slot

			debug(PRINTF) printf("### %s(): slotIndex:%lu\n", __FUNCTION__.ptr, 0);

			auto slotPtr = pagePtr.slots.ptr; // first slot
			slotIndex = 1;
			return slotPtr;
		}
		else
		{
			debug(PRINTF) printf("### %s(): slotIndex:%lu\n", __FUNCTION__.ptr, slotIndex);
			pageTables.ptr[pageIndex].slotUsages[slotIndex] = true; // mark slot
			return &pageTables.ptr[pageIndex].pagePtr.slots.ptr[slotIndex++];
		}
	}

	Array!(SmallPageTable!sizeClass) pageTables;
	size_t slotIndex = 0;	   // index to first free slot in pool across multiple page
}

/+ TODO: pure nothrow @safe @nogc +/
unittest {
	static foreach (sizeClass; smallSizeClasses)
	{
		{
			SmallPool!(sizeClass, false) x;
		}
	}
}

/// All small pools.
struct SmallPools
{
	this(size_t pageTableCapacity)
	{
		static foreach (sizeClass; smallSizeClasses)
		{
			// Quote from https://olshansky.me/gc/runtime/dlang/2017/06/14/inside-d-gc.html
			// "Fine grained locking from the start, I see no problem with per pool locking."
			mixin(`this.unscannedPool` ~ sizeClass.stringof ~ ` = SmallPool!(sizeClass, false)(pageTableCapacity);`);
			mixin(`this.scannedPool`	~ sizeClass.stringof ~ ` = SmallPool!(sizeClass, true)(pageTableCapacity);`);
		}
	}
	BlkInfo qalloc(size_t size, uint bits) nothrow
	{
		debug(PRINTF) printf("### %s(size:%lu, bits:%u)\n", __FUNCTION__.ptr, size, bits);

		BlkInfo blkinfo = void;
		blkinfo.attr = bits;

		/+ TODO: optimize this: +/
		blkinfo.size = ceilPow2(size);
		if (blkinfo.size < smallSizeClasses[0])
			blkinfo.size = smallSizeClasses[0];

	top:
		switch (blkinfo.size)
		{
			static foreach (sizeClass; smallSizeClasses)
			{
			case sizeClass:
				if (bits & BlkAttr.NO_SCAN) // no scanning needed
					mixin(`blkinfo.base = unscannedPool` ~ sizeClass.stringof ~ `.allocateNext();`);
				else
					mixin(`blkinfo.base = scannedPool` ~ sizeClass.stringof ~ `.allocateNext();`);
				break top;
			}
		default:
			blkinfo.base = null;
			printf("### %s(size:%lu, bits:%u) Cannot handle blkinfo.size:%lu\n", __FUNCTION__.ptr, size, bits, blkinfo.size);
			/+ TODO: find closest match of blkinfo.size <= smallSizeClasses +/
			onOutOfMemoryError();
			assert(0, "Handle other blkinfo.size");
		}

		return blkinfo;
	}
private:
	static foreach (sizeClass; smallSizeClasses)
	{
		// Quote from https://olshansky.me/gc/runtime/dlang/2017/06/14/inside-d-gc.html
		// "Fine grained locking from the start, I see no problem with per pool locking."
		mixin(`SmallPool!(sizeClass, false) unscannedPool` ~ sizeClass.stringof ~ `;`);
		mixin(`SmallPool!(sizeClass, true) scannedPool` ~ sizeClass.stringof ~ `;`);
	}
}
// pragma(msg, "SmallPools.sizeof: ", SmallPools.sizeof);

enum pageTableCapacityDefault = 256*PAGESIZE; // eight pages

struct Gcx
{
	this(size_t pageTableCapacity) // 1 one megabyte per table
	{
		this.smallPools = SmallPools(pageTableCapacity);
	}
	Array!Root roots;
	Array!Range ranges;
	SmallPools smallPools;
	uint disabled; // turn off collections if >0
}

Gcx tlGcx;					  // thread-local allocator instance
static this()
{
	tlGcx = Gcx(pageTableCapacityDefault);
}

// size class specific overloads only for thread-local GC
extern (C)
{
	static foreach (sizeClass; smallSizeClasses)
	{
		/* TODO: use template `mixin` containing, in turn, a `mixin` for generating
		 * the symbol names `gc_tlmalloc_32`, `unscannedPool32` and
		 * `scannedPool32` for sizeClass `32`.
		 *
		 * TODO: Since https://github.com/dlang/dmd/pull/8813 we can now use:
		 * `mixin("gc_tlmalloc_", sizeClass);` for symbol generation
		 */
		mixin(`
		void* gc_tlmalloc_` ~ sizeClass.stringof ~ `(uint ba = 0) @trusted nothrow
		{
			if (ba & BlkAttr.NO_SCAN) // no scanning needed
				return tlGcx.smallPools.unscannedPool` ~ sizeClass.stringof ~ `.allocateNext();
			else
				return tlGcx.smallPools.scannedPool` ~ sizeClass.stringof ~ `.allocateNext();
		}
`);
	}
}

class SegregatedGC : GC
{
	import core.internal.spinlock;
	static gcLock = shared(AlignedSpinLock)(SpinLock.Contention.lengthy);
	static bool _inFinalizer;

	// global allocator (`__gshared`)
	__gshared Gcx gGcx;

	// lock GC, throw InvalidMemoryOperationError on recursive locking during finalization
	static void lockNR() @nogc nothrow
	{
		if (_inFinalizer)
			onInvalidMemoryOperationError();
		gcLock.lock();
	}

	void initialize()
	{
		printf("### %s()\n", __FUNCTION__.ptr);

		import core.stdc.string;
		auto p = cstdlib.malloc(__traits(classInstanceSize, SegregatedGC));
		if (!p)
			onOutOfMemoryError();

		auto init = typeid(SegregatedGC).initializer();
		assert(init.length == __traits(classInstanceSize, SegregatedGC));
		auto instance = cast(SegregatedGC)memcpy(p, init.ptr, init.length);
		instance.__ctor();

		instance.gGcx = Gcx(pageTableCapacityDefault);
	}

	void finalize()
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
	}

	this()
	{
	}

	void enable()
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		static void go(Gcx* tlGcx) nothrow
		{
			tlGcx.disabled--;
		}
		runLocked!(go)(&tlGcx);
	}

	void disable()
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		static void go(Gcx* tlGcx) nothrow
		{
			tlGcx.disabled++;
		}
		runLocked!(go)(&tlGcx);
	}

	auto runLocked(alias func, Args...)(auto ref Args args)
	{
		debug(PROFILE_API) immutable tm = (config.profile > 1 ? currTime.ticks : 0);
		lockNR();
		scope (failure) gcLock.unlock();
		debug(PROFILE_API) immutable tm2 = (config.profile > 1 ? currTime.ticks : 0);

		static if (is(typeof(func(args)) == void))
			func(args);
		else
			auto res = func(args);

		debug(PROFILE_API) if (config.profile > 1) { lockTime += tm2 - tm; }
		gcLock.unlock();

		static if (!is(typeof(func(args)) == void))
			return res;
	}

	void collect() nothrow
	{
		printf("### %s: \n", __FUNCTION__.ptr);
	}

	void collectNoStack() nothrow
	{
		printf("### %s: \n", __FUNCTION__.ptr);
	}

	void minimize() nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
	}

	uint getAttr(void* p) nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		return 0;
	}

	uint setAttr(void* p, uint mask) nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		return 0;
	}

	uint clrAttr(void* p, uint mask) nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		return 0;
	}

	void* malloc(size_t size, uint bits, scope const(TypeInfo) ti) nothrow
	{
		debug(PRINTF) printf("### %s(size:%lu, bits:%u)\n", __FUNCTION__.ptr, size, bits);
		lockNR();
		scope (failure) gcLock.unlock(); /+ TODO: why needed? +/
		void* p = gGcx.smallPools.qalloc(size, bits).base;
		gcLock.unlock();
		if (size && p is null)
			onOutOfMemoryError();
		return p;
	}

	BlkInfo qalloc(size_t size, uint bits, scope const(TypeInfo) ti) nothrow
	{
		debug(PRINTF) printf("### %s(size:%lu, bits:%u)\n", __FUNCTION__.ptr, size, bits);
		lockNR();
		scope (failure) gcLock.unlock(); /+ TODO: why needed? +/
		BlkInfo blkinfo = gGcx.smallPools.qalloc(size, bits);
		gcLock.unlock();
		if (size && blkinfo.base is null)
			onOutOfMemoryError();
		return blkinfo;
	}

	void* calloc(size_t size, uint bits, scope const(TypeInfo) ti) nothrow
	{
		debug(PRINTF) printf("### %s(size:%lu, bits:%u)\n", __FUNCTION__.ptr, size, bits);
		lockNR();
		scope (failure) gcLock.unlock();
		void* p = gGcx.smallPools.qalloc(size, bits).base;
		gcLock.unlock();
		if (size && p is null)
			onOutOfMemoryError();
		import core.stdc.string : memset;
		memset(p, 0, size);	 // zero
		// why is this slower than memset? (cast(size_t*)p)[0 .. size/size_t.sizeof] = 0;
		return p;
	}

	void* realloc(void* p, size_t size, uint bits, scope const(TypeInfo) ti) nothrow
	{
		debug(PRINTF) printf("### %s(p:%p, size:%lu, bits:%u)\n", __FUNCTION__.ptr, p, size, bits);
		p = cstdlib.realloc(p, size);
		if (size && p is null)
			onOutOfMemoryError();
		return p;
	}

	/**
	 * Attempt to in-place enlarge the memory block pointed to by p by at least
	 * minsize bytes, up to a maximum of maxsize additional bytes.
	 * This does not attempt to move the memory block (like realloc() does).
	 *
	 * Returns:
	 *  0 if could not extend p,
	 *  total size of entire memory block if successful.
	 */
	size_t extend(void* p, size_t minsize, size_t maxsize, scope const(TypeInfo) ti) nothrow
	{
		debug(PRINTF) printf("### %s(p:%p, minsize:%lu, maxsize:%lu)\n", __FUNCTION__.ptr, p, minsize, maxsize);
		return 0;
	}

	size_t reserve(size_t size) nothrow
	{
		debug(PRINTF) printf("### %s(size:%lu)\n", __FUNCTION__.ptr, size);
		return 0;
	}

	void free(void* p) nothrow @nogc
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		cstdlib.free(p);
	}

	/**
	 * Determine the base address of the block containing p.  If p is not a gc
	 * allocated pointer, return null.
	 */
	void* addrOf(void* p) nothrow @nogc
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		return null;
	}

	/**
	 * Determine the allocated size of pointer p.  If p is an interior pointer
	 * or not a gc allocated pointer, return 0.
	 */
	size_t sizeOf(void* p) nothrow @nogc
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		return 0;
	}

	/**
	 * Determine the base address of the block containing p.  If p is not a gc
	 * allocated pointer, return null.
	 */
	BlkInfo query(void* p) nothrow
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		return BlkInfo.init;
	}

	void addRoot(void* p) nothrow @nogc
	{
		printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		tlGcx.roots.insertBack(Root(p));
	}

	/**
	 * remove p from list of roots
	 */
	void removeRoot(void* p) nothrow @nogc
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		foreach (ref root; tlGcx.roots)
		{
			if (root is p)
			{
				root = tlGcx.roots.back;
				tlGcx.roots.popBack();
				return;
			}
		}
		assert(false);
	}

	@property RootIterator rootIter() return @nogc
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		return &rootsApply;
	}

	private int rootsApply(scope int delegate(ref Root) nothrow dg)
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		foreach (ref r; tlGcx.roots)
			if (auto result = dg(r))
				return result;
		return 0;
	}

	/**
	 * Add range to scan for roots.
	 */
	void addRange(void* p, size_t sz, scope const(TypeInfo) ti = null) nothrow @nogc
	{
		int x;
		printf("### %s(p:%p, sz:%lu ti:%p, stack:%p)\n", __FUNCTION__.ptr, p, sz, ti, &x);
		if (p is null)
			return;
		tlGcx.ranges.insertBack(Range(p, p + sz, cast() ti));
	}

	/**
	 * Remove range `p`.
	 */
	void removeRange(void* p) nothrow @nogc
	{
		debug(PRINTF) printf("### %s(p:%p)\n", __FUNCTION__.ptr, p);
		if (p is null)
			return;
		foreach (ref range; tlGcx.ranges)
		{
			if (range.pbot is p)
			{
				range = tlGcx.ranges.back;
				tlGcx.ranges.popBack();
				return;
			}
		}
		assert(false);
	}

	@property RangeIterator rangeIter() return @nogc
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		return &rangesApply;
	}

	private int rangesApply(scope int delegate(ref Range) nothrow dg)
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		foreach (ref range; tlGcx.ranges)
			if (auto result = dg(range))
				return result;
		return 0;
	}

	/**
	 * Run finalizers.
	 */
	void runFinalizers(const scope void[] segment) nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
	}

	bool inFinalizer() nothrow
	{
		return typeof(return).init;
	}

	/**
	 * Retrieve statistics about garbage collection.
	 * Useful for debugging and tuning.
	 */
	core.memory.GC.Stats stats() nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		/+ TODO: fill in +/
		return typeof(return)();
	}

	/**
	 * Retrieve profile statistics about garbage collection.
	 * Useful for debugging and tuning.
	 */
	core.memory.GC.ProfileStats profileStats() nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		/+ TODO: fill in +/
		return typeof(return)();
	}

	/**
	 * Returns the number of bytes allocated for the current thread
	 * since program start. It is the same as
	 * GC.stats().allocatedInCurrentThread, but faster.
	 */
	ulong allocatedInCurrentThread() nothrow
	{
		debug(PRINTF) printf("### %s: \n", __FUNCTION__.ptr);
		/+ TODO: fill in +/
		return typeof(return).init;
	}
}

private enum PowType
{
	floor,
	ceil
}

private T powIntegralImpl(PowType type, T)(T val)
{
	version (D_Coverage) {} else pragma(inline, true);
	import core.bitop : bsr;
	if (val == 0 ||
		(type == PowType.ceil &&
		 (val > T.max / 2 ||
		  val == T.min)))
		return 0;
	else
		return (T(1) << bsr(val) + type);
}

private T nextPow2(T)(const T val)
if (is(T == size_t) ||
	is(T == uint))
{
	return powIntegralImpl!(PowType.ceil)(val);
}
