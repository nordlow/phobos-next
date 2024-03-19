module register_segregated_gc;

// See_Also: https://dlang.org/spec/garbage.html#gc_registry

import core.gc.gcinterface, core.gc.registry;
import segregated_gc;

extern (C) pragma(crt_constructor) void registerSegregatedGC()
{
	registerGCFactory("segregated", &createSegregatedGC);
}

GC createSegregatedGC()
{
	__gshared instance = new SegregatedGC;
	instance.initialize();
	return instance;
}

version (segregated_gc)
{
/* The new GC is added to the list of available garbage collectors that can be
 * selected via the usual configuration options, e.g. by embedding rt_options
 * into the binary:
 */
	extern (C) __gshared string[] rt_options = ["gcopt=gc:segregated"];
}
