/++ Programming concepts that capture semantic that is common among different
    programming language, both imperative, functional and declarative.

    The class hierarchy together class fields, member functions and UDAs encode
    the semantics of the above mentioned concepts.  +/
module nxt.agnostics;

@safe pure nothrow:

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
class StringLiteral : Literal {}
class CharacterLiteral : Literal {}
class NumericLiteral : Literal {}
class IntegerLiteral : Literal {}
class FloatingPointLiteral : Literal {}
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
class ControlFlowStatement : Statement {}
class IfStatement : ControlFlowStatement {}
class SwitchStatement : ControlFlowStatement {}
class ForStatement : ControlFlowStatement {}
class WhileStatement : ControlFlowStatement {}
class DoWhileStatement : ControlFlowStatement {}
class BreakStatement : ControlFlowStatement {}
class ContinueStatement : ControlFlowStatement {}
class ReturnStatement : ControlFlowStatement {}
class GotoStatement : ControlFlowStatement {}
class ExceptionHandling : Node {}
class TryBlock : ExceptionHandling {}
class CatchBlock : ExceptionHandling {}
class FinallyBlock : ExceptionHandling {}
class ThrowStatement : ExceptionHandling {}
class Module : Node {}
class Package : Node {}
class ImportStatement : Node {}
class SymboImportStatement : Node {}
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
