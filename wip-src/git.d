import std.exception : enforce;
import std.format : format;
import std.file;
import std.path;
import std.stdio : writeln, writefln;

/// Based on: https://git-scm.com/docs/git-status#_output
enum GitStatusSingleSide : char
{
	@("unmodified")		   unmodified =  ' ',
	@("ignored")			  ignored = '!',
	@("untracked")			untracked = '?',
	@("modified")			 modified = 'M',
	@("added")				added = 'A',
	@("deleted")			  deleted = 'D',
	@("renamed")			  renamed = 'R',
	@("copied")			   copied = 'C',
	@("updated but unmerged") updatedNotMerged = 'U'
}

@safe struct GitStatus
{
	GitStatusSingleSide x, y;
	char[2] xy() const pure nothrow { return [x, y]; }
	alias xy this;
}

string interpretGitStatus(GitStatus s) @safe pure
{
	if (s.x == 'U' ||
		s.y == 'U' ||
		s == "DD" ||
		s == "AA")
	{
		// unmerged
		if (s.x == s.y)
			return "both " ~ s.x.enumUdaToString;
		else if (s.x == 'U')
			return s.y.enumUdaToString ~ " by them";
		else if (s.y == 'U')
			return s.x.enumUdaToString ~ " by us";
		else
			assert(0, "Unhandled `git status` case: " ~ s);
	}
	else if (s == "??" ||
			 s == "!!")
	{
		// ignored or untracked
		return s.x.enumUdaToString;
	}
	else
	{
		// no merge conflict
		return "in index: <%s> | <%s> in work tree".format(s.tupleof);
	}
}

GitStatus gitStatus(scope string filePath) @safe
{
	//enforce(filePath.isFile, "'" ~ filePath ~ "' is not a file.");
	const gitRoot = getGitRootPathOfFileOrDir(filePath);
	const gitStatusResult = ["git", "status", "--porcelain=v1", filePath].executeInDir(gitRoot);
	enforce(gitStatusResult.length >= "XY f".length);
	GitStatus result =
	{
	x: gitStatusResult[0].assertMemberOfEnum!GitStatusSingleSide,
	y: gitStatusResult[1].assertMemberOfEnum!GitStatusSingleSide
	};
	return result;
}

string toGitRelativePath(scope string path) @safe
{
	const cwd = getcwd();
	const gitRoot = path.getGitRootPathOfFileOrDir();
	return path
	.relativePath(/* base: */ gitRoot).buildNormalizedPath;
}

string getGitRootPathOfFileOrDir(scope string path_) @safe
{
	auto path = path_.absolutePath;
	// Find the closest directory to the path that exists
	while (!path.exists ||
		   !path.isDir)
		path = path.dirName;
	const gitRootPathResult = "git rev-parse --show-toplevel".executeInDir(path);
	return gitRootPathResult;
}

/++
 Execute `Cmd` in the given `dir` and return the output.

 If `Cmd` is a `string` it does so via `executeShell`, otherwise via `spawnProcess`,
 the latter of which doesn't go through the shell.

 Returns:
 The captured output of the execution of the command with all trailing
 whitespace removed.
 +/
string executeInDir(Cmd)(scope Cmd cmd, scope string dir, scope string messageIfCommandFails = null)
if (is(Cmd : const char[]) ||
	is(Cmd : const char[][]))
in (dir.isDir)
{
	import std.process : Config, execute, executeShell;
	import std.string : stripRight;
	static if (is(Cmd : const char[]))
		const result = executeShell(
			cmd,
			/* env: */ null,
			/* config: */ Config.none,
			/* maxOutput: */ size_t.max,
			/* dir: */ dir
			); // comments written in anticipation of DIP1030 ;)
	else
		const result = execute(
			cmd,
			/* env: */ null,
			/* config: */ Config.none,
			/* maxOutput: */ size_t.max,
			/* dir: */ dir
			); // comments written in anticipation of DIP1030 ;)
	enforce(result.status == 0,
			"command: '%-s' failed.%s".format(cmd, "\n" ~ messageIfCommandFails));
	return result.output.stripRight;
}

string enumUdaToString(E)(E value)
if (is(E == enum))
{
	final switch (value)
	{
		static foreach (memberName; __traits(allMembers, E))
		case mixin(E, '.', memberName):
			return __traits(getAttributes, mixin(E, '.', memberName))[0];
	}
}

E assertMemberOfEnum(E)(BaseEnumType!E value)
if (is(E == enum))
{
	final switch (value)
	{
		static foreach (memberName; __traits(allMembers, E))
		{
			{
				enum member = mixin(E, '.', memberName);
				case member:
					return member;
			}
		}
	}
}

template BaseEnumType(E)
{
	static if (is(E Base == enum))
		alias BaseEnumType = Base;
	else
		static assert (0, "`E` is not an enum type");
}

private void testMe(scope string[] args) @safe
{
	enforce(args.length == 2, "Usage:\n\tabs_to_rel_git_path <path>");
	const path = args[1];
	//enforce(path.isFile, "'" ~ path ~ "' is not a file.");
	static void hLine() @safe
	{
		import std.range : repeat;
		"%-(%s%)".writefln("-".repeat(20));
	}
	const gitRoot = path.getGitRootPathOfFileOrDir;
	const relativePath = path.toGitRelativePath;
	const status = path.gitStatus;
	hLine();
	writeln("Git repo: ", gitRoot);
	hLine();
	writefln("File: %s\nStatus: %s",
			 relativePath,
			 status.interpretGitStatus);
	hLine();
}
