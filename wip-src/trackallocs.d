/*
  A tiny hack to install a GC proxy and track all allocations, gathering some
  stats and logging to given File (or stdout, by default).

  Use it like this:
  void myCode() {
	auto tracker = allocsTracker();
	... // do some work
		// while `tracker` is alive all allocations will be shown
  }

  Alternatively use pair of functions
	startTrackingAllocs() and stopTrackingAllocs().

*/

module trackallocs;
import std.stdio, core.memory, core.stdc.string, std.traits, std.range, std.algorithm;

//stats
__gshared ulong allocs_mc = 0; // numbers of calls for malloc, qalloc and calloc
__gshared ulong allocs_qc = 0;
__gshared ulong allocs_cc = 0;
__gshared ulong allocs_msz = 0; // total numbers of bytes requested
__gshared ulong allocs_qsz = 0;
__gshared ulong allocs_csz = 0;

void clearAllocStats() {
	allocs_mc = 0;  allocs_qc = 0;  allocs_cc = 0;
	allocs_msz = 0; allocs_qsz = 0; allocs_csz = 0;
}

void startTrackingAllocs(File logFile = stdout) {
	allocs_file = logFile;
	if (myProxy.gc_calloc is null) {
		initGcProxy();
		myProxy.gc_malloc = &genAlloc!("m");
		myProxy.gc_qalloc = &genAlloc!("q");
		myProxy.gc_calloc = &genAlloc!("c");
	}
	*pproxy = &myProxy;
	logFile.writeln("allocs tracking started");
}

void stopTrackingAllocs() {
	*pproxy = null;
	allocs_file.writeln("allocs tracking ended");
}

auto allocsTracker(File logFile = stdout) // RAII version: starts tracking now, ends it when returned value dies
{
	struct S {
		~this() nothrow { stopTrackingAllocs();	}
		this(this) @disable;
	}
	startTrackingAllocs(logFile);
	return S();
}

private: //////////////////////////////////////////////////////////////////////
alias BlkInfo = GC.BlkInfo;

struct Proxy // taken from proxy.d (d runtime)
{
	extern (C)
	{
		void function() gc_enable;
		void function() gc_disable;
		void function() gc_collect;
		void function() gc_minimize;

		uint function(void*) gc_getAttr;
		uint function(void*, uint) gc_setAttr;
		uint function(void*, uint) gc_clrAttr;

		void*   function(size_t, uint, const TypeInfo) gc_malloc;
		BlkInfo function(size_t, uint, const TypeInfo) gc_qalloc;
		void*   function(size_t, uint, const TypeInfo) gc_calloc;
		void*   function(void*, size_t, uint ba, const TypeInfo) gc_realloc;
		size_t  function(void*, size_t, size_t, const TypeInfo) gc_extend;
		size_t  function(size_t) gc_reserve;
		void	function(void*) gc_free;

		void*   function(void*) gc_addrOf;
		size_t  function(void*) gc_sizeOf;

		BlkInfo function(void*) gc_query;

		void function(void*) gc_addRoot;
		void function(void*, size_t, const TypeInfo) gc_addRange;

		void function(void*) gc_removeRoot;
		void function(void*) gc_removeRange;
		void function(in void[]) gc_runFinalizers;
	}
}

__gshared Proxy myProxy;
__gshared Proxy *pOrg; // pointer to original Proxy of runtime
__gshared Proxy** pproxy; // should point to proxy var in runtime (proxy.d)
__gshared File allocs_file; // where to write messages

template FunArgsTypes(string funname) {
	alias FunType = typeof(*__traits(getMember, myProxy, funname));
	alias FunArgsTypes = ParameterTypeTuple!FunType;
}

extern(C) {
	Proxy* gc_getProxy();

	auto genCall(string funname)(FunArgsTypes!funname args) {
		*pproxy = null;
		scope(exit) *pproxy = &myProxy;
		return __traits(getMember, pOrg, funname)(args);
	}

	auto genAlloc(string letter)(size_t sz, uint ba, const TypeInfo ti) {
		*pproxy = null;
		scope(exit) *pproxy = &myProxy;

		mixin("alias cc = allocs_" ~ letter ~ "c;");
		mixin("alias asz = allocs_" ~ letter ~ "sz;");
		allocs_file.writefln("gc_"~letter~"alloc(%d, %d) :%d %s", sz, ba, cc, ti is null ? "" : ti.toString());
		asz += sz; cc++;
		return __traits(getMember, pOrg, "gc_"~letter~"alloc")(sz, ba, ti);
	}

	auto genNop(string funname)(FunArgsTypes!funname args) { }
}

void initGcProxy() {
	pOrg = gc_getProxy();
	pproxy = cast(Proxy**) (cast(byte*)pOrg + Proxy.sizeof);
	foreach(funname; __traits(allMembers, Proxy))
		__traits(getMember, myProxy, funname) = &genCall!funname;
}


version (unittest) {
	extern(C) {
		void gc_setProxy( Proxy* p );
		void gc_clrProxy();
	}
}

unittest {
	//make sure our way to get pproxy works
	initGcProxy();
	myProxy.gc_addRoot = &genNop!"gc_addRoot";
	myProxy.gc_addRange = &genNop!"gc_addRange";
	myProxy.gc_removeRoot = &genNop!"gc_removeRoot";
	myProxy.gc_removeRange = &genNop!"gc_removeRange";
	assert(*pproxy == null);
	gc_setProxy(&myProxy);
	assert(*pproxy == &myProxy);
	gc_clrProxy();
	assert(*pproxy == null);
	writeln("pproxy test OK");
	memset(&myProxy, 0, Proxy.sizeof);
}

unittest {
	clearAllocStats();
	scope atr = allocsTracker();
	assert(allocs_qsz == 0 && allocs_qc == 0);
	scope arr = new int[32];
	assert(allocs_qsz == 129 && allocs_qc == 1);
	writeln("allocsTracker() and new int[] test OK");
}

unittest {
	clearAllocStats();
	startTrackingAllocs(stderr);
	assert(allocs_qsz == 0 && allocs_qc == 0);
	scope arr = new int[32];
	assert(allocs_qsz == 129 && allocs_qc == 1);
	stopTrackingAllocs();

	scope arr2 = new int[42];
	assert(allocs_qsz == 129 && allocs_qc == 1);

	startTrackingAllocs(stderr);
	scope arr3 = new byte[10];
	assert(allocs_qsz != 129 && allocs_qc != 1);
	stopTrackingAllocs();

	writeln("startTrackingAllocs() and new int[] test OK");
}
