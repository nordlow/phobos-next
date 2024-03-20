/** Pretty Printing.
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -I.. -i -unittest -version=show -main -run prettyio.d
 *
 * TODO: Print structures only matching a certain value passed as template
 *       parameter. Used in print debugging.
 */
module nxt.prettyio;

/++ Format of pretty printing.
 +/
struct Format {
	/++ Indentation character.
     +/
	string indentation = "\t";

	/++ New line terminator.
		See: https://en.wikipedia.org/wiki/Newline
     +/
	string newline = "\n";

	/++ Flags that (field) types should be shown.
     +/
	bool showType = false;

	/++ Flags that `.init` values should be hidden.
     +/
	bool hideInit = false;
}

/++ Pretty print `arg`.
 +/
void cwritePretty(T)(T arg, in size_t depth = 0, in char[] name = [], in Format fmt = Format.init) {
	scope const(void)*[] ptrs;
	cwritePretty_!(T)(arg, depth, name, fmt, ptrs);
}

private void cwritePretty_(T)(T arg, in size_t depth = 0, in char[] name = [], in Format fmt = Format.init, ref scope const(void)*[] ptrs) {
	import std.traits : isArray, isSomeString, isSomeChar, isPointer, hasMember;
	import std.stdio : wr = write;

	void doIndent() {
		foreach (_; 0 .. depth) wr(fmt.indentation);
	}

	void doFieldName() {
		if (name) wr(name, ": ");
	}

	void doTypeName() {
		if (fmt.showType) wr(T.stringof, " ");
	}

	void doAddress(in void* ptr) {
		wr('@', ptr);
	}

	static if (is(T == struct) || is(T == class) || is(T == union)) {
		import std.traits : FieldNameTuple;
		void doMembers() {
			foreach (memberName; FieldNameTuple!T)
				cwritePretty_(__traits(getMember, arg, memberName), depth + 1,
								   memberName, fmt, ptrs);
		}
		void doAggregate() {
			/* TODO: Using class.toString requires special care here because
			   Object.toString defaults to its qualified type name: */
			static if ((is(T == struct) || is(T == union)) && hasMember!(T, "toString")) {
				const str = arg.toString;
				if (str !is null)
					wr('"', str, '"', fmt.newline);
				else
					wr("[]", fmt.newline); /+ TODO: use cwriteMembers(); instead +/
			} else {
				if (fmt.hideInit && arg is arg.init) {
					wr(".init", fmt.newline);
				} else {
					wr("{", fmt.newline);
					doMembers();
					doIndent();
					wr("}", fmt.newline);
				}
			}
		}
	}

	doIndent();
	doFieldName();
	doTypeName();

	static if (is(T == class)) {
		const(void)* ptr;
		() @trusted { ptr = cast(void*)arg; }();
		doAddress(ptr);
		if (arg is null) {
			wr(fmt.newline);
		} else {
			const ix = ptrs.indexOf(ptr);
			wr(' ');
			if (ix != -1) { // `ptr` already printed
				wr("#", ix, fmt.newline); // Emacs-Lisp-style back-reference
			} else {
				ptrs ~= ptr;
				wr("#", ptrs.length, ' '); // Emacs-Lisp-style back-reference
				doAggregate();
			}
		}
	} else static if (is(T == union) || is(T == struct)) {
		doAggregate();
    } else static if (isPointer!T) {
		const ptr = cast(void*)arg;
		doAddress(ptr);
		if (arg is null) {
			wr(fmt.newline);
		} else {
			const ix = ptrs.indexOf(ptr);
			wr(' ');
			if (ix != -1) { // `ptr` already printed
				wr("#", ix, fmt.newline); // Emacs-Lisp-style back-reference
			} else {
				wr("#", ptrs.length, " -> "); // Emacs-Lisp-style back-reference
				ptrs ~= ptr;
				static if (is(immutable typeof(*arg))) { // `arg` is not `void*`
					cwritePretty_(*arg, depth, [], fmt, ptrs);
				}
			}
		}
    } else static if (isSomeString!T) {
		if (arg !is null)
			wr('"', arg, '"', fmt.newline);
		else
			wr("[]", fmt.newline);
    } else static if (isSomeChar!T) {
        wr(`'`, arg, `'`, fmt.newline);
    } else static if (isArray!T) {
        wr("[");
		if (arg.length) { // non-empty
			import std.range.primitives : ElementType;
			alias E = ElementType!(T);
			enum scalarE = __traits(isScalar, E);
			static if (!scalarE)
				wr(fmt.newline);
			foreach (const i, ref element; arg) {
				static if (scalarE) {
					if (i != 0)
						wr(',');
					cwritePretty_(element, 0, [],
								  Format(indentation: [], newLine: [], showType: false, hideInit: false), ptrs);
				} else {
					cwritePretty_(element, depth + 1, [], fmt, ptrs);
				}
			}
			static if (!scalarE)
				doIndent();
		}
		wr("]", fmt.newline);
    } else static if (__traits(isAssociativeArray, T)) {
        wr(arg, fmt.newline);
    } else {
        wr(arg, fmt.newline);
    }
}

/++ Colorized version of `std.stdio.write`.
 +/
void cwrite(T...)(T args) {
	import std.stdio : sw = write;
	version (none) import nxt.ansi_escape : putWithSGRs; /+ TODO: use below: +/
	// alias w = pathWrapperSymbol;
	static foreach (arg; args) {{
		static immutable S = typeof(arg).stringof;
		// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", S);
		// static if (S == "URL")
		// 	sw(w, arg, w); /+ TODO: SGR.yellowForegroundColor +/
		// else static if (S == "Path")
		// 	sw(w, arg, w); /+ TODO: SGR.whiteForegroundColor +/
		// else static if (S == "FilePath")
		// 	sw(w, arg, w); /+ TODO: SGR.whiteForegroundColor +/
		// else static if (S == "DirPath")
		// 	sw(w, arg, w); /+ TODO: SGR.cyanForegroundColor +/
		// else static if (S == "ExePath")
		// 	sw(w, arg, w); /+ TODO: SGR.lightRedForegroundColor +/
		// else static if (S == "FileName")
		// 	sw(w, arg, w); /+ TODO: SGR.whiteForegroundColor +/
		// else static if (S == "DirName")
		// 	sw(w, arg, w); /+ TODO: SGR.redForegroundColor +/
		// else static if (S == "ExitStatus")
		// 	sw(w, arg, w); /+ TODO: SGR.greenForegroundColor if arg == 0, otherwise SGR.redForegroundColor +/
		// else
		sw(arg);
	}}
}

/++ Wrapper symbol when printing paths and URLs to standard out (`stdout`) and standard error (`stderr`).
 +/
private static immutable string pathWrapperSymbol = `"`;

/++ Colorized version of `std.stdio.writeln`.
 +/
void cwriteln(T...)(T args) {
	import std.stdio : swln = writeln;
	cwrite!(T)(args);
	swln();
}

version (show)
unittest {
	@safe struct P {
		double x;
		double y;
		double z;
	}

	@safe union U {
		void* ptr;
		size_t word;
	}

	@safe struct S {
		int x;
		double y;
		char[3] c3 = "abc";
		wchar[3] wc3 = "abc";
		dchar[3] dc3 = "abc";
		string w3 = "xyz";
		wstring ws3 = "xyz";
		dstring ds3 = "xyz";
		string ns = []; // null string
		string s = ""; // non-null empty string
		int[3] i3;
		float[3] f3;
		double[3] d3;
		real[3] r3;
		int[string] ais = ["a":1, "b":2];
		P[string] ps = ["a":P(1,2,3)];
		P p0;
		P* pp0 = null;
		P* pp1 = new P(1,2,3);
		U u;
	}

	@safe class Cls {
		this(int x) {
			this.x = x;
			this.parent = this;
		}
		int x;
		Cls parent;
	}

	@safe struct Top {
		S s;
		S[2] s2;
		Cls cls;
		Cls clsNull;
		string name;
		int[] numbers;
	}

	S s = S(10, 20.5);
    Top top = { s, [s,s], new Cls(1), null, "example", [1, 2, 3] };
    top.cwritePretty(0, "top", Format(indentation: "\t", newline:  "\n", showType: false, hideInit: false));
    top.cwritePretty(0, "top", Format(indentation: "\t", newline: "\n", showType: false, hideInit: true));
    top.cwritePretty(0, "top", Format(indentation: "\t", newline: "\n", showType: true, hideInit: false));
    top.cwritePretty(0, "top", Format(indentation: "\t", newline: "\n", showType: true, hideInit: true));
}

/** Array-specialization of `indexOf` with default predicate.
 *
 * TODO: Add optimized implementation for needles with length >=
 * `largeNeedleLength` with no repeat of elements.
 */
ptrdiff_t indexOf(T)(scope inout(T)[] haystack,
					 scope const(T)[] needle) @trusted {
	// enum largeNeedleLength = 4;
	if (haystack.length < needle.length)
		return -1;
	foreach (const offset; 0 .. haystack.length - needle.length + 1)
		if (haystack.ptr[offset .. offset + needle.length] == needle)
			return offset;
	return -1;
}
/// ditto
ptrdiff_t indexOf(T)(scope inout(T)[] haystack,
					 scope const T needle) {
	static if (is(T == char))
		assert(needle < 128); // See_Also: https://forum.dlang.org/post/sjirukypxmmcgdmqbcpe@forum.dlang.org
	foreach (const offset, const ref element; haystack)
		if (element == needle)
			return offset;
	return -1;
}
