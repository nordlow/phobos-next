module nxt.storage;

/// Large array storage.
static struct Large(E, bool useGCallocation)
{
	E* ptr;
	size_t length;

	import core.exception : onOutOfMemoryError;
	static if (useGCallocation)
	{
		import core.memory : GC;
	}
	else
	{
		import core.memory : malloc = pureMalloc, realloc = pureRealloc;
	}

	pure nothrow:

	static if (useGCallocation)
	{
		this(size_t n)
		{
			length = n;
			ptr = cast(E*)GC.malloc(E.sizeof * length);
			if (length >= 1 && ptr is null)
			{
				onOutOfMemoryError();
			}
		}
		void resize(size_t n)
		{
			length = n;
			ptr = cast(E*)GC.realloc(ptr, E.sizeof * length);
			if (length >= 1 && ptr is null)
			{
				onOutOfMemoryError();
			}
		}
		void clear()
		{
			GC.free(ptr);
			debug ptr = null;
		}
	}
	else
	{
		@nogc:
		this(size_t n)
		{
			length = n;
			ptr = cast(E*)malloc(E.sizeof * length);
			if (length >= 1 && ptr is null)
			{
				onOutOfMemoryError();
			}
		}
		void resize(size_t n)
		{
			length = n;
			ptr = cast(E*)realloc(ptr, E.sizeof * length);
			if (length >= 1 && ptr is null)
			{
				onOutOfMemoryError();
			}
		}
		void clear()
		{
			import nxt.qcmeman : free;
			free(ptr);
			debug ptr = null;
		}
	}
}

/// Small array storage.
alias Small(E, size_t n) = E[n];

/// Small-size-optimized (SSO) array store.
static struct Store(E, bool useGCallocation = false)
{
	/** Fixed number elements that fit into small variant storage. */
	enum smallLength = Large!(E, useGCallocation).sizeof / E.sizeof;

	/** Maximum number elements that fit into large variant storage. */
	enum maxLargeLength = size_t.max >> 8;

	/// Destruct.
	~this() nothrow @trusted @nogc
	{
		if (isLarge) { large.clear; }
	}

	/// Get currently length at `ptr`.
	size_t length() const @trusted pure nothrow @nogc
	{
		return isLarge ? large.length : smallLength;
	}

	/// Returns: `true` iff is small packed.
	bool isSmall() const pure nothrow @safe @nogc { return !isLarge; }

private:

	/// Reserve length to `n` elements starting at `ptr`.
	size_t reserve(size_t n) pure nothrow @trusted
	{
		if (isLarge)		// currently large
		{
			if (n > smallLength) // large => large
				large.resize(n);
			else				// large => small
			{
				// large => tmp

				// temporary storage for small
				debug { typeof(small) tmp; }
				else  { typeof(small) tmp = void; }

				tmp[0 .. n] = large.ptr[0 .. n]; // large to temporary
				tmp[n .. $] = 0; // zero remaining

				// empty large
				large.clear();

				// tmp => small
				small[] = tmp[0 .. smallLength];

				isLarge = false;
			}
		}
		else					// currently small
		{
			if (n > smallLength) // small => large
			{
				typeof(small) tmp = small; // temporary storage for small

				import core.lifetime : emplace;
				emplace(&large, n);

				large.ptr[0 .. length] = tmp[0 .. length]; // temporary to large

				isLarge = true;					  // tag as large
			}
			else {}			   // small => small
		}
		return length;
	}

	/// Get pointer.
	auto ptr() pure nothrow @nogc
	{
		import nxt.container.traits : ContainerElementType;
		alias ET = ContainerElementType!(typeof(this), E);
		return isLarge ? cast(ET*)large.ptr : cast(ET*)&small;
	}

	/// Get slice.
	auto ref slice() pure nothrow @nogc
	{
		return ptr[0 .. length];
	}

	union
	{
		Small!(E, smallLength) small; // small variant
		Large!(E, useGCallocation) large;		  // large variant
	}
	bool isLarge;			   /+ TODO: make part of union as in rcstring.d +/
}

/// Test `Store`.
static void storeTester(E, bool useGCallocation)()
{
	Store!(E, useGCallocation) si;

	assert(si.ptr !is null);
	assert(si.slice.ptr !is null);
	assert(si.slice.length != 0);
	assert(si.length == si.smallLength);

	si.reserve(si.smallLength);	 // max small
	assert(si.length == si.smallLength);
	assert(si.isSmall);

	si.reserve(si.smallLength + 1); // small to large
	assert(si.length == si.smallLength + 1);
	assert(si.isLarge);

	si.reserve(si.smallLength * 8); // small to large
	assert(si.length == si.smallLength * 8);
	assert(si.isLarge);

	si.reserve(si.smallLength);	 // max small
	assert(si.length == si.smallLength);
	assert(si.isSmall);

	si.reserve(0);
	assert(si.length == si.smallLength);
	assert(si.isSmall);

	si.reserve(si.smallLength + 1);
	assert(si.length == si.smallLength + 1);
	assert(si.isLarge);

	si.reserve(si.smallLength);
	assert(si.length == si.smallLength);
	assert(si.isSmall);

	si.reserve(si.smallLength - 1);
	assert(si.length == si.smallLength);
	assert(si.isSmall);
}

pure nothrow @nogc unittest {
	import std.meta : AliasSeq;
	foreach (E; AliasSeq!(char, byte, short, int))
	{
		storeTester!(E, false);
	}
}

pure nothrow unittest {
	import std.meta : AliasSeq;
	foreach (E; AliasSeq!(char, byte, short, int))
	{
		storeTester!(E, true);
	}
}
