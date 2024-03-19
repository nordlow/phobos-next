module nxt.splitter_ex;

import std.traits : isExpressions;

/** Non-decoding ASCII-separator-only variant of Phobos' `splitter`. */
auto splitterASCII(alias separatorPred, Range)(return Range r) @trusted
if (is(typeof(Range.init[0 .. 0])) && // can be sliced
	is(typeof(Range.init[0]) : char) &&
	is(typeof(separatorPred(char.init)) : bool)) /+ TODO: check that first parameter is bool +/
{
	static struct Result
	{
		private Range _input; // original copy of r
		private size_t _offset = 0; // hit offset if any, or `_haystack.length` if miss

		this(Range input)
		{
			// dbg("input:", input);
			_input = input;
			tryFindNextFront();  // find first hit if any
		}

		bool empty() const @property
			=> _input.length == 0; // dbg("input:", _input, " ", " offset:", _offset);

		@property Range front() return @trusted
		in(!empty, "Attempting to fetch the front of an empty splitter.")
			=> _input.ptr[0 .. _offset]; // dbg("input:", _input, " ", " offset:", _offset);

		/** Skip any separators. */
		void skipSeparators() @trusted
		{
			while (_offset < _input.length &&
				   separatorPred(_input.ptr[_offset]))
			{
				/* predicate `separatorPred` must only filter out ASCII, or
				 * incorrect UTF-8 decoding will follow */
				assert(isASCII(_input.ptr[_offset]));
				_offset += 1;
			}
			_input = _input[_offset .. $]; // skip leading separators
			_offset = 0;
		}

		/** Skip any separators try finding the next front. */
		void tryFindNextFront() @trusted
		{
			skipSeparators(); // skip leading separators
			while (_offset < _input.length &&
				   !separatorPred(_input.ptr[_offset]))
				_offset += 1;
			// dbg("input:", _input, " ", " offset:", _offset);
		}

		void popFront() nothrow
		in(!empty, "Attempting to pop the front of an empty splitter.")
		  	=> tryFindNextFront();

		pragma(inline, true)
		static private bool isASCII(char x) pure nothrow @safe @nogc
			=> x < 128;
	}

	return Result(r);
}

///
pure nothrow @safe @nogc unittest {
	import std.algorithm.comparison : equal;
	import std.algorithm.comparison : among;
	import nxt.array_help : s;

	assert(``.splitterASCII!(_ => _ == ' ')
			 .empty);

	assert(` `.splitterASCII!(_ => _ == ' ')
			  .empty);

	assert(`   `.splitterASCII!(_ => _ == ' ')
				.empty);

	assert(` - `.splitterASCII!(_ => _ == ' ')
				.equal([`-`].s[]));

	assert(`a`.splitterASCII!(_ => _ == ' ')
			  .equal([`a`].s[]));

	assert(` a `.splitterASCII!(_ => _ == ' ')
				.equal([`a`].s[]));

	assert(` a b `.splitterASCII!(_ => _ == ' ')
				  .equal([`a`, `b`].s[]));

	assert(` a_b `.splitterASCII!(_ => _ == ' ')
				  .equal([`a_b`].s[]));

	assert(` - aa   bb--c-_d--_e`.splitterASCII!(_ => _.among!(' ', '-', '_') != 0)
								 .equal([`aa`, `bb`, `c`, `d`, `e`].s[]));
}

/// DIP-1000 return ref escape analysis
pure nothrow @safe unittest {
	import nxt.dip_traits : hasPreviewDIP1000;
	version (none) // TODO: enable
	static if (hasPreviewDIP1000) {
		// See_Also: https://forum.dlang.org/post/pzddsrwhfvcopfaamvak@forum.dlang.org
		static assert(!__traits(compiles, {
			char[] f() {
				char[2] x;
				return x[].splitterASCII!(_ => _ == ' ').front;
			}
		}
						));
	}
}

/** Non-decoding ASCII-separator-only variant of Phobos' `splitter` that .
 *
 * TODO: generalize to separators being either chars or strings.
 */
template splitterASCIIAmong(separators...)
if (separators.length != 0 &&
	isExpressions!separators)
{
	import std.meta : allSatisfy;
	import nxt.char_traits : isASCII;

	auto splitterASCIIAmong(Range)(return Range r)
	if (is(typeof(Range.init[0 .. 0])) && // can be sliced
		is(typeof(Range.init[0]) : char) &&
		allSatisfy!(isASCII, separators))
	{
		static if (separators.length == 1)
		{
			// reuse common instatiation of `splitterASCII` for predicate `pred`:
			alias pred = (char _) => (_ == separators[0]);
		}
		else static if (separators.length == 2)
		{
			// reuse common instatiation of `splitterASCII` for predicate `pred`:
			alias pred = (char _) => (_ == separators[0] ||
									  _ == separators[1]);
		}
		else static if (separators.length == 3)
		{
			// reuse common instatiation of `splitterASCII` for predicate `pred`:
			alias pred = (char _) => (_ == separators[0] ||
									  _ == separators[1] ||
									  _ == separators[2]);
		}
		else
		{
			import std.algorithm.comparison : among;
			alias pred = (char _) => (_.among!(separators) != 0);
		}
		return splitterASCII!(pred)(r);
	}
}

///
pure nothrow @safe @nogc unittest {
	import std.algorithm.comparison : equal;
	import nxt.array_help : s;

	assert(``.splitterASCIIAmong!(' ')
			 .empty);

	assert(` `.splitterASCIIAmong!(' ')
			  .empty);

	assert(`   `.splitterASCIIAmong!(' ')
				.empty);

	assert(` - `.splitterASCIIAmong!(' ')
				.equal([`-`].s[]));

	assert(`a`.splitterASCIIAmong!(' ')
			  .equal([`a`].s[]));

	assert(` a `.splitterASCIIAmong!(' ')
				.equal([`a`].s[]));

	assert(` a b `.splitterASCIIAmong!(' ')
				  .equal([`a`, `b`].s[]));

	assert(` a_b `.splitterASCIIAmong!(' ')
				  .equal([`a_b`].s[]));

	assert(` - aa   bb--c-d--e`.splitterASCIIAmong!(' ', '-')
								 .equal([`aa`, `bb`, `c`, `d`, `e`].s[]));

	assert(` - aa   bb--c-_d--_e`.splitterASCIIAmong!(' ', '-', '_')
								 .equal([`aa`, `bb`, `c`, `d`, `e`].s[]));

	assert(` - aa ///  bb--c-_d--_e`.splitterASCIIAmong!(' ', '-', '_', '/')
									.equal([`aa`, `bb`, `c`, `d`, `e`].s[]));
}
