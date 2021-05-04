@safe pure unittest
{
    import mir.conv : to;
    import mir.small_string : SmallString;
    alias S = SmallString!32;

    // Floating-point numbers are formatted to the shortest precise exponential notation.
    assert(123.0.to!S == "123.0");
    assert(123.to!(immutable S) == "123");
    assert(true.to!S == "true");
    assert(true.to!string == "true");
    assert((cast(S)"str")[] == "str");
}
