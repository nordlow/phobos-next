/** Boyer–Moore–Horspool Algorithm
	See_Also: https://en.wikipedia.org/wiki/Boyer%E2%80%93Moore%E2%80%93Horspool_algorithm
	Copyright: Per Nordlöw 2014-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
 */
module nxt.horspool;

import std.range.primitives : isRandomAccessRange;

/** Returns a pointer to the first occurrence of "needle"
 * within "haystack", or [] if not found. Works like
 * memmem().
 *
 * Note: In this example needle is a C string. The ending
 * 0x00 will be cut off, so you could call this example with
 * boyermoore_horspool_memmem(haystack, hlen, "abc", sizeof("abc"))
 */
Range boyerMooreHorspoolFind(Range)(Range haystack,
									in Range needle)
	if (isRandomAccessRange!Range)
{
	import std.range.primitives : ElementType;
	alias T = ElementType!Range;
	size_t scan = 0;
	size_t[T.max + 1] skips; // "bad" character index skips shift

	/* Sanity checks on the parameters */
	/* if (needle.length <= 0 || !haystack || !needle) return []; */

	/* ---- Preprocess ---- */
	/* Initialize the table to default value */
	/* When a character is encountered that does not occur
	 * in the needle, we can safely skip ahead for the whole
	 * length of the needle. */
	for (scan = 0; scan <= T.max; ++scan)
		skips[scan] = needle.length;
	const size_t last = needle.length - 1; // last index of C-style array
	/* populate with needle analysis */
	for (scan = 0; scan < last; ++scan)
		skips[needle[scan]] = last - scan;

	/* ---- Do the matching ---- */
	while (haystack.length >= needle.length) { // while the needle can still be within it
		/* scan from the end of the needle */
		for (scan = last; haystack[scan] == needle[scan]; --scan)
			if (scan == 0) /* If the first byte matches, we've found it. */
				return haystack[0..needle.length];
		/* otherwise, we need to skip some bytes and start again.
		   Note that here we are getting the skip value based on the last byte
		   of needle, no matter where we didn't match. So if needle is: "abcd"
		   then we are skipping based on 'd' and that value will be 4, and
		   for "abcdd" we again skip on 'd' but the value will be only 1.
		   The alternative of pretending that the mismatched character was
		   the last character is slower in the normal case (E.g. finding
		   "abcd" in "...azcd..." gives 4 by using 'd' but only
		   4-2==2 using 'z'. */
		/* hlen	 -= skips[haystack[last]]; */
		/* haystack += skips[haystack[last]]; */
		haystack = haystack[skips[haystack[last]]..$]; // NOTE: Is this to slow for now?
	}
	return [];
}

pure nothrow @safe unittest {
	alias boyerMooreHorspoolFind find;
	ubyte[] haystack = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
	assert(find(haystack, cast(ubyte[])[10]) == []);
	assert(find(haystack, cast(ubyte[])[2, 3]) == [2, 3]);
	assert(find(haystack, cast(ubyte[])[0]) == [0]);
	assert(find(haystack, cast(ubyte[])[9]) == [9]);
	assert(find(cast(ubyte[])[], cast(ubyte[])[9]) == []);
	assert(haystack.boyerMooreHorspoolFind(cast(ubyte[])[1, 0]) == []);
}
