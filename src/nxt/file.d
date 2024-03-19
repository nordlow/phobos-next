/** FileExtensions to std.file.
	Copyright: Per Nordlöw 2024-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.file;

import std.stdio : File;
import nxt.path : FileName, FilePath, DirPath;
import nxt.pattern : Node;

@safe:

/++ Type of file.
 +/
struct FileType {
	DataFormat format; ///< Format associated with file type.
	alias format this;
	Node fileNamePattern; ///< Pattern matching file name(s) often associated.
}

typeof(FileName.str) matchFirst(scope return /+ref+/ FileName input, const Node node) pure nothrow /+@nogc+/ {
	import nxt.pattern : matchFirst;
	return input.str.matchFirst(node);
}

/++ Get pattern that matches a file name ending with '.'~`s`. +/
static Node fileExtension(string s) pure nothrow {
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
	string name;
	alias name this;
	/// Pattern matching file contents often associated.
	Node contentPattern;
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
	return findFileInPath(a, "PATH");
}

///
version (none)
@safe unittest {
	assert(findExecutable(FileName("ls")) == FilePath("/usr/bin/ls"));
}

/++ Find path for `a` (or `FilePath.init` if not found) in `pathVariableName`.
	TODO: Add caching of result and detect changes via inotify.
 +/
FilePath findFileInPath(FileName a, scope const(char)[] pathVariableName) {
	import std.algorithm : splitter;
	import std.process : environment;
	const envPATH = environment.get(pathVariableName, "");
	foreach (const p; envPATH.splitter(':')) {
		import nxt.path : buildPath, exists;
		const path = DirPath(p).buildPath(a);
		if (path.exists)
			return path; // pick first match
	}
	return typeof(return).init;
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
    throw new Exception("Home directory environment variable is not set.");
}

///
@safe unittest {
	version (Posix) {
		import std.path : expandTilde;
		assert(homeDir().str == "~".expandTilde);
	}
}
