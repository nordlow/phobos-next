module storage;

/// Large array storage.
static struct Large(E, bool useGC)
{
    import qmem;

    E* ptr;
    size_t length;

    static if (useGC)
    {
        import core.memory : GC;
    }
    else
    {
        alias _malloc = malloc;
        alias _realloc = realloc;
        alias _free = free;
    }

    pure nothrow:

    static if (useGC)
    {
        this(size_t n)
        {
            length = n;
            ptr = cast(E*)GC.malloc(E.sizeof * length);
        }
        void resize(size_t n)
        {
            length = n;
            ptr = cast(E*)GC.realloc(ptr, E.sizeof * length);
        }
        void clear()
        {
            GC.free(ptr);
            debug ptr = null;
        }
    }
    else
    {
        @nogc:
        this(size_t n)
        {
            length = n;
            ptr = cast(E*)_malloc(E.sizeof * length);
        }
        void resize(size_t n)
        {
            length = n;
            ptr = cast(E*)_realloc(ptr, E.sizeof * length);
        }
        void clear()
        {
            _free(ptr);
            debug ptr = null;
        }
    }
}

/// Small array storage.
alias Small(E, size_t n) = E[n];

/// Small-size-optimized (SSO) array store.
static struct Store(E, bool useGC = shouldAddGCRange!E)
{
    /** Fixed number elements that fit into small variant storage. */
    enum smallLength = Large!(E, useGC).sizeof / E.sizeof;

    /** Maximum number elements that fit into large variant storage. */
    enum maxLargeLength = size_t.max >> 8;

    /// Destruct.
    ~this() nothrow @trusted
    {
        if (isLarge) { large.clear; }
    }

    /// Get currently length at `ptr`.
    size_t length() const @trusted pure nothrow @nogc
    {
        return isLarge ? large.length : smallLength;
    }

    /// Returns: `true` iff is small packed.
    bool isSmall() const @safe pure nothrow @nogc { return !isLarge; }

private:

    /// Reserve length to `n` elements starting at `ptr`.
    void reserve(size_t n) pure nothrow @trusted
    {
        if (isLarge)        // currently large
        {
            if (n > smallLength) // large => large
            {
                large.resize(n);
            }
            else                // large => small
            {
                // large => tmp

                // temporary storage for small
                debug { typeof(small) tmp; }
                else  { typeof(small) tmp = void; }

                tmp[0 .. n] = large.ptr[0 .. n]; // large to temporary
                tmp[n .. $] = 0; // zero remaining

                // empty large
                large.clear();

                // tmp => small
                small[] = tmp[0 .. smallLength];

                isLarge = false;
            }
        }
        else                    // currently small
        {
            if (n > smallLength) // small => large
            {
                typeof(small) tmp = small; // temporary storage for small

                import std.conv : emplace;
                emplace(&large, n);

                large.ptr[0 .. length] = tmp[0 .. length]; // temporary to large

                isLarge = true;                      // tag as large
            }
            else {}                // small => small
        }
    }

    /// Get pointer.
    auto ptr() pure nothrow @nogc
    {
        import container_traits : ContainerElementType;
        alias ET = ContainerElementType!(typeof(this), E);
        return isLarge ? cast(ET*)large.ptr : cast(ET*)&small;
    }

    /// Get slice.
    auto ref slice() pure nothrow @nogc
    {
        return ptr[0 .. length];
    }

    union
    {
        Small!(E, smallLength) small; // small variant
        Large!(E, useGC) large;          // large variant
    }
    bool isLarge;               // TODO make part of union as in rcstring.d
}

/// Test `Store`.
static void storeTester(E, bool useGC)()
{
    Store!(E, useGC) si;

    assert(si.ptr !is null);
    assert(si.slice.ptr !is null);
    assert(si.slice.length != 0);
    assert(si.length == si.smallLength);

    si.reserve(si.smallLength);     // max small
    assert(si.length == si.smallLength);
    assert(si.isSmall);

    si.reserve(si.smallLength + 1); // small to large
    assert(si.length == si.smallLength + 1);
    assert(si.isLarge);

    si.reserve(si.smallLength * 8); // small to large
    assert(si.length == si.smallLength * 8);
    assert(si.isLarge);

    si.reserve(si.smallLength);     // max small
    assert(si.length == si.smallLength);
    assert(si.isSmall);

    si.reserve(0);
    assert(si.length == si.smallLength);
    assert(si.isSmall);

    si.reserve(si.smallLength + 1);
    assert(si.length == si.smallLength + 1);
    assert(si.isLarge);

    si.reserve(si.smallLength);
    assert(si.length == si.smallLength);
    assert(si.isSmall);

    si.reserve(si.smallLength - 1);
    assert(si.length == si.smallLength);
    assert(si.isSmall);
}

version(unittest)
{
    import std.meta : AliasSeq;
}

pure nothrow @nogc unittest
{
    foreach (E; AliasSeq!(char, byte, short, int))
    {
        storeTester!(E, false);
    }
}

pure nothrow unittest
{
    foreach (E; AliasSeq!(char, byte, short, int))
    {
        storeTester!(E, true);
    }
}
