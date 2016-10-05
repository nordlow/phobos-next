module bithashset;

enum Growable { no, yes }

enum isBitHashable(T) = is(typeof(cast(size_t)T.init)); // TODO use `isIntegral` instead?

unittest
{
    static assert(isBitHashable!size_t);
    static assert(!isBitHashable!string);
}

version = show;
version(show)
import dbgio : dln;

/** Store presence of elements of type `E` in a set in the range `0 .. length`. */
struct BitHashSet(E, Growable growable = Growable.no)
    if (isBitHashable!E)
{
    import qmem : malloc, calloc, realloc, free;
    import core.bitop : bts, btr, btc, bt;

    @safe pure nothrow @nogc pragma(inline):

    /// Construct set to store at most `length` number of bits.
    this(size_t length) @trusted
    {
        _length = length;
        _blocksPtr = null;
        static if (growable == Growable.yes)
        {
            _capacity = 0;
            assureCapacity(length);
        }
        else
        {
            _blocksPtr = cast(Block*)calloc(blockCount, Block.sizeof);
        }
    }

    ~this() @trusted
    {
        free(_blocksPtr);
    }

    @disable this(this);        // no copy ctor for now

    /// Returns: shallow (and deep) duplicate of `this`.
    typeof(this) dup() @trusted
    {
        typeof(this) copy;
        copy._length = _length;
        copy._blocksPtr = cast(Block*)malloc(blockCount * Block.sizeof);
        copy._blocksPtr[0 .. blockCount] = this._blocksPtr[0 .. blockCount];
        return copy;
    }

    @property:

    static if (growable == Growable.yes)
    {
        /// Expand to capacity to make room for at least `newLength`.
        private void assureCapacity(size_t newLength) @trusted
        {
            if (_capacity < newLength)
            {
                const oldBlockCount = blockCount;
                import std.math : nextPow2;
                this._capacity = newLength.nextPow2;
                // dln("Expanded to new ", this._length);
                _blocksPtr = cast(Block*)realloc(_blocksPtr, blockCount * Block.sizeof);
                _blocksPtr[oldBlockCount .. blockCount] = 0;
            }
        }
    }

    /** Insert element `e`.
        Returns: precense status of element before insertion.
    */
    bool insert(E e) @trusted
    {
        const ix = cast(size_t)e;
        static if (growable == Growable.yes) { assureCapacity(ix + 1); _length = ix + 1; } else { assert(ix < _length); }
        return bts(_blocksPtr, ix) != 0;
    }

    /** Remove element `e`.
        Returns: precense status of element before removal.
     */
    bool remove(E e) @trusted
    {
        const ix = cast(size_t)e;
        static if (growable == Growable.yes) { assureCapacity(ix + 1); _length = ix + 1; } else { assert(ix < _length); }
        return btr(_blocksPtr, ix) != 0;
    }

    /** Insert element `e` if it's present otherwise remove it.
        Returns: `true` if elements was zeroed, `false` otherwise.
     */
    bool complement(E e) @trusted
    {
        const ix = cast(size_t)e;
        static if (growable == Growable.yes) { assureCapacity(ix + 1); _length = ix + 1; } else { assert(ix < _length); }
        return btc(_blocksPtr, ix) != 0;
    }

    /// Check if element `e` is stored/contained.
    bool contains(E e) @trusted const
    {
        const ix = cast(size_t)e;
        return ix < _length && bt(_blocksPtr, ix) != 0;
    }

    /// ditto
    auto opBinaryRight(string op)(E e) const
        if (op == "in")
    {
        return contains(e);
    }

    /// Get length.
    @property size_t length() const { return _length; }
private:
    static if (growable == Growable.yes)
    {
        @property size_t capacity() const { return _capacity; }
    }

    @property size_t blockCount() const
    {
        static if (growable == Growable.yes)
        {
            return _capacity / Block.sizeof + (_capacity % Block.sizeof ? 1 : 0);
        }
        else
        {
            return _length / Block.sizeof + (_length % Block.sizeof ? 1 : 0);
        }
    }

    alias Block = size_t;       /// Allocated block type.
    Block* _blocksPtr;          /// Pointer to blocks of bits.
    size_t _length;             /// Number of bits stored.
    static if (growable == Growable.yes)
    {
        size_t _capacity;           /// Number of bits allocated.
    }
}

///
@safe pure nothrow @nogc unittest
{
    alias E = uint;

    const set0 = BitHashSet!(E, Growable.no)();
    assert(set0.length == 0);

    const length = 2^^6;
    auto set = BitHashSet!E(2*length);
    const y = set.dup;
    assert(y.length == 2*length);

    foreach (ix; 0 .. length)
    {
        assert(!set.contains(ix));
        assert(ix !in set);

        assert(!set.insert(ix));
        assert(set.contains(ix));
        assert(ix in set);

        assert(set.complement(ix));
        assert(!set.contains(ix));
        assert(ix !in set);

        assert(!set.complement(ix));
        assert(set.contains(ix));
        assert(ix in set);

        assert(!set.contains(ix + 1));
    }

    auto z = set.dup;
    foreach (ix; 0 .. length)
    {
        assert(z.contains(ix));
        assert(ix in z);
    }

    foreach (ix; 0 .. length)
    {
        assert(set.contains(ix));
        assert(ix in set);
    }

    foreach (ix; 0 .. length)
    {
        assert(set.contains(ix));
        set.remove(ix);
        assert(!set.contains(ix));
    }
}

///
@safe pure nothrow @nogc unittest
{
    alias E = uint;

    auto set = BitHashSet!(E, Growable.yes)();
    assert(set.length == 0);

    const length = 2^^16;
    foreach (ix; 0 .. length)
    {
        assert(!set.contains(ix));
        assert(ix !in set);

        assert(!set.insert(ix));
        assert(set.contains(ix));
        assert(ix in set);

        assert(set.complement(ix));
        assert(!set.contains(ix));
        assert(ix !in set);

        assert(!set.complement(ix));
        assert(set.contains(ix));
        assert(ix in set);

        assert(!set.contains(ix + 1));
    }
}

/// test `RefCounted` storage
nothrow @nogc unittest          // TODO @safe pure when https://github.com/dlang/phobos/pull/4692/files has been merged
{
    import std.typecons : RefCounted;
    alias E = int;

    RefCounted!(BitHashSet!(E, Growable.yes)) set;

    assert(set.length == 0);
    assert(set.capacity == 0);

    assert(!set.insert(0));
    assert(set.length == 1);
    assert(set.capacity == 2);

    const y = set;

    foreach (const e; 1 .. 1000)
    {
        assert(!set.insert(e));
        assert(set.length == e + 1);
        assert(y.length == e + 1);
    }

    const set1 = RefCounted!(BitHashSet!(E, Growable.yes))(42);
    assert(set1.length == 42);
    assert(set1.capacity == 64);
}
