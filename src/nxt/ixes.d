module nxt.ixes;

import std.meta : allSatisfy;
import std.range.primitives : isInputRange, isBidirectionalRange;

/** Get length of Common Prefix of $(D a) and $(D b).
	See_Also: http://forum.dlang.org/thread/bmbhovkgqomaidnyakvy@forum.dlang.org#post-bmbhovkgqomaidnyakvy:40forum.dlang.org
*/
auto commonPrefixLength(alias pred = "a == b", Rs...)(Rs rs)
if (rs.length >= 2 &&
	allSatisfy!(isInputRange, Rs))
{
	import std.algorithm.searching : commonPrefix;
	static if (rs.length == 2)
		return commonPrefix!pred(rs[0], rs[1]).length;
	else
	{
		static assert("TODO");
		import std.range : zip, StoppingPolicy;
		import std.algorithm : countUntil, count;
		const hit = zip(a, b).countUntil!(ab => ab[0] != ab[1]); /+ TODO: if countUntil return zip(a, b).count upon failre... +/
		return hit == -1 ? zip(a, b).count!pred : hit; /+ TODO: ..then this would not have been needed +/
	}
}

pure @safe unittest {
	assert(commonPrefixLength(`åäö_`,
							  `åäö-`) == 6);
}

pure nothrow @safe unittest {
	const x = [1, 2, 3, 10], y = [1, 2, 4, 10];
	void f() pure nothrow @safe @nogc
	{
		assert(commonPrefixLength(x, y) == 2);
	}
	f();
	assert(commonPrefixLength([1, 2, 3, 10],
							  [1, 2, 3]) == 3);
	assert(commonPrefixLength([1, 2, 3, 0, 4],
							  [1, 2, 3, 9, 4]) == 3);
}

/** Get length of Suffix of $(D a) and $(D b).
	See_Also: http://forum.dlang.org/thread/bmbhovkgqomaidnyakvy@forum.dlang.org#post-bmbhovkgqomaidnyakvy:40forum.dlang.org
*/
auto commonSuffixLength(Rs...)(Rs rs)
	if (rs.length == 2 &&
		allSatisfy!(isBidirectionalRange, Rs))
{
	import std.traits : isNarrowString;
	import std.range: retro;
	static if (isNarrowString!(typeof(rs[0])) &&
			   isNarrowString!(typeof(rs[1])))
	{
		import std.string: representation;
		return commonPrefixLength(rs[0].representation.retro,
								  rs[1].representation.retro);
	}
	else
		return commonPrefixLength(rs[0].retro,
								  rs[1].retro);
}

pure @safe unittest {
	const x = [1, 2, 3, 10, 11, 12];
	const y = [1, 2, 4, 10, 11, 12];
	void f() pure nothrow @safe @nogc
	{
		assert(commonPrefixLength(x, y) == 2);
	}
	f();
	assert(commonSuffixLength(x, y) == 3);
	assert(commonSuffixLength([10, 1, 2, 3],
							  [1, 2, 3]) == 3);
}

pure @safe unittest {
	assert(commonSuffixLength(`_åäö`,
							  `-åäö`) == 6);
}

/** Get Count of Prefix of $(D a) and $(D b).
	See_Also: http://forum.dlang.org/thread/bmbhovkgqomaidnyakvy@forum.dlang.org#post-bmbhovkgqomaidnyakvy:40forum.dlang.org
*/
auto commonPrefixCount(alias pred = "a == b", Rs...)(Rs rs)
if (rs.length == 2 &&
	allSatisfy!(isInputRange, Rs))
{
	import std.algorithm.searching : commonPrefix, count;
	import std.traits : isNarrowString;
	static if (isNarrowString!(typeof(rs[0])) &&
			   isNarrowString!(typeof(rs[1])))
	{
		import std.utf: byDchar;
		return commonPrefix!pred(rs[0].byDchar,
								 rs[1].byDchar).count;
	}
	else
		return commonPrefix!pred(rs[0], rs[1]).count;
}

pure @safe unittest {
	assert(commonPrefixCount([1, 2, 3, 10],
							 [1, 2, 3]) == 3);
	assert(commonPrefixCount(`åäö_`,
							 `åäö-`) == 3);
}

/** Get Common Suffix of $(D a) and $(D b).
	TODO: Copy implementation of commonPrefix into commonSuffix to splitter
*/
auto commonSuffix(Rs...)(Rs rs)
if (rs.length == 2 &&
	allSatisfy!(isBidirectionalRange, Rs))
{
	import std.range : retro;
	import std.array : array;
	import std.algorithm.searching : commonPrefix;
	return commonPrefix(rs[0].retro,
						rs[1].retro).array.retro;
}

pure @safe unittest {
	import std.algorithm.comparison : equal;
	assert(equal(commonSuffix(`_åäö`,
							  `-åäö`), `åäö`));
}

// pure @safe unittest
// {
//	 import std.algorithm.comparison : equal;
//	 import nxt.splitter_ex : splitterASCIIAmong;
//	 import std.range : retro;
//	 import std.range.primitives : ElementType;
//	 import std.array : array;
//	 assert(equal(commonSuffix(`_å-ä-ö`,
//							   `-å-ä-ö`).retro.splitterASCIIAmong!('-').array, /+ TODO: how should this be solved? +/
//				  [`ö`, `ä`, `å`]));
// }

/** Get Count of Common Suffix of $(D a) and $(D b).
	See_Also: http://forum.dlang.org/thread/bmbhovkgqomaidnyakvy@forum.dlang.org#post-bmbhovkgqomaidnyakvy:40forum.dlang.org
*/
auto commonSuffixCount(alias pred = "a == b", Rs...)(Rs rs)
if (rs.length == 2 &&
	allSatisfy!(isBidirectionalRange, Rs))
{
	import std.range : retro;
	return commonPrefixCount!pred(rs[0].retro,
								  rs[1].retro);
}

pure @safe unittest {
	assert(commonSuffixCount(`_`, `-`) == 0);
	assert(commonSuffixCount(`_å`, `-å`) == 1);
	assert(commonSuffixCount(`_åä`, `-åä`) == 2);
	assert(commonSuffixCount(`_åäö`, `-åäö`) == 3);

	import std.algorithm.comparison : among;
	assert(commonSuffixCount!((a, b) => (a == b && a == 'ö'))(`_åäö`, `-åäö`) == 1);
	assert(commonSuffixCount!((a, b) => (a == b && a.among!('ä', 'ö')))(`_åäö`, `-åäö`) == 2);
}

/** Get length of Common Prefix of rs $(D rs).
	See_Also: http://forum.dlang.org/thread/bmbhovkgqomaidnyakvy@forum.dlang.org#post-bmbhovkgqomaidnyakvy:40forum.dlang.org
*/
// auto commonPrefixLengthN(R...)(R rs) if (rs.length == 2)
// {
//	 import std.range: zip;
//	 return zip!((a, b) => a != b)(rs);
// }

// unittest
// {
//	 assert(commonPrefixLengthN([1, 2, 3, 10],
//							   [1, 2, 4, 10]) == 2);
// }
