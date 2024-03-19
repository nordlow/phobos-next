/++ Algorithms that either improve or complement std.algorithm.comparison.`
 +/
module nxt.algorithm.comparison;

// version = unittestAsBetterC; // Run_As: dmd -betterC -unittest -run $(__FILE__).d

import std.range.primitives : isInputRange, isInfinite, ElementType;

// Use until `std.algorithm.comparison.equal` supports uncopyable parameters.
bool equal(T, U)(scope T a, scope U b)
if (!(isInfinite!T &&
	  isInfinite!U)) {
	static if ((is(T == TE[M], TE, size_t M)) &&
			   (is(U == UE[N], UE, size_t N)) &&
			   is(typeof(TE.init == UE.init) : bool)) /+ static array +/ {
		static if (M != N)
			return false;
		else {
			foreach (const i; 0 .. M)
				if (a[i] != b[i])
					return false;
			return true;
		}
	} else static if ((is(T == TA[], TA)) &&
					(is(U == UA[], UA)) &&
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
/// ditto
bool equal(T, U)(scope const(T)[] a, scope const(U)[] b)
if (is(typeof(T.init == U.init) : bool)) {
}

/// dynamic arrays
pure nothrow @safe @nogc unittest {
	assert(!equal([1, 2   ].s[], [1, 2, 3].s[]));
	assert(!equal([1, 2, 3].s[], [1, 2,  ].s[]));
	assert( equal([1, 2, 3].s[], [1, 2, 3].s[]));
}

/// static arrays
pure nothrow @safe @nogc unittest {
	assert(!equal([1, 2   ].s, [1, 2, 3].s));
	assert(!equal([1, 2, 3].s, [1, 2,  ].s));
	assert( equal([1, 2, 3].s, [1, 2, 3].s));
}

version (unittest) {
	import nxt.array_help : s;
}

// See_Also: https://dlang.org/spec/betterc.html#unittests
version (unittestAsBetterC)
extern(C) void main() {
	static foreach (u; __traits(getUnitTests, __traits(parent, main))) {
		u();
	}
}
