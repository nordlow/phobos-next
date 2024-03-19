/** Codecs.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.codec;

import std.typecons : Tuple;
import std.range.primitives : front, isInputRange, ElementType;
import std.array : array;
import nxt.algorithm_ex : forwardDifference;

/** Packing of $(D r) using a `forwardDifference`.
	Used to pack elements of type ptrdiff, times, etc.
 */
struct ForwardDifferenceCode(R) if (isInputRange!R) {
	this(R r) {
		_front = r.front;
		_diff = r.forwardDifference.array; /+ TODO: Can we make msgpack pack r.forwardDifference without .array +/
	}
private:
	typeof(R.init.front) _front; // First element
	typeof(R.init.forwardDifference.array) _diff; // The Difference
}

/** Instantiator for $(D ForwardDifferenceCode).
 */
auto encodeForwardDifference(R)(R r) if (isInputRange!R) {
	return ForwardDifferenceCode!R(r); /+ TODO: Use named parts? +/
}

// version = use_msgpack;

unittest {
	import std.range: dropOne;
	import core.exception: AssertError;
	import std.exception: assertThrown;
	version (use_msgpack) import msgpack;

	assertThrown!AssertError([1].dropOne.encodeForwardDifference_alt);

	auto x = [1, int.min, 22, 0, int.max, -1100];

	auto fdp = x.encodeForwardDifference;

	version (use_msgpack) {
		alias FDP = typeof(fdp);

		auto raw = fdp.pack;
		auto raw2 = raw.dup;

		FDP fdp_;				   // restored
		aw.unpack(fdp_);		   // restore it
		assert(fdp == fdp_);

		auto fdp__ = raw2.unpack!FDP; // restore it (alternatively)
		assert(fdp == fdp__);
	}
}

/** Alternative. */
auto encodeForwardDifference_alt(R)(R r) if (isInputRange!R) {
	import std.typecons: tuple;
	return tuple(r.front, r.forwardDifference);
}
/** Alternative. */
auto decodeForwardDifference_alt(E, R)(Tuple!(E, R) x)
if (isInputRange!R &&
		is(ElementType!R == typeof(E - E))) {
	/* TODO: Extract as ForwardSum */
	auto diffs = x[1]; // differences
	immutable n = diffs.array.length;
	auto y = new E[1 + n]; /+ TODO: Remove array and keep extra length argument in forwardDifference +/
	y[0] = x[0];
	auto a = diffs.array;
	foreach (ix; 0..n) {
		y[ix + 1] = y[ix] + a[ix];
	}
	return y;
}

unittest {
	auto x = [1, int.min, 22, 0, int.max, -1100];
	// in memory pack and unpack
	auto pfd = x.encodeForwardDifference_alt;
	assert(x == pfd.decodeForwardDifference_alt);
}
