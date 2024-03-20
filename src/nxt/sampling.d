/** Data sampling, typically randomly.
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -d -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run sampling.d
 */
module nxt.sampling;

alias Offset = size_t;
alias Length = size_t;

/** Span.
 * TODO: Relate|Unite with `nxt.limits.Limits`.
 */
struct Span {
	Offset offset = 0;
	Length length = 1;
}

@safe pure nothrow @nogc unittest {
	Span x;
	assert(x == Span.init);
}

/++ Format (flags) of sampling. +/
struct Format {
	/// Array length span.
	Span arrayLengthSpan = Span(0,3);
	/++ Field recursion depth span for recursive aggregate type with unbounded
		depth like `std.json.JSONValue`. +/
	Span fieldDepth = Span(Length.min, 3);
}

import std.random : Random;

/++ Returns: A random sample of the type `T`.
    TODO: Use direct field setting for T only when __traits(isPOD, T) is true
          otherwise use __traits(getOverloads, T, "__ctor").
	Test on `std.json.JSONValue`.
 +/
auto sample(T)(ref Random rnd, in Format fmt = Format.init) {
	static if (is(T == U[], U)) { // isArray
		import std.random : uniform;
		T t;
		t.length = uniform(fmt.arrayLengthSpan.offset, fmt.arrayLengthSpan.length, rnd);
		foreach (ref e; t)
			e = rnd.sample!(U);
		return t;
	} else static if (is(T == struct)) {
		import std.traits : FieldNameTuple;
		T t; /+ TODO: = void +/
		foreach (mn; FieldNameTuple!T)
			__traits(getMember, t, mn) = rnd.sample!(typeof(__traits(getMember, t, mn)))(fmt);
		return t;
	} else {
		import std.random : uniform;
		return uniform!(T);
	}
}

/// scalar
@safe unittest {
    auto rnd = Random(42);
	auto s = rnd.sample!ubyte;
}

/// char[]
@safe unittest {
    auto rnd = Random(42);
	foreach (_; 0 .. 100) {
		auto s = rnd.sample!(char[])(Format(arrayLengthSpan: Span(0,10)));
		// dbg(s);
	}
}

/// struct
@safe unittest {
    auto rnd = Random(42);
	struct S { byte x, y;}
	struct T { short a, b; ushort c, d; S s; }
	struct U { int a, b; uint c, d; T t; int[] ia; }
	auto s = rnd.sample!U;
	// dbg(s);
}

version (unittest) {
	import nxt.debugio;
}
