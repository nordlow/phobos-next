module nxt.container.hybrid_hashmap;

import core.internal.hash : hashOf;
import std.experimental.allocator.common : isAllocator;
import nxt.container.common : GrowOnlyFlag, BorrowCheckFlag;
import std.experimental.allocator.mallocator : Mallocator;
import nxt.nullable_traits : isNullable;

enum UsePrimeCapacityFlag : ubyte { no, yes }

struct Options {
	GrowOnlyFlag growOnly = GrowOnlyFlag.no;
	BorrowCheckFlag borrowCheck = BorrowCheckFlag.no;
	UsePrimeCapacityFlag usePrimeCapacity = UsePrimeCapacityFlag.no;
	uint linearSearchMaxSize = 64; ///< Use one cache-line for now.
}

@safe:

/** Hash table/map with open-addressing and hybrid storage, storing `keys` of
 * type `K` and values of type `V`. Setting `V` to `void` turns the map into a
 * set.
 *
 * Keys are immutable except for when they are `class`es in which case they are
 * head-const (through bin reinterpretation to `KeyValueType`), This can be
 * overridden by setting `keyEqualPred` to, for instance, `a == b` for `class`
 * keys.
 *
 * Uses quadratic probing (using triangular numbers) unless `usePrimeCapacity`
 * in which case a simpler probing is used.
 *
 * Deletion/Removal of elements is lazy via the sentinel bitmap `_store.holesPtr` or
 * through assignment of reserved value of `KeyType` when `KeyType` has
 * hole/tombstone-sentinel-support via trait `isHoleable`. The terms "tombstone"
 * and "sentinel" are used at, for instance,
 * https://engineering.fb.com/2019/04/25/developer-tools/f14/ and
 * https://www.youtube.com/watch?v=ncHmEUmJZf4&t=2837s.
 *
 * Element iteration via
 * - either `byKey`, `byValue` or `byKeyValue` over `HybridHashMap` and
 * - `byElement` over `HybridHashSet`
 * respects taking the container argument either as an l-value or r-value using
 * detected using `auto ref`-qualified parameter introspected using `(__traits(isRef, y))`.
 * In the r-value case no reference counting is needed.
 * In the l-value case setting `borrowChecked` to `true` adds run-time
 * support for dynamic Rust-style ownership and borrowing between the range and the container.
 *
 * Params:
 *	 K = key type
 *	 V = value type
 *	 hasher = hash function or std.digest Hash
 *	 Allocator = memory allocator for bin array
 *	 borrowChecked = only activate when it's certain that this won't be moved via std.algorithm.mutation.move()
 *	 linearSearchMaxSize = Use linear search instead of probing when `_store.elts.sizeof <= linearSearchMaxSize`
 *	 usePrimeCapacity = Use prime numbers as capacity of hash table enabling better performance of simpler hash-functions
 *
 * See_Also: https://engineering.fb.com/2019/04/25/developer-tools/f14/
 * See_Also: https://github.com/abseil/abseil-cpp/blob/master/absl/container/flat_hash_map.h
 * See_Also: https://www.sebastiansylvan.com/post/robin-hood-hashing-should-be-your-default-hash-table-implementation/
 * See_Also: https://arxiv.org/abs/1605.04031
 * See_Also: https://github.com/Tessil/robin-map
 * See_Also: https://github.com/martinus/robin-hood-hashing
 * See_Also: https://probablydance.com/2017/02/26/i-wrote-the-fastest-hashtable/
 * See_Also: https://en.wikipedia.org/wiki/Lazy_deletion
 * See_Also: https://forum.dlang.org/post/ejqhcsvdyyqtntkgzgae@forum.dlang.org
 * See_Also: https://gankro.github.io/blah/hashbrown-insert/
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -preview=fieldwise -debug -g -unittest -checkaction=context -allinst -main -unittest -I../.. -i -run hybrid_hashmap.d
 *
 * TODO: Pass `nullValue` and `holeValue` explicitly as members of `Options` instead of relying on traits isNullable.
 *       The search and remove usages of `isNullable`, `nullValue` and `holeValue` (enum) members.
 *
 * TODO: Support set/map union via `~` and `~=` operator.
 *       See https://issues.dlang.org/show_bug.cgi?id=15682.
 *
 * TODO: Support non-nullable keys via extra bit-set _nullsPtr similar to _store.holesPtr
 * TODO: Don’t allocate _store.holesPtr when we don’t need removal such as for compiler (dmd) symbol tables. Use GrowOnlyFlag.
 * TODO: Factor out array store into container/store.d
 *
 * TODO: Add support for assignment from AA that calls withElements
 *
 * TODO: Add test for real class types as keys to test/container and test also with normal AA
 *
 * TODO: Add class type erasure layer to void* for the relevant members of HashMap store and factor out that store to container/store.d
 *
 * TODO: Make sure key classes and pointers are shifted down by alignement as
 * is done in AlignedAddress.toHash before hashed
 *
 * TODO: Replace `withCapacity` with `void capacity(size_t)` like D arrays.
 *
 * TODO: Tests fails when `linearSearchMaxSize` is set to 0
 *
 * TODO: A test fails with when -preview=fieldwise is not passed.
 *
 * TODO: Add support for opApply by copying opApply members in
 * ~/.dub/packages/emsi_containers-0.8.0/emsi_containers/src/containers/hashmap.d
 *
 * TODO: Implement `foreach (const k, const v; _)` support. See
 * https://forum.dlang.org/post/tj700o$1412$1@digitalmars.com
 *
 * TODO: Disable pragma(inline, true) and rebenchmark
 *
 * TODO: Robin-hood case introspect key type for storage of parts of hash
 * alongside nullValue and holeValue. Typically for address-types that doesn't
 * need scanning. Example is `Address` for implementation of GC. This is a D
 * showcase for code that is difficult to write in C++.
 *
 * TODO: group `nxt.probing` functions in `Prober` struct given as type template
 * param to `HybridHashMap`
 *
 * TODO: Make load factor dependent on current capacity or length and perhaps
 * also type and hash-function to get memory efficiency when it matters. Similar
 * to what is recommended in https://ticki.github.io/blog/horrible/.
 *
 * TODO: For copyable types replace `auto ref` with logic that only passes by
 * `ref` when it's faster to do so. See_Also:
 * https://github.com/dlang/dmd/pull/11000. When `-preview=in` has been made
 * the default this complexity can be removed. Or replace `ref` with `in`.
 *
 * TODO: Use mmap allocator when `_store.elts.sizeof` is larger than at least 8 pages
 *
 * TODO: Use `StoreK` in store and cast between it and `KeyType`
 *
 * TODO: Fix bug in `growInPlaceWithCapacity` and benchmark
 *
 * TODO: Modify existing unittest for `struct Rel { const string name; }`
 *
 * TODO: Use allocator.dispose() instead of allocator.deallocate() as in
 * https://github.com/dlang-community/containers
 *
 * TODO: if hash-function is cast(size_t)(classInstance) always use prime length
 * and shift pointer before hash based on alignof (might not be needed when
 * module prime) to maximize memory locality when adding successively allocated
 * pointers
 *
 * TODO: Add extractElement that moves it out similar to
 * http://en.cppreference.com/w/cpp/container/unordered_set/extract
 *
 * TODO: Add merge or union algorithm here or into container/common.d. See also:
 * http://en.cppreference.com/w/cpp/container/unordered_set/merge. this
 * algorithm moves elements from source if they are not already in `this`
 *
 * TODO: Robin-Hood-hashing
 *
 * TODO: Enable `borrowChecked` unconditionally in version (debug) if and when
 * `opPostMove` is implemented, in which case opPostMove() should assert false
 * if this is borrowed. See: https://github.com/dlang/DIPs/pull/109
 *
 * TODO: Save one word by making `_store.elts.length` be inferred by
 * `prime_modulo.primeConstants[_primeIndex]` if this is not too costly.
 *
 * TODO: Only add one extra element to capacity when `assumeNonFullHaystack` is
 * `true`
 *
 * TODO: Remove use of `static if (__traits(isCopyable, ...))` and `static if
 * (__traits(isPOD, ...))` in cases where compiler can handle more moves
 */
struct HybridHashMap(K, V = void,
					 alias hasher = hashOf,
					 string keyEqualPred = defaultKeyEqualPredOf!(K),
					 Allocator = Mallocator,
					 Options options = Options.init)
if (isNullable!K /*&& !hasAliasing!K */ && isAllocator!Allocator) {
	// pragma(msg, K.stringof, " => ", V.stringof);
	import core.exception : onOutOfMemoryError;
	import core.internal.traits : hasElaborateDestructor, Unqual;
	import core.lifetime : move;
	import std.traits : hasIndirections, hasFunctionAttributes;
	import std.typecons : Nullable;

	import nxt.nullable_traits : isNullable, defaultNullKeyConstantOf, isNull, nullify;
	import nxt.container.traits : mustAddGCRange, isAddress;
	import nxt.qcmeman : gc_addRange, gc_removeRange;

	enum usePrimeCapacity = options.usePrimeCapacity == UsePrimeCapacityFlag.yes;
	static if (usePrimeCapacity)
		import nxt.prime_modulo : PrimeIndex, ceilingPrime, moduloPrimeIndex;
	else
	{
		import std.math.algebraic : nextPow2;
		import nxt.probing : triangularProbeFromIndex, triangularProbeFromIndexIncludingHoles,
			triangularProbeCountFromIndex;
		/// Setting this `true` doesn't give measurable speedups so set it to `false` for now.
		enum bool assumeNonFullHaystack = false;
	}

	static if (is(typeof(keyEqualPred) : string)) {
		import std.functional : binaryFun;
		alias keyEqualPredFn = binaryFun!keyEqualPred;
	}
	else
		alias keyEqualPredFn = keyEqualPred;

	/// Is true iff `T` is an array (slice).
	private enum isSlice(T) = is(T : const(E)[], E);
	/// Is true iff `T` is a pointer.
	private enum isPointer(T) = is(T == U*, U);

	static if ((is(K == class)) &&
			   keyEqualPred == `a is b`) /+ TODO: use better predicate compare? +/
		alias StoreK = void*;
	else static if (isPointer!K &&
					/+ TODO: use better predicate compare? +/
					(keyEqualPred == `a == b` ||
					 keyEqualPred == `a is b`))
		alias StoreK = void*;
	else
		alias StoreK = K;

	/// Is `true` iff `this` is borrow-checked.
	enum isBorrowChecked = options.borrowCheck == BorrowCheckFlag.yes;

	enum hasNullableKey = isNullable!K;

	/** In the hash map case, `V` is non-void, and a value is stored alongside
	 * the key of type `K`.
	 */
	enum hasValue = !is(V == void);

	/** Is `true` iff `K` is an address, in which case holes/tombstones are represented by
	 * a specific value `holeKeyConstant`.
	 */
	enum hasAddressLikeKey = (isAddress!K || isSlice!K);

	static if (hasAddressLikeKey) {
		enum hasHoleableKey = true;
		enum holeKeyOffset = 0x1; /+ TODO: is this a good value? Or is 0xffff_ffff_ffff_ffff better? +/
		@trusted enum holeKeyAddress = cast(void*)holeKeyOffset;

		/**
		 * See_Also: https://forum.dlang.org/post/p7726n$2apd$1@digitalmars.com
		 * TODO: test if ulong.max gives better performance
		 */
		static K holeKeyConstant() @trusted pure nothrow @nogc
		{
			version (D_Coverage) {} else pragma(inline, true);
			/+ TODO: note that cast(size_t*) will give address 0x8 instead of 0x1 +/
			static if (isSlice!K) {
				alias E = typeof(K.init[0])*; // array element type
				auto ptr = cast(E)((cast(void*)null) + holeKeyOffset); // indicates a lazily deleted key
				return ptr[0 .. 0];
			}
			else
				return cast(K)((cast(void*)null) + holeKeyOffset); // indicates a lazily deleted key
		}

		/** Returns: true iff `key` is a hole/tombstone key constant. */
		static bool isHoleKeyConstant(in K key) @trusted pure nothrow @nogc
		{
			version (D_Coverage) {} else pragma(inline, true);
			static if (isSlice!K) // for slices
				// suffice to compare pointer part
				return (key.ptr is holeKeyAddress);
			else
				return (cast(const(void)*)key is holeKeyAddress);
		}

		/** TODO: make these work
		 */
		// enum K holeKey_1 = cast(K)((cast(size_t*)null));
		// static immutable K holeKey_2 = cast(K)((cast(size_t*)null));
	}
	else static if (isHoleable!K) {
		enum hasHoleableKey = true;
		pragma(inline, true)
		static K holeKeyConstant() pure nothrow @safe @nogc
			=> K.holeValue;
		static bool isHoleKeyConstant(in K key) pure nothrow @safe @nogc
		{
			version (D_Coverage) {} else pragma(inline, true);
			static if (__traits(hasMember, K, "isHole"))
				// typically faster by asserting value of member of aggregate `K`
				return key.isHole;
			else
				return key is K.holeValue;
		}
	}
	else static if (__traits(hasMember, K, "nullifier")) {
		alias Nullifier = typeof(K.init.nullifier);
		/+ TODO: pragma(msg, K, " has nullifier ", Nullifier); +/
		static if (isHoleable!Nullifier) {
			/+ TODO: pragma(msg, K, " has holeable nullifier ", Nullifier); +/
			enum hasHoleableKey = true;
			static K holeKeyConstant() @trusted pure nothrow @nogc
			{
				version (D_Coverage) {} else pragma(inline, true);
				K k;
				k.nullifier = Nullifier.holeValue;
				return k;
			}
			pragma(inline, true)
			static bool isHoleKeyConstant(in K key) @trusted pure nothrow @nogc
				=> key.nullfier == Nullifier.holeValue;
		}
		else
		{
			enum hasHoleableKey = false;
			// pragma(msg, "Need explicit hole/tombstone bitset for non-address-like key: ", K);
			import core.bitop : bts, bt, btr;
			import nxt.array_help : makeUninitializedBitArray, makeBitArrayZeroed, makeReallocatedBitArrayZeroPadded;
		}
	}
	else
	{
		enum hasHoleableKey = false;
		// pragma(msg, "Need explicit hole/tombstone bitset for non-address-like key: ", K);
		import core.bitop : bts, bt, btr;
		import nxt.array_help : makeUninitializedBitArray, makeBitArrayZeroed, makeReallocatedBitArrayZeroPadded;
	}

	/// Element type.
	static if (hasValue) {
		/** Map insertion status.
		 */
		enum InsertionStatus {
			added,			  ///< Element was added.
			modified,		   ///< Value of element was changed (map only).
			unmodified		  ///< Element was left unchanged.
		}

		/// Mutable element reference with mutable constant key and value.
		struct T {
			K key;
			V value;
		}

		/// Get key part of element.
		pragma(inline, true) static	 inout(K) keyOf(SomeElement)(	scope		inout(SomeElement) element) => element.key;
		pragma(inline, true) static ref inout(K) keyOf(SomeElement)(ref scope return inout(SomeElement) element) => element.key;

		/// Get value part of element.
		pragma(inline, true) static	 inout(V) valueOf()(	scope		inout(T) element) => element.value;
		pragma(inline, true) static ref inout(V) valueOf()(ref scope return inout(T) element) => element.value;

		/** Type of key stored. */
		public alias KeyType = K;

		/** Type of value stored. */
		public alias ValueType = V;

		static if (hasNullableKey)
			enum nullKeyElement = T(defaultNullKeyConstantOf!K, V.init);

		/// Key-value element reference with head-const for `class` keys and mutable value.
		static private struct KeyValueType {
			static if (isAddress!K) { // for reference types
				K _key;		  // no const because
				/** Key access is head-const. */
				pragma(inline, true)
				inout(K) key() @property inout pure nothrow @safe @nogc => _key;
			} else
				const K key;
			V value;
		}

		/// Get key part.
		pragma(inline, true)
		static auto ref inout(K) keyOf()(auto ref return scope inout(KeyValueType) element) @trusted
			=> cast(typeof(return))element.key; // needed for case: `inout(const(K)) => inout(K)`
	} else { // HashSet
		/** Set insertion status. */
		enum InsertionStatus {
			added,			  ///< Element was added.
			unmodified		  ///< Element was left unchanged.
		}

		alias T = K;			// short name for element type

		/// Get key part of element.
		pragma(inline, true)
		static auto ref inout(SomeElement) keyOf(SomeElement)(auto ref return inout(SomeElement) element)
			=> element;

		static if (hasNullableKey)
			enum nullKeyElement = defaultNullKeyConstantOf!K;
	}

	/** Is `true` if an instance of `SomeKey` that can be implictly cast to `K`.
	 *
	 * For instance `const(char)[]` can be `@trusted`ly cast to `string` in a
	 * temporary scope.
	 */
	template isScopedKeyType(SomeKey) {
		static if (is(SomeKey == class))
			enum isScopedKeyType = (is(const(SomeKey) : const(K)));
		else
			enum isScopedKeyType = (is(K : SomeKey) || // `K is` implicitly convertible from `SomeKey`
									is(SomeKey : U[], U) && // is array
									is(typeof(K(SomeKey.init))));
	}

	/** Is `true` if `key` is valid.
	 */
	static bool isValidKey(SomeKey)(in SomeKey key) {
		version (D_Coverage) {} else pragma(inline, true);
		static if (hasNullableKey)
			return !key.isNull;
		else
			return true;		// no non-null-sentinel validation needed
	}

	alias ElementType = T;

	/** Make with room for storing at least `minimumCapacity` number of elements.
	 *
	 * See_Also:
	 * https://forum.dlang.org/post/nyngzsaeqxzzuumivtze@forum.dlang.org
	 */
	static typeof(this) withCapacity()(in size_t minimumCapacity) /*tlm*/ {
		static if (usePrimeCapacity) {
			PrimeIndex primeIndex;
			immutable initialCapacity = minimumCapacity == 0 ? 1 : ceilingPrime(minimumCapacity + 1, primeIndex);
			assert(minimumCapacity < initialCapacity); // need at least one vacancy
			/+ TODO: return typeof(return)(withCapacity(initialCapacity), primeIndex, 0); +/
		} else {
			immutable initialCapacity = minimumCapacity == 0 ? 1 : nextPow2(minimumCapacity);
			assert(minimumCapacity < initialCapacity); // need at least one vacancy
			return typeof(return)(Store.withCapacity(initialCapacity, true), 0);
		}
	}

	import std.range.primitives : StdElementType = ElementType;
	import std.traits : isIterable, isAssignable;

	/** Make with the element `element`. */
	this(T element) {
		static if (usePrimeCapacity) {
			_primeIndex = PrimeIndex.init;
			_store = Store.withCapacity(ceilingPrime(1 + 1, _primeIndex), true);
		} else _store = Store.withCapacity(nextPow2(1), true);
		_count = 0;
		static if (__traits(isPOD, T))
			insertWithoutGrowthNoStatus(element);
		else
			insertWithoutGrowthNoStatus(move(element));
	}

	private this(Store store, in size_t count) {
		version (D_Coverage) {} else pragma(inline, true);
		_store = store;
		_count = count;
	}

	/** Make with the elements `elements`.
		TODO: Replace with `makeWithElements`.
	 */
	static typeof(this) withElements(R)(R elements)
	if (isIterable!R &&
		isAssignable!(T, StdElementType!R)) {
		import std.range.primitives : hasLength;
		static if (hasLength!R) {
			typeof(this) that = withCapacity(elements.length);
			foreach (ref element; elements)
				that.insertWithoutGrowthNoStatus(element);
		} else {
			typeof(this) that;
			foreach (ref element; elements)
				that.insert(element);
		}
		return that;
	}

	/// Destruct.
	~this() nothrow @nogc {
		release();
	}

	/// No copying.
	this(this) @disable;

	/++ Returns: a shallow duplicate of `this`.
		TODO: Replace with `dupShallow`.
	 +/
	typeof(this) dup()() const @trusted /*tlm*/ {
		Store storeCopy = Store.withCapacity(_store.elts.length, false); // unsafe
		foreach (immutable i, ref bin; _store.elts)
			if (isOccupiedAtIndex(i)) { // normal case
				static if (hasValue) {
					duplicateEmplace(bin.key, storeCopy.elts[i].key);
					duplicateEmplace(bin.value, storeCopy.elts[i].value);
				} else
					duplicateEmplace(bin, storeCopy.elts[i]);
			} else {
				import core.lifetime : emplace;
				emplace(&storeCopy.elts[i]); /+ TODO: only emplace key and not value +/
				keyOf(storeCopy.elts[i]).nullify();
			}
		return typeof(return)(storeCopy, _count);
	}

	/// Equality.
	bool opEquals()(in typeof(this) rhs) const @trusted // TODO: remove @trusted when compiler
	{
		if (_count != rhs._count)
			return false;	   // quick discardal
		foreach (immutable i, const ref bin; _store.elts)
			if (isOccupiedAtIndex(i)) {
				static if (hasValue) {
					auto valuePtr = bin.key in rhs; // TODO: @trusted is incorrectly needed here when compiling with -dip1000
					if (!valuePtr)
						return false;
					/+ TODO: make != a parameter that can also be typically !is. TODO: ask forum about this +/
					if ((*valuePtr) != bin.value)
						return false;
				} else {
					if (!rhs.contains(bin))
						return false;
				}
			}
		return true;
	}

	static if (true) {
	private:

		static if (!hasHoleableKey) {
			/// Number of bytes in a word.
			enum wordBytes = size_t.sizeof;

			/// Number of bits in a word.
			enum wordBits = 8*wordBytes;

			/// Returns: number of words (`size_t`) needed to represent `binCount` holes.
			pragma(inline, true)
			static size_t holesWordCount(in size_t binCount)
				=> (binCount / wordBits +
					(binCount % wordBits ? 1 : 0));

			pragma(inline, true)
			static size_t binBlockBytes(in size_t binCount) => wordBytes*holesWordCount(binCount);

			/// Untag hole/tombstone at index `index`.
			void untagHoleAtIndex(in size_t index) @trusted
			{
				version (D_Coverage) {} else pragma(inline, true);
				version (unittest) assert(index < _store.elts.length);
				btr(_store.holesPtr, index);
			}

			pragma(inline, true)
			static bool hasHoleAtPtrIndex(const scope size_t* holesPtr, in size_t index) @trusted
				=> bt(holesPtr, index) != 0;
		}

		/// Tag hole/tombstone at index `index`.
		void tagHoleAtIndex(in size_t index) @trusted {
			version (D_Coverage) {} else pragma(inline, true);
			version (unittest) assert(index < _store.elts.length);
			static if (hasHoleableKey)
				keyOf(_store.elts[index]) = holeKeyConstant;
			else
				bts(_store.holesPtr, index);
		}
	}

	static if (isBorrowChecked)
		static immutable borrowedErrorMessage = "cannot mutate this when it's borrowed";

	/// Empty.
	void clear() {
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		release();
		/+ TODO: functionize?: +/
		_store = typeof(_store).init;
		static if (usePrimeCapacity)
			_primeIndex = 0;
		_count = 0;
	}

	/// Release internal allocations.
	private void release() scope @trusted {
		// Release bin elements:
		foreach (ref bin; _store.elts) {
			static if (hasElaborateDestructor!T)
				.destroy(bin);
			else static if (mustAddGCRange!T)
				bin = T.init;
		}
		// Release store slice:
		static if (mustAddGCRange!T) {
			if (_store.elts !is null)
				gc_removeRange(_store.elts.ptr); // `gc_removeRange` fails for null input
		}
		if (_store.elts !is null)
			allocator.deallocate(_store.elts);
	}

	/// Adjust `key`.
	private auto adjustKey(SomeKey)(const return scope SomeKey key) const scope @trusted
	{
		pragma(inline, true);			// must be inlined
		static if (is(SomeKey : U[], U)) // is array (slice)
			/* because return value is used only temporarily it's ok to cast to
			 * `immutable` to prevent GC-allocations in types such as
			 * `sso_string.SSOString` */
			return cast(immutable(typeof(key[0]))[])key;
		else
			return key;
	}

	/** Check if `element` is stored.
	 *
	 * Parameter `key` may be non-immutable, for instance const(char)[]
	 * eventhough key type `K` is `string`.
	 *
	 * Returns: `true` if element is present, `false` otherwise.
	 */
	bool contains(SomeKey)(in SomeKey key) const scope @trusted /* `auto ref` here makes things slow */
	if (isScopedKeyType!(typeof(key)))
	in(isValidKey(key)) {
		// pragma(msg, SomeKey.stringof ~ " " ~ K.stringof, " ", is(K : SomeKey), " ", is(SomeKey : K));
		// debug static assert(isScopedKeyType!(typeof(key)), SomeKey.stringof ~ " " ~ K.stringof);
		version (LDC) pragma(inline, true);
		static if (hasHoleableKey) { assert(!isHoleKeyConstant(cast(const(K))adjustKey(key))); }
		static if (options.linearSearchMaxSize != 0)
			if (_store.elts.length * T.sizeof <= options.linearSearchMaxSize)
				return containsUsingLinearSearch(key);
		immutable hitIndex = indexOfKeyOrVacancySkippingHoles(cast(const(K))adjustKey(key)); // cast scoped `key` is @trusted
		return (hitIndex != _store.elts.length &&
				isOccupiedAtIndex(hitIndex));
	}

	/** Check if `element` is stored.
	 *
	 * Uses linear search instead of hashing plus probing and may be faster for
	 * for small tables with complicated hash functions.
	 *
	 * Parameter `key` may be non-immutable, for instance const(char)[]
	 * eventhough key type `K` is `string`.
	 *
	 * Returns: `true` if element is present, `false` otherwise.
	 */
	bool containsUsingLinearSearch(SomeKey)(in SomeKey key) const scope @trusted /* tlm, `auto ref` here makes things slow */
	if (isScopedKeyType!(typeof(key)))
	in(isValidKey(key)) {
		static if (hasHoleableKey) { assert(!isHoleKeyConstant(cast(const(K))adjustKey(key))); }
		static if (is(SomeKey == Nullable!(_), _)) {
			import std.algorithm.searching : canFind;
			import std.traits : TemplateArgsOf;
			alias args = TemplateArgsOf!(SomeKey);
			debug static assert(args.length == 2,
						  "linear search for Nullable without nullValue is slower than default `this.contains()` and is not allowed");
			alias UnderlyingType = args[0];
			return length >= 1 && (cast(UnderlyingType[])_store.elts).canFind!keyEqualPredFn(key.get());
		} else {
			foreach (const ref bin; _store.elts)
				if (keyEqualPredFn(keyOf(bin), key))
					return true;
			return false;
		}
	}

	/** Check if `element` is stored. Move found element to a hole if possible.
		Returns: `true` if element is present, `false` otherwise.
	*/
	bool containsWithHoleMoving()(in K key) /* tlm, `auto ref` here makes things slow */
	in(isValidKey(key)) {
		version (LDC) pragma(inline, true);

		static if (hasHoleableKey) { assert(!isHoleKeyConstant(key)); }
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		immutable hitIndex = indexOfKeyOrVacancySkippingHoles(adjustKey(key));
		/+ TODO: update holes +/
		return (hitIndex != _store.elts.length &&
				isOccupiedAtIndex(hitIndex));
	}

	/** Insert `element`, being either a key-value (map-case) or a just a key
	 * (set-case).
	 *
	 * If `element` is a nullable type and it is null an `AssertError` is thrown.
	 */
	InsertionStatus insert()(const T element) @trusted /* tlm. need `T` to be `const` in `class` case */
	in(!keyOf(element).isNull) {
		version (LDC) pragma(inline, true);
		static if (hasHoleableKey) { debug assert(!isHoleKeyConstant(keyOf(element))); }
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		reserveExtra(1);
		size_t hitIndex = 0;
		static if (__traits(isPOD, T))
			return insertWithoutGrowth(element, hitIndex);
		else
			return insertWithoutGrowth(move(*cast(T*)&element), hitIndex);
	}

	/** Insert `element`, being either a key-value (map-case) or a just a key
	 * (set-case).
	 *
	 * If `element` is a nullable type and it is null an `AssertError` is thrown.
	 *
	 * Returns: reference to existing element if present, otherwise new `element`.
	 *
	 * Can be used for implementing, for instance, caching of typically strings.
	 */
	ref T insertAndReturnElement(SomeElement)(scope SomeElement element) return /*tlm*/
	in(!keyOf(element).isNull) {
		version (LDC) pragma(inline, true);
		static if (hasHoleableKey) { debug assert(!isHoleKeyConstant(cast(K)adjustKey(keyOf(element)))); }
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		reserveExtra(1);
		static if (__traits(isPOD, SomeElement))
			immutable hitIndex = insertWithoutGrowthNoStatus(element);
		else
			immutable hitIndex = insertWithoutGrowthNoStatus(move(element));
		return _store.elts[hitIndex];
	}

	/** Insert `elements`, all being either a key-value (map-case) or a just a key (set-case).
	 */
	void insertN(R)(R elements) @trusted
	if (isIterable!R &&
		__traits(isCopyable, T))		   /+ TODO: support uncopyable T? +/
	{
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		import std.range.primitives : hasLength;
		static if (hasLength!R)
			reserveExtra(elements.length); // might create unused space in `_store` store
		foreach (ref element; elements) {
			static if (!hasLength!R)
				reserveExtra(1);
			static if (hasIndirections!T)
				insertWithoutGrowthNoStatus(element);
			else
				insertWithoutGrowthNoStatus(*cast(Unqual!T*)&element);
		}
	}

	/// Is `true` iff in-place rehashing during growth should be performed.
	enum bool growInPlaceFlag = false; /+ TODO: warning `growInPlaceWithCapacity` is buggy +/

	/// Numerator for grow scale.
	enum growScaleP = 3;
	/// Denominator for grow scale.
	enum growScaleQ = 2;

	/** Reserve room for `extraCapacity` number of extra buckets. */
	void reserveExtra(in size_t extraCapacity) { /*!tlm*/
		version (LDC) pragma(inline, true);
		static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
		immutable newCapacity = (_count + extraCapacity)*growScaleP/growScaleQ;
		if (newCapacity > _store.elts.length)
			growWithNewCapacity(newCapacity);
	}

	/// Grow (rehash) to make for `newCapacity` number of elements.
	private void growWithNewCapacity()(in size_t newCapacity) /*tlm*/ {
		version (unittest) assert(newCapacity > _store.elts.length);
		static if (__traits(hasMember, Allocator, "reallocate")) {
			static if (growInPlaceFlag)
				growInPlaceWithCapacity(newCapacity);
			else
				growStandardWithNewCapacity(newCapacity);
		} else
			growStandardWithNewCapacity(newCapacity);
	}

	/// Grow (rehash) store to make room for `newCapacity` number of elements.
	private void growStandardWithNewCapacity()(in size_t newCapacity) /*tlm*/ {
		version (unittest) assert(newCapacity > _store.elts.length);
		auto next = typeof(this).withCapacity(newCapacity);
		foreach (immutable i, ref bin; _store.elts)
			if (isOccupiedAtIndex(i)) {
				next.insertMoveWithoutGrowth(bin); // value is zeroed but
				static if (!hasHoleableKey)
					keyOf(bin).nullify(); // keyC must zeroed
			}
		move(next, this);
	}

	/// Tag as lazily delete element at index `index`.`
	private void tagAsLazilyDeletedElementAtIndex(in size_t index) {
		version (LDC) pragma(inline, true);
		// key
		static if (options.linearSearchMaxSize != 0)
			if (_store.elts.length * T.sizeof <= options.linearSearchMaxSize) {
				keyOf(_store.elts[index]).nullify();
				goto done;
			}
		static if (hasHoleableKey)
			keyOf(_store.elts[index]) = holeKeyConstant;
		else {
			keyOf(_store.elts[index]).nullify();
			tagHoleAtIndex(index);
		}
	done:
		// value
		static if (hasValue) {
			static if (hasElaborateDestructor!V) // if we should clear all
				.destroy(valueOf(_store.elts[index]));
			static if (mustAddGCRange!V) // if we should clear all
				valueOf(_store.elts[index]) = V.init; // avoid GC mark-phase dereference
		}
	}

	/// Insert `element` at `index`.
	private void insertElementAtIndex(SomeElement)(scope SomeElement element, in size_t index) @trusted /*tlm*/ {
		version (LDC) pragma(inline, true);
		static if (isSlice!SomeElement &&
				   !is(typeof(SomeElement.init[0]) == immutable)) {
			/* key is an array of non-`immutable` elements which cannot safely
			 * be stored because keys must be immutable for hashing to work
			 * properly, therefore duplicate */
			keyOf(_store.elts[index]) = element.idup;
		} else {
			static if (__traits(isPOD, SomeElement))
				_store.elts[index] = element;
			else {
				static if (__traits(isPOD, K))
					keyOf(_store.elts[index]) = keyOf(element);
				else
					move(keyOf(element),
						 keyOf(_store.elts[index]));

				static if (hasValue) {
					import core.lifetime : moveEmplace;
					moveEmplace(valueOf(element),
								valueOf(_store.elts[index]));
				}
			}
		}
	}

	/// Rehash elements in-place.
	private void rehashInPlace()() @trusted /*tlm*/ {
		import core.bitop : bts, bt;
		import nxt.array_help : makeBitArrayZeroed, wordCountOfBitCount;

		size_t* dones = makeBitArrayZeroed!Allocator(_store.elts.length);

		foreach (const doneIndex; 0 .. _store.elts.length) {
			if (bt(dones, doneIndex)) { continue; } // if _store.elts[doneIndex] continue
			if (isOccupiedAtIndex(doneIndex)) {
				import core.lifetime : moveEmplace;
				T currentElement = void;

				/+ TODO: functionize: +/
				moveEmplace(_store.elts[doneIndex], currentElement);
				static if (is(K == Nullable!(_), _))
					keyOf(_store.elts[doneIndex]).nullify(); // `moveEmplace` doesn't init source of type Nullable

				while (true) {
					// TODO remove param `element`
					alias pred = (in index, in element)
						=> (!isOccupiedAtIndex(index) || // free slot
							!bt(dones, index)); // or a not yet replaced element
					static if (usePrimeCapacity)
						immutable hitIndex = xxx;
					else
						immutable hitIndex = _store.elts[].triangularProbeFromIndex!(pred, assumeNonFullHaystack)(keyToIndex(keyOf(currentElement)));
					assert(hitIndex != _store.elts.length, "no free slot");

					bts(dones, hitIndex); // _store.elts[hitIndex] will be at it's correct position

					if (isOccupiedAtIndex(doneIndex)) {
						T nextElement = void;

						/+ TODO: functionize: +/
						moveEmplace(_store.elts[hitIndex], nextElement); // save non-free slot
						static if (is(K == Nullable!(_), _))
							keyOf(_store.elts[hitIndex]).nullify(); // `moveEmplace` doesn't init source of type Nullable

						moveEmplace(currentElement, _store.elts[hitIndex]);
						moveEmplace(nextElement, currentElement);
					} else { // if no free slot
						moveEmplace(currentElement, _store.elts[hitIndex]);
						break; // inner iteration is finished
					}
				}
			}
			bts(dones, doneIndex); // _store.elts[doneIndex] is at it's correct position
		}

		allocator.deallocate(cast(void[])(dones[0 .. wordCountOfBitCount(_store.elts.length)]));
	}

	/** Grow (with rehash) store in-place making room for `minimumCapacity` number of elements. */
	private void growInPlaceWithCapacity()(in size_t minimumCapacity) @trusted /*tlm*/ {
		assert(minimumCapacity > _store.elts.length);
		static if (usePrimeCapacity)
			immutable newCapacity = ceilingPrime(minimumCapacity, _primeIndex);
		else
			immutable newCapacity = nextPow2(minimumCapacity);
		immutable newByteCount = T.sizeof*newCapacity;
		const oldStorePtr = _store.elts.ptr;
		immutable oldLength = _store.elts.length;
		auto rawStore = cast(void[])_store;
		if (allocator.reallocate(rawStore, newByteCount)) {
			_store = cast(T[])rawStore;
			static if (mustAddGCRange!T) {
				if (oldStorePtr !is null)
					gc_removeRange(oldStorePtr); // `gc_removeRange` fails for null input
				gc_addRange(_store.elts.ptr, newByteCount);
			}
			/+ TODO: make this an array operation `nullifyAll` or `nullifyN` +/
			foreach (ref bin; _store.elts[oldLength .. newCapacity])
				keyOf(bin).nullify(); // move this `init` to reallocate() above?
			rehashInPlace();
		} else
			assert(0, "couldn't reallocate bin");
	}

	/** Insert (without growth) `element` at `hitIndex`. */
	private InsertionStatus insertWithoutGrowth(SomeElement)(in SomeElement element, /*tlm*/
															 out size_t hitIndex) @trusted {
		version (LDC) pragma(inline, true);
		version (unittest) {
			assert(!keyOf(element).isNull);
			static if (hasHoleableKey) { assert(!isHoleKeyConstant(adjustKey(keyOf(element)))); }
		}
		size_t holeIndex = size_t.max; // first hole index to written to if hole found
		const hitIndexPrel = indexOfKeyOrVacancyAndFirstHole(keyOf(element), holeIndex);
		if (hitIndexPrel == _store.elts.length || // keys miss and holes may have filled all empty slots
			keyOf(_store.elts[hitIndexPrel]).isNull) // just key miss but a hole may have been found on the way
		{
			immutable hasHole = holeIndex != size_t.max; // hole was found along the way
			if (hasHole)
				hitIndex = holeIndex; // pick hole instead
			else
				hitIndex = hitIndexPrel; // normal hit
			version (unittest) assert(hitIndex != _store.elts.length, "no null or hole slot");
			static if (__traits(isPOD, SomeElement))
				insertElementAtIndex(*cast(SomeElement*)&element, hitIndex);
			else
				insertElementAtIndex(move(*cast(SomeElement*)&element), hitIndex);
			static if (!hasHoleableKey)
				if (hasHole)
					untagHoleAtIndex(hitIndex);
			_count = _count + 1;
			return InsertionStatus.added;
		}
		else
			hitIndex = hitIndexPrel;
		static if (hasValue) {
			static if (__traits(isStaticArray, V))
				// identity comparison of static arrays implicitly coerces them
				// to slices, which are compared by reference, so don't use !is here
				immutable valueDiffers = (valueOf(element) !=
										  valueOf(_store.elts[hitIndexPrel])); // only value changed
			else
				immutable valueDiffers = (valueOf(element) !is
										  valueOf(_store.elts[hitIndexPrel])); // only value changed
			if (valueDiffers) { // only value changed
				move(valueOf(*cast(SomeElement*)&element),
					 valueOf(_store.elts[hitIndexPrel])); // value is defined so overwrite it
				return InsertionStatus.modified;
			}
		}
		return InsertionStatus.unmodified;
	}

	/** Insert (without growth) `element` and return index to bin where insertion happended. */
	private size_t insertWithoutGrowthNoStatus(SomeElement)(in SomeElement element) @trusted /*tlm*/ {
		version (LDC) pragma(inline, true);
		version (unittest) {
			assert(!keyOf(element).isNull);
			static if (hasHoleableKey) { assert(!isHoleKeyConstant(adjustKey(keyOf(element)))); }
		}
		size_t hitIndex = 0;
		size_t holeIndex = size_t.max; // first hole index to written to if hole found
		const hitIndexPrel = indexOfKeyOrVacancyAndFirstHole(adjustKey(keyOf(element)), holeIndex);
		if (hitIndexPrel == _store.elts.length || // keys miss and holes may have filled all empty slots
			keyOf(_store.elts[hitIndexPrel]).isNull) // just key miss but a hole may have been found on the way
		{
			immutable hasHole = holeIndex != size_t.max; // hole was found along the way
			if (hasHole)
				hitIndex = holeIndex; // pick hole instead
			else
				hitIndex = hitIndexPrel; // normal hit
			version (unittest) assert(hitIndex != _store.elts.length, "no null or hole slot");
			static if (__traits(isPOD, SomeElement))
				insertElementAtIndex(*cast(SomeElement*)&element, hitIndex);
			else
				insertElementAtIndex(move(*cast(SomeElement*)&element), hitIndex);
			static if (!hasHoleableKey)
				if (hasHole) { untagHoleAtIndex(hitIndex); }
			_count = _count + 1;
			return hitIndex;
		}
		else
			hitIndex = hitIndexPrel;
		static if (hasValue)
			// modify existing value
			move(valueOf(*cast(SomeElement*)&element),
				 valueOf(_store.elts[hitIndexPrel])); // value is defined so overwrite it
		return hitIndex;
	}

	/** Insert `element`, being either a key-value (map-case) or a just a key (set-case).
	 */
	private InsertionStatus insertMoveWithoutGrowth()(ref T element) /*tlm*/ {
		version (LDC) pragma(inline, true);
		size_t hitIndex = 0;
		return insertWithoutGrowth(move(element), hitIndex);
	}

	static if (hasValue) {
		/** Insert or replace `value` at `key`. */
		InsertionStatus insert()(K key, V value) /*tlm*/ {
			pragma(inline, true); // LDC must have this
			static if (__traits(isPOD, K)) {
				static if (__traits(isPOD, V))
					return insert(T(key, value));
				else
					return insert(T(key, move(value)));
			} else {
				static if (__traits(isPOD, V))
					return insert(T(move(key), value));
				else
					return insert(T(move(key), move(value)));
			}
		}
	}

	static if (!hasValue) {
		scope const(K)* opBinaryRight(string op, SomeKey)(in SomeKey key) const return @trusted
		if (op == `in` &&
			isScopedKeyType!(typeof(key)))
		in(isValidKey(key)) {
			version (D_Coverage) {} else pragma(inline, true);
			static if (hasHoleableKey) { assert(!isHoleKeyConstant(cast(K)adjustKey(key))); }
			immutable hitIndex = indexOfKeyOrVacancySkippingHoles(adjustKey(key)); // cast scoped `key` is @trusted
			immutable match = hitIndex != _store.elts.length && isOccupiedAtIndex(hitIndex);
			if (match)
				return &_store.elts[hitIndex];
			else
				return null;
		}

		ref typeof(this) opOpAssign(string op, SomeKey)(in SomeKey key) return @trusted
		if (op == `~` &&		// binary assignment operator `~=`
			isScopedKeyType!(typeof(key))) {
			version (LDC) pragma(inline, true);
			reserveExtra(1);
			immutable hitIndex = insertWithoutGrowthNoStatus(key);
			return this;
		}

		/** Try to retrieve `class`-element of type `Class` constructed with
		 * parameters `params`.
		 *
		 * Typically used to implement (polymorphic) caching of class-types
		 * without the need for GG-allocating a temporary instance of a
		 * `class`-element potentially already stored in `this` set.
		 *
		 * Polymorphic caching can be realized by setting `hasher` to
		 * `hash_functions.hashOfPolymorphic`.
		 */
		scope const(Class) tryGetElementFromCtorParams(Class, Params...)(scope Params params) const return @trusted
		if (is(Class : K)) {
			import core.lifetime : emplace;
			void[__traits(classInstanceSize, Class)] tempNode_ = void;
			scope Class temp = emplace!(Class)(tempNode_, params);
			Class* hit = cast(Class*)(temp in this);

			static if (__traits(hasMember, Class, "__dtor"))
				temp.__dtor();

			if (hit) {
				auto typedHit = cast(typeof(return))*hit;
				assert(typedHit, "Expected class " ~ Class.stringof ~ " but got hit was of other type"); /+ TODO: give warning or throw +/
				return typedHit;
			}
			return null;
		}
	}

	static if (hasValue) {
		scope inout(V)* opBinaryRight(string op, SomeKey)(in SomeKey key) inout return @trusted // `auto ref` here makes things slow
		if (op == `in` &&
			isScopedKeyType!(SomeKey)) {
			version (LDC) pragma(inline, true);
			// pragma(msg, SomeKey, " => ", K);
			immutable hitIndex = indexOfKeyOrVacancySkippingHoles(cast(const(K))adjustKey(key)); // cast scoped `key` is @trusted
			immutable match = hitIndex != _store.elts.length && isOccupiedAtIndex(hitIndex);
			if (match)
				return cast(typeof(return))&_store.elts[hitIndex].value;
			else
				return null;
		}

		/// Indexing.
		scope ref inout(V) opIndex(SomeKey)(in SomeKey key) inout return @trusted // `auto ref` here makes things slow.
		if (isScopedKeyType!(typeof(key))) {
			import core.exception : onRangeError;
			version (LDC) pragma(inline, true);
			immutable hitIndex = indexOfKeyOrVacancySkippingHoles(adjustKey(key)); // cast scoped `key` is @trusted
			immutable match = hitIndex != _store.elts.length && isOccupiedAtIndex(hitIndex);
			if (!match)
				onRangeError();
			return _store.elts[hitIndex].value;
		}

		/** Get value of `key` or `defaultValue` if `key` not present (and
		 * therefore `nothrow`).
		 *
		 * Returns: value reference iff `defaultValue` is an l-value.
		 *
		 * TODO: make `defaultValue` `lazy` when that can be `nothrow`
		 */
		auto ref inout(V) get()(in K key, auto ref inout(V) defaultValue) inout /*tlm*/ {
			version (LDC) pragma(inline, true);
			if (auto valuePtr = key in this)
				return *valuePtr;
			else
				return defaultValue;
		}

		/** Get reference to `key`-part of stored element at `key`, if present,
		 * otherwise return `defaultKey`.
		 *
		 * Used to implement caching inside the key part of a map.
		 */
		ref const(K) getKeyRef(SomeKey)(in SomeKey key, ref const(K) defaultKey) const return @trusted @nogc
		if (isScopedKeyType!(SomeKey)) {
			version (LDC) pragma(inline, true);
			immutable hitIndex = indexOfKeyOrVacancySkippingHoles(adjustKey(key)); // cast scoped `key` is @trusted
			immutable match = hitIndex != _store.elts.length && isOccupiedAtIndex(hitIndex);
			if (match)
				return _store.elts[hitIndex].key;
			return defaultKey;
		}

		/** Supports the syntax `aa[key] = value;`.
		 */
		ref V opIndexAssign()(V value, K key) /* tlm. TODO: return scope */
		in(isValidKey(key)) {
			version (LDC) pragma(inline, true);
			static if (hasHoleableKey) { debug assert(!isHoleKeyConstant(key)); }
			static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
			reserveExtra(1);
			static if (__traits(isPOD, K)) {
				static if (__traits(isPOD, V))
					immutable hitIndex = insertWithoutGrowthNoStatus(T(key, value));
				else
					immutable hitIndex = insertWithoutGrowthNoStatus(T(key, move(value)));
			} else {
				static if (__traits(isPOD, V))
					immutable hitIndex = insertWithoutGrowthNoStatus(T(move(key), value));
				else
					immutable hitIndex = insertWithoutGrowthNoStatus(T(move(key), move(value)));
			}
			return _store.elts[hitIndex].value;
		}

		ref V opIndexOpAssign(string op, Rhs)(Rhs rhs, K key) /+ TODO: return scope +/
		// if (true)			   /+ TODO: pre-check that mixin will work +/
		in(isValidKey(key)) {
			// pragma(msg, "opIndexOpAssign: Key:", K, " Value:", V, " Rhs:", Rhs, " op:", op);
			static if (hasHoleableKey) { debug assert(!isHoleKeyConstant(key)); }
			static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
			reserveExtra(1);
			size_t holeIndex = size_t.max; // first hole index to written to if hole found
			immutable hitIndex = indexOfKeyOrVacancyAndFirstHole(key, holeIndex);
			if (hitIndex == _store.elts.length || // keys miss and holes may have filled all empty slots
				keyOf(_store.elts[hitIndex]).isNull) // just key miss but a hole may have been found on the way
			{
				immutable hasHole = holeIndex != size_t.max; // hole was found along the way
				immutable index = (hasHole ?
							   holeIndex : // pick hole instead
							   hitIndex); // normal hit
				version (unittest) assert(index != _store.elts.length, "no null or hole slot");
				static if (__traits(isCopyable, K)) {
					static if (op == "~" ||
							   op == "+" ||
							   op == "*") {
						static if (is(V : Rhs[])) // isDynamicArray of `Rhs`
							insertElementAtIndex(T(key, [rhs]), /+ TODO: if `V(rhs)` is not supported use `V.init` followed by `OP= rhs` +/
												 index);
						else
							// dbg("opIndexOpAssign-new: k:", key, " rhs:", rhs);
							insertElementAtIndex(T(key, V(rhs)), /+ TODO: if `V(rhs)` is not supported use `V.init` followed by `OP= rhs` +/
												 index);
					}
					else
						static assert(0, "Handel op " ~ op);
				}
				else
					static assert(0, "Handle uncopyable key " ~ K.stringof);
					// insertElementAtIndex(move(*cast(SomeElement*)&element), index);
				static if (!hasHoleableKey)
					if (hasHole) { untagHoleAtIndex(index); }
				_count = _count + 1;
				return _store.elts[index].value;
			}
			else { // `key`-hit at index `hitIndex`
				// dbg("opIndexOpAssign-mod: k:", key, " rhs:", rhs);
				mixin(`return _store.elts[hitIndex].value ` ~ op ~ `= rhs;`); // modify existing value
			}
		}
	}

	static if (!options.growOnly) {
		/** Remove `element`.
		 * Returns: `true` if element was removed, `false` otherwise.
		 */
		bool remove(SomeKey)(in SomeKey key) scope /*tlm*/
		if (isScopedKeyType!(typeof(key))) {
			version (LDC) pragma(inline, true);
			static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
			static if (options.linearSearchMaxSize != 0)
				if (_store.elts.length * T.sizeof <= options.linearSearchMaxSize) {
					foreach (immutable i, const ref element; _store.elts) // linear search is faster for small arrays
						if (keyEqualPredFn(keyOf(element), key)) {
							tagAsLazilyDeletedElementAtIndex(i);
							_count = _count - 1;
							return true;
						}
					return false;
				}
			immutable hitIndex = indexOfKeyOrVacancySkippingHoles(cast(const(K))adjustKey(key));
			immutable match = hitIndex != _store.elts.length && isOccupiedAtIndex(hitIndex);
			if (match) {
				tagAsLazilyDeletedElementAtIndex(hitIndex);
				_count = _count - 1;
				return true;
			}
			return false;
		}

		import nxt.traits_ex : isRefIterable;
		import std.range.primitives : front;

		/** Remove all elements matching `keys` followed by a rehash.
		 *
		 * Returns: number of elements that were removed.
		 */
		version (none)											/+ TODO: enable +/
		size_t rehashingRemoveN(Keys)(in Keys keys) /*tlm*/
		if (isRefIterable!Keys &&
			is(typeof(Keys.front == K.init))) {
			static if (isBorrowChecked) { debug assert(!isBorrowed, borrowedErrorMessage); }
			rehash!("!a.isNull && keys.canFind(a)")(); /+ TODO: make this work +/
			return 0;
		}
	}

	/// Check if empty.
	@property bool empty() const => _count == 0;
	/// Get length.
	@property size_t length() const => _count;
	/// Get element count.
	alias count = length;
	/// Get bin count (capacity).
	@property size_t binCount() const => _store.elts.length;

	/** Returns: get total probe count for all elements stored. */
	size_t totalProbeCount()() const /*tlm*/ {
		static if (hasValue)
			auto range = byKeyValue(this);
		else
			auto range = byElement(this);
		typeof(return) totalCount = 0;
		foreach (const ref currentElement; range) {
			static if (__traits(isCopyable, T)) // TODO why does using `passElementByValue` fail as an expression for certain element types?
				/* don't use `auto ref` for copyable `T`'s to prevent
				 * massive performance drop for small elements when compiled
				 * with LDC. TODO: remove when LDC is fixed. */
				alias pred = (const scope element) => (keyEqualPredFn(keyOf(element),
																	  keyOf(currentElement)));
			else
				alias pred = (const scope ref element) => (keyEqualPredFn(keyOf(element),
																		  keyOf(currentElement)));
			static if (usePrimeCapacity)
				immutable probeCount = xxx;
			else
				immutable probeCount = triangularProbeCountFromIndex!(pred)(_store.elts[], keyToIndex(keyOf(currentElement)));
			totalCount += probeCount;
		}
		return totalCount;
	}

	/** Returns: average probe count for all elements stored. */
	double averageProbeCount()() const /*tlm*/ => (cast(typeof(return))totalProbeCount)/length;

	/** Unsafe access to raw store.
	 *
	 * Needed by wrapper containers such as `SSOHybridHashSet`.
	 */
	pragma(inline, true)
	inout(T)[] rawStore() inout @system pure nothrow @nogc => _store.elts;

	static if (hasHoleableKey) {
		static bool isOccupiedBin(in T bin) => (keyOf(bin).isNull && !isHoleKeyConstant(keyOf(bin)));
	}

private:
	import nxt.allocator_traits : AllocatorState;
	mixin AllocatorState!Allocator; // put first as emsi-containers do

	struct Store {
		/** Make store with `capacity` number of slots.
		 *
		 * If `initFlag` is true then initialize the elements.
		 */
		static typeof(this) withCapacity(in size_t capacity, in bool initFlag) @trusted pure nothrow @nogc
		{
			static if (usePrimeCapacity) {
				/+ TODO: check that capacity is prime? +/
			} else {
				debug import std.math : isPowerOf2;
				debug assert(capacity.isPowerOf2); // quadratic probing needs power of two capacity (`_store.elts.length`)
			}
			/+ TODO: cannot use makeArray here because it cannot handle uncopyable types +/
			// import std.experimental.allocator : makeArray;
			// auto store = allocator.makeArray!T(capacity, nullKeyElement);
			import nxt.bit_traits : isAllZeroBits;
			immutable eltByteCount = T.sizeof*capacity;
			static if (!hasHoleableKey) {
				immutable holeByteCount = binBlockBytes(capacity);
				immutable totalByteCount = eltByteCount + holeByteCount;
			} else
				immutable totalByteCount = eltByteCount;
			static if (hasAddressLikeKey ||
					   (__traits(isZeroInit, K)  &&
						__traits(hasMember, K, "nullifier")) ||
					   /+ TODO: add check for __traits(isZeroInit, K) and member `K.nullValue` == `K.init` +/
					   (__traits(hasMember, K, `nullValue`) && // if key has a null value
						__traits(compiles, { enum _ = isAllZeroBits!(K, K.nullValue); }) && // prevent strange error given when `K` is `knet.data.Data`
						isAllZeroBits!(K, K.nullValue))) // check that it's zero bits only
			{
				/+ TODO: use std.experimental.allocator.makeArray instead of this which handles clever checking for isZeroInit +/
				import nxt.container.traits : makeInitZeroArray;
				static if (__traits(hasMember, typeof(allocator), "allocateZeroed") &&
						  is(typeof(allocator.allocateZeroed(totalByteCount))))
					auto rawStore = allocator.allocateZeroed(totalByteCount);
				else {
					auto rawStore = allocator.allocate(totalByteCount);
					(cast(ubyte[])rawStore)[] = 0;	/+ TODO: is this the most efficient way? +/
				}
				if (rawStore.ptr is null &&
					capacity >= 1)
					onOutOfMemoryError();
				static if (!hasHoleableKey) {
					auto holes = rawStore[eltByteCount .. totalByteCount]; /+ TODO: currently unused +/
				}
				auto store = typeof(this)(cast(T[])rawStore[0 .. eltByteCount]);
			} else { // when default null key is not represented by zeros
				// pragma(msg, "emplace:", "K:", K, " V:", V);
				auto rawStore = allocator.allocate(totalByteCount);
				if (rawStore.ptr is null &&
					totalByteCount >= 1)
					onOutOfMemoryError();
				auto store = typeof(this)(cast(T[])rawStore[0 .. eltByteCount]);
				static if (!hasHoleableKey) {
					size_t[] holes = (cast(size_t*)(store.elts.ptr + store.elts.length))[0 .. holesWordCount(capacity)];
					holes[] = 0; /+ TODO: is this the most efficient way? +/
				}
				if (initFlag) {
					foreach (ref bin; store.elts) {
						import core.lifetime : emplace;
						enum hasNullValueKey = __traits(hasMember, K, `nullValue`);
						static if (hasNullValueKey &&
							   !is(typeof(emplace(&keyOf(bin), K.nullValue)))) // __traits(compiles) fails here when building knet
							pragma(msg, __FILE__, ":", __LINE__, ":warning: emplace fails for null-Value key type ", K);
						// initialize key
						static if (hasNullValueKey &&
								   is(typeof(emplace(&keyOf(bin), K.nullValue))))
							emplace(&keyOf(bin), K.nullValue); // initialize in-place with explicit `K.nullValue`
						else {
							emplace(&keyOf(bin)); // initialize in-place with default value
							keyOf(bin).nullify(); // moveEmplace doesn't init source of type `Nullable`
						}
						// initialize value
						static if (hasValue) {
							static if (hasElaborateDestructor!V)
								emplace(&valueOf(bin)); // initialize in-place
							else static if (mustAddGCRange!V)
								valueOf(bin) = V.init;
							else {}	// ok for this case to have uninitialized value part
						}
					}
				}
			}
			static if (mustAddGCRange!T)
				gc_addRange(store.elts.ptr, eltByteCount);
			return store;
		}

		static if (hasFunctionAttributes!(allocator.allocate, "@nogc")) {
			import nxt.gc_traits : NoGc;
			@NoGc T[] elts;		// one element per bin
		} else
			T[] elts;			  // one element per bin
		static if (!hasHoleableKey)
			inout(size_t)* holesPtr() inout @property @trusted pure nothrow @nogc => cast(size_t*)(elts.ptr + elts.length);
	}
	Store _store;

	static if (usePrimeCapacity)
		PrimeIndex _primeIndex = PrimeIndex.init;

	size_t _count;		// total number of (non-null) elements stored in `_store`

	static if (isBorrowChecked) {
		debug { // use Rust-style borrow checking at run-time
			size_t _borrowCount;

			/// Number of bits needed to store number of read borrows.
			enum borrowCountBits = 8*isBorrowChecked.sizeof;

			/// Maximum value possible for `_borrowCount`.
			enum borrowCountMax = 2^^borrowCountBits - 1;

			version (none) {
				/// Number of bits needed to store number of read borrows.
				enum borrowCountBits = 24;

				/// Maximum value possible for `_borrowCount`.
				enum borrowCountMax = 2^^borrowCountBits - 1;

				import std.bitmanip : bitfields;
				mixin(bitfields!(size_t, "_count", 8*size_t.sizeof - borrowCountBits,
								 uint, "_borrowCount", borrowCountBits));
			}

			pragma(inline, true):
			pure nothrow @safe @nogc:

			@property {
				/// Returns: `true` iff `this` is borrowed (either read or write).
				bool isBorrowed() const => _borrowCount >= 1;
				/// Returns: number of borrowers of `this` (both read and write).
				auto borrowCount() const => _borrowCount;
			}

			/// Increase borrow count.
			void incBorrowCount()
			in(_borrowCount + 1 != borrowCountMax) {
				_borrowCount = _borrowCount + 1;
			}

			/// Decrease borrow count.
			void decBorrowCount()
			in(_borrowCount != 0) {
				_borrowCount = _borrowCount - 1;
			}
		}
	}

	/** Returns: bin index of `key`. */
	private size_t keyToIndex(SomeKey)(in SomeKey key) const @trusted {
		version (LDC) pragma(inline, true); /+ TODO: inline always +/

		/** Returns: current index mask from bin count `_store.elts.length`.
		 * TODO: Inline this and check for speed-up.
		 */
		static size_t powerOf2Mask(in size_t length) pure nothrow @safe @nogc {
			version (unittest) {
				/+ TODO: move to in contract: +/
				debug import std.math : isPowerOf2;
				debug assert(length.isPowerOf2); // quadratic probing needs power of two capacity (`_store.elts.length`)
			} else {
				version (D_Coverage) {} else pragma(inline, true);
			}
			return length - 1;
		}

		static if (is(typeof(hasher(key)) == hash_t)) // for instance when hasher being `hashOf`
			immutable hash = hasher(key);
		else static if (is(hasher == struct) || // such as `FNV`
						is(hasher == class)) {
			import nxt.digestion : hashOf2;
			immutable hash = hashOf2!(hasher)(key);
		} else
			static assert(false, "Unsupported hasher of type " ~ typeof(hasher).stringof);
		static if (usePrimeCapacity)
			return moduloPrimeIndex(hash, _primeIndex);
		else
			return hash & powerOf2Mask(_store.elts.length);
	}

	/** Find index to `key` if it exists or to first empty slot found, skipping
	 * (ignoring) lazily deleted slots.
	 */
	private size_t indexOfKeyOrVacancySkippingHoles(in K key) const @trusted scope { // `auto ref` here makes things slow
	/+ TODO: if (...) +/
		version (LDC) pragma(inline, true);
		version (unittest) {
			assert(!key.isNull);
			static if (hasHoleableKey) { assert(!isHoleKeyConstant(key)); }
		}
		static if (options.linearSearchMaxSize != 0)
			if (_store.elts.length * T.sizeof <= options.linearSearchMaxSize) {
				foreach (immutable i, const ref element; _store.elts) // linear search is faster for small arrays
					if ((keyOf(element).isNull ||
						 keyEqualPredFn(keyOf(element), key)))
						return i;
				return _store.elts.length;
			}
		static if (hasHoleableKey)
			alias pred = (in element) => (keyOf(element).isNull ||
										  keyEqualPredFn(keyOf(element), key));
		else
			alias pred = (in index,
						  in element) => (!hasHoleAtPtrIndex(_store.holesPtr, index) &&
										  (keyOf(element).isNull ||
										   keyEqualPredFn(keyOf(element), key)));
		static if (usePrimeCapacity)
			return xxx;
		else
			return _store.elts[].triangularProbeFromIndex!(pred, assumeNonFullHaystack)(keyToIndex(key));
	}

	private size_t indexOfKeyOrVacancyAndFirstHole(in K key, // `auto ref` here makes things slow
												   ref size_t holeIndex) const @trusted scope
	{
		version (LDC) pragma(inline, true);
		version (unittest) {
			assert(!key.isNull);
			static if (hasHoleableKey) { assert(!isHoleKeyConstant(key)); }
		}
		static if (options.linearSearchMaxSize != 0)
			if (_store.elts.length * T.sizeof <= options.linearSearchMaxSize) {
				foreach (immutable i, const ref element; _store.elts) // linear search is faster for small arrays
					if ((keyOf(element).isNull ||
						 keyEqualPredFn(keyOf(element), key)))
						return i;
				return _store.elts.length;
			}
		static if (hasHoleableKey) {
			alias hitPred = (in element) => (keyOf(element).isNull ||
											 keyEqualPredFn(keyOf(element), key));
			alias holePred = (in element) => (isHoleKeyConstant(keyOf(element)));
		} else {
			alias hitPred = (in index,
							 in element) => (!hasHoleAtPtrIndex(_store.holesPtr, index) &&
											 (keyOf(element).isNull ||
											  keyEqualPredFn(keyOf(element), key)));
			alias holePred = (in index, /+ TODO: use only index +/
							  in element) => (hasHoleAtPtrIndex(_store.holesPtr, index));
		}
		static if (usePrimeCapacity)
			return xxx;
		else
			return _store.elts[].triangularProbeFromIndexIncludingHoles!(hitPred, holePred, assumeNonFullHaystack)(keyToIndex(key), holeIndex);
	}

	/// Returns: `true` iff `index` indexes a non-null element, `false` otherwise.
	private bool isOccupiedAtIndex(in size_t index) const {
		version (LDC) pragma(inline, true);
		version (unittest) assert(index < _store.elts.length);
		if (keyOf(_store.elts[index]).isNull) { return false; }
		static if (hasHoleableKey)
			return !isHoleKeyConstant(keyOf(_store.elts[index]));
		else
			return !hasHoleAtPtrIndex(_store.holesPtr, index);
	}
}

/** Duplicate `src` into uninitialized `dst` ignoring prior destruction of `dst`.
 *
 * TODO: Move to a more generic place either in phobos-next or Phobos.
 */
static private void duplicateEmplace(T)(in T src,
										scope ref T dst) @system {
	version (D_Coverage) {} else pragma(inline, true);
	import core.internal.traits : hasElaborateCopyConstructor;
	import std.traits : isBasicType;
	static if (!hasElaborateCopyConstructor!T) {
		import std.typecons : Nullable;
		static if (is(T == class) ||
				   is(T == string))
			dst = cast(T)src;
		else static if (isBasicType!T || is(T == Nullable!(_), _)) // `Nullable` types cannot be emplaced
			dst = src;
		else { /+ TODO: can this case occur? +/
			import core.internal.traits : Unqual;
			import core.lifetime : emplace;
			emplace(&dst, cast(Unqual!T)src);
		}
	}
	else static if (__traits(hasMember, T, "dup")) {
		import core.lifetime : emplace;
		/+ TODO: when `emplace` can handle src being an r-value of uncopyable types replace with: `emplace(&dst, src.dup);` +/
		emplace(&dst);
		dst = src.dup;
	}
	else
		debug static assert(0, "cannot duplicate a " ~ T.stringof);
}

/** L-value element reference (and in turn range iterator).
 */
static private struct LvalueElementRef(SomeMap) {
	import std.traits : isMutable;
	debug static assert(isMutable!SomeMap, "SomeMap type must be mutable");

	private SomeMap* _table;	  // scoped access
	private size_t _binIndex;   // index to bin inside `table`
	private size_t _hitCounter; // counter over number of elements popped (needed for length)

	this(SomeMap* table) @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		this._table = table;
		static if (SomeMap.isBorrowChecked)
			debug { _table.incBorrowCount(); }
	}

	~this() nothrow @nogc @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		static if (SomeMap.isBorrowChecked)
			debug { _table.decBorrowCount(); }
	}

	this(this) @trusted {
		version (D_Coverage) {} else pragma(inline, true);
		static if (SomeMap.isBorrowChecked)
			debug {
				assert(_table._borrowCount != 0);
				_table.incBorrowCount();
			}
	}

	/// Check if empty.
	bool empty() const @property pure nothrow @safe @nogc {
		version (D_Coverage) {} else pragma(inline, true);
		return _binIndex == _table.binCount;
	}

	/// Get number of element left to pop.
	@property size_t length() const pure nothrow @safe @nogc {
		version (D_Coverage) {} else pragma(inline, true);
		return _table.length - _hitCounter;
	}

	@property typeof(this) save() { // ForwardRange
		version (D_Coverage) {} else pragma(inline, true);
		return this;
	}

	void popFront() in(!empty) {
		version (LDC) pragma(inline, true);
		_binIndex += 1;
		findNextNonEmptyBin();
		_hitCounter += 1;
	}

	private void findNextNonEmptyBin() {
		version (D_Coverage) {} else pragma(inline, true);
		while (_binIndex != (*_table).binCount &&
			   !(*_table).isOccupiedAtIndex(_binIndex))
			_binIndex += 1;
	}
}

/** R-value element reference (and in turn range iterator).
 *
 * Does need to do borrow-checking.
 */
static private struct RvalueElementRef(SomeMap) {
	debug import std.traits : isMutable;
	debug static assert(isMutable!SomeMap, "SomeMap type must be mutable");

	SomeMap _table;				// owned table
	size_t _binIndex;			// index to bin inside table
	size_t _hitCounter;	// counter over number of elements popped

	/// Check if empty.
	bool empty() const @property pure nothrow @safe @nogc {
		version (D_Coverage) {} else pragma(inline, true);
		return _binIndex == _table.binCount;
	}

	/// Get number of element left to pop.
	@property size_t length() const pure nothrow @safe @nogc {
		version (D_Coverage) {} else pragma(inline, true);
		return _table.length - _hitCounter;
	}

	void popFront() in(!empty) {
		version (LDC) pragma(inline, true);
		_binIndex += 1;
		findNextNonEmptyBin();
		_hitCounter += 1;
	}

	private void findNextNonEmptyBin() {
		version (D_Coverage) {} else pragma(inline, true);
		while (_binIndex != _table.binCount &&
			   !_table.isOccupiedAtIndex(_binIndex))
			_binIndex += 1;
	}
}

/** Hash set with in-place open-addressing, storing keys (elements) of type `K`.
 *
 * Reuse `HybridHashMap` with its V-type set to `void`.
 *
 * See_Also: `HybridHashMap`.
 */
alias HybridHashSet(K,
					alias hasher = hashOf,
					string keyEqualPred = defaultKeyEqualPredOf!K,
					Allocator = Mallocator,
					Options options = Options.init) =
	HybridHashMap!(K, void, hasher, keyEqualPred, Allocator, options);

import std.functional : unaryFun;

/** Remove all elements in `x` matching `pred`.
 *
 * TODO: make this generic for all iterable containers and move to
 * container/common.d.
 */
size_t removeAllMatching(alias pred, SomeMap)(auto ref SomeMap x) @trusted
if (is(SomeMap == HybridHashMap!(_), _...) && /+ TODO: generalize to `isSetOrMap` +/
	is(typeof((unaryFun!pred)))) {
	import nxt.nullable_traits : nullify;
	size_t removalCount = 0;
	foreach (immutable i, ref bin; x._store.elts) {
		/+ TODO: +/
		// move to SomeMap.removeRef(bin) // uses: `offset = &bin - _store.elts.ptr`
		// move to SomeMap.inplaceRemove(bin) // uses: `offset = &bin - _store.elts.ptr`
		// or   to SomeMap.removeAtIndex(i)
		if (x.isOccupiedAtIndex(i) &&
			unaryFun!pred(bin)) {
			x.tagAsLazilyDeletedElementAtIndex(i);
			removalCount += 1;
		}
	}
	x._count = x._count - removalCount;
	return removalCount;		/+ TODO: remove this return value +/
}

/** Returns: `x` eagerly filtered on `pred`.
 *
 * TODO: move to container/common.d with more generic template restrictions
 */
SomeMap filtered(alias pred, SomeMap)(SomeMap x)
if (is(SomeMap == HybridHashMap!(_), _...)) { /+ TODO: generalize to `isSetOrMap` +/
	import core.lifetime : move;
	import std.functional : not;
	x.removeAllMatching!(not!pred); // `x` is a singleton (r-value) so safe to mutate
	return move(x);			 // functional
}

/** Returns: `x` eagerly intersected with `y`.
 *
 * TODO: move to container/common.d.
 * TODO: Check that `ElementType`'s of `C1` and `C2` match. Look at std.algorithm.intersection for hints.
 */
auto intersectedWith(C1, C2)(C1 x, auto ref C2 y)
if (is(C1 == HybridHashMap!(_1), _1...) && /+ TODO: generalize to `isSetOrMap` +/
	is(C2 == HybridHashMap!(_2), _2...))   /+ TODO: generalize to `isSetOrMap` +/
{
	import core.lifetime : move;
	static if (__traits(isRef, y)) // y is l-value
		// @("complexity", "O(x.length)")
		return move(x).filtered!(_ => y.contains(_)); // only x can be reused
	else {
		/* both are r-values so reuse the shortest */
		// @("complexity", "O(min(x.length), min(y.length))")
		if (x.length < y.length)
			return move(x).filtered!(_ => y.contains(_)); // functional
		else
			return move(y).filtered!(_ => x.contains(_)); // functional
	}
}

/// exercise opEquals
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;

	alias K = Nullable!(ulong, ulong.max);
	alias X = HybridHashSet!(K, FNV!(64, true));

	const n = 100;

	X a;
	foreach (const i_; 0 .. n) {
		const i = 1113*i_;		   // insert in order
		assert(!a.contains(K(i)));
		assert(!a.containsUsingLinearSearch(K(i)));
		assert(a.insertAndReturnElement(K(i)) == K(i));
		assert(a.contains(K(i)));
		assert(a.containsUsingLinearSearch(K(i)));
	}

	X b;
	foreach (const i_; 0 .. n) {
		const i = 1113*(n - 1 - i_);   // insert in reverse
		assert(!b.contains(K(i)));
		assert(!b.containsUsingLinearSearch(K(i)));
		assert(b.insertAndReturnElement(K(i)) == K(i));
		assert(b.contains(K(i)));
		assert(b.containsUsingLinearSearch(K(i)));
	}

	assert(a == b);

	// bin storage must be deterministic
	() @trusted { assert(a._store != b._store); }();
}

pure nothrow @safe @nogc unittest {
	import nxt.digest.fnv : FNV;

	enum Pot { noun, verb }
	struct ExprPot {
		string expr;
		alias nullifier = expr;
		Pot pot;
		static immutable nullValue = typeof(this).init;
	}

	alias X = HybridHashSet!(ExprPot, FNV!(64, true));

	X x;

	const aa = "aa";

	// two keys with same contents but different place in memory
	const key1 = ExprPot(aa[0 .. 1], Pot.noun);
	const key2 = ExprPot(aa[1 .. 2], Pot.noun);

	assert(key1 == key2);
	assert(key1 !is key2);

	assert(!x.contains(key1));
	assert(!x.contains(key2));
	x.insert(key1);
	assert(x.contains(key1));
	assert(x.containsUsingLinearSearch(key1));
	assert(x.contains(key2));
	/* assert(x.containsUsingLinearSearch(key2)); */
	assert(key1 in x);
	assert(key2 in x);
}

/// `string` as key
pure nothrow @safe @nogc unittest {
	import nxt.container.traits : mustAddGCRange;
	import nxt.digest.fnv : FNV;

	alias X = HybridHashSet!(string, FNV!(64, true));
	debug static assert(!mustAddGCRange!X);
	debug static assert(X.sizeof == 24); // dynamic arrays also `hasAddressLikeKey`

	auto x = X();

	auto testEscapeShouldFail()() @safe pure {
		X x;
		x.insert("a");
		return x.byElement;
	}

	auto testEscapeShouldFailFront()() @safe pure {
		X x;
		x.insert("a");
		return x.byElement.front;
	}

	assert(&"a"[0] is &"a"[0]); // string literals are store in common place

	const aa = "aa";

	// string slices are equal when elements are equal regardless of position
	// (.ptr) in memory
	assert(x.insertAndReturnElement(aa[0 .. 1]) !is "a");
	x.insert(aa[0 .. 1]);
	assert(x.insertAndReturnElement(aa[0 .. 1]) is aa[0 .. 1]);
	assert(x.contains(aa[1 .. 2]));
	assert(x.containsUsingLinearSearch(aa[1 .. 2]));

	const(char)[] aa_ = "aa";
	assert(x.contains(aa_[1 .. 2]));
	assert(x.containsUsingLinearSearch(aa_[1 .. 2]));
	assert(aa_[1 .. 2] in x);

	char[2] aa__; aa__ = "aa";
	assert(x.contains(aa__[1 .. 2]));
	assert(x.containsUsingLinearSearch(aa__[1 .. 2]));
	assert(aa__[1 .. 2] in x);

	const bb = "bb";

	assert(x.insertAndReturnElement(bb[0 .. 1]) is bb[0 .. 1]); // returns newly added ref
	assert(x.insertAndReturnElement(bb[0 .. 1]) !is "b");	   // return other ref not equal new literal
	x.insert(bb[0 .. 1]);
	assert(x.contains(bb[1 .. 2]));
	assert(x.containsUsingLinearSearch(bb[1 .. 2]));

	x.remove(aa[0 .. 1]);
	assert(!x.contains(aa[1 .. 2]));
	assert(!x.containsUsingLinearSearch(aa[1 .. 2]));
	assert(x.contains(bb[1 .. 2]));
	assert(x.containsUsingLinearSearch(bb[1 .. 2]));

	x.remove(bb[0 .. 1]);
	assert(!x.contains(bb[1 .. 2]));
	assert(!x.containsUsingLinearSearch(bb[1 .. 2]));

	x.insert("a");
	x.insert("b");
	assert(x.contains("a"));
	assert(x.containsUsingLinearSearch("a"));
	assert(x.contains("b"));
	assert(x.containsUsingLinearSearch("b"));

	debug static assert(!__traits(compiles, { testEscapeShouldFail(); } ));
	/+ TODO: this should fail: +/
	/+ TODO: debug static assert(!__traits(compiles, { testEscapeShouldFailFront(); } )); +/
}

/// `string` as key
pure nothrow @safe unittest {
	import nxt.digest.fnv : FNV;
	alias X = HybridHashSet!(string, FNV!(64, true));
	auto x = X();

	char[2] cc = "cc";		  // mutable chars
	assert(x.insertAndReturnElement(cc[]) !is cc[]); // will allocate new slice

	const cc_ = "cc";		   // immutable chars
	assert(x.insertAndReturnElement(cc_[]) !is cc[]); // will not allocate
}

/// array container as value type
pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;
	import std.typecons : Nullable;
	import nxt.container.traits : mustAddGCRange;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	alias K = Nullable!(uint, uint.max);

	alias VE = Nullable!(uint, uint.max);
	alias V = HybridHashSet!(VE, FNV!(64, true));

	debug static assert(!mustAddGCRange!V);

	foreach (X; AliasSeq!(HybridHashMap!(K, V, FNV!(64, true)))) {
		const VE n = 600;

		auto x = X();

		{					   // scoped range
			auto xkeys = x.byKey;
			assert(xkeys.length == 0);
			foreach (ref key; xkeys) {
				debug static assert(is(typeof(key) == const(K)));
				assert(0);
			}
			foreach (ref key; X().byKey) {
				debug static assert(is(typeof(key) == const(K)));
				assert(0);
			}
		}

		foreach (immutable i; 0 .. n) {
			assert(x.length == i);

			auto key = K(i);
			auto value = V.withElements([VE(i)].s);

			x[key] = value.dup;
			assert(x.length == i + 1);
			assert(x.contains(key));
			/+ TODO: assert(x.containsUsingLinearSearch(key)); +/
			{
				auto valuePtr = key in x;
				assert(valuePtr);
				assert(*valuePtr == value);
			}

			x.remove(key);
			assert(x.length == i);
			assert(!x.contains(key));
			assert(key !in x);

			x[key] = value.dup;
			assert(x.length == i + 1);
			assert(x.contains(key));
			{
				auto valuePtr = key in x;
				assert(valuePtr && *valuePtr == value);
			}
		}

		assert(x is x);

		x = x.dup;

		auto y = x.dup;
		assert(x !is y);
		assert(x.length == y.length);

		assert(y == x);
		assert(x == y);

		foreach (ref key; x.byKey) {
			assert(x.contains(key));
		}

		foreach (ref keyValue; x.byKeyValue) {
			assert(x.contains(keyValue.key));
			auto keyValuePtr = keyValue.key in x;
			assert(keyValuePtr &&
				   *keyValuePtr == keyValue.value);
		}

		foreach (immutable i; 0 .. n) {
			assert(x.length == n - i);

			auto key = K(i);
			auto value = V.withElements([VE(i)].s);

			assert(x.contains(key));
			{
				auto valuePtr = key in x;
				assert(valuePtr && *valuePtr == value);
			}

			x.remove(key);
			assert(!x.contains(key));
			assert(key !in x);
		}

		auto z = y.dup;
		assert(y == z);

		/* remove all elements in `y` using `removeAllMatching` and all elements
		 * in `z` using `removeAllMatching` */
		foreach (immutable i; 0 .. n) {
			assert(y.length == n - i);
			assert(z.length == n - i);

			auto key = K(i);
			auto value = V.withElements([VE(i)].s);

			assert(y.contains(key));
			{
				auto valuePtr = key in y;
				assert(valuePtr && *valuePtr == value);
			}
			assert(z.contains(key));
			{
				auto valuePtr = key in z;
				assert(valuePtr && *valuePtr == value);
			}

			y.remove(key);
			assert(z.removeAllMatching!((in element) => element.key is key) == 1);
			assert(y == z);

			assert(!y.contains(key));
			assert(!z.contains(key));

			assert(key !in y);
			assert(key !in z);
		}
	}
}

/// r-value and l-value intersection
pure nothrow @safe @nogc unittest {
	import core.lifetime : move;
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	alias K = Nullable!(uint, uint.max);
	alias X = HybridHashSet!(K, FNV!(64, true));

	auto x = X();

	{						   // scoped range
		foreach (ref _; x.byElement) { assert(0); }
	}

	auto x0 = X.init;
	assert(x0.length == 0);
	assert(x0._store.elts.length == 0);
	assert(!x0.contains(K(1)));

	auto x1 = X.withElements([K(12)].s);
	assert(x1.length == 1);
	assert(x1.contains(K(12)));

	auto x2 = X.withElements([K(10), K(12)].s);
	assert(x2.length == 2);
	assert(x2.contains(K(10)));
	assert(x2.contains(K(12)));

	auto x3 = X.withElements([K(12), K(13), K(14)].s);
	assert(x3.length == 3);
	assert(x3.contains(K(12)));
	assert(x3.contains(K(13)));
	assert(x3.contains(K(14)));

	auto z = X.withElements([K(10), K(12), K(13), K(15)].s);
	assert(z.length == 4);
	assert(z.contains(K(10)));
	assert(z.contains(K(12)));
	assert(z.contains(K(13)));
	assert(z.contains(K(15)));

	auto y = move(z).intersectedWith(x2);
	assert(y.length == 2);
	assert(y.contains(K(10)));
	assert(y.contains(K(12)));
	assert(y.containsUsingLinearSearch(K(10)));
	assert(y.containsUsingLinearSearch(K(12)));
}

/// r-value and r-value intersection
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	alias K = Nullable!(uint, uint.max);
	alias X = HybridHashSet!(K, FNV!(64, true));

	auto y = X.withElements([K(10), K(12), K(13), K(15)].s).intersectedWith(X.withElements([K(12), K(13)].s));
	assert(y.length == 2);
	assert(y.contains(K(12)));
	assert(y.contains(K(13)));
	assert(y.containsUsingLinearSearch(K(12)));
	assert(y.containsUsingLinearSearch(K(13)));
}

/** Returns: `x` eagerly intersected with `y`.
	TODO: move to container/common.d.
 */
auto intersectWith(C1, C2)(ref C1 x, auto ref const(C2) y)
if (is(C1 == HybridHashMap!(_1), _1) &&
	is(C2 == HybridHashMap!(_2), _2)) {
	return x.removeAllMatching!(_ => !y.contains(_));
}

/// r-value and l-value intersection
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	alias K = Nullable!(uint, uint.max);
	alias X = HybridHashSet!(K, FNV!(64, true));

	auto x = X.withElements([K(12), K(13)].s);
	auto y = X.withElements([K(10), K(12), K(13), K(15)].s);
	y.intersectWith(x);
	assert(y.length == 2);
	assert(y.contains(K(12)));
	assert(y.containsUsingLinearSearch(K(12)));
	assert(y.contains(K(13)));
	assert(y.containsUsingLinearSearch(K(13)));
}

/// Range over elements of l-value instance of this.
static struct ByLvalueElement(SomeMap) // public for now because this is needed in `knet.zing.Zing.EdgesOfRels`
{
	import nxt.container.traits : isAddress;
pragma(inline, true):
	/+ TODO: functionize +/
	static if (isAddress!(SomeMap.ElementType)) // for reference types
	{
		/// Get reference to front element.
		@property scope SomeMap.ElementType front()() return @trusted {
			// cast to head-const for class key
			return (cast(typeof(return))_table._store.elts[_binIndex]);
		}
	}
	else {
		/// Get reference to front element.
		@property scope auto ref front() return @trusted {
			return *(cast(const(SomeMap.ElementType)*)&_table._store.elts[_binIndex]); // propagate constnes
		}
	}
	import core.internal.traits : Unqual;
	// unqual to reduce number of instantations of `LvalueElementRef`
	public LvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

/// Range over elements of r-value instance of this.
static private struct ByRvalueElement(SomeMap) {
	import nxt.container.traits : isAddress;
	this(this) @disable;
pragma(inline, true):
	static if (isAddress!(SomeMap.ElementType)) // for reference types
	{
		/// Get reference to front element.
		@property scope SomeMap.ElementType front()() return @trusted {
			// cast to head-const for class key
			return cast(typeof(return))_table._store.elts[_binIndex];
		}
	} else {
		/// Get reference to front element.
		@property auto ref front() return scope {
			return *(cast(const(SomeMap.ElementType)*)&_table._store.elts[_binIndex]); // propagate constnes
		}
	}
	import core.internal.traits : Unqual;
	public RvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

/** Returns: range that iterates through the elements of `c` in undefined order.
 */
auto byElement(SomeMap)(auto ref return SomeMap c) @trusted
if (is(SomeMap == HybridHashMap!(_), _...) &&
	!SomeMap.hasValue) {
	import core.internal.traits : Unqual;
	alias M = Unqual!SomeMap;
	alias C = const(SomeMap);		// be const for now
	static if (__traits(isRef, c)) // `c` is an l-value
		auto result = ByLvalueElement!C((LvalueElementRef!(M)(cast(M*)&c)));
	else { // `c` was is an r-value and can be moved
		import core.lifetime : move;
		auto result = ByRvalueElement!C((RvalueElementRef!(M)(move(*(cast(M*)&c))))); // reinterpret
	}
	result.findNextNonEmptyBin();
	return result;
}
alias range = byElement;		// EMSI-container naming

static private struct ByKey_lvalue(SomeMap)
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	@property auto ref front() const return scope // key access must be const, TODO: auto ref => ref K
	{
		version (D_Coverage) {} else pragma(inline, true);
		return _table._store.elts[_binIndex].key;
	}
	import core.internal.traits : Unqual;
	public LvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

static private struct ByKey_rvalue(SomeMap)
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	@property auto ref front() const return scope // key access must be const, TODO: auto ref => ref K
	{
		version (D_Coverage) {} else pragma(inline, true);
		return _table._store.elts[_binIndex].key;
	}
	import core.internal.traits : Unqual;
	public RvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

/** Returns: range that iterates through the keys of `c` in undefined order.
 */
auto byKey(SomeMap)(auto ref /*TODO: return*/ SomeMap c) @trusted
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	import core.internal.traits : Unqual;
	alias M = Unqual!SomeMap;
	alias C = const(SomeMap);		// be const
	static if (__traits(isRef, c)) // `c` is an l-value
		auto result = ByKey_lvalue!C((LvalueElementRef!(M)(cast(M*)&c)));
	else { // `c` was is an r-value and can be moved
		import core.lifetime : move;
		auto result = ByKey_rvalue!C((RvalueElementRef!M(move(*(cast(M*)&c))))); // reinterpret
	}
	result.findNextNonEmptyBin();
	return result;
}

static private struct ByValue_lvalue(SomeMap)
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	@property scope auto ref front() return @trusted /+ TODO: auto ref => ref V +/
	{
		version (D_Coverage) {} else pragma(inline, true);
		/+ TODO: functionize +/
		import std.traits : isMutable;
		static if (isMutable!(SomeMap)) /+ TODO: can this be solved without this `static if`? +/
			alias E = SomeMap.ValueType;
		else
			alias E = const(SomeMap.ValueType);
		return *(cast(E*)&_table._store.elts[_binIndex].value);
	}
	import core.internal.traits : Unqual;
	public LvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

static private struct ByValue_rvalue(SomeMap)
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	@property scope auto ref front() return @trusted /+ TODO: auto ref => ref V +/
	{
		version (D_Coverage) {} else pragma(inline, true);
		/+ TODO: functionize +/
		import std.traits : isMutable;
		static if (isMutable!(SomeMap)) /+ TODO: can this be solved without this `static if`? +/
			alias E = SomeMap.ValueType;
		else
			alias E = const(SomeMap.ValueType);
		return *(cast(E*)&_table._store.elts[_binIndex].value);
	}
	import core.internal.traits : Unqual;
	public RvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

/** Returns: range that iterates through the values of `c` in undefined order.
 */
auto byValue(SomeMap)(auto ref return SomeMap c) @trusted
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	import core.internal.traits : Unqual;
	import std.traits : isMutable;
	alias M = Unqual!SomeMap;
	alias C = const(SomeMap);
	static if (__traits(isRef, c)) // `c` is an l-value
		auto result = ByValue_lvalue!SomeMap((LvalueElementRef!(M)(cast(M*)&c)));
	else						// `c` was is an r-value and can be moved
	{
		import core.lifetime : move;
		auto result = ByValue_rvalue!C((RvalueElementRef!M(move(*(cast(M*)&c))))); // reinterpret
	}
	result.findNextNonEmptyBin();
	return result;
}

static private struct ByKeyValue_lvalue(SomeMap)
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	@property scope auto ref front() return @trusted /+ TODO: auto ref => ref T +/
	{
		version (D_Coverage) {} else pragma(inline, true);
		/+ TODO: functionize +/
		import std.traits : isMutable;
		static if (isMutable!(SomeMap))
			alias E = SomeMap.KeyValueType;
		else
			alias E = const(SomeMap.T);
		return *(cast(E*)&_table._store.elts[_binIndex]);
	}
	import core.internal.traits : Unqual;
	public LvalueElementRef!(Unqual!SomeMap) _elementRef;
	alias _elementRef this;
}

/** Returns: range that iterates through the key-value-pairs of `c` in undefined order.
 */
auto byKeyValue(SomeMap)(auto ref return SomeMap c) @trusted
if (is(SomeMap == HybridHashMap!(_), _...) &&
	SomeMap.hasValue) {
	import core.internal.traits : Unqual;
	alias M = Unqual!SomeMap;
	static if (__traits(isRef, c)) // `c` is an l-value
		auto result = ByKeyValue_lvalue!SomeMap((LvalueElementRef!(M)(cast(M*)&c)));
	else						// `c` was is an r-value and can be moved
	{
		import core.lifetime : move;
		auto result = ByKeyValue_rvalue!SomeMap((RvalueElementRef!M(move(*(cast(M*)&c))))); // reinterpret
	}
	result.findNextNonEmptyBin();
	return result;
}

/// make range from l-value and r-value. element access is always const
pure @safe unittest {
	import core.exception : AssertError;
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;
	debug import std.exception : assertThrown;

	import std.algorithm.searching : count;
	alias K = Nullable!(uint, uint.max);
	alias X = HybridHashSet!(K, FNV!(64, true), defaultKeyEqualPredOf!K, Mallocator, Options(GrowOnlyFlag.no, BorrowCheckFlag.yes));

	auto k11 = K(11);
	auto k22 = K(22);
	auto k33 = K(33);
	auto ks = [k11, k22, k33].s;
	auto k44 = K(44);

	// mutable
	auto x = X.withElements(ks);
	assert(!x.contains(k44));
	assert(!x.containsUsingLinearSearch(k44));
	assert(x.length == 3);

	assert(x.byElement.count == x.length);
	foreach (e; x.byElement)	// from l-value
	{
		debug static assert(is(typeof(e) == const(K))); // always const access

		// range invalidation forbidden:
		debug
		{
			assertThrown!AssertError(x.reserveExtra(1));  // range invalidation
			assertThrown!AssertError(x.clear());		  // range invalidation
			assertThrown!AssertError(x.insert(k11));	  // range invalidation
			assertThrown!AssertError(x.insertN([k11].s)); // range invalidation
			assertThrown!AssertError(x.remove(k11));	  // range invalidation
		}

		// allowed
		assert(x.contains(e));
		assert(x.containsUsingLinearSearch(e));

		const eHit = e in x;
		assert(eHit);		   // found
		assert(*eHit is e);	 // and the value equals what we searched for

		const eDup = x.dup;	 // duplication is `const` and allowed
		assert(eDup == x);
	}

	// const
	const y = X.withElements(ks);
	assert(!x.contains(k44));
	assert(!x.containsUsingLinearSearch(k44));
	foreach (e; y.byElement)	// from l-value
	{
		auto _ = y.byElement;   // ok to read-borrow again
		assert(y.contains(e));
		assert(y.containsUsingLinearSearch(e));
		debug static assert(is(typeof(e) == const(K)));
	}

	foreach (e; X.withElements([K(11)].s).byElement) // from r-value
	{
		assert(e == K(11));
		debug static assert(is(typeof(e) == const(K))); // always const access
	}
}

/// range checking
pure @safe unittest {
	import core.exception : RangeError;
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;
	debug import std.exception : assertThrown, assertNotThrown;
	immutable n = 11;

	alias K = Nullable!(uint, uint.max);
	alias V = uint;

	alias X = HybridHashMap!(K, V, FNV!(64, true));

	auto s = X.withCapacity(n);

	void dummy(ref V value) {}

	debug assertThrown!RangeError(dummy(s[K(0)]));

	foreach (immutable i; 0 .. n) {
		const k = K(i);
		s[k] = V(i);
		debug assertNotThrown!RangeError(dummy(s[k]));
	}

	foreach (immutable i; 0 .. n) {
		const k = K(i);
		assert(s.remove(k));
		debug assertThrown!RangeError(dummy(s[k]));
	}

	s[K(0)] = V.init;
	auto vp = K(0) in s;
	debug static assert(is(typeof(vp) == V*));
	assert((*vp) == V.init);

	assert(s.remove(K(0)));
	assert(K(0) !in s);

	X t;
	t.reserveExtra(4096);

	t.clear();
}

/// class as value
pure @safe unittest {
	import core.exception : RangeError;
	import std.typecons : Nullable;
	debug import std.exception : assertThrown, assertNotThrown;
	import nxt.digest.fnv : FNV;

	immutable n = 11;

	alias K = Nullable!(uint, uint.max);
	class V
	{
		this(uint data) { this.data = data; }
		uint data;
	}

	alias X = HybridHashMap!(K, V, FNV!(64, true));

	auto s = X.withCapacity(n);

	void dummy(ref V value) {}

	debug assertThrown!RangeError(dummy(s[K(0)]));

	foreach (immutable i; 0 .. n) {
		const k = K(i);
		s[k] = new V(i);
		debug assertNotThrown!RangeError(dummy(s[k]));
	}

	// test range
	{
		auto sr = s.byKeyValue; // scoped range
		assert(sr.length == n);
		foreach (immutable i; 0 .. n) {
			sr.popFront();
			assert(sr.length == n - i - 1);
		}
	}

	foreach (immutable i; 0 .. n) {
		const k = K(i);
		assert(s.remove(k));
		debug assertThrown!RangeError(dummy(s[k]));
	}

	s[K(0)] = V.init;
	auto vp = K(0) in s;
	debug static assert(is(typeof(vp) == V*));

	assert(s.remove(K(0)));
	assert(K(0) !in s);

	X t;
	t.reserveExtra(4096);
}

/// constness inference of ranges
pure nothrow unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;

	alias K = Nullable!(uint, uint.max);
	class V
	{
		this(uint data) { this.data = data; }
		uint data;
	}

	alias X = HybridHashMap!(K, V, FNV!(64, true));
	const x = X();

	foreach (const e; x.byKey) {
		debug static assert(is(typeof(e) == const(X.KeyType)));
	}

	foreach (const e; x.byValue) {
		debug static assert(is(typeof(e) == const(X.ValueType)));
	}

	foreach (const e; X.init.byValue) {
		debug static assert(is(typeof(e) == const(X.ValueType)));
	}

	foreach (const e; x.byKeyValue) {
		debug static assert(is(typeof(e.key) == const(X.KeyType)));
		debug static assert(is(typeof(e.value) == const(X.ValueType)));
		debug static assert(is(typeof(e) == const(X.ElementType)));
	}
}

/// range key constness and value mutability with `class` value
pure nothrow unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;

	struct S
	{
		uint value;
	}
	alias K = Nullable!(S, S(uint.min)); // use uint.min to trigger use of faster `allocator.allocateZeroed`

	class V
	{
		this(uint data) { this.data = data; }
		uint data;
	}

	alias X = HybridHashMap!(K, V, FNV!(64, true));
	auto x = X();

	x[K(S(42))] = new V(43);

	assert(x.length == 1);

	foreach (e; x.byValue)	  // `e` is auto ref
	{
		debug static assert(is(typeof(e) == X.ValueType)); // mutable access to value
		assert(e.data == 43);

		// value mutation side effects
		e.data += 1;
		assert(e.data == 44);
		e.data -= 1;
		assert(e.data == 43);
	}

	foreach (ref e; x.byKeyValue)   // `e` is auto ref
	{
		debug static assert(is(typeof(e.key) == const(X.KeyType))); // const access to key
		debug static assert(is(typeof(e.value) == X.ValueType)); // mutable access to value

		assert(e.key.value == 42);
		assert(e.value.data == 43);

		// key cannot be mutated
		debug static assert(!__traits(compiles, { e.key.value += 1; }));

		// value mutation side effects
		e.value.data += 1;
		assert(e.value.data == 44);
		e.value.data -= 1;
		assert(e.value.data == 43);
	}
}

/// range key constness and value mutability with `class` key and `class` value
pure nothrow unittest {
	import nxt.digest.fnv : FNV;

	class K
	{
		this(uint value) {
			this.value = value;
		}

		@property bool opEquals(in typeof(this) rhs) const
		{
			return value == rhs.value;
		}

		uint value;
	}

	class V
	{
		this(uint data) { this.data = data; }
		uint data;
	}

	alias X = HybridHashMap!(K, V, FNV!(64, true));
	auto x = X();

	x[new K(42)] = new V(43);

	assert(x.length == 1);

	foreach (e; x.byValue)	  // `e` is auto ref
	{
		debug static assert(is(typeof(e) == X.ValueType)); // mutable access to value
		assert(e.data == 43);

		// value mutation side effects
		e.data += 1;
		assert(e.data == 44);
		e.data -= 1;
		assert(e.data == 43);
	}

	foreach (ref e; x.byKeyValue)   // `e` is auto ref
	{
		debug static assert(is(typeof(e.key) == X.KeyType)); // mutable access to class key
		debug static assert(is(typeof(e.value) == X.ValueType)); // mutable access to value

		assert(e.key.value == 42);
		assert(e.value.data == 43);

		// class key itself should not be mutable
		debug static assert(!__traits(compiles, { e.key = null; }));

		// members of key can be mutated
		debug static assert(__traits(compiles, { e.key.value += 1; }));

		// value mutation side effects
		e.value.data += 1;
		assert(e.value.data == 44);
		e.value.data -= 1;
		assert(e.value.data == 43);
	}
}

/// range key constness and value mutability with `class` key and `class` value
pure nothrow unittest {
	import nxt.digest.fnv : FNV;
	class K
	{
		this(uint value) scope {
			this.value = value;
		}
		uint value;
	}

	struct V
	{
		this(uint data) { this.data = data; }
		this(this) @disable;
		uint data;
	}

	alias X = HybridHashMap!(K, V, FNV!(64, true));
	auto x = X();

	scope key42 = new K(42);
	() @trusted { x[key42] = V(43); }(); // TODO: qualify `HybridHashMap.opIndexAssign` with @trusted and remove

	assert(x.length == 1);

	foreach (ref e; x.byValue)  // `e` is auto ref
	{
		debug static assert(is(typeof(e) == X.ValueType)); // mutable access to value
		assert(e.data == 43);

		// value mutation side effects
		e.data += 1;
		assert(e.data == 44);
		e.data -= 1;
		assert(e.data == 43);
	}

	foreach (ref e; x.byKeyValue) // `e` is auto ref
	{
		debug static assert(is(typeof(e.key) == X.KeyType)); // mutable access to class key
		debug static assert(is(typeof(e.value) == X.ValueType)); // mutable access to value

		assert(e.key.value == 42);
		assert(e.value.data == 43);

		// value mutation side effects
		e.value.data += 1;
		assert(e.value.data == 44);
		e.value.data -= 1;
		assert(e.value.data == 43);
	}

	assert(x.length == 1);

	assert(x.remove(key42));
	assert(x.length == 0);

	() @trusted { x[key42] = V(43); }(); // TODO: qualify `HybridHashMap.opIndexAssign` with @trusted and remove
	assert(x.length == 1);
}

version (unittest) {
	T make(T)(ulong value) {
		static if (is(T == class))
			return new T(value);
		else
			return T(value);
	}
}

/// test various things
@trusted unittest {
	import std.meta : AliasSeq;
	import std.typecons : Nullable;
	import std.algorithm.comparison : equal;
	import nxt.container.traits : mustAddGCRange;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	const n = 100;

	void testEmptyAll(K, V, X)(ref X x, size_t n,
							   scope K[] keys) {
		assert(x.length == n);
		foreach (key; keys) {
			static if (X.hasValue)
				const element = X.ElementType(key, V.init);
			else
				alias element = key;

			assert(x.length == n - key.get);

			const hitPtr = key in x;
			static if (X.hasValue)
				assert(hitPtr && *hitPtr is element.value);
			else
				assert(hitPtr && *hitPtr is element);

			assert(x.remove(key));
			assert(x.length == n - key.get - 1);

			static if (!X.hasValue) {
				assert(!x.contains(key));
				assert(!x.containsUsingLinearSearch(key));
			}
			assert(key !in x);
			assert(!x.remove(key));
			assert(x.length == n - key.get - 1);
		}

		assert(x.length == 0);

		x.clear();
		assert(x.length == 0);
	}

	X testDup(X)(scope ref X x, size_t n) {
		typeof(return) y = x.dup;

		assert(x._store.elts.ptr !is y._store.elts.ptr);
		assert(x.length == y.length);
		assert(y.length == n);
		// non-symmetric algorithm so both are needed
		assert(y == x);
		assert(x == y);

		static if (X.hasValue) {
			assert(equal(x.byKey,
						 y.byKey));
			assert(equal(x.byValue,
						 y.byValue));
			auto a = x.byKeyValue;
			auto b = y.byKeyValue;
			size_t i = 0;
			while (!a.empty &&
				   !b.empty) {
				a.popFront();
				b.popFront();
				i++;
			}
			auto xR = x.byKeyValue;
			auto yR = y.byKeyValue;
			assert(xR.length == yR.length);
			size_t ix = 0;
			while (!xR.empty &&
				   !yR.empty) {
				auto xK = xR.front.key;
				auto yK = yR.front.key;
				auto xV = xR.front.value;
				auto yV = yR.front.value;
				// import std.stdio : writeln;
				// writeln("ix:", ix, " xV:", xV, " yV:", yV);
				assert(xK == yK);
				assert(xV == yV);
				assert(xR.front == yR.front);
				xR.popFront();
				yR.popFront();
				ix++;
			}
			assert(equal(x.byKeyValue,
						 y.byKeyValue));
		}
		else
			assert(equal(x.byElement,
						 y.byElement));

		debug static assert(!__traits(compiles, { const _ = x < y; })); // no ordering

		return y;
	}

	alias NullableUlong = Nullable!(ulong, ulong.max);

	static class SomeSimpleClass
	{
		pure nothrow @safe @nogc
		this(ulong value) {
			this._value = value;
		}

		pure nothrow @safe @nogc
		ulong get() const => _value;

		void toString(Sink)(ref scope Sink sink) const {
			import std.format : formattedWrite;
			sink.formattedWrite(typeof(this).stringof, "(%s)", _value);
		}

		@property bool opEquals(in typeof(this) rhs) => _value == rhs._value;

		private ulong _value;
	}

	debug static assert(mustAddGCRange!string);

	foreach (K; AliasSeq!(SomeSimpleClass,
						  NullableUlong)) {
		foreach (V; AliasSeq!(string, int, void)) {
			alias X = HybridHashMap!(K, V, FNV!(64, true));

			static if (!X.hasValue) {
				auto k11 = make!K(11);
				auto k12 = make!K(12);
				auto k13 = make!K(13);

				auto x = X.withElements([k11, k12, k13].s);

				import std.algorithm : count;

				// ByLvalueElement
				auto xr = x.byElement;

				alias R = typeof(xr);
				import std.range.primitives : isInputRange;
				import std.traits : ReturnType;
				debug static assert(is(typeof(R.init) == R));
				debug static assert(is(ReturnType!((R xr) => xr.empty) == bool));

				/+ TODO: Is this needed? debug static assert(!__traits(compiles, { xr.front == K.init; })); // always head-const +/
				auto f = xr.front;
				static if (is(K == class)) {
					debug static assert(is(typeof(f) == K)); // tail-mutable
				}
				else
				{
					debug static assert(is(typeof(f) == const(K))); // tail-const
				}

				debug static assert(is(typeof((R xr) => xr.front)));
				debug static assert(!is(ReturnType!((R xr) => xr.front) == void));
				debug static assert(is(typeof((R xr) => xr.popFront)));

				debug static assert(isInputRange!(typeof(xr)));

				assert(x.byElement.count == 3);

				X y;
				size_t ix = 0;
				foreach (ref e; x.byElement) {
					assert(x.contains(e));
					assert(x.containsUsingLinearSearch(e));
					assert(!y.contains(e));
					assert(!y.containsUsingLinearSearch(e));
					static if (is(K == class))
						y.insert(cast(K)e); // ugly but ok in tests
					else
						y.insert(e);
					assert(y.contains(e));
					assert(y.containsUsingLinearSearch(e));
					ix++;
				}

				assert(y.byElement.count == 3);
				assert(x == y);

				const z = X();
				assert(z.byElement.count == 0);

				immutable w = X();
				assert(w.byElement.count == 0);

				{
					auto xc = X.withElements([k11, k12, k13].s);
					assert(xc.length == 3);
					assert(xc.contains(k11));
					assert(xc.containsUsingLinearSearch(k11));

					/+ TODO: http://forum.dlang.org/post/kvwrktmameivubnaifdx@forum.dlang.org +/
					xc.removeAllMatching!(_ => _ == k11);

					assert(xc.length == 2);
					assert(!xc.contains(k11));
					assert(!xc.containsUsingLinearSearch(k11));

					xc.removeAllMatching!(_ => _ == k12);
					assert(!xc.contains(k12));
					assert(!xc.containsUsingLinearSearch(k12));
					assert(xc.length == 1);

					xc.removeAllMatching!(_ => _ == k13);
					assert(!xc.contains(k13));
					assert(!xc.containsUsingLinearSearch(k13));
					assert(xc.length == 0);

					// this is ok
					foreach (_; xc.byElement) {}
				}

				{			   // ByRvalueElement
					auto k = X.withElements([k11, k12].s).filtered!(_ => _ != k11).byElement;
					debug static assert(isInputRange!(typeof(k)));
					assert(k.front == k12);

					debug static assert(!__traits(compiles, { k.front = K.init; })); // head-const
					static if (is(K == class)) {
						debug static assert(is(typeof(k.front) == K)); // tail-mutable
					}
					else
					{
						debug static assert(is(typeof(k.front) == const(K))); // tail-const
					}

					k.popFront();
					assert(k.empty);
				}

				{
					X q;
					auto qv = [make!K(11U), make!K(12U), make!K(13U), make!K(14U)].s;
					q.insertN(qv[]);
					foreach (e; qv[]) {
						assert(q.contains(e));
						assert(q.containsUsingLinearSearch(e));
					}
					q.clear();
					assert(q.empty);
				}
			}

			static if (is(V == string)) {
				debug static assert(mustAddGCRange!V);
				debug static assert(mustAddGCRange!(V[1]));
				debug static assert(mustAddGCRange!(X.T));
			}

			auto x1 = X();			// start empty

			// fill x1

			import std.array : Appender;
			Appender!(K[]) keys;

			foreach (immutable key_; 0 .. n) {
				auto key = make!K(key_);
				keys.put(key);

				// create elements
				static if (X.hasValue) {
					auto value = V.init;
					auto element = X.ElementType(key, value);
				}
				else
					// no assignment because Nullable.opAssign may leave rhs in null state
					auto element = key;

				assert(key !in x1);

				assert(x1.length == key.get);
				assert(x1.insert(element) == X.InsertionStatus.added);
				assert(x1.length == key.get + 1);

				static if (X.hasValue) {
					import std.conv : to;
					auto e2 = X.ElementType(key, (42 + key_).to!V);
					assert(x1.insert(e2) == X.InsertionStatus.modified);
					assert(x1.contains(key));
					assert(x1.get(key, V.init) == (42 + key_).to!V);

					assert(x1.remove(key));
					assert(!x1.contains(key));

					x1[key] = value; // restore value
					assert(x1.contains(key));
				}

				assert(x1.length == key.get + 1);

				const hitPtr = key in x1;
				static if (X.hasValue)
					assert(hitPtr && *hitPtr == value);
				else
					assert(hitPtr && *hitPtr is key);

				auto status = x1.insert(element);
				assert(status == X.InsertionStatus.unmodified);
				static if (X.hasValue)
					assert(x1.insert(key, value) == X.InsertionStatus.unmodified);
				assert(x1.length == key.get + 1);

				assert(key in x1);
			}

			static if (X.hasValue) {
				import nxt.container.dynamic_array : Array = DynamicArray;
				Array!(X.ElementType) a1; // remember the keys

				foreach (const ref key; x1.byKey) {
					auto keyPtr = key in x1;
					assert(keyPtr);
					a1 ~= X.ElementType(cast(K)key, (*keyPtr));
				}

				assert(x1.length == a1.length);

				foreach (ae; a1[]) {
					auto keyPtr = ae.key in x1;
					assert(keyPtr);
					assert((*keyPtr) is ae.value);
				}
			}

			assert(x1.length == n);

			auto x2 = testDup(x1, n);

			testEmptyAll!(K, V)(x1, n, keys.data);

			testEmptyAll!(K, V)(x2, n, keys.data); // should be not affected by emptying of x1
		}
	}
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;
	import nxt.digest.fnv : FNV;

	alias X = HybridHashMap!(Nullable!(size_t, size_t.max), size_t, FNV!(64, true));
	X x;
	assert(x.empty);
	// import nxt.container.dynamic_array : Array = DynamicArray;
	/+ TODO: these segfault: +/
	/+ TODO: auto a = Array!(X.KeyType).withElementsOfRange_untested(x.byKey); // l-value byKey +/
	/+ TODO: auto b = Array!(X.KeyType).withElementsOfRange_untested(X().byKey); // r-value byKey +/
}

/// manual Nullable type
pure @safe unittest {
	import nxt.nullable_traits : isNullable;
	import nxt.digest.fnv : FNV;

	static class Zing {
		pure nothrow @safe @nogc:
		this(ulong value) { this._value = value; }
		private ulong _value;
	}
	debug static assert(isNullable!Zing);

	enum Alt { unknown, a, b, c, d }

	struct ZingRelation {
		Zing zing;
		Alt alts;

		alias nullifier = zing;
		static immutable nullValue = typeof(this).init;

		bool opEquals(in typeof(this) that) const pure nothrow @safe @nogc
			=> (this.zing is that.zing && this.alts == that.alts);
	}
	debug static assert(isNullable!ZingRelation);

	alias X = HybridHashSet!(ZingRelation, FNV!(64, true));
	debug static assert(X.sizeof == 24);
	X x;

	scope e = ZingRelation(new Zing(42), Alt.init);

	assert(!x.contains(e));
	assert(!x.containsUsingLinearSearch(e));
	assert(x.insert(e) == X.InsertionStatus.added);
	assert(x.contains(e));
	assert(x.containsUsingLinearSearch(e));
}

/// abstract class value type
@safe unittest {
	static abstract class Zing {
		pure nothrow @safe @nogc:
	}
	static class Node : Zing {
		pure nothrow @safe @nogc:
	}

	alias X = HybridHashSet!(Zing);
	X x;

	const Zing cz = new Node();
	x.insert(cz);			   // ok to insert const

	Zing z = new Node();
	x.insert(z); // ok to insert mutable because hashing is on address by default
}

/// class type with default hashing
@safe unittest {
	static class Base {
		static size_t dtorCount = 0; // number of calls to this destructor
	@safe nothrow @nogc:
		~this() nothrow @nogc { dtorCount += 1; }
	pure:
		this(ulong value) { this._value = value; }
		@property bool opEquals(in typeof(this) rhs) const => _value == rhs._value;
		override hash_t toHash() const => hashOf(_value);
		private ulong _value;
	}

	/** Node containing same data members but different type. */
	static class Node : Base {
		pure nothrow @safe @nogc:
		this(ulong value) { super(value);  }
	}
	debug static assert(is(Node : Base));

	import nxt.hash_functions : hashOfPolymorphic; // neede to separate hash of `Base(N)` from `Node(N)`
	alias X = HybridHashSet!(Base, hashOfPolymorphic, "a && b && (typeid(a) is typeid(b)) && a.opEquals(b)");
	debug static assert(X.sizeof == 24);
	X x;

	// top-class
	auto b42 = new Base(42);	/+ TODO: qualify as scope when hashOf parameter arg is scope +/
	assert(!x.contains(b42));
	assert(!x.containsUsingLinearSearch(b42));
	assert(x.insert(b42) == X.InsertionStatus.added);
	assert(x.contains(b42));
	assert(x.containsUsingLinearSearch(b42));
	assert(x.tryGetElementFromCtorParams!Base(42) !is null);
	assert(Base.dtorCount == 1);
	assert(x.tryGetElementFromCtorParams!Base(42)._value == 42);
	assert(Base.dtorCount == 2);
	assert(x.tryGetElementFromCtorParams!Base(41) is null);
	assert(Base.dtorCount == 3);

	// top-class
	auto b43 = new Base(43);	/+ TODO: qualify as scope when hashOf parameter arg is scope +/
	assert(!x.contains(b43));
	assert(!x.containsUsingLinearSearch(b43));
	assert(x.insert(b43) == X.InsertionStatus.added);
	assert(x.contains(b43));
	assert(x.containsUsingLinearSearch(b43));
	assert(x.tryGetElementFromCtorParams!Base(43) !is null);
	assert(Base.dtorCount == 4);
	assert(x.tryGetElementFromCtorParams!Base(43)._value == 43);
	assert(Base.dtorCount == 5);

	// sub-class
	assert(x.tryGetElementFromCtorParams!Node(42) is null);
	assert(Base.dtorCount == 6);
	immutable n42 = new Node(42);
	assert(!x.contains(n42));	 // mustn't equal to `b42`
	assert(!x.containsUsingLinearSearch(n42)); // mustn't equal to `b42`
	assert(x.insert(n42) == X.InsertionStatus.added); // added as separate type
	assert(x.contains(n42));
	assert(x.containsUsingLinearSearch(n42));
	assert(x.tryGetElementFromCtorParams!Node(42) !is null);
	assert(Base.dtorCount == 7);
	assert(x.tryGetElementFromCtorParams!Node(42)._value == 42);
	assert(Base.dtorCount == 8);

	assert(hashOf(b42) == hashOf(n42));

	// sub-class
	assert(x.tryGetElementFromCtorParams!Node(43) is null);
	assert(Base.dtorCount == 9);
	auto n43 = new Node(43);
	assert(!x.contains(n43));	 // mustn't equal to `b43`
	assert(!x.containsUsingLinearSearch(n43)); // mustn't equal to `b43`
	assert(x.insert(n43) == X.InsertionStatus.added); // added as separate type
	assert(x.contains(n43));
	assert(x.containsUsingLinearSearch(n43));
	assert(x.tryGetElementFromCtorParams!Node(43) !is null);
	assert(Base.dtorCount == 10);
	assert(x.tryGetElementFromCtorParams!Node(43)._value == 43);
	assert(Base.dtorCount == 11);

	assert(hashOf(b43) == hashOf(n43));
}

/// enumeration key
pure @safe unittest {
	import nxt.digest.fnv : FNV;

	enum Alt {
		nullValue,			  // trait
		a, b, c, d
	}
	alias X = HybridHashSet!(Alt, FNV!(64, true));
	X x;
	assert(!x.contains(Alt.a));

	assert(x.insert(Alt.a) == X.InsertionStatus.added);

	assert(x.contains(Alt.a));
	assert(x.containsUsingLinearSearch(Alt.a));
	assert(!x.contains(Alt.b));
	assert(!x.contains(Alt.c));
	assert(!x.contains(Alt.d));
	assert(!x.containsUsingLinearSearch(Alt.b));
	assert(!x.containsUsingLinearSearch(Alt.c));
	assert(!x.containsUsingLinearSearch(Alt.d));

	assert(x.remove(Alt.a));
	assert(!x.contains(Alt.a));
	assert(!x.containsUsingLinearSearch(Alt.a));
}

///
pure nothrow @safe unittest {
	import nxt.digest.fnv : FNV;
	static struct Rel {
		static immutable nullValue = typeof(this).init;
		string name;			// relation name. WARNING compiler crashes when qualified with `package`
	}
	alias X = HybridHashSet!(Rel, FNV!(64, true));
	X x;
	foreach (const i; 0 .. 100) {
		const char[1] ch = ['a' + i];
		assert(!x.contains(Rel(ch.idup)));
		assert(!x.containsUsingLinearSearch(Rel(ch.idup)));
		x.insert(Rel(ch.idup));
		assert(x.contains(Rel(ch.idup)));
		/* TODO: assert(x.containsUsingLinearSearch(Rel(ch.idup))); */
	}
}

/// `SSOString` as set key type
pure nothrow @safe @nogc unittest {
	import nxt.sso_string : SSOString;
	import nxt.digest.fnv : FNV;

	alias K = SSOString;
	static assert(isHoleable!K);
	alias X = HybridHashSet!(K, FNV!(64, true));
	const n = 100;

	X a;
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + i];
		const k = K(ch);		// @nogc

		assert(!a.contains(k));
		assert(!a.containsUsingLinearSearch(k));

		assert(a.insert(K(ch)) == X.InsertionStatus.added);
		/+ TODO: assert(a.insertAndReturnElement(K(ch)) == k); +/
		assert(a.contains(k));
		assert(a.containsUsingLinearSearch(k));

		assert(a.remove(k));
		assert(!a.contains(k));
		assert(a.insert(K(ch)) == X.InsertionStatus.added);

		assert(a.remove(ch[]));
		assert(!a.contains(k));
		assert(a.insert(K(ch)) == X.InsertionStatus.added);
	}

	X b;
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + (n - 1 - i)];
		const k = K(ch);		// @nogc

		assert(!b.contains(k));
		assert(!b.containsUsingLinearSearch(k));

		assert(b.insert(K(ch)) == X.InsertionStatus.added);
		/+ TODO: assert(b.insertAndReturnElement(K(ch)) == k); +/

		assert(b.contains(k));
		assert(b.containsUsingLinearSearch(k));

		assert(b.remove(k));
		assert(!b.contains(k));

		assert(b.insert(K(ch)) == X.InsertionStatus.added);
	}

	assert(a == b);

	const us = K("_");
	assert(!a.contains(us));
	a ~= us;
	assert(a.contains(us));
}

/// test `opIndexOpAssign`
pure nothrow @safe unittest {
	import nxt.sso_string : SSOString;
	import nxt.digest.fnv : FNV;

	alias K = SSOString;
	alias V = long;
	alias X = HybridHashMap!(K, V, FNV!(64, true));

	X x;

	const a = K("a");
	const b = K("b");

	x[a] = 17;
	assert(x[a] == 17);

	x[a] += 10;				 // opIndexOpAssign!("+=") with existing key
	assert(x[a] == 27);

	x[b] += 10;				 // opIndexOpAssign!("+=") with non-existing key
	assert(x[b] == 10);

	x[b] *= 10;				 // opIndexOpAssign!("*=") with non-existing key
	assert(x[b] == 100);

	assert(x.length == 2);

	assert(x.contains(a));
	assert(x.contains(a[]));
	() @trusted { assert(a in x); }(); /+ TODO: remove wrapper lambda +/
	assert(a[] in x);

	assert(x.contains(b));
	assert(x.contains(b[]));
	() @trusted { assert(b in x); }(); /+ TODO: remove wrapper lambda +/
	assert(b[] in x);

	const c = K("c");
	assert(!x.contains(c));
	assert(!x.contains(c[]));
	assert(c !in x);
	assert(c[] !in x);
}

/// use prime numbers as capacity
version (none)					/+ TODO: enable +/
pure @safe unittest {
	import nxt.address : AlignedAddress;
	alias K = AlignedAddress!1;
	alias V = size_t;
	alias M = HybridHashMap!(K, V, hashOf, defaultKeyEqualPredOf!K, Mallocator,
							 BorrowCheckFlag.no, true, UsePrimeCapacityFlag.yes);
	M x;
	assert(x.empty);
}

/// `SSOString` as map key type
pure nothrow @safe @nogc unittest {
	import nxt.sso_string : SSOString;
	import nxt.digest.fnv : FNV;
	alias K = SSOString;
	alias V = long;
	alias X = HybridHashMap!(K, V, FNV!(64, true));
	const n = 100;

	immutable default_k = K("miss");

	X a;

	// insert all
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + i];
		const k = K(ch);		// @nogc
		assert(k[] == ch[]);

		assert(!a.contains(k));
		assert(!a.contains(ch[]));						  // @nogc
		assert(a.getKeyRef(k, default_k)[] is default_k[]); // on miss use `default_k`
		/+ TODO: assert(a.getKeyRef(ch, default_k)[] is default_k[]); // on miss use `default_k` +/

		a[k] = V.init;

		assert(a.contains(k));
		assert(a.contains(ch[]));					// @nogc
		assert(a.getKeyRef(k, default_k)[] !is k[]); // on hit doesn't use `default_k`
		assert(a.getKeyRef(k, default_k)[] == ch);
		/+ TODO: assert(a.getKeyRef(ch, default_k)[] !is k[]); // on hit doesn't use `default_k` +/
		// assert(a.getKeyRef(ch, default_k)[] == ch);
	}
	assert(a.length == n);

	// remove all
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + i];
		const k = K(ch);		// @nogc
		assert(a.contains(k));
		assert(a.remove(k));
		assert(!a.contains(k));
	}
	assert(a.length == 0);

	// insert all again
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + i];
		const k = K(ch);		// @nogc
		assert(k[] == ch[]);

		assert(!a.contains(k));
		assert(!a.contains(ch[]));						  // @nogc
		assert(a.getKeyRef(k, default_k)[] is default_k[]); // on miss use `default_k`
		/+ TODO: assert(a.getKeyRef(ch, default_k)[] is default_k[]); // on miss use `default_k` +/

		a[k] = V.init;
	}
	assert(a.length == n);

	X b;
	foreach (const i; 0 .. n) {
		const char[1] ch = ['a' + (n - 1 - i)];
		const k = K(ch);		// @nogc

		assert(!b.contains(k));

		b[k] = V.init;

		assert(b.contains(k));
	}

	assert(a == b);
}

///
pure nothrow @safe @nogc unittest {
	import nxt.address : AlignedAddress;
	alias A = AlignedAddress!1;
	HybridHashMap!(A, A) m;
	static assert(m.sizeof == 3*size_t.sizeof); // assure that hole bitmap is not used
	foreach (const address; 1 .. 0x1000) {
		const key = address;
		const value = 2*address;
		assert(A(key) !in m);
		m[A(key)] = A(value);
		const eq = m[A(key)] == A(value);
		assert(eq);
		assert(A(key) in m);
	}
}

///
pure nothrow @safe @nogc unittest {
	import nxt.sso_string : SSOString;
	alias K = SSOString;
	alias V = long;
	alias X = HybridHashMap!(K, V, hashOf, defaultKeyEqualPredOf!(K), Mallocator, Options(GrowOnlyFlag.no, BorrowCheckFlag.no));
	X x;
}

/// non-nullable key type
version (none)					/+ TODO: enable +/
pure nothrow @safe @nogc unittest {
	alias K = long;
	alias V = long;
	alias X = HybridHashMap!(K, V, hashOf, defaultKeyEqualPredOf!(K), Mallocator, Options(GrowOnlyFlag.no, BorrowCheckFlag.no));
	X x;
}

/** Is `true` iff `T` has a specific value dedicated to representing holes
 * (removed/erase) values.
 */
enum isHoleable(T) = (// __traits(hasMember, T, "isHole") &&
					  // __traits(hasMember, T, "holeify") &&
	__traits(hasMember, T, "holeValue"));

/** Default key equality/equivalence predicate for the type `T`.
 */
template defaultKeyEqualPredOf(T) {
	static if (is(T == class))
		// static assert(__traits(hasMember, T, "opEquals"),
		//			   "Type" ~ T.stringof ~ " doesn't have local opEquals() defined");
		// enum defaultKeyEqualPredOf = "a && b && a.opEquals(b)";
		enum defaultKeyEqualPredOf = "a is b";
		// (const T a, const T b) => ((a !is null) && (b !is null) && a.opEquals(b));
	else
		enum defaultKeyEqualPredOf = "a == b";
}

///
pure nothrow @safe unittest {
	class C {
		pure nothrow @safe @nogc:
		this(int x) {
			this.x = x;
		}
		@property bool opEquals(in typeof(this) rhs) const => x == rhs.x;
		@property override bool opEquals(const scope Object rhs) const @trusted {
			C rhs_ = cast(C)rhs;
			return rhs_ && x == rhs_.x;
		}
		int x;
	}
	static assert(defaultKeyEqualPredOf!(C) == "a is b");
}
