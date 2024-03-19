module nxt.unsafe;

/** Call the possibly unsafe function `fn` in a @trusted way.
 *
 * See_Also: https://forum.dlang.org/post/amvspqyavdavzgjegkzt@forum.dlang.org
 *
 * TODO: Add to std.meta or std.typecons.
 */
template unsafe(alias fn)
{
	auto unsafe(T...)(T args) @trusted
	{
		return fn(args);
	}
}

//
@safe unittest {
	static @system void dummy(int n) {}
	unsafe!({ dummy(42); });
	unsafe!dummy(42);
}
