/** Extensions to std.range.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module nxt.range_ex;

import core.internal.traits: hasElaborateDestructor;
import std.traits : isSomeString, isNarrowString;
import std.range: hasSlicing, hasLength, isInfinite, isInputRange, isBidirectionalRange, ElementType, isRandomAccessRange, hasMobileElements;
import std.traits: hasUnsharedAliasing, isScalarType;

public import nxt.slicing;

enum hasPureCopy(T) = (isScalarType!T || /+ TODO: remove? +/
					   (!hasUnsharedAliasing!T &&
						!hasElaborateDestructor!T));

enum hasStealableElements(R) = (hasPureCopy!(ElementType!R)); /+ TODO: recurse +/
/* template hasStealableElements(T...) */
/* { */
/*	 import std.range: ElementType; */
/*	 import std.typecons : Rebindable; */

/*	 static if (is(ElementType!T)) */
/*	 { */
/*		 enum hasStealableElements = true; */
/*	 } */
/*	 else static if (is(T[0] R: Rebindable!R)) */
/*	 { */
/*		 enum hasStealableElements = hasStealableElements!R; */
/*	 } */
/*	 else */
/*	 { */
/*		 template unsharedDelegate(T) */
/*		 { */
/*			 enum bool unsharedDelegate = isDelegate!T */
/*			 && !is(T == shared) */
/*			 && !is(T == shared) */
/*			 && !is(T == immutable) */
/*			 && !is(FunctionTypeOf!T == shared) */
/*			 && !is(FunctionTypeOf!T == immutable); */
/*		 } */

/*		 enum hasStealableElements = */
/*		 hasRawUnsharedAliasing!(T[0]) || */
/*		 anySatisfy!(unsharedDelegate, RepresentationTypeTuple!(T[0])) || */
/*		 hasUnsharedObjects!(T[0]) || */
/*		 hasStealableElements!(T[1..$]); */
/*	 } */
/* } */

/** Take/Steal front from $(D r) destructively and return it.
 *
 * See_Also: http://forum.dlang.org/thread/jkbhlezbcrufowxtthmy@forum.dlang.org#post-konhvblwbmpdrbeqhyuv:40forum.dlang.org
 * See_Also: http://forum.dlang.org/thread/onibkzepudfisxtrigsi@forum.dlang.org#post-dafmzroxvaeejyxrkbon:40forum.dlang.org
 * See_Also: https://forum.dlang.org/thread/arufovtvoewhyfuesvco@forum.dlang.org
 */
ElementType!R takeFront(R)(ref R r)
if (isInputRange!R &&
	hasMobileElements!R)
{
	import std.range.primitives : moveFront, popFront;
	scope(exit) r.popFront();
	return r.moveFront();
}

version (unittest)
{
	import nxt.array_help : s;
}

pure nothrow @safe unittest {
	auto x = [11, 22];
	assert(x.takeFront() == 11); assert(x == [22]);
	assert(x.takeFront() == 22); assert(x == []);
}

pure nothrow @safe unittest {
	auto x = ["a", "b"];
	assert(x.takeFront() == "a"); assert(x == ["b"]);
}

pure nothrow @safe unittest {
	struct V { int x, y; }
	auto x = [V(11, 12),
			  V(21, 22)];
	assert(x.takeFront() == V(11, 12)); assert(x == [V(21, 22)]);
	assert(x.takeFront() == V(21, 22)); assert(x == []);
}

ElementType!R* frontPtr(R)(R r) @system
if (isInputRange!R)
{
	import std.range.primitives: empty, front;
	if (r.empty)
		return typeof(return).init;
	return &(r.front);
}

@trusted pure unittest {
	auto x = [11, 22];
	if (auto y = x.frontPtr)
	{
		static assert(is(typeof(y) == int*));
		assert(*y == 11);
	}
}

@trusted pure unittest {
	const x = [11, 22];
	if (auto y = x.frontPtr)
	{
		static assert(is(typeof(y) == const(int)*));
		assert(*y == 11);
	}
}

/** Take/Steal back from $(D r) destructively and return it.
 *
 * See_Also: http://forum.dlang.org/thread/jkbhlezbcrufowxtthmy@forum.dlang.org#post-konhvblwbmpdrbeqhyuv:40forum.dlang.org
 * See_Also: http://forum.dlang.org/thread/onibkzepudfisxtrigsi@forum.dlang.org#post-dafmzroxvaeejyxrkbon:40forum.dlang.org
 * See_Also: https://forum.dlang.org/thread/arufovtvoewhyfuesvco@forum.dlang.org
*/
ElementType!R takeBack(R)(ref R r)
if (isBidirectionalRange!R &&
	hasMobileElements!R)
{
	import std.range.primitives : moveBack, popBack;
	scope(exit) r.popBack();
	return r.moveBack();
}

pure nothrow @safe unittest {
	auto x = [11, 22];
	assert(x.takeBack() == 22); assert(x == [11]);
	assert(x.takeBack() == 11); assert(x == []);
}

pure nothrow @safe unittest {
	auto x = ["a", "b"];
	assert(x.takeBack() == "b"); assert(x == ["a"]);
}

pure nothrow @safe unittest {
	struct V { int x, y; }
	auto x = [V(11, 12),
			  V(21, 22)];
	assert(x.takeBack() == V(21, 22)); assert(x == [V(11, 12)]);
	assert(x.takeBack() == V(11, 12)); assert(x == []);
}

/** Sliding Splitter.
 *
 * See_Also: http://forum.dlang.org/thread/dndicafxfubzmndehzux@forum.dlang.org
 * See_Also: http://forum.dlang.org/thread/uzrbmjonrkixojzflbig@forum.dlang.org#epost-viwkavbmwouiquoqwntm:40forum.dlang.org
 *
 * TODO: Use size_t for _lower and _upper instead and reserve _upper = size_t.max
 * for emptyness?
 *
 * TODO: Should lower and upper operate on code units instead of code point if
 * isNarrowString!Range. ?
 *
 * TODO: generalize with stride
 */
struct SlidingSplitter(Range)
if (isSomeString!Range ||
	(hasSlicing!Range &&
	 !isInfinite!Range))
{
	import std.range: isForwardRange;
	import core.internal.traits : Unqual;
	import std.typecons : Tuple, tuple;
	alias R = Unqual!Range;

	this(R)(R data, size_t lower = 0)
	in (lower <= data.length)
	{
		_data = data;
		static if (hasSlicing!Range) /+ TODO: should we use isSomeString here instead? +/
		{
			_lower = lower;
			_upper = data.length;
		}
		else
		{
			while (lower)
			{
				popFront();
				--lower;
			}
		}
		_upper = data.length;
	}

	this(R)(R data, size_t lower, size_t upper)
	in (lower <= upper + 1 || // the extra + 1 makes empty initialization (lower + 1 == upper) possible in for example opSlice below
		((lower <= data.length) &&
		 (upper <= data.length)))
	{
		_data = data;
		_lower = lower;
		_upper = upper;
	}

	@property Tuple!(R, R) front() => typeof(return)(_data[0 .. _lower],
													 _data[_lower .. $]);

	void popFront()
	{
		static if (isNarrowString!R)
		{
			import std.utf: stride;
			if (_lower < _upper)
				_lower += stride(_data, _lower);
			else				// when we can't decode beyond
				++_lower; // so just indicate we're beyond back
		}
		else
			++_lower;
	}

	static if (!isInfinite!R)
	{
		@property Tuple!(R, R) back() => typeof(return)(_data[0 .. _upper],
														_data[_upper .. $]);

		void popBack()
		{
			static if (isNarrowString!R)
			{
				import std.utf: strideBack;
				if (_lower < _upper)
					_upper -= strideBack(_data, _upper);
				else				// when we can't decode beyond
					--_upper; // so just indicate we're beyond front
			}
			else
				--_upper;
		}
	}

	static if (isForwardRange!R)
	{
		@property auto save()
		{
			import std.range: save;
			return typeof(this)(_data.save, _lower, _upper);
		}
	}

	static if (isInfinite!R)
		enum bool empty = false;  // propagate infiniteness
	else
	{
		bool empty() const @property => _upper < _lower;
	}

	static if (hasSlicing!R)
	{
		Tuple!(R, R) opIndex(size_t i) in (i < length) => typeof(return)(_data[0 .. _lower + i],
																		 _data[_lower + i .. _upper]);

		typeof(this) opSlice(size_t lower, size_t upper)
		{
			if (lower == upper)
				return slidingSplitter(_data,
									   _upper + 1, // defines empty intialization
									   _upper);
			else
				return slidingSplitter(_data,
									   _lower + lower,
									   _lower + (upper - 1));
		}

		/+ TODO: Should length be provided if isNarrowString!Range? +/
		@property size_t length() const => _upper - _lower + 1;
	}

	private R _data;
	private ptrdiff_t _lower;
	private ptrdiff_t _upper;
}

auto slidingSplitter(R)(R data, size_t lower = 0)
	=> SlidingSplitter!R(data, lower, data.length);

auto slidingSplitter(R)(R data, size_t lower, size_t upper)
	=> SlidingSplitter!R(data, lower, upper);

pure nothrow @safe unittest {
	import std.typecons : tuple;
	import std.conv: to;

	auto x = [1, 2, 3];

	import std.range: isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange;

	static assert(isInputRange!(SlidingSplitter!(typeof(x))));
	static assert(isForwardRange!(SlidingSplitter!(typeof(x))));
	// static assert(isBidirectionalRange!(SlidingSplitter!(typeof(x))));
	static assert(isRandomAccessRange!(SlidingSplitter!(typeof(x))));
	static assert(!isRandomAccessRange!(SlidingSplitter!string));
	static assert(!isRandomAccessRange!(SlidingSplitter!wstring));
	static assert(isRandomAccessRange!(SlidingSplitter!dstring));

	auto y = SlidingSplitter!(typeof(x))(x);

	for (size_t i; i < y.length; ++i)
	{
		assert(y[i] == tuple(x[0 .. i],
							 x[i .. 3]));
	}

	assert(y.front == tuple([], x));
	assert(!y.empty);
	assert(x.length + 1 == y.length);

	assert(!y.empty); assert(y.front == tuple(x[0 .. 0], x[0 .. 3])); y.popFront();
	assert(!y.empty); assert(y.front == tuple(x[0 .. 1], x[1 .. 3])); y.popFront();
	assert(!y.empty); assert(y.front == tuple(x[0 .. 2], x[2 .. 3])); y.popFront();
	assert(!y.empty); assert(y.front == tuple(x[0 .. 3], x[3 .. 3])); y.popFront();
	y.popFront(); assert(y.empty);
}

pure @safe unittest						// forwards
{
	import std.conv: to;

	size_t lower = 2;

	const name = "Nordlöw";
	auto name8  = name.to! string.slidingSplitter(lower);
	auto name16 = name.to!wstring.slidingSplitter(lower);
	auto name32 = name.to!dstring.slidingSplitter(lower);

	static assert(!__traits(compiles, { name8.length >= 0; } ));
	static assert(!__traits(compiles, { name16.length >= 0; } ));
	assert(name32.length);

	foreach (ch; name8)
	{
		static foreach (ix; 0 .. ch.length) // for each part in split
		{
			import std.algorithm: equal;
			assert(ch[ix].equal(name16.front[ix]));
			assert(ch[ix].equal(name32.front[ix]));

		}
		name16.popFront();
		name32.popFront();
	}
}

pure @safe unittest						// backwards
{
	import std.conv: to;
	import std.range: retro;

	size_t lower = 2;

	auto name = "Nordlöw";
	auto name8  = name.to! string.slidingSplitter(lower).retro;
	auto name16 = name.to!wstring.slidingSplitter(lower).retro;
	auto name32 = name.to!dstring.slidingSplitter(lower).retro;

	foreach (ch; name8)
	{
		import std.algorithm: equal;
		static foreach (ix; 0 .. ch.length) // for each part in split
		{
			assert(ch[ix].equal(name16.front[ix]));
			assert(ch[ix].equal(name32.front[ix]));
		}
		name16.popFront();
		name32.popFront();
	}
}

pure nothrow @safe unittest						// radial
{
	auto x = [1, 2, 3];
	import std.range: radial;
	import std.typecons : tuple;
	auto s = x.slidingSplitter;
	auto r = s.radial;
	assert(!r.empty); assert(r.front == tuple(x[0 .. 1], x[1 .. 3])); r.popFront();
	assert(!r.empty); assert(r.front == tuple(x[0 .. 2], x[2 .. 3])); r.popFront();
	assert(!r.empty); assert(r.front == tuple(x[0 .. 0], x[0 .. 3])); r.popFront();
	assert(!r.empty); assert(r.front == tuple(x[0 .. 3], x[3 .. 3])); r.popFront();
	assert(r.empty);
}

/** Ring Buffer.
 *
 * See_Also: http://forum.dlang.org/thread/ltpaqk$2dav$1@digitalmars.com
 * TODO: inout
 */
struct RingBuffer(T)
{
	this(T[] data, size_t length = 0)
	{
		enforce(data.length, "empty ring buffer is prohibited");
		enforce(length <= data.length, "buffer length shall not be more
than buffer capacity");
		_data = data;
		_beginIndex = 0;
		_length = length;
	}

	auto opSlice() const => cycle(_data[0 .. _length]).take(_length);

	@property auto length() => _length;

private:
	T[] _data;
	size_t _beginIndex;
	size_t _length;
}

/** Same as $(D iota) but with explicit conversion to type $(D T).
	See_Also: http://forum.dlang.org/thread/mailman.955.1444358510.22025.digitalmars-d@puremagic.com?page=1
*/
auto iotaOf(T, B, E, S)(B begin = T.min,
						E end = T.max,
						S step = 1)
{
	import std.range : iota;
	import std.algorithm.iteration : map;
	import std.conv : to;
	return iota(begin, end, step).map!(a => cast(T)a);
}

// pure @safe unittest
// {
//	 import std.array : array;
//	 import std.exception : assertThrown;
//	 import std.meta : AliasSeq;
//	 foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
//	 {
//		 auto x = iotaOf!T(0, T.max + 1);
//		 import nxt.traits_ex : ElementTypeOf;
//		 static assert(is(ElementTypeOf!(x) == T));
//	 }
// }

auto iotaOfExceptional(T, B, E, S)(B begin = T.min, E end = T.max, S step = 1)
{
	import std.range : iota;
	import std.algorithm.iteration : map;
	import std.conv : to;
	return iota(begin, end, step).map!(a => a.to!T);
}

// pure @safe unittest
// {
//	 import std.array : array;
//	 import std.exception : assertThrown;
//	 import std.conv;
//	 alias T = ubyte;
//	 auto x = iotaOfExceptional!T(0, T.max + 1);
//	 import nxt.traits_ex : ElementTypeOf;
//	 static assert(is(ElementTypeOf!() == T));
//	 assertThrown!ConvOverflowException(iotaOfExceptional!T(0, T.max + 1 + 1).array);
// }

/** Return Array of Key-Value Pairs of Associative Array $(D aa).
 *
 * See_Also: https://github.com/D-Programming-Language/druntime/pull/574
 * See_Also: http://forum.dlang.org/thread/dxotcrutrlmszlidufcr@forum.dlang.org?page=2#post-fhkgitmifgnompkqiscd:40forum.dlang.org
*/
auto pairs(Key, Value)(Value[Key] aa)
{
	import std.typecons: Tuple, tuple;
	Tuple!(Key,Value)[] arr;
	arr.reserve(aa.length);
	foreach (key; aa.byKey)
		arr ~= tuple(key, aa[key]);
	return arr;
}
alias items = pairs; /+ TODO: Is this Python-style naming better? +/

unittest {
	string[int] x;
	x[0] = "a";
	import std.typecons : tuple;
	assert(x.pairs == [tuple(0, "a")]);
}

import std.meta: staticMap;

/// Is the `CommonType` of the `ElementType`s of the ranges `Rs`.
template CommonElementType(Rs...)
{
	import std.traits: CommonType;
	import std.range: ElementType;
	alias CommonElementType = CommonType!(staticMap!(ElementType, Rs));
}

///
pure nothrow @safe @nogc unittest {
	static assert(is(CommonElementType!(int[], double[]) == double));
}

enum bool haveCommonElementType(Types...) = !is(CommonElementType!Types == void);

/// Is `true` iff the ranges `Rs` have a common element type.
pure nothrow @safe @nogc unittest {
	static assert(haveCommonElementType!(bool[], int[]));
	static assert(!haveCommonElementType!(bool[], int[], string[]));
}

import std.range: SortedRange;

enum isSortedRange(R) = is(R == SortedRange!(_), _);

/** True if R is a `SortedRange`
 *
 * SeeAlso:
 * `std.range.SortedRange`
 */
template isSortedRange_alt(R)
{
	import std.range.primitives : SortedRange;
	enum isSortedRange = is(R : SortedRange!U, U...);
}

///
unittest {
	import std.algorithm : sort;
	import std.range : assumeSorted;
	static assert(isSortedRange!(typeof([0, 1, 2])) == false);
	static assert(isSortedRange!(typeof([0, 1, 2].sort)) == true);
	static assert(isSortedRange!(typeof([0, 1, 2].assumeSorted)) == true);
	static assert(isSortedRange!int == false);
}

/// See_Also: http://forum.dlang.org/post/gkdqakdogqevwzntpgtu@forum.dlang.org
template genTypeList(T, size_t n)
{
	import std.meta : AliasSeq;
	static if (n <= 1)
		alias genTypeList = T;
	else
		alias genTypeList = AliasSeq!(T, genTypeList!(T, n - 1));
}

/** Return Static Array $(D arr) as a $(D Tuple).
 *
 * See_Also: http://forum.dlang.org/post/gkdqakdogqevwzntpgtu@forum.dlang.org
 * Check if std.conv.to() support conversion from T[n] to std.typecons.Tuple(T, ...).
 */
auto asTuple(T, size_t n)(ref T[n] arr)
{
	import std.typecons : Tuple;
	return Tuple!(genTypeList!(T, n))(arr);
}

/** Return: Adjacent $(D N)-Tuples of $(D r).
 *
 * TODO: Support ref return via $(D zip) for non-const case.
 * TODO: Use a ring buffer instead of copy?
 * TODO: Add a variant of adjacentTuples that return a static array instead?
 * See_Also: http://forum.dlang.org/post/gkdqakdogqevwzntpgtu@forum.dlang.org
 */
auto adjacentTuples(size_t N, R)(R r)
	if (N >= 2 &&
		isInputRange!R)
{
	struct Range(R)
	{
		import core.internal.traits : Unqual;
		import std.typecons : Tuple;
		alias E = Unqual!(ElementType!R);
		enum M = N - 1;  // temporary order
		alias P = E[M];
		alias T = Tuple!(genTypeList!(E, N)); /+ TODO: functionize +/

		this(R r)
		{
			this._source = r;
			foreach (i; 0 .. M)
				if (!empty)
					popFront();
		}

		static if (isInfinite!R)
			enum bool empty = false;  // propagate infiniteness
		else
		{
			bool empty() @property /+ TODO: can't empty be const when R is a MapResult? +/
			{
				import std.range.primitives : empty;
				return _source.empty;
			}
		}

		auto ref front() @property
		{
			import std.range.primitives : front;
			T t;
			t[0 .. M] = _prevs.asTuple;
			t[M] = _source.front;
			return t;
		}

		void popFront()
		{
			static if (N >= 3)
			{
				/+ TODO: use static foreach to do left-shifting +/

				// Need $(D copy) because $(D source) and $(D dest) may overlap.
				// See_Also: http://dlang.org/arrays.html#overlapping-copying
				import std.algorithm.mutation : copy;
				copy(_prevs[1 .. M], _prevs[0 .. M - 1]);
			}

			import std.range.primitives : front, popFront;
			_prevs[M - 1] = _source.front;
			_source.popFront();
		}

		private:
		P _prevs;
		R _source;
	}
	return Range!R(r);
}

auto adjacentPairs(R)(R r) if (isInputRange!R) => adjacentTuples!(2, R)(r);
auto adjacentTriples(R)(R r) if (isInputRange!R) => adjacentTuples!(3, R)(r);

///
pure nothrow @safe @nogc unittest {
	import std.typecons : t = tuple;
	import std.algorithm : equal, map;
	auto x = [1, 2, 3, 4, 5, 6, 7].s[].map!(a => a); // test with ForwardRange
	auto y = x.adjacentTuples!4;
	assert(y.equal([t(1, 2, 3, 4),
					t(2, 3, 4, 5),
					t(3, 4, 5, 6),
					t(4, 5, 6, 7)].s[]));
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : t = tuple;
	import std.algorithm : equal;
	immutable x = [1, 2, 3, 4].s;
	auto y = x[].adjacentPairs;
	assert(y.equal([t(1, 2), t(2, 3), t(3, 4)].s[]));
}

///
@trusted pure nothrow @nogc unittest /+ TODO: @safe +/
{
	import std.typecons : t = tuple;
	import std.algorithm : equal;
	auto x = ["1", "2", "3", "4"].s;
	auto y = x[].adjacentPairs;
	assert(y.equal([t("1", "2"), t("2", "3"), t("3", "4")].s[])); /+ TODO: @safe +/
}

///
@trusted pure nothrow @nogc unittest /+ TODO: @safe +/
{
	import std.typecons : t = tuple;
	import std.algorithm : equal;
	immutable x = ["1", "2", "3", "4"].s;
	auto y = x[].adjacentPairs;
	assert(y.equal([t("1", "2"), t("2", "3"), t("3", "4")].s[])); /+ TODO: @safe +/
}

auto rangify(T)(T range)
if (__traits(hasMember, T, "length") &&
	__traits(hasMember, T, "opIndex"))
{
	struct Range
	{
		bool empty() => _counter == range.length;
		auto front() => range[_counter];
		auto popFront() { _counter++; }
		T range;
		ulong _counter;
	}
	return Range(range);
}

struct S
{
	int[] arr;
	auto length() => arr.length;
	int opIndex(size_t i) => arr[i];
}

unittest {
	import std.algorithm : equal;
	auto s = S();
	s.arr = [1, 2, 3];
	assert(s.rangify.equal([1, 2, 3].s[]));
}

/** Overload has questionable memory safety.  Would be quite cool if DIP-1000
 * could support this use case
 *
 * See_Also: http://forum.dlang.org/post/qgrbmkqxffgeiqaigdic@forum.dlang.org
 */
auto staticLengthRange(T, size_t n)(ref T[n] arr)
	=> .staticLengthRange!(n, T[])(arr[]); /+ TODO: DIP-1000 scope +/

import std.range.primitives : hasLength, isInputRange;

auto staticLengthRange(size_t n, R)(R range)
if (isInputRange!R && hasLength!R)
{
	static struct Result
	{
		enum size_t length = n;
		R _range;
		alias _range this;
	}
	assert (range.length == n);
	return Result(range);
}


pure nothrow @safe @nogc unittest {
	import std.algorithm.iteration : map;

	int[3] sarr = [1, 2, 3];
	auto r1 = sarr.staticLengthRange;
	static assert (isInputRange!(typeof(r1)));
	static assert (r1.length == 3);

	auto arr = [1, 2, 3, 4].s;
	auto r2 = arr[].map!(a => a * 2).staticLengthRange!4;
	static assert (r2.length == 4);
}

/** Given a `SortedRange` R, `sortingPredicate!R(a, b)` will call in to the
 * predicate that was used to create the `SortedRange`.
 *
 * Params:
 *   Range = the range to extract the predicate from
 *   fallbackPred = the sorting predicate to fallback to if `Range` is not a `SortedRange`
*/
template sortingPredicate(Range, alias fallbackPred = "a < b")
if (isInputRange!Range)
{
	import std.range : SortedRange;
	import std.functional : binaryFun;
	static if (is(Range : SortedRange!P, P...))
		alias sortingPredicate = binaryFun!(P[1]);
	else
		alias sortingPredicate = binaryFun!fallbackPred;
}

///
unittest {
	import std.algorithm : sort;
	assert(sortingPredicate!(typeof([1].sort!"a < b"))(1, 2) == true);
	assert(sortingPredicate!(typeof([1].sort!"a > b"))(1, 2) == false);
	assert(sortingPredicate!(typeof([1].sort!((a, b) => a < b)))(1, 2) == true);
	assert(sortingPredicate!(typeof([1].sort!((a, b) => a > b)))(1, 2) == false);
	assert(sortingPredicate!(int[])(1, 2) == true);
}

/** Faster than std.range.zip on DMD.
 *
 * See_Also: https://forum.dlang.org/post/khvwfwvjiblobfybsurd@forum.dlang.org
 */
auto zip(R1, R2)(R1 r1, R2 r2)
if (isRandomAccessRange!R1 &&
	isRandomAccessRange!R2)
{
	import std.typecons : tuple;
	static struct Result(R1, R2)
	{
		size_t _length;

		this(R1 r1, R2 r2)
		{
			_r1 = r1;
			_r2 = r2;
			import std.algorithm.comparison : min;
			_length = min(r1.length, r2.length);
		}

		bool empty() const @property
			=> _index == _length;

		size_t length() const @property
			=> _length;

		auto front() @property in(!empty)
			=> tuple(_r1[_index],
					 _r2[_index]);

		void popFront() in(!empty)
			=> cast(void)(_index += 1);

	private:
		size_t _index = 0;
		R1 _r1;
		R2 _r2;
	}
	return Result!(R1,R2)(r1,r2);
}

pure nothrow @safe @nogc unittest {
	import nxt.array_help : s;
	import std.algorithm.comparison : equal;
	import std.typecons : tuple;
	const r1 = [1, 2, 3].s;
	const r2 = [4, 5, 6, 7].s;
	auto r12 = zip(r1[], r2[]);
	assert(r12.equal([tuple(1, 4),
					  tuple(2, 5),
					  tuple(3, 6)].s[]));
}

/// Returns: n:th element of `r`.
ElementType!R nth(R)(R r, size_t n) if (isInputRange!R)
{
	static if (is(typeof(r[n]) == typeof(return)))
		return r[n];
	else
	{
		import std.range.primitives: front, popFront;
		foreach (_; 0..n)
			r.popFront();
		return r.front();
	}
}

pure nothrow @safe unittest {
	const r = [1, 2, 3];
	assert(r.nth(0) == 1);
	assert(r.nth(1) == 2);
	assert(r.nth(2) == 3);
}
