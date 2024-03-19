/++ Algorithms that either improve or complement std.algorithm.searching.`

	NOTE: `static` qualifier on scoped definitions of `struct Result` is needed
	for `inout` to propagate correctly.
 +/
module nxt.algorithm.searching;

// version = unittestAsBetterC; // Run_As: dmd -betterC -unittest -run $(__FILE__).d

/** Array-specialization of `startsWith` with default predicate.
 *
 * See_Also: https://d.godbolt.org/z/ejEmrK
 */
bool startsWith(T)(scope const T[] haystack, scope const T[] needle) @trusted {
	if (haystack.length < needle.length)
		return false;
	return haystack.ptr[0 .. needle.length] == needle;
}
/// ditto
bool startsWith(T)(scope const T[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	if (haystack.length == 0)
		return false;
	return haystack.ptr[0] == needle;
}
///
pure nothrow @safe @nogc unittest {
	const x = "beta version";
	assert(x.startsWith("beta"));
	assert(x.startsWith('b'));
	assert(!x.startsWith("_"));
	assert(!"".startsWith("_"));
	assert(!"".startsWith('_'));
}

/** Array-specialization of `all` with element `needle`. */
bool all(T)(scope const T[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset; 0 .. haystack.length)
		if (haystack.ptr[offset] != needle)
			return false;
	return true;
}
///
pure nothrow @safe @nogc unittest {
	assert("".all('a'));	// matches behaviour of `std.algorithm.searching.any`
	assert("aaa".all('a'));
	assert(!"aa_".all('a'));
}

/** Array-specialization of `any` with element `needle`. */
bool any(T)(scope const T[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset; 0 .. haystack.length)
		if (haystack.ptr[offset] == needle)
			return true;
	return false;
}
///
pure nothrow @safe @nogc unittest {
	assert(!"".any('a'));  // matches behaviour of `std.algorithm.searching.any`
	assert("aaa".any('a'));
	assert("aa_".any('a'));
	assert(!"_".any('a'));
}

/** Array-specialization of `endsWith` with default predicate. */
bool endsWith(T)(scope const T[] haystack, scope const T[] needle) @trusted {
	if (haystack.length < needle.length)
		return false;
	return haystack.ptr[haystack.length - needle.length .. haystack.length] == needle;
}
/// ditto
bool endsWith(T)(scope const T[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	if (haystack.length == 0)
		return false;
	return haystack.ptr[haystack.length - 1] == needle;
}
///
pure nothrow @safe @nogc unittest {
	const x = "beta version";
	assert(x.endsWith("version"));
	assert(x.endsWith('n'));
	assert(!x.endsWith("_"));
	assert(!"".endsWith("_"));
	assert(!"".endsWith('_'));
}

bool startsWithAmong(T)(scope const T[] haystack, scope const T[][] needles) {
	foreach (const needle; needles)
		if (haystack.startsWith(needle)) /+ TODO: optimize +/
			return true;
	return false;
}
/// ditto
bool startsWithAmong(T)(scope const T[] haystack, scope const T[] needles) {
	foreach (const needle; needles)
		if (haystack.startsWith(needle)) /+ TODO: optimize +/
			return true;
	return false;
}
///
pure nothrow @safe @nogc unittest {
	const x = "beta version";
	assert(x.startsWithAmong(["beta", "version", ""]));
	assert(x.startsWithAmong(['b', ' ']));
	assert(x.startsWithAmong("b "));
	assert(!x.startsWithAmong(["_"]));
	assert(!x.startsWithAmong(['_']));
}

bool endsWithAmong(T)(scope const T[] haystack, scope const T[][] needles) {
	foreach (const needle; needles)
		if (haystack.endsWith(needle)) /+ TODO: optimize +/
			return true;
	return false;
}
/// ditto
bool endsWithAmong(T)(scope const T[] haystack, scope const T[] needles) {
	foreach (const needle; needles)
		if (haystack.endsWith(needle)) /+ TODO: optimize +/
			return true;
	return false;
}
///
pure nothrow @safe @nogc unittest {
	const x = "beta version";
	assert(x.endsWithAmong(["version", ""]));
	assert(x.endsWithAmong(['n', ' ']));
	assert(x.endsWithAmong("n "));
	assert(!x.endsWithAmong(["_"]));
	assert(!x.endsWithAmong(['_']));
}

/** Array-specialization of `findSkip` with default predicate.
 */
auto findSkip(T)(scope ref inout(T)[] haystack, scope const T[] needle) @trusted {
	const index = haystack.indexOf(needle);
	if (index != -1) {
		haystack = haystack.ptr[index + needle.length .. haystack.length];
		return true;
	}
	return false;
}
/// ditto
auto findSkip(T)(scope ref inout(T)[] haystack, scope const T needle) @trusted {
	const index = haystack.indexOf(needle);
	if (index != -1) {
		haystack = haystack.ptr[index + 1 .. haystack.length];
		return true;
	}
	return false;
}
///
pure nothrow @safe @nogc unittest {
	const auto x = "abc";
	{
		string y = x;
		const bool ok = y.findSkip("_");
		assert(!ok);
		assert(y is x);
	}
	{
		string y = x;
		const bool ok = y.findSkip("a");
		assert(ok);
		assert(y == x[1 .. $]);
	}
	{
		string y = x;
		const bool ok = y.findSkip("c");
		assert(ok);
		assert(y is x[$ .. $]);
	}
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].findSkip(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const auto x = "abc";
	{
		string y = x;
		const bool ok = y.findSkip('_');
		assert(!ok);
		assert(y is x);
	}
	{
		string y = x;
		const bool ok = y.findSkip('a');
		assert(ok);
		assert(y == x[1 .. $]);
	}
	{
		string y = x;
		const bool ok = y.findSkip('c');
		assert(ok);
		assert(y is x[$ .. $]);
	}
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].findSkip(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `findSkip` with default predicate that finds the last skip.
 */
auto findLastSkip(T)(scope ref inout(T)[] haystack, scope const T[] needle) @trusted {
	const index = haystack.lastIndexOf(needle);
	if (index != -1) {
		haystack = haystack.ptr[index + needle.length .. haystack.length];
		return true;
	}
	return false;
}
///
auto findLastSkip(T)(scope ref inout(T)[] haystack, scope const T needle) @trusted {
	const index = haystack.lastIndexOf(needle);
	if (index != -1) {
		haystack = haystack.ptr[index + 1 .. haystack.length];
		return true;
	}
	return false;
}
///
pure nothrow @safe @nogc unittest {
	const auto x = "abacc";
	{
		string y = x;
		const bool ok = y.findLastSkip("_");
		assert(!ok);
		assert(y is x);
	}
	{
		string y = x;
		const bool ok = y.findLastSkip("a");
		assert(ok);
		assert(y == x[3 .. $]);
	}
	{
		string y = x;
		const bool ok = y.findLastSkip("c");
		assert(ok);
		assert(y is x[$ .. $]);
	}
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSkip(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const auto x = "abacc";
	{
		string y = x;
		const bool ok = y.findLastSkip('_');
		assert(!ok);
		assert(y is x);
	}
	{
		string y = x;
		const bool ok = y.findLastSkip('a');
		assert(ok);
		assert(y == x[3 .. $]);
	}
	{
		string y = x;
		const bool ok = y.findLastSkip('c');
		assert(ok);
		assert(y is x[$ .. $]);
	}
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSkip(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `skipOver` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
bool skipOver(T)(scope ref inout(T)[] haystack, scope const T[] needle) @trusted {
	if (!startsWith(haystack, needle))
		return false;
	haystack = haystack.ptr[needle.length .. haystack.length];
	return true;
}
/// ditto
bool skipOver(T)(scope ref inout(T)[] haystack, scope const T needle) @trusted {
	if (!startsWith(haystack, needle))
		return false;
	haystack = haystack.ptr[1 .. haystack.length];
	return true;
}
///
pure nothrow @safe @nogc unittest {
	string x = "beta version";
	assert(x.skipOver("beta"));
	assert(x == " version");
	assert(x.skipOver(' '));
	assert(x == "version");
	assert(!x.skipOver("_"));
	assert(x == "version");
	assert(!x.skipOver('_'));
	assert(x == "version");
}
/// constness of haystack and needle
pure nothrow @safe @nogc unittest {
	{
		const(char)[] haystack;
		string needle;
		assert(haystack.skipOver(needle));
	}
	{
		const(char)[] haystack;
		const(char)[] needle;
		assert(haystack.skipOver(needle));
	}
	{
		const(char)[] haystack;
		char[] needle;
		assert(haystack.skipOver(needle));
	}
}

/** Array-specialization of `skipOverBack` with default predicate.
 *
 * See: `std.string.chomp`
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
bool skipOverBack(T)(scope ref inout(T)[] haystack, scope const T[] needle) @trusted {
	if (!endsWith(haystack, needle))
		return false;
	haystack = haystack.ptr[0 .. haystack.length - needle.length];
	return true;
}
/// ditto
bool skipOverBack(T)(scope ref inout(T)[] haystack, scope const T needle) @trusted {
	if (!endsWith(haystack, needle))
		return false;
	haystack = haystack.ptr[0 .. haystack.length - 1];
	return true;
}
///
pure nothrow @safe @nogc unittest {
	string x = "beta version";
	assert(x.skipOverBack(" version"));
	assert(x == "beta");
	assert(x.skipOverBack('a'));
	assert(x == "bet");
	assert(!x.skipOverBack("_"));
	assert(x == "bet");
	assert(!x.skipOverBack('_'));
	assert(x == "bet");
}

bool skipOverAround(T)(scope ref inout(T)[] haystack, scope const T[] needleFront, scope const T[] needleBack) @trusted {
	if (!startsWith(haystack, needleFront) ||
		!endsWith(haystack, needleBack))
		return false;
	haystack = haystack.ptr[needleFront.length .. haystack.length - needleBack.length];
	return true;
}
/// ditto
bool skipOverAround(T)(scope ref inout(T)[] haystack, scope const T needleFront, scope const T needleBack) @trusted {
	if (!startsWith(haystack, needleFront) ||
		!endsWith(haystack, needleBack))
		return false;
	haystack = haystack.ptr[1 .. haystack.length - 1];
	return true;
}
///
pure nothrow @safe @nogc unittest {
	string x = "alpha beta_gamma";
	assert(x.skipOverAround("alpha", "gamma"));
	assert(x == " beta_");
	assert(x.skipOverAround(' ', '_'));
	assert(x == "beta");
	assert(!x.skipOverAround(" ", " "));
	assert(x == "beta");
	assert(!x.skipOverAround(' ', ' '));
	assert(x == "beta");
}

/** Array-specialization of `std.string.chompPrefix` with default predicate.
 */
inout(T)[] chompPrefix(T)(scope return inout(T)[] haystack, in T[] needle) @trusted {
	if (startsWith(haystack, needle))
		haystack = haystack.ptr[needle.length .. haystack.length];
	return haystack;
}
inout(T)[] chompPrefix(T)(scope return inout(T)[] haystack, in T needle) @trusted {
	if (startsWith(haystack, needle))
		haystack = haystack.ptr[1 .. haystack.length];
	return haystack;
}
/// ditto
inout(char)[] chompPrefix()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.chompPrefix(' ');
}
///
pure nothrow @safe @nogc unittest {
	assert(chompPrefix("hello world", "he") == "llo world");
	assert(chompPrefix("hello world", "hello w") == "orld");
	assert(chompPrefix("hello world", " world") == "hello world");
	assert(chompPrefix("", "hello") == "");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].chompPrefix(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `std.string.chomp` with default predicate.
 */
inout(T)[] chomp(T)(scope return inout(T)[] haystack, in T[] needle) @trusted {
	if (endsWith(haystack, needle))
		haystack = haystack.ptr[0 .. haystack.length - needle.length];
	return haystack;
}
inout(T)[] chomp(T)(scope return inout(T)[] haystack, in T needle) @trusted {
	if (endsWith(haystack, needle))
		haystack = haystack.ptr[0 .. haystack.length - 1];
	return haystack;
}
///
pure nothrow @safe @nogc unittest {
	assert(chomp("hello world", 'd') == "hello worl");
	assert(chomp(" hello world", "orld") == " hello w");
	assert(chomp(" hello world", " he") == " hello world");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].chomp(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `stripLeft` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripLeft(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = 0;
	while (offset != haystack.length &&
		   haystack.ptr[offset] == needle) /+ TODO: elide range-check +/
		offset += 1;
	return haystack.ptr[offset .. haystack.length];
}
/// ditto
inout(char)[] stripLeft()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.stripLeft(' ');
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".stripLeft(' ') == "beta");
	assert(" beta".stripLeft(' ') == "beta");
	assert("  beta".stripLeft(' ') == "beta");
	assert("   beta".stripLeft(' ') == "beta");
	assert("   beta".stripLeft() == "beta");
	assert(" _ beta _ ".stripLeft(' ') == "_ beta _ ");
	assert(" _  beta _ ".stripLeft(' ') == "_  beta _ ");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripLeft(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `stripRight` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripRight(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = haystack.length;
	while (offset != 0 &&
		   haystack.ptr[offset - 1] == needle) /+ TODO: elide range-check +/
		offset -= 1;
	return haystack.ptr[0 .. offset];
}
/// ditto
inout(T)[] stripRight(T)(scope return inout(T)[] haystack, scope const T[] needles) @trusted {
	static if (is(T : const(char)))
		foreach (needle; needles)
			assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t offset = haystack.length;
	while (offset != 0 &&
		   needles.canFind(haystack.ptr[offset - 1])) /+ TODO: elide range-check +/
		offset -= 1;
	return haystack.ptr[0 .. offset];
}
/// ditto
inout(char)[] stripRight()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.stripRight([' ', '\t', '\r', '\n']); /+ TODO: `std.ascii.iswhite` instead +/
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".stripRight(' ') == "beta");
	assert("beta ".stripRight(' ') == "beta");
	assert("beta  ".stripRight(' ') == "beta");
	assert("beta	".stripRight('	') == "beta");
	assert("beta	".stripRight() == "beta");
	assert(" _ beta _ ".stripRight(' ') == " _ beta _");
	assert(" _  beta _ ".stripRight(' ') == " _  beta _");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripRight(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}

/** Array-specialization of `strip` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] strip(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t leftOffset = 0;
	while (leftOffset != haystack.length &&
		   haystack.ptr[leftOffset] == needle) /+ TODO: elide range-check +/
		leftOffset += 1;
	size_t rightOffset = haystack.length;
	while (rightOffset != leftOffset &&
		   haystack.ptr[rightOffset - 1] == needle) /+ TODO: elide range-check +/
		rightOffset -= 1;
	return haystack.ptr[leftOffset .. rightOffset];
}
/// ditto
inout(char)[] strip()(scope return inout(char)[] haystack) pure nothrow @safe @nogc /*tlm*/ {
	return haystack.strip(' ');
}
///
pure nothrow @safe @nogc unittest {
	assert("beta".strip(' ') == "beta");
	assert(" beta ".strip(' ') == "beta");
	assert("  beta  ".strip(' ') == "beta");
	assert("   beta   ".strip(' ') == "beta");
	assert(" _ beta _ ".strip(' ') == "_ beta _");
	assert(" _  beta _ ".strip(' ') == "_  beta _");
	version (unittest) {
		static char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].strip(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const ubyte[3] x = [0, 42, 0];
	assert(x.strip(0) == x[1 .. 2]);
}

/** Array-specialization of `count` with default predicate.
 *
 * TODO: Add optimized implementation for needles with length >=
 * `largeNeedleLength` with no repeat of elements.
 *
 * TODO: reuse `return haystack.indexOf(needle) != -1` in both overloads
 */
bool canFind(T)(scope const T[] haystack, scope const T[] needle) @trusted
in(needle.length, "Cannot count occurrences of an empty range") {
	// enum largeNeedleLength = 4;
	if (haystack.length < needle.length)
		return false;
	foreach (const offset; 0 .. haystack.length - needle.length + 1)
		if (haystack.ptr[offset .. offset + needle.length] == needle)
			return true;
	return false;
}
/// ditto
bool canFind(T)(scope const T[] haystack, scope const T needle) @trusted {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	if (haystack.length == 0)
		return false;
	foreach (const ref element; haystack)
		if (element == needle)
			return true;
	return false;
}
///
pure nothrow @safe @nogc unittest {
	assert(!"".canFind("_"));
	assert(!"a".canFind("_"));
	assert("a".canFind("a"));
	assert(!"a".canFind("ab"));
	assert("ab".canFind("a"));
	assert("ab".canFind("b"));
	assert("ab".canFind("ab"));
	assert(!"a".canFind("ab"));
	assert(!"b".canFind("ab"));
}
///
pure nothrow @safe @nogc unittest {
	assert(!"".canFind('_'));
	assert(!"a".canFind('_'));
	assert("a".canFind('a'));
	assert("a".canFind('a'));
	assert("ab".canFind('a'));
	assert("ab".canFind('b'));
}

/** Array-specialization of `count` with default predicate.
 */
ptrdiff_t count(T)(scope const T[] haystack, scope const T[] needle) @trusted {
	if (needle.length == 0)
		return -1;
	size_t result = 0;
	if (haystack.length < needle.length)
		return false;
	foreach (const offset; 0 .. haystack.length - needle.length + 1)
		result += haystack.ptr[offset .. offset + needle.length] == needle ? 1 : 0;
	return result;
}
/// ditto
size_t count(T)(scope const T[] haystack, scope const T needle) {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	size_t result;
	foreach (const ref element; haystack)
		result += element == needle ? 1 : 0;
	return result;
}
///
pure nothrow @safe @nogc unittest {
	assert("".count("") == -1); // -1 instead of `assert` that `std.algorithm.count` does
	assert("".count("_") == 0);
	assert("".count(" ") == 0);
	assert(" ".count(" ") == 1);
	assert("abc_abc".count("a") == 2);
	assert("abc_abc".count("abc") == 2);
	assert("_a_a_".count("_") == 3);
	assert("_aaa_".count("a") == 3);
}
///
pure nothrow @safe @nogc unittest {
	assert("".count('_') == 0);
	assert("abc_abc".count('a') == 2);
	assert("_abc_abc_".count('_') == 3);
}

/** Array-specialization of `count` with default predicate and no needle.
 */
size_t count(T)(scope const T[] haystack) => haystack.length;
///
pure nothrow @safe @nogc unittest {
	assert("abc_abc".count == 7);
}

/** Array-specialization of `countAmong` with default predicate.
 */
ptrdiff_t countAmong(T)(scope const T[] haystack, scope const T[][] needles) @trusted {
	if (needles.length == 0)
		return -1;
	size_t result = 0;
	foreach (const ref needle; needles)
		foreach (const offset; 0 .. haystack.length - needle.length + 1)
			result += haystack.ptr[offset .. offset + needle.length] == needle ? 1 : 0;
	return result;
}
/// ditto
ptrdiff_t countAmong(T)(scope const T[] haystack, scope const T[] needles) {
	static if (is(T : const(char)))
		foreach (needle; needles)
			assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	if (needles.length == 0)
		return -1;
	size_t result = 0;
	foreach (const offset; 0 .. haystack.length)
		foreach (const ref needle; needles)
			result += haystack[offset] == needle ? 1 : 0;
	return result;
}
///
pure nothrow @safe @nogc unittest {
	assert("".countAmong(string[].init) == -1);
	assert("".countAmong([""]) == 1);
	assert("".countAmong(["_"]) == 0);
	assert("".countAmong([" "]) == 0);
	assert(" ".countAmong([" "]) == 1);
	assert("abc_abc".countAmong(["a"]) == 2);
	assert("abc_abc".countAmong(["abc"]) == 2);
	assert("_a_a_".countAmong(["_"]) == 3);
	assert("_aaa_".countAmong(["a"]) == 3);
}
///
pure nothrow @safe @nogc unittest {
	assert("".countAmong(string.init) == -1); // -1 instead of `assert` that `std.algorithm.count` does
	assert("".countAmong("") == -1); // -1 instead of `assert` that `std.algorithm.count` does
	assert(" ".countAmong("") == -1); // -1 instead of `assert` that `std.algorithm.count` does
	assert("".countAmong("_") == 0);
	assert("".countAmong(" ") == 0);
	assert(" ".countAmong(" ") == 1);
	assert("abc_abc".countAmong("a") == 2);
	assert("abc_abc".countAmong(" ") == 0);
	assert("abc_abc".countAmong("ab") == 4);
	assert("abc_abc".countAmong("abc") == 6);
	assert("_a_a_".countAmong("_") == 3);
	assert("_aaa_".countAmong("a") == 3);
}

/** Array-specialization of `indexOf` with default predicate.
 *
 * TODO: Add optimized implementation for needles with length >=
 * `largeNeedleLength` with no repeat of elements.
 */
ptrdiff_t indexOf(T)(scope inout(T)[] haystack, scope const(T)[] needle) @trusted {
	// enum largeNeedleLength = 4;
	if (haystack.length < needle.length)
		return -1;
	foreach (const offset; 0 .. haystack.length - needle.length + 1)
		if (haystack.ptr[offset .. offset + needle.length] == needle)
			return offset;
	return -1;
}
/// ditto
ptrdiff_t indexOf(T)(scope inout(T)[] haystack, scope const T needle) {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset, const ref element; haystack)
		if (element == needle)
			return offset;
	return -1;
}
///
pure nothrow @safe @nogc unittest {
	assert("_abc_abc_".indexOf("abc") == 1);
	assert("__abc_".indexOf("abc") == 2);
	assert("a".indexOf("a") == 0);
	assert("abc".indexOf("abc") == 0);
	assert("_".indexOf("a") == -1);
	assert("_".indexOf("__") == -1);
	assert("__".indexOf("a") == -1);
}
///
pure nothrow @safe @nogc unittest {
	assert("_".indexOf('a') == -1);
	assert("a".indexOf('a') == 0);
	assert("_a".indexOf('a') == 1);
	assert("__a".indexOf('a') == 2);
}

/// ditto
ptrdiff_t indexOfAmong(T)(scope inout(T)[] haystack, scope const T[] needles) {
	if (needles.length == 0)
		return -1;
	foreach (const offset, const ref element; haystack)
		foreach (const needle; needles)
			if (element == needle)
				return offset;
	return -1;
}
alias indexOfAny = indexOfAmong; // Compliance with `std.string.indexOfAny`.
///
pure nothrow @safe @nogc unittest {
	assert("_".indexOfAmong("a") == -1);
	assert("_a".indexOfAmong("a") == 1);
	assert("_a".indexOfAmong("ab") == 1);
	assert("_b".indexOfAmong("ab") == 1);
	assert("_b".indexOfAmong("_") == 0);
	assert("_b".indexOfAmong("xy") == -1);
	assert("_b".indexOfAmong("") == -1);
}

/** Array-specialization of `lastIndexOf` with default predicate.
 */
ptrdiff_t lastIndexOf(T)(scope inout(T)[] haystack, scope const(T)[] needle) @trusted {
	if (haystack.length < needle.length)
		return -1;
	foreach_reverse (const offset; 0 .. haystack.length - needle.length + 1)
		if (haystack.ptr[offset .. offset + needle.length] == needle)
			return offset;
	return -1;
}
/// ditto
ptrdiff_t lastIndexOf(T)(scope inout(T)[] haystack, scope const T needle) {
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach_reverse (const offset, const ref element; haystack)
		if (element == needle)
			return offset;
	return -1;
}
///
pure nothrow @safe @nogc unittest {
	assert("_abc_abc_".lastIndexOf("abc") == 5);
	assert("__abc_".lastIndexOf("abc") == 2);
	assert("a".lastIndexOf("a") == 0);
	assert("aa".lastIndexOf("a") == 1);
	assert("abc".lastIndexOf("abc") == 0);
	assert("_".lastIndexOf("a") == -1);
	assert("_".lastIndexOf("__") == -1);
	assert("__".lastIndexOf("a") == -1);
}
///
pure nothrow @safe @nogc unittest {
	assert("_".lastIndexOf('a') == -1);
	assert("a".lastIndexOf('a') == 0);
	assert("_a".lastIndexOf('a') == 1);
	assert("__a".lastIndexOf('a') == 2);
	assert("a__a".lastIndexOf('a') == 3);
}

/** Array-specialization of `findSplit` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findSplit(T)(scope return inout(T)[] haystack, scope const(T)[] needle) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset; // hit offset
		private size_t _length; // hit length
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] opIndex(in size_t i) inout {
			switch (i) {
			case 0: return pre;
			case 1: return separator;
			case 2: return post;
			default: return typeof(return).init;
			}
		}
		inout(T)[] pre() @trusted inout		  => _haystack.ptr[0 .. _offset];
		inout(T)[] separator() @trusted inout => _haystack.ptr[_offset .. _offset + _length];
		inout(T)[] post() @trusted inout	  => _haystack.ptr[_offset + _length .. _haystack.length];
		bool opCast(T : bool)() @safe const	  => _haystack.length != _offset;
	}

	assert(needle.length, "Cannot find occurrence of an empty range");
	const index = haystack.indexOf(needle);
	if (index >= 0)
		return inout(Result)(haystack, index, needle.length);
	return inout(Result)(haystack, haystack.length, 0); // miss
}
/// ditto
auto findSplit(T)(scope return inout(T)[] haystack, scope const T needle) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset; // hit offset
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] opIndex(in size_t i) inout {
			switch (i) {
			case 0: return pre;
			case 1: return separator;
			case 2: return post;
			default: return typeof(return).init;
			}
		}
		inout(T)[] pre() @trusted inout		  => _haystack.ptr[0 .. _offset];
		inout(T)[] separator() @trusted inout => !empty ? _haystack.ptr[_offset .. _offset + 1] : _haystack[$ .. $];
		inout(T)[] post() @trusted inout	  => !empty ? _haystack.ptr[_offset + 1 .. _haystack.length] : _haystack[$ .. $];
		bool opCast(T : bool)() const		  => !empty;
		private bool empty() const @property  => _haystack.length == _offset;
	}
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	const index = haystack.indexOf(needle);
	if (index >= 0)
		return inout(Result)(haystack, index);
	return inout(Result)(haystack, haystack.length);
}
///
pure nothrow @safe @nogc unittest {
	const h = "a**b";
	const r = h.findSplit("**");
	assert(r);
	assert(r.pre is h[0 .. 1]);
	assert(r.separator is h[1 .. 3]);
	assert(r.post is h[3 .. 4]);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplit(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const h = "a**b";
	const r = h.findSplit("_");
	static assert(r.sizeof == 2 * 2 * size_t.sizeof);
	assert(!r);
	assert(r.pre is h);
	assert(r.separator is h[$ .. $]);
	assert(r.post is h[$ .. $]);
}
///
version (none)
pure nothrow @safe @nogc unittest {
	import std.algorithm.searching : findSplit;
	const h = "a**b";
	const r = h.findSplit("_");
	static assert(r.sizeof == 3 * 2 * size_t.sizeof);
	assert(!r);
	assert(r[0] is h);
	assert(r[1] is h[$ .. $]);
	assert(r[2] is h[$ .. $]);
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplit('*');
	static assert(r.sizeof == 3 * size_t.sizeof);
	assert(r);
	assert(r.pre == "a");
	assert(r.separator == "*");
	assert(r.post == "b");
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplit(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
/// DIP-1000 scope analysis
version (none)					// TODO. enable
pure nothrow @safe @nogc unittest {
	char[] f() @safe pure nothrow
	{
		char[3] haystack = "a*b";
		auto r = haystack[].findSplit('*');
		static assert(is(typeof(r.pre()) == char[]));
		return r.pre();		 /+ TODO: this should fail +/
	}
	f();
}

/** Array-specialization of `findLastSplit` with default predicate.
 */
auto findLastSplit(T)(scope return inout(T)[] haystack, scope const(T)[] needle) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset; // hit offset
		private size_t _length; // hit length
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] opIndex(in size_t i) inout {
			switch (i) {
			case 0: return pre;
			case 1: return separator;
			case 2: return post;
			default: return typeof(return).init;
			}
		}
		inout(T)[] pre() @trusted inout		  => _haystack.ptr[0 .. _offset];
		inout(T)[] separator() @trusted inout => _haystack.ptr[_offset .. _offset + _length];
		inout(T)[] post() @trusted inout	  => _haystack.ptr[_offset + _length .. _haystack.length];
		bool opCast(T : bool)() @safe const	  => _haystack.length != _offset;
	}
	assert(needle.length, "Cannot find occurrence of an empty range");
	const index = haystack.lastIndexOf(needle);
	if (index >= 0)
		return inout(Result)(haystack, index, needle.length);
	return inout(Result)(haystack, haystack.length, 0); // miss
}
/// ditto
auto findLastSplit(T)(scope return inout(T)[] haystack, scope const T needle) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset; // hit offset
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] opIndex(in size_t i) inout {
			switch (i) {
			case 0: return pre;
			case 1: return separator;
			case 2: return post;
			default: return typeof(return).init;
			}
		}
		inout(T)[] pre() @trusted inout		  => _haystack.ptr[0 .. _offset];
		inout(T)[] separator() @trusted inout => !empty ? _haystack.ptr[_offset .. _offset + 1] : _haystack[$ .. $];
		inout(T)[] post() @trusted inout	  => !empty ? _haystack.ptr[_offset + 1 .. _haystack.length] : _haystack[$ .. $];
		bool opCast(T : bool)() const		  => !empty;
		private bool empty() const @property  => _haystack.length == _offset;
	}
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	const index = haystack.lastIndexOf(needle);
	if (index >= 0)
		return inout(Result)(haystack, index);
	return inout(Result)(haystack, haystack.length);
}
///
pure nothrow @safe @nogc unittest {
	const h = "a**b**c";
	const r = h.findLastSplit("**");
	assert(r);
	assert(r.pre is h[0 .. 4]);
	assert(r.separator is h[4 .. 6]);
	assert(r.post is h[6 .. 7]);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplit(" "); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const h = "a**b**c";
	const r = h.findLastSplit("_");
	static assert(r.sizeof == 2 * 2 * size_t.sizeof);
	assert(!r);
	assert(r.pre is h);
	assert(r.separator is h[$ .. $]);
	assert(r.post is h[$ .. $]);
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b*c".findLastSplit('*');
	static assert(r.sizeof == 3 * size_t.sizeof);
	assert(r);
	assert(r.pre == "a*b");
	assert(r.separator == "*");
	assert(r.post == "c");
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplit(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
/// DIP-1000 scope analysis
version (none)					/+ TODO: enable +/
pure nothrow @safe @nogc unittest {
	char[] f() @safe pure nothrow
	{
		char[3] haystack = "a*b";
		auto r = haystack[].findLastSplit('*');
		static assert(is(typeof(r.pre()) == char[]));
		return r.pre();		 /+ TODO: this should fail +/
	}
	f();
}

/** Array-specialization of `findSplitBefore` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findSplitBefore(T)(scope return inout(T)[] haystack, scope const T needle) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset;
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] pre() @trusted inout		 => _haystack.ptr[0 .. _offset];
		inout(T)[] post() @trusted inout	 => !empty ? _haystack.ptr[_offset .. _haystack.length] : _haystack[$ .. $];
		bool opCast(T : bool)() const		 => !empty;
		private bool empty() const @property => _haystack.length == _offset;
	}
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset, const ref element; haystack)
		if (element == needle)
			return inout(Result)(haystack, offset);
	return inout(Result)(haystack, haystack.length);
}
///
pure nothrow @safe @nogc unittest {
	char[] haystack;
	auto r = haystack.findSplitBefore('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitBefore(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const(char)[] haystack;
	auto r = haystack.findSplitBefore('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplitBefore('*');
	assert(r);
	assert(r.pre == "a");
	assert(r.post == "*b");
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplitBefore('_');
	assert(!r);
	assert(r.pre == "a*b");
	assert(r.post == "");
}

/** Array-specialization of `findSplitBefore` with explicit needle-only predicate `needlePred`.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findSplitBefore(alias needlePred, T)(scope return inout(T)[] haystack) {
	static struct Result {
		private T[] _haystack;
		private size_t _offset;
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] pre() @trusted inout		 => _haystack.ptr[0 .. _offset];
		inout(T)[] post() @trusted inout	 => !empty ? _haystack.ptr[_offset .. _haystack.length] : _haystack[$ .. $];
		bool opCast(T : bool)() const		 => !empty;
		private bool empty() const @property => _haystack.length == _offset;
	}
	foreach (const offset, const ref element; haystack)
		if (needlePred(element))
			return inout(Result)(haystack, offset);
	return inout(Result)(haystack, haystack.length);
}
///
pure nothrow @safe @nogc unittest {
	char[] haystack;
	auto r = haystack.findSplitBefore!(_ => _ == '_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitBefore!(_ => _ == ' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const(char)[] haystack;
	auto r = haystack.findSplitBefore!(_ => _ == '_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == const(char)[]));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplitBefore!(_ => _ == '*');
	assert(r);
	assert(r.pre == "a");
	assert(r.post == "*b");
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplitBefore!(_ => _ == '*' || _ == '+');
	assert(r);
	assert(r.pre == "a");
	assert(r.post == "*b");
}
///
pure nothrow @safe @nogc unittest {
	const r = "a+b".findSplitBefore!(_ => _ == '*' || _ == '+');
	assert(r);
	assert(r.pre == "a");
	assert(r.post == "+b");
}
///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplitBefore!(_ => _ == '_');
	assert(!r);
	assert(r.pre == "a*b");
	assert(r.post == "");
}

/** Array-specialization of `findSplitAfter` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findSplitAfter(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static struct Result {
		private T[] _haystack;
		private size_t _offset;
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] pre() @trusted inout		 => !empty ? _haystack.ptr[0 .. _offset + 1] : _haystack[$ .. $];
		inout(T)[] post() @trusted inout	 => !empty ? _haystack.ptr[_offset + 1 .. _haystack.length] : _haystack[0 .. $];
		bool opCast(T : bool)() const		 => !empty;
		private bool empty() const @property => _haystack.length == _offset;
	}
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset, const ref element; haystack)
		if (element == needle)
			return inout(Result)(haystack, offset);
	return inout(Result)(haystack, haystack.length);
}
///
pure nothrow @safe @nogc unittest {
	char[] haystack;
	auto r = haystack.findSplitAfter('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitAfter(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const(char)[] haystack;
	auto r = haystack.findSplitAfter('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
}
///
pure nothrow @safe @nogc unittest {
	auto haystack = "a*b";
	auto r = haystack.findSplitAfter('*');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(r);
	assert(r.pre == "a*");
	assert(r.post == "b");
}

/** Array-specialization of `findLastSplitAfter` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findLastSplitAfter(T)(scope return inout(T)[] haystack, scope const T needle) @trusted {
	static struct Result {
		private T[] _haystack;
		private size_t _offset;
	pragma(inline, true) pure nothrow @nogc:
		inout(T)[] pre() @trusted inout		 => !empty ? _haystack.ptr[0 .. _offset + 1] : _haystack[$ .. $];
		inout(T)[] post() @trusted inout	 => !empty ? _haystack.ptr[_offset + 1 .. _haystack.length] : _haystack[0 .. $];
		bool opCast(T : bool)() const		 => !empty;
		private bool empty() const @property => _haystack.length == _offset;
	}
	static if (is(T : const(char)))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	const index = haystack.lastIndexOf(needle);
	if (index >= 0)
		return inout(Result)(haystack, index);
	return inout(Result)(haystack, haystack.length); // miss
}
///
pure nothrow @safe @nogc unittest {
	char[] haystack;
	auto r = haystack.findLastSplitAfter('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
	version (unittest) {
		static auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplitAfter(' '); }
		static if (hasPreviewDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
	}
}
///
pure nothrow @safe @nogc unittest {
	const(char)[] haystack;
	auto r = haystack.findLastSplitAfter('_');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(!r);
	assert(!r.pre);
	assert(!r.post);
}
///
pure nothrow @safe @nogc unittest {
	auto haystack = "a*b*c";
	auto r = haystack.findLastSplitAfter('*');
	static assert(is(typeof(r.pre()) == typeof(haystack)));
	static assert(is(typeof(r.post()) == typeof(haystack)));
	assert(r);
	assert(r.pre == "a*b*");
	assert(r.post == "c");
}

import std.traits : isExpressions;

/** Like `findSplit` but with multiple separator `needles` known at compile-time
 * to prevent `NarrowString` decoding.
 *
 * TODO: Resort to `memchr` for some case `if (!__ctfe)`.
 * See_Also: https://forum.dlang.org/post/efpbmtyisamwwqgpxnbq@forum.dlang.org
 *
 * See_Also: https://forum.dlang.org/post/ycotlbfsqoupogaplkvf@forum.dlang.org
 */
template findSplitAmong(needles...)
if (needles.length != 0 &&
	isExpressions!needles) {
	import std.meta : allSatisfy;
	import nxt.char_traits : isASCII;

	auto findSplitAmong(Haystack)(const scope return Haystack haystack) @trusted /+ TODO: qualify with `inout` to reduce template bloat +/
	if (is(typeof(Haystack.init[0 .. 0])) && // can be sliced
		is(typeof(Haystack.init[0]) : char) &&
		allSatisfy!(isASCII, needles)) {
		// similar return result to `std.algorithm.searching.findSplit`
		static struct Result {
			/* Only requires 3 words opposite to Phobos' `findSplit`,
			 * `findSplitBefore` and `findSplitAfter`:
			 */

			private Haystack _haystack; // original copy of haystack
			private size_t _offset; // hit offset if any, or `_haystack.length` if miss

			bool opCast(T : bool)() const => !empty;

			inout(Haystack) opIndex(in size_t i) inout {
				switch (i) {
				case 0: return pre;
				case 1: return separator;
				case 2: return post;
				default: return typeof(return).init;
				}
			}

		@property:
			private bool empty() const => _haystack.length == _offset;

			inout(Haystack) pre() inout => _haystack[0 .. _offset];

			inout(Haystack) separator() inout {
				if (empty) { return _haystack[$ .. $]; }
				return _haystack[_offset .. _offset + 1];
			}

			inout(Haystack) post() inout {
				if (empty) { return _haystack[$ .. $]; }
				return _haystack[_offset + 1 .. $];
			}
		}

		enum use_memchr = false;
		static if (use_memchr &&
				   needles.length == 1) {
			// See_Also: https://forum.dlang.org/post/piowvfbimztbqjvieddj@forum.dlang.org
			import core.stdc.string : memchr;
			// extern (C) @system nothrow @nogc pure void* rawmemchr(return const void* s, int c);

			const void* hit = memchr(haystack.ptr, needles[0], haystack.length);
			return Result(haystack, hit ? hit - cast(const(void)*)haystack.ptr : haystack.length);
		} else {
			foreach (immutable offset; 0 .. haystack.length) {
				static if (needles.length == 1) {
					immutable hit = haystack[offset] == needles[0];
				} else {
					import std.algorithm.comparison : among;
					immutable hit = haystack[offset].among!(needles) != 0;
				}
				if (hit)
					return Result(haystack, offset);
			}
			return Result(haystack, haystack.length);
		}
	}
}

template findSplit(needles...)
if (needles.length == 1 &&
	isExpressions!needles) {
	import nxt.char_traits : isASCII;
	auto findSplit(Haystack)(const scope return Haystack haystack) @trusted /+ TODO: qualify with `inout` to reduce template bloat +/
	if (is(typeof(Haystack.init[0 .. 0])) && // can be sliced
		is(typeof(Haystack.init[0]) : char) &&
		isASCII!(needles[0])) {
		return findSplitAmong!(needles)(haystack);
	}
}

///
pure nothrow @safe @nogc unittest {
	const r = "a*b".findSplit!('*');
	assert(r);

	assert(r[0] == "a");
	assert(r.pre == "a");

	assert(r[1] == "*");
	assert(r.separator == "*");

	assert(r[2] == "b");
	assert(r.post == "b");
}

///
pure nothrow @safe @nogc unittest {
	auto r = "a+b*c".findSplitAmong!('+', '-');

	static assert(r.sizeof == 24);
	static assert(is(typeof(r.pre) == string));
	static assert(is(typeof(r.separator) == string));
	static assert(is(typeof(r.post) == string));

	assert(r);

	assert(r[0] == "a");
	assert(r.pre == "a");

	assert(r[1] == "+");
	assert(r.separator == "+");

	assert(r[2] == "b*c");
	assert(r.post == "b*c");
}

///
pure nothrow @safe @nogc unittest {
	const r = "a+b*c".findSplitAmong!('-', '*');
	assert(r);
	assert(r.pre == "a+b");
	assert(r.separator == "*");
	assert(r.post == "c");
}

///
pure nothrow @safe @nogc unittest {
	const r = "a*".findSplitAmong!('*');

	assert(r);

	assert(r[0] == "a");
	assert(r.pre == "a");

	assert(r[1] == "*");
	assert(r.separator == "*");

	assert(r[2] == "");
	assert(r.post == "");
}

///
pure nothrow @safe @nogc unittest {
	const r = "*b".findSplitAmong!('*');

	assert(r);

	assert(r[0] == "");
	assert(r.pre == "");

	assert(r[1] == "*");
	assert(r.separator == "*");

	assert(r[2] == "b");
	assert(r.post == "b");
}

///
pure nothrow @safe @nogc unittest {
	const r = "*".findSplitAmong!('*');

	assert(r);

	assert(r[0] == "");
	assert(r.pre == "");

	assert(r[1] == "*");
	assert(r.separator == "*");

	assert(r[2] == "");
	assert(r.post == "");
}

///
pure nothrow @safe @nogc unittest {
	static immutable separator_char = '/';

	immutable r = "a+b*c".findSplitAmong!(separator_char);

	static assert(r.sizeof == 24);
	static assert(is(typeof(r.pre) == immutable string));
	static assert(is(typeof(r.separator) == immutable string));
	static assert(is(typeof(r.post) == immutable string));

	assert(!r);

	assert(r.pre == "a+b*c");
	assert(r[0] == "a+b*c");
	assert(r.separator == []);
	assert(r[1] == []);
	assert(r.post == []);
	assert(r[2] == []);
}

version (unittest) {
	import nxt.dip_traits : hasPreviewDIP1000;
	import nxt.array_help : s;
}

// See_Also: https://dlang.org/spec/betterc.html#unittests
version (unittestAsBetterC)
extern(C) void main() {
	static foreach (u; __traits(getUnitTests, __traits(parent, main))) {
		u();
	}
}
