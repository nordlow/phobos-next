module nxt.soa_petar_kirov;

/++
 Structure of Arrays

 This type constructor turns a structure with any number of fields into a
 structure with (conceptually) the same number of arrays with minimal overhead
 (basically two pointers). Even though the implementation uses low-level tricks
 like pointer-arithmetic, the interface is completely type-safe.

 The representation in memory is roughly this:
 storage = [ [ Fields!T[0], .. ] ... [ Fields!T[$ - 1] .. ] ]
 (storage is a single memory allocation)

 Original at https://gist.github.com/PetarKirov/a074073a12482e761a5e88eec559e5a8
 +/
struct SoA(T, alias Allocator = from!`std.experimental.allocator.gc_allocator`.GCAllocator)
if (is(T == struct))
{
	static assert (__traits(isPOD, T));
	static assert (typeof(this).sizeof == size_t.sizeof * 2); // only two words

	private // internal state
	{
		void* _storage;
		size_t _length;
		alias allocator = allocatorInstanceOf!Allocator;
		alias Fields = from!`std.traits`.Fields!T;
		enum FieldNames = from!`std.traits`.FieldNameTuple!T;
	}

	/** Creates a structure of arrays instance with `newLength` elements. */
	this(size_t newLength) nothrow
	in (newLength)
	out (; this._storage)
	{
		_length = newLength;

		/+ TODO: Respect individual field alignment +/
		_storage = allocator.allocate(T.sizeof * capacity()).ptr;

		// Initialize each array with the default value for each field type:
		static foreach (idx; 0 .. Fields.length)
			chunkFor!idx(_storage, capacity())[] = Fields[idx].init;
	}

	void toString(Writer)(Writer sink) const
	{
		import std.format : formattedWrite;

		sink.formattedWrite("%s\n{\n", typeof(this).stringof);
		static foreach (idx; 0 .. Fields.length)
			sink.formattedWrite("  %s[] %s = %s,\n",
								Fields[idx].stringof,
								T.tupleof[idx].stringof,
								chunkFor!idx(_storage, capacity)[0 .. length]
			);
		sink.formattedWrite("}");
	}

	nothrow:

	/** Returns the number of inserted elements. */
	size_t length() const pure @safe
	{
		return _length;
	}

	alias opDollar = length;

	/** Returns the current capacity - the current length rounded up to a power
		of two. This assumption allows us to save on having a separate field.
	*/
	size_t capacity() const pure @safe
	{
		return _length.roundUpToPowerOf2;
	}

	/** Returns the number of elements that can be inserted without allocation. */
	size_t availableCapacity() const pure
	{
		assert (length <= capacity);
		return capacity - length;
	}

	/** Returns true iff no elements are present. */
	bool empty() const @property pure @safe { return !length; }

	/** Given a field name, returns its index.
		Callable at compile-time.
	*/
	enum size_t fieldIndex(string fieldName) = from!"std.meta".staticIndexOf!(fieldName, FieldNames);

	auto opIndex(size_t idx)
	{
		auto self = this;
		static struct Result
		{
			typeof(self) parent;
			size_t idx;
			void toString(Sink)(ref scope Sink sink) const
			{
				import std.format : formattedWrite;
				sink.formattedWrite("%s\n{\n", T.stringof ~ "Ref");
				static foreach (field; 0 .. Fields.length)
				{{
						enum fieldName = T.tupleof[field].stringof;
						sink.formattedWrite("  %s: %s,\n",
											fieldName,
											opDispatch!fieldName()
						);
					}}
				sink.formattedWrite("}");
			}

			ref opDispatch(string field)() inout
			{
				return parent.opDispatch!field()[idx];
			}
		}
		return Result(self, idx);
	}

	/// Returns the array corresponding to the instances of `field`.
	auto opDispatch(string field)() inout pure @safe
	in (!empty)
	{
		enum idx = fieldIndex!field;
		return chunkFor!idx(_storage, capacity())[0 .. _length];
	}

	/// Given an argument of type `T` or argument sequence of type `Fields!T`,
	/// inserts the fields of T at the back of the container.
	void insertBack(Args...)(auto ref Args args) @safe
	if (is(Args == from!`std.meta`.AliasSeq!T) ||
		is(Args == Fields))
	{
		if (availableCapacity)
			_length++;
		else
			grow!true;

		static foreach (idx; 0 .. Fields.length)
			static if (is(Args == from!`std.meta`.AliasSeq!T))
				chunkFor!idx(_storage, capacity())[_length - 1] =
				args[0].tupleof[idx];

			else static if (is(Args == Fields))
				chunkFor!idx(_storage, capacity())[_length - 1] =
				args[idx];
	}

	/// Returns `inout(U)[]`- the slice of memory pointing where elements of
	/// type `U == Field!T[idx]` are stored.
	private static pure @trusted
	inout(Fields[idx])[] chunkFor(size_t idx)(inout(void)* base, size_t size)
	{
		auto add(alias a, alias b)() { return a + b; }
		size_t sizeOf(X)() { return X.sizeof * size; }

		static if (idx)
			size_t offset = staticMapReduce!(sizeOf, add, Fields[0 .. idx]);
		else
			size_t offset = 0;

		return (cast(inout(Fields[idx])*)(base + offset))[0 .. size];
	}

	/// Doubles the available size (capacity) and conditionally copies the data
	/// to the new location.
	private void grow(bool relocateData)() @trusted
	{
		auto old_capacity = this.capacity();
		auto new_capacity = this._length++? this.capacity() : 1;

		auto add(alias a, alias b)() { return a + b; }
		auto sizeOfOld(X)() { return X.sizeof * old_capacity; }
		auto sizeOfNew(X)() { return X.sizeof * new_capacity; }

		auto old_storage_size = staticMapReduce!(sizeOfOld, add, Fields);
		auto new_storage_size = staticMapReduce!(sizeOfNew, add, Fields);

		auto new_storage = allocator.allocate(new_storage_size);

		// move chunk by chunk to the new location
		static if (relocateData)
			static foreach(idx; 0 .. Fields.length)
				chunkFor!idx(new_storage.ptr, new_capacity)[0 .. length - 1] =
				chunkFor!idx(_storage, old_capacity)[0 .. length - 1];

		if (old_capacity)
			allocator.deallocate(_storage[0 .. old_storage_size]);

		_storage = new_storage.ptr;
	}
}

template from(string module_)
{
	mixin("import from = ", module_, ';');
}

template allocatorInstanceOf(alias Allocator)
{
	static if (is(typeof(Allocator)))
		alias allocatorInstanceOf = Allocator;
	else static if (is(typeof(Allocator.instance)))
		alias allocatorInstanceOf = Allocator.instance;
	else
		static assert (0);
}

size_t roundUpToPowerOf2(size_t s) @safe @nogc nothrow pure
in (s <= (size_t.max >> 1) + 1)
{
	--s;
	static foreach (i; 0 .. 5)
		s |= s >> (1 << i);
	return s + 1;
}

/// Applies `map` to each element of a compile-time sequence and
/// then recursively calls `reduce` on each pair.
template staticMapReduce(alias map, alias reduce, Args...)
if (Args.length > 0)
{
	static if (Args.length == 1)
		alias staticMapReduce = map!(Args[0]);
	else
		alias staticMapReduce = reduce!(
			staticMapReduce!(map, reduce, Args[0]),
			staticMapReduce!(map, reduce, Args[1 .. $])
		);
}

///
unittest {
	import std.meta : AliasSeq;
	enum mulBy2(alias x) = x * 2;
	enum add(alias a, alias b) = a + b;
	static assert(staticMapReduce!(mulBy2, add, AliasSeq!(1)) == 2);
	static assert(staticMapReduce!(mulBy2, add, AliasSeq!(1, 2)) == 6);
	static assert(staticMapReduce!(mulBy2, add, AliasSeq!(1, 2, 3, 4, 5)) == 30);
}

@system unittest {
	// import std.stdio : writeln;

	static struct Vec3
	{
		float x, y, z;
	}

	auto soa = SoA!Vec3(5);

	soa.y[] = 2;
	soa.z[] = 3;
	soa.x[] = soa.y[] * soa.z[];
	// soa.writeln;

	// soa[0].writeln;

	soa[1].x++;
	soa[1].y += 2;
	soa[1].z *= 3;
	// soa.writeln;

	soa.insertBack(Vec3(21, 42, 84));
	// soa.writeln;

	soa.insertBack(0.5f, 0.25f, 0.125f);
	// soa.writeln;
}
