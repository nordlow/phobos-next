module nxt.parsing;

/** Returns: true if `s` is null-terminated (ending with `'\0'`).
 *
 * Prior to parsing used to verify input to parsers that make use of
 * sentinel-based search.
 *
 * See_Also: https://en.wikipedia.org/wiki/Sentinel_value
 */
bool isNullTerminated(scope const(char)[] s) pure nothrow @safe @nogc
{
	version (D_Coverage) {} else pragma(inline, true);
	return s.length >= 1 && s[$ - 1] == '\0';
}
