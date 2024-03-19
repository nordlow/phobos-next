module nxt.unique_range;

import std.range.primitives : hasLength;

/** Unique range (slice) owning its source of `Source`.

	Copy construction is disabled, explicit copying is instead done through
	member `.dup`.
 */
struct UniqueRange(Source)
if (hasLength!Source)	   /+ TODO: use traits `isArrayContainer` checking fo +/
{
pure nothrow @safe @nogc:
	import std.range.primitives : ElementType, isBidirectionalRange;
	import std.traits : isArray;
	alias SourceRange = typeof(Source.init[]);
	alias E = ElementType!SourceRange;

	this(this) @disable;		// not intended to be copied

	/// Construct from `source`.
	this(Source source)
	{
		import std.algorithm.mutation : move;
		() @trusted { move(source, _source); } (); /+ TODO: remove `move` when compiler does it for us +/
		_sourceRange = _source[];
	}

	/// Construct from reference to `source`, used by `intoUniqueRange`.
	private this(ref Source source)
	{
		import std.algorithm.mutation : move;
		() @trusted { move(source, _source); } (); /+ TODO: remove `move` when compiler does it for us +/
		_sourceRange = _source[];
	}

	/// Is `true` if range is empty.
	bool empty() const @property @trusted
	{
		static if (!__traits(hasMember, SourceRange, "empty"))
			import std.range.primitives : empty;
		return (cast(Unqual!SourceRange)_sourceRange).empty; /+ TODO: remove cast and @trusted when SortedRange.empty is const +/
	}

	/// Returns: length of `this`.
	static if (hasLength!(typeof(Source.init[])))
		size_t length() const @property @trusted => (cast(Unqual!SourceRange)_sourceRange).length; /+ TODO: remove cast and @trusted when SortedRange.empty is const +/

	/// Front element.
	@property scope auto ref inout(E) front() inout return @trusted in(!empty)
	{
		static if (!__traits(hasMember, SourceRange, "front"))
			import std.range.primitives : front;
		return cast(inout(E))(cast(SourceRange)_sourceRange).front;
	}

	/// Pop front element.
	void popFront() in(!empty)
	{
		static if (!__traits(hasMember, SourceRange, "popFront"))
			import std.range.primitives : popFront;
		_sourceRange.popFront(); // should include check for emptyness
	}

	/// Pop front element and return it.
	E takeFront()() in(!empty)
	{
		scope(exit) popFront();
		static if (__traits(isPOD, E))
			return front;
		else
		{
			import std.algorithm.mutation : move;
			return move(front);
		}
	}

	static if (isBidirectionalRange!(typeof(Source.init[])))
	{
		/// Back element.
		@property scope auto ref inout(E) back() inout return @trusted in(!empty)
		{
			static if (!__traits(hasMember, SourceRange, "back"))
				import std.range.primitives : back;
			return cast(inout(E))(cast(SourceRange)_sourceRange).back;
		}

		/// Pop back element.
		void popBack() in(!empty)
		{
			static if (!__traits(hasMember, SourceRange, "popBack"))
				import std.range.primitives : popBack;
			_sourceRange.popBack(); // should include check for emptyness
		}

		/// Pop back element and return it.
		E takeBack()() in(!empty)
		{
			import core.internal.traits : hasElaborateDestructor;
			static if (__traits(isCopyable, E) &&
					   !hasElaborateDestructor!E)
			{
				typeof(return) value = back;
				popBack();
				return value;
			}
			else
			{
				static assert(0, "TODO: if back is an l-value move it out and return it");
				// import std.algorithm.mutation : move;
				// import core.internal.traits : Unqual;
				/+ TODO: reinterpret as typeof(*(cast(Unqual!E*)(&_source[_backIx]))) iff `E` doesn't contain any immutable indirections +/
				// typeof(return) value = move(_sourceRange.back);
				// popBack();
				// return value;
			}
		}
		alias stealBack = takeBack;
	}

	/// Returns: shallow duplicate of `this`.
	static if (__traits(hasMember, Source, "dup"))
		@property typeof(this) dup()() const => typeof(return)(_source.dup);

private:
	Source _source; // typically a non-reference counted container type with disable copy construction
	SourceRange _sourceRange;
}

/** Returns: A range of `Source` that owns its `source` (data container).
	Similar to Rust's `into_iter`.
 */
UniqueRange!Source intoUniqueRange(Source)(Source source)
	=> typeof(return)(source); // construct from reference

/// A generator is a range which owns its state (typically a non-reference counted container).
alias intoGenerator = intoUniqueRange;

/// basics
pure nothrow @safe @nogc unittest {
	import std.experimental.allocator.mallocator : Mallocator;
	import nxt.container.dynamic_array : DA = DynamicArray;
	import std.traits : isIterable;
	import std.range.primitives : isInputRange;
	alias C = DA!(int, Mallocator);

	auto cs = C([11, 13, 15, 17].s).intoUniqueRange;
	auto cs2 = C([11, 13, 15, 17].s).intoUniqueRange;
	// TODO: instead use auto cs2 = cs.dupShallow;

	assert(cs !is cs2);

	assert(cs == cs2);
	cs2.popFront();
	assert(cs2.length == 3);
	assert(cs != cs2);

	static assert(isInputRange!(typeof(cs)));
	static assert(isIterable!(typeof(cs)));

	assert(!cs.empty);
	assert(cs.length == 4);
	assert(cs.front == 11);
	assert(cs.back == 17);

	cs.popFront();
	assert(cs.length == 3);
	assert(cs.front == 13);
	assert(cs.back == 17);

	cs.popBack();
	assert(cs.length == 2);
	assert(cs.front == 13);
	assert(cs.back == 15);

	assert(cs.takeFront() == 13);
	assert(cs.length == 1);
	assert(cs.front == 15);
	assert(cs.back == 15);

	assert(cs.takeBack() == 15);
	assert(cs.length == 0);
	assert(cs.empty);
}

/// combined with Phobos ranges
pure nothrow @safe unittest {
	import std.experimental.allocator.mallocator : Mallocator;
	import nxt.container.dynamic_array : DA = DynamicArray;
	alias C = DA!(int, Mallocator);
	assert(C([11, 13, 15, 17].s)
		   .intoUniqueRange()
		   .filterUnique!(_ => _ != 11)
		   .mapUnique!(_ => 2*_)
		   .equal([2*13, 2*15, 2*17]));
}

import std.functional : unaryFun;

template mapUnique(fun...)
if (fun.length >= 1)
{
	import std.algorithm.mutation : move;
	import std.range.primitives : isInputRange, ElementType;
	import core.internal.traits : Unqual;

	auto mapUnique(Range)(Range r)
	if (isInputRange!(Unqual!Range))
	{
		import std.meta : AliasSeq, staticMap;

		alias RE = ElementType!(Range);
		static if (fun.length > 1)
		{
			import std.functional : adjoin;
			import std.meta : staticIndexOf;

			alias _funs = staticMap!(unaryFun, fun);
			alias _fun = adjoin!_funs;

			// Once DMD issue #5710 is fixed, this validation loop can be moved into a template.
			foreach (f; _funs)
				static assert(!is(typeof(f(RE.init)) == void),
					"Mapping function(s) must not return void: " ~ _funs.stringof);
		}
		else
		{
			alias _fun = unaryFun!fun;
			alias _funs = AliasSeq!(_fun);

			// Do the validation separately for single parameters due to DMD issue #15777.
			static assert(!is(typeof(_fun(RE.init)) == void),
				"Mapping function(s) must not return void: " ~ _funs.stringof);
		}

		return MapUniqueResult!(_fun, Range)(move(r));
	}
}

private struct MapUniqueResult(alias fun, Range)
{
	import core.internal.traits : Unqual;
	import std.range.primitives : isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange, isInfinite, hasSlicing;
	import std.algorithm.mutation : move;

	alias R = Unqual!Range;
	R _input;

	this(R input)
	{
		_input = move(input); /+ TODO: remove `move` when compiler does it for us +/
	}

	static if (isInfinite!R)
		enum bool empty = false; ///< Propagate infinite-ness.
	else
		@property bool empty() => _input.empty;

	auto ref front() @property in(!empty) => fun(_input.front);
	void popFront() in(!empty) => _input.popFront();

	static if (isBidirectionalRange!R)
	{
		auto ref back()() @property in(!empty) => fun(_input.back);
		void popBack()() in(!empty) => _input.popBack();
	}

	static if (isRandomAccessRange!R)
	{
		static if (is(typeof(_input[ulong.max])))
			private alias opIndex_t = ulong;
		else
			private alias opIndex_t = uint;
		auto ref opIndex(opIndex_t index) => fun(_input[index]);
	}

	static if (hasLength!R)
	{
		@property auto length() => _input.length;
		alias opDollar = length;
	}

	static if (hasSlicing!R &&
			   __traits(isCopyable, R))
	{
		static if (is(typeof(_input[ulong.max .. ulong.max])))
			private alias opSlice_t = ulong;
		else
			private alias opSlice_t = uint;
		static if (hasLength!R)
			auto opSlice(opSlice_t low, opSlice_t high) => typeof(this)(_input[low .. high]);
		else static if (is(typeof(_input[opSlice_t.max .. $])))
		{
			struct DollarToken{}
			enum opDollar = DollarToken.init;
			auto opSlice(opSlice_t low, DollarToken) => typeof(this)(_input[low .. $]);
			import std.range : takeExactly;
			auto opSlice(opSlice_t low, opSlice_t high) => this[low .. $].takeExactly(high - low);
		}
	}

	static if (isForwardRange!R &&
			   __traits(isCopyable, R))	/+ TODO: should save be allowed for non-copyable? +/
		@property auto save() => typeof(this)(_input.save);
}

/+ TODO: Add duck-typed interface that shows that result is still sorted according to `predicate` +/
template filterUnique(alias predicate)
if (is(typeof(unaryFun!predicate)))
{
	import std.algorithm.mutation : move;
	import std.range.primitives : isInputRange;
	import core.internal.traits : Unqual;
	auto filterUnique(Range)(Range range)
	if (isInputRange!(Unqual!Range))
		=> FilterUniqueResult!(unaryFun!predicate, Range)(move(range));
}

/+ TODO: Add duck-typed interface that shows that result is still sorted according to `predicate` +/
private struct FilterUniqueResult(alias pred, Range)
{
	import std.algorithm.mutation : move;
	import std.range.primitives : isForwardRange, isInfinite;
	import core.internal.traits : Unqual;
	alias R = Unqual!Range;
	R _input;

	this(R r)
	{
		_input = move(r);	   /+ TODO: remove `move` when compiler does it for us +/
		while (!_input.empty && !pred(_input.front))
			_input.popFront();
	}

	static if (__traits(isCopyable, Range))
		auto opSlice() => this;

	static if (isInfinite!Range)
		enum bool empty = false;
	else
		bool empty() @property => _input.empty;

	void popFront()
	{
		do
			_input.popFront();
		while (!_input.empty && !pred(_input.front));
	}

	auto ref front() @property in(!empty) => _input.front;

	static if (isForwardRange!R &&
			   __traits(isCopyable, R)) /+ TODO: should save be allowed for non-copyable? +/
		auto save() @property => typeof(this)(_input.save);
}

/+ TODO: move these hidden behind template defs of takeUnique +/
import core.internal.traits : Unqual;
import std.range.primitives : isInputRange, isInfinite, hasSlicing;

/// Unique take.
UniqueTake!R takeUnique(R)(R input, size_t n)
	if (is(R T == UniqueTake!T))
{
	import std.algorithm.mutation : move;
	import std.algorithm.comparison : min;
	return R(move(input.source), /+ TODO: remove `move` when compiler does it for us +/
			 min(n, input._maxAvailable));
}

/// ditto
UniqueTake!(R) takeUnique(R)(R input, size_t n)
if (isInputRange!(Unqual!R) &&
	(isInfinite!(Unqual!R) ||
	 !hasSlicing!(Unqual!R) &&
	 !is(R T == UniqueTake!T)))
{
	import std.algorithm.mutation : move;
	return UniqueTake!R(move(input), n); /+ TODO: remove `move` when compiler does it for us +/
}

struct UniqueTake(Range)
if (isInputRange!(Unqual!Range) &&
	//take _cannot_ test hasSlicing on infinite ranges, because hasSlicing uses
	//take for slicing infinite ranges.
	!((!isInfinite!(Unqual!Range) && hasSlicing!(Unqual!Range)) || is(Range T == UniqueTake!T)))
{
	import std.range.primitives : isForwardRange, hasAssignableElements, ElementType, hasMobileElements, isRandomAccessRange, moveFront;

	private alias R = Unqual!Range;

	/// User accessible in read and write
	public R source;

	private size_t _maxAvailable;

	alias Source = R;

	this(R source, size_t _maxAvailable)
	{
		import std.algorithm.mutation : move;
		this.source = move(source);
		this._maxAvailable = _maxAvailable;
	}

	/// Range primitives
	bool empty() @property => _maxAvailable == 0 || source.empty;

	/// ditto
	auto ref front() @property in(!empty) => source.front;

	/// ditto
	void popFront() in(!empty)
	{
		source.popFront();
		--_maxAvailable;
	}

	static if (isForwardRange!R)
		/// ditto
		UniqueTake save() @property => UniqueTake(source.save, _maxAvailable);

	static if (hasAssignableElements!R)
		/// ditto
		@property auto front(ElementType!R v)
		in(!empty, "Attempting to assign to the front of an empty " ~ UniqueTake.stringof)
		{
			// This has to return auto instead of void because of Bug 4706.
			source.front = v;
		}

	// static if (hasMobileElements!R)
	// {
	//	 /// ditto
	//	 auto moveFront()
	//	 {
	//		 assert(!empty,
	//			 "Attempting to move the front of an empty "
	//			 ~ UniqueTake.stringof);
	//		 return source.moveFront();
	//	 }
	// }

	static if (isInfinite!R)
	{
		/// ditto
		@property size_t length() const => _maxAvailable;
		/// ditto
		alias opDollar = length;

		//Note: Due to UniqueTake/hasSlicing circular dependency,
		//This needs to be a restrained template.
		/// ditto
		auto opSlice()(size_t i, size_t j)
		if (hasSlicing!R)
		in(i <= j, "Invalid slice bounds")
		in(j <= length, "Attempting to slice past the end of a " ~ UniqueTake.stringof)
			=> source[i .. j];
	}
	else static if (hasLength!R)
	{
		/// ditto
		@property size_t length()
		{
			import std.algorithm.comparison : min;
			return min(_maxAvailable, source.length);
		}
		alias opDollar = length;
	}

	static if (isRandomAccessRange!R)
	{
		/// ditto
		void popBack()
		in(!empty, "Attempting to popBack() past the beginning of a " ~ UniqueTake.stringof)
		{
			--_maxAvailable;
		}

		/// ditto
		@property auto ref back()
		in(!empty, "Attempting to fetch the back of an empty " ~ UniqueTake.stringof)
			=> source[this.length - 1];

		/// ditto
		auto ref opIndex(size_t index)
		in(index < length, "Attempting to index out of the bounds of a " ~ UniqueTake.stringof)
			=> source[index];

		static if (hasAssignableElements!R)
		{
			/// ditto
			@property auto back(ElementType!R v)
			in(!empty, "Attempting to assign to the back of an empty " ~ UniqueTake.stringof)
			{
				// This has to return auto instead of void because of Bug 4706.
				source[this.length - 1] = v;
			}

			/// ditto
			void opIndexAssign(ElementType!R v, size_t index)
			in(index < length, "Attempting to index out of the bounds of a " ~ UniqueTake.stringof)
			{
				source[index] = v;
			}
		}

		static if (hasMobileElements!R)
		{
			/// ditto
			auto moveBack()
			in(!empty, "Attempting to move the back of an empty " ~ UniqueTake.stringof)
				=> source.moveAt(this.length - 1);

			/// ditto
			auto moveAt(size_t index)
			in(index < length, "Attempting to index out of the bounds of a " ~ UniqueTake.stringof)
				=> source.moveAt(index);
		}
	}

	/**
	Access to maximal length of the range.
	Note: the actual length of the range depends on the underlying range.
	If it has fewer elements, it will stop before lengthMax is reached.
	*/
	@property size_t lengthMax() const => _maxAvailable;
}

/// array range
pure nothrow @safe @nogc unittest {
	import std.experimental.allocator.mallocator : Mallocator;
	import nxt.container.dynamic_array : DA = DynamicArray;
	import std.traits : isIterable;
	import std.range.primitives : isInputRange;
	alias C = DA!(int, Mallocator);

	auto cs = C([11, 13].s).intoUniqueRange;

	alias CS = typeof(cs);
	static assert(isInputRange!(typeof(cs)));
	static assert(isIterable!(typeof(cs)));

	assert(cs.front == 11);
	cs.popFront();

	assert(cs.front == 13);
	cs.popFront();

	assert(cs.empty);
}

import std.functional : binaryFun;

InputRange findUnique(alias pred = "a == b", InputRange, Element)(InputRange haystack, scope Element needle)
if (isInputRange!InputRange &&
	is (typeof(binaryFun!pred(haystack.front, needle)) : bool))
{
	for (; !haystack.empty; haystack.popFront())
		if (binaryFun!pred(haystack.front, needle))
			break;
	import std.algorithm.mutation : move;
	return move(haystack);
}

version (unittest)
{
	import nxt.array_help : s;
	import nxt.debugio : dbg;
	import nxt.algorithm.comparison : equal;
}

version (unittest) {
	import nxt.construction : dupShallow;
}
