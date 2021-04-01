// See_Also: https://forum.dlang.org/post/omfkmlsqamxjtktnaqic@forum.dlang.org
@safe pure unittest
{
	const(char)[] x;
    string y;
    string z1 = x ~ y; // errors
    string z2 = y ~ x; // errors
}
