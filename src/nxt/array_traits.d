module nxt.array_traits;

/// Is `true` iff `T` is a slice of `char`s.
enum isCharArray(T) = is(T : const(char)[]);

///
pure @safe unittest {
	static assert(isCharArray!(char[]));
	static assert(isCharArray!(const(char[])));
	static assert(isCharArray!(const char[]));
	static assert(isCharArray!(const const(char)[]));

	static assert(!isCharArray!(wstring));
	static assert(!isCharArray!(dstring));
}

/// Is `true` iff `T` is a slice of `char`s.
enum isArrayFast(T) = is(T : const(E)[], E);

///
pure @safe unittest {
	static assert(isArrayFast!(char[]));
	static assert(isArrayFast!(int[]));
	static assert(isArrayFast!(const(char[])));
	static assert(isArrayFast!(const char[]));
	static assert(isArrayFast!(const const(char)[]));
	static assert(isArrayFast!(string[]));
	static assert(isArrayFast!(immutable(int)[]));
	static assert(isArrayFast!(char[3]));
}

/// Is `true` iff `T` is a slice of `char`s.
enum isDynamicArrayFast(T) = is(T : const(E)[], E) && !__traits(isStaticArray, T);

///
pure @safe unittest {
	static assert(isDynamicArrayFast!(char[]));
	static assert(isDynamicArrayFast!(int[]));
	static assert(isDynamicArrayFast!(const(char[])));
	static assert(isDynamicArrayFast!(const char[]));
	static assert(isDynamicArrayFast!(const const(char)[]));
	static assert(isDynamicArrayFast!(string[]));
	static assert(isDynamicArrayFast!(immutable(int)[]));
	static assert(!isDynamicArrayFast!(char[3]));
}

/** Is `true` iff all `Ts` are slices with same unqualified matching element types.
 *
 * Used to define template-restrictions on template parameters of only arrays
 * (slices) of the same unqualified element types.
 */
template isSameSlices(Ts...)
if (Ts.length >= 2) {
	enum isSlice(T) = is(T : const(E)[], E);
	enum isSliceOf(T, E) = is(T : const(E)[]);
	static if (isSlice!(Ts[0])) {
		alias E = typeof(Ts[0].init[0]);
		static foreach (T; Ts[1 .. $]) {
			static if (is(typeof(isSameSlices) == void) && // not yet defined
					   !(isSliceOf!(T, E))) {
				enum isSameSlices = false;
			}
		}
		static if (is(typeof(isSameSlices) == void)) // if not yet defined
		{
			enum isSameSlices = true;
		}
	}
	else
	{
		enum isSameSlices = false;
	}
}

///
pure @safe unittest {
	static assert(isSameSlices!(int[], int[]));
	static assert(isSameSlices!(const(int)[], int[]));
	static assert(isSameSlices!(int[], const(int)[]));
	static assert(isSameSlices!(int[], immutable(int)[]));

	static assert(isSameSlices!(int[], int[], int[]));
	static assert(isSameSlices!(int[], const(int)[], int[]));
	static assert(isSameSlices!(int[], const(int)[], immutable(int)[]));
	static assert(isSameSlices!(const(int)[], const(int)[], const(int)[]));

	static assert(!isSameSlices!(int, char));
	static assert(!isSameSlices!(int, const(char)));
	static assert(!isSameSlices!(int, int));

	static assert(!isSameSlices!(int[], char[]));
	static assert(!isSameSlices!(int[], char[], char[]));
	static assert(!isSameSlices!(char[], int[]));

	static assert(!isSameSlices!(char[], dchar[]));
	static assert(!isSameSlices!(wchar[], dchar[]));
	static assert(!isSameSlices!(char[], wchar[]));
}
