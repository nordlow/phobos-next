/++ Command-Line-Interface (CLI) utilities.

	Expose CLI based on a root type being a struct or class or module. By
	default it creates an instance of an aggregate and expose members as
	sub-command. This handles D types, files, etc.

Reflects on nxt.path, string, and other built-in types using arg.to!Arg.

Constructor of T is also reflected as flags before sub-command.

	TODO: Use in MLParser:
	- `--requestedFormats=C,D` or `--fmts` because arg is a Fmt[]
	- `scan dirPath`

Auto-gen of help also works if any arg in args is --help or -h.

 +/
module nxt.cli;

/++ Match method to use when matching CLI sub-commands with member functions. +/
enum Match {
	exact,
	prefix,
	acronym,
}

struct Flags {
	@disable this(this);
	Match match;
}

/++ Evaluate `cmd` as a CLI-like sub-command calling a member of `T`.
	Typically called with the `args` passed to a `main` function.

	Returns: `true` iff the command `cmd` result in a call to `T`-member named `cmd[0]`.

	TODO: Use parameter `flags`

	TODO: Auto-generate help description when --help is passed.

	TODO: Support both
	- EXE scan("/tmp/")
	- EXE scan /tmp/
	where the former is inputted in bash as
      EXE 'scan("/tmp/")'
 +/
bool evalMemberCommand(T)(ref T arg, in const(string)[] cmd, in Flags flags = Flags.init)
if (is(T == struct) || is(T == class)) {
	import nxt.path : Path, FilePath, DirPath;
	if (cmd.length == 0)
		return false;
	auto args = cmd[1 .. $];
	foreach (const mn; __traits(allMembers, T)) { /+ member name +/
		// TODO: Use std.traits.isSomeFunction or it's inlined definition.
		// is(T == return) || is(typeof(T) == return) || is(typeof(&T) == return) /+ isSomeFunction +/
		static immutable qmn = T.stringof ~ '.' ~ mn; /+ qualified +/
		if (cmd[0] != mn)
			continue;
		alias member = __traits(getMember, arg, mn);
		static if (__traits(getVisibility, member) == "public") { // TODO: perhaps include other visibilies later on
			static if (!is(member) /+ not a type +/ && !(mn.length >= 2 && mn[0 .. 2] == "__")) /+ non-generated members like `__ctor` +/ {
				switch (args.length) {
				case 0: // nullary
					static if (__traits(compiles, { mixin(`arg.`~mn~`();`); })) { /+ nullary function +/
						mixin(`arg.`~mn~`();`); // call
						return true;
					}
					break;
				case 1: // unary
					static if (__traits(compiles, { mixin(`arg.`~mn~`(FilePath.init);`); })) {
						mixin(`arg.`~mn~`(FilePath(args[0]));`); // call
						return true;
					}
					static if (__traits(compiles, { mixin(`arg.`~mn~`(DirPath.init);`); })) {
						mixin(`arg.`~mn~`(DirPath(args[0]));`); // call
						return true;
					}
					break;
				default:
					break;
				}
			}
		}
	}
	return false;
}

///
@safe pure unittest {
	import nxt.path : DirPath;

	struct S {
	version (none) @disable this(this);
	@safe pure nothrow @nogc:
		void f1() scope {
			f1Count += 1;
		}
		void f2(int inc = 1) scope { // TODO: support f2:32
			f2Count += inc;
		}
		void scan(DirPath path) {
			_path = path;
			_scanDone = true;
		}
		private uint f1Count;
		uint f2Count;
		DirPath _path;
		bool _scanDone;
	}
	S s;

	assert(!s.evalMemberCommand([]));
	assert(!s.evalMemberCommand([""]));
	assert(!s.evalMemberCommand(["_"]));

	assert(s.f1Count == 0);
	s.evalMemberCommand(["f1"]);
	assert(s.f1Count == 1);

	assert(s.f2Count == 0);
	s.evalMemberCommand(["f2"]); // TODO: call as "f2", "42"
	assert(s.f2Count == 1);

	assert(s._path == DirPath.init);
	assert(!s._scanDone);
	assert(s.evalMemberCommand(["scan", "/tmp"]));
	assert(s._path == DirPath("/tmp"));
	assert(s._scanDone);
}

version (unittest) {
import nxt.debugio;
}
