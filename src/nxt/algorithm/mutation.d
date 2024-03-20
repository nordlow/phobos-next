/++ Algorithms that either improve or complement std.algorithm.mutation.`
 +/
module nxt.algorithm.mutation;

/** Array-specialization of `stripLeft` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripLeft(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = 0;
	while (offset != haystack.length &&
		   haystack.ptr[offset] == needle) /+ TODO: elide range-check +/
		offset += 1;
	return haystack.ptr[offset .. haystack.length];
}
/// ditto
inout(char)[] stripLeft()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.stripLeft(' ');
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".stripLeft(' ') == "beta");
	assert(" beta".stripLeft(' ') == "beta");
	assert("  beta".stripLeft(' ') == "beta");
	assert("   beta".stripLeft(' ') == "beta");
	assert("   beta".stripLeft() == "beta");
	assert(" _ beta _ ".stripLeft(' ') == "_ beta _ ");
	assert(" _  beta _ ".stripLeft(' ') == "_  beta _ ");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripLeft(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `stripRight` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripRight(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = haystack.length;
	while (offset != 0 &&
		   haystack.ptr[offset - 1] == needle) /+ TODO: elide range-check +/
		offset -= 1;
	return haystack.ptr[0 .. offset];
}
/// ditto
inout(T)[] stripRight(T)(scope return inout(T)[] haystack, scope const T[] needles) @trusted {
	import nxt.algorithm.searching : canFind;
	static if (is(T : const(char)))
		foreach (needle; needles)
			assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = haystack.length;
	while (offset != 0 &&
		   needles.canFind(haystack.ptr[offset - 1])) /+ TODO: elide range-check +/
		offset -= 1;
	return haystack.ptr[0 .. offset];
}
/// ditto
inout(char)[] stripRight()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.stripRight([' ', '\t', '\r', '\n']); /+ TODO: `std.ascii.iswhite` instead +/
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".stripRight(' ') == "beta");
	assert("beta ".stripRight(' ') == "beta");
	assert("beta  ".stripRight(' ') == "beta");
	assert("beta	".stripRight('	') == "beta");
	assert("beta	".stripRight() == "beta");
	assert(" _ beta _ ".stripRight(' ') == " _ beta _");
	assert(" _  beta _ ".stripRight(' ') == " _  beta _");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripRight(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `strip` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] strip(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t leftOffset = 0;
	while (leftOffset != haystack.length &&
		   haystack.ptr[leftOffset] == needle) /+ TODO: elide range-check +/
		leftOffset += 1;
	size_t rightOffset = haystack.length;
	while (rightOffset != leftOffset &&
		   haystack.ptr[rightOffset - 1] == needle) /+ TODO: elide range-check +/
		rightOffset -= 1;
	return haystack.ptr[leftOffset .. rightOffset];
}
/// ditto
inout(char)[] strip()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.strip(' ');
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".strip(' ') == "beta");
	assert(" beta ".strip(' ') == "beta");
	assert("  beta  ".strip(' ') == "beta");
	assert("   beta   ".strip(' ') == "beta");
	assert(" _ beta _ ".strip(' ') == "_ beta _");
	assert(" _  beta _ ".strip(' ') == "_  beta _");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].strip(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const ubyte[3] x = [0, 42, 0];
	assert(x.strip(0) == x[1 .. 2]);
}

version (unittest) {
	import nxt.dip_traits : hasPreviewDIP1000;
}
