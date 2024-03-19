/++ High-level control of the Git version control system.
	See: https://github.com/s-ludwig/dlibgit
 +/
module nxt.git;

@safe:

/// Depth of git clone.
struct Depth {
	uint value;
	alias value this;
	static Depth min() pure nothrow @safe @nogc => Depth(1);
	static Depth max() pure nothrow @safe @nogc => Depth(value.max);
}

/++ SHA-1 Digest +/
struct SHA1Digest {
	ubyte[20] bytes;
	alias bytes this;
}

/++ (Git) Repository URL.
 +/
struct RepoURL {
	import nxt.path : URL;
	this(string value) pure nothrow @nogc {
		this._value = URL(value); // don't enforce ".git" extension in `value` because it's optional
	}
	URL _value; /+ TODO: replace _value with url +/
	alias _value this;
}

/++ (Git) Repository URL with optional sub-directory relative path.
 +/
struct RepoURLDir {
	import nxt.path : DirPath;
	this(RepoURL url, DirPath subDir = DirPath.init) pure nothrow @nogc {
		this.url = url;
		this.subDir = subDir;
	}
	RepoURL url;
	DirPath subDir; ///< Optional sub-directory in `url`. Can be both in absolute and relative.
}

struct RepositoryAndDir
{
	import std.exception : enforce;
	import nxt.path : DirPath, buildNormalizedPath, exists;
	import nxt.cmd : Spawn, spawn, writeFlushed;
	import nxt.logging : LogLevel, trace, info, warning, error;
	import std.file : exists;

	const RepoURL url;
	const DirPath lrd;			///< Local checkout root directory.
	LogLevel logLevel = LogLevel.warning;

	this(const RepoURL url, const DirPath lrd = [], in bool echoOutErr = true)
	{
		this.url = url;
		if (lrd != lrd.init)
			this.lrd = lrd;
		else
		{
			import std.path : baseName, stripExtension;
			this.lrd = DirPath(this.url._value.str.baseName.stripExtension);
		}
	}

	this(this) @disable;

	// Actions:

	auto ref setLogLevel(in LogLevel logLevel) scope pure nothrow @nogc {
		this.logLevel = logLevel;
		return this;
	}

	Spawn cloneOrPull(in bool recursive = true, string branch = [], in Depth depth = Depth.max)
	{
		if (lrd.buildNormalizedPath(DirPath(".git")).exists)
			return pull(recursive);
		else
			return clone(recursive, branch, depth);
	}

	Spawn cloneOrResetHard(in bool recursive = true, string remote = "origin", string branch = [], in Depth depth = Depth.max)
	{
		if (lrd.buildNormalizedPath(DirPath(".git")).exists)
			return resetHard(recursive, remote, branch);
		else
			return clone(recursive, branch, depth);
	}

	Spawn clone(in bool recursive = true, string branch = [], in Depth depth = Depth.max) const
	{
		import std.conv : to;
		if (logLevel <= LogLevel.trace) trace("Cloning ", url, " to ", lrd);
		return spawn(["git", "clone"]
					 ~ [url._value.str, lrd.str]
					 ~ (branch.length ? ["-b", branch] : [])
					 ~ (recursive ? ["--recurse-submodules"] : [])
					 ~ (depth != depth.max ? ["--depth", depth.to!string] : []),
					 logLevel);
	}

	Spawn pull(in bool recursive = true)
	{
		if (logLevel <= LogLevel.trace) trace("Pulling ", url, " to ", lrd);
		return spawn(["git", "-C", lrd.str, "pull"]
					 ~ (recursive ? ["--recurse-submodules"] : []),
					 logLevel);
	}

	Spawn resetHard(in bool recursive = true, string remote = "origin", string branch = [])
	{
		if (logLevel <= LogLevel.trace) trace("Resetting hard ", url, " to ", lrd);
		if (branch)
			return resetHardTo(remote~"/"~branch, recursive);
		else
			return resetHard(recursive);
	}

	Spawn checkout(string branchName)
	{
		if (logLevel <= LogLevel.trace) trace("Checking out branch ", branchName, " at ", lrd);
		return spawn(["git", "-C", lrd.str, "checkout" , branchName], logLevel);
	}

	Spawn remoteRemove(string name)
	{
		if (logLevel <= LogLevel.trace) trace("Removing remote ", name, " at ", lrd);
		return spawn(["git", "-C", lrd.str, "remote", "remove", name], logLevel);
	}
	alias removeRemote = remoteRemove;

	Spawn remoteAdd(in RepoURL url, string name)
	{
		if (logLevel <= LogLevel.trace) trace("Adding remote ", url, " at ", lrd, (name ? " as " ~ name : "") ~ " ...");
		return spawn(["git", "-C", lrd.str, "remote", "add", name, url._value.str], logLevel);
	}
	alias addRemote = remoteAdd;

	Spawn fetch(string[] names)
	{
		if (logLevel <= LogLevel.trace) trace("Fetching remotes ", names, " at ", lrd);
		if (names)
			return spawn(["git", "-C", lrd.str, "fetch", "--multiple"] ~ names, logLevel);
		else
			return spawn(["git", "-C", lrd.str, "fetch"], logLevel);
	}

	Spawn fetchAll()
	{
		if (logLevel <= LogLevel.trace) trace("Fetching all remotes at ", lrd);
		return spawn(["git", "-C", lrd.str, "fetch", "--all"], logLevel);
	}

	Spawn clean()
	{
		if (logLevel <= LogLevel.trace) trace("Cleaning ", lrd);
		return spawn(["git", "-C", lrd.str, "clean", "-ffdx"], logLevel);
	}

	Spawn resetHard(in bool recursive = true)
	{
		if (logLevel <= LogLevel.trace) trace("Resetting hard ", lrd);
		return spawn(["git", "-C", lrd.str, "reset", "--hard"]
					 ~ (recursive ? ["--recurse-submodules"] : []), logLevel);
	}

	Spawn resetHardTo(string treeish, in bool recursive = true)
	{
		if (logLevel <= LogLevel.trace) trace("Resetting hard ", lrd);
		return spawn(["git", "-C", lrd.str, "reset", "--hard", treeish]
					 ~ (recursive ? ["--recurse-submodules"] : []), logLevel);
	}

	Spawn merge(string[] commits, string[] args = [])
	{
		if (logLevel <= LogLevel.trace) trace("Merging commits ", commits, " with flags ", args, " at ", lrd);
		return spawn(["git", "-C", lrd.str, "merge"] ~ args ~ commits, logLevel);
	}

	Spawn revParse(string treeish, string[] args = []) const
	{
		if (logLevel <= LogLevel.trace) trace("Getting rev-parse of ", treeish, " at ", lrd);
		return spawn(["git", "rev-parse", treeish] ~ args, logLevel);
	}

	// Getters:

@property:

	SHA1Digest commitSHAOf(string treeish) const
	{
		Spawn spawn = revParse(treeish);
		enforce(spawn.wait() == 0);
		return typeof(return).init; /+ TODO: use `spawn.output` +/
	}
}

/++ State of repository.
 +/
struct RepoState {
	string commitShaHex;		// SHA of commit in hexadecimal form.
	string branchOrTag;			// Optional.
}
