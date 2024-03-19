module nxt.iso_639_2;

@safe:

private alias LanguageT = ushort;

/** ISO 639-1 language code.
 *
 * See_Also: https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes
 * Ref: https://loc.gov/standards/iso639-2/ISO-639-2_utf-8.txt
 * Ref: https://github.com/ISO639/2
 */
enum Language : LanguageT {
	unknown, nullValue = unknown, // `HybridHashMap` null support
	aar,
	abk,
	ace,
	ach,
	ada,
	ady,
	afa,
	afh,
	afr,
	ain,
	aka,
	akk,
	alb,
	ale,
	alg,
	alt,
	amh,
	ang,
	anp,
	apa,
	ara,
	arc,
	arg,
	arm,
	arn,
	arp,
	art,
	arw,
	asm_,
	ast,
	ath,
	aus,
	ava,
	ave,
	awa,
	aym,
	aze,
	bad,
	bai,
	bak,
	bal,
	bam,
	ban,
	baq,
	bas,
	bat,
	bej,
	bel,
	bem,
	ben,
	ber,
	bho,
	bih,
	bik,
	bin,
	bis,
	bla,
	bnt,
	bos,
	bra,
	bre,
	btk,
	bua,
	bug,
	bul,
	bur,
	byn,
	cad,
	cai,
	car,
	cat,
	cau,
	ceb,
	cel,
	cha,
	chb,
	che,
	chg,
	chi,
	chk,
	chm,
	chn,
	cho,
	chp,
	chr,
	chu,
	chv,
	chy,
	cmc,
	cnr,
	cop,
	cor,
	cos,
	cpe,
	cpf,
	cpp,
	cre,
	crh,
	crp,
	csb,
	cus,
	cze,
	dak,
	dan,
	dar,
	day,
	del,
	den,
	dgr,
	din,
	div,
	doi,
	dra,
	dsb,
	dua,
	dum,
	dut,
	dyu,
	dzo,
	efi,
	egy,
	eka,
	elx,
	eng,
	enm,
	epo,
	est,
	ewe,
	ewo,
	fan,
	fao,
	fat,
	fij,
	fil,
	fin,
	fiu,
	fon,
	fre,
	frm,
	fro,
	frr,
	frs,
	fry,
	ful,
	fur,
	gaa,
	gay,
	gba,
	gem,
	geo,
	ger,
	gez,
	gil,
	gla,
	gle,
	glg,
	glv,
	gmh,
	goh,
	gon,
	gor,
	got,
	grb,
	grc,
	gre,
	grn,
	gsw,
	guj,
	gwi,
	hai,
	hat,
	hau,
	haw,
	heb,
	her,
	hil,
	him,
	hin,
	hit,
	hmn,
	hmo,
	hrv,
	hsb,
	hun,
	hup,
	iba,
	ibo,
	ice,
	ido,
	iii,
	ijo,
	iku,
	ile,
	ilo,
	ina,
	inc,
	ind,
	ine,
	inh,
	ipk,
	ira,
	iro,
	ita,
	jav,
	jbo,
	jpn,
	jpr,
	jrb,
	kaa,
	kab,
	kac,
	kal,
	kam,
	kan,
	kar,
	kas,
	kau,
	kaw,
	kaz,
	kbd,
	kha,
	khi,
	khm,
	kho,
	kik,
	kin,
	kir,
	kmb,
	kok,
	kom,
	kon,
	kor,
	kos,
	kpe,
	krc,
	krl,
	kro,
	kru,
	kua,
	kum,
	kur,
	kut,
	lad,
	lah,
	lam,
	lao,
	lat,
	lav,
	lez,
	lim,
	lin,
	lit,
	lol,
	loz,
	ltz,
	lua,
	lub,
	lug,
	lui,
	lun,
	luo,
	lus,
	mac,
	mad,
	mag,
	mah,
	mai,
	mak,
	mal,
	man,
	mao,
	map,
	mar,
	mas,
	may,
	mdf,
	mdr,
	men,
	mga,
	mic,
	min,
	mis,
	mkh,
	mlg,
	mlt,
	mnc,
	mni,
	mno,
	moh,
	mon,
	mos,
	mul,
	mun,
	mus,
	mwl,
	mwr,
	myn,
	myv,
	nah,
	nai,
	nap,
	nau,
	nav,
	nbl,
	nde,
	ndo,
	nds,
	nep,
	new_,
	nia,
	nic,
	niu,
	nno,
	nob,
	nog,
	non,
	nor,
	nqo,
	nso,
	nub,
	nwc,
	nya,
	nym,
	nyn,
	nyo,
	nzi,
	oci,
	oji,
	ori,
	orm,
	osa,
	oss,
	ota,
	oto,
	paa,
	pag,
	pal,
	pam,
	pan,
	pap,
	pau,
	peo,
	per,
	phi,
	phn,
	pli,
	pol,
	pon,
	por,
	pra,
	pro,
	pus,
	// qaa_qtz,
	que,
	raj,
	rap,
	rar,
	roa,
	roh,
	rom,
	rum,
	run,
	rup,
	rus,
	sad,
	sag,
	sah,
	sai,
	sal,
	sam,
	san,
	sas,
	sat,
	scn,
	sco,
	sel,
	sem,
	sga,
	sgn,
	shn,
	sid,
	sin,
	sio,
	sit,
	sla,
	slo,
	slv,
	sma,
	sme,
	smi,
	smj,
	smn,
	smo,
	sms,
	sna,
	snd,
	snk,
	sog,
	som,
	son,
	sot,
	spa,
	srd,
	srn,
	srp,
	srr,
	ssa,
	ssw,
	suk,
	sun,
	sus,
	sux,
	swa,
	swe,
	syc,
	syr,
	tah,
	tai,
	tam,
	tat,
	tel,
	tem,
	ter,
	tet,
	tgk,
	tgl,
	tha,
	tib,
	tig,
	tir,
	tiv,
	tkl,
	tlh,
	tli,
	tmh,
	tog,
	ton,
	tpi,
	tsi,
	tsn,
	tso,
	tuk,
	tum,
	tup,
	tur,
	tut,
	tvl,
	twi,
	tyv,
	udm,
	uga,
	uig,
	ukr,
	umb,
	und,
	urd,
	uzb,
	vai,
	ven,
	vie,
	vol,
	vot,
	wak,
	wal,
	war,
	was,
	wel,
	wen,
	wln,
	wol,
	xal,
	xho,
	yao,
	yap,
	yid,
	yor,
	ypk,
	zap,
	zbl,
	zen,
	zgh,
	zha,
	znd,
	zul,
	zun,
	zxx,
	zza,
	holeValue = LanguageT.max,				  // `HybridHashMap` hole support
}

/** TODO: Remove when `__traits(documentation)` is merged */
string toSpoken(in Language lang, in Language spokenLang = Language.init) pure nothrow @safe @nogc {
	with (Language) {
		final switch (lang) {
		case unknown: return `nullValue`;
		case holeValue: return `holeValue`;
		case aar: return `Afar`; // ||aa|Afar|afar
		case abk: return `Abkhazian`; // ||ab|Abkhazian|abkhaze
		case ace: return `Achinese`; // |||Achinese|aceh
		case ach: return `Acoli`; // |||Acoli|acoli
		case ada: return `Adangme`; // |||Adangme|adangme
		case ady: return `Adyghe; Adygei`; // |||Adyghe; Adygei|adyghé
		case afa: return `Afro-Asiatic languages`; // |||Afro-Asiatic languages|afro-asiatiques, langues
		case afh: return `Afrihili`; // |||Afrihili|afrihili
		case afr: return `Afrikaans`; // ||af|Afrikaans|afrikaans
		case ain: return `Ainu`; // |||Ainu|aïnou
		case aka: return `Akan`; // ||ak|Akan|akan
		case akk: return `Akkadian`; // |||Akkadian|akkadien
		case alb: return `Albanian`; // |sqi|sq|Albanian|albanais
		case ale: return `Aleut`; // |||Aleut|aléoute
		case alg: return `Algonquian languages`; // |||Algonquian languages|algonquines, langues
		case alt: return `Southern Altai`; // |||Southern Altai|altai du Sud
		case amh: return `Amharic`; // ||am|Amharic|amharique
		case ang: return `English, Old (ca.450-1100)`; // |||English, Old (ca.450-1100)|anglo-saxon (ca.450-1100)
		case anp: return `Angika`; // |||Angika|angika
		case apa: return `Apache languages`; // |||Apache languages|apaches, langues
		case ara: return `Arabic`; // ||ar|Arabic|arabe
		case arc: return `Official Aramaic (700-300 BCE); Imperial Aramaic (700-300 BCE)`; // |||Official Aramaic (700-300 BCE); Imperial Aramaic (700-300 BCE)|araméen d'empire (700-300 BCE)
		case arg: return `Aragonese`; // ||an|Aragonese|aragonais
		case arm: return `Armenian`; // |hye|hy|Armenian|arménien
		case arn: return `Mapudungun; Mapuche`; // |||Mapudungun; Mapuche|mapudungun; mapuche; mapuce
		case arp: return `Arapaho`; // |||Arapaho|arapaho
		case art: return `Artificial languages`; // |||Artificial languages|artificielles, langues
		case arw: return `Arawak`; // |||Arawak|arawak
		case asm_: return `Assamese`; // ||as|Assamese|assamais
		case ast: return `Asturian; Bable; Leonese; Asturleonese`; // |||Asturian; Bable; Leonese; Asturleonese|asturien; bable; léonais; asturoléonais
		case ath: return `Athapascan languages`; // |||Athapascan languages|athapascanes, langues
		case aus: return `Australian languages`; // |||Australian languages|australiennes, langues
		case ava: return `Avaric`; // ||av|Avaric|avar
		case ave: return `Avestan`; // ||ae|Avestan|avestique
		case awa: return `Awadhi`; // |||Awadhi|awadhi
		case aym: return `Aymara`; // ||ay|Aymara|aymara
		case aze: return `Azerbaijani`; // ||az|Azerbaijani|azéri
		case bad: return `Banda languages`; // |||Banda languages|banda, langues
		case bai: return `Bamileke languages`; // |||Bamileke languages|bamiléké, langues
		case bak: return `Bashkir`; // ||ba|Bashkir|bachkir
		case bal: return `Baluchi`; // |||Baluchi|baloutchi
		case bam: return `Bambara`; // ||bm|Bambara|bambara
		case ban: return `Balinese`; // |||Balinese|balinais
		case baq: return `Basque`; // |eus|eu|Basque|basque
		case bas: return `Basa`; // |||Basa|basa
		case bat: return `Baltic languages`; // |||Baltic languages|baltes, langues
		case bej: return `Beja; Bedawiyet`; // |||Beja; Bedawiyet|bedja
		case bel: return `Belarusian`; // ||be|Belarusian|biélorusse
		case bem: return `Bemba`; // |||Bemba|bemba
		case ben: return `Bengali`; // ||bn|Bengali|bengali
		case ber: return `Berber languages`; // |||Berber languages|berbères, langues
		case bho: return `Bhojpuri`; // |||Bhojpuri|bhojpuri
		case bih: return `Bihari languages`; // ||bh|Bihari languages|langues biharis
		case bik: return `Bikol`; // |||Bikol|bikol
		case bin: return `Bini; Edo`; // |||Bini; Edo|bini; edo
		case bis: return `Bislama`; // ||bi|Bislama|bichlamar
		case bla: return `Siksika`; // |||Siksika|blackfoot
		case bnt: return `Bantu languages`; // |||Bantu languages|bantou, langues
		case bos: return `Bosnian`; // ||bs|Bosnian|bosniaque
		case bra: return `Braj`; // |||Braj|braj
		case bre: return `Breton`; // ||br|Breton|breton
		case btk: return `Batak languages`; // |||Batak languages|batak, langues
		case bua: return `Buriat`; // |||Buriat|bouriate
		case bug: return `Buginese`; // |||Buginese|bugi
		case bul: return `Bulgarian`; // ||bg|Bulgarian|bulgare
		case bur: return `Burmese`; // |mya|my|Burmese|birman
		case byn: return `Blin; Bilin`; // |||Blin; Bilin|blin; bilen
		case cad: return `Caddo`; // |||Caddo|caddo
		case cai: return `Central American Indian languages`; // |||Central American Indian languages|amérindiennes de L'Amérique centrale, langues
		case car: return `Galibi Carib`; // |||Galibi Carib|karib; galibi; carib
		case cat: return `Catalan; Valencian`; // ||ca|Catalan; Valencian|catalan; valencien
		case cau: return `Caucasian languages`; // |||Caucasian languages|caucasiennes, langues
		case ceb: return `Cebuano`; // |||Cebuano|cebuano
		case cel: return `Celtic languages`; // |||Celtic languages|celtiques, langues; celtes, langues
		case cha: return `Chamorro`; // ||ch|Chamorro|chamorro
		case chb: return `Chibcha`; // |||Chibcha|chibcha
		case che: return `Chechen`; // ||ce|Chechen|tchétchène
		case chg: return `Chagatai`; // |||Chagatai|djaghataï
		case chi: return `Chinese`; // |zho|zh|Chinese|chinois
		case chk: return `Chuukese`; // |||Chuukese|chuuk
		case chm: return `Mari`; // |||Mari|mari
		case chn: return `Chinook jargon`; // |||Chinook jargon|chinook, jargon
		case cho: return `Choctaw`; // |||Choctaw|choctaw
		case chp: return `Chipewyan; Dene Suline`; // |||Chipewyan; Dene Suline|chipewyan
		case chr: return `Cherokee`; // |||Cherokee|cherokee
		case chu: return `Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic`; // ||cu|Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic|slavon d'église; vieux slave; slavon liturgique; vieux bulgare
		case chv: return `Chuvash`; // ||cv|Chuvash|tchouvache
		case chy: return `Cheyenne`; // |||Cheyenne|cheyenne
		case cmc: return `Chamic languages`; // |||Chamic languages|chames, langues
		case cnr: return `Montenegrin`; // |||Montenegrin|monténégrin
		case cop: return `Coptic`; // |||Coptic|copte
		case cor: return `Cornish`; // ||kw|Cornish|cornique
		case cos: return `Corsican`; // ||co|Corsican|corse
		case cpe: return `Creoles and pidgins, English based`; // |||Creoles and pidgins, English based|créoles et pidgins basés sur l'anglais
		case cpf: return `Creoles and pidgins, French-based`; // |||Creoles and pidgins, French-based|créoles et pidgins basés sur le français
		case cpp: return `Creoles and pidgins, Portuguese-based`; // |||Creoles and pidgins, Portuguese-based|créoles et pidgins basés sur le portugais
		case cre: return `Cree`; // ||cr|Cree|cree
		case crh: return `Crimean Tatar; Crimean Turkish`; // |||Crimean Tatar; Crimean Turkish|tatar de Crimé
		case crp: return `Creoles and pidgins`; // |||Creoles and pidgins|créoles et pidgins
		case csb: return `Kashubian`; // |||Kashubian|kachoube
		case cus: return `Cushitic languages`; // |||Cushitic languages|couchitiques, langues
		case cze: return `Czech`; // |ces|cs|Czech|tchèque
		case dak: return `Dakota`; // |||Dakota|dakota
		case dan: return `Danish`; // ||da|Danish|danois
		case dar: return `Dargwa`; // |||Dargwa|dargwa
		case day: return `Land Dayak languages`; // |||Land Dayak languages|dayak, langues
		case del: return `Delaware`; // |||Delaware|delaware
		case den: return `Slave (Athapascan)`; // |||Slave (Athapascan)|esclave (athapascan)
		case dgr: return `Dogrib`; // |||Dogrib|dogrib
		case din: return `Dinka`; // |||Dinka|dinka
		case div: return `Divehi; Dhivehi; Maldivian`; // ||dv|Divehi; Dhivehi; Maldivian|maldivien
		case doi: return `Dogri`; // |||Dogri|dogri
		case dra: return `Dravidian languages`; // |||Dravidian languages|dravidiennes, langues
		case dsb: return `Lower Sorbian`; // |||Lower Sorbian|bas-sorabe
		case dua: return `Duala`; // |||Duala|douala
		case dum: return `Dutch, Middle (ca.1050-1350)`; // |||Dutch, Middle (ca.1050-1350)|néerlandais moyen (ca. 1050-1350)
		case dut: return `Dutch; Flemish`; // |nld|nl|Dutch; Flemish|néerlandais; flamand
		case dyu: return `Dyula`; // |||Dyula|dioula
		case dzo: return `Dzongkha`; // ||dz|Dzongkha|dzongkha
		case efi: return `Efik`; // |||Efik|efik
		case egy: return `Egyptian (Ancient)`; // |||Egyptian (Ancient)|égyptien
		case eka: return `Ekajuk`; // |||Ekajuk|ekajuk
		case elx: return `Elamite`; // |||Elamite|élamite
		case eng: return `English`; // ||en|English|anglais
		case enm: return `English, Middle (1100-1500)`; // |||English, Middle (1100-1500)|anglais moyen (1100-1500)
		case epo: return `Esperanto`; // ||eo|Esperanto|espéranto
		case est: return `Estonian`; // ||et|Estonian|estonien
		case ewe: return `Ewe`; // ||ee|Ewe|éwé
		case ewo: return `Ewondo`; // |||Ewondo|éwondo
		case fan: return `Fang`; // |||Fang|fang
		case fao: return `Faroese`; // ||fo|Faroese|féroïen
		case fat: return `Fanti`; // |||Fanti|fanti
		case fij: return `Fijian`; // ||fj|Fijian|fidjien
		case fil: return `Filipino; Pilipino`; // |||Filipino; Pilipino|filipino; pilipino
		case fin: return `Finnish`; // ||fi|Finnish|finnois
		case fiu: return `Finno-Ugrian languages`; // |||Finno-Ugrian languages|finno-ougriennes, langues
		case fon: return `Fon`; // |||Fon|fon
		case fre: return `French`; // |fra|fr|French|français
		case frm: return `French, Middle (ca.1400-1600)`; // |||French, Middle (ca.1400-1600)|français moyen (1400-1600)
		case fro: return `French, Old (842-ca.1400)`; // |||French, Old (842-ca.1400)|français ancien (842-ca.1400)
		case frr: return `Northern Frisian`; // |||Northern Frisian|frison septentrional
		case frs: return `Eastern Frisian`; // |||Eastern Frisian|frison oriental
		case fry: return `Western Frisian`; // ||fy|Western Frisian|frison occidental
		case ful: return `Fulah`; // ||ff|Fulah|peul
		case fur: return `Friulian`; // |||Friulian|frioulan
		case gaa: return `Ga`; // |||Ga|ga
		case gay: return `Gayo`; // |||Gayo|gayo
		case gba: return `Gbaya`; // |||Gbaya|gbaya
		case gem: return `Germanic languages`; // |||Germanic languages|germaniques, langues
		case geo: return `Georgian`; // |kat|ka|Georgian|géorgien
		case ger: return `German`; // |deu|de|German|allemand
		case gez: return `Geez`; // |||Geez|guèze
		case gil: return `Gilbertese`; // |||Gilbertese|kiribati
		case gla: return `Gaelic; Scottish Gaelic`; // ||gd|Gaelic; Scottish Gaelic|gaélique; gaélique écossais
		case gle: return `Irish`; // ||ga|Irish|irlandais
		case glg: return `Galician`; // ||gl|Galician|galicien
		case glv: return `Manx`; // ||gv|Manx|manx; mannois
		case gmh: return `German, Middle High (ca.1050-1500)`; // |||German, Middle High (ca.1050-1500)|allemand, moyen haut (ca. 1050-1500)
		case goh: return `German, Old High (ca.750-1050)`; // |||German, Old High (ca.750-1050)|allemand, vieux haut (ca. 750-1050)
		case gon: return `Gondi`; // |||Gondi|gond
		case gor: return `Gorontalo`; // |||Gorontalo|gorontalo
		case got: return `Gothic`; // |||Gothic|gothique
		case grb: return `Grebo`; // |||Grebo|grebo
		case grc: return `Greek, Ancient (to 1453)`; // |||Greek, Ancient (to 1453)|grec ancien (jusqu'à 1453)
		case gre: return `Greek, Modern (1453-)`; // |ell|el|Greek, Modern (1453-)|grec moderne (après 1453)
		case grn: return `Guarani`; // ||gn|Guarani|guarani
		case gsw: return `Swiss German; Alemannic; Alsatian`; // |||Swiss German; Alemannic; Alsatian|suisse alémanique; alémanique; alsacien
		case guj: return `Gujarati`; // ||gu|Gujarati|goudjrati
		case gwi: return `Gwich'in`; // |||Gwich'in|gwich'in
		case hai: return `Haida`; // |||Haida|haida
		case hat: return `Haitian; Haitian Creole`; // ||ht|Haitian; Haitian Creole|haïtien; créole haïtien
		case hau: return `Hausa`; // ||ha|Hausa|haoussa
		case haw: return `Hawaiian`; // |||Hawaiian|hawaïen
		case heb: return `Hebrew`; // ||he|Hebrew|hébreu
		case her: return `Herero`; // ||hz|Herero|herero
		case hil: return `Hiligaynon`; // |||Hiligaynon|hiligaynon
		case him: return `Himachali languages; Western Pahari languages`; // |||Himachali languages; Western Pahari languages|langues himachalis; langues paharis occidentales
		case hin: return `Hindi`; // ||hi|Hindi|hindi
		case hit: return `Hittite`; // |||Hittite|hittite
		case hmn: return `Hmong; Mong`; // |||Hmong; Mong|hmong
		case hmo: return `Hiri Motu`; // ||ho|Hiri Motu|hiri motu
		case hrv: return `Croatian`; // ||hr|Croatian|croate
		case hsb: return `Upper Sorbian`; // |||Upper Sorbian|haut-sorabe
		case hun: return `Hungarian`; // ||hu|Hungarian|hongrois
		case hup: return `Hupa`; // |||Hupa|hupa
		case iba: return `Iban`; // |||Iban|iban
		case ibo: return `Igbo`; // ||ig|Igbo|igbo
		case ice: return `Icelandic`; // |isl|is|Icelandic|islandais
		case ido: return `Ido`; // ||io|Ido|ido
		case iii: return `Sichuan Yi; Nuosu`; // ||ii|Sichuan Yi; Nuosu|yi de Sichuan
		case ijo: return `Ijo languages`; // |||Ijo languages|ijo, langues
		case iku: return `Inuktitut`; // ||iu|Inuktitut|inuktitut
		case ile: return `Interlingue; Occidental`; // ||ie|Interlingue; Occidental|interlingue
		case ilo: return `Iloko`; // |||Iloko|ilocano
		case ina: return `Interlingua (International Auxiliary Language Association)`; // ||ia|Interlingua (International Auxiliary Language Association)|interlingua (langue auxiliaire internationale)
		case inc: return `Indic languages`; // |||Indic languages|indo-aryennes, langues
		case ind: return `Indonesian`; // ||id|Indonesian|indonésien
		case ine: return `Indo-European languages`; // |||Indo-European languages|indo-européennes, langues
		case inh: return `Ingush`; // |||Ingush|ingouche
		case ipk: return `Inupiaq`; // ||ik|Inupiaq|inupiaq
		case ira: return `Iranian languages`; // |||Iranian languages|iraniennes, langues
		case iro: return `Iroquoian languages`; // |||Iroquoian languages|iroquoises, langues
		case ita: return `Italian`; // ||it|Italian|italien
		case jav: return `Javanese`; // ||jv|Javanese|javanais
		case jbo: return `Lojban`; // |||Lojban|lojban
		case jpn: return `Japanese`; // ||ja|Japanese|japonais
		case jpr: return `Judeo-Persian`; // |||Judeo-Persian|judéo-persan
		case jrb: return `Judeo-Arabic`; // |||Judeo-Arabic|judéo-arabe
		case kaa: return `Kara-Kalpak`; // |||Kara-Kalpak|karakalpak
		case kab: return `Kabyle`; // |||Kabyle|kabyle
		case kac: return `Kachin; Jingpho`; // |||Kachin; Jingpho|kachin; jingpho
		case kal: return `Kalaallisut; Greenlandic`; // ||kl|Kalaallisut; Greenlandic|groenlandais
		case kam: return `Kamba`; // |||Kamba|kamba
		case kan: return `Kannada`; // ||kn|Kannada|kannada
		case kar: return `Karen languages`; // |||Karen languages|karen, langues
		case kas: return `Kashmiri`; // ||ks|Kashmiri|kashmiri
		case kau: return `Kanuri`; // ||kr|Kanuri|kanouri
		case kaw: return `Kawi`; // |||Kawi|kawi
		case kaz: return `Kazakh`; // ||kk|Kazakh|kazakh
		case kbd: return `Kabardian`; // |||Kabardian|kabardien
		case kha: return `Khasi`; // |||Khasi|khasi
		case khi: return `Khoisan languages`; // |||Khoisan languages|khoïsan, langues
		case khm: return `Central Khmer`; // ||km|Central Khmer|khmer central
		case kho: return `Khotanese; Sakan`; // |||Khotanese; Sakan|khotanais; sakan
		case kik: return `Kikuyu; Gikuyu`; // ||ki|Kikuyu; Gikuyu|kikuyu
		case kin: return `Kinyarwanda`; // ||rw|Kinyarwanda|rwanda
		case kir: return `Kirghiz; Kyrgyz`; // ||ky|Kirghiz; Kyrgyz|kirghiz
		case kmb: return `Kimbundu`; // |||Kimbundu|kimbundu
		case kok: return `Konkani`; // |||Konkani|konkani
		case kom: return `Komi`; // ||kv|Komi|kom
		case kon: return `Kongo`; // ||kg|Kongo|kongo
		case kor: return `Korean`; // ||ko|Korean|coréen
		case kos: return `Kosraean`; // |||Kosraean|kosrae
		case kpe: return `Kpelle`; // |||Kpelle|kpellé
		case krc: return `Karachay-Balkar`; // |||Karachay-Balkar|karatchai balkar
		case krl: return `Karelian`; // |||Karelian|carélien
		case kro: return `Kru languages`; // |||Kru languages|krou, langues
		case kru: return `Kurukh`; // |||Kurukh|kurukh
		case kua: return `Kuanyama; Kwanyama`; // ||kj|Kuanyama; Kwanyama|kuanyama; kwanyama
		case kum: return `Kumyk`; // |||Kumyk|koumyk
		case kur: return `Kurdish`; // ||ku|Kurdish|kurde
		case kut: return `Kutenai`; // |||Kutenai|kutenai
		case lad: return `Ladino`; // |||Ladino|judéo-espagnol
		case lah: return `Lahnda`; // |||Lahnda|lahnda
		case lam: return `Lamba`; // |||Lamba|lamba
		case lao: return `Lao`; // ||lo|Lao|lao
		case lat: return `Latin`; // ||la|Latin|latin
		case lav: return `Latvian`; // ||lv|Latvian|letton
		case lez: return `Lezghian`; // |||Lezghian|lezghien
		case lim: return `Limburgan; Limburger; Limburgish`; // ||li|Limburgan; Limburger; Limburgish|limbourgeois
		case lin: return `Lingala`; // ||ln|Lingala|lingala
		case lit: return `Lithuanian`; // ||lt|Lithuanian|lituanien
		case lol: return `Mongo`; // |||Mongo|mongo
		case loz: return `Lozi`; // |||Lozi|lozi
		case ltz: return `Luxembourgish; Letzeburgesch`; // ||lb|Luxembourgish; Letzeburgesch|luxembourgeois
		case lua: return `Luba-Lulua`; // |||Luba-Lulua|luba-lulua
		case lub: return `Luba-Katanga`; // ||lu|Luba-Katanga|luba-katanga
		case lug: return `Ganda`; // ||lg|Ganda|ganda
		case lui: return `Luiseno`; // |||Luiseno|luiseno
		case lun: return `Lunda`; // |||Lunda|lunda
		case luo: return `Luo (Kenya and Tanzania)`; // |||Luo (Kenya and Tanzania)|luo (Kenya et Tanzanie)
		case lus: return `Lushai`; // |||Lushai|lushai
		case mac: return `Macedonian`; // |mkd|mk|Macedonian|macédonien
		case mad: return `Madurese`; // |||Madurese|madourais
		case mag: return `Magahi`; // |||Magahi|magahi
		case mah: return `Marshallese`; // ||mh|Marshallese|marshall
		case mai: return `Maithili`; // |||Maithili|maithili
		case mak: return `Makasar`; // |||Makasar|makassar
		case mal: return `Malayalam`; // ||ml|Malayalam|malayalam
		case man: return `Mandingo`; // |||Mandingo|mandingue
		case mao: return `Maori`; // |mri|mi|Maori|maori
		case map: return `Austronesian languages`; // |||Austronesian languages|austronésiennes, langues
		case mar: return `Marathi`; // ||mr|Marathi|marathe
		case mas: return `Masai`; // |||Masai|massaï
		case may: return `Malay`; // |msa|ms|Malay|malais
		case mdf: return `Moksha`; // |||Moksha|moksa
		case mdr: return `Mandar`; // |||Mandar|mandar
		case men: return `Mende`; // |||Mende|mendé
		case mga: return `Irish, Middle (900-1200)`; // |||Irish, Middle (900-1200)|irlandais moyen (900-1200)
		case mic: return `Mi'kmaq; Micmac`; // |||Mi'kmaq; Micmac|mi'kmaq; micmac
		case min: return `Minangkabau`; // |||Minangkabau|minangkabau
		case mis: return `Uncoded languages`; // |||Uncoded languages|langues non codées
		case mkh: return `Mon-Khmer languages`; // |||Mon-Khmer languages|môn-khmer, langues
		case mlg: return `Malagasy`; // ||mg|Malagasy|malgache
		case mlt: return `Maltese`; // ||mt|Maltese|maltais
		case mnc: return `Manchu`; // |||Manchu|mandchou
		case mni: return `Manipuri`; // |||Manipuri|manipuri
		case mno: return `Manobo languages`; // |||Manobo languages|manobo, langues
		case moh: return `Mohawk`; // |||Mohawk|mohawk
		case mon: return `Mongolian`; // ||mn|Mongolian|mongol
		case mos: return `Mossi`; // |||Mossi|moré
		case mul: return `Multiple languages`; // |||Multiple languages|multilingue
		case mun: return `Munda languages`; // |||Munda languages|mounda, langues
		case mus: return `Creek`; // |||Creek|muskogee
		case mwl: return `Mirandese`; // |||Mirandese|mirandais
		case mwr: return `Marwari`; // |||Marwari|marvari
		case myn: return `Mayan languages`; // |||Mayan languages|maya, langues
		case myv: return `Erzya`; // |||Erzya|erza
		case nah: return `Nahuatl languages`; // |||Nahuatl languages|nahuatl, langues
		case nai: return `North American Indian languages`; // |||North American Indian languages|nord-amérindiennes, langues
		case nap: return `Neapolitan`; // |||Neapolitan|napolitain
		case nau: return `Nauru`; // ||na|Nauru|nauruan
		case nav: return `Navajo; Navaho`; // ||nv|Navajo; Navaho|navaho
		case nbl: return `Ndebele, South; South Ndebele`; // ||nr|Ndebele, South; South Ndebele|ndébélé du Sud
		case nde: return `Ndebele, North; North Ndebele`; // ||nd|Ndebele, North; North Ndebele|ndébélé du Nord
		case ndo: return `Ndonga`; // ||ng|Ndonga|ndonga
		case nds: return `Low German; Low Saxon; German, Low; Saxon, Low`; // |||Low German; Low Saxon; German, Low; Saxon, Low|bas allemand; bas saxon; allemand, bas; saxon, bas
		case nep: return `Nepali`; // ||ne|Nepali|népalais
		case new_: return `Nepal Bhasa; Newari`; // |||Nepal Bhasa; Newari|nepal bhasa; newari
		case nia: return `Nias`; // |||Nias|nias
		case nic: return `Niger-Kordofanian languages`; // |||Niger-Kordofanian languages|nigéro-kordofaniennes, langues
		case niu: return `Niuean`; // |||Niuean|niué
		case nno: return `Norwegian Nynorsk; Nynorsk, Norwegian`; // ||nn|Norwegian Nynorsk; Nynorsk, Norwegian|norvégien nynorsk; nynorsk, norvégien
		case nob: return `Bokmål, Norwegian; Norwegian Bokmål`; // ||nb|Bokmål, Norwegian; Norwegian Bokmål|norvégien bokmål
		case nog: return `Nogai`; // |||Nogai|nogaï; nogay
		case non: return `Norse, Old`; // |||Norse, Old|norrois, vieux
		case nor: return `Norwegian`; // ||no|Norwegian|norvégien
		case nqo: return `N'Ko`; // |||N'Ko|n'ko
		case nso: return `Pedi; Sepedi; Northern Sotho`; // |||Pedi; Sepedi; Northern Sotho|pedi; sepedi; sotho du Nord
		case nub: return `Nubian languages`; // |||Nubian languages|nubiennes, langues
		case nwc: return `Classical Newari; Old Newari; Classical Nepal Bhasa`; // |||Classical Newari; Old Newari; Classical Nepal Bhasa|newari classique
		case nya: return `Chichewa; Chewa; Nyanja`; // ||ny|Chichewa; Chewa; Nyanja|chichewa; chewa; nyanja
		case nym: return `Nyamwezi`; // |||Nyamwezi|nyamwezi
		case nyn: return `Nyankole`; // |||Nyankole|nyankolé
		case nyo: return `Nyoro`; // |||Nyoro|nyoro
		case nzi: return `Nzima`; // |||Nzima|nzema
		case oci: return `Occitan (post 1500)`; // ||oc|Occitan (post 1500)|occitan (après 1500)
		case oji: return `Ojibwa`; // ||oj|Ojibwa|ojibwa
		case ori: return `Oriya`; // ||or|Oriya|oriya
		case orm: return `Oromo`; // ||om|Oromo|galla
		case osa: return `Osage`; // |||Osage|osage
		case oss: return `Ossetian; Ossetic`; // ||os|Ossetian; Ossetic|ossète
		case ota: return `Turkish, Ottoman (1500-1928)`; // |||Turkish, Ottoman (1500-1928)|turc ottoman (1500-1928)
		case oto: return `Otomian languages`; // |||Otomian languages|otomi, langues
		case paa: return `Papuan languages`; // |||Papuan languages|papoues, langues
		case pag: return `Pangasinan`; // |||Pangasinan|pangasinan
		case pal: return `Pahlavi`; // |||Pahlavi|pahlavi
		case pam: return `Pampanga; Kapampangan`; // |||Pampanga; Kapampangan|pampangan
		case pan: return `Panjabi; Punjabi`; // ||pa|Panjabi; Punjabi|pendjabi
		case pap: return `Papiamento`; // |||Papiamento|papiamento
		case pau: return `Palauan`; // |||Palauan|palau
		case peo: return `Persian, Old (ca.600-400 B.C.)`; // |||Persian, Old (ca.600-400 B.C.)|perse, vieux (ca. 600-400 av. J.-C.)
		case per: return `Persian`; // |fas|fa|Persian|persan
		case phi: return `Philippine languages`; // |||Philippine languages|philippines, langues
		case phn: return `Phoenician`; // |||Phoenician|phénicien
		case pli: return `Pali`; // ||pi|Pali|pali
		case pol: return `Polish`; // ||pl|Polish|polonais
		case pon: return `Pohnpeian`; // |||Pohnpeian|pohnpei
		case por: return `Portuguese`; // ||pt|Portuguese|portugais
		case pra: return `Prakrit languages`; // |||Prakrit languages|prâkrit, langues
		case pro: return `Provençal, Old (to 1500); Occitan, Old (to 1500)`; // |||Provençal, Old (to 1500); Occitan, Old (to 1500)|provençal ancien (jusqu'à 1500); occitan ancien (jusqu'à 1500)
		case pus: return `Pushto; Pashto`; // ||ps|Pushto; Pashto|pachto
		// case qaa_qtz: return `Reserved for local use`; // |||Reserved for local use|réservée à l'usage local
		case que: return `Quechua`; // ||qu|Quechua|quechua
		case raj: return `Rajasthani`; // |||Rajasthani|rajasthani
		case rap: return `Rapanui`; // |||Rapanui|rapanui
		case rar: return `Rarotongan; Cook Islands Maori`; // |||Rarotongan; Cook Islands Maori|rarotonga; maori des îles Cook
		case roa: return `Romance languages`; // |||Romance languages|romanes, langues
		case roh: return `Romansh`; // ||rm|Romansh|romanche
		case rom: return `Romany`; // |||Romany|tsigane
		case rum: return `Romanian; Moldavian; Moldovan`; // |ron|ro|Romanian; Moldavian; Moldovan|roumain; moldave
		case run: return `Rundi`; // ||rn|Rundi|rundi
		case rup: return `Aromanian; Arumanian; Macedo-Romanian`; // |||Aromanian; Arumanian; Macedo-Romanian|aroumain; macédo-roumain
		case rus: return `Russian`; // ||ru|Russian|russe
		case sad: return `Sandawe`; // |||Sandawe|sandawe
		case sag: return `Sango`; // ||sg|Sango|sango
		case sah: return `Yakut`; // |||Yakut|iakoute
		case sai: return `South American Indian languages`; // |||South American Indian languages|sud-amérindiennes, langues
		case sal: return `Salishan languages`; // |||Salishan languages|salishennes, langues
		case sam: return `Samaritan Aramaic`; // |||Samaritan Aramaic|samaritain
		case san: return `Sanskrit`; // ||sa|Sanskrit|sanskrit
		case sas: return `Sasak`; // |||Sasak|sasak
		case sat: return `Santali`; // |||Santali|santal
		case scn: return `Sicilian`; // |||Sicilian|sicilien
		case sco: return `Scots`; // |||Scots|écossais
		case sel: return `Selkup`; // |||Selkup|selkoupe
		case sem: return `Semitic languages`; // |||Semitic languages|sémitiques, langues
		case sga: return `Irish, Old (to 900)`; // |||Irish, Old (to 900)|irlandais ancien (jusqu'à 900)
		case sgn: return `Sign Languages`; // |||Sign Languages|langues des signes
		case shn: return `Shan`; // |||Shan|chan
		case sid: return `Sidamo`; // |||Sidamo|sidamo
		case sin: return `Sinhala; Sinhalese`; // ||si|Sinhala; Sinhalese|singhalais
		case sio: return `Siouan languages`; // |||Siouan languages|sioux, langues
		case sit: return `Sino-Tibetan languages`; // |||Sino-Tibetan languages|sino-tibétaines, langues
		case sla: return `Slavic languages`; // |||Slavic languages|slaves, langues
		case slo: return `Slovak`; // |slk|sk|Slovak|slovaque
		case slv: return `Slovenian`; // ||sl|Slovenian|slovène
		case sma: return `Southern Sami`; // |||Southern Sami|sami du Sud
		case sme: return `Northern Sami`; // ||se|Northern Sami|sami du Nord
		case smi: return `Sami languages`; // |||Sami languages|sames, langues
		case smj: return `Lule Sami`; // |||Lule Sami|sami de Lule
		case smn: return `Inari Sami`; // |||Inari Sami|sami d'Inari
		case smo: return `Samoan`; // ||sm|Samoan|samoan
		case sms: return `Skolt Sami`; // |||Skolt Sami|sami skolt
		case sna: return `Shona`; // ||sn|Shona|shona
		case snd: return `Sindhi`; // ||sd|Sindhi|sindhi
		case snk: return `Soninke`; // |||Soninke|soninké
		case sog: return `Sogdian`; // |||Sogdian|sogdien
		case som: return `Somali`; // ||so|Somali|somali
		case son: return `Songhai languages`; // |||Songhai languages|songhai, langues
		case sot: return `Sotho, Southern`; // ||st|Sotho, Southern|sotho du Sud
		case spa: return `Spanish; Castilian`; // ||es|Spanish; Castilian|espagnol; castillan
		case srd: return `Sardinian`; // ||sc|Sardinian|sarde
		case srn: return `Sranan Tongo`; // |||Sranan Tongo|sranan tongo
		case srp: return `Serbian`; // ||sr|Serbian|serbe
		case srr: return `Serer`; // |||Serer|sérère
		case ssa: return `Nilo-Saharan languages`; // |||Nilo-Saharan languages|nilo-sahariennes, langues
		case ssw: return `Swati`; // ||ss|Swati|swati
		case suk: return `Sukuma`; // |||Sukuma|sukuma
		case sun: return `Sundanese`; // ||su|Sundanese|soundanais
		case sus: return `Susu`; // |||Susu|soussou
		case sux: return `Sumerian`; // |||Sumerian|sumérien
		case swa: return `Swahili`; // ||sw|Swahili|swahili
		case swe: return `Swedish`; // ||sv|Swedish|suédois
		case syc: return `Classical Syriac`; // |||Classical Syriac|syriaque classique
		case syr: return `Syriac`; // |||Syriac|syriaque
		case tah: return `Tahitian`; // ||ty|Tahitian|tahitien
		case tai: return `Tai languages`; // |||Tai languages|tai, langues
		case tam: return `Tamil`; // ||ta|Tamil|tamoul
		case tat: return `Tatar`; // ||tt|Tatar|tatar
		case tel: return `Telugu`; // ||te|Telugu|télougou
		case tem: return `Timne`; // |||Timne|temne
		case ter: return `Tereno`; // |||Tereno|tereno
		case tet: return `Tetum`; // |||Tetum|tetum
		case tgk: return `Tajik`; // ||tg|Tajik|tadjik
		case tgl: return `Tagalog`; // ||tl|Tagalog|tagalog
		case tha: return `Thai`; // ||th|Thai|thaï
		case tib: return `Tibetan`; // |bod|bo|Tibetan|tibétain
		case tig: return `Tigre`; // |||Tigre|tigré
		case tir: return `Tigrinya`; // ||ti|Tigrinya|tigrigna
		case tiv: return `Tiv`; // |||Tiv|tiv
		case tkl: return `Tokelau`; // |||Tokelau|tokelau
		case tlh: return `Klingon; tlhIngan-Hol`; // |||Klingon; tlhIngan-Hol|klingon
		case tli: return `Tlingit`; // |||Tlingit|tlingit
		case tmh: return `Tamashek`; // |||Tamashek|tamacheq
		case tog: return `Tonga (Nyasa)`; // |||Tonga (Nyasa)|tonga (Nyasa)
		case ton: return `Tonga (Tonga Islands)`; // ||to|Tonga (Tonga Islands)|tongan (Îles Tonga)
		case tpi: return `Tok Pisin`; // |||Tok Pisin|tok pisin
		case tsi: return `Tsimshian`; // |||Tsimshian|tsimshian
		case tsn: return `Tswana`; // ||tn|Tswana|tswana
		case tso: return `Tsonga`; // ||ts|Tsonga|tsonga
		case tuk: return `Turkmen`; // ||tk|Turkmen|turkmène
		case tum: return `Tumbuka`; // |||Tumbuka|tumbuka
		case tup: return `Tupi languages`; // |||Tupi languages|tupi, langues
		case tur: return `Turkish`; // ||tr|Turkish|turc
		case tut: return `Altaic languages`; // |||Altaic languages|altaïques, langues
		case tvl: return `Tuvalu`; // |||Tuvalu|tuvalu
		case twi: return `Twi`; // ||tw|Twi|twi
		case tyv: return `Tuvinian`; // |||Tuvinian|touva
		case udm: return `Udmurt`; // |||Udmurt|oudmourte
		case uga: return `Ugaritic`; // |||Ugaritic|ougaritique
		case uig: return `Uighur; Uyghur`; // ||ug|Uighur; Uyghur|ouïgour
		case ukr: return `Ukrainian`; // ||uk|Ukrainian|ukrainien
		case umb: return `Umbundu`; // |||Umbundu|umbundu
		case und: return `Undetermined`; // |||Undetermined|indéterminée
		case urd: return `Urdu`; // ||ur|Urdu|ourdou
		case uzb: return `Uzbek`; // ||uz|Uzbek|ouszbek
		case vai: return `Vai`; // |||Vai|vaï
		case ven: return `Venda`; // ||ve|Venda|venda
		case vie: return `Vietnamese`; // ||vi|Vietnamese|vietnamien
		case vol: return `Volapük`; // ||vo|Volapük|volapük
		case vot: return `Votic`; // |||Votic|vote
		case wak: return `Wakashan languages`; // |||Wakashan languages|wakashanes, langues
		case wal: return `Wolaitta; Wolaytta`; // |||Wolaitta; Wolaytta|wolaitta; wolaytta
		case war: return `Waray`; // |||Waray|waray
		case was: return `Washo`; // |||Washo|washo
		case wel: return `Welsh`; // |cym|cy|Welsh|gallois
		case wen: return `Sorbian languages`; // |||Sorbian languages|sorabes, langues
		case wln: return `Walloon`; // ||wa|Walloon|wallon
		case wol: return `Wolof`; // ||wo|Wolof|wolof
		case xal: return `Kalmyk; Oirat`; // |||Kalmyk; Oirat|kalmouk; oïrat
		case xho: return `Xhosa`; // ||xh|Xhosa|xhosa
		case yao: return `Yao`; // |||Yao|yao
		case yap: return `Yapese`; // |||Yapese|yapois
		case yid: return `Yiddish`; // ||yi|Yiddish|yiddish
		case yor: return `Yoruba`; // ||yo|Yoruba|yoruba
		case ypk: return `Yupik languages`; // |||Yupik languages|yupik, langues
		case zap: return `Zapotec`; // |||Zapotec|zapotèque
		case zbl: return `Blissymbols; Blissymbolics; Bliss`; // |||Blissymbols; Blissymbolics; Bliss|symboles Bliss; Bliss
		case zen: return `Zenaga`; // |||Zenaga|zenaga
		case zgh: return `Standard Moroccan Tamazight`; // |||Standard Moroccan Tamazight|amazighe standard marocain
		case zha: return `Zhuang; Chuang`; // ||za|Zhuang; Chuang|zhuang; chuang
		case znd: return `Zande languages`; // |||Zande languages|zandé, langues
		case zul: return `Zulu`; // ||zu|Zulu|zoulou
		case zun: return `Zuni`; // |||Zuni|zuni
		case zxx: return `No linguistic content; Not applicable`; // |||No linguistic content; Not applicable|pas de contenu linguistique; non applicable
		case zza: return `Zaza; Dimili; Dimli; Kirdki; Kirmanjki; Zazaki`; // |||Zaza; Dimili; Dimli; Kirdki; Kirmanjki; Zazaki|zaza; dimili; dimli; kirdki; kirmanjki; zazaki
		}
	}
}
