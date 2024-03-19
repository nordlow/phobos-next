/** Lexer and parser of Lisp-like languages, including SUO-KIF and Emacs-Lisp.
 *
 * See_Also: https://www.csee.umbc.edu/csee/research/kif/
 * See_Also: https://en.wikipedia.org/wiki/Knowledge_Interchange_Format
 * See_Also: http://sigmakee.cvs.sourceforge.net/viewvc/sigmakee/sigma/suo-kif.pdf
 * See_Also: http://forum.dlang.org/post/prsxfcmkngfwomygmthi@forum.dlang.org
 *
 * TODO: Break out lexer and parser parts to to `nxt.`lexing and `nxt.parsing`
 *
 * TODO: Try infinite loops with break or goto instead of for loops.
 *
 * TODO: Should we add `LispFile.bySExpr` to allow use of `offsetTo` inside
 * `LispFileParser lfp; foreach (lfp.bySExpr)` now that copy-ctor is disabled
 * for `LispParser`?
 */
module nxt.lispy;

import nxt.path : FilePath, expandTilde, exists;

@safe:

/** Lisp-like token type. */
enum TOK {
	unknown,					///< Unknown.

	leftParen,				  ///< Left parenthesis.
	rightParen,				 ///< Right parenthesis.

	symbol,					 ///< Symbol.

	stringLiteral,			  ///< String literal.

	comma,					  ///< Lisp comma expression, `,`.
	backquote,				  ///< Lisp backquote expression, `\``.
	singlequote,				///< Lisp singlequote expression, `'`.

	variable,
	variableList, ///< one or more variables (parameters) starting with an at-sign, for instance `@ROW`
	functionName,

	number,					 ///< number as integer or floating point literal.

	comment,					///< Comment (to end of line).
	whitespace,				 ///< Whitespace.

	emptyList,				  ///< Empty list.
}

/** Lisp-like token. */
struct Token
{
	this(TOK tok, const(char)[] src = null) pure nothrow @safe @nogc {
		this.tok = tok;
		this.src = src;
	}

	@property final void toString(Sink)(ref scope Sink sink) const @safe {
		switch (tok) {
		case TOK.symbol:
			sink(src);
			break;
		case TOK.comma:
			sink(`,`);
			break;
		case TOK.backquote:
			sink("`");
			break;
		case TOK.singlequote:
			sink("'");
			break;
		case TOK.stringLiteral:
			sink(`"`);
			sink(src);
			sink(`"`);
			break;
		case TOK.emptyList:
			sink(`()`);
			break;
		default:
			// import std.conv : to;
			// sink(tok.to!string);
			if (src)
			{
				// sink(`:`);
				sink(src);
			}
			break;
		}
	}

	TOK tok;
	const(char)[] src;		  // optional source slice
}

/** Lisp-like S-expression. */
struct SExpr {
	final void toString(Sink)(ref scope Sink sink) const @safe @property {
		if (subs) { sink(`(`); }

		token.toString(sink);

		TOK lastTok = TOK.unknown;
		foreach (const ref sub; subs) {
			import std.algorithm.comparison : among;
			if (!lastTok.among!(TOK.comma,
								TOK.backquote,
								TOK.singlequote))
				sink(` `);
			sub.toString(sink);
			lastTok = sub.token.tok;
		}

		if (subs) { sink(`)`); }
	}

	/* This overload is needed in order for `Sexpr.init.to!string` to be @safe pure, I
	 * don’t know why. Perhaps because of incomplete attribute inference in compiler. */
	final string toString() const @property @safe pure {
		import std.conv : to;
		return this.to!(typeof(return));
	}

	Token token;
	SExpr[] subs;
}

/** Parse from `input` into lazy range over top-level expressions (`SExpr`).
 *
 * See_Also: https://forum.dlang.org/post/okqdldjnoyrtuizevqeo@forum.dlang.org
 */
struct LispParser			   /+ TODO: convert to `class` +/
{
	import std.algorithm.comparison : among;

	alias Input = const(char)[];

	struct Config {
		uint subExprCountsGuess = 0;
		bool includeComments;	 /+ TODO: use bitfield +/
		bool includeWhitespace;	 /+ TODO: use bitfield +/
		bool disallowEmptyLists; /+ TODO: use bitfield +/
	}

@safe pure:

	/** Parse `input` into returned array of expressions (`SExpr`).
	 */
	this(Input input, Config config = Config.init) @trusted {
		_input = input;
		// if (subExprCountsGuess) // if guess use region
		// {
		//	 _subExprsStore = new SExpr[subExprCountsGuess]; // region store
		// }
		import std.exception : enforce;
		import nxt.parsing : isNullTerminated;
		enforce(_input.isNullTerminated, "Input isn't null-terminated"); // input cannot be trusted
		_config = config;
		nextFront();
	}

	this(this) @disable;

	pragma(inline, true)
	bool empty() @property const nothrow scope @nogc => _endOfFile;

	pragma(inline, true)
	ref const(SExpr) front() @property const scope return in(!empty) => _topExprs.back;

	pragma(inline, true)
	void popFront() in(!empty) {
		_topExprs.popBack();
		nextFront();
	}

	@property size_t subExprsCount() const pure nothrow @safe @nogc => _subExprsCount;

	import std.meta : AliasSeq;

	// from std.ascii.isWhite
	alias endOfLineChars = AliasSeq!('\n', // (0x0a)
									 '\r', // (0x0c)
		);
	alias whiteChars = AliasSeq!(' ', // 0x20
								 '\t', // (0x09)
								 '\n', // (0x0a)
								 '\v', // (0x0b)
								 '\r', // (0x0c)
								 '\f' // (0x0d)
		);
	alias digitChars = AliasSeq!('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');

private:

	/// Get next `dchar` in input.
	pragma(inline, true)
	dchar peekNext() const scope nothrow @nogc
		=> _input[_offset]; /+ TODO: .ptr. TODO: decode `dchar` +/

	/// Get next `dchar` in input.
	pragma(inline, true)
	dchar peekNextNth(size_t n) const scope nothrow @nogc
		=> _input[_offset + n]; /+ TODO: .ptr. TODO: decode `dchar` +/

	/// Get next n `chars` in input.
	pragma(inline, true)
	Input peekNextsN(size_t n) const return scope nothrow @nogc
		=> _input[_offset .. _offset + n]; /+ TODO: .ptr +/

	/// Drop next byte in input.
	pragma(inline, true)
	void dropFront() scope nothrow @nogc { _offset += 1; }

	/// Drop next `n` bytes in input.
	pragma(inline, true)
	void dropFrontN(size_t n) scope nothrow @nogc { _offset += n; }

	/// Skip over `n` bytes in input.
	pragma(inline, true)
	Input skipOverN(size_t n) return scope nothrow @nogc {
		const part = _input[_offset .. _offset + n]; /+ TODO: .ptr +/
		dropFrontN(n);
		return part;
	}

	/// Skip line comment.
	void skipLineComment() scope nothrow @nogc {
		while (!peekNext().among!('\0', endOfLineChars))
			_offset += 1;
	}

	/// Get symbol.
	Input getSymbol() return nothrow @nogc {
		size_t i = 0;
		while ((!peekNextNth(i).among!('\0', '(', ')', '"', whiteChars))) // NOTE this is faster than !src[i].isWhite
			++i;
		return skipOverN(i);
	}

	/// Get numeric literal (number) in integer or decimal form.
	Input getNumberOrSymbol(out bool gotSymbol) return nothrow @nogc {
		size_t i = 0;
		while ((peekNextNth(i).among!('+', '-', '.', digitChars))) // NOTE this is faster than !src[i].isWhite
			++i;
		import std.ascii : isAlpha;
		if (peekNextNth(i).isAlpha) // if followed by letter
		{
			size_t alphaCount = 0;
			while ((!peekNextNth(i).among!('\0', '(', ')', '"', whiteChars))) // NOTE this is faster than !src[i].isWhite
			{
				alphaCount += peekNextNth(i).isAlpha;
				++i;
			}
			gotSymbol = alphaCount >= 2; // at least two letters, excluding floating point such as 1.0e+10
		}

		return skipOverN(i);
	}

	/// Get whitespace.
	Input getWhitespace() return nothrow @nogc {
		size_t i = 0;
		while (peekNextNth(i).among!(whiteChars)) // NOTE this is faster than `src[i].isWhite`
			++i;
		return skipOverN(i);
	}

	/// Get string literal in input.
	Input getStringLiteral() return nothrow @nogc {
		dropFront();
		size_t i = 0;
		while (!peekNextNth(i).among!('\0', '"'))
		{
			if (peekNextNth(i) == '\\' &&
				peekNextNth(i + 1) == '"')
			{
				i += 2;		 // skip \n
				continue;
			}
			++i;
		}
		const literal = peekNextsN(i);
		dropFrontN(i);
		if (peekNext() == '"') { dropFront(); } // pop ending double singlequote
		return literal;
	}

	SExpr[] dupTopExprs(scope SExpr[] exprs) scope @safe pure nothrow {
		pragma(inline, true);
		_subExprsCount += exprs.length; // log it for future optimizations
		return exprs.dup; /+ TODO: use region allocator stored locally in `LispParser` +/
	}

	void nextFront() {
		import std.range.primitives : empty, front, popFront, popFrontN;
		import std.uni : isWhite, isAlpha;
		import std.ascii : isDigit;

		while (true) {
			switch (_input[_offset]) /+ TODO: .ptr +/
			{
			case ';':
				if (_config.includeComments) {
					assert(0, "TODO: don't use skipLineComment");
					// _topExprs.insertBack(SExpr(Token(TOK.comment, src[0 .. 1])));
				}
				else
					skipLineComment();
				break;
			case '(':
				_topExprs.insertBack(SExpr(Token(TOK.leftParen, peekNextsN(1))));
				dropFront();
				++_depth;
				break;
			case ')':
				// NOTE: this is not needed: _topExprs.insertBack(SExpr(Token(TOK.rightParen, src[0 .. 1])));
				dropFront();
				--_depth;
				// NOTE: this is not needed: _topExprs.popBack();   // pop right paren

				assert(!_topExprs.empty);

				/+ TODO: retroIndexOf +/
				size_t count; // number of elements between parens
				while (_topExprs[$ - 1 - count].token.tok != TOK.leftParen)
					++count;
				if (_config.disallowEmptyLists)
					assert(count != 0);

				import core.lifetime : move;
				SExpr newExpr = ((count == 0) ?
								 SExpr(Token(TOK.emptyList)) :
								 SExpr(_topExprs[$ - count].token,
									   dupTopExprs(_topExprs[$ - count + 1 .. $])));
				_topExprs.popBackN(1 + count); // forget tokens including leftParen
				_topExprs.insertBack(newExpr.move);

				if (_depth == 0) {				   // top-level expression done
					assert(_topExprs.length >= 1); // we should have at least one `SExpr`
					return;
				}

				break;
			case '"':
				const stringLiteral = getStringLiteral(); /+ TODO: tokenize +/
				() @trusted {
					_topExprs.insertBack(SExpr(Token(TOK.stringLiteral, stringLiteral)));
				}();
				break;
			case ',':
				dropFront();
				_topExprs.insertBack(SExpr(Token(TOK.comma)));
				break;
			case '`':
				dropFront();
				_topExprs.insertBack(SExpr(Token(TOK.backquote)));
				break;
			case '\'':
				dropFront();
				_topExprs.insertBack(SExpr(Token(TOK.singlequote)));
				break;
			case '?':
				dropFront();
				const variableSymbol = getSymbol();
				() @trusted {
					_topExprs.insertBack(SExpr(Token(TOK.variable, variableSymbol)));
				}();
				break;
			case '@':
				dropFront();
				const variableListSymbol = getSymbol();
				() @trusted {
					_topExprs.insertBack(SExpr(Token(TOK.variableList, variableListSymbol)));
				}();
				break;
				// std.ascii.isDigit:
			case '0':
				..
			case '9':
			case '+':
			case '-':
			case '.':
				bool gotSymbol;
				const numberOrSymbol = getNumberOrSymbol(gotSymbol);
				if (gotSymbol) {
					// debug writeln("TODO: handle floating point: ", numberOrSymbol);
					() @trusted {
						_topExprs.insertBack(SExpr(Token(TOK.symbol, numberOrSymbol)));
					}();
				} else {
					() @trusted {
						_topExprs.insertBack(SExpr(Token(TOK.number, numberOrSymbol)));
					}();
				}
				break;
				// from std.ascii.isWhite
			case ' ':
			case '\t':
			case '\n':
			case '\v':
			case '\r':
			case '\f':
				assert(peekNext.isWhite);
				getWhitespace();
				if (_config.includeWhitespace)
					_topExprs.insertBack(SExpr(Token(TOK.whitespace, null)));
				break;
			case '\0':
				assert(_depth == 0, "Unbalanced parenthesis at end of file");
				_endOfFile = true;
				return;
			default:
				// other
				if (true// src.front.isAlpha
					)
				{
					const symbol = getSymbol(); /+ TODO: tokenize +/
					import nxt.algorithm.searching : endsWith;
					if (symbol.endsWith(`Fn`)) {
						() @trusted {
							_topExprs.insertBack(SExpr(Token(TOK.functionName, symbol)));
						}();
					} else {
						() @trusted {
							_topExprs.insertBack(SExpr(Token(TOK.symbol, symbol)));
						}();
					}
				}
				else
				{
					import std.conv : to;
					assert(false,
						   `Cannot handle character '` ~ peekNext.to!string ~
						   `' at charater offset:` ~ _offset.to!string);
				}
				break;
			}
		}
	}

	public ptrdiff_t offsetTo(scope const char[] expr) const @trusted pure nothrow @nogc
		=> expr.ptr - _input.ptr;

	import nxt.line_column : LineColumn, scanLineColumnToOffset;
	import nxt.offset : Offset;

	public LineColumn offsetToLineColumn(size_t offset) const @trusted pure nothrow @nogc
		=> scanLineColumnToOffset(_input, Offset(offset));

	public LineColumn sexprToLineColumn(scope const SExpr sexpr) const @trusted pure nothrow @nogc
		=> scanLineColumnToOffset(_input, Offset(offsetTo(sexpr.token.src)));

	public LineColumn charsToLineColumn(scope const(char)[] chars) const @trusted pure nothrow @nogc
		=> scanLineColumnToOffset(_input, Offset(offsetTo(chars)));

private:
	size_t _offset;			 // current offset in `_input`
	const Input _input;		 // input

	import nxt.container.static_array : StaticArray;
	// import nxt.container.dynamic_array : DynamicArray;
	alias TopExprs = StaticArray!(SExpr, 1024);
	TopExprs _topExprs;		   // top s-expressions (stack)
	size_t _subExprsCount;

	// SExpr[] _subExprsStore;	 // sub s-expressions (region)
	// size_t _subExprsOffset = 0; // offset into `_subExprsStore`

	size_t _depth;			  // parenthesis depth
	bool _endOfFile;			// signals null terminator found
	Config _config;
}

///
pure @safe unittest {
	const text = ";;a comment\n(instance AttrFn BinaryFunction);;another comment\0";
	auto parser = LispParser(text);
	assert(!parser.empty);

	assert(parser.front.token.tok == TOK.symbol);
	assert(parser.front.token.src == `instance`);

	assert(parser.front.subs[0].token.tok == TOK.functionName);
	assert(parser.front.subs[0].token.src == "AttrFn");

	assert(parser.front.subs[1].token.tok == TOK.symbol);
	assert(parser.front.subs[1].token.src == "BinaryFunction");

	parser.popFront();
	assert(parser.empty);

}

///
pure @safe unittest {
	const text = ";;a comment\n(instance AttrFn BinaryFunction);;another comment\0";
	auto parser = LispParser(text);
	import std.conv : to;
	assert(parser.front.to!string == `(instance AttrFn BinaryFunction)`);
	assert(!parser.empty);
}

/** Parse the contents of `file` into lazy range over top-level expressions (`SExpr`).
 *
 * See_Also: https://forum.dlang.org/post/okqdldjnoyrtuizevqeo@forum.dlang.org
 */
struct LispFileParser		   /+ TODO: convert to `class` +/
{
	import nxt.path : FilePath, expandTilde;
@safe:
	this(FilePath file) {
		const size_t subExprsCount = 0;
		/+ TODO: lookup `subExprsCount` using `file` extended attr or hash and pass to constructor +/
		import nxt.file : rawReadZ;
		const data = cast(LispParser.Input)rawReadZ(file.expandTilde); // cast to Input because we don't want to keep all file around:
		parser = LispParser(data, LispParser.Config(subExprsCount));
	}
	~this() nothrow @nogc {
		/+ TODO: write parser.subExprsCount +/
	}
	LispParser parser;
	ptrdiff_t offsetTo(scope const char[] expr) const pure nothrow @safe @nogc => parser.offsetTo(expr);
	alias parser this;
}

/// Optional integration test if path exists.
@safe unittest {
	const path = FilePath(`~/Work/knet/knowledge/xlg.el`);
	if (path.exists) {
		auto parser = LispFileParser(path);
		assert(!parser.empty);
	}
}
