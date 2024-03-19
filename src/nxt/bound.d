/** Bounded arithmetic wrapper type, similar to Ada's range/interval types.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	See_Also: http://en.wikipedia.org/wiki/Interval_arithmetic
	See_Also: https://bitbucket.org/davidstone/bounded_integer
	See_Also: http://stackoverflow.com/questions/18514806/ada-like-types-in-nimrod
	See_Also: http://forum.dlang.org/thread/xogeuqdwdjghkklzkfhl@forum.dlang.org#post-rksboytciisyezkapxkr:40forum.dlang.org
	See_Also: http://forum.dlang.org/thread/lxdtukwzlbmzebazusgb@forum.dlang.org#post-ymqdbvrwoupwjycpizdi:40forum.dlang.org
	See_Also: http://dlang.org/operatoroverloading.html

	TODO: Test with geometry.Vector or geometry.Point

	TODO: Make stuff @safe pure @nogc and in some case nothrow

	TODO: Implement overload for conditional operator p ? x1 : x2
	TODO: Propagate ranges in arithmetic (opUnary, opBinary, opOpAssign):
		  - Integer: +,-,*,^^,/
		  - FloatingPoint: +,-,*,/,^^,sqrt,

	TODO: Should implicit conversions to un-Bounds be allowed?
	Not in https://bitbucket.org/davidstone/bounded_integer.

	TODO: Merge with limited
	TODO: Is this a good idea to use?:
	import std.meta;
	mixin Proxy!_t;			 // Limited acts as V (almost).
	invariant() {
	enforce(_t >= low && _t <= high);
	wln("fdsf");

	TODO: If these things take to long to evaluted at compile-time maybe we need
	to build it into the language for example using a new syntax either using
	- integer(range:low..high, step:1)
	- int(range:low..high, step:1)
	- num(range:low..high, step:1)

	TODO: Use
	V saveOp(string op, V)(V x, V y) pure @save @nogc if(isIntegral!V
	&& (op=="+" || op=="-" || op=="<<" || op=="*"))
	{
	mixin("x "~op~"= y");
	static if(isSigned!V)
	{
	static if(op == "*")
	{
	asm naked { jnc opok; }
	}
	else
	{
	asm naked { jno opok; }
	}
	x = V.min;
	}
	else // unsigned
	{
	asm naked { jnc opok; }
	x = V.max;
	}
	opok:
	return x;
	}

	TODO: Reuse core.checkedint

	TODO: Move to Phobos std.typecons
 */
module nxt.bound;

version (none):

import std.conv: to;
import std.traits: CommonType, isIntegral, isUnsigned, isSigned, isFloatingPoint, isSomeChar, isScalarType, isBoolean;
import nxt.traits_ex : haveCommonType;
import std.stdint: intmax_t;
import std.exception: assertThrown;

version = print;

version (print) import std.stdio: wln = writeln;

/++ TODO: Use boundness policy. +/
enum Policy { clamped, overflowed, throwed, modulo }

//	 TODO: Do we need a specific underflow Exception?
// class BoundUnderflowException : Exception {
//	 this(string msg) { super(msg); }
// }

/** Exception thrown when `Bound` values overflows or underflows. */
class BoundOverflowException : Exception
{
	this(string msg) { super(msg); }
}

/** Check if the value of `expr` is known at compile-time.
	See_Also: http://forum.dlang.org/thread/owlwzvidwwpsrelpkbok@forum.dlang.org
*/
enum isCTEable(alias expr) = __traits(compiles, { enum id = expr; });

/** Check if type `T` can wrapped in a `Bounded`.
 */
enum isBoundable(T) = isScalarType!T;

/** Check if expression `expr` is a compile-time-expression that can be used as a `Bound`.
 */
enum isCTBound(alias expr) = (isBoundable!(typeof(expr)) &&
							  isCTEable!expr);

/++ TODO: use this. +/
enum areCTBoundable(alias low, alias high) = (isCTBound!low &&
											  isCTBound!high &&
											  low < high);

/* TODO: Is there a already a Phobos trait or builtin property for this? */
template PackedNumericType(alias expr)
if (isCTBound!expr) {
	alias Type = typeof(expr);
	static if (isIntegral!Type) {
		static if (expr < 0) {
			static	  if (expr >= -0x80			   && high <= 0x7f)			   { alias PackedNumericType = byte; }
			else static if (expr >= -0x8000			 && high <= 0x7fff)			 { alias PackedNumericType = short; }
			else static if (expr >= -0x80000000		 && high <= 0x7fffffff)		 { alias PackedNumericType = int; }
			else static if (expr >= -0x8000000000000000 && high <= 0x7fffffffffffffff) { alias PackedNumericType = long; }
			else { alias PackedNumericType = Type; }
		}
		else					// positive
		{
			static	  if (expr <= 0xff)			   { alias PackedNumericType = ubyte; }
			else static if (expr <= 0xffff)			 { alias PackedNumericType = ushort; }
			else static if (expr <= 0xffffffff)		 { alias PackedNumericType = uint; }
			else static if (expr <= 0xffffffffffffffff) { alias PackedNumericType = ulong; }
			else { alias PackedNumericType = Type; }
		}
	}
	else // no special handling for Boolean, FloatingPoint, SomeChar for now
	{
		alias PackedNumericType = Type;
	}
}

/** Get type that can contain the inclusive bound [`low`, `high`].
	If `packed` optimize storage for compactness otherwise for speed.
	If `signed` use a signed integer.
*/
template BoundsType(alias low,
					alias high,
					bool packed = true,
					bool signed = false)
if (isCTBound!low &&
		isCTBound!high) {
	static assert(low != high,
				  "low == high: use an enum instead");
	static assert(low < high,
				  "Requires low < high, low = " ~
				  to!string(low) ~ " and high = " ~ to!string(high));

	alias LowType = typeof(low);
	alias HighType = typeof(high);

	enum span = high - low;
	alias SpanType = typeof(span);

	static if (isIntegral!LowType &&
			   isIntegral!HighType) {
		static if (signed &&
				   low < 0)	// negative
		{
			static if (packed) {
				static	  if (low >= -0x80			   && high <= 0x7f)			   { alias BoundsType = byte; }
				else static if (low >= -0x8000			 && high <= 0x7fff)			 { alias BoundsType = short; }
				else static if (low >= -0x80000000		 && high <= 0x7fffffff)		 { alias BoundsType = int; }
				else static if (low >= -0x8000000000000000 && high <= 0x7fffffffffffffff) { alias BoundsType = long; }
				else { alias BoundsType = CommonType!(LowType, HighType); }
			}
			else
				alias BoundsType = CommonType!(LowType, HighType);
		}
		else					// positive
		{
			static if (packed) {
				static	  if (span <= 0xff)			   { alias BoundsType = ubyte; }
				else static if (span <= 0xffff)			 { alias BoundsType = ushort; }
				else static if (span <= 0xffffffff)		 { alias BoundsType = uint; }
				else static if (span <= 0xffffffffffffffff) { alias BoundsType = ulong; }
				else { alias BoundsType = CommonType!(LowType, HighType); }
			}
			else
				alias BoundsType = CommonType!(LowType, HighType);
		}
	}
	else static if (isFloatingPoint!LowType &&
					isFloatingPoint!HighType)
		alias BoundsType = CommonType!(LowType, HighType);
	else static if (isSomeChar!LowType &&
					isSomeChar!HighType)
		alias BoundsType = CommonType!(LowType, HighType);
	else static if (isBoolean!LowType &&
					isBoolean!HighType)
		alias BoundsType = CommonType!(LowType, HighType);
	else
		static assert(0, "Cannot construct a bound using types " ~ LowType.stringof ~ " and " ~ HighType.stringof);
}

unittest {
	assertThrown(('a'.bound!(false, true)));
	assertThrown((false.bound!('a', 'z')));
	//wln(false.bound!('a', 'z')); /+ TODO: Should this give compile-time error? +/

	static assert(!__traits(compiles, { alias IBT = BoundsType!(0, 0); }));  // disallow
	static assert(!__traits(compiles, { alias IBT = BoundsType!(1, 0); })); // disallow

	static assert(is(typeof(false.bound!(false, true)) == Bound!(bool, false, true)));
	static assert(is(typeof('p'.bound!('a', 'z')) == Bound!(char, 'a', 'z')));

	// low < 0
	static assert(is(BoundsType!(-1, 0, true, true) == byte));
	static assert(is(BoundsType!(-1, 0, true, false) == ubyte));
	static assert(is(BoundsType!(-0xff, 0, true, false) == ubyte));
	static assert(is(BoundsType!(-0xff, 1, true, false) == ushort));

	static assert(is(BoundsType!(byte.min, byte.max, true, true) == byte));
	static assert(is(BoundsType!(byte.min, byte.max + 1, true, true) == short));

	static assert(is(BoundsType!(short.min, short.max, true, true) == short));
	static assert(is(BoundsType!(short.min, short.max + 1, true, true) == int));

	// low == 0
	static assert(is(BoundsType!(0, 0x1) == ubyte));
	static assert(is(BoundsType!(ubyte.min, ubyte.max) == ubyte));

	static assert(is(BoundsType!(ubyte.min, ubyte.max + 1) == ushort));
	static assert(is(BoundsType!(ushort.min, ushort.max) == ushort));

	static assert(is(BoundsType!(ushort.min, ushort.max + 1) == uint));
	static assert(is(BoundsType!(uint.min, uint.max) == uint));

	static assert(is(BoundsType!(uint.min, uint.max + 1UL) == ulong));
	static assert(is(BoundsType!(ulong.min, ulong.max) == ulong));

	// low > 0
	static assert(is(BoundsType!(ubyte.max, ubyte.max + ubyte.max) == ubyte));
	static assert(is(BoundsType!(ubyte.max, ubyte.max + 0x100) == ushort));
	static assert(is(BoundsType!(uint.max + 1UL, uint.max + 1UL + ubyte.max) == ubyte));
	static assert(!is(BoundsType!(uint.max + 1UL, uint.max + 1UL + ubyte.max + 1) == ubyte));

	// floating point
	static assert(is(BoundsType!(0.0, 10.0) == double));
}

/** Value of type `V` bound inside inclusive range [`low`, `high`].

	If `optional` is `true`, this stores one extra undefined state (similar to
	Haskell's `Maybe`).

	If `useExceptions` is true range errors will throw a `BoundOverflowException`,
	otherwise truncation plus warnings will issued.
*/
struct Bound(V,
			 alias low,
			 alias high,
			 bool optional = false,
			 bool useExceptions = true,
			 bool packed = true,
			 bool signed = false)
if (isBoundable!V) {
	/* Requirements */
	static assert(low <= high,
				  "Requirement not fulfilled: low < high, low = " ~
				  to!string(low) ~ " and high = " ~ to!string(high));
	static if (optional)
		static assert(high + 1 == V.max,
					  "high + 1 cannot equal V.max");

	/** Get low inclusive bound. */
	static auto min() @property @safe pure nothrow => low;

	/** Get high inclusive bound. */
	static auto max() @property @safe pure nothrow => optional ? high - 1 : high;

	static if (isIntegral!V && low >= 0)
		size_t opCast(U : size_t)() const => this._value; // for IndexedBy support

	/** Construct from unbounded value `rhs`. */
	this(U, string file = __FILE__, int line = __LINE__)(U rhs)
		if (isBoundable!(U)) {
		checkAssign!(U, file, line)(rhs);
		this._value = cast(V)(rhs - low);
	}
	/** Assigne from unbounded value `rhs`. */
	auto opAssign(U, string file = __FILE__, int line = __LINE__)(U rhs)
		if (isBoundable!(U)) {
		checkAssign!(U, file, line)(rhs);
		_value = rhs - low;
		return this;
	}

	bool opEquals(U)(U rhs) const
	if (is(typeof({ auto _ = V.init == U.init; })))
		=> value() == rhs;

	/** Construct from `Bound` value `rhs`. */
	this(U,
		 alias low_,
		 alias high_)(Bound!(U, low_, high_,
							 optional, useExceptions, packed, signed) rhs)
	if (low <= low_ &&
		high_ <= high)
		=> this._value = rhs._value + (high - high_); // verified at compile-time

	/** Assign from `Bound` value `rhs`. */
	auto opAssign(U,
				  alias low_,
				  alias high_)(Bound!(U, low_, high_,
									  optional, useExceptions, packed, signed) rhs)
		if (low <= low_ &&
			high_ <= high &&
			haveCommonType!(V, U)) {
		// verified at compile-time
		this._value = rhs._value + (high - high_);
		return this;
	}

	auto opOpAssign(string op, U, string file = __FILE__, int line = __LINE__)(U rhs)
		if (haveCommonType!(V, U)) {
		CommonType!(V, U) tmp = void;
		mixin("tmp = _value " ~ op ~ "rhs;");
		mixin(check());
		_value = cast(V)tmp;
		return this;
	}

	@property auto value() inout => _value + this.min;

	void toString(Sink)(ref scope Sink sink) const
	{
		import std.format : formattedWrite;
		sink.formattedWrite!"%s ∈ [%s, %s] ⟒ %s"(this.value, min, max, V.stringof);
	}

	/** Check if this value is defined. */
	@property bool isDefined() @safe const pure nothrow @nogc
		=> optional ? this.value != V.max : true;

	/** Check that last operation was a success. */
	static string check() @trusted pure @nogc
	{
		return q{
			asm { jo overflow; }
			if (value < min)
				goto overflow;
			if (value > max)
				goto overflow;
			goto ok;
		  // underflow:
		  //   immutable uMsg = "Underflow at " ~ file ~ ":" ~ to!string(line) ~ " (payload: " ~ to!string(value) ~ ")";
		  //   if (useExceptions) {
		  //	   throw new BoundUnderflowException(uMsg);
		  //   } else {
		  //	   wln(uMsg);
		  //   }
		  overflow:
			throw new BoundOverflowException("Overflow at " ~ file ~ ":" ~ to!string(line) ~ " (payload: " ~ to!string(value) ~ ")");
		  ok: ;
		};
	}

	/** Check that assignment from `rhs` is ok. */
	void checkAssign(U, string file = __FILE__, int line = __LINE__)(U rhs) {
		if (rhs < min)
			goto overflow;
		if (rhs > max)
			goto overflow;
		goto ok;
	overflow:
		throw new BoundOverflowException("Overflow at " ~ file ~ ":" ~ to!string(line) ~ " (payload: " ~ to!string(rhs) ~ ")");
	ok: ;
	}

	auto opUnary(string op, string file = __FILE__, int line = __LINE__)() {
		static	  if (op == "+")
			return this;
		else static if (op == "-") {
			Bound!(-cast(int)V.max,
				   -cast(int)V.min) tmp = void; /+ TODO: Needs fix +/
		}
		mixin("tmp._value = " ~ op ~ "_value " ~ ";");
		mixin(check());
		return this;
	}

	auto opBinary(string op, U,
				  string file = __FILE__,
				  int line = __LINE__)(U rhs)
		if (haveCommonType!(V, U)) {
		alias TU = CommonType!(V, U.type);
		static if (is(U == Bound)) {
			// do value range propagation
			static	  if (op == "+") {
				enum min_ = min + U.min;
				enum max_ = max + U.max;
			}
			else static if (op == "-") {
				enum min_ = min - U.max; // min + min(-U.max)
				enum max_ = max - U.min; // max + max(-U.max)
			}
			else static if (op == "*") {
				import std.math: abs;
				static if (_value*rhs._value>= 0) // intuitive case
				{
					enum min_ = abs(min)*abs(U.min);
					enum max_ = abs(max)*abs(U.max);
				}
				else
				{
					enum min_ = -abs(max)*abs(U.max);
					enum max_ = -abs(min)*abs(U.min);
				}
			}
			/* else static if (op == "/") */
			/* { */
			/* } */
			else static if (op == "^^")  /+ TODO: Verify this case for integers and floats +/
			{
				import nxt.traits_ex: isEven;
				if (_value >= 0 ||
					(rhs._value >= 0 &&
					 rhs._value.isEven)) // always positive if exponent is even
				{
					enum min_ = min^^U.min;
					enum max_ = max^^U.max;
				}
				else
				{
					/* TODO: What to do here? */
					enum min_ = max^^U.max;
					enum max_ = min^^U.min;
				}
			}
			else
			{
				static assert(0, "Unsupported binary operator " + op);
			}
			alias TU_ = CommonType!(typeof(min_), typeof(max_));

			mixin("const result = _value " ~ op ~ "rhs;");

			/* static assert(0, min_.stringof ~ "," ~ */
			/*			   max_.stringof ~ "," ~ */
			/*			   typeof(result).stringof ~ "," ~ */
			/*			   TU_.stringof); */

			return bound!(min_, max_)(result);
			// return Bound!(TU_, min_, max_)(result);
		}
		else
		{
			CommonType!(V, U) tmp = void;
		}
		mixin("const tmp = _value " ~ op ~ "rhs;");
		mixin(check());
		return this;
	}

	private V _value;		   /// Payload.
}

/** Instantiate \c Bound from a single expression `expr`.
 *
 * Makes it easier to add free-contants to existing Bounded variables.
 */
template bound(alias value)
if (isCTBound!value) {
	const bound = Bound!(PackedNumericType!value, value, value)(value);
}

unittest {
	int x = 13;
	static assert(!__traits(compiles, { auto y = bound!x; }));
	static assert(is(typeof(bound!13) == const Bound!(ubyte, 13, 13)));
	static assert(is(typeof(bound!13.0) == const Bound!(double, 13.0, 13.0)));
	static assert(is(typeof(bound!13.0L) == const Bound!(real, 13.0L, 13.0L)));
}

/** Instantiator for \c Bound.
 *
 * Bounds `low` and `high` infer type of internal _value.
 * If `packed` optimize storage for compactness otherwise for speed.
 *
 * \see http://stackoverflow.com/questions/17502664/instantiator-function-for-bound-template-doesnt-compile
 */
template bound(alias low,
			   alias high,
			   bool optional = false,
			   bool useExceptions = true,
			   bool packed = true,
			   bool signed = false)
if (isCTBound!low &&
		isCTBound!high) {
	alias V = BoundsType!(low, high, packed, signed); // ValueType
	alias C = CommonType!(typeof(low),
						  typeof(high));
	auto bound() => Bound!(V, low, high, optional, useExceptions, packed, signed)(V.init);
	auto bound(V)(V value = V.init) => Bound!(V, low, high, optional, useExceptions, packed, signed)(value);
}

unittest {
	// static underflow
	static assert(!__traits(compiles, { auto x = -1.bound!(0, 1); }));

	// dynamic underflow
	int m1 = -1;
	assertThrown(m1.bound!(0, 1));

	// dynamic overflows
	assertThrown(2.bound!(0, 1));
	assertThrown(255.bound!(0, 1));
	assertThrown(256.bound!(0, 1));

	// dynamic assignment overflows
	auto b1 = 1.bound!(0, 1);
	assertThrown(b1 = 2);
	assertThrown(b1 = -1);
	assertThrown(b1 = 256);
	assertThrown(b1 = -255);

	Bound!(int, int.min, int.max) a;

	a = int.max;
	assert(a.value == int.max);

	Bound!(int, int.min, int.max) b;
	b = int.min;
	assert(b.value == int.min);

	a -= 5;
	assert(a.value == int.max - 5); // ok
	a += 5;

	/* assertThrown(a += 5); */

	auto x = bound!(0, 1)(1);
	x += 1;
}

unittest {
	/* TODO: static assert(is(typeof(bound!13 + bound!14) == const Bound!(ubyte, 27, 27))); */
}

/** Return `x` with automatic packed saturation.
 *
 * If `packed` optimize storage for compactness otherwise for speed.
 */
auto saturated(V,
			   bool optional = false,
			   bool packed = true)(V x) /+ TODO: inout may be irrelevant here +/
	=> bound!(V.min, V.max, optional, false, packed)(x);

/** Return `x` with automatic packed saturation.
 *
 * If `packed` optimize storage for compactness otherwise for speed.
*/
auto optional(V, bool packed = true)(V x) /+ TODO: inout may be irrelevant here +/
	=> bound!(V.min, V.max, true, false, packed)(x);

unittest {
	const sb127 = saturated!byte(127);
	static assert(!__traits(compiles, { const sb128 = saturated!byte(128); }));
	static assert(!__traits(compiles, { saturated!byte bb = 127; }));
}

unittest {
	const sb127 = saturated!byte(127);
	auto sh128 = saturated!short(128);
	sh128 = sb127;
	static assert(__traits(compiles, { sh128 = sb127; }));
	static assert(!__traits(compiles, { sh127 = sb128; }));
}

unittest {
	import std.meta: AliasSeq;
	static saturatedTest(T)() {
		const shift = T.max;
		auto x = saturated!T(shift);
		static assert(x.sizeof == T.sizeof);
		x -= shift; assert(x == T.min);
		x += shift; assert(x == T.max);
		/+ TODO: Make this work +/
		// x -= shift + 1; assert(x == T.min);
		// x += shift + 1; assert(x == T.max);
	}

	foreach (T; AliasSeq!(ubyte, ushort, uint, ulong)) {
		saturatedTest!T();
	}
}

/** Calculate Minimum.
	TODO: variadic.
*/
auto min(V1, alias low1, alias high1,
		 V2, alias low2, alias high2,
		 bool optional = false,
		 bool useExceptions = true,
		 bool packed = true,
		 bool signed = false)(Bound!(V1, low1, high1,
									 optional, useExceptions, packed, signed) a1,
							  Bound!(V2, low2, high2,
									 optional, useExceptions, packed, signed) a2) {
	import std.algorithm: min;
	enum lowMin = min(low1, low2);
	enum highMin = min(high1, high2);
	return (cast(BoundsType!(lowMin,
							 highMin))min(a1.value,
										  a2.value)).bound!(lowMin,
															highMin);
}

/** Calculate Maximum.
	TODO: variadic.
*/
auto max(V1, alias low1, alias high1,
		 V2, alias low2, alias high2,
		 bool optional = false,
		 bool useExceptions = true,
		 bool packed = true,
		 bool signed = false)(Bound!(V1, low1, high1,
									 optional, useExceptions, packed, signed) a1,
							  Bound!(V2, low2, high2,
									 optional, useExceptions, packed, signed) a2) {
	import std.algorithm: max;
	enum lowMax = max(low1, low2);
	enum highMax = max(high1, high2);
	return (cast(BoundsType!(lowMax,
							 highMax))max(a1.value,
										  a2.value)).bound!(lowMax,
															highMax);
}

unittest {
	const a = 11.bound!(0, 17);
	const b = 11.bound!(5, 22);
	const abMin = min(a, b);
	static assert(is(typeof(abMin) == const Bound!(ubyte, 0, 17)));
	const abMax = max(a, b);
	static assert(is(typeof(abMax) == const Bound!(ubyte, 5, 22)));
}

/** Calculate absolute value of `a`. */
auto abs(V,
		 alias low,
		 alias high,
		 bool optional = false,
		 bool useExceptions = true,
		 bool packed = true,
		 bool signed = false)(Bound!(V, low, high,
									 optional, useExceptions, packed, signed) a) {
	static if (low >= 0 && high >= 0) // all positive
	{
		enum low_ = low;
		enum high_ = high;
	}
	else static if (low < 0 && high < 0) // all negative
	{
		enum low_ = -high;
		enum high_ = -low;
	}
	else static if (low < 0 && high >= 0) // negative and positive
	{
		import std.algorithm: max;
		enum low_ = 0;
		enum high_ = max(-low, high);
	}
	else
	{
		static assert("This shouldn't happen!");
	}
	import std.math: abs;
	return Bound!(BoundsType!(low_, high_),
				  low_, high_,
				  optional, useExceptions, packed, signed)(a.value.abs - low_);
}

unittest {
	static assert(is(typeof(abs(0.bound!(-3, +3))) == Bound!(ubyte, 0, 3)));
	static assert(is(typeof(abs(0.bound!(-3, -1))) == Bound!(ubyte, 1, 3)));
	static assert(is(typeof(abs(0.bound!(-3, +0))) == Bound!(ubyte, 0, 3)));
	static assert(is(typeof(abs(0.bound!(+0, +3))) == Bound!(ubyte, 0, 3)));
	static assert(is(typeof(abs(0.bound!(+1, +3))) == Bound!(ubyte, 1, 3)));
	static assert(is(typeof(abs(0.bound!(-255, 255))) == Bound!(ubyte, 0, 255)));
	static assert(is(typeof(abs(0.bound!(-256, 255))) == Bound!(ushort, 0, 256)));
	static assert(is(typeof(abs(0.bound!(-255, 256))) == Bound!(ushort, 0, 256)));
	static assert(is(typeof(abs(10_000.bound!(10_000, 10_000+255))) == Bound!(ubyte, 10_000, 10_000+255)));
}

unittest {
	auto x01 = 0.bound!(0, 1);
	auto x02 = 0.bound!(0, 2);
	static assert( __traits(compiles, { x02 = x01; })); // ok within range
	static assert(!__traits(compiles, { x01 = x02; })); // should fail
}

/** TODO: Can D do better than C++ here?
	Does this automatically deduce to CommonType and if so do we need to declare it?
	Or does it suffice to constructors?
 */
version (none) {
	auto doIt(ubyte x) {
		if (x >= 0)
			return x.bound!(0, 2);
		else
			return x.bound!(0, 1);
	}

	unittest
	{
		auto x = 0.doIt;
	}
}
