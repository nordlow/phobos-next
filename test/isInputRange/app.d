import std.range.primitives: isInputRange; // always import to give same phobos import overhead
import std.meta : AliasSeq;

// version = doBenchmark;
// version = useBuiltin;

alias types = AliasSeq!(ubyte, ushort, uint, ulong,
						byte, short, int, long,
						float, double, real,
						char, wchar, dchar);
enum qualifiers = AliasSeq!("", "const");

pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", types.length ^^ 3 * qualifiers.length, " calls to isInputRange");

static foreach (T; types)
{
	static foreach (U; types)
	{
		static foreach (V; types)
		{
			mixin("struct ",
				  T, "_" ,U, "_" ,V,
				  " {",
				  T, " t; ",
				  U, " u; ",
				  V, " v; ",
				  "}");
			version (doBenchmark)
			{
				version (useFaster)
					static foreach (qualifier; qualifiers)
						static assert(!is(T == struct) || isInputRange!(mixin(qualifier, "(", T, "_", U, "_", V, ")")[]));
				else
					static foreach (qualifier; qualifiers)
						static assert(isInputRange!(mixin(qualifier, "(", T, "_", U, "_", V, ")")[]));
			}
		}
	}
}
