/++ Utilies for getting DUB packages.
	Test: dmd -version=show -vcolumns -preview=in -preview=dip1000 -g -checkaction=context -allinst -unittest -version=integration_test -i -I.. -main -run dub.d
 +/
module nxt.dub;

// version = integration_test;

@safe:

/++ DUB Package.
	Copy struct from DUB.
 +/
struct Package {
	PackageName name;
}

/++ DUB Package Name.
 +/
struct PackageName {
	string str;
	bool opCast(T : bool)() const scope pure nothrow @nogc => str !is null;
	string toString() inout return scope @property pure nothrow @nogc => str;
}

/++ Get all DUB package names registered on code.dlang.org.
	Parse into `Package`s.
 +/
auto getPackages() @trusted {
	import std.algorithm : map;
	import std.json : parseJSON;
	import std.net.curl : get;
	return url.get.parseJSON.array;
}

/++ Get all DUB package names registered on code.dlang.org.
 +/
auto getPackageNames() @trusted {
	import std.algorithm : map;
	import std.json : parseJSON;
	import std.net.curl : get;
	return url.get.parseJSON.array.map!(a => PackageName(a.str));
}

@safe
version (integration_test)
unittest {
	auto names = getPackageNames();
	assert(names.length >= 2444); // as of 2024-03-12
}

private const url = "https://code.dlang.org/packages/index.json";
