/++ File system path and name types and their operations.

	See: https://en.cppreference.com/w/cpp/filesystem/path
	See: https://hackage.haskell.org/package/FileSystem-1.0.0/docs/System-FileSystem-Types.html
	See_Also: `dmd.root.filename`
 +/
module nxt.path;

import nxt.algorithm.searching : canFind, stripRight;
private import std.path : std_expandTilde = expandTilde, std_buildPath = buildPath, std_buildNormalizedPath = buildNormalizedPath, std_baseName = baseName, dirSeparator;

@safe:

/++ Path.

	The concept of a "pure path" doesn't need to be modelled in D as
	it has `pure` functions.  See
	https://docs.python.org/3/library/pathlib.html#pure-paths.

	See: SUMO:`ComputerPath`.
 +/
struct Path {
	this(string str, in bool normalize = false) pure nothrow @nogc {
		this.str = normalize ? str.stripRight(dirSeparator) : str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
@safe pure nothrow unittest {
	assert(Path("/usr/bin/").toString == "/usr/bin/");
}

/++ (Regular) File path.
	See: https://hackage.haskell.org/package/filepath-1.5.0.0/docs/System-FilePath.html#t:FilePath
 +/
struct FilePath {
	this(string str, in bool normalize = false) pure nothrow @nogc {
		this.path = Path(str, normalize);
	}
	Path path;
	alias path this;
}

///
@safe pure nothrow unittest {
	assert(FilePath("/usr/bin/") == FilePath("/usr/bin/"));
	assert(FilePath("/usr/bin/") == Path("/usr/bin/"));
	assert(FilePath("foo") == Path("foo"));
	assert(FilePath("foo", false).str == "foo");
	assert(FilePath("foo", true).str == "foo");
	assert(Path("/etc/", false).str == "/etc/");
	assert(Path("/etc/", true).str == "/etc");
	assert(Path("foo", true).str == "foo");
}

/++ Directory path.
	See: SUMO:`ComputerDirectory`.
 +/
struct DirPath {
	this(string path, in bool normalize = false) pure nothrow @nogc {
		this.path = Path(path, normalize);
	}
	Path path;
	alias path this;
}

///
@safe pure nothrow unittest {
	assert(DirPath("/etc") == Path("/etc"));
	assert(DirPath("/etc") == DirPath("/etc"));
	assert(DirPath("/etc/", false).str == "/etc/");
	assert(DirPath("/etc/", true).str == "/etc");
}

/++ File (local) name.
 +/
struct FileName {
	this(string str) pure nothrow @nogc in (!str.canFind('/')) {
		this.str = str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
pure nothrow @safe unittest {
	assert(FileName(".emacs").str == ".emacs");
	assert(FileName(".emacs").toString == ".emacs");
}

/++ Directory (local) name.
 +/
struct DirName {
	this(string str) pure nothrow @nogc in (!str.canFind('/')) {
		this.str = str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
pure nothrow @safe unittest {
	assert(DirName(".emacs.d").str == ".emacs.d");
	assert(DirName(".emacs.d").toString == ".emacs.d");
}

/++ Execute file path.
 +/
struct ExePath {
	this(string path) pure nothrow @nogc {
		this.path = Path(path);
	}
	Path path;
	alias path this;
}

///
@safe pure nothrow unittest {
	assert(ExePath("/usr/bin/") == Path("/usr/bin/"));
}

/++ Written (input) path. +/
struct RdPath {
	this(string str) pure nothrow @nogc {
		this.path = Path(str);
	}
	Path path;
	alias path this;
}

///
@safe pure nothrow unittest {
	assert(RdPath("/usr/bin/") == Path("/usr/bin/"));
}

/++ Written (output) path. +/
struct WrPath {
	this(string str) pure nothrow @nogc {
		this.path = Path(str);
	}
	Path path;
	alias path this;
}

///
@safe pure nothrow unittest {
	assert(WrPath("/usr/bin/") == Path("/usr/bin/"));
}

/// Expand tilde in `a`.
FilePath expandTilde(FilePath a) nothrow => typeof(return)(std_expandTilde(a.path.str));
/// ditto
DirPath expandTilde(DirPath a) nothrow => typeof(return)(std_expandTilde(a.path.str));

///
@safe nothrow unittest {
	assert(FilePath("~").expandTilde);
	assert(DirPath("~").expandTilde);
}

/// Build path `a`/`b`.
FilePath buildPath(DirPath a, FilePath b) pure nothrow => typeof(return)(std_buildPath(a.path.str, b.path.str));
/// ditto
DirPath buildPath(DirPath a, DirPath b) pure nothrow => typeof(return)(std_buildPath(a.path.str, b.path.str));
/// ditto
DirPath buildPath(DirPath a, DirName b) pure nothrow => typeof(return)(std_buildPath(a.path.str, b.str));
/// ditto
FilePath buildPath(DirPath a, FileName b) pure nothrow => typeof(return)(std_buildPath(a.path.str, b.str));

///
@safe pure nothrow unittest {
	assert(DirPath("/etc").buildPath(FileName("foo")) == FilePath("/etc/foo"));
	assert(DirPath("/etc").buildPath(FilePath("foo")) == FilePath("/etc/foo"));
	assert(DirPath("/usr").buildPath(DirName("bin")) == DirPath("/usr/bin"));
	assert(DirPath("/usr").buildPath(DirPath("bin")) == DirPath("/usr/bin"));
	assert(DirPath("/usr").buildPath(DirPath("/bin")) == DirPath("/bin"));
}

/// Build path `a`/`b`.
FilePath buildNormalizedPath(DirPath a, FilePath b) pure nothrow => typeof(return)(std_buildNormalizedPath(a.path.str, b.path.str));
/// ditto
DirPath buildNormalizedPath(DirPath a, DirPath b) pure nothrow => typeof(return)(std_buildNormalizedPath(a.path.str, b.path.str));
/// ditto
DirPath buildNormalizedPath(DirPath a, DirName b) pure nothrow => typeof(return)(std_buildNormalizedPath(a.path.str, b.str));
/// ditto
FilePath buildNormalizedPath(DirPath a, FileName b) pure nothrow => typeof(return)(std_buildNormalizedPath(a.path.str, b.str));

///
@safe pure nothrow unittest {
	assert(DirPath("/etc").buildNormalizedPath(FileName("foo")) == FilePath("/etc/foo"));
	assert(DirPath("/etc").buildNormalizedPath(FilePath("foo")) == FilePath("/etc/foo"));
	assert(DirPath("/usr").buildNormalizedPath(DirName("bin")) == DirPath("/usr/bin"));
	assert(DirPath("/usr").buildNormalizedPath(DirPath("bin")) == DirPath("/usr/bin"));
	assert(DirPath("/usr").buildNormalizedPath(DirPath("/bin")) == DirPath("/bin"));
}

/++ URL.
 +/
struct URL {
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
@safe pure nothrow unittest {
	assert(URL("www.sunet.se").toString == "www.sunet.se");
}

/++ File URL.
 +/
struct FileURL {
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
@safe pure nothrow unittest {
	assert(FileURL("www.sunet.se").toString == "www.sunet.se");
}

/++ Directory URL.
 +/
struct DirURL {
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() inout @property => str;
}

///
@safe pure nothrow unittest {
	assert(DirURL("www.sunet.se").toString == "www.sunet.se");
}

/++ File Offset URL.
 +/
struct FileURLOffset {
	import nxt.offset : Offset;
	FileURL url;
	Offset offset;
}

/++ File Region URL.
 +/
struct FileURLRegion {
	import nxt.region : Region;
	FileURL url;
	Region region;
}

/// Get basename of `a`.
FileName baseName(FilePath a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
DirName baseName(DirPath a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
DirName baseName(URL a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
FileName baseName(FileURL a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
DirName baseName(DirURL a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));

///
version (Posix) nothrow @safe unittest {
	assert(FilePath("/etc/foo").baseName.str == "foo");
	assert(DirPath("/etc/").baseName.str == "etc");
	const dmd = "https://github.com/dlang/dmd/";
	assert(URL(dmd).baseName.str == "dmd");
	assert(FileURL(dmd).baseName.str == "dmd");
	assert(DirURL(dmd).baseName.str == "dmd");
}

private import std.file : std_exists = exists;

/// Check if `a` exists.
bool exists(in Path a) nothrow @nogc => typeof(return)(std_exists(a.str));
/// ditto
bool exists(in FilePath a) nothrow @nogc => typeof(return)(std_exists(a.str));
/// ditto
bool exists(in DirPath a) nothrow @nogc => typeof(return)(std_exists(a.str));
/// ditto
bool exists(in FileName a) nothrow @nogc => typeof(return)(std_exists(a.str));
/// ditto
bool exists(in DirName a) nothrow @nogc => typeof(return)(std_exists(a.str));

/// verify `a.toString` when `a` being `scope` parameter
version (none) // TODO: Remove or make compile
@safe pure nothrow @nogc unittest {
	import std.meta : AliasSeq;

	static foreach (T; AliasSeq!(Path, FilePath, DirPath, FileName, DirName)) {{
		static void f(in T a) { const _ = a.toString; }
		f(T.init);
	}}
}

///
version (Posix) nothrow @safe unittest {
	assert( Path("/etc/").exists);
	assert(!Path("/etcxyz/").exists);
	assert( DirPath("/etc/").exists);
	assert(!DirPath("/etcxyz/").exists);
	assert( FilePath("/etc/passwd").exists);
	assert(!FileName("dsfdsfdsfdsfdfdsf").exists);
	assert(!DirName("dsfdsfdsfdsfdfdsf").exists);
}
