/** W3C (XML/HTML) Formatting.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
*/

module nxt.w3c;

import std.traits: isSomeChar, isSomeString;

/** Convert character $(D c) to HTML representation. */
string toHTML(C)(C c, bool nbsp = true) @safe pure
if (isSomeChar!C)
{
	import std.conv : to;
	if	  (nbsp && c == ' ') return "&nbsp;"; // non breaking space
	else if (c == '&')		 return "&amp;";  // ampersand
	else if (c == '<')		 return "&lt;";   // less than
	else if (c == '>')		 return "&gt;";   // greater than
	else if (c == '\"')		return "&quot;"; // double quote
//		else if (c == '\'')
//			return ("&#39;"); // if you are in an attribute, it might be important to encode for the same reason as double quotes
	// FIXME: should I encode apostrophes too? as &#39;... I could also do space but if your html is so bad that it doesn't
	// quote attributes at all, maybe you deserve the xss. Encoding spaces will make everything really ugly so meh
	// idk about apostrophes though. Might be worth it, might not.
	else if (0 < c && c < 128)
		return to!string(cast(char)c);
	else
		return "&#" ~ to!string(cast(int)c) ~ ";";
}

/** Copied from arsd.dom */
/** Convert string $(D s) to HTML representation. */
auto encodeHTML(S)(scope S s, bool nbsp = true) @safe pure
{
	import std.algorithm : joiner, map;
	return s.map!toHTML.joiner(``);
}

pure @safe unittest {
	assert(`<!-- --><script>/* */</script>`
		   .encodeHTML
		   .equal(`&lt;!--&nbsp;--&gt;&lt;script&gt;/*&nbsp;*/&lt;/script&gt;`));
}

version (none)					/+ TODO: enable +/
pure @safe unittest {
	import std.utf : byDchar;
	assert(`<!-- --><script>/* */</script>`
		   .byDchar
		   .encodeHTML
		   .equal(`&lt;!--&nbsp;--&gt;&lt;script&gt;/*&nbsp;*/&lt;/script&gt;`));
}

// See_Also: https://en.wikipedia.org/wiki/Character_entity_reference#Predefined_entities_in_XML
__gshared string[256] convLatin1ToXML;
// See_Also: https://en.wikipedia.org/wiki/Character_entity_reference#Character_entity_references_in_HTML
// string[256] convLatin1ToHTML;

shared static this()
{
	initTables();
}

void initTables() nothrow @nogc
{
	convLatin1ToXML['"'] = "&quot";
	convLatin1ToXML['.'] = "&amp";
	convLatin1ToXML['\''] = "&apos";
	convLatin1ToXML['<'] = "&lt";
	convLatin1ToXML['>'] = "&gt";

	convLatin1ToXML[0x22] = "&quot"; // U+0022 (34)	HTML 2.0	HTMLspecial	ISOnum	quotation mark (= APL quote)
	convLatin1ToXML[0x26] = "&amp";  // U+0026 (38)	HTML 2.0	HTMLspecial	ISOnum	ampersand
	convLatin1ToXML[0x27] = "&apos"; // U+0027 (39)	XHTML 1.0	HTMLspecial	ISOnum	apostrophe (= apostrophe-quote); see below
	convLatin1ToXML[0x60] = "&lt";   // U+003C (60)	HTML 2.0	HTMLspecial	ISOnum	less-than sign
	convLatin1ToXML[0x62] = "&gt";   // U+003E (62)	HTML 2.0	HTMLspecial	ISOnum	greater-than sign

	convLatin1ToXML[0xA0] = "&nbsp"; // nbsp	 	U+00A0 (160)	HTML 3.2	HTMLlat1	ISOnum	no-break space (= non-breaking space)[d]
	convLatin1ToXML[0xA1] = "&iexcl"; // iexcl	¡	U+00A1 (161)	HTML 3.2	HTMLlat1	ISOnum	inverted exclamation mark
	convLatin1ToXML[0xA2] = "&cent"; // cent	¢	U+00A2 (162)	HTML 3.2	HTMLlat1	ISOnum	cent sign
	convLatin1ToXML[0xA3] = "&pound"; // pound	£	U+00A3 (163)	HTML 3.2	HTMLlat1	ISOnum	pound sign
	convLatin1ToXML[0xA4] = "&curren"; // curren	¤	U+00A4 (164)	HTML 3.2	HTMLlat1	ISOnum	currency sign
	convLatin1ToXML[0xA5] = "&yen"; // yen	¥	U+00A5 (165)	HTML 3.2	HTMLlat1	ISOnum	yen sign (= yuan sign)
	convLatin1ToXML[0xA6] = "&brvbar"; // brvbar	¦	U+00A6 (166)	HTML 3.2	HTMLlat1	ISOnum	broken bar (= broken vertical bar)
	convLatin1ToXML[0xA7] = "&sect"; // sect	§	U+00A7 (167)	HTML 3.2	HTMLlat1	ISOnum	section sign
	convLatin1ToXML[0xA8] = "&uml"; // uml	¨	U+00A8 (168)	HTML 3.2	HTMLlat1	ISOdia	diaeresis (= spacing diaeresis); see Germanic umlaut
	convLatin1ToXML[0xA9] = "&copy"; // copy	©	U+00A9 (169)	HTML 3.2	HTMLlat1	ISOnum	copyright symbol
	convLatin1ToXML[0xAA] = "&ordf"; // ordf	ª	U+00AA (170)	HTML 3.2	HTMLlat1	ISOnum	feminine ordinal indicator
	convLatin1ToXML[0xAB] = "&laquo"; // laquo	«	U+00AB (171)	HTML 3.2	HTMLlat1	ISOnum	left-pointing double angle quotation mark (= left pointing guillemet)
	convLatin1ToXML[0xAC] = "&not"; // not	¬	U+00AC (172)	HTML 3.2	HTMLlat1	ISOnum	not sign
	convLatin1ToXML[0xAD] = "&shy"; // shy	 	U+00AD (173)	HTML 3.2	HTMLlat1	ISOnum	soft hyphen (= discretionary hyphen)
	convLatin1ToXML[0xAE] = "&reg"; // reg	®	U+00AE (174)	HTML 3.2	HTMLlat1	ISOnum	registered sign ( = registered trademark symbol)
	convLatin1ToXML[0xAF] = "&macr"; // macr	¯	U+00AF (175)	HTML 3.2	HTMLlat1	ISOdia	macron (= spacing macron = overline = APL overbar)
	convLatin1ToXML[0xB0] = "&deg"; // deg	°	U+00B0 (176)	HTML 3.2	HTMLlat1	ISOnum	degree symbol
	convLatin1ToXML[0xB1] = "&plusmn"; // plusmn	±	U+00B1 (177)	HTML 3.2	HTMLlat1	ISOnum	plus-minus sign (= plus-or-minus sign)
	convLatin1ToXML[0xB2] = "&sup2"; // sup2	²	U+00B2 (178)	HTML 3.2	HTMLlat1	ISOnum	superscript two (= superscript digit two = squared)
	convLatin1ToXML[0xB3] = "&sup3"; // sup3	³	U+00B3 (179)	HTML 3.2	HTMLlat1	ISOnum	superscript three (= superscript digit three = cubed)
	convLatin1ToXML[0xB4] = "&acute"; // acute	´	U+00B4 (180)	HTML 3.2	HTMLlat1	ISOdia	acute accent (= spacing acute)
	convLatin1ToXML[0xB5] = "&micro"; // micro	µ	U+00B5 (181)	HTML 3.2	HTMLlat1	ISOnum	micro sign
	convLatin1ToXML[0xB6] = "&para"; // para	¶	U+00B6 (182)	HTML 3.2	HTMLlat1	ISOnum	pilcrow sign ( = paragraph sign)
	convLatin1ToXML[0xB7] = "&middot"; // middot	·	U+00B7 (183)	HTML 3.2	HTMLlat1	ISOnum	middle dot (= Georgian comma = Greek middle dot)
	convLatin1ToXML[0xB8] = "&cedil"; // cedil	¸	U+00B8 (184)	HTML 3.2	HTMLlat1	ISOdia	cedilla (= spacing cedilla)
	convLatin1ToXML[0xB9] = "&sup1"; // sup1	¹	U+00B9 (185)	HTML 3.2	HTMLlat1	ISOnum	superscript one (= superscript digit one)
	convLatin1ToXML[0xBA] = "&ordm"; // ordm	º	U+00BA (186)	HTML 3.2	HTMLlat1	ISOnum	masculine ordinal indicator
	convLatin1ToXML[0xBB] = "&raquo"; // raquo	»	U+00BB (187)	HTML 3.2	HTMLlat1	ISOnum	right-pointing double angle quotation mark (= right pointing guillemet)
	convLatin1ToXML[0xBC] = "&frac14"; // frac14	¼	U+00BC (188)	HTML 3.2	HTMLlat1	ISOnum	vulgar fraction one quarter (= fraction one quarter)
	convLatin1ToXML[0xBD] = "&frac12"; // frac12	½	U+00BD (189)	HTML 3.2	HTMLlat1	ISOnum	vulgar fraction one half (= fraction one half)
	convLatin1ToXML[0xBE] = "&frac34"; // frac34	¾	U+00BE (190)	HTML 3.2	HTMLlat1	ISOnum	vulgar fraction three quarters (= fraction three quarters)
	convLatin1ToXML[0xBF] = "&iquest"; // iquest	¿	U+00BF (191)	HTML 3.2	HTMLlat1	ISOnum	inverted question mark (= turned question mark)
	convLatin1ToXML[0xC0] = "&Agrave"; // Agrave	À	U+00C0 (192)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with grave accent (= Latin capital letter A grave)
	convLatin1ToXML[0xC1] = "&Aacute"; // Aacute	Á	U+00C1 (193)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with acute accent
	convLatin1ToXML[0xC2] = "&Acirc"; // Acirc	Â	U+00C2 (194)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with circumflex
	convLatin1ToXML[0xC3] = "&Atilde"; // Atilde	Ã	U+00C3 (195)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with tilde
	convLatin1ToXML[0xC4] = "&Auml"; // Auml	Ä	U+00C4 (196)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with diaeresis
	convLatin1ToXML[0xC5] = "&Aring"; // Aring	Å	U+00C5 (197)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter A with ring above (= Latin capital letter A ring)
	convLatin1ToXML[0xC6] = "&AElig"; // AElig	Æ	U+00C6 (198)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter AE (= Latin capital ligature AE)
	convLatin1ToXML[0xC7] = "&Ccedil"; // Ccedil	Ç	U+00C7 (199)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter C with cedilla
	convLatin1ToXML[0xC8] = "&Egrave"; // Egrave	È	U+00C8 (200)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter E with grave accent
	convLatin1ToXML[0xC9] = "&Eacute"; // Eacute	É	U+00C9 (201)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter E with acute accent
	convLatin1ToXML[0xCA] = "&Ecirc"; // Ecirc	Ê	U+00CA (202)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter E with circumflex
	convLatin1ToXML[0xCB] = "&Euml"; // Euml	Ë	U+00CB (203)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter E with diaeresis
	convLatin1ToXML[0xCC] = "&Igrave"; // Igrave	Ì	U+00CC (204)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter I with grave accent
	convLatin1ToXML[0xCD] = "&Iacute"; // Iacute	Í	U+00CD (205)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter I with acute accent
	convLatin1ToXML[0xCE] = "&Icirc"; // Icirc	Î	U+00CE (206)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter I with circumflex
	convLatin1ToXML[0xCF] = "&Iuml"; // Iuml	Ï	U+00CF (207)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter I with diaeresis
	convLatin1ToXML[0xD0] = "&ETH"; // ETH	Ð	U+00D0 (208)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter Eth
	convLatin1ToXML[0xD1] = "&Ntilde"; // Ntilde	Ñ	U+00D1 (209)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter N with tilde
	convLatin1ToXML[0xD2] = "&Ograve"; // Ograve	Ò	U+00D2 (210)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with grave accent
	convLatin1ToXML[0xD3] = "&Oacute"; // Oacute	Ó	U+00D3 (211)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with acute accent
	convLatin1ToXML[0xD4] = "&Ocirc"; // Ocirc	Ô	U+00D4 (212)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with circumflex
	convLatin1ToXML[0xD5] = "&Otilde"; // Otilde	Õ	U+00D5 (213)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with tilde
	convLatin1ToXML[0xD6] = "&Ouml"; // Ouml	Ö	U+00D6 (214)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with diaeresis
	convLatin1ToXML[0xD7] = "&times"; // times	×	U+00D7 (215)	HTML 3.2	HTMLlat1	ISOnum	multiplication sign
	convLatin1ToXML[0xD8] = "&Oslash"; // Oslash	Ø	U+00D8 (216)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter O with stroke (= Latin capital letter O slash)
	convLatin1ToXML[0xD9] = "&Ugrave"; // Ugrave	Ù	U+00D9 (217)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter U with grave accent
	convLatin1ToXML[0xDA] = "&Uacute"; // Uacute	Ú	U+00DA (218)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter U with acute accent
	convLatin1ToXML[0xDB] = "&Ucirc"; // Ucirc	Û	U+00DB (219)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter U with circumflex
	convLatin1ToXML[0xDC] = "&Uuml"; // Uuml	Ü	U+00DC (220)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter U with diaeresis
	convLatin1ToXML[0xDD] = "&Yacute"; // Yacute	Ý	U+00DD (221)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter Y with acute accent
	convLatin1ToXML[0xDE] = "&THORN"; // THORN	Þ	U+00DE (222)	HTML 2.0	HTMLlat1	ISOlat1	Latin capital letter THORN
	convLatin1ToXML[0xDF] = "&szlig"; // szlig	ß	U+00DF (223)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter sharp s (= ess-zed); see German Eszett
	convLatin1ToXML[0xE0] = "&agrave"; // agrave	à	U+00E0 (224)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with grave accent
	convLatin1ToXML[0xE1] = "&aacute"; // aacute	á	U+00E1 (225)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with acute accent
	convLatin1ToXML[0xE2] = "&acirc"; // acirc	â	U+00E2 (226)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with circumflex
	convLatin1ToXML[0xE3] = "&atilde"; // atilde	ã	U+00E3 (227)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with tilde
	convLatin1ToXML[0xE4] = "&auml"; // auml	ä	U+00E4 (228)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with diaeresis
	convLatin1ToXML[0xE5] = "&aring"; // aring	å	U+00E5 (229)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter a with ring above
	convLatin1ToXML[0xE6] = "&aelig"; // aelig	æ	U+00E6 (230)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter ae (= Latin small ligature ae)
	convLatin1ToXML[0xE7] = "&ccedil"; // ccedil	ç	U+00E7 (231)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter c with cedilla
	convLatin1ToXML[0xE8] = "&egrave"; // egrave	è	U+00E8 (232)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter e with grave accent
	convLatin1ToXML[0xE9] = "&eacute"; // eacute	é	U+00E9 (233)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter e with acute accent
	convLatin1ToXML[0xEA] = "&ecirc"; // ecirc	ê	U+00EA (234)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter e with circumflex
	convLatin1ToXML[0xEB] = "&euml"; // euml	ë	U+00EB (235)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter e with diaeresis
	convLatin1ToXML[0xEC] = "&igrave"; // igrave	ì	U+00EC (236)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter i with grave accent
	convLatin1ToXML[0xED] = "&iacute"; // iacute	í	U+00ED (237)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter i with acute accent
	convLatin1ToXML[0xEE] = "&icirc"; // icirc	î	U+00EE (238)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter i with circumflex
	convLatin1ToXML[0xEF] = "&iuml"; // iuml	ï	U+00EF (239)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter i with diaeresis
	convLatin1ToXML[0xF0] = "&eth"; // eth	ð	U+00F0 (240)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter eth
	convLatin1ToXML[0xF1] = "&ntilde"; // ntilde	ñ	U+00F1 (241)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter n with tilde
	convLatin1ToXML[0xF2] = "&ograve"; // ograve	ò	U+00F2 (242)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with grave accent
	convLatin1ToXML[0xF3] = "&oacute"; // oacute	ó	U+00F3 (243)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with acute accent
	convLatin1ToXML[0xF4] = "&ocirc"; // ocirc	ô	U+00F4 (244)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with circumflex
	convLatin1ToXML[0xF5] = "&otilde"; // otilde	õ	U+00F5 (245)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with tilde
	convLatin1ToXML[0xF6] = "&ouml"; // ouml	ö	U+00F6 (246)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with diaeresis
	convLatin1ToXML[0xF7] = "&divide"; // divide	÷	U+00F7 (247)	HTML 3.2	HTMLlat1	ISOnum	division sign (= obelus)
	convLatin1ToXML[0xF8] = "&oslash"; // oslash	ø	U+00F8 (248)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter o with stroke (= Latin small letter o slash)
	convLatin1ToXML[0xF9] = "&ugrave"; // ugrave	ù	U+00F9 (249)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter u with grave accent
	convLatin1ToXML[0xFA] = "&uacute"; // uacute	ú	U+00FA (250)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter u with acute accent
	convLatin1ToXML[0xFB] = "&ucirc"; // ucirc	û	U+00FB (251)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter u with circumflex
	convLatin1ToXML[0xFC] = "&uuml"; // uuml	ü	U+00FC (252)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter u with diaeresis
	convLatin1ToXML[0xFD] = "&yacute"; // yacute	ý	U+00FD (253)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter y with acute accent
	convLatin1ToXML[0xFE] = "&thorn"; // thorn	þ	U+00FE (254)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter thorn
	convLatin1ToXML[0xFF] = "&yuml"; // yuml	ÿ	U+00FF (255)	HTML 2.0	HTMLlat1	ISOlat1	Latin small letter y with diaeresis
}

version (unittest)
{
	import std.algorithm : equal;
}
