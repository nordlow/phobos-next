/++ Resuable primitives for compile-time reflection.
	Used to implement design-by-introspection.
 +/
module nxt.reflection;

version (none)
shared static this() {
  // Override the default unit test runner to do nothing. After that, "main" will
  // be called.
  Runtime.moduleUnitTester = { return true; };
}

/// compile-time reflect on all compiled modules
@trusted unittest {
	import nxt.path;
	// See: https://dlang.org/spec/traits.html#getUnitTests
	foreach (test; __traits(getUnitTests, nxt.path)) {
		foreach (attr; __traits(getAttributes, test)) {
			pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", attr);
		}
		// TODO: Call test();
		// test();
		// dbg(msg, __FILE__, "(", __LINE__, ",1): Debug: ", ut);
	}
}

/// run-time reflect on all compiled modules
@trusted unittest {
	foreach (const module_; ModuleInfo) {
		if (module_) {
			// import nxt.debugio;
			// dbg(module_.name);
		}
	}
}

version (unittest) import nxt.debugio;
