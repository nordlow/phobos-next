/** Traits used by containers.
 *
 * TODO: add `isUnorderedContainer` and `isUnorderedRange` traits and used to
 * forbid hash algorithms to operate on unordered containers (such as
 * `hybrid_hashmap` and `hybrid_hashmap`) and their ranges.
 */
module nxt.container.traits;

public import nxt.gc_traits;

@safe:

/++ Is true iff a `T` can be a assigned from an `U` l-value. +/
enum isLvalueAssignable(T, U = T) = __traits(compiles, { T t; U u; t = u; });

/++ Is true iff a `T` can be a assigned from an `U` r-value
	Opposite to `std.traits.isRvalueAssignable` this correctly handles
	uncopyable types.
 +/
template isRvalueAssignable(T, U = T) {
	static if (__traits(isCopyable, T))
		// needed as special cases such as T=int, U=long
		enum isRvalueAssignable = __traits(compiles, { T t; U u; t = u; });
	else
		// value range propagation (VRP) makes this true for `T=int`, `U=long` because of:
		enum isRvalueAssignable = __traits(compiles, { T t; t = U.init; });
}

@safe pure unittest {
	static assert(isRvalueAssignable!(int, int));
	static assert(!isRvalueAssignable!(int, string));
	static assert(!isRvalueAssignable!(int, long));
	alias E = Uncopyable;
	static assert(isRvalueAssignable!(E, E));
}

/** Is `true` iff `T` is a memory address (either a `class` or a pointer).
	TODO: Replace with __traits(isAddress, T) when it's added.
 */
enum bool isAddress(T) = (is(T == class) ||
						  (is(T == U*, U) &&
						   T.sizeof == size_t.sizeof &&
						   // exclude alias this:
						   !(is(T == struct) ||
							 is(T == union) ||
							 is(T == interface))));

///
pure nothrow @safe @nogc unittest {
	static assert( isAddress!(int*));
	static assert(!isAddress!(int));

	class C {}
	static assert( isAddress!(C));

	struct S {}
	static assert(!isAddress!(S));
	static assert( isAddress!(S*));
}

/** Is `true` iff `T` can and (for performance reasons) should be passed by value.
 *
 * @kinke: "The builtin `__argTypes` is (currently) only used/populated for Posix x64
 * (and AArch64 for LDC), and not used by GDC at all AFAIK".
 *
 * See_Also: https://github.com/dlang/dmd/pull/11000
 * See_Also: https://github.com/dlang/dmd/pull/11000#issuecomment-671103778
 */
enum shouldBePassedByValue(T) = (__traits(isPOD, T) && is(T U == __argTypes) && U.length >= 1);

/** True if the last reference of a `T` in the scope of its lifetime should be
 * passed by move instead of by copy either because
 *
 * - it cannot be copied or
 * - because it has an elaborate constructor or elaborate destructor that can be
 *   elided via a move.
 *
 * This excludes arrays and classes.
 *
 * Note that `__traits(isPOD, T)` implies
 * `core.internal.traits.hasElaborateAssign!T ||
 *  core.internal.traits.hasElaborateDestructor!T`.
 *
 * See_Also: `std.traits.hasElaborateMove`.
 */
enum bool shouldMove(T) = !__traits(isPOD, T);

///
pure @safe unittest {
	static assert(!shouldMove!(char));
	static assert(!shouldMove!(int));
	static assert(!shouldMove!(string));
	static assert(!shouldMove!(int[]));

	class C {}
	static assert(!shouldMove!(C));

	struct POD {}
	static assert(!shouldMove!(POD));

	static assert(shouldMove!(Uncopyable));

	struct WithDtor { ~this() nothrow {} }
	static assert(shouldMove!(WithDtor));
}

/+ TODO: this can be simplified for faster compilation +/
template ContainerElementType(ContainerType, ElementType) {
	import std.traits : isMutable, hasIndirections, PointerTarget, isPointer,
		Unqual;

	template ET(bool isConst, T) {
		static if (isPointer!ElementType) {
			enum PointerIsConst = is(ElementType == const);
			enum PointerIsImmutable = is(ElementType == immutable);
			enum DataIsConst = is(PointerTarget!ElementType == const);
			enum DataIsImmutable = is(PointerTarget!ElementType == immutable);
			static if (isConst) {
				static if (PointerIsConst)
					alias ET = ElementType;
				else static if (PointerIsImmutable)
					alias ET = ElementType;
				else
					alias ET = const(PointerTarget!ElementType)*;
			}
			else
			{
				static assert(DataIsImmutable,
							  "An immutable container cannot reference const or mutable data");
				static if (PointerIsConst)
					alias ET = immutable(PointerTarget!ElementType)*;
				else
					alias ET = ElementType;
			}
		}
		else
		{
			static if (isConst) {
				static if (is(ElementType == immutable))
					alias ET = ElementType;
				else
					alias ET = const(Unqual!ElementType);
			}
			else
				alias ET = immutable(Unqual!ElementType);
		}
	}

	static if (isMutable!ContainerType)
		alias ContainerElementType = ElementType;
	else
	{
		static if (hasIndirections!ElementType)
			alias ContainerElementType = ET!(is(ContainerType == const), ElementType);
		else
			alias ContainerElementType = ElementType;
	}
}

/// Returns: `true` iff `T` is a template instance, `false` otherwise.
private template isTemplateInstance(T) {
	import std.traits : TemplateOf;
	enum isTemplateInstance = is(typeof(TemplateOf!(T)));
}

/** Is `true` iff `T` is a set like container. */
template isSet(T) {
	import std.range.primitives : hasLength;
	enum isSet = (__traits(hasMember, T, "insert") && /+ TODO: assert O(1) +/
				  __traits(hasMember, T, "remove") && /+ TODO: assert O(1) +/
				  __traits(compiles, { auto _ = T.init.byElement; }));
}

/** Is `true` iff `T` is a set like container with elements of type `E`. */
template isSetOf(T, E) {
	import std.range.primitives : hasLength;
	enum isSetOf = (is(typeof(T.init.insert(E.init))) && /+ TODO: assert O(1) +/
					is(typeof(T.init.remove(E.init))) && /+ TODO: assert O(1) +/
					__traits(compiles, { auto _ = T.init.byElement; }));
}

/** Allocate an array of `T`-elements of length `length` using `allocator`.
 */
T[] makeInitZeroArray(T, alias allocator)(const size_t length) @trusted
{
	version (none)			   /+ TODO: activate +/
	{
		// See: https://github.com/dlang/phobos/pull/6411
		import std.experimental.allocator.gc_allocator : GCAllocator;
		static if (__traits(hasMember, GCAllocator, "allocateZeroed")) {
			static assert(0, "Use std.experimental.allocator.package.make!(T) instead because it makes use of allocateZeroed.");
		}
	}
	immutable byteCount = T.sizeof * length;
	/* when possible prefer call to calloc before malloc+memset:
	 * https://stackoverflow.com/questions/2688466/why-mallocmemset-is-slower-than-calloc */
	static if (__traits(hasMember, allocator, "allocateZeroed")) {
		version (D_Coverage) {} else pragma(inline, true);
		return cast(typeof(return))allocator.allocateZeroed(byteCount);
	}
	else
	{
		auto array = cast(typeof(return))allocator.allocate(byteCount);
		import core.stdc.string : memset;
		memset(array.ptr, 0, byteCount);
		return array;
	}
}

/** Variant of `hasElaborateDestructor` that also checks for destructor when `S`
 * is a `class`.
 *
 * See_Also: https://github.com/dlang/phobos/pull/4119
 */
template hasElaborateDestructorNew(S) {
	static if (is(S == struct) ||
			   is(S == class)) // check also class
	{
		static if (__traits(hasMember, S, "__dtor"))
			enum bool hasElaborateDestructorNew = true;
		else
		{
			import std.traits : FieldTypeTuple;
			import std.meta : anySatisfy;
			enum hasElaborateDestructorNew = anySatisfy!(.hasElaborateDestructorNew, FieldTypeTuple!S);
		}
	}
	else
	{
		static if (__traits(isStaticArray, S) && S.length)
			enum bool hasElaborateDestructorNew = hasElaborateDestructorNew!(typeof(S.init[0]));
		else
			enum bool hasElaborateDestructorNew = false;
	}
}

version (unittest) {
	private static struct Uncopyable { this(this) @disable; int _x; }
}
