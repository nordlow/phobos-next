/** Detect DIP-support given as compiler flags starting with `-dip`.
 */
module nxt.dip_traits;

/** Is `true` iff DIP-1000 checking is enabled via compiler flag -dip1000.
 *
 * See_Also: https://forum.dlang.org/post/qglynupcootocnnnpmhj@forum.dlang.org
 * See_Also: https://forum.dlang.org/post/pzddsrwhfvcopfaamvak@forum.dlang.org
 */
enum hasPreviewDIP1000 = __traits(compiles, () @safe { int x; int* p; p = &x; });

/** Is `true` iff bitfields is enabled via compiler flag `-preview=bitfields`.
 *
 * Use mixin to make parsing lazy.
 */
enum hasPreviewBitfields = __VERSION__ >= 2100 && __traits(compiles, { mixin("struct S { int x:2; }"); } );

version (unittest) {
static if (hasPreviewBitfields) {
	struct S(T) {
		mixin("T x:2;");
		mixin("T y:2;");
		mixin("T z:2;");
		mixin("T w:2;");
	}
	static assert(S!(ubyte).sizeof == 1);
	static assert(S!(ushort).sizeof == 2);
	static assert(S!(uint).sizeof == 4);
	static assert(S!(ulong).sizeof == 8);
}
}
