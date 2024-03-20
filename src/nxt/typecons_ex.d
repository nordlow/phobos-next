module nxt.typecons_ex;

/+ TODO: Move to Phobos and refer to http://forum.dlang.org/thread/lzyqywovlmdseqgqfvun@forum.dlang.org#post-ibvkvjwexdafpgtsamut:40forum.dlang.org +/
/+ TODO: Better with?: +/
/* inout(Nullable!T) nullable(T)(inout T a) */
/* { */
/*	 return typeof(return)(a); */
/* } */
/* inout(Nullable!(T, nullValue)) nullable(alias nullValue, T)(inout T value) */
/* if (is (typeof(nullValue) == T)) */
/* { */
/*	 return typeof(return)(value); */
/* } */

import std.typecons : Nullable, NullableRef;

/** Instantiator for `Nullable`.
 */
auto nullable(T)(T a)
{
	return Nullable!T(a);
}

///
pure nothrow @safe @nogc unittest {
	auto x = 42.5.nullable;
	assert(is(typeof(x) == Nullable!double));
}

/** Instantiator for `Nullable`.
*/
auto nullable(alias nullValue, T)(T value)
if (is (typeof(nullValue) == T))
{
	return Nullable!(T, nullValue)(value);
}

///
pure nothrow @safe @nogc unittest {
	auto x = 3.nullable!(int.max);
	assert(is (typeof(x) == Nullable!(int, int.max)));
}

/** Instantiator for `NullableRef`.
 */
auto nullableRef(T)(T* a) @safe pure nothrow
{
	return NullableRef!T(a);
}

///
/*TODO: @safe*/ pure nothrow @nogc unittest {
	auto x = 42.5;
	auto xr = nullableRef(&x);
	assert(!xr.isNull);
	xr.nullify;
	assert(xr.isNull);
}

/** See_Also: http://forum.dlang.org/thread/jwdbjlobbilowlnpdzzo@forum.dlang.org
 */
template New(T)
if (is(T == class))
{
	T New(Args...) (Args args)
	{
		return new T(args);
	}
}

import std.traits : isArray, isUnsigned;
import std.range.primitives : hasSlicing;

/** Check if `T` is castable to `U`.
 */
enum isCastableTo(T, U) = __traits(compiles, { cast(U)(T.init); });

enum isIndex(I) = (is(I == enum) ||
				   isUnsigned!I || /+ TODO: should we allow isUnsigned here? +/
				   isCastableTo!(I, size_t));

/** Check if `T` can be indexed by an instance of `I`.
 *
 * See_Also: http://forum.dlang.org/post/ajxtksnsxqmeulsedmae@forum.dlang.org
 *
 * TODO: move to traits_ex.d
 * TODO: Move to Phobos
 */
enum hasIndexing(T, I = size_t) = is(typeof(T.init[I.init]) == typeof(T.init[0]));

///
pure nothrow @safe @nogc unittest {
	static assert(!hasIndexing!(int));
	static assert(hasIndexing!(int[3]));
	static assert(hasIndexing!(byte[]));
	static assert(hasIndexing!(byte[], uint));
	static assert(hasIndexing!(string));
}

/** Check if `R` is indexable by `I`. */
enum isIndexableBy(R, I) = (hasIndexing!R && isIndex!I);

///
pure nothrow @safe @nogc unittest {
	static assert(isIndexableBy!(int[3], ubyte));
}

/** Check if `R` is indexable by a automatically `R`-local defined integer type named `I`.
 */
enum isIndexableBy(R, alias I) = (hasIndexing!R && is(string == typeof(I))); /+ TODO: extend to isSomeString? +/

///
pure nothrow @safe @nogc unittest {
	static assert(isIndexableBy!(int[], "I"));
}

/** Generate bounds-checked `opIndex` and `opSlice`.
 */
static private
mixin template _genIndexAndSliceOps(I)
{
	import nxt.conv_ex : toDefaulted;

	// indexing

	/// Get element at compile-time index `i`.
	auto ref at(size_t i)() inout
	{
		assert(cast(size_t)i < _r.length, "Index " ~ i ~ " must be smaller than array length" ~ _r.length.stringof);
		return _r[i];
	}

	/// Get element at index `i`.
	auto ref opIndex(I i) inout
	{
		assert(cast(size_t)i < _r.length, "Range violation with index of type " ~ I.stringof);
		return _r[cast(size_t)i];
	}

	/// Set element at index `i` to `value`.
	auto ref opIndexAssign(V)(V value, I i)
	{
		assert(cast(size_t)i < _r.length, "Range violation with index of type " ~ I.stringof);

		import core.lifetime : move;

		move(value, _r[cast(size_t)i]);
		return _r[cast(size_t)i];
	}

	// slicing
	static if (hasSlicing!R)
	{
		auto ref opSlice(I i, I j) inout
		{
			return _r[cast(size_t)i .. cast(size_t)j];
		}
		auto ref opSliceAssign(V)(V value, I i, I j)
		{
			return _r[cast(size_t)i .. cast(size_t)j] = value; /+ TODO: use `move()` +/
		}
	}
}

/** Generate @trusted non-bounds-checked `opIndex` and `opSlice`.
 */
static private
mixin template _genIndexAndSliceOps_unchecked(I)
{
	@trusted:

	// indexing

	/// Get element at compile-time index `i`.
	auto ref at(size_t i)() inout
	{
		static assert(i < _r.length, "Index " ~ i.stringof ~ " must be smaller than array length " ~ _r.length.stringof);
		return _r.ptr[i];
	}

	/// Get element at index `i`.
	auto ref opIndex(I i) inout
	{
		return _r.ptr[cast(size_t)i]; // safe to avoid range checking
	}

	/// Set element at index `i` to `value`.
		auto ref opIndexAssign(V)(V value, I i)
	{
		return _r.ptr[cast(size_t)i] = value;
	}

	// slicing
	static if (hasSlicing!R)
	{
		auto ref opSlice(I i, I j) inout			 { return _r.ptr[cast(size_t)i ..
																	 cast(size_t)j]; }
		auto ref opSliceAssign(V)(V value, I i, I j) { return _r.ptr[cast(size_t)i ..
																	 cast(size_t)j] = value; }
	}
}

/** Wrapper for `R` with Type-Safe `I`-Indexing.
	See_Also: http://forum.dlang.org/thread/gayfjaslyairnzrygbvh@forum.dlang.org#post-gayfjaslyairnzrygbvh:40forum.dlang.org

	TODO: Merge with https://github.com/rcorre/enumap

	TODO: Use std.range.indexed when I is an enum with non-contigious
	enumerators. Perhaps use among aswell.

	TODO: Rename to something more concise such as [Bb]y.

	TODO: Allow `I` to be a string and if so derive `Index` to be that string.
   */
struct IndexedBy(R, I)
if (isIndexableBy!(R, I))
{
	alias Index = I;		/// indexing type
	mixin _genIndexAndSliceOps!I;
	R _r;
	alias _r this; /+ TODO: Use opDispatch instead; to override only opSlice and opIndex +/
}

/** Statically-Sized Array of ElementType `E` indexed by `I`.
	TODO: assert that `I` is continuous if it is a `enum`.
*/
struct IndexedArray(E, I)
if (isIndex!I)
{
	static assert(I.min == 0, "Index type I is currently limited to start at 0 and be continuous");
	alias Index = I;			/// indexing type
	mixin _genIndexAndSliceOps!I;
	alias R = E[I.max + 1];	 // needed by mixins
	R _r;					   // static array
	alias _r this; /+ TODO: Use opDispatch instead; to override only opSlice and opIndex +/
}

///
pure nothrow @safe unittest {
	enum N = 7;
	enum I { x = 0, y = 1, z = 2}
	alias E = int;
	alias A = IndexedArray!(E, I);
	static assert(A.sizeof == 3*int.sizeof);
	A x;
	x[I.x] = 1;
	x[I.y] = 2;
	x[I.z] = 3;
	static assert(!__traits(compiles, { x[1] = 3; })); // no integer indexing
}

/** Instantiator for `IndexedBy`.
 */
auto indexedBy(I, R)(R range)
if (isIndexableBy!(R, I))
{
	return IndexedBy!(R, I)(range);
}

struct IndexedBy(R, string IndexTypeName)
if (hasIndexing!R &&
	IndexTypeName != "IndexTypeName") // prevent name lookup failure
{
	static if (__traits(isStaticArray, R)) // if length is known at compile-time
	{
		import nxt.modulo : Mod;
		mixin(`alias ` ~ IndexTypeName ~ ` = Mod!(R.length);`); /+ TODO: relax integer precision argument of `Mod` +/

		// dummy variable needed for symbol argument to `_genIndexAndSliceOps_unchecked`
		mixin(`private static alias I__ = ` ~ IndexTypeName ~ `;`);

		mixin _genIndexAndSliceOps_unchecked!(I__); // no range checking needed because I is always < R.length

		/** Get index of element `E` wrapped in a `bool`-convertable struct. */
		auto findIndex(E)(E e) pure nothrow @safe @nogc
		{
			static struct Result
			{
				Index index;	// index if exists is `true', 0 otherwise
				bool exists;  // `true` iff `index` is defined, `false` otherwise
				bool opCast(T : bool)() const pure nothrow @safe @nogc { return exists; }
			}
			import std.algorithm : countUntil;
			const ix = _r[].countUntil(e); // is safe
			if (ix >= 0)
			{
				return Result(Index(ix), true);
			}
			return Result(Index(0), false);
		}
	}
	else
	{
		mixin(q{ struct } ~ IndexTypeName ~
			  q{ {
					  alias T = size_t;
					  this(T ix) { this._ix = ix; }
					  T opCast(U : T)() const { return _ix; }
					  private T _ix = 0;
				  }
			  });
		mixin _genIndexAndSliceOps!(mixin(IndexTypeName));
	}
	R _r;
	alias _r this; /+ TODO: Use opDispatch instead; to override only opSlice and opIndex +/
}

/* Wrapper type for `R' indexable/sliceable only with type `R.Index`. */
template TypesafelyIndexed(R)
if (hasIndexing!R) // prevent name lookup failure
{
	alias TypesafelyIndexed = IndexedBy!(R, "Index");
}

/** Instantiator for `IndexedBy`.
 */
auto indexedBy(string I, R)(R range)
if (isArray!R &&
	I != "IndexTypeName") // prevent name lookup failure
{
	return IndexedBy!(R, I)(range);
}

/** Instantiator for `TypesafelyIndexed`.
 */
auto strictlyIndexed(R)(R range)
if (hasIndexing!(R))
{
	return TypesafelyIndexed!(R)(range);
}

///
pure nothrow @safe unittest {
	enum m = 3;
	int[m] x = [11, 22, 33];
	auto y = x.strictlyIndexed;

	alias Y = typeof(y);

	static assert(is(typeof(y.findIndex(11).index) == Y.Index));

	assert(y.findIndex(11).exists);
	assert(y.findIndex(22).exists);
	assert(y.findIndex(33).exists);

	if (auto hit = y.findIndex(11)) { assert(hit.index == 0); } else { assert(false); }
	if (auto hit = y.findIndex(22)) { assert(hit.index == 1); } else { assert(false); }
	if (auto hit = y.findIndex(33)) { assert(hit.index == 2); } else { assert(false); }

	assert(!y.findIndex(44));
	assert(!y.findIndex(55));

	assert(!y.findIndex(44).exists);
	assert(!y.findIndex(55).exists);
}

///
pure nothrow @safe unittest {
	enum N = 7;
	alias T = TypesafelyIndexed!(size_t[N]); // static array
	static assert(T.sizeof == N*size_t.sizeof);
	import nxt.modulo : Mod, mod;

	T x;

	x[Mod!N(1)] = 11;
	x[1.mod!N] = 11;
	assert(x[1.mod!N] == 11);

	x.at!1 = 12;
	static assert(!__traits(compiles, { x.at!N; }));
	assert(x.at!1 == 12);
}

///
pure nothrow @safe unittest {
	int[3] x = [1, 2, 3];

	// sample index
	struct Index(T = size_t)
		if (isUnsigned!T)
	{
		this(T i) { this._i = i; }
		T opCast(U : T)() const { return _i; }
		private T _i = 0;
	}
	alias J = Index!size_t;

	enum E { e0, e1, e2 }

	with (E)
	{
		auto xb = x.indexedBy!ubyte;
		auto xi = x.indexedBy!uint;
		auto xj = x.indexedBy!J;
		auto xe = x.indexedBy!E;
		auto xf = x.strictlyIndexed;

		auto xs = x.indexedBy!"I";
		alias XS = typeof(xs);
		XS xs_;

		// indexing with correct type
		xb[  0 ] = 11; assert(xb[  0 ] == 11);
		xi[  0 ] = 11; assert(xi[  0 ] == 11);
		xj[J(0)] = 11; assert(xj[J(0)] == 11);
		xe[ e0 ] = 11; assert(xe[ e0 ] == 11);

		// indexing with wrong type
		static assert(!__traits(compiles, { xb[J(0)] = 11; }));
		static assert(!__traits(compiles, { xi[J(0)] = 11; }));
		static assert(!__traits(compiles, { xj[  0 ] = 11; }));
		static assert(!__traits(compiles, { xe[  0 ] = 11; }));
		static assert(!__traits(compiles, { xs[  0 ] = 11; }));
		static assert(!__traits(compiles, { xs_[  0 ] = 11; }));

		import std.algorithm.comparison : equal;
		import std.algorithm.iteration : filter;

		assert(equal(xb[].filter!(a => a < 11), [2, 3]));
		assert(equal(xi[].filter!(a => a < 11), [2, 3]));
		assert(equal(xj[].filter!(a => a < 11), [2, 3]));
		assert(equal(xe[].filter!(a => a < 11), [2, 3]));
		// assert(equal(xs[].filter!(a => a < 11), [2, 3]));
	}
}

///
pure nothrow @safe unittest {
	auto x = [1, 2, 3];

	// sample index
	struct Index(T = size_t)
		if (isUnsigned!T)
	{
		this(T ix) { this._ix = ix; }
		T opCast(U : T)() const { return _ix; }
		private T _ix = 0;
	}
	alias J = Index!size_t;

	enum E { e0, e1, e2 }

	with (E)
	{
		auto xb = x.indexedBy!ubyte;
		auto xi = x.indexedBy!uint;
		auto xj = x.indexedBy!J;
		auto xe = x.indexedBy!E;

		// indexing with correct type
		xb[  0 ] = 11; assert(xb[  0 ] == 11);
		xi[  0 ] = 11; assert(xi[  0 ] == 11);
		xj[J(0)] = 11; assert(xj[J(0)] == 11);
		xe[ e0 ] = 11; assert(xe[ e0 ] == 11);

		// slicing with correct type
		xb[  0  ..   1 ] = 12; assert(xb[  0  ..   1 ] == [12]);
		xi[  0  ..   1 ] = 12; assert(xi[  0  ..   1 ] == [12]);
		xj[J(0) .. J(1)] = 12; assert(xj[J(0) .. J(1)] == [12]);
		xe[ e0  ..  e1 ] = 12; assert(xe[ e0  ..  e1 ] == [12]);

		// indexing with wrong type
		static assert(!__traits(compiles, { xb[J(0)] = 11; }));
		static assert(!__traits(compiles, { xi[J(0)] = 11; }));
		static assert(!__traits(compiles, { xj[  0 ] = 11; }));
		static assert(!__traits(compiles, { xe[  0 ] = 11; }));

		// slicing with wrong type
		static assert(!__traits(compiles, { xb[J(0) .. J(0)] = 11; }));
		static assert(!__traits(compiles, { xi[J(0) .. J(0)] = 11; }));
		static assert(!__traits(compiles, { xj[  0  ..   0 ] = 11; }));
		static assert(!__traits(compiles, { xe[  0  ..   0 ] = 11; }));

		import std.algorithm.comparison : equal;
		import std.algorithm.iteration : filter;

		assert(equal(xb.filter!(a => a < 11), [2, 3]));
		assert(equal(xi.filter!(a => a < 11), [2, 3]));
		assert(equal(xj.filter!(a => a < 11), [2, 3]));
		assert(equal(xe.filter!(a => a < 11), [2, 3]));
	}
}

///
pure nothrow @safe unittest {
	auto x = [1, 2, 3];
	struct I(T = size_t)
	{
		this(T ix) { this._ix = ix; }
		T opCast(U : T)() const { return _ix; }
		private T _ix = 0;
	}
	alias J = I!size_t;
	auto xj = x.indexedBy!J;
}

///
pure nothrow @safe unittest {
	auto x = [1, 2, 3];
	struct I(T = size_t)
	{
		private T _ix = 0;
	}
	alias J = I!size_t;
	static assert(!__traits(compiles, { auto xj = x.indexedBy!J; }));
}

///
version (none)
pure nothrow @safe unittest {
	auto x = [1, 2, 3];
	import nxt.bound : Bound;
	alias B = Bound!(ubyte, 0, 2);
	B b;
	auto c = cast(size_t)b;
	auto y = x.indexedBy!B;
}

///
pure nothrow @safe unittest {
	import nxt.container.dynamic_array : Array = DynamicArray;

	enum Lang { en, sv, fr }

	alias Ixs = Array!int;

	struct S {
		Lang lang;
		string data;
		Ixs ixs;
	}

	alias A = Array!S;

	struct I {
		size_t opCast(U : size_t)() const pure nothrow @safe @nogc { return _ix; }
		uint _ix;
		alias _ix this;
	}

	I i;
	static assert(isCastableTo!(I, size_t));
	static assert(isIndexableBy!(A, I));

	alias IA = IndexedBy!(A, I);
	IA ia;
	ia ~= S.init;
	assert(ia.length == 1);
	Ixs ixs;
	ixs.length = 42;
	import std.algorithm.mutation : move;
	auto s = S(Lang.en, "alpha", move(ixs)); /+ TODO: use generic `makeOfLength` +/

	import core.lifetime : move;

	ia ~= move(s);
	assert(ia.length == 2);
}

/** Returns: a `string` containing the definition of an `enum` named `name` and
	with enumerator names given by `Es`, optionally prepended with `prefix` and
	appended with `suffix`.

	TODO: Move to Phobos std.typecons
*/
template makeEnumFromSymbolNames(string prefix = `__`,
								 string suffix = ``,
								 bool firstUndefined = true,
								 bool useMangleOf = false,
								 Es...)
if (Es.length != 0)
{
	enum members =
	{
		string s = firstUndefined ? `undefined, ` : ``;
		foreach (E; Es)
		{
			static if (useMangleOf)
			{
				enum E_ = E.mangleof;
			}
			else
			{
				import std.traits : isPointer;
				static if (isPointer!E)
				{
					import std.traits : TemplateOf;
					enum isTemplateInstance = is(typeof(TemplateOf!(typeof(*E.init))));
					static if (isTemplateInstance) // strip template params for now
					{
						enum E_ = __traits(identifier, TemplateOf!(typeof(*E))) ~ `Ptr`;
					}
					else
					{
						enum E_ = typeof(*E.init).stringof ~ `Ptr`;
					}
				}
				else
				{
					enum E_ = E.stringof;
				}

			}
			s ~= prefix ~ E_ ~ suffix ~ `, `;
		}
		return s;
	}();
	mixin("enum makeEnumFromSymbolNames : ubyte {" ~ members ~ "}");
}

///
pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;
	struct E(T) { T x; }
	alias Types = AliasSeq!(byte, short, int*, E!int*);
	alias Type = makeEnumFromSymbolNames!(`_`, `_`, true, false, Types);
	static assert(is(Type == enum));
	static assert(Type.undefined.stringof == `undefined`);
	static assert(Type._byte_.stringof == `_byte_`);
	static assert(Type._short_.stringof == `_short_`);
	static assert(Type._intPtr_.stringof == `_intPtr_`);
	static assert(Type._EPtr_.stringof == `_EPtr_`);
}

///
pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;

	struct E(T) { T x; }

	alias Types = AliasSeq!(byte, short, int*, E!int*);
	alias Type = makeEnumFromSymbolNames!(`_`, `_`, true, true, Types);

	static assert(is(Type == enum));

	static assert(Type.undefined.stringof == `undefined`);
	static assert(Type._g_.stringof == `_g_`);
	static assert(Type._s_.stringof == `_s_`);
	static assert(Type._Pi_.stringof == `_Pi_`);
}

/**
   See_Also: https://p0nce.github.io/d-idioms/#Rvalue-references:-Understanding-auto-ref-and-then-not-using-it
   */
mixin template RvalueRef()
{
	alias T = typeof(this); // typeof(this) get us the type we're in
	static assert (is(T == struct));

	@nogc @safe
	ref inout(T) asRef() inout pure nothrow return
	{
		return this;
	}
}

@safe @nogc pure nothrow unittest {
	static struct Vec
	{
		@safe @nogc pure nothrow:
		float x, y;
		this(float x, float y) pure nothrow
		{
			this.x = x;
			this.y = y;
		}
		mixin RvalueRef;
	}

	static void foo(ref const Vec pos)
	{
	}

	Vec v = Vec(42, 23);
	foo(v);					 // works
	foo(Vec(42, 23).asRef);	 // works as well, and use the same function
}
