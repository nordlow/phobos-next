/++ Limits.
 +/
module nxt.limits;

/** Limit/Span (Min,Max) Pair.
 *
 * TODO: Relate|Unite with `nxt.sampling.Span`.
 * TODO: Simultaneous min and max (minmax) can be optimized to 3/4 comparison.
 * TODO: Decide on either `Span`, `MinMax` or `Limits`
 * See_Also: https://stackoverflow.com/questions/21241878/generic-span-type-in-phobos
 */
struct Limits(T) {
	auto ref include(in T a) {
		import std.algorithm.comparison : min, max;
		_min = min(_min, a);
		_max = max(_max, a);
		return this;
	}
	alias expand = include;
@property:
	T min() const => _min;
	T max() const => _max;
private:
	T _min = T.max;
	T _max = T.min;
}

///
@safe pure nothrow @nogc unittest {
	alias T = int;
	Limits!T x;
	assert(x.min == T.max);
	assert(x.max == T.min);
	x.expand(-10);
	x.expand(10);
	assert(x.min == -10);
	assert(x.max == +10);
}
