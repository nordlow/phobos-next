template from(string module_)
{
    mixin("import from = ", module_, ';');
}

@safe pure unittest
{
    alias A = from!`std.meta`.AliasSeq;
    A!int x;
}
