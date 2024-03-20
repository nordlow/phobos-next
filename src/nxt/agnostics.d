/++ Programming concepts that capture semantic that is common among different
    programming language, both imperative, functional and declarative.

    The class hierarchy together class fields, member functions and UDAs encode
    the semantics of the above mentioned concepts.  +/
module nxt.agnostics;

@safe pure nothrow:

/++ Language-Agnostic Syntax Tree Node Type Code.
	A UDA ´@isA_$NODETYPE´ => inherit `$NODETYPE`.
	Expresses inheritance via UDAs, for instance:
	`@isA_token comment`
	means that `comment` is a kind of `token`.
 +/
enum NodeTypeCode : ubyte {
	any, /++ Any kind of node. +/
	token, /++ Token|Terminal node. (typically un-named in tree-sitter terminology). +/
	@isA_token comment, /++ Any kind of comment. +/
	@isA_comment comment_multiLine, /++ Multi-Line Comment. +/
	@isA_comment comment_endOfLine, /++ End-Of-Line Comment. +/
	@isA_node expr, /++ Expression. +/
	@isA_node expr_ident_rvalue, /++ Identifier Expression (r-value). +/
	@isA_node expr_ident_lvalue, /++ Identifier Expression (l-value). +/
	@isA_expr expr_unary, /++ Unary Expression. +/
	@isA_expr_unary expr_unary_cast, /++ Cast Expression. +/
	@isA_expr_unary_arith expr_unary_arith_negation, /++ Arithmetic negation. +/
	@isA_expr_unary_arith expr_unary_arith_plus, /++ Arithmetic plus. +/
	@isA_expr expr_binary, /++ Binary Expression. +/
	@isA_expr_binary_arith expr_binary_arith_addition, /++ Addition. +/
	@isA_expr_binary_arith expr_binary_arith_multiplication, /++ Multiplication. +/
	@isA_expr_binary_arith expr_binary_arith_division, /++ Division. +/
	@isA_expr_binary_arith expr_binary_arith_exponentation, /++ Exponentation|Power. +/
	@isA_expr expr_ternary, /++ Ternary Expression. +/
	@isA_expr expr_assign, /++ Assign Expression. +/
	@isA_expr expr_functionCall, /++ Function Call Expression. +/
	@isA_token litr, /++ Literal (Constant). +/
	@isA_litr litr_string, /++ String Literal. +/
	@isA_litr litr_string_standard, /++ Standard-String Literal. +/
	@isA_litr litr_string_raw, /++ Raw-String Literal. +/
	@isA_litr litr_string_quoted, /++ Quoted-String Literal (in dlang.org). +/
	@isA_litr litr_string_standard_interpolating, /++ Interpolating Standard-String Literal. +/
	@isA_litr litr_string_raw_interpolating, /++ Interpolating Raw-String Literal. +/
	@isA_litr litr_string_quoted_interpolating, /++ Interpolating Quoted-String Literal (in dlang.org). +/
	@isA_litr litr_scalar, /++ Scalar Literal. +/
	@isA_litr_scalar litr_scalar_character, /++ Character Literal. +/
	@isA_litr_scalar litr_numeric, /++ Numeric Literal. +/
	@isA_litr_numeric litr_boolean, /++ Boolean Literal. +/
	@isA_litr_numeric litr_numeric_integer, /++ Integer Numeric Literal. +/
	@isA_litr_numeric_integer litr_numeric_integer_signed, /++ Signed Integer Numeric Literal. +/
	@isA_litr_numeric_integer litr_numeric_integer_unsigned, /++ Signed Integer Numeric Literal. +/
	@isA_litr_numeric litr_numeric_floatingPoint, /++ Floating-Point|Real|Decimal Numeric Literal. +/
	@isA_token symbolReference,	 /++ Symbol reference. +/
	@isA_node decl, /++ Declaration. +/
	@isA_decl decl_type, /++ Type Declaration. +/
	@isA_decl_type decl_module, /++ Module Declaration. +/
	@isA_decl_type decl_package, /++ Package Declaration. +/
	@isA_decl_type decl_namespace, /++ Namespace Declaration. +/
	@isA_decl_type decl_type_label, /++ Label Declaration. +/
	@isA_decl_type decl_type_function, /++ Function Type Declaration. +/
	@isA_decl_type decl_type_class, /++ Class Type Declaration. +/
	@isA_decl_type decl_type_interface, /++ Interface Type Declaration. +/
	@isA_decl_type decl_type_enumeration, /++ Enumeration Type Declaration. +/
	@isA_decl_type decl_type_union, /++ Union Type Declaration. +/
	@isA_decl_type decl_type_struct, /++ Struct Type Declaration. +/
	@isA_decl decl_constant_enumerator, /++ Enumerator Constant Declaration. +/
	@isA_type type_scalar,
	@isA_type_scalar type_scalar_numeric, /++ Numeric Scalar Type. +/
	@isA_type type_vector, /++ SIMD fixed-length vector type of scalar elements. +/
	@isA_type_vector type_vector_integer, /++ SIMD fixed-length vector type of scalar elements. +/
	@isA_type_vector type_vector_floatingPoint, /++ SIMD fixed-length vector type of scalar elements. +/
	@isA_type_scalar type_scalar_arith, /++ Arithmetic Type. +/
	@isA_type_scalar type_scalar_character, /++ Character Type. +/
	@isA_type type_string, /++ String Type. +/
	@isA_type type_aggregate, /++ Aggregate Type. +/
	@isA_type_aggregate type_value_aggregate,
	@isA_type_value_aggregate type_struct, /++ Struct Type having value semantics. +/
	@isA_type_aggregate type_anonymous_struct, /++ Anonymous Struct Type. +/
	@isA_type_aggregate type_aggregate_tuple = type_anonymous_struct, /++ Tuple Type. +/
	@isA_type_aggregate type_aggregate_union, /++ Union type. +/
	@isA_type_aggregate type_aggregate_class, /++ Class type. +/
	@isA_type type_enumeration, /++ Enumeration Type. +/
	@isA_type type_array, /++ Array type. +/
	@isA_type type_array_slice, /++ Array slice type. +/
	@isA_type type_machine_word, /++ Type of size machine word. +/
	@isA_machinewordtype type_addr, /++ Address type. +/
	@isA_machinewordtype type_size, /++ Size type. +/
	@isA_type_addr type_ptr, /++ Pointer type. +/
	@isA_type_addr type_ref, /++ Reference type. +/
	@isA_type functionType, /++ Function type. +/
	@isA_node defi, /++ Definition. +/
	@isA_defi defi_type, /++ Type Definition. +/
	@isA_defi_type defi_type_module, /++ Module Definition. +/
	@isA_defi_type defi_type_package, /++ Package Definition. +/
	@isA_defi_type defi_type_namespace, /++ Namespace Definition. +/
	@isA_defi_type defi_type_label, /++ Label definition. +/
	@isA_defi_type defi_type_function, /++ Function definition. +/
	@isA_defi_type defi_type_class, /++ Class definition. +/
	@isA_defi_type defi_type_interface, /++ Interface definition. +/
	@isA_defi_type defi_type_enumeration, /++ Enumeration definition. +/
	@isA_defi_type defi_type_union, /++ Union definition. +/
	@isA_defi_type defi_type_struct, /++ Struct definition. +/
	@isA_defi_type defi_type_enumerator, /++ Enumerator definition. +/
	@isA_defi defi_variable, /++ Variable definition. +/
	@isA_defi_variable defi_variable_parameter, /++ Function parameter (local variable) definition. +/
    @isA_node directive, /++ Directive. +/
    @isA_directive directive_pragma, /++ Pragma directive. +/
	@isA_node inst, /++ Instance. +/
	@isA_inst inst_variable, /++ Variable instance. +/
	@isA_inst inst_function, /++ Function instance. +/
	@isA_inst inst_class, /++ Class instance. +/
	@isA_inst inst_interface, /++ Interface instance. +/
	@isA_inst inst_enumeration, /++ Enumeration instance. +/
	@isA_inst inst_union, /++ Union instance. +/
	@isA_inst inst_struct, /++ Struct instance. +/
	@isA_node stmt, /++ Statement. +/
	@isA_stmt stmt_assignment, /++ Assignment Statement. +/
	@isA_stmt_assignment stmt_assignment_add,
	@isA_stmt_assignment stmt_assignment_sub,
	@isA_stmt_assignment stmt_assignment_mul,
	@isA_stmt_assignment stmt_assignment_div,
	@isA_stmt_assignment stmt_assignment_pow,
	@isA_stmt_assignment stmt_assignment_shl,
	@isA_stmt_assignment stmt_assignment_shr,
	@isA_stmt_assignment stmt_assignment_rol,
	@isA_stmt_assignment stmt_assignment_ror,
	@isA_stmt_assignment stmt_assignment_cat,
	@isA_stmt stmt_cflow, /++ Control-Flow Statement. +/
	@isA_stmt_cflow stmt_if, /++ If statement. +/
	@isA_stmt_cflow stmt_switch, /++ Switch statement. +/
	@isA_stmt_cflow stmt_for, /++ For statement. +/
	@isA_stmt_cflow stmt_while, /++ While statement. +/
	@isA_stmt_cflow stmt_doWhile, /++ Do-while statement. +/
	@isA_stmt_cflow stmt_break, /++ Break statement. +/
	@isA_stmt_cflow stmt_continue, /++ Continue statement. +/
	@isA_stmt_cflow stmt_return, /++ Return statement. +/
	@isA_stmt_cflow stmt_goto, /++ Goto statement. +/
	@isA_stmt_cflow stmt_block_try, /++ Try block statement. +/
	@isA_stmt_cflow stmt_block_catch, /++ Catch block statement. +/
	@isA_stmt_cflow stmt_block_finally, /++ Finally block statement. +/
	@isA_stmt stmt_throw, /++ Throw statement. +/
	@isA_stmt stmt_import, /++ Import statement. +/
	@isA_stmt_import stmt_import_module, /++ Import stmt of public module(s). +/
	@isA_stmt_import_module stmt_import_module_public, /++ Import stmt of public module(s). +/
	@isA_stmt_import_module stmt_import_module_private, /++ Import stmt of private module(s) (default). +/
	@isA_stmt_import_module stmt_import_symbol, /++ Symbol import statement. +/
	@isA_stmt_import_module stmt_import_symbol_public, /++ Import stmt of public symbol(s). +/
	@isA_stmt_import_module stmt_import_symbol_private, /++ Import stmt of private symbol(s). +/
	@isA_stmt stmt_namespace_using, /++ Namespace using. (C++). +/
	@isA_node modi_access, /++ Access modifier. +/
	@isA_modi_access modi_access_public, /++ Unrestricted access. +/
	@isA_modi_access modi_access_protected, /++ Access restricted to class and sub-classes. (C++'s `protected`). +/
	@isA_modi_access modi_access_package, /++ Access restricted to current package. (D's `package`). +/
	@isA_modi_access modi_access_private_aggregate, /++ Aggregate-scope private qualifier (C++'s `private`). +/
	@isA_modi_access modi_access_private_module, /++ Module-scope private qualifier (D's `private`). +/
	@isA_modi_access modi_access_mutable, /++ Mutable qualifier. +/
	@isA_modi_access modi_access_constant, /++ Constant qualifier. +/
	@isA_modi_access modi_access_immutable, /++ Immutable qualifier. +/
	@isA_modi_access modi_access_unique, /++ Unique-reference qualifier. +/
	@isA_modi_access_unique modi_access_owned, /++ Unique-and-owning-reference qualifier. See Mojo's `owned`. +/
	@isA_modi_access modi_access_scope, /++ Scope qualifier. +/
	@isA_node annotation,
	@isA_node attr,
	@isA_attr attr_inline, /++ Attribute inline. +/
	@isA_node decorator,
	@isA_node language_specific, /++ Such C Preprocessor (CPP) directives. +/
}

/+ `NodeTypeCode` Predicates. +/

enum isA_token;
enum isA_comment;
enum isA_litr;
enum isA_litr_scalar;
enum isA_litr_numeric;
enum isA_litr_numeric_integer;
enum isA_type;
enum isA_type_aggregate;
enum isA_type_value_aggregate;
enum isA_type_scalar;
enum isA_type_vector;
enum isA_machinewordtype;
enum isA_type_addr;
enum isA_node;
enum isA_expr;
enum isA_expr_unary;
enum isA_expr_unary_arith;
enum isA_expr_binary;
enum isA_expr_binary_arith;
enum isA_expr_ternary;
enum isA_decl;
enum isA_decl_type;
enum isA_defi;
enum isA_defi_type;
enum isA_defi_variable;
enum isA_directive;
enum isA_inst;
enum isA_stmt;
enum isA_stmt_assignment;
enum isA_stmt_import;
enum isA_stmt_import_module;
enum isA_stmt_cflow;
enum isA_modi_access;
enum isA_modi_access_unique;
enum isA_attr;

version (none): // unused

class Point {}
class Node {}
class Token : Node {
@safe pure nothrow /+@nogc+/:
	@property Point start() const { return new typeof(return)(); }
	@property Point end() const { return new typeof(return)(); }
}
class Comment : Token {}
class EndOfLineComment : Token {}
class MultiLineComment : Token {}
class Literal : Token {}
class StringLiteraleral : Literal {}
class CharacterLiteraleral : Literal {}
class NumericLiteraleral : Literal {}
class IntegerLiteraleral : Literal {}
class FloatingPointLiteraleral : Literal {}
class Symbol : Token {}
class SymbolReference : Token {}
class Tree : Node {}
class Declaration : Tree {
@safe pure nothrow @nogc:
	Node[] ctParams; ///< Compile-time parameters.
	@property bool isTemplate() const => ctParams.length != 0;
}
class Type : Declaration {}
class ScalarType : Type {}
class ArithmeticType : ScalarType {}
class CharacterType : ScalarType {}
class StringType : Type {}
class AggregateType : Type {}
class ValueAggregateType : AggregateType {}
class StructType : ValueAggregateType {}
class AnonymousStructType : AggregateType {}
alias TupleType = AnonymousStructType;
class UnionType : AggregateType {}
class ClassType : AggregateType {}
class EnumerationType : Type {}
class ArrayType : Type {}
class MachineWordType : Type {}
class AddressType : MachineWordType {}
class SizeType : MachineWordType {}
class PointerType : AddressType {} // pointer
class ReferenceType : AddressType {} // D class
class FunctionType : Type {}
class Definition : Node {}
class LabelDefinition : Definition {}
class FunctionDefinition : Definition {}
class ClassDefinition : Definition {}
class InterfaceDefinition : Definition {}
class EnumDefinition : Definition {}
class UnionDefinition : Definition {}
class StructDefinition : Definition {}
class Instance : Node {}
class VariableInstance : Instance {}
class FunctionInstance : Instance {}
class ClassInstance : Instance {}
class InterfaceInstance : Instance {}
class EnumInstance : Instance {}
class UnionInstance : Instance {}
class StructInstance : Instance {}
class Statement {}
class FunctionCallStatement : Statement {}
class ControlflowStatement : Statement {}
class IfStatement : ControlflowStatement {}
class SwitchStatement : ControlflowStatement {}
class ForStatement : ControlflowStatement {}
class WhileStatement : ControlflowStatement {}
class DoWhileStatement : ControlflowStatement {}
class BreakStatement : ControlflowStatement {}
class ContinueStatement : ControlflowStatement {}
class ReturnStatement : ControlflowStatement {}
class GotoStatement : ControlflowStatement {}
class ExceptionHandling : Node {}
class TryBlock : ExceptionHandling {}
class CatchBlock : ExceptionHandling {}
class FinallyBlock : ExceptionHandling {}
class ThrowStatement : ExceptionHandling {}
class Module : Node {}
class Package : Node {}
class ImportStatement : Node {}
class SymbolImportStatement : Node {}
class AccessModifiers {}
class PublicModifier : AccessModifiers {}
class PrivateModifier : AccessModifiers {}
class ProtectedModifier : AccessModifiers {}
class InternalModifier : AccessModifiers {}
class Annotation : Node {}
class Decorator : Node {}
class Concurrency {}
class Thread : Concurrency {}
class AsyncAwait : Concurrency {}
class Lock : Concurrency {}

@safe pure nothrow unittest {
	auto d = new Declaration();
	assert(!d.isTemplate);
}
