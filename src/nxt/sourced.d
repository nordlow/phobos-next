module nxt.sourced;

import nxt.path : Path, exists;

/++ JSON value with origin path.

	TODO: generalize (templated) to any value.
	TODO: generalize (templated) to any URL.
 +/
struct SourcedJSON {
	import std.json : JSONValue, parseJSON;
	Path path;					///< Path of `value` serialized to string.
	JSONValue value;			///< JSON value.
	bool outdated;				///< Is true if value needs has been changed since read from path.

	/++ Uses parameter `Path` in ctor instead of `fromFile`.
		See: https://docs.rs/from_file/latest/from_file/
	+/
	this(Path path, bool silentPassUponFailure = false) @safe {
		import std.file : readText;
		this.path = path;
		this.value = silentPassUponFailure ?
			(path.exists ?
				readText(path.str).parseJSON :
				JSONValue.emptyObject) :
			readText(path.str).parseJSON;
	}

	~this() const {
		if (outdated)
			writeBack();
	}

	void writeBack(in bool pretty = true) const {
		import std.stdio : File;
		import std.json : JSONOptions;
		if (pretty) {
			static if (__traits(hasMember, JSONValue, "toPrettyString")) {
				static if (is(typeof(value.toPrettyString(File(path, "w").lockingBinaryWriter, JSONOptions.doNotEscapeSlashes)))) {
					value.toPrettyString(File(path, "w").lockingBinaryWriter, JSONOptions.doNotEscapeSlashes);
				} else {
					File(path.str, "w").write(value.toPrettyString(JSONOptions.doNotEscapeSlashes));
				}
			} else {
				static assert(0);
			}
		} else {
			static if (__traits(hasMember, JSONValue, "toString")) {
				File(path.str, "w").write(value.toString(JSONOptions.doNotEscapeSlashes));
			} else {
				File(path.str, "w").write(value.to!string());
			}
		}
	}
}

///
@safe unittest {
	/+ TODO: const x = SourcedJSON(Path("")); +/
}
