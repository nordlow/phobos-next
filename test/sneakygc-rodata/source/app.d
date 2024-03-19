/** Sneak into the GC to get the memory segments
 * See_Also: https://pastebin.com/n1vmzKnV
 */
extern (C) __gshared string[] rt_options = ["gcopt=gc:sneakygc"];
extern (C) pragma(crt_constructor) void register_sneakygc()
{
	import core.gc.registry : registerGCFactory;
	registerGCFactory("sneakygc", &initializeSneakyGC);
}

import core.internal.gc.impl.conservative.gc : ConservativeGC;
__gshared ConservativeGC sneakygc;

import core.gc.gcinterface : GC;
private GC initializeSneakyGC() // copied from ConservativeGC
{
	import core.exception : onOutOfMemoryErrorNoGC;
	import core.lifetime : emplace;
	import core.stdc.stdlib : malloc;
	sneakygc = cast(ConservativeGC) malloc(__traits(classInstanceSize, ConservativeGC));
	if (!sneakygc)
		onOutOfMemoryErrorNoGC();
	return emplace(sneakygc);
}

extern (C) void* _d_allocmemory(size_t sz);
shared static this()
{
	cast(void)_d_allocmemory(0); // force initialize GC.
	immutable(void[])[] initInLoop;
	import std.stdio;
	foreach (const range; sneakygc.rangeIter) { // memory segments
		debug writeln("range:", range);
		initInLoop ~= cast(immutable)range.pbot[0 .. range.ptop - range.pbot];
	}
	staticReadOnlyData = initInLoop;
}

__gshared immutable void[][] staticReadOnlyData;

immutable(void)[] isStaticReadOnlyData(scope const(void)[] s) @trusted pure nothrow @nogc
{
	foreach (const seg; staticReadOnlyData)
		if (seg.ptr <= s.ptr &&
			s.ptr + s.length + 1 <= seg.ptr + seg.length)
			return seg;
	return typeof(return).init;
}

void main() {
	__gshared int[4] foo;
	int[4] bar;
	assert( isStaticReadOnlyData(foo[]));
	assert(!isStaticReadOnlyData(bar[]));
}
