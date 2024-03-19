import core.stdc.stdio: printf;
import core.memory : GC, pureMalloc, pureCalloc, pureFree;
import std.stdio;
import core.time : Duration;
import std.datetime.stopwatch : benchmark;

/// Small slot sizes classes (in bytes).
static immutable smallSizeClasses = [8,
									 16, /+ TODO: 16 + 8, +/
									 32, /+ TODO: 32 + 16, +/
									 64, /+ TODO: 64 + 32, +/
									 128, /+ TODO: 128 +64, +/
									 256, /+ TODO: 256 + 128, +/
									 512, /+ TODO: 512 + 256, +/
									 1024, /+ TODO: 1024 + 512, +/
									 2048, /+ TODO: 2048 + 1024, +/
	];

extern (C) @safe pure nothrow
{
	static foreach (sizeClass; smallSizeClasses)
	{
		/* TODO: Since https://github.com/dlang/dmd/pull/8813 we can now use:
		 * `mixin("gc_tlmalloc_", sizeClass);` for symbol generation.
		 */
		mixin("void* gc_tlmalloc_" ~ sizeClass.stringof ~ "(uint ba = 0);");
	}
}

void main(string[] args)
{
	benchmarkEnableDisable();
	/* All but last, otherwise new C() fails below because it requires one extra
	 * word for type-info. */
	writeln(" size new-C new-S GC.malloc+E gc_tlmalloc_N+E GC.calloc malloc calloc FreeList!(GCAllocator)");
	static foreach (byteSize; smallSizeClasses[0 .. $ - 1])
	{
		{
			enum wordCount = byteSize/8;
			benchmarkAllocation!(ulong, wordCount)();
		}
	}
	GC.collect();
	writeln("  ns/w: nanoseconds per word");
}

static immutable benchmarkCount = 1000;
static immutable iterationCount = 100;

/** Benchmark a single `new`-allocation of `T` using GC.
 */
size_t benchmarkAllocation(E, uint n)() @trusted
{
	import core.internal.traits : hasElaborateDestructor;
	import std.traits : hasIndirections;
	import core.lifetime : emplace;

	alias A = E[n];
	struct T { A a; }
	class C { A a; }
	static assert(!hasElaborateDestructor!C); // shouldn't need finalizer
	enum ba = (!hasIndirections!T) ? GC.BlkAttr.NO_SCAN : 0;

	size_t ptrSum;

	void doNewClass() @trusted pure nothrow /+ TODO: this crashes +/
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = new C();   // allocates: `__traits(classInstanceSize, C)` bytes
			ptrSum ^= cast(size_t)(cast(void*)x); // side-effect
		}
	}

	void doNewStruct() @trusted pure nothrow
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = new T();
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	void doGCMalloc() @trusted pure nothrow
	{
		foreach (const i; 0 .. iterationCount)
		{
			T* x = cast(T*)GC.malloc(T.sizeof, ba);
			emplace!(T)(x);
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	void doGCNMalloc(int n)() @trusted pure nothrow
	{
		foreach (const i; 0 .. iterationCount)
		{
			/* TODO: Since https://github.com/dlang/dmd/pull/8813 we can now use:
			 * `mixin("gc_tlmalloc_", sizeClass);` for symbol generation.
			 */
			mixin(`T* x = cast(T*)gc_tlmalloc_` ~ n.stringof ~ `(ba);`);
			emplace!(T)(x);
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	void doGCCalloc() @trusted pure nothrow
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = GC.calloc(T.sizeof, ba);
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	void doMalloc() @trusted pure nothrow @nogc
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = pureMalloc(T.sizeof);
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	void doCalloc() @trusted pure nothrow @nogc
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = pureCalloc(T.sizeof, 1);
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	import std.experimental.allocator.gc_allocator : GCAllocator;
	import std.experimental.allocator.building_blocks.free_list : FreeList;
	FreeList!(GCAllocator, T.sizeof) allocator;

	void doAllocatorFreeList() @trusted pure nothrow
	{
		foreach (const i; 0 .. iterationCount)
		{
			auto x = allocator.allocate(T.sizeof).ptr;
			ptrSum ^= cast(size_t)x; // side-effect
		}
	}

	GC.disable();
	const results = benchmark!(doNewClass,
							   doNewStruct,
							   doGCMalloc,
							   doGCNMalloc!(T.sizeof),
							   doGCCalloc,
							   doMalloc,
							   doCalloc,
							   doAllocatorFreeList)(benchmarkCount);
	GC.enable();

	writef(" %4s  %4.1f  %4.1f	%4.1f			%4.1f		%4.1f	 %4.1f   %4.1f   %4.1f",
		   T.sizeof,
		   cast(double)results[0].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[1].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[2].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[3].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[4].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[5].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[6].total!"nsecs"/(benchmarkCount*iterationCount*n),
		   cast(double)results[7].total!"nsecs"/(benchmarkCount*iterationCount*n),
		);

	writeln();

	return ptrSum;			  // side-effect
}

/** Benchmark a single call to enable and disable() using `GC`.
 */
void benchmarkEnableDisable() @safe
{
	void doEnableDisable() @trusted
	{
		foreach (const i; 0 .. iterationCount)
		{
			GC.enable();
			GC.disable();
		}
	}

	const Duration[1] results = benchmark!(doEnableDisable)(benchmarkCount);

	writefln("- enable()-disable(): %s ns",
			 cast(double)results[0].total!"nsecs"/(benchmarkCount*iterationCount));
}
