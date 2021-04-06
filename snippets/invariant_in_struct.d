struct S
{
    int * _handle;
    invariant
    {
        assert(_handle !is null);
        pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", typeof(_handle));
    }
}

@safe pure unittest
{
    S s;
}
