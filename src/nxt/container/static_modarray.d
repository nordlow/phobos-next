module nxt.container.static_modarray;

version = useModulo;

/** Statically allocated `Mod`-array of fixed pre-allocated length `capacity` of
 * `Mod`-elements in chunks of `elementLength`. `ElementType` is
 * `Mod[elementLength]`.
 */
struct StaticModArray(uint capacity,
					  uint elementLength,
					  uint span,
					  bool useModuloFlag)
if (capacity*elementLength >= 2) // no use storing less than 2 bytes
{
	private enum radix = 2^^span;

	/// Index modulo `radix` type.
	static if (useModuloFlag) {
		import nxt.modulo : Mod;
		alias Ix = Mod!(radix, ubyte);
	}
	else
		alias Ix = ubyte;

	enum L = elementLength;

	/// ElementType type `T`.
	static if (L == 1)
		alias T = Ix;
	else
		alias T = Ix[L];

	/** Construct with `rhsCapacity`. */
	this(uint rhsCapacity)(in StaticModArray!(rhsCapacity,
											  elementLength,
											  span, useModuloFlag) rhs) {
		static if (capacity < rhsCapacity)
			assert(rhs.length <= capacity);
		foreach (immutable i, const ix; rhs)
			_store[i] = ix;
		_length = rhs.length;
	}

	/** Construct with elements `es`. */
	this(Es...)(Es es)
	if (Es.length >= 1 &&
		Es.length <= capacity) {
		foreach (immutable i, ix; es)
			_store[i] = ix;
		_length = es.length;
	}

	static if (L == 1) {
		/** Construct with elements in `es`. */
		this(const Ix[] es)
		in(es.length <= capacity) {
			_store[0 .. es.length] = es;
			_length = cast(typeof(_length))es.length;
		}
	}

	/** Default key separator in printing. */
	enum keySeparator = ',';

	@property auto toString()(char separator = keySeparator) const /*tlm*/
	{
		string s;
		foreach (immutable i, const ix; chunks) {
			if (i != 0) { s ~= separator; }
			import std.string : format;
			static if (elementLength == 1)
				s ~= format("%.2X", ix); // in hexadecimal
			else
			{
				foreach (const j, const subIx; ix[]) {
					if (j != 0) { s ~= '_'; } // separator
					s ~= format("%.2X", subIx); // in hexadecimal
				}
			}
		}
		return s;
	}

	pure nothrow @safe @nogc:

	/** Returns: `true` if `this` is empty, `false` otherwise. */
	pragma(inline, true)
	bool empty() const @property => _length == 0;

	/** Get first element. */
	pragma(inline, true)
	auto front() inout in(!empty) => _store[0];

	/** Get last element. */
	pragma(inline, true)
	auto back() inout in(!empty) => _store[_length - 1];

	/** Returns: `true` if `this` is full, `false` otherwise. */
	pragma(inline, true)
	bool full() const => _length == capacity;

	/** Pop first (front) element. */
	auto ref popFront() in(!empty) {
		/+ TODO: is there a reusable Phobos function for this? +/
		foreach (immutable i; 0 .. _length - 1)
			_store[i] = _store[i + 1]; // like `_store[i] = _store[i + 1];` but more generic
		_length = cast(typeof(_length))(_length - 1);
		return this;
	}

	/** Pop `n` front elements. */
	auto ref popFrontN(size_t n) in(length >= n) {
		/+ TODO: is there a reusable Phobos function for this? +/
		foreach (immutable i; 0 .. _length - n)
			_store[i] = _store[i + n];
		_length = cast(typeof(_length))(_length - n);
		return this;
	}

	/** Pop last (back) element. */
	auto ref popBack() in(!empty) {
		version (LDC) pragma(inline, true);
		_length = cast(typeof(_length))(_length - 1); /+ TODO: better? +/
		return this;
	}

	/** Push/Add elements `es` at back.
		NOTE Doesn't invalidate any borrow.
	*/
	auto ref pushBack(Es...)(Es es)
	if (Es.length <= capacity)
	in(length + Es.length <= capacity) {
		foreach (immutable i, const e; es)
			_store[_length + i] = e;
		_length = cast(typeof(_length))(_length + Es.length);
		return this;
	}

	/** Returns: `true` if `key` is contained in `this`. */
	bool contains(in Ix[] key) const @nogc
	{
		import std.algorithm.searching : canFind;
		if (key.length != L) { return false; }
		return chunks.canFind(key);	/+ TODO: use binarySearch instead +/
	}

	static if (L == 1) {
		import std.traits : isUnsigned;

		/** Returns: `true` if `ix` is contained in `this`. */
		static if (useModuloFlag) {
			pragma(inline, true)
			bool contains(ModUInt)(in Mod!(radix, ModUInt) ix) const @nogc
			if (isUnsigned!ModUInt) {
				import std.algorithm.searching : canFind;
				return chunks.canFind(ix); /+ TODO: use binarySearch +/
			}
		}
		else
		{
			pragma(inline, true)
			bool contains(UInt)(in UInt ix) const @nogc
			if (isUnsigned!UInt) {
				import std.algorithm.searching : canFind;
				return chunks.canFind(cast(T)ix); /+ TODO: use binarySearch +/
			}
		}
	}

	/** Returns: elements as a slice. */
	pragma(inline, true)
	auto chunks() inout => _store[0 .. _length];
	alias chunks this;

	/** Variant of `opIndex` with compile-time range checking. */
	auto ref at(uint ix)() inout @trusted if (ix < capacity) in(ix < _length) {
		version (D_Coverage) {} else version (LDC) pragma(inline, true);
		return _store.ptr[ix]; // uses `.ptr` because `ix` known at compile-time to be within bounds; `ix < capacity`
	}


	/** Get length. */
	pragma(inline, true)
	auto length() const => _length;

	enum typeBits = 4; // number of bits in enclosing type used for representing type

private:
	static if (L == 1)
		T[capacity] _store = void; // byte indexes
	else
		T[capacity] _store = void; // byte indexes
	static if (_store.sizeof == 6)
		ubyte _padding;
	import nxt.dip_traits : hasPreviewBitfields;
	static if (hasPreviewBitfields)
	{
		mixin("ubyte _length : 8-typeBits;"); // maximum length of 15
		mixin("ubyte _mustBeIgnored : typeBits;");
	}
	else
	{
		import std.bitmanip : bitfields;
		mixin(bitfields!(size_t, "_length", 4, // maximum length of 15
						 ubyte, "_mustBeIgnored", typeBits)); // must be here and ignored because it contains `WordVariant` type of `Node`
	}
}

version (unittest) {
	static assert(StaticModArray!(3, 1, 8, false).sizeof == 4);
	static assert(StaticModArray!(7, 1, 8, false).sizeof == 8);
	static assert(StaticModArray!(3, 2, 8, false).sizeof == 8);
	static assert(StaticModArray!(2, 3, 8, false).sizeof == 8);
}

///
pure nothrow @safe @nogc unittest {
	import std.algorithm : equal;

	version (useModulo) {
		enum span = 8;
		enum radix = 2^^span;
		import nxt.modulo : Mod, mod;
		alias Ix = Mod!(radix, ubyte);
		static Mod!radix mk(ubyte value) => mod!radix(value);
	}
	else
	{
		alias Ix = ubyte;
		static ubyte mk(ubyte value) => value;
	}

	const ixs = [mk(11), mk(22), mk(33), mk(44)].s;
	enum capacity = 7;

	auto x = StaticModArray!(capacity, 1, 8, true)(ixs);
	auto y = StaticModArray!(capacity, 1, 8, true)(mk(11), mk(22), mk(33), mk(44));

	assert(x == y);

	assert(x.length == 4);
	assert(!x.empty);

	assert(!x.contains([mk(10)].s));
	assert(x.contains([mk(11)].s));
	assert(x.contains([mk(22)].s));
	assert(x.contains([mk(33)].s));
	assert(x.contains([mk(44)].s));
	assert(!x.contains([mk(45)].s));

	assert(!x.contains(mk(10)));
	assert(x.contains(mk(11)));
	assert(x.contains(mk(22)));
	assert(x.contains(mk(33)));
	assert(x.contains(mk(44)));
	assert(!x.contains(mk(45)));

	assert(x.equal([11, 22, 33, 44].s[]));
	assert(x.front == 11);
	assert(x.back == 44);
	assert(!x.full);
	x.popFront();
	assert(x.equal([22, 33, 44].s[]));
	assert(x.front == 22);
	assert(x.back == 44);
	assert(!x.full);
	x.popBack();
	assert(x.equal([22, 33].s[]));
	assert(x.front == 22);
	assert(x.back == 33);
	assert(!x.full);
	x.popFront();
	assert(x.equal([33].s[]));
	assert(x.front == 33);
	assert(x.back == 33);
	assert(!x.full);
	x.popFront();
	assert(x.empty);
	assert(!x.full);
	assert(x.length == 0);

	x.pushBack(mk(11), mk(22), mk(33), mk(44), mk(55), mk(66), mk(77));
	assert(x.equal([11, 22, 33, 44, 55, 66, 77].s[]));
	assert(!x.empty);
	assert(x.full);

	x.popFrontN(3);
	assert(x.equal([44, 55, 66, 77].s[]));

	x.popFrontN(2);
	assert(x.equal([66, 77].s[]));

	x.popFrontN(1);
	assert(x.equal([77].s[]));

	x.popFrontN(1);
	assert(x.empty);

	x.pushBack(mk(1)).pushBack(mk(2)).equal([1, 2].s[]);
	assert(x.equal([1, 2].s[]));
	assert(x.length == 2);
}

pure nothrow @safe unittest {
	import std.algorithm : equal;

	version (useModulo) {
		enum span = 8;
		enum radix = 2^^span;
		import nxt.modulo : Mod, mod;
		alias Ix = Mod!(radix, ubyte);
		static Mod!radix mk(ubyte value) => mod!radix(value);
	}
	else
	{
		alias Ix = ubyte;
		static ubyte mk(ubyte value) => value;
	}

	const ixs = [mk(11), mk(22), mk(33), mk(44)].s;
	enum capacity = 7;
	auto z = StaticModArray!(capacity, 1, 8, true)(ixs);
	assert(z.sizeof == 8);
	try
	{
		assert(z.toString == `0B,16,21,2C`);
	}
	catch (Exception e) {}
}

version (unittest) {
	import nxt.array_help : s;
}
