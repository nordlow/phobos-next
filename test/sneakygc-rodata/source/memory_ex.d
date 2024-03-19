/** Extensions to core.memory.
 * See_Also: sneakygc_main.d
 */
module memory_ex;

immutable(void)[] isStaticReadOnlyData(scope const(void)[] s) @trusted pure nothrow @nogc {
	/+ TODO: maybe use binary search of `staticReadOnlyData` +/
	foreach (const seg; staticReadOnlyData[0 .. staticReadOnlyData_count])
		if (seg.ptr <= s.ptr &&
			s.ptr + s.length + 1 <= seg.ptr + seg.length)
			return seg;
	return typeof(return).init;
}

private static immutable staticRO42 = "42";

///
pure nothrow @safe @nogc unittest {
	char[2] stack42 = staticRO42;
	assert(!stack42.isStaticReadOnlyData);
	assert(staticRO42.isStaticReadOnlyData);
	assert("42".isStaticReadOnlyData);
}

///
pure nothrow @safe unittest {
	char[] gc42 = new char[2];
	assert(!gc42.isStaticReadOnlyData);
}

///
@system pure nothrow @nogc unittest {
	import core.memory : pureMalloc, pureFree;
	void[] buf = (cast(void*)pureMalloc(1))[0 .. 1];
	assert(!buf.isStaticReadOnlyData);
	scope(exit) () @trusted { pureFree(buf.ptr); } ();
}

private enum staticReadOnlyData_MaxCount = 128;
/** Array of memory regions where static read only data is stored. */
__gshared private static immutable(void[])[staticReadOnlyData_MaxCount] staticReadOnlyData;
private static immutable uint staticReadOnlyData_count;

shared static this() @system nothrow /* TODO: @nogc */ {
	version (linux) {
		import core.sys.posix.fcntl : open, mode_t, O_RDONLY, O_CLOEXEC;
		import core.sys.posix.unistd : read, ssize_t;
		import core.memory : pureMalloc, pureFree;
		import nxt.algorithm.searching : findSplit;

		// See: https://stackoverflow.com/a/1401595/683710 for explanation on "/proc/self/maps".
		immutable path = "/proc/self/maps";
		const fd = open(path.ptr, O_RDONLY|O_CLOEXEC);
		if (fd == -1)
			return;				/+ TODO: signal error +/

		const bufSize = 64*1024; /+ TODO: set to size of `path` +/
		void[] buf = pureMalloc(bufSize)[0 .. bufSize];
		scope(exit) () @trusted { pureFree(buf.ptr); } ();

		const bytesRead = read(fd, buf.ptr, bufSize); /+ TODO: use File.byLine instead? +/
		if (bytesRead == -1)
			return;				/+ TODO: signal error +/

		string maps = cast(string)buf[0 .. bytesRead];
		uint i = 0;
		while (true) {
			if (const split = maps.findSplit('\n')) {
				if (split.pre[26 .. 30] == "r--p")  {
					try {
						import std.conv : parse;
						const beg = split.pre[0 ..		 12].parse!size_t(16);
						const end = split.pre[13 .. + 13 + 12].parse!size_t(16);
						const seg = (cast(immutable(void)*)(beg))[0 .. end-beg]; // ok to append to immutable in module constructor
						staticReadOnlyData[i] = seg;
						i += 1;
					} catch (Exception e) {}
				}
				maps = split.post;
			} else
				break;
		}
		staticReadOnlyData_count = i;
	}
}

immutable(char)* toStringz(return scope const(char)[] s) @trusted pure nothrow {
	if (s.isStaticReadOnlyData &&
		s.ptr[s.length] == '\0') // range checking forbids s[$] here
		return cast(typeof(return))s.ptr;
	import std.string : toStringz;
	return s.toStringz;
}

///
@system pure unittest {
	import core.stdc.string : strlen;
	string s = "Hello world";
	assert(s[0 .. 5].toStringz().strlen() == 5);
}
