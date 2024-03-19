module nxt.sso_open_hashset;

import nxt.container.hybrid_hashmap;

import nxt.nullable_traits : isNullable, isAddress;
import std.experimental.allocator.mallocator : Mallocator;

/** Small-Size-Optimized (SSO) `HybridHashSet`.
 *
 * TODO: search for `nullify`, `isNull`, `nullValue` and support deleted keys (`isDull`)
 *
 * TODO: use opPostMove to update `gc_addRange` and `gc_removeRange` when
 * implemented. See: https://github.com/dlang/DIPs/pull/109
 *
 * See_Also: https://forum.dlang.org/post/pb87rn$2icb$1@digitalmars.com
 */
struct SSOHybridHashSet(K, alias hasher = hashOf, alias Allocator = Mallocator.instance)
if (isNullable!K)
{
	import nxt.qcmeman : gc_addRange, gc_removeRange;

	import core.lifetime : emplace, move, moveEmplace;
	import std.traits : isDynamicArray;
	import core.internal.traits : hasElaborateDestructor;
	import nxt.nullable_traits : defaultNullKeyConstantOf, isNull, nullify;
	import nxt.bit_traits : isAllZeroBits;

	alias InsertionStatus = Large.InsertionStatus;

	@safe:

	static if (!large.hasAddressLikeKey &&
			   (__traits(hasMember, K, `nullValue`) && // if key has a null value
				__traits(compiles, { enum _ = isAllZeroBits!(K, K.nullValue); }) && // prevent strange error given when `K` is `knet.data.Data`
				!isAllZeroBits!(K, K.nullValue)))
	{
		pragma(msg, "TODO: warning key type ", K, " has non-zero-bit init value, default construction should be disabled or Small._store should be set to init value");
	}
	/+ TODO: @disable this(); +/

	static typeof(this) withCapacity()(size_t minimumCapacity) @trusted /*tlm*/
	{
		typeof(return) result;				   /+ TODO: `result = void` for nullify case +/
		if (minimumCapacity > Small.maxCapacity) // will be large
			result.large = Large.withCapacity(minimumCapacity);
		else					// small
		{
			static if (Large.hasAddressLikeKey ||
					   (__traits(hasMember, K, `nullValue`) && // if key has a null value
						__traits(compiles, { enum _ = isAllZeroBits!(K, K.nullValue); }) && // prevent strange error given when `K` is `knet.data.Data`
						isAllZeroBits!(K, K.nullValue))) // check that it's zero bits only
			{
				// nothing needed
			}
			else				// needs explicit null
				static foreach (immutable index; 0 .. small.maxCapacity)
					result.small._store[index].nullify();

			result.small._capacityDummy = 2; // tag as small
		}
		return result;
	}

	~this() nothrow @trusted @nogc
	{
		if (isLarge)
		{
			static if (hasElaborateDestructor!Large)
				.destroy(large);
		}
		else
		{
			static if (hasElaborateDestructor!K)
				static assert(0, "Destroy non-null elements");
		}
	}

	this(this) @disable;

	@property size_t capacity() const pure nothrow @trusted @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		return small._capacityDummy;
	}

	@property size_t length() const pure nothrow @trusted @nogc
	{
		version (LDC) pragma(inline, true);
		if (isLarge)
			return large.length;
		import std.algorithm.searching : count;
		return small._store[].count!(bin => Large.isOccupiedBin(bin));
	}

	InsertionStatus insert(K key) @trusted
	{
		if (isLarge)
			return large.insert(key);
		else
		{
			assert(!key.isNull);

			// try inserting into small
			foreach (immutable index; 0 .. small.maxCapacity) /+ TODO: benchmark with `static foreach` +/
			{
				if (small._store[index].isNull) // free slot
				{
					move(key, small._store[index]);
					return InsertionStatus.added;
				}
			}

			// not hit
			expandWithExtraCapacity(1);
			assert(isLarge);
			return large.insert(key);
		}
	}

	bool remove()(const scope K key) @trusted /*tlm*/
	{
		assert(!key.isNull);
		if (isLarge)
		{
			const hit = large.remove(key);
			if (large.length <= small.maxCapacity)
				shrinkLargeToSmall();
			return hit;
		}
		else
		{
			foreach (immutable index; 0 .. small.maxCapacity) /+ TODO: benchmark with `static foreach` +/
			{
				if (small._store[index] is key)
				{
					small._store[index].nullify(); // don't need holes for small array
					return true;
				}
			}
			return false;
		}
	}

	private void shrinkLargeToSmall()() @trusted /*tlm*/
	{
		Large largeCopy = void;
		moveEmplace(large, largeCopy); /+ TODO: no need to reset `large` +/

		size_t count = 0;
		foreach (ref e; largeCopy.rawStore)
		{
			if (e.isNull) { continue; }
			static if (Large.hasAddressLikeKey)
				if (Large.isHoleKeyConstant(e))
					continue;
			moveEmplace(e, small._store[count]);
			count += 1;
		}

		foreach (immutable index; count .. small.maxCapacity)
		{
			static if (hasElaborateDestructor!K)
				emplace(&small._store[index]); // reset
			small._store[index].nullify();
		}
	}

	/** Check if `element` is stored.
		Returns: `true` if element is present, `false` otherwise.
	*/
	bool contains(const scope K key) const @trusted /*tlm*/ // `auto ref` here makes things slow
	in(!key.isNull)
	{
		if (isLarge)
			return large.contains(key);
		static if (Large.hasAddressLikeKey)
			assert(!Large.isHoleKeyConstant(key));
		/+ TODO: is static foreach faster here? +/
		import std.algorithm.searching : canFind;
		alias pred = (a, b) => a is b;			/+ TODO: add to template +/
		return small._store[].canFind!(pred)(key);
	}

	private void expandWithExtraCapacity(size_t extraCapacity) @trusted
	{
		Small.Bins binsCopy = small._store; /+ TODO: moveEmplace +/
		/+ TODO: merge these lines? +/
		emplace!Large(&large);
		large.reserveExtra(Small.maxCapacity + extraCapacity);
		large.insertN(binsCopy);
	}

	/// Get bin count.
	@property size_t binCount() const @trusted
	{
		pragma(inline, true)
		if (isLarge)
			return large.binCount;
		return small.maxCapacity;
	}

	@property private scope inout(K)[] bins() inout @trusted return
	{
		version (D_Coverage) {} else pragma(inline, true);
		if (isLarge)
			return large.rawStore;
		return small._store[];
	}

private:
	bool isLarge() const pure nothrow @trusted @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		return small._capacityDummy > Small.maxCapacity;
	}

	/// Returns: `true` if `this` currently uses small (packed) array storage.
	bool isSmall() const pure nothrow @trusted @nogc { return !isLarge; }

	union
	{
		alias Large = HybridHashSet!(K, hasher);
		Large large;
		static struct Small
		{
			/* discriminator between large and small storage; must be placed at
			 * exactly here (maps to position of `large._store.length`) and
			 * always contain `maxCapacity` when this is small */
			size_t _capacityDummy;
			enum maxCapacity = (large.sizeof - _capacityDummy.sizeof)/K.sizeof;
			static assert(maxCapacity, "Cannot fit a single element in a Small");
			alias Bins = K[maxCapacity];
			Bins _store;
		}
		Small small;
	};
}

/** L-value element reference (and in turn range iterator).
 */
static private struct LvalueElementRef(Table)
{
	import std.traits : isMutable;
	debug static assert(isMutable!Table, "Table type should always be mutable");

	private Table* _table;	  // scoped access
	private size_t _binIndex;   // index to bin inside `table`
	private size_t _hitCounter; // counter over number of elements popped (needed for length)

	this(Table* table) @trusted
	{
		version (D_Coverage) {} else pragma(inline, true);
		this._table = table;
		// static if (Table.isBorrowChecked)
		// {
		//	 debug
		//	 {
		//		 _table.incBorrowCount();
		//	 }
		// }
	}

	~this() nothrow @trusted @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		// static if (Table.isBorrowChecked)
		// {
		//	 debug
		//	 {
		//		 _table.decBorrowCount();
		//	 }
		// }
	}

	this(this) @trusted
	{
		version (D_Coverage) {} else pragma(inline, true);
		// static if (Table.isBorrowChecked)
		// {
		//	 debug
		//	 {
		//		 assert(_table._borrowCount != 0);
		//		 _table.incBorrowCount();
		//	 }
		// }
	}

	/// Check if empty.
	bool empty() const @property pure nothrow @safe @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		return _binIndex == _table.binCount;
	}

	/// Get number of element left to pop.
	@property size_t length() const pure nothrow @safe @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		return _table.length - _hitCounter;
	}

	@property typeof(this) save() // ForwardRange
	{
		version (D_Coverage) {} else pragma(inline, true);
		return this;
	}

	void popFront()
	{
		version (LDC) pragma(inline, true);
		assert(!empty);
		_binIndex += 1;
		findNextNonEmptyBin();
		_hitCounter += 1;
	}

	private void findNextNonEmptyBin()
	{
		version (D_Coverage) {} else pragma(inline, true);
		while (_binIndex != (*_table).binCount &&
			   !Table.Large.isOccupiedBin(_table.bins[_binIndex]))
			_binIndex += 1;
	}
}

/// Range over elements of l-value instance of this.
static private struct ByLvalueElement(Table)
{
pragma(inline, true):
	import std.traits : isMutable;
	static if (isAddress!(Table.Large.ElementType)) // for reference types
	{
		/// Get reference to front element.
		@property scope Table.Large.ElementType front()() return @trusted
		{
			// cast to head-const for class key
			return (cast(typeof(return))_table.bins[_binIndex]);
		}
	}
	else
	{
		/// Get reference to front element.
		@property scope auto ref front() return @trusted
		{
			return *(cast(const(Table.ElementType)*)&_table._store[_binIndex]); // propagate constnes
		}
	}
	import core.internal.traits : Unqual;
	// unqual to reduce number of instantations of `LvalueElementRef`
	public LvalueElementRef!(Unqual!Table) _elementRef;
	alias _elementRef this;
}

/** Returns: range that iterates through the elements of `c` in undefined order.
 */
auto byElement(Table)(auto ref return Table c) @trusted
	if (is(Table == SSOHybridHashSet!(_), _...))
{
	import core.internal.traits : Unqual;
	alias M = Unqual!Table;
	alias C = const(Table);		// be const for now
	static if (__traits(isRef, c)) // `c` is an l-value and must be borrowed
		auto result = ByLvalueElement!C((LvalueElementRef!(M)(cast(M*)&c)));
	else						// `c` was is an r-value and can be moved
		static assert(0, "R-value parameter not supported");
	result.findNextNonEmptyBin();
	return result;
}
alias range = byElement;		// EMSI-container naming

/// start small and expand to large
pure nothrow @safe unittest {
	import std.algorithm.comparison : equal;
	import nxt.digest.fnv : FNV;
	import nxt.array_help : s;

	// construct small
	alias X = SSOHybridHashSet!(K, FNV!(64, true));
	static assert(X.sizeof == 24);
	auto x = X.withCapacity(X.small.maxCapacity);
	assert(x.isSmall);
	assert(x.capacity == X.small.maxCapacity);
	assert(x.length == 0);

	auto k42 = new K(42);
	auto k43 = new K(43);
	auto k44 = new K(44);

	// insert first into small

	assert(!x.contains(k42));

	assert(x.insert(k42) == x.InsertionStatus.added);
	assert(x.contains(k42));

	assert(x.remove(k42));
	assert(!x.contains(k42));

	assert(x.insert(k42) == x.InsertionStatus.added);
	assert(x.contains(k42));

	assert(x.byElement.equal!((a, b) => a is b)([k42].s[]));
	assert(x.isSmall);
	assert(x.length == 1);

	// insert second into small

	assert(!x.contains(k43));

	assert(x.insert(k43) == x.InsertionStatus.added);
	assert(x.contains(k42));
	assert(x.contains(k43));

	assert(x.remove(k43));
	assert(x.remove(k42));
	assert(!x.contains(k43));
	assert(!x.contains(k42));

	assert(x.insert(k43) == x.InsertionStatus.added);
	assert(x.insert(k42) == x.InsertionStatus.added);

	assert(x.byElement.equal!((a, b) => a is b)([k43, k42].s[]));
	assert(x.isSmall);
	assert(x.length == 2);

	// expanding insert third into large

	assert(!x.contains(k44));
	assert(x.insert(k44) == x.InsertionStatus.added);
	// unordered store so equal doesn't work anymore
	assert(x.contains(k42));
	assert(x.contains(k43));
	assert(x.contains(k44));
	foreach (ref e; x.byElement)
	{
		static assert(is(typeof(e) == K));
		assert(x.contains(e));
	}
	assert(x.isLarge);
	assert(x.length == 3);

	// shrinking remove third into small
	assert(x.remove(k44));
	assert(!x.contains(k44));
	assert(x.isSmall);
	assert(x.length == 2);
	assert(x.byElement.equal!((a, b) => a is b)([k43, k42].s[]));
	// auto xr = x.byElement;
	// assert(xr.front.value == 43);
	// assert(xr.front is k43);
	// xr.popFront();
	// assert(xr.front.value == 42);
	// assert(xr.front is k42);
	// xr.popFront();
	// assert(xr.empty);

	const cx = X.withCapacity(X.small.maxCapacity);
	foreach (ref e; cx.byElement)
		static assert(is(typeof(e) == K)); // head-const because of `is`-equality
}

/// start large
pure nothrow @safe unittest {
	import nxt.digest.fnv : FNV;
	alias X = SSOHybridHashSet!(K, FNV!(64, true));
	import nxt.container.traits : mustAddGCRange;
	static assert(mustAddGCRange!K);
	static assert(mustAddGCRange!X);
	auto x = X.withCapacity(3);
	assert(x.isLarge);
	assert(x.capacity == 4);	// nextPow2(3)
	assert(x.length == 0);
	assert(x.insert(new K(42)) == x.InsertionStatus.added);
	assert(x.length == 1);
	assert(x.insert(new K(43)) == x.InsertionStatus.added);
	assert(x.length == 2);
}

version (unittest)
{
	class K
	{
		this(uint value) pure nothrow @safe @nogc
		{
			this.value = value;
		}
		uint value;
	}
}
