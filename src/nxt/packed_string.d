module nxt.packed_string;

/** String packed into one word.
 *
 * Length is stored in upper `lengthBits` of pointer/word `_raw`.
 *
 * All length bits set means memory bits of `_raw` points to `string`. This
 * makes `PackedString` `nothrow`.
 *
 * TODO: If D's GC doesn't ignore the upper `lengthBits` bits of pointer, make
 * `core.memory.GC` be told that every `PackedString` should be bit-anded with
 * `addressMask` before scanned for an address. Related functions:
 * - isLarge.
 *
 * Proposed API for specifying this is: `__traits(adressBitMask, declaration,
 * mask)` where `declaration.sizeof == size_t.sizeof`.
 */
@safe struct PackedString {
	enum totalBits = 8 * _raw.sizeof;

	/++ Number of bits used to store length.
		2024-01-01: Address space of a single Linux user process is 47 bits.
	 +/
	enum lengthBits = 16;

	/// Number of bits used to memory address.
	enum addressBits = totalBits - lengthBits;

	/// Capacity of small variant where `length` fits in `lengthBits`.
	public enum smallCapacity = (2 ^^ lengthBits - 1) - 1;

	/// Bit mask of length part.
	enum size_t lengthMask = (cast(size_t)(2^^lengthBits - 1)) << addressBits;

	/// Bit mask of address part.
	enum size_t addressMask = ~lengthMask;

	alias Large = immutable(char)[];

pure nothrow @nogc:

	this(in string x) @trusted in(!((cast(size_t)x.ptr) & lengthMask)) {
		if (x.length <= smallCapacity)
			_raw = cast(size_t)(x.ptr) | (x.length << addressBits);
		else {
			assert(0, "TODO: implement this");
			// string* y = new string; /+ TODO: how do I do this? +/
			// *y = x;
			// _raw = cast(size_t)(x.ptr) | (x.length << addressBits);
		}
	}

	/** Returns: `true` iff this is a large string, otherwise `false.` */
	@property bool isLarge() const scope @trusted
	{
		version (D_Coverage) {} else pragma(inline, true);
		return (_raw & lengthMask) == (2^^lengthBits) - 1;
	}

	/// Get pointer to characters.
	immutable(char)* ptr() const @property @trusted
		=> cast(typeof(return))(_raw & addressMask);

	/// Get length.
	size_t length() const @property @safe => (cast(size_t)_raw) >> addressBits;

	/// Get slice.
	string opSlice() const @property @trusted => ptr[0 .. length];

	void toString(Sink)(ref scope Sink sink) const @property scope => sink(opSlice());

	alias opSlice this;

	private size_t _raw;
}

version (unittest) {
	static assert(PackedString.sizeof == size_t.sizeof);
	static assert(PackedString.totalBits == 64);
	static assert(PackedString.addressBits == 48);
	static assert(PackedString.smallCapacity == 65534);
	static assert(PackedString.lengthMask == 0xffff_0000_0000_0000);
	static assert(PackedString.addressMask == 0x0000_ffff_ffff_ffff);
}

///
pure @safe unittest {
	const s = "alpha";
	PackedString p = s;
	assert(p.ptr == s.ptr);
	assert(p.length == s.length);
	assert(p[] == s);
	assert(p == s);
}

///
pure @safe unittest {
	string s;
	s.length = PackedString.smallCapacity;
	PackedString p = s;
	assert(p.ptr == s.ptr);
	assert(p.length == s.length);
	assert(p[] == s);
	assert(p == s);
	assert(p is s);
}
