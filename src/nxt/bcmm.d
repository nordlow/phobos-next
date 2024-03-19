/** Memory management in better C.
 *
 * See_Also: https://lsferreira.net/posts/zet-1-classes-betterc-d/
 */
module nxt.bcmm;

T alloc(T, Args...)(auto ref Args args) {
	enum tsize = __traits(classInstanceSize, T);
	T t = () @trusted {
		import core.memory : pureMalloc;
		auto _t = cast(T)pureMalloc(tsize);
		if (!_t) return null;
		import core.stdc.string : memcpy;
		memcpy(cast(void*)_t, __traits(initSymbol, T).ptr, tsize);
		return _t;
	} ();
	if(!t) return null;
	t.__ctor(args);

	return t;
}

void destroy(T)(ref T t) {
	static if (__traits(hasMember, T, "__dtor"))
		t.__dtor();
	() @trusted {
		import core.memory : pureFree;
		pureFree(cast(void*)t);
	}();
	t = null;
}

version (unittest) {
	extern(C++) class Foo
	{
		this(int a, float b) {
			this.a = a * 2;
			this.b = b;
		}
		int a;
		float b;
		bool c = true;
	}

	extern(C) int test() {
		Foo foo = alloc!Foo(2, 2.0f);
		scope(exit) destroy(foo);

		int a = foo.a;   // 4
		float b = foo.b; // 2.0
		bool c = foo.c;  // true

		return 0;
	}
}
