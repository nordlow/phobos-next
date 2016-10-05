/** Array container(s) with optional sortedness via template-parameter
    `Ordering` and optional use of GC via `useGC`.

    TODO Add alias for {Unique,Movable,Copyable}{,Sorted,Set}Array

    TODO Make Array have reference assignment instead through via Automatic
    Reference Counting and scope keyword when DIP-1000 has been implemented

    TODO Use std.array.insertInPlace in insert()?
    TODO Use std.array.replaceInPlace?

    TODO Split up `Array` into `Array`, `SortedArray`, `SetArray` and reuse
    logic in `Array` via `alias this` or free functions.

    TODO Use `std.algorithm.mutation.move` and `std.range.primitives.moveAt`
    when moving internal sub-slices

    TODO struct Store, Notify andralex of packed array

    TODO Add `c.insertAfter(r, x)` where `c` is a collection, `r` is a range
    previously extracted from `c`, and `x` is a value convertible to
    collection's element type. See also:
    https://forum.dlang.org/post/n3qq6e$2bis$1@digitalmars.com
 */
module array_ex;

enum Ordering
{
    unsorted, // unsorted array
    sortedValues, // sorted array with possibly duplicate values
    sortedUniqueSet, // sorted array with unique values
}

enum IsOrdered(Ordering ordering) = ordering != Ordering.unsorted;

version(unittest)
{
    import std.algorithm.comparison : equal;
    import std.meta : AliasSeq;
}

import std.math : nextPow2;
import container_traits : ContainerElementType;

/** Is `true` iff `T` is a type whose instances need to be scanned by the garbage
    collector (GC). */
template shouldAddGCRange(T)
{
    import std.traits : isPointer, hasIndirections;
    enum shouldAddGCRange = isPointer!T || hasIndirections!T || is (T == class);
}

/// Returns: `true` iff C is an `Array`.
import std.traits : isInstanceOf;
enum isMyArray(C) = isInstanceOf!(Array, C);

/// Semantics of copy construction and assignment.
enum Assignment
{
    disabled,              /// for reference counting use `std.typecons.RefCounted`
    move,              /// only move construction allowed
    copy               /// always copy (often not the desirable)
}

/** Small-size-optimized (SSO-packed) array of value types `E` with optional
    ordering given by `ordering`.

    Copy construction and assignment currently does copying.

    For move construction use `std.algorithm.mutation.move(source, target)`
    where both arguments are instances of `Array`.
 */
struct Array(E,
             Assignment assignment = Assignment.disabled,
             Ordering ordering = Ordering.unsorted,
             bool useGC = shouldAddGCRange!E,
             alias less = "a < b") // TODO move out of this definition and support only for the case when `ordering` is not `Ordering.unsorted`
{
    import std.range : isInputRange, ElementType;
    import std.traits : isAssignable, Unqual, isSomeChar, isArray;
    import std.functional : binaryFun;
    import std.meta : allSatisfy;
    import qmem;

    alias ME = Unqual!E; // mutable E

    /// Is `true` iff array can be interpreted as a D `string`, `wstring` or `dstring`.
    enum isString = isSomeChar!E;

    alias comp = binaryFun!less; //< comparison

    /// Maximum number of elements that fits in SSO-packed
    enum smallLength = (_storeCapacity.sizeof + _length.sizeof) / E.sizeof;

    /// Returns: `true` iff is SSO-packed.
    bool isSmall() const @safe pure nothrow @nogc { return length <= smallLength; }

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

    /// Create a empty array.
    this(typeof(null)) nothrow
    {
        this(0);
    }

    /// Create a empty array of length `n`.
    this(size_t n) nothrow
    {
        allocateStorePtr(n);
        _length = _storeCapacity = n;
        defaultInitialize();
    }

    /// Construct with length `n`.
    static if (useGC)
    {
        nothrow:

        /// Allocate a store pointer of length `n`.
        private void allocateStorePtr(size_t n) @trusted pure
        {
            _storePtr = cast(E*)GC.malloc(E.sizeof * n);
            static if (shouldAddGCRange!E) { gc_addRange(ptr, length * E.sizeof); }
        }
    }
    else
    {
        nothrow @nogc:

        /// Allocate a store pointer of length `n`.
        private void allocateStorePtr(size_t n) @trusted pure
        {
            _storePtr = cast(E*)_malloc(E.sizeof * n);
            static if (shouldAddGCRange!E) { gc_addRange(ptr, length * E.sizeof); }
        }
    }

    static if (assignment == Assignment.copy)
    {
        /// Copy construction.
        this(this) nothrow @trusted
        {
            postblit();
        }

        /// Copy assignment.
        void opAssign(typeof(this) rhs) @trusted
        {
            // self-assignment may happen when assigning derefenced pointer
            if (_storePtr != rhs._storePtr) // if not self assignment
            {
                reserve(rhs.length);
                foreach (const i; 0 .. _length)
                {
                    ptr[i] = rhs.ptr[i]; // copy from old to new
                }
            }
        }
    }

    static if (assignment == Assignment.disabled ||
               assignment == Assignment.move)
    {
        @disable this(this);

        /// Returns: shallow duplicate of `this`.
        typeof(this) dup() nothrow @trusted
        {
            typeof(return) copy;
            copy._storeCapacity = this._storeCapacity;
            copy._length = this._length;
            copy._storePtr = this._storePtr;
            copy.postblit();
            return copy;
        }
    }

    /// Called either automatically or explicitly depending on `assignment`.
    private void postblit() nothrow @trusted
    {
        auto rhs_storePtr = _storePtr; // save store pointer
        allocateStorePtr(_length);     // allocate new store pointer
        foreach (const i; 0 .. _length)
        {
            ptr[i] = rhs_storePtr[i]; // copy from old to new
        }
    }

    void opAssign(typeof(null))
    {
        clear();
    }

    bool opEquals(const ref typeof(this) rhs) const @trusted
    {
        return this[] == rhs[];
    }

    /** Default-initialize all elements to `zeroValue`.. */
    void defaultInitialize(E zeroValue = E.init) @("complexity", "O(length)")
    {
        ptr[0 .. length] = zeroValue; // NOTE should we zero [0 .. _storeCapacity] instead?
    }

    /** Construct from InputRange `values`.
        If `values` are sorted `assumeSortedParameter` is true.
     */
    this(R)(R values, bool assumeSortedParameter = false) @trusted nothrow @("complexity", "O(n*log(n))")
        if (isInputRange!R)
    {
        // init
        _storePtr = null;
        _storeCapacity = 0;

        // append new data
        import std.range.primitives : hasLength;
        static if (hasLength!R)
        {
            reserve(values.length); // fast reserve
            size_t i = 0;
            foreach (ref value; values)
            {
                ptr[i++] = value;
            }
            _length = values.length;
        }
        else
        {
            size_t i = 0;
            foreach (ref value; values)
            {
                reserve(i + 1); // slower reserve
                ptr[i++] = value;
            }
            _length = i;
        }

        static if (IsOrdered!ordering)
        {
            if (!assumeSortedParameter)
            {
                import std.algorithm.sorting : sort;
                sort!comp(ptr[0 .. _length]);
            }
        }
    }

    /// Reserve room for `n` elements at store `_storePtr`.
    static if (useGC)
    {
        void reserve(size_t n) pure nothrow @trusted
        {
            makeReservedLengthAtLeast(n);
            _storePtr = cast(E*)GC.realloc(_storePtr, E.sizeof * _storeCapacity);
            static if (shouldAddGCRange!E) { gc_addRange(ptr, length * E.sizeof); }
        }
    }
    else
    {
        void reserve(size_t n) pure nothrow @trusted @nogc
        {
            makeReservedLengthAtLeast(n);
            _storePtr = cast(E*)_realloc(_storePtr, E.sizeof * _storeCapacity);
        }
    }

    /// Helper for `reserve`.
    private void makeReservedLengthAtLeast(size_t n) pure nothrow @safe @nogc
    {
        if (_storeCapacity < n) { _storeCapacity = n.nextPow2; }
    }

    /// Pack/Compress storage.
    static if (useGC)
    {
        void compress() pure nothrow @trusted
        {
            if (length)
            {
                _storePtr = cast(E*)GC.realloc(_storePtr, E.sizeof * _length);
            }
            else
            {
                GC.free(_storePtr);
                _storePtr = null;
            }
            _storeCapacity = _length;
        }
    }
    else
    {
        void compress() pure nothrow @trusted @nogc
        {
            if (length)
            {
                _storePtr = cast(E*)_realloc(_storePtr, E.sizeof * _storeCapacity);
            }
            else
            {
                _free(_storePtr);
                _storePtr = null;
            }
            _storeCapacity = _length;
        }
    }
    alias pack = compress;

    /// Destruct.
    static if (useGC)
    {
        nothrow:

        ~this() { release(); }

        void clear()
        {
            release();
            resetInternalData();
        }

        private void release() pure @trusted
        {
            static if (shouldAddGCRange!E) { gc_removeRange(ptr); }
            GC.free(_storePtr);
        }
    }
    else
    {
        nothrow @nogc:

        ~this() { release(); }

        void clear()
        {
            release();
            resetInternalData();
        }

        private void release() pure @trusted
        {
            static if (shouldAddGCRange!E) { gc_removeRange(ptr); }
            _free(_storePtr);
        }
    }

    private void resetInternalData()
    {
        _storePtr = null;
        _length = 0;
        _storeCapacity = 0;
    }

    enum isElementAssignable(U) = isAssignable!(E, U);

    /** Removal doesn't need to care about ordering. */
    ContainerElementType!(typeof(this), E) linearPopAtIndex(size_t index) @trusted @("complexity", "O(length)")
    {
        import std.algorithm : move;

        assert(index < _length);
        assert(!empty);

        typeof(return) value;
        move(ptr[index], value);
        debug ptr[index] = typeof(ptr[index]).init;

        // TODO use memmove instead?
        foreach (const i; 0 .. length - (index + 1)) // each element index that needs to be moved
        {
            const si = index + i + 1; // source index
            const ti = index + i; // target index
            move(ptr[si], ptr[ti]); // ptr[ti] = ptr[si]; // TODO move construct?
            debug ptr[si] = typeof(ptr[si]).init;
        }
        --_length;
        return value;
    }
    alias linearRemoveAt = linearPopAtIndex;
    alias linearDeleteAt = linearPopAtIndex;

    /** Removal doesn't need to care about ordering. */
    ContainerElementType!(typeof(this), E) linearPopFront() @trusted @("complexity", "O(length)")
    {
        assert(!empty);
        typeof(return) value = ptr[0]; // TODO move construct?
        // TODO use memmove instead?
        foreach (const i; 0 .. length - 1) // each element index that needs to be moved
        {
            const si = i + 1; // source index
            const ti = i; // target index
            import std.algorithm : move;
            move(ptr[si], ptr[ti]); // ptr[ti] = ptr[si]; // TODO move construct?
        }
        --_length;
        return value;
    }

    /** Removal doesn't need to care about ordering. */
    void popBack() @safe @("complexity", "O(1)")
    {
        assert(!empty);
        --_length;
    }

    /** Pop back element and return it. */
    E backPop()
    {
        assert(!empty);
        E value = back;
        popBack();
        return value;
    }

    /** Pop last `count` back elements. */
    pragma(inline) void popBackN(size_t count) @safe @("complexity", "O(1)")
    {
        shrinkTo(_length - count);
    }

    static if (!IsOrdered!ordering) // for unsorted arrays
    {
        /// Push back (append) `values`.
        void pushBack(Us...)(Us values) @("complexity", "O(1)")
            if (values.length >= 1 &&
                allSatisfy!(isElementAssignable, Us))
        {
            pushBackHelper(values);
        }
        /// ditto
        void pushBack(R)(R values) @("complexity", "O(values.length)")
            if (isInputRange!R &&
                !(isArray!R) &&
                !(isMyArray!R) &&
                isElementAssignable!(ElementType!R))
        {
            // import std.range.primitives : hasLength;
            // static if (hasLength!R) { dln("Reuse logic in range constructor"); }
            foreach (ref value; values)
            {
                pushBackHelper(value);
            }
        }
        /// ditto.
        void pushBack(A)(A values) @trusted @("complexity", "O(values.length)")
            if (isArray!A &&
                isElementAssignable!(ElementType!A))
        {
            if (ptr == values.ptr) // called as: this ~= this
            {
                reserve(2*length);
                foreach (const i; 0 .. length)
                {
                    ptr[length + i] = ptr[i];
                }
                _length *= 2;
            }
            else
            {
                reserve(length + values.length);
                if (is(Unqual!E == Unqual!(ElementType!A)))
                {
                    // TODO reuse memcopy if ElementType!A is same as E)
                }
                foreach (const i, ref value; values)
                {
                    ptr[length + i] = value;
                }
                _length += values.length;
            }
        }
        /// ditto.
        void pushBack(A)(const ref A values) @trusted @("complexity", "O(values.length)") // TODO `in` parameter qualifier doesn't work here. Compiler bug?
            if (isMyArray!A &&
                isElementAssignable!(ElementType!A))
        {
            if (ptr == values.ptr) // called as: this ~= this
            {
                reserve(2*length);
                // NOTE: this is not needed because we don't need range checking here?:
                // ptr[length .. 2*length] = values.ptr[0 .. length];
                foreach (const i; 0 .. length)
                {
                    ptr[length + i] = values.ptr[i];
                }
                _length *= 2;
            }
            else
            {
                reserve(length + values.length);
                if (is(Unqual!E == Unqual!(ElementType!A)))
                {
                    // TODO reuse memcopy if ElementType!A is same as E)
                }
                foreach (const i, ref value; values.slice)
                {
                    ptr[length + i] = value;
                }
                _length += values.length;
            }
        }
        alias append = pushBack;

        // NOTE these separate overloads of opOpAssign are needed because one
        // `const ref`-parameter-overload doesn't work because of compiler bug
        // with: `this(this) @disable`
        void opOpAssign(string op, Us...)(Us values)
            if (op == "~" &&
                values.length >= 1 &&
                allSatisfy!(isElementAssignable, Us))
        {
            pushBack(values);
        }
	void opOpAssign(string op, R)(R values)
            if (op == "~" &&
                isInputRange!R &&
                allSatisfy!(isElementAssignable, ElementType!R))
        {
            pushBack(values);
        }
	void opOpAssign(string op, A)(const ref A values)
            if (op == "~" &&
                isMyArray!A &&
                isElementAssignable!(ElementType!A))
        {
            pushBack(values);
        }
    }

    static if (IsOrdered!ordering)
    {
        import std.range : SearchPolicy;
        import std.range : assumeSorted;

        /// Returns: `true` iff this contains `value`.
        bool contains(U)(U value) const nothrow @nogc @("complexity", "O(log(length))")
        {
            return this[].contains(value);
        }

        /** Wrapper for `std.range.SortedRange.lowerBound` when this `ordering` is sorted. */
        auto lowerBound(SearchPolicy sp = SearchPolicy.binarySearch, U)(U e) inout @("complexity", "O(log(length))")
        {
            return this[].lowerBound!sp(e);
        }

        /** Wrapper for `std.range.SortedRange.upperBound` when this `ordering` is sorted. */
        auto upperBound(SearchPolicy sp = SearchPolicy.binarySearch, U)(U e) inout @("complexity", "O(log(length))")
        {
            return this[].upperBound!sp(e);
        }

        static if (ordering == Ordering.sortedUniqueSet)
        {
            /** Inserts `values` into `this` ordered set.
                Returns: `bool`-array with same length as `values`, where i:th
                `bool` value is set if `value[i]` wasn't previously in `this`.
            */
            bool[Us.length] linearInsert(SearchPolicy sp = SearchPolicy.binarySearch, Us...)(Us values) @("complexity", "O(length)")
                if (values.length >= 1 &&
                    allSatisfy!(isElementAssignable, Us))
            in
            {
                // assert no duplicates in `values`
                import std.range : empty;
                import std.algorithm.searching : findAdjacent;
                import std.algorithm.sorting : sort;

                // TODO functionize or use other interface in pushing `values`
                import std.traits : CommonType;
                CommonType!Us[Us.length] valuesArray;
                foreach (const i, const ref value; values)
                {
                    valuesArray[i] = value;
                }
                assert(sort(valuesArray[]).findAdjacent.empty, "Parameter `values` must not contain duplicate elements");
            }
            body
            {
                static if (values.length == 1) // faster because `contains()` followed by `completeSort()` searches array twice
                {
                    static if (false)
                    {
                        import std.traits : CommonType;
                        size_t[Us.length] ixs;
                        CommonType!Us[Us.length] vs;
                        size_t i = 0;
                        foreach (const ref value; sort([values]))
                        {
                            const index = indexOf(value);
                            if (index != size_t.max)
                            {
                                ixs[i] = index;
                                vs[i] = value;
                                ++i;
                            }
                        }
                        // TODO insert them in one go in reverse starting from
                        // the end of this array
                    }

                    import searching_ex : containsStoreIndex;
                    size_t index;
                    if (slice.assumeSorted!comp.containsStoreIndex!sp(values, index)) // faster than `completeSort` for single value
                    {
                        return [false];
                    }
                    else
                    {
                        linearInsertAtIndexHelper(index, values);
                        return [true];
                    }
                }
                else
                {
                    import std.algorithm.sorting : completeSort;
                    debug { typeof(return) hits; }
                    else  { typeof(return) hits = void; }
                    size_t expandedLength = 0;
                    const initialLength = length;
                    foreach (const i, ref value; values)
                    {
                        // TODO reuse completeSort with uniqueness handling?
                        static if (values.length == 1)
                        {
                            // TODO reuse single parameter overload linearUniqueInsert() and return
                        }
                        else
                        {
                            // TODO reuse completeSort with uniqueness handling?
                        }
                        hits[i] = !this[0 .. initialLength].contains(value);
                        if (hits[i])
                        {
                            pushBackHelper(value); // NOTE: append but don't yet sort
                            ++expandedLength;
                        }
                    }

                    if (expandedLength != 0)
                    {
                        const ix = length - expandedLength;
                        completeSort!comp(ptr[0 .. ix].assumeSorted!comp,
                                          ptr[ix .. length]);
                    }
                    return hits;
                }
            }
        }
        else static if (ordering == Ordering.sortedValues)
        {
            /** Inserts `values`. */
            void linearInsert(SearchPolicy sp = SearchPolicy.binarySearch, Us...)(Us values) @("complexity", "O(log(length))")
                if (values.length >= 1 &&
                    allSatisfy!(isElementAssignable, Us))
            {
                // TODO add optimization for values.length == 2
                static if (values.length == 1)
                {
                    import searching_ex : containsStoreIndex;
                    size_t index;
                    if (!slice.assumeSorted!comp.containsStoreIndex!sp(values, index)) // faster than `completeSort` for single value
                    {
                        linearInsertAtIndexHelper(index, values);
                    }
                }
                else
                {
                    import std.algorithm.sorting : completeSort;
                    pushBackHelper(values); // simpler because duplicates are allowed
                    const ix = length - values.length;
                    completeSort!comp(ptr[0 .. ix].assumeSorted!comp,
                                      ptr[ix .. length]);
                }
            }
        }
        alias linsert = linearInsert;
    }
    else
    {
        /** Insert element(s) `values` at array offset `index`. */
        void linearInsertAtIndex(Us...)(size_t index, Us values) nothrow @("complexity", "O(length)")
            if (values.length >= 1 &&
                allSatisfy!(isElementAssignable, Us))
        {
            linearInsertAtIndexHelper(index, values);
        }

        /** Insert element(s) `values` at the beginning. */
        void linearPushFront(Us...)(Us values) nothrow @("complexity", "O(length)")
            if (values.length >= 1 &&
                allSatisfy!(isElementAssignable, Us))
        {
            linearInsertAtIndex(0, values);
        }

        alias prepend = linearPushFront;
    }

    /** Helper function used externally for unsorted and internally for sorted. */
    private void linearInsertAtIndexHelper(Us...)(size_t index, Us values) nothrow @("complexity", "O(length)")
    {
        reserve(length + values.length);

        // TODO factor this to robustCopy. It uses copy when no overlaps (my algorithm_em), iteration otherwise
        enum usePhobosCopy = false;
        static if (usePhobosCopy)
        {
            // TODO why does this fail?
            import std.algorithm.mutation : copy;
            copy(ptr[index ..
                     length],        // source
                 ptr[index + values.length ..
                     length + values.length]); // target
        }
        else
        {
            // move second part in reverse
            // TODO functionize move
            foreach (const i; 0 .. length - index) // each element index that needs to be moved
            {
                const si = length - 1 - i; // source index
                const ti = si + values.length; // target index
                ptr[ti] = ptr[si]; // TODO move construct?
            }
        }

        // set new values
        foreach (const i, ref value; values)
        {
            ptr[index + i] = value; // TODO use range algorithm instead?
        }

        _length += values.length;
    }

    private void pushBackHelper(Us...)(Us values) @trusted nothrow @("complexity", "O(1)")
    {
        reserve(length + values.length);
        size_t i = 0;
        foreach (ref value; values)
        {
            ptr[length + i] = value;
            ++i;
        }
        _length += values.length;
    }

    @property @("complexity", "O(1)")
    pragma(inline, true):

    /// ditto
    static if (IsOrdered!ordering)
    {
    const nothrow @nogc:                      // indexing and slicing must be `const` when ordered

        /// Slice operator must be const when ordered.
        auto opSlice()
        {
            return opSlice!(typeof(this))(0, _length);
        }
        /// ditto
        auto opSlice(this This)(size_t i, size_t j) @trusted // const because mutation only via `op.*Assign`
        {
            alias ET = ContainerElementType!(This, E);
            import std.range : assumeSorted;
            return (cast(const(ET)[])slice[i .. j]).assumeSorted!comp;
        }

        auto ref opIndex(size_t i) @trusted
        {
            alias ET = ContainerElementType!(typeof(this), E);
            return cast(const(ET))slice[i];
        }

        /// Get front element (as constant reference to preserve ordering).
        ref const(E) front() @trusted
        {
            assert(!empty);
            return ptr[0];
        }

        /// Get back element (as constant reference to preserve ordering).
        ref const(E) back() @trusted
        {
            assert(!empty);
            return ptr[_length - 1];
        }
    }
    else
    {
        nothrow:

        void resize(size_t length) @safe
        {
            reserve(length);
            _length = length;
        }

        inout:               // indexing and slicing can be mutable when ordered

        /// Slice operator overload is mutable when unordered.
        auto opSlice()
        {
            return this.opSlice(0, _length);
        }
        /// ditto
        auto opSlice(this This)(size_t i, size_t j) @trusted
        {
            alias ET = ContainerElementType!(This, E);
            return cast(inout(ET)[])slice[i .. j];
        }

        /// Index operator can be const or mutable when unordered.
        auto ref opIndex(size_t i) @trusted
        {
            alias ET = ContainerElementType!(typeof(this), E);
            return cast(inout(ET))slice[i];
        }

        /// Get front element reference.
        ref inout(E) front() inout @trusted
        {
            assert(!empty);
            return ptr[0];
        }

        /// Get back element reference.
        ref inout(E) back() inout @trusted
        {
            assert(!empty);
            return ptr[_length - 1];
        }
    }

    pure nothrow:

    @nogc:

    /// Check if empty.
    bool empty() const @safe
    {
        return _length == 0;
    }

    /// Get length.
    size_t length() const @safe
    {
        return _length;
    }
    alias opDollar = length;    /// ditto

    /// Shrink length to `length`.
    void shrinkTo(size_t length) @safe
    {
        assert(length <= _length);
        _length = length;
    }
    alias opDollar = length;    /// ditto

    /// Get length of reserved store.
    size_t reservedLength() const @safe
    {
        return _storeCapacity;
    }
    alias capacity = reservedLength;

    /// Get internal pointer.
    private inout(E*) ptr() inout
    {
        // TODO Use cast(ET[])?: alias ET = ContainerElementType!(typeof(this), E);
        return _storePtr;
    }

    /// Get internal slice.
    private auto ref slice() inout @trusted
    {
        return ptr[0 .. length];
    }

private:
    // TODO reuse module `storage` for small size/array optimization (SSO)
    E* _storePtr;               // store pointer
    size_t _storeCapacity;      // store capacity
    size_t _length;             // length
}

alias SortedArray(E, Assignment assignment = Assignment.disabled,
                  bool useGC = shouldAddGCRange!E,
                  alias less = "a < b") = Array!(E, assignment, Ordering.sortedValues, useGC, less);

alias SortedSetArray(E, Assignment assignment = Assignment.disabled,
                     bool useGC = shouldAddGCRange!E,
                     alias less = "a < b") = Array!(E, assignment, Ordering.sortedUniqueSet, useGC, less);

static void tester(Ordering ordering, bool supportGC, alias less)()
{
    import std.functional : binaryFun;
    import std.range : iota, retro, chain, repeat, only, ElementType;
    import std.algorithm : filter, map;
    import std.algorithm.sorting : isSorted, sort;
    import std.exception : assertThrown, assertNotThrown;
    import std.traits : isInstanceOf;
    import std.typecons : Unqual;

    enum assignment = Assignment.copy;
    alias comp = binaryFun!less; //< comparison

    alias E = int;

    foreach (Ch; AliasSeq!(char, wchar, dchar))
    {
        alias Str = Array!(Ch, assignment, ordering, supportGC, less);
        Str str;
        static assert(is(Unqual!(ElementType!Str) == Ch));
        static assert(str.isString);
        str = Str.init;         // inhibit Dscanner warning
    }

    static if (E.sizeof == 4)
    {
        foreach (const n; [0, 1, 2, 3, 4])
        {
            assert(Array!(E, assignment, ordering, supportGC, less)(n).isSmall);
        }
        assert(!(Array!(E, assignment, ordering, supportGC, less)(5).isSmall));
    }

    // test move construction
    {
        const maxLength = 1024;
        foreach (const n; 0 .. maxLength)
        {
            auto x = Array!(E, assignment, ordering, supportGC, less)(n);

            // test resize
            static if (!IsOrdered!ordering)
            {
                assert(x.length == n);
                x.resize(n + 1);
                assert(x.length == n + 1);
                x.resize(n);
            }

            const ptr = x.ptr;
            const capacity = x.capacity;
            assert(x.length == n);

            import std.algorithm.mutation : move;
            auto y = Array!(E, assignment, ordering, supportGC, less)();
            move(x, y);

            assert(x.length == 0);
            assert(x.capacity == 0);
            assert(x.ptr == null);

            assert(y.length == n);
            assert(y.capacity == capacity);
            assert(y.ptr == ptr);

        }
    }

    foreach (const n; chain(0.only,
                            iota(0, 10).map!(x => 2^^x)))
    {
        import std.array : array;
        import std.range : radial, retro;

        const zi = cast(int)0;
        const ni = cast(int)n;

        auto fw = iota(zi, ni); // 0, 1, 2, ..., n-1

        // TODO use radial instead
        auto bw = fw.array.radial;

        Array!(E, assignment, ordering, supportGC, less) ss0 = bw; // reversed
        static assert(is(Unqual!(ElementType!(typeof(ss0))) == E));
        static assert(isInstanceOf!(Array, typeof(ss0)));
        assert(ss0.length == n);

        static if (IsOrdered!ordering)
        {
            if (!ss0.empty) { assert(ss0[0] == ss0[0]); } // trigger use of opindex
            assert(ss0[].equal(fw.array.sort!comp));
            assert(ss0[].isSorted!comp);
        }

        Array!(E, assignment, ordering, supportGC, less) ss1 = fw; // ordinary
        assert(ss1.length == n);

        static if (IsOrdered!ordering)
        {
            assert(ss1[].equal(fw.array.sort!comp));
            assert(ss1[].isSorted!comp);
        }

        Array!(E, assignment, ordering, supportGC, less) ss2 = fw.filter!(x => x & 1);
        assert(ss2.length == n/2);

        static if (IsOrdered!ordering)
        {
            assert(ss2[].equal(fw.filter!(x => x & 1).array.sort!comp));
            assert(ss2[].isSorted!comp);
        }

        auto ssA = Array!(E, assignment, ordering, supportGC, less)(0);
        static if (IsOrdered!ordering)
        {
            static if (less == "a < b")
            {
                alias A = Array!(E, assignment, ordering, supportGC, less);
                const A x = [1, 2, 3, 4, 5, 6];
                assert(x.front == 1);
                assert(x.back == 6);
                assert(x.lowerBound(3).equal([1, 2]));
                assert(x.upperBound(3).equal([4, 5, 6]));
            }

            foreach (i; bw)
            {
                static if (ordering == Ordering.sortedUniqueSet)
                {
                    assert(ssA.linearInsert(i)[].equal([true]));
                    assert(ssA.linearInsert(i)[].equal([false]));
                }
                else
                {
                    ssA.linearInsert(i);
                }
            }
            assert(ssA[].equal(sort!comp(fw.array)));

            auto ssB = Array!(E, assignment, ordering, supportGC, less)(0);
            static if (ordering == Ordering.sortedUniqueSet)
            {
                assert(ssB.linearInsert(1, 7, 4, 9)[].equal(true.repeat(4)));
                assert(ssB.linearInsert(3, 6, 8, 5, 1, 9)[].equal([true, true, true, true, false, false]));
                assert(ssB.linearInsert(3, 0, 2, 10, 11, 5)[].equal([false, true, true, true, true, false]));
                assert(ssB.linearInsert(0, 2, 10, 11)[].equal(false.repeat(4))); // false becuse already inserted
                assert(ssB.reservedLength == 16);
            }
            else
            {
                ssB.linearInsert(1, 7, 4, 9);
                ssB.linearInsert(3, 6, 8, 5);
                ssB.linearInsert(0, 2, 10, 11);
                assert(ssB.reservedLength == 16);
            }

            auto ssI = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].sort!comp; // values
            const ssO = [12, 13]; // values not range

            assert(ssB[].equal(ssI));

            foreach (s; ssI) { assert(ssB.contains(s)); }
            foreach (s; ssO) { assert(!ssB.contains(s)); }

            ssB.compress;
            assert(ssB.reservedLength == 12);
        }
        else
        {
            {
                alias A = Array!(E, assignment, ordering, supportGC);
                A x = [1, 2, 3];
                x ~= x;
                assert(x[].equal([1, 2, 3,
                                  1, 2, 3]));
                x ~= x[];
                assert(x[].equal([1, 2, 3, 1, 2, 3,
                                  1, 2, 3, 1, 2, 3]));
            }

            ssA ~= 3;
            ssA ~= 2;
            ssA ~= 1;
            assert(ssA[].equal([3, 2, 1]));
            assert(ssA.reservedLength == 4);

            ssA.compress;
            assert(ssA.reservedLength == 3);

            // popBack
            ssA[0] = 1;
            ssA[1] = 2;
            assert(ssA[].equal([1, 2, 1]));
            assert(!ssA.empty);
            assert(ssA.front == 1);
            assert(ssA.back == 1);

            assertNotThrown(ssA.popBack);
            assert(ssA[].equal([1, 2]));
            assert(!ssA.empty);
            assert(ssA.front == 1);
            assert(ssA.back == 2);

            assertNotThrown(ssA.popBack);
            assert(ssA[].equal([1]));
            assert(!ssA.empty);
            assert(ssA.front == 1);
            assert(ssA.back == 1);

            assertNotThrown(ssA.popBack);
            assert(ssA.length == 0);
            assert(ssA.empty);
            assert(ssA.reservedLength != 0);

            ssA.compress;
            assert(ssA.length == 0);
            assert(ssA.reservedLength == 0);
            assert(ssA.empty);

            // linearInsertAt
            ssA ~= 1;
            ssA ~= 2;
            ssA ~= 3;
            ssA ~= 4;
            ssA ~= 5;
            ssA ~= 6;
            ssA ~= 7;
            ssA ~= 8;
            assert(ssA[].equal([1, 2, 3, 4, 5, 6, 7, 8]));
            ssA.linearInsertAtIndex(3, 100, 101);
            assert(ssA[].equal([1, 2, 3, 100, 101, 4, 5, 6, 7, 8]));
            assertNotThrown(ssA.linearPopFront);
            assert(ssA[].equal([2, 3, 100, 101, 4, 5, 6, 7, 8]));
            assertNotThrown(ssA.linearPopFront);
            assert(ssA[].equal([3, 100, 101, 4, 5, 6, 7, 8]));
            assertNotThrown(ssA.linearPopFront);
            assert(ssA[].equal([100, 101, 4, 5, 6, 7, 8]));
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assertNotThrown(ssA.linearPopFront);
            assert(ssA.empty);
            ssA.compress;

            // linearPopAtIndex
            ssA ~= 1;
            ssA ~= 2;
            ssA ~= 3;
            ssA ~= 4;
            ssA ~= 5;
            assertNotThrown(ssA.linearPopAtIndex(2));
            assert(ssA[].equal([1, 2, 4, 5]));

            // pushBack and assignment from slice
            auto ssB = Array!(E, assignment, ordering, supportGC, less)(0);
            ssB.pushBack([1, 2, 3, 4, 5]);
            ssB.pushBack([6, 7]);
            assert(ssB[].equal([1, 2, 3, 4, 5, 6, 7]));
            assert(ssB.backPop == 7);
            assert(ssB.backPop == 6);
            assert(ssB.backPop == 5);
            assert(ssB.backPop == 4);
            assert(ssB.backPop == 3);
            assert(ssB.backPop == 2);
            assert(ssB.backPop == 1);
            assert(ssB.empty);

            // pushBack(Array)
            {
                const s = [1, 2, 3];
                Array!(E, assignment, ordering, supportGC, less) s1 = s;
                Array!(E, assignment, ordering, supportGC, less) s2 = s1[];
                assert(s1[].equal(s));
                s1 ~= s1;
                assert(s1[].equal(chain(s, s)));
                s1 ~= s2;
                assert(s1[].equal(chain(s, s, s)));
            }

            const ss_ = Array!(E, assignment, ordering, supportGC, less)(null);
            assert(ss_.empty);

            auto ssC = Array!(E, assignment, ordering, supportGC, less)(0);
            const(int)[] i5 = [1, 2, 3, 4, 5];
            ssC.pushBack(i5);
            assert(ssC[].equal(i5));

            auto ssCc = ssC;    // copy it
            assert(ssCc[].equal(i5));

            ssC.shrinkTo(4);
            assert(ssC[].equal([1, 2, 3, 4]));

            ssC.shrinkTo(3);
            assert(ssC[].equal([1, 2, 3]));

            ssC.shrinkTo(2);
            assert(ssC[].equal([1, 2]));

            ssC.shrinkTo(1);
            assert(ssC[].equal([1]));

            ssC.shrinkTo(0);
            assert(ssC[].length == 0);
            assert(ssC.empty);

            ssC.pushBack(i5);
            ssC.popBackN(3);
            assert(ssC[].equal([1, 2]));

            auto ssD = ssC;
            ssC.clear();
            assert(ssC.empty);

            assert(!ssD.empty);
            ssD = null;
            assert(ssD.empty);

            assert(ssCc[].equal(i5));

            ssCc = ssCc;   // self assignment
        }
    }
}

/// disabled copying
pure nothrow unittest
{
    import std.functional : binaryFun;
    import std.conv : to;
    enum less = "a < b";
    alias comp = binaryFun!less; //< comparison
    alias E = string;
    alias A = Array!(E, Assignment.disabled, Ordering.unsorted, false, less);
    A a;
    const n = 100_000;
    size_t i = 0;
    foreach (const ref e; 0 .. n)
    {
        a ~= e.to!E;
        assert(a.length == i + 1);
        ++i;
    }
    const b = a.dup;
    assert(b.length == a.length);
    assert(a !is b);
    assert(a == b);
    assert(a[] == b[]);
}

/// use GC
pure nothrow unittest
{
    import std.traits : EnumMembers;
    foreach (ordering; EnumMembers!Ordering)
    {
        tester!(ordering, true, "a < b"); // use GC
        tester!(ordering, true, "a > b"); // use GC
    }
}

/// don't use GC
pure nothrow /+TODO @nogc+/ unittest
{
    import std.traits : EnumMembers;
    foreach (ordering; EnumMembers!Ordering)
    {
        tester!(ordering, false, "a < b"); // don't use GC
        tester!(ordering, false, "a > b"); // don't use GC
    }
}
