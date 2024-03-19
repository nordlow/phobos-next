/** Stemming algorithms
 */
module nxt.stemming;

import std.algorithm.comparison: among;
import std.algorithm.searching : endsWith, canFind;
import std.range: empty;
import std.traits: isSomeString;
import std.typecons : Tuple, tuple;

import nxt.iso_639_1 : Language;
import nxt.lingua : isEnglishVowel, isSwedishVowel, isSwedishConsonant, isEnglishConsonant;
import nxt.skip_ex : skipOverBack;

public class Stemmer(S)
if (isSomeString!S)
{
	/**
	 * In stem(p,i,j), p is a char pointer, and the string to be stemmed
	 * is from p[i] to p[j] inclusive. Typically i is zero and j is the
	 * offset to the last character of a string, (p[j+1] == '\0'). The
	 * stemmer adjusts the characters p[i] ... p[j] and returns the new
	 * end-point of the string, k. Stemming never increases word length, so
	 * i <= k <= j. To turn the stemmer into a module, declare 'stem' as
	 * extern, and delete the remainder of this file.
	 */
	public S stem(S p)
	{
		_b = p;
		_k = p.length - 1;
		_k0 = 0;

		/** strings of length 1 or 2 don't go through the stemming process,
		 * although no mention is made of this in the published
		 * algorithm. Remove the line to match the published algorithm.
		 */
		if (_k <= _k0 + 1)
			return _b;

		step1ab();
		step1c();
		step2();
		step3();
		step4();
		step5();
		return _b[_k0 .. _k + 1];

	}

private:
	S _b;			// buffer for the word
	ptrdiff_t _k = 0;
	ptrdiff_t _k0 = 0;
	ptrdiff_t _j = 0;	   // offset within the string

	/**
	 * cons returns true, if b[i] is a consonant
	 */
	bool isConsonant(ptrdiff_t i)
	{
		if (_b[i].isEnglishVowel)
			return false;
		if (_b[i] == 'y')
		{
			if (i == _k0)
			{
				return true;
			}
			else
			{
				return !isConsonant(i - 1);
			}
		}
		return true;
	}

	/** Return the number of consonant sequences between k0 and j.
	 * if c is a consonant sequence and v a vowel sequence, and <..>
	 * indicates arbitrary presence,
	 *
	 * <c><v>	   gives 0
	 * <c>vc<v>	 gives 1
	 * <c>vcvc<v>   gives 2
	 * <c>vcvcvc<v> gives 3
	 *
	 */
	size_t m()
	{
		ptrdiff_t n = 0;
		ptrdiff_t i = _k0;

		while (true)
		{
			if (i > _j)
			{
				return n;
			}
			if (!isConsonant(i))
			{
				break;
			}
			i++;
		}
		i++;
		while (true)
		{
			while (true)
			{
				if (i > _j)
				{
					return n;
				}
				if (isConsonant(i))
				{
					break;
				}
				i++;
			}
			i++;
			n++;
			while (true)
			{
				if (i > _j)
				{
					return n;
				}
				if (!isConsonant(i))
				{
					break;
				}
				i++;
			}
			i++;
		}
	}

	/** Returns true if k0...j contains a vowel. */
	bool hasVowelInStem()
	{
		for (ptrdiff_t i = _k0; i < _j + 1; i++)
		{
			if (!isConsonant(i))
				return true;
		}
		return false;
	}

	/** Returns true if j, j-1 contains a double consonant
	 */
	bool doublec(ptrdiff_t j)
	{
		if (j < (_k0 + 1))
			return false;
		if (_b[j] != _b[j-1])
			return false;
		return isConsonant(j);
	}

	/** Returns true if i-2,i-1,i has the form consonant - vowel - consonant
	 * and also if the second c is not w,x or y. this is used when trying to
	 * restore an e at the end of a short  e.g.
	 *
	 *	cav(e), lov(e), hop(e), crim(e), but
	 *	snow, box, tray.
	 *
	 */
	bool cvc(ptrdiff_t i)
	{
		if (i < (_k0 + 2) || !isConsonant(i) || isConsonant(i-1) || !isConsonant(i-2))
			return false;
		if (_b[i] == 'w' || _b[i] == 'x' || _b[i] == 'y')
			return false;
		return true;
	}

	/** Return true if k0,...k endsWith with the string s.
	 */
	bool endsWith(S)(S s)
	if (isSomeString!S)
	{
		const len = s.length;

		if (s[len - 1] != _b[_k])
			return false;
		if (len > (_k - _k0 + 1))
			return false;

		const a = _k - len + 1;
		const b = _k + 1;

		if (_b[a..b] != s)
		{
			return false;
		}
		_j = _k - len;

		return true;
	}

	/** Sets (j+1),...k to the characters in the string s, readjusting k. */
	void setto(S)(S s)
	if (isSomeString!S)
	{
		_b = _b[0.._j+1] ~ s ~ _b[_j + s.length + 1 .. _b.length];
		_k = _j + s.length;
	}

	/** Used further down. */
	void r(S)(S s)
	if (isSomeString!S)
	{
		if (m() > 0)
			setto(s);
	}

	/** Gets rid of plurals and -ed or -ing. e.g. */
	void step1ab()
	{
		if (_b[_k] == 's')
		{
			if (endsWith("sses"))
			{
				_k = _k - 2;
			}
			else if (endsWith("ies"))
			{
				setto("i");
			}
			else if (_b[_k - 1] != 's')
			{
				_k--;
			}
		}
		if (endsWith("eed"))
		{
			if (m() > 0)
				_k--;
		}
		else if ((endsWith("ed") || endsWith("ing")) && hasVowelInStem())
		{
			_k = _j;
			if (endsWith("at"))
			{
				setto("ate");
			}
			else if (endsWith("bl"))
			{
				setto("ble");
			}
			else if (endsWith("iz"))
			{
				setto("ize");
			}
			else if (doublec(_k))
			{
				_k--;
				if (_b[_k] == 'l' || _b[_k] == 's' || _b[_k] == 'z')
					_k++;
			}
			else if (m() == 1 && cvc(_k))
			{
				setto("e");
			}
		}
	}

	/**
	 * step1c() turns terminal y to i when there is another vowel in the stem.
	 */
	void step1c()
	{
		if (endsWith("y") &&
			!endsWith("day") &&
			hasVowelInStem())
		{
			_b = _b[0.._k] ~ 'i' ~ _b[_k+1 .. _b.length];
		}
	}

	/**
	 * step2() maps double suffices to single ones.
	 * so -ization (= -ize plus -ation) maps to -ize etc. note that the
	 * string before the suffix must give m() > 0.*
	 */
	void step2()
	{
		if (_b[_k - 1] == 'a')
		{
			if (endsWith("ational"))
				r("ate");
			else if (endsWith("tional"))
				r("tion");
		}
		else if (_b[_k - 1] == 'c')
		{
			if (endsWith("enci"))
				r("ence");
			else if (endsWith("anci"))
				r("ance");
		}
		else if (_b[_k - 1] == 'e')
		{
			if (endsWith("izer"))
				r("ize");
		}
		else if (_b[_k - 1] == 'l')
		{
			if (endsWith("bli"))
				r("ble");
			/* --DEPARTURE--
			 * To match the published algorithm, replace this phrase with
			 * if (endsWith("abli"))
			 *	   r("able");
			 */
			else if (endsWith("alli"))
				r("al");
			else if (endsWith("entli"))
				r("ent");
			else if (endsWith("eli"))
				r("e");
			else if (endsWith("ousli"))
				r("ous");
		}
		else if (_b[_k - 1] == 'o')
		{
			if (endsWith("ization"))
				r("ize");
			else if (endsWith("ation") || endsWith("ator"))
				r("ate");
		}
		else if (_b[_k - 1] == 's')
		{
			if (endsWith("alism"))
				r("al");
			else if (endsWith("iveness"))
				r("ive");
			else if (endsWith("fulness"))
				r("ful");
			else if (endsWith("ousness"))
				r("ous");
		}
		else if (_b[_k - 1] == 't')
		{
			if (endsWith("aliti"))
				r("al");
			else if (endsWith("iviti"))
				r("ive");
			else if (endsWith("biliti"))
				r("ble");
		}
		else if (_b[_k - 1] == 'g')
		{
			/**
			 * --DEPARTURE--
			 * To match the published algorithm, delete this phrase
			 */
			if (endsWith("logi"))
				r("log");
		}
	}

	/**
	 * step3() dels with -ic-, -full, -ness etc. similar strategy to step2.
	 */
	void step3()
	{
		if (_b[_k] == 'e')
		{
			if	  (endsWith("icate")) r("ic");
			else if (endsWith("ative")) r("");
			else if (endsWith("alize")) r("al");
		}
		else if (_b[_k] == 'i')
		{
			if (endsWith("iciti")) r("ic");
		}
		else if (_b[_k] == 'l')
		{
			if	  (endsWith("ical")) r("ic");
			else if (endsWith("ful")) r("");
		}
		else if (_b[_k] == 's')
		{
			if (endsWith("ness")) r("");
		}
	}

	/**
	 * step4() takes off -ant, -ence etc., in context <c>vcvc<v>.
	 */
	void step4()
	{
		/* fixes bug 1 */
		if (_k == 0)
			return;
		switch (_b[_k - 1])
		{
			case 'a':
				if (endsWith("al"))
					break;
				return;
			case 'c':
				if (endsWith("ance") || endsWith("ence"))
					break;
				return;
			case 'e':
				if (endsWith("er"))
					break;
				return;
			case 'i':
				if (endsWith("ic"))
					break;
				return;
			case 'l':
				if (endsWith("able") || endsWith("ible"))
					break;
				return;
			case 'n':
				if (endsWith("ant") || endsWith("ement") || endsWith("ment") || endsWith("ent"))
					break;
				return;
			case 'o':
				if (endsWith("ion") && _j >= 0 && (_b[_j] == 's' || _b[_j] == 't'))
				{
					/* _j >= 0 fixes bug 2 */
					break;
				}
				if (endsWith("ou"))
					break;
				return;
			case 's':
				if (endsWith("ism"))
					break;
				return;
			case 't':
				if (endsWith("ate") || endsWith("iti"))
					break;
				return;
			case 'u':
				if (endsWith("ous"))
					break;
				return;
			case 'v':
				if (endsWith("ive"))
					break;
				return;
			case 'z':
				if (endsWith("ize"))
					break;
				return;
			default:
				return;
		}

		if (m() > 1)
			_k = _j;

	}

	/**
	 * step5() removes a final -e if m() > 1, and changes -ll to -l if m() > 1.
	 */
	void step5()
	{
		_j = _k;
		if (_b[_k] == 'e' &&
			_b[0 .. _k] != `false`)
		{
			auto a = m();
			if (a > 1 || (a == 1 && !cvc(_k - 1)))
				_k--;
		}
		if (_b[_k] == 'l' && doublec(_k) && m() > 1)
			_k--;
	}
}

unittest {
	scope stemmer = new Stemmer!string();

	assert(stemmer.stem("") == "");
	assert(stemmer.stem("x") == "x");
	assert(stemmer.stem("xyz") == "xyz");
	assert(stemmer.stem("win") == "win");
	/+ TODO: assert(stemmer.stem("winner") == "win"); +/
	assert(stemmer.stem("winning") == "win");
	assert(stemmer.stem("farted") == "fart");
	assert(stemmer.stem("caresses") == "caress");
	assert(stemmer.stem("ponies") == "poni");
	assert(stemmer.stem("ties") == "ti");
	assert(stemmer.stem("caress") == "caress");
	assert(stemmer.stem("cats") == "cat");
	assert(stemmer.stem("feed") == "feed");
	assert(stemmer.stem("matting") == "mat");
	assert(stemmer.stem("mating") == "mate");
	assert(stemmer.stem("meeting") == "meet");
	assert(stemmer.stem("milling") == "mill");
	assert(stemmer.stem("messing") == "mess");
	assert(stemmer.stem("meetings") == "meet");
	assert(stemmer.stem("neutralize") == "neutral");
	assert(stemmer.stem("relational") == "relat");
	assert(stemmer.stem("relational") == "relat");
	assert(stemmer.stem("intricate") == "intric");

	assert(stemmer.stem("connection") == "connect");
	assert(stemmer.stem("connective") == "connect");
	assert(stemmer.stem("connecting") == "connect");

	assert(stemmer.stem("agreed") == "agre");
	assert(stemmer.stem("disabled") == "disabl");
	assert(stemmer.stem("gentle") == "gentl");
	assert(stemmer.stem("gently") == "gentli");
	assert(stemmer.stem("served") == "serv");
	assert(stemmer.stem("competes") == "compet");

	assert(stemmer.stem("fullnessful") == "fullness");
	assert(stemmer.stem(stemmer.stem("fullnessful")) == "full");

	assert(stemmer.stem("bee") == "bee");

	assert(stemmer.stem("dogs") == "dog");
	assert(stemmer.stem("churches") == "church");
	assert(stemmer.stem("hardrock") == "hardrock");

	/+ TODO: assert(stemmer.stem("false") == "false"); +/
}

import nxt.debugio;

/** Stem Swedish Word $(D s).
 */
auto ref stemSwedish(S)(S s)
if (isSomeString!S)
{
	enum ar = `ar`;
	enum or = `or`;
	enum er = `er`;
	enum ya = `ya`;

	enum en = `en`;
	enum ern = `ern`;
	enum an = `an`;
	enum na = `na`;
	enum et = `et`;
	enum aste = `aste`;
	enum are = `are`;
	enum ast = `ast`;
	enum iserad = `iserad`;
	enum de = `de`;
	enum ing = `ing`;
	enum igt = `igt`;
	enum llt = `llt`;

	switch (s)
	{
		case `samtida`: return `samtid`;
		default: break;
	}

	if (s.endsWith(`n`))
	{
		if (s.endsWith(en))
		{
			const t = s[0 .. $ - en.length];
			if (s.among!(`även`))
			{
				return s;
			}
			else if (t.among!(`sann`))
			{
				return t;
			}
			else if (t.endsWith(`mm`, `nn`))
			{
				return t[0 .. $ - 1];
			}
			return t;
		}
		if (s.endsWith(ern))
		{
			return s[0 .. $ - 1];
		}
		if (s.endsWith(an))
		{
			const t = s[0 .. $ - an.length];
			if (t.length >= 3 &&
				t.endsWith(`tt`, `mp`, `ck`, `st`))
			{
				return s[0 ..$ - 1];
			}
			else if (t.length >= 2 &&
					 t.endsWith(`n`, `p`))
			{
				return s[0 ..$ - 1];
			}
			else if (t.length < 3)
			{
				return s;
			}
			return t;
		}
	}

	if (s.endsWith(igt))
	{
		return s[0 .. $ - 1];
	}

	if (s.endsWith(ya))
	{
		return s[0 .. $ - 1];
	}

	if (s.endsWith(na))
	{
		if (s.among!(`sina`, `dina`, `mina`))
		{
			return s[0 .. $ - 1];
		}
		auto t = s[0 .. $ - na.length];
		if (t.endsWith(`r`))
		{
			if (t.endsWith(ar, or, er))
			{
				const u = t[0 .. $ - ar.length];
				if (u.canFind!(a => a.isSwedishVowel))
				{
					return u;
				}
				else
				{
					return t[0 .. $ - 1];
				}
			}
		}
	}

	if (s.endsWith(et))
	{
		const t = s[0 .. $ - et.length];
		if (t.length >= 3 &&
			t[$ - 3].isSwedishConsonant &&
			t[$ - 2].isSwedishConsonant &&
			t[$ - 1].isSwedishConsonant)
		{
			return s[0 .. $ - 1];
		}
		else if (t.endsWith(`ck`))
		{
			return s[0 .. $ - 1];
		}

		return t;
	}

	if (s.endsWith(ar, or, er))
	{
		const t = s[0 .. $ - ar.length];
		if (t.canFind!(a => a.isSwedishVowel))
		{
			if (t.endsWith(`mm`, `nn`))
			{
				return t[0 .. $ - 1];
			}
			else
			{
				return t;
			}
		}
		else
		{
			return s[0 .. $ - 1];
		}
	}

	if (s.endsWith(aste))
	{
		const t = s[0 .. $ - aste.length];
		if (t.among!(`sann`))
		{
			return t;
		}
		if (t.endsWith(`mm`, `nn`))
		{
			return t[0 .. $ - 1];
		}
		if (t.canFind!(a => a.isSwedishVowel))
		{
			return t;
		}
	}

	if (s.endsWith(are, ast))
	{
		const t = s[0 .. $ - are.length];
		if (t.among!(`sann`))
		{
			return t;
		}
		if (t.endsWith(`mm`, `nn`))
		{
			return t[0 .. $ - 1];
		}
		if (t.canFind!(a => a.isSwedishVowel))
		{
			return t;
		}
	}

	if (s.endsWith(iserad))
	{
		const t = s[0 .. $ - iserad.length];
		if (!t.endsWith(`n`))
		{
			return t;
		}
	}

	if (s.endsWith(de))
	{
		enum ande = `ande`;
		if (s.endsWith(ande))
		{
			const t = s[0 .. $ - ande.length];
			if (t.empty)
			{
				return s;
			}
			else if (t[$ - 1].isSwedishConsonant)
			{
				return s[0 .. $ - 3];
			}
			return t;
		}
		if (s.among!(`hade`))
		{
			return s;
		}
		const t = s[0 .. $ - de.length];
		return t;
	}

	if (s.endsWith(ing))
	{
		enum ning = `ning`;
		if (s.endsWith(ning))
		{
			const t = s[0 .. $ - ning.length];
			if (!t.endsWith(`n`) &&
				t != `tid`)
			{
				return t;
			}
		}
		return s[0 .. $ - ing.length];
	}

	if (s.endsWith(llt))
	{
		return s[0 .. $ - 1];
	}

	return s;
}

unittest {
	// import nxt.assert_ex;

	assert("rumpan".stemSwedish == "rumpa");
	assert("sopan".stemSwedish == "sopa");
	assert("kistan".stemSwedish == "kista");

	assert("karl".stemSwedish == "karl");

	assert("grenen".stemSwedish == "gren");
	assert("busen".stemSwedish == "bus");
	assert("husen".stemSwedish == "hus");
	assert("räven".stemSwedish == "räv");
	assert("dunken".stemSwedish == "dunk");
	assert("männen".stemSwedish == "män");
	assert("manen".stemSwedish == "man");
	assert("mannen".stemSwedish == "man");

	assert("skalet".stemSwedish == "skal");
	assert("karet".stemSwedish == "kar");
	assert("taket".stemSwedish == "tak");
	assert("stinget".stemSwedish == "sting");

	assert("äpplet".stemSwedish == "äpple");

	assert("jakt".stemSwedish == "jakt");

	assert("sot".stemSwedish == "sot");
	assert("sotare".stemSwedish == "sot");

	assert("klok".stemSwedish == "klok");
	assert("klokare".stemSwedish == "klok");
	assert("klokast".stemSwedish == "klok");

	assert("stark".stemSwedish == "stark");
	assert("starkare".stemSwedish == "stark");
	assert("starkast".stemSwedish == "stark");

	assert("kort".stemSwedish == "kort");
	assert("kortare".stemSwedish == "kort");
	assert("kortast".stemSwedish == "kort");

	assert("rolig".stemSwedish == "rolig");
	assert("roligare".stemSwedish == "rolig");
	assert("roligast".stemSwedish == "rolig");

	assert("dum".stemSwedish == "dum");
	assert("dummare".stemSwedish == "dum");
	assert("dummast".stemSwedish == "dum");
	assert("dummaste".stemSwedish == "dum");
	assert("senaste".stemSwedish == "sen");

	assert("sanning".stemSwedish == "sann");
	assert("sann".stemSwedish == "sann");
	assert("sannare".stemSwedish == "sann");
	assert("sannare".stemSwedish == "sann");

	assert("stare".stemSwedish == "stare");
	assert("kvast".stemSwedish == "kvast");

	assert("täcket".stemSwedish == "täcke");
	assert("räcket".stemSwedish == "räcke");

	assert("van".stemSwedish == "van");
	assert("dan".stemSwedish == "dan");
	assert("man".stemSwedish == "man");
	assert("ovan".stemSwedish == "ovan");
	assert("stan".stemSwedish == "stan");
	assert("klan".stemSwedish == "klan");

	assert("klockan".stemSwedish == "klocka");
	assert("klockande".stemSwedish == "klocka");
	assert("sockan".stemSwedish == "socka");
	assert("rockan".stemSwedish == "rocka");
	assert("rock".stemSwedish == "rock");

	assert("agenter".stemSwedish == "agent");
	assert("agenterna".stemSwedish == "agent");
	assert("regenter".stemSwedish == "regent");
	assert("regenterna".stemSwedish == "regent");

	assert("brodern".stemSwedish == "broder");
	assert("kärnan".stemSwedish == "kärna");

	assert("skorna".stemSwedish == "sko");

	assert("inträffade".stemSwedish == "inträffa");
	assert("roa".stemSwedish == "roa");
	assert("roade".stemSwedish == "roa");
	assert("hade".stemSwedish == "hade");
	assert("hades".stemSwedish == "hades");

	assert("fullt".stemSwedish == "full");

	assert("kanaliserad".stemSwedish == "kanal");
	assert("alkoholiserad".stemSwedish == "alkohol");

	assert("roande".stemSwedish == "ro");

	/* assertEqual("ror".stemSwedish, "ro"); */
	/* assertEqual("öbor".stemSwedish, "öbo"); */

	assert("ande".stemSwedish == "ande");

	assert("störande".stemSwedish == "störa");
	assert("nekande".stemSwedish == "neka");
	assert("jagande".stemSwedish == "jaga");
	assert("stimulerande".stemSwedish == "stimulera");

	assert("karlar".stemSwedish == "karl");
	assert("lagar".stemSwedish == "lag");

	assert("sina".stemSwedish == "sin");
	assert("dina".stemSwedish == "din");
	assert("mina".stemSwedish == "min");

	assert("även".stemSwedish == "även");

	assert("samtida".stemSwedish == "samtid");

	assert("trattar".stemSwedish == "tratt");

	assert("katter".stemSwedish == "katt");
	assert("dagar".stemSwedish == "dag");
	assert("öar".stemSwedish == "ö");
	assert("åar".stemSwedish == "å");
	assert("ängar".stemSwedish == "äng");

	assert("spelar".stemSwedish == "spel");
	assert("drar".stemSwedish == "dra");

	assert("kullar".stemSwedish == "kull");
	assert("kullarna".stemSwedish == "kull");

	assert("mamma".stemSwedish == "mamma");

	assert("bestyr".stemSwedish == "bestyr");

	assert("krya".stemSwedish == "kry");
	assert("nya".stemSwedish == "ny");

	assert("lemmar".stemSwedish == "lem");

	/* assertEqual("ämnar".stemSwedish, "ämna"); */
	/* assert("rämnar".stemSwedish == "rämna"); */
	/* assert("lämnar".stemSwedish == "lämna"); */
}

auto ref stemNorvegian(S)(S s)
if (isSomeString!S)
{
	s.skipOverBack(`ede`);
	return s;
}

/** Stem $(D s) in Language $(D lang).
	If lang is unknown try each known language until failure.
 */
Tuple!(S, Language_ISO_639_1) stemIn(S)(S s, Language_ISO_639_1 lang = Language_ISO_639_1.init)
if (isSomeString!S)
{
	typeof(return) t;
	switch (lang) with (Language_ISO_639_1)
	{
		case unknown:
			t = s.stemIn(en); if (t[0].length != s.length) return t;
			t = s.stemIn(sv); if (t[0].length != s.length) return t;
			t = s.stemIn(no); if (t[0].length != s.length) return t;
			break;
		case sv: t = tuple(s.stemSwedish, sv); break;
		case no: t = tuple(s.stemNorvegian, no); break;
		case en:
		default:
			auto stemmer = new Stemmer!string();
			t = tuple(stemmer.stem(s), lang);
	}
	return t;
}

/** Destructively Stem $(D s) in Language $(D lang). */
Tuple!(bool, Language_ISO_639_1) stemize(S)(ref S s, Language_ISO_639_1 lang = Language_ISO_639_1.init)
if (isSomeString!S)
{
	const n = s.length;
	auto t = s.stemIn(lang);
	s = t[0];
	return tuple(n != s.length, t[1]);
}

/** Return Stem of $(D s) using Porter's algorithm
	See_Also: https://en.wikipedia.org/wiki/I_m_still_remembering
	See_Also: https://en.wikipedia.org/wiki/Martin_Porter
	See_Also: https://www.youtube.com/watch?v=2s7f8mBwnko&list=PL6397E4B26D00A269&index=4.
*/
S alternativePorterStemEnglish(S)(S s)
if (isSomeString!S)
{
	/* Step 1a */
	if	  (s.endsWith(`sses`)) { s = s[0 .. $-2]; }
	else if (s.endsWith(`ies`))  { s = s[0 .. $-2]; }
	else if (s.endsWith(`ss`))   { }
	else if (s.endsWith(`s`))	{ s = s[0 .. $-1]; }

	/* Step 2 */
	if	  (s.endsWith(`ational`)) { s = s[0 .. $-7] ~ `ate`; }
	else if (s.endsWith(`izer`))	{ s = s[0 .. $-1]; }
	else if (s.endsWith(`ator`))	{ s = s[0 .. $-2] ~ `e`; }

	/* Step 3 */
	else if (s.endsWith(`al`)) { s = s[0 .. $-2] ~ `e`; }
	else if (s.endsWith(`able`)) { s = s[0 .. $-4]; }
	else if (s.endsWith(`ate`)) { s = s[0 .. $-3] ~ `e`; }

	return s;
}

unittest {
	assert(`caresses`.alternativePorterStemEnglish == `caress`);
	assert(`ponies`.alternativePorterStemEnglish == `poni`);
	assert(`caress`.alternativePorterStemEnglish == `caress`);
	assert(`cats`.alternativePorterStemEnglish == `cat`);

	assert(`relational`.alternativePorterStemEnglish == `relate`);
	assert(`digitizer`.alternativePorterStemEnglish == `digitize`);
	assert(`operator`.alternativePorterStemEnglish == `operate`);

	assert(`revival`.alternativePorterStemEnglish == `revive`);
	assert(`adjustable`.alternativePorterStemEnglish == `adjust`);
	assert(`activate`.alternativePorterStemEnglish == `active`);
}
