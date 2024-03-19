module nxt.container.nary_tree;

import std.experimental.allocator.common : isAllocator;
import std.experimental.allocator.gc_allocator : GCAllocator;

/** Grow-only N-ary tree storing elements of type `E`.
 *
 * TODO: Complete.
 * TODO: Default `Allocator` to a suitable default growth-only allocator.
 *
 * See_Also: https://en.wikipedia.org/wiki/M-ary_tree
 * See_Also: http://forum.dlang.org/post/prsxfcmkngfwomygmthi@forum.dlang.org
 */
struct GrowOnlyNaryTree(E, uint N, Allocator = GCAllocator)
if (N >= 2 && isAllocator!Allocator) {
	alias degree = N;
	this(E rootValue) {_root.value = rootValue;}
	/// Returns: root|top node.
	@property inout(Node!(E, N)) root() inout return scope => _root;
	/// ditto
	alias top = root;
private:
	import nxt.allocator_traits : AllocatorState;
	mixin AllocatorState!Allocator; // put first as emsi-containers do
	Node!(E, N) _root;
}

/** Grow-only binary tree storing elements of type `E`. */
alias GrowOnlyBinaryTree(E, Allocator = GCAllocator) = GrowOnlyNaryTree!(E, 2, Allocator);

/** Grow-only ternary tree storing elements of type `E`. */
alias GrowOnlyTernaryTree(E, Allocator = GCAllocator) = GrowOnlyNaryTree!(E, 3, Allocator);

/** Node containing an element of type `E`. */
struct Node(E, uint N) {
private:
	static if (!is(E == void))
		E value;
	/++ Sub-nodes (children). +/
	Node!(E, N)*[N] subs;
}

///
pure @safe unittest {
	struct X { string src; }
	enum N = 4;
	const e = X("alpha");
	auto tree = GrowOnlyNaryTree!(X, N)(e);
	assert(tree.root.value == e);
}
