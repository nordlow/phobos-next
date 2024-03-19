/** Integer Sorting Algorithms.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
 */
module nxt.integer_sorting;

version = nxt_benchmark;
// version = show;

import std.range.primitives : isRandomAccessRange, ElementType;
import std.traits : isNumeric;
import std.meta : AliasSeq;

import nxt.bijections;

/** Radix sort of `input`.

	Note that this implementation of non-inplace radix sort only requires
	`input` to be a `BidirectionalRange` not a `RandomAccessRange`.

	Note that `input` can be a `BidirectionalRange` aswell as
	`RandomAccessRange`.

	`radixBitCount` is the number of bits in radix (digit)

	TODO: make `radixBitCount` a template parameter either 8 or 16,
	ElementType.sizeof must be a multiple of radixBitCount

	TODO: input[] = y[] not needed when input is mutable

	TODO: Restrict fun.

	TODO: Choose fastDigitDiscardal based on elementMin and elementMax (if they
	are given)

	See_Also: https://probablydance.com/2016/12/27/i-wrote-a-faster-sorting-algorithm/
	See_Also: https://github.com/skarupke/ska_sort/blob/master/ska_sort.hpp
	See_Also: http://forum.dlang.org/thread/vmytpazcusauxypkwdbn@forum.dlang.org#post-vmytpazcusauxypkwdbn:40forum.dlang.org
 */
auto radixSort(R,
			   alias fun = "a",
			   bool descending = false,
			   bool requestDigitDiscardal = false,
			   bool inPlace = false)(R input,
									 /* ElementType!R elementMin = ElementType!(R).max, */
									 /* ElementType!R elementMax = ElementType!(R).min */)

	@trusted
if (isRandomAccessRange!R &&
	(isNumeric!(ElementType!R)))
{
	import std.range : assumeSorted;
	import std.algorithm.sorting : isSorted; /+ TODO: move this to radixSort when know how map less to descending +/
	import std.algorithm.comparison : min, max;
	import std.range.primitives : front;

	immutable n = input.length; // number of elements
	alias E = ElementType!R;
	enum elementBitCount = 8*E.sizeof; // total number of bits needed to code each element

	/* Lookup number of radix bits from sizeof `ElementType`.
	   These give optimal performance on Intel Core i7.
	*/
	static if (elementBitCount == 8 ||
			   elementBitCount == 24)
		enum radixBitCount = 8;
	else static if (elementBitCount == 16 ||
					elementBitCount == 32 ||
					elementBitCount == 64)
		enum radixBitCount = 16;
	else
		static assert(0, "TODO: handle element type " ~ e.stringof);

	/+ TODO: activate this: subtract min from all values and then immutable uint elementBitCount = is_min(a_max) ? 8*sizeof(E) : binlog(a_max); and add it back. +/
	enum digitCount = elementBitCount / radixBitCount;		 // number of `digitCount` in radix `radixBitCount`
	static assert(elementBitCount % radixBitCount == 0,
				  "Precision of ElementType must be evenly divisble by bit-precision of Radix.");

	enum doDigitDiscardal = requestDigitDiscardal && digitCount >= 2;

	enum radix = cast(typeof(radixBitCount))1 << radixBitCount;	// bin count
	enum mask = radix-1;									 // radix bit mask

	alias UE = typeof(input.front.bijectToUnsigned); // get unsigned integer type of same precision as \tparam E.

	import nxt.container.fixed_dynamic_array : FixedDynamicArray;

	static if (inPlace) // most-significant digit (MSD) first in-place radix sort
	{
		static assert(!descending, "TODO: Implement descending version");

		foreach (immutable digitOffsetReversed; 0 .. digitCount) // for each `digitOffset` (in base `radix`) starting with least significant (LSD-first)
		{
			immutable digitOffset = digitCount - 1 - digitOffsetReversed;
			immutable digitBitshift = digitOffset*radixBitCount; // digit bit shift

			// [lowOffsets[i], highOffsets[i]] will become slices into `input`
			size_t[radix] lowOffsets; // low offsets for each bin
			size_t[radix] highOffsets; // high offsets for each bin

			// calculate counts
			foreach (immutable j; 0 .. n) // for each element index `j` in `input`
			{
				immutable UE currentUnsignedValue = cast(UE)input[j].bijectToUnsigned(descending);
				immutable i = (currentUnsignedValue >> digitBitshift) & mask; // digit (index)
				++highOffsets[i];   // increase histogram bin counter
			}

			// bin boundaries: accumulate bin counters array
			lowOffsets[0] = 0;			 // first low is always zero
			foreach (immutable j; 1 .. radix) // for each successive bin counter
			{
				lowOffsets[j] = highOffsets[j - 1]; // previous roof becomes current floor
				highOffsets[j] += highOffsets[j - 1]; // accumulate bin counter
			}
			assert(highOffsets[radix - 1] == n); // should equal high offset of last bin
		}

		// /** \em unstable in-place (permutate) reorder/sort `input`
		//  * access `input`'s elements in \em reverse to \em reuse filled caches from previous forward iteration.
		//  * \see `in_place_indexed_reorder`
		//  */
		// for (int r = radix - 1; r >= 0; --r) // for each radix digit r in reverse order (cache-friendly)
		// {
		//	 while (binStat[r])  // as long as elements left in r:th bucket
		//	 {
		//		 immutable uint i0 = binStat[r].pop_back(); // index to first element of permutation
		//		 immutable E	e0 = input[i0]; // value of first/current element of permutation
		//		 while (true)
		//		 {
		//			 immutable int rN = (e0.bijectToUnsigned(descending) >> digitBitshift) & mask; // next digit (index)
		//			 if (r == rN) // if permutation cycle closed (back to same digit)
		//				 break;
		//			 immutable ai = binStat[rN].pop_back(); // array index
		//			 swap(input[ai], e0); // do swap
		//		 }
		//		 input[i0] = e0;		 // complete cycle
		//	 }
		// }

		/+ TODO: copy reorder algorithm into local function that calls itself in the recursion step +/
		/+ TODO: call this local function +/

		assert(input.isSorted!"a < b");
	}
	else						// standard radix sort
	{
		// non-in-place requires temporary `y`. TODO: we could allocate these as
		// a stack-allocated array for small arrays and gain extra speed.
		auto tempStorage = FixedDynamicArray!E.makeUninitializedOfLength(n);
		auto tempSlice = tempStorage[];

		static if (doDigitDiscardal)
		{
			UE ors  = 0;		 // digits diff(xor)-or-sum
		}

		foreach (immutable digitOffset; 0 .. digitCount) // for each `digitOffset` (in base `radix`) starting with least significant (LSD-first)
		{
			immutable digitBitshift = digitOffset*radixBitCount;   // digit bit shift

			static if (doDigitDiscardal)
				if (digitOffset != 0) // if first iteration already performed we have bit statistics
					if ((! ((ors >> digitBitshift) & mask))) // if bits in digit[d] are either all \em zero or
						continue;			   // no sorting is needed for this digit

			// calculate counts
			size_t[radix] highOffsets; // histogram buckets count and later upper-limits/walls for values in `input`
			UE previousUnsignedValue = cast(UE)input[0].bijectToUnsigned(descending);
			foreach (immutable j; 0 .. n) // for each element index `j` in `input`
			{
				immutable UE currentUnsignedValue = cast(UE)input[j].bijectToUnsigned(descending);
				static if (doDigitDiscardal)
					if (digitOffset == 0) // first iteration calculates statistics
					{
						ors |= previousUnsignedValue ^ currentUnsignedValue; // accumulate bit change statistics
						// ors |= currentUnsignedValue; // accumulate bits statistics
					}
				immutable i = (currentUnsignedValue >> digitBitshift) & mask; // digit (index)
				++highOffsets[i];			  // increase histogram bin counter
				previousUnsignedValue = currentUnsignedValue;
			}

			static if (doDigitDiscardal)
				if (digitOffset == 0) // if first iteration already performed we have bit statistics
					if ((! ((ors >> digitBitshift) & mask))) // if bits in digit[d] are either all \em zero or
						continue;			   // no sorting is needed for this digit

			// bin boundaries: accumulate bin counters array
			foreach (immutable j; 1 .. radix) // for each successive bin counter
				highOffsets[j] += highOffsets[j - 1]; // accumulate bin counter
			assert(highOffsets[radix - 1] == n); // should equal high offset of last bin

			// reorder. access `input`'s elements in \em reverse to \em reuse filled caches from previous forward iteration.
			// \em stable reorder from `input` to `tempSlice` using normal counting sort (see `counting_sort` above).
			enum unrollFactor = 1;
			assert((n % unrollFactor) == 0, "TODO: Add reordering for remainder"); // is evenly divisible by unroll factor
			for (size_t j = n - 1; j < n; j -= unrollFactor) // for each element `j` in reverse order. when `j` wraps around `j` < `n` is no longer true
			{
				static foreach (k; 0 .. unrollFactor) // inlined (unrolled) loop
				{
					immutable i = (input[j - k].bijectToUnsigned(descending) >> digitBitshift) & mask; // digit (index)
					tempSlice[--highOffsets[i]] = input[j - k]; // reorder into tempSlice
				}
			}
			assert(highOffsets[0] == 0); // should equal low offset of first bin

			static if (digitCount & 1) // if odd number of digit passes
			{
				static if (__traits(compiles, input[] == tempSlice[]))
					input[] = tempSlice[]; // faster than std.algorithm.copy() because input never overlap tempSlice
				else
				{
					import std.algorithm.mutation : copy;
					copy(tempSlice[], input[]); /+ TODO: use memcpy +/
				}
			}
			else
			{
				import std.algorithm.mutation : swap;
				swap(input, tempSlice);
			}
		}
	}

	static if (descending)
		return input.assumeSorted!"a > b";
	else
		return input.assumeSorted!"a < b";
}

version (nxt_benchmark)
@safe unittest {
	version (show) import std.stdio : write, writef, writeln;

	/** Test `radixSort` with element-type `E`. */
	void test(E)(int n) @safe
	{
		version (show) writef("%8-s, %10-s, ", E.stringof, n);

		import nxt.container.dynamic_array : Array = DynamicArray;

		import std.traits : isIntegral, isSigned, isUnsigned;
		import nxt.random_ex : randInPlace, randInPlaceWithElementRange;
		import std.algorithm.sorting : sort, isSorted;
		import std.algorithm.mutation : SwapStrategy;
		import std.algorithm.comparison : min, max, equal;
		import std.range : retro;
		import std.datetime.stopwatch : StopWatch, AutoStart;
		auto sw = StopWatch();
		immutable nMax = 5;

		// generate random
		alias A = Array!E;
		A a;
		a.length = n;
		static if (isUnsigned!E) {
			// a[].randInPlaceWithElementRange(cast(E)0, cast(E)uint.max);
			a[].randInPlace();
		} else {
			a[].randInPlace();
		}
		version (show) write("original random: ", a[0 .. min(nMax, $)], ", ");

		// standard quick sort
		auto qa = a.dupShallow;

		sw.reset;
		sw.start();
		qa[].sort!("a < b", SwapStrategy.stable)();
		sw.stop;
		immutable sortTimeUsecs = sw.peek.total!"usecs";
		version (show) write("quick sorted: ", qa[0 .. min(nMax, $)], ", ");
		assert(qa[].isSorted);

		// reverse radix sort
		{
			auto b = a.dupShallow;
			b[].radixSort!(typeof(b[]), "a", true)();
			version (show) write("reverse radix sorted: ", b[0 .. min(nMax, $)], ", ");
			assert(b[].retro.equal(qa[]));
		}

		// standard radix sort
		{
			auto b = a.dupShallow;

			sw.reset;
			sw.start();
			b[].radixSort!(typeof(b[]), "b", false)();
			sw.stop;
			immutable radixTime1 = sw.peek.total!"usecs";

			version (show) writef("%9-s, ", cast(real)sortTimeUsecs / radixTime1);
			assert(b[].equal(qa[]));
		}

		// standard radix sort fast-discardal
		{
			auto b = a.dupShallow;

			sw.reset;
			sw.start();
			b[].radixSort!(typeof(b[]), "b", false, true)();
			sw.stop;
			immutable radixTime = sw.peek.total!"usecs";

			assert(b[].equal(qa[]));

			version (show)
			{
				writeln("standard radix sorted with fast-discardal: ",
						b[0 .. min(nMax, $)]);
			}
			version (show) writef("%9-s, ", cast(real)sortTimeUsecs / radixTime);
		}

		// inplace-place radix sort
		// static if (is(E == uint))
		// {
		//	 auto b = a.dupShallow;

		//	 sw.reset;
		//	 sw.start();
		//	 b[].radixSort!(typeof(b[]), "b", false, false, true)();
		//	 sw.stop;
		//	 immutable radixTime = sw.peek.usecs;

		//	 assert(b[].equal(qa[]));

		//	 version (show)
		//	 {
		//		 writeln("in-place radix sorted with fast-discardal: ",
		//				 b[0 .. min(nMax, $)]);
		//	 }
		//	 writef("%9-s, ", cast(real)sortTimeUsecs / radixTime);
		// }

		version (show) writeln("");
	}

	import std.meta : AliasSeq;
	immutable n = 1_00_000;
	version (show) writeln("EType, eCount, radixSort (speed-up), radixSort with fast discardal (speed-up), in-place radixSort (speed-up)");
	foreach (immutable ix, T; AliasSeq!(byte, short, int, long))
	{
		test!T(n); // test signed
		import std.traits : Unsigned;
		test!(Unsigned!T)(n); // test unsigned
	}
	test!float(n);
	test!double(n);
}

@safe unittest {
	import std.algorithm.sorting : sort, isSorted;
	import std.algorithm.mutation : swap;
	import std.meta : AliasSeq;
	import nxt.container.dynamic_array : Array = DynamicArray;
	import nxt.random_ex : randInPlace;
	immutable n = 10_000;
	foreach (ix, E; AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong, float, double)) {
		alias A = Array!E;
		A a;
		a.length = n;
		a[].randInPlace();
		auto b = a.dupShallow;
		assert(a[].radixSort() == b[].sort());
		swap(a, b);
	}
}

version (unittest) {
	import nxt.construction : dupShallow;
}
