module nxt.appender_stack;

/** Stack using `std.array.Appender`.
 *
 * See_Also: http://forum.dlang.org/thread/wswbtzakdvpgaebuhbom@forum.dlang.org
 */
struct Stack(T) {
	import std.array : Appender;

	ref inout(T) top() inout @property => _app.data[$ - 1];
	bool empty() const @property => _app.data.length == 0;

	/// Pop back value.
	void pop() => _app.shrinkTo(_app.data.length - 1);

	/// Pop back value and return it.
	T takeBack() {
		T value = top;
		_app.shrinkTo(_app.data.length - 1);
		return value;
	}

	void push(T t) => _app.put(t);

	private Appender!(T[]) _app;
}

pure @safe unittest {
	alias T = uint;

	Stack!T s;
	assert(s.empty);

	// pushBack:

	s.push(13);
	assert(!s.empty);
	assert(s.top == 13);

	s.push(14);
	assert(!s.empty);
	assert(s.top == 14);

	s.push(15);
	assert(!s.empty);
	assert(s.top == 15);

	// pop:

	s.pop();
	assert(!s.empty);
	assert(s.top == 14);

	s.pop();
	assert(!s.empty);
	assert(s.top == 13);

	s.pop();
	assert(s.empty);

	// push:

	s.push(13);
	s.push(14);
	s.push(15);
	assert(!s.empty);
	assert(s.top == 15);

	// takeBack:

	assert(s.takeBack() == 15);
	assert(s.takeBack() == 14);
	assert(s.takeBack() == 13);

	assert(s.empty);
}
