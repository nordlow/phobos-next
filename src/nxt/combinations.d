module nxt.combinations;

/** Given non-negative integers $(D m) and $(D n), generate all size $(D m)
   combinations of the integers from 0 to $(D n)-1 in sorted order (each
   combination is sorted and the entire table is sorted).

   For example, 3 comb 5 is
   0 1 2
   0 1 3
   0 1 4
   0 2 3
   0 2 4
   0 3 4
   1 2 3
   1 2 4
   1 3 4
   2 3 4

   See_Also: http://rosettacode.org/wiki/Combinations
*/
struct Combinations(T, bool copy = true, bool useArray = true) {
	import std.container: Array;
	import std.traits: Unqual;

	static if (useArray)
		alias Indices = Array!size_t;
	else
		alias Indices = size_t[];

	Unqual!T[] pool, front;
	size_t r, n;
	bool empty = false;

	Indices indices;

	size_t len;
	bool lenComputed = false;

	this(T[] pool_, in size_t r_) // pure nothrow @safe
	{
		this.pool = pool_.dup;
		this.r = r_;
		this.n = pool.length;
		if (r > n)
			empty = true;

		indices.length = r;

		size_t i;

		i = 0;
		foreach (ref ini; indices[])
			ini = i++;

		front.length = r;

		i = 0;
		foreach (immutable idx; indices[])
			front[i++] = pool[idx];
	}

	@property size_t length() /*logic_const*/ // pure nothrow @nogc
	{
		static size_t binomial(size_t n, size_t k) // pure nothrow @safe @nogc
		in
		{
			assert(n > 0, "binomial: n must be > 0.");
		}
		do
		{
			if (k < 0 || k > n)
				return 0;
			if (k > (n / 2))
				k = n - k;
			size_t result = 1;
			foreach (size_t d; 1 .. k + 1) {
				result *= n;
				n--;
				result /= d;
			}
			return result;
		}

		if (!lenComputed) {
			// Set cache.
			len = binomial(n, r);
			lenComputed = true;
		}
		return len;
	}

	void popFront() // pure nothrow @safe
	{
		if (!empty) {
			bool broken = false;
			size_t pos = 0;
			foreach_reverse (immutable i; 0 .. r) {
				pos = i;
				if (indices[i] != i + n - r) {
					broken = true;
					break;
				}
			}
			if (!broken) {
				empty = true;
				return;
			}
			indices[pos]++;
			foreach (immutable j; pos + 1 .. r)
				indices[j] = indices[j - 1] + 1;
			static if (copy)
				front = new Unqual!T[front.length];

			size_t i = 0;
			foreach (immutable idx; indices[]) {
				front[i] = pool[idx];
				i++;
			}
		}
	}
}

auto combinations(bool copy = true, T, bool useArray = false)(T[] items, in size_t k)
in(items.length)
	=> Combinations!(T, copy, useArray)(items, k);

unittest {
	import std.algorithm: equal, map;
	// assert(equal([1, 2, 3, 4].combinations!false(2), [[3, 4], [3, 4], [3, 4], [3, 4], [3, 4], [3, 4]]));
	enum solution = [[1, 2],
					 [1, 3],
					 [1, 4],
					 [2, 3],
					 [2, 4],
					 [3, 4]];
	assert(equal([1, 2, 3, 4].combinations!true(2), solution));
	assert(equal([1, 2, 3, 4].combinations(2).map!(x => x), solution));
}

import std.range.primitives : isInputRange;

/** All Unordered Element Pairs (2-Element Subsets) of a $(D Range).

	TODO: Add template parameter to decide if .array should be used internally.

	See_Also: http://forum.dlang.org/thread/iqkybajwdzcvdytakgvw@forum.dlang.org#post-vhufbwsqbssyqwfxxbuu:40forum.dlang.org
	See_Also: https://issues.dlang.org/show_bug.cgi?id=6788
	See_Also: https://issues.dlang.org/show_bug.cgi?id=7128
*/
auto pairwise(R)(R r)
if (isInputRange!R) {
	struct Pairwise(R) {
		import core.internal.traits : Unqual;
		import std.traits : ForeachType;
		import std.typecons: Tuple;

		alias UR = Unqual!R;
		alias E = ForeachType!UR;
		alias Pair = Tuple!(E, E);

		import std.range.primitives : isRandomAccessRange, hasLength;
		import std.traits : isNarrowString;

		static if (isRandomAccessRange!R &&
				   hasLength!R &&
				   !isNarrowString!R) {

			this(R r_) {
				this._input = r_;
				j = 1;
			}
			@property bool empty() => j >= _input.length;
			@property Pair front() => typeof(return)(_input[i], _input[j]);
			void popFront() {
				if (j >= _input.length - 1) {
					i++;
					j = i + 1;
				}
				else
					j++;
			}
			private size_t i, j;
		}
		else // isInputRange!UR
		{
			import std.range : dropOne;
			this(R r_) {
				this._input = r_;
				i = r_;
				if (!i.empty)
					j = i.dropOne;
				else
					j = UR.init;
			}
			@property bool empty() => j.empty;
			@property Pair front() => typeof(return)(i.front, j.front);
			void popFront() {
				j.popFront();
				if (j.empty) {
					i.popFront();
					j = i.dropOne;
				}
			}
			private UR i, j; // temporary copies of $(D _input)
		}

	private:
		UR _input;
	}

	return Pairwise!R(r);
}

/// test RandomAccessRange input
unittest {
	import std.algorithm: equal, filter;
	import std.typecons: Tuple;

	assert((new int[0]).pairwise.empty);
	assert([1].pairwise.empty);

	alias T = Tuple!(int, int);
	assert(equal([1, 2].pairwise,
				 [T(1, 2)]));
	assert(equal([1, 2, 3].pairwise,
				 [T(1, 2), T(1, 3), T(2, 3)]));
	assert(equal([1, 2, 3, 4].pairwise,
				 [T(1, 2), T(1, 3), T(1, 4),
				  T(2, 3), T(2, 4), T(3, 4)]));
}

/// test ForwardRange input
unittest {
	import std.algorithm: equal, filter;
	import std.array : array;

	auto p = [1].filter!"a < 4".pairwise;
	assert(p.empty);

	assert(equal(p.array,
				 [1].pairwise.array));

	assert(equal([1, 2, 3, 4].filter!"a < 4".pairwise,
				 [1, 2, 3].pairwise));
}
