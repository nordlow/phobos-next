/** Structure of arrays (SoA).
 *
 * SoAs are common in game engines.
 *
 * Initially a builtin feature in the Jai programming language that later was
 * made into a library solution.
 *
 * TODO merge with soa_petar_kirov.d by
 * 1. allocate all arrays in a single chunk
 * 2. calculating `_capacity` based on `_length` and
 *
 * See_Also: http://forum.dlang.org/post/wvulryummkqtskiwrusb@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/purhollnapramxczmcka@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/cvxuagislrpfomalcelc@forum.dlang.org
 * See_Also: https://maikklein.github.io/post/soa-d/
 */
module nxt.soa;

/** Structure of arrays similar to members of `S`.
 */
struct SoA(S)
if (is(S == struct))        // TODO: extend to `isAggregate!S`?
{
    import nxt.pure_mallocator : PureMallocator;

    private alias toType(string s) = typeof(__traits(getMember, S, s));
    private alias Types = typeof(S.tupleof);

    this(in size_t initialCapacity)
    {
        _capacity = initialCapacity;
        allocate(initialCapacity);
    }

    auto opDispatch(string name)()
    {
        static foreach (const index, memberSymbol; S.tupleof)
            static if (name == memberSymbol.stringof)
                return getArray!index;
        // TODO: static assert(0, S.stringof ~ " has no field named " ~ name);
    }

    /** Push element (struct) `value` to back of array. */
    void insertBack()(S value) @trusted // template-lazy
    {
        import core.lifetime : moveEmplace;
        reserveOneExtra();
        static foreach (const index, memberSymbol; S.tupleof)
            moveEmplace(__traits(getMember, value, memberSymbol.stringof),
                        getArray!index[_length]); // TODO: assert that
        ++_length;
    }

    /** Push element (struct) `value` to back of array using its data members `members`. */
    void insertBackMembers()(Types members) @trusted // template-lazy
    {
        import core.lifetime : moveEmplace;
        reserveOneExtra();
        // move each member to its position respective array
        static foreach (const index, _; members)
            moveEmplace(members[index], getArray!index[_length]); // same as `getArray!index[_length] = members[index];`
        ++_length;
    }

    void opOpAssign(string op, S)(S value)
    if (op == "~")
    {
        pragma(inline, true);
        insertBack(value);
    }

    /** Length of this array. */
    @property size_t length() const @safe pure nothrow @nogc
    {
        return _length;
    }

    /** Capacity of this array. */
    @property size_t capacity() const @safe pure nothrow @nogc
    {
        return _capacity;
    }

    /** Returns true iff no elements are present. */
    bool empty() const pure @safe { return _length == 0; }

    ~this() @trusted @nogc
    {
        import std.experimental.allocator : dispose;
        static foreach (const index, _; S.tupleof)
            PureMallocator.instance.dispose(getArray!index);
    }

    /** Index operator. */
    inout(SoAElementRef!S) opIndex()(in size_t elementIndex) inout return // template-lazy
    {
        assert(elementIndex < _length);
        return typeof(return)(&this, elementIndex);
    }

    /** Slice operator. */
    inout(SoASlice!S) opSlice()() inout return // template-lazy
    {
        return typeof(return)(&this);
    }

private:

    // generate array definitions
    static foreach (const index, Type; Types)
        mixin(Type.stringof ~ `[] _container` ~ index.stringof ~ ";");

    /** Get array of all fields at aggregate field index `index`. */
    ref inout(Types[index][]) getArray(size_t index)() inout return
    {
        mixin(`return _container` ~ index.stringof ~ ";");
    }

    size_t _length = 0;         ///< Current length.
    size_t _capacity = 0;       ///< Current capacity.

    /** Growth factor P/Q.
        https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
        Use 1.5 like Facebook's `fbvector` does.
    */
    enum _growthP = 3;
    /// ditto
    enum _growthQ = 2;

    void allocate(in size_t newCapacity) @trusted
    {
        import std.experimental.allocator : makeArray;
        static foreach (const index, _; S.tupleof)
            getArray!index = PureMallocator.instance.makeArray!(Types[index])(newCapacity);
    }

    /** Grow storage.
     */
    void grow() @trusted
    {
        // Motivation: https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
        import std.algorithm.comparison : max;
        import std.experimental.allocator : expandArray;
        const newCapacity = max(1, _growthP * _capacity / _growthQ);
        const expandSize = newCapacity - _capacity;
        if (_capacity is 0)
            allocate(newCapacity);
        else
            static foreach (const index, _; S.tupleof)
                PureMallocator.instance.expandArray(getArray!index, expandSize);
        _capacity = newCapacity;
    }

    void reserveOneExtra()
    {
        if (_length == _capacity)
            grow();
    }
}
alias StructArrays = SoA;

/** Reference to element in `soaPtr` at index `elementIndex`. */
private struct SoAElementRef(S)
if (is(S == struct))        // TODO: extend to `isAggregate!S`?
{
    SoA!S* soaPtr;
    size_t elementIndex;

    @disable this(this);

    /** Access member name `memberName`. */
    auto ref opDispatch(string memberName)()
        @trusted return scope
    {
        mixin(`return ` ~ `(*soaPtr).` ~ memberName ~ `[elementIndex];`);
    }
}

/** Reference to slice in `soaPtr`. */
private struct SoASlice(S)
if (is(S == struct))            // TODO: extend to `isAggregate!S`?
{
    SoA!S* soaPtr;

    @disable this(this);

    /** Access aggregate at `index`. */
    inout(S) opIndex(in size_t index) inout @trusted return scope
    {
        S s = void;
        static foreach (const memberIndex, memberSymbol; S.tupleof)
            mixin(`s.` ~ memberSymbol.stringof ~ `= (*soaPtr).getArray!` ~ memberIndex.stringof ~ `[index];`);
        return s;
    }
}

@safe:

@safe pure nothrow @nogc unittest
{
    import nxt.dip_traits : isDIP1000;

    struct S { int i; float f; }

    auto x = SoA!S();

    static assert(is(typeof(x.getArray!0()) == int[]));
    static assert(is(typeof(x.getArray!1()) == float[]));

    assert(x.length == 0);

    x.insertBack(S.init);
    assert(x.length == 1);

    x ~= S.init;
    assert(x.length == 2);

    x.insertBackMembers(42, 43f);
    assert(x.length == 3);
    assert(x.i[2] == 42);
    assert(x.f[2] == 43f);

    // uses opDispatch
    assert(x[2].i == 42);
    assert(x[2].f == 43f);

    const x3 = SoA!S(3);
    assert(x3.length == 0);
    assert(x3.capacity == 3);

    // TODO: make foreach work
    // foreach (_; x[])
    // {
    // }

    static if (isDIP1000)
    {
        static assert(!__traits(compiles,
                                {
                                    ref int testScope() @safe
                                    {
                                        auto y = SoA!S(1);
                                        y ~= S(42, 43f);
                                        return y[0].i;
                                    }
                                }));
    }
}
