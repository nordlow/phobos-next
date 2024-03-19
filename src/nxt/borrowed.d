module nxt.borrowed;

/** Read-and-Write-borrowed access to a range of type `Range` owned by `Owner`. */
struct WriteBorrowed(Range, Owner)
	// if (is(Owner == Owned!(_), _))
{
	this(Range range, Owner* owner) {
		assert(owner);
		_range = range;
		_owner = owner;
		owner._writeBorrowed = true;
	}

	this(this) @disable;		// cannot be copied

	~this() nothrow @nogc
	{
		debug assert(_owner._writeBorrowed, "Write borrow flag is already false, something is wrong with borrowing logic");
		_owner._writeBorrowed = false;
	}

	Range _range;				   /// range
	alias _range this;			  /// behave like range

private:
	Owner* _owner = null;		   /// pointer to container owner
}

/** Read-borrowed access to a range of type `Range` owned by `Owner`. */
struct ReadBorrowed(Range, Owner)
	// if (is(Owner == Owned!(_), _))
{
	this(const Range range, Owner* owner) {
		import core.internal.traits : Unqual;
		_range = *(cast(Unqual!Range*)&range);
		_owner = owner;
		if (_owner) {
			assert(_owner._readBorrowCount != _owner.readBorrowCountMax, "Cannot have more borrowers");
			_owner._readBorrowCount = _owner._readBorrowCount + 1;
		}
	}

	this(this) {
		if (_owner) {
			assert(_owner._readBorrowCount != _owner.readBorrowCountMax, "Cannot have more borrowers");
			_owner._readBorrowCount = _owner._readBorrowCount + 1;
		}
	}

	~this() nothrow @nogc
	{
		if (_owner) {
			assert(_owner._readBorrowCount != 0, "Read borrow counter is already zero, something is wrong with borrowing logic");
			_owner._readBorrowCount = _owner._readBorrowCount - 1;
		}
	}

	/// Get read-only slice in range `i` .. `j`.
	auto opSlice(size_t i, size_t j) => typeof(this)(_range[i .. j], _owner);

	/// Get read-only slice.
	auto opSlice() inout => this;			// same as copy

	bool empty() const @property pure nothrow @safe @nogc
	{
		import std.range.primitives : empty; // pick this if `_range` doesn't have it
		return _range.empty;
	}

	@property auto ref front() inout @safe pure in(!empty) {
		import std.range.primitives : front; // pick this if `_range` doesn't have it
		return _range.front;
	}

	typeof(this) save() => this;

	void popFront() @safe in(!empty) {
		import std.range.primitives : popFront; // pick this if `_range` doesn't have it
		_range.popFront();
	}

	Range _range;			   /// constant range
	alias _range this;		  /// behave like range

private:
	Owner* _owner = null;	   /// pointer to container owner
}
