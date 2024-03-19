/** Algorithms that either improve or complement std.algorithm`.
 *
 * Functions are when possible `pure nothrow @safe @nogc`.
 * Haystack parameter is when possible and relevant `scope return inout(T)[]` and DIP-1000-compliant.
 * Needle parameter is either `scope const(T)[]` or `T[]`.
 *
 * Provides more than twice as fast compilation for `char`-arrays (`string`s).
 *
 * See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
 * See_Also: https://forum.dlang.org/thread/ybamybeakxwxwleebnwb@forum.dlang.org?page=1
 *
 * TODO: Merge into separate array-specializations of Phobos algorithms for less template bloat in Phobos.
 */
module nxt.algorithm;

public import nxt.algorithm.searching;
public import nxt.algorithm.comparison;
public import nxt.algorithm.sortn;
