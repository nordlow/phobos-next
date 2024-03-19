/** Predicate extensions to std.algorithm.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
   */
module nxt.predicates;

import std.range.primitives : ElementType;

// ==============================================================================================

import std.range: isInputRange;

/** Returns: `true` iff all elements in range are equal (or range is empty).
	http://stackoverflow.com/questions/19258556/equality-of-all-elements-in-a-range/19292822?noredirect=1#19292822

	Possible alternatives or aliases: allElementsEqual, haveEqualElements
*/
bool allEqual(R)(R range)
if (isInputRange!R)
{
	import std.algorithm: findAdjacent;
	import std.range: empty;
	return range.findAdjacent!("a != b").empty;
}
pure nothrow @safe unittest { assert([11, 11].allEqual); }
pure nothrow @safe unittest { assert(![11, 12].allEqual); }
pure nothrow @safe unittest { int[] x; assert(x.allEqual); }

/* See_Also: http://forum.dlang.org/thread/febepworacvbapkpozjl@forum.dlang.org#post-gbqvablzsbdowqoijxpn:40forum.dlang.org */
/* import std.range: InputRange; */
/* bool allEqual_(T)(InputRange!T range) @safe pure nothrow */
/* { */
/*	 import std.algorithm: findAdjacent; */
/*	 import std.range: empty; */
/*	 return range.findAdjacent!("a != b").empty; */
/* } */
/* pure nothrow @safe unittest { assert([11, 11].allEqual_); } */
/* pure nothrow @safe unittest { assert(![11, 12].allEqual_); } */
/* pure nothrow @safe unittest { int[] x; assert(x.allEqual_); } */

/** Returns: `true` iff all elements in range are equal (or range is empty) to $(D element).

	Possible alternatives or aliases: allElementsEqualTo
*/
bool allEqualTo(R, E)(R range, E element)
if (isInputRange!R &&
	is(ElementType!R == E))
{
	import std.algorithm: all;
	return range.all!(a => a == element);
}

///
pure nothrow @safe unittest {
	assert([42, 42].allEqualTo(42));
}

// ==============================================================================================

/** Check if all Elements of $(D x) are zero. */
bool allZero(T, bool useStatic = true)(in T x)
{
	static if (is(T == struct) || is(T == class))
	{
		foreach (const ref elt; x.tupleof)
			if (!elt.allZero)
				return false;
		return true;
	}
	else
	{
		import std.traits : isIterable;
		static if (useStatic && __traits(isStaticArray, T))
		{
			static foreach (ix; 0 .. x.length) /+ TODO: do we need static iota here? +/
				if (!x[ix].allZero)
					return false; // make use of iota?
			return true;
		}
		else static if (isIterable!T)
		{
			foreach (const ref elt; x)
				if (!elt.allZero)
					return false;
			return true;
		}
		else
			return x == 0;
	}
}
/// ditto
alias zeroed = allZero;

///
pure nothrow @safe unittest {
	ubyte[20] d;
	assert(d.allZero);	 // note that [] is needed here

	ubyte[2][2] zeros = [ [0, 0],
						  [0, 0] ];
	assert(zeros.allZero);

	ubyte[2][2] one = [ [0, 1],
						[0, 0] ];
	assert(!one.allZero);

	ubyte[2][2] ones = [ [1, 1],
						 [1, 1] ];
	assert(!ones.allZero);

	ubyte[2][2][2] zeros3d = [ [ [0, 0],
								 [0, 0] ],
							   [ [0, 0],
								 [0, 0] ] ];
	assert(zeros3d.allZero);

	ubyte[2][2][2] ones3d = [ [ [1, 1],
								[1, 1] ],
							  [ [1, 1],
								[1, 1] ] ];
	assert(!ones3d.allZero);
}

///
pure nothrow @safe unittest {
	struct Vec { real x, y; }
	const v0 = Vec(0, 0);
	assert(v0.zeroed);
	const v1 = Vec(1, 1);
	assert(!v1.zeroed);
}

///
pure nothrow @safe unittest {
	class Vec
	{
		this(real x, real y) { this.x = x; this.y = y; }
		real x, y;
	}
	const v0 = new Vec(0, 0);
	assert(v0.zeroed);
	const v1 = new Vec(1, 1);
	assert(!v1.zeroed);
}
