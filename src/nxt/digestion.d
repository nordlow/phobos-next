/** Hash digestion of standard types.
 *
 * TODO: use:
 *
 *  static if (__traits(hasMember,hasher, "putStaticArray"))
 *	  digest.putStaticArray((cast(ubyte*)&value)[0 .. value.sizeof]);
 *  else
 *	  digest.put((cast(ubyte*)&value)[0 .. value.sizeof]);
 */
module nxt.digestion;

import std.traits : isScalarType, hasIndirections, isArray, isPointer;
import std.digest : isDigest;
import nxt.container.traits : isAddress;

@safe:

/// ditto
hash_t hashOf2(alias hasher, T)(const scope auto ref T value) {
	version (LDC) pragma(inline, true);
	static if (__traits(compiles, { enum _ = isDigest!hasher; }) &&
			   isDigest!hasher) {
		import std.digest : makeDigest;

		auto digest = makeDigest!(hasher);
		static if (__traits(hasMember, T, "toDigest"))
			value.toDigest(digest);
		else
			digestAny(digest, value);

		static if (__traits(hasMember, hasher, "get")) {
			digest.finish();
			auto result = digest.get();
		}
		else
			auto result = digest.finish();

		static if (is(typeof(result) == typeof(return)))
			return result;
		else static if (is(typeof(result) == ubyte[4])) {
			static hash_t fix(in ubyte[4] x) @trusted => *cast(uint*)(&x);
			return fix(result);
		}
		else static if (is(typeof(result) == ubyte[8])) {
			static hash_t fix(in ubyte[8] x) @trusted => *cast(typeof(return)*)(&x);
			return fix(result);
		}
		else static if (is(typeof(result) == typeof(return)[2]))
			return (result[0] ^ result[1]);
		else
			static assert(0, "Handle get() with return type " ~ typeof(result).stringof ~
						  " on " ~ size_t.sizeof.stringof ~ "-bit platform");
	}
	else static if (__traits(compiles, { auto _ = hasher((ubyte[]).init); })) {
		// cast input `value` to `ubyte[]` and use std.digest API
		immutable digest = hasher((cast(ubyte*)&value)[0 .. value.sizeof]); /+ TODO: ask forums when this isn't correct +/

		static assert(digest.sizeof >=
					  typeof(return).sizeof,
					  `Size of digest is ` ~ digest.sizeof
					  ~ ` but needs to be at least ` ~ typeof(return).sizeof.stringof);

		import std.traits : isUnsigned;

		static if (isUnsigned!(typeof(digest)))
			return cast(typeof(return))digest; // fast modulo calculation
		else static if (__traits(isStaticArray, typeof(digest))) {
			typeof(return) hashIndex;
			static if (2*hash_t.sizeof == digest.sizeof)
				// for instance, use all 128-bits when hash_t is 64-bit
				(cast(ubyte*)&hashIndex)[0 .. hashIndex.sizeof] = (digest[0 .. hashIndex.sizeof] ^
																   digest[hashIndex.sizeof .. 2*hashIndex.sizeof]);
			else
				(cast(ubyte*)&hashIndex)[0 .. hashIndex.sizeof] = digest[0 .. hashIndex.sizeof];
			return hashIndex;
		}
		else
			static assert(0, "Unsupported digest type " ~ typeof(digest).stringof);
	}
	else
		static assert(0, "Cannot combine hasher " ~ hasher.stringof ~
					  " with element type " ~ T.stringof);
}

/** Digest `value` into `digest`.
 */
void digestAny(Digest, T)(ref Digest digest,
						  const scope auto ref T value)
if (isDigest!Digest) {
	version (LDC) pragma(inline, true);
	static if (isScalarType!T)  // first because faster to evaluate than
								// `!hasIndirections!T` below
		digestRaw(digest, value);
	else static if (__traits(hasMember, T, "toDigest"))
		value.toDigest(digest);
	else static if (isAddress!T)
		digestAddress(digest, value);
	else static if (!hasIndirections!T) // no pointers left in `T`. TODO: make this the default in-place of `isScalarType`
	{
		version (LDC)			// LDC doesn't zero pad `real`s
		{
			/+ TODO: needed to improve this with a trait +/
			import std.traits : isInstanceOf;
			static if (__traits(isStaticArray, T)) {
				import std.meta : staticIndexOf;
				enum isReal = is(typeof(T.init[0]) == real);
				static if (isReal) // static array of `real`s
					foreach (e; value)
						digestRaw(digest, e); // hash each element for now because padding might now be zero
				else
					digestRaw(digest, value); // hash everything in one call for better speed
			}
			else
			{
				import std.typecons : Nullable;
				static if (is(T == Nullable!(_), _))
					digestRaw(digest, value); // hash everything in one call for better speed
				else
				{
					import std.meta : staticIndexOf;
					enum realIndex = staticIndexOf!(real, typeof(T.init.tupleof));
					static if (realIndex != -1)
						digestStruct(digest, value); // hash each element for now because padding might now be zero
					else
						digestRaw(digest, value); // hash everything in one call for better speed
				}
			}
		}
		else
			digestRaw(digest, value); // hash everything in one call for better speed
	}
	else static if (isArray!T) // including `T` being `string`, `wstring`, `dstring`
		digestArray(digest, value);
	else static if (is(T == struct)) {
		static if (is(typeof(T.init[])) && isArray!(typeof(T.init[]))) /+ TODO: trait: `isArrayLike` +/
			digestAnyWithTrustedSystemSlicing(digest, value);
		else
			digestStruct(digest, value);
	}
	else
		static assert(0, "handle type " ~ T.stringof);
}

/+ TODO: remove when `SSOString` gets scope-checked opSlice +/
private
void digestAnyWithTrustedSystemSlicing(Digest, T)(ref Digest digest,
												  const scope ref T value) @trusted
{
	digestArray(digest, value[]);
}

/** Digest the `value` as an address (pointer). */
private void digestAddress(Digest, T)(scope ref Digest digest,
									  const scope T value) @trusted // pointer passed by value
if (isDigest!Digest &&
	isAddress!T) {
	static if (is(T == class)) {
		static if (size_t.sizeof == 8)
			enum bitshift = 3;  // 64-bit platform
		else
			enum bitshift = 2;  // 32-bit platform
	}
	else static if (isPointer!T) {
		enum Tvalue = typeof(*T.init);
		enum Talignment = T.value.alignof;
		static	  if (Talignment == 16)
			enum bitshift = 4;
		else static if (Talignment == 8)
			enum bitshift = 3;
		else static if (Talignment == 4)
			enum bitshift = 2;
		else static if (Talignment == 2)
			enum bitshift = 1;
		else static if (Talignment == 1)
			enum bitshift = 0;
		else
			static assert(0, "Cannot calculate alignment of T being " ~ T.stringof);
	}
	const valueAsSize = *cast(size_t*)(&value); // `value` as pointer
	assert((valueAsSize & (bitshift - 1)) == 0); // shifted out bits should all be zero
	digestRaw(digest, valueAsSize >> bitshift);
}

/** Digest the struct `value` by digesting each member sequentially. */
private void digestStruct(Digest, T)(scope ref Digest digest,
									 const scope auto ref T value) @trusted
if (isDigest!Digest &&
	is(T == struct)) {
	static if (!hasIndirections!T) {
		version (D_Coverage) {} else pragma(inline, true);
		digestRaw(digest, value); // hash everything in one call for better speed
	}
	else
	{
		version (LDC) pragma(inline, true);
		foreach (const ref subValue; value.tupleof) // for each member
			digestAny(digest, subValue);
	}
}

/** Digest the array `value`. */
void digestArray(Digest, T)(scope ref Digest digest,
							const scope auto ref T value) @trusted
if (isDigest!Digest &&
	isArray!T) {
	import std.traits : isDynamicArray;
	static if (isDynamicArray!T)
		// only dynamic arrays vary in length for a specific type `T` being hashed
		digestRaw(digest, value.length); // length

	alias E = typeof(T.init[0]);
	static if (isScalarType!E ||
			   isPointer!E ||
			   (is(T == class) &&
				!__traits(hasMember, T, "toDigest"))) {
		version (D_Coverage) {} else pragma(inline, true);
		digest.put((cast(ubyte*)value.ptr)[0 .. value.length * value[0].sizeof]); // faster
	}
	else
		foreach (const ref element; value)
			digestAny(digest, element); // slower
}

/** Digest raw bytes of `values`.
 */
private void digestRaw(Digest, T)(scope ref Digest digest,
								  const scope T value) @trusted // pass scalar types by value
if (isDigest!Digest &&
	isScalarType!T)			 // scalar type `T`
{
	version (LDC) pragma(inline, true);
	/+ TODO: optimize when value is size_t, ulong and digest supports it +/
	digest.put((cast(ubyte*)&value)[0 .. value.sizeof]);
}

private void digestRaw(Digest, T)(scope ref Digest digest,
								  const scope auto ref T value) @trusted // pass non-scalar types by ref when possible
if (isDigest!Digest &&
	!isScalarType!T)			// non-scalar type `T`
{
	version (LDC) pragma(inline, true);
	/+ TODO: optimize when value is size_t, ulong and digest supports it +/
	digest.put((cast(ubyte*)&value)[0 .. value.sizeof]);
}

/// arrays and containers and its slices
pure @safe unittest {
	import nxt.container.dynamic_array : DynamicArray;
	import nxt.construction : makeWithElements;

	alias E = double;
	alias A = DynamicArray!E;

	immutable e = [cast(E)1, cast(E)2, cast(E)3].s;
	auto a = makeWithElements!(A)(e[]);

	// static array and its slice (dynamic array) hash differently
	const sh = hashOf2!(FNV64)(e); /* does not need to include length in hash
									* because all instances of typeof(e) have
									* the same length */
	const dh = hashOf2!(FNV64)(e[]); // includes hash in length
	assert(sh != dh);

	// array container and its slice should hash equal
	assert(hashOf2!(FNV64)(a) ==
		   hashOf2!(FNV64)(e[]));
}

@trusted pure unittest {
	const ubyte[8] bytes8 = [1, 2, 3, 4, 5, 6, 7, 8];
	assert(hashOf2!(FNV64)(bytes8) == 9130222009665091821UL);

	enum E { first, second, third }

	assert(hashOf2!(FNV64)(E.first) ==
		   hashOf2!(FNV64)(E.first));
	assert(hashOf2!(FNV64)(E.second) ==
		   hashOf2!(FNV64)(E.second));
	assert(hashOf2!(FNV64)(E.third) ==
		   hashOf2!(FNV64)(E.third));
	assert(hashOf2!(FNV64)(E.first) !=
		   hashOf2!(FNV64)(E.second));
	assert(hashOf2!(FNV64)(E.second) !=
		   hashOf2!(FNV64)(E.third));

	struct V
	{
		float f = 3;
		double d = 5;
		real r = 7;
		E e;
	}

	struct S
	{
		string str = `abc`;
		wstring wstr = `XYZ`;
		dstring dstr = `123`;
		size_t sz = 17;
		ushort us = 18;
		ubyte ub = 255;
		V v;
	}

	// check determinism
	assert(hashOf2!(FNV64)("alpha") ==
		   hashOf2!(FNV64)("alpha".dup));

	assert(hashOf2!(FNV64)(S()) ==
		   hashOf2!(FNV64)(S()));

	struct HasDigest
	{
		E e;
		void toDigest(Digest)(scope ref Digest digest) const
			pure nothrow @nogc
			if (isDigest!Digest) {
			digestRaw(digest, e);
		}
	}

	assert(hashOf2!(FNV64)(HasDigest(E.first)) ==
		   hashOf2!(FNV64)(HasDigest(E.first)));

	assert(hashOf2!(FNV64)(HasDigest(E.first)) !=
		   hashOf2!(FNV64)(HasDigest(E.second)));
}

version (unittest) {
	import nxt.digest.fnv : FNV;
	alias FNV64 = FNV!(64, true);
	import nxt.debugio;
	import nxt.array_help : s;
}
