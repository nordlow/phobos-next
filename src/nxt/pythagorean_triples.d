/** Pythogorean triple generators.
 *
 * See_Also: https://forum.dlang.org/post/q08qsm$22j3$1@digitalmars.com
 */
module nxt.pythagorean_triples;

/// Pythogorean triple generator rangeg.
struct PossiblePythagoreanTriples(T) {
	/// Pythogorean triple.
	struct Triple
	{
		T x, y, z;
		version (none)
		void toString(Sink)(ref scope Sink sink) const @safe
		{
			import std.conv : to;
			sink(x.to!string);
			sink(",");
			sink(y.to!string);
			sink(",");
			sink(z.to!string);
		}
	}

	@property Triple front() const => _front;

	void nextTriple() {
		if (++_front.y == _front.z) {
			if (++_front.x == _front.z) {
				++_front.z;	 // if `_front.z` becomes 0 empty should be true
				_front.x = 1;
			}
			_front.y = _front.x;
		}
	}

	void popFront() {
		do {
			nextTriple();
		} while (_front.x*_front.x + _front.y*_front.y != _front.z*_front.z);
	}

	enum empty = false;

	private Triple _front = Triple(1, 1, 2);
}

/// Get all Pythogorean triples in an infinite generator.
auto pythagoreanTriples(T = size_t)()
	=> PossiblePythagoreanTriples!T();

///
pure nothrow @safe @nogc unittest {
	auto t = pythagoreanTriples!size_t;
	alias Triple = typeof(t.front);
	assert(t.front == Triple(1,1,2)); t.popFront();
	assert(t.front == Triple(3,4,5)); t.popFront();
	assert(t.front == Triple(6,8,10)); t.popFront();
	assert(t.front == Triple(5,12,13)); t.popFront();
	assert(t.front == Triple(9,12,15)); t.popFront();
	assert(t.front == Triple(8,15,17)); t.popFront();
	assert(t.front == Triple(12,16,20)); t.popFront();
}
