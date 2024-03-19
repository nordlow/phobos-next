/++ Translations.
	Test: dmd -version=integration_test -version=show -vcolumns -preview=in -preview=dip1000 -g -checkaction=context -allinst -unittest -i -I.. -main -run translation.d
 +/
module nxt.translation;

// version = integration_test;

import nxt.iso_639_1 : Language;

@safe:

/++ Translate `text` from `sourceLanguage` to `targetLanguage` via Google Translate.
 +/
string translateByGoogle(in char[] text, in Language sourceLanguage, in Language targetLanguage) @trusted {
	import std.conv : to;
	return translateByGoogle(text, sourceLanguage.to!string, targetLanguage.to!string);
;
}

/++ Translate `text` from `sourceLangCodeCode` to `targetLangCodeCode` via Google Translate.
 +/
string translateByGoogle(in char[] text, in char[] sourceLangCode, in char[] targetLangCode) @trusted {
	import std.conv : to;
	import std.uri : encode;

	import std.net.curl : HTTP;
	const msg = "http://translate.googleapis.com/translate_a/single?client=gtx&sl="~sourceLangCode ~"&tl="~targetLangCode ~ "&dt=t&q="~encode(text);
	auto http = HTTP(msg);
	http.onReceiveStatusLine = (HTTP.StatusLine status) {
		if (status.code != 200)
			throw new Exception("Error " ~ status.code.to!string ~ " (" ~ status.reason.to!string ~ ")");
	};

	string responseJson;
	http.onReceive = (ubyte[] data) {
		responseJson = cast(string) data;
		return data.length;
	};

	http.perform();

	typeof(return) result;
	import std.json : parseJSON, JSONType;
	foreach (const entry; responseJson.parseJSON().array) {
		import std.exception : enforce;
		if (entry.type is JSONType.array) {
			import std.algorithm : each;
			foreach (const second; entry.array) {
				if (second.type is JSONType.array && second[0].type is JSONType.string) {
					result ~= second[0].str;
				}
			}
		}
	}

	return result;
}

version(integration_test)
@safe unittest {
	const text = "Text intended for translation into LANGUAGE";
	assert(text.tr(Language.en, Language.de) == "Text, der in die SPRACHE übersetzt werden soll");
	assert(text.tr(Language.en, Language.tr) == "LANGUAGE diline çevrilmesi amaçlanan metin");
	assert(text.tr(Language.en, Language.sv) == "Text avsedd för översättning till SPRÅK");
	assert(text.tr("engb", "sv") == "Text avsedd för översättning till SPRÅK");
	assert(text.tr("en-GB", "sv") == "Text avsedd för översättning till SPRÅK");
	assert(text.tr("en", "zh-CN") == "打算翻译成语言的文本");
	assert(text.tr("en", "zh-TW") == "打算翻譯成語言的文本");
}

version(unittest)
	private static alias tr = translateByGoogle;
