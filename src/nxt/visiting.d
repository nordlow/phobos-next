/++ Types for keeping track of visited elements.
 +/
module nxt.visiting;

@safe:

/++ Is `true` iff `T` support slicing and `~=`.
 +/
enum isVisitSet(T) = is(typeof(T.init[]));

/++ Visited addresses (pointers).
	Typically used in recursion during pretty-printing and serialization
	of cyclic data structures.
 +/
version (D_Optimized) {
	import std.array : Appender;
	/* TODO: instead use `nxt.container.sorted.Sorted!(Ptrs)` or
	   nxt.container.hybrid_hashmap.HybridHashMap!(Ptrs)`
	   in release mode .
     */
	/+ TODO: Use `nxt.container.dynamic_array` instead. +/
	alias Addresses = Appender!(const(void)*[]);
} else {
	/+ TODO: Use `nxt.fast_appender.FastAppender`. +/
	alias Addresses = const(void)*[];
}

static assert(isVisitSet!Addresses);
