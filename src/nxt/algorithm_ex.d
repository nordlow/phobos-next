/** Extensions to std.algorithm.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	TODO: merge stuff from algorithm_ex_2.d
*/
module nxt.algorithm_ex;

/* version = show; */

import std.traits : isArray, Unqual, isIntegral, CommonType, arity, isSomeString, isExpressionTuple;
import std.range.primitives : ElementType, isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange, front;
import nxt.traits_ex : allSame;
import std.functional : binaryFun;
import std.algorithm.searching : find;

version (show) {
	import nxt.debugio : dbg;
}

import std.range : dropOne;
alias tail = dropOne;

/** This overload enables, when possible, lvalue return.
 *
 * BUG: this overload is not chosen over `std.algorithm.either` so function
 * must currently be called `eitherRef` instead of `either`.
 */
ref Ts[0] eitherRef(Ts...)(ref Ts a) if (a.length != 0 && allSame!Ts) /+ TODO: better trait for this? +/ {
	static if (Ts.length == 1)
		return a[0];
	else
		return a[0] ? a[0] : eitherRef(a[1 .. $]); // recurse
}

///
@safe pure /*TODO: nothrow*/ unittest {
	int x = 1, y = 2;
	eitherRef(x) = x;
	eitherRef(x, y) = 3;
	assert(x == 3);
	assert(y == 2);
}

/** Returns: last argument if all arguments implicitly bool-convert to `true`
 * otherwise `CommonType!T.init`.
 *
 * Similar to behaviour of `and` operator in dynamic languages such as of Lisp's
 * `(and a...)` and Python's `a and ....`.
 *
 * TODO: Is inout Conversion!T the correct return value?
*/
CommonType!T every(T...)(lazy T a) if (T.length != 0) {
	auto a0 = a[0]();		   // evaluate only once
	static if (T.length == 1)
		return a0;
	else
		return a0 ? every(a[1 .. $]) : CommonType!T.init; // recurse
}

///
@safe pure /*TODO: nothrow*/ unittest {
	assert(every(3) == 3);
	assert(every(3, 4) == 4);
	assert(every(0, 4) == 0);
	assert(every(0, 0) == 0);
	assert(every([0, 1], [1, 2]) == [1, 2]);
	assert(every([0, 1], [1]) == [1]);
	assert(every(`a`, `b`) == `b`);
	assert(every(``, `b`) == `b`);
	assert(every(cast(string)null, `b`) == cast(string)null);
}

version (none) // WARNING disabled because I don't see any use of this for.
{
	/** This overload enables, when possible, lvalue return.
	*/
	auto ref every(T...)(ref T a)
	if (T.length != 0 && allSame!T) {
		static if (T.length == 1)
			return a[0];
		else
			return a[0] ? every(a[1 .. $]) : a[0]; // recurse
	}

	///
	unittest
	{
		immutable p = 1, q = 2;
		assert(every(p, q) == 2);

		int x = 1, y = 2;
		every(x, y) = 3;
		assert(x == 1);
		assert(y == 3);
	}
}

/** Evaluate all `parts` possibly digesting `whole`.
 *
 * If all values of `parts` implicitly convert to `bool true`, return the values
 * as an array, otherwise restore whole and return null.
 */
CommonType!T[] tryEvery(S, T...)(ref S whole, lazy T parts) if (T.length != 0) {
	const wholeBackup = whole;
	bool all = true;
	alias R = typeof(return);
	R results;
	foreach (result; parts) // evaluate each part
	{
		if (result)
			results ~= result;
		else
		{
			all = false;
			break;
		}
	}
	if (all)
		return results;		// ok that whole has been changed in caller scope
	else
	{
		whole = wholeBackup; // restore whole in caller scope if any failed
		return R.init;
	}
}

///
unittest {
	auto whole = `xyz`;
	import std.algorithm.searching : skipOver;

	assert(whole.tryEvery(whole.skipOver('x'),
						  whole.skipOver('z')) == []); // failing match
	assert(whole == `xyz`); // should restore whole

	assert(whole.tryEvery(whole.skipOver('x'),
						  whole.skipOver('y'),
						  whole.skipOver('w')) == []); // failing match
	assert(whole == `xyz`); // should restore whole

	assert(whole.tryEvery(whole.skipOver('x'),
						  whole.skipOver('y')) == [true, true]); // successful match
	assert(whole == `z`); // should digest matching part
}

/** Returns: `true` iff `a` has a value containing meaningful information.
 */
bool hasContents(T)(in T a) {
	import std.typecons : Nullable;
	static if (is(T == Nullable!(_), _))
		return !a.isNull;
	else static if (isArray!T ||
					isSomeString!T)
		return cast(bool)a.length; // see: http://stackoverflow.com/questions/18563414/empty-string-should-implicit-convert-to-bool-true/18566334?noredirect=1#18566334
	else
		return cast(bool)a;
}

/** Reset `a` to its default value.
 *
 * Params:
 *	  T = the argument type, likely to be infered.
 *	  a = a reference to a T.
 *
 * See_Also: std.typecons.Nullable.nullify
 */
auto ref reset(T)(ref T a) @trusted // pure nothrow
{
	import std.typecons : Nullable;
	static if (is(T == Nullable!(_), _))
		a.nullify();
	else
		return a = T.init;
}

///
@safe @nogc pure nothrow unittest {
	uint a = 159;
	a.reset();
	assert(a == a.init);

	string b = "bla";
	b.reset();
	assert(b == b.init);
}

/** Returns: `true` iff $(D a) is set to the default/initial value of its type $(D T).
 */
bool isDefaulted(T)(in T a) {
	static if (__traits(hasMember, T, "isNull"))
		return a.isNull;		// Nullable
	else
		return a == T.init;
}

///
pure nothrow @safe @nogc unittest {
	import std.typecons : Nullable;
	auto n = Nullable!(size_t, size_t.max)();
	assert(n.isDefaulted);
	n = 0;
	assert(!n.isDefaulted);
	assert(n == 0);
	n.reset;
	assert(n.isDefaulted);
}

import std.typecons : Tuple, tuple;

/** Find `needles` in order in `haystack`. */
auto findInOrder(alias pred = `a == b`,
				 alias finder = find,
				 R,
				 E...)(R haystack,
					   E needles) /* @trusted pure nothrow */
{
	import std.range.primitives : empty;
	auto hit = haystack; // reference
	foreach (needle; needles) // for every needle in order
	{
		hit = finder!pred(hit, needle);
		if (hit.empty)
			break;
	}
	return hit;
}

///
pure nothrow @safe @nogc unittest {
	import std.range.primitives : empty;
	assert(`a b c`.findInOrder(`a`, `b`, `c`));
	assert(`b a`.findInOrder(`a`, `b`).empty);
}

/** Returns: If `range` is symmetric.
 *
 * See_Also: http://forum.dlang.org/thread/dlfeiszyweafpjiocplf@forum.dlang.org#post-vpzuaqxvtdpzpeuorxdl:40forum.dlang.org
 * See_Also: https://stackoverflow.com/questions/21849580/equality-operator-in-favour-of-std-range-equal
 *
 * TODO: Test graphemes in `string` and `wstring`.
 * TODO: Move to Phobos
*/
bool isSymmetric(R)(R range) if (isBidirectionalRange!(R)) {
	size_t i = 0;
	import std.range.primitives : empty;
	while (!range.empty) {
		import std.range.primitives : front, back, popFront, popBack;
		if (range.front != range.back)
			return false;
		range.popFront(); ++i;
		if (range.empty)
			break;
		range.popBack(); ++i;
	}
	return true;
}

///
pure @safe unittest {
	assert(`dallassallad`.isSymmetric);
	assert(!`ab`.isSymmetric);
	assert(`a`.isSymmetric);
	assert(`åäå`.isSymmetric);
	assert(`áá`.isSymmetric);
	assert(`åäå`.isSymmetric);
	assert(``.isSymmetric);
	assert([1, 2, 2, 1].isSymmetric);
}

/** Returns: If `range` is a palindrome larger than `lengthMin`.
 */
bool isPalindrome(R)(R range, size_t lengthMin = 0) /+ TODO: good value for lengthMin? +/
if (isBidirectionalRange!(R)) {
	static if (hasLength!R) // arrays excluding `char[]` and `wchar[]`
		if (range.length < lengthMin)
			return false;
	size_t i = 0;
	/+ TODO: reuse `isSymmetric` +/
	import std.range.primitives : empty;
	while (!range.empty) {
		import std.range.primitives : front, back, popFront, popBack;
		if (range.front != range.back)
			return false;
		range.popFront(); ++i;
		if (range.empty)
			break;
		range.popBack(); ++i;
	}
	return i >= lengthMin;
}

///
pure @safe unittest {
	assert(!`ab`.isPalindrome);
	assert(`a`.isPalindrome);
	assert(`åäå`.isPalindrome);
	assert(`áá`.isPalindrome);
	assert(`åäå`.isPalindrome);
	assert(``.isPalindrome);
	assert([1, 2, 2, 1].s[].isPalindrome);
	assert(![1, 2, 2, 1].s[].isPalindrome(5));
	assert(``.isPalindrome(lengthMin: 0));
	assert(!``.isPalindrome(lengthMin: 1));
}

import nxt.traits_ex : areEquable;

/** Return true if $(D s1) is an Anagram of $(D s2).
 *
 * Equal arguments are not considered to be an anagrams of each other.
 *
 * TODO: Is there a faster way of calculating anagrams?
 * TODO: Allow const input
 * TODO: Move to Phobos std.algorithm.sorting.
 * TODO: Should requirement isInputRange be relaxed?
 *
 * Note that implementations in http://rosettacode.org/wiki/Anagrams#D doesn't
 * correctly handle multi-byte encoded characters in string and wstring.
 */
auto isAnagramOf(R1, R2)(scope R1 r1, scope R2 r2) /+ TODO: nothrow +/
if (isInputRange!R1 &&
	isInputRange!R2 &&
	areEquable!(ElementType!R1,
				ElementType!R2)) {
	immutable sortLimit = 0;
	import std.range.primitives : empty;
	if (r1.empty || r2.empty)
		return false;
	if (r1.length + r2.length < sortLimit) {
		import std.algorithm.comparison : equal;
		import nxt.sort_ex : sorted; // NOTE allocates
		return equal(r1.sorted,
					 r2.sorted);
	}
	else
	{
		alias E1 = ElementType!R1;
		alias E2 = ElementType!R2;
		alias C = CommonType!(E1, E2);

		alias T = Tuple!(size_t, // R1 histogram bin count
						 size_t); // R2 histogram bin count

		import std.traits : isNarrowString;
		import std.utf : byUTF;

		/+ TODO: functionize +/
		static if (isNarrowString!R1)
			auto s1 = r1.byUTF!dchar;
		else
			auto s1 = r1; /+ TODO: avoid copying +/

		static if (isNarrowString!R2)
			auto s2 = r2.byUTF!dchar;
		else
			auto s2 = r2; /+ TODO: avoid copying +/

		// histogram
		T[C] hist;			  /+ TODO: use non-GC-allocating AA +/

		// create histograms
		foreach (const ref e1; s1) {
			/+ TODO: functionize to hist.initOrUpdate(e1, T(0,1), (ref AA aa){ aa[0] += 1; }) +/
			if (auto hit = e1 in hist)
				(*hit)[0] += 1;
			else
				hist[e1] = T(1, 0);
		}
		foreach (const ref e2; s2) {
			/+ TODO: functionize to hist.initOrUpdate(e2, T(0,1), (ref AA aa){ aa[1] += 1; }) +/
			if (auto hit = e2 in hist)
				(*hit)[1] += 1;
			else
				hist[e2] = T(0, 1);
		}

		// check histograms
		foreach (const ref e; hist) /+ TODO: nothrow +/
			if (e[0] != e[1])
				return false;
		return true;
	}
}
alias isPermutationOf = isAnagramOf; /+ TODO: Only define isAnagramOf for strings? +/

///
pure @safe unittest {
	assert([1, 2, 3, 4, 5].s[].isPermutationOf([1, 2, 4, 5, 3].s[]));
	assert(![1, 2, 3, 4, 5].s[].isPermutationOf([1, 4, 5, 3].s[]));
}

///
pure @safe unittest {
	assert(!``w.isAnagramOf(``));
	assert(`äöå`w.isAnagramOf(`åäö`));
	assert(`äöå`.isAnagramOf(`åäö`w));
	assert(`äöå`w.isAnagramOf(`åäö`w));

	assert(`äöå`d.isAnagramOf(`åäö`));
	assert(`äöå`.isAnagramOf(`åäö`d));
	assert(`äöå`d.isAnagramOf(`åäö`d));
}

///
pure @safe unittest {
	assert(`äöå`.isAnagramOf(`åäö`));
	assert(!`äöå`.isAnagramOf(`xyz`));
	assert(!`äöå`.isAnagramOf(``));
	assert(!``.isAnagramOf(`åäö`));
}
pure @safe unittest {
	assert(`xyzxyzxyzxyzxyzxyzxyzxyz`.isAnagramOf(`xyzxyzxyzxyzxyzxyzxyzxyz`));
	assert(`xyzxyzxyzxyzxyzxyzxyzxyz`.isAnagramOf(`xxyyzzxxyyzzxxyyzzxxyyzz`));
}

///
pure @safe unittest {
	import std.conv: to;

	auto x = `äöå`.to!(dchar[]);

	auto y = sort(x);
	alias Y = typeof(y);

	immutable z = `åäö`;

	assert(y.isAnagramOf(z));
	assert(z.isAnagramOf(y));
}

/* ref Unqual!T unqual(T)(in T x) pure nothrow if isStuct!T { return cast(Unqual!T)x; } */
/* /// */
/* unittest { */
/*	 const int x; */
/*	 unqual(x) = 1; */
/* } */

enum Reduction
{
	forwardDifference,
	backwardDifference,
	sum,
}

/** Generalized Windowed Reduce.
 *
 * See_Also: https://stackoverflow.com/questions/21004944/forward-difference-algorithm
 * See_Also: http://forum.dlang.org/thread/ujouqtqeehkegmtaxebg@forum.dlang.org#post-lczzsypupcfigttghkwx:40forum.dlang.org
 * See_Also: http://rosettacode.org/wiki/Forward_difference#D
*/
auto ref windowedReduce(Reduction reduction = Reduction.forwardDifference, R)(R range)
if (isInputRange!R) {
	import std.algorithm.iteration: map;
	import std.range: zip, dropOne;
	auto ref op(T)(T a, T b) @safe pure nothrow
	{
		static	  if (reduction == Reduction.forwardDifference)
			return b - a; /+ TODO: final static switch +/
		else static if (reduction == Reduction.backwardDifference)
			return a - b;
		else static if (reduction == Reduction.sum)
			return a + b;
	}
	return range.zip(range.dropOne).map!(a => op(a[0], a[1])); // a is a tuple here
}
// NOTE: Disabled for now because this solution cannot be made nothrow
/* auto ref windowedReduce(Reduction reduction = Reduction.forwardDifference, uint N = 0, R)(R range) */
/*	 @safe pure /\* nothrow *\/ if (isInputRange!R) */
/* { */
/*	 auto ref helper(R range) @safe pure /\* nothrow *\/ { */
/*		 import std.algorithm.iteration: map; */
/*		 import std.range: zip, dropOne; */
/*		 //  Note: that a[0] and a[1] indexes Zip tuple */
/*		 static if (reduction == Reduction.forwardDifference) */
/*			 return range.zip(range.dropOne).map!(a => a[1] - a[0]); */
/*		 static if (reduction == Reduction.backwardDifference) */
/*			 return range.zip(range.dropOne).map!(a => a[0] - a[1]); */
/*		 static if (reduction == Reduction.sum) */
/*			 return range.zip(range.dropOne).map!(a => a[0] + a[1]); */
/*	 } */
/*	 static if (N != 0) { */
/*		 return windowedReduce!(reduction, N - 1)(helper(range)); */
/*	 } else { */
/*		 return helper(range); */
/*	 } */
/* } */

/* /// */
/* unittest { */
/*	 import std.range: front; */
/*	 dbg([1].windowedReduce!(Reduction.forwardDifference)); */
/*	 dbg([1, 22].windowedReduce!(Reduction.forwardDifference)); */
/*	 dbg([1, 22, 333].windowedReduce!(Reduction.forwardDifference)); */
/* } */

///
@safe unittest {
	import std.datetime : Clock, SysTime;
	SysTime[] times;
	immutable n = 4;
	foreach (_; 0 .. n)
		times ~= Clock.currTime;
	version (show) dbg(times);
	auto spans = times.windowedReduce!(Reduction.forwardDifference);
	version (show) dbg(spans);
	// dbg(*(cast(ulong*)&(spans.front)));
	version (show) import std.datetime : Duration;
	version (show) dbg(Duration.sizeof);
}

///
pure @safe unittest {
	immutable i = [1, 4, 9, 17];
	assert(i.windowedReduce!(Reduction.forwardDifference).equal ([+3, +5, +8]));
	assert(i.windowedReduce!(Reduction.backwardDifference).equal([-3, -5, -8]));
	assert(i.windowedReduce!(Reduction.sum).equal ([+5, +13, +26]));
	assert([1].windowedReduce.empty);
	version (show) dbg(i.windowedReduce!(Reduction.sum));
}

/* TODO: Assert that ElementType!R only value semantics.  */
auto ref packBitParallelRunLengths(R)(in R x)
if (isInputRange!R) {
	import std.bitmanip: BitArray;
	import core.bitop: bt;
	alias E = ElementType!R; // element type
	enum nBits = 8*E.sizeof;

	BitArray[nBits] runs;

	// allocate runs
	foreach (ref run; runs)
		run.length = x.length;

	/* string toString() @property @trusted const { */
	/*	 typeof(return) y; */
	/*	 import std.conv: to; */
	/*	 foreach (run; runs) { */
	/*		 y ~= run.to!string ~ "\n"; */
	/*	 } */
	/*	 return y; */
	/* } */

	/* size_t[nBits] counts; */

	import nxt.container.static_bitarray : StaticBitArray;
	import nxt.bitop_ex: testBit;
	foreach (eltIx, elt; x)
		/* StaticBitArray!nBits bits; */
		foreach (bitIndex; 0..nBits)
			runs[bitIndex][eltIx] = elt.testBit(bitIndex);
	return runs;
}
alias packBPRL = packBitParallelRunLengths;

///
@trusted pure unittest {
	/* import backtrace.backtrace; */
	/* import std.stdio: stderr; */
	/* backtrace.backtrace.install(stderr); */
	immutable x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
	immutable xPacked = x.packBitParallelRunLengths;
	version (show) dbg(xPacked);
}

/** Compute Forward Difference of `range`.
 *
 * TODO: Is there a difference between whether `R r` is immutable, const or
 * mutable?
 *
 * TODO: If `r` contains only one element return empty range.
 *
 * See_Also: https://stackoverflow.com/questions/21004944/forward-difference-algorithm
 * See_Also: http://forum.dlang.org/thread/ujouqtqeehkegmtaxebg@forum.dlang.org#post-lczzsypupcfigttghkwx:40forum.dlang.org
 * See_Also: http://rosettacode.org/wiki/Forward_difference#D
 */
auto forwardDifference(R)(R r) if (isInputRange!R) {
	import std.range: front, empty, popFront, dropOne;

	struct ForwardDifference
	{
		R _range;
		alias E = ElementType!R;					   // Input ElementType
		alias D = typeof(_range.front - _range.front); // Element Difference Type. TODO: Use this as ElementType of range
		D _front;
		bool _initialized = false;

		this(R range)
		in(!range.empty) {
			auto tmp = range;
			if (tmp.dropOne.empty) /+ TODO: This may be an unneccesary cost but is practical to remove extra logic +/
				_range = R.init; // return empty range
			else
				_range = range; // store range internally (by reference)
		}

		@property:
		auto ref front() {
			if (!_initialized)
				popFront();
			return _front;
		}
		auto ref moveFront() {
			popFront();
			return _front;
		}
		void popFront() {
			if (empty is false) {
				_initialized = true;
				const E rf = _range.front;
				_range.popFront();
				if (_range.empty is false)
					_front = _range.front - rf;
			}
		}
		bool empty() => _range.empty;
	}

	return ForwardDifference(r);
}

///
pure @safe unittest {
	auto x = [long.max, 0, 1];
	auto y = x.forwardDifference;
	version (show) dbg(y);
}

import std.traits: isCallable, ReturnType, arity;
import nxt.traits_ex: arityMin0;

/** Create Range of Elements Generated by `fun`.
 *
 * Use for example to generate random instances of return value of fun.
 *
 * TODO: I believe we need arityMin, arityMax trait here
 */
auto apply(alias fun, N)(N n)
if (/+ TODO: isCallable!fun && +/
		arityMin0!fun &&
		!is(ReturnType!fun == void) &&
		isIntegral!N) {
	import std.range: iota;
	import std.algorithm.iteration: map;
	return n.iota.map!(n => fun);
}

///
@safe unittest {
	import std.datetime: Clock;
	import std.array: array;
	immutable n = 3;
	auto times = n.apply!(Clock.currTime).array;
	version (show) dbg(times);
	auto spans = times.forwardDifference;
	version (show) dbg(spans);
}

/** In Place Ordering (in Sorted Order) of all Elements `t`.
 *
 * See_Also: https://stackoverflow.com/questions/21102646/in-place-ordering-of-elements/
 * See_Also: http://forum.dlang.org/thread/eweortsmcmibppmvtriw@forum.dlang.org#post-eweortsmcmibppmvtriw:40forum.dlang.org
*/
void orderInPlace(T...)(ref T t) @trusted
{
	import std.algorithm: sort, swap;
	static if (t.length == 2) {
		if (t[0] > t[1])
			swap(t[0], t[1]);
	}
	else
	{						   // generic version
		T[0][T.length] buffer;	  // static buffer to capture elements
		foreach (idx, a; t)
			buffer[idx] = a;
		auto sorted = sort(buffer[]);
		foreach (idx, a; t)
			t[idx] = sorted[idx];
	}
}

///
pure @safe unittest {
	auto x = 2, y = 1;
	orderInPlace(x, y);
	assert(x == 1);
	assert(y == 2);
}

///
pure @safe unittest {
	auto x = 3, y = 1, z = 2;
	orderInPlace(x, y, z);
	assert(x == 1);
	assert(y == 2);
	assert(z == 3);
}

import std.algorithm: SwapStrategy;

/** Allow static arrays to be sorted without [].
 *
 * See_Also: http://forum.dlang.org/thread/jhzurojjnlkatjdgcfhg@forum.dlang.org
 */
template sort(alias less = `a < b`, SwapStrategy ss = SwapStrategy.unstable) {
	import std.algorithm: stdSort = sort;
	auto sort(Arr)(ref Arr arr) if (__traits(isStaticArray, Arr)) {
		return stdSort!(less, ss)(arr[]);
	}
	auto sort(Range)(Range r) if (!__traits(isStaticArray, Range)) {
		return stdSort!(less, ss)(r);
	}
}

///
pure @safe unittest {
	int[5] a = [ 9, 5, 1, 7, 3 ];
	int[]  b = [ 4, 2, 1, 6, 3 ];
	sort(a);
	sort(b);
}

/** Stable Variant of Quick Sort.
 *
 * See_Also: http://forum.dlang.org/thread/gjuvmrypvxeebvztszpr@forum.dlang.org
 */
auto ref stableSort(T)(auto ref T a) pure if (isRandomAccessRange!T) {
	if (a.length >= 2) {
		import std.algorithm: partition3, sort;
		auto parts = partition3(a, a[$ / 2]); // mid element as pivot
		parts[0].sort();
		parts[2].sort();
	}
	return a;
}

///
@safe unittest {
	import nxt.random_ex : randInPlace;
	immutable n = 2^^16;
	auto a = new int[n];
	a.randInPlace();
	auto b = a.dup;
	a[].stableSort;
	import std.algorithm: sort;
	sort(b);
	assert(a == b);
}

/** Execute Expression `expr` the same way `n` times. */
void doTimes(uint n, lazy void expr) {
	while (n--)
		expr();
}

/** Execute Expression `expr` $(I inline) the same way `n` times.
	`n` must be a constant known at compile time.
*/
void doTimes(uint n)(lazy void expr) {
	static foreach (i; 0 .. n)
		expr();
}

///
pure @safe unittest {
	int i = 0;
	doTimes!4(i++);
	assert(i == 4);
}

alias loop = doTimes;
alias doN = doTimes;
alias repeat = doTimes;

/** Execute Expression `action` the same way `n` times. */
void times(alias action, N)(N n)
if (isCallable!action &&
	isIntegral!N &&
	arity!action <= 1) {
	import std.traits: ParameterTypeTuple;
	static if (arity!action == 1 && // if one argument and
			   isIntegral!(ParameterTypeTuple!action[0])) // its an integer
		foreach (i; 0 .. n)
			action(i); // use it as action input
	else
		foreach (i; 0 .. n)
			action();
}

///
pure @safe unittest {
	enum n = 10;
	int sum = 0;
	10.times!({ sum++; });
	assert(sum == n);
}

private string genNaryFun(string fun, V...)() {
	string code;
	import std.string : format;
	foreach (n, v; V)
		code ~= "alias values[%d] %s;".format(n, cast(char)('a'+n));
	code ~= `return ` ~ fun ~ `;`;
	return code;
}
template naryFun(string fun) {
	auto naryFun(V...)(V values) {
		mixin(genNaryFun!(fun, V));
	}
}

///
pure @safe unittest {
	alias test = naryFun!`a + b + c`;
	assert(test(1, 2, 3) == 6);
}

import std.meta : allSatisfy;

/** Zip `ranges` together with operation `fun`.
 *
 * TODO: Remove when Issue 8715 is fixed providing zipWith
 */
auto zipWith(alias fun, Ranges...)(Ranges ranges)
if (Ranges.length >= 2 &&
	allSatisfy!(isInputRange, Ranges)) {
	import std.range: zip;
	import std.algorithm.iteration: map;
	static if (ranges.length < 2)
		static assert(0, `Need at least 2 range arguments.`);
	else static if (ranges.length == 2)
		return zip(ranges).map!(a => binaryFun!fun(a.expand));
	else
		return zip(ranges).map!(a => naryFun!fun(a.expand));
	// return zip(ranges).map!(a => fun(a.expand));
}

///
pure @safe unittest {
	auto x = [1, 2, 3];
	import std.array: array;
	assert(zipWith!`a+b`(x, x).array == [2, 4, 6]);
	assert(zipWith!((a, b) => a + b)(x, x).array == [2, 4, 6]);
	assert(zipWith!`a+b+c`(x, x, x).array == [3, 6, 9]);
}

auto zipWith(fun, StoppingPolicy, Ranges...)(StoppingPolicy sp, Ranges ranges)
if (Ranges.length != 0 &&
	allSatisfy!(isInputRange, Ranges)) {
	import std.range: zip;
	import std.algorithm.iteration: map;
	return zip(sp, ranges).map!fun;
}

/** Pair. TODO: std.typecons */
alias Pair(T, U) = Tuple!(T, U);
/** Instantiator for `Pair`. */
auto pair(T, U)(T t, U u) { return Pair!(T, U)(t, u); }

/** Triple. TODO: std.typecons */
alias Triple(T, U, V) = Tuple!(T, U, V);
/** Instantiator for `Triple`. */
auto triple(T, U, V)(T t, U u, V v) { return Triple!(T, U, V)(t, u, v); }

/** Quadruple. TODO: std.typecons */
alias Quadruple(T, U, V, W) = Tuple!(T, U, V, W);
/** Instantiator for `Quadruple`. */
auto quadruple(T, U, V, W)(T t, U u, V v, W w) { return Quadruple!(T, U, V, W)(t, u, v, w); }

/** Check if `a` and `b` are colinear.
	`a` and `b` are colinear iff `a.x / a.y == b.x / b.y` holds.
	We can avoid the division by multiplying out.
 */
bool areColinear(T)(in T a, in T b) {
	return a.x * b.y == a.y * b.x;
}

/* /\** TODO: Remove when each is standard in Phobos. *\/ */
/* void each(R)(R range, delegate x) @safe pure /\* nothrow *\/ if (isInputRange!R) { */
/*	 foreach (ref elt; range) { */
/*		 x(elt); */
/*	 } */
/* } */
/* /// */
/* pure @safe unittest { */
/*	 version (show) [1, 2, 3, 4].each(a => dbg(a)); */
/* } */

enum isIntLike(T) = is(typeof({ T t = 0; t = t+t; })); // More if needed

/** $(LUCKY Fibonacci) Numbers (Infinite Range).
	See_Also: http://forum.dlang.org/thread/dqlrfoxzsppylcgljyyf@forum.dlang.org#post-mailman.1072.1350619455.5162.digitalmars-d-learn:40puremagic.com
	See_Also: https://www.reddit.com/r/programming/comments/rif9x/uniform_function_call_syntax_for_the_d/
*/
auto fibonacci(T = int)(in T nth = 0) if (isIntLike!T) {
	static struct Result {
		T a, b;
		void popFront() {
			const T c = a+b;
			a = b;
			b = c;
		}
	pragma(inline, true):
		inout(T) front() inout => b;
		enum bool empty = false;
	}
	return nth == 0 ? Result(0, 1) : Result(1, 1);
}

///
pure @safe unittest {
	import std.range: take;
	assert(fibonacci.take(10).equal([1, 1, 2, 3, 5, 8, 13, 21, 34, 55]));
	assert(1.fibonacci.take(9).equal([1, 2, 3, 5, 8, 13, 21, 34, 55]));
}

/** Expand Static `array` into a parameter arguments (AliasSeq!).
	See_Also: http://forum.dlang.org/thread/hwellpcaomwbpnpofzlx@forum.dlang.org?page=1
*/
template expand(alias array, size_t idx = 0) if (__traits(isStaticArray, typeof(array))) {
	@property ref delay() { return array[idx]; }
	static if (idx + 1 < array.length) {
		import std.meta : AliasSeq;
		alias expand = AliasSeq!(delay, expand!(array, idx + 1));
	} else
		alias expand = delay;
}

///
pure @safe unittest {
	static void foo(int a, int b, int c) {
		version (show) {
			import std.stdio: writefln;
			writefln("a: %s, b: %s, c: %s", a, b, c);
		}
	}
	int[3] arr = [1, 2, 3];
	foo(expand!arr);
}

/** Python Style To-String-Conversion Alias. */
string str(T)(in T a) {
	import std.conv: to;
	return to!string(a);
}

/** Python Style Length Alias. */
auto len(T)(in T a) {
	return a.length;
}

///
pure @safe unittest {
	import std.algorithm.iteration: map;
	import std.array: array;
	assert(([42].map!str).array == [`42`]);
}

import std.range: InputRange, OutputRange;
alias Source = InputRange; // nicer alias
alias Sink = OutputRange; // nicer alias

/* belongs to std.range */
import std.range: cycle, retro;
import std.functional: compose;
alias retroCycle = compose!(cycle, retro);

import std.traits: isAggregateType;

/** Generic Member Setter.
	See_Also: http://forum.dlang.org/thread/fdjkijrtduraaajlxxne@forum.dlang.org
*/
auto ref T set(string member, T, U)(auto ref T a, in U value)
if (isAggregateType!T &&
	__traits(hasMember, T, member)) {
	__traits(getMember, a, member) = value;
	return a;
}

///
pure @safe unittest {
	class C { int x, y, z, w; }
	auto c = new C().set!`x`(11).set!`w`(44);
	assert(c.x == 11);
	assert(c.w == 44);
}

/* Check if `part` is part of `whole`.
   See_Also: http://forum.dlang.org/thread/ls9dbk$jkq$1@digitalmars.com
   TODO: Standardize name and remove alises.
 */
bool isSliceOf(T)(in T[] part,
				  in T[] whole) {
	return (whole.ptr <= part.ptr &&
			part.ptr + part.length <=
			whole.ptr + whole.length);
}

/* See_Also: http://forum.dlang.org/thread/cjpplpzdzebfxhyqtskw@forum.dlang.org#post-cjpplpzdzebfxhyqtskw:40forum.dlang.org */
auto dropWhile(alias pred = `a == b`, R, E)(R range, E element)
if (isInputRange!R &&
	is (typeof(binaryFun!pred(range.front, element)) : bool)) {
	alias predFun = binaryFun!pred;
	return range.find!(a => !predFun(a, element));
}
alias dropAllOf = dropWhile;
alias stripFront = dropWhile;
alias lstrip = dropWhile;	   // Python style

import std.algorithm.searching: until;
alias takeUntil = until;

alias dropUntil = find;

///
pure @safe unittest {
	assert([1, 2, 3].dropWhile(1) == [2, 3]);
	assert([1, 1, 1, 2, 3].dropWhile(1) == [2, 3]);
	assert([1, 2, 3].dropWhile(2) == [1, 2, 3]);
	assert(`aabc`.dropWhile('a') == `bc`); /+ TODO: Remove restriction on cast to dchar +/
}

/* See_Also: http://forum.dlang.org/thread/cjpplpzdzebfxhyqtskw@forum.dlang.org#post-cjpplpzdzebfxhyqtskw:40forum.dlang.org */
auto takeWhile(alias pred = `a == b`, R, E)(R range, E element)
if (isInputRange!R &&
	is (typeof(binaryFun!pred(range.front, element)) : bool)) {
	import std.algorithm: until;
	alias predFun = binaryFun!pred;
	return range.until!(a => !predFun(a, element));
}
alias takeAllOf = takeWhile;

///
pure @safe unittest {
	assert(equal([1, 1, 2, 3].takeWhile(1),
				 [1, 1]));
}

/** Simpler variant of Phobos' `split`. */
auto split(alias pred, R)(R haystack)
if (isForwardRange!R) {
	import std.range.primitives : empty;
	static if (isSomeString!R ||
			   isRandomAccessRange!R) {
		auto balance = find!pred(haystack);
		immutable pos1 = haystack.length - balance.length;
		immutable pos2 = balance.empty ? pos1 : pos1 + 1;
		return tuple(haystack[0 .. pos1],
					 haystack[pos1 .. pos2],
					 haystack[pos2 .. haystack.length]);
	} else {
		import std.functional : unaryFun;
		auto original = haystack.save;
		auto h = haystack.save;
		size_t pos1, pos2;
		while (!h.empty) {
			if (unaryFun!pred(h.front)) {
				h.popFront();
				++pos2;
			} else {
				haystack.popFront();
				h = haystack.save;
				pos2 = ++pos1;
			}
		}
		/+ TODO: use Voldemort struct instead of tuple +/
		return tuple(takeExactly(original, pos1),
					 takeExactly(haystack, pos2 - pos1),
					 h);
	}
}

///
pure @safe unittest {
	import std.ascii: isDigit;
	assert(`aa1bb`.split!(a => a.isDigit) == tuple(`aa`, `1`, `bb`));
	assert(`aa1`.split!(a => a.isDigit) == tuple(`aa`, `1`, ``));
	assert(`1bb`.split!(a => a.isDigit) == tuple(``, `1`, `bb`));
}

/** Simpler variant of Phobos' `splitBefore`. */
auto splitBefore(alias pred, R)(R haystack)
if (isForwardRange!R) {
	static if (isSomeString!R ||
			   sRandomAccessRange!R) {
		auto balance = find!pred(haystack);
		immutable pos = haystack.length - balance.length;
		return tuple(haystack[0 .. pos],
					 haystack[pos .. haystack.length]);
	} else {
		import std.functional : unaryFun;
		auto original = haystack.save;
		auto h = haystack.save;
		size_t pos;
		import std.range.primitives : empty;
		while (!h.empty)
			if (unaryFun!pred(h.front))
				h.popFront();
			else {
				haystack.popFront();
				h = haystack.save;
				++pos;
			}
		/+ TODO: use Voldemort struct instead of tuple +/
		return tuple(takeExactly(original, pos),
					 haystack);
	}
}

///
pure @safe unittest {
	import std.ascii: isDigit;
	assert(`11ab`.splitBefore!(a => !a.isDigit) == tuple(`11`, `ab`));
	assert(`ab`.splitBefore!(a => !a.isDigit) == tuple(``, `ab`));
}

auto splitAfter(alias pred, R)(R haystack)
if (isForwardRange!R) {
	static if (isSomeString!R || isRandomAccessRange!R) {
		import std.range.primitives : empty;
		auto balance = find!pred(haystack);
		immutable pos = balance.empty ? 0 : haystack.length - balance.length + 1;
		/+ TODO: use Voldemort struct instead of tuple +/
		return tuple(haystack[0 .. pos], haystack[pos .. haystack.length]);
	} else {
		static assert(0, `How to implement this?`);
		// import std.range.primitives : empty;
		/* auto original = haystack.save; */
		/* auto h = haystack.save; */
		/* size_t pos1, pos2; */
		/* while (!n.empty) */
		/* { */
		/*	 if (h.empty) */
		/*	 { */
		/*		 // Failed search */
		/*		 return tuple(takeExactly(original, 0), original); */
		/*	 } */
		/*	 if (binaryFun!pred(h.front, n.front)) */
		/*	 { */
		/*		 h.popFront(); */
		/*		 n.popFront(); */
		/*		 ++pos2; */
		/*	 } */
		/*	 else */
		/*	 { */
		/*		 haystack.popFront(); */
		/*		 n = needle.save; */
		/*		 h = haystack.save; */
		/*		 pos2 = ++pos1; */
		/*	 } */
		/* } */
		/* return tuple(takeExactly(original, pos2), h); */
	}
}

///
pure @safe unittest {
	import std.ascii: isDigit;
	assert(`aa1bb`.splitAfter!(a => a.isDigit) == tuple(`aa1`, `bb`));
	assert(`aa1`.splitAfter!(a => a.isDigit) == tuple(`aa1`, ``));
}

auto moveUntil(alias pred, R)(ref R r) if (isInputRange!R) {
	auto split = r.splitBefore!pred;
	r = split[1];
	return split[0];
}

///
pure @safe unittest {
	auto r = `xxx111`;
	auto id = r.moveUntil!(a => a == '1');
	assert(id == `xxx`);
	assert(r == `111`);
}

auto moveWhile(alias pred, R)(ref R r) if (isInputRange!R) {
	return r.moveUntil!(a => !pred(a));
}

///
pure @safe unittest {
	auto r = `xxx111`;
	auto id = r.moveWhile!(a => a == 'x');
	assert(id == `xxx`);
	assert(r == `111`);
}

/** Variant of `findSplitBefore` that destructively pops everything up to,
	not including, `needle` from `haystack`.
*/
auto findPopBefore(alias pred = `a == b`, R1, R2)(ref R1 haystack, R2 needle)
if (isForwardRange!R1 &&
	isForwardRange!R2) {
	import std.range.primitives : empty;
	if (needle.empty)
		return haystack[0 .. 0]; // contextual empty hit
	if (haystack.empty)
		return R1.init;
	import std.algorithm.searching : findSplitBefore;
	if (auto split = findSplitBefore!pred(haystack, needle)) /+ TODO: If which case are empty and what return value should they lead to? +/ {
		haystack = split[1];
		return split[0];
	} else
		return R1.init; /+ TODO: correct? +/
}

///
pure nothrow @safe @nogc unittest {
	auto haystack = `xy`;
	const needle = `z`;
	auto pop = haystack.findPopBefore(needle);
	assert(haystack == `xy`);
	assert(pop == ``);
}

///
pure nothrow @safe @nogc unittest {
	auto haystack = `xyz`;
	const needle = `y`;
	auto pop = haystack.findPopBefore(needle);
	assert(pop == `x`);
	assert(haystack == `yz`);
}

/** Variant of `findSplitAfter` that destructively pops everything up to,
	including, `needle` from `haystack`.
*/
auto findPopAfter(alias pred = `a == b`, R1, R2)(ref R1 haystack, R2 needle)
if (isForwardRange!R1 &&
	isForwardRange!R2) {
	import std.range.primitives : empty;
	if (needle.empty)
		return haystack[0 .. 0]; // contextual empty hit
	if (haystack.empty)
		return R1.init;
	import std.algorithm.searching : findSplitAfter;
	auto split = findSplitAfter!pred(haystack, needle);/+ TODO: use new interface to findSplitAfter +/
	if (split[0].empty)
		return R1.init; /+ TODO: correct? +/
	else {
		haystack = split[1];
		return split[0];
	}
}

///
pure nothrow @safe @nogc unittest {
	auto source = `xyz`;
	auto haystack = source;
	const needle = `y`;
	auto pop = haystack.findPopAfter(needle);
	assert(pop == `xy`);
	assert(haystack == `z`);
}

///
pure nothrow @safe @nogc unittest {
	auto source = `xy`;
	auto haystack = source;
	const needle = `z`;
	auto pop = haystack.findPopAfter(needle);
	assert(pop is null);
	assert(!pop);
	assert(haystack == source);
}

/** Find First Occurrence any of `needles` in `haystack`.
 *
 * Like to std.algorithm.find but takes an array of needles as argument instead
 * of a variadic list of key needle arguments.  Return found range plus index
 * into needles starting at 1 upon.
 */
Tuple!(R, size_t) findFirstOfAnyInOrder(alias pred = `a == b`, R)(R haystack, const R[] needles) {
	import std.algorithm.searching : find;
	switch (needles.length) {
		case 1:
			import std.range.primitives : empty;
			auto hit = haystack.find(needles[0]);
			return tuple(hit, hit.empty ? 0UL : 1UL);
		case 2:
			return haystack.find(needles[0],
								 needles[1]);
		case 3:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2]);
		case 4:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2],
								 needles[3]);
		case 5:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2],
								 needles[3],
								 needles[4]);
		case 6:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2],
								 needles[3],
								 needles[4],
								 needles[5]);
		case 7:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2],
								 needles[3],
								 needles[4],
								 needles[5],
								 needles[6]);
		case 8:
			return haystack.find(needles[0],
								 needles[1],
								 needles[2],
								 needles[3],
								 needles[4],
								 needles[5],
								 needles[6],
								 needles[7]);
		default:
			import std.conv: to;
			assert(0, `Too many keys ` ~ needles.length.to!string);
	}
}

///
pure @safe unittest {
	assert(`abc`.findFirstOfAnyInOrder([`x`]) == tuple(``, 0UL));
	assert(`abc`.findFirstOfAnyInOrder([`a`]) == tuple(`abc`, 1UL));
	assert(`abc`.findFirstOfAnyInOrder([`c`]) == tuple(`c`, 1UL));
	assert(`abc`.findFirstOfAnyInOrder([`a`, `b`]) == tuple(`abc`, 1UL));
	assert(`abc`.findFirstOfAnyInOrder([`a`, `b`]) == tuple(`abc`, 1UL));
	assert(`abc`.findFirstOfAnyInOrder([`x`, `b`]) == tuple(`bc`, 2UL));
}

Tuple!(R, size_t)[] findAllOfAnyInOrder(alias pred = `a == b`, R)(R haystack, R[] needles) {
	/+ TODO: Return some clever lazy range that calls each possible haystack.findFirstOfAnyInOrder(needles); +/
	return typeof(return).init;
}

/** Return true if all arguments `args` are strictly ordered, that is args[0] <
 * args[1] < args[2] < ... .
 *
 * TODO: CT-variant
 * See_Also: http://forum.dlang.org/thread/wzsdhzycwqyrvqmmttix@forum.dlang.org?page=2#post-vprvhifglfegnlvzqmjj:40forum.dlang.org
 */
bool areStrictlyOrdered(Ts...)(Ts args)
if (args.length >= 2 &&
	haveCommonType!Ts) {
	foreach (i, arg; args[1..$])
		if (args[i] >= arg)
			return false;
	return true;
}

///
pure nothrow @safe @nogc unittest {
	static assert(!__traits(compiles, areStrictlyOrdered()));
	static assert(!__traits(compiles, areStrictlyOrdered(1)));
	assert(areStrictlyOrdered(1, 2, 3));
	assert(!areStrictlyOrdered(1, 3, 2));
	assert(!areStrictlyOrdered(1, 2, 2));
	assert(areStrictlyOrdered('a', 'b', 'c'));
}

/** Return true if all arguments `args` are unstrictly ordered,
 * that is args[0] <= args[1] <= args[2] <= ... .
 *
 * TODO: CT-variant
 * See_Also: http://forum.dlang.org/thread/wzsdhzycwqyrvqmmttix@forum.dlang.org?page=2#post-vprvhifglfegnlvzqmjj:40forum.dlang.org
*/
bool areUnstrictlyOrdered(Ts...)(Ts args)
if (args.length >= 2 &&
	haveCommonType!Ts) {
	foreach (i, arg; args[1..$])
		if (args[i] > arg)
			return false;
	return true;
}

///
pure nothrow @safe @nogc unittest {
	static assert(!__traits(compiles, areUnstrictlyOrdered()));
	static assert(!__traits(compiles, areUnstrictlyOrdered(1)));
	assert(areUnstrictlyOrdered(1, 2, 2, 3));
	assert(!areUnstrictlyOrdered(1, 3, 2));
	assert(areUnstrictlyOrdered('a', 'b', 'c'));
}

import core.checkedint: addu, subu, mulu;

alias sadd = addu;
alias ssub = subu;
alias smul = mulu;

/** Distinct Elements of `r`.
 *
 * See_Also: http://forum.dlang.org/thread/jufggxqwzhlsmhshtnfj@forum.dlang.org?page=2
 * See_Also: http://dpaste.dzfl.pl/7b4b37b490a7
 */
auto distinct(R)(R r) if (isInputRange!(Unqual!R)) {
	import std.traits: ForeachType;
	bool[ForeachType!R] seen; /+ TODO: Use containers.hashset.HashSet +/
	import std.algorithm.iteration: filter;
	return r.filter!((k) {
						 if (k !in seen)
							 return false;
						 else
							 return seen[k] = true;
					 });
}

// pure @safe unittest
// {
//	 immutable first = [1, 0, 2, 1, 3];
//	 immutable second = [1,5,6];
//	 import std.range: chain, take;
//	 assert(equal(first.chain(second).distinct.take(5),
//				  [1, 0, 2, 3, 5]));
// }

/** Returns: `true` iff `needle` is equal to any of `haystack`, `false` otherwise. */
bool isAmong(alias pred = (a, b) => a == b, Value, Values...)(Value needle, Values haystack)
if (Values.length != 0) {
	import std.algorithm.comparison : among;
	return cast(bool)needle.among!pred(haystack);
}

///
pure nothrow @safe @nogc unittest {
	assert(`b`.isAmong(`a`, `b`));
	assert(!`c`.isAmong(`a`, `b`));
}

import std.traits : isExpressionTuple;
import nxt.traits_ex : haveCommonType;

/** Returns: `true` iff `value` is equal to any of `values`, `false` otherwise. */
template isAmong(values...)
if (isExpressionTuple!values &&
	values.length != 0) {
	bool isAmong(Value)(Value value)
		if (haveCommonType!(Value, values)) {
		switch (value) {
			foreach (uint i, v; values)
			case v:
				return true;
		default:
			return false;
		}
	}
}

///
pure nothrow @safe @nogc unittest {
	assert(`b`.isAmong!(`a`, `b`));
	assert(!`c`.isAmong!(`a`, `b`));
}

import std.algorithm.setops : cartesianProduct;

/** More descriptive alias. */
alias elementCombinations = cartesianProduct;

/** Reset all members in aggregate instance `c`.
 *
 * See_Also: http://forum.dlang.org/post/ckitmpguywfitgadfpkv@forum.dlang.org
 * See_Also: http://forum.dlang.org/post/fbs8b5$5bu$1@digitalmars.com
 */
void resetAllMembers(T)(T c)
if (is(T == class)) {
	foreach (ref m; c.tupleof) {
		import std.traits : isMutable;
		alias M = typeof(m);
		static if (isMutable!M)
			m = M.init;
	}
}

///
pure nothrow @safe unittest {
	class C {
		this (int a, int b, string c) {
			this.a = a;
			this.b = b;
			this.c = c;
		}
		int a; int b; string c;
	}
	void f(C c) { c.resetAllMembers(); }
	auto c = new C(1, 2, "3");
	assert(c.a == 1);
	assert(c.b == 2);
	assert(c.c == "3");
	f(c);
	assert(c.a == 0);
	assert(c.b == 0);
	assert(c.c == null);
}

/** Returns: `true` iff `r` contains strictly values that are strictly increase
 * with the increment `step`.
 *
 * See_Also: http://forum.dlang.org/post/mqjyhvqxepgfljpkxvmd@forum.dlang.org
 */
bool isLinearRamp(R)(R r, size_t step = 1)
if (isInputRange!R &&
	isIntegral!(ElementType!R)) {
	import std.algorithm.searching : findAdjacent;
	import std.range.primitives : empty;
	return r.findAdjacent!((a, b) => a + step != b).empty;
}

bool hasHoles(R)(R r)
if (isInputRange!R &&
	isIntegral!(ElementType!R)) {
	return !r.isLinearRamp;
}

///
pure nothrow @safe unittest {
	assert([1].isLinearRamp);
	assert([1, 2, 3].isLinearRamp);
	assert(![1, 1].isLinearRamp);
	assert(![1, 2, 1].isLinearRamp);
	assert(![1, 2, 4].isLinearRamp);
}

/** Check if `r` counts to exactly `exactCount` elements.
 */
bool countsExactly(R)(R r, size_t exactCount) @("complexity", "O(exactCount)")
if (isInputRange!R) {
	import std.range.primitives : hasLength;
	static if (hasLength!R)
		return r.length == exactCount;
	else {
		size_t n = 0;
		import std.range.primitives : empty;
		while (!r.empty) {
			r.popFront();
			if (++n > exactCount)
				return false;
		}
		return n == exactCount;
	}
}

/** Check if `r` counts to at least `minCount` elements.
 */
bool countsAtLeast(R)(R r, size_t minCount) @("complexity", "O(minCount)")
if (isInputRange!R) {
	import std.range.primitives : hasLength;
	static if (hasLength!R)
		return r.length >= minCount;
	else {
		size_t n;
		import std.range.primitives : empty;
		while (!r.empty) {
			r.popFront();
			if (++n >= minCount)
				return true;
		}
		return false;
	}
}

/** Check if `r` counts to at most `maxCount` elements.
 */
bool countsAtMost(R)(R r, size_t maxCount) @("complexity", "O(maxCount)")
if (isInputRange!R) {
	import std.range.primitives : hasLength;
	static if (hasLength!R)
		return r.length <= maxCount;
	else {
		size_t n;
		import std.range.primitives : empty;
		while (!r.empty) {
			r.popFront();
			if (++n > maxCount)
				return false;
		}
		return true;
	}
}

///
pure nothrow @safe @nogc unittest {
	static void test(R)(R x)
		if (isInputRange!R) {
		import std.algorithm.searching : count;
		immutable n = x.count;

		// below
		foreach (immutable i; 0 .. n) {
			assert(x.countsAtLeast(i));
			assert(!x.countsExactly(i));
			assert(!x.countsAtMost(i));
		}

		// at
		assert(x.countsAtLeast(n));
		assert(x.countsExactly(n));
		assert(x.countsAtMost(n));

		// above
		foreach (immutable i; n + 1 .. n + 10) {
			assert(!x.countsAtLeast(i));
			assert(!x.countsExactly(i));
			assert(x.countsAtMost(i));
		}
	}

	import std.algorithm.iteration : filter;
	import std.range : iota;

	test(3.iota.filter!(x => true));

	int[3] x = [0, 1, 2];
	test(x[]);
}

import std.meta : allSatisfy;
import std.range.primitives : hasLength;

/** Returns: `true` iff `r` and all `ss` all have equal length.
 */
bool equalLength(R, Ss...)(const R r, const Ss ss)
if (Ss.length != 0 &&
	allSatisfy!(hasLength, R, Ss)) {
	foreach (const ref s; ss)
		if (r.length != s.length)
			return false;
	return true;
}

///
pure nothrow @safe unittest {
	assert(equalLength([1], [2], [3]));
	assert(!equalLength([1, 1], [2], [3]));
	assert(!equalLength([1], [2, 2], [3]));
	assert(!equalLength([1], [2], [3, 3]));
}

/** Collect/Gather the elements of `r` into a `Container` and return it.
 *
 * TODO: Use std.container.util.make instead?: https://dlang.org/phobos/std_container_util.html#.make
 * TODO: Rename `container` to `output`?
 * TODO: Support Set-containers via `insert` aswell, or add `alias put = insert` to them?
 * TODO: What about `Appender`?
 * TODO: Rename from `collect` to `gather`.
 */
Container collect(Container, Range) (Range r)
	// if (isInputRange!Range &&
	//	 isOutputRange!(Container, ElementType!Range))
{
	static if (hasLength!Range) {
		static if (isArray!Container) {
			import std.array : uninitializedArray;
			auto output = uninitializedArray!(Container)(r.length);
		}
		else
		{
			Container output;
			output.length = r.length;
		}
		import std.algorithm.mutation : copy;
		r.copy(output[]);	   // slicing is @trusted
		return output;
	}
	else
	{
		static if (isArray!Container) {
			import std.array : Appender;
			Appender!Container output;
			foreach (ref e; r)  /+ TODO: make const when this works with array_ex +/
				output.put(e);
			return output.data;
		}
		else
		{
			Container output;
			foreach (ref e; r)  /+ TODO: make const when this works with array_ex +/
				output ~= e; /+ TODO: use Appender or remove because too GC.intensive inefficient, or reuse `.array`? +/
			return output;
		}
	}
}

///
pure nothrow @safe unittest {
	import std.range : iota;
	import std.algorithm.iteration : map, filter;
	import nxt.algorithm_ex : collect;

	alias E = int;
	alias V = E[];
	immutable n = 1000;

	auto x = 0.iota(n).collect!V;

	assert([0, 1, 2].map!(_ => _^^2).collect!V.equal([0, 1, 4]));
	assert([0, 1, 2, 3].filter!(_ => _ & 1).collect!V.equal([1, 3]));
}

/** Returns: `x` eagerly split in two parts, all as equal in length as possible.
 *
 * Safely avoids range checking thanks to D's builtin slice expressions.
 * Use in divide-and-conquer algorithms such as quicksort and binary search.
 */
auto spliced2(T)(T[] x) @trusted {
	static struct Result /+ Voldemort type +/ {
		T[] first;			  // first half
		T[] second;			 // second half
	}
	immutable m = x.length / 2;
	// range checking is not needed
	return Result(x.ptr[0 .. m], // can be @trusted
				  x.ptr[m .. x.length]); // can be @trusted
}
alias halved = spliced2;

///
pure nothrow @safe @nogc unittest {
	immutable int[6] x = [0, 1, 2, 3, 4, 5];
	immutable y = x.spliced2;
	assert(y.first.equal(x[0 .. 3]));
	assert(y.second.equal(x[3 .. $]));
}

/** Returns: `x` eagerly split in three parts, all as equal in length as possible.
 *
 * Safely avoids range checking thanks to D's builtin slice expressions.
 * Use in divide-and-conquer algorithms such as quicksort and binary search.
 */
auto spliced3(T)(T[] x) @trusted {
	enum count = 3;
	static struct Result /+ Voldemort type +/ {
		T[] first;			  // first half
		T[] second;			 // second half
		T[] third;			  // third half
	}
	// range checking is not needed
	immutable m = 1*x.length/count;
	immutable n = 2*x.length/count;
	return Result(x.ptr[0 .. m], // can be @trusted
				  x.ptr[m .. n], // can be @trusted
				  x.ptr[n .. x.length]); // can be @trusted
}

pure nothrow @safe @nogc unittest {
	immutable int[6] x = [0, 1, 2, 3, 4, 5];
	immutable y = x.spliced3;
	assert(y.first.equal(x[0 .. 2]));
	assert(y.second.equal(x[2 .. 4]));
	assert(y.third.equal(x[4 .. 6]));
}

/** Splice `x` in `N` parts, all as equal in lengths as possible.
 *
 * Safely avoids range checking thanks to D's builtin slice expressions.
 * Use in divide-and-conquer algorithms such as quicksort and binary search.
 */
auto splicerN(uint N, T)(T[] x) @trusted {
	static struct Result /+ Voldemort type +/ {
		enum count = N;
		pragma(inline) @trusted pure nothrow @nogc:

		/// Returns: `i`:th slice.
		inout(T)[] at(uint i)() inout {
			static assert(i < N, "Index " ~ i ~ " to large");
			static if (i == 0)
				return _.ptr[0 .. (i + 1)*_.length/N]; // can be @trusted
			else static if (i + 1 == N)
				return _.ptr[i * _.length/N .. _.length]; // can be @trusted
			else
				return _.ptr[i * _.length/N .. (i + 1)*_.length/N]; // non-range-checked can be @trusted
		}

		private T[] _;
	}
	return Result(x);
}

///
pure nothrow @safe @nogc unittest {
	enum count = 6;

	immutable int[count] x = [0, 1, 3, 3, 4, 5];
	immutable y = x.splicerN!count;

	static foreach (i; 0 .. count) {
		assert(y.at!i.equal(x[i .. i + 1]));
	}
}

/** Specialization of `splicerN` to `N` being 2. */
auto splicer2(T)(T[] x) @trusted {
	static struct Result /+ Voldemort type +/ {
		enum count = 2;
		pragma(inline) @trusted pure nothrow @nogc:

		/// Returns: first part of splice.
		@property inout(T)[] first() inout {
			return _.ptr[0 .. _.length/count]; // can be @trusted
		}

		/// Returns: second part of splice.
		@property inout(T)[] second() inout {
			return _.ptr[_.length/count .. _.length]; // can be @trusted
		}

		inout(T)[] at(uint i)() inout {
			static assert(i < count, "Index " ~ i ~ " to large");
			static	  if (i == 0)
				return first;
			else static if (i == 1)
				return second;
		}

		private T[] _;
	}
	return Result(x);
}

///
pure nothrow @safe @nogc unittest {
	immutable int[6] x = [0, 1, 2, 3, 4, 5];
	immutable y = x.splicer2;
	assert(y.first.equal(x[0 .. 3]));
	assert(y.second.equal(x[3 .. $]));
	assert(y.at!0.equal(x[0 .. 3]));
	assert(y.at!1.equal(x[3 .. $]));
}

/** Specialization of `splicerN` to `N` being 3. */
auto splicer3(T)(T[] x) @trusted {
	static struct Result /+ Voldemort type +/ {
		enum count = 3;
		pragma(inline) @trusted pure nothrow @nogc:

		/// Returns: first part of splice.
		@property inout(T)[] first() inout {
			return _.ptr[0 .. _.length/count];  // can be @trusted
		}

		/// Returns: second part of splice.
		@property inout(T)[] second() inout {
			return _.ptr[_.length/count .. 2*_.length/count];  // can be @trusted
		}

		/// Returns: third part of splice.
		@property inout(T)[] third() inout {
			return _.ptr[2*_.length/count .. _.length]; // can be @trusted
		}

		private T[] _;
	}
	return Result(x);
}

///
pure nothrow @safe @nogc unittest {
	immutable int[6] x = [0, 1, 3, 3, 4, 5];
	immutable y = x.splicer3;
	assert(y.first.equal(x[0 .. 2]));
	assert(y.second.equal(x[2 .. 4]));
	assert(y.third.equal(x[4 .. $]));
}

/**
   See_Also: http://forum.dlang.org/post/mqfaevkvhwwtzaafrtve@forum.dlang.org
 */
auto use(alias F, T)(T t) if (is(typeof(F(T.init)))) => F(t);

pure nothrow @safe @nogc unittest {
	foreach (const i; 1 .. 11)
		foreach (const j; 1 .. 11)
			immutable result = (i * j).use!(x => x*x);
}

import nxt.char_traits : isASCII;

/** TOOD Merge into Phobos' startsWith. */
template startsWith(needles...)
if (isExpressionTuple!needles &&
	needles.length != 0) {
	uint startsWith(Haystack)(Haystack haystack) @trusted
		if (!is(CommonType!(typeof(Haystack.front), needles) == void)) {
		if (haystack.length == 0)
			return 0;
		static if (isArray!Haystack &&
				   is(typeof(Haystack.init[0]) : char) &&
				   allSatisfy!(isASCII, needles)) {
			// no front decoding needed
			static if (needles.length == 1)
				return haystack.ptr[0] == needles[0] ? 1 : 0;
			else {
				import std.algorithm.comparison : among;
				return haystack.ptr[0].among!(needles);
			}
		} else {
			import std.range.primitives : front; // need decoding
			import std.algorithm.comparison : among;
			return haystack.front.among!(needles);
		}
	}
}

pure nothrow @safe @nogc unittest {
	const haystack = "abc";
	assert(haystack.startsWith!('a'));
	assert(!haystack.startsWith!('b'));
}

pure @safe unittest {
	const haystack = "äbc";
	assert(haystack.startsWith!('ä'));
}

pure nothrow @safe @nogc unittest {
	const haystack = "abc";
	assert(haystack.startsWith!('b') == 0);
	assert(haystack.startsWith!('a') == 1);
	assert(haystack.startsWith!('_',
								'a') == 2);
}

/** TOOD Merge into Phobos' endsWith. */
template endsWith(needles...)
if (isExpressionTuple!needles &&
	needles.length != 0) {
	uint endsWith(Haystack)(Haystack haystack)
		@trusted
	if (!is(CommonType!(typeof(Haystack.back), needles) == void)) {
		if (haystack.length == 0)
			return 0;
		static if (isArray!Haystack &&
				   is(Unqual!(typeof(Haystack.init[0])) == char) && /+ TODO: reuse existing trait +/
				   allSatisfy!(isASCII, needles)) {
			// no back decoding needed
			static if (needles.length == 1)
				return haystack.ptr[haystack.length - 1] == needles[0] ? 1 : 0;
			else {
				import std.algorithm.comparison : among;
				return haystack.ptr[haystack.length - 1].among!(needles);
			}
		} else {
			import std.range.primitives : back; // need decoding
			import std.algorithm.comparison : among;
			return haystack.back.among!(needles);
		}
	}
}

pure nothrow @safe @nogc unittest {
	const haystack = "abc";
	assert(haystack.endsWith!('b') == 0);
	assert(haystack.endsWith!('c') == 1);
	assert(haystack.endsWith!('_',
							  'c') == 2);
}

pure @safe unittest {
	const haystack = "abć";
	assert(haystack.endsWith!('ć'));
}

/**
 * Allows forbidden casts.
 *
 * Params:
 *	  OT = The output type.
 *	  IT = The input type, optional, likely to be infered.
 *	  it = A reference to an IT.
 *
 * Returns:
 *	  the same as $(D cast(OT) it), except that it never fails to compile.
 */
auto bruteCast(OT, IT)(auto ref IT it) => *cast(OT*) &it;

///
@trusted nothrow pure @nogc unittest {
	static immutable array = [0u,1u,2u];
	size_t len;
	//len = cast(uint) array; // not allowed.
	len = bruteCast!uint(array);
	assert(len == array.length);
}

/** Split `range` using multiple separators stored as elements in `separators`.
 *
 * See_Also: https://forum.dlang.org/post/nv60ra$9vc$1@digitalmars.com
 */
auto splitterN(R, S)(scope return R range,
					 const scope S separators) {
	import std.algorithm.iteration : splitter;
	import std.algorithm.searching : canFind;
	return range.splitter!(element => separators.canFind(element));
}

///
pure @safe unittest {
	auto result = "a-b+c".splitterN("+-");
	assert(result.equal(["a", "b", "c"].s[]));
}

// splitter is nothrow @nogc when `haystack` is of same NarrowString as `needle`
pure nothrow @safe @nogc unittest {
	import std.algorithm.iteration : splitter;
	assert("a b".splitter(" ").equal(["a", "b"].s[]));
}

version (unittest) {
	import std.algorithm.comparison : equal;
	import nxt.array_help : s;
}
