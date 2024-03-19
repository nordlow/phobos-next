struct W(T, size_t n)
{
	T value;
}

pure @safe unittest {
	import std.meta : AliasSeq;
	import std.traits : isCopyable;
	alias Ts(uint n) = AliasSeq!(W!(byte, n), W!(ubyte, n),
								 W!(short, n), W!(ushort, n),
								 W!(int, n), W!(uint, n),
								 W!(long, n), W!(ulong, n),
								 W!(float, n), W!(cfloat, n),
								 W!(double, n), W!(cdouble, n),
								 W!(real, n), W!(creal, n),
								 W!(string, n), W!(wstring, n), W!(dstring, n));

	enum n = 100;
	enum m = 100;
	static foreach (i; 0 .. n)
	{
		foreach (T; Ts!(n))
		{
			static foreach (j; 0 .. m)
			{
				static assert(__traits(isCopyable, T));
				// static assert(isCopyable!(T));
			}
		}
	}
}
