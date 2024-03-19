/*
  A tiny hack to redirect all GC allocations to a fixed size arena.

  Say, you've got an operation that actively allocates in GC'ed heap but
  after it's complete you don't need anything it allocated. And you need
  to do it in a loop many times, potentially allocating lots of memory.
  Just add one line in the beginning of loop's scope and each iteration
  will reuse the same fixed size buffer.
  Like this:

  foreach(fname; files) {
	auto ar = useCleanArena();	 // (1)
	auto img = readPng(fname).getAsTrueColorImage();
	process(img);
	// (2)
  }

  Between points (1) and (2) all GC allocations will happen inside
  an arena which will be reused on each iteration. No GC will happen,
  no garbage accumulated.

  If you need some data created inbetween, you can temporarily pause
  using the arena and allocate something on main GC heap:

	void testArena() {
		auto ar = useCleanArena();
		auto s = new ubyte[100]; // allocated in arena
		{
			auto pause = pauseArena();  // in this scope it's not used
			auto t = new ubyte[200];	// allocated in main GC heap
		}
		auto v = new ubyte[300];   // allocated in arena again
		writeln("hi");
		// end of scope, stop using arena
	}

  You can set size for arena by calling setArenaSize() before its first use.
  Default size is 64 MB.

*/
module gcarena;
import std.stdio, core.memory, core.exception;

void setArenaSize(size_t totalSize) {
	gcaData.arena_size = totalSize;
}

struct ArenaHandler {
	this(this) @disable;
	~this() @nogc { stop(); }

	void stop() @nogc {
		if (stopped) return;
		gcaData.clearProxy();
		stopped = true;
	}

	size_t allocated() { return gcaData.arena_pos; }

	private bool stopped = false;
}

auto useCleanArena() {
	gcaData.arena_pos = 0;
	gcaData.installProxy();
	return ArenaHandler();
}

auto pauseArena() {
	gcaData.clearProxy();
	struct ArenaPause {
		~this() @nogc { gcaData.installProxy(); }
		this(this) @disable;
	}
	return ArenaPause();
}

private: //////////////////////////////////////////////////////////////
alias BlkInfo = GC.BlkInfo;

struct Proxy // copied from proxy.d (d runtime)
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

struct GCAData {
	Proxy myProxy;
	Proxy *pOrg; // pointer to original Proxy of runtime
	Proxy** pproxy;

	ubyte[] arena_bytes;
	size_t arena_pos = 0;
	size_t arena_size = 64*1024*1024;

	void initProxy() {
		pOrg = gc_getProxy();
		pproxy = cast(Proxy**) (cast(byte*)pOrg + Proxy.sizeof);
		foreach(funname; __traits(allMembers, Proxy))
			__traits(getMember, myProxy, funname) = &genCall!funname;
		myProxy.gc_malloc = &gca_malloc;
		myProxy.gc_qalloc = &gca_qalloc;
		myProxy.gc_calloc = &gca_calloc;
	}

	void* alloc(size_t size) {
		if (arena_bytes.length==0) {
			auto oldproxy = *pproxy;
			*pproxy = null;
			arena_bytes = new ubyte[arena_size];
			*pproxy = oldproxy;
		}

		if (arena_pos + size > arena_bytes.length) {
			writeln("Arena too small! arena=", arena_bytes.length, " asked for ", size, " need ", arena_pos + size);
			onOutOfMemoryError();
		}
		auto pos = arena_pos;
		arena_pos += size;
		arena_pos = (arena_pos + 15) & ~15;
		return &arena_bytes[pos];
	}

	void clearArena() {
		writeln("clearArena: allocated ", arena_pos);
		arena_pos = 0;
	}

	void installProxy() @nogc {
		// writeln("using arena now");
		*pproxy = &myProxy;
	}

	void clearProxy() @nogc {
		// writeln("using GC now");
		*pproxy = null;
	}
}

extern(C) {
	Proxy* gc_getProxy();

	auto genCall(string funname)(FunArgsTypes!funname args) {
		*gcaData.pproxy = null;
		scope(exit) *gcaData.pproxy = &gcaData.myProxy;
		return __traits(getMember, *gcaData.pOrg, funname)(args);
	}

	void* gca_malloc(size_t sz, uint ba, const TypeInfo ti) {
		//writeln("gca_malloc ", sz);
		return gcaData.alloc(sz);
	}

	BlkInfo gca_qalloc(size_t sz, uint ba, const TypeInfo ti) {
		//writeln("gca_qalloc ", sz);
		auto pos0 = gcaData.arena_pos;
		BlkInfo b;
		b.base = gcaData.alloc(sz);
		b.size = gcaData.arena_pos - pos0;
		b.attr = ba;
		return b;
	}

	void* gca_calloc(size_t sz, uint ba, const TypeInfo ti) {
		import core.stdc.string : memset;
		//writeln("gca_calloc ", sz);
		void* p = gcaData.alloc(sz);
		memset(p, 0, sz);
		return p;
	}
}

template FunArgsTypes(string funname) {
	alias FunType = typeof(*__traits(getMember, gcaData.myProxy, funname));
	alias FunArgsTypes = ParameterTypeTuple!FunType;
}

GCAData gcaData; // thread local

static this() {
	gcaData.initProxy();
}
