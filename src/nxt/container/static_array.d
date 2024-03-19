/** Statically allocated arrays with compile-time known lengths.
 */
module nxt.container.static_array;

@safe pure:

/** Statically allocated `T`-array of fixed pre-allocated length.
 *
 * Similar to C++'s `std::static_vector<T, Capacity>`
 * Similar to Rust's `fixedvec`: https://docs.rs/fixedvec/0.2.4/fixedvec/
 * Similar to `mir.small_array` at http://mir-algorithm.libmir.org/mir_small_array.html
 *
 * See_Also: https://en.cppreference.com/w/cpp/container/array
 *
 * TODO: Merge member functions with basic_*_array.d and array_ex.d
 */
struct StaticArray(T, uint capacity_, bool borrowChecked = false) {
	import core.exception : onRangeError;
	import core.lifetime : move, moveEmplace;
	import core.internal.traits : hasElaborateDestructor;
	import std.bitmanip : bitfields;
	import std.traits : isSomeChar, isAssignable, hasIndirections;
	import nxt.container.traits : mustAddGCRange;

	alias capacity = capacity_; // for public use

	/// Store of `capacity` number of elements.
	T[capacity] _store;		 /+ TODO: use store constructor +/

	static if (borrowChecked) {
		/// Number of bits needed to store number of read borrows.
		private enum readBorrowCountBits = 3;

		/// Maximum value possible for `_readBorrowCount`.
		enum readBorrowCountMax = 2^^readBorrowCountBits - 1;

		static	  if (capacity <= 2^^(8*ubyte.sizeof - 1 - readBorrowCountBits) - 1) {
			private enum lengthMax = 2^^4 - 1;
			alias Length = ubyte;
			/+ TODO: make private: +/
			mixin(bitfields!(Length, "_length", 4, /// number of defined elements in `_store`
							 bool, "_writeBorrowed", 1,
							 uint, "_readBorrowCount", readBorrowCountBits,
					  ));
		}
		else static if (capacity <= 2^^(8*ushort.sizeof - 1 - readBorrowCountBits) - 1) {
			alias Length = ushort;
			private enum lengthMax = 2^^14 - 1;
			/+ TODO: make private: +/
			mixin(bitfields!(Length, "_length", 14, /// number of defined elements in `_store`
							 bool, "_writeBorrowed", 1,
							 uint, "_readBorrowCount", readBorrowCountBits,
					  ));
		}
		else
		{
			static assert("Too large requested capacity " ~ capacity);
		}
	}
	else
	{
		static if (capacity <= ubyte.max) {
			static if (T.sizeof == 1)
				alias Length = ubyte; // pack length
			else
				alias Length = uint;
		}
		else static if (capacity <= ushort.max) {
			static if (T.sizeof <= 2)
				alias Length = uint; // pack length
			else
				alias Length = uint;
		}
		else
		{
			static assert("Too large requested capacity " ~ capacity);
		}
		Length _length;		 /// number of defined elements in `_store`
	}

	/// Is `true` if `U` can be assigned to the elements of `this`.
	private enum isElementAssignable(U) = isAssignable!(T, U);

	/// Empty.
	void clear() @nogc
	{
		releaseElementsStore();
		resetInternalData();
	}

	/// Release elements and internal store.
	private void releaseElementsStore() @trusted @nogc
	{
		static if (borrowChecked) { assert(!isBorrowed); }
		foreach (immutable i; 0 .. length)
			static if (hasElaborateDestructor!T)
				.destroy(_store.ptr[i]);
			else static if (hasIndirections!T)
				_store.ptr[i] = T.init; // nullify any pointers
	}

	/// Reset internal data.
	private void resetInternalData() @nogc
	{
		version (D_Coverage) {} else pragma(inline, true);
		_length = 0;
	}

	/// Construct from element `values`.
	this(Us...)(Us values) @trusted
	if (Us.length <= capacity) {
		static foreach (const i, value; values)
			static if (__traits(isPOD, typeof(value)))
				_store[i] = value;
			else
				moveEmplace(value, _store[i]);
		_length = cast(Length)values.length;
		static if (borrowChecked) {
			_writeBorrowed = false;
			_readBorrowCount = 0;
		}
	}

	/// Construct from element `values`.
	this(U)(U[] values) @trusted
	if (__traits(isCopyable, U)//  &&
		/+ TODO: isElementAssignable!U +/
		) // prevent accidental move of l-value `values` in array calls
	{
		version (assert) if (values.length > capacity) onRangeError(); // `Arguments don't fit in array`
		_store[0 .. values.length] = values;
		_length = cast(Length)values.length;
		static if (borrowChecked) {
			_writeBorrowed = false;
			_readBorrowCount = 0;
		}
	}

	/// Construct from element `values`.
	static typeof(this) fromValuesUnsafe(U)(U[] values) @system
	if (__traits(isCopyable, U) &&
		isElementAssignable!U
		) // prevent accidental move of l-value `values` in array calls
	{
		typeof(return) that;			  /+ TODO: use Store constructor: +/

		that._store[0 .. values.length] = values;
		that._length = cast(Length)values.length;

		static if (borrowChecked) {
			that._writeBorrowed = false;
			that._readBorrowCount = 0;
		}

		return that;
	}

	static if (borrowChecked ||
			   hasElaborateDestructor!T) {
		/** Destruct. */
		~this() nothrow @nogc
		{
			releaseElementsStore();
		}
	}

	/** Add elements `es` to the back.
	 * Throws when array becomes full.
	 * NOTE: doesn't invalidate any borrow
	 */
	void insertBack(Es...)(Es es) @trusted
	if (Es.length <= capacity) /+ TODO: use `isAssignable` +/
	{
		version (assert) if (_length + Es.length > capacity) onRangeError(); // `Arguments don't fit in array`
		static foreach (const i, e; es) {
			static if (__traits(isPOD, T))
				_store[_length + i] = e;
			else
				moveEmplace(e, _store[_length + i]); /+ TODO: remove when compiler does this +/
		}
		_length = cast(Length)(_length + Es.length); /+ TODO: better? +/
	}
	/// ditto
	alias put = insertBack;	   // `OutputRange` support

	/** Try to add elements `es` to the back.
	 * NOTE: doesn't invalidate any borrow
	 * Returns: `true` iff all `es` were pushed, `false` otherwise.
	 */
	bool insertBackMaybe(Es...)(Es es) @trusted
	if (Es.length <= capacity) /+ TODO: use `isAssignable` +/
	{
		version (LDC) pragma(inline, true);
		if (_length + Es.length > capacity) { return false; }
		insertBack(es);
		return true;
	}
	/// ditto
	alias putMaybe = insertBackMaybe;

	/** Add elements `es` to the back.
	 * NOTE: doesn't invalidate any borrow
	 */
	void opOpAssign(string op, Us...)(Us values)
	if (op == "~" &&
		values.length >= 1 &&
		allSatisfy!(isElementAssignable, Us)) {
		insertBack(values.move()); /+ TODO: remove `move` when compiler does it for +/
	}

	import std.traits : isMutable;
	static if (isMutable!T) {
		/** Pop first (front) element. */
		auto ref popFront() in(!empty) {
			static if (borrowChecked) { assert(!isBorrowed); }
			/+ TODO: is there a reusable Phobos function for this? +/
			foreach (immutable i; 0 .. _length - 1)
				move(_store[i + 1], _store[i]); // like `_store[i] = _store[i + 1];` but more generic
			_length = cast(typeof(_length))(_length - 1); /+ TODO: better? +/
			return this;
		}
	}

	/** Pop last (back) element. */
	pragma(inline, true)
	void popBack()() @trusted in(!empty) /*tlm*/
	{
		static if (borrowChecked) { assert(!isBorrowed); }
		_length = cast(Length)(_length - 1); /+ TODO: better? +/
		static if (hasElaborateDestructor!T)
			.destroy(_store.ptr[_length]);
		else static if (mustAddGCRange!T)
			_store.ptr[_length] = T.init; // avoid GC mark-phase dereference
	}

	pragma(inline, true)
	T takeBack()() @trusted in(!empty) /*tlm*/
	{
		static if (__traits(isPOD, T))
			return _store.ptr[--_length]; // no move needed
		else
			return move(_store.ptr[--_length]); // move is indeed need here
	}

	/** Pop the `n` last (back) elements. */
	void popBackN()(size_t n) @trusted in(length >= n) /*tlm*/
	{
		static if (borrowChecked) { assert(!isBorrowed); }
		_length = cast(Length)(_length - n); /+ TODO: better? +/
		static if (hasElaborateDestructor!T)
			foreach (const i; 0 .. n)
				.destroy(_store.ptr[_length + i]);
		else static if (mustAddGCRange!T) // avoid GC mark-phase dereference
			foreach (const i; 0 .. n)
				_store.ptr[_length + i] = T.init;
	}

	/** Move element at `index` to return. */
	static if (isMutable!T) {
		/** Pop element at `index`. */
		void popAt()(size_t index) /*tlm*/
		@trusted
		@("complexity", "O(length)")
		in(index < this.length) {
			.destroy(_store.ptr[index]);
			shiftToFrontAt(index);
			_length = cast(Length)(_length - 1);
		}

		T moveAt()(size_t index) /*tlm*/
		@trusted
		@("complexity", "O(length)")
		in(index < this.length) {
			auto value = _store.ptr[index].move();
			shiftToFrontAt(index);
			_length = cast(Length)(_length - 1);
			return value;
		}

		private void shiftToFrontAt()(size_t index) /*tlm*/
			@trusted
		{
			foreach (immutable i; 0 .. this.length - (index + 1)) {
				immutable si = index + i + 1; // source index
				immutable ti = index + i;	 // target index
				moveEmplace(_store.ptr[si],
							_store.ptr[ti]);
			}
		}
	}

	/** Index operator. */
	pragma(inline, true)
	ref inout(T) opIndex(size_t i) inout return => _store[i];

	/** First (front) element. */
	pragma(inline, true)
	ref inout(T) front() inout return => _store[0];

	/** Last (back) element. */
	pragma(inline, true)
	ref inout(T) back() inout return => _store[_length - 1];

	static if (borrowChecked) {
		import nxt.borrowed : ReadBorrowed;
		import core.internal.traits : Unqual;

		/// Get full read-only slice.
		ReadBorrowed!(T[], typeof(this)) sliceRO() const @trusted return scope
		in(!_writeBorrowed, "Already write-borrowed")
			=> typeof(return)(_store[0 .. _length],
							  cast(Unqual!(typeof(this))*)(&this)); // trusted unconst cast

		/// Get read-only slice in range `i` .. `j`.
		ReadBorrowed!(T[], typeof(this)) sliceRO(size_t i, size_t j) const @trusted return scope
		in(!_writeBorrowed, "Already write-borrowed")
			=> typeof(return)(_store[i .. j],
							  cast(Unqual!(typeof(this))*)(&this)); // trusted unconst cast

		import nxt.borrowed : WriteBorrowed;

		/// Get full read-write slice.
		WriteBorrowed!(T[], typeof(this)) sliceRW() @trusted return scope /+ TODO: remove @trusted? +/
		in(!_writeBorrowed, "Already write-borrowed")
		in(_readBorrowCount == 0, "Already read-borrowed")
			=> typeof(return)(_store[0 .. _length], &this);

		/// Get read-write slice in range `i` .. `j`.
		WriteBorrowed!(T[], typeof(this)) sliceRW(size_t i, size_t j) @trusted return scope /+ TODO: remove @trusted? +/
		in(!_writeBorrowed, "Already write-borrowed")
		in(_readBorrowCount == 0, "Already read-borrowed")
			=> typeof(return)(_store[0 .. j], &this);

		@property pragma(inline, true) {
			/// Get read-only slice in range `i` .. `j`.
			auto opSlice(size_t i, size_t j) const return scope => sliceRO(i, j);
			/// Get read-write slice in range `i` .. `j`.
			auto opSlice(size_t i, size_t j) return scope  => sliceRW(i, j);

			/// Get read-only full slice.
			auto opSlice() const return scope => sliceRO();
			/// Get read-write full slice.
			auto opSlice() return scope => sliceRW();

			/// Returns: `true` iff `this` is either write or read borrowed.
			bool isBorrowed() const => _writeBorrowed || _readBorrowCount >= 1;

			/// Returns: `true` iff `this` is write borrowed.
			bool isWriteBorrowed() const => _writeBorrowed;

			/// Returns: number of read-only borrowers of `this`.
			uint readBorrowCount() const => _readBorrowCount;
		}
	}
	else
	{
		/// Get slice in range `i` .. `j`.
		pragma(inline, true);
		inout(T)[] opSlice(size_t i, size_t j) inout @trusted return /+ TODO: remove @trusted? +/
		// in(i <= j)
		// in(j <= _length)
			=> _store[i .. j];

		/// Get full slice.
		pragma(inline, true)
		inout(T)[] opSlice() inout @trusted return /+ TODO: remove @trusted? +/
			=> _store[0 .. _length];
	}

	@property pragma(inline, true) {
		/** Returns: `true` iff `this` is empty, `false` otherwise. */
		bool empty() const @property { return _length == 0; }

		/** Returns: `true` iff `this` is full, `false` otherwise. */
		bool full() const { return _length == capacity; }

		/** Get length. */
		auto length() const { return _length; }
		alias opDollar = length;	/// ditto

		static if (isSomeChar!T) {
			/** Get as `string`. */
			scope const(T)[] toString() const return
			{
				version (DigitalMars) pragma(inline, false);
				return opSlice();
			}
		}
	}

	/** Comparison for equality. */
	bool opEquals()(const scope auto ref typeof(this) rhs) const
		=> this[] == rhs[];
	/// ditto
	bool opEquals(U)(const scope U[] rhs) const
	if (is(typeof(T[].init == U[].init)))
		=> this[] == rhs;
}

/** Stack-allocated string of maximum length of `capacity.`
 *
 * Similar to `mir.small_string` at http://mir-algorithm.libmir.org/mir_small_string.html.
 */
alias StringN(uint capacity, bool borrowChecked = false) = StaticArray!(immutable(char), capacity, borrowChecked);

/** Stack-allocated wstring of maximum length of `capacity.` */
alias WStringN(uint capacity, bool borrowChecked = false) = StaticArray!(immutable(wchar), capacity, borrowChecked);

/** Stack-allocated dstring of maximum length of `capacity.` */
alias DStringN(uint capacity, bool borrowChecked = false) = StaticArray!(immutable(dchar), capacity, borrowChecked);

/** Stack-allocated mutable string of maximum length of `capacity.` */
alias MutableStringN(uint capacity, bool borrowChecked = false) = StaticArray!(char, capacity, borrowChecked);

/** Stack-allocated mutable wstring of maximum length of `capacity.` */
alias MutableWStringN(uint capacity, bool borrowChecked = false) = StaticArray!(char, capacity, borrowChecked);

/** Stack-allocated mutable dstring of maximum length of `capacity.` */
alias MutableDStringN(uint capacity, bool borrowChecked = false) = StaticArray!(char, capacity, borrowChecked);

/// construct from array may throw
pure @safe unittest {
	enum capacity = 3;
	alias T = int;
	alias A = StaticArray!(T, capacity);
	static assert(!mustAddGCRange!A);

	auto a = A([1, 2, 3].s[]);
	assert(a[] == [1, 2, 3].s);
}

/// unsafe construct from array
@trusted pure nothrow @nogc unittest {
	enum capacity = 3;
	alias T = int;
	alias A = StaticArray!(T, capacity);
	static assert(!mustAddGCRange!A);

	auto a = A.fromValuesUnsafe([1, 2, 3].s);
	assert(a[] == [1, 2, 3].s);
}

/// construct from scalars is nothrow
pure nothrow @safe @nogc unittest {
	enum capacity = 3;
	alias T = int;
	alias A = StaticArray!(T, capacity);
	static assert(!mustAddGCRange!A);

	auto a = A(1, 2, 3);
	assert(a[] == [1, 2, 3].s);

	static assert(!__traits(compiles, { auto _ = A(1, 2, 3, 4); }));
}

/// scope checked string
pure @safe unittest {
	enum capacity = 15;
	foreach (StrN; AliasSeq!(StringN// , WStringN, DStringN
				 )) {
		alias String15 = StrN!(capacity);

		typeof(String15.init[0])[] xs;
		assert(xs.length == 0);
		auto x = String15("alphas");

		assert(x[0] == 'a');
		assert(x[$ - 1] == 's');

		assert(x[0 .. 2] == "al");
		assert(x[] == "alphas");

		const y = String15("åäö_åäöå"); // fits in 15 chars
		assert(y.length == capacity);
	}
}

/// scope checked string
pure unittest {
	enum capacity = 15;
	foreach (Str; AliasSeq!(StringN!capacity,
							WStringN!capacity,
							DStringN!capacity)) {
		static assert(!mustAddGCRange!Str);
		static if (hasPreviewDIP1000) {
			static assert(!__traits(compiles, {
						auto f() @safe pure
						{
							auto x = Str("alphas");
							auto y = x[];
							return y;   // errors with -dip1000
						}
					}));
		}
	}
}

pure @safe unittest {
	static assert(mustAddGCRange!(StaticArray!(string, 1, false)));
	static assert(mustAddGCRange!(StaticArray!(string, 1, true)));
	static assert(mustAddGCRange!(StaticArray!(string, 2, false)));
	static assert(mustAddGCRange!(StaticArray!(string, 2, true)));
}

///
pure @safe unittest {
	import std.exception : assertNotThrown;

	alias T = char;
	enum capacity = 3;

	alias A = StaticArray!(T, capacity, true);
	static assert(!mustAddGCRange!A);
	static assert(A.sizeof == T.sizeof*capacity + 1);

	import std.range.primitives : isOutputRange;
	static assert(isOutputRange!(A, T));

	auto ab = A("ab");
	assert(!ab.empty);
	assert(ab[0] == 'a');
	assert(ab.front == 'a');
	assert(ab.back == 'b');
	assert(ab.length == 2);
	assert(ab[] == "ab");
	assert(ab[0 .. 1] == "a");
	assertNotThrown(ab.insertBack('_'));
	assert(ab[] == "ab_");
	ab.popBack();
	assert(ab[] == "ab");
	assert(ab.toString == "ab");

	ab.popBackN(2);
	assert(ab.empty);
	assertNotThrown(ab.insertBack('a', 'b'));

	const abc = A("abc");
	assert(!abc.empty);
	assert(abc.front == 'a');
	assert(abc.back == 'c');
	assert(abc.length == 3);
	assert(abc[] == "abc");
	assert(ab[0 .. 2] == "ab");
	assert(abc.full);
	static assert(!__traits(compiles, { const abcd = A('a', 'b', 'c', 'd'); })); // too many elements

	assert(ab[] == "ab");
	ab.popFront();
	assert(ab[] == "b");

	const xy = A("xy");
	assert(!xy.empty);
	assert(xy[0] == 'x');
	assert(xy.front == 'x');
	assert(xy.back == 'y');
	assert(xy.length == 2);
	assert(xy[] == "xy");
	assert(xy[0 .. 1] == "x");

	const xyz = A("xyz");
	assert(!xyz.empty);
	assert(xyz.front == 'x');
	assert(xyz.back == 'z');
	assert(xyz.length == 3);
	assert(xyz[] == "xyz");
	assert(xyz.full);
	static assert(!__traits(compiles, { const xyzw = A('x', 'y', 'z', 'w'); })); // too many elements
}

///
pure @safe unittest {
	static void testAsSomeString(T)() {
		enum capacity = 15;
		alias A = StaticArray!(immutable(T), capacity);
		static assert(!mustAddGCRange!A);
		auto a = A("abc");
		assert(a[] == "abc");

		import std.conv : to;
		const x = "a".to!(T[]);
	}

	foreach (T; AliasSeq!(char// , wchar, dchar
				 )) {
		testAsSomeString!T();
	}
}

/// equality
pure @safe unittest {
	enum capacity = 15;
	alias S = StaticArray!(int, capacity);
	static assert(!mustAddGCRange!S);

	assert(S([1, 2, 3].s[]) ==
		   S([1, 2, 3].s[]));
	assert(S([1, 2, 3].s[]) ==
		   [1, 2, 3]);
}

pure @safe unittest {
	class C { int value; }
	alias S = StaticArray!(C, 2);
	static assert(mustAddGCRange!S);
}

/// `insertBackMaybe` is nothrow @nogc.
pure nothrow @safe @nogc unittest {
	alias S = StaticArray!(int, 2);
	S s;
	assert(s.insertBackMaybe(42));
	assert(s.insertBackMaybe(43));
	assert(!s.insertBackMaybe(0));
	assert(s.length == 2);
}

/// equality
@system pure nothrow @nogc unittest {
	enum capacity = 15;
	alias S = StaticArray!(int, capacity);

	assert(S.fromValuesUnsafe([1, 2, 3].s) ==
		   S.fromValuesUnsafe([1, 2, 3].s));

	const ax = [1, 2, 3].s;
	assert(S.fromValuesUnsafe([1, 2, 3].s) == ax);
	assert(S.fromValuesUnsafe([1, 2, 3].s) == ax[]);

	const cx = [1, 2, 3].s;
	assert(S.fromValuesUnsafe([1, 2, 3].s) == cx);
	assert(S.fromValuesUnsafe([1, 2, 3].s) == cx[]);

	immutable ix = [1, 2, 3].s;
	assert(S.fromValuesUnsafe([1, 2, 3].s) == ix);
	assert(S.fromValuesUnsafe([1, 2, 3].s) == ix[]);
}

/// assignment from `const` to `immutable` element type
pure @safe unittest {
	enum capacity = 15;
	alias String15 = StringN!(capacity);
	static assert(!mustAddGCRange!String15);

	enum n = 4;
	const char[n] _ = ['a', 'b', 'c', 'd'];
	auto x = String15(_[]);
	assert(x.length == 4);
	assert(x[] == _);

	foreach_reverse (const i; 0 .. n)
		assert(x.takeBack() == _[i]);
	assert(x.empty);
}

/// borrow checking
@system pure unittest {
	enum capacity = 15;
	alias String15 = StringN!(capacity, true);
	static assert(String15.readBorrowCountMax == 7);
	static assert(!mustAddGCRange!String15);

	auto x = String15("alpha");

	assert(x[] == "alpha");

	{
		auto xw1 = x[];
		assert(x.isWriteBorrowed);
		assert(x.isBorrowed);
	}

	auto xr1 = (cast(const)x)[];
	assert(x.readBorrowCount == 1);

	auto xr2 = (cast(const)x)[];
	assert(x.readBorrowCount == 2);

	auto xr3 = (cast(const)x)[];
	assert(x.readBorrowCount == 3);

	auto xr4 = (cast(const)x)[];
	assert(x.readBorrowCount == 4);

	auto xr5 = (cast(const)x)[];
	assert(x.readBorrowCount == 5);

	auto xr6 = (cast(const)x)[];
	assert(x.readBorrowCount == 6);

	auto xr7 = (cast(const)x)[];
	assert(x.readBorrowCount == 7);

	assertThrown!AssertError((cast(const)x)[]);
}

version (unittest) {
	import std.meta : AliasSeq;
	import std.exception : assertThrown;
	import core.exception : AssertError;

	import nxt.array_help : s;
	import nxt.container.traits : mustAddGCRange;
	import nxt.dip_traits : hasPreviewDIP1000;
}
