@safe pure unittest
{
	import std.traits;

    static assert(!hasAliasing!());

    enum T : int { x, y}
    static assert(!hasAliasing!(T));

    struct S { int* x; }
    static assert(hasAliasing!(S));

    enum Estring : string { x = "a" }
    static assert(!hasAliasing!(Estring));

    enum Ecchar : const(char)[] { x = "a" }
    static assert(hasAliasing!(Ecchar));
}
