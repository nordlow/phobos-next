module nxt.typedoc;

/** Returns: Documentation String for Enumeration Type $(D EnumType). */
string enumDoc(EnumType, string separator = `|`)() @safe pure nothrow
{
	/* import std.traits: EnumMembers; */
	/* return EnumMembers!EnumType.join(separator); */
	/* auto subsSortingNames = EnumMembers!EnumType; */
	auto x = __traits(allMembers, EnumType);
	string doc = ``;
	foreach (ix, name; x)
	{
		if (ix >= 1) { doc ~= separator; }
		doc ~= name;
	}
	return doc;
}

/** Returns: Default Documentation String for value $(D a) of for Type $(D T). */
string defaultDoc(T)(in T a) @safe pure
{
	import std.conv: to;
	return (` (type:` ~ T.stringof ~
			`, default:` ~ to!string(a) ~
			`).`) ;
}
