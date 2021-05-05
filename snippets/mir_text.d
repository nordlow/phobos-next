void testMirFormatText()
{
    import mir.format : text;
    assert(text("hello", " world ", 42) == "hello world 42");
}
