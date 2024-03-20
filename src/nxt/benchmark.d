/** Extensions to std.datetime.benchmark.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	TODO: Mimic benchmark.run at https://docs.modular.com/mojo/stdlib/benchmark/benchmark
	TODO: Use ggplot or similar to visualize results.
	TODO: Use `nxt.sampling` to generate test data.
*/
module nxt.benchmark;

/** Behavior or reservation of space for a specific implicit length/size/count.
 */
enum ReserveSupport {
	no,							///< Reservation is not (yet) supported.
	yes,						///< Reservation is supported.
	always,	///< Reservation is not needed because of unconditional pre-allocation, either static or dynamic.
}

struct Results {
	import core.time : Duration;
	@property void toString(Sink)(ref scope Sink sink) const {
		import std.format : formattedWrite;
		foreach (memberName; __traits(allMembers, typeof(this))) {
			const member = __traits(getMember, this, memberName);
			alias Member = typeof(member);
			static if (is(immutable Member == immutable Duration)) {
				if (member == Member.init)
					continue;
				sink.formattedWrite("%s: %s ns/op",
									memberName,
									cast(double)(member).total!"nsecs" / elementCount);
			}
		}
	}
	string typeName;
	size_t elementCount;
	size_t runCount;
	private Duration _insertWithoutGrowthTime;
	private Duration _insertWithGrowthTime;
	private Duration _removeTime;
	private Duration _containsTime;
	private Duration _inTime;
	private Duration _rehashTime;
	private Duration _inAfterRehashTime;
	private Duration _indexTime;
	private Duration _appendTime;
}

/// Number of run per benchmark.
debug
	static immutable runCountDefault = 3; // lighter test in debug mode
else
	static immutable runCountDefault = 10;

/// Formatting uses some extra space but should be removed when outputting to plots.
static immutable formatNsPerOp = "%6.1f ns/op";

/** Benchmark append operation available in type `A` with test source `S`.
 */
Results benchmarkAppendable(A, Sample, Source)(in Source testSource, in size_t runCount = runCountDefault) {
	import core.time : Duration;
	import std.datetime : MonoTime;
	import std.conv : to;
	import std.algorithm.searching : minElement, maxElement;
	import std.stdio : writef, writefln;

	ReserveSupport reserveSupport;
	auto results = typeof(return)(A.stringof, testSource.length, runCount);

	writef("- ");

	scope spans = new Duration[runCount];

	A _ = makeWithRequestedCapacity!(A)(0, reserveSupport);
	foreach (const runIx; 0 .. runCount) {
		A a = makeWithRequestedCapacity!(A)(results.elementCount, reserveSupport);
		const start = MonoTime.currTime();
		foreach (immutable i; testSource) {
			static	  if (is(typeof(a ~= i)))
				a ~= i;
			else static if (is(typeof(a ~= i.to!Sample)))
				a ~= i.to!Sample;
			else static if (is(typeof(a.put(i))))
				a.put(i);
			else static if (is(typeof(a.put(i.to!Sample))))
				a.put(i.to!Sample);
			else
				static assert(0, "Cannot append a `" ~ typeof(i).stringof ~ "` to a `" ~ A.stringof ~ "`");
		}
		spans[runIx] = MonoTime.currTime() - start;
		static if (__traits(hasMember, A, `clear`) &&
				   is(typeof(a.clear())))
			a.clear();
	}
	results._appendTime = spans[].minElement();
	writef("append (%s) (~=): "~formatNsPerOp,
		   reserveSupport == ReserveSupport.no ? "no growth" : "with growth",
		   cast(double)(results._appendTime).total!"nsecs" / results.elementCount);

	writefln(` for %s`, A.stringof);

	return results;
}

/** Benchmark set (container) type `A` with test source `S`.
 */
Results benchmarkSet(A, Sample, Source)(in Source testSource, in size_t runCount = runCountDefault)
/+ TODO: if (isSet!A) +/
{
	import core.time : Duration;
	import std.datetime : MonoTime;
	import std.conv : to;
	import std.stdio : writef, writefln, writeln;
	import std.algorithm.searching : minElement, maxElement;
	import nxt.address : AlignedAddress;

	alias Address = AlignedAddress!1;

	ReserveSupport reserveSupport;
	scope spans = new Duration[runCount];
	auto results = typeof(return)(A.stringof, testSource.length, runCount);

	writef("- ");

	A a;
	{							// needs scope
		foreach (const runIx; 0 .. runCount) {
			const start = MonoTime.currTime();
			foreach (immutable i; testSource) {
				static if (__traits(hasMember, A, `ElementType`) &&
						   is(A.ElementType == ubyte[]))
					a.insert(i.toUbytes);
				else {
					static if (__traits(hasMember, A, `ElementType`)) {
						static if (is(A.ElementType == Address))
							const element = A.ElementType(i + 1); ///< Start at 1 instead of 0 because `Address` uses 0 for `nullValue`.
						else static if (is(A.ElementType : string) ||
										is(typeof(A.ElementType(string.init))))
							const element = A.ElementType(to!string(i));
						else
							const element = A.ElementType(i);
					}
					else
						const element = i;
					a.insert(element);
				}
			}
			spans[runIx] = MonoTime.currTime() - start;
			static if (__traits(hasMember, A, `clear`) &&
					   is(typeof(a.clear())))
				if (runIx+1 != runCount)
					a.clear();	// clear all but the last one needed in contains below
		}
		results._insertWithGrowthTime = spans[].minElement();
		writef("insert (with growth): "~formatNsPerOp,
			   cast(double)(results._insertWithGrowthTime).total!"nsecs" / results.elementCount);
	}

	{							// needs scope
		const start = MonoTime.currTime();
		size_t hitCount = 0;
		foreach (immutable i; testSource) {
			static if (__traits(hasMember, A, `ElementType`) &&
					   is(A.ElementType == ubyte[]))
				hitCount += a.contains(i.toUbytes);
			else {
				static if (__traits(hasMember, A, `ElementType`)) {
					static if (is(A.ElementType == Address))
						const element = A.ElementType(i + 1); ///< Start at 1 instead of 0 because `Address` uses 0 for `nullValue`.
					else static if (is(A.ElementType : string) ||
									is(typeof(A.ElementType(string.init))))
						const element = A.ElementType(to!string(i));
					else
						const element = A.ElementType(i); // wrap in `i` in `Nullable`
				}
				else
					const element = i;
				static if (__traits(hasMember, A, "contains"))
					hitCount += a.contains(element);
				else static if (is(typeof(a.contains(element)) == bool))
					hitCount += a.contains(element);
				else static if (is(typeof(element in a) == bool))
					hitCount += element in a;
				else
					static assert(0,
								  "Cannot check that " ~
								  typeof(a).stringof ~
								  " contains " ~
								  typeof(element).stringof);
			}
		}
		const ok = hitCount == results.elementCount; // for side effect in output
		results._containsTime = MonoTime.currTime() - start;
		writef(", contains: "~formatNsPerOp~" ns/op (%s)",
			   cast(double)(results._containsTime).total!"nsecs" / results.elementCount,
			   ok ? "OK" : "ERR");
	}

	const _ = makeWithRequestedCapacity!(A)(0, reserveSupport);
	if (reserveSupport) {
		foreach (const runIx; 0 .. runCount) {
			A b = makeWithRequestedCapacity!(A)(results.elementCount, reserveSupport);
			const start = MonoTime.currTime();
			foreach (immutable i; testSource) {
				static if (__traits(hasMember, A, `ElementType`) &&
						   is(A.ElementType == ubyte[]))
					b.insert(i.toUbytes);
				else {
					static if (__traits(hasMember, A, `ElementType`)) {
						static if (is(A.ElementType == Address))
							const element = A.ElementType(i + 1); ///< Start at 1 instead of 0 because `Address` uses 0 for `nullValue`.
						else static if (is(A.ElementType : string) ||
										is(typeof(A.ElementType(string.init))))
							const element = A.ElementType(to!string(i));
						else
							const element = A.ElementType(i); // wrap in `i` in `Nullable`
					}
					else
						const element = i;
					b.insert(element);
				}
			}
			spans[runIx] = MonoTime.currTime() - start;
			static if (__traits(hasMember, A, `clear`) &&
					   is(typeof(b.clear())))
				b.clear();		  // TODO why does this fail for `RadixTreeMap`?

		}
		results._insertWithoutGrowthTime = spans[].minElement();
		writef(", insert (no growth): "~formatNsPerOp,
			   cast(double)(results._insertWithoutGrowthTime).total!"nsecs" / results.elementCount);
	}

	writef(` for %s`, A.stringof);

	static if (__traits(hasMember, A, `binCounts`))
		writef(" %s", a.binCounts());
	static if (__traits(hasMember, A, `smallBinCapacity`))
		writef(" smallBinCapacity:%s", A.smallBinCapacity);
	static if (__traits(hasMember, A, `averageProbeCount`))
		writef(" averageProbeCount:%s", a.averageProbeCount);

	writeln();

	return results;
}

/** Benchmark map (container) type `A` with test source `S`.
 */
Results benchmarkMap(A, Sample, Source)(in Source testSource, in size_t runCount = runCountDefault)
/+ TODO: if (isMap!A || __traits(isAssociativeArray, A)) +/
{
	import core.time : Duration;
	import std.datetime : MonoTime;
	import std.conv : to;
	import std.stdio : writef, writefln, writeln;
	import std.algorithm.searching : minElement, maxElement;
	import nxt.address : AlignedAddress;

	alias Address = AlignedAddress!1;

	ReserveSupport reserveSupport;
	scope spans = new Duration[runCount];
	auto results = typeof(return)(A.stringof, testSource.length, runCount);

	writef("- ");

	// determine key and value type. TODO: extract to trait `KeyValueType(A)`
	static if (is(A : V[K], K, V)) {
		alias KeyType = K;
		alias ValueType = K;
	} else {
		// determine key type. TODO: extract to trait `KeyType(A)`
		static if (is(A.KeyType)) {
			alias KeyType = A.KeyType;
		} else static if (is(typeof(A.KeyValue.key))) { // StringMap
			alias KeyType = typeof(A.KeyValue.key);
		} else static if (is(immutable typeof(A.keys()) == immutable K[], K)) { // emsi HashMap
			alias KeyType = K;
		} else static if (__traits(hasMember, A, "byKey")) { // emsi HashMap
			import std.range.primitives : std_ElementType = ElementType;
			alias KeyType = std_ElementType!(typeof(A.init.byKey()));
		} else {
			static assert(0, "Could not determine key type of " ~ A.stringof ~ " " ~ typeof(A.keys()).stringof);
		}
		// determine value type. TODO: extract to trait `ValueType(A)`
		static if (is(A.ValueType)) {
			alias ValueType = A.ValueType;
		} else static if (is(typeof(A.KeyValue.value))) { // StringMap
			alias ValueType = typeof(A.KeyValue.value);
		} else static if (__traits(hasMember, A, "byValue")) { // emsi HashMap
			import std.range.primitives : std_ElementType = ElementType;
			alias ValueType = std_ElementType!(typeof(A.init.byValue()));
		} else {
			static assert(0, "Could not determine value type of " ~ A.stringof);
		}
	}

	// determine element type. TODO: extract to trait `ElementType(A)` or reuse `std.primitives.ElementType`
	static if (is(A.ElementType)) {
		alias ElementType = A.ElementType;
	} else static if (is(A.KeyValue)) { // StringMap
		alias ElementType = A.KeyValue;
	} else static if (__traits(hasMember, A, "byKeyValue") || // emsi HashMap
					  !is(typeof(A.init.byKeyValue) == void)) {
		import std.range.primitives : std_ElementType = ElementType;
		alias ElementType = std_ElementType!(typeof(A.init.byKeyValue()));
	} else {
		static assert(0, "Could not determine element type of " ~ A.stringof);
	}

	// allocate
	const keys = iotaArrayOf!(KeyType)(0, results.elementCount);

	A a;

	// insert/opIndex without preallocation via void capacity(size_t)
	{
		foreach (const runIx; 0 .. runCount) {
			const start = MonoTime.currTime();
			foreach (immutable i; testSource) {
				static if (is(typeof(A.init.insert(ElementType.init)))) {
					static if (is(KeyType == Address))
						const element = ElementType(Address(keys[i] + 1), // avoid `Address.null Value`
													ValueType.init);
					else
						const element = ElementType(keys[i], ValueType.init);
					a.insert(element);
				}
				else
					a[keys[i]] = ValueType.init; // AAs
			}
			spans[runIx] = MonoTime.currTime() - start;
		}
		results._insertWithGrowthTime = spans[].minElement();
		writef("insert (with growth): "~formatNsPerOp,
			   cast(double)(results._insertWithGrowthTime).total!"nsecs" / results.elementCount);
	}

	// contains
	static if (is(typeof(A.init.contains(KeyType.init)) : bool)) {
		{
			bool okAll = true;
			foreach (const runIx; 0 .. runCount) {
				const start = MonoTime.currTime();
				size_t hitCount = 0;
				foreach (immutable i; testSource) {
					static if (is(KeyType == Address))
						hitCount += a.contains(Address(keys[i] + 1)); // avoid `Address.nullValue`
					else
						hitCount += a.contains(keys[i]) ? 1 : 0;
				}
				const ok = hitCount == results.elementCount; // for side effect in output
				if (!ok)
					okAll = false;
				spans[runIx] = MonoTime.currTime() - start;
			}
			results._containsTime = spans[].minElement();
			writef(", contains: "~formatNsPerOp~" ns/op (%s)",
				   cast(double)(results._containsTime).total!"nsecs" / results.elementCount,
				   okAll ? "OK" : "ERR");
		}
	}

	// in
	{
		bool okAll = true;
		foreach (const runIx; 0 .. runCount) {
			const start = MonoTime.currTime();
			size_t hitCount = 0;
			foreach (immutable i; testSource) {
				static if (is(KeyType == Address))
					hitCount += cast(bool)(Address(keys[i] + 1) in a); // avoid `Address.nullValue`
				else
					hitCount += cast(bool)(keys[i] in a);
			}
			const ok = hitCount == results.elementCount; // for side effect in output
			if (!ok)
				okAll = false;
			spans[runIx] = MonoTime.currTime() - start;
		}
		results._inTime = spans[].minElement();
		writef(",	   in: "~formatNsPerOp~" ns/op (%s)",
			   cast(double)(results._inTime).total!"nsecs" / results.elementCount,
			   okAll ? "OK" : "ERR");
	}

	// rehash (AAs) + in
	static if (is(typeof(a.rehash()))) {
		// rehash
		foreach (const runIx; 0 .. runCount) {
			const start = MonoTime.currTime();
			a.rehash();
			spans[runIx] = MonoTime.currTime() - start;
		}
		results._rehashTime = spans[].minElement();
		writef(", rehash: "~formatNsPerOp,
			   cast(double)(results._rehashTime).total!"nsecs" / results.elementCount);
		// in
		foreach (const runIx; 0 .. runCount) {
			const start = MonoTime.currTime();
			foreach (immutable i; testSource)
				const hit = keys[i] in a;
			spans[runIx] = MonoTime.currTime() - start;
		}
		results._inAfterRehashTime = spans[].minElement();
		writef(", in (after rehash): "~formatNsPerOp,
			   cast(double)(results._inAfterRehashTime).total!"nsecs" / results.elementCount);
	}

	A _ = makeWithRequestedCapacity!(A)(0, reserveSupport);
	if (reserveSupport) {
		bool unsupported = false;
		// insert/opIndex with preallocation via void capacity(size_t)
		foreach (const runIx; 0 .. runCount) {
			A b = makeWithRequestedCapacity!(A)(results.elementCount, reserveSupport);
			const start = MonoTime.currTime();
			foreach (immutable i; testSource) {
				static if (__traits(hasMember, A, "insert")) {
					static if (is(immutable A.KeyType == immutable Address))
						const key = Address(keys[i] + 1); // avoid `Address.nullValue`
					else
						const key = keys[i];
					static if (is(typeof(b.insert(key, ValueType.init))))
						b.insert(key, ValueType.init);
					else static if (is(typeof(b.insert(ElementType(key, ValueType.init)))))
						b.insert(ElementType(key, ValueType.init));
					else
					{
						pragma(msg, "Skipping unsupported insert for " ~ A.stringof);
						unsupported = true;
					}
				}
				else
					b[keys[i]] = ValueType.init;
			}
			spans[runIx] = MonoTime.currTime() - start;
			static if (__traits(hasMember, A, `clear`) &&
					   is(typeof(b.clear())))
				b.clear();
		}
		if (!unsupported) {
			results._insertWithoutGrowthTime = spans[].minElement();
			writef(", insert (no growth): "~formatNsPerOp,
				   cast(double)(results._insertWithoutGrowthTime).total!"nsecs" / results.elementCount);
		}
	}

	writef(` for %s`, A.stringof);

	static if (__traits(hasMember, A, `binCounts`))
		writef(" %s", a.binCounts());
	static if (__traits(hasMember, A, `smallBinCapacity`))
		writef(" smallBinCapacity:%s", A.smallBinCapacity);
	static if (__traits(hasMember, A, `totalProbeCount`))
		writef(" averageProbeCount:%s", cast(double)a.totalProbeCount/a.length);

	writeln();

	return results;
}

alias benchmarkAssociativeArray = benchmarkMap;

/** Make `A` and try setting its capacity to `results.elementCount`.
 */
auto makeWithRequestedCapacity(A)(size_t elementCount, out ReserveSupport reserveSupport) {
	static if (is(typeof(A.init.withCapacity(elementCount)))) {
		reserveSupport = ReserveSupport.yes;
		return A.withCapacity(elementCount);
	}
	else
	{
		static if (is(A == class))
			auto a = new A();
		else static if (is(A == struct))
			auto a = A();
		else
			A a;

		static if (__traits(hasMember, A, `reserve`)) {
			static if (__traits(compiles, { a.reserve(elementCount); })) {
				a.reserve(elementCount);
				reserveSupport = ReserveSupport.yes;
			}
			else static if (__traits(compiles, { a.reserve!uint(elementCount); })) {
				a.reserve!uint(elementCount);
				reserveSupport = ReserveSupport.yes;
			}
		}
		else static if (is(A == U[], U)) {
			// this doesn’t work aswell:
			// import std.range.primitives : ElementType;
			// return new ElementType!A[elementCount];
			a.reserve(elementCount); // See_Also: https://dlang.org/library/object/reserve.html
			reserveSupport = ReserveSupport.yes;
			return a;
		}
		else static if (is(A : V[K], K, V)) {
			static if (__traits(compiles, { a.reserve(elementCount); })) {
				a.reserve(elementCount); // builtin AA’s might get this later on
				reserveSupport = ReserveSupport.yes;
			}
		}
		else static if (is(typeof(a.reserve(elementCount)))) {
			a.reserve(elementCount);
			reserveSupport = ReserveSupport.yes;
		}

		static if (__traits(isPOD, A))
			return a;
		else
		{
			import std.algorithm.mutation : move;
			return move(a);
		}
	}
}

private T[] iotaArrayOf(T)(in size_t begin, in size_t end) {
	import std.typecons : Nullable;

	typeof(return) es = new T[end];
	foreach (immutable i; begin .. end) {
		static if (is(typeof(T(i)))) // if possible
			es[i] = T(i);	   // try normal construction
		else {
			import std.conv : to;
			static if (is(typeof(T(i))))
				es[i] = T(i);
			else static if (is(typeof(T(i.to!string))))
				es[i] = T(i.to!string);
			else static if (is(typeof(i.to!T)))
				es[i] = i.to!T;
			else static if (is(T == Nullable!(uint, uint.max))) /+ TODO: avoid this +/
				es[i] = T(cast(uint)i);
			else
				static assert(0, "Cannot convert `" ~ typeof(i).stringof ~ "` to `" ~ T.stringof ~ "`");
		}
	}
	return es;
}
