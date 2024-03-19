/++ Lazily Initialized Regular Expression.
 +/
module nxt.lazy_regex;

@safe:

version (none): // avoid having to `import std.regex`

/++ Lazily initialized regular expression (Regexp).
 +/
struct LazyRegex {
	this(string str) pure nothrow @nogc {
		this.str = str;
	}

	/// File name extension instantiator.
	static typeof(this) fileExtension(in char[] s) pure nothrow {
		return typeof(return)((`\.` ~ s ~ `$`).idup);
	}

	string str;
	import std.regex : Regex;
	private Regex!char *_regexP; ///< Lazily initialized.
}

auto matchFirst(in char[] value, ref LazyRegex re) @trusted {
	import std.regex : regex, matchFirst, Regex;
	if (re._regexP is null) {
		re._regexP = new Regex!char();
		*re._regexP = regex(re.str);
	}
	return value.matchFirst(*re._regexP);
}
