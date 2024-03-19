/**
 * FASTQ is a format for storing DNA sequences together with the associated
 * quality information often encoded in ascii characters. It is typically made
 * of 4 lines for example 2 fastq entries would look like this.
 *
 * @seq1
 * TTATTTTAAT
 * +
 * ?+BBB/DHH@
 * @seq2
 * GACCCTTTGCA
 * +
 * ?+BHB/DIH@
 *
 * See_Also: https://en.wikipedia.org/wiki/FASTQ_format
 * See_Also: http://forum.dlang.org/post/nd01qd$2k8c$1@digitalmars.com
 */
module fastq;

pure nothrow @safe @nogc:

struct FastQRecord
{
	/+ TODO: `inout` support like in `rdf.d` +/
	const(char)[] sequenceId;
	const(char)[] sequenceLetters;
	const(char)[] quality;

	static auto parse(const(char)[] from)
	{
		static struct Result
		{
		@safe pure nothrow:
			private
			{
				const(char)[] source;
				FastQRecord value;
				bool isEmpty;
			}

			this(const(char)[] source)
			{
				this.source = source;
				popFront;
			}

			@property
			{
				FastQRecord front()
				{
					return value;
				}

				bool empty()
				{
					return isEmpty;
				}
			}

			void popFront()
			{
				import std.string : indexOf;

				if (source is null)
				{
					isEmpty = true;
					return;
				}

				void tidyInput()
				{
					foreach(i, c; source)
					{
						switch(c)
						{
						case 0: .. case ' ':
							break;
						default:
							source = source[i .. $];
							return;
						}
					}

					source = null;
				}

				tidyInput();

				if (source is null)
					return;

				// sequenceId

				assert(source[0] == '@');

				ptrdiff_t len = source.indexOf("\n");
				assert(len > 0);

				value.sequenceId = source[1 .. len];
				if (value.sequenceId[$-1] == "\r"[0])
					value.sequenceId = value.sequenceId[0 .. $-1];

				source = source[len + 1 .. $];

				// sequenceLetters

				len = source.indexOf("\n");
				assert(len > 0);

				value.sequenceLetters = source[0 .. len];
				if (value.sequenceLetters[$-1] == "\r"[0])
					value.sequenceLetters = value.sequenceLetters[0 .. $-1];

				source = source[len + 1 .. $];

				// +sequenceId

				len = source.indexOf("\n");
				assert(len > 0);
				source = source[len + 1 .. $];

				// quality

				len = source.indexOf("\n");
				assert(len > 0);

				value.quality = source[0 .. len];
				if (value.quality[$-1] == "\r"[0])
					value.quality = value.quality[0 .. $-1];

				if (source.length > len + 1)
				{
					source = source[len + 1 .. $];
					tidyInput();
				} else
					source = null;
			}
		}

		return Result(from);
	}
}

unittest {
	string input = `
@seq1
TTATTTTAAT
+
?+BBB/DHH@
@seq2
GACCCTTTGCA
+
?+BHB/DIH@
@SEQ_ID
GATTTGGGGTTCAAAGCAGTATCGATCAAATAGTAAATCCATTTGTTCAACTCACAGTTT
+
!''*((((***+))%%%++)(%%%%).1***-+*''))**55CCF>>>>>>CCCCCCC65
`[1 .. $];
	assert(equal(FastQRecord.parse(input),
				 [FastQRecord("seq1", "TTATTTTAAT", "?+BBB/DHH@"),
				  FastQRecord("seq2", "GACCCTTTGCA", "?+BHB/DIH@"),
				  FastQRecord("SEQ_ID", "GATTTGGGGTTCAAAGCAGTATCGATCAAATAGTAAATCCATTTGTTCAACTCACAGTTT", "!''*((((***+))%%%++)(%%%%).1***-+*''))**55CCF>>>>>>CCCCCCC65")].s[]));
}

version (unittest)
{
	import std.algorithm.comparison : equal;
	import nxt.array_help : s;
}
