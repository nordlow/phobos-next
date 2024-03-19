module nxt.logging;

@safe:

/++ Log level copied from `std.logger.core.LogLevel`.
 +/
enum LogLevel : ubyte
{
	all = 1, /** Lowest possible assignable `LogLevel`. */
	trace = 32, /** `LogLevel` for tracing the execution of the program. */
	info = 64, /** This level is used to display information about the
				program. */
	warning = 96, /** warnings about the program should be displayed with this
				   level. */
	error = 128, /** Information about errors should be logged with this
				   level.*/
	critical = 160, /** Messages that inform about critical errors should be
					logged with this level. */
	fatal = 192,   /** Log messages that describe fatal errors should use this
				  level. */
	off = ubyte.max /** Highest possible `LogLevel`. */
}

enum defaultLogLevel = LogLevel.warning;

void trace(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[trace] ", args);
}

void info(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[info] ", args);
}

void warning(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[warning] ", args);
}

void error(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[error] ", args);
}

void critical(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[critical] ", args);
}

void fatal(Args...)(scope Args args) pure /* nothrow @nogc */ {
	import std.stdio : writeln;
	/+ TODO: check LogLevel +/
	debug writeln("[fatal] ", args);
}
