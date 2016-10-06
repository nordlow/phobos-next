/** SUO-KIF File Format.

    See: https://en.wikipedia.org/wiki/Knowledge_Interchange_Format
    See: http://sigmakee.cvs.sourceforge.net/viewvc/sigmakee/sigma/suo-kif.pdf
*/
module suokif;

// import std.range : isInputRange;
import dbgio : dln;
import array_ex : Array, Ordering;

/** SUO-KIF Token. */
enum Token
{
    leftParen,
    rightParen,
    symbol,
    stringLiteral,
    oneDirInference,            // one-directional inference
    biDirInference,             // bi-directional inference
    equivalence,

    variable,
    varParams,                  // one or more parameter
    whitespace,
    number,
    comment,

    className,
    functionName,

    // keywords
    and_,
    or_,
    not_,
    exists_,
    instance_,
    domain_,
    lexicon_,
    range_,
    subrelation_,
    models_,
    format_,
    subclass_,
    documentation_,
    meronym_,
    property_,
    attribute_,
    subAttribute_,
    equal_,
    abbreviation_,
    result_,
    duration_,
    agent_,
    member_,
    hasPurpose_,
    finishes_,
    earlier_,
    yield_,
    instrument_,
    destination_,
    material_,
    causes_,
    origin_,
    located_,
    employs_,
    possesses_,
    disjoint_,
    mother_,
    father_,
    son_,
    daughter_,
    brother_,
    sister_,
    sibling_,

    lessThan_,
    greaterThan_,
    lessThanOrEqualTo_,
    greaterThanOrEqualTo_,

    date_,
    insured_,
    askPrice_,
    outOfTheMoney_,
}

bool isLispSymbolChar(char x)
    @safe pure nothrow @nogc
{
    import std.uni : isAlphaNum;
    import std.algorithm : among;
    return x.isAlphaNum || x.among!('_', '-');
}

/** Parse SUO-KIF from `src`. */
Array!Token lexSUOKIF(string src) @safe pure
{
    import std.range : empty, front, popFront;
    import std.uni : isWhite, isAlpha;
    import std.ascii : isDigit;
    import std.algorithm : among, skipOver;

    typeof(return) tokens;

    const whole = src;

    src.skipOver(x"EFBBBF");    // skip magic? header for some files

    /// Skip comment.
    static void skipComment(ref string src)
    {
        while (!src.empty && !src.front.among('\r', '\n')) // until end of line
        {
            src.popFront();
        }
    }

    static string skipN(ref string src, size_t n)
    {
        const part = src[0 .. n];
        src = src[n .. $];
        return part;
    }

    /// Get symbol.
    static string getSymbol(ref string src)
    {
        size_t i = 0;
        while (i != src.length && src[i].isLispSymbolChar) { ++i; }
        return skipN(src, i);
    }

    /// Get numeric literal (number) in integer or decimal forma.
    static string getNumber(ref string src)
    {
        size_t i = 0;
        while (i != src.length && (src[i].isDigit ||
                                   src[i].among!('+', '-', '.'))) { ++i; }
        return skipN(src, i);
    }

    /// Get string literal.
    static string getStringLiteral(ref string src)
    {
        src.popFront();         // pop leading double quote
        size_t i = 0;
        while (i != src.length && src[i] != '"') { ++i; }
        const literal = src[0 .. i]; src = src[i .. $]; // TODO functionize
        src.popFront();         // pop ending double quote
        return literal;
    }

    /// Skip whitespace.
    static string getWhitespace(ref string src)
    {
        size_t i = 0;
        while (i != src.length && src[i].isWhite) { ++i; }
        return skipN(src, i);
    }

    bool[string] lowerSymbols;

    while (!src.empty)
    {
        switch (src.front)
        {
        case ';':
            skipComment(src);
            tokens ~= Token.comment;
            break;
        case '(':
            src.popFront();
            tokens ~= Token.leftParen;
            break;
        case ')':
            src.popFront();
            tokens ~= Token.rightParen;
            break;
        case '"':
            const stringLiteral = getStringLiteral(src); // TODO tokenize
            tokens ~= Token.stringLiteral;
            break;
        case '=':
            src.popFront();
            if (src.front == '>')
            {
                src.popFront();
                tokens ~= Token.oneDirInference;
            }
            else
            {
                tokens ~= Token.equivalence;
            }
            break;
        case '<':
            src.popFront();
            if (src.front == '=')
            {
                src.popFront();
                if (src.front == '>')
                {
                    src.popFront();
                    tokens ~= Token.biDirInference;
                }
            }
            break;
        case '?':
            src.popFront();
            const variableSymbol = getSymbol(src); // TODO tokenize
            tokens ~= Token.variable;
            break;
        case '@':
            src.popFront();
            const variableSymbol = getSymbol(src); // TODO tokenize
            tokens ~= Token.varParams;
            break;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
        case '-':
        case '+':
        case '.':
            const number = getNumber(src); // TODO tokenize
            tokens ~= Token.number;
            break;
            // std.ascii.isWhite
        case ' ':
        case 0x09:
        case 0x10:
        case 0x0A:
        case 0x0B:
        case 0x0C:
        case 0x0D:
            assert(src.front.isWhite);
            getWhitespace(src);
            tokens ~= Token.whitespace;
            break;
        default:
            // other
            if (src.front.isAlpha)
            {
                const symbol = getSymbol(src); // TODO tokenize
                switch (symbol)
                {
                case `and`: tokens ~= Token.and_; break;
                case `or`: tokens ~= Token.or_; break;
                case `not`: tokens ~= Token.not_; break;
                case `exists`: tokens ~= Token.exists_; break;
                case `instance`: tokens ~= Token.instance_; break;
                case `domain`: tokens ~= Token.domain_; break;
                case `lexicon`: tokens ~= Token.lexicon_; break;
                case `range`: tokens ~= Token.range_; break;
                case `subrelation`: tokens ~= Token.subrelation_; break;
                case `models`: tokens ~= Token.models_; break;
                case `format`: tokens ~= Token.format_; break;
                case `subclass`: tokens ~= Token.subclass_; break;
                case `documentation`: tokens ~= Token.documentation_; break;
                case `meronym`: tokens ~= Token.meronym_; break;
                case `property`: tokens ~= Token.property_; break;
                case `attribute`: tokens ~= Token.attribute_; break;
                case `subAttribute`: tokens ~= Token.subAttribute_; break;
                case `equal`: tokens ~= Token.equal_; break;
                case `abbreviation`: tokens ~= Token.abbreviation_; break;
                case `result`: tokens ~= Token.result_; break;
                case `duration`: tokens ~= Token.duration_; break;
                case `agent`: tokens ~= Token.agent_; break;
                case `member`: tokens ~= Token.member_; break;
                case `hasPurpose`: tokens ~= Token.hasPurpose_; break;
                case `finishes`: tokens ~= Token.finishes_; break;
                case `earlier`: tokens ~= Token.earlier_; break;
                case `yield`: tokens ~= Token.yield_; break;
                case `instrument`: tokens ~= Token.instrument_; break;
                case `destination`: tokens ~= Token.destination_; break;
                case `material`: tokens ~= Token.material_; break;
                case `causes`: tokens ~= Token.causes_; break;
                case `origin`: tokens ~= Token.origin_; break;
                case `located`: tokens ~= Token.located_; break;
                case `employs`: tokens ~= Token.employs_; break;
                case `possesses`: tokens ~= Token.possesses_; break;
                case `disjoint`: tokens ~= Token.disjoint_; break;
                case `mother`: tokens ~= Token.mother_; break;
                case `father`: tokens ~= Token.father_; break;
                case `son`: tokens ~= Token.son_; break;
                case `daughter`: tokens ~= Token.daughter_; break;
                case `brother`: tokens ~= Token.brother_; break;
                case `sister`: tokens ~= Token.sister_; break;
                case `sibling`: tokens ~= Token.sibling_; break;
                case `lessThan`: tokens ~= Token.lessThan_; break;
                case `lessThanOrEqualTo`: tokens ~= Token.lessThanOrEqualTo_; break;
                case `greaterThan`: tokens ~= Token.greaterThan_; break;
                case `greaterThanOrEqualTo`: tokens ~= Token.greaterThanOrEqualTo_; break;
                case `date`: tokens ~= Token.date_; break;
                case `insured`: tokens ~= Token.insured_; break;
                case `askPrice`: tokens ~= Token.askPrice_; break;
                case `outOfTheMoney`: tokens ~= Token.outOfTheMoney_; break;
                default:
                    import std.uni : isLower;
                    import std.algorithm : endsWith;
                    if (symbol.front.isLower)
                    {
                        if (symbol !in lowerSymbols)
                        {
                            lowerSymbols[symbol] = true;
                        }
                    }
                    else if (symbol.endsWith(`Fn`))
                    {
                        tokens ~= Token.functionName;
                    }
                    else
                    {
                        tokens ~= Token.symbol;
                    }
                    break;
                }
            }
            else
            {
                dln(`Cannot handle character '`, src.front, `' at index:`, &src[0] - &whole[0]);
                // dln(tokens[]);
                assert(false);
            }
            break;
        }
    }

    dln(lowerSymbols);
    return tokens;
}

unittest
{
    import std.stdio : write, writeln;
    import std.path : expandTilde;

    const rootDirPath = `~/Work/justd/sumo`;

    import std.file: dirEntries, SpanMode;
    auto entries = dirEntries(rootDirPath.expandTilde, SpanMode.breadth, false); // false: skip symlinks
    foreach (dent; entries)
    {
        const filePath = dent.name;
        import std.algorithm : endsWith;

        import std.path : baseName;
        immutable basename = dent.name.baseName;

        import std.utf;
        import std.algorithm : among;
        try
        {
            if (filePath.endsWith(`.kif`)) // invalid UTF-8 encodings
            {
                write(`Lexing SUO-KIF `, filePath, ` ... `);

                import std.file : readText;
                // file.readText.lexSUOKIF2();

                import std.datetime : StopWatch, AutoStart, Duration;
                auto sw = StopWatch(AutoStart.yes);
                const tokens = filePath.readText.lexSUOKIF();
                sw.stop;
                import std.conv : to;
                writeln(`took `, sw.peek().to!Duration);
            }
        }
        catch (std.utf.UTFException e)
        {
            import std.file : read;
            writeln(" failed because of invalid UTF-8 encoding starting with ", filePath.read(16));
        }
    }

    // const file = `~/Work/justd/phobos-next/src/emotion.kif`.expandTilde;
    // dln(tokens[]);
}

// void lexSUOKIF2(R)(R src)
// {
//     import std.experimental.lexer;

//     static immutable TokOperators = [ `(`, `)`, `=>` ];
//     static immutable TokDynamic = [ `stringLiteral`, `comment`, `identifier`, `numberLiteral`, `whitespace` ];
//     static immutable TokKeywords = [ `and`, `exists`, `or`, `not` ];
//     import std.meta : AliasSeq;

//     alias Toks = AliasSeq!(TokOperators, TokDynamic, TokKeywords);
//     alias TokID = TokenIdType!Toks;
//     alias tokToString = tokenStringRepresentation!(TokID, Toks);
//     alias tok(string symbol) = TokenId!(TokID, LuaTokens, symbol);

//     static immutable tokenHandlers = [
//         "\"", "lexStringLiteral",
//         ";", "lexComment",
//         " ",  "lexWhitespace",
//         "\t", "lexWhitespace",
//         "\r", "lexWhitespace",
//         "\n", "lexWhitespace",
//         ];
// }
