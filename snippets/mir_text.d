/++ name
 +/
@safe struct S
{
pure nothrow @nogc:
    @disable this(this);
    this(int x)
    {
        _x = x;
    }
    string toString() const scope
    {
        return "xx";
    }
    private int _x;
}

@safe pure unittest
{
    import mir.format : text;
    assert(text("hello", "world ", 42, S(32)) == "hello world 42");
}
