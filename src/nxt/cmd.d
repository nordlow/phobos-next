/** Wrappers around commands such `git`, `patch`, etc.
 *
 * Original version https://gist.github.com/PetarKirov/b4c8b64e7fc9bb7391901bcb541ddf3a
 *
 * See_Also: https://github.com/CyberShadow/ae/blob/master/sys/git.d
 * See_Also: https://forum.dlang.org/post/ziqgqpkdjolplyfztulp@forum.dlang.org
 *
 * TODO: integrate @CyberShadow’s ae.sys.git at ae/sys/git.d
 */
module nxt.cmd;

import std.exception : enforce;
import std.format : format;
import std.file : exists, isDir, isFile;
import std.path : absolutePath, buildNormalizedPath, dirName, relativePath;
import std.stdio : write, writeln, writefln, File, stdin, stdout, stderr;
import std.algorithm.mutation : move;
import nxt.logging : LogLevel, defaultLogLevel, trace, info, warning, error;

@safe:

ExitStatus exitMessage(ExitStatus code) => typeof(return)(code);

/** Process exit status (code).
 *
 * See: https://en.wikipedia.org/wiki/Exit_status
 */
struct ExitStatus
{
	int value;
	alias value this;
}

/** Process spawn state.
	Action accessing predeclared file system resources.
 */
struct Spawn
{
	import std.process : Pid;

	this(Pid pid, File input_, File out_, File err_, in LogLevel logLevel = defaultLogLevel)
		in(input_.isOpen)
		in(out_.isOpen)
		in(err_.isOpen) {
		this.pid = pid;
		this.input = input_;
		this.output = out_;
		this.error = err_;
		this.logLevel = logLevel;
	}

	this(this) @disable;		// avoid copying `File`s for now

	auto ref setLogLevel(in LogLevel logLevel) scope pure nothrow @nogc {
		this.logLevel = logLevel;
		return this;
	}

	ExitStatus wait() {
		if (logLevel <= LogLevel.trace) .trace("Waiting");

		import std.process : wait;
		auto result = typeof(return)(pid.wait());

		static void echo(ref File src, ref File dst, in string name)
			in(src.isOpen)
			in(dst.isOpen) {
			if (src.eof)
				return; // skip if empty
			writeln("  - ", name, ":");
			src.flush();
			import std.algorithm.mutation: copy;
			writeln("src:",src, "dst:",dst, "stdout:",stdout, "stderr:",stderr);
			() @trusted { src.byLine().copy(dst.lockingBinaryWriter); } (); /+ TODO: writeIndented +/
		}

		if (result == 0) {
			if (logLevel <= LogLevel.trace)
				.trace("Process exited successfully with exitStatus:", result);
		} else {
			if (logLevel <= LogLevel.error)
				.error("Process exited unsuccessfully with exitStatus:", result);
		}

		import std.stdio : stdout, stderr;
		if (result != 0 && logLevel <= LogLevel.info) {
			() @trusted { if (output != stdout) echo(output, stdout, "OUT"); } ();
		}
		if (result != 0 && logLevel <= LogLevel.warning) {
			() @trusted { if (error != stderr) echo(error, stderr, "ERR"); } ();
		}

		return result;
	}

package:
	Pid pid;
	File input;
	File output;
	File error;
	LogLevel logLevel;
}

Spawn spawn(scope const(char[])[] args,
			in LogLevel logLevel = defaultLogLevel,
			File input_ = stdin,
			File out_ = stdout,
			File err_ = stderr) {
	import std.process : spawnProcess;
	if (logLevel <= LogLevel.trace) .trace("Spawning ", args);
	auto pid = spawnProcess(args, input_, out_, err_);
	return typeof(return)(pid, input_, out_, err_, logLevel);
}

/++ Variant of `std.stdio.write` that flushes `stdout` afterwards.
 +/
void writeFlushed(Args...)(scope Args args) {
	import std.stdio : stdout;
	() @trusted { write(args, " ... "); stdout.flush(); } ();
}

/++ Variant of `std.stderr.write` that flushes `stderr` afterwards.
 +/
void ewriteFlushed(Args...)(scope Args args) {
	import std.stdio : stderr;
	() @trusted { stderr.write(args, " ... "); stderr.flush(); } ();
}
