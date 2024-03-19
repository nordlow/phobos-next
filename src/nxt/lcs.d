/** Longest Common Subsequence, typically used as a base for writing diff/compare algorithms.

	Copyright: Per Nordlöw 2014-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	See_Also: https://en.wikipedia.org/wiki/Longest_common_subsequence_problem
	See_Also: https://en.wikipedia.org/wiki/Diff
*/

module nxt.lcs;

/** Longest Common Subsequence (LCS).
	See_Also: http://rosettacode.org/wiki/Longest_common_subsequence#Recursive_version
*/
T[] lcsR(T)(in T[] a,
			in T[] b) pure nothrow
{
	import std.range.primitives : empty;
	if (a.empty || b.empty)
		return null;			// undefined
	if (a[0] == b[0])
		return a[0] ~ lcsR(a[1 .. $],
						   b[1 .. $]);
	const longest = (T[] x, T[] y) => x.length > y.length ? x : y;
	return longest(lcsR(a, b[1 .. $]),
				   lcsR(a[1 .. $], b));
}

/** Longest Common Subsequence (LCS).
	Faster Dynamic Programming Version.
	See_Also: http://rosettacode.org/wiki/Longest_common_subsequence#Faster_dynamic_programming_version
*/
T[] lcsDP(T)(in T[] a,
			 in T[] b) pure /* nothrow */
{
	import std.algorithm.comparison : max;

	auto L = new uint[][](a.length + 1, b.length + 1);

	foreach (immutable i; 0 .. a.length)
		foreach (immutable j; 0 .. b.length)
			L[i + 1][j + 1] = (a[i] == b[j]) ? (1 + L[i][j]) : max(L[i + 1][j], L[i][j + 1]);

	import core.internal.traits : Unqual;
	Unqual!T[] result;

	for (auto i = a.length, j = b.length; i > 0 && j > 0; )
	{
		if (a[i - 1] == b[j - 1])
		{
			result ~= a[i - 1];
			i--;
			j--;
		}
		else
		{
			if (L[i][j - 1] < L[i - 1][j])
				i--;
			else
				j--;
		}
	}

	import std.algorithm : reverse;
	result.reverse();		   // not nothrow
	return result;
}

/** Get LCS Lengths. */
uint[] lcsLengths(R)(R xs,
					 R ys) pure nothrow
{
	import std.algorithm.comparison : max;

	auto prev = new typeof(return)(1 + ys.length);
	auto curr = new typeof(return)(1 + ys.length);

	foreach (immutable x; xs)
	{
		import std.algorithm: swap;
		swap(curr, prev);
		size_t i = 0;
		foreach (immutable y; ys)
		{
			curr[i + 1] = (x == y) ? prev[i] + 1 : max(curr[i], prev[i + 1]);
			i++;
		}
	}

	return curr;
}

void lcsDo(T)(in T[] xs,
			  in T[] ys,
			  bool[] xsInLCS,
			  in size_t idx = 0) pure nothrow
{
	immutable nx = xs.length;
	immutable ny = ys.length;

	if (nx == 0)
		return;

	if (nx == 1)
	{
		import std.algorithm: canFind;
		if (ys.canFind(xs[0]))
			xsInLCS[idx] = true;
	}
	else
	{
		immutable mid = nx / 2;
		const xb = xs[0.. mid];
		const xe = xs[mid .. $];
		immutable ll_b = lcsLengths(xb, ys);

		import std.range: retro;
		const ll_e = lcsLengths(xe.retro,
								ys.retro); // retro is slow with DMD

		// import std.algorithm.comparison : max;
		//immutable k = iota(ny + 1)
		//			  .reduce!(max!(j => ll_b[j] + ll_e[ny - j]));
		import std.range: iota;
		import std.algorithm: minPos;
		import std.typecons: tuple;
		immutable k = iota(ny + 1).minPos!((i, j) => tuple(ll_b[i] + ll_e[ny - i]) >
										   tuple(ll_b[j] + ll_e[ny - j]))[0];

		lcsDo(xb, ys[0 .. k], xsInLCS, idx);
		lcsDo(xe, ys[k .. $], xsInLCS, idx + mid);
	}
}

/** Longest Common Subsequence (LCS) using Hirschberg.
	Linear-Space Faster Dynamic Programming Version.

	Time Complexity: O(m*n)
	Space Complexity: O(min(m,n))

	To speed up this code on DMD remove the memory allocations from $(D lcsLengths), and
	do not use the $(D retro) range (replace it with $(D foreach_reverse))

	See_Also: https://en.wikipedia.org/wiki/Hirschberg%27s_algorithm
	See_Also: http://rosettacode.org/wiki/Longest_common_subsequence#Hirschberg_algorithm_version
*/
const(T)[] lcs(T)(in T[] xs,
				  in T[] ys) pure /*nothrow*/
{
	auto xsInLCS = new bool[xs.length];
	lcsDo(xs, ys, xsInLCS);
	import std.range : zip;
	import std.algorithm.iteration : filter, map;
	import std.array : array;
	return zip(xs, xsInLCS).filter!q{ a[1] }.map!q{ a[0] }.array; // Not nothrow.
}

import std.string : representation, assumeUTF;

immutable(char)[] lcs(inout(char)[] a, inout(char)[] b) pure /*nothrow*/
	=> cast(typeof(return))(lcs(a.representation, b.representation).assumeUTF);

unittest {
	immutable x = "thisisatest";
	immutable y = "testing123testing";
	immutable z = "tsitest";
	assert(z == lcsR(x, y));
	assert(z == lcsDP(x, y));
	assert(z == lcs(x, y));
	assert("" == lcs("", ""));
}

unittest {
	immutable x = [1, 2, 3];
	immutable y = [4, 5, 6];
	immutable z = [];
	assert(z == lcsR(x, y));
	assert(z == lcsDP(x, y));
	assert(z == lcs(x, y));
}

unittest {
	immutable x = [1, 2, 3];
	immutable y = [2, 3, 4];
	immutable z = [2, 3];
	assert(z == lcsR(x, y));
	assert(z == lcsDP(x, y));
	assert(z == lcs(x, y));
}

unittest {
	alias T = int;
	size_t n = 300;
	auto x = new T[n];
	auto y = new T[n];
	assert(lcs(x, y).length == n);
}

version (nxt_benchmark) unittest {
	import std.algorithm : levenshteinDistance, levenshteinDistanceAndPath;
	import nxt.random_ex: randInPlaceBlockwise;

	alias T = int;
	size_t n = 300;
	auto x = new T[n];
	auto y = new T[n];

	x.randInPlaceBlockwise;
	y.randInPlaceBlockwise;

	void bLCS() { const d = lcs(x, y); }
	void bLD() { const d = levenshteinDistance(x, y); }
	void bLDAP() { const dp = levenshteinDistanceAndPath(x, y); }

	import std.datetime: benchmark;
	import std.algorithm: map;
	import std.array: array;

	auto r = benchmark!(bLCS, bLD, bLDAP)(1);
	auto q = r.array.map!(a => a.msecs);

	import std.stdio: writeln;
	writeln(q, " milliseconds");
}
