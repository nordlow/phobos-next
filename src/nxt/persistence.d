/** Object Data Persistence.
	See_Also: https://stackoverflow.com/questions/20932921/automatic-object-persistence-in-d/20934647?noredirect=1#20934647
*/
module nxt.persistence;

/// Persistent storage of variables of type `T`.
struct persistent(T, string file = __FILE__, size_t line = __LINE__)
{
	T store;
	alias store this;

	@disable this();	// require an initializer

	// with the initializer
	this(T t)
	{
		// if it is in the file, we should load it here
		// else...
		store = t;
	}

	~this() nothrow
	{
		// import std.stdio : writeln;
		// you should actually save it to the file. TODO: Import file and
		// calculate its sha1 all at compile-time!
		/+ TODO: Save store, " as key ", file,":",line); +/
	}
}

unittest {
	persistent!int x = 10;
}
