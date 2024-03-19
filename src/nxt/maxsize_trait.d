/** Trait for getting maximum size of types `T`.
 *
 * Implementation in `std.variant` uses recursion.
 *
 * See_Also: https://forum.dlang.org/post/hzpuiyxrrfasfuktpgqn@forum.dlang.org
 */
module nxt.maxsize_trait;

// version = nxt_benchmark;

/** Get maximum size of types `Ts`.
 *
 * Limitation compared to `std.variant.maxSize`: `Ts` cannot contain `void`.
 */
static template maxSizeOf(Ts...)
{
	align(1) union Impl { Ts t; }
	enum maxSizeOf = Impl.sizeof;
}

///
pure @safe unittest {
	static assert(maxSizeOf!(char) == 1);
	static assert(maxSizeOf!(byte) == 1);
	static assert(maxSizeOf!(byte, short) == 2);
	static assert(maxSizeOf!(short, byte) == 2);
	static assert(maxSizeOf!(byte, short, int) == 4);
	static assert(maxSizeOf!(byte, short, int, long) == 8);
	static assert(maxSizeOf!(byte, short, int, string) == 16);
	static assert(!__traits(compiles, { enum _ = maxSizeOf!(byte, void); }));
}

// alternative implementation that supports `void`
static template maxSizeOf_1(Ts...)
{
	align(1) union Impl {
		static foreach (i, T; Ts) {
			static if (!is(T == void))
				mixin("T _field_" ~ i.stringof ~ ";");
		}
	}
	enum maxSizeOf_1 = Impl.sizeof;
}

///
pure @safe unittest {
	static assert(maxSizeOf_1!(char) == 1);
	static assert(maxSizeOf_1!(byte) == 1);
	static assert(maxSizeOf_1!(byte, short) == 2);
	static assert(maxSizeOf_1!(short, byte) == 2);
	static assert(maxSizeOf_1!(byte, short, int) == 4);
	static assert(maxSizeOf_1!(byte, short, int, long) == 8);
	static assert(maxSizeOf_1!(byte, short, int, string) == 16);
	static assert(maxSizeOf_1!(byte, void) == 1);
	static assert(maxSizeOf_1!(byte, short, void) == 2);
}

template maxSizeOf_2(Ts...)
{
	enum maxSizeOf_2 = compute();
	auto compute()
	{
		size_t result;
		static foreach (T; Ts)
			if (T.sizeof > result)
				result = T.sizeof;
		return result;
	}
}

///
pure @safe unittest {
	static assert(maxSizeOf_2!(char) == 1);
	static assert(maxSizeOf_2!(byte) == 1);
	static assert(maxSizeOf_2!(byte, short) == 2);
	static assert(maxSizeOf_2!(short, byte) == 2);
	static assert(maxSizeOf_2!(byte, short, int) == 4);
	static assert(maxSizeOf_2!(byte, short, int, long) == 8);
	static assert(maxSizeOf_2!(byte, short, int, string) == 16);
	static assert(maxSizeOf_2!(byte, void) == 1);
	static assert(maxSizeOf_2!(byte, short, void) == 2);
}

struct W(T, size_t n)
{
	T value;
}

version (nxt_benchmark)
void benchmark()
{
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
				static assert(maxSizeOf!(T) != 0);
			}
		}
	}
}
