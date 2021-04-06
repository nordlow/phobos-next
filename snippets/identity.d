// See_Also: https://forum.dlang.org/post/uhwjlhxojafhahby// yoms@forum.dlang.org

auto ref T identity(T)(auto ref T arg)
{
    return arg;
}

auto ref T identity_fwd(T)(auto ref T arg)
{
    import core.lifetime : forward;
    return forward!arg;
}

@safe pure unittest
{

}
