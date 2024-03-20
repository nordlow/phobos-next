/** Scan file/magic/Magdir */
module nxt.magics;

/** Magic Specifier. */
struct Magic
{
	string header;
	string description;
	size_t byteOffset;
}

// version = show;

// import backtrace.backtrace;

/** Scan Directory $(D dir) for file magic. */
void scanMagicFiles(string dir)
{
	import std.file: dirEntries, SpanMode;
	import std.stdio: write, writeln, File;
	import std.array: array;
	import std.range: front, empty;
	import std.algorithm : find;
	import std.ascii: isDigit;
	import std.uni: isAlpha, isWhite;
	import std.algorithm.iteration : splitter;
	import nxt.algorithm.searching : startsWith;
	import nxt.algorithm.mutation : strip;

	size_t baseCount = 0;
	size_t attrCount = 0;

	Magic current;

	foreach (file; dir.dirEntries(SpanMode.depth))
	{
		version (show) writeln(`file: `, file.name);
		foreach (line; File(file).byLine)
		{
			// auto parts = line.splitter("\t");
			auto parts = line.splitter!(isWhite);
			if (!parts.empty) // line contains something
			{
				if (parts.front.startsWith('#')) // if comment
				{
					/* version (show) writeln("comment: ", parts); */
				}
				else			// otherwise magic
				{
					const first = parts.front;
					const firstChar = first.front;
					if (firstChar.isDigit) // base magic
					{
						size_t offset;
						if (first == `0`) // at beginning of file
						{
							offset = 0;
							version (show) write(offset, `-offset-`);
							parts.popFront();
							auto kind = parts.front;
							switch (kind.strip(' '))
							{
								case `string`:
									parts.popFront();
									auto rest = find!(a => !a.empty)(parts); // skip empty strings
									if (!rest.empty)
									{
										auto magic = rest.front;
										/+ TODO: Merge these? +/
										// import std.array: replaceInPlace;
										/* magic = magic.replace(`\ `, ` `); */
										/* magic = magic.replace(`\r`, "\r"); */
										/* magic = magic.replace(`\n`, "\n"); */
										/* magic = magic.replace(`\t`, "\t"); */
										/+ TODO: Replace `\0`, `\1` +/
										/+ TODO: Replace `\OCTAL` with "\OCTAL" +/
										/+ TODO: Replace \0xa +/
										version (show) writeln(kind, `: `, magic);
									}
									break;
								case `regex`:
									parts.popFront();
									auto rest = find!(a => !a.empty)(parts); // skip empty strings
									version (show) writeln(kind, `: `, parts);
									break;
								case `belong`: // big-endian 64-bit
									parts.popFront();
									auto rest = find!(a => !a.empty)(parts); // skip empty strings
									version (show) writeln(kind, `: `, parts);
									break;
								case `lelong`: // little-endian 64-bit
									parts.popFront();
									auto rest = find!(a => !a.empty)(parts); // skip empty strings
									version (show) writeln(kind, `: `, parts);
									break;
								default:
									parts.popFront();
									auto rest = find!(a => !a.empty)(parts); // skip empty strings
									version (show) writeln(kind, `: `, parts);
									break;
							}
							baseCount++;

						}
						else
						{
							version (show) writeln("todo: ", parts);
						}

					}
					else if (firstChar == '>')
					{
						version (show) writeln(`>: `, parts);
						attrCount++;
					}
				}
			}
		}
	}

	version (show) writeln(`Found `, baseCount, ` number of magic bases`);
	version (show) writeln(`Found `, attrCount, ` number of magic attributes`);
}

version (none)
unittest {
	scanMagicFiles(`/home/per/ware/file/magic/Magdir/`);
}
