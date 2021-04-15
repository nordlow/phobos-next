/// Software package builder.
module nxt.pbuild;

import std.path;
import std.stdio;
import std.file;
import std.process;

import nxt.file_system;
import nxt.git;

@safe:

@safe unittest
{
    buildN(["vox"]);     // TOOD: replace with `args`
}

/// Build Name.
alias Name = string;

/// Commad (name or path).
alias Cmd = string;

/// Command line flag.
alias CmdFlag = string;

/// D `version` symbol.
alias DlangVersionName = string;

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
          repoURL : URL("https://github.com/MrSmith33/vox.git"),
          compiler : "ldc2",
          versionNames : ["cli"],
          sourceFilePaths : [Path("main.d")],
          outFilePath : Path("vox.out"),
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
        const dlDirName = DirName("ware"); // TODO: change to `sw` later on
        const dlDirPath = ("~/" ~ dlDirName).expandTilde;

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
