module nxt.concatenation;

/** Sum of the lengths of the static arrays 'A'.
 */
template sumOfLengths(A...)
if (A.length) {
	static if (A.length == 1) {
		static if (isType!(A[0])) {
			static if (__traits(isStaticArray, A[0]))
				enum sumOfLengths = A[0].length;
			else
				enum sumOfLengths = 1;
		}
		else
		{
			static if (__traits(isStaticArray, typeof(A[0])))
				enum sumOfLengths = A[0].length;
			else
				enum sumOfLengths = 1;
		}
	}
	else
		enum sumOfLengths = A[0].length + sumOfLengths!(A[1 .. $]);
}

/** Is `true` iff `T` is a type. */
private template isType(T)	   { enum isType = true; }
/// ditto
private template isType(alias T) { enum isType = false; }

pure nothrow @safe @nogc unittest {
	int[2] x, y, z;
	int w;
	static assert(sumOfLengths!(x, y, z, w) == 7);
}

/** Returns: concatenation of the static arrays `Args` as a static array.
 * Move to Phobos's std.array.
 */
StaticArrayElementType!(Args[0])[sumOfLengths!Args] concatenate(Args...)(const auto ref Args args) {
	pragma(inline, true);		 // must be inlineable
	typeof(return) result = void; // @trusted
	foreach (const i, arg; args) {
		static if (i == 0)
			enum offset = 0;
		else
			enum offset = sumOfLengths!(args[0 .. i]);
		static if (__traits(isStaticArray, typeof(arg)))
			result[offset .. offset + arg.length] = arg[];
		else
			result[offset] = arg;
	}
	return result;
}

private alias StaticArrayElementType(A : E[n], E, size_t n) = E;

pure nothrow @safe @nogc unittest {
	int[2] x = [11, 22];
	const int[2] y = [33, 44];
	const int w = 55;
	auto z = concatenate(x, y, w);
	static assert(is(typeof(z) == int[5]));
	assert(z == [11, 22, 33, 44, 55]);
}

import core.internal.traits : hasElaborateDestructor;
import core.internal.traits : Unqual;

/** Overload with faster compilation.
 */
Unqual!T[n + 1] concatenate(T, size_t n)(auto ref T[n] a, T b)
if (!hasElaborateDestructor!T) {
	pragma(inline, true);		 // must be inlineable
	typeof(return) c = void;
	c[0 .. n] = a;
	c[n] = b;
	return c;
}

pure nothrow @safe @nogc unittest {
	const int[2] x = [11, 22];
	int y = 33;
	auto z = concatenate(x, y);
	static assert(is(typeof(z) == int[3]));
	assert(z == [11, 22, 33]);
}
