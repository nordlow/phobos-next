/**
  Provide a 2^N-bit integer type.
  Guaranteed to never allocate and expected binary layout
  Recursive implementation with very slow division.

  Copied from https://raw.githubusercontent.com/d-gamedev-team/gfm/master/integers/gfm/integers/wideint.d

  <b>Supports all operations that builtin integers support.</b>

  TODO: Integrate representations and potential assembly optimizations from
  https://github.com/ckormanyos/wide-integer

  See_Also: https://github.com/ckormanyos/wide-integer

  Bugs: it's not sure if the unsigned operand would take precedence in a comparison/division.
		  - a < b should be an unsigned comparison if at least one operand is unsigned
		  - a / b should be an unsigned division   if at least one operand is unsigned
 */
module nxt.wideint;

// version = format;				// Support std.format

import std.traits, std.ascii;

/// Signed integer of arbitary static precision `bits`.
/// Params:
///	bits = number of bits, must be a power of 2.
alias SInt(uint bits) = Int!(true, bits);

/// Unsigned integer of arbitary static precision `bits`.
/// Params:
///	bits = number of bits, must be a power of 2.
alias UInt(uint bits) = Int!(false, bits);

// Some predefined integers (any power of 2 greater than 128 would work)

/// Use this template to get an arbitrary sized integer type.
private template Int(bool signed, uint bits)
if ((bits & (bits - 1)) == 0)
{
	// forward to native type for lower numbers of bits in order of most probable
	static if (bits == 64)
	{
		static if (signed)
			alias Int = long;
		else
			alias Int = ulong;
	}
	else static if (bits == 32)
	{
		static if (signed)
			alias Int = int;
		else
			alias Int = uint;
	}
	else static if (bits == 16)
	{
		static if (signed)
			alias Int = short;
		else
			alias Int = ushort;
	}
	else static if (bits == 8)
	{
		static if (signed)
			alias Int = byte;
		else
			alias Int = ubyte;
	}
	else
	{
		alias Int = IntImpl!(signed, bits);
	}
}

private template Int(bool signed, uint bits)
if (!isPowerOf2(bits))
{
	static assert(0, "Integer bits " ~ bits.stringof ~ " is not a power of two.");
}

private bool isPowerOf2(in uint x) pure @safe nothrow @nogc
{
	auto y = cast(typeof(x + 0u))x;
	return (y & -y) > (y - 1);
}

version (unittest)
{
	static assert(isPowerOf2(2));
	static assert(!isPowerOf2(3));
	static assert(isPowerOf2(4));
	static assert(!isPowerOf2(5));
	static assert(!isPowerOf2(7));
	static assert(isPowerOf2(8));
}

/// Recursive 2^n integer implementation.
private struct IntImpl(bool signed, uint bits)
{
	static assert(bits >= 128);
	private
	{
		alias Self = typeof(this);
		enum bool isSelf(T) = is(Unqual!T == typeof(this));

		alias sub_int_t = Int!(true, bits/2);   // signed bits/2 integer
		alias sub_uint_t = Int!(false, bits/2); // unsigned bits/2 integer

		alias sub_sub_int_t = Int!(true, bits/4);   // signed bits/4 integer
		alias sub_sub_uint_t = Int!(false, bits/4); // unsigned bits/4 integer

		static if (signed)
			alias hi_t = sub_int_t; // hi_t has same signedness as the whole struct
		else
			alias hi_t = sub_uint_t;

		alias low_t = sub_uint_t;   // low_t is always unsigned

		enum _bits = bits, _signed = signed;
	}

	/// Construct from a value.
	this(T)(T x) pure nothrow @nogc
	{
		opAssign!T(x);
	}

	// Private functions used by the `literal` template.
	private static bool isValidDigitString(string digits)
	{
		import std.algorithm.searching : startsWith;
		import std.ascii : isDigit;

		if (digits.startsWith("0x"))
		{
			foreach (const d; digits[2 .. $])
				if (!isHexDigit(d) && d != '_')
					return false;
		}
		else // decimal
		{
			static if (signed)
				if (digits.startsWith("-"))
					digits = digits[1 .. $];
			if (digits.length < 1)
				return false;   // at least 1 digit required
			foreach (const d; digits)
				if (!isDigit(d) && d != '_')
					return false;
		}
		return true;
	}

	private static typeof(this) literalImpl(string digits)
	{
		import std.algorithm.searching : startsWith;
		import std.ascii : isDigit;

		typeof(this) value = 0;
		if (digits.startsWith("0x"))
		{
			foreach (const d; digits[2 .. $])
			{
				if (d == '_')
					continue;
				value <<= 4;
				if (isDigit(d))
					value += d - '0';
				else
					value += 10 + toUpper(d) - 'A';
			}
		}
		else
		{
			static if (signed)
			{
				bool negative = false;
				if (digits.startsWith("-"))
				{
					negative = true;
					digits = digits[1 .. $];
				}
			}
			foreach (const d; digits)
			{
				if (d == '_')
					continue;
				value *= 10;
				value += d - '0';
			}
			static if (signed)
				if (negative)
					value = -value;
		}
		return value;
	}

	/// Construct from compile-time digit string.
	///
	/// Both decimal and hex digit strings are supported.
	///
	/// Example:
	/// ----
	/// auto x = int128_t.literal!"20_000_000_000_000_000_001";
	/// assert((x >>> 1) == 0x8AC7_2304_89E8_0000);
	///
	/// auto y = int126.literal!"0x1_158E_4609_13D0_0001";
	/// assert(y == x);
	/// ----
	template literal(string digits)
	{
		static assert(isValidDigitString(digits),
					  "invalid digits in literal: " ~ digits);
		enum literal = literalImpl(digits);
	}

	/// Assign with a smaller unsigned type.
	ref typeof(this) opAssign(T)(T n) pure nothrow @nogc if (isIntegral!T && isUnsigned!T)
	{
		hi = 0;
		lo = n;
		return this;
	}

	/// Assign with a smaller signed type (sign is extended).
	ref typeof(this) opAssign(T)(T n) pure nothrow @nogc if (isIntegral!T && isSigned!T)
	{
		// shorter int always gets sign-extended,
		// regardless of the larger int being signed or not
		hi = (n < 0) ? cast(hi_t)(-1) : cast(hi_t)0;

		// will also sign extend as well if needed
		lo = cast(sub_int_t)n;
		return this;
	}

	/// Assign with a wide integer of the same size (sign is lost).
	ref typeof(this) opAssign(T)(T n) pure nothrow @nogc if (isWideIntInstantiation!T && T._bits == bits)
	{
		hi = n.hi;
		lo = n.lo;
		return this;
	}

	/// Assign with a smaller wide integer (sign is extended accordingly).
	ref typeof(this) opAssign(T)(T n) pure nothrow @nogc if (isWideIntInstantiation!T && T._bits < bits)
	{
		static if (T._signed)
		{
			// shorter int always gets sign-extended,
			// regardless of the larger int being signed or not
			hi = cast(hi_t)((n < 0) ? -1 : 0);

			// will also sign extend as well if needed
			lo = cast(sub_int_t)n;
			return this;
		}
		else
		{
			hi = 0;
			lo = n;
			return this;
		}
	}

	/// Cast to a smaller integer type (truncation).
	T opCast(T)() pure const nothrow @nogc if (isIntegral!T) => cast(T)lo;

	/// Cast to bool.
	T opCast(T)() pure const nothrow @nogc if (is(T == bool)) => this != 0;

	/// Cast to wide integer of any size.
	T opCast(T)() pure const nothrow @nogc if (isWideIntInstantiation!T)
	{
		static if (T._bits < bits)
			return cast(T)lo;
		else
			return T(this);
	}

	version (format)
	{
		import std.format : FormatSpec;

		/// Converts to a string. Supports format specifiers %d, %s (both decimal)
		/// and %x (hex).
		void toString(Sink)(Sink sink, in FormatSpec!char fmt) const /+ TODO: something like is(Sink == scope void delegate(scope const(char)[]) @safe)) +/
		{
			if (fmt.spec == 'x')
				toStringHexadecimal(sink);
			else
				toStringDecimal(sink);
		}
	}

	void toStringHexadecimal(Sink)(Sink sink) const /+ TODO: something like is(Sink == scope void delegate(scope const(char)[]) @safe)) +/
	{
		if (this == 0)
			return sink("0");
		enum maxDigits = bits / 4;
		char[maxDigits] buf;
		IntImpl tmp = this;
		size_t i;
		for (i = maxDigits-1; tmp != 0 && i < buf.length; i--)
		{
			buf[i] = hexDigits[cast(int)tmp & 0b00001111];
			tmp >>= 4;
		}
		assert(i+1 < buf.length);
		sink(buf[i+1 .. $]);
	}

	void toStringDecimal(Sink)(Sink sink) const /+ TODO: something like is(Sink == scope void delegate(scope const(char)[]) @safe)) +/
	{
		if (this == 0)
			return sink("0");

		// The maximum number of decimal digits is basically
		// ceil(log_10(2^^bits - 1)), which is slightly below
		// ceil(bits * log(2)/log(10)). The value 0.30103 is a slight
		// overestimate of log(2)/log(10), to be sure we never
		// underestimate. We add 1 to account for rounding up.
		enum maxDigits = cast(ulong)(0.30103 * bits) + 1;
		char[maxDigits] buf;
		size_t i;
		Self q = void, r = void;

		IntImpl tmp = this;
		if (tmp < 0)
		{
			sink("-");
			tmp = -tmp;
		}
		for (i = maxDigits-1; tmp > 0; i--)
		{
			assert(i < buf.length);
			static if (signed)
				Internals!bits.signedDivide(tmp, Self.literal!"10", q, r);
			else
				Internals!bits.unsignedDivide(tmp, Self.literal!"10", q, r);

			buf[i] = digits[cast(int)(r)];
			tmp = q;
		}
		assert(i+1 < buf.length);
		sink(buf[i+1 .. $]);
	}

	typeof(this) opBinary(string op, T)(T o) pure const nothrow @nogc
	{
		typeof(return) r = this;
		typeof(return) y = o;
		return r.opOpAssign!(op)(y);
	}

	ref typeof(this) opOpAssign(string op, T)(T y) pure nothrow @nogc if (!isSelf!T)
	{
		const(Self) o = y;
		return opOpAssign!(op)(o); /+ TODO: this can be optimized +/
	}

	ref typeof(this) opOpAssign(string op, T)(T y) pure nothrow @nogc if (isSelf!T)
	{
		static if (op == "+")
		{
			hi += y.hi;
			if (lo + y.lo < lo) // deal with overflow
				++hi;
			lo += y.lo;
		}
		else static if (op == "-")
		{
			opOpAssign!"+"(-y);
		}
		else static if (op == "<<")
		{
			if (y >= bits)
			{
				hi = 0;
				lo = 0;
			}
			else if (y >= bits / 2)
			{
				hi = lo << (y.lo - bits / 2);
				lo = 0;
			}
			else if (y > 0)
			{
				hi = (lo >>> (-y.lo + bits / 2)) | (hi << y.lo);
				lo = lo << y.lo;
			}
		}
		else static if (op == ">>" || op == ">>>")
		{
			assert(y >= 0);
			static if (!signed || op == ">>>")
				immutable(sub_int_t) signFill = 0;
			else
				immutable(sub_int_t) signFill = cast(sub_int_t)(isNegative() ? -1 : 0);

			if (y >= bits)
			{
				hi = signFill;
				lo = signFill;
			}
			else if (y >= bits/2)
			{
				lo = hi >> (y.lo - bits/2);
				hi = signFill;
			}
			else if (y > 0)
			{
				lo = (hi << (-y.lo + bits/2)) | (lo >> y.lo);
				hi = hi >> y.lo;
			}
		}
		else static if (op == "*")
		{
			const sub_sub_uint_t[4] a = toParts();
			const sub_sub_uint_t[4] b = y.toParts();

			this = 0;
			foreach (const uint i; 0 .. 4)
				foreach (const uint j; 0 .. (4 - i))
					this += Self(cast(sub_uint_t)(a[i]) * b[j]) << ((bits/4) * (i + j));
		}
		else static if (op == "&")
		{
			hi &= y.hi;
			lo &= y.lo;
		}
		else static if (op == "|")
		{
			hi |= y.hi;
			lo |= y.lo;
		}
		else static if (op == "^")
		{
			hi ^= y.hi;
			lo ^= y.lo;
		}
		else static if (op == "/" || op == "%")
		{
			Self q = void, r = void;
			static if (signed)
				Internals!bits.signedDivide(this, y, q, r);
			else
				Internals!bits.unsignedDivide(this, y, q, r);
			static if (op == "/")
				this = q;
			else
				this = r;
		}
		else
		{
			static assert(false, "unsupported operation '" ~ op ~ "'");
		}
		return this;
	}

	// const unary operations
	Self opUnary(string op)() pure const nothrow @nogc if (op == "+" || op == "-" || op == "~")
	{
		static if (op == "-")
		{
			Self r = this;
			r.not();
			r.increment();
			return r;
		}
		else static if (op == "+")
		   return this;
		else static if (op == "~")
		{
			Self r = this;
			r.not();
			return r;
		}
	}

	// non-const unary operations
	Self opUnary(string op)() pure nothrow @nogc if (op == "++" || op == "--")
	{
		static if (op == "++")
			increment();
		else static if (op == "--")
			decrement();
		return this;
	}

	bool opEquals(T)(in T y) pure const @nogc if (!isSelf!T) => this == Self(y);
	bool opEquals(T)(in T y) pure const @nogc if (isSelf!T) => lo == y.lo && y.hi == hi;

	int opCmp(T)(in T y) pure const @nogc if (!isSelf!T) => opCmp(Self(y));
	int opCmp(T)(in T y) pure const @nogc if (isSelf!T)
	{
		if (hi < y.hi) return -1;
		if (hi > y.hi) return 1;
		if (lo < y.lo) return -1;
		if (lo > y.lo) return 1;
		return 0;
	}

	// binary layout should be what is expected on this platform
	version (LittleEndian)
	{
		low_t lo;
		hi_t hi;
	}
	else
	{
		hi_t hi;
		low_t lo;
	}

	private
	{
		static if (signed)
			bool isNegative() @safe pure nothrow const @nogc => signBit();
		else
			bool isNegative() @safe pure nothrow const @nogc => false;

		void not() pure nothrow @safe @nogc
		{
			hi = ~hi;
			lo = ~lo;
		}

		void increment() pure nothrow @safe @nogc
		{
			++lo;
			if (lo == 0) ++hi;
		}

		void decrement() pure nothrow @safe @nogc
		{
			if (lo == 0) --hi;
			--lo;
		}

		enum SIGN_SHIFT = bits / 2 - 1;

		bool signBit() @safe pure const nothrow @nogc => ((hi >> SIGN_SHIFT) & 1) != 0;

		sub_sub_uint_t[4] toParts() @safe pure const nothrow @nogc
		{
			sub_sub_uint_t[4] p = void;
			enum SHIFT = bits / 4;
			immutable lomask = cast(sub_uint_t)(cast(sub_sub_int_t)(-1));
			p[3] = cast(sub_sub_uint_t)(hi >> SHIFT);
			p[2] = cast(sub_sub_uint_t)(hi & lomask);
			p[1] = cast(sub_sub_uint_t)(lo >> SHIFT);
			p[0] = cast(sub_sub_uint_t)(lo & lomask);
			return p;
		}
	}
}

template isWideIntInstantiation(U)
{
	private static void isWideInt(bool signed, uint bits)(IntImpl!(signed, bits) x)
	{
	}

	enum bool isWideIntInstantiation = is(typeof(isWideInt(U.init)));
}

public IntImpl!(signed, bits) abs(bool signed, uint bits)(IntImpl!(signed, bits) x) pure nothrow @nogc
	=> (x >= 0) ? x : -x;

private struct Internals(uint bits)
{
	alias wint_t = IntImpl!(true, bits);
	alias uwint_t = IntImpl!(false, bits);

	static void unsignedDivide(uwint_t dividend, uwint_t divisor, out uwint_t quotient, out uwint_t remainder) pure nothrow @nogc
	{
		assert(divisor != 0);

		uwint_t rQuotient = 0;
		uwint_t cDividend = dividend;

		while (divisor <= cDividend)
		{
			// find N so that (divisor << N) <= cDividend && cDividend < (divisor << (N + 1) )

			uwint_t N = 0;
			uwint_t cDivisor = divisor;
			while (cDividend > cDivisor)
			{
				if (cDivisor.signBit())
					break;

				if (cDividend < (cDivisor << 1))
					break;

				cDivisor <<= 1;
				++N;
			}
			cDividend = cDividend - cDivisor;
			rQuotient += (uwint_t(1) << N);
		}

		quotient = rQuotient;
		remainder = cDividend;
	}

	static void signedDivide(wint_t dividend, wint_t divisor, out wint_t quotient, out wint_t remainder) pure nothrow @nogc
	{
		uwint_t q, r;
		unsignedDivide(uwint_t(abs(dividend)), uwint_t(abs(divisor)), q, r);

		// remainder has same sign as the dividend
		if (dividend < 0)
			r = -r;

		// negate the quotient if opposite signs
		if ((dividend >= 0) != (divisor >= 0))
			q = -q;

		quotient = q;
		remainder = r;

		assert(remainder == 0 || ((remainder < 0) == (dividend < 0)));
	}
}

// Verify that toString is callable from pure / nothrow / @nogc code as long as
// the callback also has these attributes.
@safe unittest {
	int256 x = 123;
	x.toStringDecimal((scope const(char)[]) @safe {});
	x.toStringDecimal((scope const(char)[] x) @safe { assert(x == "123"); });
}

version (format)
unittest {
	import std.format : format;

	int128 x;
	x.hi = 1;
	x.lo = 0x158E_4609_13D0_0001;
	assert(format("%s", x) == "20000000000000000001");
	assert(format("%d", x) == "20000000000000000001");
	assert(format("%x", x) == "1158E460913D00001");

	x.hi = 0xFFFF_FFFF_FFFF_FFFE;
	x.lo = 0xEA71_B9F6_EC2F_FFFF;
	assert(format("%d", x) == "-20000000000000000001");
	assert(format("%x", x) == "FFFFFFFFFFFFFFFEEA71B9F6EC2FFFFF");

	x.hi = x.lo = 0;
	assert(format("%d", x) == "0");

	x.hi = x.lo = 0xFFFF_FFFF_FFFF_FFFF;
	assert(format("%d", x) == "-1"); // array index boundary condition
}

unittest {
	string testSigned(string op) @safe pure nothrow
	{
		return "assert(cast(ulong)(si" ~ op ~ "sj) == cast(ulong)(csi" ~ op ~ "csj));";
	}
	string testMixed(string op) @safe pure nothrow
	{
		return "assert(cast(ulong)(ui" ~ op ~ "sj) == cast(ulong)(cui" ~ op ~ "csj));"
		~ "assert(cast(ulong)(si" ~ op ~ "uj) == cast(ulong)(csi" ~ op ~ "cuj));";
	}
	string testUnsigned(string op) @safe pure nothrow
	{
		return "assert(cast(ulong)(ui" ~ op ~ "uj) == cast(ulong)(cui" ~ op ~ "cuj));";
	}
	string testAll(string op) @safe pure nothrow
	{
		return testSigned(op) ~ testMixed(op) ~ testUnsigned(op);
	}
	const long step = 164703072086692425;
	for (long si = long.min; si <= long.max - step; si += step)
	{
		for (long sj = long.min; sj <= long.max - step; sj += step)
		{
			const ulong ui = cast(ulong)si;
			const ulong uj = cast(ulong)sj;
			int128 csi = si;
			const uint128 cui = si;
			const int128 csj = sj;
			const uint128 cuj = sj;
			assert(csi == csi);
			assert(~~csi == csi);
			assert(-(-csi) == csi);
			assert(++csi == si + 1);
			assert(--csi == si);

			mixin(testAll("+"));
			mixin(testAll("-"));
			mixin(testAll("*"));
			mixin(testAll("|"));
			mixin(testAll("&"));
			mixin(testAll("^"));
			if (sj != 0)
			{
				mixin(testSigned("/"));
				mixin(testSigned("%"));
				if (si >= 0 && sj >= 0)
				{
					// those operations are not supposed to be the same at
					// higher bitdepth: a sign-extended negative may yield higher dividend
					testMixed("/");
					testUnsigned("/");
					testMixed("%");
					testUnsigned("%");
				}
			}
		}
	}
}

unittest {
	// Just a little over 2^64, so it actually needs int128.
	// Hex value should be 0x1_158E_4609_13D0_0001.
	enum x = int128.literal!"20_000_000_000_000_000_001";
	assert(x.hi == 0x1 && x.lo == 0x158E_4609_13D0_0001);
	assert((x >>> 1) == 0x8AC7_2304_89E8_0000);

	enum y = int128.literal!"0x1_158E_4609_13D0_0001";
	enum z = int128.literal!"0x1_158e_4609_13d0_0001"; // case insensitivity
	assert(x == y && y == z && x == z);
}

unittest {
	version (format) import std.format : format;

	// Malformed literals that should be rejected
	assert(!__traits(compiles, int128.literal!""));
	assert(!__traits(compiles, int128.literal!"-"));

	// Negative literals should be supported
	auto x = int128.literal!"-20000000000000000001";
	assert(x.hi == 0xFFFF_FFFF_FFFF_FFFE &&
		   x.lo == 0xEA71_B9F6_EC2F_FFFF);
	version (format) assert(format("%d", x) == "-20000000000000000001");
	version (format) assert(format("%x", x) == "FFFFFFFFFFFFFFFEEA71B9F6EC2FFFFF");

	// Negative literals should not be supported for unsigned types
	assert(!__traits(compiles, uint128.literal!"-1"));

	// Hex formatting tests
	x = 0;
	version (format) assert(format("%x", x) == "0");
	x = -1;
	version (format) assert(format("%x", x) == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
}

version (unittest)
{
	alias int128 = SInt!128;		// cent
	alias uint128 = UInt!128;		// ucent
	alias int256 = SInt!256;
	alias uint256 = UInt!256;
}
