/** Geometry types and algorithms.

   Special thanks to:
   $(UL
   $(LI Tomasz Stachowiak (h3r3tic): allowed me to use parts of $(LINK2 https://bitbucket.org/h3r3tic/boxen/src/default/src/xf/omg, omg).)
   $(LI Jakob Øvrum (jA_cOp): improved the code a lot!)
   $(LI Florian Boesch (___doc__): helps me to understand opengl/complex maths better, see: $(LINK http://codeflow.org/).)
   $(LI #D on freenode: answered general questions about D.)
   )

   Note: All methods marked with pure are weakly pure since, they all access an
   instance member.  All static methods are strongly pure.

   TODO: Support radian and degree types (from units-d package)

   TODO: Use `sink` as param in `toMathML` and `toLaTeX`

   TODO: Replace toMathML() with fmt argument %M to toString functions
   TODO: Replace toLaTeX() with fmt argument %L to toString functions

   TODO: Optimize using core.simd or std.simd
   TODO: Merge with analyticgeometry
   TODO: Merge with https://github.com/CyberShadow/ae/blob/master/utils/geometry.d
   TODO: Integrate with http://code.dlang.org/packages/blazed2
   TODO: logln, log.warn, log.error, log.info, log.debug
   TODO: Make use of staticReduce etc when they become available in Phobos.
   TODO: Go through all usages of real and use CommonType!(real, E) to make it work when E is a bignum.
   TODO: ead and perhaps make use of http://stackoverflow.com/questions/3098242/fast-vector-struct-that-allows-i-and-xyz-operations-in-d?rq=1
   TODO: Tag member functions in t_geom.d as pure as is done https://github.com/D-Programming-Language/phobos/blob/master/std/bigint.d
   TODO: Remove need to use [] in x[] == y[]

   See: https://www.google.se/search?q=point+plus+vector
   See: http://mosra.cz/blog/article.php?a=22-introducing-magnum-a-multiplatform-2d-3d-graphics-engine
*/
module old_geometry;

/+ TODO: use import core.simd; +/
import std.math: sqrt, PI, sin, cos, acos;
import std.traits: isFloatingPoint, isNumeric, isSigned, isDynamicArray, isAssignable, isArray, CommonType;
import std.string: format, rightJustify;
import std.array: join;
import std.algorithm.iteration : map, reduce;
import std.algorithm.searching : all, any;
import std.algorithm.comparison : min, max;
import std.random: uniform;

import nxt.mathml;

enum isVector(E)	 = is(typeof(isVectorImpl(E.init)));
enum isPoint(E)	  = is(typeof(isPointImpl(E.init)));
enum isMatrix(E)	 = is(typeof(isMatrixImpl(E.init)));
enum isQuaternion(E) = is(typeof(isQuaternionImpl(E.init)));
enum isPlane(E)	  = is(typeof(isPlaneImpl(E.init)));

private void isVectorImpl	(E, uint D)		(Vector	!(E, D)	vec) {}
private void isPointImpl	 (E, uint D)		(Point	 !(E, D)	vec) {}
private void isMatrixImpl	(E, uint R, uint C)(Matrix	!(E, R, C) mat) {}
private void isQuaternionImpl(E)				(Quaternion!(E)		qu) {}
private void isPlaneImpl	 (E)				(PlaneT	!(E)		 p) {}

enum isFixVector(E) = isFix(typeof(isFixVectorImpl(E.init)));
enum isFixPoint(E)  = isFix(typeof(isFixPointImpl (E.init)));
enum isFixMatrix(E) = isFix(typeof(isFixMatrixImpl(E.init)));

private void isFixVectorImpl (E, uint D)		(Vector!(E, D)	vec) {}
private void isFixPointImpl  (E, uint D)		(Point !(E, D)	vec) {}
private void isFixMatrixImpl (E, uint R, uint C)(Matrix!(E, R, C) mat) {}

// See_Also: http://stackoverflow.com/questions/18552454/using-ctfe-to-generate-set-of-struct-aliases/18553026?noredirect=1#18553026
version (none)
string makeInstanceAliases(in string templateName,
						   string aliasName = "",
						   in uint minDimension = 2,
						   in uint maxDimension = 4,
						   in string[] elementTypes = defaultElementTypes)
in
{
	assert(templateName.length);
	assert(minDimension <= maxDimension);
}
do
{
	import std.string : toLower;
	import std.conv : to;
	string code;
	if (!aliasName.length)
	{
		aliasName = templateName.toLower;
	}
	foreach (immutable n; minDimension .. maxDimension + 1)
	{
		foreach (const et; elementTypes) // for each elementtype
		{
			immutable prefix = ("alias " ~ templateName ~ "!("~et~", " ~
								to!string(n) ~ ") " ~ aliasName ~ "" ~
								to!string(n));
			if (et == "float")
			{
				code ~= (prefix ~ ";\n"); // GLSL-style prefix-less single precision
			}
			code ~= (prefix ~ et[0] ~ ";\n");
		}
	}
	return code;
}

version (none)
mixin(makeInstanceAliases("Point", "point", 2,3,
						   ["int", "float", "double", "real"]));

/* Copied from https://github.com/CyberShadow/ae/blob/master/utils/geometry.d */
auto sqrtx(T)(T x)
{
	static if (is(T : int))
	{
		return std.math.sqrt(cast(float)x);
	}
	else
	{
		return std.math.sqrt(x);
	}
}

import std.meta : AliasSeq;

version (unittest)
{
	static foreach (T; AliasSeq!(ubyte, int, float, double, real))
	{
		static foreach (uint n; 2 .. 4 + 1)
		{
		}
	}

	alias vec2b = Vector!(byte, 2, false);

	alias vec2f = Vector!(float, 2, true);
	alias vec3f = Vector!(float, 3, true);

	alias vec2d = Vector!(float, 2, true);

	alias nvec2f = Vector!(float, 2, true);
}

// mixin(makeInstanceAliases("Vector", "vec", 2,4,
//						   ["ubyte", "int", "float", "double", "real"]));

///
pure nothrow @safe @nogc unittest {
	assert(vec2f(2, 3)[] == [2, 3].s);
	assert(vec2f(2, 3)[0] == 2);
	assert(vec2f(2) == 2);
	assert(vec2f(true) == true);
	assert(vec2b(true) == true);
	assert(all!"a"(vec2b(true)[]));
	assert(any!"a"(vec2b(false, true)[]));
	assert(any!"a"(vec2b(true, false)[]));
	assert(!any!"a"(vec2b(false, false)[]));
	assert((vec2f(1, 3)*2.5f)[] == [2.5f, 7.5f].s);
	nvec2f v = vec2f(3, 4);
	assert(v[] == nvec2f(0.6, 0.8)[]);
}

///
@safe unittest {
	import std.conv : to;
	auto x = vec2f(2, 3);
	assert(to!string(vec2f(2, 3)) == `ColumnVector(2,3)`);
	assert(to!string(transpose(vec2f(11, 22))) == `RowVector(11,22)`);
	assert(vec2f(11, 22).toLaTeX == `\begin{pmatrix} 11 \\ 22 \end{pmatrix}`);
	assert(vec2f(11, 22).T.toLaTeX == `\begin{pmatrix} 11 & 22 \end{pmatrix}`);
}

auto transpose(E, uint D,
			   bool normalizedFlag,
			   Orient orient)(in Vector!(E, D,
										 normalizedFlag,
										 orient) a)
{
	static if (orient == Orient.row)
	{
		return Vector!(E, D, normalizedFlag, Orient.column)(a._vector);
	}
	else
	{
		return Vector!(E, D, normalizedFlag, Orient.row)(a._vector);
	}
}
alias T = transpose; // C++ Armadillo naming convention.

auto elementwiseLessThanOrEqual(Ta, Tb,
								uint D,
								bool normalizedFlag,
								Orient orient)(in Vector!(Ta, D, normalizedFlag, orient) a,
											   in Vector!(Tb, D, normalizedFlag, orient) b)
{
	Vector!(bool, D) c = void;
	static foreach (i; 0 .. D)
	{
		c[i] = a[i] <= b[i];
	}
	return c;
}

pure nothrow @safe @nogc unittest {
	assert(elementwiseLessThanOrEqual(vec2f(1, 1),
									  vec2f(2, 2)) == vec2b(true, true));
}

/// Returns: Scalar/Dot-Product of Two Vectors `a` and `b`.
T dotProduct(T, U)(in T a, in U b)
if (is(T == Vector!(_), _) &&
	is(U == Vector!(_), _) &&
	(T.dimension ==
	 U.dimension))
{
	T c = void;
	static foreach (i; 0 .. T.dimension)
	{
		c[i] = a[i] * b[i];
	}
	return c;
}
alias dot = dotProduct;

/// Returns: Outer-Product of Two Vectors `a` and `b`.
auto outerProduct(Ta, Tb, uint Da, uint Db)(in Vector!(Ta, Da) a,
											in Vector!(Tb, Db) b)
if (Da >= 1 &&
	Db >= 1)
{
	Matrix!(CommonType!(Ta, Tb), Da, Db) y = void;
	static foreach (r; 0 .. Da)
	{
		static foreach (c; 0 .. Db)
		{
			y.at(r,c) = a[r] * b[c];
		}
	}
	return y;
}
alias outer = outerProduct;

/// Returns: Vector/Cross-Product of two 3-Dimensional Vectors.
auto crossProduct(T, U)(in T a,
						in U b)
if (is(T == Vector!(_), _) && T.dimension == 3 &&
	is(U == Vector!(_), _) && U.dimension == 3)
{
	return T(a.y * b.z - b.y * a.z,
			 a.z * b.x - b.z * a.x,
			 a.x * b.y - b.x * a.y);
}

/// Returns: (Euclidean) Distance between `a` and `b`.
real distance(T, U)(in T a,
					in U b)
if ((is(T == Vector!(_), _) && // either both vectors
	 is(U == Vector!(_), _) &&
	 T.dimension == U.dimension) ||
	(isPoint!T && // or both points
	 isPoint!U))  /+ TODO: support distance between vector and point +/
{
	return (a - b).magnitude;
}

pure nothrow @safe @nogc unittest {
	auto v1 = vec3f(1, 2, -3);
	auto v2 = vec3f(1, 3, 2);
	assert(crossProduct(v1, v2)[] == [13, -5, 1].s);
	assert(distance(vec2f(0, 0), vec2f(0, 10)) == 10);
	assert(distance(vec2f(0, 0), vec2d(0, 10)) == 10);
	assert(dot(v1, v2) == dot(v2, v1)); // commutative
}

enum Layout { columnMajor, rowMajor }; // Matrix Storage Major Dimension.

/// Base template for all matrix-types.
/// Params:
///  E = all values get stored as this type
///  rows_ = rows of the matrix
///  cols_ = columns of the matrix
///  layout = matrix layout
struct Matrix(E, uint rows_, uint cols_,
			  Layout layout = Layout.rowMajor)
if (rows_ >= 1 &&
	cols_ >= 1)
{
	alias mT = E; /// Internal type of the _matrix
	static const uint rows = rows_; /// Number of rows
	static const uint cols = cols_; /// Number of columns

	/** Matrix $(RED row-major) in memory. */
	static if (layout == Layout.rowMajor)
	{
		E[cols][rows] _matrix; // In C it would be mt[rows][cols], D does it like this: (mt[cols])[rows]

		ref inout(E) opCall()(uint row, uint col) inout
		{
			return _matrix[row][col];
		}

		ref inout(E) at()(uint row, uint col) inout
		{
			return _matrix[row][col];
		}
	}
	else
	{
		E[rows][cols] _matrix; // In C it would be mt[cols][rows], D does it like this: (mt[rows])[cols]
		ref inout(E) opCall()(uint row, uint col) inout
		{
			return _matrix[col][row];
		}

		ref inout(E) at()(uint row, uint col) inout
		{
			return _matrix[col][row];
		}
	}
	alias _matrix this;

	/// Returns: The pointer to the stored values as OpenGL requires it.
	/// Note this will return a pointer to a $(RED row-major) _matrix,
	/// $(RED this means you've to set the transpose argument to GL_TRUE when passing it to OpenGL).
	/// Examples:
	/// ---
	/// // 3rd argument = GL_TRUE
	/// glUniformMatrix4fv(programs.main.model, 1, GL_TRUE, mat4.translation(-0.5f, -0.5f, 1.0f).value_ptr);
	/// ---
	// @property auto value_ptr() { return _matrix[0].ptr; }

	/// Returns: The current _matrix formatted as flat string.

	@property void toString(Sink)(ref scope Sink sink) const
	{
		import std.conv : to;
		sink(`Matrix(`);
		sink(to!string(_matrix));
		sink(`)`);
	}

	@property string toLaTeX()() const
	{
		string s;
		static foreach (r; 0 .. rows)
		{
			static foreach (c; 0 .. cols)
			{
				s ~= to!string(at(r, c)) ;
				if (c != cols - 1) { s ~= ` & `; } // if not last column
			}
			if (r != rows - 1) { s ~= ` \\ `; } // if not last row
		}
		return `\begin{pmatrix} ` ~ s ~ ` \end{pmatrix}`;
	}

	@property string toMathML()() const
	{
		// opening
		string str = `<math><mrow>
  <mo>❲</mo>
  <mtable>`;

		static foreach (r; 0 .. rows)
		{
			str ~=  `
	<mtr>`;
			static foreach (c; 0 .. cols)
			{
				str ~= `
	  <mtd>
		<mn>` ~ at(r, c).toMathML ~ `</mn>
	  </mtd>`;
			}
			str ~=  `
	</mtr>`;
		}

		// closing
		str ~= `
  </mtable>
  <mo>❳</mo>
</mrow></math>
`;
		return str;
	}

	/// Returns: The current _matrix as pretty formatted string.
	@property string toPrettyString()()
	{
		string fmtr = "%s";

		size_t rjust = max(format(fmtr, reduce!(max)(_matrix[])).length,
						   format(fmtr, reduce!(min)(_matrix[])).length) - 1;

		string[] outer_parts;
		foreach (E[] row; _matrix)
		{
			string[] inner_parts;
			foreach (E col; row)
			{
				inner_parts ~= rightJustify(format(fmtr, col), rjust);
			}
			outer_parts ~= " [" ~ join(inner_parts, ", ") ~ "]";
		}

		return "[" ~ join(outer_parts, "\n")[1..$] ~ "]";
	}

	static void isCompatibleMatrixImpl(uint r, uint c)(Matrix!(E, r, c) m) {}

	enum isCompatibleMatrix(T) = is(typeof(isCompatibleMatrixImpl(T.init)));

	static void isCompatibleVectorImpl(uint d)(Vector!(E, d) vec) {}

	enum isCompatibleVector(T) = is(typeof(isCompatibleVectorImpl(T.init)));

	private void construct(uint i, T, Tail...)(T head, Tail tail)
	{
		static if (i >= rows*cols)
		{
			static assert(0, "Too many arguments passed to constructor");
		}
		else static if (is(T : E))
		{
			_matrix[i / cols][i % cols] = head;
			construct!(i + 1)(tail);
		}
		else static if (is(T == Vector!(E, cols)))
		{
			static if (i % cols == 0)
			{
				_matrix[i / cols] = head._vector;
				construct!(i + T.dimension)(tail);
			}
			else
			{
				static assert(0, "Can't convert Vector into the matrix. Maybe it doesn't align to the columns correctly or dimension doesn't fit");
			}
		}
		else
		{
			static assert(0, "Matrix constructor argument must be of type " ~ E.stringof ~ " or Vector, not " ~ T.stringof);
		}
	}

	private void construct(uint i)()  // terminate
	{
		static assert(i == rows*cols, "Not enough arguments passed to constructor");
	}

	/// Constructs the matrix:
	/// If a single value is passed, the matrix will be cleared with this value (each column in each row will contain this value).
	/// If a matrix with more rows and columns is passed, the matrix will be the upper left nxm matrix.
	/// If a matrix with less rows and columns is passed, the passed matrix will be stored in the upper left of an identity matrix.
	/// It's also allowed to pass vectors and scalars at a time, but the vectors dimension must match the number of columns and align correctly.
	/// Examples:
	/// ---
	/// mat2 m2 = mat2(0.0f); // mat2 m2 = mat2(0.0f, 0.0f, 0.0f, 0.0f);
	/// mat3 m3 = mat3(m2); // mat3 m3 = mat3(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
	/// mat3 m3_2 = mat3(vec3(1.0f, 2.0f, 3.0f), 4.0f, 5.0f, 6.0f, vec3(7.0f, 8.0f, 9.0f));
	/// mat4 m4 = mat4.identity; // just an identity matrix
	/// mat3 m3_3 = mat3(m4); // mat3 m3_3 = mat3.identity
	/// ---
	this(Args...)(Args args)
	{
		construct!(0)(args);
	}

	this(T)(T mat)
	if (isMatrix!T &&
		(T.cols >= cols) &&
		(T.rows >= rows))
	{
		_matrix[] = mat._matrix[];
	}

	this(T)(T mat)
	if (isMatrix!T &&
		(T.cols < cols) &&
		(T.rows < rows))
	{
		makeIdentity();
		static foreach (r; 0 .. T.rows)
		{
			static foreach (c; 0 .. T.cols)
			{
				at(r, c) = mat.at(r, c);
			}
		}
	}

	this()(E value) { clear(value); }

	/// Sets all values of the matrix to value (each column in each row will contain this value).
	void clear()(E value)
	{
		static foreach (r; 0 .. rows)
		{
			static foreach (c; 0 .. cols)
			{
				at(r,c) = value;
			}
		}
	}

	static if (rows == cols)
	{
		/// Makes the current matrix an identity matrix.
		void makeIdentity()()
		{
			clear(0);
			static foreach (r; 0 .. rows)
			{
				at(r,r) = 1;
			}
		}

		/// Returns: Identity Matrix.
		static @property Matrix identity()
		{
			Matrix ret;
			ret.clear(0);
			static foreach (r; 0 .. rows)
			{
				ret.at(r,r) = 1;
			}

			return ret;
		}
		alias id = identity;	// shorthand

		/// Transpose Current Matrix.
		void transpose()()
		{
			_matrix = transposed()._matrix;
		}
		alias T = transpose; // C++ Armadillo naming convention.

		unittest
		{
			mat2 m2 = mat2(1.0f);
			m2.transpose();
			assert(m2._matrix == mat2(1.0f)._matrix);
			m2.makeIdentity();
			assert(m2._matrix == [[1.0f, 0.0f],
								  [0.0f, 1.0f]]);
			m2.transpose();
			assert(m2._matrix == [[1.0f, 0.0f],
								  [0.0f, 1.0f]]);
			assert(m2._matrix == m2.identity._matrix);

			mat3 m3 = mat3(1.1f, 1.2f, 1.3f,
						   2.1f, 2.2f, 2.3f,
						   3.1f, 3.2f, 3.3f);
			m3.transpose();
			assert(m3._matrix == [[1.1f, 2.1f, 3.1f],
								  [1.2f, 2.2f, 3.2f],
								  [1.3f, 2.3f, 3.3f]]);

			mat4 m4 = mat4(2.0f);
			m4.transpose();
			assert(m4._matrix == mat4(2.0f)._matrix);
			m4.makeIdentity();
			assert(m4._matrix == [[1.0f, 0.0f, 0.0f, 0.0f],
								  [0.0f, 1.0f, 0.0f, 0.0f],
								  [0.0f, 0.0f, 1.0f, 0.0f],
								  [0.0f, 0.0f, 0.0f, 1.0f]]);
			assert(m4._matrix == m4.identity._matrix);
		}

	}

	/// Returns: a transposed copy of the matrix.
	@property Matrix!(E, cols, rows) transposed()() const
	{
		typeof(return) ret;
		static foreach (r; 0 .. rows)
		{
			static foreach (c; 0 .. cols)
			{
				ret.at(c,r) = at(r,c);
			}
		}
		return ret;
	}

}
alias mat2i = Matrix!(int, 2, 2);
alias mat2 = Matrix!(float, 2, 2);
alias mat2d = Matrix!(real, 2, 2);
alias mat2r = Matrix!(real, 2, 2);
alias mat3 = Matrix!(float, 3, 3);
alias mat34 = Matrix!(float, 3, 4);
alias mat4 = Matrix!(float, 4, 4);
alias mat2_cm = Matrix!(float, 2, 2, Layout.columnMajor);

pure nothrow @safe @nogc unittest {
	auto m = mat2(1, 2,
				  3, 4);
	assert(m(0, 0) == 1);
	assert(m(0, 1) == 2);
	assert(m(1, 0) == 3);
	assert(m(1, 1) == 4);
}

pure nothrow @safe @nogc unittest {
	auto m = mat2_cm(1, 3,
					 2, 4);
	assert(m(0, 0) == 1);
	assert(m(0, 1) == 2);
	assert(m(1, 0) == 3);
	assert(m(1, 1) == 4);
}

pure nothrow @safe @nogc unittest {
	alias E = float;
	immutable a = Vector!(E, 2, false, Orient.column)(1, 2);
	immutable b = Vector!(E, 3, false, Orient.column)(3, 4, 5);
	immutable c = outerProduct(a, b);
	assert(c[] == [[3, 4, 5].s,
				   [6, 8, 10].s].s);
}

/// 3-Dimensional Spherical Point with Coordinate Type (Precision) `E`.
struct SpherePoint3(E)
if (isFloatingPoint!E)
{
	enum D = 3;				 // only in three dimensions
	alias ElementType = E;

	/** Construct from Components `args`. */
	this(T...)(T args)
	{
		foreach (immutable ix, arg; args)
		{
			_spherePoint[ix] = arg;
		}
	}
	/** Element data. */
	E[D] _spherePoint;
	enum dimension = D;

	@property void toString(Sink)(ref scope Sink sink) const
	{
		sink(`SpherePoint3(`);
		foreach (const ix, const e ; _spherePoint)
		{
			if (ix != 0) { sink(","); }
			sink(to!string(e));
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
		<mn>` ~ _spherePoint[i].toMathML ~ `</mn>
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
	@property E area() const { return 0; }

	auto opSlice() { return _spherePoint[]; }
}

/** Instantiator for `SpherePoint3`. */
auto spherePoint(Ts...)(Ts args)
if (!is(CommonType!Ts == void))
{
	return SpherePoint3!(CommonType!Ts, args.length)(args);
}

/** `D`-Dimensional Particle with Cartesian Coordinate `position` and
	`velocity` of Element (Component) Type `E`.
*/
struct Particle(E, uint D,
				bool normalizedVelocityFlag = false)
if (D >= 1)
{
	Point!(E, D) position;
	Vector!(E, D, normalizedVelocityFlag) velocity;
	E mass;
}

// mixin(makeInstanceAliases("Particle", "particle", 2,4,
//						   ["float", "double", "real"]));

/** `D`-Dimensional Particle with Coordinate Position and
	Direction/Velocity/Force Type (Precision) `E`.
	F = m*a; where F is force, m is mass, a is acceleration.
*/
struct ForcedParticle(E, uint D,
					  bool normalizedVelocityFlag = false)
if (D >= 1)
{
	Point!(E, D) position;
	Vector!(E, D, normalizedVelocityFlag) velocity;
	Vector!(E, D) force;
	E mass;

	/// Get acceleration.
	@property auto acceleration()() const { return force/mass; }
}

/** `D`-Dimensional Axis-Aligned (Hyper) Cartesian `Box` with Element (Component) Type `E`.

	Note: We must use inclusive compares betweeen boxes and points in inclusion
	functions such as inside() and includes() in order for the behaviour of
	bounding boxes (especially in integer space) to work as desired.
 */
struct Box(E, uint D)
if (D >= 1)
{
	this(Vector!(E,D) lh) { min = lh; max = lh; }
	this(Vector!(E,D) l_,
		 Vector!(E,D) h_) { min = l_; max = h_; }

	@property void toString(Sink)(ref scope Sink sink) const
	{
		sink(`Box(lower:`);
		min.toString(sink);
		sink(`, upper:`);
		max.toString(sink);
		sink(`)`);
	}

	/// Get Box Center.
	/+ TODO: @property Vector!(E,D) center() { return (min + max) / 2;} +/

	/// Constructs a Box enclosing `points`.
	static Box fromPoints(in Vector!(E,D)[] points)
	{
		Box y;
		foreach (p; points)
		{
			y.expand(p);
		}
		return y;
	}

	/// Expands the Box, so that $(I v) is part of the Box.
	ref Box expand(Vector!(E,D) v)
	{
		static foreach (i; 0 .. D)
		{
			if (min[i] > v[i]) min[i] = v[i];
			if (max[i] < v[i]) max[i] = v[i];
		}
		return this;
	}

	/// Expands box by another box `b`.
	ref Box expand()(Box b)
	{
		return this.expand(b.min).expand(b.max);
	}

	unittest
	{
		immutable auto b = Box(Vector!(E,D)(1),
							   Vector!(E,D)(3));
		assert(b.sides == Vector!(E,D)(2));
		immutable auto c = Box(Vector!(E,D)(0),
							   Vector!(E,D)(4));
		assert(c.sides == Vector!(E,D)(4));
		assert(c.sidesProduct == 4^^D);
		assert(unite(b, c) == c);
	}

	/** Returns: Length of Sides */
	@property auto sides()() const { return max - min; }

	/** Returns: Area */
	@property real sidesProduct()() const
	{
		typeof(return) y = 1;
		foreach (const ref side; sides)
		{
			y *= side;
		}
		return y;
	}

	static if (D == 2)
	{
		alias area = sidesProduct;
	}
	else static if (D == 3)
	{
		alias volume = sidesProduct;
	}
	else static if (D >= 4)
	{
		alias hyperVolume = sidesProduct;
	}

	alias include = expand;

	Vector!(E,D) min;		   /// Low.
	Vector!(E,D) max;		   /// High.

	/** Either an element in min or max is nan or min <= max. */
	invariant()
	{
		// assert(any!"a==a.nan"(min),
		//				  all!"a || a == a.nan"(elementwiseLessThanOrEqual(min, max)[]));
	}
}

// mixin(makeInstanceAliases("Box","box", 2,4,
//						   ["int", "float", "double", "real"]));

Box!(E,D) unite(E, uint D)(Box!(E,D) a,
						   Box!(E,D) b) { return a.expand(b); }
Box!(E,D) unite(E, uint D)(Box!(E,D) a,
						   Vector!(E,D) b) { return a.expand(b); }

/** `D`-Dimensional Infinite Cartesian (Hyper)-Plane with Element (Component) Type `E`.
	See_Also: http://stackoverflow.com/questions/18600328/preferred-representation-of-a-3d-plane-in-c-c
 */
struct Plane(E, uint D)
if (D >= 2 &&
	isFloatingPoint!E)
{
	enum dimension = D;

	alias ElementType = E;

	/// Normal type of plane.
	alias NormalType = Vector!(E, D, true);

	union
	{
		static if (D == 3)
		{
			struct
			{
				E a; /// normal.x
				E b; /// normal.y
				E c; /// normal.z
			}
		}
		NormalType normal;	  /// Plane Normal.
	}
	E distance;				  /// Plane Constant (Offset from origo).

	@property void toString(Sink)(ref scope Sink sink) const
	{
		import std.conv : to;
		sink(`Plane(normal:`);
		sink(to!string(normal));
		sink(`, distance:`);
		sink(to!string(distance));
		sink(`)`);
	}

	/// Constructs the plane, from either four scalars of type $(I E)
	/// or from a 3-dimensional vector (= normal) and a scalar.
	static if (D == 2)
	{
		this()(E a, E b, E distance)
		{
			this.normal.x = a;
			this.normal.y = b;
			this.distance = distance;
		}
	}
	else static if (D == 3)
	{
		this()(E a, E b, E c, E distance)
		{
			this.normal.x = a;
			this.normal.y = b;
			this.normal.z = c;
			this.distance = distance;
		}
	}

	this()(NormalType normal, E distance)
	{
		this.normal = normal;
		this.distance = distance;
	}

	/* unittest
	   { */
	/*	 Plane p = Plane(0.0f, 1.0f, 2.0f, 3.0f); */
	/*	 assert(p.normal == N(0.0f, 1.0f, 2.0f)); */
	/*	 assert(p.distance == 3.0f); */

	/*	 p.normal.x = 4.0f; */
	/*	 assert(p.normal == N(4.0f, 1.0f, 2.0f)); */
	/*	 assert(p.x == 4.0f); */
	/*	 assert(p.y == 1.0f); */
	/*	 assert(p.c == 2.0f); */
	/*	 assert(p.distance == 3.0f); */
	/* } */

	/// Normalizes the plane inplace.
	void normalize()()
	{
		immutable E det = cast(E)1 / normal.magnitude;
		normal *= det;
		distance *= det;
	}

	/// Returns: a normalized copy of the plane.
	/* @property Plane normalized() const { */
	/*	 Plane y = Plane(a, b, c, distance); */
	/*	 y.normalize(); */
	/*	 return y; */
	/* } */

//	 unittest {
//		 Plane p = Plane(0.0f, 1.0f, 2.0f, 3.0f);
//		 Plane pn = p.normalized();
//		 assert(pn.normal == N(0.0f, 1.0f, 2.0f).normalized);
//		 assert(almost_equal(pn.distance, 3.0f / N(0.0f, 1.0f, 2.0f).length));
//		 p.normalize();
//		 assert(p == pn);
//	 }

	/// Returns: distance from a point to the plane.
	/// Note: the plane $(RED must) be normalized, the result can be negative.
	/* E distanceTo(N point) const { */
	/*	 return dot(point, normal) + distance; */
	/* } */

	/// Returns: distanceTo from a point to the plane.
	/// Note: the plane does not have to be normalized, the result can be negative.
	/* E ndistance(N point) const { */
	/*	 return (dot(point, normal) + distance) / normal.magnitude; */
	/* } */

	/* unittest
	   { */
	/*	 Plane p = Plane(-1.0f, 4.0f, 19.0f, -10.0f); */
	/*	 assert(almost_equal(p.ndistance(N(5.0f, -2.0f, 0.0f)), -1.182992)); */
	/*	 assert(almost_equal(p.ndistance(N(5.0f, -2.0f, 0.0f)), */
	/*						 p.normalized.distanceTo(N(5.0f, -2.0f, 0.0f)))); */
	/* } */

	/* bool opEquals(Plane other) const { */
	/*	 return other.normal == normal && other.distance == distance; */
	/* } */

}

// mixin(makeInstanceAliases("Plane","plane", 3,4,
//						   defaultElementTypes));

/** `D`-Dimensional Cartesian (Hyper)-Sphere with Element (Component) Type `E`.
 */
struct Sphere(E, uint D)
if (D >= 2 &&
	isNumeric!E)
{
	alias CenterType = Point!(E, D);

	CenterType center;
	E radius;

	void translate(Vector!(E, D) shift)
	{
		center = center + shift; // point + vector => point
	}
	alias shift = translate;

	@property:

	E diameter()() const
	{
		return 2 * radius;
	}
	static if (D == 2)
	{
		auto area()() const
		{
			return PI * radius ^^ 2;
		}
	}
	else static if (D == 3)
	{
		auto area()() const
		{
			return 4 * PI * radius ^^ 2;
		}
		auto volume()() const
		{
			return 4 * PI * radius ^^ 3 / 3;
		}
	}
	else static if (D >= 4)
	{
		// See_Also: https://en.wikipedia.org/wiki/Volume_of_an_n-ball
		real n = D;
		auto volume()() const
		{
			import std.mathspecial: gamma;
			return PI ^^ (n / 2) / gamma(n / 2 + 1) * radius ^^ n;
		}
	}
}

auto sphere(C, R)(C center, R radius)
{
	return Sphere!(C.ElementType, C.dimension)(center, radius);
}
/+ TODO: Use this instead: +/
// auto sphere(R, C...)(Point!(CommonType!C, C.length) center, R radius) {
// return Sphere!(CommonType!C, C.length)(center, radius);
// }

/**
   See_Also: http://stackoverflow.com/questions/401847/circle-rectangle-collision-detection-intersect
 */
bool intersect(T)(Circle!T circle, Rect!T rect)
{
	immutable hw = rect.w/2, hh = rect.h/2;

	immutable dist = Point!T(abs(circle.x - rect.x0 - hw),
							 abs(circle.y - rect.y0 - hh));

	if (dist.x > (hw + circle.r)) return false;
	if (dist.y > (hh + circle.r)) return false;

	if (dist.x <= hw) return true;
	if (dist.y <= hh) return true;

	immutable cornerDistance_sq = ((dist.x - hw)^^2 +
								   (dist.y - hh)^^2);

	return (cornerDistance_sq <= circle.r^^2);
}

@safe unittest {
	assert(box2f(vec2f(1, 2), vec2f(3, 3)).to!string == `Box(lower:ColumnVector(1,2), upper:ColumnVector(3,3))`);
	assert([12, 3, 3].to!string == `[12, 3, 3]`);

	assert(vec2f(2, 3).to!string == `ColumnVector(2,3)`);

	assert(vec2f(2, 3).to!string == `ColumnVector(2,3)`);
	assert(vec2f(2, 3).to!string == `ColumnVector(2,3)`);

	assert(vec3f(2, 3, 4).to!string == `ColumnVector(2,3,4)`);

	assert(box2f(vec2f(1, 2),
				 vec2f(3, 4)).to!string == `Box(lower:ColumnVector(1,2), upper:ColumnVector(3,4))`);

	assert(vec2i(2, 3).to!string == `ColumnVector(2,3)`);
	assert(vec3i(2, 3, 4).to!string == `ColumnVector(2,3,4)`);
	assert(vec3i(2, 3, 4).to!string == `ColumnVector(2,3,4)`);

	assert(vec2i(2, 3).toMathML == `<math><mrow>
  <mo>⟨</mo>
  <mtable>
	<mtr>
	  <mtd>
		<mn>2</mn>
	  </mtd>
	</mtr>
	<mtr>
	  <mtd>
		<mn>3</mn>
	  </mtd>
	</mtr>
  </mtable>
  <mo>⟩</mo>
</mrow></math>
`);

	auto m = mat2(1, 2, 3, 4);
	assert(m.toLaTeX == `\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}`);
	assert(m.toMathML == `<math><mrow>
  <mo>❲</mo>
  <mtable>
	<mtr>
	  <mtd>
		<mn>1</mn>
	  </mtd>
	  <mtd>
		<mn>2</mn>
	  </mtd>
	</mtr>
	<mtr>
	  <mtd>
		<mn>3</mn>
	  </mtd>
	  <mtd>
		<mn>4</mn>
	  </mtd>
	</mtr>
  </mtable>
  <mo>❳</mo>
</mrow></math>
`);
}

version (unittest)
{
	import std.conv : to;
	import nxt.array_help : s;
}
