/** Extensions to std.parallelism.
*/

module nxt.parallelism_ex;

/** See_Also: http://forum.dlang.org/thread/irlkdkrgrnadgsgkvcjt@forum.dlang.org#post-vxbhxqgfhuwytdqkripq:40forum.dlang.org
 */
private auto pmap(alias fun, R)(R range) if(isInputRange!R)
{
	import std.parallelism;
	import core.sync.mutex;

	static __gshared Mutex mutex;
	if (mutex is null) mutex = new Mutex;

	typeof (fun(range.front))[] values;

	foreach (i, value; range.parallel)
	{
		auto newValue = fun(value);
		synchronized (mutex)
		{
			if (values.length < i + 1) values.length = i + 1;
			values[i] = newValue;
		}
	}

	return values;
}
