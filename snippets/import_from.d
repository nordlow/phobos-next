template from(string moduleName)
{
    mixin("import from = ", moduleName, ';');
}

@safe pure unittest
{
    alias A = from!`std.meta`.AliasSeq;
    A!int x;
}
