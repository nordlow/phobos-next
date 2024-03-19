module nxt.notnull;

/** An of a reference type `T` never being `null`.

   * Must be initialized when declared.

   * Can never be assigned the null literal (compile time error).

   * If assigned a `null` value at runtime an exception will be thrown.

   `NotNull!T` can be substituted for `T` at any time, but `T` cannot become
   `NotNull` without some attention: either declaring `NotNull!T`, or using the
   convenience function, `enforceNotNull!T`.

   Condition: `T` must be a reference type.

   Examples:
   ---
   int myInt;
   NotNull!(int *) not_null = &myInt;
   // you can now use variable not_null anywhere you would
   // have used a regular int*, but with the assurance that
   // it never stored null.
   ---
*/
struct NotNull(T)
if (is(T == class) ||
	is(T == interface) ||
	is(T == U*, U) && __traits(isScalar, T)) {
	import std.traits: isAssignable;

	@disable this(); // disallow default initialized (to null)

	/** Assignment from $(D NotNull) inherited class $(D rhs) to $(D NotNull) base
		class $(D this). */
	typeof(this) opAssign(U)(NotNull!U rhs) pure nothrow @safe @nogc if (isAssignable!(T, U)) {
		this._value = rhs._value;
		return this;
	}

	bool opCast(T : bool)() => _value !is null;

	/// Constructs with a runtime not null check (via assert()).
	this(T value) pure nothrow {
		assert(value !is null);
		_value = value;
	}

	/** Disable null construction. */
	@disable this(typeof(null));

	/** Disable null assignment. */
	@disable typeof(this) opAssign(typeof(null));

	@property inout(T) get() inout pure nothrow @safe @nogc {
		assert(_value !is null);
		return _value;
	}
	alias get this; /// this is substitutable for the regular (nullable) type

	private T _value;

	version (none):		   /+ TODO: activate with correct template restriction +/
		NotNull!U opCast(U)() pure nothrow if (isAssignable!(U, T)) => NotNull!_value;

	version (none) {		// NOTE: Disabled because it makes members inaccessible
		/* See_Also:
		 * http://forum.dlang.org/thread/aprsozwvnpnchbaswjxd@forum.dlang.org#post-aprsozwvnpnchbaswjxd:40forum.dlang.org
		 */
		import std.traits: BaseClassesTuple;
		static if (is(T == class) && !is(T == Object)) {
			@property NotNull!(BaseClassesTuple!T[0]) _valueHelper() inout @trusted pure nothrow {
				assert(_value !is null); // sanity check of invariant
				return assumeNotNull(cast(BaseClassesTuple!T[0]) _value);
			}
		} else {
			@property inout(T) _valueHelper() inout pure nothrow {
				assert(_value !is null); // sanity check of invariant
				return _value;
			}
		}
	}

	// Apparently a compiler bug - the invariant being uncommented breaks all kinds of stuff.
	// invariant() { assert(_value !is null); }
}

/** A convenience function to construct a NotNull value from something $(D t)
	you know isn't null.
*/
NotNull!T assumeNotNull(T)(T t)
if (is(T == class) ||
	is(T == interface) ||
	is(T == U*, U) && __traits(isScalar, T))
	=> NotNull!T(t); // note the constructor asserts it is not null

/** A convenience function to check for null $(D t).

	If you pass null to $(D t), it will throw an exception. Otherwise, return
	NotNull!T.
*/
NotNull!T enforceNotNull(T, string file = __FILE__, size_t line = __LINE__)(T t)
if (is(T == class) ||
	is(T == interface) ||
	is(T == U*, U) && __traits(isScalar, T)) {
	import std.exception: enforce;
	enforce(t !is null, "t is null!", file, line);
	return NotNull!T(t);
}

///
unittest {
	import core.exception;
	import std.exception;

	void NotNullCompilationTest1()() // I'm making these templates to defer compiling them
	{
		NotNull!(int*) defaultInitiliation; // should fail because this would be null otherwise
	}
	assert(!__traits(compiles, NotNullCompilationTest1!()()));

	void NotNullCompiliationTest2()() {
		NotNull!(int*) defaultInitiliation = null; // should fail here too at compile time
	}
	assert(!__traits(compiles, NotNullCompiliationTest2!()()));

	int dummy;
	NotNull!(int*) foo = &dummy;

	assert(!__traits(compiles, foo = null)); // again, literal null is caught at compile time

	int* test;

	test = &dummy;

	foo = test.assumeNotNull; // should be fine

	void bar(int* a) {}

	// these should both compile, since NotNull!T is a subtype of T
	bar(test);
	bar(foo);

	void takesNotNull(NotNull!(int*) a) { }

	assert(!__traits(compiles, takesNotNull(test))); // should not work; plain int might be null
	takesNotNull(foo); // should be fine

	takesNotNull(test.assumeNotNull); // this should work too
	assert(!__traits(compiles, takesNotNull(null.assumeNotNull))); // notNull(null) shouldn't compile
	test = null; // reset our pointer

	assertThrown!AssertError(takesNotNull(test.assumeNotNull)); // test is null now, so this should throw an assert failure

	void takesConstNotNull(in NotNull!(int *) a) {}

	test = &dummy; // make it valid again
	takesConstNotNull(test.assumeNotNull); // should Just Work

	NotNull!(int*) foo2 = foo; // we should be able to assign NotNull to other NotNulls too
	foo2 = foo; // including init and assignment

}

///
unittest {
	class A {}
	class B : A {}
	NotNull!B b = (new B).assumeNotNull;
	NotNull!A a = (new A).assumeNotNull;
	assert(a && b);
	a = b;
	assert(a is b);
}

///
unittest {
	class A {}
	class B : A {}
	auto b = assumeNotNull(new B);
	auto a = assumeNotNull(new A);
	a = b;
	assert(a is b);
}

/** See_Also: http://forum.dlang.org/thread/mxpfzghydhirdtltmmvo@forum.dlang.org?page=3#post-ngtuwqiqumommfrlngjy:40forum.dlang.org */
///
unittest {
	class A {}
	class B : A {}
	void f(NotNull!A a) {}
	NotNull!B b = assumeNotNull(new B);
	static assert(!__traits(compiles, { f(b); })); /+ TODO: I don't want this to fail. +/
}
