module crc32c_sse42;

/** SSE 4.2 optimized CRC32c.
 *
 * See_Also: https://www.felixcloutier.com/x86/crc32
 * See_Also: https://news.ycombinator.com/item?id=32305900
 * See_Also: https://stackoverflow.com/questions/17645167/implementing-sse-4-2s-crc32c-in-software
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -mcpu=native -debug -g -unittest -main -I.. -i -run crc32c_sse42.d crc32c.d
 * Test: ldmd2 -mcpu=native -debug -g -unittest -main -I.. -i -run crc32c_sse42.d crc32c.d
 */
version (DigitalMars)
struct CRC32c
{
	private:
	alias T = uint;

	/**
	 * Type of the finished CRC hash.
	 * ubyte[4] if N is 32, ubyte[8] if N is 64.
	 */
	alias R = ubyte[4];

	// magic initialization constants
	version (LDC)
		T _state = T.max;
	version (DigitalMars)
		T _state = 0;

public:
	/**
	 * Use this to feed the digest with data.
	 * Also implements the $(REF isOutputRange, std,range,primitives)
	 * interface for `ubyte` and `const(ubyte)[]`.
	 */
	void put(scope const(ubyte)[] data...) @trusted pure nothrow @nogc
	{
		version (LDC)
		{
			import ldc.gccbuiltins_x86 : __builtin_ia32_crc32qi;
			foreach (const i; 0 .. data.length)
				_state = __builtin_ia32_crc32qi(_state, data[i]);
		}
		version (DigitalMars)
		{
			import crc32c;
			_state = crc32c_hw(_state, data);
		}
	}

	/**
	 * Used to initialize the CRC32 digest.
	 *
	 * Note:
	 * For this CRC32 Digest implementation calling start after default construction
	 * is not necessary. Calling start is only necessary to reset the Digest.
	 *
	 * Generic code which deals with different Digest types should always call start though.
	 */
	void start() pure nothrow @safe @nogc
	{
		this = typeof(this).init;
	}

	/**
	 * Returns the finished CRC hash. This also calls $(LREF start) to
	 * reset the internal state.
	 */
	R finish() @trusted pure nothrow @nogc
	{
		auto tmp = peek();
		start();
		return tmp;
	}

	/**
	 * Works like `finish` but does not reset the internal state, so it's possible
	 * to continue putting data into this CRC after a call to peek.
	 */
	R peek() const @trusted pure nothrow @nogc
	{
		import std.bitmanip : nativeToLittleEndian;
		//Complement, LSB first / Little Endian, see http://rosettacode.org/wiki/CRC-32
		version (LDC)
			return nativeToLittleEndian(_state ^ 0xFFFFFFFF);
		version (DigitalMars)
			return nativeToLittleEndian(_state);
	}
}

//
version (DigitalMars)
pure @safe unittest {
	import std.digest : digest, hexDigest;
	import std.digest.crc : CRC;
	alias std_CRC32c = CRC!(32, 0x82f63b78);
	foreach (const i; 0 .. 256) {
		const v = [cast(ubyte)i];
		assert(digest!(std_CRC32c)(v) ==
			   digest!(CRC32c)(v));
	}
}
