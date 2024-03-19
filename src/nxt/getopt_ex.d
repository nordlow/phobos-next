/** Extensions to getopt
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	TODO: Merge with getoptx.d
*/
module nxt.getopt_ex;

import std.stdio;
public import std.getopt;

// private import std.contracts;
private import std.meta : AliasSeq;
private import std.conv;

bool getoptEx(T...)(string helphdr, ref string[] args, T opts)
{
	assert(args.length,
			"Invalid arguments string passed: program name missing");

	string helpMsg = getoptHelp(opts); // extract all help strings
	bool helpPrinted = false; // state tells if called with "--help"
	void printHelp()
	{
		writeln("\n", helphdr, "\n", helpMsg,
				"--help", "\n\tproduce help message");
		helpPrinted = true;
	}

	getopt(args, GetoptEx!(opts), "help", &printHelp);

	return helpPrinted;
}

private template GetoptEx(TList...)
{
	static if (TList.length)
	{
		static if (is(typeof(TList[0]) : config))
			// it's a configuration flag, lets move on
			alias AliasSeq!(TList[0],
							GetoptEx!(TList[1 .. $])) GetoptEx;
		else
			// it's an option string, eat help string
			alias AliasSeq!(TList[0],
							TList[2],
							GetoptEx!(TList[3 .. $])) GetoptEx;
	}
	else
		alias TList GetoptEx;
}

private string getoptHelp(T...)(T opts)
{
	static if (opts.length)
	{
		static if (is(typeof(opts[0]) : config))
			// it's a configuration flag, skip it
			return getoptHelp(opts[1 .. $]);
		else
		{
			// it's an option string
			string option  = to!(string)(opts[0]);
			string help	= to!(string)(opts[1]);
			return("--" ~ option ~ "\n" ~ help ~ "\n" ~ getoptHelp(opts[3 .. $]));
		}
	}
	else
		return to!(string)("\n");
}
