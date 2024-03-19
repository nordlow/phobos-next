module nxt.owned;

/** Return wrapper around container `Container` that can be safely sliced, by
	tracking number of read borrowed ranges and whether it's currently write
	borrowed.

	Only relevant when `Container` implements referenced access over
	<ul>
	<li> `opSlice` and
	<li> `opIndex`
	</ul>

	TODO: Iterate and wrap all @unsafe accessors () and wrapped borrow
	checks for all modifying members of `Container`?
*/
struct Owned(Container)
	if (needsOwnership!Container)
{
	import std.range.primitives : hasSlicing;
	import std.traits : isMutable;

	/// Type of range of `Container`.
	alias Range = typeof(Container.init[]);

pragma(inline):

	~this() nothrow @nogc
	{
		assert(!_writeBorrowed, "This is still write-borrowed, cannot release!");
		assert(_readBorrowCount == 0, "This is still read-borrowed, cannot release!");
	}

	/// Move `this` into a returned r-value.
	typeof(this) move()
	{
		assert(!_writeBorrowed, "This is still write-borrowed, cannot move!");
		assert(_readBorrowCount == 0, "This is still read-borrowed, cannot move!");
		import core.lifetime : move;
		return move(this);
	}

	/** Checked overload for `std.algorithm.mutation.move`. */
	void move(ref typeof(this) dst) pure nothrow @nogc
	{
		assert(!_writeBorrowed, "Source is still write-borrowed, cannot move!");
		assert(_readBorrowCount == 0, "Source is still read-borrowed, cannot move!");

		assert(!dst._writeBorrowed, "Destination is still write-borrowed, cannot move!");
		assert(dst._readBorrowCount == 0, "Destination is still read-borrowed, cannot move!");

		import core.lifetime : move;
		move(this, dst);
	}

	/** Checked overload for `std.algorithm.mutation.moveEmplace`. */
	void moveEmplace(ref typeof(this) dst) pure nothrow @nogc
	{
		assert(!_writeBorrowed, "Source is still write-borrowed, cannot moveEmplace!");
		assert(_readBorrowCount == 0, "Source is still read-borrowed, cannot moveEmplace!");

		import core.lifetime : moveEmplace;
		moveEmplace(this, dst);
	}

	static if (true/*TODO: hasUnsafeSlicing!Container*/)
	{
		import nxt.borrowed : ReadBorrowed, WriteBorrowed;

		/+ TODO: can all these definitions be reduce somehow? +/

		/// Get full read-only slice.
		ReadBorrowed!(Range, Owned) sliceRO() const @trusted
		{
			import core.internal.traits : Unqual;
			assert(!_writeBorrowed, "This is already write-borrowed");
			return typeof(return)(_container.opSlice,
								  cast(Unqual!(typeof(this))*)(&this)); // trusted unconst casta
		}

		/// Get read-only slice in range `i` .. `j`.
		ReadBorrowed!(Range, Owned) sliceRO(size_t i, size_t j) const @trusted
		{
			import core.internal.traits : Unqual;
			assert(!_writeBorrowed, "This is already write-borrowed");
			return typeof(return)(_container.opSlice[i .. j],
								  cast(Unqual!(typeof(this))*)(&this)); // trusted unconst cast
		}

		/// Get full read-write slice.
		WriteBorrowed!(Range, Owned) sliceRW() @trusted
		{
			assert(!_writeBorrowed, "This is already write-borrowed");
			assert(_readBorrowCount == 0, "This is already read-borrowed");
			return typeof(return)(_container.opSlice, &this);
		}

		/// Get read-write slice in range `i` .. `j`.
		WriteBorrowed!(Range, Owned) sliceRW(size_t i, size_t j) @trusted
		{
			assert(!_writeBorrowed, "This is already write-borrowed");
			assert(_readBorrowCount == 0, "This is already read-borrowed");
			return typeof(return)(_container.opSlice[i .. j], &this);
		}

		/// Get read-only slice in range `i` .. `j`.
		auto opSlice(size_t i, size_t j) const
		{
			return sliceRO(i, j);
		}
		/// Get read-write slice in range `i` .. `j`.
		auto opSlice(size_t i, size_t j)
		{
			return sliceRW(i, j);
		}

		/// Get read-only full slice.
		auto opSlice() const
		{
			return sliceRO();
		}
		/// Get read-write full slice.
		auto opSlice()
		{
			return sliceRW();
		}
	}

	pure nothrow @safe @nogc:

	@property:

	/// Returns: `true` iff `this` is either write or read borrowed.
	bool isBorrowed() const { return _writeBorrowed || _readBorrowCount >= 1; }

	/// Returns: `true` iff owned container is write borrowed.
	bool isWriteBorrowed() const { return _writeBorrowed; }

	/// Returns: number of read-only borrowers of owned container.
	uint readBorrowCount() const { return _readBorrowCount; }

	Container _container;			/// wrapped container
	alias _container this;

public:
	bool _writeBorrowed = false; /// `true` iff `_container` is currently referred to
	uint _readBorrowCount = 0; /// number of readable borrowers. TODO: use `size_t` minus one bit instead in `size_t _stats`
	enum readBorrowCountMax = typeof(_readBorrowCount).max;
}

/** Checked overload for `std.algorithm.mutation.move`.

	TODO: Can we somehow prevent users of Owned from accidentally using
	`std.algorithm.mutation.move` instead of this wrapper?
 */
void move(Owner)(ref Owner src, ref Owner dst) pure nothrow @safe @nogc
	if (is(Owner == Owned!(_), _))
{
	src.move(dst);			  // reuse member function
}

/** Checked overload for `std.algorithm.mutation.moveEmplace`.

	TODO: Can we somehow prevent users of Owned from accidentally using
	`std.algorithm.mutation.moveEmplace` instead of this wrapper?
*/
void moveEmplace(Owner)(ref Owner src, ref Owner dst) pure nothrow @safe @nogc
	if (is(Owner == Owned!(_), _))
{
	src.moveEmplace(dst);   // reuse member function
}

template needsOwnership(Container)
{
	import std.range.primitives : hasSlicing;
	/+ TODO: activate when array_ex : UniqueArray +/
	// enum needsOwnership = hasSlicing!Container; /+ TODO: extend to check if it's not @safe +/
	enum needsOwnership = is(Container == struct);
}

pure unittest {
	alias A = UniqueArray!int;
	const Owned!A co;		  // const owner

	import std.traits : isMutable;
	static assert(!isMutable!(typeof(co)));

	const cos = co[];
}

pure @safe unittest {
	alias A = UniqueArray!int;
	A a = A.init;
	a = A.init;
	/+ TODO: a ~= A.init; +/
}

pure unittest {
	import std.exception: assertThrown;
	import core.exception : AssertError;

	import nxt.borrowed : ReadBorrowed, WriteBorrowed;

	alias A = UniqueArray!int;

	Owned!A oa;

	Owned!A ob;
	oa.move(ob);				// ok to move unborrowed

	Owned!A od = void;
	oa.moveEmplace(od);		 // ok to moveEmplace unborrowed

	oa ~= 1;
	oa ~= 2;
	assert(oa[] == [1, 2]);
	assert(oa[0 .. 1] == [1]);
	assert(oa[1 .. 2] == [2]);
	assert(oa[0 .. 2] == [1, 2]);
	assert(!oa.isWriteBorrowed);
	assert(!oa.isBorrowed);
	assert(oa.readBorrowCount == 0);

	{
		const wb = oa.sliceRW;

		Owned!A oc;
		assertThrown!AssertError(oa.move()); // cannot move write borrowed

		assert(wb.length == 2);
		static assert(!__traits(compiles, { auto wc = wb; })); // write borrows cannot be copied
		assert(oa.isBorrowed);
		assert(oa.isWriteBorrowed);
		assert(oa.readBorrowCount == 0);
		assertThrown!AssertError(oa.opSlice); // one more write borrow is not allowed
	}

	// ok to write borrow again in separate scope
	{
		const wb = oa.sliceRW;

		assert(wb.length == 2);
		assert(oa.isBorrowed);
		assert(oa.isWriteBorrowed);
		assert(oa.readBorrowCount == 0);
	}

	// ok to write borrow again in separate scope
	{
		const wb = oa.sliceRW(0, 2);
		assert(wb.length == 2);
		assert(oa.isBorrowed);
		assert(oa.isWriteBorrowed);
		assert(oa.readBorrowCount == 0);
	}

	// multiple read-only borrows are allowed
	{
		const rb1 = oa.sliceRO;

		Owned!A oc;
		assertThrown!AssertError(oa.move(oc)); // cannot move read borrowed

		assert(rb1.length == oa.length);
		assert(oa.readBorrowCount == 1);

		const rb2 = oa.sliceRO;
		assert(rb2.length == oa.length);
		assert(oa.readBorrowCount == 2);

		const rb3 = oa.sliceRO;
		assert(rb3.length == oa.length);
		assert(oa.readBorrowCount == 3);

		const rb_ = rb3;
		assert(rb_.length == oa.length);
		assert(oa.readBorrowCount == 4);
		assertThrown!AssertError(oa.sliceRW); // single write borrow is not allowed
	}

	// test modification via write borrow
	{
		auto wb = oa.sliceRW;
		wb[0] = 11;
		wb[1] = 12;
		assert(wb.length == oa.length);
		assert(oa.isWriteBorrowed);
		assert(oa.readBorrowCount == 0);
		assertThrown!AssertError(oa.sliceRO);
	}
	assert(oa[] == [11, 12]);
	assert(oa.sliceRO(0, 2) == [11, 12]);

	// test mutable slice
	static assert(is(typeof(oa.sliceRW()) == WriteBorrowed!(_), _...));
	static assert(is(typeof(oa[]) == WriteBorrowed!(_), _...));
	foreach (ref e; oa.sliceRW)
	{
		assertThrown!AssertError(oa.sliceRO); // one more write borrow is not allowed
		assertThrown!AssertError(oa.sliceRW); // one more write borrow is not allowed
		assertThrown!AssertError(oa[]); // one more write borrow is not allowed
	}

	// test readable slice
	static assert(is(typeof(oa.sliceRO()) == ReadBorrowed!(_), _...));
	foreach (const ref e; oa.sliceRO)
	{
		assert(oa.sliceRO.length == oa.length);
		assert(oa.sliceRO[0 .. 0].length == 0);
		assert(oa.sliceRO[0 .. 1].length == 1);
		assert(oa.sliceRO[0 .. 2].length == oa.length);
		assertThrown!AssertError(oa.sliceRW); // write borrow during iteration is not allowed
		assertThrown!AssertError(oa.move());  // move not allowed when borrowed
	}

	// move semantics
	auto oaMove1 = oa.move();
	auto oaMove2 = oaMove1.move();
	assert(oaMove2[] == [11, 12]);

	// constness propagation from owner to borrower
	Owned!A mo;		  // mutable owner
	assert(mo.sliceRO.ptr == mo.ptr);
	assert(mo.sliceRO(0, 0).ptr == mo.ptr);
	static assert(is(typeof(mo.sliceRO()) == ReadBorrowed!(_), _...));

	const Owned!A co;		  // const owner
	assert(co.sliceRO.ptr == co.ptr);
	static assert(is(typeof(co.sliceRO()) == ReadBorrowed!(_), _...));
}

nothrow unittest {
	import std.algorithm.sorting : sort;
	alias E = int;
	alias A = UniqueArray!E;
	A a;
	sort(a[]);		 /+ TODO: make this work +/
}

// y = sort(x.move()), where x and y are instances of unsorted Array
@safe nothrow unittest {
	import std.algorithm.sorting : sort;
	import std.range.primitives : isInputRange, isForwardRange, isRandomAccessRange, hasSlicing;

	alias E = int;
	alias A = UniqueArray!E;
	alias O = Owned!A;

	O o;
	o ~= [42, 43];

	assert(o.length == 2);

	scope os = o.sliceRO;

	alias OS = typeof(os);
	static assert(isInputRange!(OS));
	static assert(isForwardRange!(OS));
	static assert(hasSlicing!(OS));
	static assert(isRandomAccessRange!OS);

	assert(!os.empty);
	assert(os.length == 2);
	os.popFront();
	assert(!os.empty);
	assert(os.length == 1);
	os.popFront();
	assert(os.empty);

	/+ TODO: scope oss = os[];			// no op +/
	/+ TODO: assert(oss.empty); +/
}

// check write-borrow
@safe nothrow unittest {
	import std.algorithm.sorting : sort;
	import std.range.primitives : isInputRange, isForwardRange, isRandomAccessRange, hasSlicing;

	alias E = int;
	alias A = UniqueArray!E;
	alias O = Owned!A;

	const O co;
	auto cos = co[0 .. 0];
	const ccos = co[0 .. 0];

	/+ TODO: const coc = co[].save(); +/

	O o;
	o ~= [42, 43];
	auto os = o.sliceRW;
	alias OS = typeof(os);
	static assert(isInputRange!(OS));

	// static assert(isForwardRange!(OS));
	// static assert(hasSlicing!(OS));
	// static assert(isRandomAccessRange!OS);
	// import std.algorithm.sorting : sort;
	// sort(o[]);
}

version (unittest)
{
	import nxt.container.dynamic_array : UniqueArray = DynamicArray;
	import nxt.debugio;
}
