module nxt.notnull;

/** Note that `NotNull!T` is not `isNullAssignable`. */
template isNullAssignable(T)
{
    import std.traits : isAssignable;
    enum isNullAssignable = isAssignable!(T, typeof(null));
}

///
@safe pure nothrow @nogc unittest
{
    static assert( isNullAssignable!(int*));
    static assert(!isNullAssignable!(int));
}

/**
   NotNull ensures a null value can never be stored.

   * You must initialize it when declared

   * You must never assign the null literal to it (this is a compile time error)

   * If you assign a null value at runtime to it, it will immediately throw an Error
   at the point of assignment.

   NotNull!T can be substituted for T at any time, but T cannot become
   NotNull without some attention: either declaring NotNull!T, or using
   the convenience function, notNull.

   Condition: T must be a reference type.
   Instead of: __traits(compiles, { T t; assert(t is null); } ).

   TODO: Merge with http://arsdnet.net/dcode/notnullsimplified.d

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
if (isNullAssignable!T)
{
    import std.traits: isAssignable;

    @disable this(); // Disallow default initialized (to null)

    /** Assignment from $(D NotNull) Inherited Class $(D rhs) to $(D NotNull) Base
        Class $(D this). */
    typeof(this) opAssign(U)(NotNull!U rhs) @safe pure nothrow
    if (isAssignable!(T, U))
    {
        this._value = rhs._value;
        return this;
    }

    version(none)            // TODO: activate with correct template restriction
    NotNull!U opCast(U)() @safe pure nothrow
    if (isAssignable!(U, T))
    {
        return NotNull!_value;
    }

    // this could arguably break the static type check because
    // you can assign it from a variable that is null.. but I
    // think it is important that NotNull!Object = new Object();
    // works, without having to say assumeNotNull(new Object())
    // for convenience of using with local variables.

    /// Constructs with a runtime not null check (via assert()).
    this(T value) @safe pure nothrow
    {
        assert(value !is null);
        _value = value;
    }

    /** Disable null construction. */
    @disable this(typeof(null));

    /** Disable null assignment. */
    @disable typeof(this) opAssign(typeof(null));

    /* See_Also: http://forum.dlang.org/thread/aprsozwvnpnchbaswjxd@forum.dlang.org#post-aprsozwvnpnchbaswjxd:40forum.dlang.org */
    version(none)        // NOTE: Disabled because it makes members inaccessible
    {
        import std.traits: BaseClassesTuple;
        static if (is(T == class) && !is(T == Object))
        {
            @property NotNull!(BaseClassesTuple!T[0]) _valueHelper() inout @trusted pure nothrow
            {
                assert(_value !is null); // sanity check of invariant
                return assumeNotNull(cast(BaseClassesTuple!T[0]) _value);
            }
        }
        else
        {
            @property inout(T) _valueHelper() inout @safe pure nothrow
            {
                assert(_value !is null); // sanity check of invariant
                return _value;
            }
        }
    }

    @property inout(T) value() inout
    {
        assert(_value !is null);
        return _value;
    }
    alias value this; /// this is substitutable for the regular (nullable) type

    private T _value;

    // Apparently a compiler bug - the invariant being uncommented breaks all kinds of stuff.
    // invariant() { assert(_value !is null); }

    /* void toMsgpack  (Packer)  (ref Packer packer) const { packer.pack(_value); } */
    /* void fromMsgpack(Unpacker)(auto ref Unpacker unpacker) { unpacker.unpack(_value); } */
}

/** A convenience function to construct a NotNull value from something $(D t)
    you know isn't null.
*/
NotNull!T assumeNotNull(T)(T t)
if (isNullAssignable!T)
{
    return NotNull!T(t); // note the constructor asserts it is not null
}

/** A convenience function to check for null $(D t).

    If you pass null to $(D t), it will throw an exception. Otherwise, return
    NotNull!T.
*/
NotNull!T enforceNotNull(T, string file = __FILE__, size_t line = __LINE__)(T t)
if (isNullAssignable!T)
{
    import std.exception: enforce;
    enforce(t !is null, "t is null!", file, line);
    return NotNull!T(t);
}

unittest
{
    import core.exception;
    import std.exception;

    void NotNullCompilationTest1()() // I'm making these templates to defer compiling them
    {
        NotNull!(int*) defaultInitiliation; // should fail because this would be null otherwise
    }
    assert(!__traits(compiles, NotNullCompilationTest1!()()));

    void NotNullCompiliationTest2()()
    {
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

unittest
{
    class A {}
    class B : A {}
    NotNull!B b = (new B).assumeNotNull;
    NotNull!A a = (new A).assumeNotNull;
    assert(a && b);
    a = b;
    assert(a is b);
}

unittest
{
    class A {}
    class B : A {}
    auto b = assumeNotNull(new B);
    auto a = assumeNotNull(new A);
    a = b;
    assert(a is b);
}

/** See_Also: http://forum.dlang.org/thread/mxpfzghydhirdtltmmvo@forum.dlang.org?page=3#post-ngtuwqiqumommfrlngjy:40forum.dlang.org */
unittest
{
    class A {}
    class B : A {}
    void f(NotNull!A a) {}
    NotNull!B b = assumeNotNull(new B);
    static assert(!__traits(compiles, { f(b); })); // TODO: I don't want this to fail.
}

/** by Andrej Mitrovic
    See_Also: http://forum.dlang.org/thread/llezieyytpcbcaoqeajz@forum.dlang.org?page=6
*/
struct CheckNull(T)
{
   private T _payload;
   auto opCast(X : bool)() { return _payload !is null; }
   @property NotNull!T getNotNull() { return NotNull!T(_payload); }
   alias getNotNull this;
}

CheckNull!T checkNull(T)(T obj)
{
   return CheckNull!T(obj);
}
