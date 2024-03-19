#!/usr/bin/rdmd

import std;

/++ TODO: loop through status of run process and forward stdout and stderr until
    it completes. Currently it waits until the process have completed and then
    prints everything in one go. This is now good from an interactive point of
    view.

    TODO: Remove all .lst files that are not registered by git and end with
	.d is 93% covered\n

	TODO: ../nxt/algorithm/searching.d is 93% covered

	TODO: When -unittest -main is passed to `args`:
	      - Disable networking on Linux by LD_PRELOAD
	      - Generate a main-fail that imports the .d files passed in args and run only the pure unittests
		  - -unitest=attributes:pure
 +/

alias Line = string;

enum Op {
	chk,
	run,
	runAndLint, // Dscanner
	all,
}

enum TaskType {
	chk,
	run,
	lnt, // Dscanner
}

alias Args = const(string)[];

static immutable lstExt = `.lst`;
static immutable dExt = `.d`;

struct Task {
	this(TaskType tt, FileName exe, Args args, DirPath cwd, Redirect redirect) {
		// writeln("In ", cwd, ": ", tt, ": ", (exe.str ~ args).join(' '));
		this.tt = tt;
		this.exe = exe;
		final switch (tt) {
		case TaskType.chk:
			this.args = args.filter!(_ => _ != "-main" && _ != "-run").array ~ [`-o-`];
			break;
		case TaskType.lnt:
			this.args = ["lint", "--styleCheck", "--errorFormat=digitalmars"] ~ args.filter!(_ => _.endsWith(".d") || _.startsWith("-I")).array;
			this.use = true;
			break;
		case TaskType.run:
			this.args = args;
			bool anyMain;
			foreach (const arg; args)
				if (arg.isDMainSansUnittestFile())
					anyMain = true;
			this.use = args.canFind("-run") || !anyMain;
			if (this.use)
				this.args ~= args ~ "-d"; // hide deprecations already shown in chk
			break;
		}
		this.cwd = cwd;
		auto ppArgs = exe.str ~ this.args;
		// writeln("args:", ppArgs.join(' '));
		this.redirect = redirect;
		this.pp = pipeProcess(ppArgs, redirect);
	}
	TaskType tt;
	FileName exe;
	Args args;
	bool use;
	DirPath cwd;
	ProcessPipes pp;
	char[] outLines;
	char[] errLines;
	Redirect redirect;
}

int main(string[] args_) {
	bool selfFlag = false;

	typeof(args_) args;
	foreach (const ref arg; args_) {
		if (arg.baseName.endsWith(__FILE__))
			selfFlag = true;
		if (const split = arg.findSplitAfter("-I"))
			args ~= split[0] ~ split[1].expandTilde;
		else
			args ~= arg;
	}

	// Flags:
	const op = Op.runAndLint;
	const cwd = DirPath(getcwd);

	const ldmd2X = FileName(findExecutable(FileName(`ldmd2`)) ? `ldmd2` : []);
	const dmdX = FileName(findExecutable(FileName(`dmd`)) ? `dmd` : []);
	const lntX = FileName(findExecutable(FileName(`dscanner`)) ? `dscanner` : []);

	const chkOn = (op == Op.chk || op == Op.all);
	const runOn = (op == Op.runAndLint || op == Op.run || op == Op.all) && !selfFlag;
	const lntOn = (op == Op.runAndLint || op == Op.all) && lntX;
	const redirect = (op == Op.all) ? Redirect.all : Redirect.init;

	// ldmd2 fastest at check
	auto chk = chkOn ? Task(TaskType.chk, either(ldmd2X, dmdX), args[1 .. $], cwd, redirect) : Task.init;
	// dmd fastest at build
	auto run = runOn ? Task(TaskType.run, either(dmdX, ldmd2X), args[1 .. $], cwd, redirect) : Task.init;
	auto lnt = lntOn ? Task(TaskType.lnt, lntX, args[1 .. $], cwd, Redirect.all) : Task.init;

	int chkRet;
	if (chk.use) {
		chkRet = chk.pp.pid.wait();
		if (redirect != Redirect.init) {
			chk.outLines = chk.pp.stdout.byLine.join('\n');
			chk.errLines = chk.pp.stderr.byLine.join('\n');
			if (chk.outLines.length)
				stdout.writeln(chk.outLines);
			if (chk.errLines.length)
				stderr.writeln(chk.errLines);
		}
		if (chkRet)
			return chkRet; // early failure return
	}

	int lntRet;
	if (lnt.use) {
		lntRet = lnt.pp.pid.wait();
		if (lnt.redirect != Redirect.init) {
			foreach (ref outLine; lnt.pp.stdout.byLine)
				if (!outLine.isIgnoredMessage)
					stderr.writeln(outLine); // forward to stderr for now
			foreach (ref errLine; lnt.pp.stderr.byLine)
				if (!errLine.isIgnoredMessage)
					stderr.writeln(errLine); // forward to stderr for now
		}
	}

	int runRet;
	if (run.use) {
		runRet = run.pp.pid.wait();
		if (redirect != Redirect.init) {
			auto runOut = run.pp.stdout.byLine.join('\n');
			auto runErr = run.pp.stderr.byLine.join('\n');
			runOut.skipOver(chk.outLines);
			runErr.skipOver(chk.errLines);
			if (runOut.length)
				stdout.writeln(runOut);
			if (runErr.length)
				stderr.writeln(runErr);
		}
		if (runRet) {
			// don't 'return runRet here to let lntRet complete
		}

		// TODO: show other files
		if (args.canFind(`-cov`)) {
			// process .lst files
			foreach (const arg; args) {
				if (!arg.endsWith(dExt))
					continue;
				if (arg.isDMainSansUnittestFile()) {
					stderr.writeln(arg, "(", 1, "): Coverage: Skipping analysis because of presence of `main` function and absence of any `unittest`s");
					continue;
				}
				const lst = arg.replace(`/`, `-`).stripExtension ~ lstExt;
				try {
					size_t nr;
					foreach (const line; File(lst).byLine) {
						if (line.startsWith(`0000000|`))
							stderr.writeln(arg, "(", nr + 1, "): Coverage: Line not covered by unitests");
						nr += 1;
					}
				} catch (Exception _) {
					dbg("Missing coverage file, ", lst);
				}
			}

			// clean up .lst files
			foreach (ref de; cwd.str.dirEntries(SpanMode.shallow)) {
				if (!de.isDir && de.name.endsWith(lstExt)) {
					const bn = de.name.baseName;
					if (bn == "__main.lst") {
						de.name.remove();
						continue;
					}
					if (bn.canFind("-")) {
						size_t cnt = 0;
						foreach (const line; File(de.name).byLine) {
							if (line[7] == '|')
								cnt += 1;
						}
						if (cnt >= 1) {
							de.name.remove();
							continue;
						}
					}
				}
			}
		}
	}

	if (chkRet != 0)
		return chkRet;

	if (runRet != 0)
		return runRet;

	// don't care about lntRet for now
	if (lntRet != 0)
		if (lntRet == 1) {
			// don't forward "normal" exit status because it's only a linter
		} else {
			return lntRet;
		}

	return 0;
}

private bool isIgnoredMessage(in char[] msg) pure nothrow @nogc {
	if (msg.canFind("Warning: ")) {
		if (msg.canFind("Public declaration") && msg.canFind("is undocumented"))
			return true;
		if (msg.canFind("Line is longer than") && msg.canFind("characters"))
			return true;
	}
	return false;
}

static bool isDMainSansUnittestFile(in char[] path) {
	if (!path.endsWith(dExt))
		return false;
	const text = path.readText;
	// TODO: process (treesit) nodes of parseTree(text) instead
	return text.canFind("main") && !text.canFind("unittest");
}

void dbg(Args...)(scope auto ref Args args, in string file = __FILE_FULL_PATH__, const uint line = __LINE__) {
	stderr.writeln(file, "(", line, "):", " Debug: ", args, "");
}

private string mkdirRandom() {
    const dirName = buildPath(tempDir(), "xdmd-" ~ randomUUID().toString());
    dirName.mkdirRecurse();
    return dirName;
}

struct Path {
	this(string str) pure nothrow @nogc {
		this.str = str;
	}
	string str;
	bool opCast(T : bool)() const scope pure nothrow @nogc => str !is null;
	string toString() inout return scope @property pure nothrow @nogc => str;
}

/++ File (local) name.
 +/
struct FileName {
	this(string str, in bool normalize = false) pure nothrow @nogc {
		this.str = str;
	}
	string str;
	bool opCast(T : bool)() const scope pure nothrow @nogc => str !is null;
	string toString() inout return scope @property pure nothrow @nogc => str;
}

/++ (Regular) File path.
	See: https://hackage.haskell.org/package/filepath-1.5.0.0/docs/System-FilePath.html#t:FilePath
 +/
struct FilePath {
	this(string str) pure nothrow @nogc {
		this.path = Path(str);
	}
	Path path;
	alias path this;
}

struct DirPath {
	this(string str) pure nothrow @nogc {
		this.path = Path(str);
	}
	Path path;
	alias path this;
}

/++ Find path for `a` (or `FilePath.init` if not found) in `pathVariableName`.
	TODO: Add caching of result and detect changes via inotify.
 +/
private FilePath findExecutable(FileName a, scope const(char)[] pathVariableName = "PATH") {
	return findFileInPath(a, "PATH");
}

/++ Find path for `a` (or `FilePath.init` if not found) in `pathVariableName`.
	TODO: Add caching of result and detect changes via inotify.
 +/
FilePath findFileInPath(FileName a, scope const(char)[] pathVariableName) {
	import std.algorithm : splitter;
	import std.process : environment;
	const envPATH = environment.get(pathVariableName, "");
	foreach (const p; envPATH.splitter(':')) {
		import std.path : buildPath;
		const path = p.buildPath(a.str);
		if (path.exists)
			return FilePath(path); // pick first match
	}
	return typeof(return).init;
}
