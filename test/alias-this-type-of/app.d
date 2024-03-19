template BooleanTypeOf2(T)
{
	import std.traits : OriginalType;
	static if (is(typeof(__traits(getMember, T.init, __traits(getAliasThis, T)[0])) AT) && !is(AT[] == AT))
		alias X = BooleanTypeOf2!AT;
	else
		alias X = OriginalType!T;

	static if (is(immutable X == immutable bool))
	{
		alias BooleanTypeOf2 = X;
	}
	else
		static assert(0, T.stringof~" is not boolean type");
}

import std.meta : AliasSeq;
alias SampleTypes = AliasSeq!(bool,
							  char, wchar, dchar,
							  byte, ubyte,
							  short, ushort,
							  int, uint,
							  long, ulong,
							  float, double, real,
							  string, wstring, dstring);

int main(string[] args)
{
	enum count = 5_000;
	import std.meta : AliasSeq;
	import std.traits : BooleanTypeOf;
	version (typeof2)
		static foreach (i; 0 .. count)
			foreach (T; SampleTypes)
				enum _ = is(BooleanTypeOf2!(T));
	else
		static foreach (i; 0 .. count)
			foreach (T; SampleTypes)
				enum _ = is(BooleanTypeOf!(T));
	return 0;
}
