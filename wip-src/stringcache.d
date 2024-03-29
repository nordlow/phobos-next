module nxt.stringcache;

/**
 * The string cache is used for string interning.
 *
 * It will only story a single copy of any string that it is asked to hold.
 * Interned strings can be compared for equality by comparing their $(B .ptr)
 * field.
 *
 * Default and postbilt constructors are disabled. When a StringCache goes out
 * of scope, the memory held by it is freed.
 *
 * See_Also: $(LINK http://en.wikipedia.org/wiki/String_interning)
 */
struct StringCache
{
public:

	@disable this();
	this(this) @disable;

	/**
	 * Params: bucketCount = the initial number of buckets. Must be a
	 * power of two
	 */
	this(size_t bucketCount)
	{
		buckets = (cast(Node**) calloc((Node*).sizeof, bucketCount))[0 .. bucketCount];
	}

	~this() nothrow @nogc
	{
		Block* current = rootBlock;
		while (current !is null)
		{
			Block* prev = current;
			current = current.next;
			free(cast(void*) prev.bytes.ptr);
			free(cast(void*) prev);
		}
		foreach (nodePointer; buckets)
		{
			Node* currentNode = nodePointer;
			while (currentNode !is null)
			{
				Node* prev = currentNode;
				currentNode = currentNode.next;
				free(prev);
			}
		}
		rootBlock = null;
		free(buckets.ptr);
		buckets = null;
	}

	/**
	 * Caches a string.
	 */
	string intern(const(ubyte)[] str) pure nothrow @safe
	{
		if (str is null || str.length == 0)
			return "";
		immutable uint hash = hashBytes(str);
		return intern(str, hash);
	}

	/**
	 * ditto
	 */
	string intern(string str) pure nothrow @trusted
	{
		return intern(cast(ubyte[]) str);
	}

	/**
	 * Caches a string as above, but uses the given hash code instead of
	 * calculating one itself. Use this alongside $(LREF hashStep)() can reduce the
	 * amount of work necessary when lexing dynamic tokens.
	 */
	string intern(const(ubyte)[] str, uint hash) pure nothrow @safe
		in
		{
			assert (str.length > 0);
		}
	do
	{
		return _intern(str, hash);
//		string s = _intern(str, hash);
//		size_t* ptr = s in debugMap;
//		if (ptr is null)
//			debugMap[s] = cast(size_t) s.ptr;
//		else
//			assert (*ptr == cast(size_t) s.ptr);
//		return s;
	}

	/**
	 * Incremental hashing.
	 * Params:
	 *	 b = the byte to add to the hash
	 *	 h = the hash that has been calculated so far
	 * Returns: the new hash code for the string.
	 */
	static uint hashStep(ubyte b, uint h) pure nothrow @safe
	{
		return (h ^ sbox[b]) * 3;
	}

	/**
	 * The default bucket count for the string cache.
	 */
	static enum defaultBucketCount = 4096;

	size_t allocated() pure nothrow @safe @property
	{
		return _allocated;
	}

private:

	string _intern(const(ubyte)[] bytes, uint hash) pure nothrow @trusted
	{
		if (bytes is null || bytes.length == 0)
			return "";
		immutable size_t index = hash & (buckets.length - 1);
		Node* s = find(bytes, hash);
		if (s !is null)
			return cast(string) s.str;
		_allocated += bytes.length;
		ubyte[] mem = allocate(bytes.length);
		mem[] = bytes[];
		Node* node = cast(Node*) malloc(Node.sizeof);
		node.str = mem;
		node.hash = hash;
		node.next = buckets[index];
		buckets[index] = node;
		return cast(string) mem;
	}

	Node* find(const(ubyte)[] bytes, uint hash) pure nothrow @trusted
	{
		import std.algorithm;
		immutable size_t index = hash & (buckets.length - 1);
		Node* node = buckets[index];
		while (node !is null)
		{
			if (node.hash == hash && bytes.equal(cast(ubyte[]) node.str))
				return node;
			node = node.next;
		}
		return node;
	}

	static uint hashBytes(const(ubyte)[] data) pure nothrow @trusted
		in
		{
			assert (data !is null);
			assert (data.length > 0);
		}
	do
	{
		uint hash = 0;
		foreach (ubyte b; data)
		{
			hash ^= sbox[b];
			hash *= 3;
		}
		return hash;
	}

	ubyte[] allocate(size_t numBytes) pure nothrow @trusted
		in
		{
			assert (numBytes != 0);
		}
	out (result)
		{
			assert (result.length == numBytes);
		}
	do
	{
		if (numBytes > (blockSize / 4))
			return (cast(ubyte*) malloc(numBytes))[0 .. numBytes];
		Block* r = rootBlock;
		size_t i = 0;
		while  (i <= 3 && r !is null)
		{

			immutable size_t available = r.bytes.length;
			immutable size_t oldUsed = r.used;
			immutable size_t newUsed = oldUsed + numBytes;
			if (newUsed <= available)
			{
				r.used = newUsed;
				return r.bytes[oldUsed .. newUsed];
			}
			i++;
			r = r.next;
		}
		Block* b = cast(Block*) malloc(Block.sizeof);
		b.bytes = (cast(ubyte*) malloc(blockSize))[0 .. blockSize];
		b.used = numBytes;
		b.next = rootBlock;
		rootBlock = b;
		return b.bytes[0 .. numBytes];
	}

	static struct Node
	{
		ubyte[] str;
		uint hash;
		Node* next;
	}

	static struct Block
	{
		ubyte[] bytes;
		size_t used;
		Block* next;
	}

	static enum blockSize = 1024 * 16;

	static immutable uint[] sbox = [
		0xF53E1837, 0x5F14C86B, 0x9EE3964C, 0xFA796D53,
		0x32223FC3, 0x4D82BC98, 0xA0C7FA62, 0x63E2C982,
		0x24994A5B, 0x1ECE7BEE, 0x292B38EF, 0xD5CD4E56,
		0x514F4303, 0x7BE12B83, 0x7192F195, 0x82DC7300,
		0x084380B4, 0x480B55D3, 0x5F430471, 0x13F75991,
		0x3F9CF22C, 0x2FE0907A, 0xFD8E1E69, 0x7B1D5DE8,
		0xD575A85C, 0xAD01C50A, 0x7EE00737, 0x3CE981E8,
		0x0E447EFA, 0x23089DD6, 0xB59F149F, 0x13600EC7,
		0xE802C8E6, 0x670921E4, 0x7207EFF0, 0xE74761B0,
		0x69035234, 0xBFA40F19, 0xF63651A0, 0x29E64C26,
		0x1F98CCA7, 0xD957007E, 0xE71DDC75, 0x3E729595,
		0x7580B7CC, 0xD7FAF60B, 0x92484323, 0xA44113EB,
		0xE4CBDE08, 0x346827C9, 0x3CF32AFA, 0x0B29BCF1,
		0x6E29F7DF, 0xB01E71CB, 0x3BFBC0D1, 0x62EDC5B8,
		0xB7DE789A, 0xA4748EC9, 0xE17A4C4F, 0x67E5BD03,
		0xF3B33D1A, 0x97D8D3E9, 0x09121BC0, 0x347B2D2C,
		0x79A1913C, 0x504172DE, 0x7F1F8483, 0x13AC3CF6,
		0x7A2094DB, 0xC778FA12, 0xADF7469F, 0x21786B7B,
		0x71A445D0, 0xA8896C1B, 0x656F62FB, 0x83A059B3,
		0x972DFE6E, 0x4122000C, 0x97D9DA19, 0x17D5947B,
		0xB1AFFD0C, 0x6EF83B97, 0xAF7F780B, 0x4613138A,
		0x7C3E73A6, 0xCF15E03D, 0x41576322, 0x672DF292,
		0xB658588D, 0x33EBEFA9, 0x938CBF06, 0x06B67381,
		0x07F192C6, 0x2BDA5855, 0x348EE0E8, 0x19DBB6E3,
		0x3222184B, 0xB69D5DBA, 0x7E760B88, 0xAF4D8154,
		0x007A51AD, 0x35112500, 0xC9CD2D7D, 0x4F4FB761,
		0x694772E3, 0x694C8351, 0x4A7E3AF5, 0x67D65CE1,
		0x9287DE92, 0x2518DB3C, 0x8CB4EC06, 0xD154D38F,
		0xE19A26BB, 0x295EE439, 0xC50A1104, 0x2153C6A7,
		0x82366656, 0x0713BC2F, 0x6462215A, 0x21D9BFCE,
		0xBA8EACE6, 0xAE2DF4C1, 0x2A8D5E80, 0x3F7E52D1,
		0x29359399, 0xFEA1D19C, 0x18879313, 0x455AFA81,
		0xFADFE838, 0x62609838, 0xD1028839, 0x0736E92F,
		0x3BCA22A3, 0x1485B08A, 0x2DA7900B, 0x852C156D,
		0xE8F24803, 0x00078472, 0x13F0D332, 0x2ACFD0CF,
		0x5F747F5C, 0x87BB1E2F, 0xA7EFCB63, 0x23F432F0,
		0xE6CE7C5C, 0x1F954EF6, 0xB609C91B, 0x3B4571BF,
		0xEED17DC0, 0xE556CDA0, 0xA7846A8D, 0xFF105F94,
		0x52B7CCDE, 0x0E33E801, 0x664455EA, 0xF2C70414,
		0x73E7B486, 0x8F830661, 0x8B59E826, 0xBB8AEDCA,
		0xF3D70AB9, 0xD739F2B9, 0x4A04C34A, 0x88D0F089,
		0xE02191A2, 0xD89D9C78, 0x192C2749, 0xFC43A78F,
		0x0AAC88CB, 0x9438D42D, 0x9E280F7A, 0x36063802,
		0x38E8D018, 0x1C42A9CB, 0x92AAFF6C, 0xA24820C5,
		0x007F077F, 0xCE5BC543, 0x69668D58, 0x10D6FF74,
		0xBE00F621, 0x21300BBE, 0x2E9E8F46, 0x5ACEA629,
		0xFA1F86C7, 0x52F206B8, 0x3EDF1A75, 0x6DA8D843,
		0xCF719928, 0x73E3891F, 0xB4B95DD6, 0xB2A42D27,
		0xEDA20BBF, 0x1A58DBDF, 0xA449AD03, 0x6DDEF22B,
		0x900531E6, 0x3D3BFF35, 0x5B24ABA2, 0x472B3E4C,
		0x387F2D75, 0x4D8DBA36, 0x71CB5641, 0xE3473F3F,
		0xF6CD4B7F, 0xBF7D1428, 0x344B64D0, 0xC5CDFCB6,
		0xFE2E0182, 0x2C37A673, 0xDE4EB7A3, 0x63FDC933,
		0x01DC4063, 0x611F3571, 0xD167BFAF, 0x4496596F,
		0x3DEE0689, 0xD8704910, 0x7052A114, 0x068C9EC5,
		0x75D0E766, 0x4D54CC20, 0xB44ECDE2, 0x4ABC653E,
		0x2C550A21, 0x1A52C0DB, 0xCFED03D0, 0x119BAFE2,
		0x876A6133, 0xBC232088, 0x435BA1B2, 0xAE99BBFA,
		0xBB4F08E4, 0xA62B5F49, 0x1DA4B695, 0x336B84DE,
		0xDC813D31, 0x00C134FB, 0x397A98E6, 0x151F0E64,
		0xD9EB3E69, 0xD3C7DF60, 0xD2F2C336, 0x2DDD067B,
		0xBD122835, 0xB0B3BD3A, 0xB0D54E46, 0x8641F1E4,
		0xA0B38F96, 0x51D39199, 0x37A6AD75, 0xDF84EE41,
		0x3C034CBA, 0xACDA62FC, 0x11923B8B, 0x45EF170A,
		];

//	deprecated size_t[string] debugMap;
	size_t _allocated;
	Node*[] buckets;
	Block* rootBlock;
}

private extern (C) void* calloc(size_t, size_t) nothrow pure @nogc;
private extern (C) void* malloc(size_t) nothrow pure @nogc;
private extern (C) void free(void*) nothrow pure @nogc;
