module nxt.container.variant_arrays;

// version = nxt_benchmark;

/** Typed index (reference) into an element in `VariantArrays`.
 *
 * TODO: merge with soa.d?
 */
private struct VariantRef(Size, DefinedTypes...) {
	import std.meta : staticIndexOf;

	alias Kind = ubyte;			  // kind code

	import nxt.bit_traits : bitsNeeded;

	/// Used to indicate undefined value.
	private struct Undefined {}

	import std.meta : AliasSeq;

	alias Types = AliasSeq!(Undefined, DefinedTypes);

	/// Number of bits needed to represent kind.
	private enum kindBits = bitsNeeded!(Types.length);

	/** Get number kind of kind type `SomeKind`.
		TODO: make private?
	 */
	enum nrOfKind(SomeKind) = staticIndexOf!(SomeKind, Types); /+ TODO: cast to ubyte if Types.length is <= 256 +/

	/// Is `true` iff an index to a `SomeKind`-kind can be stored.
	enum canReferenceType(SomeKind) = nrOfKind!SomeKind >= 0;

	/// Comparsion works like for integers.
	int opCmp(in typeof(this) rhs) const @trusted
	{
		version (LDC) pragma(inline, true);
		if (this._rawWord < rhs._rawWord)
			return -1;
		if (this._rawWord > rhs._rawWord)
			return +1;
		return 0;
	}

	pragma(inline, true):

	/// Construct from mutable `that`.
	this(in typeof(this) that) {
		this._rawWord = that._rawWord;
	}
	/// Construct from constant `that`.
	this(typeof(this) that) {
		this._rawWord = that._rawWord;
	}

	/// Construct.
	this(Kind kind, Size index) /+ TODO: can ctor inferred by bitfields? +/
	{
		this._word.kindNr = kind;
		this._word.index = index;
	}

	/// Construct from raw word representation `rawWord`.
	private this(Size rawWord) {
		this._rawWord = rawWord;
	}

	/// Get kindNr.
	Kind kindNr() const => _word.kindNr;

	/// Get index.
	Size index() const => _word.index;

	/// Cast to `size_t`.
	size_t opCast(T : size_t)() const => _rawWord;

	import core.internal.traits : Unqual;

	/// Allow cast to unqualified.
	U opCast(U : Unqual!(typeof(this)))() const => U(rawWord);

	/// The index itself is the hash.
	hash_t toHash() const @property => _rawWord;
	static assert(hash_t.sizeof == _rawWord.sizeof);

	/// Cast to `bool`, meaning 'true' if defined, `false` otherwise.
	bool opCast(U : bool)() const => isDefined();

	/// Returns: `true` iff is defined.
	bool isDefined() const => _rawWord != 0;

	/// Returns: `true` iff `this` targets a value of type `SomeKind`.
	public bool isA(SomeKind)() const => nrOfKind!(SomeKind) == _word.kindNr;

	void toString(Sink)(ref scope Sink sink) const @trusted {
		import std.format : formattedWrite;
		if (isDefined)
			sink.formattedWrite!`%s(%s@%s)`(Unqual!(typeof(this)).stringof, _word.index, _word.kindNr);
		else
			sink.formattedWrite!`%s(null)`(Unqual!(typeof(this)).stringof);
	}

	private struct Word {
		import nxt.dip_traits : hasPreviewBitfields;
		version (LittleEndian) {
			static if (hasPreviewBitfields) {
				/+ TODO: remove mixins when -preview=bitfields is in stable dmd +/
				mixin("Kind kindNr:kindBits;");
				mixin("Size index:8*Size.sizeof - kindBits;");
			} else {
				import std.bitmanip : bitfields;
				mixin(bitfields!(Kind, "kindNr", kindBits,
								 Size, "index", 8*Size.sizeof - kindBits));
			}
		} else {
			static assert(0, "TODO: BigEndian support");
		}
	}

	private union {
		Word _word;
		Size _rawWord;			// for comparsion
	}

	// static assert(this.sizeof == Size.sizeof,
	//			   `This should haven't any memory overhead compared to size_t`);
}

pure nothrow @safe unittest {
	alias R = VariantRef!(size_t, int, float);
	R r;
	static assert(r.canReferenceType!(int));
	static assert(r.canReferenceType!(float));
	static assert(!r.canReferenceType!(short));

	import std.array : Appender;
	Appender!(const(R)[]) app;
	assert(app.data.length == 0);

	const R x;
	R mx = x;
	assert(x == mx);

	/+ TODO: app ~= x; +/

	// const y = [R.init, R.init];
	/+ TODO: app ~= y; +/
}

unittest {
	import std.conv : to;
	alias R = VariantRef!(size_t, int, float);
	R r;
	assert(r.to!string == R.stringof~`(null)`);
}

// private mixin template VariantArrayOf(Type)
// {
//	 import nxt.container.dynamic_array : DynamicArray;
//	 DynamicArray!Type store;
// }

/** Stores set of variants.

	Enables lightweight storage of polymorphic objects.

	Each element is indexed by a corresponding `VariantRef`.
 */
struct VariantArrays(Types...) { /+ TODO: Change to AliasSeq TypesTuple, Allocatar = GCAllocator +/
	alias Size = size_t;
	alias Ref = VariantRef!(Size, Types);

	import nxt.container.dynamic_array : DynamicArray;
	import std.experimental.allocator.mallocator : Mallocator;

	/// Returns: array type (as a string) of `Type`.
	private static immutable(string) arrayTypeStringOfIndex(uint typeIndex)() {
		pragma(inline, true);
		return `DynamicArray!(Types[` ~ typeIndex.stringof ~ `], Mallocator)`; /+ TODO: Make Mallocator a parameter +/
	}

	/** Returns: array instance (as a strinng) storing `SomeKind`.
	 * TODO: make this a template mixin
	 */
	private static immutable(string) arrayInstanceString(SomeKind)()
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		return `_store` ~ Ref.nrOfKind!(SomeKind).stringof; // previously `SomeKind.mangleof`
	}

	/// Make reference to type `SomeKind` at offset `index`.
	static Ref makeRef(SomeKind)(Ref.Size index)
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		return Ref(Ref.nrOfKind!SomeKind, index);
	}

	/** Insert `value` at back.
	 */
	Ref insertBack(SomeKind)(SomeKind value) /+ TODO: add array type overload +/
	if (Ref.canReferenceType!SomeKind) {
		mixin(`alias arrayInstance = ` ~ arrayInstanceString!SomeKind ~ `;`);
		const currentIndex = arrayInstance.length;
		arrayInstance.insertBackMove(value);
		return Ref(Ref.nrOfKind!SomeKind, currentIndex);
	}
	alias put = insertBack;	 // polymorphic `OutputRange` support

	/** Move (emplace) `value` into back.
	 */
	Ref insertBackMove(SomeKind)(ref SomeKind value) /+ TODO: add array type overload +/
	if (Ref.canReferenceType!SomeKind) {
		version (DigitalMars) pragma(inline, false); // DMD cannot inline
		mixin(`alias arrayInstance = ` ~ arrayInstanceString!SomeKind ~ `;`);
		const currentIndex = arrayInstance.length;
		arrayInstance.insertBackMove(value);
		return Ref(Ref.nrOfKind!SomeKind, currentIndex);
	}

	/// ditto
	void opOpAssign(string op, SomeKind)(SomeKind value) /+ TODO: add array type overload +/
	if (op == "~" &&
		Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		insertBackMove(value);  // move enables uncopyable types
	}

	/// Get reference to element of type `SomeKind` at `index`.
	ref inout(SomeKind) at(SomeKind)(in size_t index) inout return scope
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		mixin(`return ` ~ arrayInstanceString!SomeKind ~ `[index];`);
	}

	/// Get reference to element of type `SomeKind` at `ref_`.
	scope ref inout(SomeKind) at(SomeKind)(in Ref ref_) inout return
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		assert(Ref.nrOfKind!SomeKind == ref_.kindNr,
			   "Ref is not of expected template type " ~ SomeKind.stringof);
		mixin(`return ` ~ arrayInstanceString!SomeKind ~ `[ref_.index];`);
	}

	/// Peek at element of type `SomeKind` at `ref_`.
	inout(SomeKind)* peek(SomeKind)(in Ref ref_) inout return @system
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		if (Ref.nrOfKind!SomeKind == ref_._word.kindNr)
			return &at!SomeKind(ref_._word.index);
		else
			return null;
	}

	/// Constant access to all elements of type `SomeKind`.
	inout(SomeKind)[] allOf(SomeKind)() inout return scope
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		mixin(`return ` ~ arrayInstanceString!SomeKind ~ `[];`);
	}

	/// Reserve space for `newCapacity` elements of type `SomeKind`.
	size_t reserve(SomeKind)(in size_t newCapacity)
	if (Ref.canReferenceType!SomeKind) {
		pragma(inline, true);
		mixin(`alias arrayInstance = ` ~ arrayInstanceString!SomeKind ~ `;`);
		return arrayInstance.reserve(newCapacity);
	}

	/** Returns: length of store. */
	@property size_t length() const
	{
		pragma(inline, true);
		typeof(return) lengthSum = 0;
		foreach (Type; Types)
			mixin(`lengthSum += ` ~ arrayInstanceString!Type ~ `.length;`);
		return lengthSum;
	}

	/** Check if empty. */
	bool empty() const @property
	{
		pragma(inline, true);
		return length == 0;
	}

private:
	// static foreach (const typeIndex, Type; Types)
	// {
	//	 /+ TODO: is it better to use?: mixin VariantArrayOf!(Type); +/
	//	 mixin(arrayTypeStringOfIndex!typeIndex ~ ` ` ~ arrayInstanceString!Type ~ `;`);
	// }
	mixin({
		string s = "";
		foreach (const typeIndex, Type; Types)
			s ~= arrayTypeStringOfIndex!typeIndex ~ ` ` ~ arrayInstanceString!Type ~ `;`;
		return s;
	}());
}

/** Minimalistic fixed-length (static) array of (`capacity`) number of elements
 * of type `E` where length only fits in an `ubyte` for compact packing.
 */
version (unittest)
private struct MinimalStaticArray(E, ubyte capacity) {
	this(in E[] es) {
		assert(es.length <= capacity,
			   "Length of input parameter `es` is larger than capacity "
			   ~ capacity.stringof);
		_es[0 .. es.length] = es;
		_length = cast(typeof(_length))es.length;
	}

private:
	E[capacity] _es;
	typeof(capacity) _length;
}

pure nothrow @safe @nogc unittest {
	const ch7 = MinimalStaticArray!(char, 7)(`1234567`);
	assert(ch7._es[] == `1234567`);
}

///
pure nothrow @safe @nogc unittest {
	alias Chars(uint capacity) = MinimalStaticArray!(char, capacity);
	alias Chars7 = Chars!7;
	alias Chars15 = Chars!15;
	alias VA = VariantArrays!(ulong,
							  Chars7,
							  Chars15);

	VA data;
	assert(data.length == 0);
	assert(data.empty);

	const i0 = data.put(ulong(13));
	assert(cast(size_t)i0 == 1);

	assert(i0.isA!ulong);
	assert(data.at!ulong(0) == ulong(13));
	assert(data.length == 1);
	assert(!data.empty);
	assert(data.allOf!ulong == [ulong(13)].s);

	const i1 = data.put(Chars7(`1234567`));
	assert(cast(size_t)i1 == 2);

	// same order as in `Types`
	assert(i0 < i1);

	assert(i1.isA!(Chars7));
	assert(data.at!(Chars7)(0) == Chars7(`1234567`));
	assert(data.allOf!(Chars7) == [Chars7(`1234567`)].s);
	assert(data.length == 2);

	const i2 = data.put(Chars15(`123`));
	assert(cast(size_t)i2 == 3);

	// same order as in `Types`
	assert(i0 < i2);
	assert(i1 < i2);

	assert(i2.isA!(Chars15));
	assert(data.at!(Chars15)(0) == Chars15(`123`));
	/+ TODO: assert(data.allOf!(Chars15) == [Chars15(`123`)].s); +/
	assert(data.length == 3);

	const i3 = data.put(Chars15(`1234`));
	assert(cast(size_t)i3 == 7);

	// same order as in `Types`
	assert(i0 < i3);
	assert(i1 < i3);
	assert(i2 < i3);			// same type, i2 added before i3

	assert(i3.isA!(Chars15));
	assert(data.at!(Chars15)(1) == Chars15(`1234`));
	assert(data.allOf!(Chars15) == [Chars15(`123`), Chars15(`1234`)].s);
	assert(data.length == 4);
}

// version = extraTests;

version (extraTests) {
static private:
	alias S = VariantArrays!(Rel1, Rel2, Int);

	// relations
	struct Rel1 { S.Ref[1] args; }
	struct Rel2 { S.Ref[2] args; }

	struct Int { int value; }
}

///
version (extraTests)
pure nothrow @safe @nogc unittest {
	S s;

	const S.Ref top = s.put(Rel1(s.put(Rel1(s.put(Rel2([s.put(Int(42)),
														s.put(Int(43))]))))));
	assert(top);
	assert(s.allOf!Rel1.length == 2);
	assert(s.allOf!Rel2.length == 1);
	assert(s.allOf!Int.length == 2);
	assert(s.length == 5);
}

/// put and peek
version (extraTests)
@system pure nothrow @nogc unittest {
	S s;
	const n = 10;
	foreach (const i; 0 .. n) {
		S.Ref lone = s.put(Int(i));
		Int* lonePtr = s.peek!Int(lone);
		assert(lonePtr);
		assert(*lonePtr == Int(i));
	}
	assert(s.length == 10);
}

version (unittest) {
	import nxt.array_help : s;
}

version (nxt_benchmark)
unittest {
	import std.stdio : writeln;
	import std.datetime : MonoTime;
	import std.meta : AliasSeq;
	alias E = uint;
	immutable n = 5_000_000;
	foreach (A; AliasSeq!(VariantArrays!(E))) {
		A a;
		immutable before = MonoTime.currTime();
		foreach (uint i; 0 .. n)
			a ~= i;
		immutable after = MonoTime.currTime();
		writeln("Added ", n, " integer nodes into ", A.stringof, " in ", after - before);
	}

}

/** Store array of `E[]` with different lengths compactly.
    When length of `E` is known at compile-time store it as a static array.
 */
private struct HybridArrayArray(E) { /+ TODO: make useful and then public +/
@safe pure:
	void insertBack(E[] value) {
		switch (value.length) {
			/+ TODO: static foreach +/
		case 1: _store.insertBack(cast(char[1])value[0 .. 1]); break;
		case 2: _store.insertBack(cast(char[2])value[0 .. 2]); break;
		case 3: _store.insertBack(cast(char[3])value[0 .. 3]); break;
		case 4: _store.insertBack(cast(char[4])value[0 .. 4]); break;
		case 5: _store.insertBack(cast(char[5])value[0 .. 5]); break;
		case 6: _store.insertBack(cast(char[6])value[0 .. 6]); break;
		case 7: _store.insertBack(cast(char[7])value[0 .. 7]); break;
		case 8: _store.insertBack(cast(char[8])value[0 .. 8]); break;
		default:
			_store.insertBack(value);
		}
	}
private:
	VariantArrays!(char[1],
				   char[2],
				   char[3],
				   char[4],
				   char[5],
				   char[6],
				   char[7],
				   char[8],
				   E[]) _store;
}

///
pure nothrow @safe @nogc unittest {
	alias E = char;
	HybridArrayArray!(E) ss;
	ss.insertBack(E[].init);
}
