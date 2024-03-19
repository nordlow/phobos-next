module nxt.optional;

import nxt.nullable_traits : isNullable;

@safe:

private struct None {}

/++ Optional `T`.
 +/
struct Optional(T) {
	import core.internal.traits : Unqual;

	private Unqual!T _value;
	static if (!isNullable!T)
		private bool _present;

	this(T value) {
		opAssign(value);
	}

	this(None) {}

	void opAssign(T value) {
		_value = value;
		static if (!isNullable!T)
			_present = true;
	}

	void opAssign(None) {
		static if (isNullable!T)
			_value = null;
		else
			_present = false;
	}

	static if (isNullable!T)
		bool isPresent() const => _value !is null;
	else
		bool isPresent() const => _present;

	T get() in(isPresent) => _value;
	T front() => get;

	T or(lazy T alternativeValue) => isPresent ? _value : alternativeValue;

	bool empty() const @property => !isPresent;
	bool opCast(T : bool)() const pure nothrow @safe @nogc => isPresent;
	inout(T) opUnary(string op : `*`)() inout {
		assert(!empty);
		return _value;
	}
	size_t length() const pure nothrow @nogc => isPresent ? 1 : 0;

	void popFront() {
		static if (isNullable!T)
			_value = null;
		else
			_present = false;
	}

	// auto ref opDispatch(string name, Args...)(auto ref Args args)
	// {
	//	 import std.traits : PointerTarget, isPointer;
	//	 import dlp.core.traits : hasField, TypeOfMember, getMember;

	//	 static if (isPointer!T)
	//		 alias StoredType = PointerTarget!T;
	//	 else
	//		 alias StoredType = T;

	//	 static if (is(StoredType == class) || is(StoredType == struct))
	//	 {
	//		 static if (hasField!(StoredType, name))
	//		 {
	//			 alias FieldType = TypeOfMember!(StoredType, name);

	//			 if (isPresent)
	//				 return optional(value.getMember!name);
	//			 else
	//				 return none!FieldType;
	//		 }
	//		 else
	//		 {
	//			 alias ReturnType = typeof(__traits(getMember, value, name)(args));

	//			 if (isPresent)
	//				 return optional(__traits(getMember, value, name)(args));
	//			 else
	//				 return none!ReturnType;
	//		 }
	//	 }
	//	 else
	//	 {
	//		 return optional(value.getMember!name);
	//	 }

	//	 assert(0);
	// }

	// pure nothrow @safe @nogc unittest
	// {
	//	 assert(Optional!Foo(Foo(3)).a.get == 3);
	//	 assert(Optional!Foo.init.a.empty);

	//	 assert(Optional!Foo(Foo()).opDispatch!"c"(4).get == 4);
	//	 assert(Optional!Foo.init.c(4).empty);

	//	 assert(Optional!Foo(Foo(1, new Bar(5))).b.a.get == 5);
	//	 assert(Optional!Foo(Foo(1)).b.a.empty);
	// }
}

pure nothrow @safe @nogc unittest {
	enum newVale = 4;
	Optional!int a = 3;
	a = newVale;
	assert(a.get == newVale);
}

pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	a = none;
	assert(!a.isPresent);
}

pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	assert(a.isPresent);

	Optional!(int*) b = null;
	assert(!b.isPresent);
}

pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	assert(a.get == 3);
}

@safe pure /*nothrow*/ unittest {
	Optional!int a = 3;
	assert(a.or(4) == 3);

	Optional!int b = none;
	assert(b.or(4) == 4);
}

pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	assert(!a.empty);

	Optional!int b = none;
	assert(b.empty);
}

pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	assert(a.get == 3);
}

/** Instantiate an `Optional` `value`. */
Optional!T optional(T)(T value) => Optional!T(value);

///
pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	a.popFront();
	assert(!a.isPresent);
}

///
pure nothrow @safe @nogc unittest {
	Optional!int a = 3;
	assert(a.length == 1);

	Optional!int b = none;
	assert(b.length == 0);
}

///
pure nothrow @safe @nogc unittest {
	assert(optional(3).isPresent);
}

///
@trusted pure nothrow @nogc unittest {
	int i;
	assert(optional(&i).isPresent);
	assert(!optional!(int*)(null).isPresent);
}

///
pure nothrow @safe @nogc unittest {
	import std.algorithm : map;
	enum value = 3;
	assert(optional(value).map!(e => e).front == value);
}

Optional!T some(T)(T value)
in {
	static if (isNullable!T)
		assert(value !is null);
} do {
	Optional!T o;
	o._value = value;
	o._present = true;

	return o;
}

///
pure nothrow @safe @nogc unittest {
	assert(some(3).isPresent);
}

pure nothrow @safe @nogc None none() {
	return None();
}

Optional!T none(T)() => Optional!T.init;

///
pure nothrow @safe @nogc unittest {
	assert(!none!int.isPresent);
}

version (unittest) {
	// Cannot put this inside the pure nothrow @safe @nogc unittest block due to
	// https://issues.dlang.org/show_bug.cgi?id=19157
	private struct Foo
	{
		int a;
		Bar* b;
		int c(int a) => a;
		Bar d(int a) => Bar(a);
	}

	private struct Bar
	{
		int a;
		int foo(int a) => a;
	}
}
