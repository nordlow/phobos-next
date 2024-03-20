module nxt.enum_ex;

@safe:

/** Enumeration wrapper that uses optimized conversion to string (via `toString`
 * member).
 *
 * See_Also: https://forum.dlang.org/thread/ppndhxvzayedgpbjculm@forum.dlang.org?page=1
 *
 * TODO: Move logic to `std.conv.to`.
 */
struct Enum(E)
if (is(E == enum)) {
	@property string toString() pure nothrow @safe @nogc => toStringFromEnumWithConsecutiveAliases(_enum);
	E _enum;					// the wrapped enum
	alias _enum this;
}

///
pure @safe unittest {
	enum X { a,
			 b,
	}
	alias EnumX = Enum!X;
	assert(EnumX(X.a).toString == "a");
	assert(EnumX(X.b).toString == "b");
}

/** Fast and more generic implementation of `std.conv.to` for enumerations.
	TODO: Handle non-adjacent enumerator aliases.
 */
string toStringFromEnumWithConsecutiveAliases(T)(const scope T value) pure nothrow @safe @nogc
if (is(T == enum)) {
	alias members = __traits(allMembers, T);
	final switch (value) {
		static foreach (index, member; members) {
			static if (index == 0 ||
					   (__traits(getMember, T, members[index - 1]) !=
						__traits(getMember, T, member))) {
				case __traits(getMember, T, member):
					return member;
			}
		}
	}
}

///
pure nothrow @safe @nogc unittest {
	enum E { unknown, x, y, z, z_ = z, }
	assert(E.x.toStringFromEnumWithConsecutiveAliases == "x");
	assert(E.y.toStringFromEnumWithConsecutiveAliases == "y");
	assert(E.z.toStringFromEnumWithConsecutiveAliases == "z");
	assert(E.z_.toStringFromEnumWithConsecutiveAliases == "z");
}

/** Faster implementation of `std.conv.to` for enumerations with no aliases.
	Will error if aliases are present.
 */
string toStringFromEnumWithNoAliases(T)(const scope T value) pure nothrow @safe @nogc
if (is(T == enum)) /+ TODO: check for no aliases +/ {
	final switch (value) {
		static foreach (member; __traits(allMembers, T)) {
		case __traits(getMember, T, member):
			return member;
		}
	}
}

///
pure nothrow @safe @nogc unittest {
	enum E { unknown, x, y, z, }
	assert(E.x.toStringFromEnumWithNoAliases == "x");
	assert(E.y.toStringFromEnumWithNoAliases == "y");
	assert(E.z.toStringFromEnumWithNoAliases == "z");
}

/** Convert enumerator value `v` to `string`.
	See_Also: http://forum.dlang.org/post/aqqhlbaepoimpopvouwv@forum.dlang.org
 */
string toStringFromEnumThatMimicsPhobos(T)(T v) if (is(T == enum)) {
	switch (v) {
		foreach (m; __traits(allMembers, T)) {
			case mixin("T." ~ m) : return m;
		}
		default: {
			char[] result = ("cast(" ~ T.stringof ~ ")").dup;
			uint val = v;

			enum headLength = T.stringof.length + "cast()".length;
			const uint log10Val = (val < 10) ? 0 : (val < 100) ? 1 : (val < 1_000) ? 2 :
				(val < 10_000) ? 3 : (val < 100_000) ? 4 : (val < 1_000_000) ? 5 :
				(val < 10_000_000) ? 6 : (val < 100_000_000) ? 7 : (val < 1000_000_000) ? 8 : 9;

			result.length += log10Val + 1;

			foreach (uint i; 0 .. log10Val + 1) {
				cast(char)result[headLength + log10Val - i] = cast(char) ('0' + (val % 10));
				val /= 10;
			}
			return () @trusted { return cast(string) result; }();
		}
	}
}

pure nothrow @safe unittest {
	enum ET { one, two }
	// static assert(to!string(ET.one) == "one");
	static assert (toStringFromEnumThatMimicsPhobos(ET.one) == "one");
	assert (toStringFromEnumThatMimicsPhobos(ET.one) == "one");
}
