/** Dynamic Ownership and borrowing á lá Rust at run-time instead of compile-time.

	TODO: Override all members with write checks. See
	http://forum.dlang.org/post/mailman.63.1478697690.3405.digitalmars-d-learn@puremagic.com

	TODO: Perhaps disable all checking (and unittests) in release mode (when
	debug is not active), but preserve overloads sliceRO and sliceRW. If not use
	`enforce` instead.

	TODO: Implement and use trait `hasUnsafeSlicing`

	TODO: Add WriteBorrowedPointer, ReadBorrowedPointer to wrap `ptr` access to
	Container

	TODO: Is sliceRW and sliceRO good names?

	TODO: can we make the `_range` member non-visible but the alias this public
	in ReadBorrowed and WriteBorrowed
 */
module nxt.borrown;

public import nxt.owned;
public import nxt.borrowed;
