module nxt.patching;

/** Patch file handling.
 */
struct Patch
{
	import nxt.path : Path, DirPath;
	import nxt.cmd : Spawn, writeFlushed, spawn;
	import nxt.logging : LogLevel, defaultLogLevel, trace;
	import std.path : absolutePath;

	Path file;
	uint level;
	LogLevel logLevel;

	this(Path file, in uint level, in bool echoOutErr) @safe
	{
		this.file = file;
		this.level = level;
		this.logLevel = defaultLogLevel;
	}

	Spawn applyIn(in DirPath dir) @trusted
	{
		import std.conv : to;
		import std.stdio : File, stdin, stderr;
		if (logLevel <= LogLevel.trace) trace("Applying patch ", file.str.absolutePath, " at ", dir);
		return spawn(["patch", /+ TODO: can we use execute shell instead? +/
						  "-d", dir.path.str.to!string,
					  "-p" ~ level.to!string],
					 logLevel,
					 stdin, // needs @trusted
					 File(file.str.absolutePath.to!string),
					 stderr); // needs @trusted
	}
}
