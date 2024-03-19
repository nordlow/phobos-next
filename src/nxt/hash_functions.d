/** Various hash functions, including integer ones.
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -mcpu=native -checkaction=context -debug -g -unittest -main -I.. -i -run hash_functions.d
 */
module nxt.hash_functions;

@safe nothrow:

/** See_Also: http://forum.dlang.org/post/o1igoc$21ma$1@digitalmars.com
 *
 * Doesn't work: integers are returned as is.
 */
pragma(inline, true)
size_t typeidHashOf(T)(in T x) @trusted => typeid(T).getHash(&x);

///
@safe nothrow unittest {
	scope x = typeidHashOf(cast(int)17);
}

pure @nogc:

pragma(inline, true)
hash_t hashOfTypeInfoPtr(TypeInfo_Class typeinfo) @trusted pure nothrow @nogc
in(typeof(typeinfo).alignof == 8)
	=> (cast(hash_t)(cast(void*)typeinfo) >> 3);

/** Hash that incorporates the hash of `typeid` bit-xored with `hashOf(a)`.
 *
 * See_Also: https://forum.dlang.org/post/lxqoknwuujbymolnlyfw@forum.dlang.org
 */
pragma(inline, true)
hash_t hashOfPolymorphic(Class)(Class a) @trusted pure nothrow @nogc
if (is(Class == class)) {
	static assert(typeid(Class).alignof == 8);
	// const class_typeid_hash = (cast(hash_t)(cast(void*)typeid(Class)) >> 3)
	return fibonacciHash(.hashOf(cast(void*)typeid(a))) ^ .hashOf(a);
}

pragma(inline, true)
size_t fibonacciHash(in hash_t hash) pure nothrow @safe @nogc
	=> (hash * 11400714819323198485LU);

version (unittest) {
	private static:
	class Thing {}
	class Expr : Thing {
		pure nothrow @safe @nogc:
		alias Data = string;
		this(Data data) scope { this.data = data; }
		@property override hash_t toHash() const pure nothrow @safe @nogc => .hashOf(data);
		Data data;
	}
	class NounExpr : Expr {
		pure nothrow @safe @nogc:
		this(Data data) scope { super(data); }
		@property override hash_t toHash() const pure nothrow @safe @nogc => .hashOf(data);
	}
}

///
pure nothrow @safe @nogc unittest {
	scope car1 = new Expr("car");
	scope car2 = new Expr("car");
	scope bar1 = new Expr("bar");
	scope ncar = new NounExpr("car");

	void testEqual() @trusted pure nothrow @nogc //	TODO: make @safe when hashOf arg is scope
	{
		assert(hashOf(car1) == hashOf(car2));
		assert(hashOfPolymorphic(car1) == hashOfPolymorphic(car2));
	}

	void testDifferent1() @trusted pure nothrow @nogc /+ TODO: make @safe when hashOf arg is scope +/
	{
		assert(hashOf(car1) != hashOf(bar1));
		assert(hashOfPolymorphic(car1) != hashOfPolymorphic(bar1));
	}

	void testDifferent2() @trusted pure nothrow @nogc /+ TODO: make @safe when hashOf arg is scope +/
	{
		assert(hashOf(car1) == hashOf(ncar));
		assert(hashOfPolymorphic(car1) != hashOfPolymorphic(ncar));
	}

	testEqual();
	testDifferent1();
	testDifferent2();
}

@nogc:

/** Dummy-hash for benchmarking performance of HashSet. */
pragma(inline, true)
hash_t identityHash64(in ulong x) pure nothrow @safe @nogc => x; // maps -1 to ulong.max

///
pure nothrow @safe @nogc unittest {
	assert(identityHash64(-1) == ulong.max);
	assert(identityHash64(int.max) == int.max);
	assert(identityHash64(ulong.max) == ulong.max);
}

/** Mueller integer hash function (bit mixer) A (32-bit).
 *
 * See_Also: https://stackoverflow.com/a/12996028/683710
 * See_Also: http://zimbry.blogspot.se/2011/09/better-bit-mixing-improving-on.html
 */
uint muellerHash32(uint x) pure nothrow @safe @nogc {
	version (D_Coverage) {} else pragma(inline, true);
	x = ((x >> 16) ^ x) * 0x45d9f3b;
	x = ((x >> 16) ^ x) * 0x45d9f3b;
	x = (x >> 16) ^ x;
	return x;
}

/** Mueller integer hash function (bit mixer) A (64-bit).
 *
 * Based on splitmix64, which seems to be based on the blog article "Better Bit
 * Mixing" (mix 13).
 *
 * See_Also: https://stackoverflow.com/a/12996028/683710
 * See_Also: http://zimbry.blogspot.se/2011/09/better-bit-mixing-improving-on.html
 * See_Also: http://xorshift.di.unimi.it/splitmix64.c
 */
hash_t muellerHash64(ulong x) pure nothrow @safe @nogc {
	version (D_Coverage) {} else pragma(inline, true);
	x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9UL;
	x = (x ^ (x >> 27)) * 0x94d049bb133111ebUL;
	x = x ^ (x >> 31);
	return x;
}

/** Thomas Wang 64-bit mix integer hash function.
 *
 * See_Also: https://gist.github.com/badboy/6267743#64-bit-mix-functions
 */
hash_t wangMixHash64(ulong x) pure nothrow @safe @nogc {
	version (D_Coverage) {} else pragma(inline, true);
	x = (~x) + (x << 21); // x = (x << 21) - x - 1;
	x = x ^ (x >>> 24);
	x = (x + (x << 3)) + (x << 8); // x * 265
	x = x ^ (x >>> 14);
	x = (x + (x << 2)) + (x << 4); // x * 21
	x = x ^ (x >>> 28);
	x = x + (x << 31);
	return x;
}

///
pure nothrow @safe @nogc unittest {
	assert(wangMixHash64(0) == 8633297058295171728UL);
	assert(wangMixHash64(1) == 6614235796240398542UL);
}

/** Inspired by Lemire's strongly universal hashing.
 *
 * See_Also: https://lemire.me/blog/2018/08/15/fast-strongly-universal-64-bit-hashing-everywhere/
 *
 * Instead of shifts, we use rotations so we don't lose any bits.
 *
 * Added a final multiplcation with a constant for more mixing. It is most important that the
 * lower bits are well mixed.
 */
hash_t lemireHash64(in ulong x) pure nothrow @safe @nogc {
	import core.bitop : ror;
	version (D_Coverage) {} else pragma(inline, true);
	enum shift = 8*x.sizeof / 2;
	const ulong h1 = x * 0x_A24B_AED4_963E_E407UL;
	const ulong h2 = ror(x, shift) * 0x_9FB2_1C65_1E98_DF25UL;
	const ulong h = ror(h1 + h2, shift);
	return h;
}
/// ditto
hash_t lemireHash64(in double x) @trusted pure nothrow @nogc {
	return lemireHash64(*(cast(ulong*)&x));
}

///
pure nothrow @safe @nogc unittest {
	assert(lemireHash64(0) == 0UL);
	assert(lemireHash64(1) == 10826341276197359097UL);
	assert(lemireHash64(2) == 3205938474390199283UL);
	assert(lemireHash64(0f) == 0UL);
	assert(lemireHash64(1f) == 5597974336836488763);
	assert(lemireHash64(2f) == 4611686018555721673UL);
}

uint lemireHash32(in uint x) pure nothrow @safe @nogc {
	import core.bitop : ror;
	version (D_Coverage) {} else pragma(inline, true);
	enum shift = 8*x.sizeof / 2;
	const uint h1 = x * 0x_963E_E407U;
	const uint h2 = ror(x, shift) * 0x_1E98_DF25U;
	const uint h = ror(h1 + h2, shift);
	return h;
}
/// ditto
uint lemireHash32(in float x) @trusted pure nothrow @nogc {
	return lemireHash32(*(cast(uint*)&x));
}

///
pure nothrow @safe @nogc unittest {
	assert(lemireHash32(0) == 0UL);
	assert(lemireHash32(1) == 3825694051);
	assert(lemireHash32(2) == 3356420807);
	assert(lemireHash32(0f) == 0UL);
	assert(lemireHash32(1f) == 2910889945);
	assert(lemireHash32(2f) == 1073805257);
}

/** Combine the hashes `lhs` and `rhs`.
 *
 * Copied from `boost::hash_combine`.
 * See_Also: `dmd.root.hash.mixHash`.
 */
hash_t hashCombine(hash_t lhs, in hash_t rhs) pure nothrow @safe @nogc {
	version (D_Coverage) {} else pragma(inline, true);
	lhs ^= rhs + 0x9e3779b9 + (lhs << 6) + (lhs >> 2);
	return lhs;
}
alias mixHash = hashCombine;

///
pure nothrow @safe @nogc unittest {
	assert(hashCombine(8633297058295171728UL, 6614235796240398542UL) == 1903124116120912827UL);
}
