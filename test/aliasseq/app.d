int main()
{
	import std.meta : AliasSeq;
	alias ScalarTypes = AliasSeq!(ubyte, ushort, uint, ulong,
								  byte, short, int, long,
								  float, double, real);

	static foreach (S; ScalarTypes)
		static foreach (T; ScalarTypes)
			static foreach (U; ScalarTypes)
				static foreach (V; ScalarTypes)
			{
				{
					alias A = AliasSeq!(S, T, U, V); // replace this line with alias T = int; to disable
				}
			}

	// the difference in output of /usr/bin/time dmd -o- benchmark_aliasseq.d
	// between
	// - alias A = AliasSeq!(S, T, U, V);
	// - alias T = int;
	enum mu = 118_920 -  64_912;

	pragma(msg, __FILE__, "(", __LINE__, ",1): : ", cast(double)mu / ScalarTypes.length ^^ 4, " kB per A instance");

	return 0;
}
