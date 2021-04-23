module nxt.dynamic_array;

// version = debugCtors;

import core.internal.traits : Unqual;

/** Array type with deterministic control of memory. The memory allocated for
    the array is reclaimed as soon as possible; there is no reliance on the
    garbage collector. Array uses malloc, realloc and free for managing its own
    memory.

    A null `Allocator` means means to qcmeman functions. TODO use `PureMallocator` by default

    TODO: Use `std.bitmanip.BitArray` for array container storing boolean values.
    TODO: Add OutputRange.writer support as
    https://github.com/burner/StringBuffer/blob/master/source/stringbuffer.d#L45
    TODO: Use `std.traits.areCopyCompatibleArrays`

    See also https://github.com/izabera/s
 */
@safe struct DynamicArray(T, alias Allocator = null, CapacityType = size_t)
if (!is(Unqual!T == bool) &&             // use `BitArray` instead
    (is(CapacityType == ulong) ||        // 3 64-bit words
     is(CapacityType == uint)))          // 2 64-bit words
{
    /** Growth factor P/Q.
        https://github.com/facebook/folly/blob/master/folly/docs/FBVector.md#memory-handling
        Use 1.5 like Facebook's `fbvector` does.
    */
    enum _growthP = 3;          // numerator
    /// ditto
    enum _growthQ = 2;          // denominator

    // import core.exception : onOutOfMemoryError;
    import core.internal.traits : hasElaborateDestructor;

    import std.range.primitives : isInputRange, ElementType, hasLength, hasSlicing, isInfinite;
    import std.traits : hasIndirections, hasAliasing,
        isMutable, TemplateOf, isArray, isAssignable, isType, hasFunctionAttributes, isIterable, isPointer;
    import core.lifetime : emplace, move, moveEmplace;

    import nxt.qcmeman : malloc, calloc, realloc, free, gc_addRange, gc_removeRange;
    import nxt.container_traits : mustAddGCRange, needsMove;

    /// Mutable element type.
    private alias MutableE = Unqual!T;

    /// Is `true` if `U` can be assign to the element type `T` of `this`.
    enum isElementAssignable(U) = isAssignable!(MutableE, U);

pragma(inline):

    /// Returns: an array of length `initialLength` with all elements default-initialized to `ElementType.init`.
    static typeof(this) withLength()(size_t initialLength) // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return withCapacityLengthZero(initialLength, initialLength, true);
    }

    /// Returns: an array with initial capacity `initialCapacity`.
    static typeof(this) withCapacity()(size_t initialCapacity) // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return withCapacityLengthZero(initialCapacity, 0, false);
    }

    static if (__traits(isCopyable, T))
    {
        /** Construct using
         * - initial length `length`,
         * - and value of all elements `elementValue`.
         */
        static typeof(this) withLengthElementValue()(size_t length, T elementValue)
        in(length <= CapacityType.max)
        {
            version(D_Coverage) {} else pragma(inline, true);
            return typeof(return)(Store(typeof(this).allocateWithValue(length, move(elementValue)),
                                        cast(CapacityType)length,
                                        cast(CapacityType)length));
        }
    }

    /** Construct using
        - initial capacity `capacity`,
        - initial length `length`,
        - and zeroing-flag `zero`.
    */
    private static typeof(this) withCapacityLengthZero()(size_t capacity, size_t length, bool zero) @trusted // template-lazy
    in(capacity >= length)
    in(capacity <= CapacityType.max)
    {
        version(LDC) pragma(inline, true);
        return typeof(return)(Store(typeof(this).allocate(capacity, zero),
                                    cast(CapacityType)capacity,
                                    cast(CapacityType)length));
    }

    /** Emplace `thatPtr` with elements moved from `elements`. */
    static ref typeof(this) emplaceWithMovedElements()(typeof(this)* thatPtr, T[] elements) @system // template-lazy
    {
        immutable length = elements.length;
        thatPtr._store.ptr = typeof(this).allocate(length, false);
        thatPtr._store.capacity = cast(CapacityType)length;
        thatPtr._store.length = cast(CapacityType)length;
        foreach (immutable i, ref e; elements[])
            moveEmplace(e, thatPtr._mptr[i]);
        return *thatPtr;
    }

    /** Emplace `thatPtr` with elements copied from `elements`. */
    static ref typeof(this) emplaceWithCopiedElements()(typeof(this)* thatPtr, const(T)[] elements) @system // template-lazy
    if (__traits(isCopyable, T))
    {
        immutable length = elements.length;
        thatPtr._store.ptr = typeof(this).allocate(length, false);
        thatPtr._store.capacity = cast(CapacityType)length;
        thatPtr._store.length = cast(CapacityType)length;
        foreach (immutable i, ref e; elements[])
            thatPtr._mptr[i] = cast(T)e; // TODO: restrict this function using a
                                         // T-trait where this cast can be @trusted
        return *thatPtr;
    }

    private this(Store store)
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(store));
        _store = store;
    }

    /// Construct from uncopyable element `value`.
    this()(T value) @trusted    // template-lazy
    if (!__traits(isCopyable, T))
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(value));
        _store.ptr = typeof(this).allocate(1, false);
        _store.capacity = 1;
        _store.length = 1;
        moveEmplace(value, _mptr[0]); // TODO: remove `moveEmplace` when compiler does it for us
    }

    /// Construct from copyable element `value`.
    this(U)(U value) @trusted
    if (__traits(isCopyable, U) &&
        isElementAssignable!U)
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(value));
        _store.ptr = typeof(this).allocate(1, false);
        _store.capacity = 1;
        _store.length = 1;
        emplace(&_mptr[0], value);
    }

    static if (__traits(isCopyable, T) &&
               !is(T == union)) // forbid copying of unions such as `HybridBin` in hashmap.d
    {
        static typeof(this) withElements()(const T[] elements) @trusted // template-lazy
        {
            version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(elements));
            immutable length = elements.length;
            auto ptr = typeof(this).allocate(length, false);

            foreach (immutable i, const element; elements[])
                // TODO: be more strict
                // static if (hasIndirections!T)
                // {
                //     ptr[i] = element;
                // }
                // else
                // {
                //     ptr[i] = *cast(MutableE*)&element;
                // }
                ptr[i] = *cast(MutableE*)&element;

            // ptr[0 .. length] = elements[];
            return typeof(return)(Store(ptr,
                                        cast(CapacityType)length,
                                        cast(CapacityType)length));
        }

        /// Returns: shallow duplicate of `this`.
        @property DynamicArray!(Unqual!T, Allocator, CapacityType) dup()() const @trusted // template-lazy
        {
            version(D_Coverage) {} else pragma(inline, true);
            return typeof(this).withElements(this[]);
        }
    }

    /// Construct from the element(s) of the dynamic array `values`.
    this(U)(U[] values) @trusted
    if (isElementAssignable!(U))
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(values));
        // TODO: use import emplace_all instead

        _store.ptr = allocate(values.length, false);
        static if (!is(CapacityType == size_t))
            assert(values.length <= CapacityType.max,
                   "Minimum capacity doesn't fit in capacity type.");
        _store.capacity = cast(CapacityType)values.length;

        foreach (index; 0 .. values.length)
            static if (needsMove!(T))
                move(values[index], _mptr[index]);
            else
                _mptr[index] = values[index];

        setLengthChecked(values.length);
    }

    /// Construct from the `n` number of element(s) in the static array `values`.
    this(uint n, U)(U[n] values) @trusted
    if (isElementAssignable!(U))
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(values));
        // TODO: use import emplace_all instead

        _store.ptr = allocate(values.length, false);
        static assert(values.length <= CapacityType.max);
        _store.capacity = cast(CapacityType)values.length;

        static foreach (index; 0 .. values.length)
            static if (needsMove!(T))
                move(values[index], _mptr[index]);
            else
                _mptr[index] = values[index];

        setLengthChecked(values.length);
    }
    /// ditto
    this(R)(scope R values) @trusted
    if (// isRefIterable!R &&
        isElementAssignable!(ElementType!R) &&
        !isArray!R)
    {
        version(debugCtors) pragma(msg, __FILE_FULL_PATH__, ":", __LINE__, ": info: ", typeof(values));
        static if (hasLength!R)
        {
            reserve(values.length);
            size_t index = 0;
            foreach (ref value; values)
                _mptr[index++] = value;
            setLengthChecked(values.length);
        }
        else
            foreach (ref value; values)
                insertBack1(value);
    }

    /** Is `true` iff the iterable container `C` can be insert to `this`.
     */
    private enum isInsertableContainer(C) = (is(C == struct) && // exclude class ranges for aliasing control
                                             isRefIterable!C && // elements may be non-copyable
                                             !isInfinite!C &&
                                             isElementAssignable!(ElementType!C));

    /// Construct from the elements `values`.
    static typeof(this) withElementsOfRange_untested(R)(R values) @trusted
    if (isInsertableContainer!R)
    {
        typeof(this) result;

        static if (hasLength!R)
            result.reserve(values.length);

        static if (hasLength!R &&
                   hasSlicing!R &&
                   !needsMove!(ElementType!R))
        {
            import std.algorithm.mutation : copy;
            copy(values[0 .. values.length],
                 result._mptr[0 .. values.length]); // TODO: better to use foreach instead?
            result.setLengthChecked(values.length);
        }
        else
        {
            static if (hasLength!R)
            {
                size_t i = 0;
                foreach (ref value; move(values)) // TODO: remove `move` when compiler does it for us
                    static if (needsMove!(typeof(value)))
                        moveEmplace(value, result._mptr[i++]);
                    else
                        result._mptr[i++] = value;
                result.setLengthChecked(values.length);
            }
            else
            {
                // import std.algorithm.mutation : moveEmplaceAll;
                /* TODO: optimize with `moveEmplaceAll` that does a raw copy and
                 * zeroing of values */
                foreach (ref value; move(values)) // TODO: remove `move` when compiler does it for us
                    static if (needsMove!(ElementType!R))
                        result.insertBackMove(value); // steal element
                    else
                        result.insertBack(value);
            }
        }
        return result;
    }

    /// No default copying.
    @disable this(this);

    // TODO: this gives error in insertBack. why?
    // void opAssign()(typeof(this) rhs) @trusted pure nothrow @nogc // template-lazy
    // {
    //     move(rhs, this);
    // }

    /** Destruct.
     *
     * TODO: what effect does have here?
     * See_Also: https://github.com/atilaneves/automem/blob/master/source/automem/vector.d#L92
     */
    ~this() @nogc /*TODO: scope*/
    {
        releaseElementsStore();
    }

    /// Empty.
    void clear() @nogc
    {
        releaseElementsStore();
        resetInternalData();
    }

    /// Release elements and internal store.
    private void releaseElementsStore() @nogc @trusted
    {
        foreach (immutable index; 0 .. _store.length)
            static if (hasElaborateDestructor!T)
                .destroy(_mptr[index]);
            else static if (is(T == class) || isPointer!T || hasIndirections!T)
                _mptr[index] = T.init; // nullify any pointers
        freeStore();
    }

    /// Free internal store.
    private void freeStore() @trusted
    {
        static if (mustAddGCRange!T)
            gc_removeRange(_mptr);
        free(_mptr);
    }

    /// Reset internal data.
    private void resetInternalData() @nogc
    {
        version(D_Coverage) {} else pragma(inline, true);
        _store.ptr = null;
        _store.capacity = 0;
        _store.length = 0;
    }

    /** Allocate heap region with `initialCapacity` number of elements of type `T`.
     *
     * If `zero` is `true` they will be zero-initialized.
     */
    private static MutableE* allocate(size_t initialCapacity, bool zero) @trusted
    {
        immutable size_t numBytes = initialCapacity * T.sizeof;

        typeof(return) ptr = null;
        static if (!is(typeof(Allocator) == typeof(null)))
        {
            import std.experimental.allocator : makeArray;
            if (zero)
                ptr = Allocator.makeArray!T(initialCapacity, 0).ptr; // TODO: set length
            else
                ptr = cast(typeof(return))Allocator.allocate(numBytes).ptr; // TODo set length
        }
        else
        {
            if (zero)
                ptr = cast(typeof(return))calloc(initialCapacity, T.sizeof);
            else
                ptr = cast(typeof(return))malloc(numBytes);
            assert(ptr, "Allocation failed");
        }

        if (ptr is null &&
            initialCapacity >= 1 )
            // TODO: onOutOfMemoryError();
            return null;

        static if (mustAddGCRange!T)
            gc_addRange(ptr, numBytes);

        return ptr;
    }

    static if (__traits(isCopyable, T))
    {
        /** Allocate heap region with `initialCapacity` number of elements of type `T` all set to `elementValue`.
         */
        private static MutableE* allocateWithValue(size_t initialCapacity, T elementValue) @trusted
        {
            immutable size_t numBytes = initialCapacity * T.sizeof;

            typeof(return) ptr = null;
            static if (!is(typeof(Allocator) == typeof(null)))
            {
                import std.experimental.allocator : makeArray;
                ptr = Allocator.makeArray!T(initialCapacity, elementValue).ptr; // TODO: set length
                if (ptr is null &&
                    initialCapacity >= 1)
                    // TODO: onOutOfMemoryError();
                    return null;
            }
            else
            {
                ptr = cast(typeof(return))malloc(numBytes);
                if (ptr is null &&
                    initialCapacity >= 1)
                    // TODO: onOutOfMemoryError();
                    return null;
                foreach (immutable index; 0 .. initialCapacity)
                    emplace(&ptr[index], elementValue);
            }

            static if (mustAddGCRange!T)
                gc_addRange(ptr, numBytes);

            return ptr;
        }
    }

    /** Comparison for equality. */
    bool opEquals()(const scope auto ref typeof(this) rhs) const scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice() == rhs.opSlice();
    }
    /// ditto
    bool opEquals(U)(const scope U[] rhs) const scope
    if (is(typeof(T[].init == U[].init)))
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice() == rhs;
    }

    /// Calculate D associative array (AA) key hash.
    hash_t toHash()() const scope @trusted // template-lazy
    {
        import core.internal.hash : hashOf;
        static if (__traits(isCopyable, T))
            return hashOf(this.length) ^ hashOf(opSlice());
        else
        {
            typeof(return) hash = hashOf(this.length);
            foreach (immutable index; 0 .. this.length)
                hash ^= this.ptr[index].hashOf;
            return hash;
        }
    }

    static if (__traits(isCopyable, T))
    {
        /** Construct a string representation of `this` at `sink`.
         */
        void toString()(scope void delegate(scope const(char)[]) sink) const scope // template-lazy
        {
            sink("[");
            foreach (immutable index, ref value; opSlice())
            {
                import std.conv : to;
                sink(to!string(value));
                if (index + 1 < length) { sink(", "); } // separator
            }
            sink("]");
        }
    }

    /// Check if empty.
    @property bool empty()() const scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return _store.length == 0;
    }

    /// Get length.
    @property size_t length() const scope // can't be template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return _store.length;
    }
    alias opDollar = length;    /// ditto

    /** Set length to `newLength`.
     *
     * If `newLength` < `length` elements are truncate.
     * If `newLength` > `length` default-initialized elements are appended.
     */
    @property void length(size_t newLength) @trusted scope // can't template-lazy
    {
        if (newLength < length) // if truncatation
        {
            static if (hasElaborateDestructor!T)
                foreach (immutable index; newLength .. _store.length)
                    .destroy(_mptr[index]);
            else static if (mustAddGCRange!T)
                foreach (immutable index; newLength .. _store.length)
                    _mptr[index] = T.init; // avoid GC mark-phase dereference
        }
        else
        {
            reserve(newLength);
            static if (hasElaborateDestructor!T)
                // TODO: remove when compiler does it for us
                foreach (immutable index; _store.length .. newLength)
                {
                    // TODO: remove when compiler does it for us:
                    static if (__traits(isCopyable, T))
                        emplace(&_mptr[index], T.init);
                    else
                    {
                        auto _ = T.init;
                        moveEmplace(_, _mptr[index]);
                    }
                }
            else
                _mptr[_store.length .. newLength] = T.init;
        }

        setLengthChecked(newLength);
    }

    /// Set capacity, checking for overflow when `CapacityType` is not `size_t`.
    private void setLengthChecked(size_t newLength) scope
    {
        static if (!is(CapacityType == size_t))
            assert(newLength <= CapacityType.max,
                   "New length doesn't fit in capacity type.");
        _store.length = cast(CapacityType)newLength;
    }

    /// Get capacity.
    @property size_t capacity() const scope // can't be template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return _store.capacity;
    }

    /** Ensures sufficient capacity to accommodate for minimumCapacity number of
        elements. If `minimumCapacity` < `capacity`, this method does nothing.
     */
    void reserve(size_t minimumCapacity) @trusted scope pure nothrow @nogc
    {
        static if (!is(CapacityType == size_t))
            assert(minimumCapacity <= CapacityType.max,
                   "Minimum capacity doesn't fit in capacity type.");

        if (minimumCapacity <= capacity)
            return;

        reallocateAndSetCapacity(_growthP * minimumCapacity / _growthQ);
        // import std.math : nextPow2;
        // reallocateAndSetCapacity(minimumCapacity.nextPow2);
    }

    /// Reallocate storage.
    private void reallocateAndSetCapacity()(size_t newCapacity) @trusted // template-lazy
    {
        static if (!is(CapacityType == size_t))
            assert(newCapacity <= CapacityType.max,
                   "New capacity doesn't fit in capacity type.");

        static if (mustAddGCRange!T)
            gc_removeRange(_store.ptr);

        _store.capacity = cast(CapacityType)newCapacity;
        _store.ptr = cast(T*)realloc(_mptr, T.sizeof * _store.capacity);

        if (_store.ptr is null &&
            newCapacity >= 1)
            // TODO: onOutOfMemoryError();
            return;

        static if (mustAddGCRange!T)
            gc_addRange(_store.ptr, _store.capacity * T.sizeof);
    }

    /// Index support.
    ref inout(T) opIndex()(size_t i) inout return scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[i];
    }

    /// Slice support.
    inout(T)[] opSlice()(size_t i, size_t j) inout return scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[i .. j];
    }
    /// ditto
    inout(T)[] opSlice()() inout return @trusted scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return _store.ptr[0 .. _store.length];
    }

    /// Index assignment support.
    ref T opIndexAssign(U)(scope U value, size_t i) @trusted return scope
    {
        static if (needsMove!T)
        {
            move(*(cast(MutableE*)(&value)), _mptr[i]); // TODO: is this correct?
            return opSlice()[i];
        }
        else static if ((is(T == class) || isPointer!T || hasIndirections!T) &&
                        !isMutable!T)
            static assert("Cannot modify constant elements with indirections");
        else
            return opSlice()[i] = value;
    }

    /// Slice assignment support.
    T[] opSliceAssign(U)(scope U value) return scope
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[] = value;
    }
    /// ditto
    T[] opSliceAssign(U)(scope U value, size_t i, size_t j) return scope
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[i .. j] = value;
    }

    /// Get reference to front element.
    @property ref inout(T) front()() inout return scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[0];      // range-checked by default
    }

    /// Get reference to back element.
    @property ref inout(T) back()() inout return scope // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return opSlice()[_store.length - 1]; // range-checked by default

    }

    /** Move `value` into the end of the array.
     */
    void insertBackMove()(ref T value) @trusted // template-lazy
    {
        version(LDC) pragma(inline, true);
        reserve(_store.length + 1);
        moveEmplace(value, _mptr[_store.length]);
        _store.length += 1;
    }

    /** Insert `value` into the end of the array.
     */
    void insertBack()(T value) @trusted // template-lazy
    {
        static if (needsMove!T)
            insertBackMove(*cast(MutableE*)(&value));
        else
        {
            reserve(_store.length + 1);
            _mptr[_store.length] = value;
            _store.length += 1;
        }
    }

    alias put = insertBack;

    /** Insert the elements `values` into the end of the array.
     */
    void insertBack(U)(U[] values...) @trusted
    if (isElementAssignable!U &&
        __traits(isCopyable, U))       // prevent accidental move of l-value `values`
    {
        if (values.length == 1) // TODO: branch should be detected at compile-time
            // twice as fast as array assignment below
            return insertBack(values[0]);

        static if (is(T == immutable(T)))
        {
            /* An array of immutable values cannot overlap with the `this`
               mutable array container data, which entails no need to check for
               overlap.
            */
            reserve(_store.length + values.length);
            _mptr[_store.length .. _store.length + values.length] = values;
        }
        else
        {
            import nxt.overlapping : overlaps;
            if (_store.ptr == values.ptr) // called for instances as: `this ~= this`
            {
                reserve(2*_store.length); // invalidates `values.ptr`
                foreach (immutable i; 0 .. _store.length)
                {
                    _mptr[_store.length + i] = _store.ptr[i];
                }
            }
            else if (overlaps(this[], values[]))
                assert(0, `TODO: Handle overlapping arrays`);
            else
            {
                reserve(_store.length + values.length);
                _mptr[_store.length .. _store.length + values.length] = values;
            }
        }
        _store.length += values.length;
    }

    /** Insert the elements `elements` into the end of the array.
     */
    void insertBack(R)(scope R elements) @trusted
    if (isInsertableContainer!R)
    {
        import std.range.primitives : hasLength;
        static if (isInputRange!R &&
                   hasLength!R)
        {
            reserve(_store.length + elements.length);
            import std.algorithm.mutation : copy;
            copy(elements, _mptr[_store.length .. _store.length + elements.length]);
            _store.length += elements.length;
        }
        else
        {
            foreach (ref element; move(elements)) // TODO: remove `move` when compiler does it for us
                static if (__traits(isCopyable, ElementType!R))
                    insertBack(element);
                else
                    insertBackMove(element);
        }
    }
    /// ditto
    alias put = insertBack;

    /** Remove last value fromm the end of the array.
     */
    void popBack()() @trusted   // template-lazy
    in(!empty)
    {
        version(D_Coverage) {} else pragma(inline, true);
        _store.length -= 1;
        static if (hasElaborateDestructor!T)
            .destroy(_mptr[_store.length]);
        else static if (mustAddGCRange!T)
            _mptr[_store.length] = T.init; // avoid GC mark-phase dereference
    }

    /** Rmove `n` last values from the end of the array.

        See_Also: http://mir-algorithm.libmir.org/mir_appender.html#.ScopedBuffer.popBackN
     */
    void popBackN()(size_t n) @trusted   // template-lazy
    in(length >= n)
    {
        _store.length -= n;
        static if (hasElaborateDestructor!T)
            foreach (immutable index; 0 .. n)
                .destroy(_mptr[_store.length + index]);
        else static if (mustAddGCRange!T)
            foreach (immutable index; 0 .. n)
                _mptr[_store.length + index] = T.init; // avoid GC mark-phase dereference
    }

    /** Pop back element and return it.

        This is well-missed feature of C++'s `std::vector` because of problems
        with exception handling. For more details see
        https://stackoverflow.com/questions/12600330/pop-back-return-value.
     */
    T backPop()() @trusted      // template-lazy
    in(!empty)
    {
        version(D_Coverage) {} else pragma(inline, true);
        _store.length -= 1;
        static if (needsMove!T)
            return move(_mptr[_store.length]);
        else static if (is(T == class) || isPointer!T || hasIndirections!T) // fast, medium, slow path
        {
            T e = void;
            moveEmplace(_mptr[_store.length], e); // reset any pointers at `back`
            return e;
        }
        else
            return _mptr[_store.length];
    }

    /** Pop element at `index`. */
    void popAt()(size_t index) @trusted @("complexity", "O(length)") // template-lazy
    in(index < this.length)
    {
        static if (hasElaborateDestructor!T)
            .destroy(_mptr[index]);
        else static if (mustAddGCRange!T)
            _mptr[index] = T.init; // avoid GC mark-phase dereference
        shiftToFrontAt(index);
        _store.length -= 1;
    }

    /** Move element at `index` to return. */
    T moveAt()(size_t index) @trusted @("complexity", "O(length)") // template-lazy
    in(index < this.length)
    {
        auto value = move(_mptr[index]);
        shiftToFrontAt(index);
        _store.length -= 1;
        return move(value); // TODO: remove `move` when compiler does it for us
    }

    /** Move element at front. */
    T frontPop()()              // template-lazy
        @("complexity", "O(length)")
    {
        version(D_Coverage) {} else pragma(inline, true);
        return moveAt(0);
    }

    private void shiftToFrontAt()(size_t index) @trusted // template-lazy
    {
        // TODO: use this instead:
        // immutable si = index + 1;   // source index
        // immutable ti = index;       // target index
        // immutable restLength = this.length - (index + 1);
        // import std.algorithm.mutation : moveEmplaceAll;
        // moveEmplaceAll(_mptr[si .. si + restLength],
        //                _mptr[ti .. ti + restLength]);
        foreach (immutable i; 0 .. this.length - (index + 1)) // each element index that needs to be moved
        {
            immutable si = index + i + 1; // source index
            immutable ti = index + i; // target index
            moveEmplace(_mptr[si], // TODO: remove `move` when compiler does it for us
                        _mptr[ti]);
        }
    }

    /** Forwards to $(D insertBack(values)).
     */
    void opOpAssign(string op)(T value)
    if (op == "~")
    {
        version(D_Coverage) {} else pragma(inline, true);
        insertBackMove(value);
    }
    /// ditto
    void opOpAssign(string op, U)(U[] values...) @trusted
    if (op == "~" &&
        isElementAssignable!U &&
        __traits(isCopyable, U))       // prevent accidental move of l-value `values`
    {
        version(D_Coverage) {} else pragma(inline, true);
        insertBack(values);
    }
    /// ditto
    void opOpAssign(string op, R)(R values)
    if (op == "~" &&
        isInputRange!R &&
        !isInfinite!R &&
        !isArray!R &&
        isElementAssignable!(ElementType!R))
    {
        version(D_Coverage) {} else pragma(inline, true);
        insertBack(values);
    }

    void opOpAssign(string op)(auto ref typeof(this) values)
    if (op == "~")
    {
        version(D_Coverage) {} else pragma(inline, true);
        insertBack(values[]);
    }

    // typeof(this) opBinary(string op, R)(R values)
    //     if (op == "~")
    // {
    //     // TODO: optimize
    //     typeof(this) result;
    //     result ~= this[];
    //     assert(result.length == length);
    //     result ~= values[];
    //     return result;
    // }

    /// Unsafe access to pointer.
    inout(T)* ptr()() inout return @system // template-lazy
    {
        version(D_Coverage) {} else pragma(inline, true);
        return _store.ptr;
    }

    /// Mutable pointer.
    private MutableE* _mptr() const return @trusted
    {
        version(D_Coverage) {} else pragma(inline, true);
        return cast(typeof(return))_store.ptr;
    }

private:
    /** For more convenient construction. */
    struct Store
    {
        static if (!is(typeof(Allocator) == typeof(null)) &&
                   !hasFunctionAttributes!(Allocator.allocate, "@nogc"))
        {
            T* ptr;             // GC-allocated store pointer
        }
        else
        {
            import nxt.gc_traits : NoGc;
            @NoGc T* ptr;       // non-GC-allocated store pointer
        }

        CapacityType capacity; // store capacity
        CapacityType length;   // store length
    }

    Store _store;
}

import std.traits : isInstanceOf;
import std.functional : unaryFun;

/** Remove all elements matching `predicate`.

    Returns: number of elements that were removed.

    TODO: implement version that doesn't use a temporary array `tmp`, which is
    probably faster for small arrays.
 */
size_t remove(alias predicate, C)(ref C c) @trusted
    @("complexity", "O(length)")
if (isInstanceOf!(DynamicArray, C) &&
    is(typeof(unaryFun!predicate(C.init[0]))))
{
    C tmp;
    size_t count = 0;
    foreach (immutable i; 0 .. c.length)
    {
        if (unaryFun!predicate(c[i]))
        {
            count += 1;
            import core.internal.traits : hasElaborateDestructor;
            import nxt.container_traits : mustAddGCRange;
            alias T = typeof(c[i]);
            static if (hasElaborateDestructor!(T))
                .destroy(c[i]);
            else static if (mustAddGCRange!(T))
                c[i] = T.init;    // avoid GC mark-phase dereference
        }
        else
            tmp.insertBackMove(c[i]); // TODO: remove unnecessary clearing of `_mptr[i]`
    }

    c.freeStore();

    import core.lifetime : moveEmplace;
    moveEmplace(tmp, c);

    return count;
}

/// construct and append from slices
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T, null, uint);
    static if (size_t.sizeof == 8) // only 64-bit
        static assert(A.sizeof == 2 * size_t.sizeof); // only two words

    auto a = A([10, 11, 12].s);

    a ~= a[];
    assert(a[] == [10, 11, 12,
                   10, 11, 12].s);

    a ~= false;
    assert(a[] == [10, 11, 12,
                   10, 11, 12, 0].s);
}

///
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    A a;

    a.length = 1;
    assert(a.length == 1);
    assert(a.capacity >= 1);

    a[0] = 10;

    a.insertBack(11, 12);

    a ~= T.init;
    a.insertBack([3].s);
    assert(a[] == [10, 11, 12, 0, 3].s);

    import std.algorithm.iteration : filter;

    a.insertBack([42].s[].filter!(_ => _ is 42));
    assert(a[] == [10, 11, 12, 0, 3, 42].s);

    a.insertBack([42].s[].filter!(_ => _ !is 42));
    assert(a[] == [10, 11, 12, 0, 3, 42].s);

    a ~= a[];
    assert(a[] == [10, 11, 12, 0, 3, 42,
                   10, 11, 12, 0, 3, 42].s);
}

///
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    A a;                        // default construction allowed
    assert(a.empty);
    assert(a.length == 0);
    assert(a.capacity == 0);
    assert(a[] == []);

    auto b = DynamicArray!int.withLength(3);
    assert(!b.empty);
    assert(b.length == 3);
    assert(b.capacity == 3);
    b[0] = 1;
    b[1] = 2;
    b[2] = 3;
    assert(b[] == [1, 2, 3].s);

    b[] = [4, 5, 6].s;
    assert(b[] == [4, 5, 6].s);

    const c = DynamicArray!int.withCapacity(3);
    assert(c.empty);
    assert(c.capacity == 3);
    assert(c[] == []);

    // TODO: this should fail with -dip1000
    auto f() @safe
    {
        A a;
        return a[];
    }
    auto _d = f();

    const e = DynamicArray!int([1, 2, 3, 4].s);
    assert(e.length == 4);
    assert(e[] == [1, 2, 3, 4].s);
}

///
@trusted pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    auto a = A([1, 2, 3].s);
    A b = a.dup;                // copy construction enabled

    assert(a[] == b[]);          // same content
    assert(&a[0] !is &b[0]); // but not the same

    assert(b[] == [1, 2, 3].s);
    assert(b.length == 3);

    b ~= 4;
    assert(a != b);
    a.clear();
    assert(a != b);
    b.clear();
    assert(a == b);

    auto _c = A([1, 2, 3].s);
}

/// DIP-1000 return ref escape analysis
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!T;

    T[] leakSlice() @safe pure nothrow @nogc
    {
        A a;
        return a[];             // TODO: shouldn't compile with -dip1000
    }

    T* leakPointer() @safe pure nothrow @nogc
    {
        A a;
        return a._store.ptr;    // TODO: shouldn't compile with -dip1000
    }

    auto _lp = leakPointer();    // TODO: shouldn't compile with -dip1000
    auto _ls = leakSlice();      // TODO: shouldn't compile with -dip1000
}

version(unittest)
{
    private static struct SomeUncopyable
    {
        @disable this(this);
        int _x;
    }
}

/// construct and insert from non-copyable element type passed by value
@safe pure nothrow /*@nogc*/ unittest
{
    alias A = DynamicArray!(SomeUncopyable);

    A a = A(SomeUncopyable(17));
    assert(a[] == [SomeUncopyable(17)]);

    a.insertBack(SomeUncopyable(18));
    assert(a[] == [SomeUncopyable(17),
                   SomeUncopyable(18)]);

    a ~= SomeUncopyable(19);
    assert(a[] == [SomeUncopyable(17),
                   SomeUncopyable(18),
                   SomeUncopyable(19)]);
}

/// construct from slice of uncopyable type
@safe pure nothrow @nogc unittest
{
    alias _A = DynamicArray!(SomeUncopyable);
    // TODO: can we safely support this?: A a = [SomeUncopyable(17)];
}

// construct from array with uncopyable elements
@safe pure nothrow @nogc unittest
{
    alias A = DynamicArray!(SomeUncopyable);

    A a;
    assert(a.empty);

    // TODO: a.insertBack(A.init);
    assert(a.empty);
}

// construct from ranges of uncopyable elements
@safe pure nothrow @nogc unittest
{
    alias T = SomeUncopyable;
    alias A = DynamicArray!T;

    A a;
    assert(a.empty);

    // import std.algorithm.iteration : map, filter;

    // const b = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => T(_^^2))); // hasLength
    // assert(b.length == 3);
    // assert(b == [T(100), T(400), T(900)].s);

    // const c = A.withElementsOfRange_untested([10, 20, 30].s[].filter!(_ => _ == 30).map!(_ => T(_^^2))); // !hasLength
    // assert(c.length == 1);
    // assert(c[0].x == 900);
}

// construct from ranges of copyable elements
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!T;

    A a;
    assert(a.empty);

    import std.algorithm.iteration : map, filter;

    const b = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => T(_^^2))); // hasLength
    assert(b.length == 3);
    assert(b == [T(100), T(400), T(900)].s);

    const c = A.withElementsOfRange_untested([10, 20, 30].s[].filter!(_ => _ == 30).map!(_ => T(_^^2))); // !hasLength
    assert(c == [T(900)].s);
}

/// construct with string as element type that needs GC-range
@safe pure nothrow @nogc unittest
{
    alias T = string;
    alias A = DynamicArray!(T);

    A a;
    a ~= `alpha`;
    a ~= `beta`;
    a ~= [`gamma`, `delta`].s;
    assert(a[] == [`alpha`, `beta`, `gamma`, `delta`].s);

    const b = [`epsilon`].s;

    a.insertBack(b);
    assert(a[] == [`alpha`, `beta`, `gamma`, `delta`, `epsilon`].s);

    a ~= b;
    assert(a[] == [`alpha`, `beta`, `gamma`, `delta`, `epsilon`, `epsilon`].s);
}

/// convert to string
version(none)                   // TODO: make this work
unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    DynamicArray!char sink;
    A([1, 2, 3]).toString(sink.put);
}

/// iteration over mutable elements
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    auto a = A([1, 2, 3].s);

    foreach (immutable i, const e; a)
    {
        assert(i + 1 == e);
    }
}

/// iteration over `const`ant elements
@safe pure nothrow @nogc unittest
{
    alias T = const(int);
    alias A = DynamicArray!(T);

    auto a = A([1, 2, 3].s);

    foreach (immutable i, const e; a)
    {
        assert(i + 1 == e);
    }
}

/// iteration over immutable elements
@safe pure nothrow @nogc unittest
{
    alias T = immutable(int);
    alias A = DynamicArray!(T);

    auto a = A([1, 2, 3].s);

    foreach (immutable i, const e; a)
    {
        assert(i + 1 == e);
    }
}

/// removal
@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    auto a = A([1, 2, 3].s);
    assert(a == [1, 2, 3].s);

    assert(a.frontPop() == 1);
    assert(a == [2, 3].s);

    a.popAt(1);
    assert(a == [2].s);

    a.popAt(0);
    assert(a == []);

    a.insertBack(11);
    assert(a == [11].s);

    assert(a.backPop == 11);

    a.insertBack(17);
    assert(a == [17].s);
    a.popBack();
    assert(a.empty);

    a.insertBack([11, 12, 13, 14, 15].s[]);
    a.popAt(2);
    assert(a == [11, 12, 14, 15].s);
    a.popAt(0);
    assert(a == [12, 14, 15].s);
    a.popAt(2);

    assert(a == [12, 14].s);

    a ~= a;
}

/// removal
@safe pure nothrow unittest
{
    import nxt.container_traits : mustAddGCRange;

    size_t mallocCount = 0;
    size_t freeCount = 0;

    struct S
    {
        @safe pure nothrow @nogc:

        alias E = int;

        import nxt.qcmeman : malloc, free;

        this(E x) @trusted
        {
            _ptr = cast(E*)malloc(E.sizeof);
            mallocCount += 1;
            *_ptr = x;
        }

        @disable this(this);

        ~this() @trusted @nogc
        {
            free(_ptr);
            freeCount += 1;
        }

        import nxt.gc_traits : NoGc;
        @NoGc E* _ptr;
    }

    /* D compilers cannot currently move stuff efficiently when using
       std.algorithm.mutation.move. A final dtor call to the cleared sourced is
       always done.
    */
    size_t extraDtor = 1;

    alias A = DynamicArray!(S);
    static assert(!mustAddGCRange!A);
    alias AA = DynamicArray!(A);
    static assert(!mustAddGCRange!AA);

    assert(mallocCount == 0);

    {
        A a;
        a.insertBack(S(11));
        assert(mallocCount == 1);
        assert(freeCount == extraDtor + 0);
    }

    assert(freeCount == extraDtor + 1);

    // assert(a.front !is S(11));
    // assert(a.back !is S(11));
    // a.insertBack(S(12));
}

/// test `OutputRange` behaviour with std.format
version(none)                   // TODO: replace with other exercise of std.format
@safe pure /*TODO: nothrow @nogc*/ unittest
{
    import std.format : formattedWrite;
    const x = "42";
    alias A = DynamicArray!(char);
    A a;
    a.formattedWrite!("x : %s")(x);
    assert(a == "x : 42");
}

/// test emplaceWithMovedElements
@trusted pure nothrow @nogc unittest
{
    alias A = DynamicArray!(char);

    auto ae = ['a', 'b'].s;

    A a = void;
    A.emplaceWithMovedElements(&a, ae[]);

    assert(a.length == ae.length);
    assert(a.capacity == ae.length);
    assert(a[] == ae);
}

/// test emplaceWithCopiedElements
@trusted pure nothrow @nogc unittest
{
    alias A = DynamicArray!(char);

    auto ae = ['a', 'b'].s;

    A a = void;
    A.emplaceWithCopiedElements(&a, ae[]);

    assert(a.length == ae.length);
    assert(a.capacity == ae.length);
    assert(a[] == ae);
}

@safe pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T, null, uint);
    const a = A(17);
    assert(a[] == [17].s);
}

/// check duplication via `dup`
@trusted pure nothrow @nogc unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    static assert(!__traits(compiles, { A b = a; })); // copying disabled

    auto a = A([10, 11, 12].s);
    auto b = a.dup;
    assert(a == b);
    assert(&a[0] !is &b[0]);
}

/// element type is a class
@safe pure nothrow unittest
{
    class T
    {
        this (int x)
        {
            this.x = x;
        }
        ~this() @nogc { x = 42; }
        int x;
    }
    alias A = DynamicArray!(T);
    auto a = A([new T(10),
                new T(11),
                new T(12)].s);
    assert(a.length == 3);
    a.remove!(_ => _.x == 12);
    assert(a.length == 2);
}

/// check filtered removal via `remove`
@safe pure nothrow @nogc unittest
{
    struct T
    {
        int value;
    }

    alias A = DynamicArray!(T);

    static assert(!__traits(compiles, { A b = a; })); // copying disabled

    auto a = A([T(10), T(11), T(12)].s);

    assert(a.remove!"a.value == 13" == 0);
    assert(a[] == [T(10), T(11), T(12)].s);

    assert(a.remove!"a.value >= 12" == 1);
    assert(a[] == [T(10), T(11)].s);

    assert(a.remove!(_ => _.value == 10) == 1);
    assert(a[] == [T(11)].s);

    assert(a.remove!(_ => _.value == 11) == 1);
    assert(a.empty);
}

/// construct from map range
@safe pure nothrow unittest
{
    import std.algorithm.iteration : map;
    alias T = int;
    alias A = DynamicArray!(T);

    A a = A.withElementsOfRange_untested([10, 20, 30].s[].map!(_ => _^^2));
    assert(a[] == [100, 400, 900].s);
    a.popBackN(2);
    assert(a.length == 1);
    a.popBackN(1);
    assert(a.empty);

    A b = A([10, 20, 30].s[].map!(_ => _^^2));
    assert(b[] == [100, 400, 900].s);
    b.popBackN(2);
    assert(b.length == 1);
    b.popBackN(1);
    assert(b.empty);

    A c = A([10, 20, 30].s[]);
    assert(c[] == [10, 20, 30].s);
}

/// construct from map range
@trusted pure nothrow unittest
{
    alias T = int;
    alias A = DynamicArray!(T);

    import std.typecons : RefCounted;
    RefCounted!A x;

    auto z = [1, 2, 3].s;
    x ~= z[];

    auto y = x;
    assert(y[] == z);

    auto _ = x.toHash;
}

/// construct from static array
@trusted pure nothrow @nogc unittest
{
    alias T = uint;
    alias A = DynamicArray!(T);

    ushort[3] a = [1, 2, 3];

    auto x = A(a);
    assert(x == a);
    assert(x == a[]);
}

/// construct from static array slice
@trusted pure nothrow @nogc unittest
{
    alias T = uint;
    alias A = DynamicArray!(T);

    ushort[3] a = [1, 2, 3];
    ushort[] b = a[];

    auto y = A(b);          // cannot construct directly from `a[]` because its type is `ushort[3]`
    assert(y == a);
    assert(y == a[]);
}

/// GCAllocator
@trusted pure nothrow unittest
{
    import std.experimental.allocator.gc_allocator : GCAllocator;
    alias T = int;
    alias A = DynamicArray!(T, GCAllocator.instance);
    A a;
    assert(a.length == 0);
}

/// construct with slices as element types
@trusted pure nothrow unittest
{
    alias A = DynamicArray!(string);
    A a;
    assert(a.length == 0);
    alias B = DynamicArray!(char[]);
    B b;
    assert(b.length == 0);
}

/** Variant of `DynamicArray` with copy construction (postblit) enabled.
 *
 * See_Also: suppressing.d
 * See_Also: http://forum.dlang.org/post/eitlbtfbavdphbvplnrk@forum.dlang.org
 */
struct BasicCopyableArray
{
    /** TODO: implement using instructions at:
     * http://forum.dlang.org/post/eitlbtfbavdphbvplnrk@forum.dlang.org
     */
}

/// TODO: Move to Phobos.
private enum bool isRefIterable(T) = is(typeof({ foreach (ref elem; T.init) {} }));

version(unittest)
{
    import nxt.array_help : s;
}
