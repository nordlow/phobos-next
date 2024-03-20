/++ Traits for __vector types.
 +/
module nxt.vector_traits;

@safe:

/++ Check if `arg` has the value `arg.init`. +/
bool isInit(E, uint N)(in __vector(E[N]) arg) {
	static if (__traits(isFloating, E)) {
		import std.math : isNaN;
		foreach (const e; arg)
			if (!e.isNaN)
				return false;
	} else {
		foreach (const e; arg)
			if (e != e.init)
				return false;
	}
	return true;
}

///
@safe pure nothrow @nogc unittest {
	alias T = __vector(uint[4]);
	assert(!T([1]).isInit);
	assert(T.init.isInit);
}

///
@safe pure nothrow @nogc unittest {
	alias T = __vector(float[4]);
	assert(!T([1]).isInit);
	assert(T.init.isInit);
}

///
@safe pure nothrow @nogc unittest {
	alias T = __vector(double[2]);
	assert(!T([1]).isInit);
	assert(T.init.isInit);
}
