/** MathML.
	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/
module nxt.mathml;

import std.traits : isScalarType, isFloatingPoint;

import nxt.rational : Rational; /+ TODO: Can we turn this dep into a duck type dep? +/

/** Markup language. */
enum MarkupLanguage {
	unknown, nullValue = unknown, // `HybridHashMap` null support
	HTML,
	MathML
}

/** Horizontal Alignment. */
enum HAlign {
	unknown, nullValue = unknown, // `HybridHashMap` null support
	left,					   ///< Left aligned.
	center,					 ///< Center aligned.
	right					   ///< Right aligned.
}

/** Vertical Alignment. */
enum VAlign {
	unknown,
	top,						///< Top aligned.
	middle,					 ///< Middle aligned.
	bottom,					 ///< Bottom aligned.
}

/** Generic case. */
string toMathML(T)(in T x) @trusted /* pure nothrow */
if (isScalarType!T &&
	!isFloatingPoint!T)
{
	import std.conv : to;
	return to!string(x);
}

/** Returns: x in $(D MarkupLanguage) format.
 *
 * See_Also: http://forum.dlang.org/thread/awkynfizwqjnbilgddbh@forum.dlang.org#post-awkynfizwqjnbilgddbh:40forum.dlang.org
 * See_Also: https://developer.mozilla.org/en-US/docs/Web/MathML/Element/mn
 * See_Also: https://developer.mozilla.org/en-US/docs/Web/MathML/Element/msup
 */
string toML(T)(in T x,
			   bool usePowPlus = false,
			   bool useLeadZeros = false,
			   MarkupLanguage mlang = MarkupLanguage.HTML) @trusted /* pure nothrow */
if (isFloatingPoint!T)
{
	import std.conv : to;
	import nxt.algorithm.searching : findSplitAmong;
	const parts = to!string(x).findSplitAmong!('e'); /+ TODO: Use std.bitmanip.FloatRep instead +/
	if (parts[2].length >= 1)
	{
		// mantissa
		const mant = parts[0];

		/+ TODO: These format fixes for the exponent are not needed if we use +/
		// std.bitmanip.FloatRep instead

		// exponent
		auto exp = ((!usePowPlus &&
					  parts[2][0] == '+') ? // if leading plus
					 parts[2][1..$] : // skip plus
					 parts[2]); // otherwise whole
		import nxt.algorithm_ex : dropWhile;
		auto zexp = useLeadZeros ? exp : exp.dropWhile('0');

		final switch (mlang)
		{
			case MarkupLanguage.unknown:
			case MarkupLanguage.HTML:
				return (mant ~ `&middot;` ~ `10` ~ `<msup>` ~ zexp ~ `</msup>`);
			case MarkupLanguage.MathML:
				return (`<math>` ~ mant ~ `&middot;` ~
						`<msup>` ~
						`<mn>10</mn>` ~
						`<mn mathsize="80%">` ~ zexp ~ `</mn>` ~
						`</msup>` ~
						`</math>`);
		}
		/* NOTE: This doesn't work in Firefox. Why? */
		/* return (`<math>` ~ parts[0] ~ `&middot;` ~ */
		/*		 `<apply><power/>` ~ */
		/*		 `<ci>10</ci>` ~ */
		/*		 `<cn>` ~ parts[2] ~ `</cn>` */
		/*		 `</apply>` ~ */
		/*		 `</math>`); */
	}
	else
	{
		return parts[0];
	}
}

auto toMathML(T)(in T x,
				 bool usePowPlus = false,
				 bool useLeadZeros = false) @trusted /* pure nothrow */ if (isFloatingPoint!T)
	=> toML(x, usePowPlus, useLeadZeros, MarkupLanguage.MathML);

auto toHTML(T)(in T x,
			   bool usePowPlus = false,
			   bool useLeadZeros = false) @trusted /* pure nothrow */ if (isFloatingPoint!T)
	=> toML(x, usePowPlus, useLeadZeros, MarkupLanguage.HTML);

/** Returns: MathML Representation of $(D x).
 *
 * See_Also: https://developer.mozilla.org/en-US/docs/Web/MathML/Element/mfrac
 */
string toMathML(T)(in Rational!T x,
				   bool bevelled = false,
				   HAlign numAlign = HAlign.center,
				   HAlign denomAlign = HAlign.center,
				   in string href = null) @safe pure
{
	import std.conv : to;
	return (`<math><mfrac` ~
			(bevelled ? ` bevelled="true"` : ``) ~
			(numAlign != HAlign.center ? ` numAlign="` ~ to!string(numAlign) ~ `"` : ``) ~
			(denomAlign != HAlign.center ? ` denomAlign="` ~ to!string(denomAlign) ~ `"` : ``) ~
			`><mi>`
			~ to!string(x.numerator) ~ `</mi><mi>` ~
			to!string(x.denominator) ~
			`</mi></mfrac></math>`);
}

unittest {
	alias Q = Rational;
	auto x = Q!ulong(11, 22);
	// import nxt.debugio : dbg;
	/** dbg(x.toMathML); */
	/** dbg(x.toMathML(true)); */
	/** dbg(x.toMathML(true, HAlign.left, HAlign.left)); */
}
