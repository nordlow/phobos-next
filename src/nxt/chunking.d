module nxt.chunking;

version (none) {
import std.range.primitives : ElementType, empty, front, back, popFront, isForwardRange, isInputRange;
import std.functional : unaryFun;

// Used by implementation of chunkBy for non-forward input ranges.
private struct ChunkByChunkImpl(alias pred, Range)
if (isInputRange!Range && !isForwardRange!Range) {
	alias fun = binaryFun!pred;

	private Range r;
	private ElementType!Range prev;

	this(Range range, ElementType!Range _prev) {
		r = range;
		prev = _prev;
	}

	@property bool empty() => r.empty || !fun(prev, r.front);
	@property ElementType!Range front() => r.front;
	void popFront() => r.popFront();
}

private template ChunkByImplIsUnary(alias pred, Range) {
	static if (is(typeof(binaryFun!pred(ElementType!Range.init,
										ElementType!Range.init)) : bool))
		enum ChunkByImplIsUnary = false;
	else static if (is(typeof(
			unaryFun!pred(ElementType!Range.init) ==
			unaryFun!pred(ElementType!Range.init))))
		enum ChunkByImplIsUnary = true;
	else
		static assert(0, "chunkBy expects either a binary predicate or "~
						 "a unary predicate on range elements of type: "~
						 ElementType!Range.stringof);
}

// Implementation of chunkBy for non-forward input ranges.
private struct ChunkByImpl(alias pred, Range)
if (isInputRange!Range && !isForwardRange!Range) {
	enum bool isUnary = ChunkByImplIsUnary!(pred, Range);

	static if (isUnary)
		alias eq = binaryFun!((a, b) => unaryFun!pred(a) == unaryFun!pred(b));
	else
		alias eq = binaryFun!pred;

	private Range r;
	private ElementType!Range _prev;

	this(Range _r) {
		r = _r;
		if (!empty) {
			// Check reflexivity if predicate is claimed to be an equivalence
			// relation.
			assert(eq(r.front, r.front),
				   "predicate is not reflexive");

			// _prev's type may be a nested struct, so must be initialized
			// directly in the constructor (cannot call savePred()).
			_prev = r.front;
		}
		else
		{
			// We won't use _prev, but must be initialized.
			_prev = typeof(_prev).init;
		}
	}
	@property bool empty() => r.empty;

	@property auto front() {
		static if (isUnary) {
			import std.typecons : tuple;
			return tuple(unaryFun!pred(_prev),
						 ChunkByChunkImpl!(eq, Range)(r, _prev));
		}
		else
			return ChunkByChunkImpl!(eq, Range)(r, _prev);
	}

	void popFront() {
		while (!r.empty) {
			if (!eq(_prev, r.front)) {
				_prev = r.front;
				break;
			}
			r.popFront();
		}
	}
}

// Single-pass implementation of chunkBy for forward ranges.
private struct ChunkByImpl(alias pred, Range)
if (isForwardRange!Range) {
	import std.typecons : RefCounted;

	enum bool isUnary = ChunkByImplIsUnary!(pred, Range);

	static if (isUnary)
		alias eq = binaryFun!((a, b) => unaryFun!pred(a) == unaryFun!pred(b));
	else
		alias eq = binaryFun!pred;

	// Outer range
	static struct Impl
	{
		size_t groupNum;
		Range  current;
		Range  next;
	}

	// Inner range
	static struct Group
	{
		private size_t groupNum;
		private Range  start;
		private Range  current;

		private RefCounted!Impl mothership;

		this(RefCounted!Impl origin) {
			groupNum = origin.groupNum;

			start = origin.current.save;
			current = origin.current.save;
			assert(!start.empty);

			mothership = origin;

			// Note: this requires reflexivity.
			assert(eq(start.front, current.front),
				   "predicate is not reflexive");
		}

		@property bool empty() => groupNum == size_t.max;
		@property auto ref front() => current.front;

		void popFront() {
			current.popFront();

			// Note: this requires transitivity.
			if (current.empty || !eq(start.front, current.front)) {
				if (groupNum == mothership.groupNum) {
					// If parent range hasn't moved on yet, help it along by
					// saving location of start of next Group.
					mothership.next = current.save;
				}

				groupNum = size_t.max;
			}
		}

		@property auto save() {
			auto copy = this;
			copy.current = current.save;
			return copy;
		}
	}
	static assert(isForwardRange!Group);

	private RefCounted!Impl impl;

	this(Range r) {
		impl = RefCounted!Impl(0, r, r.save);
	}

	@property bool empty() => impl.current.empty;

	@property auto front() {
		static if (isUnary) {
			import std.typecons : tuple;
			return tuple(unaryFun!pred(impl.current.front), Group(impl));
		}
		else
			return Group(impl);
	}

	void popFront() {
		// Scan for next group. If we're lucky, one of our Groups would have
		// already set .next to the start of the next group, in which case the
		// loop is skipped.
		while (!impl.next.empty &&
			   eq(impl.current.front, impl.next.front))
			impl.next.popFront();
		impl.current = impl.next.save;
		// Indicate to any remaining Groups that we have moved on.
		impl.groupNum++;
	}

	// Note: the new copy of the range will be detached from any existing
	// satellite Groups, and will not benefit from the .next acceleration.
	@property auto save() => typeof(this)(impl.current.save);

	static assert(isForwardRange!(typeof(this)));
}

@system unittest {
	import std.algorithm.comparison : equal;

	size_t popCount = 0;
	class RefFwdRange
	{
		int[]  impl;
		@safe nothrow:
		this(int[] data) { impl = data; }
		@property bool empty() => impl.empty;
		@property auto ref front() => impl.front;
		void popFront() {
			impl.popFront();
			popCount++;
		}
		@property auto save() => new RefFwdRange(impl);
	}
	static assert(isForwardRange!RefFwdRange);

	auto testdata = new RefFwdRange([1, 3, 5, 2, 4, 7, 6, 8, 9]);
	auto groups = testdata.chunkBy!((a,b) => (a % 2) == (b % 2));
	auto outerSave1 = groups.save;

	// Sanity test
	assert(groups.equal!equal([[1, 3, 5], [2, 4], [7], [6, 8], [9]]));
	assert(groups.empty);

	// Performance test for single-traversal use case: popFront should not have
	// been called more times than there are elements if we traversed the
	// segmented range exactly once.
	assert(popCount == 9);

	// Outer range .save test
	groups = outerSave1.save;
	assert(!groups.empty);

	// Inner range .save test
	auto grp1 = groups.front.save;
	auto grp1b = grp1.save;
	assert(grp1b.equal([1, 3, 5]));
	assert(grp1.save.equal([1, 3, 5]));

	// Inner range should remain consistent after outer range has moved on.
	groups.popFront();
	assert(grp1.save.equal([1, 3, 5]));

	// Inner range should not be affected by subsequent inner ranges.
	assert(groups.front.equal([2, 4]));
	assert(grp1.save.equal([1, 3, 5]));
}

/**
 * Chunks an input range into subranges of equivalent adjacent elements.
 * In other languages this is often called `partitionBy`, `groupBy`
 * or `sliceWhen`.
 *
 * Equivalence is defined by the predicate $(D pred), which can be either
 * binary, which is passed to $(REF binaryFun, std,functional), or unary, which is
 * passed to $(REF unaryFun, std,functional). In the binary form, two _range elements
 * $(D a) and $(D b) are considered equivalent if $(D pred(a,b)) is true. In
 * unary form, two elements are considered equivalent if $(D pred(a) == pred(b))
 * is true.
 *
 * This predicate must be an equivalence relation, that is, it must be
 * reflexive ($(D pred(x,x)) is always true), symmetric
 * ($(D pred(x,y) == pred(y,x))), and transitive ($(D pred(x,y) && pred(y,z))
 * implies $(D pred(x,z))). If this is not the case, the range returned by
 * chunkBy may assert at runtime or behave erratically.
 *
 * Params:
 *  pred = Predicate for determining equivalence.
 *  r = An $(REF_ALTTEXT input range, isInputRange, std,range,primitives) to be chunked.
 *
 * Returns: With a binary predicate, a range of ranges is returned in which
 * all elements in a given subrange are equivalent under the given predicate.
 * With a unary predicate, a range of tuples is returned, with the tuple
 * consisting of the result of the unary predicate for each subrange, and the
 * subrange itself.
 *
 * Notes:
 *
 * Equivalent elements separated by an intervening non-equivalent element will
 * appear in separate subranges; this function only considers adjacent
 * equivalence. Elements in the subranges will always appear in the same order
 * they appear in the original range.
 *
 * See_Also:
 * $(LREF group), which collapses adjacent equivalent elements into a single
 * element.
 */
auto chunkBy(alias pred, Range)(Range r)
if (isInputRange!Range)
	=> ChunkByImpl!(pred, Range)(r);

/// Showing usage with binary predicate:
/*FIXME: @safe*/ @system unittest {
	import std.algorithm.comparison : equal;

	// Grouping by particular attribute of each element:
	auto data = [
		[1, 1],
		[1, 2],
		[2, 2],
		[2, 3]
	];

	auto r1 = data.chunkBy!((a,b) => a[0] == b[0]);
	assert(r1.equal!equal([
		[[1, 1], [1, 2]],
		[[2, 2], [2, 3]]
	]));

	auto r2 = data.chunkBy!((a,b) => a[1] == b[1]);
	assert(r2.equal!equal([
		[[1, 1]],
		[[1, 2], [2, 2]],
		[[2, 3]]
	]));
}

version (none) // this example requires support for non-equivalence relations
@safe unittest {
	// Grouping by maximum adjacent difference:
	import std.math : abs;
	auto r3 = [1, 3, 2, 5, 4, 9, 10].chunkBy!((a, b) => abs(a-b) < 3);
	assert(r3.equal!equal([
		[1, 3, 2],
		[5, 4],
		[9, 10]
	]));

}

/// Showing usage with unary predicate:
/* FIXME: pure @safe nothrow*/ @system unittest {
	import std.algorithm.comparison : equal;
	import std.range.primitives;
	import std.typecons : tuple;

	// Grouping by particular attribute of each element:
	auto range =
	[
		[1, 1],
		[1, 1],
		[1, 2],
		[2, 2],
		[2, 3],
		[2, 3],
		[3, 3]
	];

	auto byX = chunkBy!(a => a[0])(range);
	auto expected1 =
	[
		tuple(1, [[1, 1], [1, 1], [1, 2]]),
		tuple(2, [[2, 2], [2, 3], [2, 3]]),
		tuple(3, [[3, 3]])
	];
	foreach (e; byX) {
		assert(!expected1.empty);
		assert(e[0] == expected1.front[0]);
		assert(e[1].equal(expected1.front[1]));
		expected1.popFront();
	}

	auto byY = chunkBy!(a => a[1])(range);
	auto expected2 =
	[
		tuple(1, [[1, 1], [1, 1]]),
		tuple(2, [[1, 2], [2, 2]]),
		tuple(3, [[2, 3], [2, 3], [3, 3]])
	];
	foreach (e; byY) {
		assert(!expected2.empty);
		assert(e[0] == expected2.front[0]);
		assert(e[1].equal(expected2.front[1]));
		expected2.popFront();
	}
}

/*FIXME: pure @safe nothrow*/ @system unittest {
	import std.algorithm.comparison : equal;
	import std.typecons : tuple;

	struct Item { int x, y; }

	// Force R to have only an input range API with reference semantics, so
	// that we're not unknowingly making use of array semantics outside of the
	// range API.
	class RefInputRange(R) {
		R data;
		this(R _data) pure @safe nothrow { data = _data; }
		@property bool empty() pure @safe nothrow => data.empty;
		@property auto front() pure @safe nothrow => data.front;
		void popFront() pure @safe nothrow => data.popFront();
	}
	auto refInputRange(R)(R range) => new RefInputRange!R(range);

	{
		auto arr = [ Item(1,2), Item(1,3), Item(2,3) ];
		static assert(isForwardRange!(typeof(arr)));

		auto byX = chunkBy!(a => a.x)(arr);
		static assert(isForwardRange!(typeof(byX)));

		auto byX_subrange1 = byX.front[1].save;
		auto byX_subrange2 = byX.front[1].save;
		static assert(isForwardRange!(typeof(byX_subrange1)));
		static assert(isForwardRange!(typeof(byX_subrange2)));

		byX.popFront();
		assert(byX_subrange1.equal([ Item(1,2), Item(1,3) ]));
		byX_subrange1.popFront();
		assert(byX_subrange1.equal([ Item(1,3) ]));
		assert(byX_subrange2.equal([ Item(1,2), Item(1,3) ]));

		auto byY = chunkBy!(a => a.y)(arr);
		static assert(isForwardRange!(typeof(byY)));

		auto byY2 = byY.save;
		static assert(is(typeof(byY) == typeof(byY2)));
		byY.popFront();
		assert(byY.front[0] == 3);
		assert(byY.front[1].equal([ Item(1,3), Item(2,3) ]));
		assert(byY2.front[0] == 2);
		assert(byY2.front[1].equal([ Item(1,2) ]));
	}

	// Test non-forward input ranges.
	{
		auto range = refInputRange([ Item(1,1), Item(1,2), Item(2,2) ]);
		auto byX = chunkBy!(a => a.x)(range);
		assert(byX.front[0] == 1);
		assert(byX.front[1].equal([ Item(1,1), Item(1,2) ]));
		byX.popFront();
		assert(byX.front[0] == 2);
		assert(byX.front[1].equal([ Item(2,2) ]));
		byX.popFront();
		assert(byX.empty);
		assert(range.empty);

		range = refInputRange([ Item(1,1), Item(1,2), Item(2,2) ]);
		auto byY = chunkBy!(a => a.y)(range);
		assert(byY.front[0] == 1);
		assert(byY.front[1].equal([ Item(1,1) ]));
		byY.popFront();
		assert(byY.front[0] == 2);
		assert(byY.front[1].equal([ Item(1,2), Item(2,2) ]));
		byY.popFront();
		assert(byY.empty);
		assert(range.empty);
	}
}

// Issue 13595
version (none) // This requires support for non-equivalence relations
@system unittest {
	import std.algorithm.comparison : equal;
	auto r = [1, 2, 3, 4, 5, 6, 7, 8, 9].chunkBy!((x, y) => ((x*y) % 3) == 0);
	assert(r.equal!equal([
		[1],
		[2, 3, 4],
		[5, 6, 7],
		[8, 9]
	]));
}

// Issue 13805
@system unittest {
	[""].map!((s) => s).chunkBy!((x, y) => true);
}
}
