module nxt.bylinefast;

import std.stdio : File;
import std.typecons : Flag;

alias KeepTerminator = Flag!"keepTerminator";

/**
   Reads by line in an efficient way (10 times faster than File.byLine from
   std.stdio).  This is accomplished by reading entire buffers (fgetc() is not
   used), and allocating as little as possible.

   The char \n is considered as default separator, removing the previous \r if
   it exists.

   The \n is never returned. The \r is not returned if it was
   part of a \r\n (but it is returned if it was by itself).

   The returned string is always a substring of a temporary buffer, that must
   not be stored. If necessary, you must use str[] or .dup or .idup to copy to
   another string. DIP-25 return qualifier is used in front() to add extra
   checks in @safe callers of front().

   Example:

   File f = File("file.txt");
   foreach (string line; ByLineFast(f)) {
   ...process line...
   //Make a copy:
   string copy = line[];
   }

   The file isn't closed when done iterating, unless it was the only reference to
   the file (same as std.stdio.byLine). (example: ByLineFast(File("file.txt"))).
*/
struct ByLineFast(Char, Terminator)
{
	import core.stdc.string : memmove;
	import std.stdio : fgetc, ungetc;

	File file;
	char[] line;
	bool first_call = true;
	char[] buffer;
	char[] strBuffer;
	const string separator;
	KeepTerminator keepTerminator;

	this(File f,
		 KeepTerminator kt = KeepTerminator.no,
		 string separator = "\n",
		 uint bufferSize = 4096) @safe
	{
		assert(bufferSize > 0);
		file = f;
		this.separator = separator;
		this.keepTerminator = kt;
		buffer.length = bufferSize;
	}

	bool empty() const @property @trusted scope
	{
		// Its important to check "line !is null" instead of
		// "line.length != 0", otherwise, no empty lines can
		// be returned, the iteration would be closed.
		if (line !is null)
		{
			return false;
		}
		if (!file.isOpen)
		{
			// Clean the buffer to avoid pointer false positives:
			(cast(char[])buffer)[] = 0;
			return true;
		}

		// First read. Determine if it's empty and put the char back.
		auto mutableFP = (cast(File*) &file).getFP();
		const c = fgetc(mutableFP);
		if (c == -1)
		{
			// Clean the buffer to avoid pointer false positives:
			(cast(char[])buffer)[] = 0;
			return true;
		}
		if (ungetc(c, mutableFP) != c)
		{
			assert(0, "Bug in cstdlib implementation");
		}
		return false;
	}

	@property char[] front() @safe return scope
	{
		if (first_call)
		{
			popFront();
			first_call = false;
		}
		return line;
	}

	void popFront() @trusted scope
	{
		if (strBuffer.length == 0)
		{
			strBuffer = file.rawRead(buffer);
			if (strBuffer.length == 0)
			{
				file.detach();
				line = null;
				return;
			}
		}

		// import std.string : indexOf; /+ TODO: algorithm indexOf +/
		import nxt.algorithm.searching : indexOf;
		const pos = strBuffer.indexOf(this.separator);
		if (pos != -1)
		{
			if (pos != 0 && strBuffer[pos-1] == '\r')
			{
				line = strBuffer[0 .. (pos-1)];
			}
			else
			{
				line = strBuffer[0 .. pos];
			}
			// Pop the line, skipping the terminator:
			strBuffer = strBuffer[(pos+1) .. $];
		}
		else
		{
			// More needs to be read here. Copy the tail of the buffer
			// to the beginning, and try to read with the empty part of
			// the buffer.
			// If no buffer was left, extend the size of the buffer before
			// reading. If the file has ended, then the line is the entire
			// buffer.

			if (strBuffer.ptr != buffer.ptr)
			{
				// Must use memmove because there might be overlap
				memmove(buffer.ptr, strBuffer.ptr,
						strBuffer.length * char.sizeof);
			}
			const spaceBegin = strBuffer.length;
			if (strBuffer.length == buffer.length)
			{
				// Must extend the buffer to keep reading.
				assumeSafeAppend(buffer);
				buffer.length = buffer.length * 2;
			}
			const readPart = file.rawRead(buffer[spaceBegin .. $]);
			if (readPart.length == 0)
			{
				// End of the file. Return whats in the buffer.
				// The next popFront() will try to read again, and then
				// mark empty condition.
				if (spaceBegin != 0 && buffer[spaceBegin-1] == '\r')
				{
					line = buffer[0 .. spaceBegin-1];
				}
				else
				{
					line = buffer[0 .. spaceBegin];
				}
				strBuffer = null;
				return;
			}
			strBuffer = buffer[0 .. spaceBegin + readPart.length];
			// Now that we have new data in strBuffer, we can go on.
			// If a line isn't found, the buffer will be extended again to read more.
			popFront();
		}
	}
}

auto byLineFast(Terminator = char,
				Char = char)(File f,
							 KeepTerminator keepTerminator = KeepTerminator.no,
							 string separator = "\n",
							 uint bufferSize = 4096) @safe /+ TODO: lookup preferred block type +/
{
	return ByLineFast!(Char, Terminator)(f, keepTerminator, separator, bufferSize);
}

version (none):

version (linux)
unittest {
	import std.stdio: File, writeln;
	import std.algorithm.searching: count;
	import nxt.file : tempFile;
	import std.file : write;

	const path = tempFile("x");

	writeln(path);
	File(path, "wb").write("a\n");

	assert(File(path, "rb").byLineFast.count ==
		   File(path, "rb").byLine.count);
}

unittest {
	import std.stdio: File, writeln;
	import std.algorithm.searching: count;

	const path = "/media/per/NORDLOW_2019-06-/Knowledge/DBpedia/latest/instance_types_en.ttl";

	import std.datetime: StopWatch;

	double d1, d2;

	{
		StopWatch sw;
		sw.start;
		const c1 = File(path).byLine.count;
		sw.stop;
		d1 = sw.peek.msecs;
		writeln("byLine: ", d1, "msecs");
	}

	{
		StopWatch sw;
		sw.start;
		const c2 = File(path).byLineFast.count;
		sw.stop;
		d2 = sw.peek.msecs;
		writeln("byLineFast: ", d2, "msecs");
	}

	writeln("Speed-Up: ", d1 / d2);
}
