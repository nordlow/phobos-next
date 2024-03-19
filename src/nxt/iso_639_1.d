module nxt.iso_639_1;

@safe:

private alias LanguageT = ubyte;

/** ISO 639-1 language code.
 *
 * See_Also: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
 * See_Also: https://github.com/LBeaudoux/iso639
 * See_Also: http://www.lingoes.net/en/translator/langcode.htm
 * See_Also: http://www.mathguide.de/info/tools/languagecode.html
 * See_Also: http://msdn.microsoft.com/en-us/library/ms533052(v=vs.85).aspx
 */
enum Language : LanguageT {
	unknown, nullValue = unknown, // `HybridHashMap` null support

	ab, abkhaz = ab,/// Abkhaz	Caucasus	needed!
	am, amharic = am,/// Amharic	Ethopia, Egypt	ሰላም (salām)
	aa, afar = aa,/// Afar	(Ethiopia, Eritrea, Djibouti Salaamata)
	ae, avestan = ae,					   /// Avestan Iran (extinct)
	af, afrikaans = af, afr = afrikaans, /// Afrikaans
	ak, akan = ak,					   /// Akan
	an, aragonese = an,	 /// Aragonese
	ar, arabic = ar,					   /// Arabic
	as, assamese = as,			/// Assamese
	az, azerbaijani = az, azeri = azerbaijani,					   /// Azerbaijani (Azeri)
	ba, baskhir = ba,					   /// Baskhir: Volga, Urals, Central Asia
	be, belarusian = be,					   /// Belarusian
	bg, bulgarian = bg, bul = bulgarian,					  /// Bulgarian
	bn, bengali = bn,					  /// Bengali (Bangla): Bangladesh, India
	bo, tibetan = bo,					  /// Tibetan
	br, breton = br,					  /// Breton: France
	bs, bosnian = bs,					  /// Bosnian
	ca, catalan = ca, valencian = catalan, cat = valencian,					 /// Catalan/Valencian (Spain)
	cs, czech = cs, ces = czech,					  /// Czech: Czech Republic
	cy, welch = cy, welsh = welch, cym = welsh,					 /// Welch: Wales, Heddwch, Tangnefedd
	da, danish = da, dan = danish,					  /// Danish: Denmark, Greenland
	de, german = de, deu = german,					  /// German: Germany, Austria, Switzerland, Liechtenstein, Italy, Belgium
	dz, dzongkha = dz,/// Dzongkha	Bhutan	གཞི་བདེ (gzhi-bde)
	el, greek = el, ell = greek,	 /// Greek: Greece, Cyprus
	en, english = en,			/// English
	eo, esperanto = eo,					  /// Esperanto
	es, spanish = es, spa = spanish,					  /// Spanish
	et, estonian = et,					  /// Estonian
	eu, basque = eu,					   /// Basque: Spain, France
	fa, persian = fa, farsi = persian,					 /// Persian (Farsi): Iran, Iraq, Afghanistan, Pakistan, Azerbaijan
	fi, finnish = fi, fin = finnish,					  /// Finnish: Finland, Sweden, Russia
	fj, fijian = fj,					  /// Fijian: Fiji
	fo, faroese = fo,					  /// Faroese (Faeroese): Faroe Islands
	fr, french = fr, fra = french,					  /// French: France, Belgium, Canada, Caribbean, West Africa, Polynesia
	ga, irish = ga,					  /// Irish: Ireland
	gd, scottish_gaelic = gd,					  /// Scottish Gaelic: Scotland
	gl, galician = gl, gallegan = galician,					  /// Galician (Gallegan): Spain, Portugal
	gv, manx = gv,					  /// Manx: Isle of Man
	ha, hausa = ha,					  /// Hausa: Nigeria
	he, hebrew = he,					  /// Hebrew: Israel
	hi, hindi = hi,					  /// Hindi: India, Nepal, Uganda, Suriname
	hr, croatian = hr,					  /// Croatian: Croatia
	hu, hungarian = hu,					  /// Hungarian: Hungary, Romania, Slovakia
	hy, armenian = hy,					   /// Armenian: Armenia
	in_, indonesian = in_,
	io, ido = io,					  /// Ido: Nigeria
	is_, icelandic = is_,					 /// Icelandic
	it, italian = it, ita = italian,					  /// Italian: Italy, Switzerland
	ja, japanese = ja,					  /// Japanese, 日本語: Japan
	ka, georgian = ka,					  /// Georgian: Georgia
	kk, kazakh = kk,					  /// Kazakh: Kazakhstan
	km, khmer = km,					  /// Khmer: Cambodia
	kn, kannada = kn,					  /// Kannada: India
	ko, korean = ko,					  /// Korean: Korea
	ku, kurdish = ku,					  /// Kurdish: Kurdistan (Turkey, Syria, Iran, Iraq)
	ky, kirghiz = ky, kyrgyz = kirghiz,					  /// Kirghiz (Kyrgyz): Kirghizstan, China
	la, latin = la, lat = latin,					  /// Latin: Rome (extinct)
	lo, lao = lo,					  /// Lao: Laos
	lt, lithuanian = lt,					  /// Lithuanian: Lithuania
	lv, latvian = lv,					  /// Latvian: Latvia
	mg, malagasy = mg, malgache = malagasy,					/// Malagasy (Malgache): Madagascar
	mk, macedonian = mk,					  /// Macedonian: Macedonia
	mn, mongolian = mn,					  /// Mongolian: Mongolia
	ms, malay = ms, zsm = malay,			 /// Malay: Malaysia
	mt, maltese = mt,					  /// Maltese: Malta
	my, burmese = my,					  /// Burmese: Myanmar
	ne, nepali = ne,					  /// Nepali: Nepal
	nl, dutch = nl, flemish = dutch,					  /// Dutch (Flemish): Netherlands, Belgium
	no, norwegian = no, nob = norwegian,  /// Norwegian: Norway
	oc, occitan = oc,					  /// Occitan (Provençal, Languedocian): France
	pl, polish = pl,					  /// Polish
	ps, pashto = ps,					  /// Pashto: Afghanistan, Iran, Pakistan
	pt, portuguese = pt, por = portuguese,					 /// Portuguese: Portugal, Brazil, Angola, Mozambique, Cape Verde, Guinea-Bissau
	ro, romanian = ro,					  /// Romanian: Romania, Hungary
	ru, russian = ru, rus = russian,					  /// Russian
	sa, sanskrit = sa,					  /// Sanskrit: India (extinct, liturgical)
	si, sinhalese = si,					  /// Sinhalese: Sri Lanka
	sk, slovak = sk, slk = slovak,		 /// Slovak: Slovak Republic
	sl, slovene = sl, slovenian = slovene, slv = slovenian, /// Slovene, Slovenian: Slovenia, Austria, Italy
	sm, samoan = sm,					  /// Samoan: Samoa
	sq, albanian = sq,					  /// Albanian: Albania, Kosovo
	sr, serbian = sr,					  /// Serbian: Serbia, Montenegro, Bosnia
	sv, swedish = sv, swe = swedish,					   /// Swedish
	sw, swahili = sw, swa = swahili, /// Swahili: East Africa
	ta, tamil = ta, tam = tamil,		 /// Tamil: India
	te, telugu = te,					  /// Telugu: India
	tg, tajik = tg,					  /// Tajik: Tajikistan, Afghanistan
	th, thai = th, tha = thai,					  /// Thai: Thailand
	tk, turkmen = tk,					  /// Turkmen: Turkmenistan, Afghanistan
	tl, tagalog = tl, pilipino = tagalog,					  /// Tagalog (Pilipino): Philippines
	tr, turkish = tr, tur = turkish,				/// Turkish: Turkey, Cyprus
	uk, ukrainian = uk, ukr = ukrainian,   /// Ukrainian
	ur, urdu = ur,					  /// Urdu: Pakistan, India, Central Asia
	uz, uzbek = uz,					  /// Uzbek: Uzbekistan, Central Asia, China
	vi, vietnamese = vi, vie = vietnamese, /// Vietnamese: Viet Nam
	vo, volapuk = vo,					  /// Volapük
	wa, waloon = wa, wln = waloon,		 /// Waloon: Belgium
	yi, yiddish = yi, yid = yiddish, /// Yiddish: Israel, USA, Russia
	zh, chinese = zh,					  /// Chinese (Mandarin, Putonghua): China, Singapore

	holeValue = LanguageT.max,				  // `HybridHashMap` hole support,
}
// pragma(msg, cast(uint)Language.regularExpression);

/** TODO: Remove when `__traits(documentation)` is merged
 */
string toSpoken(in Language lang, in Language spokenLang = Language.init) pure nothrow @safe @nogc {
	with (Language) {
		final switch (lang) {
		case unknown: return `nullValue`;
		case holeValue: return `holeValue`;
		case aa: return `Afar`;
		case ab: return `Abkhaz`;
		case ae: return `Avestan`;
		case af: return `Afrikaans`;
		case ak: return `Akan`;
		case am: return `Amharic`;
		case an: return `Aragonese`;
		case ar: return `Arabic`;
		case as: return `Assamese`;
		case az: return `Azerbaijani`;
		case ba: return `Baskhir`;
		case be: return `Belarusian`;
		case bg: return `Bulgarian`;
		case bn: return `Bengali`;
		case bo: return `Tibetan`;
		case br: return `Breton`;
		case bs: return `Bosnian`;
		case ca: return `Catalan`;
		case cs: return `Czech`;
		case cy: return `Welch`;
		case da: return `Danish`;
		case de: return `German`;
		case dz: return `Dzongkha`;
		case el: return `Greek`;
		case en: return `English`;
		case eo: return `Esperanto`;
		case es: return `Spanish`;
		case et: return `Estonian`;
		case eu: return `Basque`;
		case fa: return `Persian`;
		case fi: return `Finnish`;
		case fj: return `Fiji`;
		case fo: return `Faroese`;
		case fr: return `French`;
		case ga: return `Irish`;
		case gd: return `Gaelic`; // Scottish Gaelic
		case gl: return `Galician`;
		case gv: return `Manx`;
		case ha: return `Hausa`;
		case he: return `Hebrew`;
		case hi: return `Hindi`;
		case hr: return `Croatian`;
		case hu: return `Hungarian`;
		case hy: return `Armenian`;
		case in_: return `Indonesian`;
		case io: return `Ido`;
		case is_: return `Icelandic`;
		case it: return `Italian`;
		case ja: return `Japanese`;
		case ka: return `Georgian`;
		case kk: return `Kazakh`;
		case km: return `Khmer`;
		case kn: return `Kannada`;
		case ko: return `Korean`;
		case ku: return `Kurdish`;
		case ky: return `Kyrgyz`;
		case la: return `Latin`;
		case lo: return `Lao`;
		case lt: return `Lithuanian`;
		case lv: return `Latvian`;
		case mg: return `Malagasy`;
		case mk: return `Macedonian`;
		case mn: return `Mongolian`;
		case ms: return `Malay`;
		case mt: return `Maltese`;
		case my: return `Burmese`;
		case ne: return `Nepali`;
		case nl: return `Dutch`;
		case no: return `Norwegian`;
		case oc: return `Occitan`;
		case pl: return `Polish`;
		case ps: return `Pashto`;
		case pt: return `Portuguese`;
		case ro: return `Romanian`;
		case ru: return `Russian`;
		case sa: return `Sanskrit`;
		case si: return `Sinhalese`;
		case sk: return `Slovak`;
		case sl: return `Slovene`;
		case sm: return `Samoan`;
		case sq: return `Albanian`;
		case sr: return `Serbian`;
		case sv: return `Swedish`;
		case sw: return `Swahili`;
		case ta: return `Tamil`;
		case te: return `Tegulu`;
		case tg: return `Tajik`;
		case th: return `Thai`;
		case tk: return `Turkmen`;
		case tl: return `Tagalog`;
		case tr: return `Turkish`;
		case uk: return `Ukrainian`;
		case ur: return `Urdu`;
		case uz: return `Uzbek`;
		case vi: return `Vietnamese`;
		case vo: return `Volapük`;
		case wa: return `Waloon`;
		case yi: return `Yiddish`;
		case zh: return `Chinese`;
		}
	}
}

/// Parse Language `lang`.
Language parseLanguage(scope const(char)[] lang, in Language defaultLang) pure nothrow @safe @nogc {
	switch (lang) {
		case `is`:
			return Language.is_;
		case `in`:
			return Language.in_;
		default:
			import nxt.conv_ex : toDefaulted;
			return typeof(return)(lang.toDefaulted!Language(defaultLang));
	}
}

///
pure nothrow @safe unittest {
	assert(`_`.parseLanguage(Language.unknown) == Language.unknown);
	assert(`_`.parseLanguage(Language.en) == Language.en);
	assert(`sv`.parseLanguage(Language.unknown) == Language.sv);
	assert(`en`.parseLanguage(Language.unknown) == Language.en);
}

/** Check if `lang` capitalize all its nouns include common nouns.
 */
bool capitalizesCommonNoun(in Language lang) pure nothrow @safe @nogc => lang == Language.de;

///
pure nothrow @safe @nogc unittest {
	assert(Language.de.capitalizesCommonNoun);
	assert(!Language.en.capitalizesCommonNoun);
}
