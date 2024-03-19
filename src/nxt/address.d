module nxt.address;

/** Address as an unsigned integer aligned to a byte alignment `alignment_`.
 *
 * Used as key, value or element instead of a pointer in `HybridHashMap` to
 * prevent triggering of `gc_addRange` and `gc_removeRange`.
 *
 * TODO: is `holeValue` suitably chosen?
 *
 * See_Also: https://en.wikipedia.org/wiki/Data_structure_alignment
 */
struct AlignedAddress(uint alignment_)
if (alignment_ == 1 ||
	alignment_ == 2 ||
	alignment_ == 4 ||
	alignment_ == 8 ||
	alignment_ == 16 ||
	alignment_ == 32) {
	enum alignment = alignment_; ///< Alignment in bytes.

	/// Null value.
	static immutable typeof(this) nullValue = typeof(this).init;

	/// Hole/Deletion value. Prevent hole bitmap from being used.
	static immutable typeof(this) holeValue = typeof(this)(_addr.max);

	/// Get hash of `this`, with extra fast computation for the small case.
	@property hash_t toHash() const scope @trusted pure nothrow @nogc
	{
		pragma(inline, true);
		debug checkAlignment();
		static if (alignment == 1)
			const hash = _addr; // as is
		else static if (alignment == 2)
			const hash = _addr >> 1;
		else static if (alignment == 4)
			const hash = _addr >> 2;
		else static if (alignment == 8)
			const hash = _addr >> 3;
		else static if (alignment == 16)
			const hash = _addr >> 4;
		else static if (alignment == 32)
			const hash = _addr >> 5;
		else
			static assert(0, "Unsupported alignment");
		/+ TODO: activate import nxt.hash_functions : lemireHash64; +/
		import core.internal.hash : hashOf;
		return hashOf(cast(void*)hash); /+ TODO: is `cast(void*)` preferred here? +/
	}

	/// Check alignment.
	private debug void checkAlignment() const scope pure nothrow @safe @nogc
	{
		assert((_addr & (alignment-1)) == 0,
			   "Address is not aligned to " ~ alignment.stringof);
	}

	size_t _addr;				///< Actual pointer address as unsigned integer.
	alias _addr this;
}

///
pure nothrow @safe @nogc unittest { // cannot be @nogc when `opIndex` may throw
	alias A = AlignedAddress!1;
	import nxt.nullable_traits : hasNullValue, isNullable;
	static assert(hasNullValue!A);
	static assert(isNullable!A);
}
