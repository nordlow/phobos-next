// See_Also: https://forum.dlang.org/post/uhwjlhxojafhahby// yoms@forum.dlang.org

@safe:

auto ref T identity(T)(auto ref T arg) @trusted
{
    return arg;                 // fails because the compiler cannot do move here
}

auto ref T identity_fwd(T)(auto ref T arg) @trusted
{
    import core.lifetime : forward;
    return forward!arg;
}

@safe pure unittest
{
    struct S
    {
        @disable this(this);
    }
    const _ = identity_fwd(S.init);
    // const _ = identity(S.init);
}
