/** Lazy Substitution Algorithms.
 *
 * See_Also: http://forum.dlang.org/post/pymxzazxximtgixzbnpq@forum.dlang.org
 */
module nxt.substitution;

import std.range.primitives : isInputRange, ElementType;
import core.internal.traits : Unqual;
import std.typecons : Tuple;
import std.traits : isExpressionTuple;
import std.algorithm.searching : startsWith;

import nxt.traits_ex : hasEvenLength, haveCommonType;

import std.stdio;

version (unittest)
{
	import std.algorithm.comparison : equal;
}

import std.traits : isExpressionTuple;
import nxt.traits_ex : haveCommonType;

/** Similar to $(D among) but for set of replacements/substitutions $(D substs).
 *
 * Time-Complexity: O(1) thanks to D's $(D switch) guaranteeing O(1).
 */
template substitute(substs...)
if ((substs.length & 1) == 0 && // need even number of elements (>= 1)
	substs.length >= 2 && // and at least one replacement pair
	isExpressionTuple!substs &&
	haveCommonType!(substs))
{
	Value substitute(Value)(Value value)
	if (haveCommonType!(Value, substs)) /+ TODO: need static map incorrect +/
	{
		switch (value)
		{
			static foreach (i; 0 .. substs.length / 2)
			{
			case substs[2*i]:
				return substs[2*i + 1];
			}
		default:
			return value;
		}
	}
}

pure nothrow @safe unittest {
	auto xyz_abc__(T)(T value)
	{
		immutable a = "a";
		const b = "b";
		auto c = "c";
		return value.substitute!("x", a,
								 "y", b,
								 "z", c);
	}
	assert(xyz_abc__("x") == "a");
	assert(xyz_abc__("y") == "b");
	assert(xyz_abc__("z") == "c");
	assert(xyz_abc__("w") == "w");
}

/** Substitute in parallel all elements in $(D r) which equal (according to $(D
 * pred)) $(D ss[2*n]) with $(D ss[2*n + 1]) for $(D n) = 0, 1, 2, ....
 */
auto substitute(alias pred = (a, b) => a == b, R, Ss...)(R r, Ss ss)
if (isInputRange!(Unqual!R) &&
	Ss.length >= 2 &&
	hasEvenLength!Ss &&
	haveCommonType!(ElementType!R, Ss))
{
	import std.algorithm.iteration : map;
	import std.functional : binaryFun;
	enum n = Ss.length / 2;
	auto replaceElement(E)(E e)
	{
		static foreach (i; 0 .. n)
		{
			if (binaryFun!pred(e, ss[2*i]))
			{
				return ss[2*i + 1];
			}
		}
		return e;
	}
	return r.map!(a => replaceElement(a));
}

///
pure @safe unittest {
	import std.conv : to;
	import std.algorithm : map;
	auto x = `42`.substitute('2', '3')
				 .substitute('3', '1');
	static assert(is(ElementType!(typeof(x)) == dchar));
	assert(equal(x, `41`));
}

///
pure @safe unittest {
	assert(`do_it`.substitute('_', ' ')
				  .equal(`do it`));
	int[3] x = [1, 2, 3];
	auto y = x[].substitute(1, 0.1)
				.substitute(0.1, 0.2);
	static assert(is(typeof(y.front) == double));
	assert(y.equal([0.2, 2, 3]));
	assert(`do_it`.substitute('_', ' ',
							  'd', 'g',
							  'i', 't',
							  't', 'o')
				  .equal(`go to`));
	import std.range : retro;
	assert(equal([1, 2, 3].substitute(1, 0.1)
						  .retro,
				 [3, 2, 0.1]));
}

/** Substitute in parallel all elements in $(D r) which equal (according to $(D
	pred)) $(D ss[2*n]) with $(D ss[2*n + 1]) for $(D n) = 0, 1, 2, ....

	Because $(D ss) are known at compile time, time-complexity for each element
	substitution is O(1).
*/
template substitute(ss...)
if (isExpressionTuple!ss &&
	ss.length >= 2 &&
	hasEvenLength!ss)
{
	auto substitute(R)(R r)
		if (isInputRange!(Unqual!R) &&
			haveCommonType!(ElementType!R, ss))
	{
		import std.algorithm.iteration : map;
		enum n = ss.length / 2;
		auto replaceElement(E)(E e)
		{
			switch (e)
			{
				static foreach (i; 0 .. n)
				{
				case ss[2*i]: return ss[2*i + 1];
				}
			default: return e;
			}
		}
		return r.map!(a => replaceElement(a));
	}
}

///
pure @safe unittest {
	assert(`do_it`.substitute!('_', ' ')
				  .equal(`do it`));
	int[3] x = [1, 2, 3];
	auto y = x[].substitute!(1, 0.1);
	assert(y.equal([0.1, 2, 3]));
	static assert(is(typeof(y.front) == double));
	assert(`do_it`.substitute!('_', ' ',
							   'd', 'g',
							   'i', 't',
							   't', 'o')
				  .equal(`go to`));
	import std.range : retro;
	assert(equal([1, 2, 3].substitute!(1, 0.1)
						  .retro,
				 [3, 2, 0.1]));
}

/** Helper range for subsequence overload of $(D substitute).
 */
private auto substituteSplitter(alias pred = `a == b`, R, Rs...)(R haystack, Rs needles)
if (Rs.length >= 1 &&
	is(typeof(startsWith!pred(haystack, needles))))
{
	static struct Result
	{
		alias Hit = size_t; // 0 iff no hit, otherwise hit in needles[index-1]
		alias E = Tuple!(R, Hit);
		this(R haystack, Rs needles)
		{
			this._rest = haystack;
			this._needles = needles;
			popFront();
		}

		@property auto ref front()
		{
			import std.range.primitives : empty;
			return !_skip.empty ? E(_skip, 0) : E(_hit, _hitNr);
		}

		import std.range.primitives : isInfinite;
		static if (isInfinite!R)
			enum empty = false; // propagate infiniteness
		else
			bool empty() const @property
			{
				import std.range.primitives : empty;
				return _skip.empty && _hit.empty && _rest.empty;
			}

		void popFront() @trusted
		{
			import std.range.primitives : empty;
			if (!_skip.empty)
			{
				_skip = R.init; // jump over _skip
			}
			else
			{
				import std.algorithm.searching : find;

				static if (_needles.length >= 2) // if variadic version
				{
					auto match = _rest.find!pred(_needles);
					auto hitValue = match[0];
					_hitNr = match[1];
				}
				else
				{
					auto match = _rest.find!pred(_needles);
					auto hitValue = match;
					_hitNr = !match.empty ? 1 : 0;
				}

				if (_hitNr == 0) // no more hits
				{
					_skip = _rest;
					_hit = R.init;
					_rest = R.init;
				}
				else
				{
					import std.traits : isSomeString;
					static if (isSomeString!R)
					{
						size_t hitLength = size_t.max;
						final switch (_hitNr - 1)
						{
							foreach (const i, Ri; Rs)
							{
							case i: hitLength = _needles[i].length; break;
							}
						}
						assert(hitLength != size_t.max); // not needed if match returned bounded!int

						if (_rest.ptr == hitValue.ptr) // match at start of _rest
						{
							_hit = hitValue[0 .. hitLength];
							_rest = hitValue[hitLength .. $];
						}
						else
						{
							_skip = _rest[0 .. hitValue.ptr - _rest.ptr];
							_hit = hitValue[0 .. hitLength];
							_rest = hitValue[hitLength .. $];
						}
					}
					else
					{
						static assert(0, `Handle R without slicing ` ~ R.stringof);
					}
				}
			}
		}
	private:
		R _rest;
		Rs _needles;
		R _skip; // skip before next hit
		R _hit; // most recent (last) hit if any
		size_t _hitNr; // hit number: 0 means no hit, otherwise index+1 to needles that matched
	}
	return Result(haystack, needles);
}

pure @safe unittest {
	auto h = `alpha.beta.gamma`;
	auto fs = h.substituteSplitter(`alpha`, `beta`, `gamma`);
	alias FS = typeof(fs);
	alias E = ElementType!FS;
	static assert(is(E == Tuple!(string, ulong)));
	assert(equal(fs, [E(`alpha`, 1),
					  E(`.`, 0),
					  E(`beta`, 2),
					  E(`.`, 0),
					  E(`gamma`, 3)]));
}

pure @safe unittest {
	auto h = `.alpha.beta.gamma`;
	auto fs = h.substituteSplitter(`alpha`, `beta`, `gamma`);
	alias FS = typeof(fs);
	alias E = ElementType!FS;
	static assert(is(E == Tuple!(string, ulong)));
	assert(equal(fs, [E(`.`, 0),
					  E(`alpha`, 1),
					  E(`.`, 0),
					  E(`beta`, 2),
					  E(`.`, 0),
					  E(`gamma`, 3)]));
}

pure @safe unittest {
	auto h = `alpha.beta.gamma.`;
	auto fs = h.substituteSplitter(`alpha`, `beta`, `gamma`);
	alias FS = typeof(fs);
	alias E = ElementType!FS;
	static assert(is(E == Tuple!(string, ulong)));
	assert(equal(fs, [E(`alpha`, 1),
					  E(`.`, 0),
					  E(`beta`, 2),
					  E(`.`, 0),
					  E(`gamma`, 3),
					  E(`.`, 0)]));
}

pure @safe unittest {
	auto h = `alpha.alpha.alpha.`;
	auto fs = h.substituteSplitter(`alpha`);
	alias FS = typeof(fs);
	alias E = ElementType!FS;
	static assert(is(E == Tuple!(string, ulong)));
	assert(equal(fs, [E(`alpha`, 1),
					  E(`.`, 0),
					  E(`alpha`, 1),
					  E(`.`, 0),
					  E(`alpha`, 1),
					  E(`.`, 0)]));
}

template Stride(size_t stride, size_t offset, Args...)
if (stride > 0)
{
	import std.meta : AliasSeq;
	static if (offset >= Args.length)
	{
		alias Stride = AliasSeq!();
	}
	else static if (stride >= Args.length)
	{
		alias Stride = AliasSeq!(Args[offset]);
	}
	else
	{
		alias Stride = AliasSeq!(Args[offset],
								 Stride!(stride, offset, Args[stride .. $]));
	}
}

/** Substitute in parallel all subsequences in $(D r) which equal (according to
	$(D pred)) $(D ss[2*n]) with $(D ss[2*n + 1]) for $(D n) = 0, 1, 2, ....
*/
auto substitute(alias pred = (a, b) => a == b, R, Ss...)(R r, Ss ss)
if (isInputRange!(Unqual!R) &&
	Ss.length >= 2 &&
	hasEvenLength!Ss &&
	haveCommonType!(ElementType!R,
					ElementType!(Ss[0])))
{
	import std.algorithm.iteration : map;
	import std.functional : binaryFun;

	enum n = Ss.length / 2;

	auto replaceElement(E)(E e)
	{
		auto value = e[0];
		const hitNr = e[1];
		if (hitNr == 0) // not hit
		{
			return value;
		}
		else
		{
			static foreach (i; 0 .. n)
			{
				if (hitNr == i + 1)
				{
					return ss[2*i + 1]; // replacement
				}
			}
			assert(false);
		}
	}

	// extract inputs
	alias Ins = Stride!(2, 0, Ss);
	Ins ins;
	static foreach (i; 0 .. n)
	{
		ins[i] = ss[2*i];
	}

	import std.algorithm.iteration : map, joiner;
	return r.substituteSplitter!pred(ins)
			.map!(a => replaceElement(a))
			.joiner;
}

pure @safe unittest {
	assert(`do_it now, sir`.substitute(`_`, ` `,
									   `d`, `g`,
									   `i`, `t`,
									   `t`, `o`,
									   `now`, `work`,
									   `sir`, `please`)
				  .equal(`go to work, please`));
}

pure @safe unittest {
	assert((`abcDe`.substitute(`a`, `AA`,
							   `b`, `DD`)
				   .substitute('A', 'y',
							   'D', 'x',
							   'e', '1'))
		   .equal(`yyxxcx1`));
}
