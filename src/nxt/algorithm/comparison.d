/++ Algorithms that either improve or complement std.algorithm.comparison.`
 +/
module nxt.algorithm.comparison;

import std.range.primitives : isInfinite;

// Use until `std.algorithm.comparison.equal` supports uncopyable parameters.
bool equal(T, U)(scope T a, scope U b)
if (!(isInfinite!T &&
	  isInfinite!U)) {
	import std.range.primitives : ElementType;
	static if (is(T == TE[M], TE, size_t M) &&
			   is(U == UE[N], UE, size_t N) &&
			   is(typeof(TE.init == UE.init) : bool)) /+ static array +/ {
		static if (M != N)
			return false;
		else {
			foreach (const i; 0 .. M)
				if (a[i] != b[i])
					return false;
			return true;
		}
	} else static if (is(T == TA[], TA) &&
					  is(U == UA[], UA) &&
					  is(typeof(TA.init == UA.init) : bool)) /+ dynamic array +/ {
		if (a.length != b.length)
			return false;
		const N = a.length;
		foreach (const i; 0 .. N)
			if (a[i] != b[i])
				return false;
		return true;
	} else static if (is(typeof(ElementType!T.init == ElementType!U.init) : bool)) {
		static if (is(typeof(a[size_t.init]))) {
			import std.algorithm.mutation : move;
			size_t i = 0;
			foreach (const ref be; move(b))
				if (a[i++] != be)
					return false;
			return true;
		} else static if (is(typeof(b[size_t.init]))) {
			import std.algorithm.mutation : move;
			size_t i = 0;
			foreach (const ref ae; move(a))
				if (ae != b[i++])
					return false;
			return true;
		} else {
			while (true) {
				if (a.empty())
					return b.empty();
				if (b.empty())
					return a.empty();
				if (a.front != b.front)
					return false;
				a.popFront();
				b.popFront();
			}
		}
	} else
		static assert(0, "Cannot compare " ~ T.stringof ~ "with" ~ U.stringof);
}

/// dynamic arrays
pure nothrow @safe @nogc unittest {
	assert(!equal([0], [1]));
	assert(!equal([1, 2   ].s[], [1, 2, 3].s[]));
	assert(!equal([1, 2, 3].s[], [1, 2,  ].s[]));
	assert( equal([1, 2, 3].s[], [1, 2, 3].s[]));
}

/// static arrays
pure nothrow @safe @nogc unittest {
	assert(!equal([0].s, [1].s));
	assert(!equal([1, 2   ].s, [1, 2, 3].s));
	assert(!equal([1, 2, 3].s, [1, 2,  ].s));
	assert( equal([1, 2, 3].s, [1, 2, 3].s));
}

version (unittest) {
	import nxt.array_help : s;
}
