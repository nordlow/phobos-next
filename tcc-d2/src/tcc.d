/++ Idiomatic D API for libtcc.h
	See: https://briancallahan.net/blog/20220406.html

	TODO: Wrap newly added `tcc_set_realloc` if available. Availability might be
	checkable via a trait on ImportC declarations.
	TODO: Wrap newly added `tcc_setjmp`. `tcc_set_backtrace_func`.
 +/
module tcc;

import nxt.path : FilePath, DirPath;

@safe:

/++ Tiny C Compiler (TCC).
	See: https://briancallahan.net/blog/20220406.html
 +/
struct TCC {
	import std.string : toStringz;
	import deimos.libtcc;

	/++ Output type.
	 +/
	enum OutputType {
		memory = TCC_OUTPUT_MEMORY, /** Output will be run const memory (default) */
		exe = TCC_OUTPUT_EXE, /** Executable file */
		dll = TCC_OUTPUT_DLL, /** Dynamic library */
		obj = TCC_OUTPUT_OBJ, /** Object file */
		preprocess = TCC_OUTPUT_PREPROCESS, /** Only preprocess (used internally) */
	}

	// Disable copying for now until I've figured out the preferred behavior.
	this(this) @disable;

	/** Make sure `_state` is initialized. */
	private void assertInitialized() @trusted pure nothrow @nogc {
		if (_state is null)
			_state = tcc_new();
	}

	~this() @trusted pure nothrow @nogc {
		if (_state !is null) {
			tcc_delete(_state);
			_state = null;
		}
	}

	/** Set CONFIG_TCCDIR at runtime. */
	void setLibraryPath(in char[] path) pure scope @trusted {
		assertInitialized();
		return tcc_set_lib_path(_state, path.toStringz);
	}
	/// ditto
	void setLibraryPath(in DirPath path) pure scope => setLibraryPath(path.str);

	alias ErrorFunc = extern(C) void function(void* opaque, const char* msg);

	/** Set error/warning display callback. */
	void setErrorFunction(void* error_opaque, ErrorFunc error_func) pure scope @trusted @nogc {
		assertInitialized();
		return tcc_set_error_func(_state, error_opaque, error_func);
	}

	/** Set options `opts` as from command line (multiple supported).
		Important options are `"-bt"` `"-b"`.
	 */
	int setOptions(in char[] opts) pure scope @trusted {
		assertInitialized();
		return tcc_set_options(_state, opts.toStringz);
	}

	/*****************************/
	/** Preprocessor. */

	/** Add include path `pathname`. */
	int addIncludePath(in char[] pathname) pure scope @trusted {
		assertInitialized();
		return tcc_add_include_path(_state, pathname.toStringz);
	}
	/// ditto
	int addIncludePath(in DirPath path) pure scope => addIncludePath(path.str);

	/** Add system include path `pathname`. */
	int addSystemIncludePath(in char[] pathname) pure scope @trusted {
		assertInitialized();
		return tcc_add_sysinclude_path(_state, pathname.toStringz);
	}
	/// ditto
	int addSystemIncludePath(in DirPath path) pure scope => addSystemIncludePath(path.str);

	/** Define preprocessor symbol named `sym`. Can put optional value. */
	void defineSymbol(in char[] sym, in char[] value) pure scope @trusted {
		assertInitialized();
		return tcc_define_symbol(_state, sym.toStringz, value.toStringz);
	}

	/** Undefine preprocess symbol named `sym`. */
	void undefineSymbol(in char[] sym) pure scope @trusted {
		assertInitialized();
		return tcc_undefine_symbol(_state, sym.toStringz);
	}

	/*****************************/
	/** Compiling. */

	/** Add a file (C file, dll, object, library, ld script).
		Return -1 if error.
	 */
	int addFile(in char[] filename) pure scope @trusted {
		assertInitialized();
		return tcc_add_file(_state, filename.toStringz);
	}
	/// ditto
	int addFile(in FilePath path) pure scope => addFile(path.str);

	/** Compile `source` containing a C source.
		Return -1 if error.
	 */
	int compile(in char[] source) pure scope @trusted {
		assertInitialized();
		/+ TODO: avoid `toStringz` when possible +/
		return tcc_compile_string(_state, source.toStringz);
	}

	/*****************************/
	/** Linking commands. */

	/** Set output type. MUST BE CALLED before any compilation. */
	int setOutputType(in OutputType output_type) pure scope @trusted @nogc {
		assertInitialized();
		return tcc_set_output_type(_state, output_type);
	}

	/** Equivalent to -Lpath option. */
	int addLibraryPath(in char[] pathname) pure scope @trusted {
		assertInitialized();
		return tcc_add_library_path(_state, pathname.toStringz);
	}
	int addLibraryPath(in DirPath path) pure scope => addLibraryPath(path.str);

	/** The library name is the same as the argument of the '-l' option. */
	int addLibrary(in char[] libraryname) pure scope @trusted {
		assertInitialized();
		return tcc_add_library(_state, libraryname.toStringz);
	}

	/** Add a symbol to the compiled program. */
	int addSymbol(in char[] name, const void* val) pure scope @trusted {
		assertInitialized();
		return tcc_add_symbol(_state, name.toStringz, val);
	}

	/** Output an executable, library or object file.
		DO NOT call `relocate()` before.
	 */
	int outputFile(in char[] filename) scope @trusted {
		assertInitialized();
		return tcc_output_file(_state, filename.toStringz);
	}
	/// ditto
	int outputFile(in FilePath filename) scope @trusted {
		assertInitialized();
		return tcc_output_file(_state, filename.str.toStringz);
	}

	/** Link and run `main()` function and return its value.
		DO NOT call `relocate()` before.
	 */
	int run(int argc, char** argv) scope @trusted @nogc {
		assertInitialized();
		return tcc_run(_state, argc, argv);
	}

	/** Evaluate (Compile, link and run) `source` by running its `main()` and returning its value.
		DO NOT call `relocate()` before.
	 */
	int eval(in char[] source, int argc, char** argv) scope @trusted {
		typeof(return) ret;
		ret = setOutputType(TCC.OutputType.exe);
		if (ret != 0)
			return ret;
		ret = compile(source);
		if (ret != 0)
			return ret;
		return run(argc, argv);
	}
	alias compileAndRun = eval;

	/** Do all relocations (needed before using `get_symbol()`) */
	int relocate(void* ptr);	// TOOD: define

	/** Possible values for 'ptr':
		- RELOCATE_AUTO : Allocate and manage memory internally
		- NULL			  : return required memory size for the step below
		- memory address	: copy code to memory passed by the caller
	  Returns -1 if error.
	 */
	enum RELOCATE_AUTO = cast(void*) 1;

	/** Return value of symbol named `name` or `null` if not found. */
	void* getSymbolMaybe(in char[] name) pure scope @trusted {
		assertInitialized();
		return tcc_get_symbol(_state, name.toStringz);
	}

	TCCState* _state;
}

///
pure @safe unittest {
	TCC tcc;
	assert(tcc.compile(`int f(int x) { return x; }`) == 0);
}

///
pure @safe unittest {
	TCC tcc;
	static extern(C) void error_func_ignore(void* opaque, const char* msg) {}
	tcc.setErrorFunction((void*).init, &error_func_ignore);
	assert(tcc.compile(`int f(int x) { return; }`) == 0); /+ TODO: check warning output +/
	assert(tcc.compile(`int f(int x) { return }`) == -1); /+ TODO: check error output +/
}

/// Compile main().
pure @safe unittest {
	TCC tcc;
	assert(tcc.compile(`int main(int argc, char** argv) { return 0; }`) == 0);
}

/// Run main().
@safe unittest {
	version (linux) {
		TCC tcc;
		tcc.setOutputType(TCC.OutputType.exe);
		const src = `int main(int argc, char** argv) { return 42; }`;
		assert(tcc.eval(src, 0, null) == 42);
	}
}

/// Use stdio.h.
@safe unittest {
	version (linux) {
		TCC tcc;
		tcc.setOutputType(TCC.OutputType.exe);
		const src = `
#include <stdio.h>
int main(int argc, char** argv) {
  printf("Hello world!\n");
  return 0; }
`;
		assert(tcc.eval(src, 0, null) == 0);
		// assert(tcc.addLibraryPath(DirPath("/usr/lib/x86_64-linux-gnu/")) == 0);
		// assert(tcc.addLibrary("c") == 0); // C library
	}
}

/// Use gmp.h.
@safe unittest {
	version (linux) {
		TCC tcc;
		tcc.setOutputType(TCC.OutputType.exe);
		const src = `
#include <gmp.h>
int main(int argc, char** argv) {
  mpz_t x;
  mpz_init_set_ui(x, 42);
  const ret = mpz_get_ui(x);
  mpz_clear(x);
  return ret;
}
`;
		assert(tcc.addLibrary("gmp") == 0); // GNU MP
		assert(tcc.eval(src, 0, null) == 42);
	}
}

/// Set system include paths.
pure @safe unittest {
	TCC tcc;
	tcc.addSystemIncludePath(DirPath(`/usr/include/`));
	tcc.addSystemIncludePath(DirPath(`/usr/lib/x86_64-linux-gnu/tcc/`));
	tcc.addSystemIncludePath(DirPath(`/usr/include/linux/`));
	tcc.addSystemIncludePath(DirPath(`/usr/include/x86_64-linux-gnu/`));
}

/++ In-memory compilation.
	See: https://gist.github.com/llandsmeer/3489603e5070ee8dbe75cdf1865a5ca9
 +/
@safe unittest {
	TCC tcc;

	static extern(C) void error_func_ignore(void* opaque, const char* msg) @trusted {
		import core.stdc.string : strlen;
		import std.stdio;
		printf("opaque:%p\nmsg:\n%s\n", opaque, msg);
	}
	tcc.setErrorFunction((void*).init, &error_func_ignore);

	tcc.setOutputType(TCC.OutputType.memory);

	import std.datetime.stopwatch : StopWatch, AutoStart;
	auto sw = StopWatch(AutoStart.yes);
	static extern(C) int add1(int x) { return x+1; }
	tcc.addSymbol("add1", &add1);
	tcc.compile("int add1(int); int main() { return add1(41); }");
	import std.stdio;
	writeln("tcc.compile took ", sw.peek);

	sw.reset();
	const exitStatus = tcc.run(0, null);
	writeln("tcc.run took:", sw.peek);

	assert(exitStatus == 42);
}
