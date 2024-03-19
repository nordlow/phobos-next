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
	@property string toString() pure nothrow @safe @nogc => toStringFaster(_enum);
	E _enum;					// the wrapped enum
	alias _enum this;
}

///
pure @safe unittest {
	enum X { a,
			 b,
			 _b = b			 // enumerator alias
	}
	alias EnumX = Enum!X;
	assert(EnumX(X.a).toString == "a");
	assert(EnumX(X.b).toString == "b");
	assert(EnumX(X._b).toString == "b"); // alias encodes to original
}

/** Fast and more generic implementation of `std.conv.to` for enumerations.
 */
string toStringFaster(T)(const scope T value) pure nothrow @safe @nogc
if (is(T == enum)) {
	import std.meta : AliasSeq;
	/* TODO: skip wrapping in `AliasSeq` when `allMembers` can be iterated
	 * directly when a bug in compiler has been fixed */
	alias members = AliasSeq!(__traits(allMembers, T));
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
	enum E { unknown, x, y, z, }
	assert(E.x.toStringFaster == "x");
	assert(E.y.toStringFaster == "y");
	assert(E.z.toStringFaster == "z");
}

/** Faster implementation of `std.conv.to` for enumerations with no aliases.
 */
string toStringNonAliases(T)(const scope T value) pure nothrow @safe @nogc
if (is(T == enum))			  /+ TODO: check for no aliases +/
{
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
	assert(E.x.toStringNonAliases == "x");
	assert(E.y.toStringNonAliases == "y");
	assert(E.z.toStringNonAliases == "z");
}
