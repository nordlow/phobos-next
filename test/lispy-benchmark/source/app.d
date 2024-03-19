import nxt.lispy;

import std.stdio : write, writeln;
import std.file: dirEntries, SpanMode;
import std.conv : to;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.utf;
import std.algorithm.searching : canFind;
import std.path : pathSplitter;

import nxt.algorithm.searching : endsWith;
import nxt.path : DirPath, FilePath, expandTilde;

/** Read all SUO-KIF files (.kif) located under `root`.
 */
void benchmarkSUMOTreeRead(in DirPath root)
{
	auto totalSw = StopWatch(AutoStart.yes);
	auto entries = dirEntries(root.expandTilde.str, SpanMode.breadth, false); // false: skip symlinks
	foreach (dent; entries)
	{
		const file = FilePath(dent.name);
		if (file.str.endsWith(`.kif`) &&
			!file.str.pathSplitter.canFind(`.git`)) // invalid UTF-8 encodings
		{
			try
			{
				benchmarkSUMOFileRead(file);
			}
			catch (std.utf.UTFException e)
			{
				import std.file : read;
				writeln("Failed because of invalid UTF-8 encoding starting with ", file.str.read(16));
			}
		}
	}
	totalSw.stop();
	writeln(`Reading all files took `, totalSw.peek);
}

/** Benchark reading of SUMO `src`. */
void benchmarkSUMOFileRead(FilePath src) @safe
{
	write(`Reading SUO-KIF `, src, ` ... `);
	auto sw = StopWatch(AutoStart.yes);
	auto lfp = LispFileParser(src);
	while (!lfp.empty)
	{
		// writeln(lfp.front);
		lfp.popFront();
	}
	sw.stop();
	writeln(`took `, sw.peek);
}

/** Benchark reading of Emacs-Lisp `src`. */
void benchmarkEmacsLisp(FilePath src) @safe
{
	write(`Reading Emacs-Lisp `, src, ` ... `);
	auto sw = StopWatch(AutoStart.yes);
	auto lfp = LispFileParser(src);
	while (!lfp.empty)
	{
		// writeln(lfp.front);
		lfp.popFront();
	}
	writeln(`took `, sw.peek);
}

void main(string[] args)
{
	benchmarkEmacsLisp(FilePath(`~/Work/knet/knowledge/xlg.el`));
	benchmarkSUMOTreeRead(DirPath(`~/Work/sumo`));
}
