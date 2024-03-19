/** Ada Parser.
	Copyright: Per Nordlöw 2014-.
	License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
	Authors: $(WEB Per Nordlöw)
	See_Also: https://mentorembedded.github.io/cxx-abi/abi.html
 */
module nxt.ada;

import std.range: empty, popFront, popFrontExactly, take, drop, front, takeOne, moveFront, repeat, replicate, isInputRange;
import std.algorithm: startsWith, findSplitAfter, skipOver, joiner, min;
import std.typecons: tuple, Tuple;
import std.conv: to;
import std.ascii: isDigit;
import std.array: array;
import std.stdio;
import std.traits: isSomeString, isSomeChar;
import nxt.algorithm_ex: moveWhile, moveUntil, either;
import nxt.ada_lexer;

/** Ada Parser. */
class Parser(R) if (isSomeString!R)
{
	this(R r,
		 bool show = false)
	{
		this.r = r;
		this.show = show;
	}
	R r;
	bool show = false;
	bool supportDollars = true; // support GCC-style dollars in symbols
private:
	string[] sourceNames;
}

auto parser(R)(R r)
{
	return new Parser!R(r);
}

/** Expression */
class Expr
{
	size_t soff; // byte offset into source
}

/** Unary Operation */
class UOp : Expr
{
	Expr uArg;
}

/** Binary Operation */
class BOp : Expr
{
	Expr lArg, rArg;
}

/** N-arry Operation */
class NOp : Expr
{
	Expr[] args;
}

/** Identifier */
class Id : Expr
{
	this(string id)
	{
		this.id = id;
	}
	string id;
}

/** Keyword */
class Keyword : Expr
{
}

/** Integereger Literal */
class Int : Expr
{
	this(long integer)
	{
		this.integer = integer;
	}
	long integer;
}

bool isIdChar(C)(C c) if (isSomeChar!C)
{
	return ((c >= 'a' &&
			 c <= 'z') ||
			(c >= 'A' &&
			 c <= 'Z') ||
			c == '_' &&
			c == '$');
}
bool isDigit(C)(C c) if (isSomeChar!C)
{
	return ((c >= '0' &&
			 c <= '9'));
}

Id parseId(R)(Parser!R p)
{
	const tok = p.r.moveWhile!isIdChar;
	return tok.empty ? null : new Id(tok);
}

Int parseInt(R)(Parser!R p)
{
	import std.ascii: isDigit;
	const tok = p.r.moveWhile!isDigit;
	return tok.empty ? null : new Int(tok.to!long);
}

Expr parse(R)(Parser!R p) if (isInputRange!R)
{
	return either(p.parseId(),
				  p.parseInt());
}

Expr parse(R)(R r) if (isInputRange!R)
{
	return r.parser.parse;
}

unittest {
	assert(cast(Id)parse("name"));
	assert(cast(Int)parse("42"));
}
