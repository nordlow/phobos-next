module nxt.string_ex;

public import nxt.sso_string;
public import nxt.packed_string;

/** Call `dg` with `src` as input.
 *
 * See_Also: https://youtu.be/V6KFtzF2Hx8
 */
auto toCStringThen(alias dg, uint smallSize = 512)(const(char)[] src)
if (is(typeof(dg((char[]).init)))) /+ TODO: assert that dg takes its parameter by scope +/
{
	import core.memory : pureMalloc, pureFree;
	const srcLength = src.length + 1;
	char[smallSize] stackBuf = void;

	const useHeap = srcLength > stackBuf.length;
	scope char* ptr;
	() @trusted {
		if (useHeap)
			ptr = cast(typeof(ptr))pureMalloc(src.length + 1);
		else
			ptr = stackBuf.ptr;
		ptr[0 .. src.length] = src[];
		ptr[src.length] = '\0';
	} ();
	scope(exit)
		if (useHeap)
			() @trusted { pureFree(ptr); } ();

	scope char[] buf;
	() @trusted {
		buf = ptr[0 .. srcLength];
	} ();

	return dg(buf);
}

///
pure nothrow @safe @nogc unittest {
	enum smallSize = 4;
	const src = "42";
	scope char[src.length + 1] y;
	@safe void f(in char[] x) { y = x; }
	src.toCStringThen!(f, smallSize)(); // uses stack
	assert(y[0 .. $ - 1] == src);
	assert(y[$ - 1 .. $] == "\0");
}

///
pure nothrow @safe @nogc unittest {
	enum smallSize = 4;
	const src = "4200";
	scope char[src.length + 1] y;
	@safe void f(in char[] x) { y = x; }
	src.toCStringThen!(f, smallSize)(); // uses heap
	assert(y[0 .. $ - 1] == src);
	assert(y[$ - 1 .. $] == "\0");
}

/** Zero-Terminated string.
	See: https://discord.com/channels/242094594181955585/625407836473524246/1018276401142575188
 */
struct Stringz
{
	this(string s) pure nothrow @safe @nogc
	in (s.length >= 1 &&
		s[$ - 1] == '\0')
	{
		_data = s[0 .. $ - 1];
	}
	string toString() const @property pure nothrow @safe @nogc { return _data; }
	private string _data;
}

enum stringz(string literal) = () {
	Stringz result;
	result._data = literal; // ok - literals are 0-terminated
	return result;
}();

///
pure @safe unittest {
	enum _ = stringz!("42");
	assert(_.toString == "42");
}
