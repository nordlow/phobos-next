/** First and Higher Order Statistics: $(LUCKY Histograms) and $(LUCKY N-grams).

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	TODO: Replace static ifs with static final switch when Issue 6921 is fixed

	TODO: Remove overloads using std.string:representation and use sparse maps
	over dchar for strings.
*/
module nxt.ngram;

// version = print;

import nxt.container.static_bitarray;
import std.range: InputRange, ElementType, isInputRange;
import std.traits: isSomeChar, isUnsigned, isIntegral, isFloatingPoint, Unqual, isIterable, isAssociativeArray, CommonType;
import std.stdint: uint64_t;
import std.typecons: Tuple, tuple;
import nxt.predicates: allZero, allEqualTo;
import nxt.nesses: denseness;
import nxt.rational: Rational;
// import msgpack;
import std.numeric: dotProduct;
import std.string: representation;
import std.conv: to;

/** N-Gram Model Kind. */
enum Kind
{
	saturated, // Standard Saturated Integers. Saturation is more robust than default integer wrap-around.
	binary // Binary Gram.
}

/** N-Gram Model Storage. */
enum Storage
{
	denseDynamic,// Dynamically allocated dense storage.
	denseStatic, // Statically allocated dense storage.
	sparse, // N-Dimensional/Level D Maps/Dictionaries.
}

/** N-Gram Model Symmetry. */
enum Symmetry
{
	ordered, // Order between elements matters.
	unordered, // Order of elements is ignored (relaxed). Tuples are sorted before inserted.
}

/**
   Computes $(LUCKY N-Gram) Model of Input Range $(D range).

   If N == 1 this N-gram becomes a standard $(LUCKY Histogram), also called a
   $(LUCKY Unigram).

   If Bin/Bucket Type $(D RequestedBinType), requested by user, is $(D void) it
   will be chosen automatically based on element type of $(D Range).

   TODO: Add optimized put() be precalculating maximum number of elements that
   can be inserted without any risk overflow.
*/
struct NGram(ValueType,
			 int N = 1,
			 Kind kind = Kind.saturated,
			 Storage storage = Storage.denseDynamic,
			 Symmetry symmetry = Symmetry.ordered,
			 RequestedBinType = void,
			 Range) if (is(RequestedBinType == void) ||
						isUnsigned!RequestedBinType ||
						isFloatingPoint!RequestedBinType)
{
	this(in Range range) @safe pure nothrow { put(range); }

	auto ref value() @property @safe pure inout nothrow { return _bins; }

	alias Q = Rational!ulong;

	@property static int order() @safe pure nothrow { return N; }

	enum isBinary = (kind == Kind.binary);
	enum isDense = (storage == Storage.denseStatic ||
					storage == Storage.denseDynamic);
	enum isSparse = !isDense;
	enum cacheDeepDenseness = false;

	enum getStorage = storage;

	/** Returns: Documentation of the type of $(D this). */
	string typeName() @property const
	{
		string prefix;
		static	  if (N == 1) { prefix = "Uni"; }
		else static if (N == 2) { prefix = "Bi"; }
		else static if (N == 3) { prefix = "Tri"; }
		else static if (N == 4) { prefix = "Qua"; }
		else static if (N == 5) { prefix = "Pen"; }
			else					{ prefix = to!string(N) ~ "-"; }
		string rval;
		static if (isBinary)
		{
			rval ~= "Bit";
		}
		else
		{
			rval ~= BinType.stringof;
		}
		rval ~= "-" ~ prefix ~ "Gram over " ~ ValueType.stringof ~ "s";
		return rval;
	}

	string toString() @property const
	{
		string rval = typeName ~ ": ";

		// print contents
		static if (isAA)
		{
			rval ~= to!string(_bins);
		}
		else if (N >= 2 ||
				 this.denseness < Q(1, 2)) // if less than half of the bins are occupied
		{
			// show as sparse
			rval ~= "[";

			/+ TODO: Replace these with recursion? +/
			static if (N == 1)
			{
				bool begun = false;
				foreach (ix, elt; _bins) /+ TODO: Make static_bitarray support ref foreach and make elt const ref +/
				{
					if (elt)
					{
						if (begun) { rval ~= ", "; }
						rval ~= "{" ~ to!string(ix) ~ "}#" ~ to!string(elt);
						begun = true;
					}
				}
			}
			else static if (N == 2)
			{
				bool begun = false;
				foreach (ix0, const ref elt0; _bins)
				{
					foreach (ix1, elt1; elt0) /+ TODO: Make static_bitarray support ref foreach and make elt1 const ref +/
					{
						if (elt1)
						{
							if (begun) { rval ~= ", "; }
							rval ~= ("{" ~
									 to!string(ix0) ~ "," ~
									 to!string(ix1) ~ "}#" ~
									 to!string(elt1));
							begun = true;
						}
					}
				}
			}
			else static if (N == 3)
			{
				bool begun = false;
				foreach (ix0, const ref elt0; _bins)
				{
					foreach (ix1, const ref elt1; elt0)
					{
						foreach (ix2, elt2; elt1) { /+ TODO: Make static_bitarray support ref foreach and make elt2 const ref +/
							if (elt2)
							{
								if (begun) { rval ~= ", "; }
								rval ~= ("{" ~
										 to!string(ix0) ~ "," ~
										 to!string(ix1) ~ "," ~
										 to!string(ix2) ~ "}#" ~
										 to!string(elt2));
								begun = true;
							}
						}
					}
				}
			}
			else static if (N == 4)
			{
				bool begun = false;
				foreach (ix0, const ref elt0; _bins)
				{
					foreach (ix1, const ref elt1; elt0)
					{
						foreach (ix2, elt2; elt1)
						{
							foreach (ix3, elt3; elt2) /+ TODO: Make static_bitarray support ref foreach and make elt2 const ref +/
							{
								if (elt3)
								{
									if (begun) { rval ~= ", "; }
									rval ~= ("{" ~
											 to!string(ix0) ~ "," ~
											 to!string(ix1) ~ "," ~
											 to!string(ix2) ~ "," ~
											 to!string(ix3) ~ "}#" ~
											 to!string(elt3));
									begun = true;
								}
							}
						}
					}
				}
			}
			else static if (N == 5)
			{
				bool begun = false;
				foreach (ix0, const ref elt0; _bins)
				{
					foreach (ix1, const ref elt1; elt0)
					{
						foreach (ix2, const ref elt2; elt1)
						{
							foreach (ix3, const ref elt3; elt2) /+ TODO: Make static_bitarray support ref foreach and make elt2 const ref +/
							{
								foreach (ix4, elt4; elt3) /+ TODO: Make static_bitarray support ref foreach and make elt2 const ref +/
								{
									if (elt4)
									{
										if (begun) { rval ~= ", "; }
										rval ~= ("{" ~
												 to!string(ix0) ~ "," ~
												 to!string(ix1) ~ "," ~
												 to!string(ix2) ~ "," ~
												 to!string(ix3) ~ "," ~
												 to!string(ix4) ~ "}#" ~
												 to!string(elt4));
										begun = true;
									}
								}
							}
						}
					}
				}
			}
			else
			{
				static assert(0, "N >= 5 not supported");
			}
			rval ~= "]";
		}
		else
		{
			rval ~= to!string(_bins); // default
		}

		static if (N == 1)
		{
			rval ~= " denseness:" ~ to!string(denseness);
		}
		else
		{
			rval ~= (" shallowDenseness:" ~ to!string(denseness(0)) ~
					 " deepDenseness:" ~ to!string(denseness(-1)));
		}

		return rval;
	}

	void reset() @safe nothrow
	{
		import nxt.algorithm_ex: reset;
		_bins.reset();
	}
	// alias reset = clear;

	bool empty() const @property pure @trusted nothrow
	{
		static if (isAA)
		{
			return _bins.length == 0;
		}
		else
		{
			return _bins.allZero;
		}
	}

	static if (N >= 2 &&
			   storage != Storage.sparse)
	{
		Q shallowDenseness() const pure @property @trusted nothrow
		{
			static if (N == 2)
			{
				ulong x = 0;
				foreach (const ref elt0; 0..combE) // every possible first ngram element
				{
					bool used = false;
					foreach (elt1; 0..combE) // every possible second ngram element
					{
						if (_bins[elt0][elt1]) // if any bit is used
						{
							used = true; // we flag it and exit
							break;
						}
					}
					if (used) ++x;
				}
				return Q(x, combE);
			}
			else
			{
				return Q(1, 1);
			}
		}
	}

	typeof(this) opAssign(RhsRange)(in NGram!(ValueType, N, kind, storage, symmetry, RequestedBinType, RhsRange) rhs)
	if (isInputRange!RhsRange) // if (is(Unqual!Range == Unqual!RhsRange))
	{
		static if	  (storage == Storage.denseDynamic)
			_bins = rhs._bins.dup;
		else static if (storage == Storage.sparse)
			_bins = cast(BinType[ValueType[N]])(rhs._bins.dup); /+ TODO: How can we prevent this cast? +/
		else static if (storage == Storage.denseStatic)
			_bins = rhs._bins;
		else
			static assert(0, "Cannot handle storage of type " ~ to!string(storage));
		return this;
	}

	static if (N == 1)
	{
		void normalize() @safe pure /* nothrow */
		{
			static if (kind != Kind.binary)
			{
				static if (isFloatingPoint!ValueType)
				{
					immutable scaleFactor = (cast(real)1) / _bins.length; // precalc scaling
				}
				foreach (ref elt; _bins) /+ TODO: Why can this throw for associative arrays? +/
				{
					static if (isIntegral!ValueType ||
							   isSomeChar!ValueType)
					{
						elt /= 2; // drop least significant bit
					}
					else static if (isFloatingPoint!ValueType)
					{
						elt =* scaleFactor;
					}
				}
			}
		}
	}

	/** Invalidate Local Statistics. */
	void invalidateStats() @safe nothrow
	{
		static if (isAA && cacheDeepDenseness) { _deepDenseness = 0; }
	}

	/** Saturated Increment $(D x) by one. */
	ref T incs(T)(ref T x) @safe nothrow if (isIntegral!T) { if (x != T.max) { ++x; invalidateStats(); } return x; }
	/** Saturated Increment $(D x) by one. */
	ref T incs(T)(ref T x) @safe nothrow if (isFloatingPoint!T) { invalidateStats(); return ++x; }

	static if (kind == Kind.saturated)
	{
		/** Increase bin of $(D ng).
			Bin of ng must already be allocated if its stored in a map.
		*/
		ref NGram inc(ValueType[N] ng) @safe pure nothrow
		{
			static if (isAA)
			{
				incs(_bins[ng]); // just one case!
			}
			else
			{
				static		if (N == 1)
				{
					static if (storage == Storage.denseDynamic)
					{
						if (!_bins) { _bins = new BinType[noABins]; }
					}
					incs(_bins[ng[0]]);
				}
				else static if (N == 2)
				{
					static if (storage == Storage.denseDynamic)
					{
						if (!_bins) { _bins = new BinType[][noABins]; }
						if (!_bins[ng[0]]) { _bins[ng[0]] = new BinType[noABins]; }
					}
					incs(_bins[ng[0]][ng[1]]);
				}
				else static if (N == 3)
				{
					static if (storage == Storage.denseDynamic)
					{
						if (!_bins) { _bins = new BinType[][][noABins]; }
						if (!_bins[ng[0]]) { _bins[ng[0]] = new BinType[][noABins]; }
						if (!_bins[ng[0]][ng[1]]) { _bins[ng[0]][ng[1]] = new BinType[noABins]; }
					}
					incs(_bins[ng[0]][ng[1]][ng[2]]);
				}
				else static if (N == 4)
				{
					static if (storage == Storage.denseDynamic)
					{
						if (!_bins) { _bins = new BinType[][][][noABins]; }
						if (!_bins[ng[0]]) { _bins[ng[0]] = new BinType[][][noABins]; }
						if (!_bins[ng[0]][ng[1]]) { _bins[ng[0]][ng[1]] = new BinType[][noABins]; }
						if (!_bins[ng[0]][ng[1]][ng[2]]) { _bins[ng[0]][ng[1]][ng[2]] = new BinType[noABins]; }
					}
					incs(_bins[ng[0]][ng[1]][ng[2]][ng[3]]);
				}
				else static if (N == 5)
				{
					static if (storage == Storage.denseDynamic)
					{
						if (!_bins) { _bins = new BinType[][][][][noABins]; }
						if (!_bins[ng[0]]) { _bins[ng[0]] = new BinType[][][][noABins]; }
						if (!_bins[ng[0]][ng[1]]) { _bins[ng[0]][ng[1]] = new BinType[][][noABins]; }
						if (!_bins[ng[0]][ng[1]][ng[2]]) { _bins[ng[0]][ng[1]][ng[2]] = new BinType[][noABins]; }
						if (!_bins[ng[0]][ng[1]][ng[2]][ng[3]]) { _bins[ng[0]][ng[1]][ng[2]][ng[3]] = new BinType[noABins]; }
					}
					incs(_bins[ng[0]][ng[1]][ng[2]][ng[3]][ng[4]]);
				}
				else
				{
					static assert(0, "N >= 6 not supported");
				}
			}
			return this;
		}
	}

	/** Returns: Bin Count of NGram $(D ng). */
	BinType opIndex(T)(in T ng) const @safe pure nothrow if (isIntegral!T ||
															 __traits(isStaticArray, T))
	{
		static if (isAA)
		{
			if (ng in _bins)
			{
				return _bins[ng];
			}
			else
			{
				return 0; // empty means zero bin
			}
		}
		else
		{
			static	  if (N == 1) { return _bins[ng]; }
			else static if (N == 2) { return _bins[ng[0]][ng[1]]; }
			else static if (N == 3) { return _bins[ng[0]][ng[1]][ng[2]]; }
			else static if (N == 4) { return _bins[ng[0]][ng[1]][ng[2]][ng[3]]; }
			else static if (N == 5) { return _bins[ng[0]][ng[1]][ng[2]][ng[3]][ng[4]]; }
			else { static assert(0, "N >= 6 not supported"); }
		}
	}

	/* ref BinType opIndexAssign(Index)(BinType b, Index i) @trusted pure nothrow if (isIntegral!Index) in { */

	/* } */

	/** Returns: Bin Count of NGram $(D ng). */
	auto opIndexAssign(T)(in T ng) const @safe pure nothrow if (isIntegral!T ||
																__traits(isStaticArray, T))
	{
		static if (isAA)
		{
			if (ng in _bins)
			{
				return _bins[ng];
			}
			else
			{
				return 0; // empty means zero bin
			}
		}
		else
		{
			static	  if (N == 1) { return _bins[ng]; }
			else static if (N == 2) { return _bins[ng[0]][ng[1]]; }
			else static if (N == 3) { return _bins[ng[0]][ng[1]][ng[2]]; }
			else static if (N == 4) { return _bins[ng[0]][ng[1]][ng[2]][ng[3]]; }
			else static if (N == 5) { return _bins[ng[0]][ng[1]][ng[2]][ng[3]][ng[4]]; }
			else { static assert(0, "N >= 6 not supported"); }
		}
	}

	/** Put NGram Element $(D ng) in $(D this).
	 */
	ref NGram put(ValueType[N] ng) @safe pure nothrow
	{
		static if (isBinary)
		{
			static	  if (N == 1) { _bins[ng[0]] = true; }
			else static if (N == 2) { _bins[ng[0]][ng[1]] = true; }
			else static if (N == 3) { _bins[ng[0]][ng[1]][ng[2]] = true; }
			else static if (N == 4) { _bins[ng[0]][ng[1]][ng[2]][ng[3]] = true; }
			else static if (N == 5) { _bins[ng[0]][ng[1]][ng[2]][ng[3]][ng[4]] = true; }
			else { static assert(0, "N >= 6 not supported"); }
		}
		else
		{
			static if (isAA)
			{
				if (ng in _bins)
				{
					inc(ng); // increase bin
				}
				else
				{
					_bins[ng] = 1; // initial bin count
				}
			}
			else
			{
				inc(ng);
			}
		}
		invalidateStats();
		return this;
	}

	/** Put NGram Elements $(D range) in $(D this).
	 */
	ref NGram put(T)(in T range) @safe pure nothrow if (isIterable!T)
	{
		static if (N == 1)
		{
			foreach (ix, const ref elt; range)
			{
				put([elt]);
			}
		}
		else static if (N == 2)
		{
			ValueType prev; // previous element
			foreach (ix, const ref elt; range)
			{
				if (ix >= N-1) { put([prev, elt]); }
				prev = elt;
			}
		}
		else static if (N == 3)
		{
			ValueType pprev, prev; // previous elements
			foreach (ix, const ref elt; range)
			{
				if (ix >= N-1) { put([pprev, prev, elt]); }
				pprev = prev;
				prev = elt;
			}
		}
		else static if (N == 4)
		{
			ValueType ppprev, pprev, prev; // previous elements
			foreach (ix, const ref elt; range)
			{
				if (ix >= N-1) { put([ppprev, pprev, prev, elt]); }
				ppprev = pprev;
				pprev = prev;
				prev = elt;
			}
		}
		else static if (N == 5)
		{
			ValueType pppprev, ppprev, pprev, prev; // previous elements
			foreach (ix, const ref elt; range)
			{
				if (ix >= N-1) { put([pppprev, ppprev, pprev, prev, elt]); }
				pppprev = ppprev;
				ppprev = pprev;
				pprev = prev;
				prev = elt;
			}
		}
		return this;
	}

	/** Scalar (Dot) Product Match $(D this) with $(D rhs). */
	CommonType!(ulong, BinType) matchDenser(rhsValueType,
											Kind rhsKind = Kind.saturated,
											Storage rhsStorage = Storage.denseDynamic,
											RhsRange)(in NGram!(rhsValueType,
																N,
																rhsKind,
																rhsStorage,
																symmetry,
																RequestedBinType,
																RhsRange) rhs) const @trusted pure /* nothrow */
	{
		static if (this.isDense && rhs.isDense)
		{
			static if (N == 1) return dotProduct(this._bins, rhs._bins);
			else static assert(0, "N >= " ~ to!string(N) ~ " not supported");
		}
		else static if (this.isSparse)
		{
			typeof(return) sum = 0;
			foreach (ix, const ref bin; _bins) // assume lhs is sparsest
			{
				sum += bin*rhs[ix];
			}
			return sum;
		}
		else static if (rhs.isSparse)
		{
			typeof(return) sum = 0;
			foreach (ix, const ref bin; rhs._bins) // assume lhs is sparsest
			{
				sum += this[ix]*bin;
			}
			return sum;
		}
		else
		{
			static assert(0, "Combination of " ~ typeof(storage).stringof ~ " and " ~
						  typeof(rhsStorage).stringof ~ " not supported");
			return 0;
		}
	}

	auto opBinary(string op,
				  string file = __FILE__, int line = __LINE__)(in NGram rhs) const @trusted pure /* nothrow */
	{
		NGram tmp;
		static if (this.isSparse ||
				   rhs.isSparse)
		{
			void doIt(in NGram a, in NGram b) // more functional than orderInPlace
			{
				foreach (ix, const ref bin; a._bins)
				{
					if (ix in b._bins)
					{
						mixin("tmp._bins[ix] = bin " ~ op ~ " b._bins[ix];"); // propagate pointwise operation
					}
				}
			}
			if (this.length < rhs.length) { doIt(this, rhs); }
			else						  { doIt(rhs, this); }
		}
		else static if (this.isBinary &&
						rhs.isBinary)
		{
			mixin("tmp._bins = _bins " ~ op ~ "rhs._bins;"); // bitsets cannot be sliced (yet)
		}
		else static if (this.isDense &&
						rhs.isDense &&
						N == 1)
		{
			assert(this.length == rhs.length);
			import std.range: zip;
			import std.algorithm: map;
			import std.array: array;
			tmp._bins = zip(this._bins[], rhs._bins[]).map!(a => mixin("a[0] " ~ op ~ "a[1]"))().array; /+ TODO: Use zipWith when Issue 8715 is fixed +/
			/* foreach (ix, let; this._bins) { /+ TODO: Reuse Phobos algorithm or range */ +/
			/*	 mixin("tmp[ix] = _bins[ix] " ~ op ~ "rhs._bins[ix];"); */
			/* } */
		}
		else
		{
			static assert(0, "Combination of " ~ to!string(this.getStorage) ~ " and " ~
						  to!string(rhs.getStorage) ~ " and N == " ~ to!string(N) ~ " not supported");
		}
		return tmp;
	}

	/** Determine Bin (Counter) Type. */
	static if (isBinary)
	{
		alias BinType = bool;
	}
	else static if (is(RequestedBinType == void))
	{
		alias BinType = uint64_t;   // Bin (counter) type. Count long by default.
	}
	else
	{
		alias BinType = RequestedBinType;
	}

	enum bitsE = 8 * ValueType.sizeof; /** Number of Bits in ValueType (element). TODO: This may have to be fixed for ref types. */
	enum combE = 2^^bitsE;  /** Number of combinations in element. */
	enum noABins = combE; // Number of bins per array dimension
	enum noBins = combE^^N; /** Maximum number of bins (possible). */

	// Determine storage structure base on element type.
	static if (storage == Storage.sparse)
	{
		BinType[ValueType[N]] _bins;
	}
	else static if (isBinary &&
					N*bitsE <= 32) // safely fits on stack
	{
		static if		(storage == Storage.denseStatic)
		{
			static	  if (N == 1) StaticBitArray!noABins _bins;
			else static if (N == 2) StaticBitArray!noABins[noABins] _bins;
			else static if (N == 3) StaticBitArray!noABins[noABins][noABins] _bins;
			else static assert(0, "Dense static N >= 4 does no safely fit on stack");
		}
		else static if (storage == Storage.denseDynamic)
		{
			static	  if (N == 1) StaticBitArray!noABins _bins;
			else static if (N == 2) StaticBitArray!noABins[] _bins;
			else static if (N == 3) StaticBitArray!noABins[][] _bins;
			else static if (N == 4) StaticBitArray!noABins[][][] _bins;
			else static if (N == 5) StaticBitArray!noABins[][][][] _bins;
			else static assert(0, "N >= 6 not supported");
		}
		else static if (storage == Storage.sparse) // shouldn't happen
		{
		}
	}
	else static if (storage == Storage.denseStatic &&
					(isUnsigned!ValueType ||
					 isSomeChar!ValueType) &&
					N*bitsE <= 16) // safely fits on stack
	{
		static	  if (N == 1) BinType[noABins] _bins;
		else static if (N == 2) BinType[noABins][noABins] _bins;
		else static assert(0, "Dense static N >= 3 does not safely fit on stack");
	}
	else static if (storage == Storage.denseDynamic &&
					(isUnsigned!ValueType ||
					 isSomeChar!ValueType)) // safely fits on stack
	{
		static	  if (N == 1) BinType[] _bins;
		else static if (N == 2) BinType[][] _bins;
		else static if (N == 3) BinType[][][] _bins;
		else static if (N == 4) BinType[][][][] _bins;
		else static if (N == 5) BinType[][][][][] _bins;
		else static assert(0, "N >= 6 not supported");
	}
	else
	{
		BinType[ValueType[N]] _bins;
	}

	private alias _bins this;

	enum isAA = isAssociativeArray!(typeof(_bins));

	static if (isAA && cacheDeepDenseness)
	{
		ulong _deepDenseness;	// Cache deep denseness in associative arrays
	}

	Q densenessUncached(int depth = -1) const pure @property @trusted nothrow
	{
		static if (isBinary)
		{
			static if (N >= 2)
			{
				if (N == 2 && depth == 0)  // if shallow wanted
				{
					return shallowDenseness();
				}
			}
			return _bins.denseness;
		}
		else
		{
			static if (isAA)
			{
				return Q(_bins.length, noBins);
			}
			else
			{
				return _bins.denseness(depth);
			}
		}
	}

	/** Returns: Number of Non-Zero Elements in $(D range). */
	Q denseness(int depth = -1) const pure @property @safe nothrow
	{
		static if (isAA && cacheDeepDenseness)
		{
			if (depth == -1)  // -1 means deepDenseness
			{
				if (!_deepDenseness)  // if not yet defined.
				{
					unqual(this).densenessUncached(depth).numerator; // calculate it
				}
				return Q(_deepDenseness, noBins);
			}
		}
		return densenessUncached(depth);
	}
}

/**
   Computes $(LUCKY Bi-Gram) of $(D range).
*/
auto ngram(int N = 2,
		   Kind kind = Kind.saturated,
		   Storage storage = Storage.denseDynamic,
		   Symmetry symmetry = Symmetry.ordered,
		   RequestedBinType = void,
		   Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), N,
				  kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
auto sparseUIntNGramOverRepresentation(int N = 2,
									   Kind kind = Kind.saturated,
									   Symmetry symmetry = Symmetry.ordered)(in string range) @safe pure nothrow
{
	auto y = range.representation;
	return ngram!(N, kind, Storage.sparse, symmetry, uint)(y);
}

auto histogram(Kind kind = Kind.saturated,
			   Storage storage = Storage.denseDynamic,
			   Symmetry symmetry = Symmetry.ordered,
			   RequestedBinType = void,
			   Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 1, kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
alias Hist = NGram;
alias hist = histogram;
alias unigram = histogram;

unittest {
	const ubyte[] x = [1, 2, 3, 4, 5];
	const h = x.histogram!(Kind.saturated, Storage.denseStatic);
	const hh = h + h;

	auto h2 = x.histogram!(Kind.saturated, Storage.denseStatic);
	h2.put(x);
	assert(hh == h2);
}

unittest {
	const ubyte[] x;
	const hDS = x.histogram!(Kind.saturated, Storage.denseStatic);  assert(hDS.empty);

	const hDD = x.histogram!(Kind.saturated, Storage.denseDynamic); assert(hDD.empty);

	auto h = x.histogram!(Kind.saturated, Storage.sparse); assert(h.empty);
	const ubyte[5] x1 = [1, 2, 3, 4, 5];
	h.put(x1); assert(!h.empty);
	assert(h.matchDenser(h) == x1.length);
	auto hh = h + h;
	assert(hh.matchDenser(hh) == 4*x1.length);

	h.destroy(); assert(h.empty);

	auto hU32 = x.histogram!(Kind.saturated, Storage.sparse, Symmetry.ordered, uint);
}

unittest {
	alias ValueType = ubyte;
	const ValueType[3] x = [11, 12, 13];

	auto h = x.histogram!(Kind.saturated, Storage.denseStatic);
	assert(h[0] == 0);
	assert(h[11] == 1 && h[12] == 1 && h[13] == 1);
	assert(3 == h.matchDenser(h));

	h.put(x);
	assert(h[11] == 2 && h[12] == 2 && h[13] == 2);
	assert(12 == h.matchDenser(h));

	version (print) dbg(h);

	auto hD = x.histogram!(Kind.saturated, Storage.denseDynamic);
	version (print) dbg(hD);
}

unittest {
	alias ValueType = ulong;
	const ValueType[3] x = [1, 2, 3];
	auto h = x.histogram!(Kind.saturated, Storage.denseStatic);
	h.put([4, 5, 6]);
	assert(h.length == 6);
}

/**
   Computes $(LUCKY Binary Histogram) of $(D range).
*/
auto bistogram(Range)(in Range range) @safe pure nothrow if (isIterable!Range)

{
	return NGram!(Unqual!(ElementType!Range), 1,
				  Kind.binary,
				  Storage.denseStatic,
				  Symmetry.ordered,
				  void,
				  Unqual!Range)(range);
}
alias bunigram = bistogram;

unittest {
	const ubyte[] x;
	const b = x.bistogram;
	assert(b.empty);

	// test const unqualification
	NGram!(ubyte, 1, Kind.binary, Storage.denseStatic, Symmetry.ordered, void, const(ubyte)[]) cb;
	cb = b;
	assert(cb == b);

	// test immutable unqualification
	NGram!(ubyte, 1, Kind.binary, Storage.denseStatic, Symmetry.ordered, void, immutable(ubyte)[]) ib;
	ib = b;
	assert(ib == b);
}

unittest {
	const ubyte[3] x = [1, 2, 3];
	const h_ = x.bistogram;
	assert(8*h_.sizeof == 2^^8);
	const h = h_;
	assert(h[1] && h[2] && h[3]);
	assert(!h[0]);
	assert(!h[4]);

	const h2_ = h_;
	assert((h2_ & h_) == h2_);
	assert((h2_ | h_) == h2_);
	assert((h2_.value & h_.value) == h2_.value);
	assert((h2_.value | h_.value) == h2_.value);
}
unittest {
	const ushort[3] x = [1, 2, 3];
	const h_ = x.bistogram;
	assert(8*h_.sizeof == 2^^16);
	const h = h_;
	assert(h[1] && h[2] && h[3]);
	assert(!h[0]);
	assert(!h[4]);
}

/**
   Computes $(LUCKY Binary (Occurrence) NGram) of Bytes in Input String $(D x).
*/
auto bistogramOverRepresentation(in string x) pure nothrow

{
	return bistogram(x.representation);
}
unittest {
	const x = "abcdef";
	auto h = x.bistogramOverRepresentation;
	size_t ix = 0;
	foreach (const bin; h)
	{
		if (ix >= cast(ubyte)'a' &&
			ix <= cast(ubyte)'f')
		{
			assert(bin);
		}
		else
		{
			assert(!bin);
		}
		++ix;
	}
	version (print) dbg(h);
}

/**
   Computes $(LUCKY Bi-Gram) of $(D range).
*/
auto bigram(Kind kind = Kind.saturated,
			Storage storage = Storage.denseDynamic,
			Symmetry symmetry = Symmetry.ordered,
			RequestedBinType = void,
			Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 2,
				  kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
auto sparseUIntBigram(Kind kind = Kind.saturated,
					  Symmetry symmetry = Symmetry.ordered,
					  Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 2,
				  kind, Storage.sparse, symmetry, uint, Unqual!(Range))(range);
}

unittest {
	const ubyte[] x = [1, 2, 3, 3, 3, 4, 4, 5];

	auto bSp = x.bigram!(Kind.saturated, Storage.sparse);
	alias SparseNGram = Unqual!(typeof(bSp));

	// check msgpacking
	// auto bSPBytes = bSp.pack();
	// SparseNGram bSp_;
	// bSPBytes.unpack(bSp_);
	// assert(bSp == bSp_);

	auto bS = x.bigram!(Kind.saturated, Storage.denseStatic);
	const bSCopy = bS;
	bS.put(x);
	assert(bS != bSCopy);

	const bD = x.bigram!(Kind.saturated, Storage.denseDynamic);
	version (print) dbg(bD);

	const bb = x.bigram!(Kind.binary, Storage.denseStatic);
	version (print) dbg(typeof(bb._bins).stringof);

	assert(bb.denseness(0).numerator == 4);
	// assert(bb.denseness(-1).numerator == 6);
}
unittest {
	const ubyte[] x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

	const bS = x.bigram!(Kind.saturated, Storage.denseStatic);
	version (print) dbg(bS);
	assert(bS.denseness.numerator == x.length - bS.order + 1);

	const bB = x.bigram!(Kind.binary, Storage.denseStatic);
	version (print) dbg(bB);
}

unittest {
	const x = [1, 2, 3, 4, 5];
	auto h = x.bigram!(Kind.saturated, Storage.sparse);
	assert(h.matchDenser(h) == x.length - 1);
}

/**
   Computes $(LUCKY Tri-Gram) of $(D range).
*/
auto trigram(Kind kind = Kind.saturated,
			 Storage storage = Storage.denseDynamic,
			 Symmetry symmetry = Symmetry.ordered,
			 RequestedBinType = void,
			 Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 3,
				  kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
auto sparseUIntTrigram(Kind kind = Kind.saturated,
					  Symmetry symmetry = Symmetry.ordered,
					  Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 3,
				  kind, Storage.sparse, symmetry, uint, Unqual!(Range))(range);
}
unittest {
	const ubyte[] x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

	const bS = x.trigram!(Kind.saturated, Storage.denseStatic);
	version (print) dbg(bS);
	assert(bS.denseness.numerator == x.length - bS.order + 1);

	const bD = x.trigram!(Kind.saturated, Storage.denseDynamic);
	version (print) dbg(bD);

	const bB = x.trigram!(Kind.binary, Storage.denseStatic);
	/* version (print) dbg(bB); */
}

/**
   Computes $(LUCKY Qua-Gram) of $(D range).
*/
auto quagram(Kind kind = Kind.saturated,
			 Storage storage = Storage.denseDynamic,
			 Symmetry symmetry = Symmetry.ordered,
			 RequestedBinType = void,
			 Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 4,
				  kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
auto sparseUIntQuagram(Kind kind = Kind.saturated,
					   Symmetry symmetry = Symmetry.ordered,
					   Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 4,
				  kind, Storage.sparse, symmetry, uint, Unqual!(Range))(range);
}
unittest {
	const ubyte[] x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

	const bD = x.quagram!(Kind.saturated, Storage.denseDynamic);
	version (print) dbg(bD);
	assert(bD.denseness.numerator == x.length - bD.order + 1);
}
auto sparseUIntQuagramOverRepresentation(in string x) pure nothrow
{
	return sparseUIntQuagram(x.representation);
}

/**
   Computes $(LUCKY Pen-Gram) of $(D range).
*/
auto pengram(Kind kind = Kind.saturated,
			 Storage storage = Storage.denseDynamic,
			 Symmetry symmetry = Symmetry.ordered,
			 RequestedBinType = void,
			 Range)(in Range range) @safe pure nothrow if (isIterable!Range)
{
	return NGram!(Unqual!(ElementType!Range), 5,
				  kind, storage, symmetry, RequestedBinType, Unqual!(Range))(range);
}
unittest {
	const ubyte[] x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

	const bS = x.pengram!(Kind.saturated, Storage.sparse);
	const bS_ = bS;
	assert(bS_ == bS);

	// skipping denseStatic because it doesn't fit stack anyway

	const bD = x.pengram!(Kind.saturated, Storage.denseDynamic);
	version (print) dbg(bD);
	assert(bD.denseness.numerator == x.length - bD.order + 1);
}
