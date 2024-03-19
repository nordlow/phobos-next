/** Probing algorithms used by for instance hash tables.
 */
module nxt.probing;

import std.functional : unaryFun, binaryFun;

/** Search for a key in `haystack` matching predicate `pred` starting at `index`
 * in steps of triangular numbers, 0,1,3,6,10,15,21, ... .
 *
 * If `assumeNonFullHaystack` is `true` it is assumed that at least one element
 * in `haystack` matches `pred`, thereby enabling sentinel-based probing. Such
 * probing doesn't require in-loop range checking via `indexIncrement !=
 * haystack.length` and can be made faster.
 *
 * Returns: index into `haystack` upon hit, `haystack.length` upon miss.
 *
 * Note: `haystack.length` must be a power of two (or 1 or zero).
 *
 * See_Also: https://fgiesen.wordpress.com/2015/02/22/triangular-numbers-mod-2n/
 */
size_t triangularProbeFromIndex(alias pred,
								bool assumeNonFullHaystack = false,
								T)(const scope T[] haystack, size_t index)
if (is(typeof(unaryFun!pred(T.init))) ||
	is(typeof(binaryFun!pred(size_t.init, T.init)))) {
	immutable mask = haystack.length - 1;
	assert((~mask ^ mask) == typeof(return).max); // std.math.isPowerOf2(haystack.length)

	static if (assumeNonFullHaystack)
		assert(haystack.length != 0, "haystack cannot be empty");

	// search using triangular numbers as increments
	size_t indexIncrement = 0;
	while (true) {
		static if (assumeNonFullHaystack)
			assert(indexIncrement != haystack.length,
				   "no element in `haystack` matches `pred`, cannot used sentinel-based probing");
		else
			if (indexIncrement == haystack.length) { return haystack.length; }

		static if (is(typeof(unaryFun!pred(T.init)))) {
			if (unaryFun!pred(haystack[index]))
				return index;
		} else static if (is(typeof(binaryFun!pred(size_t.min, T.init)))) {
			if (binaryFun!pred(index, haystack[index]))
				return index;
		} else
			static assert(0, "Unsupported predicate of type " ~ typeof(pred).stringof);

		indexIncrement += 1;
		index = (index + indexIncrement) & mask; // next triangular number modulo length
	}
}

/** Search for a key in `haystack` matching hit predicate `hitPred` and hole/tombstone
 * predicate `holePred` starting at `index` in steps of triangular numbers,
 * 0,1,3,6,10,15,21, ... .
 *
 * If `assumeNonFullHaystack` is `true` it is assumed that at least one element
 * in `haystack` matches `pred`, thereby enabling sentinel-based probing. Such
 * probing doesn't require in-loop range checking via `indexIncrement !=
 * haystack.length` and can be made faster.
 *
 * Returns: index into `haystack` upon hit, `haystack.length` upon miss.
 *
 * Note: `haystack.length` must be a power of two (or 1 or zero).
 *
 * See_Also: https://fgiesen.wordpress.com/2015/02/22/triangular-numbers-mod-2n/
 */
size_t triangularProbeFromIndexIncludingHoles(alias hitPred,
											  alias holePred,
											  bool assumeNonFullHaystack = false,
											  T)(const scope T[] haystack,
												 size_t index,
												 ref size_t holeIndex) // first hole index
if ((is(typeof(unaryFun!hitPred(T.init))) ||
	 is(typeof(binaryFun!hitPred(size_t.init, T.init)))) ||
	(is(typeof(unaryFun!holePred(T.init))) ||
	 is(typeof(binaryFun!holePred(size_t.init, T.init))))) {
	immutable mask = haystack.length - 1;
	assert((~mask ^ mask) == typeof(return).max); // std.math.isPowerOf2(haystack.length)

	static if (assumeNonFullHaystack)
		assert(haystack.length != 0, "haystack cannot be empty");

	// search using triangular numbers as increments
	size_t indexIncrement = 0;
	while (true) {
		static if (assumeNonFullHaystack)
			assert(indexIncrement != haystack.length,
				   "no element in `haystack` matches `hitPred`, cannot used sentinel-based probing");
		else
			if (indexIncrement == haystack.length)
				return haystack.length;

		static if (is(typeof(unaryFun!hitPred(T.init)))) {
			if (unaryFun!hitPred(haystack[index]))
				return index;
		} else static if (is(typeof(binaryFun!hitPred(size_t.min, T.init)))) {
			if (binaryFun!hitPred(index, haystack[index]))
				return index;
		} else
			static assert(0, "Unsupported hit predicate of type " ~ typeof(hitPred).stringof);

		if (holeIndex == size_t.max) { // if not yet initialized
			static if (is(typeof(unaryFun!holePred(T.init)))) {
				if (unaryFun!holePred(haystack[index]))
					holeIndex = index;
			} else static if (is(typeof(binaryFun!holePred(size_t.min, T.init)))) {
				if (binaryFun!holePred(index, haystack[index]))
					holeIndex = index;
			}
		}

		indexIncrement += 1;
		index = (index + indexIncrement) & mask; // next triangular number modulo length
	}
}

size_t triangularProbeCountFromIndex(alias pred,
									 T)(const scope T[] haystack, size_t index)
if (is(typeof(unaryFun!pred(T.init)))) {
	immutable mask = haystack.length - 1;
	assert((~mask ^ mask) == typeof(return).max); // std.math.isPowerOf2(haystack.length)

	// search using triangular numbers as increments
	size_t indexIncrement = 0;
	while (true) {
		if (indexIncrement == haystack.length)
			return indexIncrement + 1;
		if (unaryFun!pred(haystack[index]))
			return indexIncrement + 1;
		indexIncrement += 1;
		index = (index + indexIncrement) & mask; // next triangular number modulo length
	}
}

/// empty case
pure nothrow @safe unittest {
	import std.typecons : Nullable;
	alias T = Nullable!int;

	immutable length = 0;
	immutable hitKey = T(42); // key to store
	auto haystack = new T[length];

	assert(haystack.triangularProbeFromIndex!((T element) => (element is hitKey ||
															  element.isNull))(0) == haystack.length);
	assert(haystack.triangularProbeFromIndex!((size_t index, T element) => true)(0) == 0);
	assert(haystack.triangularProbeFromIndex!((size_t index, T element) => false)(0) == haystack.length);
}

/// generic case
pure nothrow @safe unittest {
	import std.typecons : Nullable;
	alias T = Nullable!int;

	foreach (immutable lengthPower; 0 .. 20) {
		immutable length = 2^^lengthPower;

		immutable hitKey = T(42);  // key to store
		immutable missKey = T(43); // other key not present

		auto haystack = new T[length];
		haystack[] = T(17);	 // make haystack full
		haystack[$/2] = hitKey;

		alias elementHitPredicate = element => (element is hitKey || element.isNull);
		alias elementMissPredicate = element => (element is missKey || element.isNull);

		// key hit
		assert(haystack.triangularProbeFromIndex!(elementHitPredicate)(lengthPower) != haystack.length);

		// key miss
		assert(haystack.triangularProbeFromIndex!(elementMissPredicate)(lengthPower) == haystack.length);
	}
}

@trusted pure unittest {
	class C { int value; }
	C x;
	C y = cast(C)((cast(size_t*)null) + 1); // indicates a lazily deleted key
	struct S {
		/+ TODO: make these work: +/
		// enum C hole1 = cast(C)((cast(size_t*)null) + 1);
		// static immutable C hole2 = cast(C)((cast(size_t*)null) + 1);
	}
}
