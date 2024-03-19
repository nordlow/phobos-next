/** Various extensions to std.traits.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	See_Also: http://forum.dlang.org/thread/jbyixfbuefvdlttnyclu@forum.dlang.org#post-mailman.2199.1353742037.5162.digitalmars-d-learn:40puremagic.com
	See_Also: http://forum.dlang.org/post/rjrdgmijsmvvsbpinidz@forum.dlang.org
*/
module nxt.traits_ex;

import std.traits: isArray, ParameterTypeTuple, isDynamicArray, isSomeChar, isSomeString, isExpressions, isIntegral, isSigned, isUnsigned, isAssignable, isIterable;
import std.meta : allSatisfy;
import std.range: ElementType, isForwardRange, isRandomAccessRange, isInputRange, isBidirectionalRange, isOutputRange;

/** Returns: `true` iff $(D ptr) is handled by D's garbage collector (GC).
 */
bool isGCPointer(T)(const T* ptr)
	@trusted nothrow @nogc
{
	import core.memory : GC;
	return cast(bool)GC.addrOf(ptr);
}

///
@system nothrow unittest {
	int s;
	int* sp = &s;
	assert(!sp.isGCPointer);
	int* ip = new int;
	assert(ip.isGCPointer);
}

/** Returns: `true` iff all values `V` are the same.
 *
 * See_Also: https://forum.dlang.org/post/lnsreapgttmdeuscsupp@forum.dlang.org
 */
template allSameIterative(V...)
{
	static if (V.length <= 1)
		enum allSameIterative = true;
	else
	{
		static foreach (Vi; V[1 .. $])
			static if (is(typeof(allSameIterative) == void) && // not yet defined
					   !isSame!(V[0], Vi))
				enum allSameIterative = false;
		static if (is(typeof(allSameIterative) == void)) // if not yet defined
			enum allSameIterative = true;
	}
}

///
pure nothrow @safe @nogc unittest {
	static assert( allSameIterative!());
	static assert( allSameIterative!(42));
	static assert( allSameIterative!(42, 42));
	static assert( allSameIterative!(42, 42, 42));
	static assert(!allSameIterative!(42, 43, 42));

	static assert( allSameIterative!(int));
	static assert( allSameIterative!(int, int));
	static assert( allSameIterative!(int, int, int));
	static assert(!allSameIterative!(int, byte, int));
}

alias allSame = allSameIterative; // default to iterative variant for now
alias isHomogeneousType = allSame;
enum isHomogeneousTuple(T) = isHomogeneousType!(T.Types);

///
pure nothrow @safe @nogc unittest {
	static assert(isHomogeneousTuple!(Tuple!(int, int, int)));
	static assert(isHomogeneousTuple!(Tuple!(float, float, float)));
	static assert(!isHomogeneousTuple!(Tuple!(int, float, double)));
}

enum isHomogeneousTupleOf(T, E) = (isHomogeneousType!(T) &&
								   is(T.Types[0] == E));

///
pure nothrow @safe @nogc unittest {
	static assert(isHomogeneousTupleOf!(Tuple!(int, int, int), int));
	static assert(isHomogeneousTupleOf!(Tuple!(float, float, float), float));
	static assert(!isHomogeneousTupleOf!(Tuple!(float, float, float), int));
}

/**
   Returns $(D true) if at least one type in the $(D Tuple T)
   is not the same as the others.
*/
enum isHeterogeneous(T) = !isHomogeneousType!T;

template allSameTypeIterative(V...)
/+ TODO: restrict `V` to types only +/
{
	static if (V.length >= 2)
		static foreach (Vi; V[1 .. $])
			static if (is(typeof(allSameTypeIterative) == void) && // not yet defined
					   !is(V[0] == Vi)) // 10% faster than `!isSame(V[0], Vi)`
				enum allSameTypeIterative = false;
	static if (is(typeof(allSameTypeIterative) == void)) // if not yet defined
		enum allSameTypeIterative = true;
}
alias allSameType = allSameTypeIterative;

///
pure nothrow @safe @nogc unittest {
	static assert( allSameTypeIterative!(int));
	static assert( allSameTypeIterative!(int, int));

	static assert( allSameTypeIterative!(int, int, int));
	static assert(!allSameTypeIterative!(int, byte, int));

	static assert( allSameTypeIterative!(int, int, int, int));
	static assert(!allSameTypeIterative!(int, byte, int, byte));

	static assert(!allSameTypeIterative!(int, const(int)));
	static assert(!allSameTypeIterative!(byte, const(int)));
}

/** Returns: `true` iff all values `V` are the same.

	Same as NoDuplicates!V.length == 1

	See_Also: https://forum.dlang.org/post/ptnzlhnkuetijhgrgumd@forum.dlang.org
	See_Also: http://forum.dlang.org/post/iflpslqgrixdjwrlqqvn@forum.dlang.org
	See_Also: http://forum.dlang.org/post/mheumktihihfsxxxapff@forum.dlang.org
*/
template allSameRecursive(V...)
if (isExpressions!V)
{
	static if (V.length <= 1)
		enum allSameRecursive = true;
	else static if (V.length & 1) // odd count
		enum allSameRecursive = (V[0] == V[$ - 1] && // first equals last
								 V[0 .. $/2] == V[$/2 .. $-1] && // (first half) equals (second half minus last element)
								 allSameRecursive!(V[0 .. $/2]));
	else						// event count
		enum allSameRecursive = (V[0 .. $/2] == V[$/2 .. $] && // (first half) equals (second half)
								 allSameRecursive!(V[0 .. $/2]));
}

///
pure nothrow @safe @nogc unittest {
	static assert( allSameRecursive!());
	static assert( allSameRecursive!(42));
	static assert( allSameRecursive!(42, 42));
	static assert( allSameRecursive!(42, 42, 42));
	static assert(!allSameRecursive!(42, 43, 42));
}

template allSameTypeHybrid(V...)
/+ TODO: restrict `V` to types only +/
{
	static if (V.length >= 8)
	{
		static if (V.length <= 1)
			enum allSameTypeHybrid = true;
		else static if (V.length == 2)
			enum allSameTypeHybrid = is(V[0] == V[1]);
		static if (V.length & 1) // odd count
			enum allSameTypeHybrid = (is(V[0] == V[$ - 1]) && // first equals last
									  is(V[0 .. $/2] == V[$/2 .. $-1]) && // (first half) equals (second half minus last element)
									  allSameTypeHybrid!(V[0 .. $/2]));
		else						// even count
			enum allSameTypeHybrid = (is(V[0 .. $/2] == V[$/2 .. $]) && // (first half) equals (second half)
									  allSameTypeHybrid!(V[0 .. $/2]));
	}
	else
		enum allSameTypeHybrid = allSameTypeIterative!(V);
}

///
pure nothrow @safe @nogc unittest {
	static assert(allSameTypeHybrid!());
	static assert(allSameTypeHybrid!(int));
	static assert(allSameTypeHybrid!(int, int));
	static assert(!allSameTypeHybrid!(int, double));
	static assert(!allSameTypeHybrid!(int, int, double));
	static assert(allSameTypeHybrid!(Tuple!(int, int, int).Types, int));

	static assert(!allSameTypeHybrid!(int, const(int)));
	static assert(!allSameTypeHybrid!(byte, const(int)));
}

/** Variant of `allSameTypeRecursive`.
 */
template allSameTypeRecursive2(V...)
	if (isExpressions!(V))
{
	static if (V.length <= 1)
		enum allSameTypeRecursive2 = true;
	else
		enum allSameTypeRecursive2 = (V[0] == V[1] &&
									  allSameTypeRecursive2!(V[1..$]));
}

///
pure nothrow @safe @nogc unittest {
	static assert(allSameTypeRecursive2!());
	static assert(allSameTypeRecursive2!(42));
	static assert(!allSameTypeRecursive2!(41, 42));
	static assert(allSameTypeRecursive2!(42, 42, 42));
}

/** Returns: `true` iff all types `T` are the same.
 */
template allSameTypeRecursive(V...)
/+ TODO: restrict `V` to types only +/
{
	static if (V.length <= 1)
		enum allSameTypeRecursive = true;
	else static if (V.length & 1) // odd count
		enum allSameTypeRecursive = (is(V[0] == V[$ - 1]) && // first equals last
									 is(V[0 .. $/2] == V[$/2 .. $-1]) && // (first half) equals (second half minus last element)
									 allSameTypeRecursive!(V[0 .. $/2]));
	else						// even count
		enum allSameTypeRecursive = (is(V[0 .. $/2] == V[$/2 .. $]) && // (first half) equals (second half)
									 allSameTypeRecursive!(V[0 .. $/2]));
}

///
pure nothrow @safe @nogc unittest {
	static assert(allSameTypeRecursive!());
	static assert(allSameTypeRecursive!(int));
	static assert(allSameTypeRecursive!(int, int));
	static assert(!allSameTypeRecursive!(int, double));
	static assert(!allSameTypeRecursive!(int, int, double));
	static assert(allSameTypeRecursive!(Tuple!(int, int, int).Types, int));

	static assert(!allSameTypeRecursive!(int, const(int)));
	static assert(!allSameTypeRecursive!(byte, const(int)));
}

/** Returns: `true` iff all types `T` are the same. */
enum allSameType_alternative(T...) = (!T.length ||
									  (is(T[0] == T[T.length > 1]) &&
									   allSameType1!(T[1 .. $])));


import std.typecons : isTuple;

/**
   Returns $(D true) if all types in the $(D Tuple T) are the same.
   TODO: Remove when this is merged: https://github.com/D-Programming-Language/phobos/pull/3395
   See_Also: https://github.com/D-Programming-Language/phobos/pull/1672/files
*/
template allSameTypesInTuple(T)
	if (isTuple!T)
{
	alias types = T.Types;
	static if (types.length > 0)
	{
		template isSameTypeAsHead(U)
		{
			enum isSameTypeAsHead = is(U == types[0]);
		}
		import std.meta : allSatisfy;
		enum allSameTypesInTuple = allSatisfy!(isSameTypeAsHead, types);
	}
	else
		enum allSameTypesInTuple = true;
}

///
pure nothrow @safe unittest {
	alias HOTUP = Tuple!(int, int, int);
	static assert(allSameTypesInTuple!HOTUP);

	const HOTUP hotup = HOTUP(1, 2, 3);
	static assert(allSameTypesInTuple!(typeof(hotup)));

	alias HETUP = Tuple!(string, bool, float);
	static assert(!allSameTypesInTuple!(HETUP));

	const HETUP hetup = HETUP("test", false, 2.345);
	static assert(!allSameTypesInTuple!(typeof(hetup)));

	alias ZTUP = Tuple!();
	static assert(allSameTypesInTuple!ZTUP);

	const ZTUP ztup = ZTUP();
	static assert(allSameTypesInTuple!(typeof(ztup)));
}

/** Returns: tuple `tup` as a dynamic array.
 */
auto asDynamicArray(T)(inout T tup)
	if (allSameTypeRecursive!(T.Types))
{
	alias E = T.Types[0];
	E[] a = new E[T.length];
	a.length = T.length;
	foreach (const i, e; tup)
		a[i] = e;
	return a;
}

///
pure nothrow unittest {
	import std.typecons: tuple;
	auto tup = tuple("a", "b", "c", "d");
	string[4] arr = ["a", "b", "c", "d"];
	assert(tup.asDynamicArray() == arr);
}

/** Is `true` if `R` is iterable over references to its elements.
 *
 * Typically used to iterate over ranges with uncopyable elements.
 *
 * TODO: Move to Phobos.
 */
enum bool isRefIterable(T) = is(typeof({ foreach (ref elem; T.init) {} }));

/// Useful aliases for combinations of range predicates.
enum isIterableOf(R, E) = isIterable!R && is(ElementType!R == E);
enum isIterableOfSomeString(R) = (isIterable!R && isSomeString!(ElementType!R));

///
pure nothrow @safe @nogc unittest {
	alias E = string;
	alias I = int;
	alias R = typeof(["a", "b"]);
	static assert(isIterableOf!(R, E));
	static assert(isIterableOfSomeString!(R));
	static assert(!isIterableOf!(R, I));
}

/// Useful aliases for combinations of range predicates.
alias isForwardRangeOf = isForwardRange;
alias isInputRangeOf = isInputRange;

enum isOutputRangeOf(R, E) = isOutputRange!R && is(ElementType!R == E);
enum isArrayOf(R, E) = isArray!R && is(ElementType!R == E);
enum isArrayOfSomeString(R) = isArray!R && isSomeString!(ElementType!R);

enum isSourceAssignableTo(R, E) = (isInputRange!R &&
								   isAssignable!(E, ElementType!R));

///
pure @safe unittest {
	static assert(isSomeString!(string));
	static assert(isSomeString!(const string));

	static assert(isSomeString!(const(char)[]));
	static assert(isSomeString!(const char[]));
}

pure nothrow @safe @nogc unittest {
	alias R = typeof(["a", "b"]);
	static assert(isArrayOf!(R, string));
	static assert(isArrayOfSomeString!(R));
}

enum isSource(R) = isInputRange!(R);
enum isRange(R) = isInputRange!(R);

enum isSourceOf(R, E) = isInputRangeOf!(R, E);
private enum isSink(R) = isOutputRange!(R);
private enum isSinkOf(R, E) = isOutputRangeOf!(R, E);

enum isSourceOfSomeChar(R) = (isSource!R &&
							  isSomeChar!(ElementType!R));
alias isSomeLazyString = isSourceOfSomeChar;

pure nothrow @safe @nogc unittest {
	import std.meta : AliasSeq;
	foreach (Ch; AliasSeq!(char, wchar, dchar))
	{
		assert(isSourceOfSomeChar!(Ch[]));
		assert(isSourceOfSomeChar!(const(Ch)[]));
		assert(isSourceOfSomeChar!(immutable(Ch)[]));
	}
}

enum isSourceOfSomeString(R) = (isSource!R && isSomeString!(ElementType!R));
alias isSomeStringSource = isSourceOfSomeString;

import std.functional: unaryFun, binaryFun;

/* TODO: Do we need use of unaryFun and binaryFun here? */
alias isEven = unaryFun!(a => (a & 1) == 0); // Limit to Integers?
alias isOdd = unaryFun!(a => (a & 1) == 1); // Limit to Integers?
alias lessThan = binaryFun!((a, b) => a < b);
alias greaterThan = binaryFun!((a, b) => a > b);

/** Check if `T` has an even length. */
enum hasEvenLength(T...) = !(T.length & 1);
pure nothrow @safe @nogc unittest {
	static assert(!hasEvenLength!(1));
	static assert(hasEvenLength!(1, 2));
	static assert(!hasEvenLength!(1, 2, 3));
	static assert(hasEvenLength!(1, 2, 3, 4));
}

enum isSignedIntegral(T) = isIntegral!T && isSigned!T;
enum isUnsignedIntegral(T) = isIntegral!T && isUnsigned!T;

enum isString (T) = is(T == string);
enum isWString(T) = is(T == wstring);
enum isDString(T) = is(T == dstring);

enum isEnum(T) = is(T == enum);
pure nothrow @safe @nogc unittest {
	interface I {}
	class A {}
	class B( T ) {}
	class C : B!int, I {}
	struct S {}
	enum E { X }
	static assert(!isEnum!A );
	static assert(!isEnum!( B!int ) );
	static assert(!isEnum!C );
	static assert(!isEnum!I );
	static assert(isEnum!E );
	static assert(!isEnum!int );
	static assert(!isEnum!( int* ) );
}

/* See_Also: http://d.puremagic.com/issues/show_bug.cgi?id=4427 */
enum isStruct(T) = is(T == struct);
pure nothrow @safe @nogc unittest {
	interface I {}
	class A {}
	class B( T ) {}
	class C : B!int, I {}
	struct S {}
	static assert(!isStruct!A );
	static assert(!isStruct!( B!int ) );
	static assert(!isStruct!C );
	static assert(!isStruct!I );
	static assert(isStruct!S );
	static assert(!isStruct!int );
	static assert(!isStruct!( int* ) );
}

enum isClass(T) = is(T == class);
pure nothrow @safe @nogc unittest {
	interface I {}
	class A {}
	class B( T ) {}
	class C : B!int, I {}
	struct S {}
	static assert(isClass!A );
	static assert(isClass!( B!int ) );
	static assert(isClass!C );
	static assert(!isClass!I );
	static assert(!isClass!S );
	static assert(!isClass!int );
	static assert(!isClass!( int* ) );
}

enum isInterface(T) = is(T == interface);
pure nothrow @safe @nogc unittest {
	interface I {}
	class A {}
	class B( T ) {}
	class C : B!int, I {}
	struct S {}
	static assert(!isInterface!A );
	static assert(!isInterface!( B!int ) );
	static assert(!isInterface!C );
	static assert(isInterface!I );
	static assert(!isInterface!S );
	static assert(!isInterface!int );
	static assert(!isInterface!( int* ) );
}

template isType(T)	   { enum isType = true; }
template isType(alias T) { enum isType = false; }

pure nothrow @safe @nogc unittest {
	struct S { alias int foo; }
	static assert(isType!int );
	static assert(isType!float );
	static assert(isType!string );
	//static assert(isType!S ); // Bugzilla 4431
	static assert(isType!( S.foo ) );
	static assert(!isType!4 );
	static assert(!isType!"Hello world!" );
}

enum nameOf(alias a) = a.stringof;
///
pure nothrow @safe @nogc unittest {
	int var;
	static assert(nameOf!var == var.stringof);
}

/** Is $(D ElementType) of type of $(D a). */
alias ElementTypeOf(alias a) = ElementType!(typeof(a));
///
pure nothrow @safe @nogc unittest {
	int[] var;
	static assert(is(ElementTypeOf!var == int));
}

template Chainable()
{
	import std.range: chain;
	auto ref opCast(Range)(Range r)
	{
		return chain(this, r);
	}
}
pure nothrow @safe @nogc unittest { mixin Chainable; }

/** Returns true if `T` is an instance of the template `S`.
	See_Also: http://forum.dlang.org/thread/mailman.2901.1316118301.14074.digitalmars-d-learn@puremagic.com#post-zzdpfhsgfdgpszdbgbbt:40forum.dlang.org
*/
template isA(alias S, T)
{
	enum isA = is(T == S!(_), _);
}

pure nothrow @safe @nogc unittest {
	import std.range : SortedRange, assumeSorted;
	const x = [1, 2, 3].s[].assumeSorted;
	static assert(is(typeof(x) == SortedRange!(_), _...));
	static assert(isA!(SortedRange, typeof(x)));
}

/** See_Also: http://forum.dlang.org/thread/bug-6384-3@http.d.puremagic.com/issues/
	See_Also: http://forum.dlang.org/thread/jrqiiicmtpenzokfxvlz@forum.dlang.org */
enum isOpBinary(T, string op, U) = is(typeof(mixin("T.init" ~ op ~ "U.init")));

enum isComparable(T) = is(typeof({ return T.init <  T.init; })); //+ TODO: Move to Phobos std.traits +/
enum isEquable   (T) = is(typeof({ return T.init == T.init; })); //+ TODO: Move to Phobos std.traits +/
enum isNotEquable(T) = is(typeof({ return T.init != T.init; })); //+ TODO: Move to Phobos std.traits +/

pure nothrow @safe @nogc unittest {
	static assert(isComparable!int);
	static assert(isComparable!string);
	static assert(!isComparable!creal);
	static struct Foo {}
	static assert(!isComparable!Foo);
	static struct Bar { bool opCmp(Bar) { return true; } }
	static assert(isComparable!Bar);
}

/+ TODO:  variadic +/
enum areComparable(T, U) = is(typeof({ return T.init <  U.init; })); //+ TODO: Move to Phobos std.traits +/
enum areEquable   (T, U) = is(typeof({ return T.init == U.init; })); //+ TODO: Move to Phobos std.traits +/
enum areNotEquable(T, U) = is(typeof({ return T.init != U.init; })); //+ TODO: Move to Phobos std.traits +/

pure nothrow @safe @nogc unittest {
	static assert(areComparable!(int, float));
	static assert(areEquable!(int, float));
	static assert(areNotEquable!(int, float));

	static assert(!areComparable!(int, string));
	static assert(!areEquable!(int, string));
	static assert(!areNotEquable!(int, string));
}

enum isValueType(T) = !hasIndirections!T;
enum hasValueSemantics(T) = !hasIndirections!T; /+ TODO: merge with isValueType +/
enum isReferenceType(T) = hasIndirections!T;

enum arityMin0(alias fun) = __traits(compiles, fun());

/** TODO: Unite into a variadic.
	See_Also: http://forum.dlang.org/thread/bfjwbhkyehcloqcjzxck@forum.dlang.org#post-atjmewbffdzeixrviyoa:40forum.dlang.org
*/
enum isCallableWith(alias fun, T) = (is(typeof(fun(T.init))) ||
									 is(typeof(T.init.fun))); /+ TODO: Are both these needed? +/
pure nothrow @safe @nogc unittest {
	auto sqr(T)(T x) { return x*x; }
	assert(isCallableWith!(sqr, int));
	assert(!isCallableWith!(sqr, string));
}

/* TODO: Unite into a variadic.
   See_Also: http://forum.dlang.org/thread/bfjwbhkyehcloqcjzxck@forum.dlang.org#post-atjmewbffdzeixrviyoa:40forum.dlang.org
 */
enum isCallableWith(alias fun, T, U) = (is(typeof(fun(T.init,
													  U.init))) ||
										is(typeof(T.init.fun(U)))); /+ TODO: Are both these needed? +/
pure nothrow @safe @nogc unittest {
	auto sqr2(T)(T x, T y) { return x*x + y*y; }
	assert(isCallableWith!(sqr2, int, int));
	assert(!isCallableWith!(sqr2, int, string));
}

/** Check if `T` is a Sorted Range.
	See_Also: http://forum.dlang.org/thread/lt1g3q$15fe$1@digitalmars.com
*/
template isSortedRange(T)
{
	import std.range: SortedRange;
	enum isSortedRange = is(T == SortedRange!(_), _); /+ TODO: Or use: __traits(isSame, TemplateOf!R, SortedRange) +/
}

/** Check if Function $(D expr) is callable at compile-time.
	See_Also: http://forum.dlang.org/thread/owlwzvidwwpsrelpkbok@forum.dlang.org
*/
template isCTFEable(alias fun)
{
	template isCTFEable_aux(alias T)
	{
		enum isCTFEable_aux = T;
	}
	enum isCTFEable = __traits(compiles, isCTFEable_aux!(fun()));
}

template isCTFEable2(fun...)
{
	enum isCTFEable2 = true;
}

pure nothrow @safe unittest {
	int fun1() { return 1; }
	auto fun1_N()
	{
		import std.array;
//would return Error: gc_malloc cannot be interpreted at compile time,
		/* because it has no available source code due to a bug */
			return [1].array;
	}
	int fun2(int x)
	{
		return 1;
	}
	auto fun2_N(int x){
		import std.array;
//same as fun1_N
		return [1].array;
	}

	int a1;
	enum a2=0;

	static assert(!isCTFEable!(()=>a1));
	static assert(isCTFEable!(()=>a2));

	static assert(isCTFEable!fun1);
	/* static assert(!isCTFEable!fun1_N); */

	static assert(isCTFEable!(()=>fun2(0)));
	/* static assert(!isCTFEable!(()=>fun2_N(0))); */
//NOTE:an alternate syntax which could be implemented would be: static
	/* assert(!isCTFEable!(fun2_N,0)); */
}

/** Check if the value of $(D expr) is known at compile-time.
	See_Also: http://forum.dlang.org/thread/owlwzvidwwpsrelpkbok@forum.dlang.org
*/
enum isCTEable(alias expr) = __traits(compiles, { enum id = expr; });

pure nothrow @safe @nogc unittest {
	static assert(isCTEable!11);
	enum x = 11;
	static assert(isCTEable!x);
	auto y = 11;
	static assert(!isCTEable!y);
}

import std.traits: hasFunctionAttributes, isCallable, ParameterTypeTuple, Unqual;

/** Returns $(D true) if `T` is not $(D const) or $(D immutable).
	Note that isConst is true for string, or immutable(char)[], because the
	'head' is mutable.
*/
import std.traits : isMutable;
enum isConst(T) = !isMutable!T;

pure nothrow @safe @nogc unittest {
	static assert(isConst!(const(int)));
	static assert(!isConst!int);
}

import std.traits : CommonType;

/// Is `true` iff `Types` all share a common type.
enum bool haveCommonType(Types...) = !is(CommonType!Types == void);

///
pure nothrow @safe @nogc unittest {
	static assert(haveCommonType!(bool, int, long));
	static assert(!haveCommonType!(bool, int, string));
}

/** Check if $(D fun) is a pure function. */
enum bool isPure(alias fun) = hasFunctionAttributes!(fun, `pure`);

/** Check if $(D fun) is a function purely callable with arguments T. */
enum bool isPurelyCallableWith(alias fun, T...) = (isPure!fun &&
												   is(T == ParameterTypeTuple!fun));

///
pure nothrow @safe @nogc unittest {
	static int foo(int x) @safe pure nothrow { return x; }
	static assert(isPure!foo);
	static assert(isPurelyCallableWith!(foo, int));
}

/** Check if $(D fun) is a @nogc function.
	See_Also: http://forum.dlang.org/thread/dyumjfmxmstpgyxbozry@forum.dlang.org
*/
enum bool isNogc(alias fun) = hasFunctionAttributes!(fun, `@nogc`);

///
pure nothrow @safe @nogc unittest {
	static int foo(int x) @nogc pure nothrow;
	static int goo(int x) pure nothrow;
	static assert(isNogc!foo);
	static assert(!isNogc!goo);
}

/** Persistently Call Function $(D fun) with arguments $(D args).

	Hash Id Build-Timestamp (Code-Id because we currently have stable way of hashing-algorithms) is Constructed from Data Structure:
	- Hierarchically Mangled Unqual!typeof(instance)
	- Use msgpack in combination with sha1Of or only sha1Of (with extended
	overloads for sha1Of) if available.

	Extend std.functional : memoize to accept pure functions that takes an
	immutable mmap as input. Create wrapper that converts file to immutable mmap
	and performs memoization on the pure function.

*/
auto persistentlyMemoizedCall(alias fun, T...)(T args)
	if (isPure!fun &&
		isCallable!(fun, args))
{
	import std.functional: memoize;
	return fun(args);
}

/** Move std.uni.newLine?
	TODO: What to do with Windows style endings?
	See_Also: https://en.wikipedia.org/wiki/Newline
*/
bool isNewline(C)(C c) pure nothrow @safe @nogc
	if (isSomeChar!C)
{
	import std.ascii: newline; /+ TODO: Probably not useful. +/
	static if (newline == "\n")
		return (c == '\n' || c == '\r'); // optimized for systems with \n as default
	else static if (newline == "\r")
		return (c == '\r' || c == '\n'); // optimized for systems with \r as default
	else
		static assert(0, "Support Windows?");
}

bool isNewline(S)(S s) pure nothrow @safe @nogc
	if (isSomeString!S)
{
	import std.ascii: newline; /+ TODO: Probably not useful. +/
	static if (newline == "\n")
		return (s == '\n' || s == '\r'); // optimized for systems with \n as default
	else static if (newline == "\r")
		return (s == '\r' || s == '\n'); // optimized for systems with \r as default
	else static if (newline == "\r\n")
		return (s == "\r\n" || s == '\r' || s == '\n'); // optimized for systems with \r\n as default
	else static if (newline == "\n\r")
		return (s == "\n\r" || s == '\r' || s == '\n'); // optimized for systems with \n\r as default
	else
		static assert(0, "Support windows?");
}

/** Dynamic variant of $(D EnumMembers) returning enum member constants
 * (enumerators) of `T`.
 *
 * See_Also: http://forum.dlang.org/thread/bspwlfypfishykezzocx@forum.dlang.org#post-dguqnroxbfewerepomwq:40forum.dlang.org
 */
T[] enumMembersAsEnumerators(T)()
if (is(T == enum))
{
	import std.array : Appender;
	Appender!(T[]) members; /+ TODO: use static array instead +/
	enum lengthMax = T.max - T.min + 1; // possibly overestimate of final length needed
	members.reserve(lengthMax);
	foreach (const member; __traits(allMembers, T))
		members.put(__traits(getMember, T, member));
	return members.data[];
}

/** Dynamic Variant of $(D EnumMembers) excluding the enumerator aliases.
 *
 * See_Also: http://forum.dlang.org/post/ziappmtvucmuefphblse@forum.dlang.org
 * See_Also: http://forum.dlang.org/post/awihyvzjswwayeqtklly@forum.dlang.org
 * See_Also: http://forum.dlang.org/thread/bspwlfypfishykezzocx@forum.dlang.org#post-dguqnroxbfewerepomwq:40forum.dlang.org
 * See_Also: https://issues.dlang.org/show_bug.cgi?id=10951
 */
auto uniqueEnumMembers(T)() @trusted
if (is(T == enum))
{
	import std.array : Appender;
	Appender!(T[]) uniqueMembers;
	enum lengthMax = T.max - T.min + 1; // possibly overestimate of final length
	uniqueMembers.reserve(lengthMax);
	enum maxBitCount = ((lengthMax / (8*size_t.sizeof)) +
						(lengthMax % (8*size_t.sizeof) ? 1 : 0));
	size_t[maxBitCount] uniqueBits; // dense set representation of enumerators
	foreach (const member; __traits(allMembers, T))
	{
		const memberEnumerator = __traits(getMember, T, member);
		const member_ = cast(size_t)memberEnumerator;
		import core.bitop : bt, bts;
		if (!bt(&uniqueBits[0], member_))
		{
			uniqueMembers.put(memberEnumerator);
			bts(&uniqueBits[0], member_);
		}
	}
	return uniqueMembers.data[];
}

///
@safe pure nothrow /*@nogc*/ unittest {
	enum E { x, y, z, Z = z, Y = y }
	import std.algorithm.comparison : equal;
	assert(enumMembersAsEnumerators!E.equal([E.x, E.y, E.z, E.Z, E.Y])); // run-time
	assert(uniqueEnumMembers!E.equal([E.x, E.y, E.z])); // run-time
	// static assert(uniqueEnumMembers!E.equal([E.x, E.y, E.z])); // compile-time
	static assert(E.x == 0);
	static assert(E.y == 1);
	static assert(E.z == 2);
	static assert(E.Z == E.z);
	static assert(E.Y == E.y);
}

enum sizeOf(T) = T.sizeof;	  /+ TODO: Move to Phobos +/
template sizesOf(T...)		  /+ TODO: Move to Phobos +/
{
	import std.meta : staticMap;
	enum sizesOf = staticMap!(sizeOf, T);
}

///
pure nothrow @safe unittest {
	enum sizes = sizesOf!(bool, short, int, long);

	// static use
	static assert(sizes[0] == 1);
	static assert(sizes[1] == 2);
	static assert(sizes[2] == 4);
	static assert(sizes[3] == 8);

	// dynamic use
	const i = 0;
	assert([sizes][i] == 1);
}

enum stringOf(T) = T.stringof;  /+ TODO: Move to Phobos +/
template stringsOf(T...)		/+ TODO: Move to Phobos +/
{
	import std.meta : staticMap;
	enum stringsOf = staticMap!(stringOf, T);
}

///
pure nothrow @safe @nogc unittest {
	enum strings = stringsOf!(bool, short, int, long);
}

/** Get Dimensionality of Type `T`.
   See_Also: http://forum.dlang.org/thread/hiuhqdxtpifhzwebewjh@forum.dlang.org?page=2
*/

template dimensionality (T)
{
	import std.range.primitives : isInputRange;
	template count_dim (uint i = 0)
	{
		static if (is(typeof(T.init.opSlice!i(0, 0))))
			enum count_dim = count_dim!(i+1);
		else static if (i == 0 &&
						(isInputRange!T ||
						 is(typeof(T.init[0]))))
			enum count_dim = 1;
		else
			enum count_dim = i;
	}
	alias dimensionality = count_dim!();
}

///
pure nothrow @safe @nogc unittest {
	static assert(dimensionality!(int[]) == 1);
}

/// Rank of type `T`.
template rank(T)
{
	import std.range.primitives : isInputRange;
	static if (isInputRange!T) // is T a range?
		enum rank = 1 + rank!(ElementType!T); // if yes, recurse
	else
		enum rank = 0; // base case, stop there
}

///
pure nothrow @safe @nogc unittest {
	import std.range : cycle;

	auto c = cycle([[0,1].s[],
					[2,3].s[]].s[]); // == [[0,1],[2,3],[0,1],[2,3],[0,1]...

	assert(rank!(typeof(c)) == 2); // range of ranges

	static assert(rank!(int[]) == 1);
	static assert(rank!(int[][]) == 2);
}

/// Returns: `true` iff `T` is a template instance, `false` otherwise.
template isTemplateInstance(T)
{
	import std.traits : TemplateOf;
	enum isTemplateInstance = is(typeof(TemplateOf!(T)));
}

///
pure nothrow @safe @nogc unittest {
	struct S(T) { T x; }
	static assert(isTemplateInstance!(S!int));
	static assert(!isTemplateInstance!(int));
}

/** Get identifier (name) string of template instance `I`, or `null` if `I` is
	not a template instance. */
template templateIdentifierOf(I)
{
	import std.traits : TemplateOf;
	static if (isTemplateInstance!I)
		enum templateIdentifierOf = __traits(identifier, TemplateOf!I);
	else
		enum templateIdentifierOf = null;
}
alias templateNameOf = templateIdentifierOf;

///
pure nothrow @safe @nogc unittest {
	struct S(T) { T x; }
	static assert(templateIdentifierOf!(S!int) == "S");
	static assert(templateIdentifierOf!(int) == null);
}

/** Get entropy in number of bits of `T`. */
template EntropyBitsOf(T)
{
	import std.traits : isAggregateType, isArray;
	static if (isAggregateType!T)
	{
		// foreach (memberName; __traits(allMembers, T)) // for each member name in `struct TypedKey`
		// {
		//	 const member = __traits(getMember, T.init, memberName); // member
		// }
		enum EntropyBitsOf = 8*T.sizeof;
	}
	else
		enum EntropyBitsOf = 8*T.sizeof;
}

///
pure nothrow @safe @nogc unittest {
	static assert(EntropyBitsOf!int == 8*int.sizeof);
}

/** Is `true` if `sym` is an l-value, `false` otherwise.
 *
 * See_Also: https://forum.dlang.org/post/mailman.4192.1454351296.22025.digitalmars-d-learn@puremagic.com
 *
 * TODO: Move to Phobos
 */
enum isLvalue(alias sym) = is(typeof((ref _){}(sym)));

///
pure nothrow @safe @nogc unittest {
	int i;
	string s;
	static assert(isLvalue!i);
	static assert(isLvalue!s);
	// static assert(!isLvalue!13);
	// static assert(!isLvalue!"a");
}

template ownsItsElements(C)
{
	import std.traits : hasIndirections;
	import std.range.primitives : ElementType;
	enum ownsItsElements = !__traits(isCopyable, C) && !hasIndirections!(ElementType!C);
}

/** Copied from private definition in Phobos' std.meta.
 */
private template isSame(ab...)
	if (ab.length == 2)
{
	static if (__traits(compiles, expectType!(ab[0]),
								  expectType!(ab[1])))
		enum isSame = is(ab[0] == ab[1]);
	else static if (!__traits(compiles, expectType!(ab[0])) &&
					!__traits(compiles, expectType!(ab[1])) &&
					 __traits(compiles, expectBool!(ab[0] == ab[1])))
	{
		static if (!__traits(compiles, &ab[0]) ||
				   !__traits(compiles, &ab[1]))
			enum isSame = (ab[0] == ab[1]);
		else
			enum isSame = __traits(isSame, ab[0], ab[1]);
	}
	else
		enum isSame = __traits(isSame, ab[0], ab[1]);
}
private template expectType(T) {}
private template expectBool(bool b) {}

template allSatisfyIterative(alias F, T...)
{
	static foreach (Ti; T)
		static if (is(typeof(allSatisfyIterative) == void) && // not yet defined
				   !F!(Ti))
			enum allSatisfyIterative = false;
	static if (is(typeof(allSatisfyIterative) == void)) // if not yet defined
		enum allSatisfyIterative = true;
}

///
@safe unittest {
	import std.traits : isIntegral;

	static assert( allSatisfyIterative!(isIntegral));
	static assert( allSatisfyIterative!(isIntegral, int));
	static assert(!allSatisfyIterative!(isIntegral, int, double));
	static assert( allSatisfyIterative!(isIntegral, int, long));
	static assert(!allSatisfyIterative!(isIntegral, string));
}

template anySatisfyIterative(alias F, T...)
{
	static foreach (Ti; T)
	{
		static if (is(typeof(anySatisfyIterative) == void) && // not yet defined
				   F!(Ti))
		{
			enum anySatisfyIterative = true;
		}
	}
	static if (is(typeof(anySatisfyIterative) == void)) // if not yet defined
	{
		enum anySatisfyIterative = false;
	}
}

///
@safe unittest {
	import std.traits : isIntegral;

	static assert(!anySatisfyIterative!(isIntegral));
	static assert( anySatisfyIterative!(isIntegral, int));
	static assert(!anySatisfyIterative!(isIntegral, string, double));
	static assert( anySatisfyIterative!(isIntegral, int, double));
	static assert( anySatisfyIterative!(isIntegral, int, string));
}

version (unittest)
{
	import std.typecons : Tuple;
	import nxt.array_help : s;
}

/** Is `true` iff `T` has a property member non-function named `name`. */
template hasPropertyFunction(T, string name)
{
	static if (__traits(hasMember, T, name))
		enum hasPropertyFunction = (!is(typeof(__traits(getMember, T, name)) == function) &&
									__traits(getOverloads, T, name).length);
	else
		enum hasPropertyFunction = false;
}

///
unittest {
	struct S
	{
		int m;
		static int sm;

		void f() {}
		static void sf() {}

		@property int rp() { return m; }
		@property void wp(int) {}
	}

	static assert(hasPropertyFunction!(S, "rp"));
	static assert(hasPropertyFunction!(S, "wp"));

	static assert(!hasPropertyFunction!(S, "na"));
	static assert(!hasPropertyFunction!(S, "m"));
	static assert(!hasPropertyFunction!(S, "sm"));
	static assert(!hasPropertyFunction!(S, "f"));
	static assert(!hasPropertyFunction!(S, "sf"));
}

/** Is `true` if `T.name` is a manifest constant, built-in type field, or
 * immutable static.
 */
template isManifestAssignable(T, string name)
{
	enum isManifestAssignable = is(typeof({ enum x = mixin("T." ~ name); }));
}

///
unittest {
	struct A
	{
		int m;
		static immutable int sim = 1;
		enum e = 1;
	}
	static assert(!isManifestAssignable!(A*, "na"));
	static assert(!isManifestAssignable!(A, "na"));
	static assert(!isManifestAssignable!(A, "m"));
	static assert(isManifestAssignable!(A, "e"));
	static assert(isManifestAssignable!(A, "sim"));
}

/** Tells you if a name is a read and/or write property
 *
 * Returns: `Tuple!(bool, "isRead", bool, "isWrite")`
 */
auto propertySemantics(T, string name)()
	if (hasPropertyFunction!(T, name))
{
	import std.typecons : tuple;

	enum overloads = __traits(getOverloads, T, name).length;
	enum canInstantiateAsField = is(typeof(mixin("T.init." ~ name)));

	static if (overloads > 1 || canInstantiateAsField)
		enum canRead = true;
	else
		enum canRead = false;
	static if (overloads > 1 || !canInstantiateAsField)
		enum canWrite = true;
	else
		enum canWrite = false;

	return tuple!("canRead", "canWrite")(canRead, canWrite);
}

///
unittest {
	import std.typecons;

	struct S
	{
		int m;
		@property int rp()
		{
			return m;
		}

		@property void wp(int)
		{
		}

		@property int rwp()
		{
			return m;
		}

		@property void rwp(int)
		{
		}
	}

	static assert(!__traits(compiles, propertySemantics!(S, "na")));
	static assert(!__traits(compiles, propertySemantics!(S, "m")));

	static assert(propertySemantics!(S, "rp") == tuple!("canRead", "canWrite")(true, false));
	static assert(propertySemantics!(S, "wp") == tuple!("canRead", "canWrite")(false, true));
	static assert(propertySemantics!(S, "rwp") == tuple!("canRead", "canWrite")(true, true));
}

/** Is `true` iff the postblit of `T` is disabled (`this(this) @disable`).
 *
 * See_Also: https://forum.dlang.org/post/dkohvpbmakbdbhnmnmbg@forum.dlang.org
 */
template hasDisabledPostblit(T)
{
	static if (__traits(hasMember, T, "__postblit"))
		enum hasDisabledPostblit = __traits(isDisabled, T.__postblit);
	else
		enum hasDisabledPostblit = false;
}

///
pure @safe unittest {
	static struct S
	{
		this(this) @disable;
	}
	static assert(!hasDisabledPostblit!int);
	static assert( hasDisabledPostblit!S);
}

template isSubclassOf(Class, BaseClass)
{
	import std.traits : BaseClassesTuple;
	alias BaseClasses = BaseClassesTuple!Class;
	import std.meta : staticIndexOf;
	enum isSubclassOf = staticIndexOf!(BaseClass, BaseClasses) != -1;
}

///
pure @safe unittest {
	class X {}
	class Y : X {}

	static assert(!isSubclassOf!(X, Y));
	static assert( isSubclassOf!(X, Object));

	static assert( isSubclassOf!(Y, X));
	static assert( isSubclassOf!(Y, Object));
}

/** Is `true` iff F are all.
 *
 * See_Also: https://forum.dlang.org/post/p9orut$2h4$1@digitalmars.com
 */
bool isStronglyPure(alias F)()
{
	import std.traits : Parameters, ParameterDefaults;
	import std.algorithm : canFind;
	static if (!__traits(getFunctionAttributes, F).canFind("pure")) /+ TODO: use staticIndexOf +/
		return false;
	enum length = ParameterDefaults!F.length;
	alias P = Parameters!F;
	static foreach (i; 0 .. length)
	{
		immutable c = __traits(getParameterStorageClasses, F, i);
		/* Why does this print:
		   const(int) int true (d-dmd-all)
		   const(int) int true (d-dmd-all)
		   const(int) int true (d-dmd-all)
		   ?
		 */
		// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", const(P[i]).stringof, " ", P[i].stringof, " ", is(P[i] == const(P[i])));
		// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", is(int == const(int)));
		if (c.canFind("ref", "out") && /+ TODO: use staticIndexOf +/
			is(const(P[i]) == P[i]))
			return false;
	}
	return true;
}

unittest {
	static int f(int x) pure { return x + 1; }
	static int g(ref int x) pure { return x + 1; }
	static int gc(const ref int x) pure { return x + 1; }
	static int gi(immutable ref int x) pure { return x + 1; }
	static void h(out int x) pure { x = 0; }
	static assert(isStronglyPure!f);
	static assert(!isStronglyPure!g);
	static assert(!isStronglyPure!h);
	/+ TODO: static assert(isStronglyPure!gc); +/
	/+ TODO: static assert(isStronglyPure!gi); +/
}

/** Is `true` iff `F` returns a value whose mutable indirections are unique.
 *
 * TODO: Check if the uniqueness property only applies to the first indirection layer.
 * TODO: Move to Phobos std.traits.
 *
 * See_Also: https://dlang.org/changelog/2.101.0.html#dmd.fix-immutable-conv
 */
enum returnsUnique(alias F) = __traits(compiles, {
		import std.traits : Parameters;

		alias P = Parameters!(F);
		P args = P.init;

		static if (__traits(isPOD, P)) {
			auto m = F(args);
			immutable i = F(args);
		} else {
			import core.lifetime : move;
			auto m = F(move(args));
			immutable i = F(move(args));
		}

		/*
		  Doesn’t suffice to pass `P.init` here because dmd knows that passing
		  `null` to `x` in

		  static int* f(scope return int *x) pure nothrow @safe @nogc { return x; }

		  is strongly pure.
		*/
		static assert(!is(typeof(m) == typeof(i)));
	});

alias hasUniqueReturn = returnsUnique;

///
pure nothrow @safe @nogc unittest {
	import core.memory : pureMalloc;

	static int identity(int x)  @safe nothrow @nogc { return x; }
	static int identityP(int x) pure nothrow @safe @nogc { return x; }
	static assert( returnsUnique!identity);
	static assert( returnsUnique!identityP);

	static auto makeBytes(size_t n)  @safe nothrow @nogc { return pureMalloc(n); }
	static auto makeBytesP(size_t n) pure nothrow @safe @nogc { return pureMalloc(n); }
	static assert( returnsUnique!makeBytes);
	static assert( returnsUnique!makeBytesP);

	static int* f(scope return int *x) pure nothrow @safe @nogc { return x; }
	static assert(!returnsUnique!f);

	struct Sint { int x; }
	static Sint fS(scope return Sint x) pure nothrow @safe @nogc { return x; }
	static assert( returnsUnique!fS);

	struct Sintp { int* x; }
	static Sintp fSintp(scope return Sintp x) pure nothrow @safe @nogc { return x; }
	static assert(!returnsUnique!fSintp);

	struct S3 { immutable int* x; }
	static S3 fS3(scope return S3 x) pure nothrow @safe @nogc { return x; }
	static assert( returnsUnique!fS3);
}
