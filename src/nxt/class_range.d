module nxt.class_range;

import std.traits : isArray;
import std.range.primitives : isInputRange, ElementType;

/** Upcast all elements in `x` of type `T` to the type `U`, where `U` is a
 * superclass of `T`.
  */
version (none)					// not needed anymore
{
inout(U)[] upcastElementsTo(U, T)(return scope inout(T)[] x) @trusted
if (is(T == class) &&
	is(U == class)
	/+ TODO: also check that `T` is a subclass of `U` +/
	) {
	return cast(typeof(return))x;
}
}

/// ditto
auto upcastElementsTo(U, R)(inout(R) x) @trusted
if (!isArray!R &&
	is(U == class) &&
	isInputRange!R && is(ElementType!R == class)
	/+ TODO: also check that `ElementType!R` is a subclass of `U` +/
	) {
	import std.algorithm.iteration : map;
	return x.map!(_ => cast(U)_);
}

///
pure @safe unittest {
	class X
	{
		this(int x) { this.x = x; }
		int x;
	}
	class Y : X
	{
		this(int x) { super(x); }
		int x;
	}

	void f2(X[2] xs) {}

	Y[2] xy = [new Y(42), new Y(43)];
	static assert(is(typeof(xy) == Y[2]));

	/+ TODO: f2(xy); +/
}

private struct DowncastingFilterResult(Subclass, Range) {
	import core.internal.traits : Unqual;

	alias R = Unqual!Range;
	R _input;
	private bool _primed;

	alias pred = _ => cast(Subclass)_ !is null;

	private void prime() {
		import std.range.primitives : empty, front, popFront;
		if (_primed)
			return;
		while (!_input.empty &&
			   !pred(_input.front))
			_input.popFront();
		_primed = true;
	}

	this(R r) {
		_input = r;
	}

	private this(R r, bool primed) {
		_input = r;
		_primed = primed;
	}

	auto opSlice() => this;

	import std.range.primitives : isInfinite;
	static if (isInfinite!Range)
		enum bool empty = false;
	else
	{
		@property bool empty() {
			prime();
			import std.range.primitives : empty;
			return _input.empty;
		}
	}

	void popFront() {
		import std.range.primitives : front, popFront, empty;
		do
		{
			_input.popFront();
		} while (!_input.empty && !pred(_input.front));
		_primed = true;
	}

	@property Subclass front() {
		import std.range.primitives : front;
		prime();
		assert(!empty, "Attempting to fetch the front of an empty filter.");
		return cast(typeof(return))_input.front;
	}

	import std.range.primitives : isForwardRange;
	static if (isForwardRange!R) {
		@property auto save() {
			import std.range.primitives : save;
			return typeof(this)(_input.save, _primed);
		}
	}
}

/** Variant of std.algorithm.iteration : that filters out all elements of
 * `range` that are instances of `Subclass`.
 */
template castFilter(Subclass) {
	import std.range.primitives : isInputRange, ElementType;
	auto castFilter(Range)(Range range)
	if (isInputRange!(Range) &&
		is(ElementType!Range == class) &&
		is(Subclass : ElementType!Range))
		=> DowncastingFilterResult!(Subclass, Range)(range);
}

///
pure @safe unittest {
	class X
	{
		this(int x) { this.x = x; }
		int x;
	}
	class Y : X
	{
		this(int x) { super(x); }
	}
	auto y = castFilter!Y([new X(42), new Y(43)]);
	auto yf = y.front;
	static assert(is(typeof(yf) == Y));
	y.popFront();
	assert(y.empty);
}
