module nxt.appending;

/** Append arguments `args` to `data`.
 *
 * See_Also: http://forum.dlang.org/thread/mevnosveagdiswkxtbrv@forum.dlang.org?page=1
 */
ref R append(R, Args...)(return ref R data,
						 auto ref Args args)
if (args.length != 0) {
	import std.range.primitives : ElementType, isRandomAccessRange, isInputRange;

	alias E = ElementType!R;

	import std.traits : isAssignable;
	enum isScalarAssignable(U) = isAssignable!(E, U);

	import std.meta : allSatisfy;

	static if (args.length == 1) {
		data ~= args[0];
	}
	else static if (isRandomAccessRange!R && /+ TODO: generalize to is(typeof(data.length += 0)) +/
					allSatisfy!(isScalarAssignable, Args)) {
		data.length += args.length;
		foreach (i, arg; args)
			data[$ - args.length + i] = arg;
	}
	else						/+ TODO: only when all `args' has length +/
	{
		/// Returns: sum of lengths of `args`.
		static size_t totalLength(scope Args args) {
			import std.traits : isArray;
			import std.range.primitives : hasLength;
			size_t result;
			foreach (i, arg; args) {
				alias Arg = typeof(arg);
				static if (isScalarAssignable!Arg)
					result += 1;
				else static if (isArray!Arg && /+ TODO: generalize to hasIndexing +/
								is(E == ElementType!Arg) &&
								hasLength!Arg)
					result += arg.length;
				else static if (isInputRange!Arg &&
								hasLength!Arg &&
								isAssignable!(E, ElementType!Arg))
					result += arg.length;
				else
					static assert(0, i.stringof ~ ": cannot append arg of type " ~ Arg.stringof ~ " to " ~ R.stringof ~ " " ~ isScalarAssignable!Arg.stringof);
			}
			return result;
		}

		/+ TODO: add case for when data += length +/

		import std.range: appender;
		auto app = appender!(R)(data);

		app.reserve(data.length + totalLength(args));

		foreach (arg; args)
			app.put(arg);

		data = app.data;
	}

	return data;
}

///
pure nothrow @safe unittest {
	int[] data;
	import std.range: only, iota;

	data.append(-1, 0, only(1, 2, 3), iota(4, 9));
	assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8]);

	data.append(9, 10);
	assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

	data.append([11, 12], [13, 14]);
	assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);

	// int[3] d;
	// data.append(d, d);

	static assert(!__traits(compiles, { data.append(); }));
}
