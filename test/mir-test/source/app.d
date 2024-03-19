import std.stdio;
import mir.ndslice;

void main()
{
	const matrix = slice!int(2, 2);
	assert(matrix == [[0, 0], [0, 0]]);
	writeln(matrix[]);
}
