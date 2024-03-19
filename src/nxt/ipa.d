/** International Phonetic Alphabet.
 */
module nxt.ipa;

// enum Phoneme : string
// {
//	 `æ`,
//	 `ə`,
//	 `ʌ`,
//	 `ɜ`,
//	 `eə`,
//	 `ɜr`,
//	 `ɑː`,
//	 `aɪ`,
//	 `ɑr`,
//	 `aʊ`,
//	 `b`,
//	 `d`,
//	 `ð`,
//	 `dʒ`,
//	 `ɛ`,
//	 `eɪ`,
//	 `f`,
//	 `ɡ`,
//	 `h`,
//	 `hw`,
//	 `iː`,
//	 `ɪ`,
//	 `j`,
//	 `k`,
//	 `l`,
//	 `m`,
//	 `n`,
//	 `ŋ`,
//	 `ɔː`,
//	 `ɔɪ`,
//	 `oʊ`,
//	 `p`,
//	 `r`,
//	 `s`,
//	 `ʃ`,
//	 `t`,
//	 `θ`,
//	 `tʃ`,
//	 `uː`,
//	 `ʊ`,
//	 `v`,
//	 `w`,
//	 `z`,
//	 `ʒ`,
//	 }

// size_t countSyllables(Phoneme s) pure nothrow @safe @nogc
// {
//	 return 0;
// }

import std.traits : isSomeString;

bool isIPAVowelPhoneme(S)(S s)
	if (isSomeString!S)
{
	import std.algorithm.comparison : among;
	return cast(bool)s.among!(`æ`, `ə`, `ʌ`, `ɜ`, `eə`, `ɜr`, `ɑː`, `aɪ`, `ɑr`, `aʊ`, `ɛ`, `eɪ`, `iː`, `ɪ`, `ɔː`, `ɔɪ`, `oʊ`, `uː`, `ʊ`);
}

pure nothrow @safe @nogc unittest {
	assert(`æ`.isIPAVowelPhoneme);
	assert(!`b`.isIPAVowelPhoneme);
}

bool isIPAConsonantPhoneme(S)(S s)
	if (isSomeString!S)
{
	import std.algorithm.comparison : among;
	return cast(bool)s.among!(`b`, `d`, `ð`, `dʒ`, `f`, `ɡ`, `h`, `hw`, `j`, `k`, `l`, `m`, `n`, `ŋ`, `p`, `r`, `s`, `ʃ`, `t`, `θ`, `tʃ`, `w`, `z`, `ʒ`);
}

pure nothrow @safe @nogc unittest {
	assert(!`a`.isIPAConsonantPhoneme);
	assert(`b`.isIPAConsonantPhoneme);
}
