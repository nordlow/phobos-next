/** Extend std.algorithm.setopts to also operate on set- and map-like
	containers/ranges.

	See_Also: http://forum.dlang.org/post/nvd09v$24e9$1@digitalmars.com
*/
module nxt.setops_ex;

// version = show;

/** Specialization for `std.algorithm.setopts.setUnion` for AA. */
auto setUnionUpdate(T1, T2)(T1 a, T2 b) @trusted
if (isAA!T1 &&
	isAA!T2)
{
	if (a.length < b.length)
		return setUnionHelper(a, b);
	else
		return setUnionHelper(b, a);
}

/** Helper function for `setUnionUpdate` that assumes `small` has shorter length than
	`large` .
*/
private static auto setUnionHelper(Small, Large)(const Small small, Large large)
{
	Large united = large.dup;   /+ TODO: this shallow copy prevents large from being `const` +/
	foreach (const ref e; small.byKeyValue)
	{
		if (auto hitPtr = e.key in large)
			(*hitPtr) = e.value; /+ TODO: this potentially changes the value of +/
		else
			united[e.key] = e.value;
	}
	return united;
}

/** Is `true` iff `T` is map-like container, that is provides membership
 * checking via the `in` operator or `contains`.
 *
 * TODO: Move to Phobos std.traits
 */
enum isAA(T) = __traits(isAssociativeArray, T); /+ TODO: check if in operator returns reference to value +/

/// union of associative array (via keys)
pure @safe unittest {
	alias Map = string[int];

	Map x = [0 : "a", 1 : "b"];
	Map y = [2 : "c"];

	Map c = [0 : "a", 1 : "b", 2 : "c"];

	// test associativity
	assert(setUnionUpdate(x, y) == c);
	assert(setUnionUpdate(y, x) == c);
}

import std.traits : CommonType, isAssociativeArray;
import std.range.primitives;
import std.meta : anySatisfy, allSatisfy, staticMap;
import std.functional : binaryFun;
import std.range : SearchPolicy;
import nxt.range_ex : haveCommonElementType;

private alias typeOfAAKeyValue(T) = typeof(T.init.byKeyValue);
private alias typeOfAAKey(T) = typeof(T.init.keys[0]);
private alias typeOfAAValue(T) = typeof(T.init.values[0]);

/** Intersection of two or more associative arrays of type `Ts`.
 *
 * See_Also: https://forum.dlang.org/post/puwffthbqaktlqnourrs@forum.dlang.org
 * TODO: Use switch + static foreach at https://forum.dlang.org/post/tdajgh$262i$1@digitalmars.com
 */
auto setIntersectionAA(Ts...)(Ts inputs)
if (Ts.length >= 2 &&
	allSatisfy!(isAssociativeArray, Ts) &&
	!is(CommonType!(staticMap!(typeOfAAKey, Ts)) == void) &&
	!is(CommonType!(staticMap!(typeOfAAValue, Ts)) == void))
{
	alias Ranges = staticMap!(typeOfAAKeyValue, Ts);
	alias KeyType = CommonType!(staticMap!(typeOfAAKey, Ts));
	alias ValueType = CommonType!(staticMap!(typeOfAAValue, Ts));
	struct Pair { KeyType key; ValueType value; }
	struct Result
	{
		alias E0 = typeof(Ranges[0].front);
		this(Ts inputs)
		{
			this._inputs = inputs;
			size_t lengthMin = inputs[0].length;
			static foreach (const i, input; inputs)
			{
				this._ranges[i] = input.byKeyValue;
				if (i != 0 &&
					input.length < lengthMin)
				{
					lengthMin = input.length;
					_shortestInputIndex = i;
				}
			}
			tryFindNextFront();
		}
		@property bool empty() /*TODO: const*/
		{
			final switch (_shortestInputIndex)
			{
				static foreach (i; 0 .. _ranges.length)
				{
				case i:
					return _ranges[i].empty;
				}
			}
		}
		@property /*TODO: inout*/ Pair front() /*TODO: inout*/
		{
			final switch (_shortestInputIndex)
			{
				static foreach (i; 0 .. _ranges.length)
				{
				case i:
					return typeof(return)(_ranges[i].front.key,
										  _ranges[i].front.value);
				}
			}
		}
		void popFront()
		{
			foreach (ref range; _ranges)
				range.popFront();
			tryFindNextFront();
		}
		private void tryFindNextFront()
		{
			while (!empty)
			{
				if (matchPopOtherFronts(front))
					break;
			sw:
				final switch (_shortestInputIndex)
				{
					static foreach (i; 0 .. _ranges.length)
					{
					case i:
						_ranges[i].popFront();
						break sw;
					}
				}
			}
		}
		private bool matchPopOtherFronts(scope const Pair baseFront)
		{
			typeof(return) result = true;
			static foreach (const i; 0 .. Ranges.length) /+ TODO: replace with `static foreach (range; ranges)` when possible +/
			{
				if (i != _shortestInputIndex)
				{
					if (_ranges[i].empty)
						return false;
					if (auto valuePtr = baseFront.key in inputs[i])
					{
						if (baseFront.value != *valuePtr)
						{
							_ranges[i].popFront();
							result = false;
						}
					}
					else
						result = false;
				}
			}
			return result;
		}
	private:
		Ts _inputs;
		Ranges _ranges;
		size_t _shortestInputIndex;
		invariant { assert(_shortestInputIndex < inputs.length); }
	}
	return Result(inputs);
}

///
@safe unittest {
	alias T = int[string];
	T x2   = [	   "1":1, "2":2,		"4":4];
	T x3   = ["0":0, "1":1, "2":2, "3":3, "4":4];
	T x4   = [	   "1":1, "2":2, "3":3, "4":4, "5":5];
	T xh;
	auto y = setIntersectionAA(x2, x3, x4);
	assert(y._shortestInputIndex == 0);
	xh[y.front.key] = y.front.value;
	assert(!y.empty);

	y.popFront();
	xh[y.front.key] = y.front.value;
	assert(!y.empty);

	y.popFront();
	xh[y.front.key] = y.front.value;
	assert(!y.empty);

	y.popFront();
	assert(y.empty);

	assert(xh == x2);
}

/** Intersection of two or more ranges of type `Rs`.
 *
 * See_Also: https://forum.dlang.org/post/puwffthbqaktlqnourrs@forum.dlang.org
 */
private struct SetIntersectionFast(alias less = "a < b",
								   SearchPolicy preferredSearchPolicy = SearchPolicy.gallop,
								   Rs...)
if (Rs.length >= 2 &&
	allSatisfy!(isInputRange, Rs) &&
	!anySatisfy!(isAssociativeArray, Rs) &&
	haveCommonElementType!Rs)
{
private:
	Rs _inputs;
	alias comp = binaryFun!less;
	alias ElementType = CommonType!(staticMap!(.ElementType, Rs));

	// Positions to the first elements that are all equal
	void adjustPosition()
	{
		if (empty) return;

		auto compsLeft = Rs.length; // number of compares left
		static if (Rs.length > 1) while (true)
		{
			foreach (i, ref r; _inputs)
			{
				alias next = _inputs[(i + 1) % Rs.length]; // requires copying of range

				/+ TODO: Use upperBound only when next.length / r.length > 12 +/

				import std.range.primitives : isRandomAccessRange;
				static if (allSatisfy!(isRandomAccessRange, typeof(next)))
				{
					import std.range : assumeSorted;

					/+ TODO: remove need for this hack +/
					static if (less == "a < b")
						enum lessEq = "a <= b";
					else static if (less == "a > b")
						enum lessEq = "a >= b";

					/+ TODO: can we merge thsse two lines two one single assignment from nextUpperBound to next +/
					auto nextUpperBound = next.assumeSorted!lessEq.upperBound!preferredSearchPolicy(r.front);
					next = next[$ - nextUpperBound.length .. $];

					if (next.empty)
						return; // next became empty, so everything becomes empty
					else if (next.front != r.front)
						compsLeft = Rs.length; // we need to start counting comparing again starting with next.front
				}
				else
				{
					if (comp(next.front, r.front))
					{
						do
						{
							next.popFront();
							if (next.empty) return;
						}
						while (comp(next.front, r.front));
						compsLeft = Rs.length;
					}
				}
				if (--compsLeft == 0) return; // count down, and if we have made Rs.length iterations we are compsLeft finding a common front element
			}
		}
	}

public:
	///
	this(Rs inputs)
	{
		import std.functional : forward;
		this._inputs = inputs; /+ TODO: remove `forward` when compiler does it for us +/
		// position to the first element
		adjustPosition();
	}

	///
	@property bool empty()
	{
		foreach (ref r; _inputs)
			if (r.empty)
				return true;
		return false;
	}

	///
	void popFront() in(!empty)
	{
		static if (Rs.length > 1)
			foreach (i, ref r; _inputs)
			{
				alias next = _inputs[(i + 1) % Rs.length];
				assert(!comp(r.front, next.front));
			}

		foreach (ref r; _inputs)
			r.popFront();
		adjustPosition();
	}

	///
	ElementType front() @property in(!empty) => _inputs[0].front;

	static if (allSatisfy!(isForwardRange, Rs))
	{
		///
		@property SetIntersectionFast save()
		{
			auto ret = this;
			foreach (i, ref r; _inputs)
				ret._inputs[i] = r.save;
			return ret;
		}
	}
}

import core.internal.traits : Unqual;

auto assumeMoveableSorted(alias pred = "a < b", R)(R r)
if (isInputRange!(Unqual!R))
{
	import core.lifetime : move;
	return MoveableSortedRange!(Unqual!R, pred)(move(r)); /+ TODO: remove `move` when compiler does it for us +/
}

/** Get intersection of `ranges`.
 *
 * See_Also: https://forum.dlang.org/post/puwffthbqaktlqnourrs@forum.dlang.org
 */
MoveableSortedRange!(SetIntersectionFast!(less, preferredSearchPolicy, Rs))
setIntersectionFast(alias less = "a < b",
					SearchPolicy preferredSearchPolicy = SearchPolicy.gallop,
					Rs...)(Rs ranges)
if (Rs.length >= 2 &&
	allSatisfy!(isInputRange, Rs) &&
	haveCommonElementType!Rs)
{
	/+ TODO: Remove need for these switch cases if this can be fixed: +/
	// http://forum.dlang.org/post/pknonazfniihvpicxbld@forum.dlang.org
	import std.range : assumeSorted;
	static if (Rs.length == 2)
	{
		import core.lifetime : move;
		return assumeMoveableSorted(SetIntersectionFast!(less,
														 preferredSearchPolicy,
														 Rs)(move(ranges[0]), /+ TODO: remove `move` when compiler does it for us +/
															 move(ranges[1]))); /+ TODO: remove `move` when compiler does it for us +/
	}
	else
	{
		import std.functional : forward;
		return assumeMoveableSorted(SetIntersectionFast!(less,
														 preferredSearchPolicy,
														 Rs)(forward!ranges)); /+ TODO: remove `forward` when compiler does it for us +/
	}
}

@safe unittest {
	import std.algorithm.comparison : equal;
	import std.algorithm.sorting : sort;
	import std.algorithm.setops : setIntersection;
	import nxt.random_ex : randInPlaceWithElementRange;
	import nxt.container.dynamic_array : DynamicArray;
	import nxt.algorithm_ex : collect;

	alias E = ulong;
	alias A = DynamicArray!E;

	auto a0 = A();
	auto a1 = A(1);

	enum less = "a < b";

	auto s0 = setIntersectionFast!(less)(a0[], a0[]);
	assert(s0.equal(a0[]));

	auto s1 = setIntersectionFast!(less)(a1[], a1[]);
	assert(s1.equal(a1[]));

	immutable smallTestLength = 1000;
	immutable factor = 12; // this is the magical limit on my laptop when performance of `upperBound` beats standard implementation
	immutable largeTestLength = factor*smallTestLength;
	E elementLow = 0;
	E elementHigh = 10_000_000;
	A x;
	x.length = smallTestLength;
	A y;
	y.length = largeTestLength;

	x[].randInPlaceWithElementRange(elementLow, elementHigh);
	y[].randInPlaceWithElementRange(elementLow, elementHigh);

	sort(x[]);
	sort(y[]);

	// associative
	assert(equal(setIntersectionFast!(less)(x[], y[]),
				 setIntersectionFast!(less)(y[], x[])));

	// same as current
	assert(equal(setIntersection!(less)(x[], y[]),
				 setIntersectionFast!(less)(x[], y[])));

	void testSetIntersection()
	{
		auto z = setIntersection!(less)(x[], y[]).collect!A;
	}

	void testSetIntersectionNew()
	{
		auto z = setIntersectionFast!(less)(x[], y[]).collect!A;
	}

	import std.datetime.stopwatch : benchmark;
	import core.time : Duration;
	immutable testCount = 10;
	auto r = benchmark!(testSetIntersection,
						testSetIntersectionNew)(testCount);
	version (show)
	{
		import std.stdio : writeln;
		import std.conv : to;
		writeln("old testSetIntersection: ", to!Duration(r[0]));
		writeln("new testSetIntersection: ", to!Duration(r[1]));
	}
}

pure nothrow @safe unittest {
	import std.algorithm.comparison : equal;
	enum less = "a < b";
	auto si = setIntersectionFast!(less)([1, 2, 3],
										 [1, 2, 3]);
	const sic = si.save();
	assert(si.equal([1, 2, 3]));
}

/+ TODO: remove this `MoveableSortedRange` and replace with Phobos' `SortedRange` in this buffer +/
struct MoveableSortedRange(Range, alias pred = "a < b")
if (isInputRange!Range)
{
	import std.functional : binaryFun;

	private alias predFun = binaryFun!pred;
	private bool geq(L, R)(L lhs, R rhs)
	{
		return !predFun(lhs, rhs);
	}
	private bool gt(L, R)(L lhs, R rhs)
	{
		return predFun(rhs, lhs);
	}
	private Range _input;

	// Undocummented because a clearer way to invoke is by calling
	// assumeSorted.
	this(Range input)
	out
	{
		// moved out of the body as a workaround for Issue 12661
		dbgVerifySorted();
	}
	do
	{
		import core.lifetime : move;
		this._input = move(input); // TODO
	}

	// Assertion only.
	private void dbgVerifySorted()
	{
		if (!__ctfe)
		debug
		{
			static if (isRandomAccessRange!Range && hasLength!Range)
			{
				import core.bitop : bsr;
				import std.algorithm.sorting : isSorted;

				// Check the sortedness of the input
				if (this._input.length < 2) return;

				immutable size_t msb = bsr(this._input.length) + 1;
				assert(msb > 0 && msb <= this._input.length);
				immutable step = this._input.length / msb;
				auto st = stride(this._input, step);

				assert(isSorted!pred(st), "Range is not sorted");
			}
		}
	}

	/// Range primitives.
	@property bool empty()			 //const
	{
		return this._input.empty;
	}

	/// Ditto
	static if (isForwardRange!Range)
	@property auto save()
	{
		// Avoid the constructor
		typeof(this) result = this;
		result._input = _input.save;
		return result;
	}

	/// Ditto
	@property auto ref front()
	{
		return _input.front;
	}

	/// Ditto
	void popFront()
	{
		_input.popFront();
	}

	/// Ditto
	static if (isBidirectionalRange!Range)
	{
		@property auto ref back()
		{
			return _input.back;
		}

		/// Ditto
		void popBack()
		{
			_input.popBack();
		}
	}

	/// Ditto
	static if (isRandomAccessRange!Range)
		auto ref opIndex(size_t i)
		{
			return _input[i];
		}

	/// Ditto
	static if (hasSlicing!Range)
		auto opSlice(size_t a, size_t b)
		{
			assert(
				a <= b,
				"Attempting to slice a SortedRange with a larger first argument than the second."
			);
			typeof(this) result = this;
			result._input = _input[a .. b];// skip checking
			return result;
		}

	/// Ditto
	static if (hasLength!Range)
	{
		@property size_t length()		  //const
		{
			return _input.length;
		}
		alias opDollar = length;
	}

/**
   Releases the controlled range and returns it.
*/
	auto release()
	{
		import core.lifetime : move;
		return move(_input);
	}

	// Assuming a predicate "test" that returns 0 for a left portion
	// of the range and then 1 for the rest, returns the index at
	// which the first 1 appears. Used internally by the search routines.
	private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
	if (sp == SearchPolicy.binarySearch && isRandomAccessRange!Range && hasLength!Range)
	{
		size_t first = 0, count = _input.length;
		while (count > 0)
		{
			immutable step = count / 2, it = first + step;
			if (!test(_input[it], v))
			{
				first = it + 1;
				count -= step + 1;
			}
			else
				count = step;
		}
		return first;
	}

	// Specialization for trot and gallop
	private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
	if ((sp == SearchPolicy.trot || sp == SearchPolicy.gallop)
		&& isRandomAccessRange!Range)
	{
		if (empty || test(front, v)) return 0;
		immutable count = length;
		if (count == 1) return 1;
		size_t below = 0, above = 1, step = 2;
		while (!test(_input[above], v))
		{
			// Still too small, update below and increase gait
			below = above;
			immutable next = above + step;
			if (next >= count)
			{
				// Overshot - the next step took us beyond the end. So
				// now adjust next and simply exit the loop to do the
				// binary search thingie.
				above = count;
				break;
			}
			// Still in business, increase step and continue
			above = next;
			static if (sp == SearchPolicy.trot)
				++step;
			else
				step <<= 1;
		}
		return below + this[below .. above].getTransitionIndex!(
			SearchPolicy.binarySearch, test, V)(v);
	}

	// Specialization for trotBackwards and gallopBackwards
	private size_t getTransitionIndex(SearchPolicy sp, alias test, V)(V v)
	if ((sp == SearchPolicy.trotBackwards || sp == SearchPolicy.gallopBackwards)
		&& isRandomAccessRange!Range)
	{
		immutable count = length;
		if (empty || !test(back, v)) return count;
		if (count == 1) return 0;
		size_t below = count - 2, above = count - 1, step = 2;
		while (test(_input[below], v))
		{
			// Still too large, update above and increase gait
			above = below;
			if (below < step)
			{
				// Overshot - the next step took us beyond the end. So
				// now adjust next and simply fall through to do the
				// binary search thingie.
				below = 0;
				break;
			}
			// Still in business, increase step and continue
			below -= step;
			static if (sp == SearchPolicy.trot)
				++step;
			else
				step <<= 1;
		}
		return below + this[below .. above].getTransitionIndex!(
			SearchPolicy.binarySearch, test, V)(v);
	}

// lowerBound
/**
   This function uses a search with policy $(D sp) to find the
   largest left subrange on which $(D pred(x, value)) is `true` for
   all $(D x) (e.g., if $(D pred) is "less than", returns the portion of
   the range with elements strictly smaller than `value`). The search
   schedule and its complexity are documented in
   $(LREF SearchPolicy).  See_Also: STL's
   $(HTTP sgi.com/tech/stl/lower_bound.html, lower_bound).
*/
	auto lowerBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
	if (isTwoWayCompatible!(predFun, ElementType!Range, V)
		 && hasSlicing!Range)
	{
		return this[0 .. getTransitionIndex!(sp, geq)(value)];
	}

// upperBound
/**
This function searches with policy $(D sp) to find the largest right
subrange on which $(D pred(value, x)) is `true` for all $(D x)
(e.g., if $(D pred) is "less than", returns the portion of the range
with elements strictly greater than `value`). The search schedule
and its complexity are documented in $(LREF SearchPolicy).

For ranges that do not offer random access, $(D SearchPolicy.linear)
is the only policy allowed (and it must be specified explicitly lest it exposes
user code to unexpected inefficiencies). For random-access searches, all
policies are allowed, and $(D SearchPolicy.binarySearch) is the default.

See_Also: STL's $(HTTP sgi.com/tech/stl/lower_bound.html,upper_bound).
*/
	auto upperBound(SearchPolicy sp = SearchPolicy.binarySearch, V)(V value)
	if (isTwoWayCompatible!(predFun, ElementType!Range, V))
	{
		static assert(hasSlicing!Range || sp == SearchPolicy.linear,
			"Specify SearchPolicy.linear explicitly for "
			~ typeof(this).stringof);
		static if (sp == SearchPolicy.linear)
		{
			for (; !_input.empty && !predFun(value, _input.front);
				 _input.popFront())
			{
			}
			return this;
		}
		else
		{
			return this[getTransitionIndex!(sp, gt)(value) .. length];
		}
	}


// equalRange
/**
   Returns the subrange containing all elements $(D e) for which both $(D
   pred(e, value)) and $(D pred(value, e)) evaluate to $(D false) (e.g.,
   if $(D pred) is "less than", returns the portion of the range with
   elements equal to `value`). Uses a classic binary search with
   interval halving until it finds a value that satisfies the condition,
   then uses $(D SearchPolicy.gallopBackwards) to find the left boundary
   and $(D SearchPolicy.gallop) to find the right boundary. These
   policies are justified by the fact that the two boundaries are likely
   to be near the first found value (i.e., equal ranges are relatively
   small). Completes the entire search in $(BIGOH log(n)) time. See also
   STL's $(HTTP sgi.com/tech/stl/equal_range.html, equal_range).
*/
	auto equalRange(V)(V value)
	if (isTwoWayCompatible!(predFun, ElementType!Range, V)
		&& isRandomAccessRange!Range)
	{
		size_t first = 0, count = _input.length;
		while (count > 0)
		{
			immutable step = count / 2;
			auto it = first + step;
			if (predFun(_input[it], value))
			{
				// Less than value, bump left bound up
				first = it + 1;
				count -= step + 1;
			}
			else if (predFun(value, _input[it]))
			{
				// Greater than value, chop count
				count = step;
			}
			else
			{
				// Equal to value, do binary searches in the
				// leftover portions
				// Gallop towards the left end as it's likely nearby
				immutable left = first
					+ this[first .. it]
					.lowerBound!(SearchPolicy.gallopBackwards)(value).length;
				first += count;
				// Gallop towards the right end as it's likely nearby
				immutable right = first
					- this[it + 1 .. first]
					.upperBound!(SearchPolicy.gallop)(value).length;
				return this[left .. right];
			}
		}
		return this.init;
	}

// trisect
/**
Returns a tuple $(D r) such that $(D r[0]) is the same as the result
of $(D lowerBound(value)), $(D r[1]) is the same as the result of $(D
equalRange(value)), and $(D r[2]) is the same as the result of $(D
upperBound(value)). The call is faster than computing all three
separately. Uses a search schedule similar to $(D
equalRange). Completes the entire search in $(BIGOH log(n)) time.
*/
	auto trisect(V)(V value)
	if (isTwoWayCompatible!(predFun, ElementType!Range, V)
		&& isRandomAccessRange!Range && hasLength!Range)
	{
		import std.typecons : tuple;
		size_t first = 0, count = _input.length;
		while (count > 0)
		{
			immutable step = count / 2;
			auto it = first + step;
			if (predFun(_input[it], value))
			{
				// Less than value, bump left bound up
				first = it + 1;
				count -= step + 1;
			}
			else if (predFun(value, _input[it]))
			{
				// Greater than value, chop count
				count = step;
			}
			else
			{
				// Equal to value, do binary searches in the
				// leftover portions
				// Gallop towards the left end as it's likely nearby
				immutable left = first
					+ this[first .. it]
					.lowerBound!(SearchPolicy.gallopBackwards)(value).length;
				first += count;
				// Gallop towards the right end as it's likely nearby
				immutable right = first
					- this[it + 1 .. first]
					.upperBound!(SearchPolicy.gallop)(value).length;
				return tuple(this[0 .. left], this[left .. right],
						this[right .. length]);
			}
		}
		// No equal element was found
		return tuple(this[0 .. first], this.init, this[first .. length]);
	}

// contains
/**
Returns `true` if and only if `value` can be found in $(D
range), which is assumed to be sorted. Performs $(BIGOH log(r.length))
evaluations of $(D pred). See_Also: STL's $(HTTP
sgi.com/tech/stl/binary_search.html, binary_search).
 */

	bool contains(V)(V value)
	if (isRandomAccessRange!Range)
	{
		if (empty) return false;
		immutable i = getTransitionIndex!(SearchPolicy.binarySearch, geq)(value);
		if (i >= length) return false;
		return !predFun(value, _input[i]);
	}

// groupBy
/**
Returns a range of subranges of elements that are equivalent according to the
sorting relation.
 */
	auto groupBy()()
	{
		import std.algorithm.iteration : chunkBy;
		return _input.chunkBy!((a, b) => !predFun(a, b) && !predFun(b, a));
	}
}
