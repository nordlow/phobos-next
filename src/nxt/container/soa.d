/** Structure of arrays (SoA).
 *
 * SoAs are common in game engines.
 *
 * Initially a builtin feature in the Jai programming language that later was
 * made into a library solution.
 *
 * TODO: merge with soa_petar_kirov.d by
 * 1. allocate all arrays in a single chunk
 * 2. calculating `_capacity` based on `_length`
 *
 * TODO: merge with variant_arrays.d?
 * TODO: Maybe growth logic can be hidden inside a wrapper Allocator
 *
 * See_Also: http://forum.dlang.org/post/wvulryummkqtskiwrusb@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/purhollnapramxczmcka@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/cvxuagislrpfomalcelc@forum.dlang.org
 * See_Also: https://maikklein.github.io/post/soa-d/
 */
module nxt.container.soa;

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.common : isAllocator;

/** Structure of Arrays similar to members of `S`.
 */
struct SoA(S, Capacity = size_t, Allocator = Mallocator)
if (is(S == struct) &&		  /+ TODO: extend to `isAggregate!S`? +/
	isAllocator!Allocator) {
	/** Growth factor P/Q.
		https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
		Use 1.5 like Facebook's `fbvector` does.
	*/
	enum _growthP = 3;		  // numerator
	/// ditto
	enum _growthQ = 2;		  // denominator

	private alias toType(string s) = typeof(__traits(getMember, S, s));
	private alias Types = typeof(S.tupleof);

	import std.experimental.allocator.common : stateSize;
	static if (stateSize!Allocator != 0) {
		this(in Capacity initialCapacity, Allocator allocator) {
			_capacity = initialCapacity;
			this.allocator = allocator;
			allocate(initialCapacity);
		}
		this() @disable; ///< No default construction if an allocator must be provided.
	} else
		this(in Capacity initialCapacity) {
			_capacity = initialCapacity;
			allocate(initialCapacity);
		}

	this(this) @disable;	// disable copy constructor

	~this() nothrow @trusted @nogc {
		import std.experimental.allocator : dispose;
		static foreach (const index, _; S.tupleof)
			allocator.dispose(getArray!index);
	}

	pragma(inline, true):

	Capacity length() const @property pure nothrow @safe @nogc => _length;
	Capacity capacity() const @property pure nothrow @safe @nogc => _capacity;
	bool empty() const @property pure nothrow @safe @nogc => _length == 0;

	inout(SoAElementRef!S) opIndex()(in Capacity elementIndex) inout return /*tlm*/
	in(elementIndex < _length)
		=> typeof(return)(&this, elementIndex);

	inout(SoASlice!S) opSlice()() inout return /*tlm*/
		=> typeof(return)(&this);

	void opOpAssign(string op, S)(S value) if (op == "~") => insertBack(value);

	pragma(inline):				// reset

	auto opDispatch(string name)() {
		static foreach (const index, memberSymbol; S.tupleof)
			static if (name == memberSymbol.stringof)
				return getArray!index;
		/+ TODO: static assert(0, S.stringof ~ " has no field named " ~ name); +/
	}

	/** Push element (struct) `value` to back of array. */
	void insertBack()(S value) @trusted /*tlm*/ {
		import core.lifetime : moveEmplace;
		reserveOneExtra();
		static foreach (const index, memberSymbol; S.tupleof)
			moveEmplace(__traits(getMember, value, memberSymbol.stringof),
						getArray!index[_length]); /+ TODO: assert that +/
		++_length;
	}

	/** Push element `value` to back of array using its data members `members`. */
	void insertBackMembers()(Types members) @trusted /*tlm*/ {
		import core.lifetime : moveEmplace;
		reserveOneExtra();
		// move each member to its position respective array
		static foreach (const index, _; members)
			moveEmplace(members[index], getArray!index[_length]); // same as `getArray!index[_length] = members[index];`
		++_length;
	}

private:
	import nxt.allocator_traits : AllocatorState;
	mixin AllocatorState!Allocator; // put first as emsi-containers do

	// generate array definitions
	static foreach (const index, Type; Types)
		mixin(Type.stringof ~ `[] _container` ~ index.stringof ~ ";");

	/** Get array of all fields at aggregate field index `index`. */
	pragma(inline, true)
	ref inout(Types[index][]) getArray(Capacity index)() inout return {
		mixin(`return _container` ~ index.stringof ~ ";");
	}

	Capacity _length = 0;		 ///< Current length.
	Capacity _capacity = 0;	   ///< Current capacity.

	void allocate(in Capacity newCapacity) @trusted
	{
		import std.experimental.allocator : makeArray;
		static foreach (const index, _; S.tupleof)
			getArray!index = allocator.makeArray!(Types[index])(newCapacity);
	}

	/** Grow storage with at least on element. */
	void grow() @trusted
	{
		// Motivation: https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
		import std.algorithm.comparison : max;
		import std.experimental.allocator : expandArray;
		const newCapacity = _capacity == 1 ? 2 : max(1, _growthP * _capacity / _growthQ);
		const expandSize = newCapacity - _capacity;
		if (_capacity is 0)
			allocate(newCapacity);
		else
			static foreach (const index, _; S.tupleof)
				allocator.expandArray(getArray!index, expandSize);
		_capacity = newCapacity;
	}

	void reserveOneExtra() {
		if (_length == _capacity)
			grow();
	}
}
alias StructArrays = SoA;

/** Reference to element in `soaPtr` at index `elementIndex`. */
private struct SoAElementRef(S)
if (is(S == struct)) /+ TODO: extend to `isAggregate!S`? +/ {
	SoA!S* soaPtr;
	size_t elementIndex;

	this(this) @disable;

	/** Access member name `memberName`. */
	auto ref opDispatch(string memberName)() @trusted return scope {
		mixin(`return ` ~ `(*soaPtr).` ~ memberName ~ `[elementIndex];`);
	}
}

/** Reference to slice in `soaPtr`. */
private struct SoASlice(S)
if (is(S == struct))			/+ TODO: extend to `isAggregate!S`? +/
{
	SoA!S* soaPtr;

	this(this) @disable;

	/** Access aggregate at `index`. */
	inout(S) opIndex(in size_t index) inout @trusted return scope {
		S s = void;
		static foreach (const memberIndex, memberSymbol; S.tupleof)
			mixin(`s.` ~ memberSymbol.stringof ~ `= (*soaPtr).getArray!` ~ memberIndex.stringof ~ `[index];`);
		return s;
	}
}

pure nothrow @safe @nogc unittest {
	import nxt.dip_traits : hasPreviewDIP1000;

	struct S { int i; float f; }

	auto x = SoA!S();

	static assert(is(typeof(x.getArray!0()) == int[]));
	static assert(is(typeof(x.getArray!1()) == float[]));

	assert(x.length == 0);

	x.insertBack(S.init);
	assert(x.length == 1);

	x ~= S.init;
	assert(x.length == 2);

	x.insertBackMembers(42, 43f);
	assert(x.length == 3);
	assert(x.i[2] == 42);
	assert(x.f[2] == 43f);

	// uses opDispatch
	assert(x[2].i == 42);
	assert(x[2].f == 43f);

	const x3 = SoA!S(3);
	assert(x3.length == 0);
	assert(x3.capacity == 3);

	/+ TODO: make foreach work +/
	// foreach (_; x[])
	// {
	// }

	static if (hasPreviewDIP1000) {
		static assert(!__traits(compiles,
								{
									ref int testScope() @safe
									{
										auto y = SoA!S(1);
										y ~= S(42, 43f);
										return y[0].i;
									}
								}));
	}
}
