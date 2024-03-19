module nxt.slicing;

/** Slice at all positions where $(D isTerminator) is $(D false) before current
	element and $(D true) at current.

	TODO: Can this be replaced by chunkBy
	See_Also: http://dlang.org/library/std/algorithm/splitter.html.
	See_Also: http://forum.dlang.org/post/cwqeywykubsuynkidlux@forum.dlang.org
*/
auto preSlicer(alias isTerminator, R)(R input)
/* if (((isRandomAccessRange!R && */
/*	   hasSlicing!R) || */
/*	  isSomeString!R) && */
/*	 is(typeof(unaryFun!isTerminator(input.front)))) */
{
	import std.functional : unaryFun;
	return PreSlicer!(unaryFun!isTerminator, R)(input);
}

private struct PreSlicer(alias isTerminator, R)
{
	this(R input)
	{
		_input = input;
		import std.range.primitives : empty;
		if (_input.empty)
			_end = size_t.max;
		else
			skipTerminatorsAndSetEnd();
	}

	import std.range.primitives : isInfinite;

	static if (isInfinite!R)
		enum bool empty = false;  // propagate infiniteness
	else
		@property bool empty() => _end == size_t.max;

	@property auto front() => _input[0 .. _end];

	void popFront()
	{
		_input = _input[_end .. $];
		import std.range.primitives : empty;
		if (_input.empty)
		{
			_end = size_t.max;
			return;
		}
		skipTerminatorsAndSetEnd();
	}

	@property PreSlicer save()
	{
		auto ret = this;
		import std.range.primitives : save;
		ret._input = _input.save;
		return ret;
	}

	private void skipTerminatorsAndSetEnd()
	{
		// `_end` is now invalid in relation to `_input`
		alias ElementEncodingType = typeof(_input[0]);
		static if (is(ElementEncodingType : char) ||
				   is(ElementEncodingType : wchar))
		{
			size_t offset = 0;
			while (offset != _input.length)
			{
				auto slice = _input[offset .. $];
				import std.utf : decodeFront;
				size_t numCodeUnits;
				const dchar dch = decodeFront(slice, numCodeUnits);
				if (offset != 0 && // ignore terminator at offset 0
					isTerminator(dch))
					break;
				offset += numCodeUnits; // skip over
			}
			_end = offset;
		}
		else
		{
			size_t offset = 0;
			if (isTerminator(_input[0]))
				offset += 1;		// skip over it
			import std.algorithm : countUntil;
			const count = _input[offset .. $].countUntil!isTerminator();
			if (count == -1)		// end reached
				_end = _input.length;
			else
				_end = offset + count;
		}
	}

	private R _input;
	private size_t _end = 0;	// _input[0 .. _end] is current front
}
alias preSplitter = preSlicer;

unittest {
	import std.uni : isUpper, isWhite;
	alias sepPred = ch => (ch == '-' || ch.isWhite);
	assert(equal("doThis or doThat do-stuff".preSlicer!(_ => (_.isUpper ||
															  sepPred(_)))
								   .map!(word => (word.length >= 1 &&
												  sepPred(word[0]) ?
												  word[1 .. $] :
												  word)),
				 ["do", "This", "or", "do", "That", "do", "stuff"]));

	assert(equal("isAKindOf".preSlicer!isUpper, ["is", "A", "Kind", "Of"]));

	assert(equal("doThis".preSlicer!isUpper, ["do", "This"]));

	assert(equal("doThisIf".preSlicer!isUpper, ["do", "This", "If"]));

	assert(equal("utcOffset".preSlicer!isUpper, ["utc", "Offset"]));
	assert(equal("isUri".preSlicer!isUpper, ["is", "Uri"]));
	/+ TODO: assert(equal("baseSIUnit".preSlicer!isUpper, ["base", "SI", "Unit"])); +/

	assert(equal("SomeGreatVariableName".preSlicer!isUpper, ["Some", "Great", "Variable", "Name"]));
	assert(equal("someGGGreatVariableName".preSlicer!isUpper, ["some", "G", "G", "Great", "Variable", "Name"]));

	string[] e;
	assert(equal("".preSlicer!isUpper, e));
	assert(equal("a".preSlicer!isUpper, ["a"]));
	assert(equal("A".preSlicer!isUpper, ["A"]));
	assert(equal("A".preSlicer!isUpper, ["A"]));
	assert(equal("ö".preSlicer!isUpper, ["ö"]));
	assert(equal("åa".preSlicer!isUpper, ["åa"]));
	assert(equal("aå".preSlicer!isUpper, ["aå"]));
	assert(equal("åäö".preSlicer!isUpper, ["åäö"]));
	assert(equal("aB".preSlicer!isUpper, ["a", "B"]));
	assert(equal("äB".preSlicer!isUpper, ["ä", "B"]));
	assert(equal("aäB".preSlicer!isUpper, ["aä", "B"]));
	assert(equal("äaB".preSlicer!isUpper, ["äa", "B"]));
	assert(equal("äaÖ".preSlicer!isUpper, ["äa", "Ö"]));

	assert(equal([1, -1, 1, -1].preSlicer!(a => a > 0), [[1, -1], [1, -1]]));

	/* TODO: Add bidir support */
	/* import std.range : retro; */
	/* assert(equal([-1, 1, -1, 1].retro.preSlicer!(a => a > 0), [[1, -1], [1, -1]])); */
}

version (none)				   /+ TODO: enable +/
auto wordByMixedCaseSubWord(Range)(Range r)
{
	static struct Result
	{
		this(Range input)
		{
			_input = input;
			import std.range.primitives : empty;
			if (_input.empty)
				_end = size_t.max;
			else
				skipTerminatorsAndSetEnd();
		}

		@property bool empty() => _end == size_t.max;

		@property auto front() => _input[0 .. _end];

		void popFront()
		{
			_input = _input[_end .. $];
			import std.range.primitives : empty;
			if (_input.empty)
			{
				_end = size_t.max;
				return;
			}
			skipTerminatorsAndSetEnd();
		}

		private void skipTerminatorsAndSetEnd()
		{
			// `_end` is now invalid in relation to `_input`
			size_t offset = 0;
			while (offset != _input.length)
			{
				auto slice = _input[offset .. $];
				import std.utf : decodeFront;
				size_t numCodeUnits;
				const dchar dch = decodeFront(slice, numCodeUnits);
				if (offset != 0 && // ignore terminator at offset 0
					isTerminator(dch))
					break;
				offset += numCodeUnits; // skip over
			}
			_end = offset;
		}

		private Range _input;
		private size_t _end = 0;	// _input[0 .. _end] is current front
	}
	return Result(r);
}

version (none)				   /+ TODO: enable +/
pure @safe unittest {
	assert(equal("äaÖ".wordByMixedCaseSubWord, ["äa", "Ö"]));
}

version (unittest)
{
	 import std.algorithm.comparison : equal;
	 import std.algorithm.iteration : map;
}
