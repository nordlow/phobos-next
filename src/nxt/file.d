/** Extensions to std.file.
	Copyright: Per Nordlöw 2024-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.file;

import std.stdio : File;
import nxt.path : FileName, FilePath, DirPath;
import nxt.pattern : PNode = Node;

private enum PAGESIZE = 4096;

@safe:

/++ Type of file.
 +/
struct FileType {
	DataFormat format; ///< Format associated with file type.
	alias format this;
	PNode fileNamePattern; ///< Pattern matching file name(s) often associated.
}

typeof(FileName.str) matchFirst(scope return /+ref+/ FileName input, const PNode node) pure nothrow /+@nogc+/ {
	import nxt.pattern : matchFirst;
	return input.str.matchFirst(node);
}

/++ Get pattern that matches a file name ending with '.'~`s`. +/
static PNode fileExtension(string s) pure nothrow {
	import nxt.pattern : seq, lit, eob;
	return seq(lit('.'), lit(s), eob());
}

/// ditto
@safe pure unittest {
	auto app_d = FileName("app.d");
	assert( app_d.matchFirst(fileExtension("d")));
	assert(!app_d.matchFirst(fileExtension("c")));
	assert(!app_d.matchFirst(fileExtension("cpp")));
	auto app = FileName("app");
	assert(!app.matchFirst(fileExtension("d")));
	assert(!app.matchFirst(fileExtension("c")));
	assert(!app.matchFirst(fileExtension("cpp")));
	auto app_c = FileName("app.c");
	assert(!app_c.matchFirst(fileExtension("d")));
	assert( app_c.matchFirst(fileExtension("c")));
	assert(!app_c.matchFirst(fileExtension("cpp")));
}

/++ (Data) Format of file contents.

	The `name` can be either a programming language such as "C",
	"C++", "D", etc or a data format such as "JSON", "XML" etc.

	See: https://en.wikipedia.org/wiki/File_format
 +/
struct DataFormat {
	/++ TODO: Make this a `PNode namePattern` to support both, for instance,
    "JavaScript Object Notation" and "JSON". +/
	string name;
	alias name this;
	/// Pattern matching file contents often associated.
	PNode contentPattern;
}

/++ Extension of filename.
	See: https://en.wikipedia.org/wiki/Filename_extension
 +/
struct FileExtension {
	string value;
	alias value this;
}

/** Read file $(D path) into raw array with one extra terminating zero byte.
 *
 * This extra terminating zero (`null`) byte at the end is typically used as a
 * sentinel value to speed up textual parsers or when characters are sent to a
 * C-function taking a zero-terminated string as input.
 *
 * TODO: Add or merge to Phobos?
 *
 * See_Also: https://en.wikipedia.org/wiki/Sentinel_value
 * See_Also: http://forum.dlang.org/post/pdzxpkusvifelumkrtdb@forum.dlang.org
 */
immutable(void)[] rawReadZ(FilePath path) @safe {
	return File(path.str, `rb`).rawReadZ();
}
/// ditto
immutable(void)[] rawReadZ(scope File file) @trusted
{
	import std.array : uninitializedArray;

	alias Data = ubyte[];
	Data data = uninitializedArray!(Data)(file.size + 1); // one extra for terminator

	file.rawRead(data);
	data[file.size] = '\0';	 // zero terminator for sentinel

	import std.exception : assumeUnique;
	return assumeUnique(data);
}

///
version (Posix)
@safe unittest {
	import nxt.algorithm.searching : endsWith;
	const d = cast(const(char)[]) FilePath(`/etc/passwd`).rawReadZ();
	assert(d.endsWith('\0')); // has 0-terminator
}

/++ Find path for `a` (or `FilePath.init` if not found) in `pathVariableName`.
	TODO: Add caching of result and detect changes via inotify.
 +/
FilePath findExecutable(FileName a, scope const(char)[] pathVariableName = "PATH") {
	return findFileInPath(a, "PATH", onlyExecutable: true);
}

///
@safe unittest {
	version (Posix) {
		assert(findExecutable(FileName("ls")) == FilePath("/usr/bin/ls"));
		assert(!findExecutable(FileName("xyz")));
	}
}

/++ Find path for `a` (or `FilePath.init` if not found) in `pathVariableName`.
	TODO: Add caching of result and detect changes via inotify.
 +/
FilePath findFileInPath(FileName a, scope const(char)[] pathVariableName, bool onlyExecutable) /+nothrow+/ {
	import std.algorithm : splitter;
	import std.process : environment;
	const envPATH = environment.get(pathVariableName, ""); // TODO: nothrow
	foreach (const p; envPATH.splitter(':')) {
		import nxt.path : buildPath, exists;
		const path = DirPath(p).buildPath(a);
		// pick first match
		if (onlyExecutable && path.toString.isExecutable)
			return path;
		if (path.exists)
			return path;
	}
	return typeof(return).init;
}

version (Posix)
private bool isExecutable(in char[] path) @trusted nothrow @nogc {
	import std.internal.cstring : tempCString;
	import core.sys.posix.unistd : access, X_OK;
    return access(path.tempCString(), X_OK) == 0;
}

/++ Get path to default temporary directory.
	See_Also: `std.file.tempDir`
	See: https://forum.dlang.org/post/gg9kds$1at0$1@digitalmars.com
 +/
DirPath tempDir() {
	import std.file : std_tempDir = tempDir;
	return typeof(return)(std_tempDir);
}

///
@safe unittest {
	version (Posix) {
		assert(tempDir().str == "/tmp/");
	}
}

/** Returns the path to a new (unique) temporary file under `tempDir`.
    See_Also: https://forum.dlang.org/post/ytmwfzmeqjumzfzxithe@forum.dlang.org
    See_Also: https://dlang.org/library/std/stdio/file.tmpfile.html
 */
string tempSubFilePath(string prefix = null, string extension = null) @safe {
	import std.file : tempDir;
	import std.uuid : randomUUID;
	import std.path : buildPath;
	/+ TODO: use allocation via lazy range or nxt.appending.append() +/
	return tempDir().buildPath(prefix ~ randomUUID.toString() ~ extension);
}

///
@safe unittest {
	import nxt.algorithm.searching : canFind, endsWith;
	const prefix = "_xyz_";
	const ext = "_ext_";
	const path = tempSubFilePath(prefix, ext);
	assert(path.canFind(prefix));
	assert(path.endsWith(ext));
}

/++ Get path to home directory.
	See_Also: `tempDir`
	See: https://forum.dlang.org/post/gg9kds$1at0$1@digitalmars.com
 +/
DirPath homeDir() {
	import std.process : environment;
    version(Windows) {
        // On Windows, USERPROFILE is typically used, but HOMEPATH is an alternative
		if (const home = environment.get("USERPROFILE"))
			return typeof(return)(home);
        // Fallback to HOMEDRIVE + HOMEPATH
        const homeDrive = environment.get("HOMEDRIVE");
        const homePath = environment.get("HOMEPATH");
        if (homeDrive && homePath)
            return typeof(return)(buildPath(homeDrive, homePath));
    } else {
        if (const home = environment.get("HOME"))
			return typeof(return)(home);
    }
    throw new Exception("No home directory environment variable is set.");
}

///
@safe unittest {
	version (Posix) {
		import std.path : expandTilde;
		assert(homeDir().str == "~".expandTilde);
	}
}

/++ Get path to the default cache (home) directory.
	See: `XDG_CACHE_HOME`
	See: https://specifications.freedesktop.org/basedir-spec/latest/
	See_Also: `tempDir`.
 +/
DirPath cacheHomeDir() {
	import std.process : environment;
    version(Windows) {
        if (const home = environment.get("XDG_CACHE_HOME"))
			return typeof(return)(home);
    } else {
        if (const home = environment.get("XDG_CACHE_HOME"))
			return typeof(return)(home);
    }
	// throw new Exception("The `XDG_CACHE_HOME` environment variable is unset");
	import nxt.path : buildPath;
	return homeDir.buildPath(DirPath(`.cache`));
}

///
@safe unittest {
	version (Posix) {
		import nxt.path : buildPath;
		assert(cacheHomeDir() == homeDir.buildPath(DirPath(`.cache`)));
	}
}

/++ Variant of `std.file.remove()` that returns status instead of throwing.

	Modified copy of `std.file.remove()`.

	Returns: `true` iff file of path `name` was successfully removed,
	         `false` otherwise.

	Typically used in contexts where a `nothrow` variant of
	`std.file.remove()` is require such as in class destructors/finalizers in which an
	illegal memory operation exception otherwise file be thrown.
 +/
bool removeIfExists(scope const(char)[] name) @trusted nothrow @nogc {
	import std.internal.cstring : tempCString;
	// implicit conversion to pointer via `TempCStringBuffer` `alias this`:
	scope const(FSChar)* namez = name.tempCString!FSChar();
    version (Windows) {
		return DeleteFileW(namez) == 0;
    } else version (Posix) {
        static import core.stdc.stdio;
		return core.stdc.stdio.remove(namez) == 0;
    }
}

/++ Character type used for operating system filesystem APIs.
	Copied from `std.file`.
 +/
version (Windows)
    private alias FSChar = WCHAR;       // WCHAR can be aliased to wchar or wchar_t
else version (Posix)
    private alias FSChar = char;
else
    static assert(0);

///
@safe nothrow unittest {
	// TODO: test `removeIfExists`
}

import std.file : DirEntry;

/++ Identical to `std.file.rmdirRecurse` on POSIX.
	On Windows it removes read-only bits before deleting.
	TODO: Integrate into Phobos as `rmdirRecurse(bool forced)`.
	TODO: Make a non-throwing version bool tryRmdirRecurse(bool forced).
 +/
void rmdirRecurseForced(in DirPath path, bool followSymlink = false) {
	rmdirRecurseForced(path.str, followSymlink);
}
/// ditto
void rmdirRecurseForced(in char[] path, bool followSymlink = false) @trusted {
	// passing `de` as an r-value segfaults so store in l-value
	auto de = DirEntry(cast(string)path);
	rmdirRecurseForced(de, followSymlink);
}
/// ditto
void rmdirRecurseForced(ref DirEntry de, bool followSymlink = false) {
	import std.file : FileException, remove, dirEntries, SpanMode, attrIsDir, rmdir, attrIsDir, setAttributes;
	if (!de.isDir)
		throw new FileException(de.name, "Trying to remove non-directory " ~ de.name);
	if (de.isSymlink) {
		version (Windows)
			rmdir(de.name);
		else
			remove(de.name);
		return;
	}
	foreach (ref e; dirEntries(de.name, SpanMode.depth, followSymlink)) {
		version (Windows) {
			import core.sys.windows.windows : FILE_ATTRIBUTE_READONLY;
			if ((e.attributes & FILE_ATTRIBUTE_READONLY) != 0)
				e.name.setAttributes(e.attributes & ~FILE_ATTRIBUTE_READONLY);
		}
		attrIsDir(e.linkAttributes) ? rmdir(e.name) : remove(e.name);
	}
	rmdir(de.name); // dir itself
}

///
@safe nothrow unittest {
	// TODO: test `rmdirRecurseForced`
}

import std.file : PreserveAttributes, preserveAttributesDefault;

/++ Copy directory `from` to `to` recursively. +/
void copyRecurse(scope const(char)[] from, scope const(char)[] to, in PreserveAttributes preserve = preserveAttributesDefault) {
    import std.file : copy, dirEntries, isDir, isFile, mkdirRecurse, SpanMode;
    import std.path : buildPath;
    if (from.isDir()) {
        to.mkdirRecurse();
        const from_ = () @trusted {
            return cast(string) from;
        }();
        foreach (entry; dirEntries(from_, SpanMode.breadth)) {
			const fn = entry.name[from.length + 1 .. $]; // +1 skip separator
            const dst = () @trusted { return to.buildPath(fn); }();
            if (entry.name.isFile())
                entry.name.copy(dst, preserve);
            else
                dst.mkdirRecurse();
        }
    } else
        from.copy(to, preserve);
}
/// ditto
void copyRecurse(DirPath from, DirPath to, in PreserveAttributes preserve = preserveAttributesDefault)
	=> copyRecurse(from.str, to.str, preserve);

/++ Directory Scanning Flags|Options. +/
struct ScanFlags {
	alias Depth = ushort; // as path length <= 4096 on all architectures
	Depth depthMin = 0;
	Depth depthLength = Depth.max;
	bool followSymlink = true;
}

void dirEntries(in char[] root,
				in ScanFlags scanFlags = ScanFlags.init,
				in ScanFlags.Depth depth = ScanFlags.Depth.init) {
	import std.file : std_dirEntries = dirEntries, SpanMode;
	const root_ = () @trusted { return cast(string)(root); }();
	foreach (ref dent; std_dirEntries(root_, SpanMode.shallow, scanFlags.followSymlink)) {
		const depth1 = cast(ScanFlags.Depth)(depth + 1);
		if (dent.isDir && depth1 < scanFlags.depthMin + scanFlags.depthLength)
			dirEntries(dent.name, scanFlags, depth1);
		else if (depth >= scanFlags.depthMin) {
			assert(0, "TODO: Turn into a range");
		}
	}
}
/// ditto
void dirEntries(DirPath root,
				in ScanFlags scanFlags = ScanFlags.init,
				in ScanFlags.Depth depth = ScanFlags.Depth.init) @trusted {
	dirEntries(root.str, scanFlags, depth);
}

/** Create a new temporary file starting with ($D namePrefix) and ending with 6
	randomly defined characters.

    Returns: File Descriptor to opened file.
 */
version (linux)
int tempfile(in char[] namePrefix = null) @trusted {
	import core.sys.posix.stdlib: mkstemp;
	char[PAGESIZE] buf;
	buf[0 .. namePrefix.length] = namePrefix[]; // copy the name into the mutable buffer
	buf[namePrefix.length .. namePrefix.length + 6] = "XXXXXX"[];
	buf[namePrefix.length + 6] = 0; // make sure it is zero terminated yourself
	auto tmp = mkstemp(buf.ptr);
	return tmp;
}

/** TODO: Scoped variant of tempfile.
    Search http://forum.dlang.org/thread/mailman.262.1386205638.3242.digitalmars-d-learn@puremagic.com
 */

/** Create a New Temporary Directory Tree.

    Returns: Path to root of tree.
 */
char* temptree(char* name_x, char* template_ = null) @safe {
	return null;
}
