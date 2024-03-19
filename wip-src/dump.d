/** User-friendly dump.
 *
 * See_Also: https://github.com/dlang/phobos/pull/4318
 */
module nxt.dump;

import std.exception : enforce;
import std.traits : isCallable, ReturnType;
import std.range.primitives : isOutputRange, empty, put;
import std.format : formatValue, FormatSpec, FormatException;

private alias enforceFmt = enforce!FormatException;

/**
   Pretty-print variables with name and values.
   It can print will print all compile-time and runtime arguments.
   The first runtime argument can be a custom OutputRange. The following argument can
   be a custom format can be given in the $(LREF format) Syntax, where the first
   value is the name of the variable (or number for runtime arguments), the second
   it's value and the third it's type. Positional specifier can be used too.
   If no OutputRange is given, a `string` will be returned.
   Callable objects will be evaluated.
   Params:
   T = names of the variables to print
   w = The $(D OutputRange) to write to.
   fmt = The format of the data to read.
   xs = runtime arguments to print
   Returns:
   `void` if an output range was provided as first runtime argument and a `string`
   otherwise.
*/
template dump(T...)
{
	// formats compile-time parameters
	private void dumpCT(Writer, Char)(Writer w, in Char[] fmt, bool printLastSeparator)
	if (isOutputRange!(Writer, string))
	{
		alias FPfmt = void delegate(Writer wr) @safe;
		enum lengthMax = 3;

		foreach (k, el; T)
		{
			auto spec = FormatSpec!Char(fmt);

			// we expose three variables: name, value and typo
			FPfmt[lengthMax] funs;

			// special case for lambdas/alias functions
			static if (isCallable!el)
			{
				funs[0] = (Writer wr) { formatValue(wr, "()", spec); };
				funs[1] = (Writer wr) { formatValue(wr, el(), spec); };
				funs[2] = (Writer wr) {
					formatValue(wr, ReturnType!(typeof(el)).stringof, spec);
				};
			}
			else
			{
				funs[0] = (Writer wr) { formatValue(wr, T[k].stringof, spec); };
				funs[1] = (Writer wr) { formatValue(wr, el, spec); };
				funs[2] = (Writer wr) {
					formatValue(wr, typeof(el).stringof, spec);
				};
			}

			applySpecToFunctions(w, spec, funs);

			// don't print the trailing bit for the last function except we have
			// runtime arguments too
			if (k < T.length - 1 || printLastSeparator)
				w.put(spec.trailing);
		}
	}

	void dump(Writer, Char, Xs...)(Writer w, in Char[] fmt, lazy Xs xs)
	if (isOutputRange!(Writer, string))
	{
		static if (T.length > 0)
			dumpCT(w, fmt, Xs.length > 0);

		static if (Xs.length > 0)
			dumpRuntime(w, fmt, xs);
	}

	// if no writer passed, return string
	string dump(Char, Xs...)(in Char[] fmt, lazy Xs xs)
	{
		import std.array : appender;

		auto w = appender!string;
		dump(w, fmt, xs);
		return w.data;
	}
}

// formats runtime parameters
private void dumpRuntime(Writer, Char, Xs...)(Writer w, in Char[] fmt, lazy Xs xs)
if (isOutputRange!(Writer, string))
{
	import std.format : formatValue, FormatSpec;

	alias FPfmt = void delegate(Writer wr) @safe;
	enum lengthMax = 3;

	foreach (k, el; xs)
	{
		auto spec = FormatSpec!Char(fmt);

		// we expose three variables: name, value and typo
		FPfmt[lengthMax] funs;

		static if (isCallable!el)
		{
			funs[0] = (Writer wr) { formatValue(wr, "()", spec); };
			funs[1] = (Writer wr) { formatValue(wr, el(), spec); };
			funs[2] = (Writer wr) {
				formatValue(wr, ReturnType!(typeof(el)).stringof, spec);
			};
		}
		else
		{
			funs[0] = (Writer wr) { formatValue(wr, k, spec); };
			funs[1] = (Writer wr) { formatValue(wr, el, spec); };
			funs[2] = (Writer wr) { formatValue(wr, typeof(el).stringof, spec); };
		}

		applySpecToFunctions(w, spec, funs);

		if (k < Xs.length - 1)
			w.put(spec.trailing);
	}
}

// apply given spec with given printing functions
private void applySpecToFunctions(Writer, Char, Fun)(Writer w, ref FormatSpec!Char spec, Fun funs)
{
	enum lengthMax = 3;

	uint currentArg = 0;
	while (spec.writeUpToNextSpecWithoutEnd(w))
	{
		if (currentArg == funs.length && !spec.indexStart)
		{
			import std.conv : text;

			// Something went wrong here?
			enforceFmt(text("Orphan format specifier: %", spec.spec));
			break;
		}
		if (spec.indexStart > 0)
		{
			// positional parameters
			static if (lengthMax > 0)
			{
				foreach (i; spec.indexStart - 1 .. spec.indexEnd)
				{
					if (funs.length <= i)
						break;
					funs[i](w);
				}
			}
			if (currentArg < spec.indexEnd)
				currentArg = spec.indexEnd;
		}
		else
		{
			// parameters in given order
			funs[currentArg++](w);
		}
	}
}

// writes the non-spec parts of a format string except for the trailing end
private bool writeUpToNextSpecWithoutEnd(Char, OutputRange)(
		ref FormatSpec!Char spec, OutputRange writer)
{
	with (spec)
	{
		if (trailing.empty)
			return false;
		for (size_t i = 0; i < trailing.length; ++i)
		{
			if (trailing[i] != '%')
				continue;
			put(writer, trailing[0 .. i]);
			trailing = trailing[i .. $];
			enforceFmt(trailing.length >= 2, `Unterminated format specifier: "%"`);
			trailing = trailing[1 .. $];

			if (trailing[0] != '%')
			{
				// Spec found. Fill up the spec, and bailout
				/+ TODO: fillUp(); +/
				return true;
			}
			// Doubled! Reset and Keep going
			i = 0;
		}
	}
	return false;
}

///
unittest {
	int x = 5, y = 3;
	import std.stdio;

	assert(dump!(x, y)("%s = %s, ") == "x = 5, y = 3");

	// with order
	assert(dump!(x, y)("%2$s = %1$s, ") == "5 = x, 3 = y");

	// with runtime args
	assert(dump!(x, y)("%s = %s, ", () => 42) == "x = 5, y = 3, () = 42");

	// with runtime args & position-specifier
	assert(dump!(x, y)("%1$s = %2$s; ", "var1") == "x = 5; y = 3; 0 = var1");

	// with types
	assert(dump!(x, y)("(%s: %3$s) = %2$s, ") == "(x: int) = 5, (y: int) = 3");
	assert(dump!(x, y)("(%s!%3$s) = %2$s, ") == "(x!int) = 5, (y!int) = 3");

	// custom separator
	assert(dump!(x, y)("%s = %s; ") == "x = 5; y = 3");

	// all printf formatting works
	assert(dump!(x, y)("%-4s = %4s, ") == "x	=	5, y	=	3");

	// special formatting (if applicable for all types)
	auto z1 = 2.0, z2 = 4.0;
	assert(dump!(z1, z2)("%s = %.3f & ") == "z1 = 2.000 & z2 = 4.000");

	// functions
	assert(dump!(x, y, () => x + y)("%s = %s; ") == "x = 5; y = 3; () = 8");

	// runtime paramters
	auto b = (int a) => ++a;
	assert(dump!(x, y)("%s = %s, ", b(x), x - y) == "x = 5, y = 3, 0 = 6, 1 = 2");

	// validate laziness
	auto c = (ref int a) => ++a;
	assert(dump!(x, y, () => x + y)("%s = %s, ", c(x), x - y) == "x = 5, y = 3, () = 8, 0 = 6, 1 = 3");
	assert(dump!(x, y, () => x + y)("%s = %s, ", c(x), x - y) == "x = 6, y = 3, () = 9, 0 = 7, 1 = 4");
}

// test with output range
unittest {
	import std.array : appender;

	auto x = 2;
	long y = 4;
	auto w = appender!string;
	dump!(x, y)(w, "%s = %s, ");
	assert(w.data == "x = 2, y = 4");

	import std.stdio : stdout;

	if (false)
		dump!(x, y)(stdout.lockingTextWriter(), "%s = %s, ");
}
