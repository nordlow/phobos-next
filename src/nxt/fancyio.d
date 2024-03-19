/** Fanzy Pretty Printing to AsciiDoc, HTML, LaTeX, JIRA Wikitext, etc.
 *
 * Copyright: Per Nordlöw 2022-.
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB Per Nordlöw)
 *
 * TODO: Convert `Viz` param to delegate like for
 * `void toString(Sink)(ref scope Sink sink)`
 * for independency on arsd.
 *
 * Rename `pp1` to `ppL` and `pp` to `pp1` where relevant to reduce number of
 * template instantiations. And replace multi-calls to viz.pp() to viz.pp1()
 *
 * TODO: Add tester that prints types from `nxt.geometry`
 *
 * TODO: Remove all restrictions on pp.*Raw.* and call them using ranges such as repeat
 *
 * TODO: Use "alias this" on wrapper structures and test!
 *
 * TODO: How should std.typecons.Tuple be pretty printed?
 *
 * TODO: Add visited member to keeps track of what objects that have been visited
 *
 * TODO: Add asGCCMessage pretty prints
 * seq $PATH, ':', $ROW, ':', $COL, ':', message, '[', $TYPE, ']'
 */
module nxt.fancyio;

version (none) : // TODO: activate

// version = useTerm;
// version = show;

import core.time : Duration;

import std.range.primitives : isInputRange;
import std.traits : isSomeString, Unqual, isArray, isIterable;
import std.stdio : stdout;

/* TODO: Move logic (toHTML) to these deps and remove these imports */
import nxt.color : Color;
import nxt.mathml;
import nxt.lingua;
import nxt.attributes;
import nxt.rational : Rational;

import arsd.terminal : Terminal, ConsoleOutputType, Bright;

/// See_Also: http://forum.dlang.org/thread/fihymjelvnwfevegwryt@forum.dlang.org#post-fihymjelvnwfevegwryt:40forum.dlang.org
template Concise(Tuple)
{
	static if(isTuple!Tuple)
	{
		struct Concise(Tuple)
		{
			Tuple tup;
			alias tup this;
			// should use a better overload
			string toString() const
			{
				auto app = appender!string(); /+ TODO: use array_ex.Array instead +/
				app.put(`(`);
				app.put(to!string(concise(tuple[0])));
				foreach (t; tuple.expand[1 .. $])
				{
					app.put(`, `);
					app.put(to!string(concise(t)));
				}
				app.put(`)`);
				return app.data;
			}
		}
	}
	else
		alias Concise = Tuple;
}

auto concise(T)(T t)
{
	return Concise!T(t);
}

/** Returns: Duration `dur` in a Level-Of-Detail (LOD) string
	representation.
*/
string shortDurationString(in Duration dur) @safe pure nothrow
{
	import std.conv: to;
	immutable weeks = dur.total!`weeks`;
	if (weeks)
	{
		if (weeks < 52)
			return to!string(weeks) ~ ` week` ~ (weeks >= 2 ? `s` : ``);
		else
		{
			immutable years = weeks / 52;
			immutable weeks_rest = weeks % 52;
			return to!string(years) ~ ` year` ~ (years >= 2 ? `s` : ``) ~
			` and ` ~
			to!string(weeks_rest) ~ ` week` ~ (weeks_rest >= 2 ? `s` : ``);
		}
	}
	immutable days = dur.total!`days`;	   if (days)	return to!string(days) ~ ` day` ~ (days >= 2 ? `s` : ``);
	immutable hours = dur.total!`hours`;	 if (hours)   return to!string(hours) ~ ` hour` ~ (hours >= 2 ? `s` : ``);
	immutable minutes = dur.total!`minutes`; if (minutes) return to!string(minutes) ~ ` minute` ~ (minutes >= 2 ? `s` : ``);
	immutable seconds = dur.total!`seconds`; if (seconds) return to!string(seconds) ~ ` second` ~ (seconds >= 2 ? `s` : ``);
	immutable msecs = dur.total!`msecs`;	 if (msecs) return to!string(msecs) ~ ` millisecond` ~ (msecs >= 2 ? `s` : ``);
	immutable usecs = dur.total!`usecs`;	 if (usecs) return to!string(usecs) ~ ` microsecond` ~ (msecs >= 2 ? `s` : ``);
	immutable nsecs = dur.total!`nsecs`;	 return to!string(nsecs) ~ ` nanosecond` ~ (msecs >= 2 ? `s` : ``);
}

/** Visual Form(at). */
enum VizForm
{
	textAsciiDoc,			   // TODO.
	textAsciiDocUTF8,		   // TODO.
	HTML,
	D3js,					   // TODO. See_Also: http://d3js.org/
	LaTeX,					  // TODO.
	jiraWikiMarkup, // TODO. See_Also: https://jira.atlassiana.com/secure/WikiRendererHelpAction.jspa?section=all
	Markdown,	   // TODO.
}

/** Solarized light color theme.
 *
 * Each enumerator is an RGB hex string.
 *
 * TODO: use RGB-type as enumerator instead
 *
 * See_Also: http://ethanschoonover.com/solarized
 */
enum SolarizedLightColorTheme_hexstring
{
	base00  = `657b83`,
	base01  = `586e75`,
	base02  = `073642`,
	base03  = `002b36`,

	base0   = `839496`,
	base1   = `93a1a1`,
	base2   = `eee8d5`,
	base3   = `fdf6e3`,

	yellow  = `b58900`,
	orange  = `cb4b16`,
	red	 = `dc322f`,
	magenta = `d33682`,
	viole   = `6c71c4`,
	blue	= `268bd2`,
	cya	 = `2aa198`,
	gree	= `859900`
}

/** HTML tags with no side-effect when its arguments is empty.
	See_Also: http://www.w3schools.com/html/html_formatting.asp
*/
static immutable nonStateHTMLTags = [`b`, `i`, `strong`, `em`, `sub`, `sup`, `small`, `ins`, `del`, `mark`,
									 `code`, `kbd`, `samp`, `samp`, `var`, `pre`];

static immutable htmlHeader = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<style>

body { font: 10px Verdana, sans-serif; }
hit0 { background-color:#F2B701; border: solid 0px grey; }
hit1 { background-color:#F18204; border: solid 0px grey; }
hit2 { background-color:#F50035; border: solid 0px grey; }
hit3 { background-color:#F5007A; border: solid 0px grey; }
hit4 { background-color:#A449B6; border: solid 0px grey; }
hit5 { background-color:#3A70BB; border: solid 0px grey; }
hit6 { background-color:#0DE7A6; border: solid 0px grey; }
hit7 { background-color:#70AD48; border: solid 0px grey; }

hit_context { background-color:#c0c0c0; border: solid 0px grey; }

code { background-color:#FFFFE0; }

dlang-byte   { background-color:#FFFFE0; }
dlang-short  { background-color:#FFFFE0; }
dlang-int	{ background-color:#FFFFE0; }
dlang-long   { background-color:#FFFFE0; }

dlang-ubyte   { background-color:#FFFFE0; }
dlang-ushort  { background-color:#FFFFE0; }
dlang-uint	{ background-color:#FFFFE0; }
dlang-ulong   { background-color:#FFFFE0; }

dlang-bool   { background-color:#FFFFE0; }

dlang-float  { background-color:#FFFFE0; }
dlang-double { background-color:#FFFFE0; }
dlang-real   { background-color:#FFFFE0; }

dlang-char   { background-color:#FFFFE0; }
dlang-wchar  { background-color:#FFFFE0; }
dlang-dchar  { background-color:#FFFFE0; }

dlang-string  { background-color:#FFFFE0; }
dlang-wstring { background-color:#FFFFE0; }
dlang-dstring { background-color:#FFFFE0; }

td, th { border: 1px solid black; }
table { border-collapse: collapse; }

tr:nth-child(even) { background-color: #EBEBEB; }
tr:nth-child(2n+0) { background: #` ~ SolarizedLightColorTheme_hexstring.base2 ~ `; }
tr:nth-child(2n+1) { background: #` ~ SolarizedLightColorTheme_hexstring.base3 ~ `; }

</style>
</head>
<body>
`;

/** Visual Backend.
 */
class Viz
{
	import std.stdio : IOFile = File;

	IOFile outFile;
	Terminal* term;

	bool treeFlag;
	VizForm form;

	bool colorFlag;
	bool flushNewlines = true;

	/* If any (HTML) tags should be ended with a newline.
	   This increases the readability of generated HTML code.
	 */
	bool newlinedTags = true;

	bool _completed = false;

	this(IOFile outFile,
		 Terminal* term,
		 VizForm form = VizForm.textAsciiDocUTF8,
		 bool treeFlag = true,
		 bool colorFlag = true,
		 bool flushNewlines = true,
		 bool newlinedTags = true,
		)
	{
		this.outFile = outFile;
		this.term = term;
		this.treeFlag = treeFlag;
		this.form = form;
		this.colorFlag = colorFlag;
		this.flushNewlines = flushNewlines;
		this.newlinedTags = newlinedTags;
		if (form == VizForm.HTML)
			ppRaw(this, htmlHeader);
	}

	private void completeIfNeeded()
	{
		if (!_completed)
		{
			if (form == VizForm.HTML)
				ppRaw("</body>\n</html>");
			_completed = true;
			this.outFile.flush();
		}
	}

	/** Put `arg` to `this` without any conversion nor coloring. */
	void ppRaw(T...)(T args)
	{
		foreach (const arg; args)
		{
			if (outFile == stdout)
				term.write(arg); // trick
			else
				outFile.write(arg);
		}
	}

	/** Put `arg` to `this` without any conversion nor coloring. */
	void pplnRaw(T...)(T args)
	{
		foreach (arg; args)
		{
			if (outFile == stdout)
			{
				if (flushNewlines)
					term.writeln(arg);
				else
					term.write(arg, '\n');
			}
			else
			{
				if (flushNewlines)
					outFile.writeln(arg);
				else
					outFile.write(arg, '\n');
			}
		}
	}

	/// Print opening of tag `tag`.
	void ppTagOpen(T, P...)(T tag, P params)
	{
		if (form == VizForm.HTML)
		{
			ppRaw(`<` ~ tag);
			foreach (param; params)
				ppRaw(' ', param);
			ppRaw(`>`);
		}
	}

	/// Print closing of tag `tag`.
	void ppTagClose(T)(T tag)
	{
		immutable arg = (form == VizForm.HTML) ? `</` ~ tag ~ `>` : tag;
		ppRaw(arg);
	}

	/// Print opening of tag `tag` on a separate line.
	void pplnTagOpen(T)(T tag)
	{
		immutable arg = (form == VizForm.HTML) ? `<` ~ tag ~ `>` : tag;
		if (newlinedTags)
			pplnRaw(arg);
		else
			ppRaw(arg);
	}

	/// Print closing of tag `tag` on a separate line.
	void pplnTagClose(T)(T tag)
	{
		immutable arg = (form == VizForm.HTML) ? `</` ~ tag ~ `>` : tag;
		if (newlinedTags)
			pplnRaw(arg);
		else
			ppRaw(arg);
	}

	/** Put `arg` to `viz` possibly with conversion. */
	void ppPut(T)(T arg,
				  bool nbsp = true)
	{
		if (outFile == stdout)
			term.write(arg);
		else
		{
			import nxt.w3c : encodeHTML;
			if (form == VizForm.HTML)
				outFile.write(arg.encodeHTML(nbsp));
			else
				outFile.write(arg);
		}
	}

	/** Put `arg` to `viz` possibly with conversion. */
	void ppPut(T)(Face face,
				  T arg,
				  bool nbsp = true)
	{
		term.setFace(face, colorFlag);
		ppPut(arg, nbsp);
	}

	/** Print `args` tagged as `tag`. */
	void ppTaggedN(Tag, Args...)(in Tag tag, Args args)
	if (isSomeString!Tag)
	{
		import std.algorithm.searching : find;
		static if (args.length == 1 &&
				   isSomeString!(typeof(args[0])))
		{
			import std.string : empty;
			if (form == VizForm.HTML &&
				args[0].empty &&
				!nonStateHTMLTags.find(tag).empty)
				return;		 // skip HTML tags with no content
		}
		if (form == VizForm.HTML)
			ppRaw(`<` ~ tag ~ `>`);
		ppN(args);
		if (form == VizForm.HTML)
			ppRaw(`</` ~ tag ~ `>`);
	}

	/** Print `args` tagged as `tag` on a separate line. */
	void pplnTaggedN(Tag, Args...)(in Tag tag, Args args)
	if (isSomeString!Tag)
	{
		ppTaggedN(tag, args);
		if (newlinedTags)
			pplnRaw(``);
	}

	/+ TODO: Check for MathML support on backend +/
	@property void ppMathML(SomeIntegral)(Rational!SomeIntegral arg)
	{
		ppTagOpen(`math`);
		ppTagOpen(`mfrac`);
		ppTaggedN(`mi`, arg.numerator);
		ppTaggedN(`mi`, arg.denominator);
		ppTagClose(`mfrac`);
		ppTagClose(`math`);
	}

	/** Pretty-Print Single Argument `arg` to Terminal `term`. */
	void pp1(Arg)(Arg arg)
	{
		pp1(0, arg);
	}

	/** Pretty-Print Single Argument `arg` to Terminal `term`. */
	void pp1(Arg)(int depth,
				  Arg arg)
	{
		static if (is(typeof(ppMathML(arg))))
		{
			if (form == VizForm.HTML)
				return ppMathML(arg);
		}
		static if (is(typeof(arg.toMathML)))
		{
			if (form == VizForm.HTML)
				/+ TODO: Check for MathML support on backend +/
				return ppRaw(arg.toMathML);
		}
		static if (is(typeof(arg.toHTML)))
		{
			if (form == VizForm.HTML)
				return ppRaw(arg.toHTML);
		}
		static if (is(typeof(arg.toLaTeX)))
		{
			if (form == VizForm.LaTeX)
				return ppRaw(arg.toLaTeX);
		}

		/* TODO: Check if any member has mmber toMathML if so call it otherwise call
		 * toString. */

		static if (is(Arg == AsWords!(_), _))
		{
			foreach (ix, subArg; arg.args)
			{
				static if (ix >= 1)
					ppRaw(` `); // separator
				pp1(depth + 1, subArg);
			}
		}
		else static if (is(Arg == AsCSL!(_), _))
		{
			foreach (ix, subArg; arg.args)
			{
				static if (ix >= 1)
					pp1(depth + 1, `,`); // separator
				static if (isInputRange!(typeof(subArg)))
					foreach (subsubArg; subArg)
						ppN(subsubArg, `,`);
			}
		}
		else static if (is(Arg == AsBold!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`b`, arg.args);
			else if (form == VizForm.Markdown)
			{
				ppRaw(`**`);
				ppN(arg.args);
				ppRaw(`**`);
			}
		}
		else static if (is(Arg == AsItalic!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`i`, arg.args);
			else if (form == VizForm.Markdown)
			{
				ppRaw(`*`);
				ppN(arg.args);
				ppRaw(`*`);
			}
		}
		else static if (is(Arg == AsMonospaced!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`tt`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`{{`);
				ppN(arg.args);
				ppRaw(`}}`);
			}
			else if (form == VizForm.Markdown)
			{
				ppRaw('`');
				ppN(arg.args);
				ppRaw('`');
			}
		}
		else static if (is(Arg == AsCode!(_), _))
		{
			if	  (form == VizForm.HTML)
			{
				/* TODO: Use arg.language member to highlight using fs tokenizers
				 * which must be moved out of fs. */
				ppTaggedN(`code`, arg.args);
			}
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(arg.language ? `{code:` ~ arg.language ~ `}` : `{code}`);
				ppN(arg.args);
				ppRaw(`{code}`);
			}
		}
		else static if (is(Arg == AsEmphasized!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`em`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`_`);
				ppN(arg.args);
				ppRaw(`_`);
			}
			else if (form == VizForm.Markdown)
			{
				ppRaw(`_`);
				ppN(arg.args);
				ppRaw(`_`);
			}
		}
		else static if (is(Arg == AsStronglyEmphasized!(_), _))
		{
			if (form == VizForm.Markdown)
			{
				ppRaw(`__`);
				ppN(arg.args);
				ppRaw(`__`);
			}
		}
		else static if (is(Arg == AsStrong!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`strong`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`*`);
				ppN(arg.args);
				ppRaw(`*`);
			}
		}
		else static if (is(Arg == AsCitation!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`cite`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`??`);
				ppN(arg.args);
				ppRaw(`??`);
			}
		}
		else static if (is(Arg == AsDeleted!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`deleted`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`-`);
				ppN(arg.args);
				ppRaw(`-`);
			}
		}
		else static if (is(Arg == AsInserted!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`inserted`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`+`);
				ppN(arg.args);
				ppRaw(`+`);
			}
		}
		else static if (is(Arg == AsSuperscript!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`sup`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`^`);
				ppN(arg.args);
				ppRaw(`^`);
			}
		}
		else static if (is(Arg == AsSubscript!(_), _))
		{
			if	  (form == VizForm.HTML)
				ppTaggedN(`sub`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`~`);
				ppN(arg.args);
				ppRaw(`~`);
			}
		}
		else static if (is(Arg == AsPreformatted!(_), _))
		{
			if	  (form == VizForm.HTML)
			{
				pplnTagOpen(`pre`);
				ppN(arg.args);
				pplnTagClose(`pre`);
			}
			else if (form == VizForm.jiraWikiMarkup)
			{
				pplnRaw(`{noformat}`);
				ppN(arg.args);
				pplnRaw(`{noformat}`);
			}
		}
		else static if (is(Arg == AsHeader!(_), _))
		{
			import std.conv: to;
			if	  (form == VizForm.HTML)
				pplnTaggedN(`h` ~ to!string(arg.level),
							arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`h` ~ to!string(arg.level) ~ `. `);
				ppN(arg.args);
				pplnRaw(``);
			}
			else if (form == VizForm.Markdown)
			{
				foreach (_; 0 .. arg.level)
					pp1(0, `#`);
				ppN(` `, arg.args);
				pplnRaw(``);
			}
			else if (form == VizForm.textAsciiDoc ||
					 form == VizForm.textAsciiDocUTF8)
			{
				ppRaw('\n');
				foreach (_; 0 .. arg.level)
					pp1(0, `=`);
				ppN(' ', arg.args, ' ');
				foreach (_; 0 .. arg.level)
					pp1(0, `=`);
				ppRaw('\n');
			}
		}
		else static if (is(Arg == AsParagraph!(_), _))
		{
			if (form == VizForm.HTML)
				pplnTaggedN(`p`, arg.args);
			else if (form == VizForm.LaTeX)
			{
				ppRaw(`\par `);
				pplnTaggedN(arg.args);
			}
			else if (form == VizForm.textAsciiDoc ||
					 form == VizForm.textAsciiDocUTF8)
			{
				ppRaw('\n');
				foreach (_; 0 .. arg.level)
					pp1(0, `=`);
				ppN(` `, arg.args, ` `, tag, '\n');
			}
		}
		else static if (is(Arg == AsBlockquote!(_), _))
		{
			if (form == VizForm.HTML)
				pplnTaggedN(`blockquote`, arg.args);
			else if (form == VizForm.jiraWikiMarkup)
			{
				pplnRaw(`{quote}`);
				pplnRaw(arg.args);
				pplnRaw(`{quote}`);
			}
			else if (form == VizForm.Markdown)
			{
				foreach (subArg; arg.args)
					pplnRaw(`> `, subArg); /+ TODO: Iterate for each line in subArg +/
			}
		}
		else static if (is(Arg == AsBlockquoteSP!(_), _))
		{
			if (form == VizForm.jiraWikiMarkup)
			{
				ppRaw(`bq. `);
				ppN(arg.args);
				pplnRaw(``);
			}
		}
		else static if (is(HorizontalRuler == Arg))
		{
			if (form == VizForm.HTML)
				pplnTagOpen(`hr`);
			else if (form == VizForm.jiraWikiMarkup)
				pplnRaw(`----`);
		}
		else static if (is(Arg == MDash!(_), _))
		{
			if (form == VizForm.HTML)
				ppRaw(`&mdash;`);
			else if (form == VizForm.jiraWikiMarkup ||
					 form == VizForm.Markdown ||
					 form == VizForm.LaTeX)
			{
				pplnRaw(`---`);
			}
		}
		else static if (is(Arg == AsUList!(_), _))
		{
			if (form == VizForm.HTML)
				pplnTagOpen(`ul`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\begin{enumerate}`);
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`ul`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\end{enumerate}`);
		}
		else static if (is(Arg == AsOList!(_), _))
		{
			if (form == VizForm.HTML)
				pplnTagOpen(`ol`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\begin{itemize}`);
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`ol`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\end{itemize}`);
		}
		else static if (is(Arg == AsDescription!(_), _)) // if args .length == 1 && an InputRange of 2-tuples pairs
		{
			if (form == VizForm.HTML)
				pplnTagOpen(`dl`); /+ TODO: TERM <dt>, DEFINITION <dd> +/
			else if (form == VizForm.LaTeX)
				pplnRaw(`\begin{description}`); /+ TODO: \item[TERM] DEFINITION +/
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`dl`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\end{description}`);
		}
		else static if (is(Arg == AsTable!(_), _))
		{
			if (form == VizForm.HTML)
			{
				const border = (arg.border ? ` border=` ~ arg.border : ``);
				pplnTagOpen(`table` ~ border);
			}
			else if (form == VizForm.LaTeX)
				pplnRaw(`\begin{tabular}`);

			static if (arg.args.length == 1 &&
					   isIterable!(typeof(arg.args[0])))
			{
				auto rows = arg.args[0].asRows();
				rows.recurseFlag = arg.recurseFlag; // propagate
				rows.rowNr = arg.rowNr;
				ppNFlushed(rows);
			}
			else
				ppN(arg.args);

			if (form == VizForm.HTML)
				pplnTagClose(`table`);
			else if (form == VizForm.LaTeX)
				pplnRaw(`\end{tabular}`);
		}
		else static if (is(Arg == AsRows!(_), _) &&
						arg.args.length == 1 &&
						isIterable!(typeof(arg.args[0])))
		{
			bool capitalizeHeadings = true;

			/* See_Also: http://forum.dlang.org/thread/wjksldfpkpenoskvhsqa@forum.dlang.org#post-jwfildowqrbwtamywsmy:40forum.dlang.org */

			// use aggregate members as header
			import std.range.primitives : ElementType;
			alias Front = ElementType!(typeof(arg.args[0]));
			static if (is(Front == struct) ||
					   is(Front == union) ||
					   is(Front == class) ||
					   is(Front == interface)) // isAggregateType
			{
				/* TODO: When __traits(documentation,x)
				   here https://github.com/D-Programming-Language/dmd/pull/3531
				   get merged use it! */
				// pplnTaggedN(`tr`, subArg.asCols); /+ TODO: asItalic +/
				// Use __traits(allMembers, T) instead
				// Can we lookup file and line of user defined types aswell?

				// member names header.
				if (form == VizForm.HTML)
					pplnTagOpen(`tr`); /+ TODO: Functionize +/

				// index column
				if	  (arg.rowNr == RowNr.offsetZero)
					pplnTaggedN(`td`, `0-Offset`);
				else if (arg.rowNr == RowNr.offsetOne)
					pplnTaggedN(`td`, `1-Offset`);
				foreach (const ix, Member; typeof(Front.tupleof))
				{
					import std.ascii : isUpper; /+ TODO: support ASCII in fast path and Unicode in slow path +/
					import std.string : capitalize;
					import std.algorithm.iteration : joiner;

					static	  if (is(Memb == struct))	immutable qual = `struct `;
					else static if (is(Memb == class))	 immutable qual = `class `;
					else static if (is(Memb == enum))	  immutable qual = `enum `;
					else static if (is(Memb == interface)) immutable qual = `interface `;
					else								   immutable qual = ``; /+ TODO: Are there more qualifiers +/

					import std.algorithm.iteration : map;
					import nxt.slicing : preSlicer;
					immutable idName = __traits(identifier, Front.tupleof[ix]).preSlicer!isUpper.map!capitalize.joiner(` `); /+ TODO: reuse `nxt.casing.camelCasedToLowerSpaced` +/
					immutable typeName = Unqual!(Member).stringof; // constness of no interest here

					pplnTaggedN(`td`,
								idName.asItalic.asBold,
								`<br>`,
								qual.asKeyword,
								typeName.asType);
				}
				if (form == VizForm.HTML)
					pplnTagClose(`tr`);
			}

			size_t ix = 0;
			foreach (subArg; arg.args[0]) // for each table row
			{
				auto cols = subArg.asCols();
				cols.recurseFlag = arg.recurseFlag; // propagate
				cols.rowNr = arg.rowNr;
				cols.rowIx = ix;
				pplnTaggedN(`tr`, cols); // print columns
				ix++;
			}
		}
		else static if (is(Arg == AsCols!(_), _))
		{
			alias T_ = typeof(arg.args[0]);
			if (arg.args.length == 1 &&
				(is(T_ == struct) ||
				 is(T_ == class) ||
				 is(T_ == union) ||
				 is(T_ == interface))) // isAggregateType
			{
				auto args0 = arg.args[0];
				if (form == VizForm.jiraWikiMarkup)
				{
					/* if (args0.length >= 1) { ppRaw(`|`); } */
				}
				if	  (arg.rowNr == RowNr.offsetZero)
					pplnTaggedN(`td`, arg.rowIx + 0);
				else if (arg.rowNr == RowNr.offsetOne)
					pplnTaggedN(`td`, arg.rowIx + 1);
				foreach (subArg; args0.tupleof) // for each table column
				{
					if (form == VizForm.HTML)
						pplnTaggedN(`td`, subArg); // each element in aggregate as a column
					else if (form == VizForm.jiraWikiMarkup)
					{
						/* pp1(subArg); ppRaw(`|`); */
					}
				}
			}
			else
				pplnTaggedN(`tr`, arg.args);
		}
		else static if (is(Arg == AsRow!(_), _))
		{
			string spanArg;
			static if (arg.args.length == 1 &&
					   is(typeof(arg.args[0] == Span!(_), _)))
				spanArg ~= ` rowspan="` ~ to!string(arg._span) ~ `"`;
			if (form == VizForm.HTML)
				pplnTagOpen(`tr` ~ spanArg);
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`tr`);
		}
		else static if (is(Arg == AsCell!(_), _))
		{
			string spanArg;
			static if (arg.args.length != 0 &&
					   is(typeof(arg.args[0] == Span!(_), _)))
				spanArg ~= ` colspan="` ~ to!string(arg._span) ~ `"`;
			if (form == VizForm.HTML)
				ppTagOpen(`td` ~ spanArg);
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`td`);
		}
		else static if (is(Arg == AsTHeading!(_), _))
		{
			if (form == VizForm.HTML)
			{
				pplnTagOpen(`th`);
				ppN(arg.args);
				pplnTagClose(`th`);
			}
			else if (form == VizForm.jiraWikiMarkup)
			{
				if (args.length != 0)
					ppRaw(`||`);
				foreach (subArg; args)
				{
					pp1(subArg);
					ppRaw(`||`);
				}
			}
		}
		else static if (is(Arg == AsItem!(_), _))
		{
			if (form == VizForm.HTML)
				ppTagOpen(`li`);
			else if (form == VizForm.textAsciiDoc)
				ppRaw(` - `);   // if inside ordered list use . instead of -
			else if (form == VizForm.LaTeX)
				ppRaw(`\item `);
			else if (form == VizForm.textAsciiDocUTF8)
				ppRaw(` • `);
			else if (form == VizForm.Markdown)
				ppRaw(`* `); /+ TODO: Alternatively +,-,*, or 1. TODO: Need counter for ordered lists +/
			ppN(arg.args);
			if (form == VizForm.HTML)
				pplnTagClose(`li`);
			else if (form == VizForm.LaTeX)
				pplnRaw(``);
			else if (form == VizForm.textAsciiDoc ||
					 form == VizForm.textAsciiDocUTF8 ||
					 form == VizForm.Markdown)
				pplnRaw(``);
		}
		else static if (is(Arg == AsPath!(_), _) ||
						is(Arg == AsURL!(_), _))
		{
			auto vizArg = this;
			vizArg.treeFlag = false;

			enum isString = isSomeString!(typeof(arg.arg)); // only create hyperlink if arg is a string

			static if (isString)
				if (form == VizForm.HTML)
				{
					static if (is(Arg == AsPath!(_), _))
						ppTagOpen(`a href="file://` ~ arg.arg ~ `"`);
					else static if (is(Arg == AsURL!(_), _))
						ppTagOpen(`a href="` ~ arg.arg ~ `"`);
				}

			vizArg.pp1(depth + 1, arg.arg);

			static if (isString)
				if (form == VizForm.HTML)
					ppTagClose(`a`);
		}
		else static if (is(Arg == AsName!(_), _))
		{
			auto vizArg = viz;
			vizArg.treeFlag = true;
			pp1(term, vizArg, depth + 1, arg.arg);
		}
		// else static if (is(Arg == AsHit!(_), _))
		// {
		//	 const ixs = to!string(arg.ix);
		//	 if (form == VizForm.HTML) { ppTagOpen(`hit` ~ ixs); }
		//	 pp1(depth + 1, arg.args);
		//	 if (form == VizForm.HTML) { ppTagClose(`hit` ~ ixs); }
		// }
		// else static if (is(Arg == AsCtx!(_), _))
		// {
		//	 if (form == VizForm.HTML) { ppTagOpen(`hit_context`); }
		//	 pp1(depth + 1, arg.args);
		//	 if (form == VizForm.HTML) { ppTagClose(`hit_context`); }
		// }
		else static if (isArray!Arg &&
						!isSomeString!Arg)
		{
			ppRaw(`[`);
			foreach (ix, subArg; arg)
			{
				if (ix >= 1)
					ppRaw(`,`); // separator
				pp1(depth + 1, subArg);
			}
			ppRaw(`]`);
		}
		else static if (isInputRange!Arg)
		{
			foreach (subArg; arg)
				pp1(depth + 1, subArg);
		}
		else static if (__traits(hasMember, arg, `parent`)) /+ TODO: Use isFile = File or NonNull!File +/
		{
			import std.path: dirSeparator;
			if (form == VizForm.HTML)
			{
				ppRaw(`<a href="file://`);
				ppPut(arg.path);
				ppRaw(`">`);
			}

			if (!treeFlag)
			{
				// write parent path
				foreach (parent; arg.parents)
				{
					ppPut(dirSeparator);
					if (form == VizForm.HTML)
						ppTagOpen(`b`);
					ppPut(dirFace, parent.name);
					if (form == VizForm.HTML)
						ppTagClose(`b`);
				}
				ppPut(dirSeparator);
			}

			// write name
			static if (__traits(hasMember, arg, `isRoot`)) /+ TODO: Use isDir = Dir or NonNull!Dir +/
				immutable name = arg.isRoot ? dirSeparator : arg.name ~ dirSeparator;
			else
				immutable name = arg.name;

			if (form == VizForm.HTML)
			{
				// static	  if (isSymlink!Arg) { ppTagOpen(`i`); }
				// static if (isDir!Arg) { ppTagOpen(`b`); }
			}

			ppPut(arg.getFace(), name);

			if (form == VizForm.HTML)
			{
				// static	  if (isSymlink!Arg) { ppTagClose(`i`); }
				// static if (isDir!Arg) { ppTagClose(`b`); }
			}

			if (form == VizForm.HTML)
				ppTagClose(`a`);
		}
		else
		{
			static if (__traits(hasMember, arg, `path`))
				const arg_string = arg.path;
			else
			{
				import std.conv: to;
				const arg_string = to!string(arg);
			}

			static if (__traits(hasMember, arg, `face`) &&
					   __traits(hasMember, arg.face, `tagsHTML`))
			{
				if (form == VizForm.HTML)
					foreach (tag; arg.face.tagsHTML)
						outFile.write(`<`, tag, `>`);
			}

			// write
			term.setFace(arg.getFace(), colorFlag);
			if (outFile == stdout)
				term.write(arg_string);
			else
				ppPut(arg.getFace(), arg_string);

			static if (__traits(hasMember, arg, `face`) &&
					   __traits(hasMember, arg.face, `tagsHTML`))
			{
				if (form == VizForm.HTML)
					foreach (tag; arg.face.tagsHTML)
						outFile.write(`</`, tag, `>`);
			}
		}
	}

	/** Pretty-Print Multiple Arguments `args` to Terminal `term`. */
	void ppN(Args...)(Args args)
	{
		foreach (arg; args)
			pp1(0, arg);
	}

	/** Pretty-Print Arguments `args` to Terminal `term` without Line Termination. */
	void ppNFlushed(Args...)(Args args)
	{
		ppN(args);
		if (outFile == stdout)
			term.flush();
	}

	/** Pretty-Print Arguments `args` including final line termination. */
	void ppln(Args...)(Args args)
	{
		ppN(args);
		if (outFile == stdout)
		{
			term.writeln(lbr(form == VizForm.HTML));
			term.flush();
		}
		else
			outFile.writeln(lbr(form == VizForm.HTML));
	}

	/** Pretty-Print Arguments `args` each including a final line termination. */
	void pplns(Args...)(Args args)
	{
		foreach (arg; args)
			ppln(args);
	}

	/** Print End of Line to Terminal `term`. */
	void ppendl()
	{
		ppln(``);
	}

}

/// Face with color of type `SomeColor`.
struct Face
{
	this(Color foregroundColor,
		 Color backgroundColor,
		 bool bright = false,
		 bool italic = false,
		 string[] tagsHTML = [])
	{
		this.foregroundColor = foregroundColor;
		this.backgroundColor = backgroundColor;
		this.bright = bright;
		this.tagsHTML = tagsHTML;
	}
	string[] tagsHTML;
	Color foregroundColor;
	Color backgroundColor;
	bool bright;
	bool italic;
}

// Faces (Font/Color)
enum stdFace = Face(Color.white, Color.black);
enum pathFace = Face(Color.green, Color.black, true);

enum dirFace = Face(Color.blue, Color.black, true);
enum fileFace = Face(Color.magenta, Color.black, true);
enum baseNameFace = fileFace;
enum specialFileFace = Face(Color.red, Color.black, true);
enum regFileFace = Face(Color.white, Color.black, true, false, [`b`]);
enum symlinkFace = Face(Color.cyan, Color.black, true, true, [`i`]);
enum symlinkBrokenFace = Face(Color.red, Color.black, true, true, [`i`]);
enum missingSymlinkTargetFace = Face(Color.red, Color.black, false, true, [`i`]);

enum contextFace = Face(Color.green, Color.black);

enum timeFace = Face(Color.magenta, Color.black);
enum digestFace = Face(Color.yellow, Color.black);

enum infoFace = Face(Color.white, Color.black, true);
enum warnFace = Face(Color.yellow, Color.black);
enum kindFace = warnFace;
enum errorFace = Face(Color.red, Color.black);

enum titleFace = Face(Color.white, Color.black, false, false, [`title`]);
enum h1Face = Face(Color.white, Color.black, false, false, [`h1`]);

// Support these as immutable

/** Key (Hit) Face Palette. */
enum ctxFaces = [Face(Color.red, Color.black),
				 Face(Color.green, Color.black),
				 Face(Color.blue, Color.black),
				 Face(Color.cyan, Color.black),
				 Face(Color.magenta, Color.black),
				 Face(Color.yellow, Color.black),
	];

import std.algorithm.iteration : map;

/** Key (Hit) Faces. */
enum keyFaces = ctxFaces.map!(a => Face(a.foregroundColor, a.backgroundColor, true)); /+ TODO: avoid map +/

void setFace(Term, Face)(ref Term term,
						 Face face,
						 bool colorFlag)
{
	if (colorFlag)
	{
		version (useTerm)
			term.color(face.foregroundColor | (face.bright ? Bright : 0) ,
					   face.backgroundColor);
	}
}

/** Fazed (Rich) Text. */
struct Fazed(T)
{
	T text;
	const Face face;
	string toString() const return scope @property pure nothrow
	{
		import std.conv : to;
		return to!string(text);
	}
}
auto faze(T)(T text, in Face face = stdFace) @safe pure nothrow
{
	return Fazed!T(text, face);
}

auto getFace(Arg)(in Arg arg) @safe pure nothrow
{
	// pick face
	static if (__traits(hasMember, arg, `face`))
		return arg.face;
	// else static if (is(Arg == Digest!(_), _)) // instead of is(Unqual!(Arg) == SHA1Digest)
	// {
	//	 return digestFace;
	// }
	// else static if (is(Arg == AsHit!(_), _))
	// {
	//	 return keyFaces.cycle[arg.ix];
	// }
	// else static if (is(Arg == AsCtx!(_), _))
	// {
	//	 return ctxFaces.cycle[arg.ix];
	// }
	else
		return stdFace;
}

/** Show `viz`.
 */
void show(Viz viz)
{
	viz.completeIfNeeded();
	import std.process : spawnProcess, wait;
	auto pid = spawnProcess([`xdg-open`, viz.outFile.name]);
	assert(wait(pid) == 0);
}

version (show)
unittest {
	import std.algorithm.iteration : map;

	const outPath = `/tmp/fs-` ~ randomUUID.toString() ~ `.` ~ `html`; // reuse `nxt.tempfs`
	File outFile = File(outPath, `w`);

	auto term = Terminal(ConsoleOutputType.linear);

	auto viz = new Viz(outFile, &term, VizForm.HTML);

	viz.pp1(`Pretty Printing`.asH!1);
	viz.pp1(horizontalRuler);

	viz.pp1(`First Heading`.asH!2);
	viz.ppln(`Something first.`);

	viz.pp1(`Second Heading`.asH!2);
	viz.ppln(`Something else.`);

	struct S
	{
		string theUnit;
		int theSuperValue;
	}

	S[] s = [S("meter", 42),
			 S("second", 43)];

	viz.pp1("Struct Array".asH!2);
	viz.pp1(s.asTable);

	viz.pp1("Map Struct Array".asH!2);
	viz.pp1(s.map!(_ => S(_.theUnit,
						  _.theSuperValue^^2)).asTable);

	viz.pp1("Rational Number Array".asH!2);
	viz.pp1([rational(11, 13),
			 rational(14, 15),
			 rational(17, 32)]);

	struct NamedRational
	{
		string name;
		Rational!long value;
	}

	viz.pp1("Named Rational Number Array as Table".asH!2);
	viz.pp1([NamedRational("x", Rational!long(11, 13)),
			 NamedRational("y", Rational!long(111, 133)),
			 NamedRational("z", Rational!long(1111, 1333))].asTable);
	viz.show();
}

version (unittest)
{
	/+ TODO: hide these stuff in constructor for Viz +/
	import std.uuid : randomUUID;
	import std.stdio : File;
	import nxt.rational : rational;
}
