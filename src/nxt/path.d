/++ File system path and name types and their operations.

	See: https://en.cppreference.com/w/cpp/filesystem/path
	See: https://hackage.haskell.org/package/FileSystem-1.0.0/docs/System-FileSystem-Types.html
	See_Also: `dmd.root.filename`
 +/
module nxt.path;

@safe:

/++ Path.

	The concept of a "pure path" doesn't need to be modelled in D as
	it has `pure` functions.  See
	https://docs.python.org/3/library/pathlib.html#pure-paths.

	See: SUMO:`ComputerPath`.
 +/
struct Path {
	this(string str, in bool normalize = false) pure nothrow @nogc {
		import nxt.algorithm.mutation : stripRight;
		import std.path : dirSeparator;
		this.str = normalize ? str.stripRight(dirSeparator) : str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() const @property => str;
}

///
@safe pure nothrow unittest {
	assert(Path("/usr/bin/").toString == "/usr/bin/");
}

/++ (Regular) file path (on local file system).
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

/++ Directory path (on local file system).
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

/++ File name (either local or remote).
 +/
struct FileName {
	import nxt.algorithm.searching : canFind;
	this(string str) pure nothrow @nogc in (!str.canFind('/')) {
		this.str = str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() const @property => str;
}

///
pure nothrow @safe unittest {
	assert(FileName(".emacs").str == ".emacs");
	assert(FileName(".emacs").toString == ".emacs");
}

/++ Directory name (either local or remote).
 +/
struct DirName {
	import nxt.algorithm.searching : canFind;
	this(string str) pure nothrow @nogc in (!str.canFind('/')) {
		this.str = str;
	}
	string str;
pure nothrow @nogc:
	bool opCast(T : bool)() const scope => str !is null;
	string toString() const @property => str;
}

///
pure nothrow @safe unittest {
	assert(DirName(".emacs.d").str == ".emacs.d");
	assert(DirName(".emacs.d").toString == ".emacs.d");
}

/++ Execute file path (on local file system).
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

/++ Written (input) path (on local file system). +/
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

/++ Written (output) path (on local file system). +/
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

private import std.path : std_expandTilde = expandTilde;

/++ Expand tilde in `a`.
	TODO: remove `@trusted` when scope inference is works.
 +/
FilePath expandTilde(scope return FilePath a) nothrow @trusted => typeof(return)(std_expandTilde(a.path.str));
/// ditto
DirPath expandTilde(scope return DirPath a) nothrow @trusted => typeof(return)(std_expandTilde(a.path.str));

///
@safe nothrow unittest {
	assert(FilePath("~").expandTilde);
	assert(DirPath("~").expandTilde);
}

private import std.path : std_buildPath = buildPath;

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

private import std.path : std_buildNormalizedPath = buildNormalizedPath;

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
	string toString() const @property => str;
}

///
@safe pure nothrow unittest {
	assert(URL("www.sunet.se").toString == "www.sunet.se");
}

/++ File URL.
 +/
struct FileURL {
	URL url;
pure nothrow @nogc:
	this(string str) { this.url = URL(str); }
	this(FilePath path) { this.url = URL(path.str); }
	bool opCast(T : bool)() const scope => url.str !is null;
	string toString() const @property => url.str;
}

///
@safe pure nothrow unittest {
	assert(FileURL("www.sunet.se").toString == "www.sunet.se");
	assert(FileURL(FilePath("/etc/passwd")).toString == "/etc/passwd");
}

/++ Directory URL.
 +/
struct DirURL {
	URL url;
pure nothrow @nogc:
	this(string str) { this.url = URL(str); }
	this(DirPath path) { this.url = URL(path.str); }
	bool opCast(T : bool)() const scope => url.str !is null;
	string toString() const @property => url.str;
}

///
@safe pure nothrow unittest {
	assert(DirURL("www.sunet.se").toString == "www.sunet.se");
	assert(DirURL(DirPath("/etc/")).toString == "/etc/");
}

/++ File URL and Offset (in bytes).
 +/
struct FileURLOffset {
	import nxt.offset : Offset;
	FileURL url;
	Offset offset;
}

/++ File URL and Region (in bytes).
 +/
struct FileURLRegion {
	import nxt.region : Region;
	FileURL url;
	Region region;
}

private import std.path : std_baseName = baseName;

/// Get basename of `a`.
FileName baseName(FilePath a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
DirName baseName(DirPath a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
DirName baseName(URL a) pure nothrow @nogc => typeof(return)(std_baseName(a.str));
/// ditto
FileName baseName(FileURL a) pure nothrow @nogc => typeof(return)(std_baseName(a.url.str));
/// ditto
DirName baseName(DirURL a) pure nothrow @nogc => typeof(return)(std_baseName(a.url.str));

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
bool exists(in FileURL a) nothrow @nogc => typeof(return)(std_exists(a.url.str));
/// ditto
bool exists(in DirURL a) nothrow @nogc => typeof(return)(std_exists(a.url.str));
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
	assert( DirURL("/etc/").exists);
	assert(!DirPath("/etcxyz/").exists);
	assert( FilePath("/etc/passwd").exists);
	assert( FileURL("/etc/passwd").exists);
	assert(!FileName("dsfdsfdsfdsfdfdsf").exists);
	assert(!DirName("dsfdsfdsfdsfdfdsf").exists);
}
