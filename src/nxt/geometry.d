/** Geometry and linear algebra primitives.

   TODO: get rid of instantiators in favor of aliases to reduce template bloat
   TODO: Merge https://github.com/andrewlalis/dvec
*/
module nxt.geometry;

import std.traits: isFloatingPoint, isNumeric, isSigned, isDynamicArray, isAssignable, isArray, CommonType;

version = use_cconv;			///< Use cconv for faster compilation.
version = unittestAllInstances;

version (unittestAllInstances)
	static immutable defaultElementTypes = ["float", "double", "real"];
else
	static immutable defaultElementTypes = ["double"];

enum Orient { column, row } // Vector Orientation.

/** `D`-Dimensional Cartesian Point with Coordinate Type (Precision) `E`.
 */
struct Point(E, uint D)
if (D >= 1 /* && TODO: extend trait : isNumeric!E */)
{
	alias ElementType = E;

	this(T...)(T args)
	{
		foreach (immutable ix, arg; args)
			_point[ix] = arg;
	}

	/** Element data. */
	E[D] _point;
	enum dimension = D;

	void toString(Sink)(ref scope Sink sink) const
	{
		sink(`Point(`);
		foreach (const ix, const e; _point)
		{
			if (ix != 0) { sink(","); }
			version (use_cconv)
			{
				import nxt.cconv : toStringInSink;
				toStringInSink(e, sink);
			}
			else
			{
				import std.conv : to;
				sink(to!string(e));
			}
		}
		sink(`)`);
	}

	@property string toMathML()() const
	{
		// opening
		string str = `<math><mrow>
  <mo>(</mo>
  <mtable>`;

		static foreach (i; 0 .. D)
		{
			str ~= `
	<mtr>
	  <mtd>
		<mn>` ~ _point[i].toMathML ~ `</mn>
	  </mtd>
	</mtr>`;
		}

		// closing
		str ~= `
  </mtable>
  <mo>)</mo>
</mrow></math>
`;
		return str;
	}

	/** Returns: Area 0 */
	@property E area() const => 0;

	inout(E)[] opSlice() inout => _point[];

	/** Points +/- Vector => Point */
	auto opBinary(string op, F)(Vector!(F, D) r) const
		if ((op == "+") ||
			(op == "-"))
	{
		Point!(CommonType!(E, F), D) y;
		static foreach (i; 0 .. D)
			y._point[i] = mixin("_point[i]" ~ op ~ "r._vector[i]");
		return y;
	}
}

/** Instantiator for `Point`. */
auto point(Ts...)(Ts args)
if (!is(CommonType!Ts == void))
	=> Point!(CommonType!Ts, args.length)(args);

version (unittest)
{
	alias vec2f = Vector!(float, 2, true);
	alias vec3f = Vector!(float, 3, true);

	alias vec2d = Vector!(float, 2, true);

	alias nvec2f = Vector!(float, 2, true);
}

/** `D`-Dimensional Vector with Coordinate/Element (Component) Type `E`.
 *
 * See_Also: http://physics.stackexchange.com/questions/16850/is-0-0-0-an-undefined-vector
 */
struct Vector(E, uint D,
			  bool normalizedFlag = false, // `true` for unit vectors
			  Orient orient = Orient.column)
if (D >= 1 &&
	(!normalizedFlag ||
	 isFloatingPoint!E)) // only normalize fp for now
{
	// Construct from vector.
	this(V)(V vec)
	if (isVector!V &&
		// TOREVIEW: is(T.E : E) &&
		(V.dimension >= dimension))
	{
		static if (normalizedFlag)
		{
			if (vec.normalized)
			{
				immutable vec_norm = vec.magnitude;
				static foreach (i; 0 .. D)
					_vector[i] = vec._vector[i] / vec_norm;
				return;
			}
		}
		static foreach (i; 0 .. D)
			_vector[i] = vec._vector[i];
	}

	/** Construct from Scalar `value`. */
	this(S)(S scalar)
	if (isAssignable!(E, S))
	{
		static if (normalizedFlag)
		{
			import std.math : sqrt;
			clear(1/sqrt(cast(E)D)); /+ TODO: costly +/
		}
		else
			clear(scalar);
	}

	/** Construct from combination of arguments. */
	this(Args...)(Args args) { construct!(0)(args); }

	enum dimension = D;

	@property const
	{
		string orientationString()()
			=> orient == Orient.column ? `Column` : `Row`;
		string joinString()()
			=> orient == Orient.column ? ` \\ ` : ` & `;
	}

	void toString(Sink)(ref scope Sink sink) const
	{
		sink(orientationString);
		sink(`Vector(`);
		foreach (const ix, const e; _vector)
		{
			if (ix != 0) { sink(","); }
			version (use_cconv)
			{
				import nxt.cconv : toStringInSink;
				toStringInSink(e, sink);
			}
			else
			{
				import std.conv : to;
				sink(to!string(e));
			}
		}
		sink(`)`);
	}

	/** Returns: LaTeX Encoding of Vector. http://www.thestudentroom.co.uk/wiki/LaTex#Matrices_and_Vectors */
	@property string toLaTeX()() const
		=> `\begin{pmatrix} ` ~ map!(to!string)(_vector[]).join(joinString) ~ ` \end{pmatrix}` ;

	@property string toMathML()() const
	{
		// opening
		string str = `<math><mrow>
  <mo>⟨</mo>
  <mtable>`;

		if (orient == Orient.row)
		{
			str ~=  `
	<mtr>`;
		}

		static foreach (i; 0 .. D)
		{
			final switch (orient)
			{
			case Orient.column:
				str ~= `
	<mtr>
	  <mtd>
		<mn>` ~ _vector[i].toMathML ~ `</mn>
	  </mtd>
	</mtr>`;
				break;
			case Orient.row:
				str ~= `
	  <mtd>
		<mn>` ~ _vector[i].toMathML ~ `</mn>
	  </mtd>`;
				break;
			}
		}

		if (orient == Orient.row)
		{
			str ~=  `
	</mtr>`;
		}

		// closing
		str ~= `
  </mtable>
  <mo>⟩</mo>
</mrow></math>
`;
		return str;
	}

	auto randInPlace()(E scaling = 1)
	{
		import nxt.random_ex: randInPlace;
		static if (normalizedFlag &&
				   isFloatingPoint!E) // cannot use normalized() here (yet)
		{
			static if (D == 2)  // randomize on unit circle
			{
				alias P = real; // precision
				immutable angle = uniform(0, 2*cast(P)PI);
				_vector[0] = scaling*sin(angle);
				_vector[1] = scaling*cos(angle);
			}
			static if (D == 3)  // randomize on unit sphere: See_Also: http://mathworld.wolfram.com/SpherePointPicking.html
			{
				alias P = real; // precision
				immutable u = uniform(0, cast(P)1);
				immutable v = uniform(0, cast(P)1);
				immutable theta = 2*PI*u;
				immutable phi = acos(2*v-1);
				_vector[0] = scaling*cos(theta)*sin(phi);
				_vector[1] = scaling*sin(theta)*sin(phi);
				_vector[2] = scaling*cos(phi);
			}
			else
			{
				_vector.randInPlace();
				normalize(); /+ TODO: Turn this into D data restriction instead? +/
			}
		}
		else
		{
			_vector.randInPlace();
		}
	}

	/// Returns: `true` if all values are not `nan` nor `infinite`, otherwise `false`.
	@property bool ok()() const
	{
		static if (isFloatingPoint!E)
		{
			foreach (const ref v; _vector)
				if (isNaN(v) ||
					isInfinity(v))
					return false;
		}
		return true;
	}
	// NOTE: Disabled this because I want same behaviour as MATLAB: bool opCast(T : bool)() const { return ok; }
	bool opCast(T : bool)() const => all!"a"(_vector[]);

	/// Returns: Pointer to the coordinates.
	// @property auto value_ptr() { return _vector.ptr; }

	/// Sets all values to `value`.
	void clear(V)(V value)
	if (isAssignable!(E, V))
	{
		static foreach (i; 0 .. D)
			_vector[i] = value;
	}

	/** Returns: Whole Internal Array of E. */
	auto opSlice() => _vector[];
	/** Returns: Slice of Internal Array of E. */
	auto opSlice(uint off, uint len) => _vector[off .. len];
	/** Returns: Reference to Internal Vector Element. */
	ref inout(E) opIndex(uint i) inout => _vector[i];

	bool opEquals(S)(in S scalar) const
	if (isAssignable!(E, S)) /+ TODO: is(typeof(E.init != S.init)) +/
		=> _vector[] == scalar;

	bool opEquals(F)(in F vec) const
	if (isVector!F &&
		dimension == F.dimension) // TOREVIEW: Use isEquable instead?
		=> _vector == vec._vector;

	bool opEquals(F)(const F[] array) const
	if (isAssignable!(E, F) &&
		!isArray!F &&
		!isVector!F) // TOREVIEW: Use isNotEquable instead?
		=> _vector[] == array;

	static void isCompatibleVectorImpl(uint d)(Vector!(E, d) vec) if (d <= dimension) {}
	static void isCompatibleMatrixImpl(uint r, uint c)(Matrix!(E, r, c) m) {}

	enum isCompatibleVector(T) = is(typeof(isCompatibleVectorImpl(T.init)));
	enum isCompatibleMatrix(T) = is(typeof(isCompatibleMatrixImpl(T.init)));

	private void construct(uint i)()
	{
		static assert(i == D, "Not enough arguments passed to constructor");
	}
	private void construct(uint i, T, Tail...)(T head, Tail tail)
	{
		static		if (i >= D)
		{
			static assert(0, "Too many arguments passed to constructor");
		}
		else static if (is(T : E))
		{
			_vector[i] = head;
			construct!(i + 1)(tail);
		}
		else static if (isDynamicArray!T)
		{
			static assert((Tail.length == 0) && (i == 0), "Dynamic array can not be passed together with other arguments");
			_vector[] = head[];
		}
		else static if (__traits(isStaticArray, T))
		{
			_vector[i .. i + T.length] = head[];
			construct!(i + T.length)(tail);
		}
		else static if (isCompatibleVector!T)
		{
			_vector[i .. i + T.dimension] = head._vector[];
			construct!(i + T.dimension)(tail);
		}
		else
			static assert(0, "Vector constructor argument must be of type " ~ E.stringof ~ " or Vector, not " ~ T.stringof);
	}

	// private void dispatchImpl(int i, string s, int size)(ref E[size] result) const {
	//	 static if (s.length > 0) {
	//		 result[i] = _vector[coordToIndex!(s[0])];
	//		 dispatchImpl!(i + 1, s[1..$])(result);
	//	 }
	// }

	// /// Implements dynamic swizzling.
	// /// Returns: a Vector
	// @property Vector!(E, s.length) opDispatch(string s)() const {
	//	 E[s.length] ret;
	//	 dispatchImpl!(0, s)(ret);
	//	 Vector!(E, s.length) ret_vec;
	//	 ret_vec._vector = ret;
	//	 return ret_vec;
	// }

	ref inout(Vector) opUnary(string op : "+")() inout => this;

	Vector opUnary(string op : "-")() const
	if (isSigned!(E))
	{
		Vector y;
		static foreach (i; 0 .. D)
			y._vector[i] = - _vector[i];
		return y;
	}

	auto opBinary(string op, T)(in T rhs) const
	if (op == "+" || op == "-" &&
		is(T == Vector!(_), _) &&
		dimension && T.dimension)
	{
		Vector!(CommonType!(E, F), D) y;
		static foreach (i; 0 .. D)
			y._vector[i] = mixin("_vector[i]" ~ op ~ "rhs._vector[i]");
		return y;
	}

	Vector opBinary(string op : "*", F)(in F r) const
	{
		Vector!(CommonType!(E, F), D, normalizedFlag) y;
		static foreach (i; 0 .. dimension)
			y._vector[i] = _vector[i] * r;
		return y;
	}

	Vector!(CommonType!(E, F), D) opBinary(string op : "*", F)(in Vector!(F, D) r) const
	{
		// MATLAB-style Product Behaviour
		static if (orient == Orient.column &&
				   r.orient == Orient.row)
			return outer(this, r);
		else static if (orient == Orient.row &&
						r.orient == Orient.column)
			return dot(this, r);
		else
			static assert(0, "Incompatible vector dimensions.");
	}

	/** Multiply with right-hand-side `rhs`. */
	Vector!(E, T.rows) opBinary(string op : "*", T)(in T rhs) const
	if (isCompatibleMatrix!T &&
		(T.cols == dimension))
	{
		Vector!(E, T.rows) ret;
		ret.clear(0);
		static foreach (c; 0 .. T.cols)
			static foreach (r; 0 ..  T.rows)
				ret._vector[r] += _vector[c] * rhs.at(r,c);
		return ret;
	}

	/** Multiply with left-hand-side `lhs`. */
	version (none)			   /+ TODO: activate +/
	auto opBinaryRight(string op, T)(in T lhs) const
	if (!is(T == Vector!(_), _) &&
		!isMatrix!T &&
		!isQuaternion!T)
		=> this.opBinary!(op)(lhs);

	/++ TODO: Suitable Restrictions on F. +/
	void opOpAssign(string op, F)(in F r)
		/* if ((op == "+") || (op == "-") || (op == "*") || (op == "%") || (op == "/") || (op == "^^")) */
	{
		static foreach (i; 0 .. dimension)
			mixin("_vector[i]" ~ op ~ "= r;");
	}
	unittest
	{
		auto v2 = vec2f(1, 3);
		v2 *= 5.0f; assert(v2[] == [5, 15].s);
		v2 ^^= 2; assert(v2[] == [25, 225].s);
		v2 /= 5; assert(v2[] == [5, 45].s);
	}

	void opOpAssign(string op)(in Vector r)
	if ((op == "+") ||
		(op == "-"))
	{
		static foreach (i; 0 .. dimension)
			mixin("_vector[i]" ~ op ~ "= r._vector[i];");
	}

	/// Returns: Non-Rooted `N` - Norm of `x`.
	auto nrnNorm(uint N)() const
	if (isNumeric!E && N >= 1)
	{
		static if (isFloatingPoint!E)
			real y = 0;				 // TOREVIEW: Use maximum precision for now
		else
			E y = 0;				// TOREVIEW: Use other precision for now
		static foreach (i; 0 .. D)
			y += _vector[i] ^^ N;
		return y;
	}

	/// Returns: Squared Magnitude of x.
	@property real magnitudeSquared()() const
	if (isNumeric!E)
	{
		static if (normalizedFlag) // cannot use normalized() here (yet)
			return 1;
		else
			return nrnNorm!2;
	}

	/// Returns: Magnitude of x.
	@property real magnitude()() const
	if (isNumeric!E)
	{
		static if (normalizedFlag) // cannot use normalized() here (yet)
			return 1;
		else
		{
			import std.math : sqrt;
			return sqrt(magnitudeSquared);
		}
	}
	alias norm = magnitude;

	static if (isFloatingPoint!E)
	{
		/// Normalize `this`.
		void normalize()()
		{
			if (this != 0)		 // zero vector have zero magnitude
			{
				immutable m = this.magnitude;
				static foreach (i; 0 .. D)
					_vector[i] /= m;
			}
		}

		/// Returns: normalizedFlag Copy of this Vector.
		@property Vector normalized()() const
		{
			Vector y = this;
			y.normalize();
			return y;
		}

		unittest
		{
			static if (D == 2 && !normalizedFlag)
				assert(Vector(3, 4).magnitude == 5);
		}
	}

	/// Returns: Vector Index at Character Coordinate `coord`.
	private @property ref inout(E) get_(char coord)() inout
	{
		return _vector[coordToIndex!coord];
	}

	/// Coordinate Character c to Index
	template coordToIndex(char c)
	{
		static if ((c == 'x'))
			enum coordToIndex = 0;
		else static if ((c == 'y'))
			enum coordToIndex = 1;
		else static if ((c == 'z'))
		{
			static assert(D >= 3, "The " ~ c ~ " property is only available on vectors with a third dimension.");
			enum coordToIndex = 2;
		}
		else static if ((c == 'w'))
		{
			static assert(D >= 4, "The " ~ c ~ " property is only available on vectors with a fourth dimension.");
			enum coordToIndex = 3;
		}
		else
			static assert(0, "Accepted coordinates are x, s, r, u, y, g, t, v, z, p, b, w, q and a not " ~ c ~ ".");
	}

	/// Updates the vector with the values from other.
	void update(in Vector!(E, D) other) { _vector = other._vector; }

	static if (D == 2)
	{
		void set(E x, E y)
		{
			_vector[0] = x;
			_vector[1] = y;
		}
	}
	else static if (D == 3)
	{
		void set(E x, E y, E z)
		{
			_vector[0] = x;
			_vector[1] = y;
			_vector[2] = z;
		}
	}
	else static if (D == 4)
	{
		void set(E x, E y, E z, E w)
		{
			_vector[0] = x;
			_vector[1] = y;
			_vector[2] = z;
			_vector[3] = w;
		}
	}

	static if (D >= 1) { alias x = get_!'x'; }
	static if (D >= 2) { alias y = get_!'y'; }
	static if (D >= 3) { alias z = get_!'z'; }
	static if (D >= 4) { alias w = get_!'w'; }

	static if (isNumeric!E)
	{
		/* Need these conversions when E is for instance ubyte.
		   See this commit: https://github.com/Dav1dde/gl3n/commit/2504003df4f8a091e58a3d041831dc2522377f95 */
		static immutable E0 = E(0);
		static immutable E1 = E(1);
		static if (dimension == 2)
		{
			static immutable Vector e1 = Vector(E1, E0); /// canonical basis for Euclidian space
			static immutable Vector e2 = Vector(E0, E1); /// ditto
		}
		else static if (dimension == 3)
		{
			static immutable Vector e1 = Vector(E1, E0, E0); /// canonical basis for Euclidian space
			static immutable Vector e2 = Vector(E0, E1, E0); /// ditto
			static immutable Vector e3 = Vector(E0, E0, E1); /// ditto
		}
		else static if (dimension == 4)
		{
			static immutable Vector e1 = Vector(E1, E0, E0, E0); /// canonical basis for Euclidian space
			static immutable Vector e2 = Vector(E0, E1, E0, E0); /// ditto
			static immutable Vector e3 = Vector(E0, E0, E1, E0); /// ditto
			static immutable Vector e4 = Vector(E0, E0, E0, E1); /// ditto
		}
	}

	version (none)
	pure nothrow @safe @nogc unittest
	{
		static if (isNumeric!E)
		{
			assert(vec2.e1[] == [1, 0].s);
			assert(vec2.e2[] == [0, 1].s);

			assert(vec3.e1[] == [1, 0, 0].s);
			assert(vec3.e2[] == [0, 1, 0].s);
			assert(vec3.e3[] == [0, 0, 1].s);

			assert(vec4.e1[] == [1, 0, 0, 0].s);
			assert(vec4.e2[] == [0, 1, 0, 0].s);
			assert(vec4.e3[] == [0, 0, 1, 0].s);
			assert(vec4.e4[] == [0, 0, 0, 1].s);
		}
	}

	/** Element data. */
	E[D] _vector;

	unittest
	{
		// static if (isSigned!(E)) { assert(-Vector!(E,D)(+2),
		//								   +Vector!(E,D)(-2)); }
	}

}

auto rowVector(Ts...)(Ts args)
if (!is(CommonType!Ts == void))
	=> Vector!(CommonType!Ts, args.length)(args);
alias vector = rowVector; /+ TODO: Should rowVector or columnVector be default? +/

auto columnVector(Ts...)(Ts args)
if (!is(CommonType!Ts == void))
	=> Vector!(CommonType!Ts, args.length, false, Orient.column)(args);

///
pure nothrow @safe @nogc unittest {
	assert(point(1, 2) + vector(1, 2) == point(2, 4));
	assert(point(1, 2) - vector(1, 2) == point(0, 0));
}

version (unittest)
{
	import std.conv : to;
	import nxt.array_help : s;
}
