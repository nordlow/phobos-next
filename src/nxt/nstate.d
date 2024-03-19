/** N-State (Fuzzy Logic).

	Generalization of `bool` to three or more states.

	See_Also: https://en.wikipedia.org/wiki/Three-state_logic
	See_Also: https://en.wikipedia.org/wiki/Four-valued_logic
	See_Also: https://en.wikipedia.org/wiki/Many-valued_logic
	See_Also: https://en.wikipedia.org/wiki/Three-valued_logic
	See_Also: https://forum.dlang.org/post/l4gnrc$2glg$1@digitalmars.com
 */
module nxt.nstate;

/** Fuzzy logic State.
 */
struct Fuzzy
{
	pure nothrow @safe @nogc:

	enum defaultCode = 0;

	enum no	   = make(defaultCode); // probability: 0
	enum yes	  = make(1);	// probability: 1
	enum likely   = make(2);	// probability: > 1/2
	enum unlikely = make(3);	// probability: < 1/2
	enum unknown  = make(4);	// probability: any

	this(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	void opAssign(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	Fuzzy opUnary(string s)() if (s == "~")
	{
		final switch (_v)
		{
		case no._v: return yes;
		case yes._v: return no;
		case likely._v: return unlikely;
		case unlikely._v: return likely;
		}
	}

	Fuzzy opBinary(string s)(Fuzzy rhs) if (s == "|")
	{
		import std.algorithm.comparion : among;
		if (_v.among!(yes._v, no._v) &&
			rhs._v.among!(yes._v, no._v))
			return _v | rhs._v;
		else if (_v == yes._v ||
				 rhs._v == yes._v)
			return yes;
		else if (_v == no._v)
			return rhs._v;
		else if (rhs._v == no._v)
			return _v;
		else if (_v == rhs._v) // both likely or unlikely or unknown
			return _v;
		else
			return unknown;
	}

	// Fuzzy opBinary(string s)(Fuzzy rhs) if (s == "&")
	// {
	//	 return make(_v & rhs._v);
	// }

	// Fuzzy opBinary(string s)(Fuzzy rhs) if (s == "^")
	// {
	//	 auto v = _v + rhs._v;
	//	 return v >= 4 ? unknown : make(!!v);
	// }

private:
	ubyte _v = defaultCode;
	static Fuzzy make(ubyte b)
	{
		Fuzzy r = void;
		r._v = b;
		return r;
	}
}

pure nothrow @safe @nogc unittest {
	alias T = Fuzzy;
	T a;
	assert(a == T.no);

	a = true;
	assert(a == T.yes);

	a = T.likely;
	assert(a == T.likely);

	a = T.unlikely;
	assert(a == T.unlikely);

	with (T)
	{
		assert(~no == yes);
		assert(no == ~yes);
		assert(~unlikely == likely);
		assert(unlikely == ~likely);
	}
}

/** State being either `yes`, `no` or `unknown`.
 */
struct Tristate
{
	pure nothrow @safe @nogc:

	enum defaultCode = 0;

	enum no	  = make(defaultCode);
	enum yes	 = make(2);
	enum unknown = make(6);

	this(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	void opAssign(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	Tristate opUnary(string s)() if (s == "~") => make((193 >> _v & 3) << 1);
	Tristate opBinary(string s)(Tristate rhs) if (s == "|") => make((12756 >> (_v + rhs._v) & 3) << 1);
	Tristate opBinary(string s)(Tristate rhs) if (s == "&") => make((13072 >> (_v + rhs._v) & 3) << 1);
	Tristate opBinary(string s)(Tristate rhs) if (s == "^") => make((13252 >> (_v + rhs._v) & 3) << 1);

private:
	ubyte _v = defaultCode;
	static Tristate make(ubyte b)
	{
		Tristate r = void;
		r._v = b;
		return r;
	}
}

pure nothrow @safe @nogc unittest {
	alias T = Tristate;
	T a;
	assert(a == T.no);
	static assert(!is(typeof({ if (a) {} })));
	assert(!is(typeof({ auto b = T(3); })));

	a = true;
	assert(a == T.yes);

	a = false;
	assert(a == T.no);

	a = T.unknown;
	T b;

	b = a;
	assert(b == a);

	auto c = a | b;
	assert(c == T.unknown);
	assert((a & b) == T.unknown);

	a = true;
	assert(~a == T.no);

	a = true;
	b = false;
	assert((a ^ b) == T.yes);

	with (T)
	{
		// not
		assert(~no == yes);
		assert(~yes == no);
		assert(~unknown == unknown);

		// or
		assert((no | no) == no);
		assert((no | yes) == yes);
		assert((yes | no) == yes);
		assert((yes | yes) == yes);
		assert((no | unknown) == unknown);
		assert((yes | unknown) == yes);
		assert((unknown | no) == unknown);
		assert((unknown | yes) == yes);
		assert((unknown | unknown) == unknown);

		// and
		assert((no & no) == no);
		assert((no & yes) == no);
		assert((yes & no) == no);
		assert((yes & yes) == yes);
		assert((no & unknown) == no);
		assert((unknown & no) == no);
		assert((unknown & unknown) == unknown);
		assert((yes & unknown) == unknown);
		assert((unknown & yes) == unknown);

		// exclusive or
		assert((yes ^ yes) == no);
		assert((no ^ no) == no);
		assert((no ^ yes) == yes);
		assert((yes ^ no) == yes);
		assert((no ^ unknown) == unknown);
		assert((yes ^ unknown) == unknown);
		assert((unknown ^ no) == unknown);
		assert((unknown ^ yes) == unknown);
		assert((unknown ^ unknown) == unknown);
	}
}

/** Tristate: Three-state logic.
*/
struct TristateCond
{
	pure nothrow @safe @nogc:

	enum defaultCode = 0;

	enum no	  = make(defaultCode);
	enum yes	 = make(1);
	enum unknown = make(4);

	this(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	void opAssign(bool b)
	{
		_v = b ? yes._v : no._v;
	}

	TristateCond opUnary(string s)() if (s == "~")
		=> this == unknown ? this : make(!_v);

	TristateCond opBinary(string s)(TristateCond rhs) if (s == "|")
	{
		// | yields 0, 1, 4, 5
		auto v = _v | rhs._v;
		return v == 4 ? unknown : make(v & 1);
	}

	TristateCond opBinary(string s)(TristateCond rhs) if (s == "&")
		=> make(_v & rhs._v); // & yields 0, 1, 4

	TristateCond opBinary(string s)(TristateCond rhs) if (s == "^")
	{
		// + yields 0, 1, 2, 4, 5, 8
		auto v = _v + rhs._v;
		return v >= 4 ? unknown : make(!!v);
	}

private:
	ubyte _v = defaultCode;
	static TristateCond make(ubyte b)
	{
		TristateCond r = void;
		r._v = b;
		return r;
	}
}

pure nothrow @safe @nogc unittest {
	TristateCond a;
	assert(a == TristateCond.no);
	static assert(!is(typeof({ if (a) {} })));
	assert(!is(typeof({ auto b = TristateCond(3); })));
	a = true;
	assert(a == TristateCond.yes);
	a = false;
	assert(a == TristateCond.no);
	a = TristateCond.unknown;
	TristateCond b;
	b = a;
	assert(b == a);
	auto c = a | b;
	assert(c == TristateCond.unknown);
	assert((a & b) == TristateCond.unknown);
	a = true;
	assert(~a == TristateCond.no);
	a = true;
	b = false;
	assert((a ^ b) == TristateCond.yes);
}
