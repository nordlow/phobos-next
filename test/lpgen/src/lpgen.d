/** Lexer/Parser Generator currently supporting for ANTLR (G, G2, G4) and (E)BNF grammars.

	See_Also: https://theantlrguy.atlassian.net/wiki/spaces/ANTLR3/pages/2687036/ANTLR+Cheat+Sheet
	See_Also: https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_form
	See_Also: https://github.com/antlr/grammars-v4
	See_Also: https://github.com/antlr/grammars-v4/blob/master/bnf/bnf.g4
	See_Also: https://stackoverflow.com/questions/53245751/convert-a-form-of-bnf-grammar-to-g4-grammar
	See_Also: https://bnfc.digitalgrammars.com/
	See_Also: https://forum.dlang.org/post/rsmlqfwowpnggwyuibok@forum.dlang.org
	See_Also: https://www.regular-expressions.info/unicode.html
	See_Also: https://stackoverflow.com/questions/64654430/meaning-of-plu-in-antlr-grammar/64658336#64658336
	See_Also: https://stackoverflow.com/questions/28829049/antlr4-any-difference-between-import-and-tokenvocab
	See_Also: https://github.com/antlr/antlr4/blob/master/doc/grammars.md
	See_Also: https://github.com/antlr/antlr4/tree/master/doc
	See_Also: https://slebok.github.io/zoo/index.html

	TODO:

	- TODO: Merge with nxt/pattern.d `Node classes`

	- Map switch case ranges sets to std.ascii/utf.isAlpha/AlphaNum when
	  possible as they have optimized implementations such as
	  https://github.com/dlang/phobos/pull/8588

	- Use `FreeList` over `Region` over `GCAllocator` in `DynamicArray`’s and
	  use a single region per grammar file parsed. Use `PAGESIZE` as
	  `Region`. Ask on the forums for a suitable allocator for this.

	- (lexer) nodes corresponding to fixed length string addresses doesn’t
	  require a length property so only stored start byte offset in that case
	  instead of `Input`. This saves one word.

	- SHARCParser.g4 should be processed after SHARCLexer.g4 to avoid error when
	  reading SHARCParser.g4 and warnings when reading SHARCLexer.g4: Diagnostics:
	  - grammars-v4/sharc/SHARCParser.g4(89,49): Warning: undefined, `StringLiteral` (symbol) at byte offset 1518
	  - grammars-v4/sharc/SHARCLexer.g4(6,1): Warning: unused (lexical) lexer token rule, `StringLiteral` (symbol) at byte offset 38

	- Add Syntax Tree Nodes as structs with members being sub-nodes. Composition
	  over inheritance. If we use structs over classes more languages, such as
	  Vox, can be supported in the code generation phase. Optionally use
	  extern(C++) classes. Sub-node pointers should be defined as unique
	  pointers with deterministic destruction.

 	- Support parsing of BNF and EBNF
	  - comma operator `,`: concatenation (sequence) which is implicit in ANTLR
	  - `[...]`: optional instead of ANTLRs [a-zA-Z_]
	  - Use from tree-sitter to EBNF converted grammars in https://github.com/mingodad/plgh as tests
	  - Use the EBNF D grammar https://github.com/gdamore/tree-sitter-d/issues/17 as sample input to a parser unittest

 	- Support parsing of BNF and EBNF and extensions to it used in the Python
	  grammar https://docs.python.org/3/reference/grammar.html like
	  - PosLA: positive look-ahead operator `&`
	  - NegLA: negative look-ahead operator `!`

	- Generate C code (including case ranges) and compile and load dynamically using TCC tcc. See `version (useTCC)`.

	- Use import std.algorithm.searching : commonPrefix; in alternatives and call it commonPrefixLiteral

	- Should be allowed instead of warning:
	grammars-v4/lua/Lua.g4(329,5): Warning: missing left-hand side, token (leftParen) at byte offset 5967

	- Parallelize grammar parsing and generation of parser files using https://dlang.org/phobos/std_parallelism.html#.parallel
	  After that compilation of parser files should grouped into CPU-count number of groups.

	- Use: https://forum.dlang.org/post/zcvjwdetohmklaxriswk@forum.dlang.org

	- Rewriting (X+)? as X* in ANTLR grammars and `commit` to `grammars-v4`.
	  See https://stackoverflow.com/questions/64706408/rewriting-x-as-x-in-antlr-grammars

	- Add errors for missing symbols during code generation

	- Literal indexing:
	  - Add map from string literal to fixed-length (typically lexer) rule
	  - Warn about string literals, such as str(`...`), that are equal to tokens
		such `ELLIPSIS` in `Python3.g4`.

	- Make `Rule.root` be of type `Matcher` and make
	  - `dcharCountSpan` and
	  - `toMatchInSource`
	  members of `Matcher`.
	  - Remove `Symbol.toMatchInSource`

	- Support `tokens { INDENT_WS, DEDENT_WS, LINE_BREAK_WS }` to get
	  Python3.g4` with TOK.whitespaceIndent, whitespaceDedent, whitespaceLineBreak useWhitespaceClassesFlag
	  See: https://stackoverflow.com/questions/8642154/antlr-what-is-simpliest-way-to-realize-python-like-indent-depending-grammar

	- Unicode regular expressions.
	  Use https://www.regular-expressions.info/unicode.html
	  Use https://forum.dlang.org/post/rsmlqfwowpnggwyuibok@forum.dlang.org

	- Use to detect conflicting rules with `import` and `tokenVocab`

	- Use a region allocator on top of the GC to pre-allocate the nodes. Among
	copied from std.allocator or Vox. Maybe one region for each file. Calculate
	the region size from lexer statistics (number of operators, symbols and
	literals).

	- `not(...)`'s implementation needs to be adjusted. often used in conjunction with `altN`?

	- handle all TODO's in `makeRule`

	- Move parserSourceBegin to lpgen_rdbase.d

	- Use `TOK.tokenSpecOptions` in parsing. Ignored for now.

	- Essentially, Packrat parsing just means caching whether sub-expressions
	  match at the current position in the string when they are tested -- this
	  means that if the current attempt to fit the string into an expression
	  fails then attempts to fit other possible expressions can benefit from the
	  known pass/fail of subexpressions at the points in the string where they
	  have already been tested.

	- Deal with differences between `import` and `tokenVocab`.
	  See: https://stackoverflow.com/questions/28829049/antlr4-any-difference-between-import-and-tokenvocab

	- Add `Rule` in generated code that defines opApply for matching that overrides
	- Detect indirect mutual left-recursion by check if `Rule.lastOffset` (in
	  generated code) is same as current parser offset. Simple-way in generated
	  parsers: enters a rule again without offset change. Requires storing last
	  offset for each non-literal rule.
	  ** Last offset during parsing.
	  *
	  * Used to detect infinite recursion, `size_t.max` indicates no last offset
	  * yet defined for `this` rule. *
	  size_t lastOffset = size_t.max;

	- Warn about `options{greedy=false;}:` and advice to replace with non-greedy variants
	- Warn about `options{greedy=true;}:` being deprecated

	- Use `uint` as source byte offset for to save space.

	- Display column range for tokens in messages. Use `head.input.length`.
	  Requires updating FlyCheck.
	  See: `-fdiagnostics-print-source-range-info` at https://clang.llvm.org/docs/UsersManual.html.
	  See: https://clang.llvm.org/diagnostics.html
	  Use GNU-style formatting such as: fix-it:"test.c":{45:3-45:21}:"gtk_widget_show_all".

	- Use mixin to auto-generate definitions of `final override bool opEquals`

	- If performance is needed:
	- Avoid casts and instead compare against `head.tok` for `isA!NodeType`
	- use `RuleAltN(uint n)` in `makeAlt`
	- use `SeqN(uint n)` in `makeSeq`

	- Support reading parsers from [Grammar Zoom](https://slebok.github.io/zoo/index.html).
*/
module lpgen;

// version = show;
version = Do_Inline;
version = useTCC;

enum useStaticTempArrays = false; ///< Use fixed-size (statically allocated) sequence and alternative buffers.

import core.lifetime : move;
import core.stdc.stdio : putchar, printf;
import std.conv : to;
import std.algorithm.comparison : min, max;
import std.algorithm.iteration : map, joiner, substitute;
import std.array : array;
import std.file : tempDir;
import std.path;
import std.exception : enforce;
import std.range.primitives : isInputRange, ElementType;
import std.uni : isAlpha, isAlphaNum; /+ TODO: decode `dchar` +/

version (useTCC) import tcc;

// `d-deps.el` requires these to be at the top:
import nxt.path : FilePath, DirPath, FileName, expandTilde, buildPath, exists;
import nxt.line_column : scanLineColumnToOffset;
import nxt.container.static_array : StaticArray;
import nxt.container.dynamic_array : DynamicArray;
import nxt.file : rawReadZ;
import nxt.algorithm.searching : startsWith, endsWith, endsWithAmong, skipOver, skipOverBack, skipOverAround, canFind, indexOf, indexOfAmong;
import nxt.conv_ex : toDefaulted;
import std.stdio : File, stdout, write, writeln;
import nxt.debugio;

@safe:

alias Input = string;			  ///< Grammar input source.
alias Output = DynamicArray!(char, Mallocator); ///< Generated parser output source.
alias RulesByName = Rule[Input];  /+ TODO: use mir.string_map.StringMap +/
alias GxFileParserByModuleName = GxFileParser[string];

enum matcherFunctionNamePrefix = `m__`;

///< Token kind. TODO: make this a string type like with std.experimental.lexer
enum TOK
{
	none,

	unknown,					///< Unknown

	whitespace,				 ///< Whitespace

	symbol,					 ///< Symbol
	attributeSymbol,			///< Attribute Symbol (starting with `$`)
	actionSymbol,			   ///< Action Symbol (starting with `@`)

	number,					 ///< Number

	lineComment,				///< Single line comment
	blockComment,			   ///< Multi-line (block) comment

	leftParen,				  ///< Left parenthesis
	rightParen,				 ///< Right parenthesis

	action,					 ///< Code block

	brackets,				   ///< Alternatives within '[' ... ']'

	literal,					///< Text literal, single or double quoted

	colon,					  ///< Colon `:`
	semicolon,				  ///< Semicolon `;`
	hash,					   ///< Hash `#`
	labelAssignment,			///< Label assignment `=`
	listLabelAssignment,		///< List label assignment `+=`

	qmark,					  ///< Greedy optional or semantic predicate (`?`)
	qmarkQmark,				 ///< Non-Greedy optional (`??`)

	star,					   ///< Greedy zero or more (`*`)
	starQmark,				  ///< Non-Greedy Zero or more (`*?`)

	plus,					   ///< Greedy one or more (`+`)
	plusQmark,				  ///< Non-Greedy One or more (`+?`)

	pipe,					   ///< Alternative (`|`)
	tilde,					  ///< Match negation (`~`)
	lt,						 ///< `<`
	gt,						 ///< `>`
	comma,					  ///< `.`
	exclamation,				///< Exclude from AST (`!`)
	rootNode,				   ///< Root node (`^`)
	wildcard,				   ///< `.`
	dotdot,					 ///< `..`

	rewrite,					///< Rewrite rule (`->`)

	/** Syntactic predicate rule rewrite (`=>`).
	 *
	 * Wikipedia: A syntactic predicate specifies the syntactic validity of
	 * applying a production in a formal grammar and is analogous to a semantic
	 * predicate that specifies the semantic validity of applying a
	 * production. It is a simple and effective means of dramatically improving
	 * the recognition strength of an LL parser by providing arbitrary
	 * lookahead. In their original implementation, syntactic predicates had the
	 * form “( α )?” and could only appear on the left edge of a production.
	 * The required syntactic condition α could be any valid context-free
	 * grammar fragment.
	 *
	 * See_Also: https://en.wikipedia.org/wiki/Syntactic_predicate
	 * See_Also: https://wincent.com/wiki/ANTLR_predicates
	 */
	rewriteSyntacticPredicate,

	/** Token spec options:
		"<"
		id ASSIGN optionValue
		( SEMI id ASSIGN optionValue )*
		">"
		;
	*/
	tokenSpecOptions,

	_error,					 ///< Error token
}

/// Gx rule.
@safe struct Token
{
nothrow:
	this(in TOK tok, Input input = null) @nogc pure
	{
		this.tok = tok;
		this.input = input;
	}
	Input input;
	TOK tok;
}

static bool isSymbolStart(in dchar ch) pure nothrow @safe @nogc
	=> (ch.isAlpha || ch == '_' || ch == '$' || ch == '@');

/** Gx lexer for all version ANTLR grammsrs (`.g`, `.g2`, `.g4`).
 *
 * See_Also: `ANTLRv4Lexer.g4`
 */
@safe struct GxLexer
{
	import std.algorithm.comparison : among;

	this(const Input input,
		 FilePath path = null,
		 in bool includeComments = false,
		 in bool includeWhitespace = false)
	{
		_input = input;
		this.path = path;

		import nxt.parsing : isNullTerminated;
		enforce(_input.isNullTerminated, "Input isn't null-terminated"); // input cannot be trusted

		_includeComments = includeComments;
		_includeWhitespace = includeWhitespace;

		nextFront();
	}

	this(this) @disable;

	pragma(inline, true)
	{
		bool empty() const @property pure nothrow scope @nogc => _endOfFile;
		inout(Token) front() inout @property pure return scope nothrow @nogc in(!empty) => _token;
		void popFront() scope nothrow in(!empty) => nextFront();
	}

	void front_checked(in TOK tok, const scope Input msg = "") nothrow /+ TODO: @nogc +/
	{
		if (front.tok != tok)
			errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
	}

	void popFront_checked(in TOK tok, const scope Input msg) nothrow /+ TODO: @nogc +/
	{
		if (takeFront().tok != tok)
			errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
	}

	Token takeFront_checked(in TOK tok, const scope Input msg = "") return scope nothrow /+ TODO: @nogc +/
	{
		/+ TODO: instead use: return takeFront(); +/
		const result = front();
		popFront();
		if (result.tok != tok)
			errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
		return result;
	}

	Token takeFront() return scope nothrow
	{
		scope(exit) popFront();
		return front;
	}

	Token skipOverToken(in Token token) return scope nothrow
	{
		if (front == token)
			return takeFront();
		return typeof(return).init;
	}

	Token skipOverTOK(in TOK tok) return scope nothrow
	{
		if (front.tok == tok)
			return takeFront();
		return typeof(return).init;
	}

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

private:

	/// Peek next element in input.
	pragma(inline, true)
	dchar peek0() const pure scope nothrow @nogc @property
		=> _input[_offset]; /+ TODO: decode next `dchar` +/

	/// Peek next next element in input.
	pragma(inline, true)
	dchar peek1() const pure scope nothrow @nogc @property
		=> _input[_offset + 1]; /+ TODO: decode next `dchar` +/

	/// Peek `n`-th next `char` in input.
	pragma(inline, true)
	dchar peekN(in size_t n) const pure scope nothrow @nogc @property
		=> _input[_offset + n]; /+ TODO: decode next `dchar` +/

	/// Drop next element in input.
	pragma(inline, true)
	void drop1() pure scope nothrow @nogc
		=> cast(void)(_offset += 1); /+ TODO: drop next `dchar` +/

	/// Drop next `n` elements in input.
	pragma(inline, true)
	void dropN(in size_t n) pure scope nothrow @nogc
		=> cast(void)(_offset += n); /+ TODO: drop N next `dchar`s +/

	/// Skip over `n` elements in input.
	Input skipOverN(in size_t n) pure return scope nothrow @nogc
	{
		scope(exit) dropN(n);
		return _input[_offset .. _offset + n]; /+ TODO: decode `dchar` +/
	}

	/// Skip over next element in input.
	pragma(inline, true)
	Input skipOver1() pure return scope nothrow @nogc
		=> _input[_offset .. ++_offset]; /+ TODO: decode `dchar` +/

	/// Skip over next two elements in input.
	pragma(inline, true)
	Input skipOver2() pure return scope nothrow @nogc
		=> _input[_offset .. (_offset += 2)]; /+ TODO: decode `dchar` +/

	/// Skip over next three elements in input.
	pragma(inline, true)
	Input skipOver3() pure return scope nothrow @nogc
		=> _input[_offset .. (_offset += 3)]; /+ TODO: decode `dchar` +/

	/// Skip line comment.
	void skipLineComment() pure scope nothrow @nogc
	{
		while (!peek0().among!('\0', endOfLineChars))
			_offset += 1;	   /+ TODO: decode `dchar` +/
	}

	/// Skip line comment.
	Input getLineComment() pure return scope nothrow @nogc
	{
		size_t i;
		while (!peekN(i).among!('\0', endOfLineChars))
			i += 1;				/+ TODO: decode `dchar` +/
		return skipOverN(i);	/+ TODO: decode `dchar` +/
	}

	/// Skip block comment.
	void skipBlockComment() scope return nothrow
	{
		while (!peek0().among!('\0'))
		{
			if (peek0() == '*' &&
				peek1() == '/')
			{
				_offset += 2;
				return;
			}
			_offset += 1;
		}
		errorAtFront("unterminated block comment");
	}

	/// Pop next symbol.
	Input popSymbol() pure return scope nothrow @nogc @property
	{
		size_t i;
		const attributeFlag = peek0() == '@';
		if (peek0().isSymbolStart)
			i += 1;
		while (peekN(i).isAlphaNum ||
			   peekN(i) == '_' ||
			   (attributeFlag && // attribute name
				peekN(i) == ':')) // may include colon qualifier
			i += 1;

		// skip optional whitespace before label assignment
		auto j = i;
		while (peekN(j).among!(whiteChars)) // NOTE this is faster than `src[i].isWhite`
			j += 1;

		if (peekN(j) == '=')		 // label assignment
			return skipOverN(j + 1);
		else if (peekN(j) == '+' &&
				 peekN(j + 1) == '=') // list label assignment
			return skipOverN(j + 2);
		else
			return skipOverN(i);
	}

	/// Pop next number.
	Input popNumber() pure return scope nothrow @nogc
	{
		import std.ascii : isDigit;
		size_t i;
		while (peekN(i).isDigit)
			i += 1;
		return skipOverN(i);
	}

	/// Pop next whitespace.
	Input popWhitespace() pure return scope nothrow @nogc
	{
		size_t i;
		while (peekN(i).among!(whiteChars)) // NOTE this is faster than `src[i].isWhite`
			i += 1;
		return skipOverN(i);
	}

	bool skipOverEsc(ref size_t i) scope nothrow @nogc
	{
		if (peekN(i) == '\\')   /+ TODO: decode `dchar` +/
		{
			i += 1;
			if (peekN(i) == 'n')
				i += 1;			/+ TODO: convert to "\r" +/
			else if (peekN(i) == 't')
				i += 1;			/+ TODO: convert to "\t" +/
			else if (peekN(i) == 'r')
				i += 1;			/+ TODO: convert to ASCII "\r" +/
			else if (peekN(i) == ']')
				i += 1;			/+ TODO: convert to ASCII "]" +/
			else if (peekN(i) == 'u')
			{
				i += 1;
				import std.ascii : isDigit;
				while (peekN(i).isDigit)
					i += 1;
				/+ TODO: convert to `dchar` +/
			}
			else if (peekN(i) == '\0')
				errorAtOffset("unterminated escape sequence at end of file");
			else
				i += 1;
			return true;
		}
		return false;
	}

	Input getLiteral(dchar terminator)() return scope nothrow @nogc
	{
		size_t i = 1;
		while (!peekN(i).among!('\0', terminator))
			if (!skipOverEsc(i))
				i += 1;
		if (peekN(i) == '\0')
			errorAtOffset("unterminated string literal at end of file");
		return skipOverN(i + 1); // include terminator
	}

	Input getTokenSpecOptions() return scope nothrow @nogc
	{
		enum dchar terminator = '>';
		size_t i = 1;
		while (!peekN(i).among!('\0', terminator))
			i += 1;
		if (peekN(i) != terminator)
		{
			if (peekN(i) == '\0')
				errorAtOffset("unterminated string literal at end of file");
			else
				errorAtOffset("unterminated token spec option");
		}
		return skipOverN(i + 1); // include terminator '>'
	}

	Input getHooks() return scope nothrow @nogc
	{
		size_t i;
		while (!peekN(i).among!('\0', ']')) // may contain whitespace
			if (!skipOverEsc(i))
				i += 1;
		if (peekN(i) == ']') // skip ']'
			i += 1;
		return skipOverN(i);
	}

	Input getAction() return scope nothrow @nogc
	{
		size_t i;

		DynamicArray!(char, Mallocator) ds;   // delimiter stack

		bool inBlockComment;
		bool inLineComment;
		bool inChar;
		bool inString;

		const infoFlag = false;

		while (!peekN(i).among!('\0'))
		{
			// skip over all escape sequences in quoted
			if (inChar ||
				inString)
				while (skipOverEsc(i)) {}

			if (!inBlockComment &&
				!inLineComment &&
				!inChar &&
				!inString)
			{
				if (peekN(i) == '/' &&
					peekN(i + 1) == '/')
				{
					if (infoFlag) infoAtOffset("line comment start", i, ds[]);
					inLineComment = true;
					i += 2;
					continue;
				}
				else if (peekN(i) == '/' &&
						 peekN(i + 1) == '*')
				{
					if (infoFlag) infoAtOffset("block comment start", i, ds[]);
					inBlockComment = true;
					i += 2;
					continue;
				}
				else if (peekN(i) == '{')
				{
					if (infoFlag) infoAtOffset("brace open", i, ds[]);
					ds.put('{');
				}
				else if (peekN(i) == '}')
				{
					if (infoFlag) infoAtOffset("brace close", i, ds[]);
					if (ds.length != 0 &&
						ds.back != '{')
						errorAtOffset("unmatched", i);
					ds.popBack();
				}
				else if (peekN(i) == '[')
				{
					if (infoFlag) infoAtOffset("hook open", i, ds[]);
					ds.put('[');
				}
				else if (peekN(i) == ']')
				{
					if (infoFlag) infoAtOffset("hook close", i, ds[]);
					if (ds.length != 0 &&
						ds.back != '[')
						errorAtOffset("unmatched", i);
					ds.popBack();
				}
				else if (peekN(i) == '(')
				{
					if (infoFlag) infoAtOffset("paren open", i, ds[]);
					ds.put('(');
				}
				else if (peekN(i) == ')')
				{
					if (infoFlag) infoAtOffset("paren close", i, ds[]);
					if (ds.length != 0 &&
						ds.back != '(')
						errorAtOffset("unmatched", i);
					ds.popBack();
				}
			}

			// block comment close
			if (inBlockComment &&
				peekN(i) == '*' &&
				peekN(i + 1) == '/')
			{
				if (infoFlag) infoAtOffset("block comment close", i, ds[]);
				inBlockComment = false;
				i += 2;
				continue;
			}

			// line comment close
			if (inLineComment &&
				(peekN(i) == '\n' ||
				 peekN(i) == '\r'))
			{
				if (infoFlag) infoAtOffset("line comment close", i, ds[]);
				inLineComment = false;
			}

			// single-quote open/close
			if (!inBlockComment &&
				!inLineComment &&
				!inString &&
				peekN(i) == '\'')
			{
				if (ds.length != 0 &&
					ds.back == '\'')
				{
					if (infoFlag) infoAtOffset("single-quote close", i, ds[]);
					ds.popBack();
					inChar = false;
				}
				else
				{
					if (infoFlag) infoAtOffset("single-quote open", i, ds[]);
					ds.put('\'');
					inChar = true;
				}
			}

			// double-quote open/close
			if (!inBlockComment &&
				!inLineComment &&
				!inChar &&
				peekN(i) == '"')
			{
				if (ds.length != 0 &&
					ds.back == '"')
				{
					if (infoFlag) infoAtOffset("double-quote close", i, ds[]);
					ds.popBack();
					inString = false;
				}
				else
				{
					if (infoFlag) infoAtOffset("doubl-quote open", i, ds[]);
					ds.put('"');
					inString = true;
				}
			}

			i += 1;

			if (ds.length == 0)
				break;
		}

		if (inBlockComment)
			errorAtOffset("unterminated block comment", i);
		if (ds.length != 0)
			errorAtOffset("unbalanced code block", i);

		return skipOverN(i);
	}

	void nextFront() scope return nothrow @trusted /+ TODO: remove `@trusted` +/
	{
		switch (peek0())
		{
		case '/':
			if (peek1() == '/') // `//`
			{
				_offset += 2;
				skipLineComment();
				if (_includeComments)
					_token = Token(TOK.lineComment);
				else
					nextFront();
			}
			else if (peek1() == '*') // `/*`
			{
				_offset += 2;
				skipBlockComment();
				if (_includeComments)
					_token = Token(TOK.blockComment);
				else
					return nextFront();
			}
			else
				errorAtOffset("unexpected character");
			break;
		case '(':
			_token = Token(TOK.leftParen, skipOver1());
			break;
		case ')':
			_token = Token(TOK.rightParen, skipOver1());
			break;
		case '{':
			_token = Token(TOK.action, getAction());
			break;
		case '[':
			_token = Token(TOK.brackets, getHooks());
			break;
		case '"':
			_token = Token(TOK.literal, getLiteral!('"')());
			break;
		case '\'':
			_token = Token(TOK.literal, getLiteral!('\'')());
			break;
		case ':':
			_token = Token(TOK.colon, skipOver1());
			break;
		case ';':
			_token = Token(TOK.semicolon, skipOver1());
			break;
		case '#':
			_token = Token(TOK.hash, skipOver1());
			break;
		case '=':
			if (peek1() == '>')
				_token = Token(TOK.rewriteSyntacticPredicate, skipOver2());
			else
				errorAtFront("expected '>' after '='");
			break;
		case '?':
			if (peek1() == '?')
				_token = Token(TOK.qmarkQmark, skipOver2());
			else
				_token = Token(TOK.qmark, skipOver1());
			break;
		case '*':
			if (peek1() == '?')
				_token = Token(TOK.starQmark, skipOver2());
			else
				_token = Token(TOK.star, skipOver1());
			break;
		case '+':
			if (peek1() == '=')
				_token = Token(TOK.listLabelAssignment, skipOver2());
			else if (peek1() == '?')
				_token = Token(TOK.plusQmark, skipOver2());
			else
				_token = Token(TOK.plus, skipOver1());
			break;
		case '|':
			_token = Token(TOK.pipe, skipOver1());
			break;
		case '~':
			_token = Token(TOK.tilde, skipOver1());
			break;
		case '<':
			_token = Token(TOK.tokenSpecOptions, getTokenSpecOptions());
			break;
		case ',':
			_token = Token(TOK.comma, skipOver1());
			break;
		case '!':
			_token = Token(TOK.exclamation, skipOver1());
			break;
		case '^':
			_token = Token(TOK.rootNode, skipOver1());
			break;
		case '.':
			if (peek1() == '.') // `..`
				_token = Token(TOK.dotdot, skipOver2());
			else
				_token = Token(TOK.wildcard, skipOver1());
			break;
		case '-':
			if (peek1() == '>') // `->`
				_token = Token(TOK.rewrite, skipOver2());
			else
				errorAtOffset("unexpected character");
			break;
		case '0':
			..
		case '9':
			_token = Token(TOK.number, popNumber());
			break;
		case ' ':
		case '\t':
		case '\n':
		case '\v':
		case '\r':
		case '\f':
			/+ TODO: extend to std.uni +/
			// import std.uni : isWhite;
			// assert(peek0().isWhite);
			const ws = popWhitespace();
			if (_includeWhitespace)
				_token = Token(TOK.whitespace, ws);
			else
				return nextFront();
			break;
		case '\0':
			_token = Token.init;
			_endOfFile = true;
			return;
		default:
			if (peek0().isSymbolStart)
			{
				const symbol = popSymbol();
				if (symbol.endsWith("+="))
				{
					if (_includeListLabelAssignment)
						_token = Token(TOK.listLabelAssignment, symbol);
					else
						return nextFront();
				}
				else if (symbol.endsWith('='))
				{
					if (_includeLabelAssignment)
						_token = Token(TOK.labelAssignment, symbol);
					else
						return nextFront();
				}
				else
					switch (symbol[0])
					{
					case '$':
						_token = Token(TOK.attributeSymbol, symbol);
						break;
					case '@':
						_token = Token(TOK.actionSymbol, symbol);
						break;
					default:
						_token = Token(TOK.symbol, symbol);
						break;
					}
			}
			else
			{
				_token = Token(TOK._error);
				errorAtOffset("unexpected character");
			}
		}
	}

	void infoAtFront(const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(front, "Info", msg);
	}

	void warningAtFront(const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(front, "Warning", msg);
	}

	void errorAtFront(const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(front, "Error", msg);
		assert(false);		  /+ TODO: construct Error Node instead +/
	}

	private void infoAtToken(const scope Token token,
							 const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(token, "Info", msg);
	}

	private void warningAtToken(const scope Token token,
								const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(token, "Warning", msg);
	}

	private void errorAtToken(const scope Token token,
							  const scope Input msg) const nothrow scope @nogc
	{
		messageAtToken(token, "Error", msg);
		assert(false);		  /+ TODO: construct Error Node instead +/
	}

	private void messageAtToken(const scope Token token,
								const scope string tag,
								const scope Input msg) const nothrow scope @nogc
	{
		ptrdiff_t offset;
		() @trusted {
			offset = (token.input.ptr && _input.ptr) ? token.input.ptr - _input.ptr : 0; // unsafe
		} ();
		import nxt.offset : Offset;
		const lc = _input.scanLineColumnToOffset(Offset(offset));
		import nxt.conv_ex : toDefaulted;
		const tokString = token.tok.toDefaulted!string("unknown");
		() @trusted {
			printf("%.*s(%u,%u): %s: %.*s, `%.*s` (%.*s) at byte offset %llu\n", // move this to a member
				   cast(int)path.str.length, path.str.ptr,
				   lc.line + 1, lc.column + 1,
				   tag.ptr,
				   cast(int)msg.length, msg.ptr,
				   cast(int)token.input.length, token.input.ptr,
				   cast(int)tokString.length, tokString.ptr,
				   offset);
		} ();
	}

	/+ TODO: into warning(const char* format...) like in `dmd` and put in `nxt.parsing` and reuse here and in lispy.d +/
	void errorAtOffset(const scope Input msg,
					   in size_t i = 0) const nothrow scope @nogc
	{
		messageAtOffset("Error", msg, i);
		assert(false);		  /+ TODO: construct Error Node instead +/
	}

	void warningAtOffset(const scope Input msg,
						 in size_t i = 0) const nothrow scope @nogc
	{
		messageAtOffset("Warning", msg, i);
	}

	void infoAtOffset(const scope Input msg,
					  in size_t i = 0, scope const(char)[] ds = null) const nothrow scope @nogc
	{
		messageAtOffset("Info", msg, i, ds);
	}

	void messageAtOffset(const scope string tag,
						 const scope Input msg,
						 in size_t i = 0,
						 scope const(char)[] ds = null) const @trusted nothrow @nogc scope
	{
		import nxt.offset : Offset;
		const lc = _input.scanLineColumnToOffset(Offset(_offset + i));
		/+ TODO: remove printf +/
		debug printf("%.*s(%u,%u): %s: %.*s at byte offset %llu being char `%c` ds:`%.*s`\n",
					 cast(int)path.str.length, path.str.ptr,
					 lc.line + 1, lc.column + 1,
					 tag.ptr,
					 cast(int)msg.length, msg.ptr,
					 _offset + i,
					 peekN(i),
					 cast(int)ds.length, ds.ptr);
	}

private:
	size_t _offset;			 // current offset in `_input`
	const Input _input;		 ///< Input data.
	FilePath path;		 ///< Input file (or null if in-memory).

	Token _token;
	bool _endOfFile;			// signals null terminator found
	bool _includeComments;
	bool _includeWhitespace;
	bool _includeLabelAssignment;
	bool _includeListLabelAssignment;
	bool _diagnoseLeftRecursion; ///< Diagnose left-recursion.
}

static assert(isInputRange!(GxLexer));
static assert(is(ElementType!GxLexer == Token));

/// Layou when printing AST (nodes).
enum Layout : ubyte
{
	source,					 ///< Try to mimic original source.
	tree						///< Makes AST-structure clear.
}

enum indentStep = 4;		///< Indentation size in number of spaces.

/// Format when printing AST (nodes).
@safe struct Format
{
	uint indentDepth;		   ///< Indentation depth.
	Layout layout;
	void showIndent() @safe const nothrow @nogc
	{
		showNSpaces(indentDepth);
	}
}

void showNSpaces(in uint indentDepth) @safe nothrow @nogc
{
	foreach (_; 0 .. indentDepth*indentStep)
		putchar(' ');
}

void showNSpaces(scope ref Output sink, in uint n) pure nothrow @safe @nogc
{
	foreach (_; 0 .. n)
		sink.put(" ");
}

void showNIndents(scope ref Output sink, in uint indentDepth) pure nothrow @safe @nogc
{
	foreach (_; 0 .. indentDepth*indentStep)
		sink.put(" ");
}

/// Put `x` formatted, indented at `indentDepth`.
void putFormatted(T)(scope ref Output sink, in uint indentDepth, T x) pure nothrow @safe @nogc
if (is(typeof(sink.put(x))))
{
	/+ TODO: generalize using fmt parameter +/
	foreach (_; 0 .. indentDepth*indentStep)
		sink.put(" ");
	sink.put(x);
}
/// ditto
alias fput = putFormatted;

private void showChars(in const(char)[] chars) @trusted
{
	printf("%.*s", cast(uint)chars.length, chars.ptr);
}

private void showToken(Token token, in Format fmt)
{
	fmt.showIndent();
	showChars(token.input);
}

/** Lower and upper limit of `dchar` count.
 */
@safe struct DcharCountSpan
{
pure nothrow:
	@disable this();	   // be explicit for now as default init is not obvious
	static typeof(this) start() @nogc
		=> typeof(this)(this.lower.min, this.upper.max);
	static typeof(this) full() @nogc
		=> typeof(this)(this.lower.min, this.upper.max);
	this(in uint lower, in uint upper) @nogc
	{
		this.lower = lower;
		this.upper = upper;
	}
	this(in size_t lower, in size_t upper) @nogc
	in(lower <= this.lower.max)
	in(upper <= this.upper.max)
	{
		this.lower = cast(typeof(this.lower))lower;
		this.upper = cast(typeof(this.upper))upper;
	}
	this(in uint length) @nogc
	{
		this(length, length);
	}
	this(in size_t length) @safe nothrow @nogc
	{
		this(length, length);
	}
	uint lower = uint.max;
	uint upper = 0;
}

/// AST node.
private abstract class Node
{
	abstract void show(in Format fmt = Format.init) const;
nothrow:
	abstract bool equals(const Node o) const pure @nogc;
	abstract void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc;
	this() pure @nogc {}
}

import std.experimental.allocator.mallocator : Mallocator;

alias NodeArray = DynamicArray!(Node, Mallocator); // `uint` capacity is enough
alias PatternArray = DynamicArray!(Pattern, Mallocator); // `uint` capacity is enough

bool equalsAll(const scope Node[] a,
			   const scope Node[] b) pure nothrow @nogc
{
	if (a.length != b.length)
		return false;
	foreach (const i; 0 .. a.length)
		if (!a[i].equals(b[i])) /+ TODO: use `.ptr` if needed +/
			return false;
	return true;
}

/// N-ary expression.
@safe abstract class NaryOpPattern : Pattern
{
@safe nothrow:
	this(Token head, PatternArray subs) pure @nogc
	{
		super(head);
		this.subs = subs.move(); /+ TODO: remove when compiler does this for us +/
	}
	override bool equals(const Node o) const @nogc
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return equalsAll(this.subs[], o_.subs[]);
		return false;
	}
	this(uint n)(Token head, Pattern[n] subs) @nogc if (n >= 2)
	{
		super(head);
		foreach (const Pattern sub; subs)
			this.subs.put(sub);
	}
	PatternArray subs;
}

/** Sequence.
 *
 * A `Sequence` is empty in case when a rule provides an empty alternative.
 * Such cases `() | ...` should be rewritten to `(...)?` in `makeAlt`.
 */
@safe final class SeqM : NaryOpPattern
{
	override void show(in Format fmt = Format.init) const
	{
		fmt.showIndent();
		foreach (const i, const sub; subs)
		{
			if (i)
				putchar(' ');
			sub.show();
		}
	}
nothrow:
	this(Token head) pure @nogc
	{
		super(head, PatternArray.init);
	}
	this(PatternArray subs) @nogc
	{
		super(Token.init, subs.move());
	}
	this(uint n)(Node[n] subs) if (n >= 2)
	{
		super(subs);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("seq(");
		foreach (const i, const sub; subs)
		{
			if (i)
				sink.put(", "); // separator
			sub.toMatchInSource(sink, parser);
		}
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(: ");
		foreach (const i, const sub; subs)
		{
			if (i)
				sink.put(", "); // separator
			sub.toString(sink);
		}
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	in(!subs.empty)
	{
		auto result = typeof(return)(0, uint.max);
		foreach (const sub; subs)
		{
			const sublr = sub.dcharCountSpan;
			if (result.lower == uint.max ||
				sublr.lower == uint.max)
				result.lower = uint.max;
			else
				result.lower += sublr.lower;
			if (result.upper == uint.max ||
				sublr.upper == uint.max)
				result.upper = uint.max;
			else
				result.upper += sublr.upper;
		}
		return result;
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
		{
			if (head.input == that_.head.input)
			{
				foreach (const index, const sub; subs)
					if (!sub.opEquals(that_.subs[index]))
						return false;
				return true;
			}
		}
		return false;
	}
}

Pattern makeSeq(PatternArray subs,
				const ref GxLexer lexer,
				in bool rewriteFlag = true) nothrow
{
	subs = flattenSubs!SeqM(subs.move());
	if (subs.length == 1)
		return subs[0];
	if (rewriteFlag)
	{
		foreach (const i, const sub; subs)
		{
			if (i + 1 == subs.length) // skip last
				break;
			if (const zom = cast(const GreedyZeroOrMore)subs[i + 1])
				if (zom.sub.equals(sub))
					lexer.warningAtToken(zom.head, "should be rewritten into `X+`");
		}
	}
	if (subs.length == 0)
		lexer.warningAtToken(Token(TOK.leftParen, lexer._input[0 .. 0]),
							 "empty sequence");
	return new SeqM(subs.move());
}

Pattern makeSeq(scope Pattern[] subs,
				const ref GxLexer lexer,
				in bool rewriteFlag = true) nothrow
{
	return makeSeq(PatternArray(subs), lexer, rewriteFlag);
}

Pattern makeSeq(scope Node[] subs,
				const ref GxLexer lexer,
				in bool rewriteFlag = true) nothrow
{
	return makeSeq(checkedCastSubs(subs, lexer), lexer, rewriteFlag);
}

private PatternArray checkedCastSubs(scope Node[] subs, const ref GxLexer lexer) nothrow @nogc
{
	import nxt.construction : makeOfLength;
	auto psubs = makeOfLength!(typeof(return))(subs.length);
	foreach (const i, sub; subs)
	{
		psubs[i] = cast(Pattern)sub;
		if (!psubs[i])
		{
			lexer.errorAtFront("non-`Pattern` sub");
			debug sub.show();
		}
	}
	return psubs;
}

PatternArray flattenSubs(BranchPattern)(PatternArray subs) pure nothrow @nogc
if (is(BranchPattern : SeqM) ||
	is(BranchPattern : AltM))
{
	typeof(subs) subs_;
	foreach (sub; subs)
		if (auto sub_ = cast(BranchPattern)sub)
			subs_.insertBack(flattenSubs!(BranchPattern)(sub_.subs.move()));
		else
			subs_.insertBack(sub);
	return subs_.move();
}

/// Rule.
@safe class Rule : Node
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
		showChars(":\n");
		if (root)
			root.show(Format(fmt.indentDepth + 1));
		showChars(" ;\n");
	}
nothrow:
	void diagnoseDirectLeftRecursion(const scope ref GxLexer lexer)
	{
		void checkLeft(const scope Pattern root) @safe nothrow
		{
			if (const alt = cast(const AltM)root) // common case
				foreach (const sub; alt.subs[]) // all alternatives
					checkLeft(sub);
			else if (const seq = cast(const SeqM)root)
				return checkLeft(seq.subs[0]); // only first in sequence
			else if (const s = cast(const SymbolRef)root)
				if (head.input == s.head.input)
					lexer.warningAtToken(s.head, "left-recursion");
		}
		checkLeft(root);
	}
	this(Token head, Pattern root, bool skipFlag) @nogc
	{
		this.head = head;
		this.root = root;
		this.skipFlag = skipFlag;
	}
	override bool equals(const Node o) const @nogc
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return head == o_.head && root.equals(o_.root);
		return false;
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		// dummy
	}
	void toMatcherInSource(scope ref Output sink, const scope GxParserByStatement parser) const
	{
		sink.fput(1, `Match `);
		if (head.input != "EOF")
			sink.put(matcherFunctionNamePrefix);
		sink.put(head.input); sink.put("()\n");
		sink.fput(1, "{\n");
		import std.ascii : isUpper;
		if (head.input[0].isUpper ||
			cast(const FragmentRule)this)
			sink.fput(2, "pragma(inline, true);\n");

		/// Try to generate switch statement.
		static Output trySwitch(in Pattern root)
		{
			typeof(return) result;
			if (const AltM alt = cast(const AltM)root)
			{
				foreach (const(Pattern) sub; alt.subs[])
				{
					if (const str = cast(const StringLiteral)sub)
					{
						if (str.head.input.length == 1)
						{
							result.fput(2, "case '");
							result.putCharLiteral(str.head.input[0 .. 1]);
							result.fput(2, "': return Match(off - off0);\n");
						}
						else
							return typeof(return).init;
					}
					else if (const ch = cast(const CharLiteral)sub)
					{
						result.fput(2, "case ");
						result.putCharLiteral(ch.head.input);
						result.put(": return Match(off - off0);\n");
					}
					else if (const range = cast(const Range)sub)
					{
						/+ TODO: do we need flattening of tree before this can be used?: +/
						const subChar0 = cast(const CharLiteral)range.subs[0];
						const subChar1 = cast(const CharLiteral)range.subs[1];
						// debug writeln(range.subs[0].head.input, " .. ", range.subs[1].head.input);
						if (subChar0 !is null &&
							subChar1 !is null)
						{
							result.fput(2, "case ");
							result.putCharLiteral(subChar0.head.input);
							result.put(": .. ");
							result.fput(0, "case ");
							result.putCharLiteral(subChar1.head.input);
							result.put(": ");
							result.put("return Match(off - off0);\n");
						}
						else
							return typeof(return).init;
					}
					else
					{
						return typeof(return).init;
					}
				}
			}
			if (result != typeof(return).init)
				result.fput(2, "default: off = off0; return Match.none();\n");
			return move(result);
		}

		const switchCode = trySwitch(root);
		if (switchCode.length != 0)
		{
			sink.fput(2, "const off0 = off;\n");
			sink.fput(2, "switch (popDchar())\n");
			sink.fput(2, "{\n");
			sink.fput(0, switchCode[]);
			sink.fput(2, "}\n");
		}
		else
		{
			sink.fput(2, `return`);
			if (root)
			{
				sink.put(` `);
				root.toMatchInSource(sink, parser);
			}
			else
				sink.put(` Match.none()`);
			sink.put(";\n");
		}
		sink.fput(1, "}\n");
	}
	@property bool isFragmentRule() const @nogc
	{
		return false;
	}
	/** Is a lexer (token) rule (beginning with a capital letter) defining a token type.
	 *
	 * A lexer rule name starts with an uppercase letter distinguishing it from
	 * a parser rule.
	 *
	 * See_Also: https://github.com/antlr/antlr4/blob/master/doc/lexer-rules.md#lexer-rule-elements
	 */
	@property final bool isLexerTokenRule() const @nogc
	{
		import std.ascii : isUpper;
		return (head.input.length &&
				head.input[0].isUpper);
	}
	const Token head;		   ///< Name.
	Pattern root;			   ///< Root pattern.
	/** Set to `true` if is referenced by a `SymbolRef`.
		Set in `GxParserByStatement.tagReferencedRules`
	*/
	bool hasRef = false;
	/** Rule is skipped (ignored). For instance
		WS : [\r\n]+ -> skip ;
	 */
	const bool skipFlag;
}

/** A reusable part of a lexer rule that doesn't match (a token) on its own.

	A consequence is that fragment rules matches are never stored as a separate
	parse tree nodes.

  For example:
  INTEGER: DIGIT+
		 | '0' [Xx] HEX_DIGIT+
		 ;
  fragment DIGIT: [0-9];
  fragment HEX_DIGIT: [0-9A-Fa-f];

  See_Also: https://sodocumentation.net/antlr/topic/3271/lexer-rules-in-v4#fragments
 */
@safe final class FragmentRule : Rule
{
nothrow:
	this(Token head, Pattern root, bool skipFlag) @nogc
	{
		super(head, root, skipFlag);
	}
	@property final override bool isFragmentRule() const @nogc
	{
		return true;
	}
}

@safe final class AltM : NaryOpPattern
{
	override void show(in Format fmt = Format.init) const
	{
		const wrapFlag = needsWrapping(subs[]);
		if (wrapFlag)
			putchar('(');
		showSubs(fmt);
		if (wrapFlag)
			putchar(')');
	}
	final void showSubs(in Format fmt) const
	{
		foreach (const i, const sub; subs)
		{
			sub.show(fmt);
			if (i + 1 != subs.length)
			{
				if (fmt.indentDepth)
					showChars(" |\n");
				else
					showChars(" | ");
			}
		}
	}
nothrow:
	this(Token head, PatternArray subs) @nogc
	in(subs.length != 0)
	{
		super(head, subs.move());
	}
	this(uint n)(Pattern[n] subs) @nogc if (n >= 2)
	{
		super(subs);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		// preprocess
		bool allSubChars = true; // true if all sub-patterns are characters
		foreach (const sub; subs)
		{
			if (const lit = cast(const StringLiteral)sub)
			{
				if (lit.head.input.length != 3) // non-character literal
				{
					allSubChars = false;
					break;
				}
			}
			else
			{
				allSubChars = false;
				break;
			}
		}

		// prefix
		if (allSubChars)
		{
			switch (subs.length)
			{
			case 2:
				sink.put("alt2!(");
				break;
			case 3:
				sink.put("alt3!(");
				break;
			case 4:
				sink.put("alt4!(");
				break;
			case 5:
				sink.put("alt5!(");
				break;
			default:
				sink.put("altN!(");
				break;
			}
		}
		else
			sink.put("alt(");

		// iterate subs
		foreach (const i, const sub; subs)
		{
			if (allSubChars)
			{
				if (i)
					sink.put(","); // separator
				const lsub = cast(const StringLiteral)sub;
				if (lsub.head.input == "'")
					sink.put(`\'`);
				else
					sink.put(lsub.head.input);
			}
			else
			{
				if (i)
				{
					sink.put(",\n");
					sink.showNIndents(2);
					sink.showNSpaces(11);
				}
				sub.toMatchInSource(sink, parser);
			}
		}

		// postfix
		sink.put(")");
		if (allSubChars)
			sink.put("()");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("AltM(");
		foreach (const i, const sub; subs)
		{
			if (i)
				sink.put(", "); // separator
			sub.toString(sink);
		}
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return dcharCountSpanOf(subs[]);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
		{
			if (head.input == that_.head.input)
			{
				foreach (const index, const sub; subs)
					if (!sub.opEquals(that_.subs[index]))
						return false;
				return true;
			}
		}
		return false;
	}
}

DcharCountSpan dcharCountSpanOf(const scope Pattern[] subs) pure nothrow @safe @nogc
{
	if (subs.length == 0)
		return typeof(return)(0, 0);
	auto result = typeof(return).start();
	foreach (const sub; subs)
	{
		const sublr = sub.dcharCountSpan;
		result.lower = min(result.lower, sublr.lower);
		result.upper = max(result.upper, sublr.upper);
	}
	return result;
}

Pattern makeAltA(Token head,
				 PatternArray subs,
				 in bool rewriteFlag = true) nothrow
{
	subs = flattenSubs!AltM(subs.move());
	switch (subs.length)
	{
	case 0:
		return null;
	case 1:
		return subs[0];
	default:
		return new AltM(head, subs.move());
	}
}

Pattern makeAltM(Token head,
				 Pattern[] subs,
				 in bool rewriteFlag = true) nothrow
{
	return makeAltA(head, PatternArray(subs), rewriteFlag);
}

Pattern makeAltN(uint n)(Token head,
						 Pattern[n] subs,
						 in bool rewriteFlag = true) nothrow
if (n >= 2)
{
	return makeAltA(head, PatternArray(subs), rewriteFlag);
}

@safe class TokenNode : Node
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head) pure @nogc
	{
		this.head = head;
	}
	override bool equals(const Node o) const pure @nogc
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return head == o_.head;
		return false;
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put(`tok(`);
		sink.put(head.input[]);
		sink.put(`)`);
	}
	const Token head;
}

/// Unary match combinator.
@safe abstract class UnaryOpPattern : Pattern
{
	final override void show(in Format fmt = Format.init) const
	{
		putchar('(');
		sub.show(fmt);
		putchar(')');
		showToken(head, fmt);
	}
nothrow:
	this(Token head, Pattern sub) @nogc
	in(head.input)
	in(sub)
	{
		super(head);
		this.sub = sub;
	}
	final override bool equals(const Node o) const
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return (head == o_.head &&
					this.sub.equals(o_.sub));
		return false;
	}
	Pattern sub;
}

/// Don't match an instance of type `sub`.
@safe final class NotPattern : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("not(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(not ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return sub.dcharCountSpan();
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return sub.opEquals(that_.sub);
		return false;
	}
}

/// Match (greedily) zero or one instances of type `sub`.
@safe final class GreedyZeroOrOne : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	this(Token head, Node sub) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("gzo(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(? ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(0, sub.dcharCountSpan.upper);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return sub.opEquals(that_.sub);
		return false;
	}
}

/// Match (greedily) zero or more instances of type `sub`.
@safe final class GreedyZeroOrMore : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	this(Token head, Node sub) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("gzm(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(* ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return).full();
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return sub.opEquals(that_.sub);
		return false;
	}
}

/// Match (greedily) one or more instances of type `sub`.
@safe final class GreedyOneOrMore : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	this(Token head, Node sub) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		if (!psub)
		{
			debug sub.show();
			assert(false);
		}
		super(head, psub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("gom(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(+ ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(sub.dcharCountSpan.lower,
							  typeof(return).upper.max);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return sub.opEquals(that_.sub);
		return false;
	}
}

@safe abstract class TerminatedUnaryOpPattern : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub, Pattern terminator = null) @nogc
	{
		debug assert(head.input.ptr);
		super(head, sub);
		this.terminator = terminator;
	}
	Pattern terminator;
}

/// Match (non-greedily) zero or one instances of type `sub`.
@safe final class NonGreedyZeroOrOne : TerminatedUnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub, Pattern terminator = null) @nogc
	{
		super(head, sub, terminator);
	}
	this(Token head, Node sub, Pattern terminator = null) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub, terminator);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("nzo(");
		sub.toMatchInSource(sink, parser);
		if (terminator)
		{
			sink.put(",");
			terminator.toMatchInSource(sink, parser);
		}
		else
			parser._lexer.warningAtToken(head, "no terminator after non-greedy");
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(?? ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(0, sub.dcharCountSpan.upper);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
		{
			return (sub.opEquals(that_.sub) &&
					terminator.opEquals(that_.terminator));
		}
		return false;
	}
}

/// Match (non-greedily) zero or more instances of type `sub`.
@safe final class NonGreedyZeroOrMore : TerminatedUnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub, Pattern terminator = null) @nogc
	in(head.input)
	{
		super(head, sub, terminator);
	}
	this(Token head, Node sub, Pattern terminator = null) @nogc
	in(head.input)
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub, terminator);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("nzm(");
		sub.toMatchInSource(sink, parser);
		debug assert(head.input.ptr);
		if (terminator)
		{
			sink.put(",");
			terminator.toMatchInSource(sink, parser);
		}
		else
			parser._lexer.warningAtToken(head, "no terminator after non-greedy");
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(*? ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return).full();
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
		{
			return (sub.opEquals(that_.sub) &&
					terminator.opEquals(that_.terminator));
		}
		return false;
	}
}

/// Match (non-greedily) one or more instances of type `sub`.
@safe final class NonGreedyOneOrMore : TerminatedUnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub, Pattern terminator = null) @nogc
	{
		super(head, sub, terminator);
	}
	this(Token head, Node sub, Pattern terminator = null) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub, terminator);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("nom(");
		sub.toMatchInSource(sink, parser);
		if (terminator)
		{
			sink.put(",");
			terminator.toMatchInSource(sink, parser);
		}
		else
			parser._lexer.warningAtToken(head, "no terminator after non-greedy");
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(+? ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(sub.dcharCountSpan.lower,
							  typeof(return).upper.max);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
		{
			return (sub.opEquals(that_.sub) &&
					terminator.opEquals(that_.terminator));
		}
		return false;
	}
}

/// Match `count` number of instances of type `sub`.
@safe final class GreedyCount : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	this(Token head, Node sub) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("cnt(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		const ss = sub.dcharCountSpan;
		return typeof(return)(ss.lower == ss.lower.max ? ss.lower.max : ss.lower * count,
							  ss.upper == ss.upper.max ? ss.upper.max : ss.upper * count);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return (count == that_.count &&
					sub.opEquals(that_.sub));
		return false;
	}
	ulong count;
}

@safe final class RewriteSyntacticPredicate : UnaryOpPattern
{
nothrow:
	this(Token head, Pattern sub) @nogc
	{
		super(head, sub);
	}
	this(Token head, Node sub) @nogc
	{
		Pattern psub = cast(Pattern)sub;
		assert(psub);
		super(head, psub);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("syn(");
		sub.toMatchInSource(sink, parser);
		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(syn ");
		sub.toString(sink);
		sink.put(")");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return sub.dcharCountSpan;
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return sub.opEquals(that_.sub);
		return false;
	}
}

@safe final class OtherSymbol : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		if (head.input != "EOF")
			sink.put(matcherFunctionNamePrefix);
		sink.put(head.input);
		sink.put(`()`);
	}
}

@safe final class SymbolRef : Pattern
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		if (head.input != "EOF")
			sink.put(matcherFunctionNamePrefix);
		sink.put(head.input);
		if (parser.warnUnknownSymbolFlag &&
			head.input !in parser.rulesByName)
			parser._lexer.warningAtToken(head, "No rule for symbol");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put(head.input);
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		assert(false);
		// return typeof(return).init;
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return head.input == that_.head.input;
		return false;
	}
}

@safe final class LeftParenSentinel : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class PipeSentinel : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class DotDotSentinel : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class TildeSentinel : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class AnyClass : Pattern
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put(`any()`);
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.put("(any)");
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(1);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return true;
		return false;
	}
}

private bool isASCIICharacterLiteral(Input x) pure nothrow @nogc
{
	return (x.length == 1 ||
			(x.length == 2 &&
			 x[0] == '\\')); // backquoted character
}

private uint isUnicodeCharacterLiteral(scope Input x) pure nothrow @nogc
{
	if (!x.skipOver('\\'))
		return 0;
	if (!(x.skipOver('u') ||
		  x.skipOver('U')))
		return 0;

	x.skipOverAround('{', '}'); // optional

	if (x.skipOver(`0x`) ||	 // optional
		x.skipOver(`0X`)) {}

	while (x.length &&
		   x[0] == '0')   // trim leading zero
		x = x[1 .. $];

	uint u;
	while (x.length)
	{
		u *= 16;
		import std.ascii : isDigit, isLower, isUpper;
		const c = x[0];
		if (c.isDigit)
			u += c - '0';
		else if (c.isUpper)
			u += c - 'A' + 10;
		else if (c.isLower)
			u += c - 'a' + 10;
		else
			return 0;		   // string literal such as '\uD835\uDD38'
		x = x[1 .. $];	  // pop front
	}

	return u;
}

@safe abstract class Pattern : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	abstract DcharCountSpan dcharCountSpan() const pure @nogc;
	abstract bool opEquals(const scope Pattern that) const @nogc;
	abstract void toString(scope ref Output sink) const @property @nogc;
}

bool isQuoted(const scope string x) @trusted pure nothrow @nogc
{
	const n = x.length;
	const endIndex = n - 1;
	return (n >= 2 &&
			((x.ptr[0] == '\'' &&
			  x.ptr[endIndex] == '\'') ||
			 (x.ptr[0] ==  '"' &&
			  x.ptr[endIndex] ==  '"')));
}

///
pure nothrow @safe @nogc unittest {
	assert( `"x"`.isQuoted);
	assert(!`"x`.isQuoted);
	assert(!`x"`.isQuoted);
	assert( `'x'`.isQuoted);
	assert(!`'x`.isQuoted);
	assert(!`x'`.isQuoted);
}

@safe final class StringLiteral : Pattern
{
nothrow:
	this(Token head) pure @nogc
		in(head.input.isQuoted)
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		auto inp = unquotedInput; // skipping single-quotes
		if (inp.isASCIICharacterLiteral())
		{
			if (useCall) { sink.put(`ch(`); }
			sink.putCharLiteral(inp);
			if (useCall) { sink.put(`)`); }
		}
		else if (const uvalue = inp.isUnicodeCharacterLiteral())
		{
			if (useCall)
			{
				if (uvalue <= 0x7f)
					sink.put(`ch(`);
				else
					sink.put(`dch(`);
			}
			sink.putCharLiteral(inp);
			if (useCall) { sink.put(`)`); }
		}
		else
		{
			if (inp.canFind('`'))
			{
				if (useCall) { sink.put(`str("`); }
				sink.putStringLiteralDoubleQuoted(inp);
				if (useCall) { sink.put(`")`); }
			}
			else
			{
				if (useCall) { sink.put("str(`"); }
				sink.putStringLiteralBackQuoted(inp);
				if (useCall) { sink.put("`)"); }
			}
		}
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		return toMatchInSource(sink, null, true);
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		const inp = unquotedInput; // skipping single-quotes
		size_t cnt;
		if (inp.isASCIICharacterLiteral()) // must come first
			cnt = 1;
		else if (const _ = inp.isUnicodeCharacterLiteral()) // must come second
			cnt = 1;
		else if (inp.isASCIIString) // must come third
			cnt = inp.length;
		else
		{
			/+ TODO: optimize +/
			import std.utf : byDchar;
			import std.algorithm.searching : count;
			cnt = inp.byDchar.count;
		}
		return typeof(return)(cnt);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return head.input == that_.head.input;
		return false;
	}
	Input unquotedInput() const pure scope return @nogc
	{
		return head.input[1 .. $ - 1];
	}
}

/+ TODO: avoid linker error when using version defined in `nxt.string_traits` +/
private bool isASCIIString(scope const(char)[] input) pure nothrow @nogc
{
	foreach (const e; cast(const(ubyte)[])input) // no decoding to `dchar` needed
		if (e >= 0x7F)
			return false;
	return true;
}

void putStringLiteralDoubleQuoted(scope ref Output sink,
								  const scope Input inp) pure nothrow @nogc
{
	for (size_t i; i < inp.length; ++i)
	{
		if (inp[i] == '"')
			sink.put(`\"`);	 // backslash doublequote in D string
		else if (i + 2 <= inp.length &&
				 inp[i .. i + 2] == `\'`)
		{
			i += 1;			 // one extra char
			sink.put('\'');
		}
		else
			sink.put(inp[i]);
	}
}

void putStringLiteralBackQuoted(scope ref Output sink,
								const scope Input inp) pure nothrow @nogc
{
	for (size_t i; i < inp.length; ++i)
	{
		if (inp[i] == '`')
			sink.put("\\`");	// backslash backquote in D raw string
		else if (inp[i] == '\\' &&
				 i + 1 < inp.length)
		{
			if (inp[i + 1] == '\\')
				sink.put('\\'); // strip quoting of backslash in D raw string
			else if (inp[i + 1] == '\'')
				sink.put('\''); // strip quoting of single-quote in D raw string
			else if (inp[i + 1] == '"')
				sink.put('"'); // strip quoting of double-quote in D raw string
			else
				sink.put(inp[i]);
			i += 1;			 // one extra char
		}
		else
			sink.put(inp[i]);
	}
}

@safe final class CharLiteral : Pattern
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		if (head.input.startsWith(`\p`) || // https://github.com/antlr/antlr4/pull/1688
			head.input.startsWith(`\P`))
		{
			sink.put(`cc!(`);   /+ TODO: don’t generate trySwitch for this case +/
		}
		else if (head.input.startsWith(`\u`) || // https://github.com/antlr/antlr4/pull/1688
				 head.input.startsWith(`\U`))
		{
			sink.put(`dch(`);
		}
		else if (head.input[0] >= 0x80)
		{
			sink.put(`dch(`);
		}
		else
		{
			const uvalue = head.input.isUnicodeCharacterLiteral();
			if (uvalue < 0x00)
				sink.put(`ch(`);
			else
				sink.put(`dch(`);
		}
		sink.putCharLiteral(head.input);
		sink.put(`)`);
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.putCharLiteral(head.input);
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return DcharCountSpan(1, 1);
		// if (head.input.isASCIICharacterLiteral)
		//	 return DcharCountSpan(1, 1);
		// else
		//	 return DcharCountSpan(0, uint.max);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return head.input == that_.head.input;
		return false;
	}
}

/** Character Class.
	See: https://github.com/antlr/antlr4/pull/1688
*/
@safe final class CharClass : Pattern
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
	override void toMatchInSource(scope ref Output sink,
								  const scope GxParserByStatement parser,
								  in bool useCall = true) const @nogc
	{
		sink.put(`cc!(`);
		sink.putCharLiteral(head.input);
		sink.put(`)`);
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		sink.putCharLiteral(head.input);
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return DcharCountSpan(1, 1);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return head.input == that_.head.input;
		return false;
	}
}

void putCharLiteral(scope ref Output sink,
					scope Input inp) pure nothrow @nogc
{
	if (inp.skipOver(`\u`) ||
		inp.skipOver(`\U`))
	{
		inp.skipOverAround('{', '}');

		// strip leading zeros
		while (inp.length > 2 &&
			   inp[0] == '0')
			inp = inp[1 .. $];

		if (inp.length == 2)	// if ASCII
		{
			sink.put(`'\u00`);
			sink.put(inp);
			sink.put('\'');
		}
		else
		{
			sink.put(`(cast(dchar)0x`); /+ TODO: use `dchar(...)` for valid numbers +/
			sink.put(inp);
			sink.put(`)`);
		}
	}
	else if (inp.skipOver(`\p`) || // https://github.com/antlr/antlr4/pull/1688
			 inp.skipOver(`\P`))
	{
		inp.skipOverAround('{', '}');
		sink.put('"');
		sink.put(inp);
		sink.put('"');
	}
	else
	{
		sink.put(`'`);
		if (inp.length == 1 &&
			(inp[0] == '\'' ||
			 inp[0] == '\\'))
			sink.put(`\`);	  // need backquoting
		sink.put(inp);
		sink.put(`'`);
	}
}

/** TODO: Returns either a `CharLiteral` or `CharClass` if starts with \p or \P
 * and specialize CharLiteral.toMatchInSource to not include
 */
Pattern makeLiteral(Token head) pure nothrow
in(head.input.length >= 1)			// "..." at least of length 3
{
	if (head.input.isASCIICharacterLiteral) /+ TODO: what’s this for? +/
		return new CharLiteral(head);
	else if (head.input.startsWith(`\p`) || // https://github.com/antlr/antlr4/pull/1688
			 head.input.startsWith(`\P`))
		return new CharClass(head);
	else if (head.input.startsWith(`\u`) ||
			 head.input.startsWith(`\U`))
		return new CharLiteral(head);
	else
		return new StringLiteral(head);
}

bool needsWrapping(const scope Node[] subs) pure nothrow @safe @nogc
{
	bool wrapFlag;
	foreach (const sub; subs)
		if (!cast(const TokenNode)sub)
			wrapFlag = true;
	return wrapFlag;
}

/// Binary pattern combinator.
@safe abstract class BinaryOpPattern : Pattern
{
	override void show(in Format fmt = Format.init) const
	{
		fmt.showIndent();
		subs[0].show(fmt);
		putchar(' ');
		showChars(head.input);
		putchar(' ');
		subs[1].show(fmt);
	}
nothrow:
	this(Token head, Pattern[2] subs) @nogc
	in(subs[0])
	in(subs[1])
	{
		super(head);
		this.subs = subs;
	}
	final override bool equals(const Node o) const @nogc
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return (head == o_.head &&
					equalsAll(this.subs[], o_.subs[]));
		return false;
	}
	Pattern[2] subs;
}

/// Match value range between `limits[0]` and `limits[1]`.
@safe final class Range : BinaryOpPattern
{
	override void show(in Format fmt = Format.init) const
	{
		const wrapFlag = needsWrapping(subs[]);
		fmt.showIndent();
		if (wrapFlag)
			putchar('(');
		subs[0].show(fmt);
		showChars(" .. ");
		subs[1].show(fmt);
		if (wrapFlag)
			putchar(')');
	}
nothrow:
	this(Token head, Pattern[2] limits) @nogc
	in(limits[0])
	in(limits[1])
	{
		super(head, limits);
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		sink.put("rng(");

		if (const lower = cast(const StringLiteral)subs[0])
			sink.putCharLiteral(lower.unquotedInput);
		else if (const lower = cast(const CharLiteral)subs[0])
			sink.putCharLiteral(lower.head.input);
		else
		{
			debug writeln("handle sub[0] of type ", typeid(subs[0]).name);
			debug subs[0].show();
			assert(false);
		}

		sink.put(",");

		if (const upper = cast(const StringLiteral)subs[1])
			sink.putCharLiteral(upper.unquotedInput);
		else if (const upper = cast(const CharLiteral)subs[1])
			sink.putCharLiteral(upper.head.input);
		else
			assert(false);

		sink.put(")");
	}
	override void toString(scope ref Output sink) const @property @nogc
	{
		subs[0].toString(sink);
		sink.put("...");
		subs[1].toString(sink);
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return dcharCountSpanOf(subs[]);
	}
	final override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return (head.input == that_.head.input &&
					subs[0].opEquals(that_.subs[0]) &&
					subs[1].opEquals(that_.subs[1]));
		return false;
	}
 }

Pattern parseCharAltM(const CharAltM alt,
					  const scope ref GxLexer lexer) @safe nothrow
{
	const Input inp = alt.unquotedInput;

	bool inRange;
	PatternArray subs;
	for (size_t i; i < inp.length;)
	{
		Input inpi;

		if (inp[i] == '-' &&
			subs.length != 0)		// not first character
		{
			inRange = true;
			i += 1;
			continue;
		}

		if (inp[i] == '\\')
		{
			i += 1;			 // skip '\\'
			switch (inp[i])
			{
			case ']':
			case '-':
			case '\\':
				inpi = inp[i .. i + 1];
				break;
			case 'p':
				if (inp[i + 1] != '{')
					lexer.errorAtToken(Token(alt.head.tok, inp[i + 1 .. $]),
									   "expected brace");
				const hit = inp[i + 1 .. $].indexOf('}');
				if (hit >= 0)
				{
					inpi = inp[i - 1 .. i + 1 + hit + 1];
					i += hit + 1;
				}
				else
					lexer.errorAtToken(Token(alt.head.tok, inp[i + 1 .. $]),
									   "incorrect unicode escape sequence, missing matching closing brace '}'");
				break;
			case 'u':
				if (inp[i + 1] == '{')
				{
					const hit = inp[i + 1 .. $].indexOf('}');
					if (hit >= 0)
					{
						inpi = inp[i - 1 .. i + 1 + hit + 1];
						i += hit + 1;
					}
					else
						lexer.errorAtToken(Token(alt.head.tok, inp[i + 1 .. $]),
										   "incorrect unicode escape sequence, missing matching closing brace '}'");
				}
				else
				{
					/* Unicode code point `\u....` where `....` is the hexadecimal
					   number of the code point you want to match. */
					import std.ascii : isHexDigit;
					if (i + 5 > inp.length &&
						!(inp[i + 1].isHexDigit &&
						  inp[i + 2].isHexDigit &&
						  inp[i + 3].isHexDigit &&
						  inp[i + 4].isHexDigit))
						lexer.errorAtToken(Token(alt.head.tok, inp[i + 1 .. $]),
										   "incorrect unicode escape sequence");
					inpi = inp[i - 1 .. i + 5];
					i += 4;
				}
				break;
			default:
				inpi = inp[i - 1 .. i + 1];
				break;
			}
			i += 1;
		}
		else if (inp[i] >= 0x80)
		{
			import std.typecons : Yes;
			import std.utf : decode;
			const replacementChar = cast(dchar)0x110000;
			const i0 = i;
			const ch = decode!(Yes.useReplacementDchar)(inp, i);
			if (ch == replacementChar)
				lexer.errorAtToken(alt.head, "invalid UTF-sequence `" ~ inp[i0 .. $] ~ "`");
			inpi = inp[i0 .. i];
		}
		else
			inpi = inp[i .. ++i];

		auto lit = makeLiteral(Token(TOK.literal, inpi)); /+ TODO: this call should include quotes for the StringLiteral case +/
		if (inRange)
			subs.insertBack(new Range(Token.init, [subs.takeBack(), lit]));
		else
			subs.insertBack(lit);
		inRange = false;
	}
	return makeAltA(alt.head, subs.move()); // potentially flatten
}

@safe final class CharAltM : Pattern
{
nothrow:

	this(Token head) pure @nogc
	{
		super(head);
	}

	Input unquotedInput() const @nogc
	{
		Input inp = head.input;
		assert(inp.skipOverAround('[', ']')); // trim
		return inp;
	}

	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
		Input inp = unquotedInput;

		// TODO use `switch` `case` ranges

		if (inp.canFind('-')) // check that range is not backquoted
		{
			size_t altCount;
			const asink = toMatchRangeInSource(inp, altCount);
			if (altCount >= 2)
				sink.put("alt(");
			sink.put(asink[]);
			if (altCount >= 2)
				sink.put(")");
			return;
		}

		sink.put("altN!(");
		for (size_t i; i < inp.length;)
		{
			if (i)
				sink.put(", "); // separator

			sink.put('\'');	 // prefix

			// contents:
			if (inp[i] == '\\')
			{
				i += 1;
				switch (inp[i])
				{
				case ']':
				case '-':
					sink.put(inp[i]); // for instance: `\]` => `]`
					break;
				case '\\':
					sink.put(`\\`); // `\\` => `\\`
					break;
				default:
					sink.put('\\');
					if (inp[i] == 'u')
					{
						import std.ascii : isHexDigit;
						if (i + 5 > inp.length &&
							!(inp[i + 1].isHexDigit &&
							  inp[i + 2].isHexDigit &&
							  inp[i + 3].isHexDigit &&
							  inp[i + 4].isHexDigit))
						{
							if (parser !is null)
								parser._lexer.errorAtToken(Token(head.tok, inp[i + 1 .. $]), "incorrect unicode escape sequence");
						}
						sink.put(inp[i .. i + 5]);
						i += 4;
					}
					else
						sink.put(inp[i]);
					break;
				}
			}
			else if (inp[i] == '\'')
				sink.put(`\'`);
			else
				sink.put(inp[i]);
			i += 1;

			sink.put('\'');	 // suffix
		}
		sink.put(")()");
	}

	override void toString(scope ref Output sink) const @property @nogc
	{
		toMatchInSource(sink, null, false);
	}

	private Output toMatchRangeInSource(Input input,
										out size_t altCount) const @nogc // alt count
	{
		typeof(return) sink;	   // argument sink
		for (size_t i; i < input.length; ++altCount)
		{
			if (i)
				sink.put(", "); // separator

			if (i + 3 <= input.length &&
				input[i] != '\\' &&
				input[i + 1] == '-') // such as: `a-z`
			{
				sink.put("rng('");
				sink.put(input[i]),
				sink.put("', '");
				sink.put(input[i + 2]),
				sink.put("')");
				i += 3;
			}
			else if (i + 13 <= input.length &&
					 input[i] == '\\' &&
					 input[i + 1] == 'u' &&
					 input[i + 5] != '\\' &&
					 input[i + 6] == '-') // such as: `\u0021-\u0031`
			{
				sink.put("rng('");
				sink.put(input[i .. i + 6]),
				sink.put("', '");
				sink.put(input[i + 7 .. i + 7 + 6]),
				sink.put("')");
				i += 13;
			}
			else
			{
				sink.put("ch('");
				if (input[i] == '\'')
					sink.put(`\'`); // escaped single quote
				else if (input[i] == '\\')
				{
					i += 1;				 // skip '\\'
					switch (input[i])
					{
					case ']':
					case '-':
						sink.put(input[i]); // for instance: `\]` => `]`
						break;
					case '\\':
						sink.put(`\\`); // `\\` => `\\`
						break;
					default:
						sink.put('\\');
						sink.put(input[i]);
						break;
					}
				}
				else
					sink.put(input[i]);
				i += 1;
				sink.put("')");
			}
		}
		return sink;
	}
	override DcharCountSpan dcharCountSpan() const pure @nogc
	{
		return typeof(return)(1);
	}
	override bool opEquals(const scope Pattern that) const @nogc
	{
		if (auto that_ = cast(const typeof(this))that)
			return head.input == that_.head.input;
		return false;
	}
}

@safe final class LineComment : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class BlockComment : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

/// Grammar named `name`.
@safe final class Grammar : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
		putchar(' ');
		showChars(name);
		showChars(";\n");
	}
nothrow:
	this(Token head, Input name) @nogc
	{
		super(head);
		this.name = name;
	}
	final override bool equals(const Node o) const
	{
		if (this is o)
			return true;
		if (const o_ = cast(const typeof(this))o)
			return (head == o_.head &&
					name == o_.name);
		return false;
	}
	Input name;
}

/// Lexer grammar named `name`.
@safe final class LexerGrammar : TokenNode
{
nothrow:
	this(Token head, Input name) @nogc
	{
		super(head);
		this.name = name;
	}
	Input name;
}

/** Parser grammar named `name`.
 *
 * See_Also: https://theantlrguy.atlassian.net/wiki/spaces/ANTLR3/pages/2687210/Quick+Starter+on+Parser+Grammars+-+No+Past+Experience+Required
 */
@safe final class ParserGrammar : TokenNode
{
nothrow:
	this(Token head, Input name) @nogc
	{
		super(head);
		this.name = name;
	}
	Input name;
}

/// Import of `modules`.
@safe final class Import : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
		putchar(' ');
		foreach (const i, const m ; moduleNames)
		{
			if (i)
				putchar(',');
			showChars(m);
		}
		putchar(';');
		putchar('\n');
	}
nothrow:
	this(Token head, DynamicArray!(Input) moduleNames) @nogc
	{
		super(head);
		() @trusted { move(moduleNames, this.moduleNames); } ();
	}
	DynamicArray!(Input) moduleNames;
}

@safe final class Mode : TokenNode
{
nothrow:
	this(Token head, Input name) @nogc
	{
		super(head);
		this.name = name;
	}
	Input name;
}

@safe final class Options : TokenNode
{
nothrow:
	this(Token head, Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	Input name;
	Token code;
}

@safe final class Header : TokenNode
{
nothrow:
	this(Token head, Token name, Token code) @nogc
	{
		super(head);
		this.name = name;
		this.code = code;
	}
	Token name;
	Token code;
}

@safe final class ScopeSymbolAction : TokenNode
{
nothrow:
	this(Token head,
		 Input name,
		 Token code) @nogc
	{
		super(head);
		this.name = name;
		this.code = code;
	}
	Input name;
	Token code;
}

@safe final class ScopeSymbol : TokenNode
{
nothrow:
	this(Token head,
		 Input name) @nogc
	{
		super(head);
		this.name = name;
	}
	Input name;
}

@safe final class ScopeAction : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head,
		 Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	Token code;
}

@safe final class AttributeSymbol : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head, Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	Token code;
}

@safe final class Action : TokenNode
{
nothrow:
	this(Token head) pure @nogc
	{
		super(head);
	}
}

@safe final class ActionSymbol : TokenNode
{
	override void show(in Format fmt = Format.init) const
	{
		showToken(head, fmt);
	}
nothrow:
	this(Token head, Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	Token code;
}

@safe final class Channels : TokenNode
{
nothrow:
	this(Token head, Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	Token code;
}

@safe final class Tokens : TokenNode
{
nothrow:
	this(Token head, Token code) @nogc
	{
		super(head);
		this.code = code;
	}
	override void toMatchInSource(scope ref Output sink, const scope GxParserByStatement parser, in bool useCall = true) const @nogc
	{
	}
	Token code;
}

@safe final class Class : TokenNode
{
nothrow:
	this(Token head, Input name, Input baseName) @nogc
	{
		super(head);
		this.name = name;
		this.baseName = baseName;
	}
	Input name;
	Input baseName;			 ///< Base class name.
}

alias Imports = DynamicArray!(Import, Mallocator);
alias Rules = DynamicArray!(Rule, Mallocator);
alias SymbolRefs = DynamicArray!(SymbolRef, Mallocator);

/** Gx parser with range interface over all statements.
 *
 * See: `ANTLRv4Parser.g4`
 */
@safe class GxParserByStatement
{
	this(Input input, FilePath path = [], in bool includeComments = false)
	{
		_lexer = GxLexer(input, path, includeComments);
		if (!_lexer.empty)
			_front = nextFront();
	}

	bool empty() const @property nothrow scope @nogc
	{
		version (LDC) pragma(inline, true);
		return _front is null;
	}
	inout(Node) front() inout @property scope return in(!empty)
	{
		version (LDC) pragma(inline, true);
		return _front;
	}
	void popFront() scope in(!empty)
	{
		version (LDC) pragma(inline, true);
		return cast(void)(_front = (_lexer.empty) ? null : nextFront());
	}

	private Rule makeRule(Token name,
						  in bool isFragmentRule,
						  ActionSymbol actionSymbol = null,
						  Action action = null) scope
	{
		_lexer.popFront_checked(TOK.colon, "no colon");

		bool skipFlag;

		static if (useStaticTempArrays)
			StaticArray!(Pattern, 100) alts;
		else
			PatternArray alts;

		while (_lexer.front.tok != TOK.semicolon)
		{
			size_t parentDepth = 0;

			// temporary node sequence stack
			static if (useStaticTempArrays)
				StaticArray!(Node, 70) tseq; // doesn't speed up that much
			else
				NodeArray tseq;

			void seqPutCheck(Node last)
			{
				if (last is null)
					return _lexer.warningAtToken(name, "empty sequence");
				if (!_lexer.empty &&
					_lexer.front.tok == TOK.dotdot)
					return tseq.put(last); // ... has higher prescedence
				if (tseq.length != 0)
				{
					if (auto dotdot = cast(DotDotSentinel)tseq.back) // binary operator
					{
						tseq.popBack(); // pop `DotDotSentinel`
						return seqPutCheck(new Range(dotdot.head,
													 [cast(Pattern)tseq.takeBack(), cast(Pattern)last]));
					}
					if (auto tilde = cast(TildeSentinel)tseq.back) // prefix unary operator
					{
						tseq.popBack(); // pop `TildeSentinel`
						return seqPutCheck(new NotPattern(tilde.head,
														  cast(Pattern)last));
					}
					if (auto ng = cast(TerminatedUnaryOpPattern)tseq.back)
					{
						Pattern lastp = cast(Pattern)last;
						assert(lastp);
						ng.terminator = lastp;
					}
				}
				return tseq.put(last);
			}

			while ((parentDepth != 0 ||
					_lexer.front.tok != TOK.pipe) &&
				   _lexer.front.tok != TOK.semicolon)
			{
				/+ TODO: use static array with length being number of tokens till `TOK.pipe` +/
				const head = _lexer.takeFront();

				void groupLastSeq() @safe nothrow
				{
					// find backwards index `ih` in `tseq` at '(' or '|'. TODO: reuse `lastIndexOf`
					size_t ih = tseq.length;
					foreach_reverse (const i, const e; tseq)
					{
						if (auto sym = cast(const PipeSentinel)e)
						{
							ih = i;
							break;
						}
						else if (auto sym = cast(const LeftParenSentinel)e)
						{
							ih = i;
							break;
						}
					}
					if (ih == tseq.length)
						_lexer.errorAtToken(head, "missing left-hand side");
					Pattern nseq = makeSeq(tseq[ih + 1 .. $], _lexer);
					tseq.popBackN(tseq.length - (ih + 1)); // exclude op sentinel
					tseq.insertBack(nseq);				 // put it back
				}

				switch (head.tok)
				{
				case TOK.symbol:
					if (head.input == "options")
						auto _ = makeRuleOptions(head, true);
					else
					{
						if (_lexer.front.tok == TOK.colon)
						{
							_lexer.popFront();
							continue; // skip element label: SYMBOL '.'. See_Also: https://www.antlr2.org/doc/metalang.html section "Element Labels"
						}
						auto sref = new SymbolRef(head);
						seqPutCheck(sref);
						symbolRefs.insertBack(sref);
					}
					break;
				case TOK.literal:
					seqPutCheck(new StringLiteral(head));
					break;
				case TOK.qmark:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					Pattern node;
					if (auto oom = cast(GreedyOneOrMore)tseq.back)
					{
						// See_Also: https://stackoverflow.com/questions/64706408/rewriting-x-as-x-in-antlr-grammars
						node = new GreedyZeroOrMore(head, oom.sub);
						tseq.popBack();
						_lexer.warningAtToken(head, "read `(X+)?` as `X*`");
					}
					else
						node = new GreedyZeroOrOne(head, tseq.takeBack());
					seqPutCheck(node);
					break;
				case TOK.star:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new GreedyZeroOrMore(head, tseq.takeBack()));
					break;
				case TOK.plus:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new GreedyOneOrMore(head, tseq.takeBack()));
					break;
				case TOK.qmarkQmark:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new NonGreedyZeroOrOne(head, tseq.takeBack()));
					break;
				case TOK.starQmark:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new NonGreedyZeroOrMore(head, tseq.takeBack()));
					break;
				case TOK.plusQmark:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new NonGreedyOneOrMore(head, tseq.takeBack()));
					break;
				case TOK.rewriteSyntacticPredicate:
					if (tseq.length == 0)
						_lexer.errorAtToken(head, "missing left-hand side");
					seqPutCheck(new RewriteSyntacticPredicate(head, tseq.takeBack()));
					break;
				case TOK.tilde:
					tseq.put(new TildeSentinel(head));
					break;
				case TOK.pipe:
					if (tseq.length == 0)
					{
						_lexer.warningAtFront("missing left-hand side");
						continue;
					}
					else if (const symbol = cast(LeftParenSentinel)tseq.back)
					{
						_lexer.warningAtToken(symbol.head, "missing left-hand side");
						continue;
					}
					groupLastSeq();
					tseq.put(new PipeSentinel(head));
					break;
				case TOK.dotdot:
					tseq.put(new DotDotSentinel(head));
					break;
				case TOK.wildcard:
					seqPutCheck(new AnyClass(head));
					break;
				case TOK.brackets:
					seqPutCheck(parseCharAltM(new CharAltM(head), _lexer));
					break;
				case TOK.hash:
				case TOK.rewrite:
					// ignore `head`
					if (_lexer.front == Token(TOK.symbol, "skip"))
					{
						skipFlag = true;
						_lexer.popFront();
					}
					while (_lexer.front.tok != TOK.pipe &&
						   _lexer.front.tok != TOK.semicolon)
					{
						_lexer.warningAtFront("TODO: use rewrite argument");
						_lexer.popFront(); // ignore for now
					}
					break;
				case TOK.leftParen:
					parentDepth += 1;
					tseq.put(new LeftParenSentinel(head));
					break;
				case TOK.rightParen:
					parentDepth -= 1;

					groupLastSeq();

					// find matching '(' if any
					size_t si = tseq.length; // left paren sentinel index
					LeftParenSentinel ss;	// left parent index Symbol
					foreach_reverse (const i, Node node; tseq[])
					{
						if (auto lp = cast(LeftParenSentinel)node)
						{
							si = i;
							ss = lp;
							break;
						}
					}

					PatternArray asubs; /+ TODO: use stack allocation of length tseq[si .. $].length - number of `PipeSentinel`s +/
					Token ahead;
					foreach (e; tseq[si + 1.. $])
					{
						if (auto ps = cast(PipeSentinel)e)
						{
							if (ahead != Token.init)
								ahead = ps.head; // use first '|' as head of alternative below
						}
						else
						{
							Pattern pe = cast(Pattern)e;
							assert(pe);
							asubs.put(pe);
						}
					}
					if (asubs.length == 0)
					{
						auto nothing = new SeqM(ss.head);
						tseq.popBack(); // pop '('
						seqPutCheck(nothing);
					}
					else
					{
						auto lalt = makeAltA(ahead, asubs.move());
						tseq.popBackN(tseq.length - si);
						Node[1] ssubs = [lalt];
						seqPutCheck(makeSeq(ssubs, _lexer));
					}
					break;
				case TOK.action:
					// ignore action
					_lexer.skipOverTOK(TOK.qmark); /+ TODO: handle in a more generic way +/
					break;
				case TOK.labelAssignment:
					// ignore for now: SYMBOL '='
					if (!cast(OtherSymbol)tseq.back)
						_lexer.errorAtFront("non-symbol before label assignment");
					tseq.popBack(); // ignore
					break;
				case TOK.tokenSpecOptions:
					// ignore
					break;
				case TOK.colon:
					// ignore
					_lexer.warningAtFront("ignoring colon with no effect");
					continue;
				case TOK.rootNode:
					/* AST root operator. When generating abstract syntax trees
					 * (ASTs), token references suffixed with the "^" root
					 * operator force AST nodes to be created and added as the
					 * root of the current tree. This symbol is only effective
					 * when the buildAST option is set. More information about
					 * ASTs is also available. */
					// ignore
					break;
				case TOK.exclamation:
					/* AST exclude operator. When generating abstract syntax
					 * trees, token references suffixed with the "!" exclude
					 * operator are not included in the AST constructed for that
					 * rule. Rule references can also be suffixed with the
					 * exclude operator, which implies that, while the tree for
					 * the referenced rule is constructed, it is not linked into
					 * the tree for the referencing rule. This symbol is only
					 * effective when the buildAST option is set. More
					 * information about ASTs is also available. */
					// ignore
					break;
				case TOK.semicolon:
					assert(false);
				default:
					_lexer.infoAtFront("TODO: unhandled token type" ~ _lexer.front.to!string);
					seqPutCheck(new OtherSymbol(head));
					break;
				}
			}
			if (!tseq.length)   // may be empty
			{
				// _lexer.warningAtFront("empty rule sequence");
			}
			static if (useStaticTempArrays)
			{
				alts.put(makeSeq(tseq[], _lexer));
				tseq.clear();
			}
			else
			{
				alts.put(makeSeq(tseq[], _lexer)); /+ TODO: use `tseq.move()` when tseq is a `PatternArray` +/
				tseq.clear();
			}
			if (_lexer.front.tok == TOK.pipe)
				_lexer.popFront(); // skip terminator
		}

		_lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");

		// needed for ANTLRv2.g2:
		if (!_lexer.empty)
		{
			// if (_lexer.front == Token(TOK.symbol, "exception"))
			//	 _lexer.popFront();
			// if (_lexer.front == Token(TOK.symbol, "catch"))
			//	 _lexer.popFront();
			if (_lexer.front.tok == TOK.brackets)
				_lexer.popFront();
			if (_lexer.front.tok == TOK.action)
				_lexer.popFront();
		}

		static if (useStaticTempArrays)
		{
			Pattern root = alts.length == 1 ? alts.takeBack() : makeAltM(Token.init, alts[]);
			alts.clear();
		}
		else
			Pattern root = alts.length == 1 ? alts.takeBack() : makeAltA(Token.init, alts.move());

		Rule rule = (isFragmentRule
					 ? new FragmentRule(name, root, skipFlag)
					 : new Rule(name, root, skipFlag));

		if (_lexer._diagnoseLeftRecursion)
			rule.diagnoseDirectLeftRecursion(_lexer);

		// insert rule
		const warnDuplicateRulePattern = false; // this is normally not an error, for instance, in `oncrpcv2.g4`
		if (warnDuplicateRulePattern)
			foreach (const existingRule; rules)
			{
				if (rule.root.opEquals(existingRule.root))
				{
					_lexer.warningAtToken(rule.head, "rule with same root pattern"); /+ TODO: error +/
					_lexer.warningAtToken(existingRule.head, "existing definition here"); /+ TODO: errorSupplemental +/
				}
			}
		rules.insertBack(rule);
		rulesByName.update(rule.head.input,		// See_Also: https://dlang.org/spec/hash-map.html#advanced_updating
						   {
							   return rule;
						   },
						   (const scope ref Rule existingRule)
						   {
							   _lexer.warningAtToken(rule.head, "rule with same name already exists"); /+ TODO: error +/
							   _lexer.warningAtToken(existingRule.head, "existing definition here"); /+ TODO: errorSupplemental +/
							   return rule;
						   });

		return rule;
	}

	DynamicArray!(Input) makeArgs(in TOK separator,
								  in TOK terminator)
	{
		typeof(return) result;
		while (true)
		{
			result.put(_lexer.takeFront_checked(TOK.symbol).input);
			if (_lexer.front.tok != separator)
				break;
			_lexer.popFront();
		}
		_lexer.popFront_checked(terminator, "no terminating semicolon");
		return result;
	}

	AttributeSymbol makeAttributeSymbol(Token head) return scope nothrow
	{
		return new AttributeSymbol(head, _lexer.takeFront_checked(TOK.action, "missing action"));
	}

	ActionSymbol makeActionSymbol(Token head) nothrow scope
	{
		return new ActionSymbol(head, _lexer.takeFront_checked(TOK.action, "missing action"));
	}

	TokenNode makeScope(Token head)
	{
		if (_lexer.front.tok == TOK.symbol)
		{
			const symbol = _lexer.takeFront().input;
			if (_lexer.front.tok == TOK.action)
				return new ScopeSymbolAction(head, symbol,
											 _lexer.takeFront_checked(TOK.action, "missing action"));
			else
			{
				auto result = new ScopeSymbol(head, symbol);
				_lexer.takeFront_checked(TOK.semicolon,
										  "missing terminating semicolon");
				return result;
			}
		}
		else
		{
			return new ScopeAction(head,
								   _lexer.takeFront_checked(TOK.action, "missing action"));
		}
	}

	Import makeImport(Token head)
	{
		auto import_ = new Import(head, makeArgs(TOK.comma, TOK.semicolon));
		this.imports.put(import_);
		return import_;
	}

	TokenNode makeClass(Token head)
	{
		auto result = new Class(head,
							   _lexer.takeFront_checked(TOK.symbol, "missing symbol").input,
							   _lexer.skipOverToken(Token(TOK.symbol, "extends")).input ?
							   _lexer.takeFront().input :
							   null);
		_lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");
		return result;
	}

	OtherSymbol skipOverOtherSymbol(string symbolIdentifier) return
	{
		if (_lexer.front == Token(TOK.symbol, symbolIdentifier))
			return new typeof(return)(_lexer.takeFront());
		return null;
	}

	/// Skip over scope if any.
	TokenNode skipOverScope()
	{
		if (_lexer.front == Token(TOK.symbol, "scope"))
			return makeScope(_lexer.takeFront());
		return null;
	}

	Options makeRuleOptions(Token head, in bool skipOverColon = false) nothrow scope
	{
		const action = _lexer.takeFront_checked(TOK.action, "missing action");
		if (skipOverColon)
			_lexer.skipOverTOK(TOK.colon);
		return new Options(head, action);
	}

	Options makeTopOptions(Token head) nothrow
	{
		const action = _lexer.takeFront_checked(TOK.action, "missing action");
		_lexer.skipOverTOK(TOK.colon); // optionally scoped. See_Also: https://stackoverflow.com/questions/64477446/meaning-of-colon-inside-parenthesises/64477817#64477817
		return new Options(head, action);
	}

	Channels makeChannels(Token head) nothrow
		=> new Channels(head, _lexer.takeFront_checked(TOK.action, "missing action"));

	Tokens makeTokens(Token head) nothrow
		=> new Tokens(head, _lexer.takeFront_checked(TOK.action, "missing action"));

	Header makeHeader(Token head)
		=> new Header(head,
					  (_lexer.front.tok == TOK.literal ?
					   _lexer.takeFront() :
					   Token.init),
					  _lexer.takeFront_checked(TOK.action, "missing action"));

	Mode makeMode(Token head)
	{
		scope(exit) _lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");
		return new Mode(head, _lexer.takeFront().input);
	}

	Action makeAction(Token head)
		=> new Action(head);

	/// Skip over options if any.
	Options skipOverPreRuleOptions()
	{
		if (_lexer.front == Token(TOK.symbol, "options"))
			return makeRuleOptions(_lexer.takeFront());
		return null;
	}

	bool skipOverExclusion()
	{
		if (_lexer.front.tok == TOK.exclamation)
		{
			_lexer.takeFront();
			return true;
		}
		return false;
	}

	bool skipOverReturns()
	{
		if (_lexer.front == Token(TOK.symbol, "returns"))
		{
			_lexer.takeFront();
			return true;
		}
		return false;
	}

	bool skipOverHooks()
	{
		if (_lexer.front.tok == TOK.brackets)
		{
			// _lexer.infoAtFront("TODO: use TOK.brackets");
			_lexer.takeFront();
			return true;
		}
		return false;
	}

	Action skipOverAction()
	{
		if (_lexer.front.tok == TOK.action)
			return makeAction(_lexer.takeFront());
		return null;
	}

	ActionSymbol skipOverActionSymbol()
	{
		if (_lexer.front.tok == TOK.actionSymbol)
			return makeActionSymbol(_lexer.takeFront);
		return null;
	}

	Node makeRuleOrOther(Token head) scope @trusted
	{
		if (_lexer.front.tok == TOK.colon) // normal case
			return makeRule(head, false);  // fast path

		if (head.input == "lexer" ||
			head.input == "parser" ||
			head.input == "grammar")
		{
			bool lexerFlag;
			bool parserFlag;
			if (head.input == "lexer")
			{
				lexerFlag = true;
				_lexer.popFront_checked(TOK.symbol, "expected `grammar` after `lexer`"); /+ TODO: enforce input grammar +/
			}
			else if (head.input == "parser")
			{
				parserFlag = true;
				_lexer.popFront_checked(TOK.symbol, "expected `grammar` after `parser`"); /+ TODO: enforce input grammar +/
			}

			if (lexerFlag)
			{
				auto lexerGrammar = new LexerGrammar(head, _lexer.takeFront().input);
				_lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");
				return this.grammar = lexerGrammar;
			}
			else if (parserFlag)
			{
				auto parserGrammar = new ParserGrammar(head, _lexer.takeFront().input);
				_lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");
				return this.grammar = parserGrammar;
			}
			else
			{
				if (_lexer.front.tok == TOK.colon)
					return makeRule(head, false);
				else
				{
					auto grammar = new Grammar(head, _lexer.takeFront().input);
					_lexer.popFront_checked(TOK.semicolon, "no terminating semicolon");
					this.grammar = grammar;
					return grammar;
				}
			}
		}

		switch (head.input)
		{
		case `private`:
			_lexer.front_checked(TOK.symbol, "expected symbol after `private`");
			return makeRuleOrOther(_lexer.takeFront); /+ TODO: set private qualifier +/
		case `protected`:
			_lexer.front_checked(TOK.symbol, "expected symbol after `protected`");
			return makeRuleOrOther(_lexer.takeFront); /+ TODO: set protected qualifier +/
		case `channels`:
			return makeChannels(head);
		case `tokens`:
			return makeTokens(head);
		case `options`:
			auto options = makeTopOptions(head);
			optionsSet.insertBack(options);
			return options;
		case `header`:
			return makeHeader(head);
		case `mode`:
			return makeMode(head);
		case `class`:
			return makeClass(head);
		case `scope`:
			return makeScope(head);
		case `import`:
			return makeImport(head);
		case `fragment`: // lexer helper rule, not real token for parser.
			return makeRule(_lexer.takeFront(), true);
		default:
			while (_lexer.front.tok != TOK.colon)
			{
				/+ TODO: use switch +/
				if (skipOverExclusion()) /+ TODO: use +/
					continue;
				if (skipOverReturns())  /+ TODO: use +/
					continue;
				if (skipOverHooks())	/+ TODO: use +/
					continue;
				if (const _ = skipOverOtherSymbol("locals")) /+ TODO: use +/
					continue;
				if (const _ = skipOverPreRuleOptions()) /+ TODO: use +/
					continue;
				if (const _ = skipOverScope())	 /+ TODO: use +/
					continue;
				if (const _ = skipOverAction()) /+ TODO: use +/
					continue;
				if (const _ = skipOverActionSymbol()) /+ TODO: use +/
					continue;
				break;		  // no progression so done
			}
			return makeRule(head, false);
		}
	}

	Node nextFront() scope
	{
		const head = _lexer.takeFront();
		switch (head.tok)
		{
		case TOK.attributeSymbol:
			return makeAttributeSymbol(head);
		case TOK.actionSymbol:
			return makeActionSymbol(head);
		case TOK.blockComment:
			return new BlockComment(head);
		case TOK.lineComment:
			return new LineComment(head);
		case TOK.action:
			return new Action(head);
		case TOK.symbol:
			return makeRuleOrOther(head);
		default:
			_lexer.errorAtFront("TODO: handle");
			assert(false);
		}
	}

	TokenNode grammar;
	DynamicArray!(Options) optionsSet;
	Imports imports;
	Rules rules;
	RulesByName rulesByName;
	SymbolRefs symbolRefs;	  ///< All of `SymbolRef` instances.
	bool warnUnknownSymbolFlag;
private:
	GxLexer _lexer;
	Node _front;
	Rule _rootRule;			   ///< Root rule for grammar.
}

static assert(isInputRange!(GxParserByStatement));
static assert(is(ElementType!GxParserByStatement == Node));

/// Returns: `path` as module name.
string toPathModuleName(scope FilePath path)
{
	string adjustDirectoryName(const return scope string name) pure nothrow @nogc
	{
		if (name == "asm")	  // TODO extend to check if a keyword
			return "asm_";
		return name;
	}

	const stripLeadingSlashesFlag = false;
	if (stripLeadingSlashesFlag)
		while (path.str[0] == '/' ||
			   path.str[0] == '\\')
			path = FilePath(path.str[1 .. $]);	// strip leading '/'s

	const grammarsV4DirPath = DirPath("~/Work/grammars-v4").expandTilde; /+ TODO: move somewhere suitable +/

	return path.expandTilde.str
			   .relativePath(grammarsV4DirPath.str)
			   .stripExtension
			   .pathSplitter()
			   .map!(_ => adjustDirectoryName(_))
			   .joiner("__")	// "/" => "__"
			   .substitute('-', '_')
			   .to!string ~ "_parser"; /+ TODO: use lazy ranges that return `char`; +/
}

/// Gx filer parser.
@safe class GxFileParser : GxParserByStatement
{
	this(in FilePath src,
		 GxFileParserByModuleName cachedParsersByModuleName)
	{
		Input data = cast(Input)rawReadZ(FilePath(src.expandTilde.str)); // cast to Input because we don't want to keep all file around:
		super(data, src, false);
		this.cachedParsersByModuleName = cachedParsersByModuleName;
	}

	alias RuleNames = DynamicArray!string;

	void generateParserSourceString(scope ref Output output,
									out string moduleName)
	{
		const path = _lexer.path;
		moduleName = path.toPathModuleName();

		output.put("/// Automatically generated from `");
		output.put("/// @sourcePath(PATH_TO_GRAMMAR) `");
		output.put(path.str);
		output.put("`.\n");
		output.put("module " ~ moduleName ~ q{;

});
		output.put(parserSource_prelude);
		output.put("\n");
		output.put("@sourcePath(\""~path.str~"\")\n");
		output.put("@sourceSHA1Base64(\""~path.str~"\")\n");
		output.put(parserSource_structParser);
		toMatchers(output);
		output.put(parserSourceEnd);

		rootRule();	  /+ TODO: use this +/
	}

	/** Get root rule.
	 *
	 * See_Also: https://github.com/antlr/grammars-v4/issues/2097
	 * See_Also: https://stackoverflow.com/questions/29879626/antlr4-how-to-find-the-root-rules-in-a-gramar-which-maybe-used-to-find-the-star
	 */
	@property Rule rootRule()
	{
		if (_rootRule)
			return _rootRule;
		retagReferencedRules();
		foreach (Rule rule; rules)
		{
			if (rule.hasRef ||
				rule.skipFlag)
				continue;
			else if (rule.isFragmentRule)
				_lexer.warningAtToken(rule.head, "unused fragment rule");
			else if (rule.isLexerTokenRule)
				_lexer.warningAtToken(rule.head, "unused (lexical) lexer token rule"); /+ TODO: don't warn about skipped rules -> skip +/
			else if (_rootRule)
			{
				_lexer.warningAtToken(rule.head, "second root rule defined");
				_lexer.warningAtToken(_rootRule.head, "  existing root rule defined here");
			}
			else
				_rootRule = rule;
		}
		if (!_rootRule)
			_lexer.warningAtToken(grammar.head, "missing root rule, all rule symbols are referenced (cyclic grammar)");
		return _rootRule;
	}

	/** Retag all referenced rules.
	 */
	void retagReferencedRules()
	{
		untagReferencedRules();
		tagReferencedRules();
	}

	/** Untag all rules (as unreferenced).
	 */
	void untagReferencedRules() nothrow
	{
		foreach (Rule rule; rulesByName.byValue)
			rule.hasRef = false;
	}

	/** Tag all referenced rules in either `this` or imported modules.
	 */
	void tagReferencedRules()
	{
		foreach (const symbolRef; symbolRefs)
		{
			if (symbolRef.head.input == "EOF")
				continue;
			if (tryTagReferencedRule(symbolRef))
				continue;
			foreach (const Import import_; imports)
			{
				debug writeln("import:",import_);
				foreach (const Input moduleName; import_.moduleNames)
				{
					typeof(this) sub = findModuleUpwards(_lexer.path.str.dirName,
														 moduleName,
														 _lexer.path.str.extension,
														 cachedParsersByModuleName);
					if (sub.tryTagReferencedRule(symbolRef))
						goto done;
				}
			}
			_lexer.warningAtToken(symbolRef.head, "undefined");
		done:
		}
	}

	bool tryTagReferencedRule(const SymbolRef symbolRef) nothrow @nogc
	{
		// debug writeln("path: ", _lexer.path, " symbolRef.head=", symbolRef.head, " rulesByName.length=", rulesByName.length, " rules=", rules.length);
		// NOTE: why is this here? assert(rulesByName.length);
		if (auto hit = symbolRef.head.input in rulesByName)
		{
			hit.hasRef = true;
			return true;
		}
		return false;
	}

	void toMatchers(scope ref Output output)
	{
		RuleNames doneRuleNames;
		toMatchersForRules(doneRuleNames, output);
		toMatchersForImports(doneRuleNames, output);
		toMatchersForOptionsTokenVocab(doneRuleNames, output);
	}

	void toMatchersForImportedModule(in const(char)[] moduleName,
									 scope ref RuleNames doneRuleNames,
									 scope ref Output output) scope
	{
		GxFileParser fp_ = findModuleUpwards(_lexer.path.str.dirName, // cwd
											 moduleName,
											 _lexer.path.str.extension,
											 cachedParsersByModuleName);
		while (!fp_.empty)
			fp_.popFront();

		fp_.toMatchersForImports(doneRuleNames, output); // transitive imports

		/** Rules in the “main grammar” override rules from imported
			grammars to implement inheritance.
			See_Also: https://github.com/antlr/antlr4/blob/master/doc/grammars.md#grammar-imports
		*/
		bool isOverridden(const scope Rule rule) const pure nothrow @safe @nogc
			=> doneRuleNames[].canFind(rule.head.input);

		foreach (const Rule importedRule; fp_.rules)
		{
			if (isOverridden(importedRule)) // if `importedRule` has already been defined
			{
				fp_._lexer.warningAtToken(importedRule.head, "ignoring rule overridden in top grammar");
				continue;
			}
			importedRule.toMatcherInSource(output, this);
			doneRuleNames.put(importedRule.head.input);
		}
	}

	private static GxFileParser findModuleUpwards(const string cwd,
												  scope const(char)[] moduleName,
												  scope const string ext,
												  GxFileParserByModuleName cachedParsersByModuleName)
	{
		if (auto existingParser = moduleName in cachedParsersByModuleName)
		{
			debug writeln("reusing existing parser for module named ", moduleName.idup);
			return *existingParser;
		}
		import std.file : FileException;
		FilePath modulePath;
		() @trusted {
			/* TODO: avoid cast somehow
			   https://forum.dlang.org/post/ypnssfszqfuhjremnsqo@forum.dlang.org
			*/
			modulePath = FilePath(cast(string)chainPath(cwd, moduleName ~ ext).array);
		} ();
		try
			return cachedParsersByModuleName[moduleName.to!string] = new GxFileParser(modulePath, cachedParsersByModuleName);
		catch (Exception e)
		{
			const cwdNext = cwd.dirName;
			if (cwdNext == cwd) // stuck at top directory
				throw new FileException("couldn't find module named " ~ moduleName); /+ TODO: add source of import statement +/
			return findModuleUpwards(cwdNext, moduleName, ext, cachedParsersByModuleName);
		}
	}

	void toMatchersForRules(scope ref RuleNames doneRuleNames, scope ref Output output) const scope
	{
		foreach (const Rule rule; rules)
		{
			// rule.show();
			rule.toMatcherInSource(output, this);
			doneRuleNames.put(rule.head.input);
		}
	}

	void toMatchersForImports(scope ref RuleNames doneRuleNames, scope ref Output output) scope
	{
		foreach (const import_; imports)
		{
			foreach (const moduleName; import_.moduleNames)
				toMatchersForImportedModule(moduleName, doneRuleNames, output);
		}
	}

	void toMatchersForOptionsTokenVocab(scope ref RuleNames doneRuleNames, scope ref Output output) scope
	{
		foreach (const options; optionsSet[])
		{
			const(char)[] co = options.code.input;

			void skipWhitespace()
			{
				import std.algorithm.comparison : among;
				size_t i;
				while (co.length &&
					   co[i].among!(GxLexer.whiteChars))
					i += 1;
				co = co[i .. $];
			}

			co.skipOverAround('{', '}');

			skipWhitespace();

			// See_Also: https://stackoverflow.com/questions/28829049/antlr4-any-difference-between-import-and-tokenvocab
			if (co.skipOver("tokenVocab"))
			{
				skipWhitespace();
				co.skipOver('=');
				skipWhitespace();
				if (const ix = co.indexOfAmong(" ;"))
				{
					const module_ = co[0 .. ix];
					toMatchersForImportedModule(module_, doneRuleNames, output);
				}
			}
		}
	}
	GxFileParserByModuleName cachedParsersByModuleName;
}

static immutable parserSource_prelude =
`alias Input = const(char)[];

@safe struct Match
{
pure nothrow @safe @nogc:
	static Match zero()
	{
		return typeof(return)(0);
	}
	static Match none()
	{
		return typeof(return)(_length.max);
	}
	/// Match length in number of UTF-8 chars or 0 if empty.
	@property uint length()
	{
		return _length;
	}
	bool opCast(U : bool)() const
	{
		return _length != _length.max;
	}
	this(size_t length)
	{
		assert(length <= _length.max);
		this._length = cast(typeof(_length))length;
	}
	const uint _length;				// length == uint.max is no match
}

/// https://forum.dlang.org/post/zcvjwdetohmklaxriswk@forum.dlang.org
version (none) alias Matcher = Match function(lazy Matcher[] matchers...);

/// Source path (of grammar).
struct sourcePath { this(string) {} }

/// SHA-1 in Base-64 (of grammar).
struct sourceSHA1Base64 { this(string) {} }
`;

static immutable parserSource_structParser = `@safe struct Parser
{
	Input inp;				  ///< Input.
	size_t off;				 ///< Current offset into inp.

	Match EOF() pure nothrow @nogc
	{
		pragma(inline, true);
		if (inp[off] == '\r' &&
			inp[off + 1] == '\n') // Windows
		{
			off += 2;
			return Match(2);
		}
		if (inp[off] == '\n' || // Unix/Linux
			inp[off] == '\r')   // Mac?
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match any() pure nothrow @nogc
	{
		version (LDC) pragma(inline, true);
		if (off == inp.length)  /+ TODO: +/
			return Match.none();
		off += 1;
		return Match(1);
	}

	Match ch(in char x) pure nothrow @nogc
	{
		version (LDC) pragma(inline, true);
		if (off == inp.length)  /+ TODO: +/
			return Match.none();
		if (inp[off] == x)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match dch(const dchar x) pure nothrow @nogc /+ TODO: use x +/
	{
		import std.typecons : Yes;
		import std.utf : encode;
		char[4] ch4;
		const replacementChar = cast(dchar)0x110000; // TODO :throw exception instead
		const n = encode!(Yes.useReplacementDchar)(ch4, replacementChar); /+ TODO: use decode instead +/
		if (ch4[0 .. n] == [239, 191, 189]) // encoding of replacementChar
			return Match.none();
		if (off + n > inp.length) /+ TODO: +/
			return Match.none();
		if (inp[off .. off + n] == ch4[0 .. n])
		{
			off += n;
			return Match(n);
		}
		return Match.none();
	}

	dchar popDchar() pure /+ TODO: nothrow @nogc +/
	{
		import std.typecons : Yes;
		import std.utf : decode;
		return inp.decode(off);
	}

	dchar peekDchar() pure /+ TODO: nothrow @nogc +/
	{
		import std.typecons : Yes;
		import std.utf : decode;
		auto offCopy = off;
		return inp.decode(offCopy);
	}

	Match cc(string charClass)() pure nothrow @nogc
	{
		pragma(inline, true);
		off += 1;			   /+ TODO: switch on charClass +/
		if (off > inp.length)   /+ TODO: +/
			return Match.none();
		return Match(1);
	}

	/// Match string x.
	Match str(const scope string x) pure nothrow @nogc
	{
		pragma(inline, true);
		if (off + x.length <= inp.length && /+ TODO: optimize by using null-sentinel +/
			inp[off .. off + x.length] == x) // inp[off .. $].startsWith(x)
		{
			off += x.length;
			return Match(x.length);
		}
		return Match.none();
	}

	Match seq(Matchers...)(const scope lazy Matchers matchers)
	{
		const off0 = off;
		static foreach (const matcher; matchers)
		{{					  // scoped
			const match = matcher();
			if (!match)
			{
				off = off0;	 // backtrack
				return match;   // propagate failure
			}
		}}
		return Match(off - off0);
	}

	Match alt(Matchers...)(const scope lazy Matchers matchers)
	{
		static foreach (const matcher; matchers)
		{{					  // scoped
			const off0 = off;
			if (const match = matcher())
				return match;
			else
				off = off0;	 // backtrack
		}}
		return Match.none();
	}

	Match not(Matcher)(const scope lazy Matcher matcher)
	{
		const off0 = off;
		const match = matcher();
		if (!match)
			return match;
		off = off0;			 // backtrack
		return Match.none();
	}

	Match alt2(char a, char b)() pure nothrow @nogc
	{
		pragma(inline, true);
		const x = inp[off];
		if (x == a ||
			x == b)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match alt3(char a, char b, char c)() pure nothrow @nogc
	{
		pragma(inline, true);
		const x = inp[off];
		if (x == a ||
			x == b ||
			x == c)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match alt4(char a, char b, char c, char d)() pure nothrow @nogc
	{
		pragma(inline, true);
		const x = inp[off];
		if (x == a ||
			x == b ||
			x == c ||
			x == d)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match alt5(char a, char b, char c, char d, char e)() pure nothrow @nogc
	{
		pragma(inline, true);
		const x = inp[off];
		if (x == a ||
			x == b ||
			x == c ||
			x == d ||
			x == e)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match altN(chars...)() pure nothrow @nogc /+ TODO: non-char type in chars +/
	{
		pragma(inline, true);
		import std.algorithm.comparison : among; /+ TODO: replace with switch over static foreach to speed up compilation +/
		const x = inp[off];
		if (x.among!(chars))
		{
			off += 1; /+ TODO: skip over number of chars needed to encode hit +/
			return Match(1);
		}
		return Match.none();
	}

	Match rng(in char lower, in char upper) pure nothrow @nogc
	{
		pragma(inline, true);
		const x = inp[off];
		if (lower <= x &&
			x <= upper)
		{
			off += 1;
			return Match(1);
		}
		return Match.none();
	}

	Match rng(in dchar lower, in dchar upper) pure nothrow @nogc
	{
		pragma(inline, true);
		/+ TODO: decode dchar at inp[off] +/
		const x = inp[off];
		if (lower <= x &&
			x <= upper)
		{
			off += 1; /+ TODO: handle dchar at inp[off] +/
			return Match(1);
		}
		return Match.none();
	}

	Match gzm(Matcher)(const scope lazy Matcher matcher)
	{
		const off0 = off;
		while (true)
		{
			const off1 = off;
			const match = matcher();
			if (!match)
			{
				off = off1;	 // backtrack
				break;
			}
		}
		return Match(off - off0);
	}

	Match gzo(Matcher)(const scope lazy Matcher matcher)
	{
		const off0 = off;
		const match = matcher();
		if (!match)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		return Match(off - off0);
	}

	Match gom(Matcher)(const scope lazy Matcher matcher)
	{
		const off0 = off;
		const match0 = matcher;
		if (!match0)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		while (true)
		{
			const off1 = off;
			const match1 = matcher;
			if (!match1)
			{
				off = off1;	 // backtrack
				break;
			}
		}
		return Match(off - off0);
	}

	// TODO merge overloads of nzo by using a default type and value for Matcher2
	Match nzo(Matcher1)(const scope lazy Matcher1 matcher)
	{
		const off0 = off;
		off = off0;			 // backtrack
		const match = matcher();
		if (!match)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		return Match(off - off0);
	}
	Match nzo(Matcher1, Matcher2)(const scope lazy Matcher1 matcher, const scope lazy Matcher2 terminator)
	{
		const off0 = off;
		if (terminator())
		{
			off = off0;		 // backtrack
			return Match.zero(); // done
		}
		off = off0;			 // backtrack
		const match = matcher();
		if (!match)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		return Match(off - off0);
	}

	// TODO merge overloads of nzm by using a default type and value for Matcher2
	Match nzm(Matcher1)(const scope lazy Matcher1 matcher)
	{
		const off0 = off;
		while (true)
		{
			const off1 = off;
			off = off1;		 // backtrack
			const off2 = off;
			const match = matcher();
			if (!match)
			{
				off = off2;	 // backtrack
				break;
			}
		}
		return Match(off - off0);
	}
	Match nzm(Matcher1, Matcher2)(const scope lazy Matcher1 matcher, const scope lazy Matcher2 terminator)
	{
		const off0 = off;
		while (true)
		{
			const off1 = off;
			if (terminator())
			{
				off = off1;	 // backtrack
				return Match(off1 - off0); // done
			}
			off = off1;		 // backtrack
			const off2 = off;
			const match = matcher();
			if (!match)
			{
				off = off2;	 // backtrack
				break;
			}
		}
		return Match(off - off0);
	}

	// TODO merge overloads of nom by using a default type and value for Matcher2
	Match nom(Matcher1)(const scope lazy Matcher1 matcher)
	{
		const off0 = off;
		bool firstFlag;
		while (true)
		{
			const off1 = off;
			off = off1;		 // backtrack
			const off2 = off;
			const match = matcher();
			if (!match)
			{
				off = off2;	 // backtrack
				break;
			}
			firstFlag = true;
		}
		if (!firstFlag)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		return Match(off - off0);
	}
	Match nom(Matcher1, Matcher2)(const scope lazy Matcher1 matcher, const scope lazy Matcher2 terminator)
	{
		const off0 = off;
		bool firstFlag;
		while (true)
		{
			const off1 = off;
			if (terminator())
			{
				off = off1;	 // backtrack
				return Match(off1 - off0); // done
			}
			off = off1;		 // backtrack
			const off2 = off;
			const match = matcher();
			if (!match)
			{
				off = off2;	 // backtrack
				break;
			}
			firstFlag = true;
		}
		if (!firstFlag)
		{
			off = off0;		 // backtrack
			return Match.none();
		}
		return Match(off - off0);
	}

	Match syn(Matcher)(const scope lazy Matcher matcher)
	{
		return Match.zero(); // pass, backtracking is performed by default
	}

`;

static immutable parserSourceEnd =
`} // struct Parser
`;

@safe struct GxFileReader
{
	GxFileParser fp;
	this(in FilePath path, GxFileParserByModuleName cachedParsersByModuleName)
	{
		fp = new GxFileParser(path, cachedParsersByModuleName);
		while (!fp.empty)
			fp.popFront();
	}

	string createParserSourceFilePath(out string moduleName)
	{
		Output pss;
		fp.generateParserSourceString(pss, moduleName);
		import std.file : write;
		const path = fp._lexer.path;
		const ppath = chainPath(tempDir(), path.str.baseName.stripExtension).array ~ "_parser.d";
		write(ppath, pss[]);
		debug writeln("Wrote ", ppath);
		return ppath.to!(typeof(return));
	}

	~this() nothrow @nogc {}
}

@safe struct SourceFile
{
	this(in FilePath name, scope const(char)[] stdioOpenmode = "rb") @safe
	{
		_file = File(name.str, stdioOpenmode);
	}
	private File _file;
	alias _file this;
}

@safe struct ObjectFile
{
	this(string name, scope const(char)[] stdioOpenmode = "rb") @safe
	{
		_file = File(name, stdioOpenmode);
	}
	private File _file;
	alias _file this;
}

@safe struct ExecutableFile
{
	this(string name, scope const(char)[] stdioOpenmode = "rb") @safe
	{
		_file = File(name, stdioOpenmode);
	}
	File _file;
	alias _file this;
}

static immutable mainName = `main`;

static immutable mainSource =
`int ` ~ mainName ~ `(string[] args)
{
	return 0;
}
`;

SourceFile createMainFile(in FilePath path,
						  const string[] parserPaths,
						  const string[] parserModules)
in(parserPaths.length == parserModules.length)
{
	auto file = typeof(return)(path, "w");
	foreach (const index, const ppath; parserPaths)
	{
		file.write(`import `);
		file.write(parserModules[index]);
		file.write(";\n");
	}

	file.write("\n");		   // separator
	file.write(mainSource);
	file.close();
	return file;
}

/// Build the D source files `parserPaths`.
string buildSourceFiles(const string[] parserPaths,
						const string[] parserModules,
						in bool linkFlag = false)
{
	import std.process : execute;

	const mainFilePath = buildPath(DirPath(tempDir()), FileName("gxmain.d"));
	const mainFile = createMainFile(mainFilePath, parserPaths, parserModules);
	const parserName = "parser";
	const outFile = parserName ~ (linkFlag ? "" : ".o");
	const args = (["dmd"] ~
				  (linkFlag ? [] : ["-c"]) ~
				  ["-dip1000", "-vcolumns", "-wi"] ~
				  parserPaths ~
				  (linkFlag ? [mainFilePath.str] : []) ~
				  ("-of=" ~ outFile));
	const dmd = execute(args);
	if (dmd.status == 0)
		writeln("Compilation of ", parserPaths, " successful");
	else
		writeln("Compilation of ", parserPaths, " failed with output:\n",
				dmd.output);
	return outFile;
}

private bool isGxFilename(const scope char[] name) pure nothrow @safe @nogc
{
	return name.endsWith(`.g4`);
}

private bool isGxFilenameParsed(const scope char[] name) pure nothrow @safe @nogc
{
	if (!isGxFilename(name))
		 return false;

	// Pick specific file:
	if (name != `SHARCParser.g4`)
		return false;

	// Exclude files that currently cannot be processed.
	if (/+ TODO: +/
		name == `PhpLexer.g4` ||
		name == `PhpParser.g4` || // reads `PhpLexer.g4`
		name == `Python2.g4` ||
		name == `Python3.g4` ||
		name == `AltPython3.g4` ||
		name == `PythonParser.g4` ||
		/+ TODO: +/
		name == `ResourcePlanParser.g4` ||
		name == `SelectClauseParser.g4` ||
		name == `IdentifiersParser.g4` ||
		/+ TODO: +/
		name == `AspectJParser.g4` || /+ TODO: find rule for `annotationName` in apex.g4 +/
		name == `AspectJLexer.g4` ||
		/+ TODO: missing tokens +/
		name == `FromClauseParser.g4` ||
		name == `TSqlParser.g4` ||
		name == `informix.g4` ||
		name == `icon.g4` ||
		name == `ANTLRv4Parser.g4` ||
		name == `JPA.g4` || // INT_NUMERAL missing
		name == `STParser.g4` ||
		name == `STGParser.g4` ||
		/+ TODO: +/
		name == `RexxParser.g4` ||
		name == `RexxLexer.g4` ||
		name == `StackTrace.g4` ||
		name == `memcached_protocol.g4`) // skip this crap
		return false;
	return true;
}

import std.datetime.stopwatch : StopWatch;
import std.file : dirEntries, SpanMode, getcwd;

enum showProgressFlag = true;

void lexAllInDirTree(scope ref BuildCtx bcx) @system
{
	scope StopWatch swAll;
	swAll.start();
	foreach (const e; dirEntries(bcx.rootDirPath.str, SpanMode.breadth))
	{
		const fn = FilePath(e.name);
		if (fn.str.isGxFilename)
		{
			static if (showProgressFlag)
				bcx.outFile.writeln("Lexing ", tryRelativePath(bcx.rootDirPath.str, fn.str), " ...");  /+ TODO: read use curren directory +/
			const data = cast(Input)rawReadZ(fn); // exclude from benchmark
			scope StopWatch swOne;
			swOne.start();
			auto lexer = GxLexer(data, fn, false);
			while (!lexer.empty)
				lexer.popFront();
			static if (showProgressFlag)
				bcx.outFile.writeln("Lexing ", tryRelativePath(bcx.rootDirPath.str, fn.str), " took ", swOne.peek());
		}
	}
	bcx.outFile.writeln("Lexing all took ", swAll.peek());
}

/// Build Context
@safe struct BuildCtx {
	version (useTCC) TCC tcc;
	DirPath rootDirPath;
	File outFile;
	bool buildSingleFlag;	   ///< Build each parser separately in a separate compilation.
	bool buildAllFlag;		  ///< Build all parsers together in a common single compilation.
	bool lexerFlag;			 ///< Flag for separate lexing pass.
	bool parserFlag;			///< Flag for separate parsing pass.
	private GxFileParserByModuleName cachedParsersByModuleName; ///< Parser cache.
}

void parseAllInDirTree(scope ref BuildCtx bcx) @system
{
	scope StopWatch swAll;
	swAll.start();
	DynamicArray!string parserPaths; ///< Paths to generated parsers in D.
	DynamicArray!string parserModules;
	foreach (const e; dirEntries(bcx.rootDirPath.str, SpanMode.breadth))
	{
		const fn = FilePath(e.name);
		const dn = DirPath(fn.str.dirName);
		const bn = fn.str.baseName;
		if (bn.isGxFilenameParsed)
		{
			const exDirPath = buildPath(dn, FileName("examples")); // examples directory
			import std.file : isDir;
			const showParseExample = false;
			if (showParseExample &&
				exDirPath.exists &&
				exDirPath.str.isDir)
				foreach (const exf; dirEntries(exDirPath.str, SpanMode.breadth))
					bcx.outFile.writeln("TODO: Parse example file: ", exf);
			static if (showProgressFlag)
				bcx.outFile.writeln("Reading ", tryRelativePath(bcx.rootDirPath.str, fn.str), " ...");

			scope StopWatch swOne;
			swOne.start();

			auto reader = GxFileReader(fn, bcx.cachedParsersByModuleName);
			string parserModule;
			const parserPath = reader.createParserSourceFilePath(parserModule);
			if (parserPaths[].canFind(parserPath)) /+ TODO: remove because this should not happen +/
				bcx.outFile.writeln("Warning: duplicate entry outFile ", parserPath);
			else
			{
				parserPaths.insertBack(parserPath);
				parserModules.insertBack(parserModule);
			}

			if (bcx.buildSingleFlag)
				const parseExePath = buildSourceFiles([parserPath], [parserModule], true);

			static if (showProgressFlag)
				bcx.outFile.writeln("Reading ", tryRelativePath(bcx.rootDirPath.str, fn.str), " took ", swOne.peek());
		}
	}
	if (bcx.buildAllFlag)
		const parseExePath = buildSourceFiles(parserPaths[], parserModules[]);
	bcx.outFile.writeln("Reading all took ", swAll.peek());
}

void doTree(scope ref BuildCtx bcx) @system
{
	if (bcx.lexerFlag)
		lexAllInDirTree(bcx);
	if (bcx.parserFlag)
		parseAllInDirTree(bcx);
}

string tryRelativePath(scope string rootDirPath,
					   const return scope string path) @safe
{
	const cwd = getcwd();
	if (rootDirPath.startsWith(cwd))
		return path.relativePath(cwd);
	return path;
}
