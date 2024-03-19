module nxt.ada_defs;

/// Logical Operators
enum operatorsLogical = ["and", "or", "xor"];

/// Relational Operators
enum operatorsRelational = ["/=", "=", "<", "<=", ">", ">="];

/// Binary Adding Operators
enum operatorsBinaryAdding = ["+", "-", "&"];

/// Unary Adding Operators
enum operatorsUnaryAdding = ["+", "-"];

/// Multiplying Operators
enum operatorsMultiplying = ["*", "/", "mod", "rem"];

/// Parens
enum operatorsParens = ["(", ")", "[", "]", "{", "}"];

/// Assignment
enum operatorsAssignment = [":="];

/// Other Operators
enum operatorsOther = ["**", "not", "abs", "in",
					   ".", ",", ";", "..",
					   "<>",
					   "<<",
					   ">>"];

/// Operators
enum operators = (operatorsLogical
				  ~ operatorsRelational
				  ~ operatorsBinaryAdding
				  ~ operatorsUnaryAdding
				  ~ operatorsMultiplying
				  ~ operatorsParens
				  ~ operatorsAssignment
				  ~ operatorsOther
	);

/// Kewords Ada 83
enum keywords83 = [ "abort", "else", "new", "return", "abs", "elsif", "not", "reverse",
					"end", "null", "accept", "entry", "select", "access", "exception", "of", "separate",
					"exit", "or", "subtype", "all", "others", "and", "for", "out", "array",
					"function", "task", "at", "package", "terminate", "generic", "pragma", "then", "begin", "goto", "private",
					"type", "body", "procedure", "if", "case", "in", "use", "constant", "is", "raise",
					"range", "when", "declare", "limited", "record", "while", "delay", "loop", "rem", "with", "delta", "renames",
					"digits", "mod", "xor", "do", ];

/// New Kewords in Ada 95
enum keywordsNew95 = ["abstract", "aliased", "tagged", "protected", "until", "requeue"];

/// New Kewords in Ada 2005
enum keywordsNew2005 = ["synchronized", "overriding", "interface"];

/// New Kewords in Ada 2012
enum keywordsNew2012 = ["some"];

/// Kewords in Ada 2012
enum keywords2012 = (keywords83 ~ keywordsNew95 ~ keywordsNew2005 ~ keywordsNew2012);
