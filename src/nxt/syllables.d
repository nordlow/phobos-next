module nxt.syllables;

import nxt.iso_639_1 : Language;
import std.traits: isSomeString;
import std.uni: byGrapheme;

/** Count Number of Syllables in $(D s) interpreted in language $(D lang).

	The Algorithm:

	- If number of letters <= 3 : return 1. Incorrect for Ira, weapon:usi.

	- If doesn’t end with “ted” or “tes” or “ses” or “ied” or “ies”, discard
	  “es” and “ed” at the end. If it has only 1 vowel or 1 set of consecutive
	  vowels, discard. (like “speed”, “fled” etc.)

	 - Discard trailing “e”, except where ending is “le” and isn’t in the
	   le_except array

	- Check if consecutive vowels exists, triplets or pairs, count them as one.

	- Count remaining vowels in the word.

	- Add one if begins with “mc”

	- Add one if ends with “y” but is not surrouned by vowel. (ex. “mickey”)

	- Add one if “y” is surrounded by non-vowels and is not in the last
	  word. (ex. “python”)

	- If begins with “tri-” or “bi-” and is followed by a vowel, add one. (so
	  that “ia” at “triangle” won’t be mistreated by step 4)

	- If ends with “-ian”, should be counted as two syllables, except for
	  “-tian” and “-cian”. (ex. “indian” and “politician” should be handled
	  differently and shouldn’t be mistreated by step 4)

	- If begins with “co-” and is followed by a vowel, check if it exists in the
	  double syllable dictionary, if not, check if in single dictionary and act
	  accordingly. (co_one and co_two dictionaries handle it. Ex. “coach” and
	  “coapt” shouldn’t be treated equally by step 4)

	- If starts with “pre-” and is followed by a vowel, check if exists in the
	  double syllable dictionary, if not, check if in single dictionary and act
	  accordingly. (similar to step 11, but very weak dictionary for the moment)

	- Check for “-n’t” and cross match with dictionary to add
	  syllable. (ex. “doesn’t”, “couldn’t”)

	- Handling the exceptional words. (ex. “serious”, “fortunately”)

	Like I said earlier, this isn’t perfect, so there are some steps to add or
	modify, but it works just “fine”. Some exceptions should be added such as
	“evacuate”, “ambulances”, “shuttled”, “anyone” etc… Also it can’t handle
	some compund words like “facebook”. Counting only “face” would result
	correctly “1″, and “book” would also come out correct, but due to the “e”
	letter not being detected as a “silent e”, “facebook” will return “3
	syllables.”

	See_Also: http://eayd.in/?p=232
	See_Also: http://forum.dlang.org/thread/ovzcetxbrdblpmyizdjr@forum.dlang.org#post-ovzcetxbrdblpmyizdjr:40forum.dlang.org
 */
uint countSyllables(S)(S s, Language_ISO_639_1 lang = Language_ISO_639_1.en)
if (isSomeString!S)
{
	import std.string: toLower;
	s = s.toLower;

	enum exception_add = ["serious", "crucial"]; /* words that need extra syllables */
	enum exception_del = ["fortunately", "unfortunately"]; /* words that need less syllables */
	enum co_one = ["cool", "coach", "coat", "coal", "count", "coin", "coarse", "coup", "coif", "cook", "coign", "coiffe", "coof", "court"];
	enum co_two = ["coapt", "coed", "coinci"];
	enum pre_one = ["preach"];

	uint syls = 0;  // added syllable number
	uint disc = 0; // discarded syllable number

	return 0;
}

/* what about the word ira? */
/* #1) if letters < 3 : return 1 */
/*	 if len(word) <= 3 : */
/* syls = 1 */
/* return syls */

/* #2) if doesn't end with "ted" or "tes" or "ses" or "ied" or "ies", discard "es" and "ed" at the end. */
/*	 # if it has only 1 vowel or 1 set of consecutive vowels, discard. (like "speed", "fled" etc.) */

/*	 if word[-2:] == "es" or word[-2:] == "ed" : */
/*		 doubleAndtripple_1 = len(re.findall(r'[eaoui][eaoui]',word)) */
/*		 if doubleAndtripple_1 > 1 or len(re.findall(r'[eaoui][^eaoui]',word)) > 1 : */
/*			 if word[-3:] == "ted" or word[-3:] == "tes" or word[-3:] == "ses" or word[-3:] == "ied" or word[-3:] == "ies" : */
/*				 pass */
/*			 else : */
/*				 disc+=1 */

/*	 #3) discard trailing "e", except where ending is "le" */

/*	 le_except = ['whole','mobile','pole','male','female','hale','pale','tale','sale','aisle','whale','while'] */

/*	 if word[-1:] == "e" : */
/*		 if word[-2:] == "le" and word not in le_except : */
/*			 pass */

/*		 else : */
/*			 disc+=1 */

/*	 #4) check if consecutive vowels exists, triplets or pairs, count them as one. */

/*	 doubleAndtripple = len(re.findall(r'[eaoui][eaoui]',word)) */
/*	 tripple = len(re.findall(r'[eaoui][eaoui][eaoui]',word)) */
/*	 disc+=doubleAndtripple + tripple */

/*	 #5) count remaining vowels in word. */
/*	 numVowels = len(re.findall(r'[eaoui]',word)) */

/*	 #6) add one if starts with "mc" */
/*	 if word[:2] == "mc" : */
/*		 syls+=1 */

/*	 #7) add one if ends with "y" but is not surrouned by vowel */
/*	 if word[-1:] == "y" and word[-2] not in "aeoui" : */
/*		 syls +=1 */

/*	 #8) add one if "y" is surrounded by non-vowels and is not in the last word. */

/*	 for i,j in enumerate(word) : */
/*		 if j == "y" : */
/*			 if (i != 0) and (i != len(word)-1) : */
/*				 if word[i-1] not in "aeoui" and word[i+1] not in "aeoui" : */
/*					 syls+=1 */

/*	 #9) if starts with "tri-" or "bi-" and is followed by a vowel, add one. */

/*	 if word[:3] == "tri" and word[3] in "aeoui" : */
/*		 syls+=1 */

/*	 if word[:2] == "bi" and word[2] in "aeoui" : */
/*		 syls+=1 */

/*	 #10) if ends with "-ian", should be counted as two syllables, except for "-tian" and "-cian" */

/*	 if word[-3:] == "ian" : */
/*	 #and (word[-4:] != "cian" or word[-4:] != "tian") : */
/*		 if word[-4:] == "cian" or word[-4:] == "tian" : */
/*			 pass */
/*		 else : */
/*			 syls+=1 */

/*	 #11) if starts with "co-" and is followed by a vowel, check if exists in the double syllable dictionary, if not, check if in single dictionary and act accordingly. */

/*	 if word[:2] == "co" and word[2] in 'eaoui' : */

/*		 if word[:4] in co_two or word[:5] in co_two or word[:6] in co_two : */
/*			 syls+=1 */
/*		 elif word[:4] in co_one or word[:5] in co_one or word[:6] in co_one : */
/*			 pass */
/*		 else : */
/*			 syls+=1 */

/*	 #12) if starts with "pre-" and is followed by a vowel, check if exists in the double syllable dictionary, if not, check if in single dictionary and act accordingly. */

/*	 if word[:3] == "pre" and word[3] in 'eaoui' : */
/*		 if word[:6] in pre_one : */
/*			 pass */
/*		 else : */
/*			 syls+=1 */

/*	 #13) check for "-n't" and cross match with dictionary to add syllable. */

/*	 negative = ["doesn't", "isn't", "shouldn't", "couldn't","wouldn't"] */

/*	 if word[-3:] == "n't" : */
/*		 if word in negative : */
/*			 syls+=1 */
/*		 else : */
/*			 pass */

/*	 #14) Handling the exceptional words. */

/*	 if word in exception_del : */
/*		 disc+=1 */

/*	 if word in exception_add : */
/*		 syls+=1 */

/*	 # calculate the output */
/*	 return numVowels - disc + syls */
