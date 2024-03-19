/** Universal Build System.
 *
 * TODO: Support `$0 REPO_URL`. Try for instance git@github.com:rui314/mold.git
 * or https://github.com/rui314/mold.git. Supports matching repo with registered
 * repos where repo name is stripped ending slash before matching.
 *
 * TODO: Delete installPrefix prior to installation
 *
 * TODO: Support `xy REPO_URL`. Try for instance git@github.com:rui314/mold.git
 * or https://github.com/rui314/mold.git. Supports matching repo with registered
 * repos where repo name is stripped ending slash before matching.
 *
 */
module xdag;

// version = main;

debug import std.stdio : writeln;
import std.process : Config, spawnProcess, wait, Pid;

import nxt.path;
import nxt.file : homeDir;
import nxt.git : RepoURL;

private alias ProcessEnvironment = string[string];

version (main) {
	int main(string[] args) {
		return buildN(args[1 .. $]);
	}
}

/// Spec Name.
struct Name { string value; alias value this; }

/// D `version` symbol.
alias DlangVersionName = string;

struct RemoteSpec {
	RepoURL url;
	string remoteName;
	string[] repoBranches;
}

void ewriteln(S...)(S args) @trusted {
	import std.stdio : writeln, stderr;
	return stderr.writeln(args);
}

/** Build the packages `packages`.
 */
int buildN(scope const string[] packages) {
	const bool echo = true; // std.getopt: TODO: getopt flag being negation of make-like flag -s, --silent, --quiet
	const BuildOption[] bos;
	auto builds = makeSpecs(echo);
	foreach (const name; packages)
		if (Spec* buildPtr = Name(name) in builds) {
			(*buildPtr).go(bos, echo);
		}
		else {
			ewriteln("No spec named ", Name(name), " found");
		}
	return 0;				   /+ TODO: propagate exit code +/
}

const DlangVersionName[] versionNames = ["cli"];
const string[] dflagsLDCRelease = ["-m64", "-O3", "-release", "-boundscheck=off", "-enable-inlining", "-flto=full"];

/++ Build option.
 +/
enum BuildOption {
	debugMode,			/// Compile in debug mode (enables contracts, -debug)
	releaseMode,		  /// Compile in release mode (disables assertions and bounds checks, -release)
	ltoMode,			  /// Compile using LTO
	pgoMode,			  /// Compile using PGO
	coverage,			 /// Enable code coverage analysis (-cov)
	debugInfo,			/// Enable symbolic debug information (-g)
	debugInfoC,		   /// Enable symbolic debug information in C compatible form (-gc)
	alwaysStackFrame,	 /// Always generate a stack frame (-gs)
	stackStomping,		/// Perform stack stomping (-gx)
	inline,			   /// Perform function inlining (-inline)
	optimize,			 /// Enable optimizations (-O)
	profile,			  /// Emit profiling code (-profile)
	unittests,			/// Compile unit tests (-unittest)
	verbose,			  /// Verbose compiler output (-v)
	ignoreUnknownPragmas, /// Ignores unknown pragmas during compilation (-ignore)
	syntaxOnly,		   /// Don't generate object files (-o-)
	warnings,			 /// Enable warnings (-wi)
	warningsAsErrors,	 /// Treat warnings as errors (-w)
	ignoreDeprecations,   /// Do not warn about using deprecated features (-d)
	deprecationWarnings,  /// Warn about using deprecated features (-dw)
	deprecationErrors,	/// Stop compilation upon usage of deprecated features (-de)
	property,			 /// DEPRECATED: Enforce property syntax (-property)
	profileGC,			/// Profile runtime allocations
	pic,				  /// Generate position independent code
	betterC,			  /// Compile in betterC mode (-betterC)
	lowmem,			   /// Compile in lowmem mode (-lowmem)
}

alias BuildFlagsByOption = string[][BuildOption];

Spec[Name] makeSpecs(bool echo) {
	typeof(return) specs;
	{
		const name = "vox";
		Spec spec =
		{ homePage : URL("https://github.com/MrSmith33/"~name~"/"),
		  name : Name(name),
		  url : RepoURL("https://github.com/MrSmith33/"~name~".git"),
		  compiler : FilePath("ldc2"),
		  versionNames : ["cli"],
		  sourceFilePaths : [Path("main.d")],
		  outFilePath : Path(name~".out"),
		};
		specs[spec.name] = spec;
	}
	{
		const name = "dmd";
		Spec spec =
		{ homePage : URL("http://dlang.org/"),
		  name : Name(name),
		  url : RepoURL("https://github.com/dlang/"~name~".git"),
		  // nordlow/selective-unittest-2
		  // nordlow/check-self-assign
		  // nordlow/check-unused
		  extraRemoteSpecs : [RemoteSpec(RepoURL("https://github.com/nordlow/dmd.git"), "nordlow",
										 ["relax-alias-assign",
										 "traits-isarray-take2",
										  "diagnose-padding",
										  "aliasseq-bench",
										  "add-traits-hasAliasing",
										  "unique-qualifier"]),
							  // RemoteSpec(RepoURL("https://github.com/UplinkCoder/dmd.git"), "skoch", ["newCTFE_upstream"]),
		  ],
		  // patches : [Patch(Path("new-ctfe.patch"), 1, echo)],
		  buildFlagsDefault : ["PIC=1"],
		  buildFlagsByOption : [BuildOption.debugMode : ["ENABLE_DEBUG=1"],
							BuildOption.releaseMode : ["ENABLE_RELASE=1"]],
		};
		specs[spec.name] = spec;
	}
	{
		const name = "phobos";
		Spec spec =
		{ homePage : RepoURL("http://dlang.org/"),
		  name : Name(name),
		  url : RepoURL("https://github.com/dlang/"~name~".git"),
		  extraRemoteSpecs : [RemoteSpec(RepoURL("https://github.com/nordlow/phobos.git"), "nordlow", ["faster-formatValue"])],
		};
		specs[spec.name] = spec;
	}
	{
		const name = "dub";
		Spec spec =
		{ homePage : RepoURL("http://dlang.org/"),
		  name : Name(name),
		  url : RepoURL("https://github.com/dlang/"~name~".git"),
		};
		specs[spec.name] = spec;
	}
	{
		const name = "DustMite";
		Spec spec =
		{ homePage : RepoURL("https://github.com/CyberShadow/"~name~"/wiki"),
		  name : Name(name),
		  compiler : FilePath("ldmd2"),
		  sources : ["dustmite.d", "polyhash.d", "splitter.d"],
		  url : RepoURL("https://github.com/CyberShadow/"~name~".git"),
		};
		specs[spec.name] = spec;
	}
	{
		const name = "DCD";
		Spec spec =
		{ name : Name(name),
		  url : RepoURL("https://github.com/dlang-community/"~name~".git"),
		  buildFlagsDefault : ["ldc"],
		  buildFlagsByOption : [BuildOption.debugMode : ["debug"],
							BuildOption.releaseMode : ["ldc"]],
		};
		specs[spec.name] = spec;
	}
	{
		const name = "mold";
		Spec spec =
		{ name : Name(name),
		  url : RepoURL("https://github.com/rui314/"~name~".git"),
		};
		specs[spec.name] = spec;
	}
	return specs;
}

/** Launch/Execution specification.
 */
@safe struct Spec {
	import std.exception : enforce;
	import std.algorithm : canFind, joiner;
	import std.file : chdir, exists, mkdir;
	import nxt.patching : Patch;

	URL homePage;
	Name name;

	// Git sources
	RepoURL url;
	string gitRemote = "origin";
	string gitBranch;
	RemoteSpec[] extraRemoteSpecs;
	Patch[] patches;

	FilePath compiler;
	string[] sources;
	string[] buildFlagsDefault;
	BuildFlagsByOption buildFlagsByOption;
	DlangVersionName[] versionNames;
	Path[] sourceFilePaths;
	Path outFilePath;
	uint jobCount;
	bool recurseSubModulesFlag = true;

	void go(scope ref const BuildOption[] bos, in bool echo) scope @trusted { // TODO: -dip1000 without @trusted
		const dlRoot = homeDir.buildPath(DirPath(".cache/repos"));
		const dlDir = dlRoot.buildPath(DirName(name));
		writeln();
		/+ TODO: create build DAG and link these steps: +/
		fetch(bos, dlDir, echo);
		prebuild(bos, dlDir, echo);
		build(bos, dlDir, echo);
	}

	void fetch(scope ref const BuildOption[] bos, in DirPath dlDir, in bool echo) scope @trusted { // TODO: -dip1000 without @trusted
		import nxt.git : RepositoryAndDir;
		import core.thread : Thread;
		auto rad = RepositoryAndDir(url, dlDir, echo);
		/+ TODO: use waitAllInSequence(); +/
		enforce(!rad.cloneOrResetHard(recurseSubModulesFlag, gitRemote, gitBranch).wait());
		enforce(!rad.clean().wait());
		string[] remoteNames;
		foreach (const spec; extraRemoteSpecs)
		{
			remoteNames ~= spec.remoteName;
			const statusIgnored = rad.remoteRemove(spec.remoteName).wait(); // ok if already removed
			enforce(!rad.remoteAdd(spec.url, spec.remoteName).wait());
		}
		enforce(!rad.fetch(remoteNames).wait());
		foreach (const spec; extraRemoteSpecs)
			foreach (const gitBranch; spec.repoBranches)
				enforce(!rad.merge([spec.remoteName~"/"~gitBranch], ["--no-edit", "-Xignore-all-space"]).wait());
		foreach (ref patch; patches)
			enforce(!patch.applyIn(dlDir).wait());
	}

	string[] bosFlags(scope ref const BuildOption[] bos) const scope pure nothrow {
		typeof(return) result;
		foreach (bo; bos)
			result ~= buildFlagsByOption[bo];
		return result;
	}

	string[] allBuildFlags(scope ref const BuildOption[] bos) const scope pure nothrow {
		return buildFlagsDefault ~ bosFlags(bos) ~ jobFlags() ~ sources;
	}

	void prebuild(scope ref const BuildOption[] bos, in DirPath workDir, in bool echo) const scope {
		if (exists("CMakeLists.txt")) {
			return prebuildCmake(bos, workDir, echo);
		}
	}

	void prebuildCmake(scope ref const BuildOption[] bos, in DirPath workDir, in bool echo) const scope @trusted { // TODO: -dip1000 without @trusted
		Config config = Config.none;
		string[] args;
		ProcessEnvironment env_;

		chdir(workDir.str);		 /+ TODO: replace with absolute paths in exists or dir.exists +/

		args = ["cmake"];
		const ninjaAvailable = true; /+ TODO: check if ninja is available +/
		if (ninjaAvailable) {
			args ~= ["-G", "Ninja"];
		}
		args ~= ["."];		/+ TODO: support out-of-source (OOS) build +/
		writeln("Pre-Building as `", args.joiner(" "), "` ...");
		scope Pid pid = spawnProcess(args, env_, config, workDir.str);
		const status = pid.wait();
		if (status != 0)
			writeln("Compilation failed:\n");
		if (status != 0)
			writeln("Compilation successful:\n");
	}

	void build(scope ref const BuildOption[] bos, in DirPath workDir, in bool echo) const scope @trusted { // TODO: -dip1000 without @trusted
		Config config = Config.none;

		chdir(workDir.str);		 /+ TODO: replace with absolute paths in exists or dir.exists +/

		/+ TODO: create build DAG and link these steps: +/

		string[] args;
		ProcessEnvironment env_;

		/+ TODO: when serveral of this exists ask user +/
		if (exists("Makefile"))
			args = ["make", "-f", "Makefile"] ~ allBuildFlags(bos);
		else if (exists("makefile"))
			args = ["make", "-f", "makefile"] ~ allBuildFlags(bos);
		else if (exists("posix.mak"))
			args = ["make", "-f", "posix.mak"] ~ allBuildFlags(bos);
		else if (exists("dub.sdl") ||
				 exists("dub.json"))
			args = ["dub", "build"];
		else
		{
			if (!compiler) {
				if (bos.canFind(BuildOption.debugMode))
					args = [FilePath("dmd").str];
				else if (bos.canFind(BuildOption.releaseMode))
					args = [FilePath("ldc2").str];
				else
					args = [FilePath("dmd").str]; // default to faster dmd
			} else {
				args = [compiler.str];
			}
			if (bos.canFind(BuildOption.releaseMode) &&
				(compiler.str.canFind("ldc2") ||
				 compiler.str.canFind("ldmd2")))
				args ~= dflagsLDCRelease; /+ TODO: make declarative +/
			foreach (const ver; versionNames)
				args ~= ("-d-version=" ~ ver);
			args ~= sources;
		}
		/* ${DC} -release -boundscheck=off dustmite.d splitter.d polyhash.d */
		/*	   mkdir -p ${DMD_EXEC_PREFIX} */
		/* mv dustmite ${DMD_EXEC_PREFIX} */

		enforce(args.length, "Could not deduce build command");

		/+ TODO: Use: import nxt.cmd : spawn; +/
		writeln("Building as `", args.joiner(" "), "` ...");
		/* TODO: add a wrapper spawnProcess1 called by Patch.applyIn,
		 * Repository.spawn and here that sets stdout, stderr based on bool
		 * echo. */
		scope Pid pid = spawnProcess(args, env_, config, workDir.str);
		const status = pid.wait();
		if (status != 0)
			writeln("Compilation failed:\n");
		if (status != 0)
			writeln("Compilation successful:\n");
	}

	string[] jobFlags() const scope pure nothrow {
		import std.conv : to;
		return jobCount ? ["-j"~jobCount.to!string] : [];
	}
}

int[] waitAllInSequence(scope Pid[] pids...) {
	typeof(return) statuses;
	foreach (pid; pids)
		statuses ~= pid.wait();
	return statuses;
}

int[] waitAllInParallel(scope Pid[] pids...) {
	assert(0, "TODO: implement and use in place of waitAllInSequence");
}
