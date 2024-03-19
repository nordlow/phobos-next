/** Extensions to std.json.
 *
 * Test: dmd -preview=dip1000 -preview=in -vcolumns -I.. -i -debug -unittest -version=integration_test -main -run json.d
 */
module nxt.json;

// version = integration_test;

import std.digest.sha : SHA1;
import std.json : JSONValue, JSONOptions, parseJSON;
import nxt.path : FilePath, DirPath, FileName;

private alias Hash = SHA1;

@safe:

/++ Read JSON from file at `path` via `options`, optionally cached in
	`cacheDir`. If `cacheDir` is set try to read a cached result inside
	`cacheDir`, using binary (de)serialization functions defined in
    `nxt.serialization`.
 +/
JSONValue readJSON(const FilePath path, in JSONOptions options = JSONOptions.none, in DirPath cacheDir = [], in bool stripComments = false) {
	import nxt.debugio : dbg;
	import std.file : readText, read, write;
	import nxt.path : buildPath;
	import nxt.serialization : serializeRaw, deserializeRaw, Status, Format, CodeUnitType;
	import std.array : Appender;

	alias Sink = Appender!(CodeUnitType[]);

	const fmt = Format(false, true);
	const text = path.str.readText();

	FilePath cachePath;
	Sink sink;

	if (cacheDir) {
		/+ TODO: functionize somehow: +/
		Hash hash;
		() @trusted { hash.put(cast(ubyte[])text); }();
		const digest = hash.finish;
		import std.base64 : Base64URLNoPadding;
		const base64 = Base64URLNoPadding.encode(digest);
		cachePath = cacheDir.buildPath(FileName((base64 ~ ".json-raw").idup));
		try {
			// dbg("Loading cache from ", cachePath, " ...");
			JSONValue json;
			() @trusted {
				sink = Sink(cast(ubyte[])cachePath.str.read());
				assert(sink.deserializeRaw(json, fmt) == Status(Status.Code.successful));
			}();
			assert(sink.data.length == 0);
			return json;
		} catch (Exception e) {
			// cache reuse failed
		}
	}

	auto json = stripComments ? text.parseJSONWithHashComments(options) : text.parseJSON(options);

	if (cacheDir) {
		/+ TODO: use `immutable CodeUnitType` in cases where it avoids allocation of array elements in `deserializeRaw` +/
		sink.clear();
		sink.reserve(text.length); /+ TODO: predict from `text.length` and `fmt` +/
		const size_t initialAddrsCapacity = 0; /+ TODO: predict from `text.length` and `fmt` +/
		() @trusted {
			sink.serializeRaw(json, fmt, initialAddrsCapacity);
			// dbg("Saving cache to ", cachePath, " ...");
			// dbg(text.length, " => ", sink.data.length);
			cachePath.str.write(sink.data);
			debug {
				JSONValue jsonCopy;
				sink.deserializeRaw(jsonCopy, fmt);
				if (json != jsonCopy) {
					dbg("JSON:\n", json.toPrettyString);
					dbg("!=\n");
					dbg("JSON copy:\n", jsonCopy.toPrettyString);
				}
				assert(json == jsonCopy);
			}
		}();
	}
	return json;
}

version (integration_test)
@safe unittest {
	import std.json : JSONException;
	import std.file : dirEntries, SpanMode;
	import nxt.file : homeDir, tempDir;
	import nxt.path : buildPath, FileName, baseName;
	import nxt.stdio : writeln;
	DirPath cacheDir = tempDir;
	foreach (dent; dirEntries(homeDir.buildPath(DirPath(".dub/packages.all")).str, SpanMode.breadth)) {
		const path = FilePath(dent.name);
		if (dent.isDir || path.baseName.str != "dub.json")
			continue;
		try {
			path.readJSON(JSONOptions.none, cacheDir);
		} catch (JSONException _) {}
	}
}

/++ Parse JSON without its comments.
 +/
JSONValue parseJSONWithHashComments(const(char)[] json, in JSONOptions options = JSONOptions.none) {
	import nxt.algorithm.searching : canFind;
	if (!json.canFind('#'))
		return json.parseJSON(options); // fast path
	return json.stripJSONComments.parseJSON(options);
}

/++ Strip JSON comments from `s`.
	Returns: JSON text `s` without its comments, where each comment matches (rx bol (: space '#')).
 +/
private auto stripJSONComments(in char[] s) pure {
	import std.algorithm.iteration : filter, joiner;
	import std.string : lineSplitter, stripLeft;
	import nxt.algorithm.searching : canFind;
	return s.lineSplitter.filter!(line => !line.stripLeft(" \t").canFind('#')).joiner;
}
