/** Reorder aggregate tupleof by descending alignment.
 */
module nxt.align_reorder;

// version = show;

struct S
{
	bool x;
	bool y;
	int i;
	bool z;
}

template staticSortByDescendingAlignment(Ts...) {
	import std.meta : staticSort;
	alias staticSortByDescendingAlignment = staticSort!(alignofComp, Ts);
	enum alignofComp(alias A, alias B) = A.alignof > B.alignof;
}

/** Compile-time logging in format similar to compiler diagnotics messages.
 *
 * See_Also: https://forum.dlang.org/post/nvffhcuxicmtgsxbketg@forum.dlang.org
 */
mixin template ctLog(string msg,
					 string file = __FILE__,
					 size_t line = __LINE__) {
	pragma(msg, file, "(", line, "): ", msg);
}

pure @safe unittest {
	import std.meta : AliasSeq;
	version (show) pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", S.sizeof);
	alias T = AliasSeq!(staticSortByDescendingAlignment!(typeof(S.tupleof)));
	version (show) pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", T, " of size ");
}
