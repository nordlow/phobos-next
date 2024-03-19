import core.thread : Fiber;

class MyFiber : Fiber
{
	int _depth;
	ulong _index;
	ulong _value;

	this(int depth, ulong index)
	{
		super(&run);
		_depth = depth;
		_index = index;
	}

	void run()
	{
		if (_depth == 6) // 10^6 == 1 million, so stop here.
		{
			_value = _index;
			return;
		}

		_value = 0;
		foreach (immutable i; 0..10) // Line 23
		{
			auto e = new MyFiber(_depth+1, _index * 10 + i);
			e.call();
			_value += e._value;
		}
	}
}

unittest {
	import std.stdio : writeln;
	import std.datetime.datetime : StopWatch, AutoStart;
	auto sw = StopWatch(AutoStart.yes);
	auto a = new MyFiber(0, 0);
	a.call();
	sw.stop();
	assert(a._value == 499999500000);
	writeln(a._value, " after ", sw.peek.msecs, " msecs");
}
