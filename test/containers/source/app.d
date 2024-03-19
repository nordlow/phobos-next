void main()
{
	// standard storage
	import std.range : iota;
	import std.array : array, Appender_std = Appender;

	// shuffling
	import std.random : randomShuffle;

	// phobos allocators
	import std.experimental.allocator : theAllocator, processAllocator, RCIAllocator;
	import std.experimental.allocator.mallocator : Mallocator;
	import std.experimental.allocator.gc_allocator : GCAllocator;

	// phobos containers
	import std.container.array : Array_std = Array;
	import std.container.rbtree : RedBlackTree;
	import std.container.binaryheap : BinaryHeap;

	// mir containers
	import mir.string_map : StringMap;

	// automem containers
	import automem.vector : Automem_Vector = Vector;

	// emsi (dlang-community) containers
	import containers.dynamicarray : DynamicArray_emsi = DynamicArray;
	import containers.hashmap : HashMap_emsi = HashMap;
	import containers.hashset : HashSet_emsi = HashSet;
	import containers.openhashset : OpenHashSet_emsi = OpenHashSet;
	// too slow: import containers.simdset : SimdSet_emsi = SimdSet;

	// my containers
	import nxt.container.dynamic_array : DynamicArray;
	import nxt.container.sorted : Sorted;
	import nxt.array_help : toUbytes;
	import nxt.container.variant_arrays : VariantArrays;
	import std.experimental.allocator.mallocator : MyMallocator = Mallocator;
	import nxt.filters : DynamicDenseSetFilter;
	import nxt.container.hybrid_array : DynamicDenseSetFilterGrowableArray;
	import nxt.container.trie : RadixTreeSet, RadixTreeMap;
	import nxt.container.hybrid_hashmap : HybridHashMap, HybridHashSet, defaultKeyEqualPredOf;
	import nxt.sso_string : SSOString;
	import nxt.address : AlignedAddress;
	alias Address = AlignedAddress!1;

	// digests
	import std.digest.crc : std_CRC32 = CRC32, CRC64ECMA, CRC64ISO;
	// version (LDC)
	// 	import crc32c_sse42 : CRC32c;
	version (DigitalMars)
		import crc32c_sse42 : CRC32c;
	else
		alias CRC32c = std_CRC32;
	import std.digest.murmurhash : MurmurHash3;
	import nxt.xxhash64 : XXHash64;
	import nxt.hash_functions;
	import nxt.digest.fnv : FNV;

	import std.typecons : Nullable;
	import std.meta : AliasSeq;
	import std.stdio : writefln;

	import nxt.benchmark : benchmarkAppendable, benchmarkSet, benchmarkMap, benchmarkAssociativeArray;

	/+ TODO: remove runCount when printing happens in `Results` instead +/
	debug					   // lighter test in debug mode
	{
		immutable elementCount = 100_000; ///< Number of elements.
		immutable runCount = 1;		  ///< Number of run per benchmark.
	}
	else
	{
		immutable elementCount = 400_000; ///< Number of elements.
		immutable runCount = 10;		  ///< Number of runs per benchmark.
	}
	writefln("\nElement count: %s", elementCount);
	writefln("\nRun count: %s", runCount);

	auto testSource = iota(0, elementCount).array;
	alias TestSource = typeof(testSource);
	const useRandomShuffledSource = true;
	if (useRandomShuffledSource)
		randomShuffle(testSource);

	writefln("\nArrays:\n");

	alias Sample = ulong;

	foreach (A; AliasSeq!(Sample[],
						  Appender_std!(Sample[]),
						  Array_std!(Sample),
						  DynamicArray!(Sample, Mallocator),
						  /+ TODO: DynamicArray!(Sample, theAllocator), +/
						  /* TODO: DynamicArray!(Sample, typeof(processAllocator)), */
						  VariantArrays!(Sample),
						  DynamicArray_emsi!(Sample, Mallocator),
						  Automem_Vector!(Sample, Mallocator)))
	{
		benchmarkAppendable!(A, Sample)(testSource);
	}

	writefln("\nSets:\n");
	foreach (A; AliasSeq!(/* Sorted!(DynamicArray!(int), true), */
						  DynamicDenseSetFilter!(uint),
						  DynamicDenseSetFilterGrowableArray!(uint),
						  HybridHashSet!(Nullable!(uint, uint.max), hashOf),
						  HybridHashSet!(Nullable!(uint, uint.max), identityHash64),
						  HybridHashSet!(Nullable!(uint, uint.max), lemireHash64),
						  HybridHashSet!(Nullable!(uint, uint.max), FNV!(64, true)),
						  HybridHashSet!(Nullable!(uint, uint.max), CRC32c),
						  HybridHashSet!(Nullable!(uint, uint.max), CRC64ECMA),
						  HashSet_emsi!(uint, Mallocator),
						  OpenHashSet_emsi!(uint, Mallocator),
						  /+ TODO: why are these so slow? +/
						  // HybridHashSet!(Nullable!(Sample, Sample.max), hashOf),
						  // HybridHashSet!(Nullable!(Sample, Sample.max), lemireHash64),
						  // HybridHashSet!(Nullable!(Sample, Sample.max), FNV!(64, true)),
						  /* TODO: RadixTreeSet!(uint, Mallocator), */
						  /* TODO: this fails with memory violatation at address 0x10: RedBlackTree!(uint), */
						  /+ TODO: BinaryHeap!(StdArray!uint), +/
						  HybridHashSet!(Nullable!(ulong, ulong.max), hashOf),
						  HybridHashSet!(Nullable!(ulong, ulong.max), identityHash64),
						  HybridHashSet!(Nullable!(ulong, ulong.max), wangMixHash64),
						  HybridHashSet!(Nullable!(ulong, ulong.max), lemireHash64),
						  HybridHashSet!(Nullable!(ulong, ulong.max), FNV!(64, true)),
						  HybridHashSet!(Nullable!(ulong, ulong.max), CRC32c),
						  HybridHashSet!(Nullable!(ulong, ulong.max), CRC64ECMA),
						  HashSet_emsi!(ulong, Mallocator),
						  OpenHashSet_emsi!(ulong, Mallocator),
						  /+ TODO: enable +/
						  // HybridHashSet!(Nullable!(ulong, ulong.max), FNV!(64, true),
						  //			  defaultKeyEqualPredOf!(Nullable!(ulong)),
						  //			  MyMallocator.instance,
						  //			  false,
						  //			  false),
						  HybridHashSet!(Address, FNV!(64, true)),
						  /* TODO: RadixTreeSet!(ulong, Mallocator), */
						  // TODO RadixTreeSet!(ulong, GCAllocator),
						  /* TODO: this fails with memory violatation at address 0x10: RedBlackTree!(ulong), */
						  /* Sorted!(DynamicArray!(SSOString), true), */
						  HybridHashSet!(SSOString, hashOf),
						  HybridHashSet!(SSOString, FNV!(64, true)),
						  HybridHashSet!(SSOString, CRC32c),
						  HybridHashSet!(SSOString, CRC64ECMA),
						  /+ TODO: HybridHashSet!(string, FNV!(64, true)), +/
						  /+ TODO: HybridHashSet!(string, wangMixHash64), +/
				 ))
	{
		benchmarkSet!(A, Sample)(testSource);
	}

	writefln("\nMaps:\n");
	foreach (A; AliasSeq!(
				 // uint => uint
				 uint[uint],
				 HybridHashMap!(Nullable!(uint, uint.max), uint, hashOf),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, identityHash64),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, lemireHash64),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, wangMixHash64),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, FNV!(64, true)),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, CRC32c),
				 HybridHashMap!(Nullable!(uint, uint.max), uint, CRC64ECMA),
				 HashMap_emsi!(uint, uint, Mallocator),
				 // ulong => ulong
				 ulong[ulong],
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, hashOf),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, identityHash64),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, lemireHash64),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, wangMixHash64),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, FNV!(64, true)),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, CRC32c),
				 HybridHashMap!(Nullable!(ulong, ulong.max), ulong, CRC64ECMA),
				 /* TODO: RadixTreeMap!(ulong, ulong, Mallocator), */
				 HybridHashMap!(Address, Address, hashOf),
				 HybridHashMap!(Address, Address, identityHash64),
				 HybridHashMap!(Address, Address, lemireHash64),
				 HybridHashMap!(Address, Address, wangMixHash64),
				 HybridHashMap!(Address, Address, FNV!(64, true)),
				 // string => string
				 string[string],
				 HybridHashMap!(string, string, hashOf),
				 HybridHashMap!(string, string, XXHash64),
				 HybridHashMap!(string, string, MurmurHash3!(128)),
				 HybridHashMap!(string, string, FNV!(64, true)),
				 StringMap!(string),
				 // SSOString => SSOString
				 SSOString[SSOString],
				 HybridHashMap!(SSOString, SSOString, hashOf),
				 HybridHashMap!(SSOString, SSOString, FNV!(64, true)),
			 ))
	{
		benchmarkMap!(A, Sample)(testSource);
	}
}
