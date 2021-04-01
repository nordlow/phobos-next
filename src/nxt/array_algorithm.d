/** Array-only overloads of Phobos algorithms.
 *
 * Functions are when possible `@safe pure nothrow @nogc`.
 * Haystack parameter is when possible and relevant `scope return inout(T)[]` and DIP-1000-compliant.
 * Needle parameter is either `scope const(T)[]` or `scope const T[]`.
 *
 * Provides more than twice as fast compilation for `char`-arrays (`string`s).
 *
 * See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
 * See_Also: https://forum.dlang.org/thread/ybamybeakxwxwleebnwb@forum.dlang.org?page=1
 *
 * TODO: Merge into separate array-specializations of Phobos algorithms for less template bloat in Phobos.
 */
module nxt.array_algorithm;

// version = unittestAsBetterC; // Run_As: dmd -betterC -unittest -run $(__FILE__).d

/** Array-specialization of `startsWith` with default predicate.
 *
 * See_Also: https://d.godbolt.org/z/ejEmrK
 */
bool startsWith(T)(scope const T[] haystack,
                   scope const T[] needle) @trusted
{
    if (haystack.length < needle.length)
        return false;
    return haystack.ptr[0 .. needle.length] == needle;
}
/// ditto
bool startsWith(T)(scope const T[] haystack,
                   scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    if (haystack.length == 0)
        return false;
    return haystack.ptr[0] == needle;
}

///
@safe pure nothrow @nogc unittest
{
    const x = "beta version";
    assert(x.startsWith("beta"));
    assert(x.startsWith('b'));
    assert(!x.startsWith("_"));
}

/** Array-specialization of `all` with element needle. */
bool all(T)(scope const T[] haystack,
            scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach (const offset; 0 .. haystack.length)
        if (haystack.ptr[offset] != needle)
            return false;
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    assert("".all('a'));    // matches behaviour of `std.algorithm.searching.any`
    assert("aaa".all('a'));
    assert(!"aa_".all('a'));
}

/** Array-specialization of `any` with element needle. */
bool any(T)(scope const T[] haystack,
            scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach (const offset; 0 .. haystack.length)
        if (haystack.ptr[offset] == needle)
            return true;
    return false;
}

///
@safe pure nothrow @nogc unittest
{
    assert(!"".any('a'));  // matches behaviour of `std.algorithm.searching.any`
    assert("aaa".any('a'));
    assert("aa_".any('a'));
    assert(!"_".any('a'));
}

/** Array-specialization of `endsWith` with default predicate. */
bool endsWith(T)(scope const T[] haystack,
                 scope const T[] needle) @trusted
{
    if (haystack.length < needle.length)
        return false;
    return haystack.ptr[haystack.length - needle.length .. haystack.length] == needle;
}
/// ditto
bool endsWith(T)(scope const T[] haystack,
                 scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    if (haystack.length == 0)
        return false;
    return haystack.ptr[haystack.length - 1] == needle;
}

///
@safe pure nothrow @nogc unittest
{
    const x = "beta version";
    assert(x.endsWith("version"));
    assert(x.endsWith('n'));
    assert(!x.startsWith("_"));
}

bool endsWithEither(T)(scope const T[] haystack,
                       scope const T[][] needles) @trusted
{
    foreach (const needle; needles)
        if (haystack.endsWith(needle)) // TODO: optimize
            return true;
    return false;
}
/// ditto
bool endsWithEither(T)(scope const T[] haystack,
                       scope const T[] needles) @trusted
{
    foreach (const needle; needles)
        if (haystack.endsWith(needle)) // TODO: optimize
            return true;
    return false;
}

///
@safe pure nothrow @nogc unittest
{
    const x = "beta version";
    assert(x.endsWithEither(["version", ""]));
    assert(x.endsWithEither(['n', ' ']));
    assert(x.endsWithEither("n "));
}

/** Array-specialization of `findSkip` with default predicate.
 */
auto findSkip(T)(scope ref inout(T)[] haystack,
                 scope const T[] needle) @trusted
{
    const index = haystack.indexOf(needle);
    if (index != -1)
    {
        haystack = haystack.ptr[index + needle.length .. haystack.length];
        return true;
    }
    return false;
}
/// ditto
auto findSkip(T)(scope ref inout(T)[] haystack,
                 scope const T needle) @trusted
{
    const index = haystack.indexOf(needle);
    if (index != -1)
    {
        haystack = haystack.ptr[index + 1 .. haystack.length];
        return true;
    }
    return false;
}

///
@safe pure nothrow @nogc unittest
{
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
    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSkip(" "); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
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
    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSkip(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/** Array-specialization of `findSkip` with default predicate that finds the last skip.
 */
auto findLastSkip(T)(scope ref inout(T)[] haystack,
                     scope const T[] needle) @trusted
{
    const index = haystack.lastIndexOf(needle);
    if (index != -1)
    {
        haystack = haystack.ptr[index + needle.length .. haystack.length];
        return true;
    }
    return false;
}
///
auto findLastSkip(T)(scope ref inout(T)[] haystack,
                     scope const T needle) @trusted
{
    const index = haystack.lastIndexOf(needle);
    if (index != -1)
    {
        haystack = haystack.ptr[index + 1 .. haystack.length];
        return true;
    }
    return false;
}

///
@safe pure nothrow @nogc unittest
{
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
    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSkip(" "); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
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
    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSkip(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/** Array-specialization of `skipOver` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
bool skipOver(T)(scope ref inout(T)[] haystack,
                 scope const T[] needle) @trusted
{
    if (!startsWith(haystack, needle))
        return false;
    haystack = haystack.ptr[needle.length .. haystack.length];
    return true;
}
/// ditto
bool skipOver(T)(scope ref inout(T)[] haystack,
                 scope const T needle) @trusted
{
    if (!startsWith(haystack, needle))
        return false;
    haystack = haystack.ptr[1 .. haystack.length];
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    string x = "beta version";
    assert(x.skipOver("beta"));
    assert(x == " version");
    assert(x.skipOver(' '));
    assert(x == "version");
}

/// constness of haystack and needle
@safe pure nothrow @nogc unittest
{
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
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
bool skipOverBack(T)(scope ref inout(T)[] haystack,
                     scope const T[] needle) @trusted
{
    if (!endsWith(haystack, needle))
        return false;
    haystack = haystack.ptr[0 .. haystack.length - needle.length];
    return true;
}
/// ditto
bool skipOverBack(T)(scope ref inout(T)[] haystack,
                     scope const T needle) @trusted
{
    if (!endsWith(haystack, needle))
        return false;
    haystack = haystack.ptr[0 .. haystack.length - 1];
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    string x = "beta version";
    assert(x.skipOverBack(" version"));
    assert(x == "beta");
    assert(x.skipOverBack('a'));
    assert(x == "bet");
}

bool skipOverAround(T)(scope ref inout(T)[] haystack,
                       scope const T[] needleFront,
                       scope const T[] needleBack) @trusted
{
    if (!startsWith(haystack, needleFront) ||
        !endsWith(haystack, needleBack))
        return false;
    haystack = haystack.ptr[needleFront.length .. haystack.length - needleBack.length];
    return true;
}
/// ditto
bool skipOverAround(T)(scope ref inout(T)[] haystack,
                       scope const T needleFront,
                       scope const T needleBack) @trusted
{
    if (!startsWith(haystack, needleFront) ||
        !endsWith(haystack, needleBack))
        return false;
    haystack = haystack.ptr[1 .. haystack.length - 1];
    return true;
}

///
@safe pure nothrow @nogc unittest
{
    string x = "alpha beta_gamma";
    assert(x.skipOverAround("alpha", "gamma"));
    assert(x == " beta_");
    assert(x.skipOverAround(' ', '_'));
    assert(x == "beta");
}

/** Array-specialization of `stripLeft` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripLeft(T)(scope return inout(T)[] haystack,
                        scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    size_t offset = 0;
    while (offset != haystack.length &&
           haystack.ptr[offset] == needle) // TODO: elide range-check
        offset += 1;
    return haystack.ptr[offset .. haystack.length];
}
/// ditto
inout(char)[] stripLeft()(scope return inout(char)[] haystack) @safe pure nothrow @nogc // template-lazy
{
    return haystack.stripLeft(' ');
}

///
@safe pure nothrow @nogc unittest
{
    assert("beta".stripLeft(' ') == "beta");
    assert(" beta".stripLeft(' ') == "beta");
    assert("  beta".stripLeft(' ') == "beta");
    assert("   beta".stripLeft(' ') == "beta");
    assert("   beta".stripLeft() == "beta");
    assert(" _ beta _ ".stripLeft(' ') == "_ beta _ ");
    assert(" _  beta _ ".stripLeft(' ') == "_  beta _ ");

    char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripLeft(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/** Array-specialization of `stripRight` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] stripRight(T)(scope return inout(T)[] haystack,
                         scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    size_t offset = haystack.length;
    while (offset != 0 &&
           haystack.ptr[offset - 1] == needle) // TODO: elide range-check
        offset -= 1;
    return haystack.ptr[0 .. offset];
}
/// ditto
inout(char)[] stripRight()(scope return inout(char)[] haystack) @safe pure nothrow @nogc // template-lazy
{
    return haystack.stripRight(' ');
}

///
@safe pure nothrow @nogc unittest
{
    assert("beta".stripRight(' ') == "beta");
    assert("beta ".stripRight(' ') == "beta");
    assert("beta  ".stripRight(' ') == "beta");
    assert("beta    ".stripRight(' ') == "beta");
    assert("beta    ".stripRight() == "beta");
    assert(" _ beta _ ".stripRight(' ') == " _ beta _");
    assert(" _  beta _ ".stripRight(' ') == " _  beta _");

    char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].stripRight(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/** Array-specialization of `strip` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 */
inout(T)[] strip(T)(scope return inout(T)[] haystack,
                    scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org

    size_t leftOffset = 0;
    while (leftOffset != haystack.length &&
           haystack.ptr[leftOffset] == needle) // TODO: elide range-check
        leftOffset += 1;

    size_t rightOffset = haystack.length;
    while (rightOffset != leftOffset &&
           haystack.ptr[rightOffset - 1] == needle) // TODO: elide range-check
        rightOffset -= 1;

    return haystack.ptr[leftOffset .. rightOffset];
}
/// ditto
inout(char)[] strip()(scope return inout(char)[] haystack) @safe pure nothrow @nogc // template-lazy
{
    return haystack.strip(' ');
}

///
@safe pure nothrow @nogc unittest
{
    assert("beta".strip(' ') == "beta");
    assert(" beta ".strip(' ') == "beta");
    assert("  beta  ".strip(' ') == "beta");
    assert("   beta   ".strip(' ') == "beta");
    assert(" _ beta _ ".strip(' ') == "_ beta _");
    assert(" _  beta _ ".strip(' ') == "_  beta _");

    char[] f()() @safe pure nothrow { char[1] x = "_"; return x[].strip(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
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
bool canFind(T)(scope const T[] haystack,
                scope const T[] needle) @trusted
{
    // enum largeNeedleLength = 4;
    assert(needle.length, "Cannot count occurrences of an empty range");
    if (haystack.length < needle.length)
        return false;
    foreach (const offset; 0 .. haystack.length - needle.length + 1)
        if (haystack.ptr[offset .. offset + needle.length] == needle)
            return true;
    return false;
}
/// ditto
bool canFind(T)(scope const T[] haystack,
                scope const T needle) @trusted
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    if (haystack.length == 0)
        return false;
    foreach (const ref element; haystack)
        if (element == needle)
            return true;
    return false;
}

///
@safe pure nothrow @nogc unittest
{
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
@safe pure nothrow @nogc unittest
{
    assert(!"".canFind('_'));
    assert(!"a".canFind('_'));
    assert("a".canFind('a'));
    assert("a".canFind('a'));
    assert("ab".canFind('a'));
    assert("ab".canFind('b'));
}

/** Array-specialization of `count` with default predicate.
 */
size_t count(T)(scope const T[] haystack,
                scope const T[] needle) @trusted
{
    assert(needle.length, "Cannot count occurrences of an empty range");
    size_t result = 0;
    if (haystack.length < needle.length)
        return false;
    foreach (const offset; 0 .. haystack.length - needle.length + 1)
        result += haystack.ptr[offset .. offset + needle.length] == needle ? 1 : 0;
    return result;
}
/// ditto
size_t count(T)(scope const T[] haystack,
                scope const T needle)
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    size_t result;
    foreach (const ref element; haystack)
        result += element == needle ? 1 : 0;
    return result;
}

///
@safe pure nothrow @nogc unittest
{
    // import std.algorithm.searching : count;
    assert("".count("_") == 0);
    assert("".count(" ") == 0);
    assert(" ".count(" ") == 1);
    assert("abc_abc".count("a") == 2);
    assert("abc_abc".count("abc") == 2);
    assert("_a_a_".count("_") == 3);
    assert("_aaa_".count("a") == 3);
    // assert("".count("") == 0);
    // assert("_a_a_".count("") == 5);
}

///
@safe pure nothrow @nogc unittest
{
    assert("".count('_') == 0);
    assert("abc_abc".count('a') == 2);
    assert("_abc_abc_".count('_') == 3);
}

/** Array-specialization of `count` with default predicate and no needle.
 */
size_t count(T)(scope const T[] haystack)
{
    version(D_Coverage) {} else pragma(inline, true);
    return haystack.length;
}

///
@safe pure nothrow @nogc unittest
{
    assert("abc_abc".count == 7);
}

/** Array-specialization of `indexOf` with default predicate.
 *
 * TODO: Add optimized implementation for needles with length >=
 * `largeNeedleLength` with no repeat of elements.
 */
ptrdiff_t indexOf(T)(scope inout(T)[] haystack,
                     scope const(T)[] needle) @trusted
{
    // enum largeNeedleLength = 4;
    if (haystack.length < needle.length)
        return -1;
    foreach (const offset; 0 .. haystack.length - needle.length + 1)
        if (haystack.ptr[offset .. offset + needle.length] == needle)
            return offset;
    return -1;
}
/// ditto
ptrdiff_t indexOf(T)(scope inout(T)[] haystack,
                     scope const T needle)
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach (const offset, const ref element; haystack)
        if (element == needle)
            return offset;
    return -1;
}

///
@safe pure nothrow @nogc unittest
{
    assert("_abc_abc_".indexOf("abc") == 1);
    assert("__abc_".indexOf("abc") == 2);
    assert("a".indexOf("a") == 0);
    assert("abc".indexOf("abc") == 0);
    assert("_".indexOf("a") == -1);
    assert("_".indexOf("__") == -1);
    assert("__".indexOf("a") == -1);
}

///
@safe pure nothrow @nogc unittest
{
    assert("_".indexOf('a') == -1);
    assert("a".indexOf('a') == 0);
    assert("_a".indexOf('a') == 1);
    assert("__a".indexOf('a') == 2);
}

/// ditto
ptrdiff_t indexOfEither(T)(scope inout(T)[] haystack,
                           scope const T[] needles)
{
    if (needles.length == 0)
        return -1;
    foreach (const offset, const ref element; haystack)
        foreach (const needle; needles)
            if (element == needle)
                return offset;
    return -1;
}

///
@safe pure nothrow @nogc unittest
{
    assert("_".indexOfEither("a") == -1);
    assert("_a".indexOfEither("a") == 1);
    assert("_a".indexOfEither("ab") == 1);
    assert("_b".indexOfEither("ab") == 1);
    assert("_b".indexOfEither("_") == 0);
    assert("_b".indexOfEither("xy") == -1);
}

/** Array-specialization of `lastIndexOf` with default predicate.
 */
ptrdiff_t lastIndexOf(T)(scope inout(T)[] haystack,
                         scope const(T)[] needle) @trusted
{
    if (haystack.length < needle.length)
        return -1;
    foreach_reverse (const offset; 0 .. haystack.length - needle.length + 1)
        if (haystack.ptr[offset .. offset + needle.length] == needle)
            return offset;
    return -1;
}
/// ditto
ptrdiff_t lastIndexOf(T)(scope inout(T)[] haystack,
                         scope const T needle)
{
    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach_reverse (const offset, const ref element; haystack)
        if (element == needle)
            return offset;
    return -1;
}

///
@safe pure nothrow @nogc unittest
{
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
@safe pure nothrow @nogc unittest
{
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
auto findSplit(T)(scope return inout(T)[] haystack,
                  scope const(T)[] needle)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset; // hit offset
        private size_t _length; // hit length

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] separator() @trusted inout
        {
            return _haystack.ptr[_offset .. _offset + _length];
        }

        inout(T)[] post() @trusted inout
        {
            return _haystack.ptr[_offset + _length .. _haystack.length];
        }

        bool opCast(T : bool)() @safe const
        {
            return _haystack.length != _offset;
        }
    }

    assert(needle.length, "Cannot find occurrence of an empty range");
    const index = haystack.indexOf(needle);
    if (index >= 0)
        return inout(Result)(haystack, index, needle.length);
    return inout(Result)(haystack, haystack.length, 0); // miss
}
/// ditto
auto findSplit(T)(scope return inout(T)[] haystack,
                  scope const T needle)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset; // hit offset

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] separator() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset .. _offset + 1];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset + 1 .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    const index = haystack.indexOf(needle);
    if (index >= 0)
        return inout(Result)(haystack, index);
    return inout(Result)(haystack, haystack.length);
}

///
@safe pure nothrow @nogc unittest
{
    const h = "a**b";
    const r = h.findSplit("**");
    assert(r);
    assert(r.pre is h[0 .. 1]);
    assert(r.separator is h[1 .. 3]);
    assert(r.post is h[3 .. 4]);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplit(" "); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const h = "a**b";
    const r = h.findSplit("_");
    static assert(r.sizeof == 2 * 2 * size_t.sizeof);
    assert(!r);
    assert(r.pre is h);
    assert(r.separator is h[$ .. $]);
    assert(r.post is h[$ .. $]);
}

///
version(none)
@safe pure nothrow @nogc unittest
{
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
@safe pure nothrow @nogc unittest
{
    const r = "a*b".findSplit('*');
    static assert(r.sizeof == 3 * size_t.sizeof);
    assert(r);
    assert(r.pre == "a");
    assert(r.separator == "*");
    assert(r.post == "b");

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplit(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/// DIP-1000 scope analysis
@safe pure nothrow @nogc unittest
{
    char[] f() @safe pure nothrow
    {
        char[3] haystack = "a*b";
        auto r = haystack[].findSplit('*');
        static assert(is(typeof(r.pre()) == char[]));
        return r.pre();         // TODO: this should fail
    }
    f();
}

/** Array-specialization of `findLastSplit` with default predicate.
 */
auto findLastSplit(T)(scope return inout(T)[] haystack,
                      scope const(T)[] needle)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset; // hit offset
        private size_t _length; // hit length

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] separator() @trusted inout
        {
            return _haystack.ptr[_offset .. _offset + _length];
        }

        inout(T)[] post() @trusted inout
        {
            return _haystack.ptr[_offset + _length .. _haystack.length];
        }

        bool opCast(T : bool)() @safe const
        {
            return _haystack.length != _offset;
        }
    }

    assert(needle.length, "Cannot find occurrence of an empty range");
    const index = haystack.lastIndexOf(needle);
    if (index >= 0)
    {
        return inout(Result)(haystack, index, needle.length);
    }
    return inout(Result)(haystack, haystack.length, 0); // miss
}
/// ditto
auto findLastSplit(T)(scope return inout(T)[] haystack,
                  scope const T needle)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset; // hit offset

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] separator() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset .. _offset + 1];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset + 1 .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    const index = haystack.lastIndexOf(needle);
    if (index >= 0)
        return inout(Result)(haystack, index);
    return inout(Result)(haystack, haystack.length);
}

///
@safe pure nothrow @nogc unittest
{
    const h = "a**b**c";
    const r = h.findLastSplit("**");
    assert(r);
    assert(r.pre is h[0 .. 4]);
    assert(r.separator is h[4 .. 6]);
    assert(r.post is h[6 .. 7]);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplit(" "); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const h = "a**b**c";
    const r = h.findLastSplit("_");
    static assert(r.sizeof == 2 * 2 * size_t.sizeof);
    assert(!r);
    assert(r.pre is h);
    assert(r.separator is h[$ .. $]);
    assert(r.post is h[$ .. $]);
}

///
@safe pure nothrow @nogc unittest
{
    const r = "a*b*c".findLastSplit('*');
    static assert(r.sizeof == 3 * size_t.sizeof);
    assert(r);
    assert(r.pre == "a*b");
    assert(r.separator == "*");
    assert(r.post == "c");

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplit(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

/// DIP-1000 scope analysis
@safe pure nothrow @nogc unittest
{
    char[] f() @safe pure nothrow
    {
        char[3] haystack = "a*b";
        auto r = haystack[].findLastSplit('*');
        static assert(is(typeof(r.pre()) == char[]));
        return r.pre();         // TODO: this should fail
    }
    f();
}

/** Array-specialization of `findSplitBefore` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findSplitBefore(T)(scope return inout(T)[] haystack,
                        scope const T needle)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset;

    pragma(inline, true):

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach (const offset, const ref element; haystack)
        if (element == needle)
            return inout(Result)(haystack, offset);
    return inout(Result)(haystack, haystack.length);
}

///
@safe pure nothrow @nogc unittest
{
    char[] haystack;
    auto r = haystack.findSplitBefore('_');
    static assert(is(typeof(r.pre()) == char[]));
    static assert(is(typeof(r.post()) == char[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitBefore(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const(char)[] haystack;
    auto r = haystack.findSplitBefore('_');
    static assert(is(typeof(r.pre()) == const(char)[]));
    static assert(is(typeof(r.post()) == const(char)[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);
}

///
@safe pure nothrow @nogc unittest
{
    const r = "a*b".findSplitBefore('*');
    assert(r);
    assert(r.pre == "a");
    assert(r.post == "*b");
}

///
@safe pure nothrow @nogc unittest
{
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
auto findSplitBefore(alias needlePred, T)(scope return inout(T)[] haystack)
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset;

    pragma(inline, true):

        inout(T)[] pre() @trusted inout
        {
            return _haystack.ptr[0 .. _offset];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[_offset .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    foreach (const offset, const ref element; haystack)
        if (needlePred(element))
            return inout(Result)(haystack, offset);
    return inout(Result)(haystack, haystack.length);
}

///
@safe pure nothrow @nogc unittest
{
    char[] haystack;
    auto r = haystack.findSplitBefore!(_ => _ == '_');
    static assert(is(typeof(r.pre()) == char[]));
    static assert(is(typeof(r.post()) == char[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitBefore!(_ => _ == ' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const(char)[] haystack;
    auto r = haystack.findSplitBefore!(_ => _ == '_');
    static assert(is(typeof(r.pre()) == const(char)[]));
    static assert(is(typeof(r.post()) == const(char)[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);
}

///
@safe pure nothrow @nogc unittest
{
    const r = "a*b".findSplitBefore!(_ => _ == '*');
    assert(r);
    assert(r.pre == "a");
    assert(r.post == "*b");
}

///
@safe pure nothrow @nogc unittest
{
    const r = "a*b".findSplitBefore!(_ => _ == '*' || _ == '+');
    assert(r);
    assert(r.pre == "a");
    assert(r.post == "*b");
}

///
@safe pure nothrow @nogc unittest
{
    const r = "a+b".findSplitBefore!(_ => _ == '*' || _ == '+');
    assert(r);
    assert(r.pre == "a");
    assert(r.post == "+b");
}

///
@safe pure nothrow @nogc unittest
{
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
auto findSplitAfter(T)(scope return inout(T)[] haystack,
                       scope const T needle) @trusted
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset;

    pragma(inline, true):

        inout(T)[] pre() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[0 .. _offset + 1];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[0 .. $];
            return _haystack.ptr[_offset + 1 .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    foreach (const offset, const ref element; haystack)
        if (element == needle)
            return inout(Result)(haystack, offset);
    return inout(Result)(haystack, haystack.length);
}

///
@safe pure nothrow @nogc unittest
{
    char[] haystack;
    auto r = haystack.findSplitAfter('_');
    static assert(is(typeof(r.pre()) == char[]));
    static assert(is(typeof(r.post()) == char[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findSplitAfter(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const(char)[] haystack;
    auto r = haystack.findSplitAfter('_');
    static assert(is(typeof(r.pre()) == const(char)[]));
    static assert(is(typeof(r.post()) == const(char)[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);
}

///
@safe pure nothrow @nogc unittest
{
    auto r = "a*b".findSplitAfter('*');
    static assert(is(typeof(r.pre()) == string));
    static assert(is(typeof(r.post()) == string));
    assert(r);
    assert(r.pre == "a*");
    assert(r.post == "b");
}

/** Array-specialization of `findLastSplitAfter` with default predicate.
 *
 * See_Also: https://forum.dlang.org/post/dhxwgtaubzbmjaqjmnmq@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/zhgajqdhybtbufeiiofp@forum.dlang.org
 */
auto findLastSplitAfter(T)(scope return inout(T)[] haystack,
                           scope const T needle) @trusted
{
    static struct Result // NOTE `static` qualifier is needed for `inout` to propagate correctly
    {
        private T[] _haystack;
        private size_t _offset;

        pragma(inline, true):

        inout(T)[] pre() @trusted inout
        {
            if (empty)
                return _haystack[$ .. $];
            return _haystack.ptr[0 .. _offset + 1];
        }

        inout(T)[] post() @trusted inout
        {
            if (empty)
                return _haystack[0 .. $];
            return _haystack.ptr[_offset + 1 .. _haystack.length];
        }

        bool opCast(T : bool)() const
        {
            return !empty;
        }

        private @property bool empty() const
        {
            return _haystack.length == _offset;
        }
    }

    static if (is(T == char))
        assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
    const index = haystack.lastIndexOf(needle);
    if (index >= 0)
        return inout(Result)(haystack, index);
    return inout(Result)(haystack, haystack.length); // miss
}

///
@safe pure nothrow @nogc unittest
{
    char[] haystack;
    auto r = haystack.findLastSplitAfter('_');
    static assert(is(typeof(r.pre()) == char[]));
    static assert(is(typeof(r.post()) == char[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);

    auto f()() @safe pure nothrow { char[1] x = "_"; return x[].findLastSplitAfter(' '); }
    static if (isDIP1000) static assert(!__traits(compiles, { auto _ = f(); }));
}

///
@safe pure nothrow @nogc unittest
{
    const(char)[] haystack;
    auto r = haystack.findLastSplitAfter('_');
    static assert(is(typeof(r.pre()) == const(char)[]));
    static assert(is(typeof(r.post()) == const(char)[]));
    assert(!r);
    assert(!r.pre);
    assert(!r.post);
}

///
@safe pure nothrow @nogc unittest
{
    auto r = "a*b*c".findLastSplitAfter('*');
    static assert(is(typeof(r.pre()) == string));
    static assert(is(typeof(r.post()) == string));
    assert(r);
    assert(r.pre == "a*b*");
    assert(r.post == "c");
}

version(unittest)
{
    import nxt.dip_traits : isDIP1000;
}

// See_Also: https://dlang.org/spec/betterc.html#unittests
version(unittestAsBetterC)
extern(C) void main()
{
    static foreach (u; __traits(getUnitTests, __traits(parent, main)))
    {
        u();
    }
}
