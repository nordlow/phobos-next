module nxt.char_traits;

/** Is `true` iff `x` is an ASCII character compile-time constant.
 *
 * See_Also: `std.ascii.isASCII`.
 *
 * TODO: Extend to array of chars.
 */
enum isASCII(char x) = x < 128;
enum isASCII(wchar x) = x < 128;
enum isASCII(dchar x) = x < 128;

///
pure nothrow @safe @nogc unittest {
	static assert(isASCII!'a');
	static assert(!isASCII!'ä');

	immutable ch = 'a';
	static assert(isASCII!ch);

	const cch = 'a';
	static assert(isASCII!cch);

	const wchar wch = 'a';
	static assert(isASCII!wch);

	const wchar wch_ = 'ä';
	static assert(!isASCII!wch_);

	const dchar dch = 'a';
	static assert(isASCII!dch);

	const dchar dch_ = 'ä';
	static assert(!isASCII!dch_);
}
