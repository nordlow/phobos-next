/** Tries and Prefix Trees.

	Implementation is layered:
	$(UL
	$(LI `RawRadixTree` stores its untyped keys as variable length ubyte-strings (`UKey`))
	$(LI On top of that `RadixTree` implements typed-key access via its template parameter `Key`.)
	)
	Both layers currently support
	$(UL
	$(LI template parameterization on the `Value`-type in the map case (when `Value` is non-`void`))
	$(LI `@nogc` and, when possible, `@safe pure nothrow`)
	$(LI insertion with returned modifications status: `auto newKeyWasInserted = set.insert(Key key)`)
	$(LI AA-style `in`-operator)
	  $(UL
	  $(LI `key in set` is `bool` for set-case)
	  $(LI `key in map` returns non-`null` `value` pointer when `key` is stored in `map`)
	  )
	$(LI AA-style iteration of map keys: `map.byKey()`)
	$(LI AA-style iteration of map values: `map.byValue()`)
	$(LI `SortedRange`-style iteration over elements sorted by key: `assert(set[].isSorted)`)
	$(LI containment checking: `bool contains(in Key key)`)
	$(LI element indexing and element index assignment for map case via `opIndex` and `opIndexAssign`)
	$(LI key-prefix Completion (returning a `Range` over all set/map-elements that match a key prefix): `prefix(Key keyPrefix)`)
	)
	Typed layer supports
	$(UL
	$(LI ordered access of aggregate types)
	)

	Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -preview=in -debug -g -unittest -checkaction=context -allinst -main -unittest -I../.. -i -run trie.d

	See_Also: $(HTTP en.wikipedia.org/wiki/Trie)
	See_Also: $(HTTP en.wikipedia.org/wiki/Radix_tree)
	See_Also: $(HTTP github.com/nordlow/phobos-next/blob/master/src/test_trie_prefix.d) for a descriptive usage of prefixed access.

	TODO: Get rid of explicit @nogc qualifiers for all templates starting with those taking A alloc as parameter

	TODO: Try to get rid of alias this

	TODO: use fast bit-scanning functions in core.bitop for DenseBranch and
	DenseLeaf iterators

	TODO: shift addresses of class and pointers by its alignment before adding
	them to make top-branch as dense possible

	TODO: Allow slicing from non-mutable tries and add test-case at line 5300

	TODO: 2. Make as many members as possible free functionss free-functions to
	reduce compilation times. Alternative make them templates (`tlm` )

	TODO: Use scope on `Range`, `RawRange` and members that return key and value
	reference when DIP-1000 has been implemented

	TODO: Encode `string` with zero-terminating 0 byte when it's not the last
	member in a key aggregate

	TODO: split up file into raw_trie.d, trie.d

	TODO

	Replace
	case undefined: return typeof(return).init; // terminate recursion
	with
	case undefined: return curr;

	TODO:
	TODO: Make `Key` and Ix[]-array of `immutable Ix` like `string`

	TODO: Allow `Node`-constructors to take const and immutable prefixes and then
	make `toRawKey` and `toTypedKey` accept return const-slices

	TODO: Remove @trusted from VLA (variable length array)-members of SparseBranch/SparseLeaf and make their callers @trusted instead.

	TODO: Assure that ~this() nothrow is run for argument `nt` in `freeNode`. Can we use `postblit()` for this?

	TODO: Search for "functionize this loop or reuse memmove" and use move()

	TODO: Add Branch-hint allocation flag and re-benchmark construction of `RadixTreeSet` with 10000000 uints

	TODO: Add sortedness to `IxsN` and make `IxsN.contains()` use `binarySearch()`. Make use of `sortn`.

	TODO: Check for case when expanding to bit-branch instead of `SparseBranch` in all `expand()` overloads

	TODO: Make array indexing/slicing as @trusted and use .ptr[] instead of [] when things are stable.

	TODO: Add various extra packings in MixLeaf1to4: number of
	- Ix  (0,1,2,3,4,5,6): 3-bits
	- Ix2 (0,1,2,3): 2-bits
	- Ix3 (0,1,2): 2-bits
	- Ix4 (0,1): 1-bit
	Total bits 8-bits
	Possible packings with 6 bytes
	- 4_
	- 4_2
	- 4_2
	- 4_2_1
	- 4_1
	- 4_1_1
	- 3_2
	- 3_2_1
	- 3_1
	- 3_1_1
	- 3_1_1_1
	- 2_2_2
	- 2_2
	- 2_2_1
	- 2_2_1_1
	- 2
	- 2_1
	- 2_1_1
	- 2_1_1_1
	- 2_1_1_1_1
	- 1
	- 1_1
	- 1_1_1
	- 1_1_1_1
	- 1_1_1_1_1
	- 1_1_1_1_1_1

	TODO: Sorted Range Primitives over Keys

	- Returns a range of elements which are equivalent (though not necessarily equal) to value.
	  auto equalRange(this This)(inout T value)

	- Returns a range of elements which are greater than low and smaller than highValue.
	  auto bound(this This)(inout T lowValue, inout T highValue)

	- Returns a range of elements which are less than value.
	  auto lowerBound(this This)(inout T value)

	- Returns a range of elements which are greater than value.
	  auto upperBound(this This)(inout T value)

	TODO: opBinaryRight shall return `_rawTree.ElementRef` instead of `bool`

	TODO: Fix vla-allocations in makeVariableSizeNodePointer according
	C11-recommendations. For reference set commit
	d2f1971dd570439da4198fa76603b53b072060f8 at
	https://github.com/emacs-mirror/emacs.git
*/
module nxt.container.trie;

import std.traits : isPointer, Unqual;
import std.range.primitives : isInputRange, ElementType;

import nxt.bijections : isIntegralBijectableType, bijectToUnsigned, bijectFromUnsigned;
import nxt.variant_ex : WordVariant;
import nxt.container.traits : mustAddGCRange;
import std.experimental.allocator.common : isAllocator;
import nxt.container.dynamic_array : Array = DynamicArray;
import nxt.construction : dupShallow;

// version = enterSingleInfiniteMemoryLeakTest;
// version = nxt_benchmark;
// version = show;
// version = useMemoryErrorHandler;
// version = showBranchSizes;
// version = showAssertTags;

alias isFixedTrieableKeyType = isIntegralBijectableType;

/** Returns: `true` if `T` is a scalar trie key-type, `false` otherwise. */
enum isScalarTrieableKeyType(T) = (isFixedTrieableKeyType!T ||
								   (isInputRange!T &&
									isFixedTrieableKeyType!(ElementType!T)));

/** Returns: `true` if `T` is a type that can be stored as a key in a trie, ` false` otherwise. */
template isTrieableKeyType(T)
{
	static if (is(T == struct))
	{
		import std.meta : allSatisfy;
		enum isTrieableKeyType = allSatisfy!(isScalarTrieableKeyType, // recurse
											 typeof(T.tupleof));
	}
	else static if (is(T == class))
		static assert("Class types cannot be stored in a radix tree because classes in D has reference semantics");
	else
		enum isTrieableKeyType = isScalarTrieableKeyType!T;
}

version (useMemoryErrorHandler) unittest {
	import etc.linux.memoryerror : registerMemoryErrorHandler;
	registerMemoryErrorHandler();
	dbg("registerMemoryErrorHandler done");
}

pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	static assert(isTrieableKeyType!(const(char)[]));

	struct S { int x, y, z; double w; bool b; }
	static assert(isTrieableKeyType!(S));
}

/** Binary power of radix, typically either 1, 2, 4 or 8. */
private enum span = 8;
/** Branch-multiplicity. Also called order. */
private enum radix = 2^^span;

static assert(span == 8, "Radix is currently limited to 8");
static assert(size_t.sizeof == 8, "Currently requires a 64-bit CPU (size_t.sizeof == 8)");

version (unittest)
{
	version = useModulo;
}
version = useModulo;			/+ TODO: remove and activate only in version (unittest) +/

/** Radix Modulo Index
	Restricted index type avoids range checking in array indexing below.
*/
version (useModulo)
{
	import nxt.modulo : Mod, mod;   /+ TODO: remove these if radix is `256` +/
	alias Ix = Mod!(radix, ubyte);
	alias UIx = Mod!(radix, size_t); // `size_t` is faster than `uint` on Intel Haswell

	/** Mutable RawTree Key. */
	alias Key(size_t span) = Mod!(2^^span)[]; /+ TODO: use static_bitarray to more naturally support span != 8. +/
	/** Immutable RawTree Key. */
	alias IKey(size_t span) = immutable(Mod!(2^^span))[]; /+ TODO: use static_bitarray to more naturally support span != 8. +/
	/** Fixed-Length RawTree Key. */
	alias KeyN(size_t span, size_t N) = Mod!(2^^span)[N];

	enum useModuloFlag = true;
}
else
{
	alias Ix = ubyte;
	alias UIx = size_t;

	/** Mutable RawTree Key. */
	alias Key(size_t span) = ubyte[]; /+ TODO: use static_bitarray to more naturally support span != 8. +/
	/** Immutable RawTree Key. */
	alias IKey(size_t span) = immutable(ubyte)[]; /+ TODO: use static_bitarray to more naturally support span != 8. +/
	/** Fixed-Length RawTree Key. */
	alias KeyN(size_t span, size_t N) = ubyte[N];

	enum useModuloFlag = false;
}

import nxt.container.static_modarray : StaticModArray;

import std.experimental.allocator.mallocator : Mallocator;
alias Ixs = Array!(Ix, Mallocator); // @safe to use `Mallocator` when elements aren't accessed by reference.

alias IxsN(uint capacity,
		   uint elementLength) = StaticModArray!(capacity,
												 elementLength,
												 8,
												 useModuloFlag);

/* TODO: what follow requires memory: */

alias UKey = Key!span;
bool empty(UKey ukey) @safe pure nothrow
	=> ukey.length == 0;

private template IxElt(Value)
{
	static if (is(Value == void)) // set case
		alias IxElt = UIx;
	else						// map case
		struct IxElt { UIx ix; Value value; }
}

private static auto eltIx(Value)(inout IxElt!Value elt)
{
	static if (is(Value == void)) // set case
		return elt;
	else						// map case
		return elt.ix;
}

private template Elt(Value)
{
	static if (is(Value == void)) // set case
		alias Elt = UKey;
	else						// map case
		struct Elt { UKey key; Value value; }
}

private auto eltKey(Value)(inout Elt!Value elt)
{
	static if (is(Value == void)) // set case
		return elt;
	else						// map case
		return elt.key;
}

private auto eltKeyDropExactly(Value)(Elt!Value elt, size_t n)
{
	static if (is(Value == void)) // set case
		return elt[n .. $];
	else						// map case
		return Elt!Value(elt.key[n .. $], elt.value);
}

/** Results of attempt at modification sub. */
enum ModStatus:ubyte
{
	maxCapacityReached,		 // no operation, max capacity reached
	unchanged,				  // no operation, element already stored
	added, inserted = added,	// new element was added (inserted)
	updated, modified = updated, // existing element was update/modified
}

/** Size of a CPU cache line in bytes.
 *
 * Container layouts should be adapted to make use of at least this many bytes
 * in its nodes.
*/
private enum cacheLineSize = 64;

shared static this()
{
	import core.cpuid : dataCaches;
	assert(cacheLineSize == dataCaches()[0].lineSize, "Cache line is not 64 bytes");
}

enum keySeparator = ',';

/** Single/1-Key Leaf with maximum key-length 7. */
struct OneLeafMax7
{
	@safe pure:
	enum capacity = 7;

	this(Ix[] key) nothrow @nogc
	{
		assert(key.length != 0);
		this.key = key;
	}

	bool contains(UKey key) const nothrow @nogc
	{
		pragma(inline, true);
		return this.key == key;
	}

	@property string toString()() const /* tlm to avoid  */
	{
		import std.string : format;
		string s;
		foreach (immutable i, immutable ix; key)
		{
			immutable first = i == 0; // first iteration
			if (!first) { s ~= '_'; }
			/+ TODO: avoid calling format here and make toString non-tlm +/
			s ~= format("%.2X", ix); // in hexadecimal
		}
		return s;
	}

	IxsN!(capacity, 1) key;
}

/** Binary/2-Key Leaf with key-length 3. */
struct TwoLeaf3
{
	enum keyLength = 3; // fixed length key
	enum capacity = 2; // maximum number of keys stored

	pure nothrow @safe @nogc:

	this(Keys...)(Keys keys)
	if (Keys.length != 0 &&
		Keys.length <= capacity)
	{
		this.keys = keys;
	}

	inout(Ix)[] prefix() inout in(!keys.empty)
	{
		final switch (keys.length)
		{
		case 1:
			return keys.at!0[];
		case 2:
			import std.algorithm.searching : commonPrefix;
			return commonPrefix(keys.at!0[], keys.at!1[]);
		}
	}

	bool contains(UKey key) const in(!keys.empty)
	{
		version (LDC) pragma(inline, true);
		final switch (keys.length)
		{
		case 1: return keys[0] == key;
		case 2: return keys[0] == key || keys[1] == key;
		}
		// return keys.contains(key);
	}

	IxsN!(capacity, keyLength) keys; // should never be empty
}

/** Ternary/3-Key Leaf with key-length 2. */
struct TriLeaf2
{
	enum keyLength = 2; // fixed length key
	enum capacity = 3; // maximum number of keys stored

	pure nothrow @safe @nogc:

	this(Keys...)(Keys keys)
	if (Keys.length != 0 &&
		Keys.length <= capacity)
	{
		this.keys = keys;
	}

	inout(Ix)[] prefix() inout in(!keys.empty)
	{
		import std.algorithm.searching : commonPrefix;
		final switch (keys.length)
		{
		case 1:
			return keys.at!0[];
		case 2:
			return commonPrefix(keys.at!0[], keys.at!1[]);
		case 3:
			return commonPrefix(keys.at!0[],
								commonPrefix(keys.at!1[],
											 keys.at!2[])); /+ TODO: make and reuse variadic commonPrefix +/
		}
	}

	bool contains(UKey key) const in(!keys.empty)
	{
		version (LDC) pragma(inline, true);
		final switch (keys.length)
		{
		case 1: return keys[0] == key;
		case 2: return keys[0] == key || keys[1] == key;
		case 3: return keys[0] == key || keys[1] == key || keys[2] == key;
		}
		// return keys.contains(key);
	}

	IxsN!(capacity, keyLength) keys; // should never be empty
}

/** Hepa/7-Key Leaf with key-length 1. */
struct HeptLeaf1
{
	enum keyLength = 1;
	enum capacity = 7; // maximum number of elements

	pure nothrow @safe @nogc:

	this(Keys...)(Keys keys)
	if (Keys.length != 0 &&
		Keys.length <= capacity)
	{
		pragma(inline, true);
		// static foreach (const ix, const key; keys)
		// {
		//	 this.keys[ix] = cast(Ix)key;
		// }
		this.keys = keys;
	}

	bool contains(UIx key) const in(!keys.empty)
	{
		pragma(inline, true);
		// NOTE this is not noticably faster
		// final switch (keys.length)
		// {
		// case 1: return keys[0] == key;
		// case 2: return keys[0] == key || keys[1] == key;
		// case 3: return keys[0] == key || keys[1] == key || keys[2] == key;
		// case 4: return keys[0] == key || keys[1] == key || keys[2] == key || keys[3] == key;
		// case 5: return keys[0] == key || keys[1] == key || keys[2] == key || keys[3] == key || keys[4] == key;
		// case 6: return keys[0] == key || keys[1] == key || keys[2] == key || keys[3] == key || keys[4] == key || keys[5] == key;
		// case 7: return keys[0] == key || keys[1] == key || keys[2] == key || keys[3] == key || keys[4] == key || keys[5] == key || keys[6] == key;
		// }
		return keys.contains(key);
	}
	bool contains(UKey key) const
	{
		pragma(inline, true);
		return (key.length == 1 &&
				keys.contains(UIx(key[0])));
	}

	IxsN!(capacity, 1) keys;	// should never be empty
}

/** Check if type `NodeType` is a variable-length aggregate (`struct`) type. */
private enum hasVariableSize(NodeType) = __traits(hasMember, NodeType, "allocationSizeOfCapacity");

/** Construct a `Node`-type of value type `NodeType` using constructor arguments
 * `args` of `Args`.
 */
auto makeFixedSizeNodeValue(NodeType, Args...)(Args args) pure nothrow
if (!hasVariableSize!NodeType &&
	!isPointer!NodeType)
{
	return NodeType(args);
}

/** Allocate and Construct a `Node`-type of value type `NodeType` using
 * constructor arguments `args` of `Args`.
 */
auto makeFixedSizeNodePointer(NodeType, A, Args...)(auto ref A alloc, Args args) @trusted pure nothrow
if (isAllocator!A &&
	!hasVariableSize!NodeType &&
	!isPointer!NodeType)
{
	import std.experimental.allocator : make;
	// debug ++_heapAllocBalance;
	return make!(NodeType)(alloc, args);
	/+ TODO: ensure alignment of node at least that of NodeType.alignof +/
}

/** Allocate (via `alloc.allocate`) and `emplace` an instance of a
 * variable-length aggregate (`struct`) type `NodeType`.
 */
private NodeType* makeVariableSizeNodePointer(NodeType, A, Args...)(auto ref A alloc, size_t requestedCapacity, Args args) @trusted
if (isAllocator!A &&
	is(NodeType == struct) &&
	hasVariableSize!NodeType)
{
	import std.math.algebraic : nextPow2;
	import std.algorithm.comparison : clamp;
	const paddedCapacity = (requestedCapacity == 1 ? 1 :
							nextPow2(requestedCapacity - 1).clamp(NodeType.minCapacity, // TODO what happens when requestedCapacity doesn’t fit in NodeType.maxCapacity?
																  NodeType.maxCapacity));
	// import nxt.debugio;
	// dbg(NodeType.stringof, " paddedCapacity:", paddedCapacity, " requestedCapacity:", requestedCapacity);
	// assert(paddedCapacity >= requestedCapacity); /+ TODO: this fails for dmd but not for ldc +/
	import core.lifetime : emplace;
	// TODO extend `std.experimental.allocator.make` to `makeWithCapacity`
	return emplace(cast(typeof(return))alloc.allocate(NodeType.allocationSizeOfCapacity(paddedCapacity)),
				   paddedCapacity, args);
}

void freeNode(NodeType, A)(auto ref A alloc, NodeType nt) @trusted pure nothrow
if (isAllocator!A)
{
	static if (isPointer!NodeType)
	{
		import std.experimental.allocator : dispose;
		dispose(alloc, nt);
		// debug --_heapAllocBalance;
	}
}

/** Sparsely coded leaves with values of type `Value`. */
static private struct SparseLeaf1(Value)
{
	import nxt.searching_ex : containsStoreIndex;
	import std.range : assumeSorted;
	import std.algorithm.sorting : isSorted;

	enum hasValue = !is(Value == void);

	enum minCapacity = 0;	 // preferred minimum number of preallocated values

	// preferred maximum number of preallocated values, if larger use a DenseLeaf1 instead
	static if (hasValue)
		enum maxCapacity = 128;
	else
		enum maxCapacity = 48;

	version (useModulo)
		alias Capacity = Mod!(maxCapacity + 1);
	else
		alias Capacity = ubyte;

	alias Length = Capacity;

	pure nothrow:

	this(size_t capacity) @nogc
	{
		_capacity = cast(Capacity)capacity;
		_length = 0;
	}

	/** Returns a an allocated duplicate of this.
	 *
	 * Shallowly duplicates the values in the map case.
	 */
	typeof(this)* dupAt(A)(auto ref A alloc)
	{
		static if (hasValue)
			return makeVariableSizeNodePointer!(typeof(this))(alloc, this._capacity, ixs, values);
		else
			return makeVariableSizeNodePointer!(typeof(this))(alloc, this._capacity, ixs);
	}

	static if (hasValue)
	{
		static if (mustAddGCRange!Value)
			import core.memory : GC;

		/** Construct with capacity `capacity`. */
		this(in size_t capacity, Ix[] ixs, Value[] values)
		in(ixs.length == values.length)
		in(capacity >= ixs.length)
		in(values.length <= maxCapacity)
		in(ixs.isSorted)
		{
			_capacity = capacity;
			_length = ixs.length;
			foreach (immutable i, immutable ix; ixs)
				ixsSlots[i] = ix;
			foreach (immutable i, immutable value; values)
				valuesSlots[i] = value;
			static if (mustAddGCRange!Value)
				GC.addRange(valuesSlots.ptr, _capacity * Value.sizeof);
		}
	}
	else
	{
		this(in size_t capacity, Ix[] ixs) @nogc
		in(capacity >= ixs.length)
		in(ixs.length <= maxCapacity)
		in(ixs.isSorted)
		{
			_capacity = cast(Capacity)capacity;
			_length = cast(Length)ixs.length;
			foreach (immutable i, immutable ix; ixs)
				ixsSlots[i] = ix;
		}
	}

	~this() nothrow @nogc
	{
		deinit();
	}

	private void deinit() @trusted nothrow @nogc
	{
		static if (hasValue && mustAddGCRange!Value)
			GC.removeRange(valuesSlots.ptr, _capacity * Value.sizeof);
	}

	typeof(this)* makeRoom(A)(auto ref A alloc)
	{
		auto next = &this;
		if (full)
		{
			if (length < maxCapacity) // if we can expand more
			{
				// make room
				static if (hasValue)
					next = makeVariableSizeNodePointer!(typeof(this))(alloc, length + 1, ixsSlots, valuesSlots);
				else
					next = makeVariableSizeNodePointer!(typeof(this))(alloc, length + 1, ixsSlots);
				freeNode(alloc, &this);
			}
			else
				return null;	// indicate that max capacity has been reached
		}
		return next;
	}

	/** Insert `key`, possibly self-reallocating `this` (into return). */
	typeof(this)* reconstructingInsert(A)(auto ref A alloc, IxElt!Value elt, out ModStatus modStatus, out size_t index) @trusted
	{
		// get index
		static if (hasValue)
			immutable ix = elt.ix;
		else
			immutable ix = elt;

		// handle existing element
		if (ixs.assumeSorted.containsStoreIndex(ix, index))
		{
			static if (hasValue)
			{
				modStatus = valuesSlots[index] != elt.value ? ModStatus.updated : ModStatus.unchanged;
				valuesSlots[index] = elt.value;
			}
			else
				modStatus = ModStatus.unchanged;
			return &this;
		}

		// try making room for new element
		typeof(return) next = makeRoom(alloc);
		if (next is null)
		{
			modStatus = ModStatus.maxCapacityReached; /+ TODO: expand to `DenseLeaf1` +/
			return &this;
		}

		// insert new element
		next.insertAt(index, elt);
		modStatus = ModStatus.added;

		return next;
	}

	private void insertAt(size_t index, IxElt!Value elt) in(index <= _length)
	{
		foreach (immutable i; 0 .. _length - index) /+ TODO: functionize this loop or reuse memmove: +/
		{
			immutable iD = _length - i;
			immutable iS = iD - 1;
			ixsSlots[iD] = ixsSlots[iS];
		}
		static if (hasValue)
		{
			ixsSlots[index] = elt.ix;
			valuesSlots[index] = elt.value;
		}
		else
		{
			ixsSlots[index] = cast(Ix)elt;
		}
		++_length;
	}

	pragma(inline, true) Length length() const @safe @nogc => _length;
	pragma(inline, true) Capacity capacity() const @safe @nogc => _capacity;

	pragma(inline, true) bool empty() const @property @safe @nogc => _length == 0;
	pragma(inline, true) bool full() const @safe @nogc => _length == _capacity;

	/** Get all initialized keys. */
	pragma(inline, true) auto ixs() inout @trusted @nogc => ixsSlots[0 .. _length];

	static if (hasValue)
	{
		/** Get all intialized values. */
		inout(Value)[] values() inout @trusted @nogc
		{
			pragma(inline, true)
			return valuesSlots[0 .. _length];
		}

		void setValue(UIx ix, Value value) @trusted
		{
			size_t index;
			immutable hit = ixs.assumeSorted.containsStoreIndex(ix, index);
			assert(hit);		// assert hit for now
			assert(index < length);
			values[index] = value;
		}

		inout(Value*) contains(UIx key) inout @nogc
		{
			pragma(inline, true);
			size_t index;
			if (ixs.assumeSorted.containsStoreIndex(key, index))
				return &(values[index]);
			else
				return null;
		}
	}
	else
	{
		pragma(inline, true)
		bool contains(UIx key) const @nogc => ixs.assumeSorted.contains(key);
	}

	/** Get all reserved keys. */
	private auto ixsSlots() inout @trusted @nogc
	{
		pragma(inline, true);
		static if (hasValue)
			return (cast(Ix*)(_values.ptr + _capacity))[0 .. _capacity];
		else
			return _ixs.ptr[0 .. _capacity];
	}
	static if (hasValue)
	{
		/** Get all reserved values. */
		pragma(inline, true)
		private inout(Value)[] valuesSlots() inout @trusted @nogc => _values.ptr[0 .. _capacity];
	}

	/** Get allocation size (in bytes) needed to hold `length` number of
	 * elements (keys and optionally values).
	 */
	static size_t allocationSizeOfCapacity(in size_t capacity) pure nothrow @safe @nogc
	{
		static if (hasValue)
			return (this.sizeof + // base plus
					Value.sizeof*capacity + // actual size of `_values`
					Ix.sizeof*capacity);   // actual size of `_ixs`
		else
			return (this.sizeof + // base plus
					Ix.sizeof*capacity);   // actual size of `_ixs`
	}

	/** Get allocated size (in bytes) of `this` including the variable-length part.
	 */
	size_t allocatedSize() const pure nothrow @safe @nogc
		=> allocationSizeOfCapacity(_capacity);

private:
	Length _length;
	const Capacity _capacity;
	static if (hasValue)
		Value[0] _values;
	Ix[0] _ixs;
}

/** Densely coded leaves with values of type `Value`. */
static private struct DenseLeaf1(Value)
{
	import nxt.container.static_bitarray : StaticBitArray;

	enum hasValue = !is(Value == void);

	static if (hasValue)
		enum hasGCScannedValues = !is(Value == bool) && mustAddGCRange!Value;
	else
		enum hasGCScannedValues = false;

	static if (hasGCScannedValues)
		import core.memory : GC;

	enum capacity = radix;

	@safe pure nothrow:

	static if (hasValue)
	{
		this(Ix[] ixs, Value[] values) @nogc
		{
			assert(ixs.length <= capacity);
			assert(ixs.length == values.length);
			foreach (immutable i, immutable ix; ixs)
			{
				_ixBits[ix] = true;
				_values[ix] = values[i];
			}
			static if (hasGCScannedValues)
				GC.addRange(_values.ptr, capacity * Value.size);
		}

		this(ref StaticBitArray!capacity ixBits, Value[] values) @nogc
		{
			assert(ixBits.length == values.length);
			_ixBits = ixBits;
			_values[] = values[]; /+ TODO: commenting out does not affect unittests +/
			static if (hasGCScannedValues)
				GC.addRange(_values.ptr, capacity * Value.size);
		}
	}
	else
	{
		this(Ix[] ixs) @nogc
		{
			assert(ixs.length <= capacity);
			foreach (immutable ix; ixs)
				_ixBits[ix] = true;
		}

		this(const ref StaticBitArray!capacity ixBits) @nogc
		{
			_ixBits = ixBits;
		}
	}


	/** Returns a an allocated duplicate of this.
		Shallowly duplicates the values in the map case.
	*/
	typeof(this)* dupAt(A)(auto ref A alloc)
	{
		static if (hasValue)
			return makeFixedSizeNodePointer!(typeof(this))(alloc, _ixBits, _values);
		else
			return makeFixedSizeNodePointer!(typeof(this))(alloc, _ixBits);
	}

	~this() nothrow @nogc
	{
		static if (hasGCScannedValues)
			GC.removeRange(_values.ptr, capacity * Value.size);
	}

	pragma(inline, true) bool empty() const @property @nogc => _ixBits.allZero;
	pragma(inline, true) bool full() const @nogc => _ixBits.allOne;
	pragma(inline, true) size_t count() const @nogc => _ixBits.countOnes;

	static if (hasValue)
		inout(Value*) contains(UIx ix) inout @nogc
		{
			pragma(inline, true);
			return _ixBits[ix] ? &(_values[ix]) : null;
		}
	else
		bool contains(UIx ix) const @nogc
		{
			pragma(inline, true);
			return _ixBits[ix];
		}

	ModStatus insert(IxElt!Value elt)
	{
		ModStatus modStatus;

		static if (hasValue)
			immutable ix = elt.ix;
		else
			immutable ix = elt;

		if (contains(ix))
		{
			static if (hasValue)
				modStatus = _values[ix] != elt.value ? ModStatus.updated : ModStatus.unchanged;
			else
				modStatus = ModStatus.unchanged;
		}
		else
		{
			_ixBits[ix] = true;
			modStatus = ModStatus.added;
		}

		// set element
		static if (hasValue)
			_values[ix] = elt.value;

		return modStatus;
	}

	/** Try to find index to first set bit in `_ixBits` starting at bit index `ix` and put the result in `nextIx`.
		Returns: `true` upon find, `false` otherwise.
		TODO: move to StaticBitArray
	 */
	bool tryFindSetBitIx(UIx ix, out UIx nextIx) const @nogc
	{
		pragma(inline, true);
		assert(!_ixBits.allZero);
		return _ixBits.canFindIndexOf(true, ix, nextIx);
	}

	bool tryFindNextSetBitIx(UIx ix, out UIx nextIx) const @nogc
	{
		pragma(inline, true);
		immutable ix1 = cast(uint)(ix + 1);
		return ix1 != radix && tryFindSetBitIx(UIx(ix1), nextIx);
	}

	static if (hasValue)
	{
		/** Set value at index `ix` to `value`. */
		void setValue(UIx ix, Value value) @nogc
		{
			pragma(inline, true);
			_values[ix] = value;
		}

		inout(Value)[capacity] values() inout @nogc
		{
			version (D_Coverage) {} else version (LDC) pragma(inline, true);
			return _values;
		}
	}

private:
	StaticBitArray!capacity _ixBits;  // 32 bytes
	static if (hasValue)
	{
		// static if (is(Value == bool))
		// {
		//	 StaticBitArray!capacity _values; // packed values
		// }
		// else
		// {
		//	 Value[capacity] _values;
		// }
		Value[capacity] _values;
	}
}

/** Fixed-Length leaf Key-only Node. */
alias FixedKeyLeafN = WordVariant!(OneLeafMax7,
								   TwoLeaf3,
								   TriLeaf2);

/** Mutable leaf node of 1-Ix leaves.
 *
 * Used by branch-leaf.
 */
alias Leaf1(Value) = WordVariant!(HeptLeaf1, /+ TODO: remove from case when Value is void +/
								  SparseLeaf1!Value*,
								  DenseLeaf1!Value*);

/** Returns: `true` if `key` is stored under `curr`, `false` otherwise. */
UIx firstIx(Value)(Leaf1!Value curr)
{
	final switch (curr.typeIx) with (Leaf1!Value.Ix)
	{
	case undefined:
		assert(false);
	case ix_HeptLeaf1:
	case ix_SparseLeaf1Ptr:
		return 0;		   // always first
	case ix_DenseLeaf1Ptr:
		auto curr_ = curr.as!(DenseLeaf1!Value*);
		UIx nextIx;
		immutable bool hit = curr_.tryFindSetBitIx(0, nextIx);
		assert(hit);
		return nextIx;
	}
}

/** Try to iterate leaf index `ix` to index, either sparse or dense and put result in `nextIx`.
 *
 * Returns: `true` if `nextIx` was set, `false` if no more indexes was available.
 */
pragma(inline) bool tryNextIx(Value)(Leaf1!Value curr, const UIx ix, out Ix nextIx)
{
	final switch (curr.typeIx) with (Leaf1!Value.Ix)
	{
	case undefined:
		assert(false);
	case ix_HeptLeaf1:
		immutable curr_ = curr.as!(HeptLeaf1);
		if (ix + 1 == curr_.keys.length)
		{
			return false;
		}
		else
		{
			nextIx = Ix(ix + 1);
			return true;
		}
	case ix_SparseLeaf1Ptr:
		immutable curr_ = curr.as!(SparseLeaf1!Value*);
		if (ix + 1 == curr_.length)
		{
			return false;
		}
		else
		{
			nextIx = Ix(ix + 1);
			return true;
		}
	case ix_DenseLeaf1Ptr:
		return curr.as!(DenseLeaf1!Value*).tryFindNextSetBitIx(ix, nextIx);
	}
}

static assert((DenseLeaf1!void).sizeof == 32);

/** Adaptive radix tree/trie (ART) container storing untyped (raw) keys.

	Params:
		 Value = value type.
		 A_ = memory allocator for bin array and large bins (`LargeBin`)

	In set-case (`Value` is `void`) this container contains specific memory
	optimizations for representing a set pointers or integral types (of fixed
	length).

	Radix-trees are suitable for storing ordered sets/maps with variable-length
	keys and provide completion of all its keys matching a given
	key-prefix. This enables, for instance, efficient storage and retrieval of
	large sets of long URLs with high probability of sharing a common prefix,
	typically a domain and path.

	Branch packing of leaves is more efficient when `Key.sizeof` is fixed, that
	is, the member `hasFixedKeyLength` returns `true`.

	For optimal performance, the individual bit-chunks should be arranged
	starting with most sparse chunks first. For integers this means most
	significant chunk (byte) first. This includes IEEE-compliant floating point
	numbers.

	For a good introduction to adaptive radix trees (ART) see $(HTTP infosys.cs.uni-saarland.de/publications/ARCD15.pdf)

	See_Also: $(HTTP www.ietf.org/rfc/rfc2616.txt, RFC2616)

	See_Also: $(HTTP en.wikipedia.org/wiki/Trie)
	See_Also: $(HTTP en.wikipedia.org/wiki/Radix_tree)
	See_Also: $(HTTP github.com/npgall/concurrent-trees)
	See_Also: $(HTTP code.dogmap.org/kart/)
	See_Also: $(HTTP cr.yp.to/critbit.html)
	See_Also: $(HTTP gcc.gnu.org/onlinedocs/libstdc++/ext/pb_ds/trie_based_containers.html)
	See_Also: $(HTTP github.com/npgall/concurrent-trees)
*/
template RawRadixTree(Value = void, A_) if (isAllocator!A_) // TODO rename A_ something better later
{
	import std.algorithm.mutation : move;
	import std.algorithm.comparison : min, max;

	enum isValue = !is(Value == void);

	version (useModulo)
		alias SubCount = Mod!(radix + 1);
	else
		alias SubCount = uint; // needed because for inclusive range 0 .. 256

	struct IxSub { UIx ix; Node node; }

	/** Sparse/Packed dynamically sized branch implemented as variable-length
		struct.
	*/
	static private struct SparseBranch
	{
		enum minCapacity = 0; // minimum number of preallocated sub-indexes and sub-nodes
		enum maxCapacity = 48; // maximum number of preallocated sub-indexes and sub-nodes
		enum prefixCapacity = 5; // 5, 13, 21, ...

		version (useModulo)
			alias Count = Mod!(maxCapacity + 1);
		else
			alias Count = ubyte;

		@safe pure nothrow:

		this(size_t subCapacity)
		{
			initialize(subCapacity);
		}

		this(size_t subCapacity, const Ix[] prefix, Leaf1!Value leaf1)
		{
			initialize(subCapacity);
			this.prefix = prefix;
			this.leaf1 = leaf1;
		}

		this(size_t subCapacity, const Ix[] prefix)
		{
			initialize(subCapacity);
			this.prefix = prefix;
		}

		this(size_t subCapacity, Leaf1!Value leaf1)
		{
			initialize(subCapacity);
			this.leaf1 = leaf1;
		}

		this(size_t subCapacity, const Ix[] prefix, IxSub sub)
		{
			assert(subCapacity);

			initialize(subCapacity);

			this.prefix = prefix;
			this.subCount = 1;
			this.subIxSlots[0] = sub.ix;
			this.subNodeSlots[0] = sub.node;
		}

		this(size_t subCapacity, typeof(this)* rhs)
		in
		{
			assert(subCapacity > rhs.subCapacity);
			assert(rhs);
		}
		do
		{
			// these two must be in this order:
			// 1.
			move(rhs.leaf1, this.leaf1);
			debug rhs.leaf1 = typeof(rhs.leaf1).init;
			this.subCount = rhs.subCount;
			move(rhs.prefix, this.prefix);

			// 2.
			initialize(subCapacity);

			// copy variable length part. TODO: optimize:
			this.subIxSlots[0 .. rhs.subCount] = rhs.subIxSlots[0 .. rhs.subCount];
			this.subNodeSlots[0 .. rhs.subCount] = rhs.subNodeSlots[0 .. rhs.subCount];

			assert(this.subCapacity > rhs.subCapacity);
		}

		private void initialize(size_t subCapacity)
		{
			// assert(subCapacity != 4);
			this.subCapacity = cast(Count)subCapacity;
			debug		   // only zero-initialize in debug mode
			{
				// zero-initialize variable-length part
				subIxSlots[] = Ix.init;
				subNodeSlots[] = Node.init;
			}
		}

		typeof(this)* dupAt(A)(auto ref A alloc)
		{
			typeof(this)* copy = makeVariableSizeNodePointer!(typeof(this))(alloc, this.subCapacity);
			copy.leaf1 = treedup(this.leaf1, alloc);
			copy.prefix = this.prefix;
			copy.subCount = this.subCount;

			copy.subIxSlots[0 .. subCount] = this.subIxSlots[0 .. subCount]; // copy initialized
			debug copy.subIxSlots[subCount .. $] = Ix.init;				  // zero rest in debug

			foreach (immutable i; 0 .. subCount)
				copy.subNodeSlots[i] = treedup(subNodeSlots[i], alloc);
			return copy;
		}

		~this() nothrow @nogc
		{
			deinit();
		}

		private void deinit() @nogc { /* nothing for now */ }

		/** Insert `sub`, possibly self-reallocating `this` (into return).
		 */
		typeof(this)* reconstructingInsert(A)(auto ref A alloc, IxSub sub,
										   out ModStatus modStatus,
										   out size_t index) @trusted
		{
			typeof(this)* next = &this;

			import nxt.searching_ex : containsStoreIndex;
			if (subIxs.containsStoreIndex(sub.ix, index))
			{
				assert(subIxSlots[index] == sub.ix); // subIxSlots[index] = sub[0];
				subNodeSlots[index] = sub.node;
				modStatus = ModStatus.updated;
				return next;
			}

			if (full)
			{
				if (subCount < maxCapacity) // if we can expand more
				{
					next = makeVariableSizeNodePointer!(typeof(this))(alloc, subCount + 1, &this);
					freeNode(alloc, &this);
				}
				else
				{
					modStatus = ModStatus.maxCapacityReached; /+ TODO: expand to `DenseBranch` +/
					return next;
				}
			}

			next.insertAt(index, sub);
			modStatus = ModStatus.added;
			return next;
		}

		private void insertAt(size_t index, IxSub sub)
		{
			assert(index <= subCount);
			foreach (immutable i; 0 .. subCount - index) /+ TODO: functionize this loop or reuse memmove: +/
			{
				immutable iD = subCount - i;
				immutable iS = iD - 1;
				subIxSlots[iD] = subIxSlots[iS];
				subNodeSlots[iD] = subNodeSlots[iS];
			}
			subIxSlots[index] = cast(Ix)sub.ix; // set new element
			subNodeSlots[index] = sub.node; // set new element
			++subCount;
		}

		inout(Node) subNodeAt(UIx ix) inout
		{
			import nxt.searching_ex : binarySearch; // need this instead of `SortedRange.contains` because we need the index
			immutable hitIndex = subIxSlots[0 .. subCount].binarySearch(ix); // find index where insertion should be made
			return (hitIndex != typeof(hitIndex).max) ? subNodeSlots[hitIndex] : Node.init;
		}

		pragma(inline, true) bool empty() const @property @nogc => subCount == 0;
		pragma(inline, true) bool full()  const @nogc => subCount == subCapacity;

		import std.range : assumeSorted;

		pragma(inline, true) auto subIxs() inout @nogc => subIxSlots[0 .. subCount].assumeSorted;
		pragma(inline, true) inout(Node)[] subNodes() inout @nogc => subNodeSlots[0 .. subCount];
		pragma(inline, true) inout(Node) firstSubNode() inout @nogc => subCount ? subNodeSlots[0] : typeof(return).init;

		/** Get all sub-`Ix` slots, both initialized and uninitialized. */
		private auto subIxSlots() inout @trusted pure nothrow // TODO use `inout(Ix)[]` return type
			=> (cast(Ix*)(_subNodeSlots0.ptr + subCapacity))[0 .. subCapacity];

		/** Get all sub-`Node` slots, both initialized and uninitialized. */
		private inout(Node)[] subNodeSlots() inout @trusted pure nothrow
			=> _subNodeSlots0.ptr[0 .. subCapacity];

		/** Append statistics of tree under `this` into `stats`. */
		void appendStatsTo(ref Stats stats) const
		{
			size_t count = 0; // number of non-zero sub-nodes
			foreach (const Node sub; subNodes)
			{
				++count;
				sub.appendStatsTo!(Value, A_)(stats);
			}
			assert(count <= radix);
			++stats.popHist_SparseBranch[count]; /+ TODO: type-safe indexing +/

			stats.sparseBranchAllocatedSizeSum += allocatedSize;

			if (leaf1)
				leaf1.appendStatsTo!(Value, A_)(stats);
		}

		/** Get allocation size (in bytes) needed to hold `length` number of
			sub-indexes and sub-nodes. */
		static size_t allocationSizeOfCapacity(in size_t capacity) pure nothrow @safe @nogc
			=> (this.sizeof + // base plus
				Node.sizeof*capacity + // actual size of `_subNodeSlots0`
				Ix.sizeof*capacity);   // actual size of `_subIxSlots0`

		/** Get allocated size (in bytes) of `this` including the variable-length part. */
		size_t allocatedSize() const pure nothrow @safe @nogc
			=> allocationSizeOfCapacity(subCapacity);

	private:

		// members in order of decreasing `alignof`:
		Leaf1!Value leaf1;

		IxsN!(prefixCapacity, 1) prefix; // prefix common to all `subNodes` (also called edge-label)
		Count subCount;
		Count subCapacity;
		static assert(prefix.sizeof + subCount.sizeof + subCapacity.sizeof == 8); // assert alignment

		// variable-length part
		Node[0] _subNodeSlots0;
		Ix[0] _subIxSlots0;	 // needs to special alignment
	}

	static assert(hasVariableSize!SparseBranch);
	static if (!isValue)
		static assert(SparseBranch.sizeof == 16);

	/** Dense/Unpacked `radix`-branch with `radix` number of sub-nodes. */
	static private struct DenseBranch
	{
		enum maxCapacity = 256;
		enum prefixCapacity = 15; // 7, 15, 23, ..., we can afford larger prefix here because DenseBranch is so large

		@safe pure nothrow:

		this(const Ix[] prefix)
		{
			this.prefix = prefix;
		}

		this(const Ix[] prefix, IxSub sub)
		{
			this(prefix);
			this.subNodes[sub.ix] = sub.node;
		}

		this(const Ix[] prefix, IxSub subA, IxSub subB)
		{
			assert(subA.ix != subB.ix); // disjunct indexes
			assert(subA.node != subB.node); // disjunct nodes

			this.subNodes[subA.ix] = subA.node;
			this.subNodes[subB.ix] = subB.node;
		}

		this(SparseBranch* rhs)
		{
			this.prefix = rhs.prefix;

			// move leaf
			move(rhs.leaf1, this.leaf1);
			debug rhs.leaf1 = Leaf1!Value.init; // make reference unique, to be on the safe side

			foreach (immutable i; 0 .. rhs.subCount) // each sub node. TODO: use iota!(Mod!N)
			{
				immutable iN = (cast(ubyte)i).mod!(SparseBranch.maxCapacity);
				immutable subIx = UIx(rhs.subIxSlots[iN]);

				this.subNodes[subIx] = rhs.subNodeSlots[iN];
				debug rhs.subNodeSlots[iN] = null; // make reference unique, to be on the safe side
			}
		}

		typeof(this)* dupAt(A)(auto ref A alloc) @trusted /+ TODO: remove @trusted qualifier when .ptr problem has been fixed +/
		{
			auto copy = makeFixedSizeNodePointer!(typeof(this))(alloc);
			copy.leaf1 = treedup(leaf1, alloc);
			copy.prefix = prefix;
			foreach (immutable i, subNode; subNodes)
				copy.subNodes.ptr[i] = treedup(subNode, alloc); /+ TODO: remove .ptr access when I inout problem is solved +/
			return copy;
		}

		/** Number of non-null sub-Nodes. */
		SubCount subCount() const
		{
			typeof(return) count = 0; // number of non-zero sub-nodes
			foreach (immutable subNode; subNodes) /+ TODO: why can't we use std.algorithm.count here? +/
				if (subNode)
					++count;
			assert(count <= radix);
			return count;
		}

		bool findSubNodeAtIx(size_t currIx, out UIx nextIx) inout @nogc
		{
			import std.algorithm.searching : countUntil;
			immutable cnt = subNodes[currIx .. $].countUntil!(subNode => cast(bool)subNode);
			immutable bool hit = cnt >= 0;
			if (hit)
			{
				const nextIx_ = currIx + cnt;
				assert(nextIx_ <= Ix.max);
				nextIx = cast(Ix)nextIx_;
			}
			return hit;
		}

		/** Append statistics of tree under `this` into `stats`. */
		void appendStatsTo(ref Stats stats) const
		{
			size_t count = 0; // number of non-zero sub-nodes
			foreach (const Node subNode; subNodes)
				if (subNode)
				{
					++count;
					subNode.appendStatsTo!(Value, A_)(stats);
				}
			assert(count <= radix);
			++stats.popHist_DenseBranch[count]; /+ TODO: type-safe indexing +/
			if (leaf1)
				leaf1.appendStatsTo!(Value, A_)(stats);
		}

	private:
		// members in order of decreasing `alignof`:
		Leaf1!Value leaf1;
		IxsN!(prefixCapacity, 1) prefix; // prefix (edge-label) common to all `subNodes`
		import nxt.typecons_ex : IndexedBy;
		IndexedBy!(Node[radix], UIx) subNodes;
	}

	version (showBranchSizes)
	{
		pragma(msg, "SparseBranch.sizeof:", SparseBranch.sizeof, " SparseBranch.alignof:", SparseBranch.alignof);
		pragma(msg, "DenseBranch.sizeof:", DenseBranch.sizeof, " DenseBranch.alignof:", DenseBranch.alignof);

		pragma(msg, "SparseBranch.prefix.sizeof:", SparseBranch.prefix.sizeof, " SparseBranch.prefix.alignof:", SparseBranch.prefix.alignof);
		pragma(msg, "DenseBranch.prefix.sizeof:", DenseBranch.prefix.sizeof, " DenseBranch.prefix.alignof:", DenseBranch.prefix.alignof);

		// pragma(msg, "SparseBranch.subNodes.sizeof:", SparseBranch.subNodes.sizeof, " SparseBranch.subNodes.alignof:", SparseBranch.subNodes.alignof);
		// pragma(msg, "SparseBranch.subIxs.sizeof:", SparseBranch.subIxs.sizeof, " SparseBranch.subIxs.alignof:", SparseBranch.subIxs.alignof);
	}

	/+ TODO: make these run-time arguments at different key depths and map to statistics of typed-key +/
	alias DefaultBranch = SparseBranch; // either `SparseBranch`, `DenseBranch`

	/** Mutable node. */
	alias Node = WordVariant!(OneLeafMax7,
							  TwoLeaf3,
							  TriLeaf2,

							  HeptLeaf1,
							  SparseLeaf1!Value*,
							  DenseLeaf1!Value*,

							  SparseBranch*,
							  DenseBranch*);

	/** Mutable branch node. */
	alias Branch = WordVariant!(SparseBranch*,
								DenseBranch*);

	static assert(Node.typeBits <= IxsN!(7, 1).typeBits);
	static assert(Leaf1!Value.typeBits <= IxsN!(7, 1).typeBits);
	static assert(Branch.typeBits <= IxsN!(7, 1).typeBits);

	/** Constant node. */
	/+ TODO: make work with indexNaming +/
	// import std.typecons : ConstOf;
	// alias ConstNodePtr = WordVariant!(staticMap!(ConstOf, Node));

	static assert(span <= 8*Ix.sizeof, "Need more precision in Ix");

	/** Element reference. */
	private static struct ElementRef
	{
		Node node;
		UIx ix; // `Node`-specific counter, typically either a sparse or dense index either a sub-branch or a `UKey`-ending `Ix`
		ModStatus modStatus;

		pragma(inline, true)
		bool opCast(T : bool)() const pure nothrow @safe @nogc => cast(bool)node;
	}

	/** Branch Range (Iterator). */
	private static struct BranchRange
	{
		@safe pure nothrow:

		this(SparseBranch* branch)
		{
			this.branch = Branch(branch);

			this._subsEmpty = branch.subCount == 0;
			this._subCounter = 0; // always zero

			if (branch.leaf1)
				this.leaf1Range = Leaf1Range(branch.leaf1);

			cacheFront();
		}

		this(DenseBranch* branch)
		{
			this.branch = Branch(branch);

			this._subCounter = 0; /+ TODO: needed? +/
			_subsEmpty = !branch.findSubNodeAtIx(0, this._subCounter);

			if (branch.leaf1)
				this.leaf1Range = Leaf1Range(branch.leaf1);

			cacheFront();
		}

		pragma(inline, true) UIx frontIx() const @nogc in(!empty) => _cachedFrontIx;
		pragma(inline, true) bool atLeaf1() const @nogc in(!empty) => _frontAtLeaf1;

		private UIx subFrontIx() const
		{
			final switch (branch.typeIx) with (Branch.Ix)
			{
			case undefined:
				assert(false);
			case ix_SparseBranchPtr:
				return UIx(branch.as!(SparseBranch*).subIxs[_subCounter]);
			case ix_DenseBranchPtr:
				return _subCounter;
			}
		}

		private Node subFrontNode() const
		{
			final switch (branch.typeIx) with (Branch.Ix)
			{
			case undefined:
				assert(false);
			case ix_SparseBranchPtr: return branch.as!(SparseBranch*).subNodeSlots[_subCounter];
			case ix_DenseBranchPtr: return branch.as!(DenseBranch*).subNodes[_subCounter];
			}
		}

		void appendFrontIxsToKey(ref Ixs key) const @nogc
		{
			final switch (branch.typeIx) with (Branch.Ix)
			{
			case undefined:
				assert(false);
			case ix_SparseBranchPtr:
				key ~= branch.as!(SparseBranch*).prefix[];
				break;
			case ix_DenseBranchPtr:
				key ~= branch.as!(DenseBranch*).prefix[];
				break;
			}
			key ~= cast(Ix)frontIx; // uses cached data so ok to not depend on branch type
		}

		size_t prefixLength() const @nogc
		{
			final switch (branch.typeIx) with (Branch.Ix)
			{
			case undefined:
				assert(false);
			case ix_SparseBranchPtr: return branch.as!(SparseBranch*).prefix.length;
			case ix_DenseBranchPtr: return  branch.as!(DenseBranch*).prefix.length;
			}
		}

		pragma(inline, true) bool empty() const @property @nogc => leaf1Range.empty && _subsEmpty;
		pragma(inline, true) bool subsEmpty() const @nogc => _subsEmpty;

		/** Try to iterated forward.
			Returns: `true` upon successful forward iteration, `false` otherwise (upon completion of iteration),
		*/
		void popFront() in(!empty)
		{
			// pop front element
			if (_subsEmpty)
				leaf1Range.popFront();
			else if (leaf1Range.empty)
				popBranchFront();
			else				// both non-empty
			{
				if (leaf1Range.front <= subFrontIx) // `a` before `ab`
					leaf1Range.popFront();
				else
					popBranchFront();
			}
			if (!empty) { cacheFront(); }
		}

		/** Fill cached value and remember if we we next element is direct
			(_frontAtLeaf1 is true) or under a sub-branch (_frontAtLeaf1 is
			false).
		*/
		void cacheFront() in(!empty)
		{
			if (_subsEmpty)	 // no more sub-nodes
			{
				_cachedFrontIx = leaf1Range.front;
				_frontAtLeaf1 = true;
			}
			else if (leaf1Range.empty) // no more in direct leaf node
			{
				_cachedFrontIx = subFrontIx;
				_frontAtLeaf1 = false;
			}
			else				// both non-empty
			{
				immutable leaf1Front = leaf1Range.front;
				if (leaf1Front <= subFrontIx) // `a` before `ab`
				{
					_cachedFrontIx = leaf1Front;
					_frontAtLeaf1 = true;
				}
				else
				{
					_cachedFrontIx = subFrontIx;
					_frontAtLeaf1 = false;
				}
			}
		}

		private void popBranchFront()
		{
			/+ TODO: move all calls to Branch-specific members popFront() +/
			final switch (branch.typeIx) with (Branch.Ix)
			{
			case undefined:
				assert(false);
			case ix_SparseBranchPtr:
				auto branch_ = branch.as!(SparseBranch*);
				if (_subCounter + 1 == branch_.subCount)
					_subsEmpty = true;
				else
					++_subCounter;
				break;
			case ix_DenseBranchPtr:
				auto branch_ = branch.as!(DenseBranch*);
				_subsEmpty = !branch_.findSubNodeAtIx(_subCounter + 1, this._subCounter);
				break;
			}
		}

	private:
		Branch branch;		  // branch part of range
		Leaf1Range leaf1Range;  // range of direct leaves

		UIx _subCounter; // `Branch`-specific counter, typically either a sparse or dense index either a sub-branch or a `UKey`-ending `Ix`
		UIx _cachedFrontIx;

		bool _frontAtLeaf1;   // `true` iff front is currently at a leaf1 element
		bool _subsEmpty;	  // `true` iff no sub-nodes exists
	}

	/** Leaf1 Range (Iterator). */
	private static struct Leaf1Range
	{
		this(Leaf1!Value leaf1)
		{
			this.leaf1 = leaf1;
			bool emptied;
			this._ix = firstIx(emptied);
			if (emptied)
				this.leaf1 = null;
		}

		@safe pure nothrow:

		/** Get first index in current subkey. */
		UIx front() const in(!empty)
		{
			final switch (leaf1.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				assert(false);
			case ix_HeptLeaf1:
				static if (isValue)
					assert(false, "HeptLeaf1 cannot store a value");
				else
					return UIx(leaf1.as!(HeptLeaf1).keys[_ix]);
			case ix_SparseLeaf1Ptr:
				return UIx(leaf1.as!(SparseLeaf1!Value*).ixs[_ix]);
			case ix_DenseLeaf1Ptr:
				return _ix;
			}
		}

		static if (isValue)
		{
			Value frontValue() const in(!empty)
			{
				final switch (leaf1.typeIx) with (Leaf1!Value.Ix)
				{
				case undefined:
					assert(false);
				case ix_HeptLeaf1: assert(false, "HeptLeaf1 cannot store a value");
				case ix_SparseLeaf1Ptr:
					return leaf1.as!(SparseLeaf1!Value*).values[_ix];
				case ix_DenseLeaf1Ptr:
					return leaf1.as!(DenseLeaf1!Value*).values[_ix];
				}
			}
		}

		bool empty() const @property @nogc => leaf1.isNull;

		/** Pop front element.
		 */
		void popFront() in(!empty)
		{
			/+ TODO: move all calls to leaf1-specific members popFront() +/
			final switch (leaf1.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				assert(false);
			case ix_HeptLeaf1:
				static if (isValue)
					assert(false, "HeptLeaf1 cannot store a value");
				else
				{
					immutable leaf_ = leaf1.as!(HeptLeaf1);
					if (_ix + 1 == leaf_.keys.length)
						leaf1 = null;
					else
						++_ix;
					break;
				}
			case ix_SparseLeaf1Ptr:
				const leaf_ = leaf1.as!(SparseLeaf1!Value*);
				if (_ix + 1 == leaf_.length)
					leaf1 = null;
				else
					++_ix;
				break;
			case ix_DenseLeaf1Ptr:
				const leaf_ = leaf1.as!(DenseLeaf1!Value*);
				if (!leaf_.tryFindNextSetBitIx(_ix, _ix))
					leaf1 = null;
				break;
			}
		}

		static if (isValue)
		{
			auto ref value() inout
			{
				final switch (leaf1.typeIx) with (Leaf1!Value.Ix)
				{
				case undefined:
					assert(false);
				case ix_HeptLeaf1: assert(false, "HeptLeaf1 cannot store a value");
				case ix_SparseLeaf1Ptr: return leaf1.as!(SparseLeaf1!Value*).values[_ix];
				case ix_DenseLeaf1Ptr: return leaf1.as!(DenseLeaf1!Value*).values[_ix];
				}
			}
		}

		private UIx firstIx(out bool empty) const
		{
			final switch (leaf1.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				assert(false);
			case ix_HeptLeaf1:
				static if (isValue)
					assert(false, "HeptLeaf1 cannot store a value");
				else
					return UIx(0);		   // always first
			case ix_SparseLeaf1Ptr:
				auto leaf_ = leaf1.as!(SparseLeaf1!Value*);
				empty = leaf_.empty;
				return UIx(0);		   // always first
			case ix_DenseLeaf1Ptr:
				auto leaf_ = leaf1.as!(DenseLeaf1!Value*);
				UIx nextIx;
				immutable bool hit = leaf_.tryFindSetBitIx(UIx(0), nextIx);
				assert(hit);
				return nextIx;
			}
		}

	private:
		Leaf1!Value leaf1; /+ TODO: Use Leaf1!Value-WordVariant when it includes non-Value leaf1 types +/
		UIx _ix; // `Node`-specific counter, typically either a sparse or dense index either a sub-branch or a `UKey`-ending `Ix`
	}

	/** Leaf Value Range (Iterator). */
	private static struct LeafNRange
	{
		this(Node leaf)
		{
			this.leaf = leaf;
			bool emptied;
			this.ix = firstIx(emptied);
			if (emptied)
				this.leaf = null;
		}

		@safe pure nothrow:

		private UIx firstIx(out bool emptied) const
		{
			switch (leaf.typeIx) with (Node.Ix)
			{
			case undefined:
				assert(false);
			case ix_OneLeafMax7:
			case ix_TwoLeaf3:
			case ix_TriLeaf2:
			case ix_HeptLeaf1:
				return UIx(0);		   // always first
			case ix_SparseLeaf1Ptr:
				const leaf_ = leaf.as!(SparseLeaf1!Value*);
				emptied = leaf_.empty;
				return UIx(0);		   // always first
			case ix_DenseLeaf1Ptr:
				const leaf_ = leaf.as!(DenseLeaf1!Value*);
				UIx nextIx;
				immutable bool hit = leaf_.tryFindSetBitIx(UIx(0), nextIx);
				assert(hit);
				return nextIx;
			default: assert(false, "Unsupported Node type");
			}
		}

		/** Get first index in current subkey. */
		UIx frontIx() in(!empty)
		{
			switch (leaf.typeIx) with (Node.Ix)
			{
			case undefined:
				assert(false);
			case ix_OneLeafMax7:
				assert(ix == 0);
				return UIx(leaf.as!(OneLeafMax7).key[0]);
			case ix_TwoLeaf3:
				return UIx(leaf.as!(TwoLeaf3).keys[ix][0]);
			case ix_TriLeaf2:
				return UIx(leaf.as!(TriLeaf2).keys[ix][0]);
			case ix_HeptLeaf1:
				return UIx(leaf.as!(HeptLeaf1).keys[ix]);
			case ix_SparseLeaf1Ptr:
				return UIx(leaf.as!(SparseLeaf1!Value*).ixs[ix]);
			case ix_DenseLeaf1Ptr:
				return ix;
			default: assert(false, "Unsupported Node type");
			}
		}

		void appendFrontIxsToKey(ref Ixs key) const @nogc in(!empty)
		{
			switch (leaf.typeIx) with (Node.Ix)
			{
			case undefined:
				assert(false);
			case ix_OneLeafMax7:
				assert(ix == 0);
				key ~= leaf.as!(OneLeafMax7).key[];
				break;
			case ix_TwoLeaf3:
				key ~= leaf.as!(TwoLeaf3).keys[ix][];
				break;
			case ix_TriLeaf2:
				key ~= leaf.as!(TriLeaf2).keys[ix][];
				break;
			case ix_HeptLeaf1:
				key ~= Ix(leaf.as!(HeptLeaf1).keys[ix]);
				break;
			case ix_SparseLeaf1Ptr:
				key ~= Ix(leaf.as!(SparseLeaf1!Value*).ixs[ix]);
				break;
			case ix_DenseLeaf1Ptr:
				key ~= cast(Ix)ix;
				break;
			default: assert(false, "Unsupported Node type");
			}
		}

		pragma(inline, true) bool empty() const @property @nogc => !leaf;
		pragma(inline, true) void makeEmpty() @nogc { leaf = null; }

		/** Pop front element. */
		void popFront() in(!empty)
		{
			/+ TODO: move all calls to leaf-specific members popFront() +/
			switch (leaf.typeIx) with (Node.Ix)
			{
			case undefined:
				assert(false);
			case ix_OneLeafMax7:
				makeEmpty(); // only one element so forward automatically completes
				break;
			case ix_TwoLeaf3:
				auto leaf_ = leaf.as!(TwoLeaf3);
				if (ix + 1 == leaf_.keys.length) { makeEmpty(); } else { ++ix; }
				break;
			case ix_TriLeaf2:
				auto leaf_ = leaf.as!(TriLeaf2);
				if (ix + 1 == leaf_.keys.length) { makeEmpty(); } else { ++ix; }
				break;
			case ix_HeptLeaf1:
				auto leaf_ = leaf.as!(HeptLeaf1);
				if (ix + 1 == leaf_.keys.length) { makeEmpty(); } else { ++ix; }
				break;
			case ix_SparseLeaf1Ptr:
				auto leaf_ = leaf.as!(SparseLeaf1!Value*);
				if (ix + 1 == leaf_.length) { makeEmpty(); } else { ++ix; }
				break;
			case ix_DenseLeaf1Ptr:
				auto leaf_ = leaf.as!(DenseLeaf1!Value*);
				immutable bool emptied = !leaf_.tryFindNextSetBitIx(ix, ix);
				if (emptied)
					makeEmpty();
				break;
			default: assert(false, "Unsupported Node type");
			}
		}

		static if (isValue)
		{
			auto ref value() inout
			{
				switch (leaf.typeIx) with (Node.Ix)
				{
				case ix_SparseLeaf1Ptr: return leaf.as!(SparseLeaf1!Value*).values[ix];
				case ix_DenseLeaf1Ptr: return leaf.as!(DenseLeaf1!Value*).values[ix];
				default: assert(false, "Incorrect Leaf-type");
				}
			}
		}

	private:
		Node leaf;			  /+ TODO: Use Leaf-WordVariant when it includes non-Value leaf types +/
		UIx ix; // `Node`-specific counter, typically either a sparse or dense index either a sub-branch or a `UKey`-ending `Ix`
	}

	/** Ordered Set of BranchRanges. */
	private static struct BranchRanges
	{
		static if (isValue)
		{
			bool appendFrontIxsToKey(ref Ixs key, ref Value value) const @trusted
			{
				foreach (const ref branchRange; _bRanges)
				{
					branchRange.appendFrontIxsToKey(key);
					if (branchRange.atLeaf1)
					{
						value = branchRange.leaf1Range.frontValue;
						return true; // key and value are both complete
					}
				}
				return false;   // only key is partially complete
			}
		}
		else
		{
			bool appendFrontIxsToKey(ref Ixs key) const @trusted
			{
				foreach (const ref branchRange; _bRanges)
				{
					branchRange.appendFrontIxsToKey(key);
					if (branchRange.atLeaf1)
						return true; // key is complete
				}
				return false;   // key is not complete
			}
		}
		size_t get1DepthAt(size_t depth) const @trusted
		{
			foreach (immutable i, ref branchRange; _bRanges[depth .. $])
			{
				if (branchRange.atLeaf1)
					return depth + i;
			}
			return typeof(_branch1Depth).max;
		}

		private void updateLeaf1AtDepth(size_t depth) @trusted
		{
			if (_bRanges[depth].atLeaf1)
			{
				if (_branch1Depth == typeof(_branch1Depth).max) // if not yet defined
					_branch1Depth = min(depth, _branch1Depth);
			}
			assert(_branch1Depth == get1DepthAt(0));
		}

		pragma(inline, true)
		size_t getNext1DepthAt() const => get1DepthAt(_branch1Depth + 1);

		pragma(inline, true)
		bool hasBranch1Front() const => _branch1Depth != typeof(_branch1Depth).max;

		void popBranch1Front()
		{
			pragma(inline, true);
			// _branchesKeyPrefix.popBackN(_bRanges.back);
			_bRanges[_branch1Depth].popFront();
		}

		pragma(inline, true)
		bool emptyBranch1() const => _bRanges[_branch1Depth].empty;

		pragma(inline, true)
		bool atLeaf1() const => _bRanges[_branch1Depth].atLeaf1;

		void shrinkTo(size_t newLength)
		{
			pragma(inline, true);
			// turn emptyness exception into an assert like ranges do
			// size_t suffixLength = 0;
			// foreach (const ref branchRange; _bRanges[$ - newLength .. $]) /+ TODO: reverse isearch +/
			// {
			//	 suffixLength += branchRange.prefixLength + 1;
			// }
			// _branchesKeyPrefix.popBackN(suffixLength);
			_bRanges.length = newLength;
		}

		void push(ref BranchRange branchRange)
		{
			pragma(inline, true);
			// branchRange.appendFrontIxsToKey(_branchesKeyPrefix);
			_bRanges ~= branchRange;
		}

		pragma(inline, true)
		size_t branchCount() const pure nothrow @safe @nogc => _bRanges.length;

		pragma(inline, true)
		void pop() => _bRanges.popBack(); // _branchesKeyPrefix.popBackN(_bRanges.back.prefixLength + 1);

		pragma(inline, true)
		ref BranchRange bottom() => _bRanges.back;

		pragma(inline, true)
		private void verifyBranch1Depth() => assert(_branch1Depth == get1DepthAt(0));

		void resetBranch1Depth()
		{
			pragma(inline, true);
			_branch1Depth = typeof(_branch1Depth).max;
		}

		@property typeof(this) save()
		{
			typeof(this) copy;
			copy._bRanges = this._bRanges.dupShallow; // ...this is inferred as @safe
			copy._branch1Depth = this._branch1Depth;
			return copy;
		}

	private:
		import std.experimental.allocator.mallocator : Mallocator;
		Array!(BranchRange, Mallocator) _bRanges;
		// Ixs _branchesKeyPrefix;

		// index to first branchrange in `_bRanges` that is currently on a leaf1
		// or `typeof.max` if undefined
		size_t _branch1Depth = size_t.max;
	}

	/** Forward (Left) Single-Directional Range over Tree. */
	private static struct FrontRange
	{
		@safe pure nothrow:

		this(Node root) @nogc
		{
			if (root)
			{
				diveAndVisitTreeUnder(root, 0);
				cacheFront();
			}
		}

		void popFront() @nogc
		{
			debug branchRanges.verifyBranch1Depth();

			if (branchRanges.hasBranch1Front) // if we're currently at leaf1 of branch
				popFrontInBranchLeaf1();
			else				// if bottommost leaf should be popped
			{
				leafNRange.popFront();
				if (leafNRange.empty)
					postPopTreeUpdate();
			}

			if (!empty)
				cacheFront();
		}

		private void popFrontInBranchLeaf1() @nogc /+ TODO: move to member of BranchRanges +/
		{
			branchRanges.popBranch1Front();
			if (branchRanges.emptyBranch1)
			{
				branchRanges.shrinkTo(branchRanges._branch1Depth); // remove `branchRange` and all others below
				branchRanges.resetBranch1Depth();
				postPopTreeUpdate();
			}
			else if (!branchRanges.atLeaf1) // if not at leaf
				branchRanges._branch1Depth = branchRanges.getNext1DepthAt;
			else				// still at leaf
			{
				// nothing needed
			}
		}

		private void cacheFront() @nogc
		{
			_cachedFrontKey.length = 0; // not clear() because we want to keep existing allocation

			// branches
			static if (isValue)
			{
				if (branchRanges.appendFrontIxsToKey(_cachedFrontKey,
													 _cachedFrontValue))
					return;
			}
			else
			{
				if (branchRanges.appendFrontIxsToKey(_cachedFrontKey))
					return;
			}

			// leaf
			if (!leafNRange.empty)
			{
				leafNRange.appendFrontIxsToKey(_cachedFrontKey);
				static if (isValue)
					_cachedFrontValue = leafNRange.value; // last should be leaf containing value
			}
		}

		// Go upwards and iterate forward in parents.
		private void postPopTreeUpdate() @nogc
		{
			while (branchRanges.branchCount)
			{
				branchRanges.bottom.popFront();
				if (branchRanges.bottom.empty)
					branchRanges.pop();
				else			// if not empty
				{
					if (branchRanges.bottom.atLeaf1)
						branchRanges._branch1Depth = min(branchRanges.branchCount - 1,
														 branchRanges._branch1Depth);
					break;	  // branchRanges.bottom is not empty so break
				}
			}
			if (branchRanges.branchCount &&
				!branchRanges.bottom.subsEmpty) // if any sub nodes
				diveAndVisitTreeUnder(branchRanges.bottom.subFrontNode,
									  branchRanges.branchCount); // visit them
		}

		/** Find ranges of branches and leaf for all nodes under tree `root`. */
		private void diveAndVisitTreeUnder(Node root, size_t depth) @nogc
		{
			Node curr = root;
			Node next;
			do
			{
				final switch (curr.typeIx) with (Node.Ix)
				{
				case undefined:
					assert(false);
				case ix_OneLeafMax7:
				case ix_TwoLeaf3:
				case ix_TriLeaf2:
				case ix_HeptLeaf1:
				case ix_SparseLeaf1Ptr:
				case ix_DenseLeaf1Ptr:
					assert(leafNRange.empty);
					leafNRange = LeafNRange(curr);
					next = null; // we're done diving
					break;
				case ix_SparseBranchPtr:
					auto curr_ = curr.as!(SparseBranch*);
					auto currRange = BranchRange(curr_);
					branchRanges.push(currRange);
					branchRanges.updateLeaf1AtDepth(depth);
					next = (curr_.subCount) ? curr_.firstSubNode : Node.init;
					break;
				case ix_DenseBranchPtr:
					auto curr_ = curr.as!(DenseBranch*);
					auto currRange = BranchRange(curr_);
					branchRanges.push(currRange);
					branchRanges.updateLeaf1AtDepth(depth);
					next = branchRanges.bottom.subsEmpty ? Node.init : branchRanges.bottom.subFrontNode;
					break;
				}
				curr = next;
				++depth;
			}
			while (next);
		}

		@property typeof(this) save() @nogc @trusted /+ TODO: remove @trusted +/
		{
			typeof(this) copy;
			copy.leafNRange = this.leafNRange;
			copy.branchRanges = this.branchRanges.save;
			copy._cachedFrontKey = this._cachedFrontKey.dupShallow;
			static if (isValue)
				copy._cachedFrontValue = this._cachedFrontValue;
			return copy;
		}

		/** Check if empty. */
		pragma(inline, true)
		bool empty() const @property @nogc => (leafNRange.empty && branchRanges.branchCount == 0);

		/** Get front key. */
		pragma(inline, true)
		auto frontKey() const @trusted @nogc => _cachedFrontKey[]; /+ TODO: replace @trusted with DIP-1000 scope +/

		static if (isValue)
		{
			/** Get front value. */
			pragma(inline, true)
			auto frontValue() const @nogc => _cachedFrontValue;
		}

	private:
		LeafNRange leafNRange;
		BranchRanges branchRanges;

		// cache
		Ixs _cachedFrontKey; // copy of front key
		static if (isValue)
			Value _cachedFrontValue; // copy of front value
	}

	/** Bi-Directional Range over Tree.
		Fulfills `isBidirectionalRange`.
	*/
	private static struct Range
	{
		import nxt.algorithm.searching : startsWith;

		pure nothrow:

		this(Node root, UKey keyPrefix) @nogc
		{
			this._rawKeyPrefix = keyPrefix;

			this._front = FrontRange(root);
			/+ TODO: this._back = FrontRange(root); +/

			if (!empty &&
				!_front.frontKey.startsWith(_rawKeyPrefix))
				popFront();
		}

		@property typeof(this) save() @nogc
		{
			typeof(this) copy;
			copy._front = this._front.save;
			copy._back = this._back.save;
			copy._rawKeyPrefix = this._rawKeyPrefix;
			return copy;
		}

		pragma(inline, true)
		bool empty() const @property @nogc => _front.empty; /+ TODO: _front == _back; +/

		pragma(inline, true)
		auto lowKey() const @nogc => _front.frontKey[_rawKeyPrefix.length .. $];

		pragma(inline, true)
		auto highKey() const @nogc => _back.frontKey[_rawKeyPrefix.length .. $];

		void popFront() @nogc in(!empty)
		{
			do { _front.popFront(); }
			while (!empty &&
				   !_front.frontKey.startsWith(_rawKeyPrefix));
		}

		void popBack() @nogc in(!empty)
		{
			do { _back.popFront(); }
			while (!empty &&
				   !_back.frontKey.startsWith(_rawKeyPrefix));
		}

	private:
		FrontRange _front;
		FrontRange _back;
		UKey _rawKeyPrefix;
	}

	/** Sparse-Branch population histogram. */
	alias SparseLeaf1_PopHist = size_t[radix];

	/** 256-Branch population histogram. */
	alias DenseLeaf1_PopHist = size_t[radix];

	/** 4-Branch population histogram.
		Index maps to population with value range (0 .. 4).
	*/
	alias SparseBranch_PopHist = size_t[SparseBranch.maxCapacity + 1];

	/** Radix-Branch population histogram.
		Index maps to population with value range (0 .. `radix`).
	*/
	alias DenseBranch_PopHist = size_t[radix + 1];

	/** Tree Population and Memory-Usage Statistics. */
	struct Stats
	{
		SparseLeaf1_PopHist popHist_SparseLeaf1;
		DenseLeaf1_PopHist popHist_DenseLeaf1;
		SparseBranch_PopHist popHist_SparseBranch; // packed branch population histogram
		DenseBranch_PopHist popHist_DenseBranch; // full branch population histogram

		import nxt.typecons_ex : IndexedArray;

		/** Maps `Node` type/index `Ix` to population.

			Used to calculate complete tree memory usage, excluding allocator
			overhead typically via `malloc` and `calloc`.
		*/
		IndexedArray!(size_t, Node.Ix) popByNodeType;
		static assert(is(typeof(popByNodeType).Index == Node.Ix));

		IndexedArray!(size_t, Leaf1!Value.Ix) popByLeaf1Type;
		static assert(is(typeof(popByLeaf1Type).Index == Leaf1!Value.Ix));

		/** Number of heap-allocated `Node`s. Should always equal `heapAllocationBalance`. */
		size_t heapNodeCount;

		/** Number of heap-allocated `Leaf`s. Should always equal `heapLeafAllocationBalance`. */
		size_t heapLeafCount;

		size_t sparseBranchAllocatedSizeSum;

		size_t sparseLeaf1AllocatedSizeSum;
	}

	/** Destructively expand `curr` to a branch node able to store
		`capacityIncrement` more sub-nodes.
	*/
	Branch expand(A)(auto ref A alloc, SparseBranch* curr, in size_t capacityIncrement = 1) @safe pure nothrow
	in(curr.subCount < radix)	// we shouldn't expand beyond radix
	{
		typeof(return) next;
		if (curr.empty)	 // if curr also empty length capacity must be zero
			next = makeVariableSizeNodePointer!(typeof(*curr))(alloc, 1, curr); // so allocate one
		else if (curr.subCount + capacityIncrement <= curr.maxCapacity) // if we can expand to curr
		{
			immutable requiredCapacity = curr.subCapacity + capacityIncrement;
			auto next_ = makeVariableSizeNodePointer!(typeof(*curr))(alloc, requiredCapacity, curr);
			assert(next_.subCapacity >= requiredCapacity);
			next = next_;
		}
		else
			next = makeFixedSizeNodePointer!(DenseBranch)(alloc, curr);
		freeNode(alloc, curr);
		return next;
	}

	/** Destructively expand `curr` to a leaf node able to store
		`capacityIncrement` more sub-nodes.
	*/
	Leaf1!Value expand(A)(auto ref A alloc, SparseLeaf1!Value* curr, in size_t capacityIncrement = 1) @safe pure nothrow
	in(curr.length < radix)		// we shouldn't expand beyond radix
	{
		typeof(return) next;
		if (curr.empty)	 // if curr also empty length capacity must be zero
			next = makeVariableSizeNodePointer!(typeof(*curr))(alloc, capacityIncrement); // make room for at least one
		else if (curr.length + capacityIncrement <= curr.maxCapacity) // if we can expand to curr
		{
			immutable requiredCapacity = curr.capacity + capacityIncrement;
			static if (isValue)
				auto next_ = makeVariableSizeNodePointer!(typeof(*curr))(alloc, requiredCapacity, curr.ixs, curr.values);
			else
				auto next_ = makeVariableSizeNodePointer!(typeof(*curr))(alloc, requiredCapacity, curr.ixs);
			assert(next_.capacity >= requiredCapacity);
			next = next_;
		}
		else
		{
			static if (isValue)
				next = makeFixedSizeNodePointer!(DenseLeaf1!Value)(alloc, curr.ixs, curr.values); /+ TODO: make use of sortedness of `curr.keys`? +/
			else
				next = makeFixedSizeNodePointer!(DenseLeaf1!Value)(alloc, curr.ixs); /+ TODO: make use of sortedness of `curr.keys`? +/
		}
		freeNode(alloc, curr);
		return next;
	}

	/// ditto

	Branch setSub(A)(auto ref A alloc, SparseBranch* curr, UIx subIx, Node subNode) @safe pure nothrow
	{
		// debug if (willFail) { dbg("WILL FAIL: subIx:", subIx); }
		size_t insertionIndex;
		ModStatus modStatus;
		curr = curr.reconstructingInsert(alloc, IxSub(subIx, subNode), modStatus, insertionIndex);
		if (modStatus == ModStatus.maxCapacityReached) // try insert and if it fails
		{
			// we need to expand because `curr` is full
			auto next = expand(alloc, curr);
			assert(getSub(next, subIx) == Node.init); // key slot should be unoccupied
			return setSub(alloc, next, subIx, subNode);
		}
		return Branch(curr);
	}

	/// ditto
	Branch setSub(DenseBranch* curr, UIx subIx, Node subNode) pure nothrow @safe @nogc
	in(!curr.subNodes[subIx], "sub-Node already set ")
	{
		pragma(inline, true);
		// "sub-Node at index " ~ subIx.to!string ~
		// " already set to " ~ subNode.to!string);
		curr.subNodes[subIx] = subNode;
		return Branch(curr);
	}

	/** Set sub-`Node` of branch `Node curr` at index `ix` to `subNode`. */
	Branch setSub(A)(auto ref A alloc, Branch curr, UIx subIx, Node subNode) pure nothrow @safe @nogc // TODO needs @nogc here
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: return setSub(alloc, curr.as!(SparseBranch*), subIx, subNode);
		case ix_DenseBranchPtr: return setSub(curr.as!(DenseBranch*), subIx, subNode);
		case undefined:
			assert(false);
		}
	}

	/** Get sub-`Node` of branch `Node curr` at index `subIx`. */
	Node getSub(Branch curr, UIx subIx) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: return getSub(curr.as!(SparseBranch*), subIx);
		case ix_DenseBranchPtr: return getSub(curr.as!(DenseBranch*), subIx);
		case undefined:
			assert(false);
		}
	}
	/// ditto
	Node getSub(SparseBranch* curr, UIx subIx) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		if (auto subNode = curr.subNodeAt(subIx))
			return subNode;
		return Node.init;
	}
	/// ditto
	Node getSub(DenseBranch* curr, UIx subIx) pure nothrow @safe @nogc
	{
		pragma(inline, true);
		auto sub = curr.subNodes[subIx];
		debug curr.subNodes[subIx] = Node.init; // zero it to prevent multiple references
		return sub;
	}

	/** Get leaves of node `curr`. */
	inout(Leaf1!Value) getLeaf1(inout Branch curr) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: return curr.as!(SparseBranch*).leaf1;
		case ix_DenseBranchPtr: return curr.as!(DenseBranch*).leaf1;
		case undefined:
			assert(false);
		}
	}

	/** Set direct leaves node of node `curr` to `leaf1`. */
	void setLeaf1(Branch curr, Leaf1!Value leaf1) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: curr.as!(SparseBranch*).leaf1 = leaf1; break;
		case ix_DenseBranchPtr: curr.as!(DenseBranch*).leaf1 = leaf1; break;
		case undefined:
			assert(false);
		}
	}

	/** Get prefix of node `curr`. */
	auto getPrefix(inout Branch curr) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: return curr.as!(SparseBranch*).prefix[];
		case ix_DenseBranchPtr: return curr.as!(DenseBranch*).prefix[];
		case undefined:
			assert(false);
		}
	}

	/** Set prefix of branch node `curr` to `prefix`. */
	void setPrefix(Branch curr, const Ix[] prefix) pure nothrow @safe @nogc
	{
		pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: curr.as!(SparseBranch*).prefix = typeof(curr.as!(SparseBranch*).prefix)(prefix); break;
		case ix_DenseBranchPtr: curr.as!(DenseBranch*).prefix = typeof(curr.as!(DenseBranch*).prefix)(prefix); break;
		case undefined:
			assert(false);
		}
	}

	/** Pop `n` from prefix. */
	void popFrontNPrefix(Branch curr, size_t n) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: curr.as!(SparseBranch*).prefix.popFrontN(n); break;
		case ix_DenseBranchPtr: curr.as!(DenseBranch*).prefix.popFrontN(n); break;
		case undefined:
			assert(false);
		}
	}

	/** Get number of sub-nodes of node `curr`. */
	SubCount getSubCount(inout Branch curr) pure nothrow @safe @nogc
	{
		version (LDC) pragma(inline, true);
		final switch (curr.typeIx) with (Branch.Ix)
		{
		case ix_SparseBranchPtr: return cast(typeof(return))curr.as!(SparseBranch*).subCount;
		case ix_DenseBranchPtr: return cast(typeof(return))curr.as!(DenseBranch*).subCount;
		case undefined:
			assert(false);
		}
	}

	static if (isValue)
	{
		pure nothrow @safe @nogc:

		/** Returns: `true` if `key` is stored under `curr`, `false` otherwise. */
		inout(Value*) containsAt(inout Leaf1!Value curr, UKey key)
		{
			version (LDC) pragma(inline, true);
			// debug if (willFail) { dbg("curr:", curr); }
			// debug if (willFail) { dbg("key:", key); }
			switch (curr.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				return null;
			case ix_SparseLeaf1Ptr: return key.length == 1 ? curr.as!(SparseLeaf1!Value*).contains(UIx(key[0])) : null;
			case ix_DenseLeaf1Ptr:  return key.length == 1 ? curr.as!(DenseLeaf1!Value*).contains(UIx(key[0])) : null;
			default: assert(false);
			}
		}

		/// ditto
		inout(Value*) containsAt(inout Node curr, UKey key) /* TODO: make @safe */ @trusted
		in(key.length)
		{
			// debug if (willFail) { dbg("key:", key); }
			import nxt.algorithm.searching : skipOver;
			switch (curr.typeIx) with (Node.Ix)
			{
			case undefined:
				return null;
			case ix_SparseLeaf1Ptr: return key.length == 1 ? curr.as!(SparseLeaf1!Value*).contains(UIx(key[0])) : null;
			case ix_DenseLeaf1Ptr:  return key.length == 1 ? curr.as!(DenseLeaf1!Value*).contains(UIx(key[0])) : null;
			case ix_SparseBranchPtr:
				auto curr_ = curr.as!(SparseBranch*);
				if (key.skipOver(curr_.prefix[]))
					return (key.length == 1 ?
							containsAt(curr_.leaf1, key) : // in leaf
							containsAt(curr_.subNodeAt(UIx(key[0])), key[1 .. $])); // recurse into branch tree
				return null;
			case ix_DenseBranchPtr:
				auto curr_ = curr.as!(DenseBranch*);
				if (key.skipOver(curr_.prefix[]))
					return (key.length == 1 ?
							containsAt(curr_.leaf1, key) : // in leaf
							containsAt(curr_.subNodes[UIx(key[0])], key[1 .. $])); // recurse into branch tree
				return null;
			default: assert(false);
			}
		}
	}
	else
	{
		pure nothrow @safe @nogc:
		const:

		/** Returns: `true` if `key` is stored under `curr`, `false` otherwise. */
		bool containsAt(Leaf1!Value curr, UKey key)
		{
			// debug if (willFail) { dbg("key:", key); }
			final switch (curr.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				return false;
			case ix_HeptLeaf1: return curr.as!(HeptLeaf1).contains(key);
			case ix_SparseLeaf1Ptr: return key.length == 1 && curr.as!(SparseLeaf1!Value*).contains(UIx(key[0]));
			case ix_DenseLeaf1Ptr:  return key.length == 1 && curr.as!(DenseLeaf1!Value*).contains(UIx(key[0]));
			}
		}
		/// ditto
		bool containsAt(Node curr, UKey key) /* TODO: make @safe */ @trusted
		in(key.length)
		{
			// debug if (willFail) { dbg("key:", key); }
			import nxt.algorithm.searching : skipOver;
			final switch (curr.typeIx) with (Node.Ix)
			{
			case undefined:
				return false;
			case ix_OneLeafMax7: return curr.as!(OneLeafMax7).contains(key);
			case ix_TwoLeaf3: return curr.as!(TwoLeaf3).contains(key);
			case ix_TriLeaf2: return curr.as!(TriLeaf2).contains(key);
			case ix_HeptLeaf1: return curr.as!(HeptLeaf1).contains(key);
			case ix_SparseLeaf1Ptr:
				return key.length == 1 && curr.as!(SparseLeaf1!Value*).contains(UIx(key[0]));
			case ix_DenseLeaf1Ptr:
				return key.length == 1 && curr.as!(DenseLeaf1!Value*).contains(UIx(key[0]));
			case ix_SparseBranchPtr:
				auto curr_ = curr.as!(SparseBranch*);
				return (key.skipOver(curr_.prefix) &&		// matching prefix
						(key.length == 1 ?
						 containsAt(curr_.leaf1, key) : // in leaf
						 containsAt(curr_.subNodeAt(UIx(key[0])), key[1 .. $]))); // recurse into branch tree
			case ix_DenseBranchPtr:
				auto curr_ = curr.as!(DenseBranch*);
				return (key.skipOver(curr_.prefix) &&		// matching prefix
						(key.length == 1 ?
						 containsAt(curr_.leaf1, key) : // in leaf
						 containsAt(curr_.subNodes[UIx(key[0])], key[1 .. $]))); // recurse into branch tree
			}
		}
	}

	inout(Node) prefixAt(inout Node curr, UKey keyPrefix, out UKey keyPrefixRest) /* TODO: make @safe */ @trusted pure nothrow @nogc
	{
		import nxt.algorithm.searching : startsWith;
		final switch (curr.typeIx) with (Node.Ix)
		{
		case undefined:
			return typeof(return).init; // terminate recursion
		case ix_OneLeafMax7:
			if (curr.as!(OneLeafMax7).key[].startsWith(keyPrefix)) { goto processHit; }
			break;
		case ix_TwoLeaf3:
			if (curr.as!(TwoLeaf3).keyLength >= keyPrefix.length) { goto processHit; }
			break;
		case ix_TriLeaf2:
			if (curr.as!(TriLeaf2).keyLength >= keyPrefix.length) { goto processHit; }
			break;
		case ix_HeptLeaf1:
			if (curr.as!(HeptLeaf1).keyLength >= keyPrefix.length) { goto processHit; }
			break;
		case ix_SparseLeaf1Ptr:
		case ix_DenseLeaf1Ptr:
			if (keyPrefix.length <= 1) { goto processHit; }
			break;
		case ix_SparseBranchPtr:
			auto curr_ = curr.as!(SparseBranch*);
			if (keyPrefix.startsWith(curr_.prefix[]))
			{
				immutable currPrefixLength = curr_.prefix.length;
				if (keyPrefix.length == currPrefixLength || // if no more prefix
					(curr_.leaf1 && // both leaf1
					 curr_.subCount)) // and sub-nodes
					goto processHit;
				else if (curr_.subCount == 0) // only leaf1
					return prefixAt(Node(curr_.leaf1),
									keyPrefix[currPrefixLength .. $],
									keyPrefixRest);
				else		// only sub-node(s)
					return prefixAt(curr_.subNodeAt(UIx(keyPrefix[currPrefixLength])),
									keyPrefix[currPrefixLength + 1 .. $],
									keyPrefixRest);
			}
			break;
		case ix_DenseBranchPtr:
			auto curr_ = curr.as!(DenseBranch*);
			if (keyPrefix.startsWith(curr_.prefix[]))
			{
				immutable currPrefixLength = curr_.prefix.length;
				if (keyPrefix.length == currPrefixLength || // if no more prefix
					(curr_.leaf1 && // both leaf1
					 curr_.subCount)) // and sub-nodes
					goto processHit;
				else if (curr_.subCount == 0) // only leaf1
					return prefixAt(Node(curr_.leaf1),
									keyPrefix[currPrefixLength .. $],
									keyPrefixRest);
				else		// only sub-node(s)
					return prefixAt(curr_.subNodes[UIx(keyPrefix[currPrefixLength])],
									keyPrefix[currPrefixLength + 1 .. $],
									keyPrefixRest);
			}
			break;
		}
		return typeof(return).init;
	processHit:
		keyPrefixRest = keyPrefix;
		return curr;
	}

	inout(Node) matchCommonPrefixAt(inout Node curr, UKey key, out UKey keyRest) /* TODO: make @safe */ @trusted pure nothrow @nogc
	{
		// dbg(curr.typeIx);
		import nxt.algorithm.searching : startsWith;
		final switch (curr.typeIx) with (Node.Ix)
		{
		case undefined:
			return typeof(return).init; // terminate recursion
		case ix_OneLeafMax7:
		case ix_TwoLeaf3:
		case ix_TriLeaf2:
		case ix_HeptLeaf1:
		case ix_SparseLeaf1Ptr:
		case ix_DenseLeaf1Ptr:
			goto processHit;
		case ix_SparseBranchPtr:
			auto curr_ = curr.as!(SparseBranch*);
			// dbg(key);
			// dbg(curr_.prefix[]);
			if (key.startsWith(curr_.prefix[]))
			{
				immutable currPrefixLength = curr_.prefix.length;
				if (key.length == currPrefixLength || // if no more prefix
					(curr_.leaf1 && // both leaf1
					 curr_.subCount)) // and sub-nodes
					goto processHit;
				else if (curr_.subCount == 0) // only leaf1
					return matchCommonPrefixAt(Node(curr_.leaf1),
											   key[currPrefixLength .. $],
											   keyRest);
				else if (curr_.subCount == 1) // only one sub node
					return matchCommonPrefixAt(curr_.subNodeAt(UIx(key[currPrefixLength])),
											   key[currPrefixLength + 1 .. $],
											   keyRest);
				else
					goto processHit;
			}
			break;
		case ix_DenseBranchPtr:
			auto curr_ = curr.as!(DenseBranch*);
			if (key.startsWith(curr_.prefix[]))
			{
				immutable currPrefixLength = curr_.prefix.length;
				if (key.length == currPrefixLength || // if no more prefix
					(curr_.leaf1 && // both leaf1
					 curr_.subCount)) // and sub-nodes
					goto processHit;
				else if (curr_.subCount == 0) // only leaf1
					return matchCommonPrefixAt(Node(curr_.leaf1),
											   key[currPrefixLength .. $],
											   keyRest);
				else if (curr_.subCount == 1) // only one sub node
					return matchCommonPrefixAt(curr_.subNodes[UIx(key[currPrefixLength])],
											   key[currPrefixLength + 1 .. $],
											   keyRest);
				else
					goto processHit;
			}
			break;
		}
		return typeof(return).init;
	processHit:
		keyRest = key;
		return curr;
	}

	size_t countHeapNodesAt(Node curr) pure nothrow @safe @nogc
	{
		size_t count = 0;
		final switch (curr.typeIx) with (Node.Ix)
		{
		case undefined:
			break;  // propagate undefined
		case ix_OneLeafMax7: break;
		case ix_TwoLeaf3: break;
		case ix_TriLeaf2: break;
		case ix_HeptLeaf1: break;
		case ix_SparseLeaf1Ptr:
		case ix_DenseLeaf1Ptr:
			++count;
			break;
		case ix_SparseBranchPtr:
			auto curr_ = curr.as!(SparseBranch*);
			++count;
			foreach (subNode; curr_.subNodeSlots[0 .. curr_.subCount])
				if (subNode)
					count += countHeapNodesAt(subNode);
			break;
		case ix_DenseBranchPtr:
			++count;
			auto curr_ = curr.as!(DenseBranch*);
			foreach (subNode; curr_.subNodes)
				if (subNode)
					count += countHeapNodesAt(subNode);
			break;
		}
		return count;
	}

	/** Returns a duplicate of this tree with root at `curr`.
		Shallowly duplicates the values in the map case.
	*/
	Leaf1!Value treedup(A)(Leaf1!Value curr, auto ref A alloc) @safe pure nothrow
	{
		final switch (curr.typeIx) with (Leaf1!Value.Ix)
		{
		case undefined:		 // propagate undefined
		case ix_HeptLeaf1: return curr; // value semantics so just copy
		case ix_SparseLeaf1Ptr: return typeof(return)(curr.as!(SparseLeaf1!Value*).dupAt(alloc));
		case ix_DenseLeaf1Ptr: return typeof(return)(curr.as!(DenseLeaf1!Value*).dupAt(alloc));
		}
	}

	/** Returns a duplicate of this tree with root at `curr`.
		Shallowly duplicates the values in the map case.
	*/
	Node treedup(A)(Node curr, auto ref A alloc) pure nothrow @safe @nogc
	{
		final switch (curr.typeIx) with (Node.Ix)
		{
		case undefined:		 // propagate undefined
		case ix_OneLeafMax7:
		case ix_TwoLeaf3:
		case ix_TriLeaf2:
		case ix_HeptLeaf1: return curr; // value semantics so just copy
		case ix_SparseLeaf1Ptr: return typeof(return)(curr.as!(SparseLeaf1!Value*).dupAt(alloc));
		case ix_DenseLeaf1Ptr: return typeof(return)(curr.as!(DenseLeaf1!Value*).dupAt(alloc));
		case ix_SparseBranchPtr: return typeof(return)(curr.as!(SparseBranch*).dupAt(alloc));
		case ix_DenseBranchPtr: return typeof(return)(curr.as!(DenseBranch*).dupAt(alloc));
		}
	}

	static if (!isValue)
	{
		Node insertNew(A)(auto ref A alloc, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			Node next;
			// debug if (willFail) { dbg("WILL FAIL: key:", key); }
			switch (key.length)
			{
			case 0: assert(false, "key must not be empty"); // return elementRef = Node(makeFixedSizeNode!(OneLeafMax7)());
			case 1: next = Node(makeFixedSizeNodeValue!(HeptLeaf1)(key[0])); break;
			case 2: next = Node(makeFixedSizeNodeValue!(TriLeaf2)(key)); break;
			case 3: next = Node(makeFixedSizeNodeValue!(TwoLeaf3)(key)); break;
			default:
				if (key.length <= OneLeafMax7.capacity)
				{
					next = Node(makeFixedSizeNodeValue!(OneLeafMax7)(key));
					break;
				}
				else				// key doesn't fit in a `OneLeafMax7`
					return Node(insertNewBranch(alloc, key, elementRef));
			}
			elementRef = ElementRef(next,
									UIx(0), // always first index
									ModStatus.added);
			return next;
		}
	}

	Branch insertNewBranch(A)(auto ref A alloc, Elt!Value elt, out ElementRef elementRef) pure nothrow @safe @nogc
	{
		// debug if (willFail) { dbg("WILL FAIL: elt:", elt); }
		auto key = eltKey!Value(elt);
		assert(key.length);
		immutable prefixLength = min(key.length - 1, // all but last Ix of key
								 DefaultBranch.prefixCapacity); // as much as possible of key in branch prefix
		auto prefix = key[0 .. prefixLength];
		typeof(return) next = insertAtBelowPrefix(alloc,
												  Branch(makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1, prefix)),
												  eltKeyDropExactly!Value(elt, prefixLength), elementRef);
		assert(elementRef);
		return next;
	}

	/** Insert `key` into sub-tree under root `curr`. */
	Node insertAt(A)(auto ref A alloc, Node curr, Elt!Value elt, out ElementRef elementRef) pure nothrow @safe @nogc
	{
		auto key = eltKey!Value(elt);
		// debug if (willFail) { dbg("WILL FAIL: key:", key, " curr:", curr); }
		assert(key.length);

		if (!curr)		  // if no existing `Node` to insert at
		{
			static if (isValue)
				auto next = Node(insertNewBranch(alloc, elt, elementRef));
			else
				auto next = insertNew(alloc, key, elementRef);
			assert(elementRef); // must be added to new Node
			return next;
		}
		else
		{
			final switch (curr.typeIx) with (Node.Ix)
			{
			case undefined:
				return typeof(return).init;
			case ix_OneLeafMax7:
				static if (isValue)
					assert(false);
				else
					return insertAt(alloc, curr.as!(OneLeafMax7), key, elementRef);
			case ix_TwoLeaf3:
				static if (isValue)
					assert(false);
				else
					return insertAt(alloc, curr.as!(TwoLeaf3), key, elementRef);
			case ix_TriLeaf2:
				static if (isValue)
					assert(false);
				else
					return insertAt(alloc, curr.as!(TriLeaf2), key, elementRef);
			case ix_HeptLeaf1:
				static if (isValue)
					assert(false);
				else
					return insertAt(alloc, curr.as!(HeptLeaf1), key, elementRef);
			case ix_SparseLeaf1Ptr:
				return insertAtLeaf(alloc, Leaf1!Value(curr.as!(SparseLeaf1!Value*)), elt, elementRef); /+ TODO: use toLeaf(curr) +/
			case ix_DenseLeaf1Ptr:
				return insertAtLeaf(alloc, Leaf1!Value(curr.as!(DenseLeaf1!Value*)), elt, elementRef); /+ TODO: use toLeaf(curr) +/
			case ix_SparseBranchPtr:
				// debug if (willFail) { dbg("WILL FAIL: currPrefix:", curr.as!(SparseBranch*).prefix); }
				return Node(insertAtAbovePrefix(alloc, Branch(curr.as!(SparseBranch*)), elt, elementRef));
			case ix_DenseBranchPtr:
				return Node(insertAtAbovePrefix(alloc, Branch(curr.as!(DenseBranch*)), elt, elementRef));
			}
		}
	}

	/** Insert `key` into sub-tree under branch `curr` above prefix, that is
		the prefix of `curr` is stripped from `key` prior to insertion. */
	Branch insertAtAbovePrefix(A)(auto ref A alloc, Branch curr, Elt!Value elt, out ElementRef elementRef) pure nothrow @safe @nogc
	{
		auto key = eltKey!Value(elt);
		assert(key.length);

		import std.algorithm.searching : commonPrefix;
		auto currPrefix = getPrefix(curr);
		auto matchedKeyPrefix = commonPrefix(key, currPrefix);

		// debug if (willFail) { dbg("WILL FAIL: key:", key,
		//					 " curr:", curr,
		//					 " currPrefix:", getPrefix(curr),
		//					 " matchedKeyPrefix:", matchedKeyPrefix); }

		if (matchedKeyPrefix.length == 0) // no prefix key match
		{
			if (currPrefix.length == 0) // no current prefix
			{
				// debug if (willFail) { dbg("WILL FAIL"); }
				// NOTE: prefix:"", key:"cd"
				return insertAtBelowPrefix(alloc, curr, elt, elementRef);
			}
			else  // if (currPrefix.length != 0) // non-empty current prefix
			{
				// NOTE: prefix:"ab", key:"cd"
				immutable currSubIx = UIx(currPrefix[0]); // subIx = 'a'
				if (currPrefix.length == 1 && getSubCount(curr) == 0) // if `curr`-prefix become empty and only leaf pointer
				{
					// debug if (willFail) { dbg("WILL FAIL"); }
					popFrontNPrefix(curr, 1);
					curr = setSub(alloc, curr, currSubIx, Node(getLeaf1(curr))); // move it to sub
					setLeaf1(curr, Leaf1!Value.init);

					return insertAtBelowPrefix(alloc, curr, elt, elementRef); // directly call below because `curr`-prefix is now empty
				}
				else
				{
					// debug if (willFail) { dbg("WILL FAIL"); }
					popFrontNPrefix(curr, 1);
					auto next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 2, null, IxSub(currSubIx, Node(curr)));
					return insertAtAbovePrefix(alloc, Branch(next), elt, elementRef);
				}
			}
		}
		else if (matchedKeyPrefix.length < key.length)
		{
			if (matchedKeyPrefix.length == currPrefix.length)
			{
				// debug if (willFail) { dbg("WILL FAIL"); }
				// NOTE: key is an extension of prefix: prefix:"ab", key:"abcd"
				return insertAtBelowPrefix(alloc, curr, eltKeyDropExactly!Value(elt, currPrefix.length), elementRef);
			}
			else
			{
				// debug if (willFail) { dbg("WILL FAIL"); }
				// NOTE: prefix and key share beginning: prefix:"ab11", key:"ab22"
				immutable currSubIx = UIx(currPrefix[matchedKeyPrefix.length]); // need index first before we modify curr.prefix
				popFrontNPrefix(curr, matchedKeyPrefix.length + 1);
				auto next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 2, matchedKeyPrefix, IxSub(currSubIx, Node(curr)));
				return insertAtBelowPrefix(alloc, Branch(next), eltKeyDropExactly!Value(elt, matchedKeyPrefix.length), elementRef);
			}
		}
		else // if (matchedKeyPrefix.length == key.length)
		{
			// debug if (willFail) { dbg("WILL FAIL"); }
			assert(matchedKeyPrefix.length == key.length);
			if (matchedKeyPrefix.length < currPrefix.length)
			{
				// NOTE: prefix is an extension of key: prefix:"abcd", key:"ab"
				assert(matchedKeyPrefix.length);
				immutable nextPrefixLength = matchedKeyPrefix.length - 1;
				immutable currSubIx = UIx(currPrefix[nextPrefixLength]); // need index first
				popFrontNPrefix(curr, matchedKeyPrefix.length); // drop matchedKeyPrefix plus index to next super branch
				auto next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 2, matchedKeyPrefix[0 .. $ - 1], IxSub(currSubIx, Node(curr)));
				return insertAtBelowPrefix(alloc, Branch(next), eltKeyDropExactly!Value(elt, nextPrefixLength), elementRef);
			}
			else /* if (matchedKeyPrefix.length == currPrefix.length) and in turn
					if (key.length == currPrefix.length */
			{
				// NOTE: prefix equals key: prefix:"abcd", key:"abcd"
				assert(matchedKeyPrefix.length);
				immutable currSubIx = UIx(currPrefix[matchedKeyPrefix.length - 1]); // need index first
				popFrontNPrefix(curr, matchedKeyPrefix.length); // drop matchedKeyPrefix plus index to next super branch
				auto next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 2, matchedKeyPrefix[0 .. $ - 1], IxSub(currSubIx, Node(curr)));
				static if (isValue)
					return insertAtLeaf1(alloc, Branch(next), UIx(key[$ - 1]), elt.value, elementRef);
				else
					return insertAtLeaf1(alloc, Branch(next), UIx(key[$ - 1]), elementRef);
			}
		}
	}

	/** Like `insertAtAbovePrefix` but also asserts that `key` is
		currently not stored under `curr`. */
	pragma(inline) Branch insertNewAtAbovePrefix(A)(auto ref A alloc, Branch curr, Elt!Value elt) pure nothrow @safe @nogc
	{
		ElementRef elementRef;
		auto next = insertAtAbovePrefix(alloc, curr, elt, elementRef);
		assert(elementRef);
		return next;
	}

	static if (isValue)
	{
		pragma(inline) Branch insertAtSubNode(A)(auto ref A alloc, Branch curr, UKey key, Value value, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			// debug if (willFail) { dbg("WILL FAIL"); }
			immutable subIx = UIx(key[0]);
			return setSub(alloc, curr, subIx,
						  insertAt(alloc,
								   getSub(curr, subIx), // recurse
								   Elt!Value(key[1 .. $], value),
								   elementRef));
		}
	}
	else
	{
		pragma(inline) Branch insertAtSubNode(A)(auto ref A alloc, Branch curr, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			// debug if (willFail) { dbg("WILL FAIL"); }
			immutable subIx = UIx(key[0]);
			return setSub(alloc, curr, subIx,
						  insertAt(alloc, getSub(curr, subIx), // recurse
								   key[1 .. $],
								   elementRef));
		}
	}

	/** Insert `key` into sub-tree under branch `curr` below prefix, that is
		the prefix of `curr` is not stripped from `key` prior to
		insertion. */
	Branch insertAtBelowPrefix(A)(auto ref A alloc, Branch curr, Elt!Value elt, out ElementRef elementRef) pure nothrow @safe @nogc
	{
		auto key = eltKey!Value(elt);
		assert(key.length);
		// debug if (willFail) { dbg("WILL FAIL: key:", key,
		//						   " curr:", curr,
		//						   " currPrefix:", getPrefix(curr),
		//						   " elementRef:", elementRef); }
		if (key.length == 1)
		{
			static if (isValue)
				return insertAtLeaf1(alloc, curr, UIx(key[0]), elt.value, elementRef);
			else
				return insertAtLeaf1(alloc, curr, UIx(key[0]), elementRef);
		}
		else				// key.length >= 2
		{
			static if (isValue)
				return insertAtSubNode(alloc, curr, key, elt.value, elementRef);
			else
				return insertAtSubNode(alloc, curr, key, elementRef);
		}
	}

	Branch insertNewAtBelowPrefix(A)(auto ref A alloc, Branch curr, Elt!Value elt) pure nothrow @safe @nogc
	{
		ElementRef elementRef;
		auto next = insertAtBelowPrefix(alloc, curr, elt, elementRef);
		assert(elementRef);
		return next;
	}

	Leaf1!Value insertIxAtLeaftoLeaf(A)(auto ref A alloc,
												Leaf1!Value curr,
												IxElt!Value elt,
												out ElementRef elementRef) pure nothrow @safe @nogc
	{
		auto key = eltIx!Value(elt);
		// debug if (willFail) { dbg("WILL FAIL: elt:", elt,
		//						   " curr:", curr,
		//						   " elementRef:", elementRef); }
		switch (curr.typeIx) with (Leaf1!Value.Ix)
		{
		case undefined:
			return typeof(return).init;
		case ix_HeptLeaf1:
			static if (isValue)
				assert(false);
			else
				return insertAt(alloc, curr.as!(HeptLeaf1), key, elementRef); // possibly expanded to other Leaf1!Value
		case ix_SparseLeaf1Ptr:
			SparseLeaf1!Value* curr_ = curr.as!(SparseLeaf1!Value*);
			size_t index;
			ModStatus modStatus;
			curr_ = curr_.reconstructingInsert(alloc, elt, modStatus, index);
			curr = Leaf1!Value(curr_);
			final switch (modStatus)
			{
			case ModStatus.unchanged: // already stored at `index`
				elementRef = ElementRef(Node(curr_), UIx(index), modStatus);
				return curr;
			case ModStatus.added:
				elementRef = ElementRef(Node(curr_), UIx(index), modStatus);
				return curr;
			case ModStatus.maxCapacityReached:
				auto next = insertIxAtLeaftoLeaf(alloc,
												 expand(alloc, curr_, 1), // make room for one more
												 elt, elementRef);
				assert(next.peek!(DenseLeaf1!Value*));
				return next;
			case ModStatus.updated:
				elementRef = ElementRef(Node(curr_), UIx(index), modStatus);
				return curr;
			}
		case ix_DenseLeaf1Ptr:
			immutable modStatus = curr.as!(DenseLeaf1!Value*).insert(elt);
			static if (isValue)
				immutable ix = elt.ix;
			else
				immutable ix = elt;
			elementRef = ElementRef(Node(curr), ix, modStatus);
			break;
		default:
			assert(false, "Unsupported Leaf1!Value type " // ~ curr.typeIx.to!string
				);
		}
		return curr;
	}

	static if (isValue)
	{
		Branch insertAtLeaf1(A)(auto ref A alloc, Branch curr, UIx key, Value value, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			// debug if (willFail) { dbg("WILL FAIL: key:", key,
			//						   " value:", value,
			//						   " curr:", curr,
			//						   " currPrefix:", getPrefix(curr),
			//						   " elementRef:", elementRef); }
			if (auto leaf = getLeaf1(curr))
				setLeaf1(curr, insertIxAtLeaftoLeaf(alloc, leaf, IxElt!Value(key, value), elementRef));
			else
			{
				Ix[1] ixs = [Ix(key)]; /+ TODO: scope +/
				Value[1] values = [value]; /+ TODO: scope +/
				auto leaf_ = makeVariableSizeNodePointer!(SparseLeaf1!Value)(alloc, 1, ixs, values); // needed for values
				elementRef = ElementRef(Node(leaf_), UIx(0), ModStatus.added);
				setLeaf1(curr, Leaf1!Value(leaf_));
			}
			return curr;
		}
	}
	else
	{
		Branch insertAtLeaf1(A)(auto ref A alloc, Branch curr, UIx key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			// debug if (willFail) { dbg("WILL FAIL: key:", key,
			//						   " curr:", curr,
			//						   " currPrefix:", getPrefix(curr),
			//						   " elementRef:", elementRef); }
			if (auto leaf = getLeaf1(curr))
				setLeaf1(curr, insertIxAtLeaftoLeaf(alloc, leaf, key, elementRef));
			else
			{
				auto leaf_ = makeFixedSizeNodeValue!(HeptLeaf1)(key); // can pack more efficiently when no value
				elementRef = ElementRef(Node(leaf_), UIx(0), ModStatus.added);
				setLeaf1(curr, Leaf1!Value(leaf_));
			}
			return curr;
		}
	}

	Node insertAtLeaf(A)(auto ref A alloc, Leaf1!Value curr, Elt!Value elt, out ElementRef elementRef) pure nothrow @safe @nogc
	{
		// debug if (willFail) { dbg("WILL FAIL: elt:", elt); }
		auto key = eltKey!Value(elt);
		assert(key.length);
		if (key.length == 1)
		{
			static if (isValue)
				return Node(insertIxAtLeaftoLeaf(alloc, curr, IxElt!Value(UIx(key[0]), elt.value), elementRef));
			else
				return Node(insertIxAtLeaftoLeaf(alloc, curr, UIx(key[0]), elementRef));
		}
		else
		{
			assert(key.length >= 2);
			immutable prefixLength = key.length - 2; // >= 0
			const nextPrefix = key[0 .. prefixLength];
			auto next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1, nextPrefix, curr); // one sub-node and one leaf
			return Node(insertAtBelowPrefix(alloc, Branch(next), eltKeyDropExactly!Value(elt, prefixLength), elementRef));
		}
	}

	static if (!isValue)
	{
		Node insertAt(A)(auto ref A alloc, OneLeafMax7 curr, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			assert(curr.key.length);
			// debug if (willFail) { dbg("WILL FAIL: key:", key, " curr.key:", curr.key); }

			import std.algorithm.searching : commonPrefix;
			auto matchedKeyPrefix = commonPrefix(key, curr.key);
			if (curr.key.length == key.length)
			{
				if (matchedKeyPrefix.length == key.length) // curr.key, key and matchedKeyPrefix all equal
					return Node(curr); // already stored in `curr`
				else if (matchedKeyPrefix.length + 1 == key.length) // key and curr.key are both matchedKeyPrefix plus one extra
				{
					/+ TODO: functionize: +/
					Node next;
					switch (matchedKeyPrefix.length)
					{
					case 0:
						next = makeFixedSizeNodeValue!(HeptLeaf1)(curr.key[0], key[0]);
						elementRef = ElementRef(next, UIx(1), ModStatus.added);
						break;
					case 1:
						next = makeFixedSizeNodeValue!(TriLeaf2)(curr.key, key);
						elementRef = ElementRef(next, UIx(1), ModStatus.added);
						break;
					case 2:
						next = makeFixedSizeNodeValue!(TwoLeaf3)(curr.key, key);
						elementRef = ElementRef(next, UIx(1), ModStatus.added);
						break;
					default:
						const nextPrefix = matchedKeyPrefix[0 .. min(matchedKeyPrefix.length,
																	 DefaultBranch.prefixCapacity)]; // limit prefix branch capacity
						Branch nextBranch = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + 1, // `curr` and `key`
																							nextPrefix);
						nextBranch = insertNewAtBelowPrefix(alloc, nextBranch, curr.key[nextPrefix.length .. $]);
						nextBranch = insertAtBelowPrefix(alloc, nextBranch, key[nextPrefix.length .. $], elementRef);
						assert(elementRef);
						next = Node(nextBranch);
						break;
					}
					freeNode(alloc, curr);
					return next;
				}
			}

			return Node(insertAtAbovePrefix(alloc, expand(alloc, curr), key, elementRef));
		}

		Node insertAt(A)(auto ref A alloc, TwoLeaf3 curr, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			if (curr.keyLength == key.length)
			{
				if (curr.contains(key))
					return Node(curr);
				if (!curr.keys.full)
				{
					assert(curr.keys.length == 1);
					elementRef = ElementRef(Node(curr), UIx(curr.keys.length), ModStatus.added);
					curr.keys.pushBack(key);
					return Node(curr);
				}
			}
			return Node(insertAtAbovePrefix(alloc, expand(alloc, curr), key, elementRef)); // NOTE stay at same (depth)
		}

		Node insertAt(A)(auto ref A alloc, TriLeaf2 curr, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			if (curr.keyLength == key.length)
			{
				if (curr.contains(key))
					return Node(curr);
				if (!curr.keys.full)
				{
					elementRef = ElementRef(Node(curr), UIx(curr.keys.length), ModStatus.added);
					curr.keys.pushBack(key);
					return Node(curr);
				}
			}
			return Node(insertAtAbovePrefix(alloc, expand(alloc, curr), key, elementRef)); // NOTE stay at same (depth)
		}

		Leaf1!Value insertAt(A)(auto ref A alloc, HeptLeaf1 curr, UIx key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			if (curr.contains(key))
				return Leaf1!Value(curr);
			if (!curr.keys.full)
			{
				elementRef = ElementRef(Node(curr), UIx(curr.keys.back), ModStatus.added);
				curr.keys.pushBack(cast(Ix)key);
				return Leaf1!Value(curr);
			}
			else			// curr is full
			{
				assert(curr.keys.length == curr.capacity);

				// pack `curr.keys` plus `key` into `nextKeys`
				Ix[curr.capacity + 1] nextKeys;
				nextKeys[0 .. curr.capacity] = curr.keys;
				nextKeys[curr.capacity] = cast(Ix)key;

				import std.algorithm.sorting : sort;
				sort(nextKeys[]); /+ TODO: move this sorting elsewhere +/

				auto next = makeVariableSizeNodePointer!(SparseLeaf1!Value)(alloc, nextKeys.length, nextKeys[]);
				elementRef = ElementRef(Node(next), UIx(curr.capacity), ModStatus.added);

				freeNode(alloc, curr);
				return Leaf1!Value(next);
			}
		}

		Node insertAt(A)(auto ref A alloc, HeptLeaf1 curr, UKey key, out ElementRef elementRef) pure nothrow @safe @nogc
		{
			if (curr.keyLength == key.length)
				return Node(insertAt(alloc, curr, UIx(key[0]), elementRef)); // use `Ix key`-overload
			return insertAt(alloc, Node(makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1, Leaf1!Value(curr))), // current `key`
							key, elementRef); // NOTE stay at same (depth)
		}

		/** Split `curr` using `prefix`. */
		Node split(A)(auto ref A alloc, OneLeafMax7 curr, UKey prefix, UKey key) /+ TODO: key here is a bit malplaced +/
			pure nothrow @safe @nogc
		{
			assert(key.length);

			if (curr.key.length == key.length) // balanced tree possible
			{
				switch (curr.key.length)
				{
				case 1:
					if (prefix.length == 0)
					{
						freeNode(alloc, curr);
						return Node(makeFixedSizeNodeValue!(HeptLeaf1)(curr.key)); /+ TODO: removing parameter has no effect. why? +/
					}
					break;
				case 2:
					freeNode(alloc, curr);
					return Node(makeFixedSizeNodeValue!(TriLeaf2)(curr.key));
				case 3:
					freeNode(alloc, curr);
					return Node(makeFixedSizeNodeValue!(TwoLeaf3)(curr.key));
				default:
					break;
				}
			}

			// default case
			Branch next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + 1, prefix); // current plus one more
			next = insertNewAtBelowPrefix(alloc, next, curr.key[prefix.length .. $]);
			freeNode(alloc, curr);   // remove old current

			return Node(next);
		}

		/** Destructively expand `curr` to make room for `capacityIncrement` more keys and return it. */
		Branch expand(A)(auto ref A alloc, OneLeafMax7 curr, in size_t capacityIncrement = 1) pure nothrow @safe @nogc
		{
			assert(curr.key.length >= 2);
			typeof(return) next;

			if (curr.key.length <= DefaultBranch.prefixCapacity + 1) // if `key` fits in `prefix` of `DefaultBranch`
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + capacityIncrement, curr.key[0 .. $ - 1], // all but last
															Leaf1!Value(makeFixedSizeNodeValue!(HeptLeaf1)(curr.key.back))); // last as a leaf
			}
			else				// curr.key.length > DefaultBranch.prefixCapacity + 1
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + capacityIncrement, curr.key[0 .. DefaultBranch.prefixCapacity]);
				next = insertNewAtBelowPrefix(alloc, next, curr.key[DefaultBranch.prefixCapacity .. $]);
			}

			freeNode(alloc, curr);
			return next;
		}

		/** Destructively expand `curr` to make room for `capacityIncrement` more keys and return it. */
		Branch expand(A)(auto ref A alloc, TwoLeaf3 curr, in size_t capacityIncrement = 1)
			pure nothrow @safe @nogc
		{
			typeof(return) next;
			if (curr.keys.length == 1) // only one key
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + capacityIncrement);
				next = insertNewAtAbovePrefix(alloc, next, // current keys plus one more
											  curr.keys.at!0);
			}
			else
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, curr.keys.length + capacityIncrement, curr.prefix);
				/+ TODO: functionize and optimize to insertNewAtAbovePrefix(next, curr.keys) +/
				foreach (key; curr.keys)
					next = insertNewAtBelowPrefix(alloc, next, key[curr.prefix.length .. $]);
			}
			freeNode(alloc, curr);
			return next;
		}

		/** Destructively expand `curr` to make room for `capacityIncrement` more keys and return it. */
		Branch expand(A)(auto ref A alloc, TriLeaf2 curr, in size_t capacityIncrement = 1) pure nothrow @safe @nogc
		{
			typeof(return) next;
			if (curr.keys.length == 1) // only one key
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, 1 + capacityIncrement); // current keys plus one more
				next = insertNewAtAbovePrefix(alloc, next, curr.keys.at!0);
			}
			else
			{
				next = makeVariableSizeNodePointer!(DefaultBranch)(alloc, curr.keys.length + capacityIncrement, curr.prefix);
				/+ TODO: functionize and optimize to insertNewAtAbovePrefix(next, curr.keys) +/
				foreach (key; curr.keys)
					next = insertNewAtBelowPrefix(alloc, next, key[curr.prefix.length .. $]);
			}
			freeNode(alloc, curr);
			return next;
		}

		/** Destructively expand `curr` making room for `nextKey` and return it. */
		Node expand(A)(auto ref A alloc, HeptLeaf1 curr, in size_t capacityIncrement = 1)
		{
			auto next = makeVariableSizeNodePointer!(SparseLeaf1!Value)(alloc, curr.keys.length + capacityIncrement, curr.keys);
			freeNode(alloc, curr);
			return Node(next);
		}
	}

	pure nothrow @safe @nogc
	{
		pragma(inline, true) void release(A)(auto ref A alloc, SparseLeaf1!Value* curr) { freeNode(alloc, curr); }
		pragma(inline, true) void release(A)(auto ref A alloc, DenseLeaf1!Value* curr) { freeNode(alloc, curr); }

		void release(A)(auto ref A alloc, SparseBranch* curr)
		{
			foreach (immutable sub; curr.subNodes[0 .. curr.subCount])
				release(alloc, sub); // recurse branch
			if (curr.leaf1)
				release(alloc, curr.leaf1); // recurse leaf
			freeNode(alloc, curr);
		}

		void release(A)(auto ref A alloc, DenseBranch* curr)
		{
			import std.algorithm.iteration : filter;
			foreach (immutable sub; curr.subNodes[].filter!(sub => sub)) /+ TODO: use static foreach +/
				release(alloc, sub); // recurse branch
			if (curr.leaf1)
				release(alloc, curr.leaf1); // recurse leaf
			freeNode(alloc, curr);
		}

		pragma(inline, true) void release(A)(auto ref A alloc, OneLeafMax7 curr) { freeNode(alloc, curr); }
		pragma(inline, true) void release(A)(auto ref A alloc, TwoLeaf3 curr) { freeNode(alloc, curr); }
		pragma(inline, true) void release(A)(auto ref A alloc, TriLeaf2 curr) { freeNode(alloc, curr); }
		pragma(inline, true) void release(A)(auto ref A alloc, HeptLeaf1 curr) { freeNode(alloc, curr); }

		/** Release `Leaf1!Value curr`. */
		void release(A)(auto ref A alloc, Leaf1!Value curr)
		{
			final switch (curr.typeIx) with (Leaf1!Value.Ix)
			{
			case undefined:
				break; // ignored
			case ix_HeptLeaf1: return release(alloc, curr.as!(HeptLeaf1));
			case ix_SparseLeaf1Ptr: return release(alloc, curr.as!(SparseLeaf1!Value*));
			case ix_DenseLeaf1Ptr: return release(alloc, curr.as!(DenseLeaf1!Value*));
			}
		}

		/** Release `Node curr`. */
		void release(A)(auto ref A alloc, Node curr)
		{
			final switch (curr.typeIx) with (Node.Ix)
			{
			case undefined:
				break; // ignored
			case ix_OneLeafMax7: return release(alloc, curr.as!(OneLeafMax7));
			case ix_TwoLeaf3: return release(alloc, curr.as!(TwoLeaf3));
			case ix_TriLeaf2: return release(alloc, curr.as!(TriLeaf2));
			case ix_HeptLeaf1: return release(alloc, curr.as!(HeptLeaf1));
			case ix_SparseLeaf1Ptr: return release(alloc, curr.as!(SparseLeaf1!Value*));
			case ix_DenseLeaf1Ptr: return release(alloc, curr.as!(DenseLeaf1!Value*));
			case ix_SparseBranchPtr: return release(alloc, curr.as!(SparseBranch*));
			case ix_DenseBranchPtr: return release(alloc, curr.as!(DenseBranch*));
			}
		}

		bool isHeapAllocatedNode(const Node curr)
		{
			final switch (curr.typeIx) with (Node.Ix)
			{
			case undefined:
				return false;
			case ix_OneLeafMax7: return false;
			case ix_TwoLeaf3: return false;
			case ix_TriLeaf2: return false;
			case ix_HeptLeaf1: return false;
			case ix_SparseLeaf1Ptr: return true;
			case ix_DenseLeaf1Ptr: return true;
			case ix_SparseBranchPtr: return true;
			case ix_DenseBranchPtr: return true;
			}
		}
	}

	void printAt(Node curr, size_t depth, uint subIx = uint.max) @safe
	{
		import std.range : repeat;
		import std.stdio : write, writeln;
		import std.string : format;

		if (!curr)
			return;

		foreach (immutable i; 0 .. depth)
			write('-');		 // prefix

		if (subIx != uint.max)
			write(format("%.2X ", subIx));

		final switch (curr.typeIx) with (Node.Ix)
		{
		case undefined:
			assert(false, "Trying to print Node.undefined");
		case ix_OneLeafMax7:
			auto curr_ = curr.as!(OneLeafMax7);
			import std.conv : to;
			writeln(typeof(curr_).stringof, " #", curr_.key.length, ": ", curr_.to!string);
			break;
		case ix_TwoLeaf3:
			auto curr_ = curr.as!(TwoLeaf3);
			writeln(typeof(curr_).stringof, " #", curr_.keys.length, ": ", curr_.keys);
			break;
		case ix_TriLeaf2:
			auto curr_ = curr.as!(TriLeaf2);
			writeln(typeof(curr_).stringof, " #", curr_.keys.length, ": ", curr_.keys);
			break;
		case ix_HeptLeaf1:
			auto curr_ = curr.as!(HeptLeaf1);
			writeln(typeof(curr_).stringof, " #", curr_.keys.length, ": ", curr_.keys);
			break;
		case ix_SparseLeaf1Ptr:
			auto curr_ = curr.as!(SparseLeaf1!Value*);
			write(typeof(*curr_).stringof, " #", curr_.length, "/", curr_.capacity, " @", curr_);
			write(": ");
			bool other = false;
			foreach (immutable i, immutable ix; curr_.ixs)
			{
				string s;
				if (other)
					s ~= keySeparator;
				else
					other = true;
				import std.string : format;
				s ~= format("%.2X", ix);
				write(s);
				static if (isValue)
					write("=>", curr_.values[i]);
			}
			writeln();
			break;
		case ix_DenseLeaf1Ptr:
			auto curr_ = curr.as!(DenseLeaf1!Value*);
			write(typeof(*curr_).stringof, " #", curr_.count, " @", curr_);
			write(": ");

			// keys
			size_t ix = 0;
			bool other = false;
			if (curr_._ixBits.allOne)
				write("ALL");
			else
			{
				foreach (immutable keyBit; curr_._ixBits[])
				{
					string s;
					if (keyBit)
					{
						if (other)
							s ~= keySeparator;
						else
							other = true;
						import std.string : format;
						s ~= format("%.2X", ix);
					}
					write(s);
					static if (isValue)
						write("=>", curr_.values[ix]);
					++ix;
				}
			}

			writeln();
			break;
		case ix_SparseBranchPtr:
			auto curr_ = curr.as!(SparseBranch*);
			write(typeof(*curr_).stringof, " #", curr_.subCount, "/", curr_.subCapacity, " @", curr_);
			if (!curr_.prefix.empty)
				write(" prefix=", curr_.prefix.toString('_'));
			writeln(":");
			if (curr_.leaf1)
				printAt(Node(curr_.leaf1), depth + 1);
			foreach (immutable i, immutable subNode; curr_.subNodes)
				printAt(subNode, depth + 1, cast(uint)curr_.subIxs[i]);
			break;
		case ix_DenseBranchPtr:
			auto curr_ = curr.as!(DenseBranch*);
			write(typeof(*curr_).stringof, " #", curr_.subCount, "/", radix, " @", curr_);
			if (!curr_.prefix.empty)
				write(" prefix=", curr_.prefix.toString('_'));
			writeln(":");
			if (curr_.leaf1)
				printAt(Node(curr_.leaf1), depth + 1);
			foreach (immutable i, immutable subNode; curr_.subNodes)
				printAt(subNode, depth + 1, cast(uint)i);

			break;
		}
	}

	struct RawRadixTree
	{
		import std.experimental.allocator.common : stateSize;
		alias NodeType = Node;
		alias BranchType = Branch;
		alias DefaultBranchType = DefaultBranch;
		alias ValueType = Value;
		alias RangeType = Range;
		alias StatsType = Stats;
		alias SparseBranchType = SparseBranch;
		alias DenseBranchType = DenseBranch;
		alias ElementRefType = ElementRef;

		/** Is `true` if this tree stores values of type `Value` along with keys. In
			other words: `this` is a $(I map) rather than a $(I set).
		*/
		alias hasValue = isValue;

		pragma(inline, true)
		Range opSlice() pure nothrow => Range(_root, []); /+ TODO: DIP-1000 scope +/

		/** Returns a duplicate of this tree if present.
			Shallowly duplicates the values in the map case.
		*/
		typeof(this) dup() @trusted
		{
			static if (stateSize!A_ != 0)
				return typeof(return)(treedup(_root, _alloc), length, _alloc);
			else
				return typeof(return)(treedup(_root, _alloc), length);
		}

		Stats usageHistograms() const
		{
			if (!_root)
				return typeof(return).init;
			typeof(return) stats;
			_root.appendStatsTo!(Value, A_)(stats);
			return stats;
		}

		static if (stateSize!A_ != 0)
		{
			this(A)(Node root, size_t length, auto ref A alloc) pure nothrow @safe @nogc
			in(alloc !is null)
			{
				static if (is(typeof(alloc !is null)))
					assert(alloc !is null);
				this._root = root;
				this._length = length;
				this._alloc = alloc;
			}

			this(A)(auto ref A alloc) pure nothrow @safe @nogc
			in(alloc !is null)
			{
				static if (is(typeof(alloc !is null)))
					assert(alloc !is null);
				this._alloc = alloc;
			}

			this() @disable; ///< No default construction if an allocator must be provided.
		}
		else
		{
			this(Node root, size_t length) pure nothrow @safe @nogc
			{
				static if (is(typeof(alloc !is null)))
					assert(alloc !is null);
				this._root = root;
				this._length = length;
			}
		}

		this(this) @disable;	// disable copy constructor

		~this() nothrow
		{
			release(_alloc, _root);
			debug _root = Node.init;
		}

		/** Removes all contents (elements). */
		void clear()
		{
			release(_alloc, _root);
			_root = null;
			_length = 0;
		}

		void print() @safe const => printAt(_root, 0);

		pure nothrow @safe @nogc:

		/** Insert `key` into `this` tree. */
		static if (isValue)
			Node insert(UKey key, Value value, out ElementRef elementRef) => _root = insertAt(_alloc, _root, Elt!Value(key, value), elementRef);
		else
			Node insert(UKey key, out ElementRef elementRef) => _root = insertAt(_alloc, _root, key, elementRef);

		pragma(inline, true):

		Node root() @property => _root;

		/** Returns: `true` if `key` is stored, `false` otherwise. */
		inout(Node) prefix(UKey keyPrefix, out UKey keyPrefixRest) inout => prefixAt(_root, keyPrefix, keyPrefixRest);

		/** Lookup deepest node having whose key starts with `key`. */
		inout(Node) matchCommonPrefix(UKey key, out UKey keyRest) inout => matchCommonPrefixAt(_root, key, keyRest);

		static if (isValue)
			/** Returns: `true` if `key` is stored, `false` otherwise. */
			inout(Value*) contains(UKey key) inout => containsAt(_root, key);
		else
			/** Returns: `true` if `key` is stored, `false` otherwise. */
			bool contains(UKey key) const => containsAt(_root, key);

		size_t countHeapNodes() => countHeapNodesAt(_root);

		/** Returns: `true` iff tree is empty (no elements stored). */
		bool empty() const @property => !_root;

		/** Returns: number of elements stored. */
		size_t length() const @property => _length;

		Node rootNode() @property const => _root;

	private:
		/** Returns: number of nodes used in `this` tree. Should always equal `Stats.heapNodeCount`. */
		// debug size_t heapAllocationBalance() { return _heapAllocBalance; }

	private:
		Node _root;
		size_t _length; /// Number of elements (keys or key-value-pairs) currently stored under `_root`
		static if (stateSize!A_ == 0)
			alias _alloc = A_.instance;
		else
			A_ _alloc;
	}
}

/** Append statistics of tree under `Node` `curr.` into `stats`.
 */
static private void appendStatsTo(Value, A)(RawRadixTree!(Value, A).NodeType curr,
													ref RawRadixTree!(Value, A).StatsType stats) // TODO make `StatsType` not depend on `A`
	@safe pure nothrow /* TODO: @nogc */
if (isAllocator!A)
{
	alias RT = RawRadixTree!(Value, A);
	++stats.popByNodeType[curr.typeIx];

	final switch (curr.typeIx) with (RT.NodeType.Ix)
	{
	case undefined:
		break;
	case ix_OneLeafMax7: break; /+ TODO: appendStatsTo() +/
	case ix_TwoLeaf3: break; /+ TODO: appendStatsTo() +/
	case ix_TriLeaf2: break; /+ TODO: appendStatsTo() +/
	case ix_HeptLeaf1: break; /+ TODO: appendStatsTo() +/
	case ix_SparseLeaf1Ptr:
		++stats.heapNodeCount;
		const curr_ = curr.as!(SparseLeaf1!Value*);
		assert(curr_.length);
		++stats.popHist_SparseLeaf1[curr_.length - 1]; /+ TODO: type-safe indexing +/
		stats.sparseLeaf1AllocatedSizeSum += curr_.allocatedSize;
		break;
	case ix_DenseLeaf1Ptr:
		const curr_ = curr.as!(DenseLeaf1!Value*);
		++stats.heapNodeCount;
		immutable count = curr_._ixBits.countOnes; // number of non-zero sub-nodes
		assert(count <= curr_.capacity);
		++stats.popHist_DenseLeaf1[count - 1]; /+ TODO: type-safe indexing +/
		break;
	case ix_SparseBranchPtr:
		++stats.heapNodeCount;
		curr.as!(RT.SparseBranchType*).appendStatsTo(stats);
		break;
	case ix_DenseBranchPtr:
		++stats.heapNodeCount;
		curr.as!(RT.DenseBranchType*).appendStatsTo(stats);
		break;
	}
}

/** Append statistics of tree under `Leaf1!Value` `curr.` into `stats`.
 */
static private void appendStatsTo(Value, A)(Leaf1!Value curr, ref RawRadixTree!(Value, A).StatsType stats)
pure nothrow @safe @nogc /* TODO: @nogc */
if (isAllocator!A)
{
	alias RT = RawRadixTree!(Value, A);
	++stats.popByLeaf1Type[curr.typeIx];

	final switch (curr.typeIx) with (Leaf1!Value.Ix)
	{
	case undefined:
		break;
	case ix_HeptLeaf1: break; /+ TODO: appendStatsTo() +/
	case ix_SparseLeaf1Ptr:
		++stats.heapNodeCount;
		const curr_ = curr.as!(SparseLeaf1!Value*);
		assert(curr_.length);
		++stats.popHist_SparseLeaf1[curr_.length - 1]; /+ TODO: type-safe indexing +/
		break;
	case ix_DenseLeaf1Ptr:
		const curr_ = curr.as!(DenseLeaf1!Value*);
		++stats.heapNodeCount;
		immutable count = curr_._ixBits.countOnes; // number of non-zero curr-nodes
		assert(count <= curr_.capacity);
		assert(count);
		++stats.popHist_DenseLeaf1[count - 1]; /+ TODO: type-safe indexing +/
		break;
	}
}

/** Remap fixed-length typed key `typedKey` to raw (untyped) key of type `UKey`.
	TODO: DIP-1000 scope
*/
UKey toFixedRawKey(TypedKey)(const scope TypedKey typedKey, UKey preallocatedFixedUKey) @trusted
{
	enum radix = 2^^span;	 // branch-multiplicity, typically either 2, 4, 16 or 256
	immutable key_ = typedKey.bijectToUnsigned;

	static assert(key_.sizeof == TypedKey.sizeof);

	enum nbits = 8*key_.sizeof; // number of bits in key
	enum chunkCount = nbits/span; // number of chunks in key_
	static assert(chunkCount*span == nbits, "Bitsize of TypedKey must be a multiple of span:" ~ span.stringof);

	// big-endian storage
	foreach (immutable i; 0 .. chunkCount) // for each chunk index
	{
		immutable bitShift = (chunkCount - 1 - i)*span; // most significant bit chunk first (MSBCF)
		preallocatedFixedUKey[i] = (key_ >> bitShift) & (radix - 1); // part of value which is also an index
	}

	return preallocatedFixedUKey[];
}

/** Remap typed key `typedKey` to raw (untyped) key of type `UKey`.
 */
UKey toRawKey(TypedKey)(in TypedKey typedKey, ref Ixs rawUKey) @trusted
if (isTrieableKeyType!TypedKey)
{
	import std.traits : isArray;
	enum radix = 2^^span;	 // branch-multiplicity, typically either 2, 4, 16 or 256

	import nxt.container.traits : isAddress;
	static if (isAddress!TypedKey)
		static assert(0, "Shift TypedKey " ~ TypedKey.stringof ~ " down by its alignment before returning");

	static if (isFixedTrieableKeyType!TypedKey)
	{
		rawUKey.length = TypedKey.sizeof;
		return typedKey.toFixedRawKey(rawUKey[]);
	}
	else static if (isArray!TypedKey)
	{
		alias EType = Unqual!(typeof(TypedKey.init[0]));
		static if (is(EType == char)) /+ TODO: extend to support isTrieableKeyType!TypedKey +/
		{
			import std.string : representation;
			const ubyte[] ukey = typedKey.representation; // lexical byte-order
			return cast(Ix[])ukey;						/+ TODO: needed? +/
		}
		else static if (is(EType == wchar))
		{
			immutable ushort[] rKey = typedKey.representation; // lexical byte-order.
			/+ TODO: MSByte-order of elements in rKey for ordered access and good branching performance +/
			immutable ubyte[] ukey = (cast(const ubyte*)rKey.ptr)[0 .. rKey[0].sizeof * rKey.length]; /+ TODO: @trusted functionize. Reuse existing Phobos function? +/
			return ukey;
		}
		else static if (is(EType == dchar))
		{
			immutable uint[] rKey = typedKey.representation; // lexical byte-order
			/+ TODO: MSByte-order of elements in rKey for ordered access and good branching performance +/
			immutable ubyte[] ukey = (cast(const ubyte*)rKey.ptr)[0 .. rKey[0].sizeof * rKey.length]; /+ TODO: @trusted functionize. Reuse existing Phobos function? +/
			return ukey;
		}
		else static if (isFixedTrieableKeyType!E)
		{
			static assert(false, "TODO: Convert array of typed fixed keys");
		}
		else
		{
			static assert(false, "TODO: Handle typed key " ~ TypedKey.stringof);
		}
	}
	else static if (is(TypedKey == struct))
	{
		static if (TypedKey.tupleof.length == 1) // TypedKey is a wrapper type
		{
			return typedKey.tupleof[0].toRawKey(rawUKey);
		}
		else
		{
			enum members = __traits(allMembers, TypedKey);
			foreach (immutable i, immutable memberName; members) // for each member name in `struct TypedKey`
			{
				immutable member = __traits(getMember, typedKey, memberName); // member
				alias MemberType = typeof(member);

				static if (i + 1 == members.length) // last member is allowed to be an array of fixed length
				{
					Ixs memberRawUKey;
					const memberRawKey = member.toRawKey(memberRawUKey); /+ TODO: DIP-1000 scope +/
					rawUKey ~= memberRawUKey;
				}
				else				// non-last member must be fixed
				{
					static assert(isFixedTrieableKeyType!MemberType,
								  "Non-last " ~ i.stringof ~ ":th member of type " ~ MemberType.stringof ~ " must be of fixed length");
					Ix[MemberType.sizeof] memberRawUKey;
					const memberRawKey = member.toFixedRawKey(memberRawUKey); /+ TODO: DIP-1000 scope +/
					rawUKey ~= memberRawUKey[];
				}
			}
			return rawUKey[]; /+ TODO: return immutable slice +/
		}
	}
	else
	{
		static assert(false, "TODO: Handle typed key " ~ TypedKey.stringof);
	}
}

/** Remap raw untyped key `ukey` to typed key of type `TypedKey`. */
inout(TypedKey) toTypedKey(TypedKey)(inout(Ix)[] ukey) @trusted
if (isTrieableKeyType!TypedKey)
{
	import std.traits : isArray;
	import nxt.container.traits : isAddress;
	static if (isAddress!TypedKey)
		static assert(0, "Shift TypedKey " ~ TypedKey.stringof ~ " up by its alignment before returning");

	static if (isFixedTrieableKeyType!TypedKey)
	{
		enum nbits = 8*TypedKey.sizeof; // number of bits in key
		enum chunkCount = nbits/span; // number of chunks in key_
		static assert(chunkCount*span == nbits, "Bitsize of TypedKey must be a multiple of span:" ~ span.stringof);

		/+ TODO: reuse existing trait UnsignedOf!TypedKey +/
		static	  if (TypedKey.sizeof == 1) { alias RawKey = ubyte; }
		else static if (TypedKey.sizeof == 2) { alias RawKey = ushort; }
		else static if (TypedKey.sizeof == 4) { alias RawKey = uint; }
		else static if (TypedKey.sizeof == 8) { alias RawKey = ulong; }

		RawKey bKey = 0;

		// big-endian storage
		foreach (immutable i; 0 .. chunkCount) // for each chunk index
		{
			immutable RawKey uix = cast(RawKey)ukey[i];
			immutable bitShift = (chunkCount - 1 - i)*span; // most significant bit chunk first (MSBCF)
			bKey |= uix << bitShift; // part of value which is also an index
		}

		TypedKey typedKey;
		bKey.bijectFromUnsigned(typedKey);
		return typedKey;
	}
	else static if (isArray!TypedKey)
	{
		static if (isArray!TypedKey &&
				   is(Unqual!(typeof(TypedKey.init[0])) == char))
		{
			static assert(char.sizeof == Ix.sizeof);
			return cast(inout(char)[])ukey;
		}
		/+ TODO: handle wchar and dchar +/
		else
		{
			static assert(false, "TODO: Handle typed key " ~ TypedKey.stringof);
		}
	}
	else static if (is(TypedKey == struct))
	{
		static if (TypedKey.tupleof.length == 1) // TypedKey is a wrapper type
		{
			alias WrappedTypedKey = typeof(TypedKey.tupleof[0]);
			return TypedKey(ukey.toTypedKey!(WrappedTypedKey));
		}
		else
		{
			TypedKey typedKey;
			size_t ix = 0;
			enum members = __traits(allMembers, TypedKey);
			foreach (immutable i, immutable memberName; members) // for each member name in `struct TypedKey`
			{
				alias MemberType = typeof(__traits(getMember, typedKey, memberName));
				static if (i + 1 != members.length) // last member is allowed to be an array of fixed length
					static assert(isFixedTrieableKeyType!MemberType,
								  "Non-last MemberType must be fixed length");
				__traits(getMember, typedKey, memberName) = ukey[ix .. ix + MemberType.sizeof].toTypedKey!MemberType;
				ix += MemberType.sizeof;
			}
			return typedKey;
		}
	}
	else
	{
		static assert(false, "TODO: Handle typed key " ~ TypedKey.stringof);
	}
}

/** Radix-Tree with key of type `K` and value of type `V` (if non-`void`).
 *
 * Radix-tree is also called a patricia trie, radix trie or compact prefix tree.
 */
struct RadixTree(K, V, A = Mallocator)
if (isTrieableKeyType!(K) &&
	isAllocator!A)
{
	import std.experimental.allocator.common : stateSize;

	// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", A);
	alias KeyType = K;

	/** Keys are stored in a way that they can't be accessed by reference so we
		allow array (and string) keys to be of mutable type.
	*/
	static if (is(K == U[], U)) // isDynamicArray
		alias MK = const(Unqual!(U))[];
	else
		alias MK = K;

	static if (stateSize!A != 0)
	{
		this() @disable; ///< No default construction if an allocator must be provided.

		/** Use the given `allocator` for allocations. */
		this(A alloc)
		in(alloc !is null)
		do
		{
			this._alloc = alloc;
		}
	}

	private alias RawTree = RawRadixTree!(V, A);

	static if (RawTree.hasValue)
	{
		alias ValueType = V;

		/** Element type. */
		struct E
		{
			K key;
			V value;
		}
		alias ElementType = E;

		ref V opIndex(const scope MK key)
		{
			pragma(inline, true);
			V* value = contains(key);
			version (assert)
			{
				import core.exception : RangeError;
				if (value is null)
					throw new RangeError("Range violation");
			}
			return *value;
		}

		auto opIndexAssign(V value, const scope MK key)
		{
			_rawTree.ElementRefType elementRef; // reference to where element was added

			Ixs rawUKey;
			auto rawKey = key.toRawKey(rawUKey); /+ TODO: DIP-1000 scope +/

			_rawTree.insert(rawKey, value, elementRef);

			immutable bool added = elementRef.node && elementRef.modStatus == ModStatus.added;
			_length += added;
			/* TODO: return reference (via `auto ref` return typed) to stored
			   value at `elementRef` instead, unless packed static_bitarray storage is used
			   when `V is bool` */
			return value;
		}

		/** Insert element `elt`.
		 * Returns: `true` if `elt.key` wasn't previously added, `false` otherwise.
		 */
		bool insert(in ElementType e) @nogc => insert(e.key, e.value);

		/** Insert `key` with `value`.
			Returns: `true` if `key` wasn't previously added, `false` otherwise.
		*/
		bool insert(const scope MK key, V value) @nogc
		{
			_rawTree.ElementRefType elementRef; // indicates that key was added

			Ixs rawUKey;
			auto rawKey = key.toRawKey(rawUKey); /+ TODO: DIP-1000 scope +/

			_rawTree.insert(rawKey, value, elementRef);

			// debug if (willFail) { dbg("WILL FAIL: elementRef:", elementRef, " key:", key); }
			if (elementRef.node)  // if `key` was added at `elementRef`
			{
				// set value
				final switch (elementRef.node.typeIx) with (_rawTree.NodeType.Ix)
				{
				case undefined:
				case ix_OneLeafMax7:
				case ix_TwoLeaf3:
				case ix_TriLeaf2:
				case ix_HeptLeaf1:
				case ix_SparseBranchPtr:
				case ix_DenseBranchPtr:
					assert(false);
				case ix_SparseLeaf1Ptr:
					elementRef.node.as!(SparseLeaf1!V*).setValue(UIx(rawKey[$ - 1]), value);
					break;
				case ix_DenseLeaf1Ptr:
					elementRef.node.as!(DenseLeaf1!V*).setValue(UIx(rawKey[$ - 1]), value);
					break;
				}
				immutable bool hit = elementRef.modStatus == ModStatus.added;
				_length += hit;
				return hit;
			}
			else
				assert(false, "TODO: warning no elementRef for key:"/*, key, " rawKey:", rawKey*/);
		}

		/** Returns: pointer to value if `key` is contained in set, null otherwise. */
		inout(V*) contains(const scope MK key) inout @nogc
		{
			version (LDC) pragma(inline, true);
			Ixs rawUKey;
			auto rawKey = key.toRawKey(rawUKey); /+ TODO: DIP-1000 scope +/
			return _rawTree.contains(rawKey);
		}

		/** AA-style key-value range. */
		pragma(inline, true)
		Range byKeyValue() @nogc => this.opSlice; /+ TODO: inout?, TODO: DIP-1000 scope +/
	}
	else
	{
		alias ElementType = K;

		/** Insert `key`.
			Returns: `true` if `key` wasn't previously added, `false` otherwise.
		*/
		bool insert(const scope MK key) @nogc
		{
			_rawTree.ElementRefType elementRef; // indicates that elt was added

			Ixs rawUKey;
			auto rawKey = key.toRawKey(rawUKey); /+ TODO: DIP-1000 scope +/

			_rawTree.insert(rawKey, elementRef);

			immutable bool hit = elementRef.node && elementRef.modStatus == ModStatus.added;
			_length += hit;
			return hit;
		}

		/** Returns: `true` if `key` is stored, `false` otherwise. */
		bool contains(const scope MK key) inout nothrow @nogc
		{
			version (LDC) pragma(inline, true);
			Ixs rawUKey;
			auto rawKey = key.toRawKey(rawUKey); /+ TODO: DIP-1000 scope +/
			return _rawTree.contains(rawKey);
		}

		/** AA-style key range. */
		pragma(inline, true)
		Range byKey() nothrow @nogc => this.opSlice; /+ TODO: inout?. TODO: DIP-1000 scope +/
	}

	/** Supports $(B `K` in `this`) syntax. */
	auto opBinaryRight(string op)(const scope MK key) inout if (op == "in")
	{
		pragma(inline, true);
		return contains(key);   /+ TODO: return `_rawTree.ElementRefType` +/
	}

	Range opSlice() @system @nogc /+ TODO: inout? +/
	{
		version (LDC) pragma(inline, true);
		return Range(_root, []);
	}

	/** Get range over elements whose key starts with `keyPrefix`.
		The element equal to `keyPrefix` is return as an empty instance of the type.
	 */
	auto prefix(const scope MK keyPrefix) @system
	{
		Ixs rawUKey;
		auto rawKeyPrefix = keyPrefix.toRawKey(rawUKey);

		UKey rawKeyPrefixRest;
		auto prefixedRootNode = _rawTree.prefix(rawKeyPrefix, rawKeyPrefixRest);

		return Range(prefixedRootNode,
					 rawKeyPrefixRest);
	}

	/** Typed Range. */
	private static struct Range
	{
		this(RawTree.NodeType root, UKey keyPrefixRest) @nogc
		{
			pragma(inline, true);
			_rawRange = _rawTree.RangeType(root, keyPrefixRest);
		}

		ElementType front() const @nogc
		{
			pragma(inline, true);
			static if (RawTree.hasValue)
				return typeof(return)(_rawRange.lowKey.toTypedKey!K,
									  _rawRange._front._cachedFrontValue);
			else
				return _rawRange.lowKey.toTypedKey!K;
		}

		ElementType back() const @nogc
		{
			pragma(inline, true);
			static if (RawTree.hasValue)
				return typeof(return)(_rawRange.highKey.toTypedKey!K,
									  _rawRange._back._cachedFrontValue);
			else
				return _rawRange.highKey.toTypedKey!K;
		}

		@property typeof(this) save() @nogc
		{
			version (LDC) pragma(inline, true);
			typeof(return) copy;
			copy._rawRange = this._rawRange.save;
			return copy;
		}

		RawTree.RangeType _rawRange;
		alias _rawRange this;
	}

	/** Raw Range. */
	private static struct RawRange
	{
		this(RawTree.NodeType root,
			 UKey keyPrefixRest)
		{
			pragma(inline, true);
			this._rawRange = _rawTree.RangeType(root, keyPrefixRest);
		}

		static if (RawTree.hasValue)
		{
			pragma(inline, true):
			const(Elt!V) front() const => typeof(return)(_rawRange.lowKey,
														 _rawRange._front._cachedFrontValue);
			const(Elt!V) back() const => typeof(return)(_rawRange.highKey,
														_rawRange._back._cachedFrontValue);
		}
		else
		{
			pragma(inline, true):
			const(Elt!V) front() const => _rawRange.lowKey;
			const(Elt!V) back() const => _rawRange.highKey;
		}

		@property typeof(this) save()
		{
			typeof(return) copy;
			copy._rawRange = this._rawRange.save;
			return copy;
		}

		RawTree.RangeType _rawRange;
		alias _rawRange this;
	}

	/** This function searches with policy `sp` to find the largest right subrange
		on which pred(value, x) is true for all x (e.g., if pred is "less than",
		returns the portion of the range with elements strictly greater than
		value).

		TODO: Add template param (SearchPolicy sp)

		TODO: replace `matchCommonPrefix` with something more clever directly
		finds the next element after rawKey and returns a TreeRange at that point
	*/
	auto upperBound(const scope MK key) @system
	{
		Ixs rawUKey;
		auto rawKey = key.toRawKey(rawUKey);
		UKey rawKeyRest;
		auto prefixedRootNode = _rawTree.matchCommonPrefix(rawKey, rawKeyRest);
		return UpperBoundRange(prefixedRootNode,
							   rawKey[0 .. $ - rawKeyRest.length],
							   rawKeyRest);
	}

	/** Typed Upper Bound Range.
	 */
	private static struct UpperBoundRange
	{
		this(RawTree.NodeType root,
			 UKey rawKeyPrefix, UKey rawKeyRest) @nogc
		{
			_rawRange = _rawTree.RangeType(root, []);
			_rawKeyPrefix = rawKeyPrefix;

			// skip values
			import std.algorithm.comparison : cmp;
			while (!_rawRange.empty &&
				   cmp(_rawRange._front.frontKey, rawKeyRest) <= 0)
			{
				_rawRange.popFront();
			}
		}

		ElementType front() @nogc
		{
			Ixs wholeRawKey = _rawKeyPrefix.dupShallow;
			wholeRawKey ~= _rawRange.lowKey;
			static if (RawTree.hasValue)
				return typeof(return)(wholeRawKey[].toTypedKey!K,
									  _rawRange._front._cachedFrontValue);
			else
				return wholeRawKey[].toTypedKey!K;
		}

		@property typeof(this) save() @nogc
		{
			typeof(return) copy;
			copy._rawRange = this._rawRange.save;
			copy._rawKeyPrefix = this._rawKeyPrefix.dupShallow;
			return copy;
		}

		RawTree.RangeType _rawRange;
		alias _rawRange this;
		Ixs _rawKeyPrefix;
	}

	/** Returns a duplicate of this tree.
		Shallowly duplicates the values in the map case.
	*/
	typeof(this) dup() => typeof(this)(this._rawTree.dup);

	private RawTree _rawTree;
	alias _rawTree this;
}
alias RadixTreeMap = RadixTree;

template RadixTreeSet(K, A = Mallocator)
if (isTrieableKeyType!(K) &&
	isAllocator!A)
{
	alias RadixTreeSet = RadixTree!(K, void, A);
}

/** Print `tree`. */
void print(Key, Value, A)(const ref RadixTree!(Key, Value, A) tree) @safe
if (isTrieableKeyType!(K) &&
	isAllocator!A)
{
	print(tree._rawTree);
}

pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	version (enterSingleInfiniteMemoryLeakTest)
	{
		while (true)
		{
			checkNumeric!(bool, float, double,
						  long, int, short, byte,
						  ulong, uint, ushort, ubyte);
		}
	}
	else
	{
		checkNumeric!(bool, float, double,
					  long, int, short, byte,
					  ulong, uint, ushort, ubyte);
	}
}

/// exercise all switch-cases in `RawRadixTree.prefixAt()`
/*TODO: @safe*/ pure nothrow
/*TODO:@nogc*/ unittest
{ version (showAssertTags) dbg();
	import nxt.algorithm.comparison : equal;
	alias Key = string;
	auto set = RadixTreeSet!(Key, TestAllocator)();

	set.clear();
	set.insert(`-----1`);
	assert(set.prefix(`-----`).equal([`1`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----2`);
	assert(set.prefix(`-----`).equal([`1`, `2`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----3`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----4`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`, `4`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----5`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`, `4`, `5`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----6`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`, `4`, `5`, `6`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----7`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`, `4`, `5`, `6`, `7`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----8`);
	assert(set.prefix(`-----`).equal([`1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----____`).empty);
	set.insert(`-----11`);
	assert(set.prefix(`-----`).equal([`1`, `11`, `2`, `3`, `4`, `5`, `6`, `7`, `8`]));
	set.insert(`-----22`);
	assert(set.prefix(`-----`).equal([`1`, `11`, `2`, `22`, `3`, `4`, `5`, `6`, `7`, `8`]));
	set.insert(`-----33`);
	assert(set.prefix(`-----`).equal([`1`, `11`, `2`, `22`, `3`, `33`, `4`, `5`, `6`, `7`, `8`]));
	set.insert(`-----44`);
	assert(set.prefix(`-----`).equal([`1`, `11`, `2`, `22`, `3`, `33`, `4`, `44`, `5`, `6`, `7`, `8`]));

	set.clear();
	set.insert(`-----11`);
	assert(set.prefix(`-----`).equal([`11`]));
	set.insert(`-----22`);
	assert(set.prefix(`-----`).equal([`11`, `22`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----___`).empty);

	set.clear();
	set.insert(`-----111`);
	assert(set.prefix(`-----`).equal([`111`]));
	set.insert(`-----122`);
	assert(set.prefix(`-----`).equal([`111`, `122`]));
	set.insert(`-----133`);
	assert(set.prefix(`-----`).equal([`111`, `122`, `133`]));
	assert(set.prefix(`-----1`).equal([`11`, `22`, `33`]));
	assert(set.prefix(`-----1_`).empty);
	assert(set.prefix(`-----1___`).empty);

	set.clear();
	set.insert(`-----1111`);
	assert(set.prefix(`-----`).equal([`1111`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----___`).empty);

	set.clear();
	set.insert(`-----11111`);
	assert(set.prefix(`-----`).equal([`11111`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----___`).empty);
	set.insert(`-----12222`);
	assert(set.prefix(`-----`).equal([`11111`, `12222`]));
	assert(set.prefix(`-----_`).empty);
	assert(set.prefix(`-----___`).empty);
	assert(set.prefix(`-----12`).equal([`222`]));
	assert(set.prefix(`-----12_`).empty);
	assert(set.prefix(`-----12____`).empty);
}

/// test floating-point key range sortedness
/*@ TODO: safe */ pure nothrow @nogc unittest
{ version (showAssertTags) dbg();
	alias T = double;

	auto set = RadixTreeSet!(T, TestAllocator)();

	import std.range: isForwardRange;
	static assert(isForwardRange!(typeof(set[])));

	set.insert(-1.1e6);
	set.insert(-2.2e9);
	set.insert(-1.1);
	set.insert(+2.2);
	set.insert(T.max);
	set.insert(-T.max);
	set.insert(-3.3);
	set.insert(-4.4);
	set.insert(+4.4);
	set.insert(+3.3);
	set.insert(+1.1e6);
	set.insert(+2.2e9);

	import std.algorithm.sorting : isSorted;
	assert(set[].isSorted);
}

version (unittest)
auto testScalar(uint span, Keys...)() @safe
if (Keys.length != 0)
{
	import std.algorithm.comparison : min, max;
	import std.traits : isIntegral, isFloatingPoint;
	import std.range : iota;
	foreach (Key; Keys)
	{
		auto set = RadixTreeSet!(Key, TestAllocator)();

		static if (isIntegral!Key)
		{
			immutable low = max(Key.min, -1_000);
			immutable high = min(Key.max, 1_000);
			immutable factor = 1;
		}
		else static if (isFloatingPoint!Key)
		{
			immutable low = -1_000;
			immutable high = 1_000;
			immutable factor = 1;
		}
		else static if (is(Key == bool))
		{
			immutable low = false;
			immutable high = true;
			immutable factor = 1;
		}

		foreach (immutable uk_; low.iota(high + 1))
		{
			immutable uk = factor*uk_;
			immutable Key key = cast(Key)uk;
			assert(set.insert(key));  // insert new value returns `true` (previously not in set)
			assert(!set.insert(key)); // reinsert same value returns `false` (already in set)
		}

		import nxt.algorithm.comparison : equal;
		import std.algorithm.iteration : map;
		() @trusted { assert(set[].equal(low.iota(high + 1).map!(uk => cast(Key)uk))); } (); /+ TODO: remove @trusted when opSlice support DIP-1000 +/

		import std.algorithm.sorting : isSorted;
		() @trusted { assert(set[].isSorted); } (); /+ TODO: remove @trusted when opSlice support DIP-1000 +/
	}
}

///
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	testScalar!(8,
				bool,
				double, float,
				long, int, short, byte,
				ulong, uint, ushort, ubyte);
}

///
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	alias Key = ubyte;
	auto set = RadixTreeSet!(Key, TestAllocator)();

	assert(!set.root);

	foreach (immutable i; 0 .. 7)
	{
		assert(!set.contains(i));
		assert(set.insert(i));
		assert(set.root.peek!HeptLeaf1);
	}

	foreach (immutable i; 7 .. 48)
	{
		assert(!set.contains(i));
		assert(set.insert(i));
		assert(set.root.peek!(SparseLeaf1!void*));
	}

	foreach (immutable i; 48 .. 256)
	{
		assert(!set.contains(i));
		assert(set.insert(i));
		assert(set.root.peek!(DenseLeaf1!void*));
	}
}

/** Calculate and print statistics of `tree`. */
void showStatistics(RT)(const ref RT tree) // why does `in`RT tree` trigger a copy ctor here
{
	import std.conv : to;
	import std.stdio : writeln;

	auto stats = tree.usageHistograms;

	writeln("Population By Node Type: ", stats.popByNodeType);
	writeln("Population By Leaf1 Type: ", stats.popByLeaf1Type);

	writeln("SparseBranch Population Histogram: ", stats.popHist_SparseBranch);
	writeln("DenseBranch Population Histogram: ", stats.popHist_DenseBranch);

	writeln("SparseLeaf1 Population Histogram: ", stats.popHist_SparseLeaf1);
	writeln("DenseLeaf1 Population Histogram: ", stats.popHist_DenseLeaf1);

	size_t totalBytesUsed = 0;

	// Node-usage
	foreach (const index, const pop; stats.popByNodeType) /+ TODO: use stats.byPair when added to typecons_ex.d +/
	{
		size_t bytesUsed = 0;
		const ix = cast(RT.NodeType.Ix)index;
		final switch (ix) with (RT.NodeType.Ix)
		{
		case undefined:
			continue; // ignore
		case ix_OneLeafMax7:
			bytesUsed = pop*OneLeafMax7.sizeof;
			break;
		case ix_TwoLeaf3:
			bytesUsed = pop*TwoLeaf3.sizeof;
			break;
		case ix_TriLeaf2:
			bytesUsed = pop*TriLeaf2.sizeof;
			break;
		case ix_HeptLeaf1:
			bytesUsed = pop*HeptLeaf1.sizeof;
			break;
		case ix_SparseLeaf1Ptr:
			bytesUsed = stats.sparseLeaf1AllocatedSizeSum; // variable length struct
			totalBytesUsed += bytesUsed;
			break;
		case ix_DenseLeaf1Ptr:
			bytesUsed = pop*DenseLeaf1!(RT.ValueType).sizeof;
			totalBytesUsed += bytesUsed;
			break;
		case ix_SparseBranchPtr:
			bytesUsed = stats.sparseBranchAllocatedSizeSum; // variable length struct
			totalBytesUsed += bytesUsed;
			break;
		case ix_DenseBranchPtr:
			bytesUsed = pop*RT.DenseBranchType.sizeof;
			totalBytesUsed += bytesUsed;
			break;
		}
		writeln(pop, " number of ",
				ix.to!string[3 .. $], /+ TODO: Use RT.NodeType.indexTypeName(ix) +/
				" uses ", bytesUsed/1e6, " megabytes");
	}

	writeln("Tree uses ", totalBytesUsed/1e6, " megabytes");
}

/// test map from `uint` to values of type `double`
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	alias Key = uint;
	alias Value = uint;

	auto map = RadixTreeMap!(Key, Value, TestAllocator)();
	assert(map.empty);

	static assert(map.hasValue);

	static Value keyToValue(Key key) pure nothrow @safe @nogc { return cast(Value)((key + 1)*radix); }

	foreach (immutable i; 0 .. SparseLeaf1!Value.maxCapacity)
	{
		assert(!map.contains(i));
		assert(map.length == i);
		map[i] = keyToValue(i);
		assert(map.contains(i));
		assert(*map.contains(i) == keyToValue(i));
		assert(i in map);
		assert(*(i in map) == keyToValue(i));
		assert(map.length == i + 1);
	}

	foreach (immutable i; SparseLeaf1!Value.maxCapacity .. radix)
	{
		assert(!map.contains(i));
		assert(map.length == i);
		map[i] = keyToValue(i);
		assert(map.contains(i));
		assert(*map.contains(i) == keyToValue(i));
		assert(i in map);
		assert(*(i in map) == keyToValue(i));
		assert(map.length == i + 1);
	}

	void testRange() @trusted
	{
		size_t i = 0;
		foreach (immutable keyValue; map[])
		{
			assert(keyValue.key == i);
			assert(keyValue.value == keyToValue(cast(Key)i)); /+ TODO: use typed key instead of cast(Key) +/
			++i;
		}
	}

	testRange();
}

/** Check string types in `Keys`. */
auto testString(Keys...)(size_t count, uint lengthMax)
if (Keys.length != 0)
{
	import std.traits : isSomeString;
	void testContainsAndInsert(Set, Key)(ref Set set, Key key)
	if (isSomeString!Key)
	{
		import std.conv : to;
		immutable failMessage = `Failed for key: "` ~ key.to!string ~ `"`;

		assert(!set.contains(key), failMessage);

		assert(set.insert(key), failMessage);
		assert(set.contains(key), failMessage);

		assert(!set.insert(key), failMessage);
		assert(set.contains(key), failMessage);
	}

	import nxt.algorithm.comparison : equal;
	import std.datetime.stopwatch : StopWatch, AutoStart;

	foreach (Key; Keys)
	{
		auto set = RadixTreeSet!(Key, TestAllocator)();
		assert(set.empty);

		immutable sortedKeys = randomUniqueSortedStrings(count, lengthMax);

		auto sw1 = StopWatch(AutoStart.yes);
		foreach (immutable key; sortedKeys)
		{
			testContainsAndInsert(set, key);
		}
		sw1.stop;

		version (show)
		{
			import std.conv : to;
			version (show) import std.stdio : writeln;
			version (show) writeln("Test for contains and insert took ", sw1.peek());
		}

		auto sw2 = StopWatch(AutoStart.yes);

		void testPrefix() @trusted
		{
			assert(set[].equal(sortedKeys));
			import std.algorithm.iteration : filter, map;
			assert(set.prefix("a")
					  .equal(sortedKeys.filter!(x => x.length && x[0] == 'a')
									   .map!(x => x[1 .. $])));
			assert(set.prefix("aa")
					  .equal(sortedKeys.filter!(x => x.length >= 2 && x[0] == 'a' && x[1] == 'a')
									   .map!(x => x[2 .. $])));
		}

		testPrefix();

		sw2.stop;
		version (show)
		{
			import std.stdio : writeln;
			writeln("Compare took ", sw2.peek());
		}
	}
}

///
@safe /* TODO: pure nothrow @nogc */
unittest
{ version (showAssertTags) dbg();
	testString!(string)(512, 8);
	testString!(string)(512, 32);
}

/// test map to values of type `bool`
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	alias Key = uint;
	alias Value = bool;

	auto map = RadixTreeMap!(Key, Value, TestAllocator)();
	assert(map.empty);

	static assert(map.hasValue);
	map.insert(Key.init, Value.init);
}

/// test packing of set elements
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	auto set = RadixTreeSet!(ulong, TestAllocator)();
	enum N = HeptLeaf1.capacity;

	foreach (immutable i; 0 .. N)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));
	}

	foreach (immutable i; N .. 256)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));
	}

	foreach (immutable i; 256 .. 256 + N)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));
	}

	foreach (immutable i; 256 + N .. 256 + 256)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));
	}
}

///
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	auto set = RadixTreeSet!(ubyte, TestAllocator)();
	alias Set = typeof(set);

	foreach (immutable i; 0 .. HeptLeaf1.capacity)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));

		immutable rootRef = set.root.peek!(HeptLeaf1);
		assert(rootRef);
	}

	foreach (immutable i; HeptLeaf1.capacity .. 256)
	{
		assert(!set.contains(i));

		assert(set.insert(i));
		assert(set.contains(i));

		assert(!set.insert(i));
		assert(set.contains(i));
	}
}

///
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	import std.meta : AliasSeq;
	foreach (T; AliasSeq!(ushort, uint))
	{
		auto set = RadixTreeSet!(T, TestAllocator)();
		alias Set = typeof(set);

		foreach (immutable i; 0 .. 256)
		{
			assert(!set.contains(i));

			assert(set.insert(i));
			assert(set.contains(i));

			assert(!set.insert(i));
			assert(set.contains(i));
		}

		// 256
		assert(!set.contains(256));

		assert(set.insert(256));
		assert(set.contains(256));

		assert(!set.insert(256));
		assert(set.contains(256));

		// 257
		assert(!set.contains(257));

		assert(set.insert(257));
		assert(set.contains(257));

		assert(!set.insert(257));
		assert(set.contains(257));

		immutable rootRef = set.root.peek!(Set.DefaultBranchType*);
		assert(rootRef);
		immutable root = *rootRef;
		assert(root.prefix.length == T.sizeof - 2);

	}
}

/** Generate `count` number of random unique strings of minimum length 1 and
	maximum length of `lengthMax`.
 */
private static auto randomUniqueSortedStrings(size_t count, uint lengthMax) @trusted pure nothrow
{
	import std.random : Random, uniform;
	auto gen = Random();

	// store set of unique keys using a builtin D associative array (AA)
	bool[string] stringSet;  // set of strings using D's AA

	try
	{
		while (stringSet.length < count)
		{
			const length = uniform(1, lengthMax, gen);
			auto key = new char[length];
			foreach (immutable ix; 0 .. length)
			{
				key[ix] = cast(char)('a' + 0.uniform(26, gen));
			}
			stringSet[key[].idup] = true;
		}
	}
	catch (Exception e)
	{
		import nxt.debugio : dbg;
		dbg("Couldn't randomize");
	}

	import std.array : array;
	import std.algorithm.sorting : sort;
	auto keys = stringSet.byKey.array;
	sort(keys);
	return keys;
}

/** Create a set of words from the file `/usr/share/dict/words`. */
private void benchmarkReadDictWords(Value)(in size_t maxCount)
{
	import std.range : chain;

	const path = "test/data/dict-words";

	enum hasValue = !is(Value == void);
	static if (hasValue)
		auto rtr = RadixTreeMap!(string, Value, TestAllocator)();
	else
		auto rtr = RadixTreeSet!(string, TestAllocator)();
	assert(rtr.empty);

	enum show = false;

	string[] firsts = [];	   // used to test various things
	size_t count = 0;

	import std.datetime.stopwatch : StopWatch, AutoStart;
	auto sw = StopWatch(AutoStart.yes);

	import std.stdio : File;
	foreach (const word; chain(firsts, File(path).byLine))
	{
		if (count >= maxCount) { break; }
		import nxt.algorithm.searching : endsWith;
		import std.range.primitives : empty;
		if (!word.empty &&
			!word.endsWith(`'s`)) // skip genitive forms
		{
			assert(!rtr.contains(word));

			static if (show)
			{
				import std.string : representation;
				// dbg(`word:"`, word, `" of length:`, word.length,
				//	 ` of representation:`, word.representation);
				// debug rtr.willFail = word == `amiable`;
				// if (rtr.willFail)
				// {
				//	 rtr.print();
				// }
			}

			static if (hasValue)
			{
				assert(rtr.insert(word, count));
				const hitA = rtr.contains(word);
				assert(hitA);
				assert(*hitA == count);

				assert(!rtr.insert(word, count));
				const hitB = rtr.contains(word);
				assert(hitB);
				assert(*hitB == count);
			}
			else
			{
				assert(rtr.insert(word));
				assert(rtr.contains(word));

				assert(!rtr.insert(word));
				assert(rtr.contains(word));
			}
			++count;
		}
	}
	sw.stop;
	version (show)
	{
		import std.stdio : writeln;
		writeln("Added ", count, " words from ", path, " in ", sw.peek());
		rtr.showStatistics();
	}
}

unittest
{ version (showAssertTags) dbg();
	const maxCount = 1000;
	benchmarkReadDictWords!(void)(maxCount);
	benchmarkReadDictWords!(size_t)(maxCount);
}

static private void testSlice(T)(ref T x) @trusted
{
	auto xr = x[];
}

bool testEqual(T, U)(ref T x, ref U y) @trusted
{
	import nxt.algorithm.comparison : equal;
	return equal(x[], y[]);
}

/** Check correctness when span is `span` and for each `Key` in `Keys`. */
version (unittest)
private auto checkNumeric(Keys...)() @safe
if (Keys.length != 0)
{
	import std.algorithm.comparison : min, max;
	import std.traits : isIntegral, isFloatingPoint;
	foreach (immutable it; 0 .. 1)
	{
		struct TestValueType { int i = 42; float f = 43; char ch = 'a'; }
		alias Value = TestValueType;
		import std.meta : AliasSeq;
		foreach (Key; Keys)
		{
			auto set = RadixTreeSet!(Key, TestAllocator)();
			auto map = RadixTreeMap!(Key, Value, TestAllocator)();

			assert(set.empty);
			assert(map.empty);

			testSlice(set);
			testSlice(map);

			static assert(!set.hasValue);
			static assert(map.hasValue);

			static if (is(Key == bool) ||
					   isIntegral!Key ||
					   isFloatingPoint!Key)
			{
				static if (isIntegral!Key)
				{
					immutable low = max(Key.min, -1000);
					immutable high = min(Key.max, 1000);
					immutable factor = 1;
				}
				else static if (isFloatingPoint!Key)
				{
					immutable low = -1_000;
					immutable high = 1_000;
					immutable factor = 100;
				}
				else static if (is(Key == bool))
				{
					immutable low = false;
					immutable high = true;
					immutable factor = 1;
				}
				else
				{
					static assert(false, "Support Key " ~ Key.stringof);
				}
				immutable length = high - low + 1;

				foreach (immutable uk_; low .. high + 1)
				{
					immutable uk = factor*uk_;
					immutable Key key = cast(Key)uk;

					assert(!set.contains(key)); // `key` should not yet be in `set`
					assert(!map.contains(key)); // `key` should not yet be in 'map

					assert(key !in set);		// alternative syntax
					assert(key !in map);		// alternative syntax

					// insertion of new `key` is `true` (previously not stored)
					assert(set.insert(key));
					assert(map.insert(key, Value.init));

					// `key` should now be in `set` and `map`
					assert(set.contains(key));
					assert(map.contains(key));

					// reinsertion of same `key` is `false` (already in stored)
					assert(!set.insert(key));
					assert(!map.insert(key, Value.init));

					// `key` should now be `stored`
					assert(set.contains(key));
					assert(map.contains(key));

					// alternative syntax
					assert(key in set);
					assert(key in map);

					if (key != Key.max)		// except last value
						assert(!set.contains(cast(Key)(key + 1))); // next key is not yet in set
				}
				assert(set.length == length);
			}
			else
			{
				static assert(false, `Handle type: "` ~ Key.stringof ~ `"`);
			}

			auto setDup = set.dup();
			auto mapDup = map.dup();

			assert(testEqual(set, setDup));
			assert(testEqual(map, mapDup));

			set.clear();

			static assert(map.hasValue);
			map.clear();
		}
	}
}

/** Benchmark performance and memory usage when span is `span`. */
version (nxt_benchmark)
private void benchmarkTimeAndSpace()
{
	version (show) import std.stdio : writeln;

	struct TestValueType { int i = 42; float f = 43; char ch = 'a'; }
	alias Value = TestValueType;
	import std.meta : AliasSeq;
	foreach (Key; AliasSeq!(uint)) // just benchmark uint for now
	{
		auto set = RadixTreeSet!(Key);
		alias Set = set;
		assert(set.empty);

		static assert(!set.hasValue);

		version (show) import std.datetime.stopwatch : StopWatch, AutoStart;

		enum n = 1_000_000;

		immutable useUniqueRandom = false;

		import std.range : generate, take;
		import std.random : uniform;
		auto randomSamples = generate!(() => uniform!Key).take(n);

		{
			version (show) auto sw = StopWatch(AutoStart.yes);

			foreach (immutable Key k; randomSamples)
			{
				if (useUniqueRandom)
					assert(set.insert(k));
				else
					set.insert(k);

				/* second insert of same key should always return `false` to
				   indicate that key was already stored */
				static if (false) { assert(!set.insert(k)); }
			}

			version (show) writeln("trie: Added ", n, " ", Key.stringof, "s of size ", n*Key.sizeof/1e6, " megabytes in ", sw.peek());
			set.showStatistics();
		}

		{
			version (show) auto sw = StopWatch(AutoStart.yes);
			bool[int] aa;

			foreach (Key k; randomSamples) { aa[k] = true; }

			version (show) writeln("D-AA: Added ", n, " ", Key.stringof, "s of size ", n*Key.sizeof/1e6, " megabytes in ", sw.peek());
		}

		auto map = RadixTreeMap!(Key, Value);
		assert(map.empty);
		static assert(map.hasValue);

		map.insert(Key.init, Value.init);
	}
}

///
pure nothrow @safe @nogc unittest
{ version (showAssertTags) dbg();
	struct S { int x; }

	alias Key = S;
	auto set = RadixTreeSet!(Key, TestAllocator)();

	assert(!set.contains(S(43)));

	assert(set.insert(S(43)));
	assert(set.contains(S(43)));

	assert(!set.insert(S(43)));
	assert(set.contains(S(43)));

	set.clear();
}

/** Static Iota.
 *
 * TODO: Move to Phobos std.range.
 */
template iota(size_t from, size_t to)
if (from <= to)
{
	alias iota = iotaImpl!(to - 1, from);
}
private template iotaImpl(size_t to, size_t now)
{
	import std.meta : AliasSeq;
	static if (now >= to)
		alias iotaImpl = AliasSeq!(now);
	else
		alias iotaImpl = AliasSeq!(now, iotaImpl!(to, now + 1));
}

unittest {
	version (showAssertTags) dbg();
	version (nxt_benchmark) benchmarkTimeAndSpace();
}

version (unittest)
{
	version (showAssertTags) import nxt.debugio : dbg;
	import std.experimental.allocator.mallocator : TestAllocator = Mallocator;
	// import std.experimental.allocator.gc_allocator : TestAllocator = GCAllocator;
}
