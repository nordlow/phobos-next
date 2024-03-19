/**
   Adler-32 implementation. This module conforms to the APIs defined in std.digest.
*/
module nxt.digest.adler;

public import std.digest;

/// Template API Adler32 implementation.
struct Adler32
{
	/// Initializes the digest calculation.
	void start() pure nothrow @safe @nogc
	{
		_a = 1;
		_b = 0;
		_tlen = moduloInterval;
	}

	/// Feeds the digest with data.
	void put(scope const(ubyte)[] data...) @trusted pure nothrow @nogc
	{
		foreach (immutable ubyte i; data) {
			_a += i;
			_b += _a;

			--_tlen;
			if (_tlen == 0) {
				_a %= 65521;
				_b %= 65521;
				_tlen = moduloInterval;
			}
		}

		if (_tlen != moduloInterval) {
			_a %= 65521;
			_b %= 65521;
		}
	}

	/// Returns the finished Adler-32 digest. This also calls start to reset the internal state.
	ubyte[4] finish() @trusted pure nothrow @nogc
	{
		import std.bitmanip : nativeToBigEndian;
		auto a = _a, b = _b;
		start();
		return nativeToBigEndian((b << 16) | a);
	}

private:

	uint _a = void, _b = void;
	uint _tlen = void;

	enum moduloInterval = 5552;
}

///
unittest {
	Adler32 adler;
	adler.start();
	adler.put(cast(ubyte[]) "abc");
	assert(adler.finish() == hexString!"024d0127");
	adler.start();
	adler.put(cast(ubyte[]) "def");
	assert(adler.finish() == hexString!"025F0130");
}

/// Convenience alias for $(D digest) function in std.digest using the Adler32 implementation.
auto adler32Of(T...)(T data) {
	return digest!(Adler32, T)(data);
}

/// OOP API for Adler32.
alias Adler32Digest = WrapperDigest!Adler32;

///
unittest {
	auto adler = new Adler32Digest;
	assert(adler.digest("abc") == hexString!"024d0127");
}

pure nothrow @safe @nogc unittest {
	static assert(isDigest!Adler32);

	assert(adler32Of("abc") == hexString!"024d0127");
	assert(adler32Of("abcdefghijklmnopqrstuvwxyz") == hexString!"90860B20");
}

version (unittest) {
	import std.conv : hexString;
}
