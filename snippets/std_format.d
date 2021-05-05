void testStdFormatFormat()
{
    import std.format : format;
    assert(format("%s %s %d", "hello", "world", 42) == "hello world 42");
}
