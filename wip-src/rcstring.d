/** Reference Counted Array.
	See_Also: http://dpaste.dzfl.pl/817283c163f5
 */
module nxt.rcstring;

import core.memory : GC;
// import core.stdc.stdlib;
// import core.stdc.string;
// import std.algorithm;

/** Reference Counted (RC) version of string.
 */
alias RCString = RCXString!(immutable char);

/** Reference Counted Array.
	Configured with character type `E`, maximum length for the small string optimization,
	and the allocation function, which must have the same semantics as `realloc`.

	See_Also: https://github.com/burner/std.rcstring
*/
struct RCXString(E = immutable char, size_t maxSmallSize = 23, alias realloc = GC.realloc)
{
	pure nothrow:

	// Preconditions
	static assert(is(E == immutable), "Only immutable characters supported for now.");
	static assert(E.alignof <= 4, "Character type must be 32-bit aligned at most.");
	static assert(E.min == 0, "Character type must be unsigned.");
	static assert((maxSmallSize + 1) * E.sizeof % size_t.sizeof == 0,
				  "maxSmallSize + 1 must be a multiple of size_t.sizeof.");
	static assert((maxSmallSize + 1) * E.sizeof >= 3 * size_t.sizeof,
				  "maxSmallSize + 1 must be >= size_t.sizeof * 3.");
	static assert(maxSmallSize < E.max, "maxSmallSize must be less than E.max");

	enum maxSmallLength = maxSmallSize;

private:
	// import std.utf;
	import core.lifetime : emplace;
	import std.traits: isSomeChar, Unqual;

	version (unittest) import std.stdio;

	alias ME = Unqual!E; // mutable E

	enum isString = isSomeChar!E;

	// Simple reference-counted buffer. The reference count itself is a E. Layout is a size_t (the capacity)
	// followed by the reference count followed by the payload.
	struct RCBuffer
	{
		size_t capacity;
		uint refCount;

		// Data starts right after the refcount, no padding because of the static assert above
		ME* mptr() @nogc { return cast(ME*) (&refCount + 1); }
		E* ptr() @nogc { return cast(E*) mptr; }

		// Create a new buffer given capacity and initializes payload. Capacity must be large enough.
		static RCBuffer* make(in size_t capacity, const(ME)[] content)
		{
			assert(capacity >= content.length);
			auto result = cast(RCBuffer*) realloc(null, size_t.sizeof + uint.sizeof + capacity * E.sizeof);
			result || assert(0);
			result.capacity = capacity;
			result.refCount = 1;
			result.mptr[0 .. content.length] = content;
			return result;
		}

		// Resize the buffer. It is assumed the reference count is 1.
		static void resize(ref RCBuffer* p, in size_t capacity)
		{
			assert(p.refCount == 1);
			p = cast(RCBuffer*) realloc(p, size_t.sizeof + uint.sizeof + capacity * E.sizeof);
			p || assert(0);
			p.capacity = capacity;
		}

		unittest
		{
			auto p = make(101, null);
			assert(p.refCount == 1);
			assert(p.capacity == 101);
			resize(p, 203);
			assert(p.refCount == 1);
			assert(p.capacity == 203);
			realloc(p, 0);
		}
	}

	// Hosts a large string
	struct Large
	{
		// <layout>
		union
		{
			immutable RCBuffer* buf;
			RCBuffer* mbuf;
		}
		union
		{
			E* ptr;
			ME* mptr;
		}
		static if ((maxSmallSize + 1) * E.sizeof == 3 * size_t.sizeof)
		{
			/* The small buffer and the large buffer overlap. This means the large buffer must give up its last byte
			 * as a discriminator.
			 */
			size_t _length;
			enum maxLarge = size_t.max >> (8 * E.sizeof);
			version (BigEndian)
			{
				// Use the LSB to store the marker
				size_t length() const @safe @nogc { return _length >> 8 * E.sizeof; }
				void length(size_t s) @safe @nogc { _length = Marker.isRefCounted | (s << (8 * E.sizeof)); }
			}
			else version (LittleEndian)
			{
				// Use the MSB to store the marker
				private enum size_t mask = size_t(E.max) << (8 * (size_t.sizeof - E.sizeof));
				size_t length() const @safe @nogc { return _length & ~mask; }
				void length(size_t s) @safe @nogc { assert(s <= maxLarge); _length = s | mask; }
			}
			else
			{
				static assert(0, "Unspecified endianness.");
			}
		}
		else
		{
			// No tricks needed, store the size plainly
			size_t _length;
			size_t length() const @safe @nogc
			{
				return _length;
			}
			void length(size_t s) @safe @nogc
			{
				_length = s;
			}
		}
		// </layout>

		// Get length
		alias opDollar = length;

		// Initializes a Large given capacity and content. Capacity must be at least as large as content's size.
		this(in size_t capacity, const(ME)[] content)
		{
			assert(capacity >= content.length);
			mbuf = RCBuffer.make(capacity, content);
			mptr = mbuf.mptr;
			length = content.length;
		}

		// Initializes a Large from a string by copying it.
		this(const(ME)[] s)
		{
			this(s.length, s);
		}

		static if (isString) unittest
		{
			const(ME)[] s1 = "hello, world";
			auto lrg1 = Large(s1);
			assert(lrg1.length == 12);
			immutable lrg2 = immutable Large(s1);
			assert(lrg2.length == 12);
			const lrg3 = const Large(s1);
			assert(lrg3.length == 12);
		}

		// Initializes a Large from a static string by referring to it.
		this(immutable(ME)[] s)
		{
			assert(buf is null);
			ptr = s.ptr;
			length = s.length;
		}

		static if (isString) unittest
		{
			immutable ME[] s = "abcdef";
			auto lrg1 = Large(s);
			assert(lrg1.length == 6);
			assert(lrg1.buf is null);
		}

		// Decrements the reference count and frees buf if it goes down to zero.
		void decRef() nothrow
		{
			if (!mbuf) return;
			if (mbuf.refCount == 1) realloc(mbuf, 0);
			else --mbuf.refCount;
		}

		auto opSlice() inout return
		{
			assert(ptr);
			return ptr[0 .. length];
		}

		// Makes sure there's room for at least newCap Chars.
		void reserve(in size_t newCapacity)
		{
			if (mbuf && mbuf.refCount == 1 && mbuf.capacity >= newCapacity) return;
			immutable size = this.length;
			version (assert) scope(exit) assert(size == this.length);
			if (!mbuf)
			{
				// Migrate from static string to allocated string
				mbuf = RCBuffer.make(newCapacity, ptr[0 .. size]);
				ptr = mbuf.ptr;
				return;
			}
			if (mbuf.refCount > 1)
			{
				// Split this guy making its buffer unique
				--mbuf.refCount;
				mbuf = RCBuffer.make(newCapacity, ptr[0 .. size]);
				ptr = mbuf.ptr;
				// size stays untouched
			}
			else
			{
				immutable offset = ptr - mbuf.ptr;
				// If offset is too large, it's worth decRef()ing and then allocating a new buffer
				if (offset * 2 >= newCapacity)
				{
					auto newBuf = RCBuffer.make(newCapacity, ptr[0 .. size]);
					decRef;
					mbuf = newBuf;
					ptr = mbuf.ptr;
				}
				else
				{
					RCBuffer.resize(mbuf, newCapacity);
					ptr = mbuf.ptr + offset;
				}
			}
		}

		unittest
		{
			Large obj;
			obj.reserve(1);
			assert(obj.mbuf !is null);
			assert(obj.mbuf.capacity >= 1);
			obj.reserve(1000);
			assert(obj.mbuf.capacity >= 1000);
			obj.reserve(10000);
			assert(obj.mbuf.capacity >= 10000);
		}
	}

	// <layout>
	union
	{
		Large large;
		struct
		{
			union
			{
				E[maxSmallSize] small;
				ME[maxSmallSize] msmall;
			}
			ME smallLength;
		}
		size_t[(maxSmallSize + 1) / size_t.sizeof] ancillary; // used internally
	}
	// </layout>

	hash_t toHash() const @trusted
	{
		import core.internal.hash : hashOf;
		return this.asSlice.hashOf;
	}

	static if (isString) unittest
	{
		assert(RCXString("a").toHash ==
			   RCXString("a").toHash);
		assert(RCXString("a").toHash !=
			   RCXString("b").toHash);
		assert(RCXString("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").toHash ==
			   RCXString("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").toHash);
		assert(RCXString("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa").toHash !=
			   RCXString("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb").toHash);
	}

	static if (isString) unittest
	{
		RCXString x;
		assert(x.smallLength == 0);
		assert(x.length == 0);
		x.large.length = 133;
		assert(x.smallLength == E.max);
		assert(x.large.length == 133);
		x.large.length = 0x0088_8888_8888_8888;
		assert(x.large.length == 0x0088_8888_8888_8888);
		assert(x.smallLength == E.max);
	}

	// is this string small?
	bool isSmall() const @safe @nogc
	{
		return smallLength <= maxSmallSize;
	}

	// release all memory associated with this
	private void decRef() @nogc
	{
		if (!isSmall) large.decRef;
	}

	// Return a slice with the string's contents
	// Not public because it leaks the internals
	auto asSlice() inout @nogc
	{
		immutable s = smallLength;
		if (s <= maxSmallSize) return small.ptr[0 .. s];
		return large[];
	}

public:

	/// Returns the length of the string
	size_t length() const @nogc
	{
		immutable s = smallLength;
		return s <= maxSmallSize ? s : large.length;
	}
	/// Ditto
	alias opDollar = length;

	static if (isString) unittest
	{
		auto s1 = RCXString("123456789_");
		assert(s1.length == 10);
		s1 ~= RCXString("123456789_123456789_123456789_123456789_12345");
		assert(s1.length == 55);
	}

	/// Needed for correct printing in other modules
	static if (isString)
	{
		string toArray() const @trusted
		{
			return this.asSlice;
		}
	}

	/** Construct a `RCXString` from a slice `s`.

		If the slice is immutable, assumes the slice is a literal or
		GC-allocated and does NOT copy it internally.

		Warning: Subsequently deallocating `s` will cause the `RCXString`
		to dangle. If the slice has `const` or mutable characters, creates
		and manages a copy internally.
	 */
	this(C)(C[] s)
		if (is(Unqual!C == ME))
	{
		// Contents is immutable, we may assume it won't go away ever
		if (s.length <= maxSmallSize)
		{
			// fits in small
			small[0 .. s.length] = s[]; // so copy it
			smallLength = cast(E)s.length;
		}
		else
		{
			emplace(&large, s);
		}
	}

	// Test construction from immutable(ME)[], const(ME)[], and ME[]
	static if (isString) unittest
	{
		immutable(E)[] a = "123456789_";
		auto s1 = RCXString(a);
		assert(s1 == a);
		assert(s1.asSlice !is a, "Small strings must be copied");
		a = "123456789_123456789_123456789_123456789_";
		auto s2 = RCXString(a);
		assert(s2 == a);
		assert(s2.asSlice is a, "Large immutable strings shall not be copied");

		const(char)[] b = "123456789_";
		auto s3 = RCXString(b);
		assert(s3 == b);
		assert(s3.isSmall, "Small strings must be copied");
		b = "123456789_123456789_123456789_123456789_";
		auto s4 = RCXString(b);
		assert(s4 == b);
		assert(s4.asSlice !is b, "Large non-immutable strings shall be copied");

		char[] c = "123456789_".dup;
		auto s5 = RCXString(c);
		assert(s5 == c);
		assert(s5.isSmall, "Small strings must be copied");
		c = "123456789_123456789_123456789_123456789_".dup;
		auto s6 = RCXString(c);
		assert(s6 == c);
		assert(s6.asSlice !is c, "Large non-immutable strings shall be copied");
	}

	static if (isString) unittest
	{
		const(ME)[] s = "123456789_123456789_123456789_123456789_";
		auto s1 = RCXString(s);
		assert(s1.large.mbuf);
		auto s2 = s1;
		assert(s1.large.mbuf is s2.large.mbuf);
		assert(s1.large.mbuf.refCount == 2);
		s1 = s ~ "123";
		assert(s1.large.mbuf.refCount == 1);
		assert(s2.large.mbuf.refCount == 1);
		assert(s2 == s);
		assert(s1 == s ~ "123");
		const s3 = s1;
		assert(s1.large.mbuf.refCount == 2);
		immutable s4 = s1;
		//immutable s5 = s3;
		assert(s1.large.mbuf.refCount == 3);
	}

	// Postblit
	this(this) @nogc
	{
		if (!isSmall && large.mbuf) ++large.mbuf.refCount;
	}

	// Dtor decrements refcount and may deallocate
	~this() nothrow @nogc
	{
		decRef;
	}

	// Assigns another string
	void opAssign(immutable(ME)[] s)
	{
		decRef;
		// Contents is immutable, we may assume it won't go away ever
		emplace(&this, s);
	}

	static if (isString) unittest
	{
		immutable(ME)[] s = "123456789_";
		RCXString rcs;
		rcs = s;
		assert(rcs.isSmall);
		s = "123456789_123456789_123456789_123456789_";
		rcs = s;
		assert(!rcs.isSmall);
		assert(rcs.large.mbuf is null);
	}

	// Assigns another string
	void opAssign(const(ME)[] s)
	{
		if (capacity >= s.length)
		{
			// Noice, there's room
			if (s.length <= maxSmallSize)
			{
				// Fits in small
				msmall[0 .. s.length] = s[];
				smallLength = cast(E) s.length;
			}
			else
			{
				// Large it is
				assert(!isSmall);
				large.mptr[0 .. s.length] = s;
				large.length = s.length;
			}
		}
		else
		{
			// Tear down and rebuild
			decRef;
			emplace(&this, s);
		}
	}

	static if (isString) unittest
	{
		const(ME)[] s = "123456789_123456789_123456789_123456789_";
		RCXString s1;
		s1 = s;
		assert(!s1.isSmall && s1.large.buf !is null);
		auto p = s1.ptr;
		s1 = s;
		assert(s1.ptr is p, "Wasteful reallocation");
		RCXString s2;
		s2 = s1;
		assert(s1.large.mbuf is s2.large.mbuf);
		assert(s1.large.mbuf.refCount == 2);
		s1 = "123456789_123456789_123456789_123456789_123456789_";
		assert(s1.large.mbuf !is s2.large.mbuf);
		assert(s1.large.mbuf is null);
		assert(s2.large.mbuf.refCount == 1);
		assert(s1 == "123456789_123456789_123456789_123456789_123456789_");
		assert(s2 == "123456789_123456789_123456789_123456789_");
	}

	bool opEquals(const(ME)[] s) const @nogc
	{
		if (isSmall) return s.length == smallLength && small[0 .. s.length] == s;
		return large[] == s;
	}

	bool opEquals(in RCXString s) const => this == s.asSlice;

	static if (isString) unittest
	{
		const s1 = RCXString("123456789_123456789_123456789_123456789_123456789_");
		RCXString s2 = s1[0 .. 10];
		auto s3 = RCXString("123456789_");
		assert(s2 == s3);
	}

	/** Returns the maximum number of character this string can store without
		requesting more memory.
	 */
	size_t capacity() const @property @nogc
	{
		/** This is subtle: if large.mbuf is null (i.e. the string had been constructed from a literal), then the
			capacity is maxSmallSize because that's what we can store without a memory (re)allocation. Same if refCount is
			greater than 1 - we can't reuse the memory.
		*/
		return isSmall || !large.mbuf || large.mbuf.refCount > 1 ? maxSmallSize : large.mbuf.capacity;
	}

	static if (isString) unittest
	{
		auto s = RCXString("abc");
		assert(s.capacity == maxSmallSize);
		s = "123456789_123456789_123456789_123456789_123456789_";
		assert(s.capacity == maxSmallSize);
		const char[] lit = "123456789_123456789_123456789_123456789_123456789_";
		s = lit;
		assert(s.capacity >= 50);
	}

	void reserve(in size_t capacity)
	{
		if (isSmall)
		{
			if (capacity <= maxSmallSize)
			{
				// stays small
				return;
			}
			// small to large
			immutable length = smallLength;
			auto newLayout = Large(capacity, small.ptr[0 .. length]);
			large = newLayout;
		}
		else
		{
			// large to large
			if (large.mbuf && large.mbuf.capacity >= capacity) return;
			large.reserve(capacity);
		}
	}

	static if (isString) unittest
	{
		RCXString s1;
		s1.reserve(1);
		assert(s1.capacity >= 1);
		s1.reserve(1023);
		assert(s1.capacity >= 1023);
		s1.reserve(10230);
		assert(s1.capacity >= 10230);
	}

	/** Appends `s` to `this`.
	 */
	void opOpAssign(string s : "~")(const(ME)[] s)
	{
		immutable length = this.length;
		immutable newLen = length + s.length;
		if (isSmall)
		{
			if (newLen <= maxSmallSize)
			{
				// stays small
				msmall[length .. newLen] = s;
				smallLength = cast(E) newLen;
			}
			else
			{
				// small to large
				auto newLayout = Large(newLen, small.ptr[0 .. length]);
				newLayout.mptr[length .. newLen][] = s;
				newLayout.length = newLen;
				large = newLayout;
				assert(!isSmall);
				assert(this.length == newLen);
			}
		}
		else
		{
			// large to large
			large.reserve(newLen);
			large.mptr[length .. newLen][] = s;
			large.length = newLen;
		}
	}

	static if (isString) unittest
	{
		auto s1 = RCXString("123456789_123456789_123456789_123456789_");
		s1 ~= s1;
		assert(s1 == "123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_");
		foreach (i; 0 .. 70) s1.popFront();
		assert(s1 == "123456789_");
		s1 ~= "abc";
		assert(s1 == "123456789_abc");
	}

	/// Ditto
	void opOpAssign(string s : "~")(const auto ref RCXString s)
	{
		this ~= s.asSlice;
	}

	static if (isString) unittest
	{
		RCXString s1;
		s1 = "hello";
		assert(s1 == "hello");
		s1 ~= ", world! ";
		assert(s1 == "hello, world! ");
		s1 ~= s1;
		assert(s1 == "hello, world! hello, world! ");
		s1 ~= s1;
		assert(s1 == "hello, world! hello, world! hello, world! hello, world! ");
		auto s2 = RCXString("yah! ");
		assert(s2 == "yah! ");
		s2 ~= s1;
		assert(s2 == "yah! hello, world! hello, world! hello, world! hello, world! ");
		s2 = "123456789_123456789_123456789_123456789_";
		s2 ~= s2;
		assert(s2 == "123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_");
		auto s3 = s2;
		assert(s3.large.mbuf.refCount == 2);
		s2 ~= "123456789_";
		assert(s2.large.mbuf.refCount == 1);
		assert(s3.large.mbuf.refCount == 1);
		assert(s3 == "123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_");

		s2 = "123456789_123456789_123456789_123456789_";
		const s4 = RCXString(", world");
		s2 ~= s4;
		assert(s2 == "123456789_123456789_123456789_123456789_, world");
		s2 ~= const RCXString("!!!");
		assert(s2 == "123456789_123456789_123456789_123456789_, world!!!");
	}

	/// Returns `true` iff `this` is empty
	bool empty() const @property @nogc => !length;

	static if (isString)
	{
		private dchar unsafeDecode(const(ME)* p) const @nogc
		{
			byte c = *p;
			dchar res = c & 0b0111_1111;
			if (c >= 0) return res;
			assert(c < 0b1111_1000);
			dchar cover = 0b1000_0000;
			c <<= 1;
			assert(c < 0);
			do
			{
				++p;
				assert((*p >> 6) == 0b10);
				cover <<= 5;
				res = (res << 6) ^ *p ^ cover ^ 0b1000_0000;
				c <<= 1;
			} while(c < 0);
			return res;
		}
	}

	/// Returns the first code point of `this`.
	auto front() const @property @nogc in(!empty)
	{
		/+ TODO: make safe +/
		static if (isString)
			return unsafeDecode(ptr);
		else
			return ptr[0];
	}

	/// Returns the last code point of `this`.
	static if (isString)
	{
		dchar back() const @property @nogc in(!empty)
		{
			auto p = ptr + length - 1;
			if (*p < 0b1000_0000)
				return *p;
			/+ TODO: make safe +/
			do
			{
				--p;
			} while (!(*p & 0b0100_0000));
			return unsafeDecode(p);
		}
	}
	else
		E back() const @property @nogc => ptr[length - 1];

	/// Returns the `n`th code unit in `this`.
	E opIndex(size_t n) const @nogc in(n < length) => ptr[n];

	static if (isString) unittest
	{
		auto s1 = RCXString("hello");
		assert(s1.front == 'h');
		assert(s1[1] == 'e');
		assert(s1.back == 'o');
		assert(s1[$ - 1] == 'o');
		s1 = RCXString("Ü");
		assert(s1.length == 2);
		assert(s1.front == 'Ü');
		assert(s1.back == 'Ü');
	}

	/// Discards the first code point
	void popFront() @nogc
	{
		assert(!empty && ptr);
		uint toPop = 1;
		auto b = *ptr;
		if (b >= 0b1000_0000)
		{
			toPop = (b | 0b0010_0000) != b ? 2
				: (b | 0b0001_0000) != b ? 3
				: 4;
		}
		if (isSmall)
		{
			// Must shuffle in place
			/+ TODO: make faster +/
			foreach (i; 0 .. length - toPop)
				msmall[i] = small[i + toPop];
			smallLength -= toPop;
		}
		else
		{
			large.ptr += toPop;
			large.length = large.length - toPop;
		}
	}

	static if (isString) unittest
	{
		auto s1 = RCXString("123456789_");
		auto s2 = s1;
		s1.popFront();
		assert(s1 == "23456789_");
		assert(s2 == "123456789_");
		s1 = RCXString("123456789_123456789_123456789_123456789_");
		s2 = s1;
		s1.popFront();
		assert(s1 == "23456789_123456789_123456789_123456789_");
		assert(s2 == "123456789_123456789_123456789_123456789_");
		s1 = "öü";
		s2 = s1;
		s1.popFront();
		assert(s1 == "ü");
		assert(s2 == "öü");
	}

	/// Discards the last code point
	void popBack() @nogc
	{
		assert(!empty && ptr);
		auto p = ptr + length - 1;
		if (*p < 0b1000_0000)
		{
			// hot path
			if (isSmall) --smallLength;
			else large.length = large.length - 1;
			return;
		}
		/+ TODO: make safe +/
		auto p1 = p;
		do
		{
			--p;
		} while (!(*p & 0b0100_0000));
		immutable diff = p1 - p + 1;
		assert(diff > 1 && diff <= length);
		if (isSmall) smallLength -= diff;
		else large.length = large.length - diff;
	}

	static if (isString) unittest
	{
		auto s1 = RCXString("123456789_");
		auto s2 = s1;
		s1.popBack;
		assert(s1 == "123456789");
		assert(s2 == "123456789_");
		s1 = RCXString("123456789_123456789_123456789_123456789_");
		s2 = s1;
		s1.popBack;
		assert(s1 == "123456789_123456789_123456789_123456789");
		assert(s2 == "123456789_123456789_123456789_123456789_");
		s1 = "öü";
		s2 = s1;
		s1.popBack;
		assert(s1 == "ö");
		assert(s2 == "öü");
	}

	/// Returns a slice to the entire string or a portion of it.
	auto opSlice() inout @nogc
	{
		return this;
	}

	/// Ditto
	auto opSlice(size_t b, size_t e) inout
	{
		assert(b <= e && e <= length);
		auto ptr = this.ptr;
		auto sz = e - b;
		if (sz <= maxSmallSize)
		{
			// result is small
			RCXString result = void;
			result.msmall[0 .. sz] = ptr[b .. e];
			result.smallLength = cast(E) sz;
			return result;
		}
		assert(!isSmall);
		RCXString result = this;
		result.large.ptr += b;
		result.large.length = e - b;
		return result;
	}

	static if (isString) unittest
	{
		immutable s = RCXString("123456789_123456789_123456789_123456789");
		RCXString s1 = s[0 .. 38];
		assert(!s1.isSmall && s1.large.buf is null);
	}

	// Unsafe! Returns a pointer to the beginning of the payload.
	auto ptr() inout @nogc
	{
		return isSmall ? small.ptr : large.ptr;
	}

	static if (isString) unittest
	{
		auto s1 = RCXString("hello");
		auto s2 = s1[1 .. $ - 1];
		assert(s2 == "ell");
		s1 = "123456789_123456789_123456789_123456789_";
		s2 = s1[1 .. $ - 1];
		assert(s2 == "23456789_123456789_123456789_123456789");
	}

	/// Returns the concatenation of `this` with `s`.
	RCXString opBinary(string s = "~")(const auto ref RCXString s) const
	{
		return this ~ s.asSlice;
	}

	/// Ditto
	RCXString opBinary(string s = "~")(const(ME)[] s) const
	{
		immutable length = this.length;
		auto resultLen = length + s.length;
		RCXString result = void;
		if (resultLen <= maxSmallSize)
		{
			// noice
			result.msmall.ptr[0 .. length] = ptr[0 .. length];
			result.msmall.ptr[length .. resultLen] = s[];
			result.smallLength = cast(E) resultLen;
			return result;
		}
		emplace(&result.large, resultLen, this.asSlice);
		result ~= s;
		return result;
	}

	/// Returns the concatenation of `s` with `this`.
	RCXString opBinaryRight(string s = "~")(const(E)[] s) const
	{
		immutable length = this.length, resultLen = length + s.length;
		RCXString result = void;
		if (resultLen <= maxSmallSize)
		{
			// noice
			result.msmall.ptr[0 .. s.length] = s[];
			result.msmall.ptr[s.length .. resultLen] = small.ptr[0 .. length];
			result.smallLength = cast(E) resultLen;
			return result;
		}
		emplace(&result.large, resultLen, s);
		result ~= this;
		return result;
	}

	static if (isString) unittest
	{
		auto s1 = RCXString("hello");
		auto s2 = s1 ~ ", world!";
		assert(s2 == "hello, world!");
		s1 = "123456789_123456789_123456789_123456789_";
		s2 = s1 ~ "abcdefghi_";
		assert(s2 == "123456789_123456789_123456789_123456789_abcdefghi_");
		s2 = s1 ~ s1;
		assert(s2 == "123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_");
		s2 = "abcdefghi_" ~ s1;
		assert(s2 == "abcdefghi_123456789_123456789_123456789_123456789_");
	}
}

unittest {
	alias RCI = RCXString!(immutable uint);
	RCI x;
}

/// verify UTF-8 storage
unittest {
	string s = "åäö";
	RCString rcs = s;
	assert(rcs.length == 6);
	import std.algorithm : count;
	assert(rcs.count == 3);
	assert(rcs.front == 'å');
	rcs.popFront();
	assert(rcs.front == 'ä');
	rcs.popFront();
	assert(rcs.front == 'ö');
	rcs.popFront();
	assert(rcs.empty);
}

version = profile;

/// shows performance increase for SSO over built-in string
version (profile) unittest {
	enum maxSmallSize = 23;
	alias S = RCXString!(immutable char, maxSmallSize);

	import std.datetime: StopWatch, Duration;
	import std.conv : to;
	import std.stdio;

	enum n = 2^^21;

	StopWatch sw;

	sw.reset;
	sw.start;
	char[maxSmallSize] ss;
	foreach (i; 0 .. n)
	{
		auto x = S(ss);
	}
	sw.stop;
	auto timeRCString = sw.peek().msecs;
	writeln("> RCString took ", sw.peek().to!Duration);

	sw.reset;
	sw.start;
	foreach (i; 0 .. n)
	{
		string x = ss.idup;
	}
	sw.stop;
	auto timeString = sw.peek().msecs;
	writeln("> Builtin string took ", sw.peek().to!Duration);

	writeln("> Speedup: ", timeString/timeRCString);
}
