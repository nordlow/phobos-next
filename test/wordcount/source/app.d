void main()
{
	import std.stdio;
	import std.datetime : MonoTime;

	size_t count = 0;

	immutable before = MonoTime.currTime();

	foreach (line; File("/usr/share/dict/words").byLine) /+ TODO: make const and fix HashSet.insert +/
	{
		count += 1;
	}

	immutable after = MonoTime.currTime();
	const dur = (after - before);

	writef("Count lines: count:%d dur:%1.2smsecs, %3.1fnsecs/op\n",
		   count,
		   dur.total!"msecs",
		   cast(double)dur.total!"nsecs" / count);

}
