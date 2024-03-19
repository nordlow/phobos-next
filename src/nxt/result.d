/++ Result type.
 +/
module nxt.result;

@safe:

/++ Result of `T`.
	Designed for error handling where an operation can either succeed or fail.
	- TODO: Add member `toRange` alias with `opSlice`
	- TODO: Add member visit()
 +/
struct Result(T) {
	static if (!__traits(isPOD, T))
		import core.lifetime : move, moveEmplace;
	this(T value) {
		static if (__traits(isPOD, T))
			_value = value;
		else
			() @trusted { moveEmplace(value, _value); }(); /+ TODO: remove when compiler does this +/
		_isValid = true;
	}
	ref typeof(this) opAssign(T value) {
		static if (__traits(isPOD, T))
			_value = value;
		else
			() @trusted { move(value, _value); }(); /+ TODO: remove when compiler does this +/
		_isValid = true;
		return this;
	}
@property:
	ref inout(T) value() inout scope return in(isValid) => _value;
	// ditto
	ref inout(T) opUnary(string op)() inout scope return if (op == "*") => value;
	string toString() inout scope pure {
		import std.conv : to;
		return isValid ? _value.to!string : "invalid";
	}
pure nothrow @nogc:
	bool isValid() const scope => _isValid;
	alias hasValue = isValid;
	bool opCast(T : bool)() const scope => _isValid;
	static typeof(this) invalid() => typeof(this).init;
private
	T _value;
	bool _isValid;
}

/// to string conversion
@safe pure unittest {
	alias R = Result!int;
	const R r1;
	assert(r1.toString == "invalid");
	const R r2 = 42;
	assert(r2.toString == "42");
}

/// result of uncopyable type
@safe pure nothrow @nogc unittest {
	alias T = Uncopyable;
	alias R = Result!T;
	R r1;
	assert(!r1);
	assert(r1 == R.invalid);
	assert(r1 != R(T.init));
	assert(!r1.isValid);
	T t = T(42);
	r1 = move(t);
	assert(r1 != R(T.init));
	assert(*r1 == T(42));
	R r2 = T(43);
	assert(*r2 == T(43));
	assert(r2.value == T(43));
}

version (unittest) {
	import core.lifetime : move;
	private static struct Uncopyable { this(this) @disable; int _x; }
}
