/** Conversions from string/file offset to line and column.
	See_Also: https://gcc.gnu.org/codingconventions.html#Diagnostics
    See_Also: https://clang.llvm.org/diagnostics.html
 */
module nxt.line_column;

import nxt.path : FilePath;

public import nxt.offset : Offset;

@safe:

/++ Source Line.
 +/
alias Line = uint;

/++ Source Column.
 +/
alias Column = uint;

/** Line and column, both 0-based byte offsets.
 *
 * Uses 32-bit unsigned precision for line and column offet, for now, like
 * tree-sitter does.
 */
pure nothrow @nogc struct LineColumn {
	Line line;					///< 0-based line byte offset.
	Column column;				///< 0-based column byte offset.
}

/** Convert byte offset `offset` in `txt` to (line, column) byte offsets.
 *
 * The returned line byte offset and column byte offsets both start at zero.
 *
 * TODO: extend to support UTF-8 in column offset.
 * TODO: Move to Phobos std.txting?
 */
LineColumn scanLineColumnToOffset(in char[] txt, in Offset offset) pure nothrow @nogc {
	// find 0-based column offset
	size_t c = offset.sz;	  // cursor offset
	while (c != 0) {
		if (txt[c - 1] == '\n' ||
			txt[c - 1] == '\r')
			break;
		c -= 1;
	}
	// `c` is now at beginning of line

	/+ TODO: count UTF-8 chars in `txt[c .. offset.sz]` +/
	const column = offset.sz - c; // column byte offset

	// find 0-based line offset
	size_t lineCounter = 0;
	while (c != 0) {
		c -= 1;
		if (txt[c] == '\n') {
			if (c != 0 && txt[c - 1] == '\r') // DOS-style line ending "\r\n"
				c -= 1;
			else {} // Unix-style line ending "\n"
			lineCounter += 1;
		} else if (txt[c] == '\r') // Old Mac-style line ending "\r"
			lineCounter += 1;
		else {}				// no line ending at `c`
	}

	return typeof(return)(cast(Line)lineCounter,
						  cast(Column)column);
}

///
pure nothrow @safe @nogc unittest {
	auto x = "\nx\n y\rz";
	assert(x.length == 7);
	assert(x.scanLineColumnToOffset(Offset(0)) == LineColumn(0, 0));
	assert(x.scanLineColumnToOffset(Offset(1)) == LineColumn(1, 0));
	assert(x.scanLineColumnToOffset(Offset(2)) == LineColumn(1, 1));
	assert(x.scanLineColumnToOffset(Offset(3)) == LineColumn(2, 0));
	assert(x.scanLineColumnToOffset(Offset(4)) == LineColumn(2, 1));
	assert(x.scanLineColumnToOffset(Offset(6)) == LineColumn(3, 0));
	assert(x.scanLineColumnToOffset(Offset(7)) == LineColumn(3, 1));
}

version (unittest) {
	import nxt.debugio;
}
