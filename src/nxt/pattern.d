/**
   Patterns.

   Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run pattern.d
   Test: ldmd2 -fsanitize=address -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run pattern.d
   Debug: ldmd2 -fsanitize=address -I.. -i -debug -g -checkaction=context -allinst -unittest -main pattern.d && lldb pattern

   Concepts and namings are inspired by regular expressions, symbolic (regular)
   expressions (Emacs' rx.el package), predicate logic and grammars.

   String patterns are matched by their raw bytes for now.

   Copyright: Per Nordlöw 2022-.
   License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors: $(WEB Per Nordlöw)

   TODO: Merge with lpgen.d Node classes
   TODO: Extend `Node` classes to represent `xlg.el` read by `LispFileParser`.
   TODO: Replace `findRawAt(const Data haystack` with `findRawAt(in Data haystack`

   TODO:
   Overload operators & (and), ! (not),

   TODO: Add pattern for expressing inference with `infer`
   (infer
	((x instanceOf X) &
	 (X subClassOf Y))
	 (x instaceOf Y))

   TODO:
   Variables are either
   - _ (ignore)
   - _`x`, _`y`, etc
   - _'x', _'y'
   - _!0, _!1, ..., _!(n-1)

   infer(rel!`desire`(_!`x`, _!`y`) &&
		 rel!`madeOf`(_!`z`, _!`y`),
		 rel!`desire`(_!`x`, _!`z`))

   TODO: Support variables of specific types and inference using predicate logic:
		infer(and(fact(var!'x', rel'desire', var!'y'),
				  fact(var!'z', opt(rel'madeOf',
							  rel'instanceOf'), var!'y'))),
			  pred(var!'x', rel'desire', var!'z'
			  ))

   TODO: Make returns from factory functions immutable.
   TODO: Reuse return patterns from Lit

   TODO
   const s = seq(`al.`.lit,`pha`.lit);
   const t = `al`.lit ~ `pha`.lit;
   assert(s !is t);
   assert(equal(s, t));

 */
module nxt.pattern;

import std.algorithm : find, all, map, min, max, joiner;
import std.range : empty;
import std.array : array;
import std.string : representation;
import std.traits : isSomeString;
import nxt.find_ex : findAcronymAt, FindContext;
import nxt.debugio;
import nxt.container.dynamic_array;

@safe:

/++ Untyped data.
 +/
alias Data = ubyte[];

/++ Matching `input` with `node`.
	Compatibility with `std.regex.matchFirst`.
 +/
inout(char)[] matchFirst(scope return /+ref+/ inout(char)[] input, const Node node) pure nothrow /+@nogc+/ {
	return input.match(node);
}

/// ditto
@safe pure unittest {
	const x = "ab";
	assert(x.matchFirst(lit(x[0 .. 1])) is x[0 .. $]);
	assert(x.matchFirst(lit(x[1 .. 2])) is x[1 .. 2]);
}

/** Match `input` with `node`.
	Returns: Matched slice or `[]` if not match.
 */
auto ref matchFirst(in return /+ref+/ Data input, const Node node) pure nothrow /+@nogc+/ {
	return node.findRawAt(input, 0);
}

/// ditto
@safe pure unittest {
	/+const+/ Data x = [1,2];
	assert(x.matchFirst(lit(x[0 .. 1])) is x[0 .. $]);
	assert(x.matchFirst(lit(x[1 .. 2])) is x[1 .. 2]);
}

inout(char)[] match(scope return /+ref+/ inout(char)[] input, const Node node) @trusted pure nothrow /+@nogc+/ {
	return cast(typeof(return))input.representation.matchFirst(node);
}

/++ Pattern (length) bounds. +/
struct Bounds {
	static immutable inf = size_t.max;
	size_t low; ///< Smallest length possible.
	size_t high; ///< Largest length possible.
}

/** Base Pattern.
 */
abstract extern(C++) class Node { extern(D):
@safe pure nothrow:

	Seq opBinary(string op)(Node rhs) if (op == `~`) => opCatImpl(rhs); // template can't be overridden
	Alt opBinary(string op)(Node rhs) if (op == `|`) => opAltImpl(rhs); // template can't be overridden

	protected Seq opCatImpl(Node rhs) => seq(this, rhs); /+ TODO: check if this and rhs is Seq +/
	protected Alt opAltImpl(Node rhs) => alt(this, rhs);  /+ TODO: check if this and rhs is Alt +/

	final size_t at(const scope string input, size_t soff = 0) const
	/+ TODO: Activate this +/
	/* out (hit) { */
	/*	 assert((!hit) || hit >= bounds.min); /+ TODO: Is this needed? +/ */
	/* } */
	/* do */
	{
		return atRaw(input.representation, soff);
	}

	abstract size_t atRaw(in Data input, size_t soff = 0) const @nogc;

	/** Find $(D this) in String `input` at offset `soff`. */
	final const(Data) findAt(const return scope string input, size_t soff = 0) const {
		return findRawAt(input.representation, soff, []); /+ TODO: this is ugly +/
	}

	/** Find $(D this) in Raw Bytes `input` at offset `soff`. */
	const(Data) findRawAt(const Data input, size_t soff = 0, in Node[] enders = []) const @nogc {
		auto i = soff;
		while (i < input.length) { // while bytes left at i
			if (input.length - i < bounds.low)  // and bytes left to find pattern
				return [];
			const hit = atRaw(input, i);
			if (hit != size_t.max) // hit at i
				return input[i..i + hit];
			i++;
		}
		return [];
	}

@property @nogc:
	abstract Bounds bounds() const;

	abstract bool isFixed() const; /// Returns: true if all possible instances have same length.
	abstract bool isConstant() const; /// Returns: true if all possible instances have same length.

	final bool isVariable() => !isConstant;
	const(Data) tryGetConstant() const => []; /// Returns: data if literal otherwise empty array.

	/** Get All Literals that must match a given source $(D X) in order for $(D
		this) to match $(D X) somewhere.
	*/
	version (none) abstract Lit[] mandatories();

	/** Get Optional Literals that may match a given source $(D X) if $(D this)
		matches $(D X) somewhere.
	*/
	version (none) Lit[] optionals() => mandatories;

	protected Node _parent; /// Parenting (Super) Pattern.
}

/** Literal Pattern with Cached Binary Byte Histogram.
 */
final extern(C++) class Lit : Node { extern(D):
@safe pure nothrow:

	this(string bytes_) { assert(!bytes_.empty); this(bytes_.representation); }
	this(ubyte ch) { this._bytes ~= ch; }
	this(Data bytes_) { this._bytes = bytes_; }
	this(immutable Data bytes_) { this._bytes = bytes_.dup; }

	override size_t atRaw(in Data input, size_t soff = 0) const {
		const l = _bytes.length;
		return (soff + l <= input.length && // fits in input and
				_bytes[] == input[soff..soff + l]) ? l : size_t.max; // same contents
	}

	override const(Data) findRawAt(const Data input, size_t soff = 0, in Node[] enders = []) const nothrow {
		return input[soff..$].find(_bytes); // reuse std.algorithm: find!
	}

@property nothrow @nogc:
	auto ref bytes() const => _bytes;
	private Data _bytes;
	alias _bytes this;
override:
	Bounds bounds() const => Bounds(_bytes.length, _bytes.length);
	bool isFixed() const => true;
	bool isConstant() const => true;
	const(Data) tryGetConstant() const => _bytes;
	version (none) Lit[] mandatories() => [this];
}

/++ Literal. +/
auto lit(Args...)(Args args) @safe pure nothrow => new Lit(args); // instantiator

/++ Full|Exact literal. +/
auto full(Args...)(Args args) @safe pure nothrow => seq(bob, lit(args), eob); // instantiator

pure nothrow @safe unittest {
	const _ = lit(Data.init);
	const ab = lit(`ab`);
	assert(`ab`.match(ab));
	version (none) assert(!ab.match(`_`)); // TODO: enable
}

pure nothrow @safe unittest {
	immutable ab = `ab`;
	assert(lit('b').at(`ab`, 1) == 1);
	const a = lit('a');

	const ac = lit(`ac`);
	assert(`ac`.match(ac));
	assert(`ac`.match(ac).length == 2);
 	assert(`ca`.match(ac) == []);

	assert(a.isFixed);
	assert(a.isConstant);
	assert(a.at(ab) == 1);
	assert(lit(ab).at(`a`) == size_t.max);
	assert(lit(ab).at(`b`) == size_t.max);

	assert(a.findAt(`cba`) == cast(immutable Data)`a`);
	assert(a.findAt(`ba`) == cast(immutable Data)`a`);
	assert(a.findAt(`a`) == cast(immutable Data)`a`);
	assert(a.findAt(``) == []);
	assert(a.findAt(`b`) == []);
	assert(ac.findAt(`__ac`) == cast(immutable Data)`ac`);
	assert(a.findAt(`b`).length == 0);

	auto xyz = lit(`xyz`);
}

pure nothrow @safe unittest {
	auto ac = lit(`ac`);
	/+ TODO: assert(ac.mandatories == [ac]); +/
	/+ TODO: assert(ac.optionals == [ac]); +/
}

/** Word/Symbol Acronym Pattern.
 */
version (none) // TODO: enable if and when I need this
final extern(C++) class Acronym : Node { extern(D):
@safe pure nothrow:

	this(string bytes_, FindContext ctx = FindContext.inSymbol) {
		assert(!bytes_.empty);
		this(bytes_.representation, ctx);
	}

	this(ubyte ch) { this._acros ~= ch; }

	this(Data bytes_, FindContext ctx = FindContext.inSymbol) {
		this._acros = bytes_;
		this._ctx = ctx;
	}

	this(immutable Data bytes_, FindContext ctx = FindContext.inSymbol) {
		this._acros = bytes_.dup;
		this._ctx = ctx;
	}

	override size_t atRaw(in Data input, size_t soff = 0) const @nogc {
		// scope auto offs = new size_t[_acros.length]; // hit offsets
		size_t a = 0;		 // acronym index
		foreach(s, ub; input[soff..$]) { // for each element in source
			import std.ascii: isAlpha;

			// Check context
			final switch (_ctx) {
			case FindContext.inWord:
			case FindContext.asWord:
				if (!ub.isAlpha)
					return size_t.max;
				break;
			case FindContext.inSymbol:
			case FindContext.asSymbol:
				if (!ub.isAlpha && ub != '_')
					return size_t.max;
				break;
			}

			if (_acros[a] == ub) {
				// offs[a] = s + soff; // store hit offset
				a++; // advance acronym
				if (a == _acros.length) { // if complete acronym found
					return s + 1;			 // return its length
				}
			}
		}
		return size_t.max; // no hit
	}

	template Tuple(E...) { alias Tuple = E; }

	override const(Data) findRawAt(const Data input, size_t soff = 0, in Node[] enders = []) const nothrow {
		import std.string: CaseSensitive;
		return input.findAcronymAt(_acros, _ctx, CaseSensitive.yes, soff)[0];
	}

@property:
	override size_t bounds() const nothrow @nogc => typeof(return)(_acros.length, size_t.max);
	override bool isFixed() const nothrow @nogc => false;
	override bool isConstant() const nothrow @nogc => false;

private:
	Data _acros;
	FindContext _ctx;
}

version (none)
@safe pure nothrow {
	auto inwac(Args...)(Args args) => new Acronym(args, FindContext.inWord); // word acronym
	auto insac(Args...)(Args args) => new Acronym(args, FindContext.inSymbol); // symbol acronym
	auto aswac(Args...)(Args args) => new Acronym(args, FindContext.asWord); // word acronym
	auto assac(Args...)(Args args) => new Acronym(args, FindContext.asSymbol); // symbol acronym
}

version (none)
pure nothrow @safe unittest {
	assert(inwac(`a`).at(`a`) == 1);
	assert(inwac(`ab`).at(`ab`) == 2);
	assert(inwac(`ab`).at(`a`) == size_t.max);
	assert(inwac(`abc`).at(`abc`) == 3);
	assert(inwac(`abc`).at(`aabbcc`) == 5);
	assert(inwac(`abc`).at(`aaaabbcc`) == 7);
	assert(inwac(`fpn`).at(`fopen`) == 5);
}

/** Any Byte.
 */
final extern(C++) class Any : Node { extern(D):
@safe pure nothrow:
	this() {}

	override size_t atRaw(in Data input, size_t soff = 0) const => soff < input.length ? 1 : size_t.max;

@property:
	override Bounds bounds() const nothrow @nogc => typeof(return)(1, 1);
	override bool isFixed() const nothrow @nogc => true;
	override bool isConstant() const nothrow @nogc => false;

	version (none) override Lit[] mandatories() nothrow => [];
	version (none) override Lit[] optionals() nothrow {
		import std.range: iota;
		return iota(0, 256).map!(n => (cast(ubyte)n).lit).array;
	}
}

auto any(Args...)(Args args) => new Any(args); // instantiator

/** Abstract Super Pattern.
 */
abstract extern(C++) class SPatt : Node { extern(D):
@safe pure nothrow:

	this(Node[] subs_) { this._subs = subs_; }
	this(Args...)(Args subs_) {
		foreach (sub; subs_) {
			alias Sub = typeof(sub);
			/+ TODO: functionize to patternFromBuiltinType() or to!Node +/
			static if (is(Sub == string) ||
					   is(Sub == char)) {
				_subs ~= new Lit(sub);
			} else
				_subs ~= sub;
			sub._parent = this;
		}
	}

	protected Node[] _subs;
}

/** Sequence of Patterns.
 */
final extern(C++) class Seq : SPatt { extern(D):
@safe pure nothrow:

	this(Node[] subs_) { super(subs_); }
	this(Args...)(Args subs_) { super(subs_); }

	@property auto ref inout (Node[]) elms() inout @nogc => super._subs;

	override size_t atRaw(in Data input, size_t soff = 0) const @nogc {
		assert(!elms.empty); /+ TODO: Move to in contract? +/
		const c = tryGetConstant;
		if (!c.empty) {
			return (soff + c.length <= input.length &&   // if equal size and
					c[] == input[soff..soff + c.length]); // equal contents
		}
		size_t sum = 0;
		size_t off = soff;
		foreach (ix, sub; elms) { /+ TODO: Reuse std.algorithm instead? +/
			size_t hit = sub.atRaw(input, off);
			if (hit == size_t.max) { sum = hit; break; } // if any miss skip
			sum += hit;
			off += hit;
		}
		return sum;
	}

@property:
	override Bounds bounds() const nothrow @nogc {
		typeof(return) result;
		foreach (const ref sub; _subs) {
			if (sub.bounds.low != size_t.max)
				result.low += sub.bounds.low; // TODO: catch overflow
			if (sub.bounds.high != size_t.max)
				result.high += sub.bounds.high; // TODO: catch overflow
		}
		return result;
	}
	override bool isFixed() const nothrow @nogc => _subs.all!(a => a.isFixed);
	override bool isConstant() const nothrow @nogc => _subs.all!(a => a.isConstant);
	override const(Data) tryGetConstant() const @nogc => [];
	version (none) override Lit[] mandatories() nothrow => _subs.map!(node => node.mandatories).joiner.array;
	version (none) override Lit[] optionals() nothrow => _subs.map!(node => node.optionals).joiner.array;
}

auto seq(Args...)(Args args) @safe pure nothrow => new Seq(args); // instantiator

pure nothrow @safe unittest {
	immutable input = `alpha`;

	const s = seq(`al.`.lit,
				  `pha`.lit);
	assert(s.isFixed);
	assert(s.isConstant);
	assert(s.at(input)); // TODO: this should fail
	assert(s.bounds.low == 6);
	assert(s.bounds.high== 6);

	const t = `al`.lit ~ `pha`.lit;

	assert(s !is t);

	const al = seq(`a`.lit, `l`.lit);
	assert(al.at(`a`) == size_t.max); // `al not found in `a`
}

@trusted pure nothrow unittest {
	auto a = `aa.`.lit;
	auto b = `bb.`.lit;
	auto c = `cc.`.lit;
	auto d = `dd.`.lit;
	auto s = seq(a.opt, b,
				 c.opt, d);
	assert(!s.isFixed);
	assert(!s.isConstant);
	assert(s.bounds.low == b.length + d.length);
	assert(s.bounds.high== a.length + b.length + c.length + d.length);
	/+ TODO: assert(equal(s.mandatories, [b, d])); +/
	/+ TODO: assert(equal(s.optionals, [a, b, c, d])); +/
}

/** Alternative of Patterns in $(D ALTS).
 */
final extern(C++) class Alt : SPatt { extern(D):
@safe pure nothrow:

	this(Node[] subs_) { super(subs_); }
	this(Args...)(Args subs_) { super(subs_); }

	size_t atIx(const scope string input, size_t soff, out size_t alt_hix) const {
		return atRaw(input.representation, soff, alt_hix);
	}

	void opOpAssign(string s : "~")(Node sub) {
		import nxt.algorithm.searching : canFind;
		if (!_subs.canFind(sub))
			super._subs ~= sub;
	}

	@property inout(Node[]) alts() inout @nogc => super._subs;

	/** Get Length of hit at index soff in input or size_t.max if none.
	 */
	size_t atRaw(in Data input, size_t soff, out size_t alt_hix) const @nogc {
		assert(!alts.empty);	/+ TODO: Move to in contract? +/
		size_t hit = 0;
		size_t off = soff;
		foreach (ix, sub; alts) { /+ TODO: Reuse std.algorithm instead? +/
			hit = sub.atRaw(input[off..$]);					 // match alternative
			if (hit != size_t.max) { alt_hix = ix; break; } // if any hit were done
		}
		return hit;
	}

	override size_t atRaw(in Data input, size_t soff = 0) const @nogc {
		size_t alt_hix;
		return atRaw(input, soff, alt_hix);
	}

	/** Find $(D this) in `input` at offset `soff`. */
	override const(Data) findRawAt(const Data input, size_t soff = 0, in Node[] enders = []) const nothrow {
		assert(!alts.empty);	/+ TODO: Move to in contract? +/
		switch (alts.length) {
			case 1:
				const a0 = alts[0].tryGetConstant;
				if (!a0.empty) {
					auto hit = input[soff..$].find(a0); // Use: second argument to return alt_hix
					return hit;
				} else
					return alts[0].findRawAt(input, soff, enders); // recurse to it
			case 2:
				const a0 = alts[0].tryGetConstant;
				const a1 = alts[1].tryGetConstant;
				if (!a0.empty &&
					!a1.empty) {
					auto hit = input[soff..$].find(a0, a1); // Use: second argument to return alt_hix
					return hit[0];
				}
				break;
			case 3:
				const a0 = alts[0].tryGetConstant;
				const a1 = alts[1].tryGetConstant;
				const a2 = alts[2].tryGetConstant;
				if (!a0.empty &&
					!a1.empty &&
					!a2.empty) {
					auto hit = input[soff..$].find(a0, a1, a2); // Use: second argument to return alt_hix
					return hit[0];
				}
				break;
			case 4:
				const a0 = alts[0].tryGetConstant;
				const a1 = alts[1].tryGetConstant;
				const a2 = alts[2].tryGetConstant;
				const a3 = alts[3].tryGetConstant;
				if (!a0.empty &&
					!a1.empty &&
					!a2.empty &&
					!a3.empty) {
					auto hit = input[soff..$].find(a0, a1, a2, a3); // Use: second argument to return alt_hix
					return hit[0];
				}
				break;
			case 5:
				const a0 = alts[0].tryGetConstant;
				const a1 = alts[1].tryGetConstant;
				const a2 = alts[2].tryGetConstant;
				const a3 = alts[3].tryGetConstant;
				const a4 = alts[4].tryGetConstant;
				if (!a0.empty &&
					!a1.empty &&
					!a2.empty &&
					!a3.empty &&
					!a4.empty) {
					auto hit = input[soff..$].find(a0, a1, a2, a3, a4); // Use: second argument to return alt_hix
					return hit[0];
				}
				break;
			default:
				break;
		}
		return super.findRawAt(input, soff, enders); // revert to base case
	}

@property:
	override Bounds bounds() const nothrow @nogc {
		auto result = typeof(return)(size_t.max, size_t.min);
		foreach (const ref sub; _subs) {
			result.low = min(result.low, sub.bounds.low);
			result.high = max(result.high, sub.bounds.high);
		}
		return result;
	}
	override bool isFixed() const nothrow @nogc {
		/+ TODO: Merge these loops using tuple algorithm. +/
		auto mins = _subs.map!(a => a.bounds.low);
		auto maxs = _subs.map!(a => a.bounds.high);
		import nxt.predicates: allEqual;
		return (mins.allEqual && maxs.allEqual);
	}
	override bool isConstant() const nothrow @nogc {
		if (_subs.length == 0)
			return true;
		else if (_subs.length == 1) {
			import std.range: front;
			return _subs.front.isConstant;
		} else
			return false;	   /+ TODO: Maybe handle case when _subs are different. +/
	}
}

auto alt(Args...)(Args args) @safe pure nothrow => new Alt(args); // instantiator

pure nothrow @safe unittest {
	immutable a_b = alt(`a`.lit,
						`b`.lit);

	immutable a__b = (`a`.lit |
					  `b`.lit);

	assert(a_b.isFixed);
	assert(!a_b.isConstant);
	assert(a_b.at(`a`));
	assert(a_b.at(`b`));
	assert(a_b.at(`c`) == size_t.max);

	size_t hix = size_t.max;
	a_b.atIx(`a`, 0, hix); assert(hix == 0);
	a_b.atIx(`b`, 0, hix); assert(hix == 1);

	/* assert(alt.at(`a`) == size_t.max); */
	/* assert(alt.at(``) == size_t.max); */

	immutable a = alt(lit(`a`));
	immutable aa = alt(lit(`aa`));
	assert(aa.isConstant);

	immutable aa_bb = alt(lit(`aa`),
						  lit(`bb`));
	assert(aa_bb.isFixed);
	assert(aa_bb.bounds.low == 2);
	assert(aa_bb.bounds.high== 2);

	immutable a_bb = alt(lit(`a`),
						 lit(`bb`));
	assert(!a_bb.isFixed);
	assert(a_bb.bounds.low == 1);
	assert(a_bb.bounds.high== 2);

	const string _aa = `_aa`;
	assert(aa_bb.findAt(_aa) == cast(immutable Data)`aa`);
	assert(&aa_bb.findAt(_aa)[0] - &(cast(immutable Data)_aa)[0] == 1);

	const string _bb = `_bb`;
	assert(aa_bb.findAt(_bb) == cast(immutable Data)`bb`);
	assert(&aa_bb.findAt(_bb)[0] - &(cast(immutable Data)_bb)[0] == 1);

	assert(a.findAt(`b`) == []);
	assert(aa.findAt(`cc`) == []);
	assert(aa_bb.findAt(`cc`) == []);
	assert(aa_bb.findAt(``) == []);
}

pure nothrow @safe unittest {
	auto a_b = alt(`a`.lit);
	a_b ~= `b`.lit;

	assert(a_b.isFixed);
	assert(!a_b.isConstant);
	assert(a_b.at(`a`));
	assert(a_b.at(`b`));
	assert(a_b.at(`c`) == size_t.max);

	size_t hix = size_t.max;
	a_b.atIx(`a`, 0, hix); assert(hix == 0);
	a_b.atIx(`b`, 0, hix); assert(hix == 1);
}

final extern(C++) class Space : Node { extern(D):
@safe pure nothrow @nogc:
override:
	size_t atRaw(in Data input, size_t soff = 0) const {
		import std.ascii: isWhite;
		return soff < input.length && isWhite(input[soff]) ? 1 : size_t.max;
	}
@property const:
	override Bounds bounds() const nothrow @nogc => typeof(return)(1, 1);
	bool isFixed() => true;
	bool isConstant() => false;
}

auto ws() @safe pure nothrow => new Space(); // instantiator

pure nothrow @safe unittest {
	assert(ws.at(` `) == 1);
	assert(ws.at("\t") == 1);
	assert(ws.at("\n") == 1);
}

/** Abstract Singleton Super Pattern.
 */
abstract extern(C++) class SPatt1 : Node { extern(D):
@safe pure nothrow:
	this(Node sub) {
		this.sub = sub;
		sub._parent = this;
	}
	protected Node sub;
}

/** Optional Sub Pattern $(D count) times.
 */
final extern(C++) class Opt : SPatt1 { extern(D):
@safe pure nothrow:
	this(Node sub) { super(sub); }
override:
	size_t atRaw(in Data input, size_t soff = 0) const {
		assert(soff <= input.length); // include equality because input might be empty and size zero
		const hit = sub.atRaw(input[soff..$]);
		return hit == size_t.max ? 0 : hit;
	}
@property const nothrow @nogc:
	override Bounds bounds() const nothrow @nogc => typeof(return)(0, sub.bounds.high);
	bool isFixed() => false;
	bool isConstant() => false;
	version (none) Lit[] mandatories() nothrow => [];
	version (none) Lit[] optionals() nothrow => sub.optionals;
}

auto opt(Args...)(Args args) => new Opt(args); // optional

pure nothrow @safe unittest {
	assert(`a`.lit.opt.at(`b`) == 0);
	assert(`a`.lit.opt.at(`a`) == 1);
}

/** Repetition Sub Pattern $(D count) times.
 */
final extern(C++) class Rep : SPatt1 { extern(D):
@safe pure nothrow:

	this(Node sub, size_t count) in(count >= 2) {
		super(sub);
		this.countReq = count;
		this.countOpt = 0; // fixed length repetion
	}

	this(Node sub, size_t countMin, size_t countMax) in {
		assert(countMax >= 2);
		assert(countMin <= countMax);
	} do {
		super(sub);
		this.countReq = countMin;
		this.countOpt = countMax - countMin;
	}

	override size_t atRaw(in Data input, size_t soff = 0) const {
		size_t sum = 0;
		size_t off = soff;
		/* mandatory */
		foreach (ix; 0..countReq) /+ TODO: Reuse std.algorithm instead? +/ {
			size_t hit = sub.atRaw(input[off..$]);
			if (hit == size_t.max) { return hit; } // if any miss skip
			off += hit;
			sum += hit;
		}
		/* optional part */
		foreach (ix; countReq..countReq + countOpt) /+ TODO: Reuse std.algorithm instead? +/ {
			size_t hit = sub.atRaw(input[off..$]);
			if (hit == size_t.max) { break; } // if any miss just break
			off += hit;
			sum += hit;
		}
		return sum;
	}

@property override const nothrow @nogc:
	override Bounds bounds() const nothrow @nogc
		=> typeof(return)(countReq*sub.bounds.high, (countReq + countOpt)*sub.bounds.high);
	bool isFixed() => bounds.low == bounds.high && sub.isFixed;
	bool isConstant() => bounds.low == bounds.high && sub.isConstant;
	version (none) Lit[] mandatories() => sub.mandatories;
	version (none) Lit[] optionals() => sub.optionals;

	// invariant { assert(countReq); }
	size_t countReq; // Required.
	size_t countOpt; // Optional.
}

auto rep(Args...)(Args args) => new Rep(args); // repetition
auto zom(Args...)(Args args) => new Rep(args, 0, size_t.max); // zero or more
auto oom(Args...)(Args args) => new Rep(args, 1, size_t.max); // one or more

pure nothrow @safe unittest {
	auto l = 'a'.lit;

	const l5 = l.rep(5);
	assert(l5.isConstant);
	assert(l5.at(`aaaa`) == size_t.max);
	assert(l5.at(`aaaaa`));
	assert(l5.at(`aaaaaaa`));
	assert(l5.isFixed);
	assert(l5.bounds.low == 5);
	assert(l5.bounds.high== 5);

	const countMin = 2;
	const countMax = 3;
	const l23 = l.rep(countMin, countMax);
	assert(l23.at(`a`) == size_t.max);
	assert(l23.at(`aa`) == 2);
	assert(l23.at(`aaa`) == 3);
	assert(l23.at(`aaaa`) == 3);
	assert(!l23.isConstant);
	assert(l23.bounds.low == countMin);
	assert(l23.bounds.high== countMax);
}

pure nothrow @safe unittest {
	auto l = 'a'.lit;
	auto l5 = l.rep(5);
	/+ TODO: assert(l5.mandatories == [l]); +/
	/+ TODO: assert(l5.optionals == [l]); +/
}

pure nothrow @safe unittest {
	auto l = 'a'.lit;
	auto l5 = l.opt.rep(5);
	/+ TODO: assert(l5.mandatories == []); +/
	/+ TODO: assert(l5.optionals == [l]); +/
}

final extern(C++) class Ctx : Node { extern(D):
	enum Type {
		bob, /// Beginning Of \em Block/Name/File/String. @b Emacs: `\``
		beginningOfBlock = bob,
		beginningOfFile = bob,
		beginningOfString = bob,
		eob, /// End	   Of \em Block/Name/File/String. @b Emacs: `\'`
		endOfBlock = eob,
		endOfFile = eob,
		endOfString = eob,

		bol,			/// Beginning Of \em Line. @b Emacs: `^`
		beginningOfLine = bol,
		eol,			/// End	   Of \em Line. @b Emacs: `$`
		endOfLine = eol,

		bos,			/// Beginning Of \em Symbol. @b Emacs: `\_<`
		beginningOfSymbol = bos,
		eos,			/// End	   Of \em Symbol. @b Emacs: `\_>`
		endOfSymbol = eos,

		bow,			/// Beginning Of \em Word. @b Emacs: `\<`
		beginningOfWord = bow,
		eow,			/// End	   Of \em Word. @b Emacs: `\>`
		endOfWord = eow,
	}

@safe pure nothrow:

	this(Type type) { this.type = type; }

	override size_t atRaw(in Data input, size_t soff = 0) const
	{
		assert(soff <= input.length); // include equality because input might be empty and size zero
		bool ok = false;
		import std.ascii : isAlphaNum/* , newline */;
		final switch (type)
		{
			/* buffer */
		case Type.bob: ok = (soff == 0); break;
		case Type.eob: ok = (soff == input.length); break;

			/* line */
		case Type.bol: ok = (soff == 0		  || (input[soff - 1] == 0x0d ||
												   input[soff - 1] == 0x0a)); break;
		case Type.eol: ok = (soff == input.length || (input[soff	] == 0x0d ||
												   input[soff	] == 0x0a)); break;

			/* symbol */
		case Type.bos: ok = ((soff == 0		 || (!input[soff - 1].isAlphaNum &&
													input[soff - 1] != '_')) && /+ TODO: Make '_' language-dependent +/
							 (soff < input.length &&  input[soff].isAlphaNum)) ; break;
		case Type.eos: ok = ((soff == input.length || (!input[soff].isAlphaNum &&
														  input[soff] != '_')) && /+ TODO: Make '_' language-dependent +/
							 (soff >= 1		  &&  input[soff - 1].isAlphaNum)) ; break;

			/* word */
		case Type.bow: ok = ((soff == 0		 || !input[soff - 1].isAlphaNum) &&
							 (soff < input.length &&  input[soff].isAlphaNum)) ; break;
		case Type.eow: ok = ((soff == input.length || !input[soff].isAlphaNum) &&
							 (soff >= 1		  &&  input[soff - 1].isAlphaNum)) ; break;
		}
		return ok ? 0 : size_t.max;
	}
@property override const nothrow @nogc:
	Bounds bounds() => typeof(return)(0, 0);
	bool isFixed() => true;
	bool isConstant() => true;
	protected Type type;
}

Ctx bob(Args...)(Args args) => new Ctx(args, Ctx.Type.bob);
Ctx eob(Args...)(Args args) => new Ctx(args, Ctx.Type.eob);
Ctx bol(Args...)(Args args) => new Ctx(args, Ctx.Type.bol);
Ctx eol(Args...)(Args args) => new Ctx(args, Ctx.Type.eol);
Ctx bos(Args...)(Args args) => new Ctx(args, Ctx.Type.bos);
Ctx eos(Args...)(Args args) => new Ctx(args, Ctx.Type.eos);
Ctx bow(Args...)(Args args) => new Ctx(args, Ctx.Type.bow);
Ctx eow(Args...)(Args args) => new Ctx(args, Ctx.Type.eow);
Seq buf(Args...)(Args args) => seq(bob, args, eob);
Seq line(Args...)(Args args) => seq(bol, args, eol);
Seq sym(Args...)(Args args) => seq(bos, args, eos);
Seq word(Args...)(Args args) => seq(bow, args, eow);

pure nothrow @safe unittest {
	const bob_ = bob;
	const eob_ = eob;
	assert(bob_.at(`ab`) == 0);
	assert(eob_.at(`ab`, 2) == 0);
	assert(bob_.bounds.low == 0);
	assert(bob_.bounds.high== 0);

	const bol_ = bol;
	assert(bol_.at(`ab`) == 0);
	assert(bol_.at("a\nb", 2) == 0);
	assert(bol_.at("a\nb", 1) == size_t.max);
	assert(bol_.bounds.low == 0);
	assert(bol_.bounds.high== 0);

	const eol_ = eol;
	assert(eol_.at(`ab`, 2) == 0);
	assert(eol_.at("a\nb", 1) == 0);
	assert(eol_.at("a\nb", 2) == size_t.max);
	assert(eol_.bounds.low == 0);
	assert(eol_.bounds.high== 0);

	const bos_ = bos;
	const eos_ = eos;
	assert(bos_.at(`ab`) == 0);
	assert(bos_.at(` ab`) == size_t.max);
	assert(eos_.at(`ab`, 2) == 0);
	assert(eos_.at(`a_b `, 1) == size_t.max);
	assert(eos_.at(`ab `, 2) == 0);
	assert(eos_.bounds.low == 0);
	assert(eos_.bounds.high== 0);

	const bow_ = bow;
	const eow_ = eow;
	assert(bow_.bounds.low == 0);
	assert(bow_.bounds.high== 0);
	assert(eow_.bounds.low == 0);
	assert(eow_.bounds.high== 0);

	assert(bow_.at(`ab`) == 0);
	assert(bow_.at(` ab`) == size_t.max);

	assert(eow_.at(`ab`, 2) == 0);
	assert(eow_.at(`ab `, 0) == size_t.max);

	assert(bow_.at(` ab `, 1) == 0);
	assert(bow_.at(` ab `, 0) == size_t.max);

	assert(eow_.at(` ab `, 3) == 0);
	assert(eow_.at(` ab `, 4) == size_t.max);

	auto l = lit(`ab`);
	auto w = word(l);
	assert(w.at(`ab`) == 2);
	assert(w.at(`ab_c`) == 2);

	auto s = sym(l);
	assert(s.at(`ab`) == 2);
	assert(s.at(`ab_c`) == size_t.max);

	assert(bob_.findAt(`a`) == []);
	assert(bob_.findAt(`a`).ptr != null);
	assert(eob_.findAt(`a`) == []);

	assert(bol_.findAt(`a`) == []);
	assert(bol_.findAt(`a`).ptr != null);
	assert(eol_.findAt(`a`) == []);

	assert(bow_.findAt(`a`) == []);
	assert(bow_.findAt(`a`).ptr != null);
	assert(eow_.findAt(`a`) == []);

	assert(bos_.findAt(`a`) == []);
	assert(bos_.findAt(`a`).ptr != null);
	assert(eos_.findAt(`a`) == []);
	/+ TODO: This fails assert(eos_.findAt(`a`).ptr != null); +/
}

/** Keyword $(D arg). */
Seq kwd(Arg)(Arg arg) => seq(bow, arg, eow);

pure nothrow @safe unittest {
	const str = `int`;
	auto x = str.lit.kwd;

	assert(x.at(str, 0));
	/* TODO: assert(!x.at(str, 1)); */

	assert(x.at(` ` ~ str, 1));
	/* TODO: assert(!x.at(` int`, 0)); */
}

/** Pattern Paired with Prefix and Suffix.
 */
final extern(C++) class Clause : SPatt1 { extern(D):
@safe pure nothrow:
	this(Node prefix_, Node suffix_, Node sub) {
		super(sub);
		this.prefix = prefix_;
		this.suffix = suffix_;
	}
	override const(Data) findRawAt(const Data input, size_t soff = 0, in Node[] enders = []) const nothrow @nogc {
		import std.experimental.allocator.mallocator : Mallocator;
		DynamicArray!(Node, Mallocator) enders_;
		enders_.reserve(enders.length == 1);
		() @trusted {
			enders_ ~= cast(Node[])enders;
			enders_ ~= cast()suffix;
		}();
		typeof(return) result = sub.findRawAt(input, soff, enders_[]);
		return result;
	}
	Node prefix, suffix;
}

Clause paired(Args...)(Node prefix, Node suffix, Args args) => new Clause(prefix, suffix, args);
Clause parend(Args...)(Args args) => new Clause(lit('('), lit(')'), args);
Clause hooked(Args...)(Args args) => new Clause(lit('['), lit(']'), args);
Clause braced(Args...)(Args args) => Clause(lit('{'), lit('}'), args);

import nxt.assert_ex;

pure nothrow @safe unittest {
	/* auto p = `[alpha]`.lit.parend; */
	/* assert(p.at(`([alpha])`) == 7); */

	/* auto h = `[alpha]`.lit.hooked; */
	/* assert(h.at(`[[alpha]]`) == 7); */

	/* auto b = `[alpha]`.lit.braced; */
	/* assert(b.at(`{[alpha]}`) == 7); */

	/* auto pb = `[alpha]`.lit.parend; */
}

/** Create Matcher for a UNIX Shell $(LUCKY Shebang) Pattern.
	Example: #!/bin/env rdmd
	See_Also: https://en.wikipedia.org/wiki/Shebang_(Unix)
 */
auto ref shebangLine(Node interpreter) @safe pure nothrow {
	return seq(bob,
			   `#!`.lit,
			   `/usr`.lit.opt,
			   `/bin/env`.lit.opt,
			   ws.oom,
			   interpreter);
}

///
pure nothrow @safe unittest {
	assert(`rdmd`.lit.shebangLine
				 .at(`#!/bin/env rdmd`) == 15);
	assert(`rdmd`.lit.shebangLine
				 .at(`#!/usr/bin/env rdmd`) == 19);
	auto rgdmd = alt(`rdmd`.lit,
					 `gdmd`.lit);
	assert(rgdmd.shebangLine
				.at(`#!/usr/bin/env rdmd-dev`) == 19);
	assert(rgdmd.shebangLine
				.at(`#!/usr/bin/env gdmd`) == 19);
}
