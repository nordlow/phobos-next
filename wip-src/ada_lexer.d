/** Ada Lexer.  */
module nxt.ada_lexer;

import std.typecons;
import std.meta;
import std.array;
import std.algorithm;
import std.range;

import nxt.lexer;
import nxt.ada_defs;
import nxt.stringcache;

/// Operators
private enum operators = ada_defs.operators;

/// Keywords
private enum keywords = ada_defs.keywords2012;

/// Other tokens
private enum dynamicTokens = [
	`string`, `number`, `identifier`, `comment`, `whitespace`
	];

private enum pseudoTokenHandlers = [
	`"`, `lexStringLiteral`,
	`0`, `lexNumber`,
	`1`, `lexNumber`,
	`2`, `lexNumber`,
	`3`, `lexNumber`,
	`4`, `lexNumber`,
	`5`, `lexNumber`,
	`6`, `lexNumber`,
	`7`, `lexNumber`,
	`8`, `lexNumber`,
	`9`, `lexNumber`,
	` `, `lexWhitespace`,
	`\t`, `lexWhitespace`,
	`\r`, `lexWhitespace`,
	`\n`, `lexWhitespace`,
	`--`, `lexComment`,
	];

/// Token ID type for the D lexer.
public alias IdType = TokenIdType!(operators, dynamicTokens, keywords);

/**
 * Function used for converting an IdType to a string.
 *
 * Examples:
 * ---
 * IdType c = tok!"case";
 * assert (str(c) == "case");
 * ---
 */
public alias str = tokenStringRepresentation!(IdType, operators, dynamicTokens, keywords);

/**
 * Template used to refer to D token types.
 *
 * See the $(B operators), $(B keywords), and $(B dynamicTokens) enums for
 * values that can be passed to this template.
 * Example:
 * ---
 * import std.d.lexer;
 * IdType t = tok!"floatLiteral";
 * ---
 */
public template tok(string token)
{
	alias tok = TokenId!(IdType, operators, dynamicTokens, keywords, token);
}

private enum extraFields = q{
	string comment;
	string trailingComment;

	int opCmp(size_t i) const pure nothrow @safe {
		if (index < i) return -1;
		if (index > i) return 1;
		return 0;
	}

	int opCmp(ref const typeof(this) other) const pure nothrow @safe {
		return opCmp(other.index);
	}
};

/// The token type in the D lexer
public alias Token = lexer.TokenStructure!(IdType, extraFields);

/**
 * Lexer configuration struct
 */
public struct LexerConfig
{
	string fileName;
}

/**
 * Returns: an array of tokens lexed from the given source code to the output range. All
 * whitespace tokens are skipped and comments are attached to the token nearest
 * to them.
 */
const(Token)[] getTokensForParser(ubyte[] sourceCode, const LexerConfig config,
								  StringCache* cache)
{
//	import std.stdio;
	enum CommentType : ubyte
	{
		notDoc,
		line,
		block
	}

	static CommentType commentType(string comment) pure nothrow @safe
	{
		if (comment.length < 3)
			return CommentType.notDoc;
		if (comment[0 ..3] == "///")
			return CommentType.line;
		if (comment[0 ..3] == "/++" || comment[0 ..3] == "/**")
			return CommentType.block;
		return CommentType.notDoc;
	}

	auto output = appender!(typeof(return))();
	auto lexer = AdaLexer(sourceCode, config, cache);
	string blockComment;
	size_t tokenCount;
	while (!lexer.empty)
	{
		switch (lexer.front.type)
		{
			case tok!"whitespace":
				lexer.popFront();
			break;
			case tok!"comment":
				final switch (commentType(lexer.front.text))
			{
				case CommentType.block:
					blockComment = lexer.front.text;
					lexer.popFront();
					break;
				case CommentType.line:
					if (tokenCount > 0 && lexer.front.line == output.data[tokenCount - 1].line)
					{
						// writeln("attaching comment");
						(cast() output.data[tokenCount - 1]).trailingComment = lexer.front.text;
					}
					else
					{
						blockComment = cache.intern(blockComment.length == 0 ? lexer.front.text
													: blockComment ~ "\n" ~ lexer.front.text);
					}
					lexer.popFront();
					break;
				case CommentType.notDoc:
					lexer.popFront();
					break;
			}
				break;
			default:
				Token t = lexer.front;
				lexer.popFront();
				tokenCount++;
				t.comment = blockComment;
				blockComment = null;
				output.put(t);
				break;
		}
	}

	return output.data;
}

/**
 * The Ada lexer.
 */
public struct AdaLexer
{
	import core.vararg;

	mixin Lexer!(Token, lexIdentifier, isSeparating, operators, dynamicTokens,
				 keywords, pseudoTokenHandlers);

	@disable this();

	/**
	 * Params:
	 *	 range = the bytes that compose the source code that will be lexed.
	 *	 config = the lexer configuration to use.
	 *	 cache = the string interning cache for de-duplicating identifiers and
	 *		 other token text.
	 */
	this(ubyte[] range, const LexerConfig config, StringCache* cache)
	{
		this.range = LexerRange(range);
		this.config = config;
		this.cache = cache;
		popFront();
	}

	public void popFront() pure
	{
		_popFront();
	}

	bool isWhitespace() pure const nothrow
	{
		switch (range.front)
		{
			case ' ':
			case '\r':
			case '\n':
			case '\t':
				return true;
			case 0xe2:
				auto peek = range.peek(2);
				return peek.length == 2
				&& peek[0] == 0x80
				&& (peek[1] == 0xa8 || peek[1] == 0xa9);
			default:
				return false;
		}
	}

	void popFrontWhitespaceAware() pure nothrow
	{
		switch (range.front)
		{
			case '\r':
				range.popFront();
				if (!range.empty && range.front == '\n')
				{
					range.popFront();
					range.incrementLine();
				}
				else
				range.incrementLine();
				return;
			case '\n':
				range.popFront();
				range.incrementLine();
				return;
			case 0xe2:
				auto lookahead = range.peek(3);
				if (lookahead.length == 3 && lookahead[1] == 0x80
					&& (lookahead[2] == 0xa8 || lookahead[2] == 0xa9))
				{
					range.popFront();
					range.popFront();
					range.popFront();
					range.incrementLine();
					return;
				}
				else
				{
					range.popFront();
					return;
				}
			default:
				range.popFront();
				return;
		}
	}

	/// https://en.wikibooks.org/wiki/Ada_Programming/Lexical_elements#String_literals
	Token lexStringLiteral() pure nothrow @safe
	{
		mixin (tokenStart);
		ubyte quote = range.front;
		range.popFront();
		while (true)
		{
			if (range.empty)
				return Token(tok!"", null, 0, 0, 0);
			if (range.front == '\\')
			{
				range.popFront();
				if (range.empty)
					return Token(tok!"", null, 0, 0, 0);
				range.popFront();
			}
			else if (range.front == quote)
			{
				range.popFront();
				break;
			}
			else
			range.popFront();
		}
		return Token(tok!"string", cache.intern(range.slice(mark)), line,
					 column, index);
	}

	Token lexWhitespace() pure nothrow @safe
	{
		import std.ascii: isWhite;
		mixin (tokenStart);
		while (!range.empty && isWhite(range.front))
			range.popFront();
		string text = cache.intern(range.slice(mark));
		return Token(tok!"whitespace", text, line, column, index);
	}

	void lexExponent() pure nothrow @safe
	{
		range.popFront();
		bool foundSign = false;
		bool foundDigit = false;
		while (!range.empty)
		{
			switch (range.front)
			{
				case '-':
				case '+':
					if (foundSign)
						return;
					foundSign = true;
					range.popFront();
					break;
				case '0': .. case '9':
					foundDigit = true;
					range.popFront();
					break;
				default:
					return;
			}
		}
	}

	Token lexNumber() pure nothrow
	{
		mixin (tokenStart);
		bool foundDot = range.front == '.';
		if (foundDot)
			range.popFront();
	decimalLoop: while (!range.empty)
		{
			switch (range.front)
			{
				case '0': .. case '9':
					range.popFront();
					break;
				case 'e':
				case 'E':
					lexExponent();
					break decimalLoop;
				case '.':
					if (foundDot || !range.canPeek(1) || range.peekAt(1) == '.')
						break decimalLoop;
					else
					{
						// The following bit of silliness tries to tell the
						// difference between "int dot identifier" and
						// "double identifier".
						if (range.canPeek(1))
						{
							switch (range.peekAt(1))
							{
								case '0': .. case '9':
									goto doubleLiteral;
								default:
									break decimalLoop;
							}
						}
						else
						{
						doubleLiteral:
							range.popFront();
							foundDot = true;
						}
					}
					break;
				default:
					break decimalLoop;
			}
		}
		return Token(tok!"number", cache.intern(range.slice(mark)),
					 line, column, index);
	}

	Token lexComment() pure
	{
		mixin (tokenStart);
		IdType type = tok!"comment";
		range.popFrontN(2);
		while (!range.empty)
		{
			if (range.front == '*')
			{
				range.popFront();
				if (!range.empty && range.front == '/')
				{
					range.popFront();
					break;
				}
			}
			else
			popFrontWhitespaceAware();
		}
	end:
		return Token(type, cache.intern(range.slice(mark)), line, column,
					 index);
	}

	Token lexSlashSlashComment() pure nothrow
	{
		mixin (tokenStart);
		IdType type = tok!"comment";
		range.popFrontN(2);
		while (!range.empty)
		{
			if (range.front == '\r' || range.front == '\n')
				break;
			range.popFront();
		}
	end:
		return Token(type, cache.intern(range.slice(mark)), line, column,
					 index);
	}

	Token lexIdentifier() pure nothrow
	{
		import std.stdio;
		mixin (tokenStart);
		uint hash = 0;
		if (isSeparating(0) || range.empty)
		{
			error("Invalid identifier");
			range.popFront();
		}
		while (!range.empty && !isSeparating(0))
		{
			hash = StringCache.hashStep(range.front, hash);
			range.popFront();
		}
		return Token(tok!"identifier", cache.intern(range.slice(mark), hash), line,
					 column, index);
	}

	bool isNewline() pure @safe nothrow
	{
		if (range.front == '\n') return true;
		if (range.front == '\r') return true;
		return (range.front & 0x80) && range.canPeek(2)
		&& (range.peek(2) == "\u2028" || range.peek(2) == "\u2029");
	}

	bool isSeparating(size_t offset) pure nothrow @safe
	{
		if (!range.canPeek(offset)) return true;
		auto c = range.peekAt(offset);
		if (c >= 'A' && c <= 'Z') return false;
		if (c >= 'a' && c <= 'z') return false;
		if (c <= 0x2f) return true;
		if (c >= ':' && c <= '@') return true;
		if (c >= '[' && c <= '^') return true;
		if (c >= '{' && c <= '~') return true;
		if (c == '`') return true;
		if (c & 0x80)
		{
			auto r = range;
			range.popFrontN(offset);
			return (r.canPeek(2) && (r.peek(2) == "\u2028"
									 || r.peek(2) == "\u2029"));
		}
		return false;
	}

	enum tokenStart = q{
		size_t index = range.index;
		size_t column = range.column;
		size_t line = range.line;
		auto mark = range.mark();
	};

	void error(string message) pure nothrow @safe
	{
		messages ~= Message(range.line, range.column, message, true);
	}

	void warning(string message) pure nothrow @safe
	{
		messages ~= Message(range.line, range.column, message, false);
		assert (messages.length > 0);
	}

	struct Message
	{
		size_t line;
		size_t column;
		string message;
		bool isError;
	}

	Message[] messages;
	StringCache* cache;
	LexerConfig config;
}

public auto byToken(ubyte[] range)
{
	LexerConfig config;
	StringCache* cache = new StringCache(StringCache.defaultBucketCount);
	return AdaLexer(range, config, cache);
}

public auto byToken(ubyte[] range, StringCache* cache)
{
	LexerConfig config;
	return AdaLexer(range, config, cache);
}

public auto byToken(ubyte[] range, const LexerConfig config, StringCache* cache)
{
	return AdaLexer(range, config, cache);
}

unittest {
	assert(getTokensForParser(cast(ubyte[])`X;`, LexerConfig(), new StringCache(StringCache.defaultBucketCount))
		   .map!`a.type`()
		   .equal([tok!`identifier`,
				   tok!`;`]));
}

unittest {
	assert(getTokensForParser(cast(ubyte[])`x = "a";`, LexerConfig(), new StringCache(StringCache.defaultBucketCount))
		   .map!`a.type`()
		   .equal([tok!`identifier`,
				   tok!`=`,
				   tok!`string`,
				   tok!`;`]));
}
