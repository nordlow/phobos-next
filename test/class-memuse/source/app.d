/** Test memory usage and performance of struct and class construction.
 * https://dlang.org/spec/cpp_interface.html
 */

import std.stdio : write, writeln, writef, writefln;
import std.datetime : MonoTime;

void main(string[] args) {
	import std.experimental.allocator : theAllocator, make;
	import nxt.container.dynamic_array : DynamicArray;
	import std.array : Appender;

	const n = 2_000_000;

	{
		DynamicArray!(NodeCxxStruct) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(NodeCxxStruct(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof, before, after, n);
	}

	{
		DynamicArray!(NodeCxxClass) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(new NodeCxxClass(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof, before, after, n);
	}

	{
		DynamicArray!(NodeCxxClass) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(theAllocator.make!NodeCxxClass(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof ~ ".make", before, after, n);
	}

	version (none) 				/+ TODO: enable or remove as this causes segfault with LDC ASan +/
	{
		Appender!(NodeCxxStruct[]) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(NodeCxxStruct(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof, before, after, n);
	}

	{
		Appender!(NodeCxxClass[]) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(new NodeCxxClass(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof, before, after, n);
	}

	{
		Appender!(NodeCxxClass[]) x;
		x.reserve(n);
		const before = MonoTime.currTime();
		foreach (const _; 0 .. n)
			x.put(theAllocator.make!NodeCxxClass(42));
		const after = MonoTime.currTime();
		showStat(typeof(x).stringof ~ ".make", before, after, n);
	}
}

struct NodeCxxStruct {
	this(ulong type) { this.type = type; }
	ulong type;
}

extern(C++) class NodeCxxClass {
	this(ulong type) { this.type = type; }
	ulong type;
}

/// Show statistics.
void showStat(T)(const(char[]) typeName, in T before, in T after, in size_t n) {
	writefln(
			 "%6.1f msecs (%6.1f nsecs/op): %s",
			 cast(double) (after - before).total!"msecs",
			 cast(double) (after - before).total!"nsecs" / n,
			 typeName,
	);
}
