/** This module contains an implementation of rational numbers that is templated
 * on the underlying integer type.  It can be used with either builtin fixed
 * width integers or arbitrary precision integers.  All relevant operators are
 * overloaded for both rational-rational and rational-integer operations.
 *
 * Synopsis:
 * ---
 * // Compute pi using the generalized continued fraction approximation.
 * import std.bigint, std.rational, std.stdio;
 *
 * enum maxTerm = 30;
 *
 * Rational!(BigInt) getTerm(int termNumber)
 * {
 *	 auto addFactor = 2 * termNumber - 1;
 *
 *	 if (termNumber == maxTerm)
 *	 {
 *		 return rational(BigInt(addFactor));
 *	 }
 *
 *	 auto termNumberSquared = BigInt(termNumber * termNumber);
 *	 auto continued = termNumberSquared / getTerm(termNumber + 1);
 *
 *	 continued += addFactor;
 *	 return continued;
 * }
 *
 * void main()
 * {
 *	 auto pi = rational(BigInt(4)) / getTerm(1);
 *
 *	 // Display the result in rational form.
 *	 writeln(pi);
 *
 *	 // Display the decimal equivalent, which is accurate to 18 decimal places.
 *	 writefln("%.18f", cast(real) pi);
 * }
 * ---
 *
 *
 * Author:  David Simcha
 * Copyright:  Copyright (c) 2009-2011, David Simcha.
 * License:	$(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module nxt.rational;

import std.conv : to;
import std.math : abs;

/** Checks whether $(D T) is structurally an integer, i.e. whether it supports
 * all of the operations an integer type should support.  Does not check the
 * nominal type of $(D T).  In particular, for a mutable type $(D T) the
 * following must compile:
 *
 * ---
 * T n;
 * n = 2;
 * n <<= 1;
 * n >>= 1;
 * n += n;
 * n += 2;
 * n *= n;
 * n *= 2;
 * n /= n;
 * n /= 2;
 * n -= n;
 * n -= 2;
 * n %= 2;
 * n %= n;
 * bool foo = n < 2;
 * bool bar = n == 2;
 * bool goo = n < n + 1;
 * bool tar = n == n;
 * ---
 *
 * while for a non-mutable type, the above must compile for its unqualified,
 * mutable variant.
 *
 * All built-in D integers and character types and $(XREF bigint, BigInt) are
 * integer-like by this definition.
 */
template isIntegerLike(T)
{
	import std.traits : isMutable;
	static if (isMutable!T)
	{
		import std.traits : isIntegral, isSomeChar, isArray, isFloatingPoint;
		static if (isIntegral!T ||
				   isSomeChar!T)
		{
			enum isIntegerLike = true;
		}
		else static if (isFloatingPoint!T ||
						is(T == bool) ||
						isArray!T)
		{
			enum isIntegerLike = false;
		}
		else
		{
			enum isIntegerLike = is(typeof(
			{
				T n;
				n = 2;
				n = n;
				n <<= 1;
				n >>= 1;
				n += n;
				n += 2;
				n *= n;
				n *= 2;
				n /= n;
				n /= 2;
				n -= n;
				n -= 2;
				n %= 2;
				n %= n;
				/+ TODO: what about ^^= ? +/
				bool lt = n < 2; // less than
				bool eq = n == 2; // equal to literal
				bool ltg = n < n + 1;
				bool seq = n == n; // reflexive equal
				return n;
			}));
		}
	}
	else
	{
		import core.internal.traits : Unqual;
		alias isIntegerLike = isIntegerLike!(Unqual!T);
	}
}

pure nothrow @safe @nogc unittest {
	import std.bigint : BigInt;
	import std.meta : AliasSeq;
	foreach (T; AliasSeq!(BigInt,
						  long, ulong, int, uint,
						  short, ushort, byte, ubyte,
						  char, wchar, dchar))
	{
		static assert(isIntegerLike!T);
		static assert(isIntegerLike!(const(T)));
		static assert(isIntegerLike!(immutable(T)));
	}

	foreach (T; AliasSeq!(real, double, float, bool))
	{
		static assert(!isIntegerLike!T);
		static assert(!isIntegerLike!(const(T)));
		static assert(!isIntegerLike!(immutable(T)));
	}
}

/** Checks if $(D T) has the basic properties of a rational type, i.e.  it has a
 * numerator and a denominator.
 */
enum isRational(T) = (is(typeof(T.init.numerator)) && /+ TODO: faster to use hasMember? TODO: check that member `isIntegerLike`? +/
					  is(typeof(T.init.denominator))); /+ TODO: faster to use hasMember? TODO: check that member `isIntegerLike`? +/

/** Returns a Common Integral Type between $(D I1) and $(D I2).  This is defined
 * as the type returned by I1.init * I2.init.
 */
private template CommonInteger(I1, I2)
if (isIntegerLike!I1 &&
	isIntegerLike!I2)
{
	import core.internal.traits : Unqual;
	alias CommonInteger = typeof(Unqual!(I1).init *
								 Unqual!(I2).init);
}

pure nothrow @safe @nogc unittest {
	import std.bigint : BigInt;
	static assert(is(CommonInteger!(BigInt, int) == BigInt));
	static assert(is(CommonInteger!(byte, int) == int));
}

/** Returns a Common Rational Type between $(D R1) and $(D R2), which will be a
 * Rational based on the CommonInteger of their underlying integer types (or
 * just on the CommonInteger of ($D R1) and $(D R2), if they themselves are
 * integers).
 */
private template CommonRational(R1, R2) /+ TODO: avoid recursions below +/
{
	static if (isRational!R1)
	{
		alias CommonRational = CommonRational!(typeof(R1.numerator), R2); // recurse. TODO: avoid
	}
	else static if (isRational!R2)
	{
		alias CommonRational = CommonRational!(R1, typeof(R2.numerator)); // recurse. TODO: avoid
	}
	else static if (is(CommonInteger!(R1, R2)))
	{
		alias CommonRational = Rational!(CommonInteger!(R1, R2));
	}
}

/** Implements rational numbers on top of whatever integer type is specified by
 * the user.  The integer type used may be any type that behaves as an integer.
 * Specifically, $(D isIntegerLike) must return true, the integer type must have
 * value semantics, and the semantics of all integer operations must follow the
 * normal rules of integer arithmetic.
 *
 * A regular integer can be converted to rational type simply by passing it as
 * a single argument.  In this case the denominator will simply be set to 1.
 *
 * Examples:
 * ---
 * auto r1 = rational(BigInt("314159265"), BigInt("27182818"));
 * auto r2 = rational(BigInt("8675309"), BigInt("362436"));
 * r1 += r2;
 * assert(r1 == rational(BigInt("174840986505151"),
 *					   BigInt("4926015912324")));
 *
 * // Print result.  Prints:
 * // "174840986505151/4926015912324"
 * writeln(r1);
 *
 * // Print result in decimal form.  Prints:
 * // "35.4934"
 * writeln(cast(real) r1);
 *
 * auto r3 = rational(10);
 * assert(r3.numerator == 10);
 * assert(r3.denominator == 1);
 * assert(r3 == 10);
 * ---
 */
Rational!(CommonInteger!(I1, I2)) rational(I1, I2)(I1 i1, I2 i2)
if (isIntegerLike!I1 &&
	isIntegerLike!I2)
{
	static if (is(typeof(typeof(return)(i1, i2))))
	{
		// Avoid initializing and then reassigning.
		auto ret = typeof(return)(i1, i2);
	}
	else
	{
		/* Don't want to use void initialization b/c BigInts probably use
		 * assignment operator, copy c'tor, etc.
		 */
		typeof(return) ret;
		ret._num = i1;
		ret._den = i2;
	}
	ret.simplify();
	return ret;
}
/// ditto
Rational!(I) rational(I)(I val)
if (isIntegerLike!I)
{
	return rational(val, 1);
}

/** The struct that implements rational numbers.  All relevant operators
 * (addition, subtraction, multiplication, division, exponentiation by a
 * non-negative integer, equality and comparison) are overloaded.  The second
 * operand for all binary operators except exponentiation may be either another
 * $(D Rational) or another integer type.
 */
struct Rational(SomeIntegral)
if (isIntegerLike!SomeIntegral)
{
public:

	// ----------------Multiplication operators----------------------------------
	Rational!(SomeIntegral) opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "*" && is(CommonRational!(SomeIntegral, Rhs)) && isRational!Rhs)
	{
		auto ret = CommonRational!(SomeIntegral, Rhs)(this.numerator, this.denominator);
		return ret *= that;
	}
	/// ditto
	Rational!(SomeIntegral) opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "*" && is(CommonRational!(SomeIntegral, Rhs)) && isIntegerLike!Rhs)
	{
		const factor = gcf(this._den, that);
		const adjusted_den = cast(SomeIntegral)(this._den / factor);
		const adjusted_rhs = that / factor;
		const long new_den = this._num * adjusted_rhs;
		if (new_den > SomeIntegral.max)
			throw new Exception("");
		else
			return typeof(this)(cast(SomeIntegral)new_den,
								adjusted_den);
	}

	auto opBinaryRight(string op, Rhs)(const scope Rhs that) const
	if (op == "*" && is(CommonRational!(SomeIntegral, Rhs)) && isIntegerLike!Rhs)
	{
		return opBinary!(op, Rhs)(that); // commutative
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "*" && isRational!Rhs)
	{
		/* Cancel common factors first, then multiply.  This prevents
		 * overflows and is much more efficient when using BigInts. */
		auto divisor = gcf(this._num, that._den);
		this._num /= divisor;
		const rhs_den = that._den / divisor;

		divisor = gcf(this._den, that._num); // reuse divisor
		this._den /= divisor;
		const rhs_num = that._num / divisor;

		this._num *= rhs_num;
		this._den *= rhs_den;

		/* no simplify. already cancelled common factors before multiplying. */
		fixSigns();

		return this;
	}
	/// ditto
	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "*" && isIntegerLike!Rhs)
	{
		const divisor = gcf(this._den, that);
		this._den /= divisor;
		this._num *= that / divisor;
		/* no to simplify. already cancelled common factors before multiplying. */
		fixSigns();
		return this;
	}

	typeof(this) opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "/" &&
		is(CommonRational!(int, Rhs)) &&
		isRational!Rhs)
	{
		return typeof(return)(_num * that._den,
							  _den * that._num);
	}
	// ditto
	typeof(this) opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "/" &&
		is(CommonRational!(int, Rhs)) &&
		isIntegerLike!(Rhs))
	{
		auto ret = CommonRational!(int, Rhs)(this.numerator, this.denominator);
		return ret /= that;
	}

	typeof(this) opBinaryRight(string op, Rhs)(const scope Rhs that) const
	if (op == "/" &&
		is(CommonRational!(int, Rhs)) &&
		isIntegerLike!Rhs)
	{
		auto ret = CommonRational!(int, Rhs)(this.denominator, this.numerator);
		return ret *= that;
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "/" &&
		isIntegerLike!Rhs)
	{
		const divisor = gcf(this._num, that);
		this._num /= divisor;
		this._den *= that / divisor;

		/* no to simplify. already cancelled common factors before multiplying. */
		fixSigns();
		return this;
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "/" &&
		isRational!Rhs)
	{
		return this *= that.inverse();
	}

	// ---------------------addition operators-------------------------------------

	auto opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "+" &&
		(isRational!Rhs ||
		 isIntegerLike!Rhs))
	{
		auto ret = CommonRational!(typeof(this), Rhs)(this.numerator, this.denominator);
		return ret += that;
	}

	auto opBinaryRight(string op, Rhs)(const scope Rhs that) const
	if (op == "+" &&
		is(CommonRational!(SomeIntegral, Rhs)) &&
		isIntegerLike!Rhs)
	{
		return opBinary!(op, Rhs)(that); // commutative
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "+" &&
		isRational!Rhs)
	{
		if (this._den == that._den)
		{
			this._num += that._num;
			simplify();
			return this;
		}

		SomeIntegral commonDenom = lcm(this._den, that._den);
		this._num *= commonDenom / this._den;
		this._num += (commonDenom / that._den) * that._num;
		this._den = commonDenom;

		simplify();
		return this;
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "+" &&
		isIntegerLike!Rhs)
	{
		this._num += that * this._den;

		simplify();
		return this;
	}

	// -----------------------Subtraction operators-------------------------------
	auto opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "-" &&
		is(CommonRational!(SomeIntegral, Rhs)))
	{
		auto ret = CommonRational!(typeof(this), Rhs)(this.numerator,
													  this.denominator);
		return ret -= that;
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "-" &&
		isRational!Rhs)
	{
		if (this._den == that._den)
		{
			this._num -= that._num;
			simplify();
			return this;
		}

		auto commonDenom = lcm(this._den, that._den);
		this._num *= commonDenom / this._den;
		this._num -= (commonDenom / that._den) * that._num;
		this._den = commonDenom;

		simplify();
		return this;
	}

	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "-" &&
		isIntegerLike!Rhs)
	{
		this._num -= that * this._den;

		simplify();
		return this;
	}

	typeof(this) opBinaryRight(string op, Rhs)(const scope Rhs that) const
	if (op == "-" &&
		is(CommonInteger!(SomeIntegral, Rhs)) &&
		isIntegerLike!Rhs)
	{
		Rational!(SomeIntegral) ret;
		ret._den = this._den;
		ret._num = (that * this._den) - this._num;

		ret.simplify();
		return ret;
	}

	// ----------------------Unary operators---------------------------------------
	typeof(this) opUnary(string op)() const
	if (op == "-" || op == "+")
	{
		mixin("return typeof(this)(" ~ op ~ "_num, _den);");
	}

	// Can only handle integer powers if the result has to also be rational.
	typeof(this) opOpAssign(string op, Rhs)(const scope Rhs that)
	if (op == "^^" &&
		isIntegerLike!Rhs)
	{
		if (that < 0)
		{
			this.invert();
			_num ^^= that * -1;
			_den ^^= that * -1;
		}
		else
		{
			_num ^^= that;
			_den ^^= that;
		}

		/* don't need to simplify here.  this is already simplified, meaning
		 * the numerator and denominator don't have any common factors.  raising
		 * both to a positive integer power won't create any.
		 */
		return this;
	}
	/// ditto
	auto opBinary(string op, Rhs)(const scope Rhs that) const
	if (op == "^^" &&
		isIntegerLike!Rhs &&
		is(CommonRational!(SomeIntegral, Rhs)))
	{
		auto ret = CommonRational!(SomeIntegral, Rhs)(this.numerator, this.denominator);
		ret ^^= that;
		return ret;
	}

	import std.traits : isAssignable;

	typeof(this) opAssign(Rhs)(const scope Rhs that)
	if (isIntegerLike!Rhs &&
		isAssignable!(SomeIntegral, Rhs))
	{
		this._num = that;
		this._den = 1;
		return this;
	}

	typeof(this) opAssign(Rhs)(const scope Rhs that)
	if (isRational!Rhs &&
		isAssignable!(SomeIntegral, typeof(Rhs.numerator)))
	{
		this._num = that.numerator;
		this._den = that.denominator;
		return this;
	}

	bool opEquals(Rhs)(const scope Rhs that) const
	if (isRational!Rhs ||
		isIntegerLike!Rhs)
	{
		static if (isRational!Rhs)
		{
			return (that._num == this._num &&
					that._den == this._den);
		}
		else
		{
			static assert(isIntegerLike!Rhs);
			return (that == this._num &&
					this._den == 1);
		}
	}

	int opCmp(Rhs)(const scope Rhs that) const
	if (isRational!Rhs)
	{
		if (opEquals(that))
			return 0;

		/* Check a few obvious cases first, see if we can avoid having to use a
		 * common denominator.  These are basically speed hacks.
		 *
		 * Assumption:  When simplify() is called, rational will be written in
		 * canonical form, with any negative signs being only in the numerator.
		 */
		if (this._num < 0 &&
			that._num > 0)
		{
			return -1;
		}
		else if (this._num > 0 &&
				 that._num < 0)
		{
			return 1;
		}
		else if (this._num >= that._num &&
				 this._den <= that._den)
		{
			// We've already ruled out equality, so this must be > that.
			return 1;
		}
		else if (that._num >= this._num &&
				 that._den <= this._den)
		{
			return -1;
		}

		// Can't do it without common denominator.  Argh.
		auto commonDenom = lcm(this._den, that._den);
		auto lhsNum = this._num * (commonDenom / this._den);
		auto rhsNum = that._num * (commonDenom / that._den);

		if (lhsNum > rhsNum)
			return 1;
		else if (lhsNum < rhsNum)
			return -1;

		/* We've checked for equality already.  If we get to this point,
		 * there's clearly something wrong.
		 */
		assert(0);
	}

	int opCmp(Rhs)(const scope Rhs that) const
	if (isIntegerLike!Rhs)
	{
		if (opEquals(that))
			return 0;

		// Again, check the obvious cases first.
		if (that >= this._num)
			return -1;

		const that_ = that * this._den;
		if (that_ > this._num)
			return -1;
		else if (that_ < this._num)
			return 1;

		// Already checked for equality.  If we get here, something's wrong.
		assert(0);
	}

	///////////////////////////////////////////////////////////////////////////////

	/// Get inverse.
	typeof(this) inverse() const
	{
		return typeof(return)(_den, _num);
	}

	/// Invert `this`.
	void invert()
	{
		import std.algorithm.mutation : swap;
		swap(_den, _num);
	}

	import std.traits : isFloatingPoint;

	///Convert to floating point representation.
	F opCast(F)() const
	if (isFloatingPoint!F)
	{
		import std.traits : isIntegral;
		// Do everything in real precision, then convert to F at the end.
		static if (isIntegral!(SomeIntegral))
		{
			return cast(real) _num / _den;
		}
		else
		{
			Rational!SomeIntegral temp = this;
			real expon = 1.0;
			real ans = 0;
			byte sign = 1;
			if (temp._num < 0)
			{
				temp._num *= -1;
				sign = -1;
			}

			while (temp._num > 0)
			{
				while (temp._num < temp._den)
				{

					assert(temp._den > 0);

					static if (is(typeof(temp._den & 1)))
					{
						// Try to make numbers smaller instead of bigger.
						if ((temp._den & 1) == 0)
							temp._den >>= 1;
						else
							temp._num <<= 1;
					}
					else
					{
						temp._num <<= 1;
					}

					expon *= 0.5;

					/* This checks for overflow in case we're working with a
					 * user-defined fixed-precision integer.
					 */
					import std.exception : enforce;
					import std.conv : text;
					enforce(temp._num > 0, text(
						"Overflow while converting ", typeof(this).stringof,
						" to ", F.stringof, "."));

				}

				auto intPart = temp._num / temp._den;

				static if (is(SomeIntegral == struct) ||
						   is(SomeIntegral == class))
				{
					import std.bigint : BigInt;
				}
				static if (is(SomeIntegral == BigInt))
				{
					/* This should really be a cast, but BigInt still has a few
					 * issues.
					 */
					long lIntPart = intPart.toLong();
				}
				else
				{
					long lIntPart = cast(long)intPart;
				}

				// Test for changes.
				real oldAns = ans;
				ans += lIntPart * expon;
				if (ans == oldAns)  // Smaller than epsilon.
					return ans * sign;

				// Subtract out int part.
				temp._num -= intPart * temp._den;
			}

			return ans * sign;
		}
	}

	/** Casts $(D this) to an integer by truncating the fractional part.
	 * Equivalent to $(D integerPart), and then casting it to type $(D I).
	 */
	I opCast(I)() const
	if (isIntegerLike!I &&
		is(typeof(cast(I) SomeIntegral.init)))
	{
		return cast(I) integerPart;
	}

	///Returns the numerator.
	@property inout(SomeIntegral) numerator() inout
	{
		return _num;
	}

	///Returns the denominator.
	@property inout(SomeIntegral) denominator() inout
	{
		return _den;
	}

	/// Returns the integer part of this rational, with any remainder truncated.
	@property SomeIntegral integerPart() const
	{
		return this.numerator / this.denominator;
	}

	/// Returns the fractional part of this rational.
	@property typeof(this) fractionPart() const
	{
		return this - integerPart;
	}

	/// Returns a string representation of $(D this) in the form a/b.
	string toString() const
	{
		import std.bigint : BigInt, toDecimalString;
		static if (is(SomeIntegral == BigInt))
		{
			// Special case it for now.  This should be fixed later.
			return toDecimalString(_num) ~ "/" ~ toDecimalString(_den);
		}
		else
		{
			return to!string(_num) ~ "/" ~ to!string(_den);
		}
	}

private:
	SomeIntegral _num;					///< Numerator.
	SomeIntegral _den;					///< Denominator.

	void simplify()
	{
		if (_num == 0)
		{
			_den = 1;
			return;
		}

		const divisor = gcf(_num, _den);
		_num /= divisor;
		_den /= divisor;

		fixSigns();
	}

	void fixSigns() scope
	{
		static if (!is(SomeIntegral == ulong) &&
				   !is(SomeIntegral == uint) &&
				   !is(SomeIntegral == ushort) &&
				   !is(SomeIntegral == ubyte))
		{
			// Write in canonical form w.r.t. signs.
			if (_den < 0)
			{
				_den *= -1;
				_num *= -1;
			}
		}
	}
}

class OverflowException : Exception
{
pure nothrow @safe @nogc:
	this(string msg) { super(msg); }
}

pure unittest {
	import std.bigint : BigInt;
	import std.math : isClose;

	// All reference values from the Maxima computer algebra system.
	// Test c'tor and simplification first.
	auto _num = BigInt("295147905179352825852");
	auto _den = BigInt("147573952589676412920");
	auto simpNum = BigInt("24595658764946068821");
	auto simpDen = BigInt("12297829382473034410");
	auto f1 = rational(_num, _den);
	auto f2 = rational(simpNum, simpDen);
	assert(f1 == f2);
	// Check that signs of numerator/denominator are corrected
	assert(rational(10, -3).numerator == -10);
	assert(rational(7, -5).denominator == 5);

	// Test multiplication.
	assert((rational(0, 1) * rational(1, 1)) == 0);
	assert(rational(8, 42) * rational(cast(byte) 7, cast(byte) 68)
		   == rational(1, 51));
	assert(rational(20_000L, 3_486_784_401U) * rational(3_486_784_401U, 1_000U)
		   == rational(20, 1));
	auto f3 = rational(7, 57);
	f3 *= rational(2, 78);
	assert(f3 == rational(7, 2223));
	f3 = 5 * f3;
	assert(f3 == rational(35, 2223));
	assert(f3 * 5UL == 5 * f3);

	/* Test division.  Since it's implemented in terms of multiplication,
	 * quick and dirty tests should be good enough.
	 */
	assert(rational(7, 38) / rational(8, 79) == rational(553, 304));
	assert(rational(7, 38) / rational(8, 79) == rational(553, 304));
	auto f4 = rational(7, 38);
	f4 /= rational(8UL, 79);
	assert(f4 == rational(553, 304));
	f4 = f4 / 2;
	assert(f4 == rational(553, 608));
	f4 = 2 / f4;
	assert(f4 == rational(1216, 553));
	assert(f4 * 2 == f4 * rational(2));
	f4 = 2;
	assert(f4 == 2);

	// Test addition.
	assert(rational(1, 3) + rational(cast(byte) 2, cast(byte) 3) == rational(1, 1));
	assert(rational(1, 3) + rational(1, 2L) == rational(5, 6));
	auto f5 = rational( BigInt("314159265"), BigInt("27182818"));
	auto f6 = rational( BigInt("8675309"), BigInt("362436"));
	f5 += f6;
	assert(f5 == rational( BigInt("174840986505151"), BigInt("4926015912324")));
	assert(rational(1, 3) + 2UL == rational(7, 3));
	assert(5UL + rational(1, 5) == rational(26, 5));

	// Test subtraction.
	assert(rational(2, 3) - rational(1, 3) == rational(1, 3UL));
	assert(rational(1UL, 2) - rational(1, 3) == rational(1, 6));
	f5 = rational( BigInt("314159265"), BigInt("27182818"));
	f5 -= f6;
	assert(f5 == rational( BigInt("-60978359135611"), BigInt("4926015912324")));
	assert(rational(4, 3) - 1 == rational(1, 3));
	assert(1 - rational(1, 4) == rational(3, 4));

	// Test unary operators.
	auto fExp = rational(2, 5);
	assert(-fExp == rational(-2, 5));
	assert(+fExp == rational(2, 5));

	// Test exponentiation.
	fExp ^^= 3;
	assert(fExp == rational(8, 125));
	fExp = fExp ^^ 2;
	assert(fExp == rational(64, 125 * 125));
	assert(rational(2, 5) ^^ -2 == rational(25, 4));

	// Test decimal conversion.
	assert(isClose(cast(real) f5, -12.37883925284411L));

	// Test comparison.
	assert(rational(1UL, 6) < rational(1, 2));
	assert(rational(cast(byte) 1, cast(byte) 2) > rational(1, 6));
	assert(rational(-1, 7) < rational(7, 2));
	assert(rational(7, 2) > rational(-1, 7));
	assert(rational(7, 9) > rational(8, 11));
	assert(rational(8, 11) < rational(7, 9));

	assert(rational(9, 10) < 1UL);
	assert(1UL > rational(9, 10));
	assert(10 > rational(9L, 10));
	assert(2 > rational(5, 4));
	assert(1 < rational(5U, 4));

	// Test creating rationals of value zero.
	auto zero = rational(0, 8);
	assert(zero == 0);
	assert(zero == rational(0, 16));
	assert(zero.numerator == 0);
	assert(zero.denominator == 1);
	auto one = zero + 1;
	one -= one;
	assert(one == zero);

	// Test integerPart, fraction part.
	auto intFract = rational(5, 4);
	assert(intFract.integerPart == 1);
	assert(intFract.fractionPart == rational(1, 4));
	assert(cast(long) intFract == 1);

	// Test whether CTFE works for primitive types.  Doesn't work yet.
	version (none)
	{
		enum myRational = (((rational(1, 2) + rational(1, 4)) * 2 - rational(1, 4))
						   / 2 + 1 * rational(1, 2) - 1) / rational(2, 5);
		import std.stdio;
		writeln(myRational);
		static assert(myRational == rational(-15, 32));
	}
}

/** Convert a floating point number to a $(D Rational) based on integer type $(D
 * SomeIntegral).  Allows an error tolerance of $(D epsilon).  (Default $(D epsilon) =
 * 1e-8.)
 *
 * $(D epsilon) must be greater than 1.0L / long.max.
 *
 * Throws:  Exception on infinities, NaNs, numbers with absolute value
 * larger than long.max and epsilons smaller than 1.0L / long.max.
 *
 * Examples:
 * ---
 * // Prints "22/7".
 * writeln(toRational!int(PI, 1e-1));
 * ---
 */
Rational!(SomeIntegral) toRational(SomeIntegral)(real floatNum, real epsilon = 1e-8)
{
	import std.math: isNaN;
	import std.exception : enforce;
	enforce(floatNum != real.infinity &&
			floatNum != -real.infinity &&
			!isNaN(floatNum),
			"Can't convert NaNs and infinities to rational.");
	enforce(floatNum < long.max &&
			floatNum > -long.max,
			"Rational conversions of very large numbers not yet implemented.");
	enforce(1.0L / epsilon < long.max,
			"Can't handle very small epsilons < long.max in toRational.");

	/* Handle this as a special case to make the rest of the code less
	 * complicated:
	 */
	if (abs(floatNum) < epsilon)
	{
		Rational!SomeIntegral ret;
		ret._num = 0;
		ret._den = 1;
		return ret;
	}

	return toRationalImpl!(SomeIntegral)(floatNum, epsilon);
}

private Rational!SomeIntegral toRationalImpl(SomeIntegral)(real floatNum, real epsilon)
{
	import std.conv : roundTo;
	import std.traits : isIntegral;

	real actualEpsilon;
	Rational!SomeIntegral ret;

	if (abs(floatNum) < 1)
	{
		real invFloatNum = 1.0L / floatNum;
		long intPart = roundTo!long(invFloatNum);
		actualEpsilon = floatNum - 1.0L / intPart;

		static if (isIntegral!(SomeIntegral))
		{
			ret._den = cast(SomeIntegral) intPart;
			ret._num = cast(SomeIntegral) 1;
		}
		else
		{
			ret._den = intPart;
			ret._num = 1;
		}
	}
	else
	{
		long intPart = roundTo!long(floatNum);
		actualEpsilon = floatNum - intPart;

		static if (isIntegral!(SomeIntegral))
		{
			ret._den = cast(SomeIntegral) 1;
			ret._num = cast(SomeIntegral) intPart;
		}
		else
		{
			ret._den = 1;
			ret._num = intPart;
		}
	}

	if (abs(actualEpsilon) <= epsilon)
		return ret;

	// Else get results from downstream recursions, add them to this result.
	return ret + toRationalImpl!(SomeIntegral)(actualEpsilon, epsilon);
}

unittest {
	import std.bigint : BigInt;
	import std.math : PI, E;
	// Start with simple cases.
	assert(toRational!int(0.5) == rational(1, 2));
	assert(toRational!BigInt(0.333333333333333L) == rational(BigInt(1), BigInt(3)));
	assert(toRational!int(2.470588235294118) == rational(cast(int) 42, cast(int) 17));
	assert(toRational!long(2.007874015748032) == rational(255L, 127L));
	assert(toRational!int( 3.0L / 7.0L) == rational(3, 7));
	assert(toRational!int( 7.0L / 3.0L) == rational(7, 3));

	// Now for some fun.
	real myEpsilon = 1e-8;
	auto piRational = toRational!long(PI, myEpsilon);
	assert(abs(cast(real) piRational - PI) < myEpsilon);

	auto eRational = toRational!long(E, myEpsilon);
	assert(abs(cast(real) eRational - E) < myEpsilon);
}

/** Find the Greatest Common Factor (GCF), aka Greatest Common Divisor (GCD), of
 * $(D m) and $(D n).
 */
CommonInteger!(I1, I2) gcf(I1, I2)(I1 m, I2 n)
if (isIntegerLike!I1 &&
	isIntegerLike!I2)
{
	static if (is(I1 == const) || is(I1 == immutable) ||
			   is(I2 == const) || is(I2 == immutable))
	{
		// Doesn't work with immutable(BigInt).
		import core.internal.traits : Unqual;
		return gcf!(Unqual!I1,
					Unqual!I2)(m, n);
	}
	else
	{
		typeof(return) a = abs(m);
		typeof(return) b = abs(n);

		while (b)
		{
			auto t = b;
			b = a % b;
			a = t;
		}

		return a;
	}
}

pure unittest {
	import std.bigint : BigInt;
	assert(gcf(0, 0) == 0);
	assert(gcf(0, 1) == 1);
	assert(gcf(999, 0) == 999);
	assert(gcf(to!(immutable(int))(8), to!(const(int))(12)) == 4);

	// Values from the Maxima computer algebra system.
	assert(gcf(BigInt(314_156_535UL), BigInt(27_182_818_284UL)) == BigInt(3));
	assert(gcf(8675309, 362436) == 1);
	assert(gcf(BigInt("8589934596"), BigInt("295147905179352825852")) == 12);
}

/// Find the Least Common Multiple (LCM) of $(D a) and $(D b).
CommonInteger!(I1, I2) lcm(I1, I2)(const scope I1 a, const scope I2 b)
if (isIntegerLike!I1 &&
	isIntegerLike!I2)
{
	const n1 = abs(a);
	const n2 = abs(b);
	if (n1 == n2)
		return n1;
	return (n1 / gcf(n1, n2)) * n2;
}

/// Returns the largest integer less than or equal to $(D r).
SomeIntegral floor(SomeIntegral)(const scope Rational!SomeIntegral r)
{
	SomeIntegral intPart = r.integerPart;
	if (r > 0 || intPart == r)
		return intPart;
	else
	{
		intPart -= 1;
		return intPart;
	}
}

pure nothrow @safe @nogc unittest {
	assert(floor(rational(1, 2)) == 0);
	assert(floor(rational(-1, 2)) == -1);
	assert(floor(rational(2)) == 2);
	assert(floor(rational(-2)) == -2);
	assert(floor(rational(-1, 2)) == -1);
}

/// Returns the smallest integer greater than or equal to $(D r).
SomeIntegral ceil(SomeIntegral)(const scope Rational!SomeIntegral r)
{
	SomeIntegral intPart = r.integerPart;
	if (intPart == r || r < 0)
		return intPart;
	else
	{
		intPart += 1;
		return intPart;
	}
}

pure nothrow @safe @nogc unittest {
	assert(ceil(rational(1, 2)) == 1);
	assert(ceil(rational(0)) == 0);
	assert(ceil(rational(-1, 2)) == 0);
	assert(ceil(rational(1)) == 1);
	assert(ceil(rational(-2)) == -2);
}

/** Round $(D r) to the nearest integer.  If the fractional part is exactly 1/2,
 * $(D r) will be rounded such that the absolute value is increased by rounding.
 */
SomeIntegral round(SomeIntegral)(const scope Rational!SomeIntegral r)
{
	auto intPart = r.integerPart;
	const fractPart = r.fractionPart;

	bool added;
	if (fractPart >= rational(1, 2))
	{
		added = true;
		intPart += 1;
	}

	import std.traits : isUnsigned;

	static if (!isUnsigned!SomeIntegral)
	{
		if (!added && fractPart <= rational(-1, 2))
			intPart -= 1;
	}

	return intPart;
}

pure nothrow @safe @nogc unittest {
	assert(round(rational(1, 3)) == 0);
	assert(round(rational(7, 2)) == 4);
	assert(round(rational(-3, 4)) == -1);
	assert(round(rational(8U, 15U)) == 1);
}
