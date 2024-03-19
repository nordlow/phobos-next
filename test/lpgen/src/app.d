import lpgen;

int main(string[] args)
{
	version (DigitalMars) {
		// Fails for LDC as: undefined symbol: _D3etc5linux11memoryerror26registerMemoryErrorHandlerFNbZb
		import etc.linux.memoryerror;
		registerMemoryErrorHandler();
	}

	import std.exception : enforce;
	import std.stdio : stdout, stderr;
	import nxt.path : URL, DirPath, expandTilde;
	import nxt.git : RepositoryAndDir, RepoURL;
	import nxt.cmd;

	auto gv4 = RepositoryAndDir(RepoURL("https://github.com/antlr/grammars-v4.git"));
	enforce(!gv4.cloneOrResetHard().wait());
	if (false)					/+ TODO: cli flag +/
		enforce(!gv4.clean().wait());

	BuildCtx bcx = {
		rootDirPath : DirPath("grammars-v4").expandTilde,
		outFile : stdout,
		buildSingleFlag : true,
		buildAllFlag : true,
		lexerFlag : false,
		parserFlag : true,
	};

	doTree(bcx);

	return 0;
}
