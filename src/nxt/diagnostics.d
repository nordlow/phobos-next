/** Diagnostics.
 */
module nxt.diagnostics;

import nxt.line_column : LineColumn;
import nxt.path : FilePath;

/++ Diagnose GNU style diagnostics message.
	See_Also: https://gcc.gnu.org/codingconventions.html#Diagnostics
    See_Also: https://clang.llvm.org/diagnostics.html
 +/
void diagnoseGNU(Args...)(scope const(char)[] tag,
						  in FilePath path,
						  in LineColumn lc,
						  in Args args) @safe
{
	import std.stdio : writeln;
	debug writeln(path,
				  ":", lc.line + 1, // line offset starts at 1
				  ":", lc.column,   // column counter starts at 0
				  ": ", tag, ": ", args);
}
