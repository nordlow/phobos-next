/** Traits for introspection the nullability (undefinedness) of a type.
 *
 * If a type is nullable it has a special value reserved in its set of possible
 * which is to indicated that the value is undefined.
 */
module nxt.nullable_traits;

/** Is `true` iff `T` is a type with a standardized null (zero address) value.
 */
template hasStandardNullValue(T)
{
	static if (is(T == class) ||
			   is(T == typeof(null))) // fast compilation path
		enum hasStandardNullValue = true; // fast path first
	else static if (is(T == struct) ||
					is(T == interface) ||
					is(T == union))
		enum hasStandardNullValue = false;
	else						// slow compilation path
		enum hasStandardNullValue = (is(T == U*, U) ||
									 (is(T : const(E)[], E) &&
									  !__traits(isStaticArray, T))); // `isDynamicArrayFast`
}

///
pure nothrow @safe @nogc unittest {
	class C {}
	static assert( hasStandardNullValue!(C));
	static assert( hasStandardNullValue!(int*));
	static assert( hasStandardNullValue!(int[]));
	static assert( hasStandardNullValue!(const(int)[]));
	static assert(!hasStandardNullValue!(int[3]));
	static assert( hasStandardNullValue!(string));
	static assert(!hasStandardNullValue!(int));
}

/** Is `true` iff `T` is a type with a member null value.
 */
enum hasMemberNullValue(T) = __traits(compiles, { T _; _ = T.nullValue; });

///
pure nothrow @safe @nogc unittest {
	class S1
	{
		int x;
		int* xp;
		static nullValue = typeof(this).init;
	}
	static assert(hasMemberNullValue!S1);
}

/** Is `true` iff `T` is a type with a standardized null (zero address) value.
 */
enum hasNullValue(T) = (hasStandardNullValue!T ||
						hasMemberNullValue!T);

///
pure nothrow @safe @nogc unittest {
	static assert(!hasNullValue!int);
	static assert(!hasNullValue!float);
	struct S {
		int value;
		static immutable nullValue = typeof(this).init;
	}
	static assert(hasNullValue!S);
}

/** Is `true` iff `T` is type with a predefined undefined (`null`) value.
 */
template isNullable(T)
{
	/* TODO: remove this two first cases and rely solely on
	 * is(typeof(T.init.nullify()) == void) and
	 * is(typeof(T.init.isNull()) == bool)
	 */
	// use static if's for full lazyness of trait evaluations in order of likelyhood
	static if (is(T == class) ||
			   is(T == typeof(null)) ||
			   (is(T : const(E)[], E) &&
				!__traits(isStaticArray, T))) // `isDynamicArrayFast`
		enum isNullable = true; // fast path first, prevent instantiation of `hasStandardNullValue`
	else static if (hasStandardNullValue!T)
		enum isNullable = true;
	else static if (hasMemberNullValue!T)
		enum isNullable = true;
	else static if (__traits(hasMember, T, "nullifier"))
		enum isNullable = isNullable!(typeof(T.nullifier)); /+ TODO: require it to be an alias? +/
	else static if ((__traits(hasMember, T, "isNull") && // fast
					 __traits(hasMember, T, "nullify"))) // fast
		// lazy: only try semantic analysis when members exists
		enum isNullable = (is(typeof(T.init.isNull()) == bool)  &&
						   is(typeof(T.init.nullify()) == void));
	else
		/+ TODO: remove this later on +/
		// importf std.meta : anySatisfy;
		// static if ((is(T == struct) && // unions excluded for now
		//			 anySatisfy!(isNullable, typeof(T.init.tupleof))))
		// {
		//	 enum isNullable = true;
		// }
		// else
		// {
			enum isNullable = false;
		// }
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;

	class C {}

	static assert( isNullable!(C));
	static assert( isNullable!(int*));
	static assert( isNullable!(int[]));
	static assert( isNullable!(const(int)[]));
	static assert(!isNullable!(int[3]));
	static assert( isNullable!(string));
	static assert( isNullable!(Nullable!int));
	static assert(!isNullable!(int));

	struct S
	{
		int value;
		static immutable nullValue = typeof(this).init;
	}

	struct S2 { C x, y; }
	static assert(!isNullable!S2);

	struct S3 { int x, y; }
	static assert(!isNullable!S3);

	struct S4 { C x, y; alias nullifier = x; }
	static assert(isNullable!S4);
}

/** Default null key of type `T`,
 */
template defaultNullKeyConstantOf(T)
{
	static if (isNullable!T)
		enum defaultNullKeyConstantOf = T.init;
	else
		static assert(0, "Unsupported type " ~ T.stringof);
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;

	static assert(defaultNullKeyConstantOf!(void*) == null);

	alias Ni = Nullable!int;
	static assert(defaultNullKeyConstantOf!(Ni) == Ni.init);

	// alias cNi = const(Nullable!int);
	// static assert(defaultNullKeyConstantOf!(cNi) == cNi.init);

	alias NubM = Nullable!(ubyte, ubyte.max);
	assert(defaultNullKeyConstantOf!(NubM).isNull);

	alias NuiM = Nullable!(uint, uint.max);
	assert(defaultNullKeyConstantOf!(NuiM).isNull);

	const Nullable!(uint, uint.max) x = 13;
	assert(!x.isNull);
	const y = x;
	assert(!y.isNull);
	assert(!x.isNull);
}

/** Returns: `true` iff `x` has a null value.
 */
bool isNull(T)(const scope auto ref T x) pure nothrow @safe @nogc
if (isNullable!(T))
{
	version (D_Coverage) {} else pragma(inline, true);
	static if (is(T == class) ||
			   is(T == typeof(null))) // fast compilation path
		return x is null;
	else static if (is(T : const(E)[], E) &&
					!__traits(isStaticArray, T)) // `isDynamicArrayFast`
		return x.ptr is null;   // no need to check `length`, as in `x.ptr == T.init`
	else static if (hasStandardNullValue!T)
		return x is T.init;
	else static if (hasMemberNullValue!T)
		return x is T.nullValue;
	else static if (__traits(hasMember, T, "nullifier"))
		return x.nullifier.isNull;
	else
		static assert(0, "Unsupported type " ~ T.stringof);
}

void nullify(T)(scope ref T x) pure nothrow @safe @nogc
if (isNullable!(T))
{
	version (D_Coverage) {} else pragma(inline, true);
	static if (is(T == class) ||
			   is(T == typeof(null))) // fast compilation path
		x = null;
	else static if (hasStandardNullValue!T)
		x = T.init;
	else static if (hasMemberNullValue!T)
		x = T.nullValue;
	else static if (__traits(hasMember, T, "nullifier"))
		x.nullifier.nullify();
	else
		static assert(0, "Unsupported type " ~ T.stringof);
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;

	assert(null.isNull);

	assert((int[]).init.isNull);
	immutable int[2] x = [1, 2];
	assert(!x[].isNull);

	alias Ni = Nullable!int;
	assert(Ni.init.isNull);

	Ni ni = 3;
	assert(!ni.isNull);

	ni.nullify();
	assert(ni.isNull);

	const Ni ni2 = 3;
	assert(!ni2.isNull);

	struct S
	{
		uint value;
		static immutable nullValue = S(value.max);
	}
	S s;
	assert(!s.isNull);
	s.nullify();
	assert(s.isNull);
}

///
pure nothrow @safe unittest {
	class C
	{
		@safe pure nothrow
		this(int value)
		{
			this.value = value;
		}
		int value;
	}

	static assert(isNullable!C);

	const x = C.init;
	assert(x.isNull);

	const y = new C(42);
	assert(!y.isNull);
}
