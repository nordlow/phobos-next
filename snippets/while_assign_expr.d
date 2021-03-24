@safe unittest
{
    import std.stdio;
    size_t i = 0;
	while (const _ = i++ != 10)
        writeln(_);
}
