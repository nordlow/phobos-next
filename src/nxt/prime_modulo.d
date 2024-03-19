/** Optimized prime modulo calculations.
 *
 * Used for fast prime modulo calculations when using simple hash-functions to
 * index in hash tables (associative arrays).
 *
 * See_Also: https://www.reddit.com/r/cpp/comments/anbmol/robin_hoodunordered_map_is_now_the_fastest_hashmap/
 * See_Also: https://github.com/martinus/robin-hood-hashing
 * See_Also: https://probablydance.com/2017/02/26/i-wrote-the-fastest-hashtable/
 */
module nxt.prime_modulo;

pure nothrow @safe @nogc:

static assert(size_t.sizeof == 8, "This module currently only supports 64-bit platforms");

/** Type-safe index into prime number constants `primeConstants`.
 */
struct PrimeIndex
{
	private ubyte _ix;		  ///< The index.
	alias _ix this;			 ///< PrimeIndex becomes type-safe wrapper to `_ix`.
}

/** Returns: first prime in `primeConstants` >= `value`, where the linear search
 * in `primeConstants` starts at `primeIndex`.
 *
 * Increases `primeIndex` so that `primeConstants[primeIndex]` equals returned
 * value.
 */
size_t ceilingPrime(in size_t value,
					scope ref PrimeIndex primeIndex)
{
	foreach (const nextPrimeIndex; primeIndex .. PrimeIndex(primeConstants.length))
	{
		immutable prime = primeConstants[nextPrimeIndex];
		if (value <= prime)
		{
			primeIndex = nextPrimeIndex;
			return prime;
		}
	}
	assert(0, "Parameter value is too large");
}

/// verify for small modulos
unittest {
	size_t value = 0;		   // to be adjusted to nearest prime in `primeConstants`
	auto i = PrimeIndex(0);

	value = 0;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 0);

	value = 1;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 2);
	assert(value == 2);

	value = 2;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 2);
	assert(value == 2);

	value = 3;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 3);
	assert(value == 3);

	value = 4;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 5);
	assert(value == 5);

	value = 5;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 5);
	assert(value == 5);

	value = 6;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 7);
	assert(value == 7);

	value = 7;
	value = ceilingPrime(value, i);
	assert(primeConstants[i] == 7);

	foreach (const ix; 8 .. 11 + 1)
	{
		value = ix;
		value = ceilingPrime(value, i);
		assert(value == 11);
		assert(primeConstants[i] == 11);
	}

	foreach (const ix; 12 .. 13 + 1)
	{
		value = ix;
		value = ceilingPrime(value, i);
		assert(value == 13);
		assert(primeConstants[i] == 13);
	}

	foreach (const ix; 14 .. 17 + 1)
	{
		value = ix;
		value = ceilingPrime(value, i);
		assert(value == 17);
		assert(primeConstants[i] == 17);
	}

	foreach (const ix; 18 .. 23 + 1)
	{
		value = ix;
		value = ceilingPrime(value, i);
		assert(value == 23);
		assert(primeConstants[i] == 23);
	}
}

/// remaining modulos
unittest {
	foreach (const prime; primeConstants[3 .. $])
	{
		size_t value = prime - 1;
		PrimeIndex primeIndex;
		value = ceilingPrime(value, primeIndex);
		assert(value == prime);
		assert(moduloPrimeIndex(value, primeIndex) == 0);
	}
}

size_t moduloPrimeIndex(in size_t value,
						in PrimeIndex primeIndex)
{
	final switch (primeIndex)
	{
		static foreach (const index, const primeConstant; primeConstants)
		{
		case index:
			return value % primeConstants[index];
		}
	}
}

///
unittest {
	static assert(primeConstants.length == 187);
	assert(moduloPrimeIndex(8, PrimeIndex(3)) == 3); // modulo 5
	assert(moduloPrimeIndex(9, PrimeIndex(4)) == 2); // modulo 7
}

/// verify `moduloPrimeIndex`
unittest {
	static assert(primeConstants.length <= PrimeIndex._ix.max);
	foreach (const primeIndex, const prime; primeConstants)
	{
		if (prime != 0)
		{
			assert(moduloPrimeIndex(prime + 0, PrimeIndex(cast(typeof(PrimeIndex._ix))primeIndex)) == 0);
			assert(moduloPrimeIndex(prime + 1, PrimeIndex(cast(typeof(PrimeIndex._ix))primeIndex)) == 1);
		}
	}
}

private static:

/** Subset of prime constants in the exclusive range `[0 .. size_t.max]`.
 *
 * Suitable for use as lengths of a growing hash table.
 */
static immutable size_t[] primeConstants =
[
	0UL, 2UL, 3UL, 5UL, 7UL, 11UL, 13UL, 17UL, 23UL, 29UL, 37UL, 47UL,
	59UL, 73UL, 97UL, 127UL, 151UL, 197UL, 251UL, 313UL, 397UL,
	499UL, 631UL, 797UL, 1009UL, 1259UL, 1597UL, 2011UL, 2539UL,
	3203UL, 4027UL, 5087UL, 6421UL, 8089UL, 10193UL, 12853UL, 16193UL,
	20399UL, 25717UL, 32401UL, 40823UL, 51437UL, 64811UL, 81649UL,
	102877UL, 129607UL, 163307UL, 205759UL, 259229UL, 326617UL,
	411527UL, 518509UL, 653267UL, 823117UL, 1037059UL, 1306601UL,
	1646237UL, 2074129UL, 2613229UL, 3292489UL, 4148279UL, 5226491UL,
	6584983UL, 8296553UL, 10453007UL, 13169977UL, 16593127UL, 20906033UL,
	26339969UL, 33186281UL, 41812097UL, 52679969UL, 66372617UL,
	83624237UL, 105359939UL, 132745199UL, 167248483UL, 210719881UL,
	265490441UL, 334496971UL, 421439783UL, 530980861UL, 668993977UL,
	842879579UL, 1061961721UL, 1337987929UL, 1685759167UL, 2123923447UL,
	2675975881UL, 3371518343UL, 4247846927UL, 5351951779UL, 6743036717UL,
	8495693897UL, 10703903591UL, 13486073473UL, 16991387857UL,
	21407807219UL, 26972146961UL, 33982775741UL, 42815614441UL,
	53944293929UL, 67965551447UL, 85631228929UL, 107888587883UL,
	135931102921UL, 171262457903UL, 215777175787UL, 271862205833UL,
	342524915839UL, 431554351609UL, 543724411781UL, 685049831731UL,
	863108703229UL, 1087448823553UL, 1370099663459UL, 1726217406467UL,
	2174897647073UL, 2740199326961UL, 3452434812973UL, 4349795294267UL,
	5480398654009UL, 6904869625999UL, 8699590588571UL, 10960797308051UL,
	13809739252051UL, 17399181177241UL, 21921594616111UL, 27619478504183UL,
	34798362354533UL, 43843189232363UL, 55238957008387UL, 69596724709081UL,
	87686378464759UL, 110477914016779UL, 139193449418173UL,
	175372756929481UL, 220955828033581UL, 278386898836457UL,
	350745513859007UL, 441911656067171UL, 556773797672909UL,
	701491027718027UL, 883823312134381UL, 1113547595345903UL,
	1402982055436147UL, 1767646624268779UL, 2227095190691797UL,
	2805964110872297UL, 3535293248537579UL, 4454190381383713UL,
	5611928221744609UL, 7070586497075177UL, 8908380762767489UL,
	11223856443489329UL, 14141172994150357UL, 17816761525534927UL,
	22447712886978529UL, 28282345988300791UL, 35633523051069991UL,
	44895425773957261UL, 56564691976601587UL, 71267046102139967UL,
	89790851547914507UL, 113129383953203213UL, 142534092204280003UL,
	179581703095829107UL, 226258767906406483UL, 285068184408560057UL,
	359163406191658253UL, 452517535812813007UL, 570136368817120201UL,
	718326812383316683UL, 905035071625626043UL, 1140272737634240411UL,
	1436653624766633509UL, 1810070143251252131UL, 2280545475268481167UL,
	2873307249533267101UL, 3620140286502504283UL, 4561090950536962147UL,
	5746614499066534157UL, 7240280573005008577UL, 9122181901073924329UL,
	11493228998133068689UL, 14480561146010017169UL, 18446744073709551557UL,
];

version (none)   // deprecated by `switch` over `static foreach` in `moduloPrimeIndex`
{
	static foreach (primeConstant; primeConstants)
	{
		static if (primeConstant == 0)
		{
			mixin(`size_t mod` ~ primeConstant.stringof[0 .. $-2] ~ `(const size_t) { return ` ~ primeConstant.stringof ~ `; }`);
		}
		else
		{
			mixin(`size_t mod` ~ primeConstant.stringof[0 .. $-2] ~ `(const size_t value) { return value % ` ~ primeConstant.stringof ~ `; }`);
		}
	}
	static immutable moduloPrimeFns = [
		&mod0, &mod2, &mod3, &mod5, &mod7, &mod11, &mod13, &mod17, &mod23, &mod29, &mod37,
		&mod47, &mod59, &mod73, &mod97, &mod127, &mod151, &mod197, &mod251, &mod313, &mod397,
		&mod499, &mod631, &mod797, &mod1009, &mod1259, &mod1597, &mod2011, &mod2539, &mod3203,
		&mod4027, &mod5087, &mod6421, &mod8089, &mod10193, &mod12853, &mod16193, &mod20399,
		&mod25717, &mod32401, &mod40823, &mod51437, &mod64811, &mod81649, &mod102877,
		&mod129607, &mod163307, &mod205759, &mod259229, &mod326617, &mod411527, &mod518509,
		&mod653267, &mod823117, &mod1037059, &mod1306601, &mod1646237, &mod2074129,
		&mod2613229, &mod3292489, &mod4148279, &mod5226491, &mod6584983, &mod8296553,
		&mod10453007, &mod13169977, &mod16593127, &mod20906033, &mod26339969, &mod33186281,
		&mod41812097, &mod52679969, &mod66372617, &mod83624237, &mod105359939, &mod132745199,
		&mod167248483, &mod210719881, &mod265490441, &mod334496971, &mod421439783,
		&mod530980861, &mod668993977, &mod842879579, &mod1061961721, &mod1337987929,
		&mod1685759167, &mod2123923447, &mod2675975881, &mod3371518343, &mod4247846927,
		&mod5351951779, &mod6743036717, &mod8495693897, &mod10703903591, &mod13486073473,
		&mod16991387857, &mod21407807219, &mod26972146961, &mod33982775741, &mod42815614441,
		&mod53944293929, &mod67965551447, &mod85631228929, &mod107888587883, &mod135931102921,
		&mod171262457903, &mod215777175787, &mod271862205833, &mod342524915839,
		&mod431554351609, &mod543724411781, &mod685049831731, &mod863108703229,
		&mod1087448823553, &mod1370099663459, &mod1726217406467, &mod2174897647073,
		&mod2740199326961, &mod3452434812973, &mod4349795294267, &mod5480398654009,
		&mod6904869625999, &mod8699590588571, &mod10960797308051, &mod13809739252051,
		&mod17399181177241, &mod21921594616111, &mod27619478504183, &mod34798362354533,
		&mod43843189232363, &mod55238957008387, &mod69596724709081, &mod87686378464759,
		&mod110477914016779, &mod139193449418173, &mod175372756929481, &mod220955828033581,
		&mod278386898836457, &mod350745513859007, &mod441911656067171, &mod556773797672909,
		&mod701491027718027, &mod883823312134381, &mod1113547595345903, &mod1402982055436147,
		&mod1767646624268779, &mod2227095190691797, &mod2805964110872297, &mod3535293248537579,
		&mod4454190381383713, &mod5611928221744609, &mod7070586497075177, &mod8908380762767489,
		&mod11223856443489329, &mod14141172994150357, &mod17816761525534927,
		&mod22447712886978529, &mod28282345988300791, &mod35633523051069991,
		&mod44895425773957261, &mod56564691976601587, &mod71267046102139967,
		&mod89790851547914507, &mod113129383953203213, &mod142534092204280003,
		&mod179581703095829107, &mod226258767906406483, &mod285068184408560057,
		&mod359163406191658253, &mod452517535812813007, &mod570136368817120201,
		&mod718326812383316683, &mod905035071625626043, &mod1140272737634240411,
		&mod1436653624766633509, &mod1810070143251252131, &mod2280545475268481167,
		&mod2873307249533267101, &mod3620140286502504283, &mod4561090950536962147,
		&mod5746614499066534157, &mod7240280573005008577, &mod9122181901073924329,
		&mod11493228998133068689, &mod14480561146010017169, &mod18446744073709551557,
		];
}
