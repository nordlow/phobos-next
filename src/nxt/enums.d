/** Extensions to Enumerations.

	Copyright: Per Nordlöw 2022-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)

	TODO: Implement bidirection conversions: http://forum.dlang.org/thread/tuafkxmnntqjgycziixn@forum.dlang.org#post-tuafkxmnntqjgycziixn:40forum.dlang.org

	TODO: Join logic for ChainEnum and UnionEnum into common and then define:
	- UnionEnum: only names must be unique
	- StrictUnionEnum: both names and values must be unique

	TODO: Move to std.typecons (Type Constructor) in Phobos when ready.
 */
module nxt.enums;

import std.meta: allSatisfy, staticMap;
import std.traits: EnumMembers, CommonType, OriginalType;
import std.conv: to;
import core.exception;
import std.exception: assertThrown;

/* version = print; */
version (print) import std.stdio: writefln;

/* Helpers */
private enum isEnum(T) = is(T == enum);
private alias CommonOriginalType(T...) = CommonType!(staticMap!(OriginalType, T));

/** Chain (Append, Concatenate) Member Names of Enumerations $(D E).
	All enumerator names of $(D E) must be unique.
	See_Also: http://forum.dlang.org/thread/f9vc6p$1b7k$1@digitalmars.com
*/
template ChainEnum(E...) if (E.length >= 2 &&
							 allSatisfy!(isEnum, E) &&
							 is(CommonOriginalType!E)) {
	mixin({ string r = "enum ChainEnum { ";
			string[string] names;   // lookup: enumName[memberName]
			foreach (T; E) {
				import std.range: join;
				foreach (m; __traits(allMembers, T)) {
					assert(m !in names,
						   "Enumerator " ~ T.stringof ~"."~m ~
						   " collides with " ~ names[m] ~"."~m);
					names[m] = T.stringof;
				}
				r ~= [__traits(allMembers, T)].join(",") ~ ",";
			}
			return r ~ " }";
		}());
}

unittest {
	enum E0 { a, b, c }
	enum E1 { e, f, g }
	enum E2 { h, i, j }
	alias E12 = ChainEnum!(E0, E1);
	alias E123 = ChainEnum!(E0, E1, E2);
	version (print)
		foreach (immutable e; [EnumMembers!E123])
			writefln("E123.%s: %d", e, e);
}

/** Unite (Join) Members (both their Names and Values) of Enumerations $(D E).
	All enumerator names and values of $(D E) must be unique.
 */
template UnionEnum(E...) if (E.length >= 2 &&
							 allSatisfy!(isEnum, E) &&
							 is(CommonOriginalType!E)) {
	mixin({
			string r = "enum UnionEnum { ";
			alias O = CommonOriginalType!E;
			string[string] names;   // lookup: enumName[memberName]
			string[O] values;
			foreach (ix, T; E) {
				foreach (m; EnumMembers!T) // foreach member
				{
					// name
					enum n = to!string(m);
					assert(n !in names,
						   "Template argument E[" ~ to!string(ix)~
						   "]'s enumerator name " ~ T.stringof ~"."~n ~
						   " collides with " ~ names[n] ~"."~n);
					names[n] = T.stringof;

					// value
					enum v = to!O(m);
					assert(v !in values,
						   "Template argument E[" ~ to!string(ix)~
						   "]'s enumerator value " ~ T.stringof ~"."~n ~" == "~ to!string(v) ~
						   " collides with member value of " ~ values[v]);
					values[v] = T.stringof;

					r ~= to!string(n) ~ "=" ~ to!string(v) ~ ",";
				}
			}
			return r ~ " }";
		}());
}

/** Instance Wrapper for UnionEnum.
	Provides safe assignment and explicit casts.
	TODO: Use opImplicitCastTo instead of opCast when it becomes available in DMD.
*/
struct EnumUnion(E...) {
	alias OriginalType = CommonOriginalType!E;
	alias U = UnionEnum!(E);	// Wrapped Type.
	alias _value this;

	@safe pure nothrow:

	import std.conv : asOriginalType;

	static if (E.length >= 1) {
		void opAssign(E[0] e) { _value = cast(U)e; }
		E[0] opCast(T : E[0])() const
		{
			bool match = false;
			foreach (m; EnumMembers!(E[0])) {
				if (m.asOriginalType == _value.asOriginalType) {
					match = true;
				}
			}
			version (assert) if (!match) { throw new RangeError(); }
			return cast(E[0])_value;
		}
	}
	static if (E.length >= 2) {
		void opAssign(E[1] e) { _value = cast(U)e; }
		E[1] opCast(T : E[1])() const
		{
			bool match = false;
			foreach (m; EnumMembers!(E[1])) {
				if (m.asOriginalType == _value.asOriginalType) {
					match = true;
				}
			}
			version (assert) if (!match) { throw new RangeError(); }
			return cast(E[1])_value;
		}
	}

	/* TODO: Use (static) foreach here when it becomes available. */
	/* foreach (ix, E0; E) */
	/* { */
	/* } */
	static if (E.length >= 3) void opAssign(E[2] e) { _value = cast(U)e; }
	static if (E.length >= 4) void opAssign(E[3] e) { _value = cast(U)e; }
	static if (E.length >= 5) void opAssign(E[4] e) { _value = cast(U)e; }
	static if (E.length >= 6) void opAssign(E[5] e) { _value = cast(U)e; }
	static if (E.length >= 7) void opAssign(E[6] e) { _value = cast(U)e; }
	static if (E.length >= 8) void opAssign(E[7] e) { _value = cast(U)e; }
	static if (E.length >= 9) void opAssign(E[8] e) { _value = cast(U)e; }

	/* ====================== */
	/* TODO: Why doesn't the following mixin templates have an effect? */
	version (linux) {
		mixin template genOpAssign(uint i) {
			static if (i == 0)
				auto fortytwo() { return 42; }
			void opAssign(E[i] e) {
				_value = cast(U)e;
			}
		}
		mixin template genOpCast(uint i) {
			E[i] opCast(T : E[i])() const
			{
				bool match = false;
				foreach (m; EnumMembers!(E[i])) {
					if (m == _value) {
						match = true;
					}
				}
				version (assert) if (!match) { throw new RangeError(); }
				return cast(E[i])_value;
			}
		}
		/* TODO: Alternative to this set of static if? */
		static if (E.length >= 1) { mixin genOpAssign!0; mixin genOpCast!0; }
		static if (E.length >= 2) { mixin genOpAssign!1; mixin genOpCast!1; }
		static if (E.length >= 3) { mixin genOpAssign!2; mixin genOpCast!2; }
		static if (E.length >= 4) { mixin genOpAssign!3; mixin genOpCast!3; }
		static if (E.length >= 5) { mixin genOpAssign!4; mixin genOpCast!4; }
		static if (E.length >= 6) { mixin genOpAssign!5; mixin genOpCast!5; }
		static if (E.length >= 7) { mixin genOpAssign!6; mixin genOpCast!6; }
		static if (E.length >= 8) { mixin genOpAssign!7; mixin genOpCast!7; }
		static if (E.length >= 9) { mixin genOpAssign!8; mixin genOpCast!8; }
	}

	/* ====================== */

	private U _value;		   // Instance.
}

unittest {
	enum E0:ubyte  { a = 0, b = 3, c = 6 }
	enum E1:ushort { p = 1, q = 4, r = 7 }
	enum E2:uint   { x = 2, y = 5, z = 8 }

	alias EU = EnumUnion!(E0, E1, E2);
	EU eu;
	static assert(is(EU.OriginalType == uint));

	version (print)
		foreach (immutable e; [EnumMembers!(typeof(eu._value))])
			writefln("E123.%s: %d", e, e);

	auto e0 = E0.max;

	eu = e0;					// checked at compile-time
	assert(eu == E0.max);

	e0 = cast(E0)eu;			// run-time check is ok
	assertThrown!RangeError(cast(E1)eu);// run-time check should fail

	enum Ex:uint { x = 2, y = 5, z = 8 }
	static assert(!__traits(compiles, { Ex ex = Ex.max; eu = ex; } ));

	/* check for compilation failures */
	enum D1 { a = 0, b = 3, c = 6 }
	static assert(!__traits(compiles, { alias ED = UnionEnum!(E0, D1); } ), "Should give name and value collision");
	enum D2 { a = 1, b = 4, c = 7 }
	static assert(!__traits(compiles, { alias ED = UnionEnum!(E0, D2); } ), "Should give name collision");
	enum D3 { x = 0, y = 3, z = 6 }
	static assert(!__traits(compiles, { alias ED = UnionEnum!(E0, D3); } ),  "Should give value collision");
}
