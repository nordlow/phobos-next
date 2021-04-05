import std.stdio;
import std.traits : hasAliasing;

// See_Also: https://forum.dlang.org/post/omfkmlsqamxjtktnaqic@forum.dlang.org
@safe unittest
{
	const(char)[] x = "hello ";
    string y = "world";

    string z1 = x ~ y; // will pass
    assert(z1 == "hello world");

    string z2 = y ~ x; // will pass
    assert(z2 == "hello world");

    writeln(z1);
    writeln(z2);

    char[2] a, b;
    char[] _ = a;
    immutable char[4] c = a ~ b;
}

struct S { immutable(T)* t; }
struct T { immutable(S)* s; }

@safe pure unittest
{
    immutable(S)[] a;
    const(S)[] b;
    auto c = a ~ b;
}
