module nxt.uncopyable_sample;

struct Uncopyable
{
	import nxt.qcmeman : malloc, free;

	// import nxt.debugio;

	pure nothrow @safe @nogc:

	this(uint i) @trusted
	{
		_i = cast(typeof(_i))malloc(1 * (*_i).sizeof);
		*_i = i;
		// dbg("allocated: ", _i, " being ", *_i);
	}

	this(this) @disable;

	~this() nothrow @trusted @nogc
	{
		if (_i)
		{
			// dbg("freeing: ", _i, " being ", *_i);
		}
		free(_i);
	}

	inout(uint)* valuePointer() inout { return _i; }

	typeof(this) dup()
	{
		return typeof(return)(*_i);
	}

	uint *_i;
}
