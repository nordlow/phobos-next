module nxt.knuthhash64;

pure nothrow @safe @nogc:

/** Knuth hash.
 *
 * See_Also: https://stackoverflow.com/a/9545731/683710
 */
struct KnuthHash64()			// dummy templatized to prevent instantiation
{
	pure nothrow @safe @nogc:

	pragma(msg, "WARNING: this hash really sucks collisionwise and should not be used in production!");

	/** (Re)initialize.
	 */
	void start()
	{
		_result = _seedValue;
	}

	/** Use this to feed the hash with `data`.
	 *
	 * Also implements the $(XREF range, OutputRange) interface for $(D ubyte)
	 * and $(D const(ubyte)[]).
	 */
	void put(scope const(ubyte)[] data...) @trusted
	{
		foreach (elt; data)
		{
			_result += elt;
			_result *= _mulFactor;
		}
	}

	/** Returns: the finished hash.
	 *
	 * This also calls $(LREF start) to reset the internal _state.
	 */
	ubyte[8] finish() @trusted
	{
		version (D_Coverage) {} else pragma(inline, true);
		typeof(return) bytes = (cast(ubyte*)&_result)[0 .. typeof(return).sizeof];
		start();
		return bytes;
	}

	ulong get() => _result;

private:
	private enum _seedValue = 3074457345618258791UL;
	private enum _mulFactor = 3074457345618258799UL;
	ulong _result = _seedValue;
}

/** Compute knuthHash-64 of input `data`, with optional seed `seed`.
 */
ulong knuthhash64Of()(scope const(ubyte)[] data, ulong seed = 0)
{
	auto hash = KnuthHash64!()(seed);
	hash.start();
	hash.put(data);
	return hash.get();
}

/** Compute knuthHash-64 of input string `data`, with optional seed `seed`.
 */
ulong knuthhash64Of()(in char[] data, ulong seed = 0)
	=> knuthhash64Of(cast(ubyte[])data, seed);

/// test simple `knuthhash64Of`
// unittest
// {
//	 assert(knuthhash64Of("") == KnuthHash64!()._seedValue);
//	 assert(knuthhash64Of("a") != KnuthHash64!()._seedValue);
//	 assert(knuthhash64Of("a") != knuthhash64Of("b"));
// }

// version (unittest)
// {
//	 import std.digest : isDigest;
//	 static assert(isDigest!(KnuthHash64!()));
// }
