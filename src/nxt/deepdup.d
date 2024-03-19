/** Deep duplication.

	Move to Phobos somewhere.

	TODO: Support inout relevant for const?
	See: http://forum.dlang.org/thread/hojk95$4mk$1@digitalmars.com
 */
module nxt.deepdup;

import core.internal.traits : Unqual;
import std.typecons : tuple, Tuple;
import std.meta : staticMap;
import std.traits : isDynamicArray, isArray, isPointer;
import std.range.primitives : ElementType;

alias TypeofDeepdup(T) = typeof(deepdup(T.init));

ref Unqual!T deepdup(T)(T t)
if (is(T == struct) &&
	!is(T.Types)) {
	staticMap!(TypeofDeepdup, typeof(t.tupleof)) tup;
	foreach (const i, Type; tup)
		tup[i] = t.tupleof[i].deepdup;
	return Unqual!T(tup);
}

Tuple!(staticMap!(TypeofDeepdup, T.Types)) deepdup(T)(T t)
if (is(T.Types)) {
	staticMap!(TypeofDeepdup, T.Types) tup;
	foreach (const i, Type; tup)
		tup[i] = t.field[i].deepdup;
	return tuple(tup);
}

Unqual!T deepdup(T)(T t)
if (is(T == class)) {
	staticMap!(TypeofDeepdup, typeof(t.tupleof)) tup;
	foreach (const i, Type; tup)
		tup[i] = t.tupleof[i].deepdup;
	return new Unqual!T(tup);
}

TypeofDeepdup!(ElementType!T)[] deepdup(T)(T t)
if (isDynamicArray!T) {
	auto result = new TypeofDeepdup!(ElementType!T)[](t.length);
	foreach (const i, elem; t)
		result[i] = elem.deepdup;
	return result;
}

TypeofDeepdup!(ElementType!T)[T.length] deepdup(T)(T t)
if (__traits(isStaticArray, T)) {
	TypeofDeepdup!(ElementType!T)[T.length] result = t;
	foreach (ref elem; result)
		elem = elem.deepdup;
	return result;
}

TypeofDeepdup!T* deepdup(T)(T* t) => &deepdup(*t);

Unqual!T deepdup(T)(T t) if (!is(T == struct) &&
							 !is(T == class) &&
							 !isArray!T &&
							 !is(T.Types) &&
							 !isPointer!T)
	=> cast(Unqual!T)t;

@safe pure nothrow:

///
unittest {
	auto x = [1, 2, 3];
	assert(x == x.dup);
	auto y = x;
	assert(&x[0] == &y[0]);
	assert(&x[0] != &x.dup[0]);
}

///
unittest {
	auto x = [[1], [2], [3]];
	auto y = x.dup;
	x[0][0] = 11;
	assert(x[0][0] == 11);
	assert(y[0][0] == 11);
}

///
unittest {
	auto x = [[1], [2], [3]];
	auto y = x.deepdup;
	x[0][0] = 11;
	assert(x[0][0] == 11);
	assert(y[0][0] == 1);
}

///
unittest {
	auto x = [[1], [2], [3]];
	auto y = x.deepdup;
	x[0][0] = 11;
	assert(x[0][0] == 11);
	assert(y[0][0] == 1);
}

///
unittest {
	auto x = [[[1]], [[2]], [[3]]];
	auto y = x.deepdup;
	x[0][0][0] = 11;
	assert(x[0][0][0] == 11);
	assert(y[0][0][0] == 1);
}

/// dup of static array
unittest {
	int[3] x = [1, 2, 3];
	auto y = x.dup;
	x[0] = 11;
	assert(x[0] == 11);
	assert(y[0] == 1);
}

/// dup of static array of dynamic arrays
unittest {
	int[][3] x = [[1], [2], [3]];
	auto y = x.dup;
	x[0][0] = 11;
	assert(x[0][0] == 11);
	assert(y[0][0] == 11);
}

/// deepdup of static array of dynamic arrays
unittest {
	int[][3] x = [[1], [2], [3]];
	auto y = x.deepdup;
	x[0][0] = 11;
	assert(x[0][0] == 11);
	assert(y[0][0] == 1);
}
