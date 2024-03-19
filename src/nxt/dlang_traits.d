/** Check presence of proposed extensions/modifications to the D language itself.
 *
 * See_Also: https://forum.dlang.org/post/acjltvvqhfcchpwgodqn@forum.dlang.org
 */
module nxt.dlang_traits;

pure nothrow @safe @nogc:

/// Is `true` if D supports `foreach (const ref e; range)`.
private enum hasRefForeach = __traits(compiles, {
		mixin(`void f() { int[2] _ = [1, 2]; foreach (const ref e; _) {} }`);
	});

/// Is `true` if D supports `foreach (const auto ref e; range)`.
private enum hasAutoRefForeach = __traits(compiles, () {
		mixin(`void f() { int[2] _ = [1, 2]; foreach (const auto ref e; _) {} }`);
	});

///
unittest {
	static assert(hasRefForeach);
	static assert(!hasAutoRefForeach);
}
