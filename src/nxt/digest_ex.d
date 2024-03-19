module nxt.digest_ex;

/** Message Digest.

	Zeros contents means uninitialized digest.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	See_Also: http://stackoverflow.com/questions/1902340/can-a-sha-1-hash-be-all-zeroes
	See_Also: http://stackoverflow.com/questions/20179287/sha1-indexed-hash-table-in-d
*/
struct Digest(size_t numBytes = 20, string name = "SHA-1") {
	static assert(hash_t.sizeof == 4 ||
				  hash_t.sizeof == 8,
				  ("Unsupported size of hash_t " ~ to!string(hash_t.sizeof)));

	//enum numBytes = 20;		 /+ TODO: templatize +/
	enum numInts = numBytes / 4;
	static assert(numBytes % 4 == 0, "numBytes must be a multiple of 4");

	import std.conv: to;

	/** Data */
	static	  if (hash_t.sizeof == 4) align(4) ubyte[numBytes] _bytes;
	else static if (hash_t.sizeof == 8) align(8) ubyte[numBytes] _bytes;
	else
	{
		static assert(0, "Cannot handle hash_t of size " ~ to!string(hash_t.sizeof));
	}

	alias _bytes this;

	hash_t toHash() const @property @trusted pure nothrow
	{
		static assert(hash_t.sizeof <= numBytes, "hash_t.sizeof must be <= numBytes");
		auto x = _bytes[0..hash_t.sizeof]; // Use offset 0 to preserv alignment of _bytes
		return *(cast(hash_t*)&x); // which is required for this execute
	}

	// Alternatively: writefln("%-(%02x%)", digest[0 .. numBytes])
	string toString(bool abbreviated = true) const @property @trusted pure /* nothrow */
	{
		import std.digest.sha: toHexString;
		import std.range: chunks;
		import std.algorithm: map, joiner;
		if (abbreviated)
			return name ~ ":" ~ _bytes[0..4].toHexString ~ "\u2026";
		else
			return name ~ ":" ~ _bytes[].chunks(4).map!toHexString.joiner(":").to!string;
	}

	/** Check if digest is undefined. */
	bool empty() @property @safe const pure nothrow
	{
		/* TODO: Is this unrolled to uint/ulong compares? */
		import nxt.predicates: allZero;
		return (cast(uint[numInts])_bytes)[].allZero; // Note: D understands that this is @safe! :)
	}

	/** Check if digest is defined. */
	bool defined() @property @safe const pure nothrow => !empty;

	/** Check if digest is initialized. */
	bool opCast(T : bool)() const @safe pure nothrow => defined;

	version (none) {
		Digest opBinary(string op)(Digest rhs) {
			typeof(return) tmp = void;
			static if (op == "^" ||
					   op == "|" ||
					   op == "&")
				mixin("tmp = _bytes[] " ~ op ~ " rhs._bytes[];");
			else
				static assert(0, "Unsupported binary operator " ~ op);
			return tmp;
		}
	}

	void toMsgpack(Packer)(ref Packer packer) const
	{
		immutable bool definedFlag = defined;
		packer.pack(definedFlag);
		if (definedFlag) {
			packer.pack(_bytes); // no header
		}
	}

	void fromMsgpack(Unpacker)(auto ref Unpacker unpacker) {
		bool definedFlag = void;
		unpacker.unpack(definedFlag);
		if (definedFlag) {
			unpacker.unpack(_bytes); // no header
		}
		else
		{
			_bytes[] = 0; // zero it!
		}
	}
}

alias MD5Digest	= Digest!(16, "MD5");
alias SHA1Digest   = Digest!(20, "SHA-1");
alias SHA224Digest = Digest!(28, "SHA-224");
alias SHA256Digest = Digest!(32, "SHA-256");
alias SHA384Digest = Digest!(48, "SHA-384");
alias SHA512Digest = Digest!(64, "SHA-512");

pure nothrow @safe @nogc unittest {
	SHA1Digest a, b;
	assert(a.empty);
	assert(b.empty);
	assert(a == b);
	/* a[0] = 1; */
	/* b[0] = 1; */
	/* b[1] = 1; */
	/* const c = a^b; */
	/* assert(c[0] == 0); */
	/* assert(c[1] == 1); */
	/* assert(!c.empty); */
}
