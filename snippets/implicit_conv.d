@safe unittest
{
    import std.algorithm.iteration : map;
    import std.stdio;

    struct S { int x; }
    static void f(S s) @safe pure
    {
    }
    const s = S();              // this works
    f(s);
    auto x = [1, 2];

    const y = x.map!("a*a");

    foreach (e; y)              // should be allowed
    {
    }

    writeln(y);
}
