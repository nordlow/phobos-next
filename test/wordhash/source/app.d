void main()
{
	import std.stdio;
	import std.datetime : MonoTime;
	import std.algorithm : max;
	import nxt.digest.fnv : FNV;

	import nxt.sso_string : String = SSOString;
	import nxt.container.hybrid_hashmap : HashSet = HybridHashSet;
	import nxt.container.hybrid_hashmap : HashMap = HybridHashMap;
	import nxt.container.dynamic_array : Array = DynamicArray;

	alias Strs = HashSet!(String);

	auto strs = Strs.withCapacity(72800);

	size_t lengthMax = 0;
	immutable before = MonoTime.currTime();
	foreach (line; File("/usr/share/dict/words").byLine) /+ TODO: make const and fix HashSet.insert +/
	{
		import nxt.algorithm.searching : endsWith;
		if (!line.endsWith(`'s`))
		{
			strs.insert(String(line));
			lengthMax = max(lengthMax, line.length);
		}
	}
	immutable after = MonoTime.currTime();

	immutable secs = (after - before).total!"msecs";
	immutable nsecs = (after - before).total!"nsecs";

	immutable n = strs.length;

	writef("Insertion: n:%s lengthMax:%s %1.2smsecs, %3.1fnsecs/op\n",
		   n,
		   lengthMax,
		   secs,
		   cast(double)nsecs / n);

}
