/++ Semantic Versioning.
	TODO: Make `Major`, `Minor` and `Patch` sub-types when D gets implicit conversion in argument passing.
	See_Also: https://docs.rs/semver/latest/semver/
 +/
module nxt.semver;

import nxt.result : Result;

@safe:

/++ Semantic version number.
 +/
struct Version {
@safe pure nothrow @nogc:
    this(Major major, Minor minor = 0, Patch patch = 0, Prerelease pre = Prerelease.init, BuildMetadata build = BuildMetadata.init) {
        _major = major;
        _minor = minor;
        _patch = patch;
        _pre = pre;
        _build = build;
	}
@property:
	Major major() const scope => _major;
	Minor minor() const scope => _minor;
	Patch patch() const scope => _patch;
	Prerelease pre() const scope => _pre;
	BuildMetadata build() const scope => _build;
private:
	Major _major;
	Minor _minor;
	Patch _patch;
    Prerelease _pre;
    BuildMetadata _build;
}

/++ Major part. +/
alias Major = VersionPart;

/++ Minor part. +/
alias Minor = VersionPart;

/++ Patch part. +/
alias Patch = VersionPart;

/++ Parts of semantic version numbers. +/
alias VersionPart = uint;

/++ Prerelease.
	See_also: https://docs.rs/semver/latest/semver/struct.Prerelease.html
 +/
struct Prerelease {
	// TODO:
	// string str;
}

/++ Build metadata.
	See_also: https://docs.rs/semver/latest/semver/struct.BuildMetadata.html
 +/
struct BuildMetadata {
	// TODO:
}

///
@safe pure nothrow @nogc unittest {
	assert(Version(1)     == Version(1));
	assert(Version(1,0)   == Version(1,0));
	assert(Version(0,0,0) == Version(0,0,0));
	assert(Version(0,0,0) != Version(0,0,1));
	assert(Version(1,0,0).major == Version(1,0,0).major);
	assert(Version(1,0,0).minor == Version(1,0,0).minor);
	assert(Version(1,0,0).patch == Version(1,0,0).patch);
	assert(Version(1,0,0).pre   == Version(1,0,0).pre);
	assert(Version(1,0,0).build == Version(1,0,0).build);
}

/++ Parse `s` as a semantic version number.

 	Semantic versions are usually represented as string as:
	`MAJOR[.MINOR[.PATCH]][-PRERELEASE][+BUILD]`.

 	For ease of use, a leading `v` or a leading `=` are also accepted.

 	See_Also: https://docs.rs/semver/latest/semver/struct.Version.html
 +/
Result!Version tryParseVersion(scope const(char)[] s) pure nothrow @nogc {
	import nxt.algorithm.searching : findSplit;
	import nxt.conv : tryParse;

	alias R = typeof(return);
	Version semver;

    if (s.length == 0)
        return R.invalid;

	if (s[0] == 'v' || s[0] == '=') // skip leading {'v'|'='}
		s = s[1 .. $];

	// major
	if (auto sp = s.findSplit('.')) {
		if (const hit = sp.pre.tryParse!Major)
			semver._major = hit.value;
		else
			return R.invalid;
		() @trusted { s = sp.post; }(); // TODO: -dip1000 should allow this
	} else
		return R.invalid;

	// minor
	if (auto sp = s.findSplit('.')) {
		if (const hit = sp.pre.tryParse!Minor)
			semver._minor = hit.value;
		else
			return R.invalid;
		() @trusted { s = sp.post; }(); // TODO: -dip1000 should allow this
	} else
		return R.invalid;

	// patch
    if (s.length == 0)
        return R.invalid;

	if (const hit = s.tryParse!Patch)
		semver._patch = hit.value;
	else
		return R.invalid;

	return R(semver);
}

///
@safe pure nothrow @nogc unittest {
	assert(*tryParseVersion("0.0.0") == Version(0,0,0));
	assert(*tryParseVersion("0.0.1") == Version(0,0,1));
	assert(*tryParseVersion("0.1.1") == Version(0,1,1));
	assert(*tryParseVersion("1.1.1") == Version(1,1,1));
	assert(!tryParseVersion(""));
	assert(!tryParseVersion("").isValue);
	assert(!tryParseVersion("_").isValue);
	assert(!tryParseVersion("").isValue);
	assert(!tryParseVersion("1").isValue);
	assert(!tryParseVersion("_").isValue);
	assert(!tryParseVersion("1.").isValue);
	assert(!tryParseVersion("1._").isValue);
	assert(!tryParseVersion("1.1.").isValue);
	assert(!tryParseVersion("1.1").isValue);
	assert(!tryParseVersion("1.1_1").isValue);
	assert(!tryParseVersion("1-1-1").isValue);
	assert(!tryParseVersion("_._.__").isValue);
	assert(!tryParseVersion("1._.__").isValue);
	assert(!tryParseVersion("1.1.__").isValue);
	assert(*tryParseVersion("v1.1.1") == Version(1,1,1));
	assert(*tryParseVersion("=1.1.1") == Version(1,1,1));
}
