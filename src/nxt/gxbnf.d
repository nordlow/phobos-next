/** Lexer/Parser Generator for ANTLR (G, G2, G4) and (E)BNF grammars.

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

    TODO:

    - Should be allowed instead of warning:

    grammars-v4/lua/Lua.g4(329,5): Warning: missing left-hand side, token (leftParen) at offset 5967

    - Parallelize grammar parsing and generation of parser files using https://dlang.org/phobos/std_parallelism.html#.parallel
      After that compilation of parser files should grouped into CPU-count number of groups.

    - Use: https://forum.dlang.org/post/zcvjwdetohmklaxriswk@forum.dlang.org

    - Use: `nxt.git` to scan parsing examples in `grammars-v4`

    - Rewriting (X+)? as X* in ANTLR grammars and commit to grammars-v4. See https://stackoverflow.com/questions/64706408/rewriting-x-as-x-in-antlr-grammars

    - Add errors for missing symbols during code generation

    - Warng about string literals, such as str(`...`), that are equal to tokens such `ELLIPSIS` in `Python3.g4`

    - Make `Rule.top` be of type `Matcher` and make
      - `dcharCountSpan` and
      - `toMatchInSource`
      members of `Matcher`.
      - Remove `Symbol.toMatchInSource`

    - Set `dcharCountSpan` internally upon construction

    - Support `tokens { INDENT_WS, DEDENT_WS, LINE_BREAK_WS }` to get
      Python3.g4` with TOK.whitespaceIndent, whitespaceDedent, whitespaceLineBreak useWhitespaceClassesFlag
      See: https://stackoverflow.com/questions/8642154/antlr-what-is-simpliest-way-to-realize-python-like-indent-depending-grammar

    - unicode regular expressions.
      Use https://www.regular-expressions.info/unicode.html
      Use https://forum.dlang.org/post/rsmlqfwowpnggwyuibok@forum.dlang.org

    - Rule[Input] RulesByLiteralPrefix
    - Use to detect conflicting rules with `import` and `tokenVocab`

    - Ask on forums for AST node allocation patterns. Use region allocator of
      immutable. Size can be predicate.

    - `not(...)`'s implementation needs to be adjusted. often used in conjunction with `altN`?

    - Use `DETECT` upper-case lexer rules LexerRule

    - handle all TODO's in `makeRule`

    - Move parserSourceBegin to gxbnf_rdbase.d

    - Use `TOK.tokenSpecOptions` in parsing. Ignored for now.

    - Add properties for uint, uint lengthRng()
    - Sort `AltM` subs by descending minLength

    - Deal with differences between `import` and `tokenVocab`.
      See: https://stackoverflow.com/questions/28829049/antlr4-any-difference-between-import-and-tokenvocab

    - Detect indirect mutual left-recursion. How? Simple-way in generated
      parsers: enters a rule again without offset change.

    - non-pure diagnostics functions

    - Warn about `options{greedy=false;}:` and advice to replace with non-greedy variants
    - Warn about `options{greedy=true;}:` being deprecated

    - Display column range for tokens in messages. Use `head.input.length`.
      Requires updating FlyCheck.
      See: `-fdiagnostics-print-source-range-info` at https://clang.llvm.org/docs/UsersManual.html.
      See: https://clang.llvm.org/diagnostics.html
      Use GNU-style formatting such as: fix-it:"test.c":{45:3-45:21}:"gtk_widget_show_all".

    - Use a region allocator on top of the GC to pre-allocate the
      nodes. Maybe one region for each file. Calculate the region size from lexer
      statistics (number of operators, symbols and literals).

    - Emacs click on link in `compilation-mode` doesn't navigate to correct offset on lines containing tabs before offset

    - If performance is needed:
    - Avoid casts and instead compare against `head.tok` for `isA!NodeType`
    - use `RuleAltN(uint n)` in `makeAlt`
    - use `SeqN(uint n)` in `makeSeq`
*/
module nxt.gxbnf;

version = show;
version = Do_Inline;

enum useStaticTempArrays = false; ///< Use fixed-size (statically allocated) sequence and alternative buffers.

import core.lifetime : move;
import core.stdc.stdio : putchar, printf;

import std.conv : to;
import std.algorithm.comparison : min, max;

// `d-deps.el` requires these to be at the top:
import nxt.line_column : offsetLineColumn;
import nxt.fixed_array : FixedArray;
import nxt.dynamic_array : DynamicArray;
import nxt.file_ex : rawReadPath;
import nxt.array_algorithm : startsWith, endsWith, endsWithEither, skipOver, skipOverBack, skipOverAround, canFind, indexOf, indexOfEither;
import nxt.conv_ex : toDefaulted;
import nxt.dbgio;

import std.stdio : File, stdout, write, writeln;

@safe:

alias Input = string;      ///< Grammar input source.
alias Output = DynamicArray!char; ///< Generated parser output source.

alias RulesByName = Rule[Input];

enum matcherFunctionNamePrefix = `m__`;

///< Token kind. TODO: make this a string type like with std.experimental.lexer
enum TOK
{
    none,

    unknown,                    ///< Unknown

    whitespace,                 ///< Whitespace

    symbol,                     ///< Symbol
    attributeSymbol,            ///< Attribute Symbol (starting with `$`)
    actionSymbol,               ///< Action Symbol (starting with `@`)

    number,                     ///< Number

    lineComment,                ///< Single line comment
    blockComment,               ///< Multi-line (block) comment

    leftParen,                  ///< Left parenthesis
    rightParen,                 ///< Right parenthesis

    action,                     ///< Code block

    brackets,                   ///< Alternatives within '[' ... ']'

    literal,                    ///< Text literal, single or double quoted

    colon,                      ///< Colon `:`
    semicolon,                  ///< Semicolon `;`
    hash,                       ///< Hash `#`
    labelAssignment,            ///< Label assignment `=`
    listLabelAssignment,        ///< List label assignment `+=`

    qmark,                      ///< Greedy optional or semantic predicate (`?`)
    qmarkQmark,                 ///< Non-Greedy optional (`??`)

    star,                       ///< Greedy zero or more (`*`)
    starQmark,                  ///< Non-Greedy Zero or more (`*?`)

    plus,                       ///< Greedy one or more (`+`)
    plusQmark,                  ///< Non-Greedy One or more (`+?`)

    pipe,                       ///< Alternative (`|`)
    tilde,                      ///< Match negation (`~`)
    lt,                         ///< `<`
    gt,                         ///< `>`
    comma,                      ///< `.`
    exclamation,                ///< Exclude from AST (`!`)
    rootNode,                   ///< Root node (`^`)
    wildcard,                   ///< `.`
    dotdot,                     ///< `..`

    rewrite,                    ///< Rewrite rule (`->`)

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

    _error,                     ///< Error token
}

/// Gx rule.
struct Token
{
@safe pure nothrow:
    this(in TOK tok, Input input = null) @nogc
    {
        this.tok = tok;
        this.input = input;
    }
    Input input;
    TOK tok;
}

static bool isSymbolStart(in dchar ch) pure nothrow @safe @nogc
{
    import std.uni : isAlpha;
    return (ch.isAlpha ||
            ch == '_' ||
            ch == '$' ||
            ch == '@');
}

/** Gx lexer for all version ANTLR grammsrs (`.g`, `.g2`, `.g4`).
 *
 * See_Also: `ANTLRv4Lexer.g4`
 */
struct GxLexer
{
    import std.algorithm.comparison : among;

@safe pure:

    this(const Input input,
         const string path = null,
         in bool includeComments = false,
         in bool includeWhitespace = false)
    {
        _input = input;
        this.path = path;

        import std.exception : enforce;
        import nxt.parsing : isNullTerminated;
        enforce(_input.isNullTerminated, "Input isn't null-terminated"); // input cannot be trusted

        _includeComments = includeComments;
        _includeWhitespace = includeWhitespace;

        nextFront();
    }

    @disable this(this);

    @property bool empty() const nothrow scope @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        return _endOfFile;
    }

    inout(Token) front() inout scope return nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        assert(!empty);
        return _token;
    }

    void popFront() scope nothrow
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        assert(!empty);
        nextFront();
    }

    void frontEnforce(in TOK tok, const scope Input msg = "") nothrow
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        if (front.tok != tok)
            errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
    }

    void popFrontEnforce(in TOK tok, const scope Input msg) nothrow
    {
        version(D_Coverage) {} else version(LDC) version(Do_Inline) pragma(inline, true);
        if (frontPop().tok != tok)
            errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
    }

    Token frontPopEnforce(in TOK tok, const scope Input msg = "") nothrow
    {
        version(D_Coverage) {} else version(LDC) version(Do_Inline) pragma(inline, true);
        const result = frontPop();
        if (result.tok != tok)
            errorAtFront(msg ~ ", expected `TOK." ~ tok.toDefaulted!string(null) ~ "`");
        return result;
    }

    Token frontPop() scope return nothrow
    {
        version(D_Coverage) {} else version(LDC) version(Do_Inline) pragma(inline, true);
        const result = front;
        popFront();
        return result;
    }

    Token skipOverToken(Token token) scope return nothrow
    {
        if (front == token)
            return frontPop();
        return typeof(return).init;
    }

    Token skipOverTOK(in TOK tok) scope return nothrow
    {
        if (front.tok == tok)
            return frontPop();
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

    /// Peek next `char` in input.
    dchar peek0() const scope nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        return _input[_offset]; // TODO: decode `dchar`
    }

    /// Peek next next `char` in input.
    dchar peek1() const scope nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        return _input[_offset + 1]; // TODO: decode `dchar`
    }

    /// Peek `n`-th next `char` in input.
    dchar peekN(in size_t n) const scope nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        return _input[_offset + n]; // TODO: decode `dchar`
    }

    /// Drop next byte in input.
    void drop1() nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        _offset += 1;
    }

    /// Drop next `n` bytes in input.
    void dropN(in size_t n) nothrow @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        _offset += n;           // TODO: decode `dchar`
    }

    /// Skip over `n` bytes in input.
    Input skipOverN(in size_t n) return nothrow @nogc
    {
        version(D_Coverage) {} else pragma(inline);
        const part = _input[_offset .. _offset + n]; // TODO: decode `dchar`
        dropN(n);
        return part;
    }

    /// Skip over next `char`.
    Input skipOver1() return nothrow @nogc
    {
        version(D_Coverage) {} else pragma(inline);
        return _input[_offset .. ++_offset]; // TODO: decode `dchar`
    }

    /// Skip over next two `char`s.
    Input skipOver2() return nothrow @nogc
    {
        version(D_Coverage) {} else pragma(inline);
        return _input[_offset .. (_offset += 2)]; // TODO: decode `dchar`
    }

    /// Skip line comment.
    void skipLineComment() scope nothrow @nogc
    {
        while (!peek0().among!('\0', endOfLineChars))
            _offset += 1;       // TODO: decode `dchar`
    }

    /// Skip line comment.
    Input getLineComment() return nothrow @nogc
    {
        size_t i;
        while (!peekN(i).among!('\0', endOfLineChars))
            i += 1;                // TODO: decode `dchar`
        return skipOverN(i);    // TODO: decode `dchar`
    }

    /// Skip block comment.
    void skipBlockComment() scope nothrow
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

    /// Get symbol.
    Input getSymbol() return nothrow @nogc
    {
        import std.uni : isAlphaNum; // TODO: decode `dchar`
        size_t i;
        const bool attributeFlag = peek0() == '@';
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

        if (peekN(j) == '=')         // label assignment
            return skipOverN(j + 1);
        else if (peekN(j) == '+' &&
                 peekN(j + 1) == '=') // list label assignment
            return skipOverN(j + 2);
        else
            return skipOverN(i);
    }

    /// Get number.
    Input getNumber() return nothrow @nogc
    {
        import std.ascii : isDigit;
        size_t i;
        while (peekN(i).isDigit)
            i += 1;
        return skipOverN(i);
    }

    Input getWhitespace() return nothrow @nogc
    {
        size_t i;
        while (peekN(i).among!(whiteChars)) // NOTE this is faster than `src[i].isWhite`
            i += 1;
        return skipOverN(i);
    }

    bool skipOverEsc(ref size_t i) nothrow @nogc
    {
        if (peekN(i) == '\\')   // TODO: decode `dchar`
        {
            i += 1;
            if (peekN(i) == 'n')
                i += 1;            // TODO: convert to "\r"
            else if (peekN(i) == 't')
                i += 1;            // TODO: convert to "\t"
            else if (peekN(i) == 'r')
                i += 1;            // TODO: convert to ASCII "\r"
            else if (peekN(i) == ']')
                i += 1;            // TODO: convert to ASCII "]"
            else if (peekN(i) == 'u')
            {
                i += 1;
                import std.ascii : isDigit;
                while (peekN(i).isDigit)
                    i += 1;
                // TODO: convert to `dchar`
            }
            else if (peekN(i) == '\0')
                errorAtIndex("unterminated escape sequence at end of file");
            else
                i += 1;
            return true;
        }
        return false;
    }

    Input getLiteral(dchar terminator)() return nothrow @nogc
    {
        size_t i = 1;
        while (!peekN(i).among!('\0', terminator))
            if (!skipOverEsc(i))
                i += 1;
        if (peekN(i) == '\0')
            errorAtIndex("unterminated string literal at end of file");
        return skipOverN(i + 1); // include terminator
    }

    Input getTokenSpecOptions() return nothrow @nogc
    {
        enum dchar terminator = '>';
        size_t i = 1;
        while (!peekN(i).among!('\0', terminator))
            i += 1;
        if (peekN(i) != terminator)
        {
            if (peekN(i) == '\0')
                errorAtIndex("unterminated string literal at end of file");
            else
                errorAtIndex("unterminated token spec option");
        }
        return skipOverN(i + 1); // include terminator '>'
    }

    Input getHooks() return nothrow @nogc
    {
        size_t i;
        while (!peekN(i).among!('\0', ']')) // may contain whitespace
            if (!skipOverEsc(i))
                i += 1;
        if (peekN(i) == ']') // skip ']'
            i += 1;
        return skipOverN(i);
    }

    Input getAction() return nothrow @nogc
    {
        size_t i;

        DynamicArray!char ds;   // delimiter stack

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
                    if (infoFlag)
                        infoAtIndex("line comment start", i, ds[]);
                    inLineComment = true;
                    i += 2;
                    continue;
                }
                else if (peekN(i) == '/' &&
                         peekN(i + 1) == '*')
                {
                    if (infoFlag)
                        infoAtIndex("block comment start", i, ds[]);
                    inBlockComment = true;
                    i += 2;
                    continue;
                }
                else if (peekN(i) == '{')
                {
                    if (infoFlag)
                        infoAtIndex("brace open", i, ds[]);
                    ds.put('{');
                }
                else if (peekN(i) == '}')
                {
                    if (infoFlag)
                        infoAtIndex("brace close", i, ds[]);
                    if (!ds.empty &&
                        ds.back != '{')
                        errorAtIndex("unmatched", i);
                    ds.popBack();
                }
                else if (peekN(i) == '[')
                {
                    if (infoFlag)
                        infoAtIndex("hook open", i, ds[]);
                    ds.put('[');
                }
                else if (peekN(i) == ']')
                {
                    if (infoFlag)
                        infoAtIndex("hook close", i, ds[]);
                    if (!ds.empty &&
                        ds.back != '[')
                        errorAtIndex("unmatched", i);
                    ds.popBack();
                }
                else if (peekN(i) == '(')
                {
                    if (infoFlag)
                        infoAtIndex("paren open", i, ds[]);
                    ds.put('(');
                }
                else if (peekN(i) == ')')
                {
                    if (infoFlag)
                        infoAtIndex("paren close", i, ds[]);
                    if (!ds.empty &&
                        ds.back != '(')
                        errorAtIndex("unmatched", i);
                    ds.popBack();
                }
            }

            // block comment close
            if (inBlockComment &&
                peekN(i) == '*' &&
                peekN(i + 1) == '/')
            {
                if (infoFlag)
                    infoAtIndex("block comment close", i, ds[]);
                inBlockComment = false;
                i += 2;
                continue;
            }

            // line comment close
            if (inLineComment &&
                (peekN(i) == '\n' ||
                 peekN(i) == '\r'))
            {
                if (infoFlag)
                    infoAtIndex("line comment close", i, ds[]);
                inLineComment = false;
            }

            // single-quote open/close
            if (!inBlockComment &&
                !inLineComment &&
                !inString &&
                peekN(i) == '\'')
            {
                if (!ds.empty &&
                    ds.back == '\'')
                {
                    if (infoFlag)
                        infoAtIndex("single-quote close", i, ds[]);
                    ds.popBack();
                    inChar = false;
                }
                else
                {
                    if (infoFlag)
                        infoAtIndex("single-quote open", i, ds[]);
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
                if (!ds.empty &&
                    ds.back == '"')
                {
                    if (infoFlag)
                        infoAtIndex("double-quote close", i, ds[]);
                    ds.popBack();
                    inString = false;
                }
                else
                {
                    if (infoFlag)
                        infoAtIndex("doubl-quote open", i, ds[]);
                    ds.put('"');
                    inString = true;
                }
            }

            i += 1;

            if (ds.length == 0)
                break;
        }

        if (inBlockComment)
            errorAtIndex("unterminated block comment", i);
        if (ds.length != 0)
            errorAtIndex("unbalanced code block", i);

        return skipOverN(i);
    }

    void nextFront() scope nothrow @trusted // TODO: remove `@trusted`
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
                errorAtIndex("unexpected character");
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
                errorAtIndex("unexpected character");
            break;
        case '0':
            ..
        case '9':
            _token = Token(TOK.number, getNumber());
            break;
        case ' ':
        case '\t':
        case '\n':
        case '\v':
        case '\r':
        case '\f':
            // TODO: extend to std.uni
            // import std.uni : isWhite;
            // assert(peek0().isWhite);
            const ws = getWhitespace();
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
                const symbol = getSymbol();
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
                errorAtIndex("unexpected character");
            }
        }
    }

    void infoAtFront(const scope Input msg) const nothrow scope
    {
        messageAtToken(front, "Info", msg);
    }

    void warningAtFront(const scope Input msg) const nothrow scope
    {
        messageAtToken(front, "Warning", msg);
    }

    void errorAtFront(const scope Input msg) const nothrow scope
    {
        messageAtToken(front, "Error", msg);
        assert(false);          ///< TODO: propagate error instead of assert
    }

    private void infoAtToken(const scope Token token,
                             const scope Input msg) const nothrow scope
    {
        messageAtToken(token, "Info", msg);
    }

    private void warningAtToken(const scope Token token,
                                const scope Input msg) const nothrow scope
    {
        messageAtToken(token, "Warning", msg);
    }

    private void errorAtToken(const scope Token token,
                              const scope Input msg) const nothrow scope
    {
        messageAtToken(token, "Error", msg);
        assert(false);          ///< TODO: propagate error instead of assert
    }

    private void messageAtToken(const scope Token token,
                                const scope string tag,
                                const scope Input msg) const @trusted nothrow scope
    {
        const offset = (_token.input.ptr && _input.ptr) ? token.input.ptr - _input.ptr : 0; // unsafe
        const lc = offsetLineColumn(_input, offset);
        import nxt.conv_ex : toDefaulted;
        const string toks = token.tok.toDefaulted!string("unknown");
        debug printf("%.*s(%u,%u): %s: %.*s, token `%.*s` (%.*s) at offset %llu\n",
                     cast(int)path.length, path.ptr,
                     lc.line + 1, lc.column + 1,
                     tag.ptr,
                     cast(int)msg.length, msg.ptr,
                     cast(int)token.input.length, token.input.ptr,
                     cast(int)toks.length, toks.ptr,
                     offset);
    }

    // TODO: into warning(const char* format...) like in `dmd` and put in `nxt.parsing` and reuse here and in lispy.d
    void errorAtIndex(const scope Input msg,
                      in size_t i = 0) const nothrow @nogc scope
    {
        messageAtIndex("Error", msg, i);
        assert(false);          ///< TODO: propagate error instead of assert
    }

    void warningAtIndex(const scope Input msg,
                        in size_t i = 0) const nothrow @nogc scope
    {
        messageAtIndex("Warning", msg, i);
    }

    void infoAtIndex(const scope Input msg,
                     in size_t i = 0, in const(char)[] ds = null) const nothrow @nogc scope
    {
        messageAtIndex("Info", msg, i, ds);
    }

    void messageAtIndex(const scope string tag,
                        const scope Input msg,
                        in size_t i = 0,
                        in const(char)[] ds = null) const @trusted nothrow @nogc scope
    {
        const lc = offsetLineColumn(_input, _offset + i);
        // TODO: remove printf
        debug printf("%.*s(%u,%u): %s: %.*s at offset %llu being char `%c` ds:`%.*s`\n",
                     cast(int)path.length, path.ptr,
                     lc.line + 1, lc.column + 1,
                     tag.ptr,
                     cast(int)msg.length, msg.ptr,
                     _offset + i,
                     peekN(i),
                     cast(int)ds.length, ds.ptr);
    }

private:
    size_t _offset;             // current offset in `_input`
    const Input _input;         ///< Input data.
    const string path;         ///< Input file (or null if in-memory).

    Token _token;
    bool _endOfFile;            // signals null terminator found
    bool _includeComments;
    bool _includeWhitespace;
    bool _includeLabelAssignment;
    bool _includeListLabelAssignment;
    bool _diagnoseLeftRecursion; ///< Diagnose left-recursion.
}

/// Node.
enum NODE
{
    grammar,                    ///< Grammar defintion (name).
    rule                        ///< Grammar rule.
}

/// Format when printing AST (nodes).
enum Layout : ubyte
{
    source,                     ///< Try to mimic original source.
    tree                        ///< Makes AST-structure clear.
}

enum indentStep = 4;        ///< Indentation size in number of spaces.

struct Format
{
    uint indentDepth;           ///< Indentation depth.
    Layout layout;
    void showIndent() @safe const nothrow @nogc
    {
        showNSpaces(indentDepth);
    }
}

void showNSpaces(uint indentDepth) @safe nothrow @nogc
{
    foreach (_; 0 .. indentDepth*indentStep)
        putchar(' ');
}

void showNSpaces(scope ref Output sink, uint n) @safe pure nothrow @nogc
{
    foreach (_; 0 .. n)
        sink.put(" ");
}

void showNIndents(scope ref Output sink, uint indentDepth) @safe pure nothrow @nogc
{
    foreach (_; 0 .. indentDepth*indentStep)
        sink.put(" ");
}

/// Put `x` indented at `indentDepth`.
void iput(T)(scope ref Output sink,
             uint indentDepth, T x) @safe pure nothrow @nogc
if (is(typeof(sink.put(x))))
{
    foreach (_; 0 .. indentDepth*indentStep)
        sink.put(" ");
    sink.put(x);
}

private void showChars(in const(char)[] chars) @trusted
{
    printf("%.*s", cast(uint)chars.length, chars.ptr);
}

private void showToken(Token token,
                       in Format fmt)
{
    fmt.showIndent();
    showChars(token.input);
}

/** Lower and upper limit of `dchar` count.
 */
struct DcharCountSpan
{
@safe pure nothrow:
    @disable this();       // be explicit for now as default init is not obvious
    static typeof(this) full() @nogc
    {
        return typeof(this)(this.lower.min,
                            this.upper.max);
    }
    this(in uint lower, in uint upper) @nogc
    {
        this.lower = lower;
        this.upper = upper;
    }
    this(in size_t lower, in size_t upper) @nogc
    {
        assert(lower <= this.lower.max);
        assert(upper <= this.upper.max);
        this.lower = cast(typeof(this.lower))lower;
        this.upper = cast(typeof(this.upper))upper;
    }
    this(in uint length) @nogc
    {
        this(length, length);
    }
    this(in size_t length) @safe pure nothrow @nogc
    {
        this(length, length);
    }
    uint lower = uint.max;
    uint upper = 0;
}

/// AST node.
private abstract class Node
{
@safe:
    abstract void show(in Format fmt = Format.init) const;
pure nothrow:
    abstract bool equals(const Node o) const @nogc;
    abstract void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const;
    this() @nogc {}
}

alias NodeArray = DynamicArray!(Node, null, uint); // `uint` capacity is enough
alias PatternArray = DynamicArray!(Pattern, null, uint); // `uint` capacity is enough

bool equalsAll(const scope Node[] a,
               const scope Node[] b) pure nothrow @nogc
{
    if (a.length != b.length)
        return false;
    foreach (const i; 0 .. a.length)
        if (!a[i].equals(b[i])) // TODO: use `.ptr` if needed
            return false;
    return true;
}

/// N-ary expression.
abstract class NaryOpPattern : Pattern
{
@safe pure nothrow:
    this(Token head, PatternArray subs) @nogc
    {
        super(head);
        this.subs = subs.move(); // TODO: remove when compiler does this for us
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
        foreach (const sub; subs)
            this.subs.put(sub);
    }
    PatternArray subs;
}

/** Sequence.
 *
 * A `Sequence` is empty in case when a rule provides an empty alternative.
 * Such cases `() | ...` should be rewritten to `(...)?` in `makeAlt`.
 */
final class SeqM : NaryOpPattern
{
@safe:
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
pure nothrow:
    this(Token head) @nogc
    {
        this.head = head;
        super(head, PatternArray.init);
    }
    this(PatternArray subs) @nogc
    {
        this.head = Token.init;
        super(Token.init, subs.move());
    }
    this(uint n)(Node[n] subs) if (n >= 2)
    {
        super(subs);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        assert(!subs.empty);
        auto lr = typeof(return)(0, uint.max);
        foreach (const sub; subs)
        {
            const sublr = sub.dcharCountSpan;
            if (lr.lower == uint.max ||
                sublr.lower == uint.max)
                lr.lower = uint.max;
            else
                lr.lower += sublr.lower;
            if (lr.upper == uint.max ||
                sublr.upper == uint.max)
                lr.upper = uint.max;
            else
                lr.upper += sublr.upper;
        }
        return lr;
    }
    const Token head;
}

Pattern makeSeq(PatternArray subs,
                const ref GxLexer lexer,
                in bool rewriteFlag = true) pure nothrow
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
    if (subs.empty)
        lexer.warningAtToken(Token(TOK.leftParen, lexer._input[0 .. 0]),
                             "empty sequence");
    return new SeqM(subs.move());
}

Pattern makeSeq(Pattern[] subs,
                const ref GxLexer lexer,
                in bool rewriteFlag = true) pure nothrow
{
    return makeSeq(PatternArray(subs), lexer, rewriteFlag);
}

Pattern makeSeq(Node[] subs,
                const ref GxLexer lexer,
                in bool rewriteFlag = true) pure nothrow
{
    return makeSeq(checkedCastSubs(subs, lexer), lexer, rewriteFlag);
}

private PatternArray checkedCastSubs(Node[] subs,
                                     const ref GxLexer lexer) pure nothrow
{
    auto psubs = typeof(return).withLength(subs.length);
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
    {
        if (auto sub_ = cast(BranchPattern)sub)
            subs_.insertBack(flattenSubs!(BranchPattern)(sub_.subs.move()));
        else
            subs_.insertBack(sub);
    }
    return subs_.move();
}

/// Rule.
class Rule : Node
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
        showChars(":\n");
        if (top)
            top.show(Format(fmt.indentDepth + 1));
        showChars(" ;\n");
    }
@safe pure nothrow:
    void diagnoseDirectLeftRecursion(const scope ref GxLexer lexer)
    {
        void checkLeft(const scope Pattern top) @safe pure nothrow
        {
            if (const alt = cast(const AltM)top) // common case
                foreach (const sub; alt.subs[]) // all alternatives
                    checkLeft(sub);
            else if (const seq = cast(const SeqM)top)
                return checkLeft(seq.subs[0]); // only first in sequence
            else if (const s = cast(const SymbolPattern)top)
                if (head.input == s.head.input)
                    lexer.warningAtToken(s.head, "left-recursion");
        }
        checkLeft(top);
    }
    this(Token head, Pattern top) @nogc
    {
        this.head = head;
        this.top = top;
    }
    override bool equals(const Node o) const @nogc
    {
        if (this is o)
            return true;
        if (const o_ = cast(const typeof(this))o)
            return head == o_.head && top.equals(o_.top);
        return false;
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        // dummy
    }
    void toMatcherInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.iput(1, `Match `);
        if (head.input != "EOF")
            sink.put(matcherFunctionNamePrefix);
        sink.put(head.input); sink.put("()\n");
        sink.iput(1, "{\n");
        import std.ascii : isUpper;
        if (head.input[0].isUpper ||
            cast(const FragmentRule)this)
        {
            sink.iput(2, "pragma(inline, true);\n");
        }
        sink.iput(2, `return`);
        if (top)
        {
            sink.put(` `);
            top.toMatchInSource(sink, parser);
        }
        else
            sink.put(` Match.zero()`);
        sink.put(";\n");
        sink.iput(1, "}\n");
    }
    @property bool isFragment() const @nogc
    {
        return false;
    }
    const Token head;           ///< Name.
    Pattern top;
}

final class FragmentRule : Rule
{
@safe pure nothrow:
    this(Token head, Pattern top) @nogc
    {
        super(head, top);
    }
    @property final override bool isFragment() const @nogc
    {
        return true;
    }
}

final class AltM : NaryOpPattern
{
@safe:
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
pure nothrow:
    this(Token head, PatternArray subs) @nogc
    {
        assert(!subs.empty);
        super(head, subs.move());
    }
    this(uint n)(Pattern[n] subs) @nogc if (n >= 2)
    {
        super(subs);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        // preprocess
        bool allSubChars = true; // true if all sub-patterns are characters
        foreach (const sub; subs)
        {
            if (const lit = cast(const StrLiteral)sub)
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
                const lsub = cast(const StrLiteral)sub;
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return dcharCountSpanOf(subs[]);
    }
}

DcharCountSpan dcharCountSpanOf(const scope Pattern[] subs) @safe pure nothrow @nogc
{
    if (subs.length == 0)
        return typeof(return)(0, 0);
    auto lr = typeof(return)(uint.max, 0);
    foreach (const sub; subs)
    {
        const sublr = sub.dcharCountSpan;
        lr.lower = min(lr.lower, sublr.lower);
        lr.upper = max(lr.upper, sublr.upper);
    }
    return lr;
}

Pattern makeAltA(Token head,
                 PatternArray subs,
                 in bool rewriteFlag = true) pure nothrow
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
                 in bool rewriteFlag = true) pure nothrow
{
    return makeAltA(head, PatternArray(subs), rewriteFlag);
}

Pattern makeAltN(uint n)(Token head,
                         Pattern[n] subs,
                         in bool rewriteFlag = true) pure nothrow
    if (n >= 2)
    {
        return makeAltA(head, PatternArray(subs), rewriteFlag);
    }

class TokenNode : Node
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
pure nothrow:
    this(Token head) @nogc
    {
        this.head = head;
    }
    override bool equals(const Node o) const @nogc
    {
        if (this is o)
            return true;
        if (const o_ = cast(const typeof(this))o)
            return head == o_.head;
        return false;
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put(`tok(`);
        sink.put(head.input[]);
        sink.put(`)`);
    }
    const Token head;
}

/// Unary match combinator.
abstract class UnaryOpPattern : Pattern
{
@safe:
    final override void show(in Format fmt = Format.init) const
    {
        putchar('(');
        sub.show(fmt);
        putchar(')');
        showToken(head, fmt);
    }
@safe pure nothrow:
    this(Token head, Pattern sub) @nogc
    {
        debug assert(head.input.ptr);
        assert(sub);
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
final class NotPattern : UnaryOpPattern
{
@safe pure nothrow:
    this(Token head, Pattern sub) @nogc
    {
        super(head, sub);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("not(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return sub.dcharCountSpan();
    }
}

/// Match (greedily) zero or one instances of type `sub`.
final class GreedyZeroOrOne : UnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("gzo(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(0, sub.dcharCountSpan.upper);
    }
}

/// Match (greedily) zero or more instances of type `sub`.
final class GreedyZeroOrMore : UnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("gzm(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return).full();
    }
}

/// Match (greedily) one or more instances of type `sub`.
final class GreedyOneOrMore : UnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("gom(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(sub.dcharCountSpan.lower,
                              typeof(return).upper.max);
    }
}

abstract class TerminatedUnaryOpPattern : UnaryOpPattern
{
@safe pure nothrow:
    this(Token head, Pattern sub, Pattern terminator = null) @nogc
    {
        debug assert(head.input.ptr);
        super(head, sub);
        this.terminator = terminator;
    }
    Pattern terminator;
}

/// Match (non-greedily) zero or one instances of type `sub`.
final class NonGreedyZeroOrOne : TerminatedUnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(0, sub.dcharCountSpan.upper);
    }
}

/// Match (non-greedily) zero or more instances of type `sub`.
final class NonGreedyZeroOrMore : TerminatedUnaryOpPattern
{
@safe pure nothrow:
    this(Token head, Pattern sub, Pattern terminator = null) @nogc
    {
        debug assert(head.input.ptr);
        super(head, sub, terminator);
    }
    this(Token head, Node sub, Pattern terminator = null) @nogc
    {
        debug assert(head.input.ptr);
        Pattern psub = cast(Pattern)sub;
        assert(psub);
        super(head, psub, terminator);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
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
        {
            parser._lexer.warningAtToken(head, "no terminator after non-greedy");
        }
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return).full();
    }
}

/// Match (non-greedily) one or more instances of type `sub`.
final class NonGreedyOneOrMore : TerminatedUnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(sub.dcharCountSpan.lower,
                              typeof(return).upper.max);
    }
}

/// Match `count` number of instances of type `sub`.
final class GreedyCount : UnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("cnt(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        const ss = sub.dcharCountSpan;
        return typeof(return)(ss.lower == uint.max ? uint.max : ss.lower * count,
                              ss.upper == uint.max ? uint.max : ss.upper * count);
    }
    ulong count;
}

final class RewriteSyntacticPredicate : UnaryOpPattern
{
@safe pure nothrow:
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
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("syn(");
        sub.toMatchInSource(sink, parser);
        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return sub.dcharCountSpan;
    }
}

final class OtherSymbol : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        if (head.input != "EOF")
            sink.put(matcherFunctionNamePrefix);
        sink.put(head.input);
        sink.put(`()`);
    }
}

final class SymbolPattern : Pattern
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        if (head.input != "EOF")
            sink.put(matcherFunctionNamePrefix);
        sink.put(head.input);
        if (parser.warnUnknownSymbolFlag &&
            head.input !in parser.rulesByName)
            parser._lexer.warningAtToken(head, "unknown symbol");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        assert(false);
        // return typeof(return).init;
    }
}

final class LeftParenSentinel : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class PipeSentinel : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class DotDotSentinel : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class TildeSentinel : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class AnyClass : Pattern
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put(`any()`);
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(1);
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

    if (x.skipOver(`0x`) ||     // optional
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
            return 0;           // string literal such as '\uD835\uDD38'
        x = x[1 .. $];      // pop front
    }

    return u;
}

abstract class Pattern : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
    abstract DcharCountSpan dcharCountSpan() const @nogc;
}

final class StrLiteral : Pattern
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        assert(head.input.length >= 2);
        assert((head.input[0] == '\'' &&
                head.input[$-1] == '\'') ||
               (head.input[0] ==  '"' &&
                head.input[$-1] ==  '"'));
        super(head);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        auto inp = unquotedInput; // skipping single-quotes
        if (inp.isASCIICharacterLiteral())
        {
            sink.put(`ch(`);
            sink.putCharLiteral(inp);
            sink.put(`)`);
        }
        else if (const uvalue = inp.isUnicodeCharacterLiteral())
        {
            if (uvalue <= 0x7f)
                sink.put(`ch(`);
            else
                sink.put(`dch(`);
            sink.putCharLiteral(inp);
            sink.put(`)`);
        }
        else
        {
            if (inp.canFind('`'))
            {
                sink.put(`str("`);
                sink.putStringLiteralDoubleQuoted(inp);
                sink.put(`")`);
            }
            else
            {
                sink.put("str(`");
                sink.putStringLiteralBackQuoted(inp);
                sink.put("`)");
            }
        }
    }
    override DcharCountSpan dcharCountSpan() const @nogc
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
            // TODO: optimize
            import std.utf : byDchar;
            import std.algorithm.searching : count;
            cnt = inp.byDchar.count;
        }
        return typeof(return)(cnt);
    }
    Input unquotedInput() const scope return @nogc
    {
        return head.input[1 .. $ - 1];
    }
}

// TODO: avoid linker error when using version defined in `nxt.string_traits`
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
            sink.put(`\"`);     // backslash doublequote in D string
        else if (i + 2 <= inp.length &&
                 inp[i .. i + 2] == `\'`)
        {
            i += 1;             // one extra char
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
            sink.put("\\`");    // backslash backquote in D raw string
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
            i += 1;             // one extra char
        }
        else
            sink.put(inp[i]);
    }
}

final class AltCharLiteral : Pattern
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        if (head.input.startsWith(`\p`) || // https://github.com/antlr/antlr4/pull/1688
            head.input.startsWith(`\P`))
        {
            sink.put(`cc!(`);
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return DcharCountSpan(1, 1);
        // if (head.input.isASCIICharacterLiteral)
        //     return DcharCountSpan(1, 1);
        // else
        //     return DcharCountSpan(0, uint.max);
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

        if (inp.length == 2)    // if ASCII
        {
            sink.put(`'\u00`);
            sink.put(inp);
            sink.put('\'');
        }
        else
        {
            sink.put(`(cast(dchar)0x`); // TODO: use `dchar(...)` for valid numbers
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
            sink.put(`\`);      // need backquoting
        sink.put(inp);
        sink.put(`'`);
    }
}

version(none)                   // TODO use
TokenNode makeLiteral(Token head) pure nothrow
{
    assert(head.input.length >= 3);
    if (head.input[1 .. $-1].isASCIICharacterLiteral)
        return new AltCharLiteral(head);
    else
        return new StrLiteral(head);
}

bool needsWrapping(const scope Node[] subs) @safe pure nothrow @nogc
{
    bool wrapFlag;
    foreach (const sub; subs)
        if (!cast(const TokenNode)sub)
            wrapFlag = true;
    return wrapFlag;
}

/// Binary pattern combinator.
abstract class BinaryOpPattern : Pattern
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        fmt.showIndent();
        subs[0].show(fmt);
        putchar(' ');
        showChars(head.input);
        putchar(' ');
        subs[1].show(fmt);
    }
@safe pure nothrow:
    this(Token head, Pattern[2] subs) @nogc
    {
        assert(subs[0]);
        assert(subs[1]);
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
final class Range : BinaryOpPattern
{
@safe:
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
pure nothrow:
    this(Token head, Pattern[2] limits) @nogc
    {
        assert(limits[0]);
        assert(limits[1]);
        super(head, limits);
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
        sink.put("rng(");

        if (const lower = cast(const StrLiteral)subs[0])
            sink.putCharLiteral(lower.unquotedInput);
        else if (const lower = cast(const AltCharLiteral)subs[0])
            sink.putCharLiteral(lower.head.input);
        else
        {
            debug writeln("handle sub[0] of type ", typeid(subs[0]).name);
            debug subs[0].show();
            assert(false);
        }

        sink.put(",");

        if (const upper = cast(const StrLiteral)subs[1])
            sink.putCharLiteral(upper.unquotedInput);
        else if (const upper = cast(const AltCharLiteral)subs[1])
            sink.putCharLiteral(upper.head.input);
        else
            assert(false);

        sink.put(")");
    }
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return dcharCountSpanOf(subs[]);
    }
}

Pattern parseCharAltM(const CharAltM alt,
                      const scope ref GxLexer lexer) @safe pure nothrow
{
    const Input inp = alt.unquotedInput;

    bool inRange;
    PatternArray subs;
    for (size_t i; i < inp.length;)
    {
        Input inpi;

        if (inp[i] == '-' &&
            !subs.empty)        // not first character
        {
            inRange = true;
            i += 1;
            continue;
        }

        if (inp[i] == '\\')
        {
            i += 1;             // skip '\\'
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

        auto lit = new AltCharLiteral(Token(TOK.literal, inpi));
        if (inRange)
            subs.insertBack(new Range(Token.init, [subs.backPop(), lit]));
        else
            subs.insertBack(lit);
        inRange = false;
    }
    return makeAltA(alt.head, subs.move()); // potentially flatten
}

final class CharAltM : Pattern
{
@safe pure nothrow:

    this(Token head) @nogc
    {
        super(head);
    }

    Input unquotedInput() const @nogc
    {
        Input inp = head.input;
        assert(inp.skipOverAround('[', ']')); // trim
        return inp;
    }

    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
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

            sink.put('\'');     // prefix

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
                            parser._lexer.errorAtToken(Token(head.tok, inp[i + 1 .. $]), "incorrect unicode escape sequence");
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

            sink.put('\'');     // suffix
        }
        sink.put(")()");
    }

    private Output toMatchRangeInSource(Input input,
                                        out size_t altCount) const // alt count
    {
        typeof(return) sink;       // argument sink
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
                    i += 1;                 // skip '\\'
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
    override DcharCountSpan dcharCountSpan() const @nogc
    {
        return typeof(return)(1);
    }
}

final class LineComment : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class BlockComment : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

/// Grammar named `name`.
final class Grammar : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
        putchar(' ');
        showChars(name);
        showChars(";\n");
    }
pure nothrow:
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
final class LexerGrammar : TokenNode
{
@safe pure nothrow:
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
final class ParserGrammar : TokenNode
{
@safe pure nothrow:
    this(Token head, Input name) @nogc
    {
        super(head);
        this.name = name;
    }
    Input name;
}

/// Import of `modules`.
final class Import : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
        putchar(' ');
        foreach (const i, const m ; modules)
        {
            if (i)
                putchar(',');
            showChars(m);
        }
        putchar(';');
        putchar('\n');
    }
pure nothrow:
    this(Token head, DynamicArray!(Input) modules) @nogc
    {
        super(head);
        move(modules, this.modules);
    }
    DynamicArray!(Input) modules;
}

final class Mode : TokenNode
{
@safe pure nothrow:
    this(Token head, Input name) @nogc
    {
        super(head);
        this.name = name;
    }
    Input name;
}

final class Options : TokenNode
{
@safe pure nothrow:
    this(Token head, Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    Input name;
    Token code;
}

final class Header : TokenNode
{
@safe pure nothrow:
    this(Token head, Token name, Token code) @nogc
    {
        super(head);
        this.name = name;
        this.code = code;
    }
    Token name;
    Token code;
}

final class ScopeSymbolAction : TokenNode
{
@safe pure nothrow:
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

final class ScopeSymbol : TokenNode
{
@safe pure nothrow:
    this(Token head,
         Input name) @nogc
    {
        super(head);
        this.name = name;
    }
    Input name;
}

final class ScopeAction : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
pure nothrow:
    this(Token head,
         Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    Token code;
}

final class AttributeSymbol : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
pure nothrow:
    this(Token head, Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    Token code;
}

final class Action : TokenNode
{
@safe pure nothrow:
    this(Token head) @nogc
    {
        super(head);
    }
}

final class ActionSymbol : TokenNode
{
@safe:
    override void show(in Format fmt = Format.init) const
    {
        showToken(head, fmt);
    }
pure nothrow:
    this(Token head, Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    Token code;
}

final class Channels : TokenNode
{
@safe pure nothrow:
    this(Token head, Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    Token code;
}

final class Tokens : TokenNode
{
@safe pure nothrow:
    this(Token head, Token code) @nogc
    {
        super(head);
        this.code = code;
    }
    override void toMatchInSource(scope ref Output sink, const scope ref GxParserByStatement parser) const
    {
    }
    Token code;
}

final class Class : TokenNode
{
@safe pure nothrow:
    this(Token head, Input name, Input baseName) @nogc
    {
        super(head);
        this.name = name;
        this.baseName = baseName;
    }
    Input name;
    Input baseName;             ///< Base class name.
}

alias Imports = DynamicArray!(Import, null, uint);
alias Rules = DynamicArray!(Rule, null, uint);

/** Gx parser with range interface over all statements.
 *
 * See: `ANTLRv4Parser.g4`
 */
struct GxParserByStatement
{
@safe pure:
    this(Input input,
         const string path = null,
         in bool includeComments = false)
    {
        _lexer = GxLexer(input, path, includeComments);
        if (!_lexer.empty)
            _front = nextFront();
    }

    @property bool empty() const nothrow scope @nogc
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        return _front is null;
    }

    inout(Node) front() inout scope return
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        assert(!empty);
        return _front;
    }

    void popFront()
    {
        version(D_Coverage) {} else version(Do_Inline) pragma(inline, true);
        assert(!empty);
        if (_lexer.empty)
            _front = null;      // make `this` empty
        else
            _front = nextFront();
    }

    private Rule makeRule(Token name,
                          in bool isFragment,
                          ActionSymbol actionSymbol = null,
                          Action action = null)
    {
        _lexer.popFrontEnforce(TOK.colon, "no colon");

        static if (useStaticTempArrays)
            FixedArray!(Pattern, 100) alts;
        else
            PatternArray alts;

        while (_lexer.front.tok != TOK.semicolon)
        {
            size_t parentDepth = 0;

            // temporary node sequence stack
            static if (useStaticTempArrays)
                FixedArray!(Node, 70) tseq; // doesn't speed up that much
            else
                NodeArray tseq;

            void seqPutCheck(Node last)
            {
                if (last is null)
                    return _lexer.warningAtToken(name, "empty sequence");
                if (!_lexer.empty &&
                    _lexer.front.tok == TOK.dotdot)
                    return tseq.put(last); // ... has higher prescedence
                if (!tseq.empty)
                {
                    if (auto dotdot = cast(DotDotSentinel)tseq.back) // binary operator
                    {
                        tseq.popBack(); // pop `DotDotSentinel`
                        return seqPutCheck(new Range(dotdot.head,
                                                     [cast(Pattern)tseq.backPop(), cast(Pattern)last]));
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
                // TODO: use static array with length being number of tokens till `TOK.pipe`
                const head = _lexer.frontPop();

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
                    tseq.insertBack(nseq);                 // put it back
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
                        seqPutCheck(new SymbolPattern(head));
                    }
                    break;
                case TOK.literal:
                    seqPutCheck(new StrLiteral(head));
                    break;
                case TOK.qmark:
                    if (tseq.empty)
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
                        node = new GreedyZeroOrOne(head, tseq.backPop());
                    seqPutCheck(node);
                    break;
                case TOK.star:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new GreedyZeroOrMore(head, tseq.backPop()));
                    break;
                case TOK.plus:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new GreedyOneOrMore(head, tseq.backPop()));
                    break;
                case TOK.qmarkQmark:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new NonGreedyZeroOrOne(head, tseq.backPop()));
                    break;
                case TOK.starQmark:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new NonGreedyZeroOrMore(head, tseq.backPop()));
                    break;
                case TOK.plusQmark:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new NonGreedyOneOrMore(head, tseq.backPop()));
                    break;
                case TOK.rewriteSyntacticPredicate:
                    if (tseq.empty)
                        _lexer.errorAtToken(head, "missing left-hand side");
                    seqPutCheck(new RewriteSyntacticPredicate(head, tseq.backPop()));
                    break;
                case TOK.tilde:
                    tseq.put(new TildeSentinel(head));
                    break;
                case TOK.pipe:
                    if (tseq.empty)
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
                    while (_lexer.front.tok != TOK.pipe &&
                           _lexer.front.tok != TOK.semicolon)
                        _lexer.popFront(); // ignore for now
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
                    LeftParenSentinel ss;    // left parent index Symbol
                    foreach_reverse (const i, Node node; tseq[])
                    {
                        if (auto lp = cast(LeftParenSentinel)node)
                        {
                            si = i;
                            ss = lp;
                            break;
                        }
                    }

                    PatternArray asubs; // TODO: use stack allocation of length tseq[si .. $].length - number of `PipeSentinel`s
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
                    if (asubs.empty)
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
                    _lexer.skipOverTOK(TOK.qmark); // TODO: handle in a more generic way
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
                alts.put(makeSeq(tseq[], _lexer)); // TODO: use `tseq.move()` when tseq is a `PatternArray`
                tseq.clear();
            }
            if (_lexer.front.tok == TOK.pipe)
                _lexer.popFront(); // skip terminator
        }

        _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");

        // needed for ANTLRv2.g2:
        if (!_lexer.empty)
        {
            // if (_lexer.front == Token(TOK.symbol, "exception"))
            //     _lexer.popFront();
            // if (_lexer.front == Token(TOK.symbol, "catch"))
            //     _lexer.popFront();
            if (_lexer.front.tok == TOK.brackets)
                _lexer.popFront();
            if (_lexer.front.tok == TOK.action)
                _lexer.popFront();
        }

        static if (useStaticTempArrays)
        {
            Pattern top = alts.length == 1 ? alts.backPop() : makeAltM(Token.init, alts[]);
            alts.clear();
        }
        else
            Pattern top = alts.length == 1 ? alts.backPop() : makeAltA(Token.init, alts.move());

        Rule rule = (isFragment
                     ? new FragmentRule(name, top)
                     : new Rule(name, top));

        if (_lexer._diagnoseLeftRecursion)
            rule.diagnoseDirectLeftRecursion(_lexer);

        rules.insertBack(rule);
        rulesByName[rule.head.input] = rule;
        return rule;
    }

    DynamicArray!(Input) makeArgs(in TOK separator,
                                  in TOK terminator)
    {
        typeof(return) result;
        while (true)
        {
            result.put(_lexer.frontPopEnforce(TOK.symbol).input);
            if (_lexer.front.tok != separator)
                break;
            _lexer.popFront();
        }
        _lexer.popFrontEnforce(terminator, "no terminating semicolon");
        return result;
    }

    AttributeSymbol makeAttributeSymbol(Token head) nothrow
    {
        return new AttributeSymbol(head, _lexer.frontPopEnforce(TOK.action, "missing action"));
    }

    ActionSymbol makeActionSymbol(Token head) nothrow
    {
        return new ActionSymbol(head, _lexer.frontPopEnforce(TOK.action, "missing action"));
    }

    TokenNode makeScope(Token head)
    {
        if (_lexer.front.tok == TOK.symbol)
        {
            const symbol = _lexer.frontPop().input;
            if (_lexer.front.tok == TOK.action)
                return new ScopeSymbolAction(head, symbol,
                                             _lexer.frontPopEnforce(TOK.action, "missing action"));
            else
            {
                auto result = new ScopeSymbol(head, symbol);
                _lexer.frontPopEnforce(TOK.semicolon,
                                          "missing terminating semicolon");
                return result;
            }
        }
        else
        {
            return new ScopeAction(head,
                                   _lexer.frontPopEnforce(TOK.action, "missing action"));
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
                               _lexer.frontPopEnforce(TOK.symbol, "missing symbol").input,
                               _lexer.skipOverToken(Token(TOK.symbol, "extends")).input ?
                               _lexer.frontPop().input :
                               null);
        _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");
        return result;
    }

    OtherSymbol skipOverOtherSymbol(string symbolIdentifier) return
    {
        if (_lexer.front == Token(TOK.symbol, symbolIdentifier))
        {
            return new typeof(return)(_lexer.frontPop());
        }
        return null;
    }

    /// Skip over scope if any.
    TokenNode skipOverScope()
    {
        if (_lexer.front == Token(TOK.symbol, "scope"))
            return makeScope(_lexer.frontPop());
        return null;
    }

    Options makeRuleOptions(Token head,
                            in bool skipOverColon = false) nothrow
    {
        version(Do_Inline) pragma(inline, true);
        const action = _lexer.frontPopEnforce(TOK.action, "missing action");
        if (skipOverColon)
            _lexer.skipOverTOK(TOK.colon);
        return new Options(head, action);
    }

    Options makeTopOptions(Token head) nothrow
    {
        version(Do_Inline) pragma(inline, true);
        const action = _lexer.frontPopEnforce(TOK.action, "missing action");
        _lexer.skipOverTOK(TOK.colon); // optionally scoped. See_Also: https://stackoverflow.com/questions/64477446/meaning-of-colon-inside-parenthesises/64477817#64477817
        return new Options(head, action);
    }

    Channels makeChannels(Token head) nothrow
    {
        version(Do_Inline) pragma(inline, true);
        return new Channels(head, _lexer.frontPopEnforce(TOK.action, "missing action"));
    }

    Tokens makeTokens(Token head) nothrow
    {
        version(Do_Inline) pragma(inline, true);
        return new Tokens(head, _lexer.frontPopEnforce(TOK.action, "missing action"));
    }

    Header makeHeader(Token head)
    {
        const name = (_lexer.front.tok == TOK.literal ?
                      _lexer.frontPop() :
                      Token.init);
        const action = _lexer.frontPopEnforce(TOK.action, "missing action");
        return new Header(head, name, action);
    }

    Mode makeMode(Token head)
    {
        auto result = new Mode(head, _lexer.frontPop().input);
        _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");
        return result;
    }

    Action makeAction(Token head)
    {
        version(Do_Inline) pragma(inline, true);
        return new Action(head);
    }

    /// Skip over options if any.
    Options skipOverPreRuleOptions()
    {
        if (_lexer.front == Token(TOK.symbol, "options"))
            return makeRuleOptions(_lexer.frontPop());
        return null;
    }

    bool skipOverExclusion()
    {
        if (_lexer.front.tok == TOK.exclamation)
        {
            _lexer.frontPop();
            return true;
        }
        return false;
    }

    bool skipOverReturns()
    {
        if (_lexer.front == Token(TOK.symbol, "returns"))
        {
            _lexer.frontPop();
            return true;
        }
        return false;
    }

    bool skipOverHooks()
    {
        if (_lexer.front.tok == TOK.brackets)
        {
            // _lexer.infoAtFront("TODO: use TOK.brackets");
            _lexer.frontPop();
            return true;
        }
        return false;
    }

    Action skipOverAction()
    {
        if (_lexer.front.tok == TOK.action)
            return makeAction(_lexer.frontPop());
        return null;
    }

    ActionSymbol skipOverActionSymbol()
    {
        if (_lexer.front.tok == TOK.actionSymbol)
            return makeActionSymbol(_lexer.frontPop);
        return null;
    }

    Node makeRuleOrOther(Token head)
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
                _lexer.popFrontEnforce(TOK.symbol, "expected `grammar` after `lexer`"); // TODO: enforce input grammar
            }
            else if (head.input == "parser")
            {
                parserFlag = true;
                _lexer.popFrontEnforce(TOK.symbol, "expected `grammar` after `parser`"); // TODO: enforce input grammar
            }

            if (lexerFlag)
            {
                auto lexerGrammar = new LexerGrammar(head, _lexer.frontPop().input);
                _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");
                return this.grammar = lexerGrammar;
            }
            else if (parserFlag)
            {
                auto parserGrammar = new ParserGrammar(head, _lexer.frontPop().input);
                _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");
                return this.grammar = parserGrammar;
            }
            else
            {
                if (_lexer.front.tok == TOK.colon)
                    return makeRule(head, false);
                else
                {
                    auto grammar = new Grammar(head, _lexer.frontPop().input);
                    _lexer.popFrontEnforce(TOK.semicolon, "no terminating semicolon");
                    this.grammar = grammar;
                    return grammar;
                }
            }
        }

        switch (head.input)
        {
        case `private`:
            _lexer.frontEnforce(TOK.symbol, "expected symbol after `private`");
            return makeRuleOrOther(_lexer.frontPop); // TODO: set private qualifier
        case `protected`:
            _lexer.frontEnforce(TOK.symbol, "expected symbol after `protected`");
            return makeRuleOrOther(_lexer.frontPop); // TODO: set protected qualifier
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
            return makeRule(_lexer.frontPop(), true);
        default:
            while (_lexer.front.tok != TOK.colon)
            {
                // TODO: use switch
                if (skipOverExclusion()) // TODO: use
                    continue;
                if (skipOverReturns())  // TODO: use
                    continue;
                if (skipOverHooks())    // TODO: use
                    continue;
                if (const _ = skipOverOtherSymbol("locals")) // TODO: use
                    continue;
                if (const _ = skipOverPreRuleOptions()) // TODO: use
                    continue;
                if (const _ = skipOverScope())     // TODO: use
                    continue;
                if (const _ = skipOverAction()) // TODO: use
                    continue;
                if (const _ = skipOverActionSymbol()) // TODO: use
                    continue;
                break;          // no progression so done
            }
            return makeRule(head, false);
        }
    }

    Node nextFront()
    {
        const head = _lexer.frontPop();
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

    Node grammar;
    DynamicArray!(Options) optionsSet;
    Imports imports;
    Rules rules;
    RulesByName rulesByName;
    bool warnUnknownSymbolFlag;
private:
    GxLexer _lexer;
    Node _front;
}

/// Returns: `path` as module name.
string toPathModuleName(scope string path) pure
{
    string adjustDirectoryName(const return scope string name) pure nothrow @nogc
    {
        if (name == "asm")      // TODO extend to check if a keyword
            return "asm_";
        return name;
    }
    import std.path : pathSplitter, stripExtension;
    import std.algorithm.iteration : map, joiner, substitute;
    import std.conv : to;
    while (path[0] == '/' ||
           path[0] == '\\')
        path = path[1 .. $];    // strip leading '/'s
    return path.stripExtension
               .pathSplitter()
               .map!(_ => adjustDirectoryName(_))
               .joiner(".")
               .substitute('-', '_')
               .to!string ~ "_parser"; // TODO: use lazy ranges that return `char`;
}

/// Gx filer parser.
struct GxFileParser           // TODO: convert to `class`
{
@safe:
    this(string path)
    {
        import std.path : expandTilde;
        Input data = cast(Input)rawReadPath(path.expandTilde); // cast to Input because we don't want to keep all file around:
        parser = GxParserByStatement(data, path, false);
    }

    alias RuleNames = DynamicArray!string;

    void generateParserSourceString(scope ref Output output)
    {
        const path = parser._lexer.path;
        const moduleName = path.toPathModuleName();

        output.put("/// Automatically generated from `");
        output.put(path);
        output.put("`.\n");
        output.put("module " ~ moduleName ~ q{;

});
        output.put(parserSourceBegin);
        RuleNames doneRuleNames;
        toMatchersForRules(doneRuleNames, output);
        toMatchersForImports(doneRuleNames, output);
        toMatchersForOptionsTokenVocab(doneRuleNames, output);
        output.put(parserSourceEnd);
    }

    void toMatchersForImportedModule(in const(char)[] moduleName,
                                     scope ref RuleNames doneRuleNames,
                                     scope ref Output output) const scope
    {
        import std.path : chainPath, dirName, extension;

        const string path = parser._lexer.path;
        string cwd = path.dirName; // current working directory
        const string ext = path.extension;

        GxFileParser fp_ = findModuleUpwards(cwd, moduleName, ext);

        while (!fp_.parser.empty)
            fp_.parser.popFront();

        fp_.toMatchersForImports(doneRuleNames, output); // transitive imports

        /** Rules in the “main grammar” override rules from imported
            grammars to implement inheritance.
            See_Also: https://github.com/antlr/antlr4/blob/master/doc/grammars.md#grammar-imports
        */
        bool isOverridden(const scope Rule rule) const @safe pure nothrow @nogc
        {
            return doneRuleNames[].canFind(rule.head.input);
        }

        foreach (const importedRule; fp_.parser.rules)
        {
            if (isOverridden(importedRule)) // if `importedRule` has already been defined
            {
                fp_.parser._lexer.warningAtToken(importedRule.head, "ignoring rule overridden in top grammar");
                continue;
            }
            importedRule.toMatcherInSource(output, parser);
            doneRuleNames.put(importedRule.head.input);
        }
    }

    private static GxFileParser findModuleUpwards(const string cwd,
                                                  scope const(char)[] moduleName,
                                                  scope const string ext)
    {
        import std.path : chainPath, dirName;
        import std.array : array;
        import std.file : FileException;
        const modulePath = chainPath(cwd, moduleName ~ ext).array.idup; // TODO: detect mutual file recursion
        try
            return GxFileParser(modulePath);
        catch (Exception e)
        {
            const cwdNext = cwd.dirName;
            if (cwdNext == cwd) // stuck at top directory
                throw new FileException("Couldn't find module named " ~ moduleName); // TODO: add source of import statement
            return findModuleUpwards(cwdNext, moduleName, ext);
        }
    }

    void toMatchersForRules(scope ref RuleNames doneRuleNames, scope ref Output output) const scope
    {
        foreach (const rule; parser.rules)
        {
            // rule.show();
            rule.toMatcherInSource(output, parser);
            doneRuleNames.put(rule.head.input);
        }
    }

    void toMatchersForImports(scope ref RuleNames doneRuleNames, scope ref Output output) const scope
    {
        foreach (const import_; parser.imports)
            foreach (const module_; import_.modules)
                toMatchersForImportedModule(module_, doneRuleNames, output);
    }

    void toMatchersForOptionsTokenVocab(scope ref RuleNames doneRuleNames, scope ref Output output) const scope
    {
        foreach (const options; parser.optionsSet[])
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
                if (const ix = co.indexOfEither(" ;"))
                {
                    const module_ = co[0 .. ix];
                    toMatchersForImportedModule(module_, doneRuleNames, output);
                }
            }
        }
    }

    ~this() @nogc {}

    GxParserByStatement parser;
}

static immutable parserSourceBegin =
`alias Input = const(char)[];

struct Match
{
@safe pure nothrow @nogc:
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
    const uint _length;                // length == uint.max is no match
}

/// https://forum.dlang.org/post/zcvjwdetohmklaxriswk@forum.dlang.org
version(none) alias Matcher = Match function(lazy Matcher[] matchers...);

struct Parser
{
@safe:
    Input inp;                  ///< Input.
    size_t off;                 ///< Current offset into inp.

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
        version(LDC) pragma(inline, true);
        if (off == inp.length)  // TODO:
            return Match.none();
        off += 1;
        return Match(1);
    }

    Match ch(in char x) pure nothrow @nogc
    {
        version(LDC) pragma(inline, true);
        if (off == inp.length)  // TODO:
            return Match.none();
        if (inp[off] == x)
        {
            off += 1;
            return Match(1);
        }
        return Match.none();
    }

    Match dch(const dchar x) pure nothrow @nogc
    {
        import std.typecons : Yes;
        import std.utf : encode;
        char[4] ch4;
        const replacementChar = cast(dchar)0x110000;
        const n = encode!(Yes.useReplacementDchar)(ch4, replacementChar);
        if (ch4[0 .. n] == [239, 191, 189]) // encoding of replacementChar
            return Match.none();
        if (off + n > inp.length) // TODO:
            return Match.none();
        if (inp[off .. off + n] == ch4[0 .. n])
        {
            off += n;
            return Match(n);
        }
        return Match.none();
    }

    Match cc(string cclass)() pure nothrow @nogc
    {
        pragma(inline, true);
        off += 1;               // TODO: switch on cclass
        if (off > inp.length)   // TODO:
            return Match.none();
        return Match(1);
    }

    /// Match string x.
    Match str(const scope string x) pure nothrow @nogc
    {
        pragma(inline, true);
        if (off + x.length <= inp.length && // TODO: optimize by using null-sentinel
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
        {{                      // scoped
            const match = matcher();
            if (!match)
            {
                off = off0;     // backtrack
                return match;   // propagate failure
            }
        }}
        return Match(off - off0);
    }

    Match alt(Matchers...)(const scope lazy Matchers matchers)
    {
        static foreach (const matcher; matchers)
        {{                      // scoped
            const off0 = off;
            if (const match = matcher())
                return match;
            else
                off = off0;     // backtrack
        }}
        return Match.none();
    }

    Match not(Matcher)(const scope lazy Matcher matcher)
    {
        const off0 = off;
        const match = matcher();
        if (!match)
            return match;
        off = off0;             // backtrack
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

    Match altN(chars...)() pure nothrow @nogc // TODO: non-char type in chars
    {
        pragma(inline, true);
        import std.algorithm.comparison : among; // TODO: replace with switch over static foreach to speed up compilation
        const x = inp[off];
        if (x.among!(chars))
        {
            off += 1; // TODO: skip over number of chars needed to encode hit
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
        // TODO: decode dchar at inp[off]
        const x = inp[off];
        if (lower <= x &&
            x <= upper)
        {
            off += 1; // TODO: handle dchar at inp[off]
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
                off = off1;     // backtrack
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
            off = off0;         // backtrack
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
            off = off0;         // backtrack
            return Match.none();
        }
        while (true)
        {
            const off1 = off;
            const match1 = matcher;
            if (!match1)
            {
                off = off1;     // backtrack
                break;
            }
        }
        return Match(off - off0);
    }

    // TODO merge overloads of nzo by using a default type and value for Matcher2
    Match nzo(Matcher1)(const scope lazy Matcher1 matcher)
    {
        const off0 = off;
        off = off0;             // backtrack
        const match = matcher();
        if (!match)
        {
            off = off0;         // backtrack
            return Match.none();
        }
        return Match(off - off0);
    }
    Match nzo(Matcher1, Matcher2)(const scope lazy Matcher1 matcher, const scope lazy Matcher2 terminator)
    {
        const off0 = off;
        if (terminator())
        {
            off = off0;         // backtrack
            return Match.zero(); // done
        }
        off = off0;             // backtrack
        const match = matcher();
        if (!match)
        {
            off = off0;         // backtrack
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
            off = off1;         // backtrack
            const off2 = off;
            const match = matcher();
            if (!match)
            {
                off = off2;     // backtrack
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
                off = off1;     // backtrack
                return Match(off1 - off0); // done
            }
            off = off1;         // backtrack
            const off2 = off;
            const match = matcher();
            if (!match)
            {
                off = off2;     // backtrack
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
            off = off1;         // backtrack
            const off2 = off;
            const match = matcher();
            if (!match)
            {
                off = off2;     // backtrack
                break;
            }
            firstFlag = true;
        }
        if (!firstFlag)
        {
            off = off0;         // backtrack
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
                off = off1;     // backtrack
                return Match(off1 - off0); // done
            }
            off = off1;         // backtrack
            const off2 = off;
            const match = matcher();
            if (!match)
            {
                off = off2;     // backtrack
                break;
            }
            firstFlag = true;
        }
        if (!firstFlag)
        {
            off = off0;         // backtrack
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

struct GxFileReader
{
    import std.path : stripExtension;
    GxFileParser fp;
@safe:
    this(string path)
    {
        fp = GxFileParser(path);
        while (!fp.parser.empty)
            fp.parser.popFront();
    }

    string createParserSourceFile()
    {
        Output pss;
        fp.generateParserSourceString(pss);
        import std.file : write;
        const path = fp.parser._lexer.path;
        const ppath = path.stripExtension ~ "_parser.d";
        write(ppath, pss[]);
        debug writeln("Wrote ", ppath);
        return ppath;
    }

    ~this() @nogc {}
}

struct ObjectFile
{
    File file;
    void open(string name, scope const(char)[] stdioOpenmode = "rb") @safe
    {
        file.open(name, stdioOpenmode);
    }
    alias file this;
}

struct ExecutableFile
{
    File file;
    void open(string name, scope const(char)[] stdioOpenmode = "rb") @safe
    {
        file.open(name, stdioOpenmode);
    }
    alias file this;
}

/// Build the D source files `ppaths`.
string buildSourceFiles(const string[] ppaths,
                        in bool linkFlag = false)
{
    import std.process : execute;
    const parserName = "parser";
    const outFile = parserName ~ (linkFlag ? "" : ".o");
    const args = (["dmd"] ~
                  (linkFlag ? [] : ["-c"]) ~
                  ["-dip25", "-dip1000", "-vcolumns", "-wi"] ~
                  ppaths ~
                  ("-of=" ~ outFile));
    writeln("args:", args);
    const dmd = execute(args);
    if (dmd.status == 0)
        writeln("Compilation of ", ppaths, " successful");
    else
        writeln("Compilation of ", ppaths, " failed with output:\n",
                dmd.output);
    return outFile;
}

private bool isGxFilename(const scope char[] name) @safe pure nothrow @nogc
{
    return name.endsWith(`.g4`);
}

private bool isGxFilenameParsed(const scope char[] name) @safe pure nothrow @nogc
{
    if (!isGxFilename(name))
         return false;
    // Pick specific file:
    // if (name != `Arithmetic.g4`)
    //     return false;
    if (// TODO:
        name == `Python2.g4` ||
        name == `Python3.g4` ||
        name == `AltPython3.g4` ||
        name == `PythonParser.g4` ||
        // TODO:
        name == `ResourcePlanParser.g4` ||
        name == `SelectClauseParser.g4` ||
        name == `IdentifiersParser.g4` ||
        // TODO:
        name == `AspectJParser.g4` || // TODO: find rule for `annotationName` in apex.g4
        name == `AspectJLexer.g4` ||
        // TODO: missing tokens
        name == `FromClauseParser.g4` ||
        name == `TSqlParser.g4` ||
        name == `informix.g4` ||
        name == `icon.g4` ||
        name == `ANTLRv4Parser.g4` ||
        name == `JPA.g4` || // INT_NUMERAL missing
        name == `STParser.g4` ||
        name == `STGParser.g4` ||
        // TODO:
        name == `RexxParser.g4` ||
        name == `RexxLexer.g4` ||
        name == `StackTrace.g4` ||
        name == `memcached_protocol.g4`) // skip this crap
        return false;
    return true;
}

import std.datetime.stopwatch : StopWatch;
import std.file : dirEntries, SpanMode, getcwd;
import std.path : expandTilde, relativePath, baseName, dirName, buildPath;

enum showProgressFlag = true;

void lexAllInDirTree(string rootDirPath,
           scope File outFile) @system
{
    scope StopWatch swAll;
    swAll.start();
    foreach (const e; dirEntries(rootDirPath, SpanMode.breadth))
    {
        const fn = e.name;
        if (fn.isGxFilename)
        {
            static if (showProgressFlag)
                outFile.writeln("Lexing ", tryRelativePath(rootDirPath, fn), " ...");  // TODO: read use curren directory
            const data = cast(Input)rawReadPath(fn); // exclude from benchmark
            scope StopWatch swOne;
            swOne.start();
            auto lexer = GxLexer(data, fn, false);
            while (!lexer.empty)
                lexer.popFront();
            static if (showProgressFlag)
                outFile.writeln("Lexing ", tryRelativePath(rootDirPath, fn), " took ", swOne.peek());
        }
    }
    outFile.writeln("Lexing all took ", swAll.peek());
}

void parseAllInDirTree(string rootDirPath,
                       scope File outFile,
                       bool buildSingleFlag,
                       bool buildAllFlag) @system
{
    scope StopWatch swAll;
    swAll.start();
    DynamicArray!string parserPaths; ///< Paths to generated parsers in D.
    foreach (const e; dirEntries(rootDirPath, SpanMode.breadth))
    {
        const fn = e.name;
        const dn = fn.dirName;
        const bn = fn.baseName;
        if (bn.isGxFilenameParsed)
        {
            const exDirPath = buildPath(dn, "examples"); // examples directory
            import std.file : exists, isDir;
            if (exDirPath.exists &&
                exDirPath.isDir)
                foreach (const exf; dirEntries(exDirPath, SpanMode.breadth))
                    outFile.writeln("TODO: Parse example file: ", exf);
            static if (showProgressFlag)
                outFile.writeln("Reading ", tryRelativePath(rootDirPath, fn), " ...");

            scope StopWatch swOne;
            swOne.start();

            auto reader = GxFileReader(fn);
            const parsePath = reader.createParserSourceFile();
            if (parserPaths[].canFind(parsePath)) // TODO: remove because this should not happen
                outFile.writeln("Warning: duplicate entry outFile ", parsePath);
            else
                parserPaths.insertBack(parsePath);
            if (buildSingleFlag)
            {
                const parseExePath = buildSourceFiles([parsePath], true);
            }

            static if (showProgressFlag)
                outFile.writeln("Reading ", tryRelativePath(rootDirPath, fn), " took ", swOne.peek());
        }
    }
    if (buildAllFlag)
        buildSourceFiles(parserPaths[]);
    outFile.writeln("Reading all took ", swAll.peek());
}

void doTree(string rootDirPath) @system
{
    const lexerFlag = true;
    const parserFlag = true;
    const buildSingleFlag = true;
    const buildAllFlag = true;
    File outFile = stdout;
    if (lexerFlag)
        lexAllInDirTree(rootDirPath, outFile);
    if (parserFlag)
        parseAllInDirTree(rootDirPath, outFile, buildSingleFlag, buildAllFlag);
}

string tryRelativePath(scope string rootDirPath,
                       const return scope string path) @safe
{
    const cwd = getcwd();
    if (rootDirPath.startsWith(cwd))
        return path.relativePath(cwd);
    return path;
}

///
version(show)
@system unittest
{
    const rootDirPath = "~/Work/grammars-v4/".expandTilde;
    doTree(rootDirPath);
}
