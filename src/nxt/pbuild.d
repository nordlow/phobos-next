/// Software package builder.
module nxt.pbuild;

import std.path;
import std.stdio;
import std.file;
import std.process;

@safe:

// TODO: make these strong sub-types of string
alias URL = string;             ///< URL.
alias Path = string;            ///< Path.
alias DirName = string;         ///< Directory name.
alias DirPath = string;         ///< Directory path.
alias Name = string;            ///< Build name.
alias Cmd = string;             ///< Commad (name or path).
alias CmdFlag = string;         ///< Command line flag.
alias DlangVersionName = string; ///< D `version` symbol.

@safe unittest
{
    buildN(["vox"]);     // TOOD: replace with `args`
}

int buildN(in string[] names)
{
    const builds = makeBuilds();
    foreach (const name; names)
        if (const Build* buildPtr = name in builds)
            (*buildPtr).go();
	return 0;
}

const DlangVersionName[] versionNames = ["cli"];
const CmdFlag[] compilerFlagsLDCRelease = ["-m64", "-O3", "-release", "-boundscheck=off", "-enable-inlining", "-flto=full"];

/** Returns: build descriptions.
 */
Build[Name] makeBuilds()
{
    Build[Name] builds;
    {
        Build build =
        { name : "vox",
          repoURL : "https://github.com/MrSmith33/vox.git",
          compiler : "ldc2",
          versionNames : ["cli"],
          sourceFilePaths : ["main.d"],
          outFilePath : "vox.out",
          recurseSubModulesFlag : true,
        };
        builds[build.name] = build;
    }
    return builds;
}

/** Build specification.
 */
@safe struct Build
{
    Name name;
    URL repoURL;
    Cmd compiler;
    DlangVersionName[] versionNames;
    Path[] sourceFilePaths;
    Path outFilePath;
    bool recurseSubModulesFlag = true;
    void go() const
    {
        const DirName dlDirName = "ware"; // TODO: change to `sw` later on
        const DirPath dlDirPath = ("~/" ~ dlDirName).expandTilde;

        repoURL.gitCloneOrPullTo(dlDirPath.buildPath(name), recurseSubModulesFlag);

        getdir(dlDirPath);

        const pkgDirPath = buildPath(dlDirPath, name);
        chdir(pkgDirPath);

        string[] cmd = [compiler];

        cmd ~= compilerFlagsLDCRelease;

        foreach (const ver; versionNames)
            cmd ~= ("-d-version=" ~ ver);

        writeln("Compiling via:", cmd);
        const res = execute(cmd);
        if (res.status != 0)
            writeln("Compilation failed:\n", res.output);
        if (res.status != 0)
            writeln("Compilation successful:\n", res.output);
    }
}

/// Relaxed variant of `mkdir`.
void getdir(in const(char)[] pathname)
{
    try
        mkdir(pathname);
    catch (FileException e) {}  // TODO: avoid need for throwing
}

auto gitCloneOrPullTo(in URL repoURL,
                      in string destDir,
                      in bool recurseSubModulesFlag)
{
    const destDirGit = destDir.buildPath(".git");
    if (destDirGit.exists &&
        destDirGit.isDir)
        return gitPullIn(repoURL, destDir); // TODO: respect `recurseSubModulesFlag`
    else
        return gitCloneTo(repoURL,
                          destDir,
                          recurseSubModulesFlag);
}

auto gitPullIn(in URL repoURL,
               in string destDir)
{
    writeln("Pulling ", repoURL, " to ", destDir, " ...");
    auto args = (["git", "-C", destDir, "pull"]);
    const res = execute(args);
    if (res[0])
        writeln(args, " res:", res);
    return res;
}

auto gitCloneTo(in URL repoURL,
                in string destDir,
                in bool recurseSubModulesFlag)
{
    writeln("Cloning ", repoURL, " to ", destDir, " ...");
    auto args = (["git", "clone"] ~
                 (recurseSubModulesFlag ? ["--recurse-submodules"] : []) ~
                 [repoURL, destDir]);
    return execute(args);
}
