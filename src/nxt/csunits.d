/** Computer Science Units.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
 */
module nxt.csunits;

/** Prefix Multipliers.
	See_Also: http://searchstorage.techtarget.com/definition/Kilo-mega-giga-tera-peta-and-all-that
*/
enum PrefixMultipliers {
	yocto = -24, // y
	zepto = -21, // z
	atto  = -18, // a
	femto = -15, // f
	pico  = -12, // p
	nano  =  -9, // n
	micro =  -6, // m
	milli =  -3, // m
	centi =  -2, // c
	deci  =  -1, // d
	none  =   0,
	deka  =   1, // D
	hecto =   2, // h
	kilo  =   3, // k
	mega  =   6, // M
	giga  =   9, // G
	tera  =  12, // T
	peta  =  15, // P
	exa   =  18, // E
	zetta =  21, // Z
	yotta =  24, // Y
}

/** Bytes (Count) Unit. */
struct Bytes {
	alias T = size_t;
	alias _value this;

	inout(T) value() @property inout @safe pure nothrow => _value;

	/**
	   See_Also: http://searchstorage.techtarget.com/definition/Kilo-mega-giga-tera-peta-and-all-that
	   See_Also: https://en.wikipedia.org/wiki/Exabyte
	 */
	string toString(bool inBits = false) const @property @trusted /* pure nothrow */
	{
		// import core.internal.traits : Unqual;

		string name = void;
		T val = void;
		if (inBits) {
			name = "Bits"; // Unqual!(typeof(this)).stringof; // Unqual: "const(Bytes)" => "Bytes"
			val = 8*_value;
		} else {
			name = "Bytes"; // Unqual!(typeof(this)).stringof; // Unqual: "const(Bytes)" => "Bytes"
			val = _value;
		}

		import std.conv : to;
		if	  (val < 1024^^1) { return to!string(val) ~ " " ~ name; }
		else if (val < 1024^^2) { return to!string(cast(real)val / 1024^^1) ~ " kilo" ~ name; }
		else if (val < 1024^^3) { return to!string(cast(real)val / 1024^^2) ~ " Mega" ~ name; }
		else if (val < 1024^^4) { return to!string(cast(real)val / 1024^^3) ~ " Giga" ~ name; }
		else if (val < 1024^^5) { return to!string(cast(real)val / 1024^^4) ~ " Tera" ~ name; }
		else if (val < 1024^^6) { return to!string(cast(real)val / 1024^^5) ~ " Peta" ~ name; }
		else if (val < 1024^^7) { return to!string(cast(real)val / 1024^^6) ~ " Exa" ~ name; }
		else if (val < 1024^^8) { return to!string(cast(real)val / 1024^^7) ~ " Zetta" ~ name; }
		else /* if (val < 1024^^9) */ { return to!string(cast(real)val / 1024^^8) ~ " Yotta" ~ name;
		/* } else { */
		/*	 return to!string(val) ~ " " ~ name; */
		}
	}

	T opUnary(string op, string file = __FILE__, int line = __LINE__)() {
		T tmp = void; mixin("tmp = " ~ op ~ " _value;"); return tmp;
	}

	T opBinary(string op, string file = __FILE__, int line = __LINE__)(T rhs) {
		T tmp = void; mixin("tmp = _value " ~ op ~ "rhs;"); return tmp;
	}

	T opOpAssign(string op, string file = __FILE__, int line = __LINE__)(T rhs) {
		mixin("_value = _value " ~ op ~ "rhs;"); return _value;
	}

	T opAssign(T rhs) {
		return _value = rhs;
	}

	private T _value;
}

/** $(D Bytes) Instantiator. */
auto bytes(size_t value) => Bytes(value);

///
pure nothrow @safe @nogc unittest {
	immutable a = bytes(1);
	immutable b = bytes(1);
	immutable c = a + b;
	assert(c == 2);
	assert(1.bytes == 1);
}

auto inPercent	   (T)(T a) => to!string(a * 1e2) ~ " \u0025";
auto inPerMille	  (T)(T a) => to!string(a * 1e3) ~ " \u2030";
auto inPerTenThousand(T)(T a) => to!string(a * 1e4) ~ " \u2031";
auto inDegrees	   (T)(T a) => to!string(a	  ) ~ " \u00B0";
