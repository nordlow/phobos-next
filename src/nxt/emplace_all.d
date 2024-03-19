module nxt.emplace_all;

/** Version of `std.algorithm.mutation.moveEmplaceAll` that works for uncopyable
 * element type `T`.
 */
void moveEmplaceAllNoReset(T)(scope T[] src,
							  scope T[] tgt) {
	assert(src.length == tgt.length);
	static if (__traits(isPOD, T)) {
		tgt[] = src[];
		src[] = T.init;
	}
	else
	{
		immutable n = src.length;
		/+ TODO: benchmark with `memmove` and `memset` instead +/
		import core.lifetime : moveEmplace;
		foreach (i; 0 .. n)
			moveEmplace(src[i], tgt[i]);
	}
}

pure nothrow @nogc unittest {
	import nxt.uncopyable_sample : Uncopyable;

	alias T = Uncopyable;
	enum n = 3;
	alias A = T[n];

	A x = [T(1), T(2), T(3)];
	A y = void;
	moveEmplaceAllNoReset(x[], y[]);

	foreach (immutable i; 0 .. n) {
		assert(x[i] == T.init);
		assert(*y[i].valuePointer == i + 1);
	}
}
