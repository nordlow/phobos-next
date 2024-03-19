module nxt.graph;

@safe pure nothrow:

import std.array : Appender;

extern(C++) class Graph { extern(D):
	Appender!(Node[]) nodes;
	Appender!(Edge[]) edges;
	Appender!(SuperEdge[]) superEdges;
}

extern(C++) class Entity { extern(D):
@safe pure nothrow:
	abstract inout(Graph) gr() inout;		   // get up-reference
}

extern(C++) class Node : Entity { extern(D):
@safe pure nothrow:
	this(Graph gr) scope @trusted {
		_db = gr;
		gr.nodes.put(this);
	}
	pragma(inline, true)
	override final inout(Graph) gr() inout => _db;
	private Graph _db;			 // up-reference
}

extern(C++) class Text : Node { extern(D):
@safe pure nothrow:
	this(Graph gr, string text) scope @trusted {
		super(gr);
		this.text = text;
	}
	const string text;
}

/// Number with numerical type `T`.
extern(C++) class Number(T) : Node { extern(D):
@safe pure nothrow:
	this(Graph gr, T value) scope @trusted {
		super(gr);
		this.value = value;
	}
	const T value;
}

extern(C++) class Edge : Entity { extern(D):
@safe pure nothrow:
	this(Graph gr) scope @trusted {
		_db = gr;
		gr.edges.put(this);
	}
	pragma(inline, true)
	override final inout(Graph) gr() inout => _db;
	private Graph _db;			 // up-reference
}

extern(C++) class SuperEdge : Entity { extern(D):
@safe pure nothrow:
	this(Graph gr) scope @trusted {
		_db = gr;
		gr.superEdges.put(this);
	}
	pragma(inline, true)
	override final inout(Graph) gr() inout => _db;
	private Graph _db;			 // up-reference
}

extern(C++) class Rela(uint arity) : Edge if (arity >= 2) { extern(D):
@safe pure nothrow:
	this(Graph gr) scope @trusted {
		super(gr);
	}
	Entity[arity] actors;
}

extern(C++) class Func(uint arity) : Edge if (arity >= 1) { extern(D):
@safe pure nothrow:
	this(Graph gr) scope @trusted {
		super(gr);
	}
	Entity[arity] params;
}

pure nothrow @safe unittest {
	auto gr = new Graph();
	scope node = new Node(gr);
	scope edge = new Edge(gr);
	scope rela2 = new Rela!2(gr);
	scope func1 = new Func!1(gr);
}
