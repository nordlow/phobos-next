/** Helper functions for the SU(M)O-KIF file format.
 *
 * SUO-KIF is used the default encoding of the SUMO ontology.
 */
module nxt.sumo_kif;

@safe:

bool isFormat(scope const(char)[] chars) pure nothrow @nogc
{
	import nxt.algorithm.searching : findSkip;
	while (chars.findSkip('%'))
	{
		import std.ascii : isDigit;
		if (chars.length >= 1 &&
			(isDigit(chars[0]) ||
			 chars[0] == '*'))
		{
			return true;
		}
	}
	return false;
}

pure @safe unittest {
	assert("%1".isFormat);
	assert(" %1 ".isFormat);

	assert("%2".isFormat);
	assert(" %2 ".isFormat);

	assert("%*".isFormat);
	assert(" %* ".isFormat);

	assert(!"%".isFormat);
	assert(!"% ".isFormat);
	assert(!" % ".isFormat);

	assert("%n %1".isFormat);
	assert("%n %1".isFormat);
	assert("%n %*".isFormat);
}

bool isTermFormat(scope const(char)[] chars) pure nothrow @nogc
{
	return !isFormat(chars);
}
