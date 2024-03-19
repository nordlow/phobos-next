/** xxHash is an extremely fast non-cryptographic hash algorithm, working at
	speeds close to RAM limits. It is proposed in two flavors, 32 and 64 bits.

	Original implementation by Stephan Brumme.

	See_Also: http://cyan4973.github.io/xxHash/
	See_Also: http://create.stephan-brumme.com/xxhash/

	TODO: merge into xxhash-d
*/
module nxt.xxhash64;

pure nothrow @safe @nogc:

/** xxHash-64, based on Yann Collet's descriptions

	How to use:

		ulong myseed = 0;
		XXHash64 myhash(myseed);
		myhash.put(pointerToSomeBytes,	 numberOfBytes);
		myhash.put(pointerToSomeMoreBytes, numberOfMoreBytes); // call put() as often as you like to ...

	and compute hash:

		ulong result = myhash.hash();

	or all of the above in one single line:

		ulong result2 = XXHash64::hashOf(mypointer, numBytes, myseed);

	See_Also: http://cyan4973.github.io/xxHash/
	See_Also: http://create.stephan-brumme.com/xxhash/

	TODO: make endian-aware
**/
struct XXHash64
{
	pure nothrow @safe @nogc:

	/**
	 * Constructs XXHash64 with `seed`.
	 */
	this(ulong seed)
	{
		_seed = seed;
	}

	/** (Re)initialize.
	 */
	void start()
	{
		_state[0] = _seed + prime1 + prime2;
		_state[1] = _seed + prime2;
		_state[2] = _seed;
		_state[3] = _seed - prime1;
		_bufferSize  = 0;
		_totalLength = 0;
	}

	/** Use this to feed the hash with data.

		Also implements the $(XREF range, OutputRange) interface for $(D ubyte) and $(D const(ubyte)[]).
	 */
	void put(scope const(ubyte)[] data...) @trusted
	{
		auto ptr = data.ptr;
		auto length = data.length;

		_totalLength += length;

		// unprocessed old data plus new data still fit in temporary buffer ?
		if (_bufferSize + length < bufferMaxSize)
		{
			// just add new data
			while (length-- > 0)
				_buffer[_bufferSize++] = *ptr++;
			return;
		}

		// point beyond last byte
		const(ubyte)* end	  = ptr + length;
		const(ubyte)* endBlock = end - bufferMaxSize;

		// some data left from previous update ?
		if (_bufferSize > 0)
		{
			// make sure temporary buffer is full (16 bytes)
			while (_bufferSize < bufferMaxSize)
				_buffer[_bufferSize++] = *ptr++;

			// process these 32 bytes (4x8)
			process(_buffer.ptr, _state[0], _state[1], _state[2], _state[3]);
		}

		// copying _state to local variables helps optimizer A LOT
		ulong s0 = _state[0], s1 = _state[1], s2 = _state[2], s3 = _state[3];
		// 32 bytes at once
		while (ptr <= endBlock)
		{
			// local variables s0..s3 instead of _state[0].._state[3] are much faster
			process(ptr, s0, s1, s2, s3);
			ptr += 32;
		}
		// copy back
		_state[0] = s0; _state[1] = s1; _state[2] = s2; _state[3] = s3;

		// copy remainder to temporary buffer
		_bufferSize = end - ptr;
		foreach (const i; 0 .. _bufferSize)
			_buffer[i] = ptr[i];
	}

	/** Returns: the finished XXHash64 hash.
		This also calls $(LREF start) to reset the internal _state.
	*/
	ulong finishUlong() @trusted
	{
		// fold 256 bit _state into one single 64 bit value
		ulong result;
		if (_totalLength >= bufferMaxSize)
		{
			result = (rol(_state[0],  1) +
					  rol(_state[1],  7) +
					  rol(_state[2], 12) +
					  rol(_state[3], 18));
			result = (result ^ processSingle(0, _state[0])) * prime1 + prime4;
			result = (result ^ processSingle(0, _state[1])) * prime1 + prime4;
			result = (result ^ processSingle(0, _state[2])) * prime1 + prime4;
			result = (result ^ processSingle(0, _state[3])) * prime1 + prime4;
		}
		else
			// internal _state wasn't set in put(), therefore original seed is still stored in state2
			result = _state[2] + prime5;

		result += _totalLength;

		// process remaining bytes in temporary buffer
		const(ubyte)* data = _buffer.ptr;

		// point beyond last byte
		const(ubyte)* end = data + _bufferSize;

		// at least 8 bytes left ? => eat 8 bytes per step
		for (; data + 8 <= end; data += 8)
			result = rol(result ^ processSingle(0, *cast(ulong*)data), 27) * prime1 + prime4;

		// 4 bytes left ? => eat those
		if (data + 4 <= end)
		{
			result = rol(result ^ (*cast(uint*)data) * prime1, 23) * prime2 + prime3;
			data += 4;
		}

		// take care of remaining 0..3 bytes, eat 1 byte per step
		while (data != end)
			result = rol(result ^ (*data++) * prime5, 11) * prime1;

		// mix bits
		result ^= result >> 33;
		result *= prime2;
		result ^= result >> 29;
		result *= prime3;
		result ^= result >> 32;

		start();

		return result;
	}

	/** Returns: the finished XXHash64 hash.
		This also calls $(LREF start) to reset the internal _state.
	*/
	ubyte[8] finish() @trusted
	{
		import std.bitmanip : swapEndian;
		_result = swapEndian(finishUlong());
		return (cast(ubyte*)&_result)[0 .. typeof(return).sizeof];
	}

	ulong get()
	{
		return _result;
	}

private:
	/// magic constants
	enum ulong prime1 = 11400714785074694791UL;
	enum ulong prime2 = 14029467366897019727UL;
	enum ulong prime3 =  1609587929392839161UL;
	enum ulong prime4 =  9650029242287828579UL;
	enum ulong prime5 =  2870177450012600261UL;

	/// temporarily store up to 31 bytes between multiple put() calls
	enum bufferMaxSize = 31+1;

	ulong[4] _state;
	ulong _bufferSize;
	ulong _totalLength;
	ulong _seed;
	ubyte[bufferMaxSize] _buffer;
	ulong _result;

	import core.bitop : rol;
	/// rotate bits, should compile to a single CPU instruction (ROL)
	version (none)
	static ulong rol(ulong x, ubyte bits)
	{
		return (x << bits) | (x >> (64 - bits));
	}

	/// process a single 64 bit value
	static ulong processSingle(ulong previous, ulong data)
	{
		return rol(previous + data * prime2, 31) * prime1;
	}

	/// process a block of 4x4 bytes, this is the main part of the XXHash32 algorithm
	static void process(const(ubyte)* data,
						out ulong state0,
						out ulong state1,
						out ulong state2,
						out ulong state3) @trusted
	{
		const(ulong)* block = cast(const(ulong)*)data;
		state0 = processSingle(state0, block[0]);
		state1 = processSingle(state1, block[1]);
		state2 = processSingle(state2, block[2]);
		state3 = processSingle(state3, block[3]);
	}
}

/** Compute xxHash-64 of input `data`, with optional seed `seed`.
 */
ulong xxhash64Of(in ubyte[] data, ulong seed = 0)
{
	auto xh = XXHash64(seed);
	xh.start();
	xh.put(data);
	return xh.finishUlong();
}

/** Compute xxHash-64 of input string `data`, with optional seed `seed`.
 */
ulong xxhash64Of(in char[] data, ulong seed = 0) @trusted
{
	return xxhash64Of(cast(ubyte[])data, seed);
}

/// test simple `xxhash64Of`
unittest {
	assert(xxhash64Of("") == 17241709254077376921UL);

	ubyte[8] x = [1, 2, 3, 4, 5, 6, 7, 8];
	assert(xxhash64Of(x[]) == 9316896406413536788UL);

	// tests copied from https://pypi.python.org/pypi/xxhash/0.6.0
	assert(xxhash64Of(`xxhash`) == 3665147885093898016UL);
	assert(xxhash64Of(`xxhash`, 20141025) == 13067679811253438005UL);
}

version (unittest)
{
	import std.digest : hexDigest, isDigest;
	static assert(isDigest!(XXHash64));
}

/// `std.digest` conformance
unittest {
	import std.digest;
	assert(hexDigest!XXHash64(`xxhash`) == `32DD38952C4BC720`);
}
