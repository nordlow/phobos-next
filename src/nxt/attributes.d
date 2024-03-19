/** Attributes.
 *
 * Only make T args const when they have value semantics (allAre!hasIndirections!T).
 */
module nxt.attributes;

import nxt.iso_639_1 : Language;
import nxt.lingua: TokenId, Usage;

pure nothrow @safe @nogc
{
	/** Words. */
	struct AsWords(T...) { T args; } auto ref asWords(T...)(T args) { return AsWords!T(args); }
	/** Comma-Separated List. */
	struct AsCSL(T...) { T args; } auto ref asCSL(T...)(T args) { return AsCSL!T(args); }

	/** Printed as Path. */
	struct AsPath(T) { T arg; } auto ref asPath(T)(T arg) { return AsPath!T(arg); }
	/** Printed as Name. */
	struct AsName(T) { T arg; } auto ref asName(T)(T arg) { return AsName!T(arg); }
	/** Printed as URL. */
	struct AsURL(T) { T arg; alias arg this; } auto ref asURL(T)(T arg) { return AsURL!T(arg); }

	/* TODO: Turn these into an enum for more efficient parsing. */
	/** Printed as Italic/Slanted. */
	struct AsItalic(T...) { T args; } auto asItalic(T...)(T args) { return AsItalic!T(args); }
	/** Bold. */
	struct AsBold(T...) { T args; } auto asBold(T...)(T args) { return AsBold!T(args); }
	/** Monospaced. */
	struct AsMonospaced(T...) { T args; } auto asMonospaced(T...)(T args) { return AsMonospaced!T(args); }

	/** Code. */
	struct AsCode(TokenId token = TokenId.unknown,
				  Language lang_ = Language.unknown, T...) {
		this(T args) { this.args = args; }
		T args;
		static lang = lang_;
		string language;
		TokenId tokenId;
		Usage usage;
		auto ref setLanguage(string language) {
			this.language = language;
			return this;
		}
	}

	/* Instantiators */
	auto ref asCode(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.unknown, lang_, T)(args); }
	auto ref asKeyword(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.keyword, lang_, T)(args); } // Emacs: font-lock-keyword-face
	auto ref asType(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.type, lang_, T)(args); } // Emacs: font-lock-type-face
	auto ref asConstant(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.constant, lang_, T)(args); } // Emacs: font-lock-constant-face
	auto ref asVariable(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.variableName, lang_, T)(args); } // Emacs: font-lock-variable-name-face
	auto ref asComment(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.comment, lang_, T)(args); } // Emacs: font-lock-comment-face

	auto ref asFunction(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.functionName, lang_, T)(args); } // Emacs: font-lock-function-name-face
	auto ref asFunctionCall(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.functionCall, lang_, T)(args); } // Emacs: font-lock-function-name-face

	auto ref asConstructor(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.constructor, lang_, T)(args); } // constuctor
	auto ref asDestructor(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.destructor, lang_, T)(args); } // destructor
	auto ref asBuiltin(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.builtinName, lang_, T)(args); } // Emacs: font-lock-builtin-name-face
	auto ref asTemplate(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.templateName, lang_, T)(args); } // Emacs: font-lock-builtin-name-face
	auto ref asOperator(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.operator, lang_, T)(args); } // Emacs: font-lock-operator-face
	auto ref asMacro(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.macroName, lang_, T)(args); }
	auto ref asAlias(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.aliasName, lang_, T)(args); }
	auto ref asEnumeration(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.enumeration, lang_, T)(args); }
	auto ref asEnumerator(Language lang_ = Language.unknown, T...)(T args) { return AsCode!(TokenId.enumerator, lang_, T)(args); }
	alias asCtor = asConstructor;
	alias asDtor = asDestructor;
	alias asEnum = asEnumeration;

	/** Emphasized. */
	struct AsEmphasized(T...) { T args; } auto ref asEmphasized(T...)(T args) { return AsEmphasized!T(args); }

	/** Strongly Emphasized. */
	struct AsStronglyEmphasized(T...) { T args; } auto ref asStronglyEmphasized(T...)(T args) { return AsStronglyEmphasized!T(args); }

	/** Strong. */
	struct AsStrong(T...) { T args; } auto ref asStrong(T...)(T args) { return AsStrong!T(args); }
	/** Citation. */
	struct AsCitation(T...) { T args; } auto ref asCitation(T...)(T args) { return AsCitation!T(args); }
	/** Deleted. */
	struct AsDeleted(T...) { T args; } auto ref asDeleted(T...)(T args) { return AsDeleted!T(args); }
	/** Inserted. */
	struct AsInserted(T...) { T args; } auto ref asInserted(T...)(T args) { return AsInserted!T(args); }
	/** Superscript. */
	struct AsSuperscript(T...) { T args; } auto ref asSuperscript(T...)(T args) { return AsSuperscript!T(args); }
	/** Subscript. */
	struct AsSubscript(T...) { T args; } auto ref asSubscript(T...)(T args) { return AsSubscript!T(args); }

	/** Preformatted. */
	struct AsPreformatted(T...) { T args; } auto ref asPreformatted(T...)(T args) { return AsPreformatted!T(args); }

	/** Scan hit with index `ix`. */
	struct AsHit(T...) { uint ix; T args; } auto ref asHit(T)(uint ix, T args) { return AsHit!T(ix, args); }

	/** Scan hit context with index `ix`. */
	struct AsCtx(T...) { uint ix; T args; } auto ref asCtx(T)(uint ix, T args) { return AsCtx!T(ix, args); }

	/** Header. */
	struct AsHeader(uint Level, T...) { T args; enum level = Level; }
	auto ref asHeader(uint Level, T...)(T args) { return AsHeader!(Level, T)(args); }

	/** Paragraph. */
	struct AsParagraph(T...) { T args; } auto ref asParagraph(T...)(T args) { return AsParagraph!T(args); }

	/** Multi-Paragraph Blockquote. */
	struct AsBlockquote(T...) { T args; } auto ref asBlockquote(T...)(T args) { return AsBlockquote!T(args); }

	/** Single-Paragraph Blockquote. */
	struct AsBlockquoteSP(T...) { T args; } auto ref asBlockquoteSP(T...)(T args) { return AsBlockquoteSP!T(args); }

	/** Unordered List.
		TODO: Should asUList, asOList autowrap args as AsItems when needed?
	*/
	struct AsUList(T...) { T args; } auto ref asUList(T...)(T args) { return AsUList!T(args); }
	/** Ordered List. */
	struct AsOList(T...) { T args; } auto ref asOList(T...)(T args) { return AsOList!T(args); }

	/** Description. */
	struct AsDescription(T...) { T args; } auto ref asDescription(T...)(T args) { return AsDescription!T(args); }

	/** Horizontal Ruler. */
	struct HorizontalRuler {} auto ref horizontalRuler() { return HorizontalRuler(); }

	/** MDash. */
	struct MDash {} auto ref mDash() { return MDash(); }

	enum RowNr { none, offsetZero, offsetOne }

	/** Table.
		TODO: Should asTable autowrap args AsRows when needed?
	*/
	struct AsTable(T...) {
		string border;
		RowNr rowNr;
		bool recurseFlag;
		T args;
	}
	auto ref asTable(T...)(T args) { return AsTable!T(`"1"`, RowNr.none, false, args); }
	auto ref asTableTree(T...)(T args) { return AsTable!T(`"1"`, RowNr.none, true, args); }
	alias asTablesTable = asTableTree;
	auto ref asTableNr0(T...)(T args) { return AsTable!T(`"1"`, RowNr.offsetZero, false, args); }
	auto ref asTableNr1(T...)(T args) { return AsTable!T(`"1"`, RowNr.offsetOne, false, args); }

	struct AsCols(T...) {
		RowNr rowNr;
		size_t rowIx;
		bool recurseFlag;
		T args;
	}
	auto ref asCols(T...)(T args) { return AsCols!T(RowNr.none, 0, false, args); }

	/** Numbered Rows */
	struct AsRows(T...) {
		RowNr rowNr;
		bool recurseFlag;
		T args;
	}
	auto ref asRows(T...)(T args) { return AsRows!(T)(RowNr.none, false, args); }

	/** Table Row. */
	struct AsRow(T...) { T args; } auto ref asRow(T...)(T args) { return AsRow!T(args); }
	/** Table Cell. */
	struct AsCell(T...) { T args; } auto ref asCell(T...)(T args) { return AsCell!T(args); }

	/** Row/Column/... Span. */
	struct Span(T...) { uint _span; T args; }
	auto span(T...)(uint span, T args) { return span!T(span, args); }

	/** Table Heading. */
	struct AsTHeading(T...) { T args; } auto ref asTHeading(T...)(T args) { return AsTHeading!T(args); }

	/* /\** Unordered List Beginner. *\/ */
	/* struct UListBegin(T...) { T args; } */
	/* auto uListBegin(T...)(T args) { return UListBegin!T(args); } */
	/* /\** Unordered List Ender. *\/ */
	/* struct UListEnd(T...) { T args; } */
	/* auto uListEnd(T...)(T args) { return UListEnd!T(args); } */
	/* /\** Ordered List Beginner. *\/ */
	/* struct OListBegin(T...) { T args; } */
	/* auto oListBegin(T...)(T args) { return OListBegin!T(args); } */
	/* /\** Ordered List Ender. *\/ */
	/* struct OListEnd(T...) { T args; } */
	/* auto oListEnd(T...)(T args) { return OListEnd!T(args); } */

	/** List Item. */
	struct AsItem(T...) { T args; } auto ref asItem(T...)(T args) { return AsItem!T(args); }

	string lbr(bool useHTML) { return (useHTML ? `<br>` : ``); } // line break

	/* HTML Aliases */
	alias asB = asBold;
	alias asI = asBold;
	alias asTT = asMonospaced;
	alias asP = asParagraph;
	alias asH = asHeader;
	alias asHR = horizontalRuler;
	alias asUL = asUList;
	alias asOL = asOList;
	alias asTR = asRow;
	alias asTD = asCell;
}

struct As(Attribute, Things...) {
	Things things;
}
auto ref as(Attribute, Things...)(Things things) {
	return As!(Attribute, Things)(things);
}
