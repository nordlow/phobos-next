module nxt.variant;

@safe pure:

/** Lightweight version of $(D std.variant.Algebraic) that doesn't rely on `TypeInfo`.
 *
 * Member functions are, when possible, `pure nothrow @safe @nogc`.
 *
 * Storage (packing) is more space-efficient.
 *
 * TODO: support implicit conversions of (un)signed integer type to larger type
 * See_Also: https://forum.dlang.org/post/jfasmgwoffmbtuvrtxey@forum.dlang.org
 *
 * TODO: add warnings about combining byte, short, int, long, etc.
 * TODO: add warnings about combining ubyte, ushort, uint, ulong, etc.
 *
 * TODO: Use
 *
 * align(1)
 * struct Unaligned
 * {
 * align(1):
 * ubyte filler;
 * Victim* p;
 * }
 *
 * See_Also: https://github.com/Geod24/minivariant
 * See_Also: http://forum.dlang.org/post/osfrjcuabwscvrecuvre@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/jfasmgwoffmbtuvrtxey@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/tdviqyzrcpttwwnvlzpv@forum.dlang.org
 * See_Also: https://issues.dlang.org/show_bug.cgi?id=15399
 */
struct Algebraic(Types...) {
@safe:

	alias Ix = ubyte; // type index type. TODO: use uint or size_t when there is room (depending on `memoryPacked`)
	enum maxTypesCount = 2^^(Ix.sizeof * 8) - 1; // maximum number of allowed type parameters

	import core.internal.traits : Unqual; /+ TODO: remove by using Andreis trick with `immutable` qualifier +/
	import std.meta : anySatisfy, allSatisfy, staticIndexOf;
	import std.traits : StdCommonType = CommonType, hasIndirections, hasAliasing;
	import nxt.traits_ex : isComparable, isEquable, sizesOf, stringsOf, allSame;

public:

	enum name = Algebraic.stringof;
	alias CommonType = StdCommonType!Types;
	enum hasCommonType = !is(CommonType == void);

	enum typeCount = Types.length;
	enum typeSizes = sizesOf!Types;
	enum typeNames = stringsOf!Types;

	/// Is `true` iff `this` may have aliasing through any of `Types`.
	enum mayHaveAliasing = anySatisfy!(hasAliasing, Types);

	immutable static typeNamesRT = [typeNames]; // typeNames accessible at run-time, because `[typeNames]` is not @nogc

	/// Is $(D true) if all $(D Types) stored in this $(D Algebraic) has the same length.
	enum hasFixedSize = allSame!typeSizes;

	private enum N = typeCount; // useful local shorthand

	private enum indexOf(T) = staticIndexOf!(T, Types); /+ TODO: cast to ubyte if N is <= 256 +/

	// static checking
	static assert(N >= 1, "No use storing zero types in a " ~ name);
	static assert(N < maxTypesCount,
				  "Cannot store more than " ~ maxTypesCount.stringof ~ " Types in a " ~ name);

	/** Is `true` if `U` is allowed to be assigned to `this`. */
	enum bool allowsAssignmentFrom(U) = ((N == 0 ||
										  indexOf!(U) >= 0 ||	  // either direct match or
										  ((!hasIndirections!U) && // no indirections and
										   indexOf!(Unqual!U) >= 0))); // ok to remove constness of value types

	import nxt.maxsize_trait : maxSizeOf;

	enum dataMaxSize = maxSizeOf!Types;

	auto ref to(U)() const {
		import std.conv : to;
		final switch (typeIndex) {
			foreach (const i, T; Types) {
			case i: return as!T.to!U;
			}
		}
	}

	void toString(Sink)(ref scope Sink sink) const /*tlm*/ {
		import std.conv : to;
		if (!hasValue)
			return sink("<Uninitialized Algebraic>");
		final switch (typeIndex) {
			foreach (const i, T; Types) {
			case i:
				/+ TODO: use instead to avoid allocations +/
				// import std.format : formatValue;
				// formatValue(sink, as!T);
				sink(to!string(as!T));
				return;
			}
		}
	}

	/** Returns: $(D this) as a HTML-tagged $(D string). */
	@property void toHTML(Sink)(ref scope Sink sink) const /*tlm*/ {
		// wrap information in HTML tags with CSS propertie
		immutable tag = `dlang-` ~ typeName;
		sink(`<`); sink(tag); sink(`>`);
		toString(sink);
		sink(`</`); sink(tag); sink(`>`);
	}

	pure:

	/** Returns: Name (as a $(D string)) of Currently Stored Type. */
	private auto ref typeName()() const @safe nothrow @nogc /*tlm*/	{
		pragma(inline, true);
		return hasValue ? typeNamesRT[typeIndex] : null;
	}

	/** Copy construct from `that`. */
	this()(in Algebraic that) @safe nothrow @nogc {
		_store = that._store;
		_tix = that._tix;
		pragma(msg, "Run postblits for " ~ Types.stringof);
	}

	/// Destruct.
	~this() nothrow @nogc {
		pragma(inline, true);
		if (hasValue)
			release();
	}

	/// Construct copy from `that`.
	this(T)(T that) @trusted nothrow @nogc if (allowsAssignmentFrom!T) {
		import core.lifetime : moveEmplace;

		alias MT = Unqual!T;
		static if (__traits(isPOD, MT))
			*cast(MT*)(&_store) = that;
		else
			moveEmplace(that, *cast(MT*)(&_store)); /+ TODO: ok when `that` has indirections? +/

		_tix = cast(Ix)(indexOf!MT + 1); // set type tag
	}

	Algebraic opAssign(T)(T that) @trusted nothrow @nogc if (allowsAssignmentFrom!T) {
		import core.lifetime : moveEmplace;

		if (hasValue)
			release();

		alias MT = Unqual!T;
		static if (__traits(isPOD, MT))
			*cast(MT*)(&_store) = that;
		else
			moveEmplace(that, *cast(MT*)(&_store)); /+ TODO: ok when `that` has indirections? +/

		_tix = cast(Ix)(indexOf!MT + 1); // set type tag

		return this;
	}

	/** If the $(D Algebraic) object holds a value of the $(I exact) type $(D T),
		returns a pointer to that value. Otherwise, returns $(D null). In cases
		where $(D T) is statically disallowed, $(D peek) will not compile.
	*/
	@property inout(T)* peek(T)() inout @trusted nothrow @nogc {
		pragma(inline, true);
		alias MT = Unqual!T;
		static if (!is(MT == void))
			static assert(allowsAssignmentFrom!MT, "Cannot store a " ~ MT.stringof ~ " in a " ~ name);
		if (!ofType!MT)
			return null;
		return cast(inout MT*)&_store; /+ TODO: alignment +/
	}

	/// Get Value of type $(D T).
	@property auto ref inout(T) get(T)() inout @trusted {
		version (LDC) pragma(inline, true); // DMD cannot inline
		if (!ofType!T)
			throw new AlgebraicException("Algebraic doesn't contain type");
		return as!T;
	}

	/// ditto
	@property inout(Types[index]) get(uint index)() inout @safe if (index < Types.length) {
		pragma(inline, true);
		return get!(Types[index]);
	}

	/** Interpret data as type $(D T).
	 *
	 * See_Also: https://forum.dlang.org/post/thhrulbqsxbtzoyojqwx@forum.dlang.org
	 */
	private @property auto ref inout(T) as(T)() inout @system nothrow @nogc {
		static if (_store.alignof >= T.alignof)
			return *(cast(T*)&_store);
		else {
			inout(T) result;
			(cast(ubyte*)&result)[0 .. T.sizeof] = _store[0 .. T.sizeof];
			return result;
		}
	}

	/// Returns: $(D true) iff $(D this) $(D Algebraic) can store an instance of $(D T).
	bool ofType(T)() const @safe nothrow @nogc { /+ TODO: shorter name such `isA`, `ofType` +/
		pragma(inline, true);
		return _tix == indexOf!T + 1;
	}
	alias canStore = ofType;
	alias isType = ofType; // minivariant compliance

	/// Force $(D this) to the null/uninitialized/unset/undefined state.
	void clear() @safe nothrow @nogc {
		pragma(inline, true);
		if (_tix != _tix.init) {
			release();
			_tix = _tix.init; // this is enough to indicate undefined, no need to zero `_store`
		}
	}
	/// ditto
	alias nullify = clear;	  // compatible with `std.typecons.Nullable`

	/// Nullable type support.
	static immutable nullValue = typeof(this).init;

	/// ditto
	void opAssign(typeof(null)) {
		pragma(inline, true);
		clear();
	}

	/// Release internal store.
	private void release() @trusted nothrow @nogc {
		import core.internal.traits : hasElaborateDestructor;
		final switch (typeIndex) {
			foreach (const i, T; Types) {
			case i:
				static if (hasElaborateDestructor!T)
					.destroy(*cast(T*)&_store); // reinterpret
				return;
			}
			case Ix.max:
				return;
		}
		/+ TODO: don't call if all types satisfy traits_ex.isValueType +/
		// _store[] = 0; // slightly faster than: memset(&_store, 0, _store.sizeof);
	}

	/// Returns: $(D true) if this has a defined value (is defined).
	bool hasValue() const @safe nothrow @nogc {
		pragma(inline, true);
		return _tix != _tix.init;
	}

	bool isNull() const @safe nothrow @nogc	{
		pragma(inline, true);
		return _tix == _tix.init;
	}

	size_t currentSize()() const @safe nothrow @nogc /*tlm*/ {
		if (isNull)
			return 0;
		final switch (typeIndex) {
			foreach (const i, const typeSize; typeSizes) {
			case i:
				return typeSize;
			}
		}
	}

	/// Blindly Implicitly Convert Stored Value in $(D U).
	private U convertTo(U)() const @trusted nothrow {
		assert(hasValue);
		final switch (typeIndex) {
			foreach (const i, T; Types) {
			case i:
				return as!T;
			}
		}
	}

	static if (hasCommonType) {
		CommonType commonValue() const @trusted pure nothrow @nogc {
			assert(hasValue);
			final switch (typeIndex) {
				foreach (const i, T; Types) {
				case i:
					return cast(CommonType)as!T;
				}
			}
		}
	}

	static if (allSatisfy!(isEquable, Types)) {
		static if (hasCommonType) {
			bool opEquals()(in Algebraic that) const @trusted nothrow @nogc /* tlm, opEquals is nothrow @nogc */
			{
				if (_tix != that._tix)
					return (this.convertTo!CommonType ==
							that.convertTo!CommonType);
				if (!this.hasValue &&
					!that.hasValue)
					return true; /+ TODO: same behaviour as floating point NaN? +/
				final switch (typeIndex) {
					foreach (const i, T; Types) {
					case i:
						return this.as!T == that.as!T;
					}
				}
			}
		} else {
			bool opEquals()(in Algebraic that) const @trusted nothrow /*tlm*/
			{
				if (_tix != that._tix)
					return false; // this needs to be nothrow or otherwise x in aa will throw which is not desirable

				if (!this.hasValue &&
					!that.hasValue)
					return true; /+ TODO: same behaviour as floating point NaN? +/

				final switch (typeIndex) {
					foreach (const i, T; Types) {
					case i:
						return (this.as!T ==
								that.as!T);
					}
				}

				assert(false); // this is for knet to compile but not in this module. TODO: remove when compiler is fixed
			}
		}

		bool opEquals(T)(in T that) const @trusted nothrow {
			/+ TODO: assert failure only if none of the Types isComparable to T +/
			static assert (allowsAssignmentFrom!T,
						   "Cannot equal any possible type of " ~ Algebraic.stringof ~
						   " with " ~ T.stringof);

			if (!ofType!T)
				return false; // throw new AlgebraicException("Cannot equal Algebraic with current type " ~ "[Types][typeIndex]" ~ " with different types " ~ "T.stringof");
			return (this.as!T == that);
		}
	}

	static if (allSatisfy!(isComparable, Types)) {
		int opCmp()(in Algebraic that) const @trusted /* tlm, TODO: extend to Algebraic!(ThatTypes) */
		{
			static if (hasCommonType) { /+ TODO: extend to haveCommonType!(Types, ThatTypes) +/
				if (_tix != that._tix) {
					/+ TODO: functionize to defaultOpCmp to avoid postblits: +/
					const a = this.convertTo!CommonType;
					const b = that.convertTo!CommonType;
					return a < b ? -1 : a > b ? 1 : 0;
				}
			} else {
				if (_tix != that._tix)
					throw new AlgebraicException("Cannot compare Algebraic of type " ~ typeNamesRT[typeIndex] ~
													  " with Algebraic of type " ~ typeNamesRT[that.typeIndex]);
			}

			final switch (typeIndex) {
				foreach (const i, T; Types) {
				case i:
					/+ TODO: functionize to defaultOpCmp to avoid postblits: +/
					const a = this.as!T;
					const b = that.as!T;
					return a < b ? -1 : a > b ? 1 : 0;
				}
			}
		}

		int opCmp(U)(in U that) const @trusted {
			/+ TODO: is CommonType or isComparable the correct way of checking this? +/
			static if (!is(StdCommonType!(Types, U) == void)) {
				final switch (typeIndex) {
					foreach (const i, T; Types) {
					case i:
						const a = this.as!T;
						return a < that ? -1 : a > that ? 1 : 0; /+ TODO: functionize to defaultOpCmp +/
					}
				}
			} else {
				static assert(allowsAssignmentFrom!U, /+ TODO: relax to allowsComparisonWith!U +/
							  "Cannot compare " ~ Algebraic.stringof ~ " with " ~ U.stringof);
				if (!ofType!U)
					throw new AlgebraicException("Cannot compare " ~ Algebraic.stringof ~ " with " ~ U.stringof);
				/+ TODO: functionize to defaultOpCmp to avoid postblits: +/
				const a = this.as!U;
				return a < that ? -1 : a > that ? 1 : 0;
			}
		}
	}

	extern (D) hash_t toHash() const @trusted pure nothrow {
		import core.internal.hash : hashOf;
		const typeof(return) hash = _tix.hashOf;
		if (hasValue) {
			final switch (typeIndex) {
				foreach (const i, T; Types) {
				case i: return as!T.hashOf(hash);
				}
			}
		}
		return hash;
	}

	import std.digest : isDigest;

	//+ TODO: use `!hasAliasing`? +/
	void toDigest(Digest)(scope ref Digest digest) const nothrow @nogc if (isDigest!Digest) {
		import nxt.digestion : digestAny;
		digestAny(digest, _tix);
		if (hasValue) {
			final switch (typeIndex) {
				foreach (const i, T; Types) {
				case i:
					digestAny(digest, as!T);
					return;
				}
			}
		}
	}

private:
	// immutable to make hasAliasing!(Algebraic!(...)) false
	union {
		//align(8):
		static if (mayHaveAliasing) {
			ubyte[dataMaxSize] _store;
			void* alignDummy; // non-packed means good alignment. TODO: check for maximum alignof of Types
		} else {
			// to please hasAliasing!(typeof(this)):
			immutable(ubyte)[dataMaxSize] _store;
			immutable(void)* alignDummy; // non-packed means good alignment. TODO: check for maximum alignof of Types
		}
	}

	size_t typeIndex() const nothrow @nogc {
		pragma(inline, true);
		assert(_tix != 0, "Cannot get index from uninitialized (null) variant.");
		return _tix - 1;
	}

	Ix _tix = 0;				// type index
}

/// Algebraic type exception.
static class AlgebraicException : Exception {
	this(string s) pure @nogc {
		super(s);
	}
}

unittest {
	// Algebraic!(float, double, bool) a;
	// a = 2.1;  assert(a.to!string == "2.1");  assert(a.toHTML == "<dlang-double>2.1</dlang-double>");
	// a = 2.1f; assert(a.to!string == "2.1");  assert(a.toHTML == "<dlang-float>2.1</dlang-float>");
	// a = true; assert(a.to!string == "true"); assert(a.toHTML == "<dlang-bool>true</dlang-bool>");
}

pure:

/// equality and comparison
@trusted nothrow @nogc unittest {
	Algebraic!(float) a, b;
	static assert(a.hasFixedSize);

	a = 1.0f;
	assert(a._tix != a.Ix.init);

	b = 1.0f;
	assert(b._tix != b.Ix.init);

	assert(a._tix == b._tix);
	assert((cast(ubyte*)&a)[0 .. a.sizeof] == (cast(ubyte*)&b)[0 .. b.sizeof]);
	assert(a == b);			 /+ TODO: this errors with dmd master +/
}

///
nothrow @nogc unittest {
	alias C = Algebraic!(float, double);
	C a = 1.0;
	const C b = 2.0;
	const C c = 2.0f;
	const C d = 1.0f;

	assert(a.commonValue == 1);
	assert(b.commonValue == 2);
	assert(c.commonValue == 2);
	assert(d.commonValue == 1);

	// nothrow comparison possible
	assert(a < b);
	assert(a < c);
	assert(a == d);

	static assert(!a.hasFixedSize);
	static assert(a.allowsAssignmentFrom!float);
	static assert(a.allowsAssignmentFrom!double);
	static assert(!a.allowsAssignmentFrom!string);

	a.clear();
	assert(!a.hasValue);
	assert(a.peek!float is null);
	assert(a.peek!double is null);
	assert(a.currentSize == 0);
}

/// aliasing traits
nothrow @nogc unittest {
	import std.traits : hasAliasing;
	static assert(!hasAliasing!(Algebraic!(long, double)));
	static assert(!hasAliasing!(Algebraic!(long, string)));
	static assert(!hasAliasing!(Algebraic!(long, immutable(double)*)));
	static assert(hasAliasing!(Algebraic!(long, double*)));
}

nothrow @nogc unittest {
	alias V = Algebraic!(long, double);
	const a = V(1.0);

	static assert(a.hasFixedSize);

	assert(a.ofType!double);
	assert(a.peek!long is null);
	assert(a.peek!double !is null);

	static assert(is(typeof(a.peek!long) == const(long)*));
	static assert(is(typeof(a.peek!double) == const(double)*));
}

/// equality and comparison
nothrow @nogc unittest {
	Algebraic!(int) a, b;
	static assert(a.hasFixedSize);
	a = 1;
	b = 1;
	assert(a == b);
}

/// equality and comparison
nothrow @nogc unittest {
	Algebraic!(float) a, b;
	static assert(a.hasFixedSize);
	a = 1.0f;
	b = 1.0f;
	assert(a == b);
}

/// equality and comparison
/*TODO: @nogc*/ unittest {
	Algebraic!(float, double, string) a, b;

	static assert(!a.hasFixedSize);

	a = 1.0f;
	b = 1.0f;
	assert(a == b);

	a = 1.0f;
	b = 2.0f;
	assert(a != b);
	assert(a < b);
	assert(b > a);

	a = "alpha";
	b = "alpha";
	assert(a == b);

	a = "a";
	b = "b";
	assert(a != b);
	assert(a < b);
	assert(b > a);
}

/// AA keys
nothrow unittest {
	alias C = Algebraic!(float, double);
	static assert(!C.hasFixedSize);
	string[C] a;
	a[C(1.0f)] = "1.0f";
	a[C(2.0)] = "2.0";
	assert(a[C(1.0f)] == "1.0f");
	assert(a[C(2.0)] == "2.0");
}

/// verify nothrow comparisons
nothrow @nogc unittest {
	alias C = Algebraic!(int, float, double);
	static assert(!C.hasFixedSize);
	assert(C(1.0) < 2);
	assert(C(1.0) < 2.0);
	assert(C(1.0) < 2.0);
	static assert(!__traits(compiles, { C(1.0) < 'a'; })); // cannot compare with char
	static assert(!__traits(compiles, { C(1.0) < "a"; })); // cannot compare with string
}

/// TODO
nothrow @nogc unittest {
	// alias C = Algebraic!(int, float, double);
	// alias D = Algebraic!(float, double);
	// assert(C(1) < D(2.0));
	// assert(C(1) < D(1.0));
	// static assert(!__traits(compiles, { C(1.0) < "a"; })); // cannot compare with string
}

/// if types have CommonType comparison is nothrow @nogc
nothrow @nogc unittest {
	alias C = Algebraic!(short, int, long, float, double);
	static assert(!C.hasFixedSize);
	assert(C(1) != C(2.0));
	assert(C(1) == C(1.0));
}

/// if types have `CommonType` then comparison is `nothrow @nogc`
nothrow @nogc unittest {
	alias C = Algebraic!(short, int, long, float, double);
	static assert(!C.hasFixedSize);
	assert(C(1) != C(2.0));
	assert(C(1) == C(1.0));
}

nothrow @nogc unittest {
	alias C = Algebraic!(int, string);
	static assert(!C.hasFixedSize);
	C x;
	x = 42;
}

nothrow @nogc unittest {
	alias C = Algebraic!(int);
	static assert(C.hasFixedSize);
	C x;
	x = 42;
}

unittest {
	import core.internal.traits : hasElaborateCopyConstructor;

	import std.exception : assertThrown;

	static assert(hasElaborateCopyConstructor!(char[2]) == false);
	static assert(hasElaborateCopyConstructor!(char[]) == false);

	// static assert(Algebraic!(char, wchar).sizeof == 2 + 1);
	// static assert(Algebraic!(wchar, dchar).sizeof == 4 + 1);
	// static assert(Algebraic!(long, double).sizeof == 8 + 1);
	// static assert(Algebraic!(int, float).sizeof == 4 + 1);
	// static assert(Algebraic!(char[2], wchar[2]).sizeof == 2 * 2 + 1);

	alias C = Algebraic!(string,
						// fixed length strings: small string optimizations (SSOs)
						int, float,
						long, double);
	static assert(!C.hasFixedSize);

	static assert(C.allowsAssignmentFrom!int);
	static assert(!C.allowsAssignmentFrom!(int[2]));
	static assert(C.allowsAssignmentFrom!(const(int)));

	static assert(C.dataMaxSize == string.sizeof);
	static assert(!__traits(compiles, { assert(d == 'a'); }));

	assert(C() == C());		 // two undefined are equal

	C d;
	C e = d;					// copy construction
	assert(e == d);			 // two undefined should not equal

	d = 11;
	assert(d != e);

	/+ TODO: Allow this d = cast(ubyte)255; +/

	d = 1.0f;
	assertThrown!AlgebraicException(d.get!double);
	assert(d.hasValue);
	assert(d.ofType!float);
	assert(d.peek!float !is null);
	assert(!d.ofType!double);
	assert(d.peek!double is null);
	assert(d.get!float == 1.0f);
	assert(d == 1.0f);
	assert(d != 2.0f);
	assert(d < 2.0f);
	assert(d != "2.0f");
	assertThrown!AlgebraicException(d < 2.0);
	assertThrown!AlgebraicException(d < "2.0");
	assert(d.currentSize == float.sizeof);

	d = 2;
	assert(d.hasValue);
	assert(d.peek!int !is null);
	assert(!d.ofType!float);
	assert(d.peek!float is null);
	assert(d.get!int == 2);
	assert(d == 2);
	assert(d != 3);
	assert(d < 3);
	assertThrown!AlgebraicException(d < 2.0f);
	assertThrown!AlgebraicException(d < "2.0");
	assert(d.currentSize == int.sizeof);

	d = "abc";
	assert(d.hasValue);
	assert(d.get!0 == "abc");
	assert(d.get!string == "abc");
	assert(d.ofType!string);
	assert(d.peek!string !is null);
	assert(d == "abc");
	assert(d != "abcd");
	assert(d < "abcd");
	assertThrown!AlgebraicException(d < 2.0f);
	assertThrown!AlgebraicException(d < 2.0);
	assert(d.currentSize == string.sizeof);

	d = 2.0;
	assert(d.hasValue);
	assert(d.get!double == 2.0);
	assert(d.ofType!double);
	assert(d.peek!double !is null);
	assert(d == 2.0);
	assert(d != 3.0);
	assert(d < 3.0);
	assertThrown!AlgebraicException(d < 2.0f);
	assertThrown!AlgebraicException(d < "2.0");
	assert(d.currentSize == double.sizeof);

	d.clear();
	assert(d.peek!int is null);
	assert(d.peek!float is null);
	assert(d.peek!double is null);
	assert(d.peek!string is null);
	assert(!d.hasValue);
	assert(d.currentSize == 0);

	assert(C(1.0f) == C(1.0f));
	assert(C(1.0f) <  C(2.0f));
	assert(C(2.0f) >  C(1.0f));

	assertThrown!AlgebraicException(C(1.0f) <  C(1.0));
	// assertThrown!AlgebraicException(C(1.0f) == C(1.0));
}

///
nothrow @nogc unittest {
	import nxt.container.static_array : MutableStringN;
	alias String15 = MutableStringN!(15);

	String15 s;
	String15 t = s;
	assert(t == s);

	alias V = Algebraic!(String15, string);
	V v = String15("first");
	assert(v.peek!String15);
	assert(!v.peek!string);

	v = String15("second");
	assert(v.peek!String15);
	assert(!v.peek!string);

	v = "third";
	assert(!v.peek!String15);
	assert(v.peek!string);

	auto w = v;
	assert(v == w);
	w.clear();
	assert(!v.isNull);
	assert(w.isNull);
	w = v;
	assert(!w.isNull);

	v = V.init;
	assert(v == V.init);
}

/// check default values
nothrow @nogc unittest {
	import nxt.container.static_array : MutableStringN;
	alias String15 = MutableStringN!(15);

	alias V = Algebraic!(String15, string);
	V _;
	assert(_._tix == V.Ix.init);
	assert(V.init._tix == V.Ix.init);

	/+ TODO: import nxt.bit_traits : isInitAllZeroBits; +/
	/+ TODO: static assert(isInitAllZeroBits!(V)); +/
}
