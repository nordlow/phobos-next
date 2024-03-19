/** Various suppressing hacks.
 */
module nxt.suppressing;

enum SuppressOptions
{
	destructor = 1,
	postblit = 2
}

/** Suppress.
 *
 * See_Also: http://forum.dlang.org/post/dxakoknmzblxpgiibfmu@forum.dlang.org
 */
struct Suppress(T, SuppressOptions options)
if (options != 0)
{
	private enum suppressPostblit   = (options & SuppressOptions.postblit)   != 0;
	private enum suppressDestructor = (options & SuppressOptions.destructor) != 0;
	private enum postblitName = __traits(hasMember, T, "__xpostblit") ? "__xpostblit" : "__postblit";

	// Disguise T as a humble array.
	private ubyte[T.sizeof] _payload;

	// Create from instance of T.
	this(T arg)
	{
		_payload = *cast(ubyte[T.sizeof]*)&arg;
	}

	// Or forward constructor arguments to T's constructor.
	static if (__traits(hasMember, T, "__ctor"))
	{
		this(Args...)(Args args)
			if (__traits(compiles, (Args e){__traits(getMember, T.init, "__ctor")(e);}))
		{
			__traits(getMember, get, "__ctor")(args);
		}
	}

	// Call dtor
	static if (!suppressDestructor)
	{
		~this() nothrow @nogc
		{
			destroy(get);
		}
	}

	// Call postblit
	static if (!suppressPostblit)
	{
		static if (!__traits(isCopyable, T))
		{
			this(this) @disable;
		}
		else static if (__traits(hasMember, T, postblitName))
		{
			this(this)
			{
				__traits(getMember, get, postblitName)();
			}
		}
	}

	// Pretend to be a T.
	@property
	ref T get()
	{
		return *cast(T*)_payload.ptr;
	}

	alias get this;
}

struct S1
{
	this(this) @disable;
	~this() nothrow @nogc
	{
		assert(0, "Don't touch my destructor!");
	}
}

unittest {
	import std.exception;
	static assert(!__traits(compiles, (Suppress!S1 a) { auto b = a; }));
	static assert(__traits(compiles, (Suppress!(S1, SuppressOptions.postblit) a) { auto b = a; }));

	/+ TODO: assertThrown({ Suppress!(S1, SuppressOptions.postblit) a; }()); +/
	assertNotThrown({ Suppress!(S1, SuppressOptions.postblit | SuppressOptions.destructor) a; }());
}
