import std.stdio;

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
}
