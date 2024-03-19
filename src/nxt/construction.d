/++ Construction of types.

	Typically used for functional construction of containers.

	These generic factory functions prevents the need for defining separate
	member factory functions for each container/collection class opposite to
	what Rust's std.collection types define as `withLength`, `withCapacity`,
	etc. This adhere's to the dry-principle.

	See: nxt.container and std.container.
 +/
module nxt.construction;

import std.range.primitives : isInputRange, ElementType;

/++ Construct an instance of `T` with capacity `capacity`.
 +/
T makeOfCapacity(T, Capacity)(Capacity capacity)
if (/+is(typeof(T.init.reserve(0))) && +/is(Capacity : size_t)) {
	T t;
	t.reserve(capacity); /+ TODO: Check that this allowed in template-restriction +/
	return t;
}

///
@safe pure unittest {
	alias A = int[];
	const n = 3;
	const a = makeOfCapacity!(A)(n);
	assert(a.capacity == n);
}

/++ Construct an instance of `T` with length `n`.
 +/
T makeOfLength(T, Length)(Length length) if (is(Length : size_t)) {
	T t;
	t.length = length; /+ TODO: Check that this allowed in template-restriction +/
	return t;
}

///
@safe pure unittest {
	alias A = int[];
	const n = 3;
	const a = makeOfLength!(A)(n);
	assert(a.length == n);
}

/++ Construct an instance of `T` with `elements`.
 +/
T makeWithElements(T, R)(R elements) if (isInputRange!R) {
	import std.range.primitives : hasLength;
	static if (is(typeof(T.init.reserve(0))) && hasLength!R) {
		// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", T);
		T t = makeOfCapacity!T(elements.length);
	}
	else
		T t;
	t ~= elements; // TODO: use `.put` instead?
	return t;
}

///
@safe pure unittest {
	alias A = int[];
	const elements = [1,2,3];
	const a = makeWithElements!(A)(elements);
	assert(a.capacity == elements.length);
	assert(a.length == elements.length);
}

/// Returns: shallow duplicate of `a`.
T dupShallow(T)(in T a)
if (is(typeof(T.init[])) && // `hasSlicing!T`
	!is(T == const(U)[], U) && // builtin arrays already have `.dup` property
	__traits(isCopyable, ElementType!T)) {
	/+ TODO: delay slicing of `a` when T is a static array for compile-time
       length optimization: +/
	return makeWithElements!(T)(a[]);
}
alias dup = dupShallow;

///
version (none)
@safe pure unittest {
	alias A = int[];
	const elements = [1,2,3];
	const a = makeWithElements!(A)(elements);
	const b = a.dupShallow;
	assert(a == b);
	assert(a.ptr !is b.ptr);
}
