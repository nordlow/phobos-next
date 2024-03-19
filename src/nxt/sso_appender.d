module nxt.sso_appender;

/** Small-Size-Optimized (SSO) `Appender`.
 *
 * See_Also: https://forum.dlang.org/post/ifspcvfkwsnvyrdfngpw@forum.dlang.org
 */
struct SSOAppender(T, size_t smallCapacity)
if (smallCapacity >= 1)
{
	import std.array : Appender;
	import nxt.container.static_array : StaticArray;
	static if (!__traits(isPOD, T))
		import core.lifetime : move;

	void assureOneMoreCapacity() @trusted
	{
		if (!_isLarge &&
			_small.full)
		{
			import std.algorithm.mutation : moveEmplaceAll;

			T[smallCapacity] tmp = void;
			moveEmplaceAll(_small[], tmp[0 .. _small.length]);

			import core.lifetime : emplace;
			emplace!Large(&_large);

			_large.put(tmp[]);
			_isLarge = 1;
		}
	}

	void put(T x) @trusted
	{
		assureOneMoreCapacity();
		if (_isLarge)
		{
			static if (__traits(isPOD, T))
				_large.put(x);
			else
				_large.put(x.move);
		}
		else
		{
			static if (__traits(isPOD, T))
				_small.put(x);
			else
				_small.put(x.move);
		}
	}

	inout(T)[] data() inout return scope @trusted
	{
		if (_isLarge)
			return _large.data[];
		else
			return _small[];
	}

private:
	alias Small = StaticArray!(T, smallCapacity);
	alias Large = Appender!(T[]);
	union
	{
		Small _small;
		Large _large;
	}
	bool _isLarge;			  /+ TODO: pack this into _small +/
}

pure nothrow @safe unittest {
	alias A = SSOAppender!(int, 2);
	A a;
	a.put(11);
	a.put(12);
	assert(a.data[] == [11, 12]);
	a.put(13);
	assert(a.data[] == [11, 12, 13]);
	static if (hasPreviewDIP1000)
	{
		auto f() @safe pure {
			A a;
			return a.data;   // errors with -dip1000
		}
		static assert(!__traits(compiles, {
					auto f() @safe pure {
						auto x = SmallAppender!(char)("alphas");
						auto y = x[];
						return y;   // errors with -dip1000
					}
				}));
	}
}

version (unittest)
{
	import nxt.dip_traits : hasPreviewDIP1000;
}
