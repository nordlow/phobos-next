/** Sorted array-like.
 *
 * See_Also: https://en.wikipedia.org/wiki/Sorted_array
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -preview=in -debug -g -unittest -checkaction=context -allinst -main -unittest -I../.. -i -run sorted.d
 */
module nxt.container.sorted;

import std.algorithm.mutation : SwapStrategy;
import nxt.container.common;

/** Wrapper container around array-like type `A`.
 *
 * See_Also: https://en.wikipedia.org/wiki/Sorted_array
 * See_Also: `nxt.container.cyclic.Cyclic`.
 *
 * TODO: Add flag bool deferred which when true defers sorting to when it's needed via an index that keeps track
         of the split between sorted and non-sorted elements.
 * TODO: Make use of `GrowthStrategy` and `reserveWithGrowth`
 *
 * TODO: Implement support for storing duplicate elements by setting uniqueElements to false
 *
 * TODO: Parameterize sorting algorithm sort and add test and benchmark for hybridSort in test/containers/source/app.d
 *
 * TODO: Add template parameter GrowthStrategy (and reference the term growth
 * factor) and reuse in other dynamic containers, such as `growScaleP` and
 * `growScaleQ` in hybrid_hashmap.d and SoA._growthP and SoA._growthQ in soa.d.
 */
struct Sorted(A, bool uniqueElements = true, alias less = "a < b", SwapStrategy ss = SwapStrategy.unstable)
if (is(typeof(A.init[]))) /* hasSlicing */ {
	import std.range : SortedRange, assumeSorted;
	import std.traits : isAssignable;

	private enum isDynamic = !__traits(isStaticArray, A); /* TODO: generalize to is(typeof(A.init.reserve(0)) : size_t) */
	private alias E = typeof(A.init[0]); ///< Element type.

	this(A source) @trusted {
		import std.algorithm.sorting : sort;
		static if (isDynamic) {
			static if (is(A == U[], U)) // isArray
				_source = sort!(less, ss)(source[]);
			else {
				static if (__traits(isPOD, A))
					_raw = source;
				else {
					import core.lifetime : move;
					_raw = move(source);
				}
				sort!(less, ss)(_raw[]);
			}
		} else
			_source = sort!(less, ss)(source[]).release();
	}

	auto opSlice() @trusted {
		pragma(inline, true);
		static if (isDynamic) {
			static if (is(A == U[], U)) // isArray
				return _source[0 .. _source.length];
			else
				return _raw[].assumeSorted!(less);
		} else
			return _source[].assumeSorted!(less);
	}

	static if (isDynamic) {
		pragma(inline, true) {
			auto capacity() const @property @trusted => _raw.capacity;
			auto reserve(in size_t capacity) @trusted => _raw.reserve(capacity);
		}

		/** Insert `value` into `this`.
		 *
		 * Returns: `false` if `this` already contained `value`, `true` otherwise.
		 */
		bool insert(U)(in U value) scope @trusted
		if (isAssignable!(E, U)) {
			auto ub = _source.upperBound(value);
			const off = ub.release.ptr - _raw.ptr; // offset to all elements > `value`

			if (off > 0 &&		// there are values before `upperBound`
				_raw[off-1] == value)
				return false;

			const n = _source.length;

			/+ TODO: needed?: _raw.reserve(length + values.length); +/
			_raw.length += 1;

			// import std.algorithm.mutation : moveAll;
			/+ TODO: why does this fail: +/
			// moveAll(_raw[off .. $-1], _raw[off + 1 .. $]);
			foreach_reverse (const i; 0 .. ub.length) /+ TODO: replace with std.algorithm.mutation.move() +/
				_raw[off + i + 1] = _raw[off + i];	  /+ TODO: or use `emplace` here instead +/

			_raw[off] = value;

			return true;
		}

		static if (uniqueElements) {
			/* TODO: Add alternative implementation.
			 * See_Also: https://discord.com/channels/242094594181955585/625407836473524246/1044707571606495252
			 */
		} else {
			import std.range.primitives : isInputRange, front;

			/** Insert `values` into `this`.
			 *
			 * Returns: number of elements inserted.
			 */
			size_t insert(R)(R values) scope @trusted
			if (isInputRange!R &&
				isAssignable!(E, typeof(R.init.front))) {
				import std.algorithm.sorting : completeSort;
				const n = _source.length;

				/+ TODO: needed?: _raw.reserve(length + values.length); +/
				_raw.length += values.length;

				size_t i = 0;
				foreach (ref value; values) {
					_raw[n + i] = value;
					i += 1;
				}
				/* Require explicit template arguments because IFTI fails here: */
				completeSort!(less, ss, SortedRange!(A, less), A)(_source[0 .. n], _raw[n .. $]);
				return i;
			}
		}

		static if (is(A == U[], U)) /* isArray */ {
			pragma(inline, true)
			auto source() @trusted => _source;
			union {
				private SortedRange!(A, less) _source;
				private A _raw;
			}
		} else {
			pragma(inline, true)
			auto source() => _raw[].assumeSorted;
			private A _raw;
		}

		size_t length() @trusted scope pure nothrow @nogc {
			return source.length;
		}

		alias source this;
	} else {
		private A _source;
	}

}

/// construct from dynamic array
pure nothrow @safe unittest {
	alias A = int[];
	scope A x = [3,2,1];

	auto sx = Sorted!(A, false)(x);
	assert(sx[].isSorted);

	assert(sx.reserve(3));
	assert(!sx.insert(1));
	assert(!sx.insert(2));
	assert(!sx.insert(3));
	assert(sx.length == 3);

	assert(sx.insert(0));
	assert(sx.length == 4);
	assert(isIota(sx));

	assert(sx.insert([4,5]));
	assert(sx.length == 6);
	assert(isIota(sx));

	assert(sx.insert([4,5]));
	assert(sx.length == 8);

	assert(sx.release == [0, 1, 2, 3, 4, 4, 5, 5]);

}

/// construct from static array
pure nothrow @safe @nogc unittest {
	alias A = int[3];
	A x = [3,2,1];

	auto sx = Sorted!(A, true)(x);
	assert(sx[].isSorted);

	static assert(!is(typeof(x.reserve(0))));
	static assert(!is(typeof(sx.insert(0))));
}

/// construct from dynamic container
pure nothrow @safe @nogc unittest {
	import nxt.container.dynamic_array : DynamicArray;
	alias A = DynamicArray!(int, Mallocator);

	auto sx = Sorted!(A, true)(A([3,2,1]));
	assert(sx.capacity == 3);
	assert(sx[].release == [1,2,3]);
	assert(sx[].isSorted);

	sx.reserve(4);
	assert(sx.capacity >= 4);
}

version (unittest) {
	import std.experimental.allocator.mallocator : Mallocator;
	static private bool isIota(T)(scope T x) pure nothrow @safe @nogc {
		size_t i = 0;
		foreach (const ref e; x)
			if (e != i++)
				return false;
		return true;
	}
	import std.algorithm.sorting : isSorted;
}
