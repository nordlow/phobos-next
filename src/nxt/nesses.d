/** Sparseness and denseness of ranges.
 */
module nxt.nesses;

import nxt.rational: Rational;
import std.traits : isIterable, isFloatingPoint;

/** Returns: number of default-initialized (zero) elements in $(D x) at
 * recursion depth $(D depth).
 *
 * Depth defaults -1 meaning infinite depth.
 */
Rational!ulong sparseness(T)(const scope T x,
							 int depth = -1)
{
	alias R = typeof(return); // rational shorthand
	static if (isIterable!T)
	{
		import std.range: empty;
		immutable isEmpty = x.empty;
		if (isEmpty || depth == 0)
			return R(isEmpty, 1);
		else
		{
			immutable nextDepth = (depth == -1 ? depth : depth - 1);
			ulong nums, denoms;
			foreach (const ref elt; x)
			{
				const sub = elt.sparseness(nextDepth);
				nums += sub.numerator;
				denoms += sub.denominator;
			}
			return R(nums, denoms);
		}
	}
	else static if (isFloatingPoint!T)
		return R(x == 0, 1); // explicit zero because T.init is nan here
	else
		return R(x == T.init, 1);
}

pure nothrow @safe unittest {
	assert(1.sparseness == 0);
	assert(0.sparseness == 1);
	assert(0.0.sparseness == 1);
	assert(0.1.sparseness == 0);
	assert(0.0f.sparseness == 1);
	assert(0.1f.sparseness == 0);
	alias Q = Rational!ulong;
	{ immutable ubyte[3]	x  = [1, 2, 3];	assert(x[].sparseness == Q(0, 3)); }
	{ immutable float[3]	x  = [1, 2, 3];	assert(x[].sparseness == Q(0, 3)); }
	/+ TODO: { immutable ubyte[2][2] x  = [0, 1, 0, 1]; assert(x[].sparseness == Q(2, 4)); } +/
	/+ TODO: immutable ubyte[2][2] x22z = [0, 0, 0, 0]; assert(x22z[].sparseness == Q(4, 4)); +/
	assert("".sparseness == 1); /+ TODO: Is this correct? +/
	assert(null.sparseness == 1);
}

/** Returns: Number of Non-Zero Elements in $(D range) at recursion depth $(D
	depth) defaulting infinite depth (-1). */
auto denseness(T)(const scope T x, int depth = -1)
	=> 1 - x.sparseness(depth);

pure nothrow @safe @nogc unittest {
	immutable float[3] f = [1, 2, 3];
	alias Q = Rational!ulong;
	assert(f[].denseness == Q(1, 1)); /+ TODO: should this be 3/3? +/
	assert(f.denseness == Q(1, 1));   /+ TODO: should this be 3/3? +/
}
