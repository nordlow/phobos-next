@safe unittest
{
	import std.algorithm.iteration : map;
    import std.stdio;
    auto x = [1, 2];
    auto y = x.map!(_ => _*_);
    writeln(y);
}
